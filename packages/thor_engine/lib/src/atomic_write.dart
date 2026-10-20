import 'dart:convert';
import 'dart:io';
import 'dart:math';

final _random = Random.secure();

/// Writes [text] (UTF-8) to [file] unless it already holds exactly those
/// bytes; returns whether it wrote. Generated outputs go through here so a
/// run that changes nothing keeps the mtime (a new one would reload
/// `thor dev`) and a reader never sees a half-written file.
///
/// - Bytes are compared, not strings: a different BOM or line ending
///   rewrites, and a file that is not valid UTF-8 is replaced, not thrown on.
/// - The text goes to a temp file next to the target, unique per writer
///   (`<name>.<pid>.<random>.tmp`), then is renamed over it, so two
///   concurrent builds never share or clobber a temp file; the last rename
///   wins and each version is whole. A temp file left by a crashed run is
///   never reused (it stays, harmless); one left by a failed rename is
///   deleted here.
/// - A symlinked target stays a link: the write goes to what it points to.
/// - A directory as the target throws a [FileSystemException].
/// - web: on Windows `rename` over an existing file may fail while another
///   process has it open; this helper is not retried there.
bool writeFileIfChanged(File file, String text) {
  var target = file;
  if (FileSystemEntity.isLinkSync(file.path)) {
    try {
      target = File(file.resolveSymbolicLinksSync());
    } on FileSystemException {
      // A dangling link: writing replaces the link itself.
    }
  }
  final bytes = utf8.encode(text);
  if (_same(target, bytes)) return false;
  target.parent.createSync(recursive: true);
  final tag = _random.nextInt(1 << 32).toRadixString(36);
  final part = File('${target.path}.$pid.$tag.tmp');
  try {
    part.writeAsBytesSync(bytes, flush: true);
    part.renameSync(target.path);
  } catch (_) {
    if (part.existsSync()) part.deleteSync();
    rethrow;
  }
  return true;
}

bool _same(File file, List<int> bytes) {
  try {
    if (file.lengthSync() != bytes.length) return false;
    final old = file.readAsBytesSync();
    // A concurrent writer may have replaced the file since the length check.
    if (old.length != bytes.length) return false;
    for (var i = 0; i < bytes.length; i++) {
      if (old[i] != bytes[i]) return false;
    }
    return true;
  } on FileSystemException {
    // Missing, or a directory: let the write decide.
    return false;
  }
}

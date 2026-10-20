import 'dart:io';

import 'dev.dart';
import 'handler.dart';
import 'http_types.dart';

const _types = {
  'html': 'text/html; charset=utf-8',
  'js': 'text/javascript; charset=utf-8',
  'mjs': 'text/javascript; charset=utf-8',
  'css': 'text/css; charset=utf-8',
  'json': 'application/json',
  'map': 'application/json',
  'svg': 'image/svg+xml',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
  'avif': 'image/avif',
  'gif': 'image/gif',
  'ico': 'image/x-icon',
  'woff2': 'font/woff2',
  'woff': 'font/woff',
  'ttf': 'font/ttf',
  'txt': 'text/plain; charset=utf-8',
  'xml': 'application/xml',
  'webmanifest': 'application/manifest+json',
  'wasm': 'application/wasm',
  'otf': 'font/otf',
  'pdf': 'application/pdf',
  'csv': 'text/csv; charset=utf-8',
  'mp4': 'video/mp4',
  'm4v': 'video/mp4',
  'webm': 'video/webm',
  'mov': 'video/quicktime',
  'mp3': 'audio/mpeg',
  'm4a': 'audio/mp4',
  'ogg': 'audio/ogg',
  'oga': 'audio/ogg',
  'wav': 'audio/wav',
  'opus': 'audio/ogg',
};

const _acceptRanges = HttpHeader('accept-ranges');
const _contentRange = HttpHeader('content-range');
const _contentLength = HttpHeader('content-length');

/// A file bigger than this is streamed from disk, not read into memory.
const _streamAbove = 1 << 20;

/// The bytes a `Range` header asks of a file of [size]: `(start, end)`
/// inclusive, `null` when the header is ignored (not bytes, several ranges,
/// garbage: the full file answers) and `(-1, -1)` when no byte of it is
/// in range (416).
(int, int)? _byteRange(String header, int size) {
  final m = RegExp(r'^\s*bytes\s*=\s*(\d*)\s*-\s*(\d*)\s*$').firstMatch(header);
  if (m == null) return null;
  final a = m.group(1)!, b = m.group(2)!;
  if (a.isEmpty && b.isEmpty) return null;
  if (a.isEmpty) {
    // The last `n` bytes.
    final n = int.tryParse(b);
    if (n == null) return null;
    if (n == 0 || size == 0) return (-1, -1);
    return (n >= size ? 0 : size - n, size - 1);
  }
  final start = int.tryParse(a);
  final end = b.isEmpty ? size - 1 : int.tryParse(b);
  if (start == null || end == null || end < start) return null;
  if (start >= size) return (-1, -1);
  return (start, end >= size ? size - 1 : end);
}

/// Content-hashed names (`engine.dart.3f9a1c2e.js`, see fingerprint).
final _hashed = RegExp(r'\.[0-9a-f]{8}\.[A-Za-z0-9]+$');

/// Whether an `Accept-Encoding` value takes gzip (`gzip;q=0` refuses it).
bool acceptsGzip(String? header) {
  if (header == null) return false;
  for (final part in header.split(',')) {
    final params = part.split(';');
    final coding = params.first.trim().toLowerCase();
    if (coding != 'gzip' && coding != 'x-gzip') continue;
    var q = 1.0;
    for (final p in params.skip(1)) {
      final kv = p.split('=');
      if (kv.length == 2 && kv[0].trim().toLowerCase() == 'q') {
        q = double.tryParse(kv[1].trim()) ?? 1;
      }
    }
    return q > 0;
  }
  return false;
}

/// Serves the files of a folder: content type, gzip for text (compressed
/// once and kept), `immutable` for content-hashed names, ETag otherwise.
///
/// Every request asks here first, pages included. With [index] (the
/// default outside `thor dev`), the folder's file list is read once and a
/// path that isn't in it answers `null` without touching the disk; a file
/// added later isn't served until the server restarts, which a release
/// never needs. `thor dev` looks at the disk on every request.
class StaticFiles {
  /// Files under [root].
  StaticFiles(String root, {this.compress = true, bool? index, this.sourceMaps})
    : root = Directory(root).absolute.path,
      index = index ?? !ThorDev.enabled;

  /// Folder served.
  final String root;

  /// Gzip text files.
  final bool compress;

  /// Whether the file list is read once (see the class).
  final bool index;

  /// Whether `.map` files are served. `null` (the default): only under
  /// `thor dev`, a release never publishes its source maps.
  final bool? sourceMaps;

  // `/a/b.css` for a file under [root], whatever the separator.
  String _key(String path) =>
      '/${path.substring(root.length).replaceAll(r'\\', '/').replaceFirst(RegExp('^/+'), '')}';

  late final Set<String> _files = {
    for (final e
        in Directory(root).existsSync()
            ? Directory(root).listSync(recursive: true)
            : const <FileSystemEntity>[])
      if (e is File ||
          (e is Link &&
              FileSystemEntity.typeSync(e.path) == FileSystemEntityType.file))
        _key(e.path),
  };

  // No `..` segment (a name like `a..b.js` is fine), no dotfile
  // (`.env`, `.git/config`) except under `/.well-known/`.
  static bool _servable(String rel) {
    final segments = rel.split('/');
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      if (s == '..') return false;
      if (s.startsWith('.') &&
          s.isNotEmpty &&
          !(i == 1 && s == '.well-known')) {
        return false;
      }
    }
    return true;
  }

  final _gzipped = <String, (DateTime, List<int>)>{};

  /// The response for [path], or `null` when there is no such file.
  Future<ThorResponse?> lookup(
    String path,
    String? acceptEncoding,
    String? ifNoneMatch, {
    String? range,
    String? ifRange,
  }) async {
    final String rel;
    try {
      rel = Uri.decodeComponent(path);
    } on FormatException {
      return null; // invalid UTF-8: no file has that name
    } on ArgumentError {
      return null; // a broken `%` escape
    }
    if (rel.contains('\\') || rel.contains('\u0000') || rel.endsWith('/')) {
      return null;
    }
    if (!_servable(rel)) return null;
    if (index && !_files.contains(rel)) return null;
    final file = File('$root$rel');
    // A stat is one syscall; the async version costs more than it saves.
    final stat = file.statSync();
    if (stat.type != FileSystemEntityType.file) return null;
    final ext = rel.substring(rel.lastIndexOf('.') + 1).toLowerCase();
    if (ext == 'map' && !(sourceMaps ?? ThorDev.enabled)) return null;
    final type = _types[ext] ?? 'application/octet-stream';
    final etag =
        '"${stat.modified.millisecondsSinceEpoch.toRadixString(36)}-${stat.size.toRadixString(36)}"';
    // A text file over 1 KB has two representations: caches key them by
    // `Accept-Encoding`, the 304 included (as the pages do, server.dart).
    final compressible =
        compress &&
        stat.size > 1024 &&
        (type.startsWith('text/') ||
            type.contains('json') ||
            type.contains('svg') ||
            type.contains('xml'));
    final headers = <HttpHeader, String>{
      HttpHeader.contentType: type,
      HttpHeader.cacheControl: _hashed.hasMatch(rel)
          ? 'public, max-age=31536000, immutable'
          : 'no-cache',
      HttpHeader.etag: etag,
      _acceptRanges: 'bytes',
      if (compressible) HttpHeader.vary: 'Accept-Encoding',
    };
    if (ifNoneMatch != null && matchIfNoneMatch(ifNoneMatch, etag) != null) {
      return ThorResponse(304, headers: headers);
    }
    // A byte range of the file as it is on disk (`If-Range` with another
    // validator: the whole file). Streamed, never read whole.
    if (range != null && (ifRange == null || ifRange.trim() == etag)) {
      if (_byteRange(range, stat.size) case (final start, final end)) {
        if (start < 0) {
          return ThorResponse(
            416,
            headers: {
              _contentRange: 'bytes */${stat.size}',
              HttpHeader.cacheControl: 'no-cache',
            },
          );
        }
        return ThorResponse(
          206,
          headers: {
            ...headers,
            _contentRange: 'bytes $start-$end/${stat.size}',
            _contentLength: '${end - start + 1}',
          },
          stream: file.openRead(start, end + 1),
        );
      }
    }
    if (compressible && acceptsGzip(acceptEncoding)) {
      final cached = _gzipped[rel];
      final body = cached != null && cached.$1 == stat.modified
          ? cached.$2
          : (_gzipped[rel] = (
              stat.modified,
              gzip.encode(await file.readAsBytes()),
            )).$2;
      return ThorResponse(
        200,
        headers: {
          ...headers,
          // Other bytes, same content: a strong tag would claim they are
          // identical to the plain ones (`W/` still matches in If-None-Match).
          HttpHeader.etag: 'W/$etag',
          HttpHeader.contentEncoding: 'gzip',
        },
        body: body,
      );
    }
    if (stat.size > _streamAbove) {
      return ThorResponse(
        200,
        headers: {...headers, _contentLength: '${stat.size}'},
        stream: file.openRead(),
      );
    }
    return ThorResponse(200, headers: headers, body: await file.readAsBytes());
  }
}

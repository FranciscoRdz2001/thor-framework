// writeFileIfChanged: compare-before-write, atomic, safe for concurrent
// writers of the same target.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:thor_engine/lite.dart';

void _writer(List<Object> args) {
  final path = args[0] as String;
  final text = args[1] as String;
  final port = args[2] as SendPort;
  for (var i = 0; i < 40; i++) {
    writeFileIfChanged(File(path), '$text${i.isEven ? '' : ' '}');
  }
  port.send(true);
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('atomic_'));
  tearDown(() => dir.deleteSync(recursive: true));

  File f(String name) => File('${dir.path}/$name');
  List<String> names() => [
    for (final e in dir.listSync())
      e.uri.pathSegments.where((s) => s.isNotEmpty).last,
  ]..sort();

  test('writes a missing file and reports it', () {
    expect(writeFileIfChanged(f('a.js'), 'x'), isTrue);
    expect(f('a.js').readAsStringSync(), 'x');
    expect(names(), ['a.js']);
  });

  test('identical content keeps the mtime', () {
    final a = f('a.js')..writeAsStringSync('x');
    a.setLastModifiedSync(DateTime(2020));
    expect(writeFileIfChanged(a, 'x'), isFalse);
    expect(a.lastModifiedSync(), DateTime(2020));
  });

  test('a different BOM or line ending rewrites', () {
    final a = f('a.js')..writeAsStringSync('a\nb');
    expect(writeFileIfChanged(a, 'a\r\nb'), isTrue);
    expect(a.readAsStringSync(), 'a\r\nb');
    expect(writeFileIfChanged(a, '\u{FEFF}a\r\nb'), isTrue);
    expect(a.readAsBytesSync().take(3), [0xEF, 0xBB, 0xBF]);
  });

  test('an existing file that is not UTF-8 is replaced, not thrown on', () {
    final a = f('a.js')..writeAsBytesSync([0xFF, 0xFE, 0x00]);
    expect(writeFileIfChanged(a, 'ok'), isTrue);
    expect(a.readAsStringSync(), 'ok');
  });

  test('a stale .tmp does not matter and is not reused', () {
    f('a.js.tmp').writeAsStringSync('half');
    f('a.js').writeAsStringSync('old');
    writeFileIfChanged(f('a.js'), 'new');
    expect(f('a.js').readAsStringSync(), 'new');
    expect(f('a.js.tmp').readAsStringSync(), 'half');
  });

  test('the target missing with a .tmp present writes the target', () {
    f('a.js.tmp').writeAsStringSync('half');
    writeFileIfChanged(f('a.js'), 'full');
    expect(f('a.js').readAsStringSync(), 'full');
  });

  test('a directory as target throws and leaves no temp file', () {
    Directory('${dir.path}/a.js').createSync();
    expect(
      () => writeFileIfChanged(f('a.js'), 'x'),
      throwsA(isA<FileSystemException>()),
    );
    expect(names(), ['a.js']);
  });

  test('a read-only target is replaced (rename needs only the directory)', () {
    final a = f('a.js')..writeAsStringSync('old');
    Process.runSync('chmod', ['444', a.path]);
    expect(writeFileIfChanged(a, 'new'), isTrue);
    expect(a.readAsStringSync(), 'new');
  });

  test('a symlink target keeps the link and updates what it points to', () {
    final real = f('real.js')..writeAsStringSync('old');
    final link = Link('${dir.path}/link.js')..createSync(real.path);
    expect(writeFileIfChanged(File(link.path), 'new'), isTrue);
    expect(FileSystemEntity.isLinkSync(link.path), isTrue);
    expect(real.readAsStringSync(), 'new');
    expect(names(), ['link.js', 'real.js']);
  });

  test('a missing parent directory is created', () {
    writeFileIfChanged(File('${dir.path}/x/y/a.js'), 'x');
    expect(File('${dir.path}/x/y/a.js').readAsStringSync(), 'x');
  });

  test('a large output round-trips', () {
    final big = 'abcdefghij' * 2000000;
    writeFileIfChanged(f('big.js'), big);
    expect(f('big.js').lengthSync(), big.length);
    expect(writeFileIfChanged(f('big.js'), big), isFalse);
  });

  test(
    'concurrent writers never leave a torn file or stray temp files',
    () async {
      final target = f('a.js');
      final a = 'A' * 3000000;
      final b = 'B' * 3000000;
      final port = ReceivePort();
      final done = port.take(4).toList();
      for (final text in [a, b, a, b]) {
        await Isolate.spawn(_writer, [target.path, text, port.sendPort]);
      }
      // A reader racing the writers only ever sees a whole version.
      var reads = 0;
      final doneFlag = done.then((_) => true);
      var finished = false;
      unawaited(doneFlag.then((_) => finished = true));
      while (!finished) {
        if (target.existsSync()) {
          final s = target.readAsStringSync();
          expect(
            s.length == a.length || s.length == a.length + 1,
            isTrue,
            reason: 'torn read of ${s.length}',
          );
          reads++;
        }
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      final s = target.readAsStringSync();
      expect(s.length == a.length || s.length == a.length + 1, isTrue);
      expect(s.replaceAll(' ', '').split('').toSet().length, 1);
      expect(names(), ['a.js'], reason: 'reads: $reads');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

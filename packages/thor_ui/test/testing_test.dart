@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

/// Collects what is written to stdout.
class _Capture implements Stdout {
  final lines = StringBuffer();

  @override
  void writeln([Object? object = '']) => lines.writeln(object);

  @override
  void write(Object? object) => lines.write(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  initializeThorTests();

  test('a page without a client script renders without warnings', () async {
    // A fake stdout: there is nothing to close.
    // ignore: close_sinks
    final out = _Capture();
    final html = await IOOverrides.runZoned(
      () => renderDocument(const ThorApp(child: Text('static'))),
      stdout: () => out,
    );
    expect(html, contains('static'));
    expect(out.lines.toString(), isNot(contains('WARNING')));
  });

  test('renderHtml returns the fragment only', () async {
    final html = await renderHtml(const Text('a'));
    expect(html, isNot(contains('<html')));
    expect(const LineSplitter().convert(html), hasLength(1));
  });
}

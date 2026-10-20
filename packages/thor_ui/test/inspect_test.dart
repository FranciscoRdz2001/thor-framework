@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

/// `data-thor-src` values in [html]'s body, in document order.
List<String> sourcesOf(String html) => [
  for (final m in RegExp(
    'data-thor-src="([^"]*)"',
  ).allMatches(html.substring(html.indexOf('<body'))))
    m[1]!,
];

/// The line of the first line of this file containing [needle].
int lineOf(String needle) {
  final lines = _source.split('\n');
  return lines.indexWhere((l) => l.contains(needle)) + 1;
}

late final String _source;

class Card extends StatelessWidget implements ThorElementWidget {
  const Card({super.key});

  @override
  Widget build(BuildContext context) => // card build
      const Column(children: [Text('a'), Badge()]);
}

class Badge extends StatefulWidget {
  const Badge({super.key});

  @override
  State<Badge> createState() => _BadgeState();
}

class _BadgeState extends State<Badge> {
  @override
  Widget build(BuildContext context) => // badge build
      const SizedBox(width: 4, height: 4);
}

/// A route's `build`, like a page's.
Widget page(BuildContext context, PageState<void> state) => // page build
    const Card();

void main() {
  setUpAll(() async {
    initializeThorTests();
    _source = await _readSelf();
  });
  tearDown(() => ThorInspect.enabled = false);

  test('off: no source attribute (release and plain debug)', () async {
    ThorInspect.enabled = false;
    final html = await renderHtml(const Card());
    expect(html, isNot(contains('data-thor-src')));
  });

  test('each element points at the build of the app widget above', () async {
    ThorInspect.enabled = true;
    final html = await renderHtml(const Card());
    final sources = sourcesOf('<body>$html');
    final card = lineOf('// card build');
    final badge = lineOf('// badge build');
    expect(sources, isNotEmpty);
    // The Column and the Text: Card.build (declared one line above).
    expect(sources.first, matches(RegExp('inspect_test\\.dart:${card - 1}:')));
    // The SizedBox: the State's build, not the StatefulWidget's.
    expect(
      sources,
      contains(matches(RegExp('inspect_test\\.dart:${badge - 1}:'))),
    );
    // Absolute paths: the editor link needs them.
    expect(sources.first, startsWith('/'));
  });

  test('thor widgets never become the source', () async {
    ThorInspect.enabled = true;
    final html = await renderHtml(const Text('only thor'));
    expect(sourcesOf('<body>$html'), isEmpty);
  });

  test('a Builder points at its closure, a route at its build', () async {
    ThorInspect.enabled = true;
    final html = await renderHtml(
      Builder(
        builder:
            (context) => // inline closure
                const SizedBox(width: 1, height: 1),
      ),
    );
    expect(sourcesOf('<body>$html'), [
      matches(RegExp('inspect_test\\.dart:${lineOf('// inline closure')}:')),
    ]);
    // A route's page: the file's `build`, not the router's wrapper.
    expect(
      ThorInspect.sourceOf(page),
      contains(':${lineOf('// page build')}:'),
    );
    expect(routePage<void>(build: page), isNotNull);
  });

  test('sources are read again after clearSources (a reload)', () {
    final before = ThorInspect.sourceOf(page);
    ThorInspect.clearSources();
    expect(ThorInspect.sourceOf(page), before);
  });

  test('dev pages name the widgets of each element (data-thor-w)', () async {
    ThorInspect.enabled = true;
    final html = await renderHtml(
      const Padding(padding: EdgeInsets.all(4), child: Card()),
    );
    // The fused Padding has no node: it is read from the first element
    // it built, with Card (innermost first).
    expect(html, matches(RegExp('data-thor-w="[^"]*Card [^"]*Padding"')));
    ThorInspect.enabled = false;
    expect(await renderHtml(const Card()), isNot(contains('data-thor-w')));
  });

  test('each element carries its place in the build (data-thor-at)', () async {
    ThorInspect.enabled = true;
    final html = await renderHtml(const Card());
    final ats = [
      for (final m in RegExp('data-thor-at="([^"]*)"').allMatches(html)) m[1]!,
    ];
    // Card.build's Column is the root; its Text the first child; the
    // Badge widget's own build starts again (its SizedBox: `0.1/0`).
    expect(ats, ['0/0', '0/0.0', '0/0.1/0']);
    ThorInspect.enabled = false;
    expect(await renderHtml(const Card()), isNot(contains('data-thor-at')));
  });

  test('generated route files and the SDK are not app code', () {
    expect(ThorInspect.sourceOf(String), isNull);
    expect(ThorInspect.sourceOf(Column), isNull);
    expect(ThorInspect.sourceOf(print), isNull);
    expect(ThorInspect.sourceOf(42), isNull);
  });
}

Future<String> _readSelf() async {
  final uri = Uri.base.resolve('test/inspect_test.dart');
  return File.fromUri(uri).readAsString();
}

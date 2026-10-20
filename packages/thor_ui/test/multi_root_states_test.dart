@TestOn('vm')
library;

// A state of a `QueryBuilder` or a `Watch` whose builder
// draws more than one root (a `ResponsiveLayout`'s mobile and desktop
// copies, a fragment) is one box for the engine, and a `Watch.list` whose
// container has two roots marks one box too.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class FeedState extends ThorState {
  FeedState({super.key});

  final items = query(() async => <String>['a', 'b']);
  final open = state(false);

  List<String> rows() => items.data.value ?? const <String>[];
  String rowKey(String s) => s;
  String rowText(String s) => s;
  bool isOpen() => open.value;
}

void main() {
  initializeThorTests();
  setUpAll(
    () => ThorState.register({
      FeedState: ThorStateType('FeedState', (state) {
        final s = state as FeedState;
        return [
          ...s.items.members('items'),
          ThorMember('rows', s.rows, call: (_) => s.rows()),
          ThorMember(
            'rowKey',
            s.rowKey,
            callWithItem: (i) => s.rowKey(i! as String),
          ),
          ThorMember(
            'rowText',
            s.rowText,
            callWithItem: (i) => s.rowText(i! as String),
          ),
          ThorMember(
            'isOpen',
            s.isOpen,
            call: (_) => s.isOpen(),
            variants: const [false, true],
          ),
        ];
      }),
    }),
  );

  // The elements that carry the mark of finite states, not the templates.
  int marked(String html, String id) => RegExp(
    '<[a-z]+ [^>]*data-tv="${RegExp.escape(id)}"',
  ).allMatches(html).length;

  const two = ResponsiveLayout(
    mobile: Text('movil'),
    desktop: Text('escritorio'),
  );

  test('a QueryBuilder state with two roots is one marked box', () async {
    final s = FeedState(key: 'a');
    await s.items.prefetch((e) => ('x', ServerErrorKind.server));
    final html = await renderHtml(
      QueryBuilder<List<String>>(
        query: s.items,
        builder: (context, snap) => snap.hasData ? two : const Text('wait'),
      ),
    );
    expect(marked(html, r'FeedState#a.items$phase'), 1);
    expect(
      html,
      contains(
        RegExp(
          r'<div style="[^"]*display: contents[^"]*" '
          r'data-tv="FeedState#a.items\$phase"',
        ),
      ),
    );
    expect(html, contains('movil'));
    expect(html, contains('escritorio'));
  });

  test('the same state as a template of the others: its box, whole', () async {
    final s = FeedState(key: 'b');
    final html = await renderHtml(
      QueryBuilder<List<String>>(
        query: s.items,
        builder: (context, snap) => snap.hasData ? two : const Text('wait'),
      ),
    );
    // Live: waiting (one root); the done state, with two roots, ships as a
    // template whose only root is the box.
    expect(marked(html, r'FeedState#b.items$phase'), 1);
    final template = RegExp(
      r'<template data-tvt="FeedState#b.items\$phase" data-i="2">(.*?)</template>',
      dotAll: true,
    ).firstMatch(html)![1]!;
    expect(template, startsWith('<div'));
    expect(template, contains('display: contents'));
    expect(template, contains('movil'));
    expect(template, contains('escritorio'));
  });

  test('a Watch state with a fragment (even a fragment of a fragment) '
      'is one marked box', () async {
    final s = FeedState(key: 'c');
    for (final built in <Widget>[
      const Widget.fragment([Text('one'), Text('two')]),
      const Widget.fragment([
        Widget.fragment([Text('one'), Text('two')]),
      ]),
      two,
    ]) {
      final html = await renderHtml(
        Watch(
          s.isOpen,
          builder: (open) => open ? built : const Text('panel closed'),
        ),
      );
      expect(marked(html, 'FeedState#c.isOpen'), 1, reason: '$built');
      // The state with several roots ships as its box, whole.
      final template = RegExp(
        r'<template data-tvt="FeedState#c.isOpen" data-i="1">(.*?)</template>',
        dotAll: true,
      ).firstMatch(html)![1]!;
      expect(template, startsWith('<div'), reason: '$built');
      expect(template, contains('display: contents'), reason: '$built');
    }
  });

  test('a Watch state with DialogTrigger(dialog:) is one marked box', () async {
    final s = FeedState(key: 'f');
    final html = await renderHtml(
      Watch(
        s.isOpen,
        builder: (open) => open
            ? const DialogTrigger(
                dialog: AlertDialog(title: Text('Sure?')),
                child: FilledButton(child: Text('Open')),
              )
            : const Text('no'),
      ),
    );
    expect(marked(html, 'FeedState#f.isOpen'), 1);
    final template = RegExp(
      r'<template data-tvt="FeedState#f.isOpen" data-i="1">(.*?)</template>',
      dotAll: true,
    ).firstMatch(html)![1]!;
    expect(template, startsWith('<div'));
    expect(template, contains('display: contents'));
    expect(template, contains('<dialog'));
  });

  test('one root is not boxed', () async {
    final s = FeedState(key: 'd');
    final html = await renderHtml(
      Watch(
        s.isOpen,
        builder: (open) => Widget.fragment([Text(open ? 'yes' : 'no')]),
      ),
    );
    expect(html, isNot(contains('display: contents')));
  });

  test('a list container with two roots: one marker on a box, a template '
      'in each copy', () async {
    final s = FeedState(key: 'e');
    await s.items.prefetch((e) => ('x', ServerErrorKind.server));
    final html = await renderHtml(
      Watch.list(
        s.rows,
        itemKey: s.rowKey,
        container: (rows) => ResponsiveLayout(
          mobile: Column(children: rows),
          desktop: Row(children: rows),
        ),
        each: (row) => row.text(s.rowText),
      ),
    );
    expect(
      RegExp(
        r'<[a-z]+ [^>]*data-tl="FeedState#e.rows"',
      ).allMatches(html).length,
      1,
    );
    expect(
      RegExp(r'<template data-tlt="FeedState#e.rows"').allMatches(html).length,
      2,
    );
  });
}

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// A ThorState as thor_builder would generate it (tests don't run the build).
abstract class _LabelStateMembers extends ThorState {
  @override
  String get $type => 'LabelState';

  @override
  List<ThorMember> get $members {
    final s = this as LabelState;
    return [
      ThorMember.state('count', s.count),
      ThorMember('label', s.label, call: (_) => s.label()),
    ];
  }
}

class LabelState extends _LabelStateMembers {
  final count = state(3);
  String label() => 'Count ${count.value}';
}

final labels = LabelState();

const _heart = IconData.svg('memo-heart', '<path d="M1 1h2"/>');

/// Counts its builds: a reuse adds its HTML without building it.
// Not a ThorElementWidget on purpose: in debug, classes inside an app
// component are named after it, and such a subtree is never kept.
// ignore: thor_lints/missing_thor_element_widget
class Counted extends StatelessWidget {
  const Counted(this.name, {super.key});

  final String name;

  static final builds = <String, int>{};

  @override
  Widget build(BuildContext context) {
    builds.update(name, (n) => n + 1, ifAbsent: () => 1);
    return Container(
      padding: const EdgeInsets.all(8).when(medium: const EdgeInsets.all(16)),
      child: Row(
        children: [
          const Icon(_heart, size: 14),
          const CircularProgressIndicator(),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

/// Shows the theme's primary color: an inherited value.
// ignore: thor_lints/missing_thor_element_widget
class Themed extends StatelessWidget {
  const Themed({super.key});

  @override
  Widget build(BuildContext context) =>
      Row(children: [Text('${Theme.of(context).colorScheme.primary}')]);
}

/// An app's inherited widget, made anew for every page (compared by
/// identity).
class Scope extends InheritedWidget {
  const Scope({super.key, required this.value, required super.child});

  final int value;

  @override
  bool updateShouldNotify(Scope oldWidget) => false; // wrong, on purpose
}

// ignore: thor_lints/missing_thor_element_widget
class ReadsScope extends StatelessWidget {
  const ReadsScope({super.key});

  static var builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    return Row(
      children: [
        Text(
          'value ${context.dependOnInheritedWidgetOfExactType<Scope>()!.value}',
        ),
      ],
    );
  }
}

var _global = 0;

/// Reads a global: not a pure build.
// ignore: thor_lints/missing_thor_element_widget
class ReadsGlobal extends StatelessWidget {
  const ReadsGlobal({super.key});

  @override
  Widget build(BuildContext context) => Row(children: [Text('n $_global')]);
}

/// Asks the page for an id.
// ignore: thor_lints/missing_thor_element_widget
class WithId extends StatelessWidget {
  const WithId({super.key});

  static var builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    return html.div(id: ThorStyleRegistry.of(context)!.uniqueId('memo'), [
      const Text('labelled'),
    ]);
  }
}

// ignore: thor_lints/missing_thor_element_widget
class HasState extends StatefulWidget {
  const HasState({super.key});

  @override
  State<HasState> createState() => _HasStateState();
}

class _HasStateState extends State<HasState> {
  static var created = 0;

  @override
  void initState() {
    super.initState();
    created++;
  }

  @override
  Widget build(BuildContext context) => const Counted('in state');
}

// ignore: thor_lints/missing_thor_element_widget
class HoldsState extends StatelessWidget {
  const HoldsState({super.key});

  @override
  Widget build(BuildContext context) => const HasState();
}

Future<String> page(Widget body, {ThemeData? theme}) =>
    renderDocument(ThorApp(theme: theme, child: body));

Widget list(List<Widget> children) =>
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);

/// [body] with the memo off (the reference), then three pages with it on
/// (seen, recorded, reused): each one the reference, byte for byte.
Future<String> same(Widget Function() body, {ThemeData? theme}) async {
  final mode = ConstMemo.mode;
  ConstMemo.mode = ConstMemoMode.off;
  final off = await page(body(), theme: theme);
  ConstMemo.mode = mode;
  for (final pass in ['seen', 'recorded', 'reused']) {
    expect(await page(body(), theme: theme), off, reason: pass);
  }
  return off;
}

void main() {
  setUpAll(initializeThorTests);
  setUp(() {
    ConstMemo.clear();
    ConstMemo.mode = ConstMemoMode.on;
    ConstMemo.minNodes = 1;
    Counted.builds.clear();
  });
  tearDown(() {
    ConstMemo.mode = ConstMemoMode.off;
    ConstMemo.clear();
    ConstMemo.minNodes = 12;
    ConstMemo.maxEntries = 2000;
  });

  test('off: every page builds every widget', () async {
    ConstMemo.mode = ConstMemoMode.off;
    for (var i = 0; i < 3; i++) {
      await page(list([const Counted('a')]));
    }
    expect(Counted.builds['a'], 3);
    expect(ConstMemo.length, 0);
  });

  test('a const subtree of an earlier page is added again as it is', () async {
    await same(() => list([const Counted('a')]));
    // The reference, the page that saw it and the one that recorded it;
    // the page that reuses it only previews its root for the Column
    // (one build of the component, not of its subtree).
    expect(Counted.builds['a'], 4);
    expect(ConstMemo.length, greaterThan(0));
  });

  test('twice on one page: both reused, the page the same', () async {
    await same(() => list([const Counted('a'), const Counted('a')]));
    // Recording builds the first; the second on that page is a reuse. The
    // reusing page previews the first for the Column.
    expect(Counted.builds['a'], 2 + 2 + 1 + 1);
  });

  test('a page with only the subtree gets its classes, keyframes and '
      'symbols', () async {
    await page(list([const Text('first'), const Counted('k')]));
    await page(list([const Text('first'), const Counted('k')]));
    final alone = await same(() => list([const Counted('k')]));
    expect(alone, contains('@keyframes'));
    expect(alone, contains('<symbol id="memo-heart"'));
  });

  test(
    'a main image inside keeps its preload on the pages that reuse it',
    () async {
      final html = await same(
        () => list([
          const Column(
            children: [
              Text('hero'),
              Image.network('/hero.jpg', priority: true, width: 640),
            ],
          ),
        ]),
      );
      expect(html, contains('rel="preload"'));
      expect(html, contains('/hero.jpg'));
    },
  );

  test('inside wrappers the page is the same', () async {
    await same(
      () => list([
        const Padding(padding: EdgeInsets.all(4), child: Counted('w')),
        const Expanded(child: Counted('e')),
      ]),
    );
  });

  test('another theme is another subtree, never the kept one', () async {
    final a = ThemeData(colorScheme: const ColorScheme.light());
    final b = ThemeData(
      colorScheme: const ColorScheme.light(primary: Color(0xFF00AA00)),
    );
    final withA = await same(() => list([const Themed()]), theme: a);
    final withB = await page(list([const Themed()]), theme: b);
    ConstMemo.mode = ConstMemoMode.off;
    expect(withB, await page(list([const Themed()]), theme: b));
    expect(withB, isNot(withA));
  });

  test('an inherited widget made per page is compared by identity: always '
      'built, never stale', () async {
    final before = ReadsScope.builds;
    for (var i = 1; i <= 4; i++) {
      final html = await page(
        list([Scope(value: i, child: const ReadsScope())]),
      );
      expect(html, contains('value $i'));
    }
    expect(ReadsScope.builds - before, 4);
  });

  test('a ThorState inside is never kept', () async {
    await same(
      () => list([
        Row(children: [Watch(labels.label)]),
      ]),
    );
  });

  test('a page id inside is never kept: ids stay unique per page', () async {
    final before = WithId.builds;
    final html = await same(() => list([const WithId(), const WithId()]));
    // Plus one preview per page, dropped when it asks for an id.
    expect(WithId.builds - before, 8 + 4);
    expect(RegExp('id="memo').allMatches(html).length, 2);
    expect(html, isNot(matches(RegExp(r'id="(memo\d+)"[\s\S]*id="\1"'))));
  });

  test(
    'a StatefulWidget inside is never kept: each page creates its state',
    () async {
      final before = _HasStateState.created;
      await same(() => list([const HoldsState()]));
      expect(_HasStateState.created - before, 4);
    },
  );

  test('small subtrees are not kept', () async {
    ConstMemo.minNodes = 1000;
    await same(() => list([const Counted('small')]));
    expect(Counted.builds['small'], 4);
    expect(ConstMemo.length, 0);
  });

  test('maxEntries bounds what is kept', () async {
    ConstMemo.maxEntries = 1;
    await same(() => list([const Counted('x'), const Counted('y')]));
    expect(ConstMemo.length, 1);
    ConstMemo.maxEntries = 0;
    await page(list([const Counted('z')]));
    expect(ConstMemo.length, 0);
  });

  test('clear drops what is kept', () async {
    await same(() => list([const Counted('a')]));
    ConstMemo.clear();
    expect(ConstMemo.length, 0);
  });

  test('verify: a const widget that reads a global is THOR-R017', () async {
    ConstMemo.mode = ConstMemoMode.verify;
    for (var i = 0; i < 2; i++) {
      _global++;
      await page(list([const ReadsGlobal()]));
    }
    _global++;
    await expectLater(
      page(list([const ReadsGlobal()])),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('THOR-R017'),
        ),
      ),
    );
  });

  test('verify: a pure const subtree passes', () async {
    ConstMemo.mode = ConstMemoMode.verify;
    await same(() => list([const Counted('v')]));
  });
}

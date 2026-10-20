@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/server.dart' show Document;
import 'package:thor_ui/src/engine/form_script.dart' show formScript;
import 'package:thor_ui/src/foundation/element.dart' show thorElement;
import 'package:thor_ui/src/foundation/style_registry.dart'
    show elementStyle, elementStyleMemoSize;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// A ThorState as thor_builder would generate it (tests don't run the build).
abstract class _CounterStateMembers extends ThorState {
  @override
  String get $type => 'CounterState';

  @override
  List<ThorMember> get $members {
    final s = this as CounterState;
    return [
      ThorMember.state('count', s.count),
      ThorMember('label', s.label, call: (_) => s.label()),
    ];
  }
}

class CounterState extends _CounterStateMembers {
  final count = state(3);
  String label() => 'Count ${count.value}';
}

final counter = CounterState();

const _heart = IconData.svg('test-heart', '<path d="M1 1h2"/>');
const _dot = IconData.svg('test-dot', '<circle r="1"/>');

/// Counts its builds: a hit replays its HTML without building it.
// Not a ThorElementWidget on purpose: in debug, classes inside an app
// component are named after it, and such a fragment is never kept.
// ignore: thor_lints/missing_thor_element_widget
class Counted extends StatelessWidget {
  const Counted(this.name, {super.key, this.fail = false});

  final String name;
  final bool fail;

  static final builds = <String, int>{};

  @override
  Widget build(BuildContext context) {
    builds.update(name, (n) => n + 1, ifAbsent: () => 1);
    if (fail) throw StateError('build failed');
    return Container(
      padding: const EdgeInsets.all(8).when(medium: const EdgeInsets.all(16)),
      color: const Color(0xFFFFFFFF).when(dark: const Color(0xFF000000)),
      child: Row(
        children: [
          const Icon(_heart, size: 14),
          const CircularProgressIndicator(),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF333333),
              ).copyWith(color: const Color(0xFF333333).when(hover: blue)),
            ),
          ),
        ],
      ),
    );
  }
}

const blue = Color(0xFF1D4ED8);

/// An app component whose build is a [Cached].
class Component extends StatelessWidget implements ThorElementWidget {
  const Component({super.key});
  @override
  Widget build(BuildContext context) =>
      const Cached(cacheKey: 'c', child: Counted('c'));
}

/// Another widget type above: another place for the same key.
class Elsewhere extends StatelessWidget {
  const Elsewhere({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

/// [body] rendered with the caches off (the reference), then on: cold and
/// warm must both be the reference, byte for byte.
Future<String> same(Widget Function() body) async {
  renderCachesEnabled = false;
  final off = await page(body());
  renderCachesEnabled = true;
  expect(await page(body()), off, reason: 'caches on, first render');
  expect(await page(body()), off, reason: 'caches on, replayed');
  return off;
}

void main() {
  setUpAll(initializeThorTests);
  setUp(() {
    renderCachesEnabled = true;
    Cached.clear();
    Counted.builds.clear();
  });
  tearDown(() {
    renderCachesEnabled = true;
    Cached.maxEntries = 1000;
  });

  group('element style memo', () {
    test('merges, variants and wrappers give the same page', () async {
      await same(
        () => const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Counted('a'),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Counted('b'),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(maxWidth: 400),
                margin: EdgeInsets.only(top: 8),
                child: Text('capped'),
              ),
            ),
            Row(
              children: [
                Expanded(flex: 2, child: Text('one')),
                Spacer(),
                SizedBox(width: 12),
                Text('two'),
              ],
            ),
          ],
        ),
      );
    });

    test('without ThorApp (inline styles) too', () async {
      Widget body() => Container(
        color: blue.when(dark: const Color(0xFF93C5FD)),
        padding: const EdgeInsets.all(4).when(hover: const EdgeInsets.all(6)),
        child: const Text('inline'),
      );
      renderCachesEnabled = false;
      final off = await renderHtml(body());
      renderCachesEnabled = true;
      expect(await renderHtml(body()), off);
      expect(await renderHtml(body()), off);
    });

    test('the same declarations in another slot are another style', () async {
      // A reset (baseCss) loses to what the Row grants its children; the
      // element's own css wins over it: equal maps, different classes.
      final out = await same(
        () => Row(
          children: [
            thorElement('i', baseCss: const {'flex': '1 1 0px'}),
            thorElement('b', css: const {'flex': '1 1 0px'}),
          ],
        ),
      );
      final i = RegExp('<i class="(t[a-z0-9]+)"').firstMatch(out)![1];
      final b = RegExp('<b class="(t[a-z0-9]+)"').firstMatch(out)![1];
      expect(i, isNot(b));
      expect(out, contains('.$b{flex: 1 1 0px}'));
    });

    test('every input is part of the key', () async {
      // Pairs that differ in one input only: a memo that ignored it would
      // give the second element the first one's class.
      ConditionalCss on(CssCondition when) =>
          ConditionalCss(when, const {'color': 'red'});
      final pairs = <String, (Widget, Widget)>{
        'baseCss': (
          thorElement('i', baseCss: const {'color': 'red'}),
          thorElement('i', baseCss: const {'color': 'blue'}),
        ),
        'condition value': (
          thorElement('i', conditions: [on(CssCondition.hover)]),
          thorElement('i', conditions: [on(CssCondition.focused)]),
        ),
        'condition kind': (
          thorElement('i', conditions: [on(const CssCondition.media('x'))]),
          thorElement('i', conditions: [on(const CssCondition.selector('x'))]),
        ),
        'condition css': (
          thorElement('i', conditions: [on(CssCondition.hover)]),
          thorElement(
            'i',
            conditions: const [
              ConditionalCss(CssCondition.hover, {'color': 'blue'}),
            ],
          ),
        ),
        'layer': (
          thorElement('i', css: const {'color': 'red'}),
          thorElement(
            'i',
            css: const {'color': 'red'},
            layer: ThorLayer.overrides,
          ),
        ),
        'wrapper css': (
          const Opacity(opacity: 0.5, child: Text('a')),
          const Opacity(opacity: 0.6, child: Text('a')),
        ),
        'wrapper reset': (
          const Link(href: RouteUrl('/'), child: Text('a')),
          const Semantics(label: 'a', child: Text('a')),
        ),
        'parent': (
          const Row(children: [Expanded(child: Text('a'))]),
          const Column(children: [Expanded(child: Text('a'))]),
        ),
      };
      for (final MapEntry(:key, value: (a, b)) in pairs.entries) {
        final out = await same(() => Column(children: [a, b]));
        expect(out, isNotEmpty, reason: key);
      }
    });

    test('declaration order is part of the style', () async {
      final out = await same(
        () => Column(
          children: [
            thorElement('i', css: const {'color': 'red', 'margin': '0'}),
            thorElement('b', css: const {'margin': '0', 'color': 'red'}),
          ],
        ),
      );
      expect(out, contains('color: red; margin: 0'));
      expect(out, contains('margin: 0; color: red'));
    });

    test('a map changed after a render is read again', () async {
      final css = {'color': 'red'};
      final first = await page(thorElement('p', css: css));
      css['color'] = 'blue';
      final second = await page(thorElement('p', css: css));
      expect(first, contains('color: red'));
      expect(second, contains('color: blue'));
      expect(second, isNot(contains('color: red')));
      css['color'] = 'red';
      expect(await page(thorElement('p', css: css)), first);
    });

    test('is bounded: styles built from data do not grow it forever', () {
      for (var i = 0; i < 20001; i++) {
        elementStyle(
          layer: ThorLayer.props,
          capsWidth: false,
          baseCss: const {},
          wrapBaseCss: const {},
          granted: const {},
          css: {'width': '${i}px'},
          flexible: const {},
          wrapClassCss: const {},
          wrapCss: const {},
          conditions: const [],
          wrapConditions: const [],
          compute: () => ({'width': '${i}px'}, const []),
        );
      }
      expect(elementStyleMemoSize, lessThanOrEqualTo(20000));
      expect(elementStyleMemoSize, greaterThan(0));
    });
  });

  group('.when() declarations memo', () {
    const base = StyleProps(widthFactor: 0.9);
    const medium = StyleProps(widthFactor: 0.7);

    test('the same const parts give the same declarations once', () {
      final a = base.when(medium: medium).toCss();
      final b = base.when(medium: medium).toCss();
      expect(identical(a, b), isTrue);
      renderCachesEnabled = false;
      try {
        expect(b, base.when(medium: medium).toCss());
      } finally {
        renderCachesEnabled = true;
      }
    });

    test('other parts are another entry', () {
      final a = base.when(medium: medium).toCss();
      final b = base.when(expanded: medium).toCss();
      expect(identical(a, b), isFalse);
      expect(a, isNot(b));
    });

    test('parts built per call miss, with the same declarations', () {
      final a = base
          .when(medium: StyleProps(widthFactor: double.parse('0.7')))
          .toCss();
      final b = base
          .when(medium: StyleProps(widthFactor: double.parse('0.7')))
          .toCss();
      expect(identical(a, b), isFalse);
      expect(a, b);
    });
  });

  group('Cached', () {
    Widget list(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );

    test('adding it changes nothing in the page', () async {
      final plain = await page(
        list([
          const Counted('a'),
          const Container(width: double.infinity, child: Text('wide')),
        ]),
      );
      final cached = await same(
        () => list([
          const Cached(cacheKey: 'a', child: Counted('a')),
          const Cached(
            cacheKey: 'wide',
            child: Container(width: double.infinity, child: Text('wide')),
          ),
        ]),
      );
      expect(cached, plain);
    });

    test('a hit replays the HTML without building the child', () async {
      await same(() => list([const Cached(cacheKey: 1, child: Counted('a'))]));
      expect(Counted.builds['a'], 2); // the reference (off) + the first on
      expect(Cached.length, 1);
    });

    test('a page with only the fragment gets its classes, keyframes and '
        'symbols', () async {
      // Filled by a page where other widgets registered them first.
      await page(
        list([
          const Counted('first'),
          const Icon(_dot),
          const Cached(cacheKey: 'k', child: Counted('k')),
        ]),
      );
      expect(Counted.builds['k'], 1);
      final alone = await same(
        () => list([const Cached(cacheKey: 'k', child: Counted('k'))]),
      );
      expect(Counted.builds['k'], 2); // only the reference built it again
      expect(alone, contains('@keyframes'));
      expect(alone, contains('<symbol id="test-heart"'));
      expect(alone, isNot(contains('test-dot')));
    });

    test('a main image inside keeps its preload when replayed', () async {
      final html = await same(
        () => list([
          const Cached(
            cacheKey: 'hero',
            child: Image.network('/hero.jpg', priority: true, width: 640),
          ),
        ]),
      );
      expect(html, contains('rel="preload"'));
    });

    test('a form inside is replayed and the page still ships its '
        'script', () async {
      // A Form asks the page for its script: a flag of the page, recorded
      // with the fragment, not a reason to build it on every request.
      Widget body() => list([
        const Cached(
          cacheKey: 'form',
          child: Form(action: '/a', child: Counted('form')),
        ),
      ]);
      final html = await same(body);
      expect(html, contains(formScript));
      expect(Counted.builds['form'], 2); // the reference + the first on
      expect(Cached.length, 1);
      // A page whose only form comes from the replay ships the script too.
      expect(await page(body()), html);
      expect(Counted.builds['form'], 2);
    });

    test('rules keep the order of a fresh build when the page already has '
        'some', () async {
      await page(list([const Cached(cacheKey: 'k', child: Counted('k'))]));
      await same(
        () => list([
          const Text('before', style: TextStyle(fontSize: 13)),
          const Icon(_dot),
          const Cached(cacheKey: 'k', child: Counted('k')),
          const Counted('after'),
        ]),
      );
    });

    test('the same key under another parent is another entry', () async {
      await same(
        () => list([const Cached(cacheKey: 'p', child: Counted('p'))]),
      );
      await same(
        () => const Row(
          children: [Cached(cacheKey: 'p', child: Counted('p'))],
        ),
      );
      expect(Cached.length, 2);
    });

    test('the same key under other widgets is another entry', () async {
      await same(
        () => list([const Cached(cacheKey: 'w', child: Counted('w'))]),
      );
      await same(
        () => Elsewhere(
          child: list([const Cached(cacheKey: 'w', child: Counted('w'))]),
        ),
      );
      expect(Cached.length, 2);
    });

    test('nested: an inner hit is part of the outer fragment', () async {
      Widget tree() => list([
        const Cached(
          cacheKey: 'outer',
          child: Column(
            children: [
              Counted('outer'),
              Cached(cacheKey: 'inner', child: Counted('inner')),
            ],
          ),
        ),
      ]);
      await page(tree());
      Cached.invalidate('outer');
      // The outer is built again, the inner replayed into it.
      await page(tree());
      expect(Counted.builds, {'outer': 2, 'inner': 1});
      // A fresh page from the outer entry alone has the inner's styles.
      await same(tree);
      expect(Counted.builds, {'outer': 3, 'inner': 2});
    });

    test('ttl: an expired entry is built again', () async {
      Widget tree(Duration ttl) =>
          list([Cached(cacheKey: 't', ttl: ttl, child: const Counted('t'))]);
      await page(tree(Duration.zero));
      await page(tree(Duration.zero));
      expect(Counted.builds['t'], 2);
      Cached.clear();
      await page(tree(const Duration(hours: 1)));
      await page(tree(const Duration(hours: 1)));
      expect(Counted.builds['t'], 3);
    });

    test('invalidate drops one key, clear drops all', () async {
      Widget tree() => list([
        const Cached(cacheKey: 'x', child: Counted('x')),
        const Cached(cacheKey: 'y', child: Counted('y')),
      ]);
      await page(tree());
      Cached.invalidate('x');
      await page(tree());
      expect(Counted.builds, {'x': 2, 'y': 1});
      Cached.clear();
      await page(tree());
      expect(Counted.builds, {'x': 3, 'y': 2});
    });

    test('maxEntries evicts the least recently used', () async {
      Cached.maxEntries = 2;
      Future<void> show(String k) =>
          page(list([Cached(cacheKey: k, child: Counted(k))]));
      await show('a');
      await show('b');
      await show('a'); // a is now more recent than b
      await show('c'); // evicts b
      expect(Cached.length, 2);
      await show('a');
      await show('b');
      expect(Counted.builds, {'a': 1, 'b': 2, 'c': 1});
      Cached.maxEntries = 0;
      Cached.clear();
      await show('a');
      await show('a');
      expect(Cached.length, 0);
      expect(Counted.builds['a'], 3);
    });

    test('caches off: always built', () async {
      renderCachesEnabled = false;
      await page(list([const Cached(cacheKey: 'o', child: Counted('o'))]));
      await page(list([const Cached(cacheKey: 'o', child: Counted('o'))]));
      expect(Counted.builds['o'], 2);
      expect(Cached.length, 0);
    });

    test('without ThorApp: always built, same HTML', () async {
      const tree = Cached(cacheKey: 'n', child: Counted('n'));
      final first = await renderHtml(tree);
      expect(await renderHtml(tree), first);
      expect(Counted.builds['n'], 2);
      expect(Cached.length, 0);
    });

    test(
      'a build that throws keeps nothing and the next page is whole',
      () async {
        await expectLater(
          page(
            list([
              const Cached(cacheKey: 'f', child: Counted('f', fail: true)),
            ]),
          ),
          throwsA(isA<StateError>()),
        );
        expect(Cached.length, 0);
        await same(
          () => list([
            const Cached(
              cacheKey: 'g',
              child: Cached(cacheKey: 'f', child: Counted('f')),
            ),
          ]),
        );
      },
    );

    group('refuses (fail closed)', () {
      Matcher error(String text) => throwsA(
        isA<StateError>().having((e) => e.message, 'message', contains(text)),
      );

      test('a ThorState inside', () async {
        await expectLater(
          page(list([Cached(cacheKey: 's', child: Watch(counter.label))])),
          error('ThorState'),
        );
        expect(Cached.length, 0);
      });

      test('Document.head inside', () async {
        await expectLater(
          page(
            list([
              const Cached(
                cacheKey: 'h',
                child: Document.head(title: 'per page'),
              ),
            ]),
          ),
          error('Document.head'),
        );
      });

      test('<body> inside', () async {
        await expectLater(
          page(
            const Cached(
              cacheKey: 'b',
              child: Widget.element(tag: 'body', children: [Text('x')]),
            ),
          ),
          error('<body>'),
        );
      });

      test('a wrapper that decorates its first element', () async {
        await expectLater(
          page(
            const Row(
              children: [
                Expanded(
                  child: Cached(cacheKey: 'e', child: Counted('e')),
                ),
              ],
            ),
          ),
          error('wrapper'),
        );
        await expectLater(
          page(
            list([
              const Opacity(
                opacity: 0.5,
                child: Cached(cacheKey: 'o', child: Counted('o')),
              ),
            ]),
          ),
          error('wrapper'),
        );
        // Around a component of the app that returns a Cached: the data
        // waits for the first thor element, inside the fragment.
        await expectLater(
          page(list([const Opacity(opacity: 0.5, child: Component())])),
          error('wrapper'),
        );
        expect(Cached.length, 0);
        // Inside is fine.
        await same(
          () => list([
            const Cached(
              cacheKey: 'o',
              child: Opacity(opacity: 0.5, child: Counted('o')),
            ),
          ]),
        );
      });
    });
  });
}

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// An app component is transparent to its parent.
// Every case renders the same page twice, once with the widget written
// inline and once extracted into app components (one and two levels): the
// HTML must be the same, as in Flutter, where extracting a widget never
// changes the layout.

// The member list thor generates for [FlagState], by hand.
abstract class _FlagStateMembers extends ThorState {
  @override
  String get $type => 'FlagState';

  @override
  List<ThorMember> get $members {
    final s = this as FlagState;
    return [
      ThorMember.state('on', s.on),
      ThorMember(
        'isOn',
        s.isOn,
        call: (_) => s.isOn(),
        variants: const [false, true],
      ),
    ];
  }
}

class FlagState extends _FlagStateMembers {
  final on = state(false);
  bool isOn() => on.value;
}

final flag = FlagState();

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

/// An app component: what it builds is [child]. No marker, no hint.
class _Part extends StatelessWidget {
  const _Part(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Two levels: a component whose build is another component.
class _Outer extends StatelessWidget {
  const _Outer(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => _Part(child);
}

/// A `const` component that builds a `Center`.
class _Centered extends StatelessWidget {
  const _Centered();

  @override
  Widget build(BuildContext context) => const Center(child: Text('c'));
}

/// Expects [build] to render the same page with its widget inline, inside
/// one app component and inside two.
Future<void> expectTransparent(
  Widget Function(Widget Function(Widget)) build,
) async {
  final inline = await page(build((w) => w));
  expect(await page(build(_Part.new)), inline, reason: 'one level');
  expect(await page(build(_Outer.new)), inline, reason: 'two levels');
  expect(
    await page(build((w) => Builder(builder: (_) => w))),
    inline,
    reason: 'Builder',
  );
}

void main() {
  setUpAll(initializeThorTests);

  group('fills the width through a component', () {
    test('in a centered Column', () async {
      await expectTransparent(
        (c) => Center(
          child: Column(
            children: [
              c(const Center(child: Text('wide'))),
              const Text('x'),
            ],
          ),
        ),
      );
    });

    test('in a Row', () async {
      await expectTransparent(
        (c) => Center(
          child: Column(
            children: [
              c(const Row(children: [Text('a'), Text('b')])),
            ],
          ),
        ),
      );
    });

    test('in a SizedBox', () async {
      await expectTransparent(
        (c) => Center(
          child: SizedBox(height: 40, child: c(const Center(child: Text('s')))),
        ),
      );
    });

    test('in a Stack, a Container and a Padding', () async {
      await expectTransparent(
        (c) => Center(
          child: Column(
            children: [
              Stack(children: [c(const Center(child: Text('s')))]),
              Container(
                color: const Color(0xFF112233),
                child: c(const Align(child: Text('a'))),
              ),
              Padding(
                padding: const EdgeInsets.all(3),
                child: c(const Center(child: Text('p'))),
              ),
            ],
          ),
        ),
      );
    });
  });

  group('box merging through a component', () {
    test('a Container merges into the Flex a component builds', () async {
      await expectTransparent(
        (c) => Container(
          padding: const EdgeInsets.all(8),
          color: const Color(0xFF445566),
          child: c(const Column(children: [Text('a'), Text('b')])),
        ),
      );
    });

    test('with a role of its own', () async {
      await expectTransparent(
        (c) => Semantics(
          role: SemanticsRole.region,
          child: Container(
            padding: const EdgeInsets.all(8),
            child: c(const Row(children: [Text('a'), Text('b')])),
          ),
        ),
      );
    });

    test('a Padding merges into it too', () async {
      await expectTransparent(
        (c) => Padding(
          padding: const EdgeInsets.all(12),
          child: c(const Column(children: [Text('a'), Text('b')])),
        ),
      );
    });

    test('a Padding around a Container becomes its margin', () async {
      await expectTransparent(
        (c) => Padding(
          padding: const EdgeInsets.all(12),
          child: c(const Container(color: Color(0xFF778899), child: Text('m'))),
        ),
      );
    });

    test('a sized SizedBox takes a scroll view it wraps', () async {
      await expectTransparent(
        (c) => SizedBox(
          height: 200,
          child: c(
            const SingleChildScrollView(
              child: Column(children: [Text('a'), Text('b')]),
            ),
          ),
        ),
      );
    });

    test('a scroll view becomes the Flex it scrolls', () async {
      await expectTransparent(
        (c) => SingleChildScrollView(
          child: c(const Column(children: [Text('a'), Text('b')])),
        ),
      );
    });
  });

  group('folds through a component', () {
    test('a Center folds into the capped Column a component builds', () async {
      await expectTransparent(
        (c) => Container(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: c(
              const ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 640),
                child: Column(children: [Text('a'), Text('b')]),
              ),
            ),
          ),
        ),
      );
    });

    test('a Center in a Column folds into a Row a component builds', () async {
      await expectTransparent(
        (c) => Column(
          children: [
            Center(
              child: c(
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Text('a'), Text('b')],
                ),
              ),
            ),
          ],
        ),
      );
    });

    test('a button takes the icon + label Row a component builds', () async {
      await expectTransparent(
        (c) => FilledButton(
          onPressed: null,
          child: c(
            const Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [Text('a'), Text('b')],
            ),
          ),
        ),
      );
    });

    test('a button Row keeps a Spacer a component builds', () async {
      await expectTransparent(
        (c) => FilledButton(
          onPressed: null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [const Text('a'), c(const Spacer()), const Text('b')],
          ),
        ),
      );
    });
  });

  group('a wrapper around a component decorates its element', () {
    test('Link gives it its tag', () async {
      await expectTransparent(
        (c) => Link(
          href: const RouteUrl('/a'),
          child: c(const Row(children: [Text('F'), Text('orge')])),
        ),
      );
    });

    test('Semantics gives it a landmark and a heading level', () async {
      await expectTransparent(
        (c) => Column(
          children: [
            Semantics(
              role: SemanticsRole.main,
              child: c(const Column(children: [Text('m')])),
            ),
            Semantics(headingLevel: 2, child: c(const Text('h'))),
          ],
        ),
      );
    });

    test('Expanded compiles into its single class', () async {
      await expectTransparent(
        (c) => Row(
          children: [
            Expanded(child: c(const Center(child: Text('e')))),
            const Text('x'),
          ],
        ),
      );
    });
  });

  group('text leaf merging through a component', () {
    test('a Container renders the Text a component builds', () async {
      await expectTransparent(
        (c) => Container(
          padding: const EdgeInsets.all(4),
          color: const Color(0xFF010203),
          child: c(const Text('t')),
        ),
      );
    });

    test('in a Padding, a SizedBox, a Center and a button', () async {
      await expectTransparent(
        (c) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(2),
              child: c(const Text('p')),
            ),
            SizedBox(width: 90, child: c(const Text('s'))),
            Center(child: c(const Text('c'))),
            FilledButton(onPressed: () {}, child: c(const Text('go'))),
          ],
        ),
      );
    });
  });

  group('parent data through a component', () {
    test('an Expanded a component builds takes the free space', () async {
      await expectTransparent(
        (c) => Row(
          children: [
            c(const Expanded(child: Text('grow'))),
            const Text('x'),
          ],
        ),
      );
    });

    test('a Flexible a component builds', () async {
      await expectTransparent(
        (c) => Column(
          children: [
            c(const Flexible(child: Text('grow'))),
            const Spacer(),
            const Text('x'),
          ],
        ),
      );
    });

    test('a Spacer a component builds folds into a margin', () async {
      await expectTransparent(
        (c) => Row(
          children: [const Text('a'), c(const Spacer()), const Text('b')],
        ),
      );
    });

    test('a spacing SizedBox a component builds folds too', () async {
      await expectTransparent(
        (c) => Column(
          children: [
            const Text('a'),
            c(const SizedBox(height: 12)),
            const Text('b'),
          ],
        ),
      );
    });

    test('a Positioned a component builds in a Stack', () async {
      await expectTransparent(
        (c) => Center(
          child: Stack(
            children: [c(const Positioned(top: 4, left: 4, child: Text('p')))],
          ),
        ),
      );
    });
  });

  group('const components', () {
    test('the same instance in several places', () async {
      final inline = await page(
        const Center(
          child: Column(
            children: [
              Center(child: Text('c')),
              Row(
                children: [Expanded(child: Center(child: Text('c')))],
              ),
              Center(child: Text('c')),
            ],
          ),
        ),
      );
      final extracted = await page(
        const Center(
          child: Column(
            children: [
              _Centered(),
              Row(children: [Expanded(child: _Centered())]),
              _Centered(),
            ],
          ),
        ),
      );
      expect(extracted, inline);
    });
  });

  group('inside Watch states', () {
    test('each state is resolved like any child', () async {
      await expectTransparent(
        (c) => Center(
          child: Column(
            children: [
              Watch(
                flag.isOn,
                builder: (on) => on
                    ? c(const Center(child: Text('on')))
                    : c(const Row(children: [Text('off')])),
              ),
            ],
          ),
        ),
      );
    });

    test('a state wrapped in Padding merges into its element', () async {
      await expectTransparent(
        (c) => Watch(
          flag.isOn,
          builder: (on) => Padding(
            padding: const EdgeInsets.all(6),
            child: c(Column(children: [Text(on ? 'on' : 'off')])),
          ),
        ),
      );
    });
  });

  group('the build a parent sees is the one the page uses', () {
    test('a component is built once', () async {
      _Counted.builds = 0;
      await page(
        const Center(
          child: Column(
            children: [
              _Counted('a'),
              Padding(padding: EdgeInsets.all(1), child: _Counted('b')),
            ],
          ),
        ),
      );
      expect(_Counted.builds, 2);
    });

    test('built again where an inherited widget it reads differs', () async {
      final html = await page(const _Deciding(child: _ReadsScope()));
      expect(html, contains('scope 2'), reason: 'the value at its place');
      expect(html, isNot(contains('scope none')));
    });

    test('a build that walks its ancestors is built at its place', () async {
      final html = await page(
        const Center(child: Column(children: [_Walks()])),
      );
      // The preview's parent is the Column; the real one is its element.
      expect(html, contains('walked '));
      expect(html, isNot(contains('walked Column')));
    });

    test(
      'a build that throws where its parent is is built at its place',
      () async {
        final html = await page(const _Deciding(child: _NeedsScope()));
        expect(html, contains('needs 2'));
      },
    );
  });
}

/// Counts its builds.
class _Counted extends StatelessWidget {
  const _Counted(this.label);

  final String label;

  static int builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    return Center(child: Text(label));
  }
}

/// Publishes [value] below it.
class _Scope extends InheritedWidget {
  const _Scope({required this.value, required super.child});

  final int value;

  @override
  bool updateShouldNotify(_Scope oldComponent) => value != oldComponent.value;
}

/// A parent that asks its child's hint in its build, then puts an
/// inherited widget between itself and the child.
class _Deciding extends StatelessWidget {
  const _Deciding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fills = layoutFillsWidth(child);
    return Widget.fragment([
      Text('fills $fills'),
      _Scope(value: 2, child: child),
    ]);
  }
}

/// Reads [_Scope].
class _ReadsScope extends StatelessWidget {
  const _ReadsScope();

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_Scope>();
    return Center(child: Text('scope ${scope?.value ?? 'none'}'));
  }
}

/// Fails without [_Scope] above it.
class _NeedsScope extends StatelessWidget {
  const _NeedsScope();

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_Scope>()!;
    return Text('needs ${scope.value}');
  }
}

/// Reads its own element's ancestors.
class _Walks extends StatelessWidget {
  const _Walks();

  @override
  Widget build(BuildContext context) {
    String? first;
    context.visitAncestorElements((e) {
      first ??= e.widget.runtimeType.toString();
      return false;
    });
    return Text('walked $first');
  }
}

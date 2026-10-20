@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// The member list thor generates for [CardState], by hand (tests don't run
// the build).
abstract class _CardStateMembers extends ThorState {
  @override
  String get $type => 'CardState';

  @override
  List<ThorMember> get $members {
    final s = this as CardState;
    return [
      ThorMember.state('radius', s.radius),
      ThorMember.state('gap', s.gap),
      ThorMember('offsetPx', s.offsetPx, call: (_) => s.offsetPx()),
      ThorMember(
        'column',
        s.column,
        arity: 1,
        call: (a) => s.column(int.parse(a!)),
      ),
    ];
  }
}

class CardState extends _CardStateMembers {
  final radius = state(20.0);
  final gap = state(8);

  double offsetPx() => 12.5;
  double column(int i) => 100.0 + i;
}

final card = CardState();

void main() {
  initializeThorTests();

  group('BoundLength', () {
    test(
      'a field is a variable the element reads, with its first value',
      () async {
        final html = await renderDocument(
          ThorApp(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circularLength(card.radius.px),
              ),
              child: const Text('x'),
            ),
          ),
        );
        expect(
          html,
          contains('data-tcv="--tb-CardState-radius:CardState.radius"'),
        );
        expect(html, contains('style="--tb-CardState-radius:20px"'));
        expect(html, contains('border-radius: var(--tb-CardState-radius)'));
      },
    );

    test(
      'goes wherever a Length does, and arithmetic keeps the binding',
      () async {
        final html = await renderDocument(
          ThorApp(
            child: Padding(
              padding: EdgeInsetsGeometry.symmetricLength(
                horizontal: card.gap.px * 2,
                vertical: card.offsetPx.px,
              ),
              child: const Text(
                'x',
                style: TextStyle(fontSizeLength: Length.px(14)),
              ),
            ),
          ),
        );
        expect(html, contains('--tb-CardState-gap:CardState.gap'));
        expect(html, contains('--tb-CardState-offsetPx:CardState.offsetPx'));
        expect(html, contains('--tb-CardState-gap:8px'));
        expect(html, contains('--tb-CardState-offsetPx:12.5px'));
      },
    );

    test('withArg names the binding with its argument', () async {
      final html = await renderDocument(
        ThorApp(child: SizedBox(widthLength: card.column.withArg(2).px)),
      );
      expect(html, contains('--tb-CardState-column_7e_2:CardState.column~2'));
      expect(html, contains('--tb-CardState-column_7e_2:102px'));
      expect(html, contains('width: var(--tb-CardState-column_7e_2)'));
    });

    test(
      'a Stack child positioned by bound values needs no variables by name',
      () async {
        final html = await renderDocument(
          ThorApp(
            child: Stack(
              children: [
                Positioned(
                  leftLength: card.gap.px,
                  topLength: card.offsetPx.px,
                  child: const Text('pin'),
                ),
              ],
            ),
          ),
        );
        expect(html, contains('position: absolute'));
        expect(html, contains('left: var(--tb-CardState-gap)'));
        expect(html, contains('top: var(--tb-CardState-offsetPx)'));
        expect(html, contains('data-tcv='));
      },
    );

    test('the class is the same whatever the value is', () async {
      Future<String> render() => renderDocument(
        ThorApp(
          child: Container(
            padding: EdgeInsetsGeometry.allLength(card.gap.px),
            child: const Text('x'),
          ),
        ),
      );
      final before = await render();
      card.gap.value = 30;
      final after = await render();
      card.gap.value = 8;
      expect(after, contains('--tb-CardState-gap:30px'));
      expect(after, isNot(contains('--tb-CardState-gap:8px')));
      String classOf(String html) =>
          RegExp(r'class="(t\w+)"[^>]*data-tcv').firstMatch(html)![1]!;
      expect(classOf(after), classOf(before));
    });

    test('works without ThorApp, inline', () async {
      final html = await renderHtml(
        Container(
          padding: EdgeInsetsGeometry.allLength(card.gap.px),
          child: const Text('x'),
        ),
      );
      expect(html, contains('padding: var(--tb-CardState-gap)'));
      expect(html, contains('--tb-CardState-gap: 8px'));
    });

    test('a closure is not a binding', () {
      expect(() => BoundLength(() => 1), throwsArgumentError);
    });

    test('WatchVariables and Length.variable keep working by name', () async {
      final html = await renderHtml(
        WatchVariables(
          {const CssVariable('--card-radius'): card.offsetPx},
          child: const DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circularLength(
                Length.variable(CssVariable('--card-radius')),
              ),
            ),
          ),
        ),
      );
      expect(html, contains('data-tcv="--card-radius:CardState.offsetPx"'));
      expect(html, contains('--card-radius: 12.5px'));
    });
  });
}

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// The member list thor generates for [LayoutState], by hand.
abstract class _LayoutStateMembers extends ThorState {
  @override
  String get $type => 'LayoutState';

  @override
  List<ThorMember> get $members {
    final s = this as LayoutState;
    return [
      ThorMember.state('row', s.row),
      ThorMember(
        'isRow',
        s.isRow,
        call: (_) => s.isRow(),
        variants: const [false, true],
      ),
      ThorMember('label', s.label, call: (_) => s.label()),
    ];
  }
}

class LayoutState extends _LayoutStateMembers {
  final row = state(true);
  bool isRow() => row.value;
  String label() => row.value ? 'fila' : 'columna';
}

final layout = LayoutState();

Future<String> _page(Widget child) => renderDocument(ThorApp(child: child));

/// Row in one state, column in the other: two structures, so the other
/// state ships as a template.
Widget _items({List<String> labels = const ['a', 'b']}) => Watch(
  layout.isRow,
  builder: (row) => Flex(
    direction: row ? Axis.horizontal : Axis.vertical,
    children: [
      for (final l in labels) Hero(tag: 'item-$l', child: Text(l)),
      if (!row) const Text('extra'),
    ],
  ),
);

Matcher _r019() => throwsA(
  isA<StateError>().having((e) => e.message, 'message', contains('THOR-R019')),
);

void main() {
  setUpAll(initializeThorTests);

  group('AnimatedSwitcher', () {
    test(
      'marks the Watch element and its other states with the timing',
      () async {
        final html = await _page(
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeInOut,
            child: _items(),
          ),
        );
        final timing =
            '300ms|${Curves.easeInOut.css}|300ms|${Curves.linear.css}';
        final live = RegExp(
          r'<div[^>]*data-tv="LayoutState\.isRow"[^>]*>',
        ).firstMatch(html)![0]!;
        expect(live, contains('data-t-vt="$timing"'));
        // The template's element too: after a swap it is the live one.
        final template = RegExp(
          r'<template data-tvt="LayoutState\.isRow" data-i="0"><div[^>]*>',
        ).firstMatch(html)![0]!;
        expect(template, contains('data-t-vt="$timing"'));
        // The page's rules, only for that timing, only while one runs.
        expect(
          html,
          contains(
            ':root[data-t-vt="$timing"]::view-transition-group(*),'
            ':root[data-t-vt="$timing"]::view-transition-new(*)'
            '{animation-duration:300ms;'
            'animation-timing-function:${Curves.easeInOut.css}}',
          ),
        );
        expect(
          html,
          contains(':root[data-t-vt]::view-transition{pointer-events:none}'),
        );
        // The rest of the page keeps out of it: a layout's own name (its
        // page transition) would animate the whole page.
        expect(
          html,
          contains(
            ':root[data-t-vt] :not([data-t-vt]:not(:root),'
            '[data-t-vt]:not(:root) *){view-transition-name:none}',
          ),
        );
      },
    );

    test('reverseDuration and switchOutCurve time the old state', () async {
      final html = await _page(
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          reverseDuration: const Duration(milliseconds: 100),
          switchOutCurve: Curves.easeIn,
          child: _items(),
        ),
      );
      expect(
        html,
        contains(
          '::view-transition-old(*){animation-duration:100ms;'
          'animation-timing-function:${Curves.easeIn.css}}',
        ),
      );
    });

    test('no switcher, no rules', () async {
      final html = await _page(_items());
      expect(html, isNot(contains('data-t-vt')));
      expect(html, isNot(contains('::view-transition')));
    });

    test('around something that is not a Watch it changes nothing', () async {
      final html = await _page(
        const AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          child: Text('x'),
        ),
      );
      // The mark is inert without states; the page has no rules for it.
      expect(html, isNot(contains('::view-transition')));
      expect(html, contains('>x</'));
    });
  });

  test(
    'a Watch around the switcher swaps its element: the mark is there',
    () async {
      final html = await _page(
        Watch(
          layout.isRow,
          builder: (row) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(row ? 'a' : 'b'),
          ),
        ),
      );
      // One element carries the Watch's id, the timing and the other state's
      // patch, so the engine animates the swap.
      expect(
        RegExp(
          r'<span[^>]*data-tv="LayoutState.isRow"[^>]*data-t-vt="300ms',
        ).hasMatch(html),
        isTrue,
      );
      expect(html, contains('data-tp-0='));
      expect(html, contains(':root[data-t-vt="300ms|linear|300ms|linear"]'));
    },
  );

  test(
    'a switcher deeper in a Watch builder is inert (the lint says so)',
    () async {
      final html = await _page(
        Watch(
          layout.isRow,
          builder: (row) => Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(row ? 'a' : 'b'),
              ),
            ],
          ),
        ),
      );
      // Only the swapped element's mark ships the timing rules.
      expect(html, isNot(contains(':root[data-t-vt')));
    },
  );

  group('Hero inside the states of a Watch', () {
    test('one tag in every state is one element per state', () async {
      final html = await _page(_items());
      // The live state and the template both carry the names.
      expect(
        'view-transition-name:t-hero-item-a'.allMatches(html),
        hasLength(2),
      );
    });

    test('the same tag twice in one state is still THOR-R019', () async {
      await expectLater(_page(_items(labels: const ['a', 'a'])), _r019());
    });

    test('a tag in the states and outside the Watch is THOR-R019', () async {
      await expectLater(
        _page(
          Column(
            children: [
              _items(),
              const Hero(tag: 'item-a', child: Text('fuera')),
            ],
          ),
        ),
        _r019(),
      );
      await expectLater(
        _page(
          Column(
            children: [
              const Hero(tag: 'item-b', child: Text('fuera')),
              _items(),
            ],
          ),
        ),
        _r019(),
      );
    });
  });
}

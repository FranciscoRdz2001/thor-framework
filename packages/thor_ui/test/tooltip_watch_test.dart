@TestOn('vm')
library;

// A `Tooltip` at the root of a `Watch` state: the state mark is on the
// tooltip's box (the other state is its sibling), not on the button inside.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

abstract class _Members extends ThorState {
  @override
  String get $type => 'TipState';

  @override
  List<ThorMember> get $members {
    final s = this as TipState;
    return [
      ThorMember(
        'shown',
        s.shown,
        call: (_) => s.shown(),
        variants: const [false, true],
      ),
      ThorMember('phase', s.phase, call: (_) => s.phase()),
    ];
  }
}

class TipState extends _Members {
  bool shown() => true;
  int phase() => 0;
}

final tips = TipState();

void main() {
  setUpAll(initializeThorTests);

  Future<String> page(Widget child) => renderDocument(ThorApp(child: child));

  String body(String html) =>
      html.substring(html.indexOf('<body'), html.indexOf('</body>'));

  test(
    'a Tooltip at the root of a state carries the mark on its box',
    () async {
      final html = body(
        await page(
          Watch(
            tips.shown,
            builder: (on) => on
                ? const Tooltip(
                    message: 'Open',
                    child: TextButton(child: Text('b')),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      );
      // The mark is on the states box (`display: contents`), not on the button.
      final mark = RegExp(
        r'<(\w+)[^>]*data-tv="TipState.shown"',
      ).firstMatch(html)!;
      expect(mark[1], 'div');
      expect(html, isNot(contains('<button data-tv')));
      expect(
        html,
        matches(RegExp(r'data-tv="TipState.shown"[^>]*>(?!<template)')),
      );
      // The other state is the box's sibling, not the tooltip's.
      final box = html.indexOf('data-tv="TipState.shown"');
      expect(html.indexOf('<template', box), greaterThan(box));
      expect(
        html.indexOf('</span>', box),
        lessThan(html.indexOf('<template', box)),
      );
      expect(html, contains('role="tooltip"'));
    },
  );
}

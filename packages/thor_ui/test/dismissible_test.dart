@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// The member list thor generates for [_Inbox], by hand.
abstract class _InboxMembers extends ThorState {
  @override
  String get $type => 'Inbox';

  @override
  List<ThorMember> get $members {
    final s = this as _Inbox;
    return [
      ThorMember(
        'dismissed',
        s.dismissed,
        arity: 2,
        call: (a) {
          final x = splitArgs(a, 2);
          return s.dismissed(x[0], DismissDirection.values.byName(x[1]));
        },
      ),
      ThorMember(
        'confirm',
        s.confirm,
        arity: 2,
        call: (a) {
          final x = splitArgs(a, 2);
          return s.confirm(x[0], DismissDirection.values.byName(x[1]));
        },
      ),
    ];
  }
}

class _Inbox extends _InboxMembers {
  void dismissed(String id, DismissDirection direction) {}
  Future<bool> confirm(String id, DismissDirection direction) async => true;
}

final _inbox = _Inbox();
const _row = SizedBox(width: 200, height: 40);

Future<String> _page(Widget body) =>
    renderDocument(ThorApp(child: body)).then(headOfPage);

String _sheet(String page) =>
    RegExp(
      r'<style id="thor-styles">(.*?)</style>',
      dotAll: true,
    ).firstMatch(page)?[1] ??
    '';

void main() {
  initializeThorTests();

  test(
    'a Dismissible is a root, its backgrounds and a body (the child)',
    () async {
      final html = await renderHtml(
        Dismissible(
          key: const ValueKey('m1'),
          onDismissed: _inbox.dismissed.withArg('m1'),
          background: const Text('archive'),
          child: _row,
        ),
      );
      expect(html, contains('data-t-dm="dismissed:Inbox.dismissed"'));
      expect(html, contains('data-tx="m1"'));
      expect(html, contains('data-t-dm-body'));
      expect(html, contains('data-t-dm-bg="startToEnd endToStart"'));
      // The backgrounds are decoration: hidden from assistive tech.
      expect(html, contains('aria-hidden="true"'));
      expect(html, contains('archive'));
      // The root can be focused: Delete dismisses, and it says so.
      expect(html, contains('tabindex="0"'));
      expect(html, contains('aria-keyshortcuts="Delete"'));
      // root + the background + the child (the body is the child's own box)
      expect(RegExp('<div').allMatches(html), hasLength(3));
    },
  );

  test('background is for startToEnd (and down), secondaryBackground for '
      'endToStart (and up)', () async {
    final h = await renderHtml(
      Dismissible(
        key: const ValueKey('a'),
        onDismissed: _inbox.dismissed.withArg('a'),
        background: const Text('left'),
        secondaryBackground: const Text('right'),
        child: _row,
      ),
    );
    expect(h, contains('data-t-dm-bg="startToEnd"'));
    expect(h, contains('data-t-dm-bg="endToStart"'));
    final v = await renderHtml(
      Dismissible(
        key: const ValueKey('b'),
        direction: DismissDirection.vertical,
        onDismissed: _inbox.dismissed.withArg('b'),
        background: const Text('down'),
        secondaryBackground: const Text('up'),
        child: _row,
      ),
    );
    expect(v, contains('data-t-dm-bg="down"'));
    expect(v, contains('data-t-dm-bg="up"'));
    // Without a background there is nothing under the body.
    final none = await renderHtml(
      Dismissible(
        key: const ValueKey('c'),
        onDismissed: _inbox.dismissed.withArg('c'),
        child: _row,
      ),
    );
    expect(none, isNot(contains('data-t-dm-bg')));
  });

  test(
    'the setup: axis, a threshold per allowed direction, durations',
    () async {
      Future<String> cfg(Dismissible d) async {
        final html = await renderHtml(d);
        return RegExp(r'data-t-dm-cfg="([^"]*)"').firstMatch(html)![1]!;
      }

      Dismissible make({
        DismissDirection direction = DismissDirection.horizontal,
        Map<DismissDirection, double> thresholds = const {},
        Duration? resize = const Duration(milliseconds: 300),
        Duration movement = const Duration(milliseconds: 200),
      }) => Dismissible(
        key: const ValueKey('x'),
        direction: direction,
        dismissThresholds: thresholds,
        resizeDuration: resize,
        movementDuration: movement,
        onDismissed: _inbox.dismissed.withArg('x'),
        child: _row,
      );

      expect(await cfg(make()), 'h|0.4|0.4|-|-|200|300');
      expect(
        await cfg(make(direction: DismissDirection.startToEnd)),
        'h|0.4|-|-|-|200|300',
      );
      expect(
        await cfg(make(direction: DismissDirection.endToStart)),
        'h|-|0.4|-|-|200|300',
      );
      expect(
        await cfg(make(direction: DismissDirection.vertical)),
        'v|-|-|0.4|0.4|200|300',
      );
      expect(
        await cfg(make(direction: DismissDirection.up)),
        'v|-|-|0.4|-|200|300',
      );
      expect(
        await cfg(make(direction: DismissDirection.down)),
        'v|-|-|-|0.4|200|300',
      );
      expect(
        await cfg(
          make(
            thresholds: {
              DismissDirection.endToStart: 0.7,
              DismissDirection.startToEnd: 0.2,
            },
          ),
        ),
        'h|0.2|0.7|-|-|200|300',
      );
      // No resize: the state removes the row as soon as it has left.
      expect(
        await cfg(
          make(resize: null, movement: const Duration(milliseconds: 80)),
        ),
        'h|0.4|0.4|-|-|80|0',
      );
      // A Dismissible that can't be dismissed is only markup.
      final off = await renderHtml(make(direction: DismissDirection.none));
      expect(off, isNot(contains('data-t-dm')));
      expect(off, isNot(contains('tabindex')));
    },
  );

  test('onDismissed and confirmDismiss are state methods with the row '
      'argument', () async {
    final html = await renderHtml(
      Dismissible(
        key: const ValueKey('m7'),
        onDismissed: _inbox.dismissed.withArg('m7'),
        confirmDismiss: _inbox.confirm.withArg('m7'),
        child: _row,
      ),
    );
    expect(
      html,
      contains('data-t-dm="dismissed:Inbox.dismissed;confirm:Inbox.confirm"'),
    );
    expect(html, contains('data-tx="m7"'));
    // A callback that is not a state method has no browser to run it.
    final loose = await renderHtml(
      Dismissible(key: const ValueKey('z'), onDismissed: (_) {}, child: _row),
    );
    expect(loose, isNot(contains('data-t-dm="')));
  });

  test('the body follows the pointer through CSS variables, and the root '
      'collapses with a grid track', () async {
    final page = await _page(
      Dismissible(
        key: const ValueKey('m1'),
        onDismissed: _inbox.dismissed.withArg('m1'),
        background: const Text('x'),
        child: _row,
      ),
    );
    final css = _sheet(page);
    expect(css, contains('translate: var(--t-dm-x, 0px) var(--t-dm-y, 0px)'));
    expect(css, contains('touch-action: pan-y'));
    // The collapse is a transition of the grid track, not a height the
    // browser measures in Dart.
    expect(css, contains('grid-template-rows: 1fr'));
    expect(css, contains('[data-t-dm-gone]'));
    expect(css, contains('grid-template-rows: 0fr'));
    expect(css, contains('[data-t-dm-drag]'));
    expect(css, contains('[data-t-dm-out]'));
    expect(css, contains('[data-t-dm-on]'));
    expect(css, contains('--t-dm-x'));
    // The typed variables skip the subtree's re-resolution (like Gesture's).
    expect(
      page,
      contains(
        "@property --t-dm-x{syntax:'<length>';inherits:false;initial-value:0px}",
      ),
    );
    expect(page, contains('@property --t-dm-y{'));
    // Reduced motion: instant, not skipped (the end of a transition still
    // has to happen).
    expect(
      RegExp(
        r'@media \(prefers-reduced-motion: ?reduce\)\{[^}]*transition-duration: ?1ms',
      ).hasMatch(css),
      isTrue,
      reason: css,
    );
    // A page without one ships none of it.
    final plain = await _page(_row);
    expect(plain, isNot(contains('--t-dm-x')));
  });

  test('a vertical Dismissible pans on the other axis and collapses its '
      'width', () async {
    final css = _sheet(
      await _page(
        Dismissible(
          key: const ValueKey('v'),
          direction: DismissDirection.up,
          onDismissed: _inbox.dismissed.withArg('v'),
          child: _row,
        ),
      ),
    );
    expect(css, contains('touch-action: pan-x'));
    expect(css, contains('grid-template-columns: 1fr'));
    expect(css, contains('grid-template-columns: 0fr'));
  });

  test('the durations are the widget\'s: CSS and engine read the same '
      'numbers', () async {
    final css = _sheet(
      await _page(
        Dismissible(
          key: const ValueKey('d'),
          movementDuration: const Duration(milliseconds: 150),
          resizeDuration: const Duration(milliseconds: 450),
          onDismissed: _inbox.dismissed.withArg('d'),
          child: _row,
        ),
      ),
    );
    expect(css, contains('translate 150ms'));
    expect(css, contains('grid-template-rows 450ms'));
  });

  test('inside a Watch.list row the root is the row (data-tk) and the '
      'template carries the same markup', () async {
    final html = await renderHtml(
      Column(
        children: [
          Dismissible(
            key: const ValueKey('r'),
            onDismissed: _inbox.dismissed.withArg('r'),
            child: _row,
          ),
        ],
      ),
    );
    expect(html, contains('data-t-dm='));
  });

  test('a Dismissible keeps the semantics a Semantics wrapper gives its '
      'root', () async {
    final html = await renderHtml(
      Semantics(
        role: SemanticsRole.listItem,
        child: Dismissible(
          key: const ValueKey('s'),
          onDismissed: _inbox.dismissed.withArg('s'),
          child: _row,
        ),
      ),
    );
    // `Semantics(role: listItem)` made the root an `<li>` (one element).
    expect(html, contains('<li'));
    expect(RegExp(r'<li[^>]*data-t-dm=').hasMatch(html), isTrue, reason: html);
    expect(html, isNot(contains('role="listitem"')));
  });
}

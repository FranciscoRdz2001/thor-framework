@TestOn('vm')
library;

// The ids of the tooltips (and of any id the page derives) are the same in
// every state of a `Watch`, so a patch between states leaves them alone.
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

  test('tooltip ids are the same in every state of a Watch', () async {
    final html = body(
      await page(
        Column(
          children: [
            Watch(
              tips.phase,
              count: 3,
              builder: (i) => Tooltip(
                message: 'Tip $i',
                child: TextButton(child: Text('b$i')),
              ),
            ),
            const Tooltip(
              message: 'After',
              child: TextButton(child: Text('c')),
            ),
          ],
        ),
      ),
    );
    final ids = RegExp(
      r'aria-describedby="([^"]+)"',
    ).allMatches(html).map((m) => m[1]!).toList();
    // Three states, the same id in each; the tooltip after the Watch has
    // its own.
    final inWatch = ids.take(ids.length - 1).toSet();
    expect(inWatch, hasLength(1), reason: '$ids');
    expect(ids.last, isNot(inWatch.single));
    // The patches between the states change texts, never an id.
    for (final patch in RegExp(r'data-tp-\d="([^"]*)"').allMatches(html)) {
      expect(patch[1], isNot(contains('|id|')));
      expect(patch[1], isNot(contains('aria-describedby')));
    }
  });
}

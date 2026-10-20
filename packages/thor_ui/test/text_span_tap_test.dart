// TextSpan.onTap is wired to the engine like Gesture's tap.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// The member list thor generates for [_Terms], by hand.
abstract class _TermsMembers extends ThorState {
  @override
  String get $type => 'Terms';

  @override
  List<ThorMember> get $members {
    final s = this as _Terms;
    return [ThorMember('open', s.open, call: (_) => s.open())];
  }
}

class _Terms extends _TermsMembers {
  void open() {}
}

final _terms = _Terms();

void main() {
  initializeThorTests();

  test(
    'TextSpan(onTap:) carries the click marker and button semantics',
    () async {
      final html = await renderHtml(
        Text.rich(
          TextSpan(
            text: 'See ',
            children: [TextSpan(text: 'Terms', onTap: _terms.open)],
          ),
        ),
      );
      expect(html, contains('data-t-on="click:Terms.open"'));
      expect(html, contains('role="button"'));
      expect(html, contains('tabindex="0"'));
    },
  );

  test('a span without onTap stays a plain span', () async {
    final html = await renderHtml(
      const Text.rich(
        TextSpan(
          children: [TextSpan(text: 'Terms', style: TextStyle(fontSize: 12))],
        ),
      ),
    );
    expect(html, isNot(contains('role="button"')));
    expect(html, isNot(contains('data-t-on')));
  });
}

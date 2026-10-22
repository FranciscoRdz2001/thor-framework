@TestOn('vm')
library;

// A `Watch` state that draws nothing takes no `gap` slot in its parent.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

abstract class _Members extends ThorState {
  @override
  String get $type => 'EmptyStates';

  @override
  List<ThorMember> get $members {
    final s = this as EmptyStates;
    return [
      ThorMember.state('on', s.on, variants: const [false, true]),
    ];
  }
}

class EmptyStates extends _Members {
  final on = state(false);
}

final states = EmptyStates();

void main() {
  initializeThorTests();

  test('an empty state is a marked box with no layout box', () async {
    final html = await renderDocument(
      ThorApp(
        child: Column(
          spacing: 12,
          children: [
            const Text('field'),
            Watch.field(
              states.on,
              builder: (on) =>
                  on ? const Text('error') : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
    final head = html.substring(0, html.indexOf('</head>'));
    // The empty state's element is `display: contents`, no 0 x 0 box.
    expect(head, contains('display: contents'));
    expect(head, isNot(matches(RegExp(r'[{; ]width: 0(px)?[;}]'))));
    expect(html, contains('data-tv="EmptyStates.on"'));
    expect(html, contains('error'));
  });

  test('outside a Watch, SizedBox.shrink() stays a 0 x 0 box', () async {
    final html = await renderDocument(
      const ThorApp(
        child: Column(spacing: 12, children: [Text('a'), SizedBox.shrink()]),
      ),
    );
    final head = html.substring(0, html.indexOf('</head>'));
    expect(head, matches(RegExp(r'[{; ]width: 0(px)?[;}]')));
    expect(head, isNot(contains('display: contents')));
  });
}

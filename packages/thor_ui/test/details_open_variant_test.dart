@TestOn('vm')
library;

// `.when(open:)` styles what is inside an open `<details>`.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

String _head(String html) => html.substring(0, html.indexOf('</head>'));

void main() {
  setUpAll(initializeThorTests);

  test('.when(open:) is a rule scoped to the nearest open details', () async {
    final head = _head(
      await renderDocument(
        ThorApp(
          child: ExpansionTile(
            title: const Text('Layout'),
            trailing: Styled(
              style: const StyleProps().when(
                open: const StyleProps(opacity: 0.5),
              ),
              child: const Text('12'),
            ),
            children: const [Text('Row')],
          ),
        ),
      ),
    );
    expect(head, contains('@scope (details[open]) to (:scope details){'));
    expect(
      RegExp(
        r'@scope \(details\[open\]\) to \(:scope details\)\{\.[\w-]+\{opacity: 0.5\}',
      ).hasMatch(head),
      isTrue,
      reason: head,
    );
  });

  test('a color takes an open variant too', () async {
    final head = _head(
      await renderDocument(
        ThorApp(
          child: Container(
            color: const Color(0xFF000000).when(open: const Color(0xFF2255FF)),
            child: const Text('x'),
          ),
        ),
      ),
    );
    expect(head, contains('@scope (details[open])'));
    expect(head.toLowerCase(), contains('#2255ff'));
  });

  test('a text style takes an open variant', () async {
    final head = _head(
      await renderDocument(
        const ThorApp(
          child: Text('12', style: TextStyle(color: Color(0xFF888888))),
        ),
      ),
    );
    expect(head, isNot(contains('@scope')));
    final open = _head(
      await renderDocument(
        ThorApp(
          child: Text(
            '12',
            style: const TextStyle(
              color: Color(0xFF888888),
            ).when(open: const TextStyle(color: Color(0xFF2255FF))),
          ),
        ),
      ),
    );
    expect(open, contains('@scope (details[open])'));
  });
}

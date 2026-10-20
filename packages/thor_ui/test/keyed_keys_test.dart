@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart' show decodeOn, parseBindingId;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class RowState extends ThorState {
  RowState({super.key});
  final label = state('x');
  final on = state(false);
  void inc(String a) {}
  void flip(bool v) {}
  bool isOn() => on.value;
}

// Keys with every character a protocol separator could take for its own: the
// rendered ids carry them escaped, so the handler of a row state is the one
// of ITS instance (and `;` does not cut `data-t-on`).
String _unhtml(String v) => v
    .replaceAll('&quot;', '"')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');

void main() {
  initializeThorTests();
  setUpAll(
    () => ThorState.register({
      RowState: ThorStateType('RowState', (state) {
        final s = state as RowState;
        return [
          ThorMember.state('label', s.label),
          ThorMember('inc', s.inc, arity: 1, call: (a) => s.inc(a!)),
        ];
      }),
    }),
  );

  final keys = [
    'a;b',
    'a:b',
    'a~b',
    '100%',
    'a%7Eb',
    'x%253B',
    'a#b.c',
    'a b',
    'é😀',
    '"q"<>&',
    'a|b',
    '{{key}}',
    '%',
    '~',
    ';',
    '.',
    'a.b.c',
    '#',
    'k' * 600,
  ];

  for (final k in keys) {
    test(
      'a key of ${k.length > 20 ? 'length ${k.length}' : '`$k`'} keeps its id',
      () async {
        final s = RowState(key: k);
        final html = await renderHtml(
          Column(
            children: [
              Watch(s.label),
              TextButton(
                onPressed: s.inc.withArg('z'),
                child: const Text('go'),
              ),
            ],
          ),
        );
        final on = _unhtml(RegExp('data-t-on="([^"]*)"').firstMatch(html)![1]!);
        final handler = decodeOn(on);
        expect(handler.keys, ['click']);
        expect(handler['click'], '${s.idPrefix}.inc');
        expect(parseBindingId(handler['click']!).$1, '${s.idPrefix}.inc');
        expect(s.idPrefix.substring('RowState#'.length), isNot(contains(';')));
        expect(s.idPrefix.substring('RowState#'.length), isNot(contains('~')));
        expect(
          html,
          contains(
            'data-tt="${s.idPrefix.replaceAll('&', '&amp;').replaceAll('"', '&quot;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')}.label"',
          ),
        );
      },
    );
  }
}

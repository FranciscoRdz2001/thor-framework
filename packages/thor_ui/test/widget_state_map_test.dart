@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  setUpAll(initializeThorTests);

  group('WidgetStateProperty.fromMap', () {
    test('the first entry whose constraint holds wins', () {
      const p = WidgetStateProperty<int>.fromMap({
        WidgetState.disabled: 1,
        WidgetState.hovered: 2,
        WidgetState.any: 3,
      });
      expect(p.resolve({WidgetState.hovered}), 2);
      expect(p.resolve({WidgetState.hovered, WidgetState.disabled}), 1);
      expect(p.resolve({}), 3);
      expect(p.resolve({WidgetState.focused}), 3);
    });

    test('combines constraints with &, | and ~', () {
      final p = WidgetStateProperty<String>.fromMap({
        WidgetState.hovered & ~WidgetState.disabled: 'hot',
        WidgetState.pressed | WidgetState.focused: 'active',
        WidgetState.any: 'idle',
      });
      expect(p.resolve({WidgetState.hovered}), 'hot');
      expect(p.resolve({WidgetState.hovered, WidgetState.disabled}), 'idle');
      expect(p.resolve({WidgetState.focused}), 'active');
      expect(p.resolve({}), 'idle');
    });

    test('no match: null for a nullable value, an error otherwise', () {
      const maybe = WidgetStateProperty<int?>.fromMap({WidgetState.hovered: 1});
      expect(maybe.resolve({}), isNull);
      const sure = WidgetStateProperty<int>.fromMap({WidgetState.hovered: 1});
      expect(() => sure.resolve({}), throwsArgumentError);
    });

    test('is equal when the map is', () {
      const a = WidgetStateProperty<int>.fromMap({WidgetState.any: 1});
      const b = WidgetStateProperty<int>.fromMap({WidgetState.any: 1});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a button style takes it, one rule per state', () async {
      const hover = Color(0xff00aa00);
      const rest = Color(0xff112233);
      final html = await renderDocument(
        ThorApp(
          child: FilledButton(
            onPressed: () {},
            style: const ButtonStyle(
              backgroundColor: WidgetStateProperty.fromMap({
                WidgetState.hovered: hover,
                WidgetState.any: rest,
              }),
            ),
            child: const Text('x'),
          ),
        ),
      );
      expect(html, contains('background-color: #00aa00'));
      expect(html, contains('background-color: #112233'));
    });
  });
}

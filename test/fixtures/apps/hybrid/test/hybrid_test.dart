@TestOn('vm')
library;

import 'package:hybrid/app.dart';
import 'package:hybrid/hybrid_state.dart';
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  initializeThorTests();

  test(
    'the page: two Flutter views with their placeholders, one loader',
    () async {
      final page = await renderDocument(const ThorApp(child: HybridPage()));
      expect('data-thor-flutter="/flutter/"'.allMatches(page), hasLength(2));
      expect(page, contains('Ventas por mes: ene 12'));
      expect(page, contains('Contador: 3'));
      expect('w.thorFlutter='.allMatches(page), hasLength(1));
      expect(page, contains('thor-flutter-message:HybridState.onBar'));
      expect(page, contains('thor-flutter-message:HybridState.onCount'));
    },
  );

  group('messages from Flutter', () {
    tearDown(() {
      hybrid.onBar('');
      hybrid.onCount('');
    });

    test('a bar tap and a count are shown', () {
      hybrid.onBar('{"bar":"abr","value":24}');
      hybrid.onCount('{"count":4}');
      expect(hybrid.barLabel(), 'Tocaste abr: 24 ventas.');
      expect(hybrid.countLabel(), 'El contador de Flutter va en 4.');
    });

    for (final bad in ['', 'no json', '[1]', '{"bar":1}', '{"count":"x"}']) {
      test('"$bad" leaves the default text', () {
        hybrid.onBar(bad);
        hybrid.onCount(bad);
        expect(hybrid.barLabel(), 'Toca una barra de la gráfica.');
        expect(hybrid.countLabel(), 'El contador de Flutter aún no cambia.');
      });
    }
  });
}

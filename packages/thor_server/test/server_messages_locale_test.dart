import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

void main() {
  test('defaults are English, Spanish by request locale, fr falls back', () {
    const m = ServerMessages();
    expect(m.network, 'Network error');
    expect(m.forLocale(const Locale('es')).network, 'Error de red');
    expect(m.forLocale(const Locale('es', 'MX')).cancel, 'Cancelar');
    expect(m.forLocale(const Locale('fr')).ok, 'OK');
    expect(m.forLocale(null).forStatus(500), 'Error 500');
  });

  test('what the app sets wins in every language', () {
    const m = ServerMessages(generic: 'Oops');
    expect(m.forLocale(const Locale('es')).generic, 'Oops');
    expect(
      m.forLocale(const Locale('es')).timeout,
      'El servidor tardó demasiado en responder',
    );
    expect(m.forLocale(const Locale('es')).toPage()['generic'], 'Oops');
  });
}

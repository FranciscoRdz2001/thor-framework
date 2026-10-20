@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/intl.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  test('numbers and money follow the locale', () {
    final es = LocaleFormat(const Locale('es'));
    final en = LocaleFormat(const Locale('en', 'US'));
    expect(es.decimal(1234.5), '1.234,5');
    expect(en.decimal(1234.5), '1,234.5');
    expect(en.decimal(2, decimalDigits: 2), '2.00');
    expect(es.currency(1234.5, name: 'EUR'), contains('1.234,50'));
    expect(es.currency(1234.5, name: 'EUR'), contains('€'));
    expect(en.currency(3, symbol: r'$', decimalDigits: 0), r'$3');
    expect(en.percent(0.25), '25%');
    expect(en.compact(1200000), '1.2M');
  });

  test('dates use the locale data without any setup', () {
    final d = DateTime(2026, 9, 25, 15, 5);
    expect(LocaleFormat(const Locale('en')).date(d), 'Sep 25, 2026');
    expect(LocaleFormat(const Locale('es')).date(d), '25 sept 2026');
    expect(LocaleFormat(const Locale('es')).time(d), '15:05');
  });

  test('a locale intl lacks falls back to its language, then English', () {
    expect(LocaleFormat(const Locale('es', 'ZZ')).localeName, 'es');
    expect(LocaleFormat(const Locale('xx')).localeName, 'en');
    expect(LocaleFormat(const Locale('pt', 'BR')).localeName, 'pt_BR');
  });
}

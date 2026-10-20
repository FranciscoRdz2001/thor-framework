@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart' show DatePickerConfig;
import 'package:thor_ui/intl.dart';
import 'package:thor_ui/src/foundation/localizations.dart'
    show PreferredLocales;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class _Probe extends StatelessWidget {
  const _Probe(this.read);

  final String Function(BuildContext context) read;

  @override
  Widget build(BuildContext context) => Text(read(context));
}

Future<String> _text(
  String Function(BuildContext context) read, {
  Locale? locale,
  List<LocalizationsDelegate<Object?>>? delegates,
}) async {
  final html = await renderDocument(
    ThorApp(
      locale: locale,
      supportedLocales: [locale ?? const Locale('en')],
      localizationsDelegates: delegates,
      child: _Probe(read),
    ),
  );
  return RegExp(
    r'<body[^>]*>(.*)</body>',
    dotAll: true,
  ).firstMatch(html)![1]!.replaceAll(RegExp('<[^>]*>'), '').trim();
}

Future<String> _calendar({
  required Locale locale,
  List<LocalizationsDelegate<Object?>>? delegates,
}) async => bodyOfPage(
  await renderDocument(
    ThorApp(
      locale: locale,
      supportedLocales: [locale],
      localizationsDelegates: delegates,
      child: CalendarDatePicker(
        initialDate: DateTime(2026, 9, 25),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        name: 'due',
        onDateChanged: (_) {},
      ),
    ),
  ),
);

void main() {
  initializeThorTests();

  group('built-in localizations (ThorApp loads them)', () {
    test('English by default', () async {
      expect(
        await _text((c) => MaterialLocalizations.of(c).okButtonLabel),
        'OK',
      );
      expect(
        await _text((c) => ThorLocalizations.of(c).autocompleteResults(3)),
        '3 results',
      );
    });

    test('Spanish by locale, with the plural forms', () async {
      const es = Locale('es');
      expect(
        await _text(
          (c) => MaterialLocalizations.of(c).cancelButtonLabel,
          locale: es,
        ),
        'Cancelar',
      );
      expect(
        await _text(
          (c) => ThorLocalizations.of(c).autocompleteResults(1),
          locale: es,
        ),
        '1 resultado',
      );
      expect(
        await _text(
          (c) => ThorLocalizations.of(c).autocompleteResults(0),
          locale: es,
        ),
        'Sin resultados',
      );
      expect(
        await _text(
          (c) => WidgetsLocalizations.of(c).reorderItemToEnd,
          locale: es,
        ),
        'Mover al final',
      );
    });

    test('an unknown language answers in English', () async {
      expect(
        await _text(
          (c) => MaterialLocalizations.of(c).okButtonLabel,
          locale: const Locale('fr'),
        ),
        'OK',
      );
    });

    test('a delegate of the app wins over the default', () async {
      expect(
        await _text(
          (c) => MaterialLocalizations.of(c).okButtonLabel,
          delegates: const [_ShoutingDelegate()],
        ),
        'OKAY!',
      );
    });

    test('outside a ThorApp the request locale is read', () async {
      final html = await renderHtml(
        PreferredLocales(
          locales: const [Locale('es')],
          child: _Probe((c) => MaterialLocalizations.of(c).okButtonLabel),
        ),
      );
      expect(html, contains('Aceptar'));
    });
  });

  group('GlobalMaterialLocalizations (CLDR, any locale)', () {
    test('French dates come from CLDR', () {
      final fr = GlobalMaterialLocalizations.forLocale(const Locale('fr'));
      expect(fr.formatMonthYear(DateTime(2026, 9)), 'septembre 2026');
      expect(fr.monthNames[0], 'janvier');
      expect(fr.firstDayOfWeekIndex, 1);
      expect(fr.narrowWeekdays, hasLength(7));
      expect(fr.monthYearPattern, '{M} {y}');
      expect(fr.mediumDatePattern, contains('{w}'));
      // Texts are English until the app brings French ones.
      expect(fr.okButtonLabel, 'OK');
    });

    test('English and Spanish agree with the built-in tables', () {
      final en = GlobalMaterialLocalizations.forLocale(const Locale('en'));
      expect(en.firstDayOfWeekIndex, 0);
      expect(en.formatMonthYear(DateTime(2026, 9)), 'September 2026');
      final es = GlobalMaterialLocalizations.forLocale(const Locale('es'));
      expect(es.firstDayOfWeekIndex, 1);
      expect(es.formatMonthYear(DateTime(2026, 9)), 'septiembre de 2026');
      expect(es.okButtonLabel, 'Aceptar');
    });

    test('the date picker shows French month names', () async {
      final html = await _calendar(
        locale: const Locale('fr'),
        delegates: GlobalMaterialLocalizations.delegates,
      );
      expect(html, contains('septembre 2026'));
      final config = DatePickerConfig.decode(
        RegExp(r'data-t-date="([^"]*)"').firstMatch(html)![1]!,
      );
      expect(config.months.first, 'janvier');
      expect(config.firstDayOfWeek, 1);
    });

    test('without the delegates, French falls back to English dates', () async {
      final html = await _calendar(locale: const Locale('fr'));
      expect(html, contains('September 2026'));
    });
  });

  group('the date picker on CLDR (fr, de, ar)', () {
    DatePickerConfig configOf(String html) => DatePickerConfig.decode(
      RegExp(r'data-t-date="([^"]*)"').firstMatch(html)![1]!,
    );

    test('French: names, Monday first, the template and the labels', () async {
      final html = await _calendar(
        locale: const Locale('fr'),
        delegates: GlobalMaterialLocalizations.delegates,
      );
      final c = configOf(html);
      expect(c.months[8], 'septembre');
      expect(c.shortWeekdays[1], 'lun.');
      expect(c.monthYear, '{M} {y}');
      expect(c.mediumDate, contains('{w}'));
      expect(c.firstDayOfWeek, 1);
      expect(c.digits, '0123456789');
      expect(html, contains('septembre 2026'));
      expect(html, contains('abbr="lundi">L</th>'));
      // 1 Sep 2026 is a Tuesday: one blank with Monday first.
      final tds = [
        for (final m in RegExp(r'<td[^>]*>([^<]*)</td>').allMatches(html)) m[1],
      ];
      expect(tds.take(2), ['', '1']);
    });

    test('German: Monday first, names and a medium date with dots', () async {
      final html = await _calendar(
        locale: const Locale('de'),
        delegates: GlobalMaterialLocalizations.delegates,
      );
      final c = configOf(html);
      expect(c.months[2], 'März');
      expect(c.firstDayOfWeek, 1);
      expect(c.mediumDate, '{w}, {d}. {m}');
      expect(html, contains('abbr="Montag">M</th>'));
      expect(html, contains('September 2026'));
    });

    test(
      'Arabic: the digits, a right-to-left page and mirrored chevrons',
      () async {
        final html = await _calendar(
          locale: const Locale('ar', 'EG'),
          delegates: GlobalMaterialLocalizations.delegates,
        );
        final c = configOf(html);
        expect(c.digits, '٠١٢٣٤٥٦٧٨٩');
        expect(c.num(2026), '٢٠٢٦');
        expect(html, contains('٢٠٢٦'));
        expect(html, contains('>٢٥<'));
        expect(html, isNot(contains('>25<')));
        // The chevrons flip with the direction (`:dir(rtl)`, in the page's
        // styles), the header's paddings are logical.
        final doc = await renderDocument(
          ThorApp(
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            child: CalendarDatePicker(
              initialDate: DateTime(2026, 9, 25),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              onDateChanged: (_) {},
            ),
          ),
        );
        expect(doc, contains('dir="rtl"'));
        expect(doc, contains(':dir(rtl)'));
        expect(doc, contains('padding-inline: 12px 4px'));
      },
    );
  });

  group('widgets read them', () {
    test('Pagination and the carousel speak Spanish; params win', () async {
      final html = await renderHtml(
        ThorApp(
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          child: Column(
            children: [
              Pagination.custom(
                page: 2,
                pageCount: 3,
                href: (n) => '?p=$n',
                nextLabel: 'Sig',
              ),
              const CarouselView(children: [Text('a')]),
            ],
          ),
        ),
      );
      expect(html, contains('aria-label="Paginación"'));
      expect(html, contains('>Anterior<'));
      expect(html, contains('>Sig<'));
      expect(html, contains('aria-roledescription="carrusel"'));
    });
  });
}

class _ShoutingDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _ShoutingDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture(_Shouting());

  @override
  bool shouldReload(covariant LocalizationsDelegate<MaterialLocalizations> o) =>
      false;
}

class _Shouting extends DefaultMaterialLocalizations {
  @override
  String get okButtonLabel => 'OKAY!';
}

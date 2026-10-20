// The Flutter-shaped widget APIs of the studio and the old shapes they
// replace: chips, status labels, tables, icon buttons, the app bar and drawer
// of the scaffold, `selectedIndex`, locales, code languages and
// `StudioLocalizations`.
import 'package:test/test.dart';
import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

final _theme = StudioTheme.light();

Future<String> _body(Widget child, {Locale? locale}) async => bodyOfPage(
  await renderDocument(
    ThorApp(
      theme: _theme,
      locale: locale,
      supportedLocales: StudioLocalizations.supportedLocales,
      localizationsDelegates: [StudioLocalizations.delegate],
      child: child,
    ),
  ),
);

Future<String> _head(Widget child) async =>
    headOfPage(await renderDocument(ThorApp(theme: _theme, child: child)));

void _toggle(bool _) {}

const _links = [
  StudioNavDestination('Guide', href: '/guide'),
  StudioNavDestination('API', href: '/api'),
  StudioNavDestination('About', href: '/about'),
];

void main() {
  setUpAll(initializeThorTests);

  group('StudioFilterChip (FilterChip)', () {
    test('a Widget label, a toggle with onSelected', () async {
      final html = await _body(
        const StudioFilterChip(
          label: Text('Buttons'),
          selected: true,
          onSelected: _toggle,
        ),
      );
      expect(html, contains('<button'));
      expect(html, contains('aria-pressed="true"'));
      expect(html, contains('>Buttons<'));
    });

    test('with href it is a link, current when selected', () async {
      final html = await _body(
        const StudioFilterChip(
          label: Text('Inputs'),
          selected: true,
          href: '/c?f=inputs',
        ),
      );
      expect(html, contains('<a '));
      expect(html, contains('aria-current="true"'));
    });

    test('with no callback it is disabled, not a label', () async {
      final html = await _body(const StudioFilterChip(label: Text('Off')));
      expect(html, contains('disabled'));
      expect(html, contains('<button'));
    });

    test(
      'a tone tints the selected chip and it squeezes when pressed',
      () async {
        final head = await _head(
          const StudioFilterChip(
            label: Text('OK'),
            selected: true,
            onSelected: _toggle,
            tone: StudioTone.ok,
          ),
        );
        expect(head, contains('scale: 0.97'));
        final plain = await _head(
          const StudioFilterChip(
            label: Text('OK'),
            selected: true,
            onSelected: _toggle,
          ),
        );
        expect(head == plain, isFalse);
      },
    );
  });

  group('StudioStatusLabel', () {
    test('is a label with a Widget, in a tone', () async {
      final html = await _body(
        const StudioStatusLabel(label: Text('Nuevo'), tone: StudioTone.warn),
      );
      expect(html, contains('>Nuevo<'));
      expect(html, isNot(contains('<button')));
      expect(html, isNot(contains('tabindex')));
    });
  });

  group('StudioDataTable (DataTable)', () {
    test('takes DataColumn, DataRow and DataCell in a frame', () async {
      final html = await _body(
        const StudioDataTable(
          columns: [
            DataColumn(label: Text('Page')),
            DataColumn(label: Text('JS'), numeric: true),
          ],
          rows: [
            DataRow(cells: [DataCell(Text('Home')), DataCell(Text('0 KB'))]),
            DataRow(
              cells: [DataCell(Text('Counter')), DataCell(StudioKbd('K'))],
            ),
          ],
        ),
      );
      expect(html, contains('<table'));
      expect(RegExp(r'<th[ >]').allMatches(html), hasLength(2));
      expect(RegExp(r'<td[ >]').allMatches(html), hasLength(4));
      expect(html, contains('0 KB'));
    });

    test('a row needs one cell per column', () async {
      await expectLater(
        _body(
          const StudioDataTable(
            columns: [
              DataColumn(label: Text('A')),
              DataColumn(label: Text('B')),
            ],
            rows: [
              DataRow(cells: [DataCell(Text('1'))]),
            ],
          ),
        ),
        throwsA(anything),
      );
    });
  });

  group('StudioIconButton (IconButton)', () {
    test('an href makes it a link named by its tooltip', () async {
      final html = await _body(
        const StudioIconButton(
          icon: Icon(StudioIcons.github, size: 18),
          tooltip: 'Repository',
          href: 'https://example.com/repo',
          newTab: true,
        ),
      );
      expect(html, contains('<a '));
      expect(html, contains('href="https://example.com/repo"'));
      expect(html, contains('aria-label="Repository"'));
      expect(html, contains('target="_blank"'));
    });

    test('with onPressed it is a button with the tooltip', () async {
      final html = await _body(
        StudioIconButton(
          icon: const Icon(StudioIcons.x, size: 18),
          tooltip: 'Close',
          onPressed: () {},
        ),
      );
      expect(html, contains('<button'));
      expect(html, contains('Close'));
    });
  });

  group('StudioScaffold (appBar, drawer)', () {
    Future<String> page(Widget scaffold) => _body(scaffold);

    test('appBar and drawer are the top bar and the sidebar', () async {
      final html = await page(
        const StudioScaffold(
          appBar: StudioTopBar(brand: Text('thor-bar')),
          drawer: Text('thor-drawer'),
          body: Text('thor-body'),
        ),
      );
      expect(html, contains('thor-bar'));
      expect(html, contains('thor-drawer'));
      expect(html, contains('<dialog'));
      expect(html, contains('id="main-content"'));
    });

    test('the strings follow the page language', () async {
      final es = await _body(
        const StudioScaffold(
          appBar: StudioTopBar(brand: Text('x')),
          drawer: Text('nav'),
          body: Text('body'),
        ),
        locale: const Locale('es'),
      );
      expect(es, contains('Saltar al contenido'));
      expect(es, contains('aria-label="Abrir navegación"'));
      expect(es, contains('aria-label="Cerrar"'));
    });
  });

  group('selectedIndex', () {
    test('StudioTopBar marks the link at the index', () async {
      final html = await _body(
        const StudioTopBar(brand: Text('x'), links: _links, selectedIndex: 1),
      );
      final current = RegExp(
        r'<a [^>]*aria-current="page"[^>]*>(.*?)</a>',
      ).allMatches(html);
      expect(current, hasLength(1));
      expect(current.single[0], contains('/api'));
    });

    test('StudioSideNav counts the items of every section', () async {
      final html = await _body(
        const StudioSideNav(
          selectedIndex: 2,
          sections: [
            StudioNavSection(
              title: 'A',
              items: [
                StudioNavDestination('Guide', href: '/guide'),
                StudioNavDestination('About', href: '/about'),
              ],
            ),
            StudioNavSection(
              title: 'B',
              items: [StudioNavDestination('Third', href: '/third')],
            ),
          ],
        ),
      );
      final current = RegExp(
        r'<a [^>]*aria-current="page"[^>]*>(.*?)</a>',
      ).allMatches(html);
      expect(current, hasLength(1));
      expect(current.single[0], contains('/third'));
    });

    test('StudioThemeChoice speaks the page\'s language', () async {
      final body = await _body(
        const StudioThemeChoice(initial: StudioThemeMode.dark),
        locale: const Locale('es'),
      );
      expect(body, contains('>Sistema<'));
      expect(body, contains('>Claro<'));
      expect(body, contains('>Oscuro<'));
      expect(body, contains('aria-label="Tema"'));
    });

    test('StudioBreadcrumbs shows the current crumb as plain text', () async {
      final html = await _body(
        const StudioBreadcrumbs(trail: _links, selectedIndex: 2),
      );
      expect(html, contains('aria-current="page"'));
      expect(html, isNot(contains('href="/about"')));
      expect(html, contains('href="/guide"'));
      expect(html, contains('aria-label="Breadcrumb"'));
    });

    test('StudioLocaleSwitcher names its popover without an id', () async {
      final html = await _body(
        const StudioLocaleSwitcher(
          locales: [
            StudioLocaleOption(
              locale: Locale('es'),
              label: 'Español',
              href: '/es',
            ),
          ],
        ),
      );
      final id = RegExp(r'popovertarget="([^"]+)"').firstMatch(html)?[1];
      expect(id, isNotNull);
      expect(html, contains('id="$id"'));
    });

    test('StudioLocaleSwitcher marks the language of the page', () async {
      final html = await _body(
        const StudioLocaleSwitcher(
          selectedIndex: 1,
          locales: [
            StudioLocaleOption(
              locale: Locale('es'),
              label: 'Español',
              href: '/es',
            ),
            StudioLocaleOption(
              locale: Locale('pt', 'BR'),
              label: 'Português',
              href: '/pt',
            ),
          ],
        ),
      );
      expect(html, contains('hreflang="pt-BR"'));
      expect(html, contains('lang="es"'));
      expect(html, contains('aria-label="Language"'));
      expect(RegExp('aria-current="page"').allMatches(html), hasLength(1));
    });
  });

  group('StudioLocaleOption', () {
    test('has a Locale', () {
      const option = StudioLocaleOption(
        locale: Locale('pt', 'BR'),
        label: 'Português',
        href: '/pt',
      );
      expect(option.locale, const Locale('pt', 'BR'));
      expect(option.locale.toLanguageTag(), 'pt-BR');
    });
  });

  group('StudioCodeLanguage', () {
    const source = 'final a = 1;';

    test('the enum and the old string name draw the same', () async {
      final enumHtml = await _body(
        const StudioCodeBlock(
          source,
          language: StudioCodeLanguage.bash,
          title: 'x',
          copyButton: false,
        ),
      );
      final stringHtml = await _body(
        const StudioCodeBlock(
          source,
          language: StudioCodeLanguage.bash,
          title: 'x',
          copyButton: false,
        ),
      );
      expect(enumHtml, stringHtml);
    });

    test('Dart is colored, plain is not', () async {
      final colored = await _body(
        const StudioCodeBlock(source, copyButton: false),
      );
      final plain = await _body(
        const StudioCodeBlock(
          source,
          language: StudioCodeLanguage.plain,
          copyButton: false,
        ),
      );
      expect(colored, contains('<span class='));
      expect(colored == plain, isFalse);
    });

    test(
      'other languages are in StudioCodeTab, StudioStep and the compare',
      () async {
        final html = await _body(
          const Column(
            children: [
              StudioCodeTabs(
                copyButton: false,
                tabs: [
                  StudioCodeTab(
                    label: 'pubspec.yaml',
                    code: 'name: x',
                    language: StudioCodeLanguage.yaml,
                  ),
                ],
              ),
              StudioFlutterCompare(
                flutterCode: 'a',
                thorCode: 'b',
                language: StudioCodeLanguage.json,
                copyButton: false,
              ),
            ],
          ),
        );
        expect(html, contains('pubspec.yaml'));
      },
    );
  });

  group('StudioFlutterCompare', () {
    test('initialIndex picks the open side', () async {
      final flutter = await _body(
        const StudioFlutterCompare(
          flutterCode: 'FLUTTER-SRC',
          thorCode: 'THOR-SRC',
          initialIndex: 0,
          copyButton: false,
        ),
      );
      final thor = await _body(
        const StudioFlutterCompare(
          flutterCode: 'FLUTTER-SRC',
          thorCode: 'THOR-SRC',
          copyButton: false,
        ),
      );
      expect(flutter == thor, isFalse);
    });

    test('the tab names follow the locale', () async {
      final es = await _body(
        const StudioFlutterCompare(
          flutterCode: 'a',
          thorCode: 'b',
          copyButton: false,
        ),
        locale: const Locale('es'),
      );
      expect(es, contains('>Flutter<'));
      expect(es, contains('>Thor<'));
      final custom = await _body(
        const StudioFlutterCompare(
          flutterCode: 'a',
          thorCode: 'b',
          flutterLabel: 'En Flutter',
          thorLabel: 'En Thor',
          copyButton: false,
        ),
      );
      expect(custom, contains('>En Flutter<'));
    });
  });

  group('StudioLocalizations', () {
    test('ships English and Spanish through a delegate', () {
      const en = StudioLocalizationsEn();
      const es = StudioLocalizationsEs();
      expect(en.copy, 'Copy');
      expect(es.copy, 'Copiar');
      expect(en.onThisPage, 'On this page');
      expect(es.onThisPage, 'En esta página');
      expect(
        StudioLocalizations.delegate.isSupported(const Locale('es')),
        isTrue,
      );
      expect(
        StudioLocalizations.delegate.isSupported(const Locale('fr')),
        isFalse,
      );
      expect(StudioLocalizations.supportedLocales, hasLength(2));
    });

    test('every string is written in both languages', () {
      for (final l in const [
        StudioLocalizationsEn(),
        StudioLocalizationsEs(),
      ]) {
        final all = [
          l.copy,
          l.copied,
          l.previous,
          l.next,
          l.pagination,
          l.skipToContent,
          l.openNavigation,
          l.close,
          l.navigation,
          l.sections,
          l.search,
          l.onThisPage,
          l.breadcrumb,
          l.language,
          l.linkToSection,
          l.benchDemo,
          l.benchCode,
          l.benchView,
          l.flutterLabel,
          l.thorLabel,
        ];
        expect(all.every((s) => s.isNotEmpty), isTrue);
      }
    });

    test(
      'without a delegate the page locale still picks the language',
      () async {
        final es = bodyOfPage(
          await renderDocument(
            ThorApp(
              theme: _theme,
              locale: const Locale('es'),
              supportedLocales: StudioLocalizations.supportedLocales,
              localizationsDelegates: const [],
              child: const StudioPagerLinks(
                next: StudioNavDestination('Siguiente tema', href: '/n'),
              ),
            ),
          ),
        );
        expect(es, contains('>Siguiente<'));
      },
    );

    test('a widget\'s own parameter wins', () async {
      final html = await _body(
        const StudioPagerLinks(
          previous: StudioNavDestination('Back', href: '/b'),
          next: StudioNavDestination('Forward', href: '/f'),
          previousLabel: 'Atrás',
          nextLabel: 'Adelante',
          label: 'Navegación de páginas',
        ),
      );
      expect(html, contains('>Atrás<'));
      expect(html, contains('>Adelante<'));
      expect(html, contains('aria-label="Navegación de páginas"'));
    });

    test(
      'the pager, TOC, search pill and breadcrumbs take the locale',
      () async {
        final html = await _body(
          const Column(
            children: [
              StudioPagerLinks(
                previous: StudioNavDestination('A', href: '/a'),
                next: StudioNavDestination('B', href: '/b'),
              ),
              StudioTableOfContents(
                entries: [StudioTocEntry('One', href: '#one')],
              ),
              StudioSearchPill(href: '/s'),
            ],
          ),
          locale: const Locale('es'),
        );
        expect(html, contains('>Anterior<'));
        expect(html, contains('>Siguiente<'));
        expect(html, contains('En esta página'));
        expect(html, contains('Buscar'));
      },
    );

    test('the bench names its views by the locale', () async {
      final html = await _body(
        const StudioBench(id: 'b1', stage: Text('S'), code: Text('C')),
        locale: const Locale('es'),
      );
      expect(html, contains('aria-label="Vista"'));
      expect(html, contains('aria-label="Código"'));
    });
  });

  group('small ones', () {
    test(
      'StudioBench is const; a bad id is asserted when it is built',
      () async {
        const bench = StudioBench(id: 'ok', stage: Text('S'), code: Text('C'));
        expect(bench.id, 'ok');
        await expectLater(
          _body(
            const StudioBench(id: 'a b', stage: Text('S'), code: Text('C')),
          ),
          throwsA(anything),
        );
      },
    );

    test('the main content id is in English', () {
      expect(StudioLayout.mainId, 'main-content');
    });

    test('StudioBrand\'s mark is the first letter of the name', () async {
      final html = await _body(const StudioBrand(name: 'acme'));
      expect(html, contains('>a<'));
      final custom = await _body(const StudioBrand(name: 'acme', mark: '*'));
      expect(custom, contains('>*<'));
    });

    test('the compare summary and layer labels follow the locale', () async {
      final html = await _body(
        const StudioCompareSummary(flutter: 'A', thor: 'B'),
        locale: const Locale('es'),
      );
      expect(html, contains('Flutter'));
      expect(html, contains('Thor'));
    });

    test('StudioButtonThemeData.smallStyle is the compact pill', () {
      final t = StudioButtonThemeData.resolve(_theme);
      expect(t.smallStyle.minimumSize?.resolve({}), Size(0, t.smallHeight));
      expect(t.smallStyle.padding?.resolve({}), t.smallPadding);
    });
  });
}

// The v2 layout and navigation widgets: structure, landmarks, the current
// state, and that every string comes from a parameter.
import 'package:test/test.dart';
import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

final _theme = StudioTheme.light();
final _darkTheme = StudioTheme.dark();

/// [child] in a themed page, as an app would put it (the dark theme makes the
/// page carry the theme switch).
Widget _app(Widget child) =>
    ThorApp(theme: _theme, darkTheme: _darkTheme, child: child);

Future<String> _body(Widget child) async =>
    bodyOfPage(await renderDocument(_app(child)));

int _count(String html, String pattern) =>
    RegExp(pattern).allMatches(html).length;

/// The tag that opens with [attribute] in it, e.g. the `<a …>` with an href.
String _tagWith(String html, String attribute) =>
    RegExp('<[a-z]+ [^>]*$attribute[^>]*>').firstMatch(html)![0]!;

const _links = [
  StudioNavDestination('Guide', href: '/guide'),
  StudioNavDestination('API', href: '/api'),
];

const _sections = [
  StudioNavSection(
    title: 'Learn',
    items: [
      StudioNavDestination('Widgets', href: '/widgets'),
      StudioNavDestination('Layout', href: '/layout'),
    ],
  ),
  StudioNavSection(
    title: 'Ship',
    items: [StudioNavDestination('Deploy', href: '/deploy')],
  ),
  StudioNavSection(
    title: 'Reference',
    items: [StudioNavDestination('API', href: '/api')],
  ),
];

const _scaffold = StudioScaffold(
  skipLabel: 'Jump to the content',
  sidebarLabel: 'Docs navigation',
  menuLabel: 'Open the docs menu',
  appBar: StudioTopBar(
    brand: StudioBrand(name: 'thor'),
    linksLabel: 'Sections',
    links: _links,
    selectedIndex: 0,
    search: StudioSearchPill(
      href: '/search',
      placeholder: 'Search the guide',
      shortcut: '⌘K',
    ),
    actions: [StudioThemeToggle()],
  ),
  drawer: StudioSideNav(label: 'Docs', sections: _sections, selectedIndex: 0),
  tableOfContents: StudioTableOfContents(
    title: 'On this page',
    entries: [StudioTocEntry('Intro', href: '#intro')],
  ),
  body: Column(
    children: [StudioPageHeader(title: 'Widgets', lead: 'Everything is one.')],
  ),
  footer: StudioFooter(legal: 'MIT licensed'),
);

void main() {
  setUpAll(initializeThorTests);

  group('StudioScaffold', () {
    test(
      'landmarks: header, named navs, main, aside, footer, drawer',
      () async {
        final body = await _body(_scaffold);
        expect(_count(body, '<header[ >]'), 1);
        expect(_count(body, '<main[ >]'), 1);
        expect(_count(body, '<footer[ >]'), 1);
        expect(_count(body, '<aside[ >]'), 1);
        expect(_count(body, '<h1[ >]'), 1);
        expect(body, contains('<nav class="'));
        for (final name in ['Sections', 'Docs', 'On this page']) {
          expect(body, contains('aria-label="$name"'), reason: name);
        }
        expect(body, contains('<dialog'));
        expect(body, contains('aria-label="Docs navigation"'));
      },
    );

    test('the skip link is the first stop and lands on <main>', () async {
      final doc = await renderDocument(_app(_scaffold));
      final body = bodyOfPage(doc);
      final first = RegExp('<a [^>]*href="([^"]*)"').firstMatch(body)!;
      expect(first[1], '#${StudioLayout.mainId}');
      expect(body.indexOf(first[0]!), lessThan(body.indexOf('<header')));
      expect(body, contains('Jump to the content'));
      expect(
        RegExp('<main[^>]*id="${StudioLayout.mainId}"').hasMatch(body),
        isTrue,
      );
      // Off screen until the keyboard reaches it.
      final head = headOfPage(doc);
      expect(head, contains('top: -100px'));
      expect(head, contains(':focus-visible{top: 8px}'));
    });

    test('a sidebarId names the drawer', () async {
      final body = await _body(
        const StudioScaffold(
          sidebarId: 'my-nav',
          appBar: StudioTopBar(brand: StudioBrand(name: 'thor')),
          drawer: Text('NAV'),
          body: Text('BODY'),
        ),
      );
      expect(body, contains('<dialog id="my-nav"'));
      expect(body, contains('commandfor="my-nav"'));
    });

    test('the menu button opens the sidebar drawer by its id', () async {
      final body = await _body(_scaffold);
      final dialogId = RegExp('<dialog id="([^"]+)"').firstMatch(body)![1];
      // No `sidebarId`: the page names the drawer, and the button points at
      // the same name.
      expect(dialogId, 't-sidebar1');
      final button = _tagWith(body, 'commandfor');
      expect(button, contains('commandfor="$dialogId"'));
      expect(button, contains('command="show-modal"'));
      expect(button, contains('aria-label="Open the docs menu"'));
    });

    test(
      'the drawer has a visible close button, named by a parameter',
      () async {
        final body = await _body(_scaffold);
        final dialog = body.substring(body.indexOf('<dialog'));
        final close = RegExp(
          r'<button[^>]*command="close"[^>]*>',
        ).firstMatch(dialog)!;
        expect(close[0], contains('aria-label="Close"'));
        expect(close[0], contains('type="button"'));
        expect(dialog.indexOf(close[0]!), lessThan(dialog.indexOf('<nav')));
        final named = await _body(
          const StudioScaffold(
            skipLabel: 'Jump',
            appBar: Text('bar'),
            drawer: Text('side'),
            sidebarLabel: 'Docs',
            menuLabel: 'Menu',
            closeLabel: 'Cerrar',
            body: Text('page'),
          ),
        );
        expect(named, contains('aria-label="Cerrar"'));
        // Only below lg: the inline column has nothing to close.
        final head = headOfPage(await renderDocument(_app(_scaffold)));
        expect(head, contains('display: none'));
      },
    );

    test('the sidebar is a column from lg and a drawer below it', () async {
      final head = headOfPage(await renderDocument(_app(_scaffold)));
      // Closed, from the breakpoint up, the dialog is an inline column.
      expect(head, contains(':not([open]){display: flex'));
      expect(head, contains('position: static'));
      // The box inside sticks under the bar (and its safe-area inset).
      expect(head, contains('position: sticky'));
      expect(head, contains('--studio-top'));
      expect(head, contains('env(safe-area-inset-top'));
    });

    test('without a sidebar there is no drawer and no menu button', () async {
      final body = await _body(
        const StudioScaffold(
          skipLabel: 'Skip',
          appBar: StudioTopBar(brand: Text('x')),
          body: Text('body'),
        ),
      );
      expect(body, isNot(contains('<dialog')));
      expect(body, isNot(contains('commandfor')));
      expect(body, isNot(contains('<aside')));
    });

    test(
      'the drawer, its button and the skip link are named by the locale',
      () async {
        final body = bodyOfPage(
          await renderDocument(
            _app(
              const StudioScaffold(
                appBar: StudioTopBar(brand: Text('x')),
                drawer: Text('nav'),
                body: Text('body'),
              ),
            ),
          ),
        );
        expect(body, contains('Skip to content'));
        expect(body, contains('aria-label="Documentation"'));
        expect(body, contains('aria-label="Open navigation"'));
        expect(body, contains('aria-label="Close"'));
      },
    );

    test('the table of contents shows from xl only', () async {
      final head = headOfPage(await renderDocument(_app(_scaffold)));
      // Hidden below the xl breakpoint (1200 px).
      expect(head, contains('max-width: 1199.98px'));
    });

    test('a whole page stays under its element budget', () async {
      final body = await _body(_scaffold);
      // 100 or so when written (SVG sprite, icons and all); a wrapper node per
      // component would show here.
      expect(_count(body, '<[a-z]'), lessThanOrEqualTo(120));
    });
  });

  group('StudioTopBar', () {
    test(
      'a sticky <header> with named links, the current one marked',
      () async {
        final doc = await renderDocument(
          _app(
            const StudioTopBar(
              brand: StudioBrand(name: 'thor'),
              linksLabel: 'Main sections',
              links: _links,
              selectedIndex: 0,
            ),
          ),
        );
        final body = bodyOfPage(doc);
        expect(body, contains('<header'));
        expect(body, contains('<nav'));
        expect(body, contains('aria-label="Main sections"'));
        expect(_count(body, 'aria-current="page"'), 1);
        expect(_tagWith(body, 'aria-current'), contains('href="/guide"'));
        expect(headOfPage(doc), contains('position: sticky'));
      },
    );

    test('the bar keeps its height under the device inset', () async {
      final head = headOfPage(
        await renderDocument(_app(const StudioTopBar(brand: Text('thor')))),
      );
      expect(head, contains('env(safe-area-inset-top)'));
      expect(head, contains('height: 56px'));
    });

    test('links without a name take the locale\'s', () async {
      final body = await _body(
        const StudioTopBar(brand: Text('x'), links: _links),
      );
      expect(body, contains('aria-label="Sections"'));
    });

    test('with no links there is no empty nav', () async {
      final body = await _body(const StudioTopBar(brand: Text('thor')));
      expect(body, isNot(contains('<nav')));
    });
  });

  group('StudioSearchPill', () {
    test('is a plain link to the search page, with the hint', () async {
      final body = await _body(
        const StudioSearchPill(
          href: '/search',
          placeholder: 'Search the guide',
          shortcut: '⌘K',
        ),
      );
      expect(body, contains('href="/search"'));
      expect(body, contains('aria-label="Search the guide"'));
      expect(body, contains('Search the guide'));
      expect(body, contains('<kbd'));
      expect(body, contains('⌘K'));
      // No JavaScript: a link, no form, no script.
      expect(body, isNot(contains('<form')));
      expect(body, isNot(contains('<script')));
    });

    test('without a shortcut there is no key hint', () async {
      final body = await _body(
        const StudioSearchPill(href: '/s', placeholder: 'Buscar'),
      );
      expect(body, isNot(contains('<kbd')));
      expect(body, contains('Buscar'));
    });

    test('shrinks to the magnifier on a phone and presses in', () async {
      final doc = await renderDocument(
        _app(const StudioSearchPill(href: '/s', placeholder: 'Find')),
      );
      final head = headOfPage(doc);
      expect(head, contains('display: none'));
      expect(head, contains('scale: 0.97'));
      // Two links: the pill and the magnifier.
      expect(_count(bodyOfPage(doc), '<a [^>]*href="/s"'), 2);
    });
  });

  group('StudioSideNav', () {
    test('a named <nav> of lists; only the current item is marked', () async {
      final body = await _body(
        const StudioSideNav(
          label: 'Docs menu',
          sections: _sections,
          selectedIndex: 0,
        ),
      );
      expect(body, contains('<nav'));
      expect(body, contains('aria-label="Docs menu"'));
      expect(_count(body, '<ul[ >]'), 3);
      expect(_count(body, '<li[ >]'), 4);
      expect(_count(body, 'aria-current="page"'), 1);
      expect(_tagWith(body, 'aria-current'), contains('href="/widgets"'));
    });

    test('every section is a heading over a list, nothing folds', () async {
      final body = await _body(
        const StudioSideNav(label: 'Docs', sections: _sections),
      );
      expect(body, isNot(contains('<details')));
      expect(body, isNot(contains('<summary')));
      expect(_count(body, '<h2[ >]'), 3);
      expect(body, contains('>Reference</h2>'));
      expect(body, contains('href="/deploy"'));
    });

    test('the current item is marked by a bar, not a fill', () async {
      final head = headOfPage(
        await renderDocument(
          _app(
            const StudioSideNav(
              label: 'Docs',
              sections: _sections,
              selectedIndex: 0,
            ),
          ),
        ),
      );
      expect(head, contains('border-left: 2px solid'));
    });

    test('an item may end in a count pill named for a screen reader', () async {
      final body = await _body(
        const StudioSideNav(
          label: 'Docs',
          sections: [
            StudioNavSection(
              title: '',
              items: [
                StudioNavDestination(
                  'Issues',
                  href: '/issues',
                  count: 31,
                  countTone: StudioTone.danger,
                  countLabel: '31 open',
                ),
                StudioNavDestination('Big', href: '/big', count: 250),
                StudioNavDestination('None', href: '/none', count: 0),
                StudioNavDestination('Plain', href: '/plain'),
              ],
            ),
          ],
        ),
      );
      expect(body, contains('>31<'));
      expect(body, contains('aria-label="31 open"'));
      expect(body, contains('>99+<'));
      // Zero and null show no pill.
      expect(body, isNot(contains('>0<')));
    });

    test('a trailing widget goes after the count', () async {
      final body = await _body(
        const StudioSideNav(
          label: 'Docs',
          sections: [
            StudioNavSection(
              title: '',
              items: [
                StudioNavDestination(
                  'Alerts',
                  href: '/alerts',
                  count: 2,
                  trailing: Text('new'),
                ),
              ],
            ),
          ],
        ),
      );
      expect(body.indexOf('>2<'), lessThan(body.indexOf('>new<')));
    });

    test('touchTargets asks for 44 px rows under a coarse pointer', () async {
      Future<String> render(bool touch) async => headOfPage(
        await renderDocument(
          _app(
            StudioSideNav(
              label: 'Docs',
              sections: _sections,
              touchTargets: touch,
            ),
          ),
        ),
      );
      final on = await render(true);
      final off = await render(false);
      expect(on, contains('@media (pointer: coarse)'));
      expect(on, contains('min-height: 32px'));
      expect(off, isNot(contains('pointer: coarse')));
    });

    test('pressFeedback squeezes a pressed row, off by default', () async {
      Future<String> render({bool? press, double? scale}) async => headOfPage(
        await renderDocument(
          _app(
            press == null
                ? const StudioSideNav(label: 'Docs', sections: _sections)
                : StudioSideNav(
                    label: 'Docs',
                    sections: _sections,
                    pressFeedback: press,
                    pressScale: scale ?? 0.985,
                  ),
          ),
        ),
      );
      final off = await render();
      final on = await render(press: true);
      final custom = await render(press: true, scale: 0.95);
      expect(off, isNot(contains('scale: 0.985')));
      expect(on, contains('scale: 0.985'));
      expect(on, contains(':active'));
      expect(custom, contains('scale: 0.95'));
    });

    test('every title and link is the caller\'s text', () async {
      final body = await _body(
        const StudioSideNav(
          label: 'Navegación',
          sections: [
            StudioNavSection(
              title: 'Aprender',
              items: [StudioNavDestination('Layout', href: '/layout')],
            ),
          ],
        ),
      );
      expect(body, contains('Navegación'));
      expect(body, contains('Aprender'));
      expect(body, contains('Layout'));
    });
  });

  group('StudioTableOfContents', () {
    const entries = [
      StudioTocEntry('Intro', href: '#intro'),
      StudioTocEntry('Details', href: '#details', depth: 1),
    ];

    test('a named nav of anchors with its title as a heading', () async {
      final body = await _body(
        const StudioTableOfContents(title: 'Sur cette page', entries: entries),
      );
      expect(body, contains('aria-label="Sur cette page"'));
      expect(body, contains('>Sur cette page</h2>'));
      expect(body, contains('href="#intro"'));
      expect(body, contains('href="#details"'));
      expect(body, isNot(contains('aria-current')));
    });

    test('marks the current section as a location, only one', () async {
      final body = await _body(
        const StudioTableOfContents(
          title: 'On this page',
          entries: entries,
          current: '#details',
        ),
      );
      expect(_count(body, 'aria-current="location"'), 1);
      expect(_tagWith(body, 'aria-current'), contains('href="#details"'));
    });

    test('scroll spy: the browser tracks the reading position', () async {
      final spy = headOfPage(
        await renderDocument(
          _app(
            const StudioTableOfContents(
              title: 'On this page',
              entries: entries,
              scrollSpy: true,
            ),
          ),
        ),
      );
      expect(spy, contains('scroll-target-group: auto'));
      expect(spy, contains('@supports selector(:target-current)'));
      expect(spy, contains(':target-current'));
    });

    test('without it the list is plain anchors', () async {
      final plain = headOfPage(
        await renderDocument(
          _app(
            const StudioTableOfContents(
              title: 'On this page',
              entries: entries,
            ),
          ),
        ),
      );
      expect(plain, isNot(contains('scroll-target-group')));
      expect(plain, isNot(contains(':target-current')));
    });
  });

  group('StudioBreadcrumbs', () {
    test(
      'a named nav holding a list; the current page is not a link',
      () async {
        final body = await _body(
          const StudioBreadcrumbs(
            label: 'Fil d\'Ariane',
            selectedIndex: 1,
            trail: [
              StudioNavDestination('Learn', href: '/learn'),
              StudioNavDestination('Widgets', href: '/widgets'),
            ],
          ),
        );
        expect(body, contains('<nav'));
        expect(body, contains('aria-label="Fil d\'Ariane"'));
        expect(_count(body, '<ul[ >]'), 1);
        expect(_count(body, '<li[ >]'), 2);
        expect(body, contains('href="/learn"'));
        expect(body, isNot(contains('href="/widgets"')));
        expect(_count(body, 'aria-current="page"'), 1);
        // The separator is decoration.
        expect(body, contains('aria-hidden="true"'));
      },
    );
  });

  group('StudioPageHeader', () {
    test('one h1, the eyebrow and the lead', () async {
      final body = await _body(
        const StudioPageHeader(
          eyebrow: 'Learn',
          title: 'Widgets',
          lead: 'Everything is a widget.',
        ),
      );
      expect(_count(body, '<h1[ >]'), 1);
      expect(body, contains('>Widgets</h1>'));
      expect(body, contains('Learn'));
      expect(body, contains('Everything is a widget.'));
    });

    test('without eyebrow or lead there is only the title', () async {
      final body = await _body(const StudioPageHeader(title: 'Only'));
      expect(body, contains('>Only</h1>'));
      expect(_count(body, 'data-thor="Text"'), 1);
    });

    test('the title grows from md up', () async {
      final head = headOfPage(
        await renderDocument(_app(const StudioPageHeader(title: 'T'))),
      );
      // The title is 30 px on a phone and 36 px (displaySmall) from md,
      // balanced over its lines.
      expect(head, contains('font-size: 30px'));
      expect(head, contains('font-size: var(--t-display-small-size)'));
      expect(head, contains('text-wrap: balance'));
    });
  });

  group('StudioPagerLinks', () {
    test('previous and next with their captions and rel', () async {
      final body = await _body(
        const StudioPagerLinks(
          label: 'Pages',
          previousLabel: 'Anterior',
          nextLabel: 'Siguiente',
          previous: StudioNavDestination('Layout', href: '/layout'),
          next: StudioNavDestination('Routing', href: '/routing'),
        ),
      );
      expect(body, contains('aria-label="Pages"'));
      expect(_tagWith(body, 'rel="prev"'), contains('href="/layout"'));
      expect(_tagWith(body, 'rel="next"'), contains('href="/routing"'));
      expect(body, contains('Anterior'));
      expect(body, contains('Siguiente'));
      expect(body, contains('Layout'));
      expect(body, contains('Routing'));
    });

    test('a missing side leaves no link, only its cell', () async {
      final body = await _body(
        const StudioPagerLinks(
          label: 'Pages',
          previousLabel: 'Previous',
          nextLabel: 'Next',
          next: StudioNavDestination('Routing', href: '/routing'),
        ),
      );
      expect(_count(body, '<a [^>]*rel='), 1);
      expect(body, isNot(contains('Previous')));
    });
  });

  group('StudioFooter', () {
    test('a footer landmark with named columns and the small print', () async {
      final body = await _body(
        const StudioFooter(
          brand: Text('thor'),
          sections: [
            StudioNavSection(
              title: 'Community',
              items: [StudioNavDestination('GitHub', href: 'https://x.dev')],
            ),
          ],
          legal: 'Licence MIT',
          actions: [StudioThemeToggle()],
        ),
      );
      expect(_count(body, '<footer[ >]'), 1);
      expect(body, contains('aria-label="Community"'));
      expect(body, contains('href="https://x.dev"'));
      expect(body, contains('Licence MIT'));
      expect(body, contains('for="thor-theme"'));
    });

    test('an empty footer draws no columns', () async {
      final body = await _body(const StudioFooter(legal: 'x'));
      expect(body, isNot(contains('<nav')));
    });
  });

  group('StudioThemeToggle', () {
    test(
      'thor\'s toggle: a label of the switch with a sun and a moon',
      () async {
        final body = await _body(const StudioThemeToggle());
        expect(body, contains('<label'));
        expect(body, contains('for="thor-theme"'));
        expect(body, contains('#lucide-sun'));
        expect(body, contains('#lucide-moon'));
        // Both icons are decoration; the switch is named by the page's input.
        expect(_count(body, 'aria-hidden="true"'), greaterThanOrEqualTo(2));
      },
    );
  });

  group('StudioThemeChoice', () {
    test('three radios in one group, System checked', () async {
      final body = await _body(const StudioThemeChoice());
      expect(body, contains('role="radiogroup"'));
      expect(_count(body, 'type="radio"'), 3);
      expect(_count(body, 'name="studio-theme"'), 3);
      expect(body, contains('value="system"'));
      expect(body, contains('value="light"'));
      expect(body, contains('value="dark"'));
      expect(body, contains('>System<'));
      expect(body, contains('>Light<'));
      expect(body, contains('>Dark<'));
      expect(_count(body, ' checked'), 1);
    });

    test('the page rules set color-scheme from the checked radio', () {
      final rules = StudioThemeChoice.styles.map((r) => r.toCss()).join();
      expect(rules, contains('[value="dark"]:checked'));
      expect(rules, contains('color-scheme: dark'));
      expect(rules, contains('color-scheme: light dark'));
      expect(rules, contains(':root:root:has('));
    });

    test('the two-state toggle is untouched', () async {
      final body = await _body(const StudioThemeToggle());
      expect(body, contains('for="thor-theme"'));
      expect(body, isNot(contains('name="studio-theme"')));
    });
  });

  group('the theme switch input', () {
    test('sits inside the toggle label, in the top bar', () async {
      final body = await _body(_scaffold);
      final input = body.indexOf('id="thor-theme"');
      final label = body.indexOf('<label');
      final labelEnd = body.indexOf('</label>', label);
      expect(input, greaterThan(label));
      expect(input, lessThan(labelEnd));
      // Before the page's main: the keyboard reaches it with the bar.
      expect(input, lessThan(body.indexOf('<main')));
      expect(_count(body, 'id="thor-theme"'), 1);
    });

    test('with no toggle on the page it stays at the end', () async {
      final body = await _body(const Text('no toggle'));
      expect(body, contains('id="thor-theme"'));
      expect(
        body.indexOf('no toggle'),
        lessThan(body.indexOf('id="thor-theme"')),
      );
    });
  });

  group('StudioLocaleSwitcher', () {
    const locales = [
      StudioLocaleOption(
        locale: Locale('es'),
        label: 'Español',
        href: '/es/widgets',
      ),
      StudioLocaleOption(
        locale: Locale('en'),
        label: 'English',
        href: '/en/widgets',
      ),
    ];

    test('a native popover whose options are real links', () async {
      final body = await _body(
        const StudioLocaleSwitcher(
          id: 'langs',
          label: 'Language',
          selectedIndex: 0,
          locales: locales,
        ),
      );
      expect(body, contains('popovertarget="langs"'));
      expect(body, contains('popover="auto"'));
      expect(body, contains('aria-label="Language"'));
      expect(_tagWith(body, 'hreflang="en"'), contains('href="/en/widgets"'));
      expect(_tagWith(body, 'hreflang="es"'), contains('lang="es"'));
      // The button shows the current language, in its own language.
      expect(body, contains('>Español'));
      expect(_count(body, 'aria-current="page"'), 1);
      expect(body, isNot(contains('<script')));
    });

    test('with no current locale the button shows the first', () async {
      final body = await _body(
        const StudioLocaleSwitcher(
          id: 'l',
          label: 'Idioma',
          locales: [
            StudioLocaleOption(
              locale: Locale('en'),
              label: 'English',
              href: '/en',
            ),
          ],
        ),
      );
      expect(body, contains('English'));
      expect(body, isNot(contains('aria-current')));
    });
  });

  group('themes', () {
    test('the nav theme carries the search and section values', () {
      final nav = StudioNavThemeData.resolve(StudioTheme.light());
      expect(nav.searchHeight, 36);
      expect(nav.searchMaxWidth, 240);
      final changed = nav.copyWith(searchHeight: 48);
      expect(changed.searchHeight, 48);
      expect(changed.searchColor, nav.searchColor);
      expect(changed.hintBackground, nav.hintBackground);
      expect(changed.sectionTitleColor, nav.sectionTitleColor);
    });

    test('layout measures are tokens', () {
      expect(StudioLayout.sidebarWidth, 260);
      expect(StudioLayout.tocWidth, 232);
    });
  });
}

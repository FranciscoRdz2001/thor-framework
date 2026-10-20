// Recipe: sidebar + drawer. From `lg` (992 px) the navigation is a fixed
// sidebar; below, a menu button opens the same links in a Drawer
// (a native <dialog>: Esc, backdrop and focus without JavaScript).
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../l10n/app_localizations.thor.dart';
import '../router.dart';
import '../ui/tokens.dart';

/// The layout of `/` and the pages below it.
class RootLayout extends ThorLayout<void> {
  /// The one instance the build shares between requests.
  const RootLayout();

  /// Every page's title ends in "· Recetas" (· Recipes in English).
  @override
  PageMeta meta(PageState<void> state) {
    final t = lookupAppLocalizations(
      state.request.locale ?? const Locale('es'),
    );
    return PageMeta(title: t.homeTitle, titleTemplate: '%s · ${t.recipes}');
  }

  /// The shell: sidebar (wide) or top bar + drawer (narrow), then the page.
  @override
  Widget build(BuildContext context, PageState<void> state, Widget child) {
    final path = state.request.uri.path;
    // At least the window's height: the sidebar reaches the bottom.
    return Styled(
      style: StyleProps(minHeight: 100.dvh),
      child: Container(
        color: canvas,
        child: Row(
          // Stretch: the sidebar runs to the bottom of the window.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResponsiveVisibility(
              visibleFrom: WindowSizeClass.expanded,
              child: Container(
                width: 240,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFFFF),
                  border: Border(right: BorderSide(color: line)),
                ),
                child: _Nav(path: path),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ResponsiveVisibility(
                    hiddenFrom: WindowSizeClass.expanded,
                    child: _TopBar(path: path),
                  ),
                  Semantics(
                    role: SemanticsRole.main,
                    child: Padding(
                      padding: const EdgeInsets.all(
                        16,
                      ).when(medium: const EdgeInsets.all(32)),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _noop() {}

class _TopBar extends StatelessWidget implements ThorElementWidget {
  const _TopBar({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: const BoxDecoration(
      color: Color(0xFFFFFFFF),
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      spacing: 8,
      children: [
        DialogTrigger(
          id: 'menu',
          // A button without onPressed is disabled: give it one.
          child: OutlinedButton(
            onPressed: _noop,
            child: Text(AppLocalizations.of(context).menu),
          ),
        ),
        Text(
          AppLocalizations.of(context).recipes,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Drawer(
          id: 'menu',
          label: AppLocalizations.of(context).navigation,
          child: _Nav(path: path),
        ),
      ],
    ),
  );
}

class _Nav extends StatelessWidget implements ThorElementWidget {
  const _Nav({required this.path});

  final String path;

  /// The recipes, in the page's language (`/en/...` in English). Their
  /// names stay in Spanish: only the home page and the shell translate.
  static List<(String, String)> _links(BuildContext context) {
    final request = RequestScope.maybeOf(context);
    String localized(String path) => request?.localizedPath(path) ?? path;
    return [
      (AppLocalizations.of(context).homeMeta, localized(homeRoute.link())),
      ('Tarjeta', localized(cardRoute.link())),
      ('Lista con filtros', localized(listRoute.link())),
      ('Tabla con orden', localized(tableRoute.link())),
      ('Formulario', localized(formRoute.link())),
      ('Diálogo', localized(dialogRoute.link())),
      ('Panel', localized(panelRoute.link())),
      ('Contador (estado)', localized(counterRoute.link())),
      ('Mi cuenta', localized(accountRoute.link())),
    ];
  }

  @override
  Widget build(BuildContext context) => Semantics(
    role: SemanticsRole.navigation,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 2,
      children: [
        for (final (label, href) in _links(context))
          Link(
            href: RouteUrl(href),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: href == path ? const Color(0xFFEEF2FF) : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: href == path ? accent : ink,
                  fontWeight: href == path ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
          child: LocaleSwitcher(
            semanticsLabel: AppLocalizations.of(context).language,
          ),
        ),
      ],
    ),
  );
}

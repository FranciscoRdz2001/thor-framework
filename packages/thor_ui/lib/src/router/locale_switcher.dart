import 'package:thor_server/thor_server.dart';
import 'package:thor_style/thor_style.dart';

import '../../router.dart' show RequestScope;
import '../core/core.dart';
import '../foundation/child_rules.dart' show ThorElementWidget;
import '../foundation/element.dart';
import '../foundation/material_localizations.dart' show ThorLocalizations;
import '../foundation/style_registry.dart';
import '../widgets/basic.dart' show SizedBox;
import '../widgets/text.dart';

// web: not in Flutter.
/// Links to the page in every language of the app
/// (`RouteHandler(locales:)`), a `<nav>` of `<a hreflang lang>`.
///
/// Each link carries `?set-locale=<tag>`: the server remembers the choice
/// in the locale cookie and redirects (`303`) to the page in that language
/// — with a prefix, so `/` stops sending a Spanish visitor who picked
/// English back to `/es`. Works without JS. The current language is
/// `aria-current="true"`.
///
/// ```dart
/// LocaleSwitcher(
///   labels: {
///     const Locale('es'): 'Español',
///     const Locale('en'): 'English',
///   },
/// )
/// ```
///
/// Outside a routed page with locales it draws nothing.
class LocaleSwitcher extends StatelessWidget implements ThorElementWidget {
  /// A switcher; [labels] by locale (a locale without one shows its
  /// language's own name when thor knows it, else its tag).
  const LocaleSwitcher({
    super.key,
    this.labels = const {},
    this.semanticsLabel,
    this.spacing = 12,
    this.style,
    this.selectedStyle,
  });

  /// Locale → the text of its link.
  final Map<Locale, String> labels;

  /// The `<nav>`'s accessible name.
  final String? semanticsLabel;

  /// Space between links (px).
  final double spacing;

  /// Text style of every link.
  final TextStyle? style;

  /// Text style of the current language's link (bold by default).
  final TextStyle? selectedStyle;

  @override
  Widget build(BuildContext context) {
    final request = RequestScope.maybeOf(context);
    final routing = request?.localeRouting;
    if (request == null || routing == null) return const SizedBox.shrink();
    return thorElement(
      'nav',
      debugName: 'LocaleSwitcher',
      attributes: {
        'aria-label':
            semanticsLabel ??
            ThorLocalizations.of(context).languageSwitcherLabel,
      },
      css: {'display': 'flex', 'flex-wrap': 'wrap', 'gap': cssPx(spacing)},
      children: [
        for (final locale in routing.supportedLocales)
          thorElement(
            'a',
            debugName: 'LocaleSwitcherLink',
            attributes: {
              'href': Uri(
                path: request.uri.path,
                queryParameters: {
                  ...request.queryParametersAll,
                  LocaleRouting.switchParameter: [locale.toLanguageTag()],
                },
              ).toString(),
              'hreflang': locale.toLanguageTag(),
              'lang': locale.toLanguageTag(),
              if (locale == request.locale) 'aria-current': 'true',
            },
            baseCss: const {'color': 'inherit'},
            conditions: const [
              ConditionalCss(CssCondition.selector('[aria-current="true"]'), {
                'font-weight': '600',
                'text-decoration': 'none',
              }),
            ],
            children: [
              Text(
                labels[locale] ?? endonym(locale),
                style: locale == request.locale
                    ? selectedStyle ?? style
                    : style,
              ),
            ],
          ),
      ],
    );
  }

  /// The name of [locale]'s language in that language (`es` → `Español`),
  /// or its tag when thor doesn't know it.
  static String endonym(Locale locale) {
    final tag = locale.toLanguageTag();
    return _endonyms[tag] ?? _endonyms[locale.languageCode] ?? tag;
  }

  static const _endonyms = {
    'ar': 'العربية',
    'ca': 'Català',
    'cs': 'Čeština',
    'da': 'Dansk',
    'de': 'Deutsch',
    'el': 'Ελληνικά',
    'en': 'English',
    'es': 'Español',
    'fa': 'فارسی',
    'fi': 'Suomi',
    'fr': 'Français',
    'he': 'עברית',
    'hi': 'हिन्दी',
    'id': 'Bahasa Indonesia',
    'it': 'Italiano',
    'ja': '日本語',
    'ko': '한국어',
    'nl': 'Nederlands',
    'no': 'Norsk',
    'pl': 'Polski',
    'pt': 'Português',
    'pt-BR': 'Português (Brasil)',
    'ro': 'Română',
    'ru': 'Русский',
    'sv': 'Svenska',
    'th': 'ไทย',
    'tr': 'Türkçe',
    'uk': 'Українська',
    'vi': 'Tiếng Việt',
    'zh': '中文',
  };
}

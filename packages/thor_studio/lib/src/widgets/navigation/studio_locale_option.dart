import 'package:thor_ui/thor_ui.dart';

/// A language a `StudioLocaleSwitcher` offers: the page's address in that
/// language.
///
/// ```dart
/// const StudioLocaleOption(
///   locale: Locale('es'),
///   label: 'Español',
///   href: '/es/widgets',
/// )
/// ```
class StudioLocaleOption {
  /// A language [label]led in its own language, at [href].
  const StudioLocaleOption({
    required this.locale,
    required this.label,
    required this.href,
  });

  /// The language (`Locale('es')`, `Locale('pt', 'BR')`); its
  /// `toLanguageTag()` is written as `hreflang` and `lang`.
  final Locale locale;

  /// The language's name, in that language (`Español`).
  final String label;

  /// The same page in that language.
  final String href;
}

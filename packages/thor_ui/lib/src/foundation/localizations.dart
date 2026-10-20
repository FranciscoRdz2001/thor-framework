/// Flutter's localization model: `Locale`, `LocalizationsDelegate`,
/// `Localizations` and the locale resolution of `WidgetsApp`.
library;

import 'dart:async';

import 'package:thor_server/locale.dart' show Locale;

import '../core/core.dart';
import 'errors.dart';

// The page's one language type lives in thor_server (it routes by it).
export 'package:thor_server/locale.dart' show Locale;

/// Flutter's `SynchronousFuture`: a future whose value is already there.
/// Generated delegates return one, so a page renders in one pass.
class SynchronousFuture<T> implements Future<T> {
  /// A future completed with [_value].
  SynchronousFuture(this._value);

  final T _value;

  @override
  Stream<T> asStream() => Stream<T>.value(_value);

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) =>
      Completer<T>().future;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) {
    final result = onValue(_value);
    if (result is Future<R>) return result;
    return SynchronousFuture<R>(result);
  }

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      Future<T>.value(_value).timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) {
    try {
      final result = action();
      if (result is Future) return result.then<T>((_) => _value);
      return this;
    } catch (e, stack) {
      return Future<T>.error(e, stack);
    }
  }
}

/// Flutter's `LocalizationsDelegate`: loads the resources of type [T] (an
/// `AppLocalizations`) for a locale. `thor_builder` generates one per app
/// from its ARB files.
abstract class LocalizationsDelegate<T> {
  /// A delegate.
  const LocalizationsDelegate();

  /// Whether [locale] has resources.
  bool isSupported(Locale locale);

  /// The resources for [locale]. `// web:` a page renders in one
  /// synchronous pass: return a [SynchronousFuture] (another future is an
  /// error when the page reads the resources).
  Future<T> load(Locale locale);

  /// Whether resources must load again for a new delegate (Flutter API; a
  /// page never reloads on the server).
  bool shouldReload(covariant LocalizationsDelegate<T> old);

  /// The type [Localizations.of] finds the resources by.
  Type get type => T;
}

/// Flutter's `Localizations`: the page's [locale] and the resources its
/// [delegates] load for it, for the widgets below.
///
/// ```dart
/// final t = AppLocalizations.of(context);   // Localizations.of<AppLocalizations>
/// Text(t.cartItems(3));
/// Localizations.localeOf(context).toLanguageTag();   // 'es'
/// ```
///
/// `ThorApp` puts one above the app; use it directly to switch a subtree to
/// another language.
class Localizations extends InheritedWidget implements InheritedMemoKey {
  /// Publishes [locale] and [delegates] to [child].
  Localizations({
    super.key,
    required this.locale,
    required this.delegates,
    required super.child,
  });

  /// The locale of the widgets below.
  final Locale locale;

  /// Loaders of the resources ([of]).
  final List<LocalizationsDelegate<Object?>> delegates;

  // Loaded once per type, on the first read of the page.
  final Map<Type, Object?> _resources = {};

  /// The locale of the nearest [Localizations].
  static Locale localeOf(BuildContext context) {
    final locale = maybeLocaleOf(context);
    if (locale == null) {
      throw StateError(
        thorError(
          'THOR-R006',
          'Localizations.localeOf: no Localizations above this widget '
              '(ThorApp puts one)',
        ),
      );
    }
    return locale;
  }

  /// The locale of the nearest [Localizations], or `null`.
  static Locale? maybeLocaleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Localizations>()?.locale;

  /// The resources of [type] for the nearest [Localizations]' locale, or
  /// `null` when no delegate of that type supports it.
  static T? of<T>(BuildContext context, Type type) {
    final scope = context.dependOnInheritedWidgetOfExactType<Localizations>();
    return scope?._load(type) as T?;
  }

  Object? _load(Type type) {
    if (_resources.containsKey(type)) return _resources[type];
    Object? value;
    for (final delegate in delegates) {
      if (delegate.type != type || !delegate.isSupported(locale)) continue;
      final future = delegate.load(locale);
      if (future is! SynchronousFuture<Object?>) {
        // web: no async build: the page is written in one pass.
        throw StateError(
          thorError(
            'THOR-R007',
            '${delegate.runtimeType}.load($locale) must return a '
                'SynchronousFuture: thor renders a page in one synchronous '
                'pass',
          ),
        );
      }
      value = future._value;
      break;
    }
    return _resources[type] = value;
  }

  @override
  bool updateShouldNotify(Localizations oldWidget) =>
      oldWidget.locale != locale || oldWidget.delegates != delegates;

  /// Readers see only this value.
  @override
  Object? get memoKey => (locale, delegates);
}

/// Flutter's `LocaleResolutionCallback`: the app's locale from the
/// visitor's first preferred one.
typedef LocaleResolutionCallback =
    Locale? Function(Locale? locale, Iterable<Locale> supportedLocales);

/// Flutter's `LocaleListResolutionCallback`: the app's locale from the
/// visitor's preferred ones, in order.
typedef LocaleListResolutionCallback =
    Locale? Function(List<Locale>? locales, Iterable<Locale> supportedLocales);

/// Flutter's `basicLocaleListResolution`: the supported locale that best
/// matches [preferredLocales] (same language, script and region; then
/// language and script, language and region, language, region), else the
/// first of [supportedLocales].
Locale basicLocaleListResolution(
  List<Locale>? preferredLocales,
  Iterable<Locale> supportedLocales,
) {
  if (preferredLocales == null || preferredLocales.isEmpty) {
    return supportedLocales.first;
  }
  final all = <String, Locale>{};
  final languageAndCountry = <String, Locale>{};
  final languageAndScript = <String, Locale>{};
  final language = <String, Locale>{};
  final country = <String, Locale>{};
  for (final l in supportedLocales) {
    all.putIfAbsent(
      '${l.languageCode}_${l.scriptCode}_${l.countryCode}',
      () => l,
    );
    languageAndScript.putIfAbsent('${l.languageCode}_${l.scriptCode}', () => l);
    languageAndCountry.putIfAbsent(
      '${l.languageCode}_${l.countryCode}',
      () => l,
    );
    language.putIfAbsent(l.languageCode, () => l);
    if (l.countryCode case final c?) country.putIfAbsent(c, () => l);
  }
  Locale? matchesLanguage;
  Locale? matchesCountry;
  for (var i = 0; i < preferredLocales.length; i++) {
    final user = preferredLocales[i];
    final full =
        all['${user.languageCode}_${user.scriptCode}_${user.countryCode}'];
    if (full != null) return full;
    if (user.scriptCode != null) {
      final match =
          languageAndScript['${user.languageCode}_${user.scriptCode}'];
      if (match != null) return match;
    }
    if (user.countryCode != null) {
      final match =
          languageAndCountry['${user.languageCode}_${user.countryCode}'];
      if (match != null) return match;
    }
    if (matchesLanguage != null) return matchesLanguage;
    final match = language[user.languageCode];
    if (match != null) {
      matchesLanguage = match;
      // The next preferred locale may be a better (full) match of the same
      // language: look at it before settling.
      final next = i + 1 < preferredLocales.length
          ? preferredLocales[i + 1]
          : null;
      if (i == 0 && next?.languageCode != user.languageCode) return match;
    }
    if (matchesCountry == null && user.countryCode != null) {
      matchesCountry = country[user.countryCode];
    }
  }
  return matchesLanguage ?? matchesCountry ?? supportedLocales.first;
}

/// `// web:` the visitor's preferred locales, what Flutter reads from the
/// platform: the request's locale (`RouteHandler(locales:)`) in a routed
/// app, `THOR_LOCALE` in a static pre-render. Put by thor, read by
/// `ThorApp`.
class PreferredLocales extends InheritedWidget {
  /// Publishes [locales] to [child].
  const PreferredLocales({
    super.key,
    required this.locales,
    required super.child,
  });

  /// Most preferred first.
  final List<Locale> locales;

  /// The nearest preferred locales, or `null` (none known: the app's first
  /// supported locale applies).
  static List<Locale>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreferredLocales>()?.locales;

  @override
  bool updateShouldNotify(PreferredLocales oldWidget) =>
      oldWidget.locales != locales;
}

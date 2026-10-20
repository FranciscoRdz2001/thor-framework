/// Language tags, `Accept-Language` and text direction: the pure part of
/// thor's locale routing (no `dart:io`), usable in the browser too.
library;

export 'src/locale.dart'
    show
        LocaleRouting,
        LocaleStrategy,
        Locale,
        isRtlLanguageTag,
        matchLocale,
        parseAcceptLanguage;

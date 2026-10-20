/// **Experimental.** thor with the web's names: HTML elements, CSS
/// properties and Tailwind-style utilities, next to the Flutter widgets.
///
/// ```dart
/// import 'package:thor_ui/web.dart'; // widgets and routes come along
///
/// Article(style: tw('rounded-xl border border-outline-variant p-4 md:p-6'),
///   children: [
///     H2(text: name, style: tw('text-lg font-semibold')),
///     P(text: category, style: tw('text-sm text-on-surface-variant')),
///   ])
/// ```
///
/// The rule: a Flutter name keeps Flutter's behavior (`Row`, `Expanded`);
/// a web name behaves exactly like the web (`FlexBox`, `Style(gap:)`,
/// `tw('gap-2')`). Both end the same way: one HTML element with one class,
/// resolved on the server; `tw()` never ships CSS to the browser. Mix them
/// freely: a `FilledButton` inside a `Box`, a `Box` inside a `Column`.
///
/// Not part of the stable API yet (the deprecation policy covers only the
/// other libraries): names may change before it graduates.
library;

// One import for a page: the widgets and the routes' types come along, so
// `Text`, `Widget`, `BuildContext`, `PageState` and `PageMeta` are there.
// Importing thor_ui.dart or router.dart as well is unnecessary (the analyzer
// says so): same declarations.
export 'router.dart';
export 'src/foundation/css_rules.dart' show Css, css;
export 'src/web/elements.dart';
export 'src/web/style.dart'
    show
        AlignItems,
        AlignSelf,
        ContainerType,
        Display,
        FlexDirection,
        FlexWrap,
        FontVariantNumeric,
        GridLine,
        GridTrack,
        GridTracks,
        JustifyContent,
        LineHeight,
        LineStyle,
        ListStyleType,
        ObjectFit,
        PointerEvents,
        Position,
        Style,
        TextTransform,
        UserSelect,
        WhiteSpace;
export 'src/web/tw.dart' show tw;
// `Table` here is HTML's `<table>`; Flutter's is still in thor_ui.dart
// (`import 'package:thor_ui/thor_ui.dart' as flutter;` → `flutter.Table`).
export 'thor_ui.dart' hide Table;

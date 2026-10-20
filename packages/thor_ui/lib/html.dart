/// Raw HTML elements (`div`, `link`, `script`, `meta`…) for the few places a
/// page needs them directly, e.g. the document `<head>`:
///
/// ```dart
/// import 'package:thor_ui/html.dart' as html;
/// head: [html.link(rel: 'icon', href: 'data:,')]
/// ```
///
/// A curated list, not the whole DOM: the tags and types apps commonly
/// use, plus the basic text and structure tags. Widgets cover the rest; a tag
/// missing here is a widget to write, not an escape.
library;

export 'src/core/html.dart';

// The app's stylesheet rules, for files that import only this library.
export 'src/foundation/css_rules.dart'
    show Css, NestedStyleRule, StyleRule, css;
export 'src/foundation/html_attributes.dart'
    show AriaAttribute, AttributeName, BooleanAttribute, HtmlAttributes;

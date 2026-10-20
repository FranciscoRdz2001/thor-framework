/// Flutter-style value types that compile to CSS declarations.
///
/// Pure Dart: no DOM, no framework. Consumed by `thor_ui` (the widgets),
/// the thor runtime, or anything that can apply a `Map<String, String>`.
library;

export 'src/adaptive.dart';
export 'src/alignment.dart';
export 'src/color.dart';
export 'src/color_swatch.dart';
export 'src/color_token.dart';
export 'src/css.dart' hide cssPillRadius, cssRadiusPx;
export 'src/css_variable.dart';
export 'src/curves.dart';
export 'src/decoration.dart';
export 'src/edge_insets.dart';
export 'src/geometry.dart';
export 'src/icon_data.dart';
export 'src/layout_enums.dart';
export 'src/length.dart';
export 'src/matrix4.dart';
export 'src/text_style.dart';
export 'src/web_layout.dart';
export 'src/web_values.dart';

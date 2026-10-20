import 'package:thor_ui/thor_ui.dart';

import 'studio_accent_colors.dart';
import 'studio_action_colors.dart';
import 'studio_bench_colors.dart';
import 'studio_border_colors.dart';
import 'studio_content_colors.dart';
import 'studio_shadow_colors.dart';
import 'studio_status_colors.dart';
import 'studio_surface_colors.dart';
import 'studio_syntax_colors.dart';

/// Every color token of the system, in one list: what
/// `ThemeData(tokens:)` publishes as `--t-*` variables (each theme writes
/// the side of its brightness, and the page switches them with
/// `light-dark()`).
abstract final class StudioPalette {
  /// All the tokens, each name once.
  static const List<ColorToken> values = [
    ...StudioSurfaceColors.values,
    ...StudioBorderColors.values,
    ...StudioContentColors.values,
    ...StudioActionColors.values,
    ...StudioAccentColors.values,
    ...StudioStatusColors.values,
    ...StudioShadowColors.values,
    ...StudioBenchColors.values,
    ...StudioSyntaxColors.values,
  ];
}

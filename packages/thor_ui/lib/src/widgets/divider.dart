import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import 'theme.dart' show Theme;

const _defaultDividerColor = Color.variable(
  CssVariable('--t-outline-variant'),
  fallback: Color(0xFFCAC4D0),
);

/// Flutter's `Divider` → `<hr>`. Its defaults come from
/// `ThemeData.dividerTheme`.
class Divider extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a horizontal divider.
  const Divider({
    super.key,
    this.height,
    this.thickness,
    this.indent,
    this.endIndent,
    this.color,
  });

  /// Total height taken by the divider, including its surrounding space
  /// (default: the theme's `space`, else 16).
  final double? height;

  /// Thickness of the line, in logical pixels (default: the theme's, else
  /// Flutter's 1).
  final double? thickness;

  /// Empty space before the line's start (default: the theme's, else 0).
  final double? indent;

  /// Empty space after the line's end (default: the theme's, else 0).
  final double? endIndent;

  /// Line color (default: the theme's, else `--t-outline-variant`).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).dividerTheme;
    final thickness = this.thickness ?? theme?.thickness ?? 1;
    final height = this.height ?? theme?.space ?? 16;
    final space = (height - thickness).clamp(0, height) / 2;
    return thorElement(
      'hr',
      debugName: 'Divider',
      fillsWidth: true,
      css: {
        'border': '0',
        'border-top':
            '${cssPx(thickness)} solid ${(color ?? theme?.color ?? _defaultDividerColor).css}',
        // Flutter's indent is the start side and endIndent the end side:
        // they follow the text direction (`margin-inline`).
        ...EdgeInsetsDirectional.fromSTEB(
          indent ?? theme?.indent ?? 0,
          space,
          endIndent ?? theme?.endIndent ?? 0,
          space,
        ).toCss('margin'),
        'height': '0',
      },
    );
  }
}

/// Flutter's `VerticalDivider`. Its defaults come from
/// `ThemeData.dividerTheme`.
class VerticalDivider extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a vertical divider.
  const VerticalDivider({
    super.key,
    this.width,
    this.thickness,
    this.indent,
    this.endIndent,
    this.color,
  });

  /// Total width taken by the divider, including its surrounding space
  /// (default: the theme's `space`, else 16).
  final double? width;

  /// Thickness of the line, in logical pixels (default: the theme's, else
  /// Flutter's 1).
  final double? thickness;

  /// Empty space before the line's start (default: the theme's, else 0).
  final double? indent;

  /// Empty space after the line's end (default: the theme's, else 0).
  final double? endIndent;

  /// Line color (default: the theme's, else `--t-outline-variant`).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).dividerTheme;
    final thickness = this.thickness ?? theme?.thickness ?? 1;
    final width = this.width ?? theme?.space ?? 16;
    final space = (width - thickness).clamp(0, width) / 2;
    return thorElement(
      'div',
      debugName: 'VerticalDivider',
      fillsHeight: true,
      css: {
        'border-left':
            '${cssPx(thickness)} solid ${(color ?? theme?.color ?? _defaultDividerColor).css}',
        'margin': EdgeInsets.fromLTRB(
          space,
          indent ?? theme?.indent ?? 0,
          space,
          endIndent ?? theme?.endIndent ?? 0,
        ).css,
        'width': '0',
      },
      attributes: const {'role': 'separator', 'aria-orientation': 'vertical'},
    );
  }
}

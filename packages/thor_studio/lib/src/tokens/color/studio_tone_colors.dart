import 'package:thor_ui/thor_ui.dart';

import 'studio_accent_colors.dart';
import 'studio_border_colors.dart';
import 'studio_content_colors.dart';
import 'studio_status_colors.dart';
import 'studio_surface_colors.dart';

/// One state's three colors: the text or icon, the tinted background and
/// the border. Callouts and chips take one per tone.
class StudioToneColors {
  /// Creates a tone from its colors.
  const StudioToneColors({
    required this.foreground,
    required this.background,
    required this.border,
  });

  /// Text and icon.
  final Color foreground;

  /// The tinted background.
  final Color background;

  /// The border.
  final Color border;

  @override
  bool operator ==(Object other) =>
      other is StudioToneColors &&
      other.foreground == foreground &&
      other.background == background &&
      other.border == border;

  @override
  int get hashCode => Object.hash(foreground, background, border);

  /// A badge or chip with no status: the soft ink on the raised gray.
  static const neutral = StudioToneColors(
    foreground: StudioContentColors.inkSoft,
    background: StudioSurfaceColors.raised,
    border: StudioBorderColors.line,
  );

  /// Information (the accent family).
  static const info = StudioToneColors(
    foreground: StudioAccentColors.accent,
    background: StudioStatusColors.infoBg,
    border: StudioStatusColors.infoLine,
  );

  /// Success.
  static const ok = StudioToneColors(
    foreground: StudioStatusColors.ok,
    background: StudioStatusColors.okBg,
    border: StudioStatusColors.okLine,
  );

  /// Warnings.
  static const warn = StudioToneColors(
    foreground: StudioStatusColors.warn,
    background: StudioStatusColors.warnBg,
    border: StudioStatusColors.warnLine,
  );

  /// Errors.
  static const danger = StudioToneColors(
    foreground: StudioStatusColors.danger,
    background: StudioStatusColors.dangerBg,
    border: StudioStatusColors.dangerLine,
  );

  /// Notes about how Flutter does it (a teal).
  static const flutter = StudioToneColors(
    foreground: StudioStatusColors.flutter,
    background: StudioStatusColors.flutterBg,
    border: StudioStatusColors.flutterLine,
  );
}

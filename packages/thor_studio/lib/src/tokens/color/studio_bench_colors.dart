import 'package:thor_ui/thor_ui.dart';

/// The bench: a big stage for the demo and a side panel with Switches
/// (a segmented control) and Levels (a bar you drag).
abstract final class StudioBenchColors {
  /// The demo stage.
  static const stage = ColorToken(
    'stage',
    light: Color(0xFFF1F2F7),
    dark: Color(0xFF0E101A),
  );

  /// The groove a segmented control's choice slides in.
  static const segmentedTrack = ColorToken(
    'segmented-track',
    light: Color(0xFFE9EBF3),
    dark: Color(0xFF1A1D2B),
  );

  /// The chosen segment: the accent fill (its label is the accent ink).
  static const segmentedSelected = ColorToken(
    'segmented-selected',
    light: Color(0xFF4F46E5),
    dark: Color(0xFF818CF8),
  );

  /// The empty part of a level.
  static const levelTrack = ColorToken(
    'level-track',
    light: Color(0xFFE9EBF3),
    dark: Color(0xFF1A1D2B),
  );

  /// The filled part of a level, up to its value: an accent tint.
  static const levelFill = ColorToken(
    'level-fill',
    light: Color(0xFFD5D9F8),
    dark: Color(0xFF2D3266),
  );

  /// Every bench token.
  static const values = [
    stage,
    segmentedTrack,
    segmentedSelected,
    levelTrack,
    levelFill,
  ];
}

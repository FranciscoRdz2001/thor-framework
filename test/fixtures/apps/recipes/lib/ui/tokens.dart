/// The recipes' design tokens: one place for colors and sizes.
library;

import 'package:thor_ui/thor_ui.dart';

/// Ink for text.
const ink = Color(0xFF111827);

/// Secondary text.
const muted = Color(0xFF6B7280);

/// Hairlines and borders.
const line = Color(0xFFE5E7EB);

/// Page background.
const canvas = Color(0xFFF9FAFB);

/// Accent (buttons, focus).
const accent = Color(0xFF4F46E5);

/// Errors.
const danger = Color(0xFFB91C1C);

/// A white surface with a hairline and rounded corners.
const surface = BoxDecoration(
  color: Color(0xFFFFFFFF),
  border: Border.fromBorderSide(BorderSide(color: line)),
  borderRadius: BorderRadius.all(Radius.circular(12)),
);

/// Page titles.
const titleStyle = TextStyle(
  fontSize: 28,
  fontWeight: FontWeight.w700,
  color: ink,
);

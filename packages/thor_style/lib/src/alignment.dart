import 'css.dart';
import 'errors.dart';
import 'layout_enums.dart';

/// Flutter's `AlignmentGeometry`: a position in a box that may or may not
/// depend on the text direction ([Alignment], [AlignmentDirectional]).
///
/// Widgets that place a child with CSS box alignment (`Align`, `Container`,
/// `Stack`) take this type, as Flutter's do.
///
/// `// web:` [AlignmentDirectional] is written with CSS logical keywords
/// and margins (`start`/`end`, `margin-inline-start`), which the browser
/// flips by the document's direction. A *fractional* directional alignment
/// (`AlignmentDirectional(0.5, 0)`) needs the direction to know which way
/// to offset, so it throws (THOR-R037) unless it is centered: [resolve] it.
abstract class AlignmentGeometry {
  /// Creates an alignment geometry.
  const AlignmentGeometry();

  /// This alignment in [direction]: `start` is the left in
  /// [TextDirection.ltr] and the right in [TextDirection.rtl].
  Alignment resolve(TextDirection direction);

  /// Vertical fraction: -1 (top) to 1 (bottom), 0 is centered.
  double get y;

  /// Whether both axes land on start / center / end, so the alignment can be
  /// expressed with CSS box alignment keywords (no positioning math).
  bool get isKeyword;

  /// Whether the horizontal axis is centered (the same in both directions).
  bool get isHorizontallyCentered;

  /// CSS box-alignment keyword for the vertical axis (`start|center|end`).
  String get alignKeyword;

  /// Vertical position in a column flexbox (`justify-content`).
  String get flexJustify;

  /// Declarations for the *child* of an aligned column flexbox: loose
  /// constraints (no grow) and auto margins for the horizontal position.
  CssDeclarations get flexChildCss;

  /// `place-items` value: `<align> <justify>`.
  String get placeItems;

  /// Percent position of the aligned point, used for gradients,
  /// `background-position`, `transform-origin` and fractional alignments.
  String get cssPosition;

  /// Fractional alignment: positions a child at an arbitrary point.
  CssDeclarations fractionalChildCss();
}

/// Flutter's `AlignmentDirectional`: like [Alignment], but the horizontal
/// axis follows the text direction: [start] is -1 at the start edge (the
/// left in left-to-right text) and 1 at the end edge.
class AlignmentDirectional extends AlignmentGeometry {
  /// Creates an alignment from fractional [start]/[y] coordinates.
  const AlignmentDirectional(this.start, this.y);

  /// Horizontal fraction: -1 (start) to 1 (end), 0 is centered.
  final double start;

  /// Vertical fraction: -1 (top) to 1 (bottom), 0 is centered.
  @override
  final double y;

  /// Top start corner.
  static const topStart = AlignmentDirectional(-1, -1);

  /// Top center edge.
  static const topCenter = AlignmentDirectional(0, -1);

  /// Top end corner.
  static const topEnd = AlignmentDirectional(1, -1);

  /// Center of the start edge.
  static const centerStart = AlignmentDirectional(-1, 0);

  /// Center point.
  static const center = AlignmentDirectional(0, 0);

  /// Center of the end edge.
  static const centerEnd = AlignmentDirectional(1, 0);

  /// Bottom start corner.
  static const bottomStart = AlignmentDirectional(-1, 1);

  /// Bottom center edge.
  static const bottomCenter = AlignmentDirectional(0, 1);

  /// Bottom end corner.
  static const bottomEnd = AlignmentDirectional(1, 1);

  @override
  Alignment resolve(TextDirection direction) => switch (direction) {
    TextDirection.ltr => Alignment(start, y),
    TextDirection.rtl => Alignment(-start, y),
  };

  @override
  bool get isKeyword =>
      Alignment._keyword(start) != null && Alignment._keyword(y) != null;

  @override
  bool get isHorizontallyCentered => start == 0;

  @override
  String get alignKeyword => Alignment._keyword(y) ?? 'start';

  @override
  String get flexJustify => switch (y) {
    -1 => 'flex-start',
    1 => 'flex-end',
    _ => 'center',
  };

  @override
  CssDeclarations get flexChildCss => start == 0
      ? Alignment.center.flexChildCss
      : {
          'flex': '0 1 auto',
          'max-width': '100%',
          'margin-inline-start': start == -1 ? '0' : 'auto',
          'margin-inline-end': start == 1 ? '0' : 'auto',
        };

  @override
  String get placeItems =>
      '$alignKeyword ${Alignment._keyword(start) ?? 'start'}';

  @override
  String get cssPosition => start == 0
      ? Alignment(0, y).cssPosition
      : throw _directional('cssPosition');

  @override
  CssDeclarations fractionalChildCss() => start == 0
      ? Alignment(0, y).fractionalChildCss()
      : throw _directional('fractionalChildCss');

  StateError _directional(String what) => StateError(
    thorError(
      'THOR-R037',
      '$what: an AlignmentDirectional that is not centered horizontally '
          'depends on the text direction, which only the browser knows. Use '
          'the keyword positions (start, end), an Alignment, or resolve it '
          'with a TextDirection (`alignment.resolve(TextDirection.ltr)`).',
    ),
  );

  @override
  bool operator ==(Object other) =>
      other is AlignmentDirectional && other.start == start && other.y == y;

  @override
  int get hashCode => Object.hash(start, y, 'directional');

  @override
  String toString() => 'AlignmentDirectional($start, $y)';
}

/// Flutter's `Alignment`: `x`/`y` in [-1, 1], (0, 0) is the center.
class Alignment extends AlignmentGeometry {
  /// Creates an alignment from fractional [x]/[y] coordinates.
  const Alignment(this.x, this.y);

  /// Horizontal fraction: -1 (left) to 1 (right), 0 is centered.
  final double x;

  /// Vertical fraction: -1 (top) to 1 (bottom), 0 is centered.
  @override
  final double y;

  /// Alignment as the horizontal centering test of [AlignmentGeometry].
  @override
  bool get isHorizontallyCentered => x == 0;

  @override
  Alignment resolve(TextDirection direction) => this;

  /// Top left corner.
  static const topLeft = Alignment(-1, -1);

  /// Top center edge.
  static const topCenter = Alignment(0, -1);

  /// Top right corner.
  static const topRight = Alignment(1, -1);

  /// Center of the left edge.
  static const centerLeft = Alignment(-1, 0);

  /// Center point.
  static const center = Alignment(0, 0);

  /// Center of the right edge.
  static const centerRight = Alignment(1, 0);

  /// Bottom left corner.
  static const bottomLeft = Alignment(-1, 1);

  /// Bottom center edge.
  static const bottomCenter = Alignment(0, 1);

  /// Bottom right corner.
  static const bottomRight = Alignment(1, 1);

  /// Whether both axes land on start / center / end, so the alignment can be
  /// expressed with CSS box alignment keywords (no positioning math).
  @override
  bool get isKeyword => _keyword(x) != null && _keyword(y) != null;

  /// CSS box-alignment keyword for the horizontal axis (`start|center|end`).
  String get justifyKeyword => _keyword(x) ?? 'start';

  /// CSS box-alignment keyword for the vertical axis (`start|center|end`).
  @override
  String get alignKeyword => _keyword(y) ?? 'start';

  /// Physical horizontal keyword (`left|center|right`): Flutter's
  /// [Alignment] is absolute, it does not flip in RTL (that's
  /// `AlignmentDirectional`).
  String get justifyPhysical => switch (x) {
    -1 => 'left',
    1 => 'right',
    _ => 'center',
  };

  /// Vertical position in a column flexbox (`justify-content`).
  @override
  String get flexJustify => switch (y) {
    -1 => 'flex-start',
    1 => 'flex-end',
    _ => 'center',
  };

  /// Declarations for the *child* of an aligned column flexbox: loose
  /// constraints (no grow) and physical auto margins for the x position.
  @override
  CssDeclarations get flexChildCss => x == 0
      // web: centered with `align-self: center`, not auto margins: a child
      // wider than the box overflows both ways like in Flutter (auto margins
      // clamp to 0 and push it to one side).
      ? const {'flex': '0 1 auto', 'max-width': '100%', 'align-self': 'center'}
      : {
          'flex': '0 1 auto',
          'max-width': '100%',
          'margin-left': x == -1 ? '0' : 'auto',
          'margin-right': x == 1 ? '0' : 'auto',
        };

  /// `place-items` value: `<align> <justify>`, physical on the x axis.
  @override
  String get placeItems => '$alignKeyword $justifyPhysical';

  /// Percent position of the aligned point, used for gradients,
  /// `background-position`, `transform-origin` and fractional alignments.
  @override
  String get cssPosition => '${cssNum((x + 1) * 50)}% ${cssNum((y + 1) * 50)}%';

  /// Fractional alignment: positions a child at an arbitrary point.
  /// Applied to the child: `left: p%; top: q%; translate: -p% -q%`.
  @override
  CssDeclarations fractionalChildCss() {
    final px = cssNum((x + 1) * 50), py = cssNum((y + 1) * 50);
    return {
      'position': 'relative',
      'left': '$px%',
      'top': '$py%',
      'translate': '${cssNum(-(x + 1) * 50)}% ${cssNum(-(y + 1) * 50)}%',
    };
  }

  static String? _keyword(double v) => switch (v) {
    -1 => 'start',
    0 => 'center',
    1 => 'end',
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is Alignment && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Flutter's `Axis`.
enum Axis {
  /// Left-to-right layout, sized by `width`.
  horizontal,

  /// Top-to-bottom layout, sized by `height`.
  vertical,
}

/// Flutter's `MainAxisAlignment` → `justify-content`.
enum MainAxisAlignment {
  /// Packs children at the start of the main axis.
  start('flex-start'),

  /// Packs children at the end of the main axis.
  end('flex-end'),

  /// Centers children along the main axis.
  center('center'),

  /// Free space evenly between children (`justify-content: space-between`).
  spaceBetween('space-between'),

  /// Free space evenly around children, halved at the ends
  /// (`justify-content: space-around`).
  spaceAround('space-around'),

  /// Free space evenly between and around children
  /// (`justify-content: space-evenly`).
  spaceEvenly('space-evenly');

  /// Associates this value with its `justify-content` [css] keyword.
  const MainAxisAlignment(this.css);

  /// The `justify-content` keyword.
  final String css;
}

/// Flutter's `CrossAxisAlignment` → `align-items`.
enum CrossAxisAlignment {
  /// Aligns children to the start of the cross axis.
  start('flex-start'),

  /// Aligns children to the end of the cross axis.
  end('flex-end'),

  /// Centers children along the cross axis.
  center('center'),

  /// Stretches children to fill the cross axis.
  stretch('stretch'),

  /// Aligns children by their text baseline.
  baseline('baseline');

  /// Associates this value with its `align-items` [css] keyword.
  const CrossAxisAlignment(this.css);

  /// The `align-items` keyword.
  final String css;
}

/// Flutter's `TextBaseline`: which baseline `CrossAxisAlignment.baseline`
/// lines children up on.
///
/// web: a flex container lines items up on their first alphabetic
/// baseline (`align-items: baseline`); CSS has no ideographic baseline for
/// flex items, so [ideographic] renders like [alphabetic].
enum TextBaseline {
  /// The line Latin letters sit on.
  alphabetic,

  /// The bottom of ideographic (CJK) glyphs. `// web:` same as alphabetic.
  ideographic,
}

/// Flutter's `TextDirection` (in a `Row`, the order of its children).
enum TextDirection {
  /// Left to right.
  ltr,

  /// Right to left.
  rtl,
}

/// Flutter's `MainAxisSize`.
enum MainAxisSize {
  /// Shrinks the flex container to fit its children.
  min,

  /// Expands the flex container to fill the available space.
  max,
}

/// Flutter's `FlexFit`.
enum FlexFit {
  /// Forces the child to fill the available space along the flex axis.
  tight,

  /// Lets the child be as small as it wants along the flex axis.
  loose,
}

/// Flutter's `MaterialTapTargetSize`: how big the touch area around a
/// Material control is.
// web: the clickable area of a native control is its own box, so both values
// lay out the same box; the enum keeps Flutter's API.
enum MaterialTapTargetSize {
  /// At least 48x48 around the control (Flutter's default).
  padded,

  /// The control's own size.
  shrinkWrap,
}

/// Flutter's `StackFit`.
enum StackFit {
  /// Sizes the stack to its non-positioned children.
  loose,

  /// Expands the stack to fill the available space.
  expand,

  /// Passes the incoming constraints through to the stack's children.
  passthrough,
}

/// Flutter's `Clip` → `overflow`.
enum Clip {
  /// Content is not clipped (`overflow: visible`).
  none('visible'),

  /// Content is clipped to the box edges, no anti-aliasing
  /// (`overflow: hidden`).
  hardEdge('hidden'),

  /// Content is clipped to the box edges with anti-aliasing
  /// (`overflow: hidden`).
  antiAlias('hidden'),

  /// Like `antiAlias`, plus a separate compositing layer
  /// (`overflow: hidden`).
  antiAliasWithSaveLayer('hidden');

  /// Associates this value with its `overflow` [css] keyword.
  const Clip(this.css);

  /// The `overflow` keyword.
  final String css;
}

/// Flutter's `WrapAlignment` → `justify-content` / `align-content`.
enum WrapAlignment {
  /// Packs runs at the start of the axis.
  start('flex-start'),

  /// Packs runs at the end of the axis.
  end('flex-end'),

  /// Centers runs along the axis.
  center('center'),

  /// Free space evenly between runs.
  spaceBetween('space-between'),

  /// Free space evenly around runs, halved at the ends.
  spaceAround('space-around'),

  /// Free space evenly between and around runs.
  spaceEvenly('space-evenly');

  /// Associates this value with its [css] keyword.
  const WrapAlignment(this.css);

  /// The `justify-content` / `align-content` keyword.
  final String css;
}

/// Flutter's `WrapCrossAlignment` → `align-items`.
enum WrapCrossAlignment {
  /// Aligns children to the start of the run's cross axis.
  start('flex-start'),

  /// Aligns children to the end of the run's cross axis.
  end('flex-end'),

  /// Centers children along the run's cross axis.
  center('center');

  /// Associates this value with its `align-items` [css] keyword.
  const WrapCrossAlignment(this.css);

  /// The `align-items` keyword.
  final String css;
}

/// Flutter's `BoxFit` → `object-fit` / `background-size`.
enum BoxFit {
  /// Stretches to fill the box, ignoring aspect ratio (`fill`).
  fill('fill'),

  /// Scales to fit inside the box, preserving aspect ratio (`contain`).
  contain('contain'),

  /// Scales to cover the box, preserving aspect ratio, cropping overflow
  /// (`cover`).
  cover('cover'),

  /// Fills the box width, preserving aspect ratio.
  fitWidth('cover'),

  /// Fills the box height, preserving aspect ratio.
  fitHeight('cover'),

  /// Renders at its natural size, unscaled (`none`).
  none('none'),

  /// Scales down to fit, like `contain`, but never scales up
  /// (`scale-down`).
  scaleDown('scale-down');

  /// Associates this value with its [css] keyword.
  const BoxFit(this.css);

  /// The `object-fit` / `background-size` keyword.
  final String css;
}

/// Flutter's `BoxShape`.
enum BoxShape {
  /// A rectangle, optionally rounded via `border-radius`.
  rectangle,

  /// A circle (`border-radius: 50%`).
  circle,
}

/// Flutter's `BorderStyle`.
enum BorderStyle {
  /// No border is drawn.
  none('none'),

  /// A solid line border.
  solid('solid'),
  // Web-only extras, handy for design systems.
  /// A dashed line border.
  dashed('dashed'),

  /// A dotted line border.
  dotted('dotted');

  /// Associates this value with its `border-style` [css] keyword.
  const BorderStyle(this.css);

  /// The `border-style` keyword.
  final String css;
}

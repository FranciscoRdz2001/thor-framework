/// The CSS easing of a `Curve`, for the moves the browser plays
/// (`AnimationController.animateTo`, `ScrollController.animateTo`).
library;

/// The CSS easing function of [curve], or null for none or `linear`: any
/// object with a `css` getter, which is what thor_style's `Curve` has (the
/// engine doesn't depend on `thor_style`). Throws an [ArgumentError] for
/// anything else.
String? cssEasingOf(Object? curve) {
  if (curve == null) return null;
  String? css;
  try {
    // ignore: avoid_dynamic_calls
    css = (curve as dynamic).css as String?;
  } on Object {
    css = null;
  }
  if (css == null) {
    throw ArgumentError.value(
      curve,
      'curve',
      'must be a Curve (an object with a CSS `css` easing)',
    );
  }
  return css == 'linear' ? null : css;
}

/// The function of a `Curve` (its `transform`, 0..1 to 0..1), or null when
/// [curve] has none or is null: what the server samples to write the same
/// move as keyframes.
double Function(double)? transformOf(Object? curve) {
  if (curve == null) return null;
  try {
    // ignore: avoid_dynamic_calls
    final f = (curve as dynamic).transform;
    // ignore: avoid_dynamic_calls
    return f is double Function(double) ? f : (double t) => f(t) as double;
  } on Object {
    return null;
  }
}

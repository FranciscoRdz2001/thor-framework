import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/style_registry.dart';
import '../foundation/theme_tokens.dart';

/// A placeholder for content that is still loading: a rounded box with a
/// light that sweeps across it (the look of `skeletonizer` and `shimmer`).
///
/// Draw it where the data will go, for the snapshot with no data of a
/// `FutureBuilder`: the page goes out with it at once, and the real content
/// takes its place when the future is done.
///
/// ```dart
/// FutureBuilder<List<Product>>(
///   future: data.featured,
///   builder: (context, snapshot) => snapshot.hasData
///       ? ProductGrid(snapshot.data!)
///       : const Skeleton(height: 240),
/// )
/// ```
///
/// To fill a parent that has a size (an `AspectRatio`), use
/// `Skeleton.expand()` (or `height: double.infinity`): the default is 16
/// high.
/// With a nullable type (`Future<Product?>`) check `snapshot.connectionState
/// != ConnectionState.done` for the skeleton: `hasData` is also `false` for a
/// future that completed with `null`, which would keep it for good.
///
/// `// web:` the animation is CSS (a gradient that moves, nothing runs in the
/// browser's code) and stops with `prefers-reduced-motion`. It is hidden from
/// assistive technology (`aria-hidden`) and, without JavaScript, from the
/// page: the content that replaces it is shown at the end of the page then.
class Skeleton extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// A box of [width] by [height] (the width of its parent by default).
  ///
  /// `double.infinity` in either is `100%` of the parent, like `SizedBox`.
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 6,
  }) : circle = false;

  /// A box that fills its parent in both directions, like `SizedBox.expand`:
  /// the placeholder of an image in an `AspectRatio` or a `SizedBox`.
  ///
  /// ```dart
  /// AspectRatio(aspectRatio: 4 / 3, child: Skeleton.expand())
  /// ```
  ///
  /// `// web:` a bare `Skeleton` is 16 high, so it does not know its parent
  /// is tight (Flutter's constraints do not exist here): ask for the fill with
  /// this or `height: double.infinity`.
  const Skeleton.expand({super.key, this.borderRadius = 6})
    : width = double.infinity,
      height = double.infinity,
      circle = false;

  /// A circle of [diameter] (an avatar).
  const Skeleton.circle({super.key, required double diameter})
    : width = diameter,
      height = diameter,
      borderRadius = 0,
      circle = true;

  /// Width in logical pixels; `null` or `double.infinity` takes the width of
  /// the parent.
  final double? width;

  /// Height in logical pixels; `double.infinity` fills the parent.
  final double height;

  /// Radius of the corners in logical pixels.
  final double borderRadius;

  /// Whether it is a circle.
  final bool circle;

  /// Marks the placeholders: the page's `<noscript>` rule hides them.
  static const attribute = 'data-thor-skeleton';

  static const _name = 'thor-skeleton';
  static const _frames = 'to{background-position:-200% 0}';

  @override
  Widget build(BuildContext context) {
    ThorStyleRegistry.active(context)?.addKeyframes(_name, _frames);
    return thorElement(
      'div',
      debugName: 'Skeleton',
      css: {
        'display': 'block',
        'flex': 'none',
        'width': width == null || width!.isInfinite ? '100%' : cssPx(width!),
        'height': height.isInfinite ? '100%' : cssPx(height),
        'border-radius': circle ? '50%' : cssPx(borderRadius),
        'background-color':
            'color-mix(in srgb, ${ThemeTokens.onSurface} 8%, transparent)',
        'background-image':
            'linear-gradient(90deg, transparent, '
            'color-mix(in srgb, ${ThemeTokens.onSurface} 8%, transparent), '
            'transparent)',
        'background-size': '200% 100%',
        'background-repeat': 'no-repeat',
        'animation': '$_name 1.5s ease-in-out infinite',
      },
      conditions: const [
        ConditionalCss(CssCondition.reducedMotion, {'animation': 'none'}),
      ],
      attributes: const {'aria-hidden': 'true', attribute: ''},
    );
  }
}

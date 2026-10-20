import 'dart:convert';

import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../engine/flutter_loader.dart';
import '../engine/watch.dart' show engineAttributes;
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/style_registry.dart';

/// When a [FlutterView] downloads Flutter and draws itself.
enum FlutterViewLoading {
  /// Right away, as the page is parsed. Only for a view that is the reason
  /// the page exists.
  eager,

  /// When the main thread goes idle after `load` (like thor's engine).
  idle,

  /// When the view comes within 200 px of the viewport (the default): a
  /// view below the fold costs nothing until the user scrolls to it.
  visible,

  /// On the first `pointerdown`, `focusin` or `keydown` inside the view
  /// (put a button in the [FlutterView.placeholder] for keyboard users).
  /// The tap that starts the load is not delivered to Flutter.
  interaction,
}

/// A region of the page drawn by a Flutter web app ("hybrid mode"): a
/// chart, an editor or a game inside an otherwise thor (HTML) page.
///
/// The server renders a sized box with [placeholder] in it, so the page is
/// complete without Flutter (and without JS). A small inline loader then
/// mounts the view on its [loading] trigger: the first view downloads the
/// Flutter build at [src] (see `thor build` and the guide), which starts
/// **one** engine in multi-view mode; every [FlutterView] of the page is a
/// view of that app, with its own [initialData]. The placeholder stays
/// until the view paints its first frame.
///
/// ```dart
/// FlutterView(
///   src: '/flutter/',
///   initialData: {'view': 'chart', 'values': [3, 5, 2]},
///   aspectRatio: 16 / 9,
///   placeholder: Center(child: Text('Loading the chart…')),
///   semanticLabel: 'Sales by month',
/// )
/// ```
///
/// The box never changes size when Flutter arrives (no layout shift): give
/// it a [height] or an [aspectRatio]; its width is [width] or the whole
/// width available.
///
/// `// web:` Flutter has no counterpart (it is the inverse of
/// `HtmlElementView`); the name follows `dart:ui`'s `FlutterView`, the
/// surface a Flutter app draws into.
class FlutterView extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a view of the Flutter build at [src].
  const FlutterView({
    super.key,
    this.src = '/flutter/',
    this.initialData,
    this.placeholder,
    this.width,
    this.height,
    this.aspectRatio,
    this.loading = FlutterViewLoading.visible,
    this.semanticLabel,
    this.onMessage,
  });

  /// Base URL of the Flutter web build (the folder with
  /// `flutter_bootstrap.js`). Every [FlutterView] of a page must use the
  /// same one: a page runs one Flutter engine.
  final String src;

  /// JSON-encodable data the Flutter side reads for this view
  /// (`ui_web.views.getInitialData(viewId)`); `null` sends nothing.
  final Object? initialData;

  /// Shown until the view paints its first frame, and for good when there
  /// is no JS or the build fails to load. It fills the box.
  final Widget? placeholder;

  /// Width in logical pixels (at most the available width); `null` takes
  /// the available width.
  final double? width;

  /// Height in logical pixels. Either this or [aspectRatio] is required:
  /// a Flutter view can't size itself to its content.
  final double? height;

  /// Width / height, used when [height] is null.
  final double? aspectRatio;

  /// When the view downloads Flutter and mounts.
  final FlutterViewLoading loading;

  /// Accessible name of the region (`role="region"`). Flutter's own
  /// semantics tree goes inside it.
  final String? semanticLabel;

  /// Called with each message the Flutter side sends (a JSON string). A
  /// method of a `ThorState` runs in the browser; messages sent before the
  /// page's engine is running are dropped.
  final ValueChanged<String>? onMessage;

  @override
  Widget build(BuildContext context) {
    _check('width', width);
    _check('height', height);
    _check('aspectRatio', aspectRatio);
    if (height == null && aspectRatio == null) {
      throw ArgumentError(
        'FlutterView needs a height or an aspectRatio: a Flutter view '
        "can't size itself to its content.",
      );
    }
    if (src.trim().isEmpty) {
      throw ArgumentError.value(src, 'src', 'must be the Flutter build URL');
    }
    final base = src.endsWith('/') ? src : '$src/';
    ThorStyleRegistry.active(context)?.useFlutter(base);
    final data = initialData == null ? null : jsonEncode(initialData);
    return thorElement(
      'div',
      debugName: 'FlutterView',
      fillsWidth: width == null,
      css: {
        'display': 'block',
        'position': 'relative',
        'overflow': 'hidden',
        'width': width == null ? '100%' : cssPx(width!),
        'max-width': '100%',
        if (height != null)
          'height': cssPx(height!)
        else
          'aspect-ratio': cssNum(aspectRatio!),
      },
      attributes: {
        flutterAttr: base,
        flutterLoadAttr: loading.name,
        flutterDataAttr: ?data,
        if (semanticLabel != null) ...{
          'role': 'region',
          'aria-label': semanticLabel!,
        },
        ...engineAttributes({flutterMessageEvent: onMessage}),
      },
      children: [
        if (placeholder case final child?)
          // web: a layer over the box (Flutter appends its <flutter-view>
          // under it), removed after the first frame.
          thorElement(
            'div',
            debugName: 'FlutterViewPlaceholder',
            css: const {
              'position': 'absolute',
              'inset': '0',
              'z-index': '1',
              'display': 'grid',
            },
            attributes: const {flutterPlaceholderAttr: ''},
            children: [child],
          ),
      ],
    );
  }

  static void _check(String name, double? value) {
    if (value != null && !(value.isFinite && value > 0)) {
      throw ArgumentError.value(value, name, 'must be a finite number > 0');
    }
  }
}

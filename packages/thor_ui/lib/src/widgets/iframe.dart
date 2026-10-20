import '../core/core.dart';
import '../foundation/child_rules.dart';
import '../foundation/element.dart';

/// The `sandbox` tokens of an [Iframe]: what the framed page may still do.
/// An [Iframe] with no `sandbox` set has no restrictions; an empty set
/// restricts everything.
enum IframeSandbox {
  /// `allow-forms`
  forms('allow-forms'),

  /// `allow-modals`
  modals('allow-modals'),

  /// `allow-popups`
  popups('allow-popups'),

  /// `allow-same-origin`: the page keeps its own origin (with [scripts] it
  /// can lift the sandbox itself: do not give both to a page you do not
  /// control).
  sameOrigin('allow-same-origin'),

  /// `allow-scripts`
  scripts('allow-scripts'),

  /// `allow-downloads`
  downloads('allow-downloads'),

  /// `allow-top-navigation-by-user-activation`
  topNavigationByUserActivation('allow-top-navigation-by-user-activation');

  const IframeSandbox(this.token);

  /// The attribute token.
  final String token;
}

/// Another page inside this one: a web-only widget (Flutter has no
/// equivalent; the nearest is `HtmlElementView`, which also hosts a browser
/// element) that renders an `<iframe>`.
///
/// ```dart
/// SizedBox.expand(
///   child: Iframe(src: '/preview', title: 'Canvas'),
/// )
/// ```
///
/// An `Iframe` is **one** element with one class, like any thor widget:
/// the wrappers around it (`SizedBox`, `Expanded`, `Padding`, `Opacity`…)
/// fuse into it, so it takes the size they give. Alone it is [width] ×
/// [height] (the browser's 300 × 150 when neither is given) and, unlike the
/// browser's, has no border: draw one with `DecoratedBox`.
///
/// `// web:` [title] is required, the frame's accessible name (WCAG 4.1.2).
/// Without JavaScript it still works: the browser loads [src]. The framed
/// page is another document: nothing of this page's state, styles or engine
/// reaches it (talk to it with `postMessage` from your own script).
class Iframe extends StatelessWidget implements ThorElementWidget, ThorBuiltIn {
  /// Frames the page at [src] (or the document [srcdoc]).
  const Iframe({
    super.key,
    this.src,
    this.srcdoc,
    required this.title,
    this.width,
    this.height,
    this.sandbox,
    this.allow,
    this.name,
    this.lazy = false,
    this.referrerPolicy,
  }) : assert(src != null || srcdoc != null, 'Iframe needs a src or a srcdoc');

  /// The framed page's URL.
  final String? src;

  /// The framed document's HTML, instead of a URL.
  final String? srcdoc;

  /// The frame's accessible name.
  final String title;

  /// The frame's width (the browser's default when null).
  final double? width;

  /// The frame's height (the browser's default when null).
  final double? height;

  /// What the framed page may do; null: everything.
  final Set<IframeSandbox>? sandbox;

  /// The `allow` attribute: the permissions policy for the frame
  /// (`'fullscreen; clipboard-write'`).
  final String? allow;

  /// The `name`, a target for links and forms.
  final String? name;

  /// Whether to defer loading until the frame is near the viewport.
  final bool lazy;

  /// The `referrerpolicy` (`'no-referrer'`, `'origin'`…).
  final String? referrerPolicy;

  @override
  Widget build(BuildContext context) {
    final w = width;
    final h = height;
    return thorElement(
      'iframe',
      debugName: 'Iframe',
      baseCss: const {'border': '0'},
      css: {
        if (w != null) 'width': w.isFinite ? '${_px(w)}px' : '100%',
        if (h != null) 'height': h.isFinite ? '${_px(h)}px' : '100%',
      },
      attributes: {
        'src': ?src,
        'srcdoc': ?srcdoc,
        'title': title,
        if (sandbox case final s?)
          'sandbox': [for (final t in s) t.token].join(' '),
        'allow': ?allow,
        'name': ?name,
        if (lazy) 'loading': 'lazy',
        'referrerpolicy': ?referrerPolicy,
      },
    );
  }
}

String _px(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

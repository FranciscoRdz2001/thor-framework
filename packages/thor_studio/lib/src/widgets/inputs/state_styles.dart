import 'package:thor_ui/thor_ui.dart';

/// One state of an element and what changes in it: a [StyleProps] applied
/// under a CSS condition (`:has(:checked)`, `:focus-visible`, an ancestor).
class StateStyle {
  /// [style] applies while [when] matches.
  const StateStyle(this.when, this.style);

  /// A state selector appended to the element's class (`':has(:checked)'`).
  StateStyle.selector(String selector, StyleProps style)
    : this(CssCondition.selector(selector), style);

  /// The condition.
  final CssCondition when;

  /// The values that apply under it.
  final StyleProps style;
}

/// Typed styles for states `StyleProps.when` has no word for.
///
/// `StyleProps.when` covers breakpoints, hover, focus and press. The studio's
/// native controls are driven by *what the browser knows* instead: a radio
/// being checked (`:has(:checked)`), the whole page asking for the code view
/// (`:root:has(input[name=…]:checked)`). Those states are plain selectors on
/// the element's own class, so no state, no class swap and no JavaScript
/// are involved; [StateStyles] writes them with typed values.
///
/// ```dart
/// StateStyles(
///   duration: StudioDurations.base,
///   states: [
///     StateStyle.selector(
///       ':has(:checked)',
///       StyleProps(decoration: BoxDecoration(color: selected)),
///     ),
///   ],
///   child: Container(decoration: BoxDecoration(color: idle), child: …),
/// )
/// ```
///
/// `// web:` Flutter has no selectors; this is `WidgetStateProperty` for
/// states the platform tracks (checked, focus within), resolved by CSS.
class StateStyles extends ParentDataWrapper {
  /// Adds [style] and [states] to [child]'s element, without a node.
  const StateStyles({
    super.key,
    this.style,
    this.states = const [],
    this.duration,
    this.curve = Curves.easeOut,
    this.attributes = const {},
    required super.child,
  });

  /// Values applied always (what the widget itself has no parameter for).
  final StyleProps? style;

  /// What changes under each condition, in order (a later one wins).
  final List<StateStyle> states;

  /// When set, the values that differ between states transition.
  final Duration? duration;

  /// The easing of that transition.
  final Curve curve;

  /// HTML attributes of the element (`aria-*`, `role`, `data-*`).
  final Map<String, String> attributes;

  @override
  WrapData get wrapData {
    final base = style?.toCss() ?? const <String, String>{};
    final conditions = [
      for (final s in states) ConditionalCss(s.when, s.style.toCss()),
    ];
    final animated = duration == null
        ? const <String>[]
        : {
            for (final s in states) ...s.style.toCss().keys,
          }.where((property) => property != 'display').toList();
    return WrapData(
      css: {
        ...base,
        if (animated.isNotEmpty)
          ...cssTransition(animated, duration: duration!, curve: curve),
      },
      conditions: [
        ...conditions,
        if (animated.isNotEmpty)
          const ConditionalCss(CssCondition.reducedMotion, {
            'transition': 'none',
          }),
      ],
      attributes: attributes,
    );
  }
}

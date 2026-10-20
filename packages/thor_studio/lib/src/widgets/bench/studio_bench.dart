import 'package:thor_ui/thor_ui.dart';

import '../../l10n/studio_localizations.dart';
import '../../studio_id.dart';
import '../../theme/component_themes/studio_bench_theme.dart';
import '../../theme/component_themes/studio_segmented_button_theme.dart';
import '../inputs/state_styles.dart';
import '../inputs/studio_segmented_control.dart';
import 'bench_icons.dart';
import 'bench_scope.dart';

/// The two views of a bench's stage.
enum _View { demo, code }

final _plainId = RegExp(r'^[A-Za-z][A-Za-z0-9_-]*$');

/// The frame every example of the docs lives in: a big card-like stage
/// with the live demo, a side panel with its controls, and a toggle
/// that swaps the demo for the code that makes it.
///
/// ```dart
/// StudioBench(
///   title: 'Rounded button',
///   description: 'Pull the radius until the corners disappear.',
///   stage: DemoButton(),                      // the live demo
///   code: StudioCodeBlock(demoSource),             // what the Code view shows
///   panel: StudioBenchPanel(groups: [...], footer: [...]),
///   replayLabel: 'Replay',                    // omit: no replay button
/// )
/// ```
///
/// The panel stacks under the stage until the *bench's own* width (a size
/// container, not the viewport) reaches `StudioBenchThemeData.sideBySideFrom`, so
/// a bench in a narrow column stacks even on a wide screen. With [wide] it
/// also goes `StudioBenchThemeData.wideBleed` past the prose measure on each
/// side from the `xl` breakpoint up. The [title] and [description] name the example for assistive
/// technology and flow into the `StudioBenchPanel` when it has none of its
/// own. Every visible string is a parameter ([demoLabel], [codeLabel],
/// [viewLabel], [replayLabel]) so a site passes its translations.
///
/// ## Binding controls to the demo
///
/// The controls and the demo talk through one `ThorState`: the controls call
/// its methods, the demo reads its fields. A continuous value (a radius, a
/// padding) follows the state as a bound length (`demo.radius.px`), a finite
/// one (a theme, a variant) as `Watch` variants, so the browser never builds
/// a style.
///
/// ```dart
/// class ButtonDemoState extends ThorState {
///   final radius = state(16.0);
///   final padding = state(20.0);
///   final fill = state(Fill.solid);
///
///   String radiusText() => '${radius.value.round()} px';
///
///   void setRadius(double v) => radius.value = v;
///   void setPadding(double v) => padding.value = v;
///   void setFill(Fill? v) => fill.value = v ?? Fill.solid;
/// }
///
/// final demo = ButtonDemoState(); // top level: the browser boots with it
///
/// StudioBench(
///   stage: DemoButton(), // BorderRadius.circularLength(demo.radius.px)
///   panel: StudioBenchPanel(groups: [
///     StudioBenchGroup(label: 'Switches', children: [
///       StudioBenchRow(
///         label: 'Fill',
///         child: StudioSegmentedControl<Fill>(
///           value: Fill.solid,
///           segments: [...],
///           onChanged: demo.setFill, // void (Fill?) of the state
///         ),
///       ),
///     ]),
///     StudioBenchGroup(label: 'Levels', children: [
///       StudioLevelSlider(
///         title: 'Radius',
///         value: 16,
///         max: 48,
///         onChanged: demo.setRadius, // void (double) of the state
///         valueText: demo.radiusText, // String Function() of the state
///       ),
///     ]),
///   ]),
///   code: …,
/// )
/// ```
///
/// `// web:` Demo and Code are two panes of one stage, switched by a native
/// radio group (`:has(input:checked)` on the page), so the toggle works
/// with no JavaScript and keeps its choice on back and forward. The replay
/// button restarts the stage's CSS animations the same way: the stage is
/// drawn twice and a native checkbox shows one copy at a time, which
/// restarts what animates on show. Because of that a stage that replays must
/// not carry DOM ids, and its replay costs a second copy of the demo.
///
/// Motion: the Code pane and the replayed copy of the stage rise 8 px and fade
/// in over 200 ms with the studio's enter curve when they are shown:
/// `@starting-style` plays when `display` goes from `none`, so no script and
/// no class swap. A stage that does not replay has no entrance of its own
/// (it is on screen when the page loads, and content never waits for an
/// animation). The pane that leaves is gone at once (the two would overlap,
/// and the toggle is the thing being watched). The replay icon turns half a turn on every press.
/// `prefers-reduced-motion` keeps the swap and drops the rise and the turn.
class StudioBench extends StatelessWidget implements ThorElementWidget {
  /// A bench showing [stage] and [code]; the page names it unless [id] does.
  const StudioBench({
    super.key,
    this.id,
    required this.stage,
    required this.code,
    this.panel,
    this.title,
    this.description,
    this.actions = const [],
    this.demoLabel,
    this.codeLabel,
    this.viewLabel,
    this.replayLabel,
    this.wide = false,
    this.theme,
  });

  /// Names the Demo/Code radio group and the replay checkbox; unique on the
  /// page. Optional: without one the page names it (`t-bench1`, `t-bench2`…
  /// in build order, the same on every render of the same page).
  final String? id;

  /// The live demo.
  final Widget stage;

  /// What the Code view shows (usually a `StudioCodeBlock`).
  final Widget code;

  /// The controls (usually a `StudioBenchPanel`); omit for a stage alone.
  final Widget? panel;

  /// The example's name: the group's accessible name and the panel's title.
  final String? title;

  /// A sentence about the example, shown by the panel.
  final String? description;

  /// Small controls at the stage's top right (a share or bookmark button).
  final List<Widget> actions;

  /// The Demo segment's accessible name; defaults to
  /// [StudioLocalizations.benchDemo].
  final String? demoLabel;

  /// The Code segment's accessible name; defaults to
  /// [StudioLocalizations.benchCode].
  final String? codeLabel;

  /// The toggle's accessible name; defaults to
  /// [StudioLocalizations.benchView].
  final String? viewLabel;

  /// The replay button's accessible name; null shows no replay button.
  final String? replayLabel;

  /// Goes wider than its column by `StudioBenchThemeData.wideBleed` on each side
  /// (from `xl` up): for a bench inside a prose measure that is too narrow
  /// for a stage and a panel.
  final bool wide;

  /// Overrides the bench theme.
  final StudioBenchThemeData? theme;

  // A pane takes the whole stage (the demo then centers in all of it when
  // the panel is taller): the stage is a grid whose items start at the corner.
  static const _fill = StyleProps(
    widthFactor: 1,
    alignSelf: CrossAxisAlignment.stretch,
    minWidth: Length.px(0),
    overflowX: Overflow.auto,
  );

  static String _viewName(String id) => '$id-view';
  static String _replayName(String id) => '$id-replay';

  CssCondition _page(String has) => CssCondition.within(':root:has($has)');

  CssCondition _inCodeView(String id) =>
      _page('input[name="${_viewName(id)}"][value="code"]:checked');
  CssCondition _inDemoView(String id) =>
      _page('input[name="${_viewName(id)}"][value="demo"]:checked');

  @override
  Widget build(BuildContext context) {
    assert(
      this.id == null || _plainId.hasMatch(this.id!),
      'StudioBench.id must be letters, digits, - or _ (it names the native '
      'controls the page reads with CSS): "${this.id}"',
    );
    final id = studioId(context, 'bench', this.id);
    final t = StudioBenchThemeData.of(context, theme);
    final l10n = StudioLocalizations.of(context);
    final switchTheme = StudioSegmentedButtonThemeData.of(context);
    const hide = StyleProps(offstage: true);
    final toolbar = switchTheme.height + t.toolbarInset * 2;
    final from = t.sideBySideFrom;
    // The room the floating controls take, so the demo never sits under them.
    EdgeInsets room(EdgeInsets inset) => EdgeInsets.fromLTRB(
      inset.left,
      inset.top + toolbar - t.toolbarInset,
      inset.right,
      inset.bottom + (replayLabel == null ? 0 : toolbar - t.toolbarInset),
    );
    // Stacked (a phone) the stage is compact; side by side it has the roomy
    // padding.
    final padded = room(
      t.stageCompactPadding,
    ).when(container: {from: room(t.stagePadding)});
    final replays = replayLabel != null;
    // Showing a copy is its entrance: it fades up as it appears, which also
    // restarts whatever the stage animates.
    final rise = _riseIn(t);

    final stageCard = StateStyles(
      style:
          StyleProps(
            // Sizes to its demo, never below a least height. Stacked on a
            // phone it scrolls with the page like the rest of the content:
            // pinned above the controls it slid over them on every scroll.
            minHeight: t.stageCompactMinHeight.px,
            overflowY: Overflow.auto,
            decoration: BoxDecoration(
              color: t.stageColor,
              border: Border.all(color: t.borderColor),
              borderRadius: BorderRadius.circular(t.stageRadius),
            ),
          ).when(
            container: {
              // Beside the panel the stage is as tall as the panel or its demo.
              from: StyleProps(
                minHeight: t.stageMinHeight.px,
                maxHeight: 100.percent,
              ),
            },
          ),
      child: Stack(
        children: [
          StateStyles(
            style: _fill,
            states: [StateStyle(_inCodeView(id), hide)],
            child: Container(
              alignment: Alignment.center,
              padding: padded,
              child: replays
                  ? Column(
                      children: [
                        _StageCopy(
                          hidden: _page(
                            'input[name="${_replayName(id)}"]:checked',
                          ),
                          theme: t,
                          stage: stage,
                        ),
                        _StageCopy(
                          hidden: _page(
                            'input[name="${_replayName(id)}"]:not(:checked)',
                          ),
                          theme: t,
                          stage: stage,
                        ),
                      ],
                    )
                  : stage,
            ),
          ),
          StateStyles(
            style: _fill,
            duration: t.enterDuration,
            curve: t.enterCurve,
            states: [StateStyle(_inDemoView(id), hide), rise],
            child: Container(padding: padded, child: code),
          ),
          Positioned(
            left: t.toolbarInset,
            top: t.toolbarInset,
            // web: no `onSelectionChanged`: the native radios keep the view and
            // the page's CSS reads it (`:root:has(input[name=…]:checked)`).
            child: StudioSegmentedControl<_View>(
              name: _viewName(id),
              semanticLabel: viewLabel ?? l10n.benchView,
              selected: const {_View.demo},
              segments: [
                StudioButtonSegment(
                  value: _View.demo,
                  icon: const Icon(BenchIcons.box, size: 16),
                  label: Text(demoLabel ?? l10n.benchDemo),
                ),
                StudioButtonSegment(
                  value: _View.code,
                  icon: const Icon(BenchIcons.code, size: 16),
                  label: Text(codeLabel ?? l10n.benchCode),
                ),
              ],
            ),
          ),
          if (actions.isNotEmpty)
            Positioned(
              right: t.toolbarInset,
              top: t.toolbarInset,
              child: Row(spacing: 8, children: actions),
            ),
          if (replays)
            Positioned(
              right: t.toolbarInset,
              bottom: t.toolbarInset,
              child: StateStyles(
                states: [StateStyle(_inCodeView(id), hide)],
                child: _BenchReplayButton(
                  name: _replayName(id),
                  label: replayLabel!,
                  theme: switchTheme,
                ),
              ),
            ),
        ],
      ),
    );

    // web: a CSS container query never matches the container itself, only
    // its descendants, so the scope wraps the group and the flex column
    // inside asks for the scope's width.
    final bench = BenchScope(
      title: title,
      description: description,
      child: LayoutScope(
        child: StateStyles(
          attributes: {'role': 'group', 'aria-label': ?title},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: t.panelGap,
            layout: const FlexLayout().when(
              container: {from: const FlexLayout(direction: Axis.horizontal)},
            ),
            children: [
              Styled(
                style: const StyleProps().when(
                  container: {
                    from: const StyleProps(
                      flex: 1,
                      flexBasis: Length.px(0),
                      minWidth: Length.px(0),
                      alignSelf: CrossAxisAlignment.stretch,
                    ),
                  },
                ),
                child: stageCard,
              ),
              if (panel != null)
                Styled(
                  style: const StyleProps().when(
                    container: {
                      from: StyleProps(
                        width: t.panelWidth,
                        minWidth: t.panelWidth.px,
                        maxWidth: t.panelWidth.px,
                      ),
                    },
                  ),
                  child: panel!,
                ),
            ],
          ),
        ),
      ),
    );
    if (!wide) return bench;
    return Container(
      margin: EdgeInsets.zero.when(
        large: EdgeInsets.symmetric(horizontal: -t.wideBleed),
      ),
      child: bench,
    );
  }
}

/// The round replay control: a native checkbox laid over a circle, so the
/// browser toggles it with no script (what shows the other copy of the
/// stage).
class _BenchReplayButton extends StatelessWidget implements ThorElementWidget {
  /// A round button over the checkbox [name], named [label].
  const _BenchReplayButton({
    required this.name,
    required this.label,
    required this.theme,
  });

  /// The checkbox's native name (what the page's CSS reads).
  final String name;

  /// The accessible name.
  final String label;

  /// The bench theme.
  final StudioSegmentedButtonThemeResolved theme;

  static void _ignore(Object? _) {}

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = theme.height;
    return StateStyles(
      duration: theme.duration,
      curve: theme.curve,
      style: StyleProps(
        width: size,
        height: size,
        textStyle: TextStyle(color: theme.labelColor),
        decoration: BoxDecoration(
          color: theme.trackColor,
          borderRadius: BorderRadius.circular(size),
        ),
      ),
      states: [
        StateStyle.selector(
          ':hover',
          StyleProps(textStyle: TextStyle(color: scheme.onSurface)),
        ),
        StateStyle.selector(
          ':has(:active)',
          StyleProps(scale: theme.pressScale),
        ),
        StateStyle.selector(
          ':has(:focus-visible)',
          StyleProps(
            outline: BorderSide(color: theme.focusColor, width: 2),
            outlineOffset: 2,
          ),
        ),
      ],
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Half a turn back on every press (the checkbox flips, so the icon
          // winds back and forth: a rewind).
          StateStyles(
            duration: theme.thumbDuration,
            curve: theme.curve,
            states: [
              StateStyle(
                CssCondition.within(':root:has(input[name="$name"]:checked)'),
                const StyleProps(turns: -0.5),
              ),
            ],
            child: const Icon(BenchIcons.rotateCcw, size: 16),
          ),
          Positioned.fill(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: StateStyles(
                style: const StyleProps(
                  widthFactor: 1,
                  heightFactor: 1,
                  opacity: 0,
                ),
                child: Checkbox(
                  value: false,
                  stateLayer: false,
                  name: name,
                  semanticLabel: label,
                  onChanged: _ignore,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Showing a copy is its entrance: it fades up as it appears.
StateStyle _riseIn(StudioBenchThemeResolved t) => StateStyle(
  const CssCondition.startingStyle(),
  StyleProps(opacity: 0, offset: Offset(0, t.enterRise)),
);

/// One of the two drawn copies of a replaying stage: hidden while the other
/// one shows, entering with a rise when it is shown.
class _StageCopy extends StatelessWidget implements ThorElementWidget {
  const _StageCopy({
    required this.hidden,
    required this.theme,
    required this.stage,
  });

  final CssCondition hidden;
  final StudioBenchThemeResolved theme;
  final Widget stage;

  @override
  Widget build(BuildContext context) => StateStyles(
    duration: theme.enterDuration,
    curve: theme.enterCurve,
    states: [
      StateStyle(hidden, const StyleProps(offstage: true)),
      _riseIn(theme),
    ],
    child: Container(child: stage),
  );
}

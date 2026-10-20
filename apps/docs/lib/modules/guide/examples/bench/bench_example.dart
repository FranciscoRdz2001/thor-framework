/// An example of the guide that has controls: what it declares, and the
/// widget that puts it in a `StudioBench`.
///
/// This is the way to build an interactive example. The contract
/// (`packages/thor_studio/README.md`, "The bench"):
///
/// 1. One `ThorState` per example holds the controls' values as fields
///    (`final radius = state(20.0)`) and a method per control, created once
///    as a top-level `final`. The initial value is written once, there: a
///    control reads it (`value: buttonState.radius.value`).
/// 2. A control's `onChanged` is that method, torn off, never a closure.
/// 3. The stage reads the state with `Watch` and `WatchVariables`: a finite
///    value (an enum, a few steps) is `Watch.field(…, builder:)`, a
///    continuous one a CSS variable.
/// 4. The Code view is Dart text made by methods of the state
///    ([BenchCode] and [BenchCodeLine.live]). It is honest: it compiles as
///    shown, or it says it is `appCode` (the stage simulates something the
///    reader's app does, like a server).
///
/// ```dart
/// class ButtonViewModel extends ThorState {
///   final radius = state(16.0);
///   String radiusText() => '${radius.value.round()} px';
///   String radiusCode() => 'borderRadius: BorderRadius.circular(${radius.value.round()}),';
///   void setRadius(double value) => radius.value = value;
/// }
///
/// final buttonState = ButtonViewModel();
///
/// final buttonBench = BenchExample(
///   title: (t) => t.benchButtonTitle,
///   description: (t) => t.benchButtonDescription,
///   stage: const ButtonStage(),
///   code: BenchCode([
///     const BenchCodeLine('Container('),
///     BenchCodeLine.live(buttonState.radiusCode, indent: 1),
///     const BenchCodeLine(')'),
///   ]),
///   controls: [
///     BenchLevel(
///       label: (t) => t.benchButtonRadius,
///       value: buttonState.radius.value,
///       max: 48,
///       divisions: 24,
///       onChanged: buttonState.setRadius,
///       valueText: buttonState.radiusText,
///     ),
///   ],
/// );
/// ```
///
/// Registered with `DocExample.bench(buttonBench)` in `examples.dart`, the
/// markdown shows it with `:::bench button-radius`. The text the stage paints
/// is an English literal, the same one the Code view shows (like the samples
/// of flutter.dev); the ARB (a [MessageOf]) keeps only what surrounds the
/// example: its title, its description and the controls' labels.
library;

import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../../core/content/library.dart' show MessageOf;
import '../../../../core/i18n/docs_locale.dart';

export '../../../../core/content/library.dart' show MessageOf;

/// A control of a bench's panel: a [BenchSwitch], a [BenchToggle], a
/// [BenchDropdown] or a [BenchLevel].
///
/// Sealed: the panel has two groups (the choices, then the Levels), and a
/// `switch` over the controls is exhaustive.
sealed class BenchControl extends StatelessWidget {
  const BenchControl({super.key});
}

/// One value of a [BenchSwitch].
class BenchSegment<T> {
  /// The segment that stands for [value], named [label].
  const BenchSegment(this.value, {required this.label});

  /// What the control's value is when this segment is chosen.
  final T value;

  /// Its text.
  final MessageOf label;
}

/// A "Switch": a segmented control over a few values (an enum, a `bool`).
///
/// ```dart
/// BenchSwitch<Fill>(
///   label: (t) => t.benchCardFill,
///   value: cardState.fill.value, // the field's initial value
///   onChanged: cardState.setFill, // void setFill(Set<Fill> value)
///   segments: [
///     BenchSegment(Fill.soft, label: (t) => t.benchCardFillSoft),
///     BenchSegment(Fill.solid, label: (t) => t.benchCardFillSolid),
///   ],
/// )
/// ```
final class BenchSwitch<T> extends BenchControl {
  /// A switch named [label] over [segments], at [value] when the page is
  /// drawn; [onChanged] is a method of the example's state.
  const BenchSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.segments,
    required this.onChanged,
    this.stacked = false,
    this.code = false,
  });

  /// Its name.
  final MessageOf label;

  /// The value when the page is drawn: the state field's initial value
  /// (`cardState.fill.value`), so it is written once.
  final T value;

  /// The values it can take.
  final List<BenchSegment<T>> segments;

  /// A method of a `ThorState` that takes the chosen set
  /// (`void setFill(Set<Fill> value) => fill.value = value.first`), torn off:
  /// the control's `onSelectionChanged`.
  final ValueChanged<Set<T>> onChanged;

  /// Always put the name over the control (for long segments that do not
  /// fit next to it in the panel). Without it the name shares the line
  /// while a few short segments fit.
  final bool stacked;

  /// The segments are code names (`easeOut`, `AnimatedAlign`): their labels
  /// are set in the mono font.
  final bool code;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    StudioSegmentedControl<T> control({EdgeInsets? expandedInsets}) =>
        StudioSegmentedControl<T>(
          semanticLabel: label(t),
          selected: {value},
          onSelectionChanged: onChanged,
          expandedInsets: expandedInsets,
          segments: [
            for (final s in segments)
              StudioButtonSegment<T>(
                value: s.value,
                label: Text(s.label(t), style: code ? _codeLabel : null),
              ),
          ],
        );
    final chars = segments.fold<int>(
      label(t).length,
      (sum, s) => sum + s.label(t).length,
    );
    if (!stacked && segments.length <= 2 && chars <= 24) {
      return StudioBenchRow(label: label(t), child: control());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          label(t),
          style: Theme.of(context).textTheme.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant!,
          ),
        ),
        // The whole line, the cells sharing it.
        control(expandedInsets: EdgeInsets.zero),
      ],
    );
  }
}

/// A yes / no control: a `Switch` right of its name.
///
/// ```dart
/// BenchToggle(
///   label: (t) => t.exCatEnabled,
///   value: buttonState.enabled.value, // the field's initial value
///   onChanged: buttonState.setEnabled, // void setEnabled(bool value)
/// )
/// ```
final class BenchToggle extends BenchControl {
  /// A switch named [label], on when [value]; [onChanged] is a method of the
  /// example's state.
  const BenchToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  /// Its name.
  final MessageOf label;

  /// The value when the page is drawn: the state field's initial value.
  final bool value;

  /// A method of a `ThorState` (`void setEnabled(bool value)`), torn off:
  /// the switch's `onChanged`.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final name = label(context.l10n);
    return StudioBenchRow(
      label: name,
      child: Switch(value: value, onChanged: onChanged, semanticLabel: name),
    );
  }
}

/// A dropdown over values whose names do not fit a segmented control in one
/// row (more than three, or long code names such as `easeOutBack`): a native
/// `<select>` next to its name.
///
/// ```dart
/// BenchDropdown<MotionCurve>(
///   label: (t) => t.exMotionCurve,
///   value: implicit.curve.value,
///   onChanged: implicit.pickCurve, // void pickCurve(MotionCurve? value)
///   code: true,
///   items: motionCurveSegments(),
/// )
/// ```
final class BenchDropdown<T> extends BenchControl {
  /// A dropdown named [label] over [items], at [value] when the page is
  /// drawn; [onChanged] is a method of the example's state.
  const BenchDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.code = false,
  });

  /// Its name.
  final MessageOf label;

  /// The value when the page is drawn: the state field's initial value.
  final T value;

  /// The values it can take.
  final List<BenchSegment<T>> items;

  /// A method of a `ThorState` that takes the chosen value, torn off.
  final ValueChanged<T?> onChanged;

  /// The items are code names: they are set in the mono font.
  final bool code;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return StudioBenchRow(
      label: label(t),
      child: DropdownButton<T>(
        value: value,
        onChanged: onChanged,
        semanticLabel: label(t),
        borderRadius: BorderRadius.circular(StudioRadii.control),
        style: (code ? _codeLabel : const TextStyle(fontSize: 14)).copyWith(
          color: scheme.onSurface,
        ),
        items: [
          for (final item in items)
            DropdownMenuItem(value: item.value, child: Text(item.label(t))),
        ],
      ),
    );
  }
}

/// The style of a code segment's label.
const _codeLabel = TextStyle(
  fontFamily: 'IBM Plex Mono',
  fontFamilyFallback: ['ui-monospace', 'SF Mono', 'Menlo', 'monospace'],
  fontSize: 13,
);

/// A "Level": a bar you drag to set a number.
///
/// ```dart
/// BenchLevel(
///   label: (t) => t.benchCardRadius,
///   value: cardState.radius.value, // the field's initial value
///   max: 48,
///   divisions: 24,
///   onChanged: cardState.setRadius, // void setRadius(double value)
///   valueText: cardState.radiusText, // String radiusText()
/// )
/// ```
///
/// The number next to the bar is [valueText] from the first paint (the
/// server draws it, the browser keeps it current), so it is written once.
final class BenchLevel extends BenchControl {
  /// A bar named [label] at [value]; [onChanged] and [valueText] are
  /// methods of the example's state.
  const BenchLevel({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.valueText,
    this.min = 0,
    this.max = 1,
    this.divisions,
  });

  /// Its name.
  final MessageOf label;

  /// The value when the page is drawn: the state field's initial value
  /// (`cardState.radius.value`), so it is written once.
  final num value;

  /// The least value.
  final double min;

  /// The greatest value.
  final double max;

  /// The steps between [min] and [max]; null is continuous.
  final int? divisions;

  /// A method of a `ThorState` (`void setRadius(double value)`), torn off.
  final ValueChanged<double> onChanged;

  /// A method of the state that returns the number's text (`'20 px'`):
  /// drawn at first paint and kept current as the bar is dragged.
  final String Function() valueText;

  @override
  Widget build(BuildContext context) => StudioLevelSlider(
    title: label(context.l10n),
    // The number as first drawn; the state's method keeps it current.
    label: valueText(),
    value: value.toDouble(),
    min: min,
    max: max,
    divisions: divisions,
    onChanged: onChanged,
    valueText: valueText,
  );
}

/// What a bench example declares: its name, its stage, the live code and
/// its controls. [BenchView] puts it in a `StudioBench`.
class BenchExample {
  /// An example named [title] that shows [stage] and [code] and takes
  /// [controls] in its panel.
  const BenchExample({
    required this.title,
    required this.description,
    required this.stage,
    required this.code,
    this.controls = const [],
    this.replay = false,
  });

  /// Its name (the panel's title).
  final MessageOf title;

  /// A sentence about it.
  final MessageOf description;

  /// The live demo: reads the example's state.
  final Widget stage;

  /// The Code view: Dart text that follows the state (see [BenchCode]).
  final Widget code;

  /// Its Switches and Levels.
  final List<BenchControl> controls;

  /// Whether the bench shows a Replay button: the stage is drawn twice and
  /// the button swaps the copies, which restarts what animates on paint
  /// (an `AnimationController` that runs when the page is drawn).
  final bool replay;
}

/// A [BenchExample] in a `StudioBench`: the stage, the Demo / Code toggle and
/// a panel with the controls (Switches first, then Levels).
class BenchView extends StatelessWidget {
  /// The example [id] (unique on the page).
  const BenchView(this.id, this.example, {super.key, this.footer = const []});

  /// Names the bench's native controls (letters, digits, `-` and `_`).
  final String id;

  /// What it declares.
  final BenchExample example;

  /// Widgets under the controls, in the panel (a link to the guide).
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final switches = [
      for (final c in example.controls)
        if (c is! BenchLevel) c,
    ];
    final levels = [
      for (final c in example.controls)
        if (c is BenchLevel) c,
    ];
    return StudioBench(
      id: id,
      title: example.title(t),
      description: example.description(t),
      replayLabel: example.replay ? t.benchReplay : null,
      stage: example.stage,
      code: example.code,
      panel: example.controls.isEmpty
          ? null
          : StudioBenchPanel(
              footer: footer,
              groups: [
                if (switches.isNotEmpty)
                  StudioBenchGroup(label: t.benchSwitches, children: switches),
                if (levels.isNotEmpty)
                  StudioBenchGroup(label: t.benchLevels, children: levels),
              ],
            ),
    );
  }
}

/// One line of the Code view of a bench: fixed text, or text a method of the
/// example's state writes (and keeps current in the browser).
class BenchCodeLine {
  /// A line that never changes, indented [indent] levels (two spaces each).
  const BenchCodeLine(this.text, {this.indent = 0}) : live = null;

  /// A line that follows the state: [live] is a method of a `ThorState`
  /// that returns its text (`String radiusCode()`).
  const BenchCodeLine.live(this.live, {this.indent = 0}) : text = '';

  /// The fixed text.
  final String text;

  /// The method that writes the line, or null for fixed text.
  final String Function()? live;

  /// How many levels it is indented.
  final int indent;
}

/// The lines of [source] (two spaces per level), for a Code view that is a
/// whole file: a line that is exactly a key of [live] (`@step`, indented
/// where it goes) follows that method of the state instead.
///
/// ```dart
/// BenchCode(benchLines(r'''
/// class CounterViewModel extends ThorState {
///   @increment
/// }
/// ''', {'@increment': counterRecipe.incrementCode}))
/// ```
List<BenchCodeLine> benchLines(
  String source, [
  Map<String, String Function()> live = const {},
]) => [
  for (final line in source.trimRight().split('\n'))
    if (live[line.trim()] case final method?)
      BenchCodeLine.live(method, indent: _indentOf(line))
    else
      BenchCodeLine(
        line.trim().isEmpty ? ' ' : line.trim(),
        indent: _indentOf(line),
      ),
];

int _indentOf(String line) => (line.length - line.trimLeft().length) ~/ 2;

/// The Code view of a bench: Dart that reads like the example's code and
/// whose changing lines follow the state.
///
/// The text is honest. Either it compiles as shown, or the view says what it
/// is: with [appCode] its header reads "App code" (the stage simulates
/// something the reader's app does, like a server answering, or the lines
/// are code the app writes around the stage). A placeholder (`Avatar()`), a
/// helper the page never defines or a `…` in a view that is not [appCode] is
/// a bug.
///
/// `// web:` the server colors the fixed lines (the highlighter of a
/// `StudioCodeBlock`); a line that follows the state is plain mono text, as
/// the server cannot color a value that moves. The indentation is spaces in
/// the text, so copying keeps it; the whole view is one `<pre>` with a copy
/// button above it.
class BenchCode extends StatelessWidget {
  /// A view of [lines]; [appCode] labels it as the app's code.
  const BenchCode(
    this.lines, {
    super.key,
    this.appCode = false,
    this.language = 'dart',
  });

  /// The lines, top to bottom.
  final List<BenchCodeLine> lines;

  /// Whether the view is code of the reader's app that this stage only
  /// simulates, and not code that compiles as shown.
  final bool appCode;

  /// The language the lines are written in: `dart` or `bash` (a terminal).
  final String language;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final theme = StudioCodeThemeData.of(context);
    final text = Theme.of(context).textTheme;
    final extra = StudioExtraColors.of(context);
    final mono = theme.textStyle.copyWith(color: scheme.onSurface);
    final spans = <InlineSpan>[];
    for (final (i, line) in lines.indexed) {
      if (i > 0) spans.add(const TextSpan(text: '\n'));
      if (line.indent > 0) spans.add(TextSpan(text: '  ' * line.indent));
      final live = line.live;
      if (live != null) {
        spans.add(WidgetSpan(child: Watch(live, style: mono)));
      } else {
        for (final (kind, token) in highlightSource(
          line.text,
          language: language,
        )) {
          spans.add(TextSpan(text: token, style: _tokenStyle(kind)));
        }
      }
    }
    return StudioAttributes(
      const {'data-studio-code': ''},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          // The label and the copy button sit above the code, so the button
          // never covers a line.
          Row(
            children: [
              Expanded(
                child: Text(
                  appCode
                      ? t.benchAppCode
                      : language == 'bash'
                      ? t.codeTerminal
                      : 'Dart',
                  style: text.labelMedium.copyWith(
                    color: theme.headerTextColor,
                  ),
                ),
              ),
              _CopyWhenScripted(
                child: StudioAttributes(
                  {'data-studio-copy': StudioLocalizations.of(context).copy},
                  child: TextButton.icon(
                    // web: the script handles the click; the callback only
                    // makes the control a live (not disabled) <button>.
                    onPressed: _live,
                    icon: const Icon(StudioIcons.copy, size: 14),
                    label: Text(StudioLocalizations.of(context).copy),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.headerTextColor,
                      backgroundColor: theme.color,
                      overlayColor: extra.hover,
                      minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      side: BorderSide(color: theme.borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          StudioRadii.control,
                        ),
                      ),
                      textStyle: text.labelMedium,
                    ),
                  ),
                ),
              ),
            ],
          ),
          StudioAttributes(
            const {'tabindex': '0', 'role': 'group'},
            child: Styled(
              style: const StyleProps(overflowX: Overflow.auto),
              child: Semantics(
                role: SemanticsRole.preformatted,
                // The `<pre>` comes with the browser's 1em margins.
                child: Container(
                  margin: EdgeInsets.zero,
                  child: Text.rich(
                    TextSpan(children: spans),
                    style: mono,
                    softWrap: false,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _live() {}

  static TextStyle? _tokenStyle(CodeToken kind) => switch (kind) {
    CodeToken.keyword => const TextStyle(color: StudioSyntaxColors.keyword),
    CodeToken.string => const TextStyle(color: StudioSyntaxColors.string),
    CodeToken.number => const TextStyle(color: StudioSyntaxColors.number),
    CodeToken.type => const TextStyle(color: StudioSyntaxColors.type),
    CodeToken.comment => const TextStyle(color: StudioSyntaxColors.comment),
    CodeToken.plain => null,
  };
}

/// Hides its child until `scripts/studio-code.js` marks the page
/// (`data-studio-js`): the copy button needs that script, and without it the
/// code is plain selectable text.
class _CopyWhenScripted extends ParentDataWrapper {
  const _CopyWhenScripted({required super.child});

  @override
  WrapData get wrapData => WrapData(
    conditions: [
      ConditionalCss(
        const CssCondition.within(':root:not([data-studio-js])'),
        const StyleProps(offstage: true).toCss(),
      ),
    ],
  );
}

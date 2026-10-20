/// `:::bench bench-semantics`: the accessibility reference example. A Switch
/// picks what `Semantics` says about the text (a heading, a button or a status
/// that is announced) and a Level its heading level; the
/// stage shows the widget and the element a screen reader gets.
///
/// The choices are `Watch.field` variants the server compiled: the browser only
/// shows one of them.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';

/// What `Semantics` says the text is.
enum SemanticsKind {
  /// A heading (`headingLevel`).
  heading,

  /// A button (`button: true`).
  button,

  /// A status message (`liveRegion: true`).
  status,
}

/// What the panel controls and the stage reads.
class SemanticsBenchViewModel extends ThorState {
  /// What the text is.
  final kind = state(SemanticsKind.heading);

  /// The heading level, 2 to 6 (kept as 0 to 4): the page owns the `h1`.
  final level = state(0);

  /// The level, as the number next to the Level's bar.
  String levelText() => 'h${level.value + 2}';

  /// The `Semantics(` arguments line of the Code view.
  String argumentCode() => switch (kind.value) {
    SemanticsKind.heading => 'headingLevel: ${level.value + 2},',
    SemanticsKind.button => 'button: true,',
    SemanticsKind.status => 'liveRegion: true,',
  };

  /// The element the browser gets, as the Code view shows it.
  String elementCode() => switch (kind.value) {
    SemanticsKind.heading =>
      '// <h${level.value + 2}>Orders</h${level.value + 2}>',
    SemanticsKind.button => '// <button type="button">Orders</button>',
    SemanticsKind.status => '// <span aria-live="polite">Orders</span>',
  };

  /// What the Switch calls.
  void setKind(Set<SemanticsKind> value) => kind.value = value.first;

  /// What the Level calls.
  void setLevel(double value) => level.value = value.round();
}

/// One instance, at the top level: the browser boots with it.
final semanticsBench = SemanticsBenchViewModel();

/// The example: a Switch, a Level, the stage and its code.
final semanticsBenchExample = BenchExample(
  title: (t) => t.exUiSemTitle,
  description: (t) => t.exUiSemDescription,
  stage: const SemanticsBenchStage(),
  code: BenchCode([
    const BenchCodeLine('Semantics('),
    BenchCodeLine.live(semanticsBench.argumentCode, indent: 1),
    const BenchCodeLine("child: Text('Orders'),", indent: 1),
    const BenchCodeLine(')'),
    BenchCodeLine.live(semanticsBench.elementCode),
  ]),
  controls: [
    BenchSwitch<SemanticsKind>(
      label: (t) => t.exUiSemKind,
      value: semanticsBench.kind.value,
      onChanged: semanticsBench.setKind,
      segments: [
        BenchSegment(SemanticsKind.heading, label: (t) => t.exUiSemHeading),
        BenchSegment(SemanticsKind.button, label: (t) => t.exUiSemButton),
        BenchSegment(SemanticsKind.status, label: (t) => t.exUiSemStatus),
      ],
    ),
    BenchLevel(
      label: (t) => t.exUiSemLevel,
      value: semanticsBench.level.value,
      max: 4,
      divisions: 4,
      onChanged: semanticsBench.setLevel,
      valueText: semanticsBench.levelText,
    ),
  ],
);

/// The stage: the widget, with the tag it becomes next to it.
class SemanticsBenchStage extends StatelessWidget {
  /// The stage of the example.
  const SemanticsBenchStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    semanticsBench.kind,
    builder: (kind) => Watch.field(
      semanticsBench.level,
      count: 5,
      builder: (level) => _Subject(kind: kind, level: level + 2),
    ),
  );
}

class _Subject extends StatelessWidget {
  const _Subject({required this.kind, required this.level});

  final SemanticsKind kind;
  final int level;

  @override
  Widget build(BuildContext context) {
    // A heading shrinks as its level goes down the outline (h2 to h6).
    final size = kind == SemanticsKind.heading
        ? const [52.0, 42.0, 34.0, 27.0, 21.0][level - 2]
        : 40.0;
    final style = TextStyle(fontSize: size, fontWeight: FontWeight.w600);
    final text = Text('Orders', style: style);
    final tag = switch (kind) {
      SemanticsKind.heading => '<h$level>',
      SemanticsKind.button => '<button>',
      SemanticsKind.status => '<span aria-live>',
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        decoration: BoxDecoration(
          border: Border.all(color: ThemeColor.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            switch (kind) {
              SemanticsKind.heading => Semantics(
                headingLevel: level,
                child: text,
              ),
              SemanticsKind.button => Semantics(
                button: true,
                child: Text('Orders', style: style),
              ),
              SemanticsKind.status => Semantics(liveRegion: true, child: text),
            },
            Text(
              tag,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 18,
                color: ThemeColor.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

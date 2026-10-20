import 'package:thor_ui/thor_ui.dart';

/// What a [Callout] is about; each has its colour and icon in the docs
/// theme (`.docs-callout-<tone>`).
enum CalloutTone {
  /// A note (`> **Note:**`).
  info,

  /// A tip (`> **Tip:**`).
  tip,

  /// Something that goes wrong if it is missed (`> **Heads up:**`).
  warn,

  /// Something that breaks things (`> **Caution:**`).
  danger,

  /// What differs from Flutter (`> **Difference from Flutter:**`).
  flutter;

  /// The tone called [name], or [info].
  static CalloutTone named(String name) =>
      values.firstWhere((t) => t.name == name, orElse: () => CalloutTone.info);

  /// The CSS class of the tone's colours.
  String get cssClass => switch (this) {
    info => 'docs-callout',
    tip => 'docs-callout-tip',
    warn => 'docs-callout-warning',
    danger => 'docs-callout-danger',
    flutter => 'docs-callout-flutter',
  };
}

/// A boxed aside of the guide: a [title] over its [children], in the tone's
/// colour. A note for assistive technology (`role="note"`) named by its
/// title.
class Callout extends StatelessWidget {
  /// A callout.
  const Callout({
    super.key,
    required this.tone,
    required this.title,
    required this.children,
  });

  /// Its tone.
  final CalloutTone tone;

  /// Its heading and accessible name (`Ojo`, `Nota`…).
  final String title;

  /// What it says: the guide's prose, code and examples.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Semantics(
    role: SemanticsRole.note,
    label: title,
    child: Styled(
      classes: ['docs-callout', if (tone != CalloutTone.info) tone.cssClass],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Styled(classes: const ['docs-callout-title'], child: Text(title)),
          ...children,
        ],
      ),
    ),
  );
}

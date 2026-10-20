import 'package:thor_ui/thor_ui.dart';

import '../../theme/studio_extra_colors.dart';
import '../../tokens/shape/studio_radii.dart';
import 'studio_code_block.dart';
import 'support/studio_code_diff.dart';
import 'support/studio_code_language.dart';
import 'support/studio_line_range.dart';

/// One step of a [StudioSteps].
class StudioStep {
  /// A step titled [title] with a text [body], a [child], or neither (just a
  /// title and its [code]).
  const StudioStep({
    required this.title,
    this.body,
    this.child,
    this.code,
    this.language = StudioCodeLanguage.dart,
    this.codeTitle,
    this.id,
  }) : assert(body == null || child == null);

  /// The step's heading.
  final String title;

  /// A text under the title.
  final String? body;

  /// Widgets under the title (instead of [body]).
  final Widget? child;

  /// The code of the step.
  final String? code;

  /// The language of [code] ([StudioCodeLanguage]).
  final StudioCodeLanguage language;

  /// The file name above [code].
  final String? codeTitle;

  /// The anchor of the step's title (`#id`), for a table of contents.
  final String? id;
}

/// Numbered steps down a line, for a tutorial.
///
/// ```dart
/// StudioSteps(
///   steps: [
///     StudioStep(title: 'Create the app', code: 'thor create orders', language: StudioCodeLanguage.bash),
///     StudioStep(title: 'Add the state', body: 'One class per screen.', code: stateCode),
///   ],
///   copyLabel: l10n.copy,
///   copiedLabel: l10n.copied,
/// )
///
/// // The tutorial that grows a file: each step's code marks what it added
/// // over the previous step's.
/// StudioSteps.diff(steps: [...], copyLabel: l10n.copy)
/// ```
///
/// In the diff variant a step's lines that the previous step's [StudioStep.code]
/// does not have are marked as changed, so each step reads as "what is new
/// here". The first step has nothing to compare with and is shown plain.
///
/// The steps are a list (`<ul>`), and the number is drawn text, hidden from
/// screen readers: the list already says "item 2 of 5".
class StudioSteps extends StatelessWidget implements ThorElementWidget {
  /// Steps that show their code as it is.
  const StudioSteps({
    super.key,
    required this.steps,
    this.headingLevel = 3,
    this.copyButton = true,
    this.copyLabel,
    this.copiedLabel,
  }) : diff = false;

  /// Steps whose code marks what it adds over the previous step's.
  const StudioSteps.diff({
    super.key,
    required this.steps,
    this.headingLevel = 3,
    this.copyButton = true,
    this.copyLabel,
    this.copiedLabel,
  }) : diff = true;

  /// The steps, in order.
  final List<StudioStep> steps;

  /// Whether each step's code marks what it adds over the previous one's.
  final bool diff;

  /// The `h1`–`h6` level of each step's title.
  final int headingLevel;

  /// Whether the copy buttons show.
  final bool copyButton;

  /// The copy buttons' text (default: `StudioLocalizations.copy`).
  final String? copyLabel;

  /// The text after copying (default: [copyLabel], or
  /// `StudioLocalizations.copied` without one).
  final String? copiedLabel;

  @override
  Widget build(BuildContext context) {
    String? previous;
    final rows = <Widget>[];
    for (final (i, step) in steps.indexed) {
      final code = step.code;
      rows.add(
        _StepRow(
          number: i + 1,
          last: i == steps.length - 1,
          step: step,
          headingLevel: headingLevel,
          copyButton: copyButton,
          copyLabel: copyLabel,
          copiedLabel: copiedLabel,
          changed: diff && code != null && previous != null
              ? StudioCodeDiff.added(previous, code)
              : const [],
        ),
      );
      if (code != null) previous = code;
    }
    return Semantics(
      role: SemanticsRole.list,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

class _StepRow extends StatelessWidget implements ThorElementWidget {
  const _StepRow({
    required this.number,
    required this.last,
    required this.step,
    required this.headingLevel,
    required this.changed,
    this.copyButton = true,
    this.copyLabel,
    this.copiedLabel,
  });

  final int number;
  final bool last;
  final StudioStep step;
  final int headingLevel;
  final List<StudioLineRange> changed;
  final bool copyButton;
  final String? copyLabel;
  final String? copiedLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final extra = StudioExtraColors.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      role: SemanticsRole.listItem,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          SizedBox(
            width: 32,
            child: Semantics(
              hidden: true,
              child: Column(
                spacing: 6,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest!,
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(StudioRadii.control),
                    ),
                    child: Text(
                      '$number',
                      style: text.labelMedium.copyWith(color: scheme.onSurface),
                    ),
                  ),
                  if (!last)
                    Expanded(
                      child: Container(width: 1, color: scheme.outlineVariant),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Semantics(
                      headingLevel: headingLevel,
                      identifier: step.id,
                      child: Styled(
                        // web: an anchor clears the sticky top bar, like the
                        // prose headings.
                        style: const StyleProps(
                          scrollMargin: EdgeInsets.only(top: 72),
                        ),
                        child: Text(
                          step.title,
                          style: text.titleLarge.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (step.body != null)
                    Text(
                      step.body!,
                      style: text.bodyLarge.copyWith(
                        color: extra.onSurfaceSoft,
                      ),
                    ),
                  ?step.child,
                  if (step.code != null)
                    StudioCodeBlock(
                      step.code!,
                      language: step.language,
                      title: step.codeTitle,
                      changed: changed,
                      copyButton: copyButton,
                      copyLabel: copyLabel,
                      copiedLabel: copiedLabel,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

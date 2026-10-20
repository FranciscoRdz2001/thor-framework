/// The components of the styles guide, as markdown directives (see
/// `directives.dart`): no JavaScript, the interaction is the browser's own
/// (a `details` that opens, a box the reader resizes).
///
/// - `:::ladder` — each `### Title` inside is a rung, first to last resort;
///   the first one open.
/// - `:::tokens` — `- name #RRGGBB — use` lines → theme color cards, each
///   with its CSS variable (`--t-name`).
///
/// And [StageFrame], the box an example with `DocExample(stage: true)` is
/// shown in: the reader drags its corner and the example follows.
library;

import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import '../i18n/docs_locale.dart';
import 'blocks.dart';
import 'directives.dart';

/// The blocks of a styles directive, or null when [d] isn't one.
List<DocBlock>? parseStyleDirective(Directive d, DirectiveContext cx) =>
    switch (d.name) {
      'ladder' => [_ladder(d, cx)],
      'tokens' => [_tokens(d)],
      _ => null,
    };

DocBlock _ladder(Directive d, DirectiveContext cx) {
  final rungs = <RungData>[];
  String? title;
  final body = <String>[];
  void flush() {
    if (title != null) rungs.add(RungData(title, cx.blocks(body.join('\n'))));
    body.clear();
  }

  for (final line in d.body.split('\n')) {
    if (line.startsWith('### ')) {
      flush();
      title = plainText(line.substring(4));
    } else {
      body.add(line);
    }
  }
  flush();
  return LadderBlock(rungs);
}

final _token = RegExp(r'^-\s+([\w-]+)\s+(#[0-9a-fA-F]{6})\s*(?:—|-)?\s*(.*)$');

DocBlock _tokens(Directive d) => TokensBlock([
  for (final line in d.body.split('\n'))
    if (_token.firstMatch(line.trim()) case final m?)
      TokenData(m[1]!, m[2]!.toLowerCase(), m[3]!),
]);

/// The frame of an example the reader resizes (`DocExample(stage: true)`):
/// a hint, and a box with a corner handle and a ruler at 240, 440 and 640
/// px. What's inside follows the box's width, not the window's.
class StageFrame extends StatelessWidget {
  /// The frame around [child].
  const StageFrame(this.child, {super.key});

  /// The example inside.
  final Widget child;

  /// Where the ruler marks the box's width.
  static const marks = [240.0, 440.0, 640.0];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final mono = StudioExtraTextStyles.of(context);
    final extra = StudioExtraColors.of(context);
    final muted = text.bodySmall.copyWith(color: scheme.onSurfaceVariant!);
    return FractionallySizedBox(
      widthFactor: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          // English, like every text an example paints.
          Text(context.l10n.stageResizeHint, style: muted),
          Styled(
            style: StyleProps(
              position: const BoxPosition.relative(),
              minWidth: 220.px,
              maxWidth: 100.percent,
              overflowX: Overflow.hidden,
              overflowY: Overflow.hidden,
              // `// web:` the reader resizes the box with the browser's own
              // corner handle.
              resize: Resize.horizontal,
              boxSizing: BoxSizing.borderBox,
            ),
            child: Container(
              padding: const EdgeInsets.only(top: 8, right: 14, bottom: 14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: extra.lineStrong,
                  style: BorderStyle.dashed,
                ),
                borderRadius: BorderRadius.circular(StudioRadii.inner),
              ),
              child: Stack(
                children: [
                  for (final mark in marks)
                    Positioned(
                      top: 0,
                      left: mark,
                      child: Semantics(
                        hidden: true,
                        child: Container(
                          padding: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(color: scheme.outlineVariant),
                            ),
                          ),
                          child: Text(
                            '${mark.round()}',
                            // A mark past a narrow box is cut, not wrapped.
                            softWrap: false,
                            style: mono.codeSmall.copyWith(
                              fontSize: 10,
                              color: scheme.onSurfaceVariant!,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Below the ruler's numbers.
                  Container(
                    padding: const EdgeInsets.only(top: 16),
                    child: child,
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

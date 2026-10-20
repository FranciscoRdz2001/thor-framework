/// How an example of the registry looks on a page: a `StudioBench` with the
/// live widget on its stage and the code behind the Demo / Code toggle.
/// Examples with controls ([DocExample.bench]) bring their own panel.
library;

import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../core/content/style_directives.dart' show StageFrame;
import '../../../core/i18n/docs_locale.dart';
import 'bench/bench_example.dart';
import 'examples.dart';

/// What a `:::example id` / `:::bench id` block shows (`DocView`'s `embed` is
/// `ExampleEmbed.new`): a bench with the example's live widget and its code,
/// or nothing for an id with no example (the block is dropped).
class ExampleEmbed extends StatelessWidget {
  /// The example [id]; [open] asks for the code view from the start.
  const ExampleEmbed(this.id, {super.key, this.open = false});

  /// Its id in [examples].
  final String id;

  /// Whether the code view should start shown. It has no effect yet: the
  /// bench's Demo / Code toggle starts on Demo.
  final bool open;

  // `data-docs-example` names the example's root element for tools that
  // read the export (`tool/docs_examples_audit.mjs`).
  @override
  Widget build(BuildContext context) {
    final example = examples[id];
    if (example == null) return const SizedBox.shrink();
    // A demo is not text to find: its stage, controls and code view repeat
    // the words of the page (and the Copy button) in search excerpts.
    return StudioAttributes({
      'data-docs-example': id,
      'data-pagefind-ignore': '',
    }, child: _example(context, example));
  }

  Widget _example(BuildContext context, DocExample example) {
    // An illustration, or a demo with its own controls, stage and code.
    if (example.bare) return example.build();
    final bench = example.bench;
    if (bench != null) return BenchView(id, bench);
    final t = context.l10n;
    final code = exampleCode(id);
    return StudioBench(
      id: 'ex-$id',
      title: example.title?.call(t),
      stage: example.stage
          ? StageFrame(example.build())
          : Container(child: example.build()),
      code: code == null
          ? const SizedBox.shrink()
          : ExampleCodeTabs(
              dart: code.dart,
              htmlCode: code.html,
              cssCode: code.css,
              dartTitle: '${id.replaceAll('-', '_')}.dart',
            ),
    );
  }
}

/// The code of an example in three tabs: the Dart, then the HTML and the
/// CSS thor makes of it.
class ExampleCodeTabs extends StatelessWidget {
  /// The tabs of [dart], [htmlCode] and [cssCode]; [dartTitle] names the
  /// first.
  const ExampleCodeTabs({
    super.key,
    required this.dart,
    required this.htmlCode,
    required this.cssCode,
    required this.dartTitle,
    this.id,
  });

  /// The example's source.
  final String dart;

  /// The body it becomes.
  final String htmlCode;

  /// The rules of its classes.
  final String cssCode;

  /// The name of the Dart tab (a file name).
  final String dartTitle;

  /// Names the tabs' native group (default: its place in the page).
  final String? id;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return StudioCodeTabs(
      id: id,
      tabs: [
        StudioCodeTab(label: dartTitle, code: dart),
        StudioCodeTab(
          label: t.exampleTabHtml,
          code: htmlCode,
          language: StudioCodeLanguage.html,
        ),
        StudioCodeTab(
          label: t.exampleTabCss,
          code: cssCode,
          language: StudioCodeLanguage.css,
        ),
      ],
    );
  }
}

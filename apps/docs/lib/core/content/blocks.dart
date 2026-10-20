/// What a markdown page is made of, as data: the page's body is a list of
/// [DocBlock]s, and `blocks_view.dart` turns each one into a `thor_studio`
/// widget (`StudioProse`, `StudioCodeBlock`, `StudioCallout`…).
///
/// The renderer (`library.dart`) and the directives (`directives.dart`)
/// build blocks; they never write HTML for a component. A block holds no
/// widget and no interface text: the labels a block needs ("Copy", the
/// callout titles) are the ARB's, read when the block is drawn.
library;

import 'package:thor_studio/thor_studio.dart' show StudioTone, StudioLineRange;

/// A heading of the page, for its table of contents.
class DocHeading {
  /// A heading with the text [label], linked at [href] (`#id`), of [depth]
  /// (0 for `##`, 1 for `###`).
  const DocHeading(this.label, this.href, {this.depth = 0});

  /// Its text.
  final String label;

  /// Its anchor (`#estado`).
  final String href;

  /// 0 for an `h2`, 1 for an `h3`.
  final int depth;
}

/// One piece of a page's body.
sealed class DocBlock {
  const DocBlock();
}

/// Markdown that stays HTML (paragraphs, lists, tables, headings, quotes):
/// the body of a `StudioProse`.
final class ProseBlock extends DocBlock {
  /// Prose made of [html].
  const ProseBlock(this.html);

  /// The rendered markdown.
  final String html;

  /// How much space the block leaves above it: a section's heading opens
  /// more than a paragraph does.
  int get leading => switch (RegExp(r'^<h([234])').firstMatch(html)?[1]) {
    '2' => 56,
    '3' => 32,
    '4' => 24,
    _ => 16,
  };
}

/// A fenced code block.
final class CodeBlockData extends DocBlock {
  /// [code] in [language], with an optional file [title].
  const CodeBlockData(
    this.code, {
    this.language = 'text',
    this.title,
    this.highlight = const [],
    this.changed = const [],
  });

  /// The source, without the file-name comment the title came from.
  final String code;

  /// The fence's language (`dart`, `bash`…; `text` when it names none).
  final String language;

  /// The file the code comes from (`lib/main.dart`), or null.
  final String? title;

  /// Lines to draw the eye to (a fence's `{2-4}`).
  final List<StudioLineRange> highlight;

  /// Lines marked as added (a fence's `+{2-4}`).
  final List<StudioLineRange> changed;
}

/// A note in the reading flow: `> **Ojo:**`, `:::note`, `:::warning`…
final class CalloutBlock extends DocBlock {
  /// A [tone] note titled [title] around [children].
  const CalloutBlock(this.tone, this.title, this.children);

  /// What kind of note.
  final StudioTone tone;

  /// Its title, in the language the page is written in.
  final String title;

  /// What it says.
  final List<DocBlock> children;
}

/// A step of a [StepsBlock].
final class StepData {
  /// A step titled [title].
  const StepData(this.title, this.children, {this.code, this.id});

  /// Its `###` heading.
  final String title;

  /// The anchor of [title], listed in the page's table of contents.
  final String? id;

  /// What it says, before its [code].
  final List<DocBlock> children;

  /// The code a `:::steps diff` step compares with the previous one's.
  final CodeBlockData? code;
}

/// `:::steps`: numbered steps; with `diff`, each shows what it adds.
final class StepsBlock extends DocBlock {
  /// Steps; [diff] marks what each one's code adds.
  const StepsBlock(this.steps, {this.diff = false});

  /// The steps, in order.
  final List<StepData> steps;

  /// Whether this is `:::steps diff`.
  final bool diff;
}

/// A tab of a [TabsBlock].
final class TabData {
  /// A tab named [label].
  const TabData(this.label, this.children);

  /// Its `@tab` name.
  final String label;

  /// What it shows.
  final List<DocBlock> children;
}

/// `:::tabs`: several blocks behind native tabs.
final class TabsBlock extends DocBlock {
  /// Tabs over [tabs].
  const TabsBlock(this.tabs);

  /// The tabs, the first one open.
  final List<TabData> tabs;
}

/// A card of a [CardsBlock].
final class CardData {
  /// A card that links to [href].
  const CardData(this.title, this.href, this.description);

  /// Its title, as plain text.
  final String title;

  /// Where it goes (a route, without the language, or a URL).
  final String href;

  /// A sentence under the title, or null.
  final String? description;
}

/// `:::cards`: a grid of link cards.
final class CardsBlock extends DocBlock {
  /// A grid of [cards].
  const CardsBlock(this.cards);

  /// The cards.
  final List<CardData> cards;
}

/// A file or folder of a [FilesBlock].
final class FileData {
  /// A file named [name]; a folder when it ends in `/`.
  FileData(this.name, this.note);

  /// Its name.
  final String name;

  /// What it is for, as plain text, or null.
  final String? note;

  /// A folder's content.
  final List<FileData> children = [];
}

/// `:::files`: a project tree.
final class FilesBlock extends DocBlock {
  /// A tree of [entries].
  const FilesBlock(this.entries);

  /// The top level.
  final List<FileData> entries;
}

/// `:::flutter` / `:::compare` with a Flutter and a Thor version: the same
/// code written both ways.
final class CompareBlock extends DocBlock {
  /// The pair [flutter] / [thor], after the optional [intro].
  const CompareBlock(this.flutter, this.thor, {this.intro = const []});

  /// What comes before the pair.
  final List<DocBlock> intro;

  /// The Flutter version.
  final CodeBlockData flutter;

  /// The Thor version.
  final CodeBlockData thor;
}

/// `:::flutter Flutter: X · Thor: Y`: the one-line version of a
/// [CompareBlock].
final class CompareSummaryBlock extends DocBlock {
  /// What you use in [flutter] and what you use in [thor].
  const CompareSummaryBlock(this.flutter, this.thor);

  /// The Flutter line.
  final String flutter;

  /// The Thor line.
  final String thor;
}

/// `:::example id` / `:::bench id`: a live example of the guide.
final class ExampleBlock extends DocBlock {
  /// The example [id]; [open] starts its code view; [bench] when the page
  /// asked for it with `:::bench`.
  const ExampleBlock(this.id, {this.open = false, this.bench = false});

  /// Its id in the registry (`examples.dart`).
  final String id;

  /// Whether its code shows from the start.
  final bool open;

  /// Whether it was written `:::bench` (it must declare controls).
  final bool bench;
}

/// `:::layers id`: an architecture diagram from the registered layer sets.
final class LayersBlock extends DocBlock {
  /// The layer set [id].
  const LayersBlock(this.id);

  /// Its id in `layer_sets.dart`.
  final String id;
}

/// A rung of a [LadderBlock].
final class RungData {
  /// A rung titled [title].
  const RungData(this.title, this.children);

  /// Its `###` heading, as plain text.
  final String title;

  /// What it says.
  final List<DocBlock> children;
}

/// `:::ladder`: options from the first choice to the last resort.
final class LadderBlock extends DocBlock {
  /// A ladder of [rungs].
  const LadderBlock(this.rungs);

  /// First to last.
  final List<RungData> rungs;
}

/// A color of a [TokensBlock].
final class TokenData {
  /// A theme color [name] (`on-primary`) that is [hex] and is for [use].
  const TokenData(this.name, this.hex, this.use);

  /// The role, in kebab case.
  final String name;

  /// Its value, `#rrggbb`.
  final String hex;

  /// What it is for.
  final String use;
}

/// `:::tokens`: theme color cards.
final class TokensBlock extends DocBlock {
  /// Cards for [tokens].
  const TokensBlock(this.tokens);

  /// The colors.
  final List<TokenData> tokens;
}

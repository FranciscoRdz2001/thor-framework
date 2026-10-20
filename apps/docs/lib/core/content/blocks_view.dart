/// Draws a page's [DocBlock]s with the `thor_studio` content widgets: prose
/// in `StudioProse`, code in `StudioCodeBlock`, notes in `StudioCallout`,
/// steps in `StudioSteps`, cards in `StudioCardGrid`, trees in
/// `StudioFileTree`, Flutter / Thor pairs in `StudioFlutterCompare`.
///
/// Every label ("Copy", "In Flutter", a callout's title) is the ARB's, read
/// here from the page's language; a block never holds interface text.
library;

import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import '../i18n/docs_locale.dart';
import 'blocks.dart';
import 'code.dart';

/// The widgets a page asks of the guide for what it does not own: its live
/// examples and its layer diagrams (`DocView.embed` and `layersEmbed`).
class DocEmbeds extends InheritedWidget {
  /// Makes [example] and [layers] reachable from every block below.
  const DocEmbeds({super.key, this.example, this.layers, required super.child});

  /// The widget of `:::example id` / `:::bench id` (`open`: its code view
  /// starts shown); null or a null result drops the block.
  final Widget? Function(String id, {required bool open})? example;

  /// The widget of `:::layers id`.
  final Widget? Function(String id)? layers;

  /// The nearest embeds, or none.
  static DocEmbeds? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DocEmbeds>();

  @override
  bool updateShouldNotify(DocEmbeds oldWidget) =>
      example != oldWidget.example || layers != oldWidget.layers;
}

/// A page's blocks, one under the other: a section heading opens more
/// room than a paragraph, a component a little more than the text.
class DocBlocks extends StatelessWidget {
  /// Draws [blocks]; [compact] closes the gaps (inside a note or a step).
  const DocBlocks(this.blocks, {super.key, this.compact = false});

  /// What to draw.
  final List<DocBlock> blocks;

  /// Whether the blocks sit closer (their container already has room).
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, block) in blocks.indexed)
        if (i == 0)
          DocBlockView(block)
        else
          Padding(
            padding: EdgeInsets.only(top: _gap(block)),
            child: DocBlockView(block),
          ),
    ],
  );

  double _gap(DocBlock block) => switch (block) {
    ProseBlock(:final leading) => compact ? 12 : leading.toDouble(),
    _ => compact ? 12 : 24,
  };
}

/// One block as the widget that draws it.
class DocBlockView extends StatelessWidget {
  /// Draws [block].
  const DocBlockView(this.block, {super.key});

  /// What to draw.
  final DocBlock block;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      ProseBlock(:final html) => StudioProse(
        localizeLinks(context.docsLocale, html),
      ),
      final CodeBlockData code => _Code(code),
      CalloutBlock(:final tone, :final title, :final children) => StudioCallout(
        tone: tone,
        title: title,
        child: DocBlocks(children, compact: true),
      ),
      StepsBlock(:final steps, :final diff) => _Steps(steps, diff: diff),
      TabsBlock(:final tabs) => _Tabs(tabs),
      CardsBlock(:final cards) => StudioCardGrid(
        children: [
          for (final card in cards)
            StudioLinkCard(
              title: card.title,
              href: localizePath(context.docsLocale, card.href),
              description: card.description,
              external: card.href.contains('://'),
            ),
        ],
      ),
      FilesBlock(:final entries) => StudioFileTree(
        entries: [for (final e in entries) _entry(e)],
      ),
      CompareBlock(:final intro, :final flutter, :final thor) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          if (intro.isNotEmpty) DocBlocks(intro, compact: true),
          // The Flutter / Thor labels and the Copy button are not search text.
          StudioAttributes(
            const {'data-pagefind-ignore': ''},
            child: StudioFlutterCompare(
              flutterCode: flutter.code,
              thorCode: thor.code,
              language: StudioCodeLanguage.fromName(thor.language),
            ),
          ),
        ],
      ),
      CompareSummaryBlock(:final flutter, :final thor) => StudioAttributes(
        const {'data-pagefind-ignore': ''},
        child: StudioCompareSummary(flutter: flutter, thor: thor),
      ),
      ExampleBlock(:final id, :final open) =>
        DocEmbeds.maybeOf(context)?.example?.call(id, open: open) ??
            const SizedBox.shrink(),
      LayersBlock(:final id) =>
        DocEmbeds.maybeOf(context)?.layers?.call(id) ?? const SizedBox.shrink(),
      LadderBlock(:final rungs) => DocLadder(rungs),
      TokensBlock(:final tokens) => DocTokens(tokens),
    };
  }

  static StudioFileEntry _entry(FileData file) => StudioFileEntry(
    file.name,
    note: file.note,
    children: file.name.endsWith('/')
        ? [for (final c in file.children) _entry(c)]
        : null,
  );
}

/// A fenced code block: the studio's, with the site's copy labels and a
/// "Terminal" title for a shell block that names no file.
class _Code extends StatelessWidget {
  const _Code(this.code);

  final CodeBlockData code;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return StudioCodeBlock(
      code.code,
      language: StudioCodeLanguage.fromName(code.language),
      title: code.title ?? (isShell(code.language) ? t.codeTerminal : null),
      highlight: code.highlight,
      changed: code.changed,
    );
  }
}

/// `:::steps`, plain or `diff`.
class _Steps extends StatelessWidget {
  const _Steps(this.steps, {required this.diff});

  final List<StepData> steps;
  final bool diff;

  @override
  Widget build(BuildContext context) {
    final data = [
      for (final s in steps)
        StudioStep(
          title: s.title,
          child: s.children.isEmpty
              ? null
              : DocBlocks(s.children, compact: true),
          code: s.code?.code,
          language: StudioCodeLanguage.fromName(s.code?.language ?? 'dart'),
          codeTitle: s.code?.title,
          id: s.id,
        ),
    ];
    return diff ? StudioSteps.diff(steps: data) : StudioSteps(steps: data);
  }
}

/// `:::tabs`: the studio's code tabs when every tab is one code block, the
/// site's own tabs when there is text.
class _Tabs extends StatelessWidget {
  const _Tabs(this.tabs);

  final List<TabData> tabs;

  @override
  Widget build(BuildContext context) {
    final codes = [
      for (final tab in tabs)
        if (tab.children case [final CodeBlockData code]) code,
    ];
    if (codes.length != tabs.length) return DocTabs(tabs);
    return StudioCodeTabs(
      tabs: [
        for (final (i, tab) in tabs.indexed)
          StudioCodeTab(
            label: tab.label,
            code: codes[i].code,
            language: StudioCodeLanguage.fromName(codes[i].language),
            highlight: codes[i].highlight,
            changed: codes[i].changed,
          ),
      ],
    );
  }
}

/// `:::tabs` with text: native tabs (thor_ui's `TabBar` and `TabBarView`, no
/// JavaScript, arrow keys move between them) over any blocks. Tabs with only
/// code are a `StudioCodeTabs` instead.
class DocTabs extends StatelessWidget {
  /// Tabs over [tabs]; the first one is open.
  const DocTabs(this.tabs, {super.key});

  /// The tabs.
  final List<TabData> tabs;

  @override
  Widget build(BuildContext context) {
    final card = StudioCardThemeData.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: card.color,
        border: Border.all(color: card.borderColor),
        borderRadius: BorderRadius.circular(card.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: DefaultTabController(
        length: tabs.length,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              isScrollable: true,
              indicatorColor: scheme.accent,
              labelColor: scheme.onSurface,
              unselectedLabelColor: scheme.onSurfaceVariant!,
              dividerColor: card.borderColor,
              tabs: [
                for (final tab in tabs)
                  Tab(
                    height: 44,
                    child: Text(
                      tab.label,
                      style: text.labelLarge.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            TabBarView(
              children: [
                for (final tab in tabs)
                  Padding(
                    padding: card.padding,
                    child: DocBlocks(tab.children, compact: true),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// `:::ladder`: each rung a card that opens (a native `<details>`), the
/// first marked as the first choice and the last as the last resort.
class DocLadder extends StatelessWidget {
  /// A ladder of [rungs], the first one open.
  const DocLadder(this.rungs, {super.key});

  /// First to last.
  final List<RungData> rungs;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final card = StudioCardThemeData.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(StudioRadii.inner),
      side: BorderSide(color: card.borderColor),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        for (final (i, rung) in rungs.indexed)
          ExpansionTile(
            initiallyExpanded: i == 0,
            shape: shape,
            collapsedShape: shape,
            backgroundColor: card.color,
            collapsedBackgroundColor: card.color,
            iconColor: scheme.accent,
            collapsedIconColor: scheme.onSurfaceVariant!,
            title: Row(
              spacing: 10,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == 0
                        ? scheme.accent
                        : scheme.surfaceContainerHighest!,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: text.labelMedium.copyWith(
                      color: i == 0 ? scheme.onAccent : scheme.onSurface,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    rung.title,
                    style: text.titleMedium.copyWith(color: scheme.onSurface),
                  ),
                ),
                if (i == 0)
                  StudioStatusLabel(
                    label: Text(t.ladderFirst),
                    tone: StudioTone.info,
                  )
                else if (i == rungs.length - 1)
                  StudioStatusLabel(
                    label: Text(t.ladderLast),
                    tone: StudioTone.warn,
                  ),
              ],
            ),
            childrenPadding: const EdgeInsets.fromLTRB(50, 0, 16, 16),
            children: [DocBlocks(rung.children, compact: true)],
          ),
      ],
    );
  }
}

/// `:::tokens`: one card per theme color, with its Dart name, its CSS
/// variable and its value.
class DocTokens extends StatelessWidget {
  /// Cards for [tokens].
  const DocTokens(this.tokens, {super.key});

  /// The colors.
  final List<TokenData> tokens;

  /// `on-primary` → `onPrimary`.
  static String camel(String kebab) =>
      kebab.replaceAllMapped(RegExp('-([a-z])'), (m) => m[1]!.toUpperCase());

  @override
  Widget build(BuildContext context) {
    final card = StudioCardThemeData.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final mono = StudioExtraTextStyles.of(context);
    final code = mono.codeSmall.copyWith(
      fontSize: 11,
      color: scheme.onSurfaceVariant!,
    );
    return Grid(
      layout: const GridLayout(columns: 1, gap: 10)
          .when(medium: const GridLayout(columns: 2, gap: 10))
          .when(expanded: const GridLayout(columns: 3, gap: 10)),
      children: [
        for (final token in tokens)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: card.color,
              border: Border.all(color: card.borderColor),
              borderRadius: BorderRadius.circular(StudioRadii.inner),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Container(
                  height: 44,
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    // The color the page documents: a value of the data.
                    color: Color(
                      int.parse('FF${token.hex.substring(1)}', radix: 16),
                    ),
                    border: Border.all(color: card.borderColor),
                    borderRadius: BorderRadius.circular(StudioRadii.small),
                  ),
                ),
                Text(
                  'ThemeColor.${camel(token.name)}',
                  style: mono.codeSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                Text('var(--t-${token.name})', style: code),
                Text(
                  token.use,
                  style: text.bodySmall.copyWith(
                    color: scheme.onSurfaceVariant!,
                  ),
                ),
                Text(token.hex, style: code),
              ],
            ),
          ),
      ],
    );
  }
}

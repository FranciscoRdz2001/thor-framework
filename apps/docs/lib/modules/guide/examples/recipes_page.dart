/// The cookbook: the content page recipe (`docs/guia/es/ejemplos/pagina-de-contenido.md`).
/// A hero and a grid of posts under it: a Switch picks the hero's tone and
/// whether its image loads lazily, a Level the grid's columns.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench/bench_example.dart';
import 'bench/bench_kit.dart';

/// The hero's colors.
enum HeroTone {
  /// The theme's surface.
  soft,

  /// The theme's inverse surface.
  ink,
}

/// What the panel controls and the stage reads.
class ContentPageViewModel extends ThorState {
  /// The hero's tone.
  final tone = state(HeroTone.soft);

  /// Whether the hero image loads lazily (it should not: it is the first
  /// thing on screen).
  final lazy = state(false);

  /// The columns of the grid, minus one.
  final columns = state(1);

  /// The number next to the columns Level.
  String columnsText() => '${columns.value + 1}';

  /// The `color` line of the Code view.
  String toneCode() => tone.value == HeroTone.ink
      ? 'color: ThemeColor.inverseSurface,'
      : 'color: ThemeColor.surfaceContainer,';

  /// The `lazy` line of the Code view.
  String lazyCode() => 'lazy: ${lazy.value},';

  /// The `columns` line of the Code view.
  String columnsCode() => 'child: PostGrid(columns: ${columns.value + 1}),';

  /// What the tone Switch calls.
  void setTone(Set<HeroTone> value) => tone.value = value.first;

  /// What the lazy Switch calls.
  void setLazy(bool value) => lazy.value = value;

  /// What the columns Level calls.
  void setColumns(double value) => columns.value = value.round() - 1;
}

/// One instance, at the top level: the browser boots with it.
final contentPage = ContentPageViewModel();

/// `:::bench recipe-content-page`.
final contentPageBench = BenchExample(
  title: (t) => t.exRecPageTitle,
  description: (t) => t.exRecPageDescription,
  stage: const ContentPageStage(),
  code: BenchCode([
    const BenchCodeLine('Column(children: ['),
    const BenchCodeLine('Container(', indent: 1),
    BenchCodeLine.live(contentPage.toneCode, indent: 2),
    const BenchCodeLine('child: Row(children: [', indent: 2),
    const BenchCodeLine('Text(…),', indent: 3),
    const BenchCodeLine("Image.network('/img/hero.jpg',", indent: 3),
    const BenchCodeLine('width: 1280, height: 720,', indent: 4),
    BenchCodeLine.live(contentPage.lazyCode, indent: 4),
    const BenchCodeLine('),', indent: 3),
    const BenchCodeLine(']),', indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine('LazyLayout(', indent: 1),
    const BenchCodeLine('extentEstimate: 360,', indent: 2),
    BenchCodeLine.live(contentPage.columnsCode, indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine('])'),
  ], appCode: true),
  controls: [
    BenchSwitch<HeroTone>(
      label: (t) => t.exRecPageTone,
      value: contentPage.tone.value,
      onChanged: contentPage.setTone,
      segments: [
        BenchSegment(HeroTone.soft, label: (t) => t.exRecPageToneSoft),
        BenchSegment(HeroTone.ink, label: (t) => t.exRecPageToneInk),
      ],
    ),
    boolSwitch(
      label: (t) => t.exRecPageLazy,
      value: contentPage.lazy.value,
      onChanged: contentPage.setLazy,
    ),
    BenchLevel(
      label: (t) => t.exRecPageColumns,
      value: contentPage.columns.value + 1,
      min: 1,
      max: 3,
      divisions: 2,
      onChanged: contentPage.setColumns,
      valueText: contentPage.columnsText,
    ),
  ],
);

/// The stage: the page the controls change.
class ContentPageStage extends StatelessWidget {
  /// The stage of the example.
  const ContentPageStage({super.key});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 440),
    child: Watch.field(
      contentPage.tone,
      builder: (tone) => Watch.field(
        contentPage.lazy,
        builder: (lazy) => Watch.field(
          contentPage.columns,
          count: 3,
          builder: (step) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              _Hero(ink: tone == HeroTone.ink, lazy: lazy),
              // The browser neither lays out nor paints it until it nears
              // the viewport.
              LazyLayout(
                extentEstimate: 360,
                child: _PostGrid(columns: step + 1),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.ink, required this.lazy});

  final bool ink;
  final bool lazy;

  @override
  Widget build(BuildContext context) {
    final color = ink ? ThemeColor.onInverseSurface : ThemeColor.onSurface;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ink ? ThemeColor.inverseSurface : ThemeColor.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        spacing: 16,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Text(
                  'Notes from a fast site',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  'What we learned shipping a page that loads instantly.',
                  style: TextStyle(fontSize: 14, color: color),
                ),
                Text(
                  lazy
                      ? 'Image: requested when it nears the screen, and here it is already in view'
                      : 'Image: requested right away',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Image.network(
            '/favicon.png',
            width: 72,
            height: 72,
            lazy: lazy,
            semanticLabel: 'Cover image',
          ),
        ],
      ),
    );
  }
}

class _PostGrid extends StatelessWidget {
  const _PostGrid({required this.columns});

  final int columns;

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Fonts from your own domain',
      'Images with their size',
      'Sections that wait',
      'Metadata per page',
      'Light and dark theme',
      'Export to static',
    ];
    return Column(
      spacing: 12,
      children: [
        for (var i = 0; i < titles.length; i += columns)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              for (var j = i; j < i + columns; j++)
                Expanded(
                  child: j < titles.length
                      ? _PostCard(title: titles[j])
                      : const SizedBox(),
                ),
            ],
          ),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: ThemeColor.outlineVariant),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const Text(
          'A three-minute read.',
          style: TextStyle(fontSize: 13, color: ThemeColor.onSurfaceVariant),
        ),
      ],
    ),
  );
}

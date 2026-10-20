/// The component catalog: content (`docs/guia/es/componentes-contenido.md`).
/// Every example is a bench: a stage, a panel with Switches and Levels, and
/// a Code view that follows them. The ids (`cat-card`…) are the ones the
/// widget pages of the API reference reuse.
library;

import 'package:thor_ui/intl.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../core/i18n/docs_locale.dart';
import 'bench/bench_example.dart';
import 'bench/bench_kit.dart';
import 'bench/bench_kit_content.dart';
import 'bench/bench_kit_preview.dart';

// ----------------------------------------------------------------------- Text

/// The weights of the Text bench.
enum TextWeight {
  /// `FontWeight.w400`.
  regular,

  /// `FontWeight.w600`.
  semibold,

  /// `FontWeight.w700`.
  bold,
}

/// How many lines the Text bench allows.
enum TextLines {
  /// No `maxLines`.
  all,

  /// `maxLines: 1`.
  one,

  /// `maxLines: 2`.
  two,
}

/// What the Text panel controls.
class TextBenchViewModel extends ThorState {
  /// The weight.
  final weight = state(TextWeight.regular);

  /// The line limit.
  final lines = state(TextLines.all);

  /// The font size, in px.
  final size = state(16.0);

  /// The number next to the size Level.
  String sizeText() => '${size.value.round()} px';

  /// The `fontSize` line.
  String sizeCode() => 'fontSize: ${size.value.round()},';

  /// The `fontWeight` line.
  String weightCode() => switch (weight.value) {
    TextWeight.regular => 'fontWeight: FontWeight.w400,',
    TextWeight.semibold => 'fontWeight: FontWeight.w600,',
    TextWeight.bold => 'fontWeight: FontWeight.w700,',
  };

  /// The `maxLines` line.
  String linesCode() => switch (lines.value) {
    TextLines.all => '// no maxLines: the text takes the room it needs',
    TextLines.one => 'maxLines: 1, overflow: TextOverflow.ellipsis,',
    TextLines.two => 'maxLines: 2, overflow: TextOverflow.ellipsis,',
  };

  /// What the weight Switch calls.
  void setWeight(Set<TextWeight> value) => weight.value = value.first;

  /// What the lines Switch calls.
  void setLines(Set<TextLines> value) => lines.value = value.first;

  /// What the size Level calls.
  void setSize(double value) => size.value = value;
}

/// One instance, at the top level.
final textBench = TextBenchViewModel();

/// `cat-text`.
final textBenchExample = BenchExample(
  title: (t) => t.exContTextTitle,
  description: (t) => t.exContTextDescription,
  stage: const _TextStage(),
  code: BenchCode([
    const BenchCodeLine(
      "Text('Brewed with cinnamon and piloncillo, served in a clay mug. A long description is cut off with an ellipsis when you limit the lines.',",
    ),
    BenchCodeLine.live(textBench.linesCode, indent: 1),
    const BenchCodeLine('style: TextStyle(', indent: 1),
    BenchCodeLine.live(textBench.sizeCode, indent: 2),
    BenchCodeLine.live(textBench.weightCode, indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<TextWeight>(
      label: (t) => t.exContWeight,
      value: textBench.weight.value,
      onChanged: textBench.setWeight,
      segments: [
        BenchSegment(TextWeight.regular, label: (t) => t.exContWeightRegular),
        BenchSegment(TextWeight.semibold, label: (t) => t.exContWeightSemibold),
        BenchSegment(TextWeight.bold, label: (t) => t.exContWeightBold),
      ],
    ),
    BenchSwitch<TextLines>(
      label: (t) => t.exContLines,
      value: textBench.lines.value,
      onChanged: textBench.setLines,
      segments: [
        BenchSegment(TextLines.all, label: (t) => t.exContLinesAll),
        BenchSegment(TextLines.one, label: (t) => t.exContLinesOne),
        BenchSegment(TextLines.two, label: (t) => t.exContLinesTwo),
      ],
    ),
    pxLevel(
      label: (t) => t.exCatSize,
      value: textBench.size.value,
      min: 12,
      max: 32,
      divisions: 20,
      onChanged: textBench.setSize,
      valueText: textBench.sizeText,
    ),
  ],
);

class _TextStage extends StatelessWidget {
  const _TextStage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Watch.field(
        textBench.weight,
        builder: (weight) => Watch.field(
          textBench.lines,
          builder: (lines) => Text(
            'Brewed with cinnamon and piloncillo, served in a clay mug. A long description is cut off with an ellipsis when you limit the lines.',
            maxLines: switch (lines) {
              TextLines.all => null,
              TextLines.one => 1,
              TextLines.two => 2,
            },
            overflow: lines == TextLines.all ? null : TextOverflow.ellipsis,
            // `// web:` the size is continuous: it follows the state in the
            // browser (`BoundLength`).
            style: TextStyle(
              fontSizeLength: textBench.size.px,
              fontWeight: switch (weight) {
                TextWeight.regular => FontWeight.w400,
                TextWeight.semibold => FontWeight.w600,
                TextWeight.bold => FontWeight.w700,
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ RichText

/// The look of the highlighted span.
enum SpanLook {
  /// `FontWeight.w700`.
  bold,

  /// `FontStyle.italic`.
  italic,

  /// The text's own style.
  plain,
}

/// What the RichText panel controls.
class RichTextViewModel extends ThorState {
  /// The look of the span.
  final look = state(SpanLook.bold);

  /// Whether the second line is a `SelectableText`.
  final selectable = state(true);

  /// The line height, in steps of 0.25 from 1.
  final height = state(2);

  /// The number next to the height Level.
  String heightText() => '${1 + height.value * 0.25}';

  /// The span's `style` line.
  String spanCode() => switch (look.value) {
    SpanLook.bold =>
      "TextSpan(text: 'coffee', style: TextStyle(fontWeight: FontWeight.w700)),",
    SpanLook.italic =>
      "TextSpan(text: 'coffee', style: TextStyle(fontStyle: FontStyle.italic)),",
    SpanLook.plain => "TextSpan(text: 'coffee'),",
  };

  /// The `height` line.
  String heightCode() =>
      'style: TextStyle(height: ${1 + height.value * 0.25}),';

  /// The second line of the stage's code.
  String selectableCode() => selectable.value
      ? "SelectableText('This text is selectable.')"
      : "Text('This text is not selectable.')";

  /// What the look Switch calls.
  void setLook(Set<SpanLook> value) => look.value = value.first;

  /// What the selectable Switch calls.
  void setSelectable(bool value) => selectable.value = value;

  /// What the height Level calls.
  void setHeight(double value) => height.value = ((value - 1) / 0.25).round();
}

/// One instance, at the top level.
final richText = RichTextViewModel();

/// `cat-rich-text`.
final richTextBench = BenchExample(
  title: (t) => t.exContRichTitle,
  description: (t) => t.exContRichDescription,
  stage: const _RichTextStage(),
  code: BenchCode([
    const BenchCodeLine('RichText('),
    const BenchCodeLine('text: TextSpan(', indent: 1),
    BenchCodeLine.live(richText.heightCode, indent: 2),
    const BenchCodeLine("text: 'Brewed ',", indent: 2),
    const BenchCodeLine('children: [', indent: 2),
    BenchCodeLine.live(richText.spanCode, indent: 3),
    const BenchCodeLine("TextSpan(text: ' with cinnamon'),", indent: 3),
    const BenchCodeLine('],', indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine('),'),
    BenchCodeLine.live(richText.selectableCode),
  ]),
  controls: [
    BenchSwitch<SpanLook>(
      label: (t) => t.exContSpan,
      value: richText.look.value,
      onChanged: richText.setLook,
      segments: [
        BenchSegment(SpanLook.bold, label: (t) => t.exContWeightBold),
        BenchSegment(SpanLook.italic, label: (t) => t.exContItalic),
        BenchSegment(SpanLook.plain, label: (t) => t.exContPlain),
      ],
    ),
    boolSwitch(
      label: (t) => t.exContSelectable,
      value: richText.selectable.value,
      onChanged: richText.setSelectable,
    ),
    stepLevel(
      label: (t) => t.exContLineHeight,
      min: 1,
      step: 0.25,
      steps: 5,
      initial: richText.height.value,
      onChanged: richText.setHeight,
      valueText: richText.heightText,
      unit: '',
    ),
  ],
);

class _RichTextStage extends StatelessWidget {
  const _RichTextStage();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Watch.field(
          richText.look,
          builder: (look) => Watch.field(
            richText.height,
            count: 5,
            builder: (step) => RichText(
              text: TextSpan(
                text: 'Brewed ',
                style: TextStyle(height: 1 + step * 0.25),
                children: [
                  TextSpan(
                    text: 'coffee',
                    style: switch (look) {
                      SpanLook.bold => const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                      SpanLook.italic => const TextStyle(
                        fontStyle: FontStyle.italic,
                      ),
                      SpanLook.plain => null,
                    },
                  ),
                  const TextSpan(text: ' with cinnamon'),
                ],
              ),
            ),
          ),
        ),
        Watch.field(
          richText.selectable,
          builder: (selectable) => selectable
              ? const SelectableText('This text is selectable.')
              : const Text('This text is not selectable.'),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------- Icon

/// The glyph of the Icon bench.
enum IconGlyph {
  /// `Icons.home`.
  home,

  /// `Icons.star`.
  star,

  /// `Icons.notifications`.
  bell,

  /// `Icons.mail`.
  mail,
}

/// What the Icon panel controls.
class IconBenchViewModel extends ThorState {
  /// The glyph.
  final glyph = state(IconGlyph.star);

  /// The size, in steps of 16 px from 32.
  final size = state(2);

  /// Whether the icon takes an accent color.
  final accent = state(true);

  /// The number next to the size Level.
  String sizeText() => '${32 + size.value * 16} px';

  /// The `Icon(...)` line.
  String iconCode() {
    final name = switch (glyph.value) {
      IconGlyph.home => 'Icons.home',
      IconGlyph.star => 'Icons.star',
      IconGlyph.bell => 'Icons.notifications',
      IconGlyph.mail => 'Icons.mail',
    };
    final color = accent.value ? ', color: Color(0xFFD97706)' : '';
    return 'Icon($name, size: ${32 + size.value * 16}$color)';
  }

  /// What the glyph Switch calls.
  void setGlyph(Set<IconGlyph> value) => glyph.value = value.first;

  /// What the accent Switch calls.
  void setAccent(bool value) => accent.value = value;

  /// What the size Level calls.
  void setSize(double value) => size.value = ((value - 32) / 16).round();
}

/// One instance, at the top level.
final iconBench = IconBenchViewModel();

/// `cat-icon`.
final iconBenchExample = BenchExample(
  title: (t) => t.exContIconTitle,
  description: (t) => t.exContIconDescription,
  stage: const _IconStage(),
  code: BenchCode([BenchCodeLine.live(iconBench.iconCode)]),
  controls: [
    BenchSwitch<IconGlyph>(
      label: (t) => t.exContGlyph,
      value: iconBench.glyph.value,
      onChanged: iconBench.setGlyph,
      segments: [
        BenchSegment(IconGlyph.home, label: (t) => t.exContGlyphHome),
        BenchSegment(IconGlyph.star, label: (t) => t.exContGlyphStar),
        BenchSegment(IconGlyph.bell, label: (t) => t.exContGlyphBell),
        BenchSegment(IconGlyph.mail, label: (t) => t.exContGlyphMail),
      ],
    ),
    boolSwitch(
      label: (t) => t.exContAccent,
      value: iconBench.accent.value,
      onChanged: iconBench.setAccent,
    ),
    stepLevel(
      label: (t) => t.exCatSize,
      min: 32,
      step: 16,
      steps: 5,
      initial: iconBench.size.value,
      onChanged: iconBench.setSize,
      valueText: iconBench.sizeText,
    ),
  ],
);

class _IconStage extends StatelessWidget {
  const _IconStage();

  @override
  Widget build(BuildContext context) => Watch.field(
    iconBench.glyph,
    builder: (glyph) => Watch.field(
      iconBench.size,
      count: 5,
      builder: (step) => Watch.field(
        iconBench.accent,
        builder: (accent) => Icon(
          switch (glyph) {
            IconGlyph.home => Icons.home,
            IconGlyph.star => Icons.star,
            IconGlyph.bell => Icons.notifications,
            IconGlyph.mail => Icons.mail,
          },
          size: 32.0 + step * 16,
          color: accent ? const Color(0xFFD97706) : null,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------- Image.asset

/// How the image fills its box.
enum ImageFit {
  /// `BoxFit.cover`.
  cover,

  /// `BoxFit.contain`.
  contain,

  /// `BoxFit.fill`.
  fill,
}

/// What the Image panel controls.
class ImageBenchViewModel extends ThorState {
  /// The fit.
  final fit = state(ImageFit.cover);

  /// Whether it is clipped to rounded corners.
  final rounded = state(true);

  /// The width, in steps of 32 px from 96.
  final width = state(2);

  /// The number next to the width Level.
  String widthText() => '${96 + width.value * 32} px';

  /// The `Image.asset(...)` line.
  String fitCode() => 'fit: BoxFit.${fit.value.name},';

  /// The `width` line.
  String widthCode() => 'width: ${96 + width.value * 32}, height: 96,';

  /// The first line of the code.
  String headCode() => rounded.value
      ? 'ClipRRect(borderRadius: BorderRadius.circular(16), child:'
      : '// no ClipRRect';

  /// The last line: it closes the `ClipRRect`, when there is one.
  String closeCode() => rounded.value ? ')' : ' ';

  /// What the fit Switch calls.
  void setFit(Set<ImageFit> value) => fit.value = value.first;

  /// What the rounded Switch calls.
  void setRounded(bool value) => rounded.value = value;

  /// What the width Level calls.
  void setWidth(double value) => width.value = ((value - 96) / 32).round();
}

/// One instance, at the top level.
final imageBench = ImageBenchViewModel();

/// `cat-image`.
final imageBenchExample = BenchExample(
  title: (t) => t.exContImageTitle,
  description: (t) => t.exContImageDescription,
  stage: const _ImageStage(),
  code: BenchCode([
    BenchCodeLine.live(imageBench.headCode),
    const BenchCodeLine("Image.asset('/og.png',", indent: 1),
    BenchCodeLine.live(imageBench.widthCode, indent: 2),
    BenchCodeLine.live(imageBench.fitCode, indent: 2),
    const BenchCodeLine("semanticLabel: 'Thor logo'),", indent: 2),
    BenchCodeLine.live(imageBench.closeCode),
  ]),
  controls: [
    BenchSwitch<ImageFit>(
      label: (t) => t.exContFit,
      value: imageBench.fit.value,
      onChanged: imageBench.setFit,
      segments: [
        BenchSegment(ImageFit.cover, label: (t) => t.exContFitCover),
        BenchSegment(ImageFit.contain, label: (t) => t.exContFitContain),
        BenchSegment(ImageFit.fill, label: (t) => t.exContFitFill),
      ],
    ),
    boolSwitch(
      label: (t) => t.exContRounded,
      value: imageBench.rounded.value,
      onChanged: imageBench.setRounded,
    ),
    stepLevel(
      label: (t) => t.exContWidth,
      min: 96,
      step: 32,
      steps: 5,
      initial: imageBench.width.value,
      onChanged: imageBench.setWidth,
      valueText: imageBench.widthText,
    ),
  ],
);

class _ImageStage extends StatelessWidget {
  const _ImageStage();

  @override
  Widget build(BuildContext context) {
    return Watch.field(
      imageBench.fit,
      builder: (fit) => Watch.field(
        imageBench.rounded,
        builder: (rounded) => Watch.field(
          imageBench.width,
          count: 5,
          builder: (step) {
            final image = Image.asset(
              '/og.png',
              width: 96.0 + step * 32,
              height: 96,
              fit: switch (fit) {
                ImageFit.cover => BoxFit.cover,
                ImageFit.contain => BoxFit.contain,
                ImageFit.fill => BoxFit.fill,
              },
              semanticLabel: 'Thor logo',
            );
            return rounded
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: image,
                  )
                : image;
          },
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Image.network

/// What the image builders panel controls.
class ImageBuildersViewModel extends ThorState {
  /// Whether the file is not an image.
  final broken = state(true);

  /// Whether the builders are given.
  final builders = state(true);

  /// The URL line.
  String urlCode() =>
      broken.value ? "'/broken-image.png', // not an image" : "'/og.png',";

  /// The builders lines.
  String buildersCode() => builders.value
      ? 'errorBuilder: (context, error, stack) => …, loadingBuilder: …,'
      : '// no errorBuilder or loadingBuilder';

  /// What the broken Switch calls.
  void setBroken(bool value) => broken.value = value;

  /// What the builders Switch calls.
  void setBuilders(bool value) => builders.value = value;
}

/// One instance, at the top level.
final imageBuilders = ImageBuildersViewModel();

/// `cat-image-builders`.
final imageBuildersBench = BenchExample(
  title: (t) => t.exContBuildersTitle,
  description: (t) => t.exContBuildersDescription,
  stage: const _ImageBuildersStage(),
  code: BenchCode([
    const BenchCodeLine('Image.network('),
    BenchCodeLine.live(imageBuilders.urlCode, indent: 1),
    const BenchCodeLine('width: 96, height: 64,', indent: 1),
    BenchCodeLine.live(imageBuilders.buildersCode, indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    boolSwitch(
      label: (t) => t.exContBroken,
      value: imageBuilders.broken.value,
      onChanged: imageBuilders.setBroken,
    ),
    boolSwitch(
      label: (t) => t.exContBuilders,
      value: imageBuilders.builders.value,
      onChanged: imageBuilders.setBuilders,
    ),
  ],
);

class _ImageBuildersStage extends StatelessWidget {
  const _ImageBuildersStage();

  @override
  Widget build(BuildContext context) {
    return Watch.field(
      imageBuilders.broken,
      builder: (broken) => Watch.field(
        imageBuilders.builders,
        builder: (builders) => builders
            ? Image.network(
                broken ? '/broken-image.png' : '/og.png',
                width: 96,
                height: 64,
                errorBuilder: (context, error, stack) => const SizedBox(
                  width: 96,
                  height: 64,
                  child: Center(child: Text('No photo')),
                ),
                loadingBuilder: (context, child, progress) => const SizedBox(
                  width: 96,
                  height: 64,
                  child: Center(child: Text('Loading')),
                ),
              )
            : Image.network(
                broken ? '/broken-image.png' : '/og.png',
                width: 96,
                height: 64,
              ),
      ),
    );
  }
}

// ----------------------------------------------------------------- HtmlWidget

/// What the HtmlWidget panel controls.
class HtmlBenchViewModel extends ThorState {
  /// Whether the HTML carries a script and an `onclick`.
  final hostile = state(true);

  /// `HtmlPolicy(nofollow:)`.
  final nofollow = state(true);

  /// `HtmlPolicy(linkTarget: '_blank')`.
  final blank = state(false);

  /// The source line.
  String sourceCode() => hostile.value
      ? 'HtmlWidget(commentWithScript,'
      : 'HtmlWidget(commentSafe,';

  /// The policy line.
  String policyCode() {
    final parts = [
      if (blank.value) "linkTarget: '_blank'",
      if (nofollow.value) 'nofollow: true',
    ];
    return parts.isEmpty
        ? '// the default policy'
        : 'policy: HtmlPolicy(${parts.join(', ')}),';
  }

  /// What the hostile Switch calls.
  void setHostile(bool value) => hostile.value = value;

  /// What the nofollow Switch calls.
  void setNofollow(bool value) => nofollow.value = value;

  /// What the blank Switch calls.
  void setBlank(bool value) => blank.value = value;
}

/// One instance, at the top level.
final htmlBench = HtmlBenchViewModel();

/// `cat-html-widget`.
final htmlWidgetBench = BenchExample(
  title: (t) => t.exContHtmlTitle,
  description: (t) => t.exContHtmlDescription,
  stage: const _HtmlStage(),
  code: BenchCode([
    BenchCodeLine.live(htmlBench.sourceCode),
    BenchCodeLine.live(htmlBench.policyCode, indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    boolSwitch(
      label: (t) => t.exContHostile,
      value: htmlBench.hostile.value,
      onChanged: htmlBench.setHostile,
    ),
    boolSwitch(
      label: (t) => t.exContNofollow,
      value: htmlBench.nofollow.value,
      onChanged: htmlBench.setNofollow,
    ),
    boolSwitch(
      label: (t) => t.exContBlank,
      value: htmlBench.blank.value,
      onChanged: htmlBench.setBlank,
    ),
  ],
);

class _HtmlStage extends StatelessWidget {
  const _HtmlStage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Watch.field(
        htmlBench.hostile,
        builder: (hostile) => Watch.field(
          htmlBench.nofollow,
          builder: (nofollow) => Watch.field(
            htmlBench.blank,
            builder: (blank) {
              final policy = HtmlPolicy(
                nofollow: nofollow,
                linkTarget: blank ? '_blank' : null,
              );
              final source =
                  '<h2>Clay-pot coffee</h2>'
                  '<p>With <strong>cinnamon</strong> and <em>piloncillo</em>.</p>'
                  '<p><a href="https://example.com"'
                  '${hostile ? ' onclick="alert(1)"' : ''}>More</a></p>'
                  '${hostile ? '<script>alert(1)</script>' : ''}';
              // The page shows what the sanitizer left: the link it kept
              // and what it took out.
              final link =
                  RegExp('<a [^>]*>')
                      .firstMatch(sanitizeHtml(source, policy: policy))
                      ?.group(0) ??
                  '';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  HtmlWidget(source, policy: policy),
                  CodeNote(label: 'Link kept', code: link),
                  CodeNote(
                    label: 'Removed',
                    code: hostile ? '<script>, onclick' : 'nothing',
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------- Card

/// What the Card panel controls.
class CardBenchViewModel extends ThorState {
  /// The elevation, in steps of 2 from 0.
  final elevation = state(1);

  /// The inner space, in steps of 8 px from 8.
  final padding = state(1);

  /// Whether the card ends with buttons.
  final actions = state(true);

  /// The number next to the elevation Level.
  String elevationText() => '${elevation.value * 2}';

  /// The number next to the padding Level.
  String paddingText() => '${8 + padding.value * 8} px';

  /// The `elevation` line.
  String elevationCode() => 'elevation: ${elevation.value * 2},';

  /// The `padding` line.
  String paddingCode() => 'padding: EdgeInsets.all(${8 + padding.value * 8}),';

  /// The actions line.
  String actionsCode() => actions.value
      ? 'Row(children: [TextButton(…), FilledButton(…)]),'
      : '// no actions';

  /// What the elevation Level calls.
  void setElevation(double value) => elevation.value = (value / 2).round();

  /// What the padding Level calls.
  void setPadding(double value) => padding.value = ((value - 8) / 8).round();

  /// What the buttons call: nothing, they only have to be enabled.
  void noop() {}

  /// What the actions Switch calls.
  void setActions(bool value) => actions.value = value;
}

/// One instance, at the top level.
final cardBench = CardBenchViewModel();

/// `cat-card`.
final cardBenchExample = BenchExample(
  title: (t) => t.exContCardTitle,
  description: (t) => t.exContCardDescription,
  stage: const _CardStage(),
  code: BenchCode([
    const BenchCodeLine('Card('),
    BenchCodeLine.live(cardBench.elevationCode, indent: 1),
    const BenchCodeLine('child: Padding(', indent: 1),
    BenchCodeLine.live(cardBench.paddingCode, indent: 2),
    const BenchCodeLine('child: Column(children: [', indent: 2),
    const BenchCodeLine("Text('Order #1042'),", indent: 3),
    BenchCodeLine.live(cardBench.actionsCode, indent: 3),
    const BenchCodeLine(']),', indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    boolSwitch(
      label: (t) => t.exContActions,
      value: cardBench.actions.value,
      onChanged: cardBench.setActions,
    ),
    stepLevel(
      label: (t) => t.exContElevation,
      min: 0,
      step: 2,
      steps: 5,
      initial: cardBench.elevation.value,
      onChanged: cardBench.setElevation,
      valueText: cardBench.elevationText,
      unit: '',
    ),
    stepLevel(
      label: (t) => t.exBtnPadding,
      min: 8,
      step: 8,
      steps: 4,
      initial: cardBench.padding.value,
      onChanged: cardBench.setPadding,
      valueText: cardBench.paddingText,
    ),
  ],
);

class _CardStage extends StatelessWidget {
  const _CardStage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Watch.field(
        cardBench.elevation,
        count: 5,
        builder: (elevation) => Watch.field(
          cardBench.padding,
          count: 4,
          builder: (padding) => Watch.field(
            cardBench.actions,
            builder: (actions) => Card(
              elevation: elevation * 2.0,
              child: Padding(
                padding: EdgeInsets.all(8.0 + padding * 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    const Text(
                      'Order #1042',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(
                      '2 coffees, 1 sweet bread. Ready in 10 minutes.',
                    ),
                    if (actions)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: cardBench.noop,
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: cardBench.noop,
                            child: const Text('Pick up'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- ListTile

/// What the ListTile panel controls.
class ListTileBenchViewModel extends ThorState {
  /// `selected`.
  final selected = state(false);

  /// `enabled`.
  final enabled = state(true);

  /// `dense`.
  final dense = state(false);

  /// Whether there is a `subtitle`.
  final subtitle = state(true);

  /// The `subtitle` line.
  String subtitleCode() => subtitle.value
      ? "subtitle: Text('Sent you a message'),"
      : '// no subtitle';

  /// The state lines.
  String flagsCode() =>
      'selected: ${selected.value}, enabled: ${enabled.value}, dense: ${dense.value},';

  /// What the selected Switch calls.
  void setSelected(bool value) => selected.value = value;

  /// What the enabled Switch calls.
  void setEnabled(bool value) => enabled.value = value;

  /// What the dense Switch calls.
  void setDense(bool value) => dense.value = value;

  /// What the subtitle Switch calls.
  void setSubtitle(bool value) => subtitle.value = value;
}

/// One instance, at the top level.
final listTileBench = ListTileBenchViewModel();

/// `cat-list-tile`.
final listTileBenchExample = BenchExample(
  title: (t) => t.exContTileTitle,
  description: (t) => t.exContTileDescription,
  stage: const _ListTileStage(),
  code: BenchCode([
    const BenchCodeLine('ListTile('),
    const BenchCodeLine("leading: CircleAvatar(child: Text('AL')),", indent: 1),
    const BenchCodeLine("title: Text('Ana López'),", indent: 1),
    BenchCodeLine.live(listTileBench.subtitleCode, indent: 1),
    const BenchCodeLine("trailing: Text('9:41'),", indent: 1),
    BenchCodeLine.live(listTileBench.flagsCode, indent: 1),
    const BenchCodeLine(
      'tileColor: ThemeColor.surfaceContainerHighest,',
      indent: 1,
    ),
    const BenchCodeLine(
      'selectedTileColor: Color(0xFF0F766E), selectedColor: Color(0xFFFFFFFF),',
      indent: 1,
    ),
    const BenchCodeLine(
      'shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: ThemeColor.outline)),',
      indent: 1,
    ),
    const BenchCodeLine("href: '/messages',", indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    boolSwitch(
      label: (t) => t.exContSelected,
      value: listTileBench.selected.value,
      onChanged: listTileBench.setSelected,
    ),
    enabledSwitch(
      value: listTileBench.enabled.value,
      onChanged: listTileBench.setEnabled,
    ),
    boolSwitch(
      label: (t) => t.exContDense,
      value: listTileBench.dense.value,
      onChanged: listTileBench.setDense,
    ),
    boolSwitch(
      label: (t) => t.exContSubtitle,
      value: listTileBench.subtitle.value,
      onChanged: listTileBench.setSubtitle,
    ),
  ],
);

class _ListTileStage extends StatelessWidget {
  const _ListTileStage();

  @override
  Widget build(BuildContext context) {
    final href = context.localized(
      '/componentes/componentes-contenido#listtile',
    );
    return SizedBox(
      width: 340,
      child: Watch.field(
        listTileBench.selected,
        builder: (selected) => Watch.field(
          listTileBench.enabled,
          builder: (enabled) => Watch.field(
            listTileBench.dense,
            builder: (dense) => Watch.field(
              listTileBench.subtitle,
              builder: (subtitle) => ListTile(
                leading: const CircleAvatar(child: Text('AL')),
                title: const Text('Ana López'),
                subtitle: subtitle ? const Text('Sent you a message') : null,
                trailing: const Text('9:41'),
                selected: selected,
                enabled: enabled,
                dense: dense,
                tileColor: ThemeColor.surfaceContainerHighest,
                selectedTileColor: const Color(0xFF0F766E),
                selectedColor: const Color(0xFFFFFFFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: ThemeColor.outline),
                ),
                href: enabled ? href : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- Divider

/// What the Divider panel controls.
class DividerBenchViewModel extends ThorState {
  /// The thickness: the step of the Level, from 1 px (0 is 1 px).
  final thickness = state(0);

  /// The indent at both ends, in steps of 32 px.
  final indent = state(1);

  /// The number next to the thickness Level.
  String thicknessText() => '${1 + thickness.value} px';

  /// The number next to the indent Level.
  String indentText() => '${indent.value * 32} px';

  /// The indent, in px (`dividerBench.indentPx.px` follows it).
  double indentPx() => indent.value * 32.0;

  /// The `Divider(...)` line.
  String dividerCode() =>
      'Divider(thickness: ${1 + thickness.value}, indent: ${indent.value * 32}, endIndent: ${indent.value * 32}, color: ThemeColor.outline),';

  /// What the thickness Level calls.
  void setThickness(double value) => thickness.value = (value - 1).round();

  /// What the indent Level calls.
  void setIndent(double value) => indent.value = (value / 32).round();
}

/// One instance, at the top level.
final dividerBench = DividerBenchViewModel();

/// `cat-divider`.
final dividerBenchExample = BenchExample(
  title: (t) => t.exContDividerTitle,
  description: (t) => t.exContDividerDescription,
  stage: const _DividerStage(),
  code: BenchCode([
    const BenchCodeLine('Column(children: ['),
    const BenchCodeLine("Text('Above'),", indent: 1),
    BenchCodeLine.live(dividerBench.dividerCode, indent: 1),
    const BenchCodeLine("Text('Below'),", indent: 1),
    const BenchCodeLine('])'),
  ]),
  controls: [
    stepLevel(
      label: (t) => t.exContThickness,
      min: 1,
      step: 1,
      steps: 4,
      initial: dividerBench.thickness.value,
      onChanged: dividerBench.setThickness,
      valueText: dividerBench.thicknessText,
    ),
    stepLevel(
      label: (t) => t.exContIndent,
      min: 0,
      step: 32,
      steps: 4,
      initial: dividerBench.indent.value,
      onChanged: dividerBench.setIndent,
      valueText: dividerBench.indentText,
    ),
  ],
);

class _DividerStage extends StatelessWidget {
  const _DividerStage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      // `// web:` the indent is continuous: it follows the state in the
      // browser (`BoundLength`; `Divider(indent:)` is a margin).
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Above', style: TextStyle(fontSize: 18)),
          Watch.field(
            dividerBench.thickness,
            count: 4,
            builder: (thickness) => Padding(
              padding: EdgeInsetsGeometry.symmetricLength(
                horizontal: dividerBench.indentPx.px,
              ),
              child: Divider(
                height: 40,
                thickness: 1.0 + thickness,
                color: ThemeColor.outline,
              ),
            ),
          ),
          const Text('Below', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------- CircleAvatar, Badge

/// The kinds of badge.
enum BadgeKind {
  /// A short label.
  label,

  /// A dot, without label.
  dot,

  /// `Badge.count`.
  count,
}

/// What the avatar and badge panel controls.
class AvatarBadgeViewModel extends ThorState {
  /// The kind of badge.
  final kind = state(BadgeKind.label);

  /// The avatar's radius, in steps of 12 px from 24.
  final radius = state(1);

  /// Whether the badge uses an accent color.
  final accent = state(false);

  /// The number next to the radius Level.
  String radiusText() => '${24 + radius.value * 12} px';

  /// The avatar line.
  String avatarCode() =>
      'CircleAvatar(radius: ${24 + radius.value * 12}, child: Icon(Icons.person, size: 32)),';

  /// The badge line.
  String badgeCode() {
    final color = accent.value ? 'backgroundColor: Color(0xFF0F766E), ' : '';
    return switch (kind.value) {
      BadgeKind.label =>
        "Badge(${color}label: Text('3'), child: Icon(Icons.notifications, size: 32)),",
      BadgeKind.dot =>
        'Badge(${color}child: Icon(Icons.notifications, size: 32)),',
      BadgeKind.count =>
        'Badge.count(${color}count: 1280, child: Icon(Icons.notifications, size: 32)),',
    };
  }

  /// What the kind Switch calls.
  void setKind(Set<BadgeKind> value) => kind.value = value.first;

  /// What the accent Switch calls.
  void setAccent(bool value) => accent.value = value;

  /// What the radius Level calls.
  void setRadius(double value) => radius.value = ((value - 24) / 12).round();
}

/// One instance, at the top level.
final avatarBadge = AvatarBadgeViewModel();

/// `cat-avatar-badge`.
final avatarBadgeBench = BenchExample(
  title: (t) => t.exContAvatarTitle,
  description: (t) => t.exContAvatarDescription,
  stage: const _AvatarBadgeStage(),
  code: BenchCode([
    const BenchCodeLine('Row(children: ['),
    BenchCodeLine.live(avatarBadge.avatarCode, indent: 1),
    BenchCodeLine.live(avatarBadge.badgeCode, indent: 1),
    const BenchCodeLine('])'),
  ]),
  controls: [
    BenchSwitch<BadgeKind>(
      label: (t) => t.exContBadge,
      value: avatarBadge.kind.value,
      onChanged: avatarBadge.setKind,
      segments: [
        BenchSegment(BadgeKind.label, label: (t) => t.exContBadgeLabel),
        BenchSegment(BadgeKind.dot, label: (t) => t.exContBadgeDot),
        BenchSegment(BadgeKind.count, label: (t) => t.exContBadgeCount),
      ],
    ),
    boolSwitch(
      label: (t) => t.exContAccent,
      value: avatarBadge.accent.value,
      onChanged: avatarBadge.setAccent,
    ),
    stepLevel(
      label: (t) => t.exContRadius,
      min: 24,
      step: 12,
      steps: 4,
      initial: avatarBadge.radius.value,
      onChanged: avatarBadge.setRadius,
      valueText: avatarBadge.radiusText,
    ),
  ],
);

class _AvatarBadgeStage extends StatelessWidget {
  const _AvatarBadgeStage();

  @override
  Widget build(BuildContext context) => Watch.field(
    avatarBadge.kind,
    builder: (kind) => Watch.field(
      avatarBadge.radius,
      count: 4,
      builder: (radius) => Watch.field(
        avatarBadge.accent,
        builder: (accent) {
          final color = accent ? const Color(0xFF0F766E) : null;
          const bell = Icon(Icons.notifications, size: 32);
          return Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 28,
            children: [
              CircleAvatar(
                radius: 24.0 + radius * 12,
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: const Color(0xFFFFFFFF),
                child: const Icon(Icons.person, size: 32),
              ),
              switch (kind) {
                BadgeKind.label => Badge(
                  backgroundColor: color,
                  label: const Text('3'),
                  child: bell,
                ),
                BadgeKind.dot => Badge(backgroundColor: color, child: bell),
                BadgeKind.count => Badge.count(
                  backgroundColor: color,
                  count: 1280,
                  child: bell,
                ),
              },
            ],
          );
        },
      ),
    ),
  );
}

// ----------------------------------------------------------------------- Chip

/// The chips of the bench.
enum ChipKind {
  /// `Chip`.
  chip,

  /// `Chip` with an `avatar`.
  avatar,

  /// `ActionChip`.
  action,
}

/// What the Chip panel controls.
class ChipBenchViewModel extends ThorState {
  /// The kind.
  final kind = state(ChipKind.chip);

  /// Whether the chip can be deleted (`onDeleted`).
  final deletable = state(false);

  /// How many times the chip was pressed or deleted.
  final taps = state(0);

  /// The taps, as text.
  String tapsText() => '${taps.value}';

  /// The constructor line.
  String headCode() => switch (kind.value) {
    ChipKind.chip => "Chip(label: Text('Sugar free'),",
    ChipKind.avatar =>
      "Chip(avatar: Icon(Icons.star, size: 16), label: Text('Favorite'),",
    ChipKind.action =>
      "ActionChip(label: Text('Add note'), onPressed: chip.tap,",
  };

  /// The `onDeleted` line.
  String deletedCode() => kind.value != ChipKind.action && deletable.value
      ? 'onDeleted: chip.tap,'
      : '// no onDeleted';

  /// What the chips call.
  void tap() => taps.value++;

  /// What the kind Switch calls.
  void setKind(Set<ChipKind> value) => kind.value = value.first;

  /// What the deletable Switch calls.
  void setDeletable(bool value) => deletable.value = value;
}

/// One instance, at the top level.
final chip = ChipBenchViewModel();

/// `cat-chip`.
final chipBench = BenchExample(
  title: (t) => t.exContChipTitle,
  description: (t) => t.exContChipDescription,
  stage: const _ChipStage(),
  code: BenchCode([
    BenchCodeLine.live(chip.headCode),
    BenchCodeLine.live(chip.deletedCode, indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    BenchSwitch<ChipKind>(
      label: (t) => t.exCatVariant,
      value: chip.kind.value,
      onChanged: chip.setKind,
      segments: [
        BenchSegment(ChipKind.chip, label: (t) => t.exContChipPlain),
        BenchSegment(ChipKind.avatar, label: (t) => t.exContChipAvatar),
        BenchSegment(ChipKind.action, label: (t) => t.exContChipAction),
      ],
    ),
    boolSwitch(
      label: (t) => t.exContDeletable,
      value: chip.deletable.value,
      onChanged: chip.setDeletable,
    ),
  ],
);

class _ChipStage extends StatelessWidget {
  const _ChipStage();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 14,
      children: [
        Watch.field(
          chip.kind,
          builder: (kind) => Watch.field(
            chip.deletable,
            builder: (deletable) {
              final onDeleted = deletable ? chip.tap : null;
              return switch (kind) {
                ChipKind.chip => Chip(
                  label: const Text('Sugar free'),
                  onDeleted: onDeleted,
                ),
                ChipKind.avatar => Chip(
                  avatar: const Icon(Icons.star, size: 16),
                  label: const Text('Favorite'),
                  onDeleted: onDeleted,
                ),
                ChipKind.action => ActionChip(
                  label: const Text('Add note'),
                  onPressed: chip.tap,
                ),
              };
            },
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            const Text(
              'Taps',
              style: TextStyle(
                fontSize: 13,
                color: ThemeColor.onSurfaceVariant,
              ),
            ),
            Watch(
              chip.tapsText,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- Tooltip

/// What the Tooltip panel controls.
class TooltipBenchViewModel extends ThorState {
  /// Whether the bubble goes below.
  final below = state(true);

  /// Whether the message is long.
  final long = state(false);

  /// The delay, in steps of 250 ms.
  final wait = state(0);

  /// The number next to the delay Level.
  String waitText() => '${wait.value * 250} ms';

  /// The `message` line.
  String messageCode() => long.value
      ? "message: 'Saves automatically every minute, and when you close the tab',"
      : "message: 'Saves automatically every minute',";

  /// The placement line.
  String placementCode() => 'preferBelow: ${below.value},';

  /// The delay line.
  String waitCode() =>
      'waitDuration: Duration(milliseconds: ${wait.value * 250}),';

  /// What the button calls: nothing, it only has to be enabled.
  void noop() {}

  /// What the below Switch calls.
  void setBelow(Set<bool> value) => below.value = value.first;

  /// What the long Switch calls.
  void setLong(bool value) => long.value = value;

  /// What the delay Level calls.
  void setWait(double value) => wait.value = (value / 250).round();
}

/// One instance, at the top level.
final tooltipBench = TooltipBenchViewModel();

/// `cat-tooltip`.
final tooltipBenchExample = BenchExample(
  title: (t) => t.exContTooltipTitle,
  description: (t) => t.exContTooltipDescription,
  stage: const _TooltipStage(),
  code: BenchCode([
    const BenchCodeLine('Tooltip('),
    BenchCodeLine.live(tooltipBench.messageCode, indent: 1),
    BenchCodeLine.live(tooltipBench.placementCode, indent: 1),
    BenchCodeLine.live(tooltipBench.waitCode, indent: 1),
    const BenchCodeLine(
      "child: OutlinedButton(…, child: Text('Save')),",
      indent: 1,
    ),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<bool>(
      label: (t) => t.exContPlacement,
      value: tooltipBench.below.value,
      onChanged: tooltipBench.setBelow,
      segments: [
        BenchSegment(true, label: (t) => t.exContBelow),
        BenchSegment(false, label: (t) => t.exContAbove),
      ],
    ),
    boolSwitch(
      label: (t) => t.exContLongMessage,
      value: tooltipBench.long.value,
      onChanged: tooltipBench.setLong,
    ),
    stepLevel(
      label: (t) => t.exContDelay,
      min: 0,
      step: 250,
      steps: 5,
      initial: tooltipBench.wait.value,
      onChanged: tooltipBench.setWait,
      valueText: tooltipBench.waitText,
      unit: ' ms',
    ),
  ],
);

class _TooltipStage extends StatelessWidget {
  const _TooltipStage();

  @override
  Widget build(BuildContext context) {
    return Watch.field(
      tooltipBench.wait,
      count: 5,
      builder: (wait) => Watch.field(
        tooltipBench.below,
        builder: (below) => Watch.field(
          tooltipBench.long,
          builder: (long) {
            final message = long
                ? 'Saves automatically every minute, and when you close the tab'
                : 'Saves automatically every minute';
            // The real bubble only shows while the pointer rests on the
            // button; the preview draws it where and as it would show.
            final button = Tooltip(
              message: message,
              preferBelow: below,
              waitDuration: Duration(milliseconds: wait * 250),
              child: OutlinedButton(
                onPressed: tooltipBench.noop,
                child: const Text('Save'),
              ),
            );
            final bubble = BubblePreview(message);
            return Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                PreviewFrame(
                  child: SizedBox(
                    height: 130,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 8,
                      children: below ? [button, bubble] : [bubble, button],
                    ),
                  ),
                ),
                NoteRow(label: 'Delay', value: Watch(tooltipBench.waitText)),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ DataTable

/// The column a table is sorted by.
enum SortBy {
  /// No sort arrow.
  none,

  /// The first column.
  product,

  /// The second column.
  sold,

  /// The third column.
  price,
}

/// What the DataTable panel controls.
class DataTableBenchViewModel extends ThorState {
  /// The sorted column.
  final sortBy = state(SortBy.sold);

  /// The sort direction.
  final ascending = state(false);

  /// `showCheckboxColumn`.
  final checkboxes = state(false);

  /// How many rows, minus one.
  final rows = state(2);

  /// The number next to the rows Level.
  String rowsText() => '${rows.value + 1}';

  /// The sort lines.
  String sortCode() => sortBy.value == SortBy.none
      ? '// no sortColumnIndex'
      : 'sortColumnIndex: ${sortBy.value.index - 1}, sortAscending: ${ascending.value},';

  /// The checkbox line.
  String checkboxCode() => 'showCheckboxColumn: ${checkboxes.value},';

  /// The rows line.
  String rowsCode() => checkboxes.value
      ? 'rows: [… ${rows.value + 1} DataRow(onSelectChanged: …) …],'
      : 'rows: [… ${rows.value + 1} DataRow …],';

  /// The line that orders the data the rows are made from.
  String orderCode() => sortBy.value == SortBy.none
      ? '// rows in the order they come'
      : 'data.sort((a, b) => a.${const ['', 'name', 'sold', 'price'][sortBy.value.index]}.compareTo(b.${const ['', 'name', 'sold', 'price'][sortBy.value.index]})${ascending.value ? '' : ' * -1'});';

  /// What a row's checkbox calls (the page keeps no selection).
  void select(bool? value) {}

  /// What the sort Switch calls.
  void setSortBy(Set<SortBy> value) => sortBy.value = value.first;

  /// What the direction Switch calls.
  void setAscending(bool value) => ascending.value = value;

  /// What the checkbox Switch calls.
  void setCheckboxes(bool value) => checkboxes.value = value;

  /// What the rows Level calls.
  void setRows(double value) => rows.value = value.round() - 1;
}

/// One instance, at the top level.
final dataTableBench = DataTableBenchViewModel();

/// `cat-data-table`.
final dataTableBenchExample = BenchExample(
  title: (t) => t.exContTableTitle,
  description: (t) => t.exContTableDescription,
  stage: const _DataTableStage(),
  code: BenchCode([
    BenchCodeLine.live(dataTableBench.orderCode),
    const BenchCodeLine('DataTable('),
    BenchCodeLine.live(dataTableBench.sortCode, indent: 1),
    BenchCodeLine.live(dataTableBench.checkboxCode, indent: 1),
    const BenchCodeLine('columns: [', indent: 1),
    const BenchCodeLine("DataColumn(label: Text('Product')),", indent: 2),
    const BenchCodeLine(
      "DataColumn(label: Text('Sold'), numeric: true),",
      indent: 2,
    ),
    const BenchCodeLine(
      "DataColumn(label: Text('Price'), numeric: true),",
      indent: 2,
    ),
    const BenchCodeLine('],', indent: 1),
    BenchCodeLine.live(dataTableBench.rowsCode, indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    BenchSwitch<SortBy>(
      label: (t) => t.exContSortBy,
      value: dataTableBench.sortBy.value,
      onChanged: dataTableBench.setSortBy,
      segments: [
        BenchSegment(SortBy.none, label: (t) => t.exContSortNone),
        BenchSegment(SortBy.product, label: (t) => t.exContSortFirst),
        BenchSegment(SortBy.sold, label: (t) => t.exContSortSecond),
        BenchSegment(SortBy.price, label: (t) => t.exContSortThird),
      ],
    ),
    boolSwitch(
      label: (t) => t.exContAscending,
      value: dataTableBench.ascending.value,
      onChanged: dataTableBench.setAscending,
    ),
    boolSwitch(
      label: (t) => t.exContCheckboxes,
      value: dataTableBench.checkboxes.value,
      onChanged: dataTableBench.setCheckboxes,
    ),
    stepLevel(
      label: (t) => t.exContRows,
      min: 1,
      step: 1,
      steps: 3,
      initial: dataTableBench.rows.value,
      onChanged: dataTableBench.setRows,
      valueText: dataTableBench.rowsText,
      unit: '',
    ),
  ],
);

class _DataTableStage extends StatelessWidget {
  const _DataTableStage();

  @override
  Widget build(BuildContext context) {
    final money = LocaleFormat(const Locale('en'));
    const data = [
      ('Clay-pot coffee', 128, 45),
      ('Concha', 96, 18),
      ('Hot chocolate', 54, 52),
    ];
    return Watch.field(
      dataTableBench.sortBy,
      builder: (sortBy) => Watch.field(
        dataTableBench.ascending,
        builder: (ascending) => Watch.field(
          dataTableBench.checkboxes,
          builder: (checkboxes) => Watch.field(
            dataTableBench.rows,
            count: 3,
            builder: (rows) {
              // The rows follow the sort, so the arrow is not the only sign.
              final ordered = [...data.take(rows + 1)];
              if (sortBy != SortBy.none) {
                ordered.sort(
                  (a, b) => switch (sortBy) {
                    SortBy.product => a.$1.compareTo(b.$1),
                    SortBy.sold => a.$2.compareTo(b.$2),
                    _ => a.$3.compareTo(b.$3),
                  },
                );
                if (!ascending) {
                  ordered.replaceRange(0, ordered.length, ordered.reversed);
                }
              }
              // `// web:` a table wider than the stage scrolls in its own box.
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 24,
                  horizontalMargin: 16,
                  sortColumnIndex: sortBy == SortBy.none
                      ? null
                      : sortBy.index - 1,
                  sortAscending: ascending,
                  showCheckboxColumn: checkboxes,
                  columns: [
                    const DataColumn(label: Text('Product')),
                    const DataColumn(label: Text('Sold'), numeric: true),
                    const DataColumn(label: Text('Price'), numeric: true),
                  ],
                  rows: [
                    for (final (name, sold, price) in ordered)
                      DataRow(
                        onSelectChanged: checkboxes
                            ? dataTableBench.select
                            : null,
                        cells: [
                          DataCell(Text(name)),
                          DataCell(Text('$sold')),
                          DataCell(
                            Text(
                              money.currency(
                                price,
                                name: 'USD',
                                decimalDigits: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- ExpansionTile

/// What the ExpansionTile panel controls.
class ExpansionBenchViewModel extends ThorState {
  /// `initiallyExpanded` of the first tile.
  final open = state(true);

  /// Whether the second tile has a `subtitle`.
  final subtitle = state(true);

  /// Whether both share a `name` (an accordion).
  final accordion = state(false);

  /// The first tile's line.
  String openCode() => 'initiallyExpanded: ${open.value},';

  /// The second tile's subtitle line.
  String subtitleCode() =>
      subtitle.value ? "subtitle: Text('Payments')," : '// no subtitle';

  /// The `name` line.
  String nameCode() => accordion.value
      ? "name: 'faq', // opening one closes the other"
      : '// no name';

  /// What the open Switch calls.
  void setOpen(bool value) => open.value = value;

  /// What the subtitle Switch calls.
  void setSubtitle(bool value) => subtitle.value = value;

  /// What the accordion Switch calls.
  void setAccordion(bool value) => accordion.value = value;
}

/// One instance, at the top level.
final expansionBench = ExpansionBenchViewModel();

/// `cat-expansion-tile`.
final expansionTileBench = BenchExample(
  title: (t) => t.exContExpansionTitle,
  description: (t) => t.exContExpansionDescription,
  stage: const _ExpansionStage(),
  code: BenchCode([
    const BenchCodeLine('ExpansionTile('),
    const BenchCodeLine("title: Text('Do you deliver?'),", indent: 1),
    BenchCodeLine.live(expansionBench.openCode, indent: 1),
    BenchCodeLine.live(expansionBench.nameCode, indent: 1),
    const BenchCodeLine(
      "children: [Text('Yes, across the whole city, 9 am to 6 pm.')],",
      indent: 1,
    ),
    const BenchCodeLine('),'),
    const BenchCodeLine('ExpansionTile('),
    const BenchCodeLine("title: Text('Can I pay in cash?'),", indent: 1),
    BenchCodeLine.live(expansionBench.subtitleCode, indent: 1),
    BenchCodeLine.live(expansionBench.nameCode, indent: 1),
    const BenchCodeLine(
      "children: [Text('Yes, when you pick up in store.')],",
      indent: 1,
    ),
    const BenchCodeLine(')'),
  ]),
  controls: [
    boolSwitch(
      label: (t) => t.exContOpen,
      value: expansionBench.open.value,
      onChanged: expansionBench.setOpen,
    ),
    boolSwitch(
      label: (t) => t.exContSubtitle,
      value: expansionBench.subtitle.value,
      onChanged: expansionBench.setSubtitle,
    ),
    boolSwitch(
      label: (t) => t.exContAccordion,
      value: expansionBench.accordion.value,
      onChanged: expansionBench.setAccordion,
    ),
  ],
);

class _ExpansionStage extends StatelessWidget {
  const _ExpansionStage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: Watch.field(
        expansionBench.open,
        builder: (open) => Watch.field(
          expansionBench.subtitle,
          builder: (subtitle) => Watch.field(
            expansionBench.accordion,
            builder: (accordion) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Center(
                  child: NoteRow(
                    label: 'On open',
                    value: Text(
                      accordion ? 'the other closes' : 'each on its own',
                    ),
                  ),
                ),
                ExpansionTile(
                  title: const Text('Do you deliver?'),
                  initiallyExpanded: open,
                  name: accordion ? 'faq' : null,
                  children: [
                    const Text('Yes, across the whole city, 9 am to 6 pm.'),
                  ],
                ),
                ExpansionTile(
                  title: const Text('Can I pay in cash?'),
                  subtitle: subtitle ? const Text('Payments') : null,
                  name: accordion ? 'faq' : null,
                  children: [const Text('Yes, when you pick up in store.')],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

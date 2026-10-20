/// The guide as plain Markdown, for readers that are not browsers: one
/// `.md` per page, `llms.txt` (an index) and `llms-full.txt` (everything),
/// written at export (`bin/export.dart`) next to the pages.
library;

import 'dart:io';

import '../i18n/docs_locale.dart';
import 'directives.dart';
import 'library.dart';

/// The Markdown of [guide] in [locale] for a reader without the site's
/// components: callouts as quotes (`> **Ojo:** …`), tabs as headings, the
/// live examples left out and every link absolute ([baseUrl] + the page's
/// path in [locale]; a path when there is none). A language without the page
/// gets the default language's. Links and code are kept as the guide writes
/// them.
String guideMarkdown(
  Guide guide, {
  String locale = defaultLocale,
  String baseUrl = '',
  String? dir,
}) {
  final root = dir ?? docsDir();
  final own = guide.file(locale);
  final file = File('$root/$own').existsSync()
      ? own
      : guide.file(defaultLocale);
  final fileDir = file.substring(0, file.lastIndexOf('/'));
  return _plain(
    File('$root/$file').readAsStringSync(),
    fileDir,
    _origin(baseUrl),
    locale,
  ).trimRight();
}

String _origin(String baseUrl) => baseUrl.replaceFirst(RegExp(r'/+$'), '');

/// The label of a callout [name] in the language the page is written in
/// (the folder of [fileDir] after `guia/`: `guia/es`, `guia/en/examples`).
String _label(String fileDir, String name) {
  final t = messagesFor(RegExp(r'^guia/([\w-]+)').firstMatch(fileDir)?[1]);
  return switch (name) {
    'note' => t.calloutNote,
    'tip' => t.calloutTip,
    'warning' => t.calloutWarning,
    'danger' => t.calloutDanger,
    _ => t.calloutFlutter,
  };
}

String _plain(String markdown, String fileDir, String origin, String locale) {
  // Every piece (text or directive) is a block of its own: a directive
  // written right after a paragraph, or before the next one, must not
  // glue to it.
  final blocks = <String>[];
  for (final part in splitDirectives(markdown)) {
    if (part is! Directive) {
      blocks.add(_links(part as String, fileDir, origin, locale));
      continue;
    }
    final body = _plain(part.body, fileDir, origin, locale);
    blocks.add(switch (part.name) {
      'note' || 'tip' || 'warning' || 'danger' || 'flutter' => _quote(
        part.arg.isEmpty ? _label(fileDir, part.name) : part.arg,
        body,
      ),
      // A live widget: its page shows it; the text around it says it all.
      'example' => body,
      'tabs' => body.replaceAllMapped(
        RegExp(r'^@tab\s+(.+)$', multiLine: true),
        (m) => '#### ${m[1]!.trim()}',
      ),
      'files' => '```text\n$body\n```',
      _ => body,
    });
  }
  return [
    for (final block in blocks)
      if (block.trim().isNotEmpty)
        block.replaceAll(RegExp(r'^\n+'), '').replaceAll(RegExp(r'\n+$'), ''),
  ].join('\n\n');
}

/// `> **Label:** first line` and the rest quoted.
String _quote(String label, String body) {
  final lines = body.trim().split('\n');
  return [
    '> **$label:** ${lines.first}',
    for (final line in lines.skip(1)) line.isEmpty ? '>' : '> $line',
  ].join('\n');
}

final _fenceLine = RegExp(r'^\s*(```|~~~)');
final _inlineCode = RegExp(r'(`+)[^`].*?\1');
final _link = RegExp(r'\]\(([^)\s]+)(\s+"[^"]*")?\)');

/// [text] with every link outside code pointing at the site.
String _links(String text, String fileDir, String origin, String locale) {
  var fenced = false;
  return text
      .split('\n')
      .map((line) {
        if (_fenceLine.hasMatch(line)) {
          fenced = !fenced;
          return line;
        }
        if (fenced) return line;
        // Inline code (`[a](b.md)`) is left as written.
        return line.splitMapJoin(
          _inlineCode,
          onMatch: (m) => m[0]!,
          onNonMatch: (text) => text.replaceAllMapped(_link, (m) {
            final href = localizePath(locale, rewriteLink(m[1]!, fileDir));
            final absolute = href.startsWith('/') ? '$origin$href' : href;
            // An anchor of this page stays one; a page of the site is its
            // source.
            final target = _guideSource(absolute, origin) ?? absolute;
            return ']($target${m[2] ?? ''})';
          }),
        );
      })
      .join('\n');
}

/// A guide page's address as its `.md` (what an agent should read), or null.
String? _guideSource(String url, String origin) {
  final sections = {
    for (final s in guideSections) ...[s.slug, ...s.slugs.values],
  }.join('|');
  final match = RegExp(
    '^${RegExp.escape(origin)}(/[\\w-]+/(?:$sections)/[\\w-]+)(#.*)?\$',
  ).firstMatch(url);
  return match == null ? null : '$origin${match[1]}.md${match[2] ?? ''}';
}

/// A guide's summary: its description cut at a sentence (or a word, with
/// `…`), in one line of at most [max] characters.
String summary(String? description, {int max = 180}) {
  final text = (description ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length <= max) return text;
  final cut = text.substring(0, max);
  final end = cut.lastIndexOf('. ');
  if (end > 60) return cut.substring(0, end + 1);
  // No sentence to stop at: a whole word, never a `;` or `:` left hanging.
  final word = cut.lastIndexOf(' ');
  final head = word > 60 ? cut.substring(0, word) : cut;
  return '${head.replaceAll(RegExp(r'[\s,;:]+$'), '')}…';
}

/// `llms.txt` in [locale]: [intro] (what an agent needs first), then a link
/// to each guide's Markdown by section, the API reference and the error
/// codes (llmstxt.org). The sections after the reference are the optional
/// ones.
String llmsTxt(
  String intro, {
  String locale = defaultLocale,
  String baseUrl = '',
}) {
  final origin = _origin(baseUrl);
  final t = messagesFor(locale);
  final out = StringBuffer(intro.trimRight())..write('\n');
  void list(Iterable<Guide> guides) {
    for (final guide in guides) {
      final page = loadGuide(guide, locale)?.page;
      final text = summary(page?.description);
      out.write(
        '- [${page?.title ?? guide.title(t)}]'
        '($origin${localizePath(locale, guide.path)}.md)'
        '${text.isEmpty ? '' : ': $text'}\n',
      );
    }
  }

  final optional = [
    for (final section in guideSections)
      if (section.slug == componentsSection) section,
  ];
  for (final section in guideSections) {
    if (optional.contains(section)) continue;
    out.write('\n## ${section.title(t)}\n\n');
    list(section.guides);
  }
  out
    ..write('\n## ${t.llmsReferenceHeading}\n\n')
    ..write(
      '- [${t.llmsApiTitle}]($origin${localizePath(locale, '/api/thor_ui')}): '
      '${t.llmsApiDescription}\n',
    )
    ..write(
      '- [${t.llmsErrorsTitle}]($origin${localizePath(locale, '/errores')}): '
      '${t.llmsErrorsDescription}\n',
    )
    ..write(
      '- [${t.llmsFullTitle}]($origin/$locale/llms-full.txt): '
      '${t.llmsFullDescription}\n',
    )
    ..write('\n## Optional\n\n');
  for (final section in optional) {
    list(section.guides);
  }
  return out.toString();
}

/// `llms-full.txt` in [locale]: [intro] and then every guide's Markdown, in
/// reading order, each under its title and address.
String llmsFullTxt(
  String intro, {
  String locale = defaultLocale,
  String baseUrl = '',
  String? dir,
  List<Guide>? guides,
}) {
  final origin = _origin(baseUrl);
  final out = StringBuffer(intro.trimRight())..write('\n');
  for (final guide in guides ?? allGuides) {
    final page = loadGuide(guide, locale, dir: dir)?.page;
    out
      ..write('\n---\n\n')
      ..write('# ${page?.title ?? guide.slug}\n\n')
      ..write(
        '${messagesFor(locale).llmsSource('$origin${localizePath(locale, guide.path)}')}\n\n',
      )
      ..write(
        _anchored(
          _dropTitle(
            guideMarkdown(guide, locale: locale, baseUrl: baseUrl, dir: dir),
          ),
          guide.slugIn(locale),
          origin,
        ),
      )
      ..write('\n');
  }
  return out.toString();
}

final _heading = RegExp(r'^(#{2,3})\s+(.*?)\s*#*\s*$');
final _anchorLink = RegExp(r'\]\(#([^)\s]+)\)');

/// [markdown] of the guide [slug] made one page of a bigger file: the
/// headings that the site gives an id get an explicit anchor
/// (`<a id="slug-heading"></a>`, the same ids as the page, so the slug
/// keeps two pages' `## Uso` apart), and the links to a section (of this
/// page, or of another guide, as `.md#section`) point at those anchors.
/// Code is left as written.
String _anchored(String markdown, String slug, String origin) {
  final used = <String, int>{};
  var fenced = false;
  final guide = RegExp(
    '\\]\\(${RegExp.escape(origin)}/[\\w-]+/[\\w-]+/([\\w-]+)\\.md#([^)\\s]+)\\)',
  );
  return markdown
      .split('\n')
      .map((line) {
        if (_fenceLine.hasMatch(line)) {
          fenced = !fenced;
          return line;
        }
        if (fenced) return line;
        final heading = _heading.firstMatch(line);
        if (heading != null) {
          final base = headingId(heading[2]!.replaceAll(RegExp(r'[`*_]'), ''));
          final n = used[base] = (used[base] ?? -1) + 1;
          return '<a id="$slug-${n == 0 ? base : '$base-$n'}"></a>\n\n$line';
        }
        return line.splitMapJoin(
          _inlineCode,
          onMatch: (m) => m[0]!,
          onNonMatch: (text) => text
              .replaceAllMapped(_anchorLink, (m) => '](#$slug-${m[1]})')
              .replaceAllMapped(guide, (m) => '](#${m[1]}-${m[2]})'),
        );
      })
      .join('\n');
}

/// [markdown] without its `# Title` line (the page puts its own).
String _dropTitle(String markdown) =>
    markdown.replaceFirst(RegExp(r'^\s*# .*\n+'), '');

/// Writes the Markdown files under [outDir]: `<locale>/<section>/<slug>.md`
/// for each guide in each language, and `llms.txt` and `llms-full.txt` for
/// each one (`<locale>/llms.txt`; the default language's also at the site's
/// root). [intro] is the file whose text opens them all (`llms-intro.md`).
void writeMarkdownFiles(
  String outDir, {
  required String intro,
  String baseUrl = '',
  String? dir,
}) {
  final text = File(intro).readAsStringSync();
  for (final locale in docsLocales) {
    for (final guide in allGuides) {
      final file = File('$outDir${localizePath(locale, guide.path)}.md')
        ..parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${guideMarkdown(guide, locale: locale, baseUrl: baseUrl, dir: dir)}\n',
      );
    }
    final index = llmsTxt(text, locale: locale, baseUrl: baseUrl);
    final full = llmsFullTxt(text, locale: locale, baseUrl: baseUrl, dir: dir);
    for (final folder in [
      if (locale == defaultLocale) outDir,
      '$outDir/$locale',
    ]) {
      File('$folder/llms.txt').writeAsStringSync(index);
      File('$folder/llms-full.txt').writeAsStringSync(full);
    }
  }
}

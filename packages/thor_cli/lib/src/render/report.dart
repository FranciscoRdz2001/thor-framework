/// What `thor render` reports about one page: pure functions over the HTML
/// the server answered and what the browser saw (no `dart:io` besides
/// gzip), so the CLI, the MCP server and the tests share them.
library;

import 'dart:convert';
import 'dart:io' show gzip;
import '../errors.dart' show thorErrorsUrl;

/// One page as `thor render` saw it.
class RenderReport {
  /// The report of [target] (a route or a widget).
  RenderReport({
    required this.target,
    required this.status,
    required this.html,
    this.location,
    this.linkedCss = const {},
    this.browser,
    this.browserError,
    this.elapsed = Duration.zero,
  });

  /// The route (`/news/2?x=1`) or the widget (`lib/card.dart#Card`).
  final String target;

  /// The HTTP status.
  final int status;

  /// Where a redirect goes (`Location`).
  final String? location;

  /// The HTML the server answered.
  final String html;

  /// The linked stylesheets (`href` → content).
  final Map<String, String> linkedCss;

  /// What the browser saw, or null without one.
  final BrowserResult? browser;

  /// Why there is no browser part (not installed, failed).
  final String? browserError;

  /// How long the whole render took.
  final Duration elapsed;

  /// The page's own CSS (its `<style>` elements, the dev overlay's
  /// excluded), in order.
  String get inlineCss =>
      [for (final m in _styles.allMatches(html)) m[1]!].join('\n');

  /// Errors the server wrote for `thor dev` (`load`, actions, build).
  List<Map<String, Object?>> get serverErrors => [
    for (final m in _devErrors.allMatches(html))
      if (_json(m[1]!) case final Map<String, Object?> block) block,
  ];

  /// The `THOR-xxx` codes in the errors, the warnings and the console.
  Set<String> get codes => {
    for (final text in [
      ...serverErrors.map(jsonEncode),
      ...?browser?.warnings.map((w) => w.message),
      ...?browser?.console,
    ])
      for (final m in _code.allMatches(text)) m[0]!,
  };

  /// The accessibility outline: the browser's when there is one, else one
  /// read from the HTML.
  String get accessibility => browser?.aria ?? staticOutline(html);

  /// For `--json` and the MCP server. [full] includes HTML and CSS.
  Map<String, Object?> toJson({bool full = true}) => {
    'target': target,
    'status': status,
    'location': ?location,
    'elapsedMs': elapsed.inMilliseconds,
    'html': {
      'bytes': utf8.encode(html).length,
      'gzip': gzipSize(html),
      if (full) 'text': html,
    },
    'css': {
      'inlineBytes': utf8.encode(inlineCss).length,
      'linked': [
        for (final e in linkedCss.entries)
          {'href': e.key, 'bytes': utf8.encode(e.value).length},
      ],
      if (full) 'text': [inlineCss, ...linkedCss.values].join('\n'),
    },
    'errors': serverErrors,
    'warnings': [...?browser?.warnings.map((w) => w.toJson())],
    'console': [...?browser?.console],
    'codes': codes.toList()..sort(),
    'accessibility': accessibility,
    'screenshots': [...?browser?.screenshots.map((s) => s.toJson())],
    'browserError': ?browserError,
  };

  /// The report for a terminal: the numbers, the problems, the outline
  /// and where the screenshots are. [html] and [css] add those texts.
  String toText({bool html = false, bool css = false}) {
    final out = StringBuffer()
      ..writeln(
        '$target → $status${location == null ? '' : ' $location'}'
        '  (${elapsed.inMilliseconds} ms)',
      )
      ..writeln(
        'HTML ${_kb(utf8.encode(this.html).length)}'
        ' (${_kb(gzipSize(this.html))} gzip) · CSS inline '
        '${_kb(utf8.encode(inlineCss).length)}'
        '${linkedCss.isEmpty ? '' : ' + ${linkedCss.length} linked'}',
      );
    final errors = serverErrors;
    if (errors.isNotEmpty) {
      out.writeln('\nErrors (${errors.length}):');
      for (final e in errors) {
        out.writeln('  ✗ [${e['phase']}] ${e['type']}: ${e['message']}');
      }
    }
    final warnings = browser?.warnings ?? const [];
    if (warnings.isNotEmpty) {
      out.writeln('\nWarnings (${warnings.length}):');
      for (final w in warnings) {
        out.writeln(
          '  ! ${w.widget}: ${w.message}'
          '${w.source == null ? '' : '\n      ${w.source}'}',
        );
      }
    }
    final console = browser?.console ?? const [];
    if (console.isNotEmpty) {
      out.writeln('\nConsole (${console.length}):');
      for (final c in console) {
        out.writeln('  $c');
      }
    }
    if (codes.isNotEmpty) {
      out.writeln(
        '\nError pages: ${[for (final c in codes.toList()..sort()) '$thorErrorsUrl$c'].join(', ')}',
      );
    }
    out
      ..writeln('\nAccessibility${browser == null ? ' (from the HTML)' : ''}:')
      ..writeln(_indent(accessibility.trimRight()));
    final shots = browser?.screenshots ?? const [];
    if (shots.isNotEmpty) {
      out.writeln('\nScreenshots:');
      for (final s in shots) {
        out.writeln(
          '  ${s.width}px  ${s.path}'
          '${s.overflowX ? '  ⚠ horizontal scroll' : ''}',
        );
      }
    } else if (browserError != null) {
      out.writeln('\nNo browser: $browserError');
    }
    if (html) out.writeln('\n--- HTML ---\n${this.html}');
    if (css) {
      out.writeln('\n--- CSS ---\n$inlineCss');
      for (final e in linkedCss.entries) {
        out.writeln('/* ${e.key} */\n${e.value}');
      }
    }
    return out.toString();
  }
}

/// What the browser part saw at each width.
class BrowserResult {
  /// A browser result.
  const BrowserResult({
    required this.aria,
    required this.warnings,
    required this.console,
    required this.screenshots,
  });

  /// From the browser script's JSON.
  factory BrowserResult.fromJson(Map<String, Object?> json) => BrowserResult(
    aria: json['aria'] as String?,
    warnings: [
      for (final w in (json['warnings'] as List? ?? const []))
        InspectorWarning.fromJson((w as Map).cast()),
    ],
    console: [for (final c in (json['console'] as List? ?? const [])) '$c'],
    screenshots: [
      for (final s in (json['screenshots'] as List? ?? const []))
        Screenshot.fromJson((s as Map).cast()),
    ],
  );

  /// Playwright's ARIA snapshot of the body (YAML), at the first width.
  final String? aria;

  /// The debug inspector's layout warnings (`data-thor-warning`).
  final List<InspectorWarning> warnings;

  /// Console errors and warnings, and uncaught exceptions.
  final List<String> console;

  /// One per width.
  final List<Screenshot> screenshots;
}

/// A warning of the debug inspector on one element.
class InspectorWarning {
  /// A warning.
  const InspectorWarning(this.widget, this.message, this.source);

  /// From JSON.
  factory InspectorWarning.fromJson(Map<String, Object?> json) =>
      InspectorWarning(
        '${json['widget'] ?? '?'}',
        '${json['message'] ?? ''}',
        json['source'] as String?,
      );

  /// The widget's name (`data-thor`).
  final String widget;

  /// What the inspector says.
  final String message;

  /// The app code that built it (`data-thor-src`), if known.
  final String? source;

  /// For JSON.
  Map<String, Object?> toJson() => {
    'widget': widget,
    'message': message,
    'source': ?source,
  };
}

/// A screenshot at one width.
class Screenshot {
  /// A screenshot.
  const Screenshot(this.width, this.path, {this.overflowX = false});

  /// From JSON.
  factory Screenshot.fromJson(Map<String, Object?> json) => Screenshot(
    (json['width'] as num).toInt(),
    json['path'] as String,
    overflowX: json['overflowX'] == true,
  );

  /// The viewport width.
  final int width;

  /// The PNG.
  final String path;

  /// Whether the page scrolls sideways at this width.
  final bool overflowX;

  /// For JSON.
  Map<String, Object?> toJson() => {
    'width': width,
    'path': path,
    'overflowX': overflowX,
  };
}

/// Bytes of [text] gzipped.
int gzipSize(String text) => gzip.encode(utf8.encode(text)).length;

/// An outline of [html] for a reader without a browser: landmarks,
/// headings, links, buttons, form fields and images, indented by nesting.
String staticOutline(String html) {
  final body = html.indexOf('<body');
  final source = body < 0 ? html : html.substring(body);
  final out = StringBuffer();
  final stack = <_Open>[];
  var depth = 0;
  for (final m in _token.allMatches(source.replaceAll(_skipped, ''))) {
    if (m[4] != null) {
      final text = _decode(m[4]!).trim();
      if (text.isNotEmpty) {
        for (final open in stack) {
          if (open.collect) {
            open.text.write('${open.text.isEmpty ? '' : ' '}$text');
          }
        }
      }
      continue;
    }
    final closing = m[1] == '/';
    final tag = m[2]!.toLowerCase();
    final attrs = m[3] ?? '';
    if (_voids.contains(tag)) {
      if (!closing) {
        final line = _voidLine(tag, attrs);
        if (line != null) out.writeln('${'  ' * depth}- $line');
      }
      continue;
    }
    if (!closing) {
      final role = _role(tag, attrs);
      final open = _Open(tag, role, attrs, collect: _named.contains(role));
      stack.add(open);
      if (role != null && !open.collect) {
        out.writeln('${'  ' * depth}- $role${_label(attrs)}');
        depth++;
      }
    } else {
      final i = stack.lastIndexWhere((o) => o.tag == tag);
      if (i < 0) continue;
      final open = stack[i];
      stack.removeRange(i, stack.length);
      if (open.role == null) continue;
      if (open.collect) {
        final name = _attr(open.attrs, 'aria-label') ?? open.text.toString();
        out.writeln(
          '${'  ' * depth}- ${open.role} "${name.trim()}"'
          '${open.role == 'link' ? ' → ${_attr(open.attrs, 'href') ?? ''}' : ''}',
        );
      } else {
        depth--;
      }
    }
  }
  return out.toString();
}

final class _Open {
  _Open(this.tag, this.role, this.attrs, {required this.collect});
  final String tag;
  final String? role;
  final String attrs;
  final bool collect;
  final text = StringBuffer();
}

String? _role(String tag, String attrs) =>
    _attr(attrs, 'role') ??
    switch (tag) {
      'header' => 'banner',
      'nav' => 'navigation',
      'main' => 'main',
      'aside' => 'complementary',
      'footer' => 'contentinfo',
      'form' => 'form',
      'dialog' => 'dialog',
      'ul' || 'ol' => 'list',
      'table' => 'table',
      'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6' => 'heading ${tag[1]}',
      'a' when _attr(attrs, 'href') != null => 'link',
      'button' => 'button',
      'label' => 'label',
      'summary' => 'button',
      _ => null,
    };

const _named = {
  'link',
  'button',
  'label',
  'heading 1',
  'heading 2',
  'heading 3',
  'heading 4',
  'heading 5',
  'heading 6',
};

String? _voidLine(String tag, String attrs) {
  switch (tag) {
    case 'img':
      final alt = _attr(attrs, 'alt');
      return alt == null ? 'img (no alt!)' : 'img "$alt"';
    case 'input':
      final type = _attr(attrs, 'type') ?? 'text';
      if (type == 'hidden') return null;
      final name =
          _attr(attrs, 'aria-label') ??
          _attr(attrs, 'placeholder') ??
          _attr(attrs, 'name') ??
          '';
      return 'input[$type] "$name"';
  }
  return null;
}

String _label(String attrs) {
  final label = _attr(attrs, 'aria-label');
  return label == null ? '' : ' "$label"';
}

String? _attr(String attrs, String name) {
  final m = RegExp('(?:^|\\s)$name="([^"]*)"').firstMatch(attrs);
  return m == null ? null : _decode(m[1]!);
}

String _decode(String text) => text
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');

String _kb(int bytes) =>
    bytes < 1024 ? '$bytes B' : '${(bytes / 1024).toStringAsFixed(1)} KB';

String _indent(String text) =>
    text.isEmpty ? '  (empty)' : text.split('\n').map((l) => '  $l').join('\n');

Object? _json(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}

const _voids = {'img', 'input', 'br', 'hr', 'meta', 'link', 'source', 'wbr'};

final _token = RegExp(r'<(/?)([a-zA-Z][a-zA-Z0-9-]*)([^>]*)>|([^<]+)');
final _skipped = RegExp(
  r'<(script|style|template|svg)\b[^>]*>[\s\S]*?</\1>|<!--[\s\S]*?-->',
  caseSensitive: false,
);
final _styles = RegExp(r'<style\b[^>]*>([\s\S]*?)</style>');
final _devErrors = RegExp(
  r'<script type="application/json" id="thor-dev-error">([\s\S]*?)</script>',
);
final _code = RegExp(r'THOR-[A-Z]\d{3}');

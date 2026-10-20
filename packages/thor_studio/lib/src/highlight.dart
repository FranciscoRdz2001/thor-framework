// Syntax highlighting at render time: code blocks reach the browser as
// colored spans, with no highlighting script.
import 'dart:convert';

import 'package:thor_ui/thor_ui.dart';

import 'tokens/color/studio_syntax_colors.dart';

/// A highlighted token kind.
enum CodeToken {
  /// `class`, `final`, `return`…
  keyword,

  /// String literals.
  string,

  /// Numbers.
  number,

  /// Capitalized names.
  type,

  /// Comments.
  comment,

  /// Everything else.
  plain,
}

const _dartKeywords = {
  'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', 'case', //
  'catch', 'class', 'const', 'continue', 'covariant', 'default', 'deferred',
  'do', 'dynamic', 'else', 'enum', 'export', 'extends', 'extension',
  'external', 'factory', 'false', 'final', 'finally', 'for', 'get', 'hide',
  'if', 'implements', 'import', 'in', 'interface', 'is', 'late', 'library',
  'mixin', 'new', 'null', 'of', 'on', 'operator', 'part', 'required',
  'rethrow', 'return', 'sealed', 'set', 'show', 'static', 'super', 'switch',
  'sync', 'this', 'throw', 'true', 'try', 'typedef', 'var', 'void', 'when',
  'while', 'with', 'yield',
};

// Built-in types written in lowercase.
const _dartBuiltinTypes = {'int', 'double', 'num', 'bool'};

final _dartToken = RegExp(
  r'(?<comment>//[^\n]*|/\*[\s\S]*?\*/)'
  r'|(?<annotation>@[A-Za-z_][A-Za-z0-9_]*)'
  r"|(?<string>r?'''[\s\S]*?'''|"
  r'r?"""[\s\S]*?"""|'
  r"r?'(?:\\.|[^'\\\n])*'|"
  r'r?"(?:\\.|[^"\\\n])*")'
  r'|(?<number>\b(?:0x[0-9a-fA-F]+|\d[\d_]*(?:\.\d+)?(?:e[+-]?\d+)?)\b)'
  r'|(?<word>[A-Za-z_$][A-Za-z0-9_$]*)',
);

// Shell, YAML and TOML: `#` comments, quoted strings, numbers, and the
// words a command or a config reads as keywords.
final _hashToken = RegExp(
  r'(?<comment>(?:^|(?<=\s))#[^\n]*)'
  r'''|(?<string>'[^'\n]*'|"(?:\\.|[^"\\\n])*")'''
  r'|(?<number>\b\d[\d_.]*\b)'
  r'|(?<word>[A-Za-z_][A-Za-z0-9_-]*)',
  multiLine: true,
);

final _typeName = RegExp(r'^_?\$?[A-Z]');

const _hashKeywords = {
  'if', 'then', 'else', 'elif', 'fi', 'for', 'while', 'do', 'done', 'case', //
  'esac', 'function', 'export', 'true', 'false', 'null',
};

final _jsonToken = RegExp(
  r'(?<string>"(?:\\.|[^"\\\n])*")'
  r'|(?<number>-?\b\d[\d_.eE+-]*\b)'
  r'|(?<word>true|false|null)',
);

/// Splits [source] into highlighted runs (adjacent plain text is one run):
/// the same as [highlightSource], which it delegates to.
List<(CodeToken, String)> highlightCode(
  String source, {
  String language = 'dart',
}) => highlightSource(source, language: language);

/// Splits [source] into highlighted runs (adjacent plain text is one run).
/// Dart, shell (`bash`, `sh`, `shell`, `zsh`), YAML, TOML and JSON are
/// colored; other languages are one plain run. What the v2 code widgets use.
List<(CodeToken, String)> highlightSource(
  String source, {
  String language = 'dart',
}) {
  final pattern = switch (language) {
    'dart' => _dartToken,
    'bash' ||
    'sh' ||
    'shell' ||
    'zsh' ||
    'yaml' ||
    'yml' ||
    'toml' => _hashToken,
    'json' => _jsonToken,
    _ => null,
  };
  if (pattern == null) return [(CodeToken.plain, source)];
  final dart = pattern == _dartToken;
  final json = pattern == _jsonToken;
  final runs = <(CodeToken, String)>[];
  void add(CodeToken kind, String text) {
    if (text.isEmpty) return;
    if (runs.isNotEmpty && runs.last.$1 == kind && kind == CodeToken.plain) {
      runs[runs.length - 1] = (kind, runs.last.$2 + text);
    } else {
      runs.add((kind, text));
    }
  }

  var at = 0;
  for (final m in pattern.allMatches(source)) {
    add(CodeToken.plain, source.substring(at, m.start));
    // A language's pattern has only some of the groups.
    String? group(String name) =>
        m.groupNames.contains(name) ? m.namedGroup(name) : null;
    final word = group('word');
    if (!dart && !json && word != null && !_hashKeywords.contains(word)) {
      // A shell or config word that is not a keyword stays plain.
      add(CodeToken.plain, m[0]!);
      at = m.end;
      continue;
    }
    final kind = json && word != null
        ? CodeToken.keyword
        : !dart && word != null
        ? CodeToken.keyword
        : group('comment') != null
        ? CodeToken.comment
        : group('string') != null
        ? CodeToken.string
        : group('number') != null
        ? CodeToken.number
        : group('annotation') != null || _dartKeywords.contains(word)
        ? CodeToken.keyword
        : _dartBuiltinTypes.contains(word)
        ? CodeToken.type
        : _typeName.hasMatch(word!)
        ? CodeToken.type
        : CodeToken.plain;
    add(kind, m[0]!);
    at = m.end;
  }
  add(CodeToken.plain, source.substring(at));
  return runs;
}

/// The color of a token kind (null: the text color).
Color? codeTokenColor(CodeToken kind) => switch (kind) {
  CodeToken.keyword => StudioSyntaxColors.keyword,
  CodeToken.string => StudioSyntaxColors.string,
  CodeToken.number => StudioSyntaxColors.number,
  CodeToken.type => StudioSyntaxColors.type,
  CodeToken.comment => StudioSyntaxColors.comment,
  CodeToken.plain => null,
};

const _escape = HtmlEscape(HtmlEscapeMode.element);

/// [source] as escaped HTML with a `studio-tok-<kind>` span per highlighted
/// token (colored by `StudioProse`): for code inside
/// rendered markdown.
String highlightToHtml(String source, {String language = 'dart'}) {
  final out = StringBuffer();
  for (final (kind, text) in highlightSource(source, language: language)) {
    final escaped = _escape.convert(text);
    if (kind == CodeToken.plain) {
      out.write(escaped);
    } else {
      out.write('<span class="studio-tok-${kind.name}">$escaped</span>');
    }
  }
  return out.toString();
}

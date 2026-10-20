import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../errors.dart';
import '../workspace.dart';

export 'overlay_script.dart';

/// Where the files of a stack trace are: `package:` URIs to the packages of
/// the app's workspace, `file:` URIs as they are, and which of them are the
/// app's own code (what the overlay points at first).
class SourceMap {
  /// A map for an app in [appDir] with its packages at [packages] (name →
  /// folder of its `lib/`).
  SourceMap({required this.appDir, required this.packages, this.root});

  /// The map of [app]'s workspace (`.dart_tool/package_config.json`).
  factory SourceMap.of(Project app) {
    final tool = p.join(app.pubRoot, '.dart_tool');
    final packages = <String, String>{};
    try {
      final json =
          jsonDecode(
                File(p.join(tool, 'package_config.json')).readAsStringSync(),
              )
              as Map<String, Object?>;
      for (final entry
          in (json['packages'] as List).cast<Map<String, Object?>>()) {
        var root = entry['rootUri'] as String;
        if (!root.endsWith('/')) root = '$root/';
        final lib = Uri.directory(
          tool,
        ).resolve(root).resolve('${entry['packageUri'] ?? 'lib/'}');
        packages[entry['name'] as String] = p.normalize(lib.toFilePath());
      }
    } on Object {
      // No resolution yet: frames stay as the VM wrote them.
    }
    return SourceMap(appDir: app.dir, packages: packages, root: app.pubRoot);
  }

  /// The app's folder.
  final String appDir;

  /// The workspace's folder (its packages are "yours" too), if any.
  final String? root;

  /// Package name → the folder `package:name/` points at.
  final Map<String, String> packages;

  /// The file [uri] names (`package:shop/app.dart`, `file:///…`, a path
  /// relative to the app), or `null` for the SDK (`dart:`) and unknown
  /// packages.
  String? file(String uri) {
    if (uri.startsWith('package:')) {
      final rest = uri.substring('package:'.length);
      final slash = rest.indexOf('/');
      if (slash < 0) return null;
      final dir = packages[rest.substring(0, slash)];
      return dir == null
          ? null
          : p.join(dir, Uri.decodeFull(rest.substring(slash + 1)));
    }
    if (uri.startsWith('file:')) return Uri.parse(uri).toFilePath();
    if (uri.startsWith('dart:') || uri.contains(':')) {
      return p.isAbsolute(uri) ? uri : null;
    }
    return p.normalize(p.join(appDir, uri));
  }

  /// How close [file] is to what the developer writes: 2 the app's own
  /// code (not generated), 1 the workspace's, 0 the rest.
  int ownership(String file) {
    final generated =
        file.endsWith('.thor.dart') ||
        file.endsWith('.g.dart') ||
        file.contains('${p.separator}.dart_tool${p.separator}');
    if (p.isWithin(appDir, file) && !generated) return 2;
    final root = this.root;
    if (root != null && p.isWithin(root, file) && !generated) return 1;
    return 0;
  }

  /// [before] and [after] lines around [line] of [file] (1-based), as
  /// `[number, text]`; empty when the file can't be read.
  ///
  /// A line longer than [maxLine] (minified code) is cut; [cache] keeps the
  /// files already read (thousands of findings in a few files).
  List<List<Object>> excerpt(
    String file,
    int line, {
    int before = 3,
    int after = 3,
    int maxLine = 300,
    Map<String, List<String>>? cache,
  }) {
    try {
      final lines = cache == null
          ? File(file).readAsLinesSync()
          : cache[file] ??= File(file).readAsLinesSync();
      final from = (line - before).clamp(1, lines.length);
      final to = (line + after).clamp(1, lines.length);
      return [
        for (var n = from; n <= to; n++)
          [
            n,
            lines[n - 1].length > maxLine
                ? '${lines[n - 1].substring(0, maxLine)}…'
                : lines[n - 1],
          ],
      ];
    } on Object {
      return const [];
    }
  }
}

/// A frame of a stack trace, located.
typedef Frame = ({
  String text,
  String? file,
  int? line,
  int? column,
  int owner,
});

// `#0  member (package:x/y.dart:12:5)` (the VM) and `package:x/y.dart 12:5
// member` (package:stack_trace).
final _vmFrame = RegExp(r'^#\d+\s+(.*?)\s+\((\S+?):(\d+)(?::(\d+))?\)\s*$');
final _traceFrame = RegExp(r'^(\S+\.dart)\s+(\d+):(\d+)\s+(.*)$');

/// The frames of [stack], each with its file when [sources] knows it.
List<Frame> parseStack(String stack, SourceMap sources) {
  final out = <Frame>[];
  for (final raw in const LineSplitter().convert(stack)) {
    final text = raw.trim();
    if (text.isEmpty || text == '<asynchronous suspension>') continue;
    String? uri;
    int? line;
    int? column;
    if (_vmFrame.firstMatch(text) case final m?) {
      uri = m[2];
      line = int.tryParse(m[3]!);
      column = m[4] == null ? null : int.tryParse(m[4]!);
    } else if (_traceFrame.firstMatch(text) case final m?) {
      uri = m[1];
      line = int.tryParse(m[2]!);
      column = int.tryParse(m[3]!);
    }
    final file = uri == null ? null : sources.file(uri);
    out.add((
      text: text,
      file: file,
      line: line,
      column: column,
      owner: file == null ? 0 : sources.ownership(file),
    ));
  }
  return out;
}

/// `file:line:col: Error: message` (or `Warning:`) lines of a compiler's or
/// a lint's output: the diagnostics channel of `thor dev`.
final _diagnosticLine = RegExp(diagnosticLinePattern);

/// `(THOR-S011 · https://…/THOR-S011)` inside a message: the code and its
/// page (`thorError`); the page is optional.
final _codeMark = RegExp(r'\((THOR-[A-Z]\d{3})(?: · (https?://[^\s)]+))?\)');

/// One overlay entry: what happened, where, and the code there.
///
/// [phase] `load` / `action` / `build` / `request` / `guard` / `error
/// page` (a page request), `compile` (the server's code), `engine` (the
/// browser's), `codegen`, `diagnostics` (a lint or a build check).
/// [severity] is `error` (the overlay) or `warning` (a badge); [code] and
/// [doc] the code (THOR-S011) and its page, [fix] what to write instead.
Map<String, Object?> overlayEntry({
  required String phase,
  required String title,
  required String message,
  String where = '',
  List<Frame> frames = const [],
  required SourceMap sources,
  String severity = 'error',
  String? code,
  String? doc,
  String? fix,
  bool keepFrames = true,
  Map<String, List<String>>? cache,
}) {
  Frame? top;
  for (final wanted in [2, 1]) {
    top ??= frames
        .where((f) => f.owner == wanted && f.line != null)
        .firstOrNull;
  }
  return {
    'phase': phase,
    'title': title,
    'severity': severity,
    'message': message,
    'where': where,
    'code': ?code,
    'doc': ?doc,
    'fix': ?fix,
    if (top != null) 'at': _location(top, sources, cache),
    'frames': keepFrames
        ? [
            for (final f in frames)
              {
                'text': f.text,
                'owner': f.owner,
                if (f.file != null && f.line != null)
                  ..._where(f.file!, f.line!, f.column),
              },
          ]
        : const [],
  };
}

Map<String, Object?> _location(
  Frame f,
  SourceMap sources,
  Map<String, List<String>>? cache,
) => {
  'file': p.relative(f.file!, from: sources.root ?? sources.appDir),
  ..._where(f.file!, f.line!, f.column),
  'code': sources.excerpt(f.file!, f.line!, cache: cache),
};

// The overlay builds the link for the editor (`THOR_EDITOR`) from these.
Map<String, Object?> _where(String file, int line, int? column) => {
  'path': file,
  'line': line,
  'column': column,
};

/// The overlay entry of a page's error block (`ThorDev.errorBlock`).
Map<String, Object?> pageErrorEntry(
  Map<String, Object?> block,
  SourceMap sources,
) => overlayEntry(
  phase: '${block['phase'] ?? 'build'}',
  title: '${block['type'] ?? 'Error'}',
  message: '${block['message'] ?? ''}',
  where: '${block['where'] ?? ''}',
  frames: parseStack('${block['stack'] ?? ''}', sources),
  sources: sources,
);

/// Overlay entries for [output] of a failed compile, a lint or a start
/// (one per `Error:` / `Warning:` line; one error with the whole text when
/// there is none). A code in the message (`THOR-S011`) and the fix that
/// follows it come apart from the rest.
///
/// A line that is not a diagnostic is noise of the tool (a compiler's
/// progress) and is left out, unless [keepUnparsed]: in a channel made of
/// diagnostics only (`.dart_tool/thor/`), it is an error of its own (the
/// build fails on it, so the page shows it).
List<Map<String, Object?>> compileEntries(
  String phase,
  String title,
  String output,
  SourceMap sources, {
  bool keepUnparsed = false,
}) {
  final entries = <Map<String, Object?>>[];
  final cache = <String, List<String>>{};
  for (final line in const LineSplitter().convert(output)) {
    final m = _diagnosticLine.firstMatch(line.trim());
    if (m == null) {
      if (keepUnparsed && line.trim().isNotEmpty) {
        entries.add(
          overlayEntry(
            phase: phase,
            title: title,
            message: line.trim(),
            sources: sources,
          ),
        );
      }
      continue;
    }
    final file = sources.file(m[1]!);
    final number = int.parse(m[2]!);
    final column = int.parse(m[3]!);
    var message = m[5]!.trim();
    String? code, doc, fix;
    if (_codeMark.firstMatch(message) case final c?) {
      code = c[1];
      doc = c[2];
      fix = message.substring(c.end).trim();
      message = message.substring(0, c.start).trim();
      if (fix.isEmpty) fix = null;
    }
    entries.add(
      overlayEntry(
        phase: phase,
        title: title,
        message: message,
        severity: m[4]!.toLowerCase(),
        code: code,
        doc: doc,
        fix: fix,
        keepFrames: false,
        cache: cache,
        frames: [
          (
            text: line.trim(),
            file: file,
            line: number,
            column: column,
            // The error is in this file, whoever owns it.
            owner: file == null ? 0 : sources.ownership(file).clamp(1, 2),
          ),
        ],
        sources: sources,
      ),
    );
  }
  if (entries.isEmpty) {
    entries.add(
      overlayEntry(
        phase: phase,
        title: title,
        message: output.trim(),
        sources: sources,
      ),
    );
  }
  return entries;
}

/// The page's error blocks: `<script type="application/json"
/// id="thor-dev-error">`.
final errorBlocks = RegExp(
  r'<script type="application/json" id="thor-dev-error">([\s\S]*?)</script>',
);

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../render/render.dart';
import '../render/report.dart';
import '../run.dart';
import '../workspace.dart';

/// `thor render`: a route or a widget → HTML, CSS, accessibility tree,
/// errors, warnings and screenshots, without opening a browser yourself.
/// Made for a quick look and for AI agents (`--json`).
class RenderCommand extends Command<int> {
  /// The command.
  RenderCommand() {
    argParser
      ..addOption(
        'app',
        abbr: 'a',
        help: 'The project (a folder or a name); default: the current one.',
      )
      ..addFlag(
        'widget',
        abbr: 'w',
        negatable: false,
        help:
            'The target is `file.dart#Name`: a class with a no-argument '
            'constructor or a function returning a Widget.',
      )
      ..addMultiOption(
        'cookie',
        abbr: 'c',
        help: 'A cookie to send (name=value), e.g. a session.',
      )
      ..addOption(
        'widths',
        defaultsTo: '390,800,1440',
        help: 'Screenshot widths.',
      )
      ..addFlag(
        'browser',
        defaultsTo: true,
        help: 'Screenshots, ARIA tree, warnings and console (Playwright).',
      )
      ..addFlag(
        'codegen',
        defaultsTo: true,
        help: 'Run code generation first (skip it when thor dev runs).',
      )
      ..addOption('out', help: 'Where screenshots go.')
      ..addFlag('json', negatable: false, help: 'Everything as JSON.')
      ..addOption(
        'report',
        valueHelp: 'file',
        help:
            'Write the JSON report to <file> instead of stdout (a launcher '
            'that prints first, like `dart pub global run` resolving, '
            "can't break it).",
      )
      ..addFlag('html', negatable: false, help: 'Print the HTML too.')
      ..addFlag('css', negatable: false, help: 'Print the CSS too.');
  }

  @override
  String get name => 'render';

  @override
  String get description =>
      'Render a route or a widget: HTML, CSS, accessibility tree, errors, '
      'warnings and screenshots.';

  @override
  String get invocation => 'thor render [route] [--app <project>]';

  @override
  Future<int> run() async {
    final args = argResults!;
    final rest = args.rest;
    final app = Project.find(args['app'] as String?);
    if (app == null) {
      throw ThorException(
        'Not inside a thor project: run it in one or pass --app <project>.',
      );
    }
    final request = RenderRequest(
      rest.isEmpty ? '/' : rest.first,
      widget: args['widget'] as bool,
      cookies: parseCookies(args['cookie'] as List<String>),
      widths: parseWidths(args['widths'] as String),
      browser: args['browser'] as bool,
      codegen: args['codegen'] as bool,
      outDir: args['out'] as String?,
    );
    final file = args['report'] as String?;
    final json = file != null || args['json'] as bool;
    final out = stdout;
    // With --json, stdout is the JSON alone: progress goes to stderr.
    final report = json
        ? await IOOverrides.runZoned(
            () => render(app, request),
            stdout: () => stderr,
          )
        : await render(app, request);
    writeRenderOutput(
      report,
      out: out,
      json: json,
      file: file,
      html: args['html'] as bool,
      css: args['css'] as bool,
    );
    return report.serverErrors.isEmpty && report.status < 500 ? 0 : 1;
  }
}

/// `name=value` pairs; anything else is an error.
Map<String, String> parseCookies(List<String> values) {
  final cookies = <String, String>{};
  for (final v in values) {
    final i = v.indexOf('=');
    if (i <= 0) throw ThorException('A cookie is name=value (got "$v").');
    cookies[v.substring(0, i)] = v.substring(i + 1);
  }
  return cookies;
}

/// `390,800` → widths; each between 200 and 4000 px.
List<int> parseWidths(String text) => [
  for (final part in text.split(','))
    if (int.tryParse(part.trim()) case final w? when w >= 200 && w <= 4000)
      w
    else
      throw ThorException(
        'Widths are numbers from 200 to 4000 separated by commas '
        '(got "$text").',
      ),
];

/// Writes [report] as `thor render` prints it: the JSON to [file] (a
/// line saying so goes to stderr), else the JSON ([json]) or
/// the text (with [html]/[css]) to [out].
void writeRenderOutput(
  RenderReport report, {
  required StringSink out,
  bool json = false,
  String? file,
  bool html = false,
  bool css = false,
}) {
  final text = const JsonEncoder.withIndent('  ').convert(report.toJson());
  if (file != null) {
    File(file).writeAsStringSync('$text\n');
    stderr.writeln('Report written to $file');
  } else if (json) {
    out.writeln(text);
  } else {
    out.write(report.toText(html: html, css: css));
  }
}

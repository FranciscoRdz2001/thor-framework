/// `thor mcp`: `thor render` and the error pages as an MCP server (stdio,
/// JSON-RPC 2.0, one message per line), so an agent can look at what it
/// built without leaving its loop.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../run.dart';
import '../workspace.dart';
import 'render.dart';

/// The protocol version this server speaks.
const mcpProtocolVersion = '2025-06-18';

/// The tools, as `tools/list` describes them.
const mcpTools = [
  {
    'name': 'render',
    'description':
        'Render a route (or a widget) of a thor app and return what it '
        'produced: status, HTML and CSS sizes (and texts with include_html '
        '/ include_css), server errors with THOR codes, the debug '
        "inspector's layout warnings with the app file:line that built "
        'each element, console errors, the accessibility tree, and '
        'screenshots at each width (the first one attached as an image).',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'route': {
          'type': 'string',
          'description': 'Path with query, e.g. /articles?page=2. Default /.',
        },
        'widget': {
          'type': 'string',
          'description':
              'Instead of a route: file.dart#Name (a class with a '
              'no-argument constructor or a function returning a Widget).',
        },
        'app': {
          'type': 'string',
          'description': 'The app folder; default: the server\'s app.',
        },
        'cookies': {
          'type': 'object',
          'additionalProperties': {'type': 'string'},
          'description': 'Cookies to send (a session).',
        },
        'widths': {
          'type': 'array',
          'items': {'type': 'integer', 'minimum': 200, 'maximum': 4000},
          'description': 'Screenshot widths. Default [390, 800, 1440].',
        },
        'browser': {'type': 'boolean', 'description': 'Default true.'},
        'codegen': {
          'type': 'boolean',
          'description': 'Run code generation first. Default true.',
        },
        'include_html': {'type': 'boolean'},
        'include_css': {'type': 'boolean'},
      },
    },
  },
  {
    'name': 'error_code',
    'description':
        'Explain a THOR-xxx error code: what happened, why, and the '
        'WRONG/RIGHT fix (the page in docs/errores).',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'code': {'type': 'string', 'pattern': r'^THOR-[A-Z]\d{3}$'},
      },
      'required': ['code'],
    },
  },
];

/// Serves MCP on [input]/[output] for the app at [defaultApp] (or the one
/// each call names) until [input] ends.
Future<void> serveMcp({
  required Stream<List<int>> input,
  required IOSink output,
  String? defaultApp,
}) async {
  final lines = input.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final Object? message;
    try {
      message = jsonDecode(line);
    } on FormatException {
      output.writeln(jsonEncode(_error(null, -32700, 'Parse error')));
      continue;
    }
    if (message is! Map<String, Object?>) {
      output.writeln(jsonEncode(_error(null, -32600, 'Invalid Request')));
      continue;
    }
    final reply = await handleMcp(message, defaultApp: defaultApp);
    if (reply != null) output.writeln(jsonEncode(reply));
  }
}

/// The answer to one JSON-RPC [message], or null for a notification.
Future<Map<String, Object?>?> handleMcp(
  Map<String, Object?> message, {
  String? defaultApp,
}) async {
  final id = message['id'];
  final method = message['method'];
  if (id == null) return null; // a notification: nothing to answer.
  final params = message['params'] is Map
      ? (message['params']! as Map).cast<String, Object?>()
      : const <String, Object?>{};
  switch (method) {
    case 'initialize':
      return _result(id, {
        'protocolVersion': mcpProtocolVersion,
        'capabilities': {'tools': <String, Object?>{}},
        'serverInfo': {'name': 'thor', 'version': '0.1.0'},
        'instructions':
            'Use render after changing a thor page or widget to see its '
            'HTML, CSS, errors, layout warnings (with file:line), '
            'accessibility tree and screenshots. Use error_code for any '
            'THOR-xxx code.',
      });
    case 'ping':
      return _result(id, <String, Object?>{});
    case 'tools/list':
      return _result(id, {'tools': mcpTools});
    case 'tools/call':
      final name = params['name'];
      final args = params['arguments'] is Map
          ? (params['arguments']! as Map).cast<String, Object?>()
          : const <String, Object?>{};
      try {
        final content = await IOOverrides.runZoned(
          () => switch (name) {
            'render' => _render(args, defaultApp),
            'error_code' => _errorCode(args),
            _ => throw ThorException('Unknown tool "$name".'),
          },
          // Progress lines must not reach the protocol's stdout.
          stdout: () => stderr,
        );
        return _result(id, {'content': content});
      } on ThorException catch (e) {
        return _result(id, {
          'content': [
            {'type': 'text', 'text': e.message},
          ],
          'isError': true,
        });
      } on Object catch (e) {
        // A wrong-typed argument or an IO/process failure answers the call;
        // it must not end the agent's server.
        return _result(id, {
          'content': [
            {'type': 'text', 'text': '$e'},
          ],
          'isError': true,
        });
      }
    default:
      return _error(id, -32601, 'Method not found: $method');
  }
}

Future<List<Map<String, Object?>>> _render(
  Map<String, Object?> args,
  String? defaultApp,
) async {
  final app = Project.find(args['app'] as String? ?? defaultApp);
  if (app == null) {
    throw ThorException(
      'No thor app: pass "app" (a folder) or start `thor mcp` in one.',
    );
  }
  final widget = args['widget'] as String?;
  final widths = args['widths'] is List
      ? [for (final w in args['widths']! as List) (w as num).toInt()]
      : const [390, 800, 1440];
  final report = await render(
    app,
    RenderRequest(
      widget ?? args['route'] as String? ?? '/',
      widget: widget != null,
      cookies: args['cookies'] is Map
          ? (args['cookies']! as Map).map((k, v) => MapEntry('$k', '$v'))
          : const {},
      widths: widths,
      browser: args['browser'] as bool? ?? true,
      codegen: args['codegen'] as bool? ?? true,
    ),
  );
  final json = report.toJson(full: false);
  if (args['include_html'] == true) {
    (json['html']! as Map)['text'] = report.html;
  }
  if (args['include_css'] == true) {
    (json['css']! as Map)['text'] = [
      report.inlineCss,
      ...report.linkedCss.values,
    ].join('\n');
  }
  final shots = report.browser?.screenshots ?? const [];
  return [
    {'type': 'text', 'text': const JsonEncoder.withIndent(' ').convert(json)},
    if (shots.isNotEmpty && File(shots.first.path).existsSync())
      {
        'type': 'image',
        'mimeType': 'image/png',
        'data': base64Encode(File(shots.first.path).readAsBytesSync()),
      },
  ];
}

Future<List<Map<String, Object?>>> _errorCode(Map<String, Object?> args) async {
  final code = '${args['code'] ?? ''}'.trim().toUpperCase();
  if (!RegExp(r'^THOR-[A-Z]\d{3}$').hasMatch(code)) {
    throw ThorException('A code looks like THOR-S001 (got "$code").');
  }
  final home = await ThorHome.locate();
  final page = home == null
      ? null
      : File(p.join(home.root, 'docs', 'errores', '$code.md'));
  if (page == null || !page.existsSync()) {
    throw ThorException('No page for $code in the thor checkout (THOR_HOME).');
  }
  return [
    {'type': 'text', 'text': page.readAsStringSync()},
  ];
}

Map<String, Object?> _result(Object id, Map<String, Object?> result) => {
  'jsonrpc': '2.0',
  'id': id,
  'result': result,
};

Map<String, Object?> _error(Object? id, int code, String message) => {
  'jsonrpc': '2.0',
  'id': id,
  'error': {'code': code, 'message': message},
};

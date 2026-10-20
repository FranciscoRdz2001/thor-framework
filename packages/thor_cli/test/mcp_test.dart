// `thor mcp`: the JSON-RPC answers (no app needed) and one render through
// the protocol, with stdout kept for the protocol alone.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/src/render/mcp.dart';

import 'support/generated.dart';

Map<String, Object?> call(int id, String method, [Object? params]) => {
  'jsonrpc': '2.0',
  'id': id,
  'method': method,
  'params': ?params,
};

void main() {
  test('initialize, tools and ping', () async {
    final init = (await handleMcp(call(1, 'initialize')))!;
    final result = init['result']! as Map;
    expect(result['protocolVersion'], mcpProtocolVersion);
    expect((result['capabilities']! as Map).containsKey('tools'), isTrue);
    final tools = (await handleMcp(call(2, 'tools/list')))!;
    final names = [
      for (final t in ((tools['result']! as Map)['tools']! as List))
        (t as Map)['name'],
    ];
    expect(names, ['render', 'error_code']);
    expect((await handleMcp(call(3, 'ping')))!['result'], isEmpty);
  });

  test('notifications get no answer, unknown methods an error', () async {
    expect(
      await handleMcp({
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      }),
      isNull,
    );
    final unknown = (await handleMcp(call(4, 'resources/list')))!;
    expect((unknown['error']! as Map)['code'], -32601);
  });

  test('a wrong-typed argument is a tool error, not a dead server', () async {
    for (final args in [
      {
        'widths': ['390'],
      },
      {'app': 5},
      {'browser': 'yes'},
    ]) {
      final bad = (await handleMcp(
        call(9, 'tools/call', {'name': 'render', 'arguments': args}),
      ))!;
      expect((bad['result']! as Map)['isError'], isTrue, reason: '$args');
    }
    final code = (await handleMcp(
      call(10, 'tools/call', {
        'name': 'error_code',
        'arguments': {'code': 5},
      }),
    ))!;
    expect((code['result']! as Map)['isError'], isTrue);
  });

  test('error_code returns the page; a bad code is a tool error', () async {
    final ok = (await handleMcp(
      call(5, 'tools/call', {
        'name': 'error_code',
        'arguments': {'code': 'thor-s001'},
      }),
    ))!;
    final content = ((ok['result']! as Map)['content']! as List).single as Map;
    expect(content['text'], contains('THOR-S001'));
    for (final code in ['S001', 'THOR-1', 'THOR-Z999']) {
      final bad = (await handleMcp(
        call(6, 'tools/call', {
          'name': 'error_code',
          'arguments': {'code': code},
        }),
      ))!;
      expect((bad['result']! as Map)['isError'], isTrue, reason: code);
    }
  });

  test('an unknown tool and a missing app are tool errors', () async {
    final unknown = (await handleMcp(
      call(7, 'tools/call', {
        'name': 'deploy',
        'arguments': <String, Object?>{},
      }),
    ))!;
    expect((unknown['result']! as Map)['isError'], isTrue);
    final noApp = (await handleMcp(
      call(8, 'tools/call', {
        'name': 'render',
        'arguments': {'app': '/nowhere/at/all'},
      }),
    ))!;
    expect((noApp['result']! as Map)['isError'], isTrue);
  });

  test(
    'render through the protocol: stdout carries only JSON-RPC',
    () async {
      // A clean checkout has no generated registries yet.
      await generateOnce(
        p.join('..', '..', 'test', 'fixtures', 'apps', 'realworld'),
      );
      final input = StreamController<List<int>>();
      final captured = _Sink();
      final served = serveMcp(
        input: input.stream,
        output: IOSink(captured),
        defaultApp: p.join('..', '..', 'test', 'fixtures', 'apps', 'realworld'),
      );
      input
        ..add(utf8.encode('not json\n'))
        ..add(
          utf8.encode(
            '${jsonEncode(call(9, 'tools/call', {
              'name': 'render',
              'arguments': {'route': '/login', 'browser': false, 'codegen': false},
            }))}\n',
          ),
        );
      await input.close();
      await served;
      final lines = const LineSplitter().convert(captured.text);
      expect(lines, hasLength(2));
      final parse = jsonDecode(lines[0]) as Map;
      expect((parse['error']! as Map)['code'], -32700);
      final rendered = jsonDecode(lines[1]) as Map;
      final text =
          (((rendered['result']! as Map)['content']! as List).first
                  as Map)['text']
              as String;
      final report = jsonDecode(text) as Map;
      expect(report['status'], 200);
      expect((report['html']! as Map).containsKey('text'), isFalse);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _Sink implements StreamConsumer<List<int>> {
  final _bytes = <int>[];
  String get text => utf8.decode(_bytes);

  @override
  Future<void> addStream(Stream<List<int>> stream) =>
      stream.forEach(_bytes.addAll);

  @override
  Future<void> close() async {}
}

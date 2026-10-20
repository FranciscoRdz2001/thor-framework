@TestOn('vm')
library;

// The head future wait is bounded: a head future that never
// finishes answers a deterministic 504, never a 200 and never a hang.
import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  initializeThorTests();

  late List<Object> errors;

  RouteHandler<Widget> handler(
    Future<String> Function() head, {
    Duration deferTimeout = const Duration(milliseconds: 120),
    Duration? budget,
  }) => RouteHandler<Widget>(
    deferTimeout: deferTimeout,
    renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
    onError: (request, error, stack) => errors.add(error),
    routes: [
      PageRoute<Widget, ({Future<String> v})>(
        path: 'p',
        load: (r) => (v: defer(head(), head: true, headBudget: budget)),
        meta: (s) => PageMeta(title: resolvedValue(s.data.v) ?? 'Fallback'),
        build: (s) => const Text('body'),
      ),
    ],
  );

  PageRequest get() => PageRequest(
    method: HttpMethod.get,
    uri: Uri.parse('http://site.test/p'),
    headers: {HttpHeader.host: 'site.test'},
  );

  setUp(() => errors = []);

  test('a head future that never completes answers 504 within '
      'deferTimeout, reported to onError', () async {
    final never = Completer<String>();
    final started = Stopwatch()..start();
    final r = await handler(() => never.future).handle(get());
    expect(r.status, 504);
    expect(started.elapsedMilliseconds, lessThan(2000));
    expect(errors, hasLength(1));
  });

  test(
    'a head future that finishes inside deferTimeout is unaffected',
    () async {
      final r = await handler(
        () => Future.delayed(const Duration(milliseconds: 30), () => 'Real'),
      ).handle(get());
      expect(r.status, 200);
      final html = r.stream == null
          ? utf8.decode(r.body)
          : utf8.decode(await r.stream!.first);
      expect(html, contains('<title>Real</title>'));
    },
  );

  test('a complete page (no stream) is bounded too', () async {
    final never = Completer<String>();
    final r = await handler(() => never.future).handle(get(), stream: false);
    expect(r.status, 504);
  });

  test(
    'an opt-in budget still wins over deferTimeout: 200, fallback head',
    () async {
      final never = Completer<String>();
      final r = await handler(
        () => never.future,
        budget: const Duration(milliseconds: 30),
        deferTimeout: const Duration(seconds: 5),
      ).handle(get());
      expect(r.status, 200);
    },
  );
}

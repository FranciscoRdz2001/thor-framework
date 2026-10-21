@TestOn('vm')
library;

// The head future: a future marked `defer(f, head: true)` is awaited
// by the server before the head goes out, so `meta` can read its value and a
// `NotFound`/`Redirect` from it answers a real status, however slow the
// backend is. Only an opt-in `headBudget` (cosmetic head data) gives up
// waiting: past it the page streams with the fallback head.
import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class _Product {
  const _Product(this.name);
  final String name;
}

class _Data {
  _Data(this.product, this.related);
  final Future<_Product> product;
  final Future<String> related;
}

void main() {
  initializeThorTests();

  late Completer<_Product> product;
  late Completer<String> related;
  late List<Object> errors;
  // null: the default, no budget (the status never depends on latency).
  late Duration? budget;

  RouteHandler<Widget> handler({
    Duration botBudget = const Duration(seconds: 3),
  }) => RouteHandler<Widget>(
    headBotBudget: botBudget,
    renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
    onError: (request, error, stack) => errors.add(error),
    routes: [
      PageRoute<Widget, _Data>(
        path: 'p',
        load: (r) => _Data(
          defer(product.future, head: true, headBudget: budget),
          defer(related.future),
        ),
        meta: (s) {
          final p = resolvedValue(s.data.product);
          return PageMeta(
            title: p?.name ?? 'Loading product',
            description: p == null ? null : 'Buy ${p.name}',
          );
        },
        build: (s) => Column(
          children: [
            const Text('header'),
            FutureBuilder<_Product>(
              future: s.data.product,
              builder: (c, snap) => snap.hasData
                  ? Text('product ${snap.data!.name}')
                  : snap.hasError
                  ? Text('product failed: ${snap.error}')
                  : const Text('product loading'),
            ),
            FutureBuilder<String>(
              future: s.data.related,
              builder: (c, snap) =>
                  Text(snap.hasData ? 'related ${snap.data}' : 'related ...'),
            ),
          ],
        ),
      ),
    ],
  );

  PageRequest get(String path) => PageRequest(
    method: HttpMethod.get,
    uri: Uri.parse('http://site.test$path'),
    headers: {HttpHeader.host: 'site.test'},
  );

  Future<String> shell(ThorResponse r) async {
    if (r.stream == null) return utf8.decode(r.body);
    final first = Completer<String>();
    final sub = r.stream!.listen((c) {
      if (!first.isCompleted) first.complete(utf8.decode(c));
    });
    addTearDown(sub.cancel);
    return first.future;
  }

  setUp(() {
    product = Completer();
    product.future.ignore();
    related = Completer();
    errors = [];
    budget = null;
  });

  test('no budget: a slow missing product is a real 404, not a 200', () async {
    // Slower than the old 300 ms budget: the status must not depend on it.
    Future<void>.delayed(
      const Duration(milliseconds: 700),
      () => product.completeError(const NotFound('no such product')),
    );
    final started = DateTime.now();
    final r = await handler().handle(get('/p'));
    expect(
      DateTime.now().difference(started),
      greaterThanOrEqualTo(const Duration(milliseconds: 600)),
    );
    expect(r.status, 404);
    expect(r.stream, isNull);
    related.complete('x');
  });

  test('no budget: a slow product gives the real title, in a 200', () async {
    Future<void>.delayed(
      const Duration(milliseconds: 600),
      () => product.complete(const _Product('Shampoo')),
    );
    final r = await handler().handle(get('/p'));
    expect(r.status, 200);
    final html = await shell(r);
    expect(html, contains('<title>Shampoo</title>'));
    expect(html, contains('product Shampoo'));
    // Only the head future is waited for: the rest still streams.
    expect(r.stream, isNotNull);
    expect(html, contains('related ...'));
    related.complete('x');
  });

  test('no budget: a slow redirect is a real redirect', () async {
    Future<void>.delayed(
      const Duration(milliseconds: 500),
      () => product.completeError(const Redirect(RouteUrl('/moved'))),
    );
    final r = await handler().handle(get('/p'));
    expect(r.status, 303);
    expect(r.headers['location'], '/moved');
    related.complete('x');
  });

  test('no budget: a bot gets the same answer as a browser, no Vary', () async {
    Future<void>.delayed(
      const Duration(milliseconds: 400),
      () => product.completeError(const NotFound()),
    );
    final r = await handler().handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://site.test/p'),
        headers: {
          HttpHeader.host: 'site.test',
          HttpHeader.userAgent: 'Twitterbot/1.0',
        },
      ),
    );
    expect(r.status, 404);
    expect(r.headers['vary'] ?? '', isNot(contains('User-Agent')));
    related.complete('x');
  });

  group('a budget that expires and then fails', () {
    late List<String> lines;
    late bool wasEnabled;
    late void Function(String) wasSink;

    setUp(() {
      lines = [];
      wasEnabled = ThorDev.enabled;
      wasSink = ThorDev.errorSink;
      ThorDev.enabled = true;
      ThorDev.errorSink = lines.add;
      ThorDev.forgetLoggedErrors();
    });
    tearDown(() {
      ThorDev.enabled = wasEnabled;
      ThorDev.errorSink = wasSink;
    });

    Future<void> drain(ThorResponse r) async {
      final done = Completer<void>();
      r.stream!.listen((_) {}, onDone: done.complete);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      product.completeError(const NotFound('gone'));
      related.complete('x');
      await done.future;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    test('thor dev warns: the page can answer 200 for a missing one', () async {
      budget = const Duration(milliseconds: 40);
      await drain(await handler().handle(get('/p')));
      expect(lines, hasLength(1));
      expect(lines.single, contains('THOR-S038'));
      expect(lines.single, contains('/p'));
      expect(lines.single, contains('headBudget'));
    });

    test('not under thor dev: nothing is printed', () async {
      ThorDev.enabled = false;
      budget = const Duration(milliseconds: 40);
      await drain(await handler().handle(get('/p')));
      expect(lines, isEmpty);
    });

    test('inside the budget: the 404 is real, no warning', () async {
      budget = const Duration(milliseconds: 200);
      product.completeError(const NotFound());
      final r = await handler().handle(get('/p'));
      expect(r.status, 404);
      expect(lines, isEmpty);
      related.complete('x');
    });

    test('another error, or a value, is not a status: no warning', () async {
      budget = const Duration(milliseconds: 40);
      final r = await handler().handle(get('/p'));
      final done = Completer<void>();
      r.stream!.listen((_) {}, onDone: done.complete);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      product.completeError(StateError('backend'));
      related.complete('x');
      await done.future;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(lines.where((l) => l.contains('THOR-S038')), isEmpty);
    });
  });

  test('inside the budget: the head has the real name, no skeleton', () async {
    Future<void>.delayed(
      const Duration(milliseconds: 30),
      () => product.complete(const _Product('Shampoo')),
    );
    final r = await handler().handle(get('/p'));
    expect(r.status, 200);
    final html = await shell(r);
    expect(html, contains('<title>Shampoo</title>'));
    expect(html, contains('Buy Shampoo'));
    expect(html, contains('product Shampoo'));
    expect(html, isNot(contains('product loading')));
    // The slow value that is not a head one still streams.
    expect(r.stream, isNotNull);
    expect(html, contains('related ...'));
    related.complete('x');
  });

  test('a NotFound inside the budget is a real 404', () async {
    Future<void>.delayed(
      const Duration(milliseconds: 30),
      () => product.completeError(const NotFound('no such product')),
    );
    final r = await handler().handle(get('/p'));
    expect(r.status, 404);
    expect(r.stream, isNull);
    expect(utf8.decode(r.body), isNot(contains('header')));
    related.complete('x');
  });

  test('a Redirect inside the budget redirects', () async {
    product.completeError(const Redirect(RouteUrl('/moved')));
    final r = await handler().handle(get('/p'));
    expect(r.status, 303);
    expect(r.headers['location'], '/moved');
    related.complete('x');
  });

  test(
    'past the budget: 200, the fallback head, the value comes late',
    () async {
      budget = const Duration(milliseconds: 60);
      final started = DateTime.now();
      final r = await handler().handle(get('/p'));
      final waited = DateTime.now().difference(started);
      expect(waited, lessThan(const Duration(milliseconds: 400)));
      expect(r.status, 200);
      final chunks = <String>[];
      final done = Completer<void>();
      r.stream!.listen(
        (c) => chunks.add(utf8.decode(c)),
        onDone: done.complete,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(chunks.first, contains('<title>Loading product</title>'));
      expect(chunks.first, contains('product loading'));
      product.complete(const _Product('Shampoo'));
      related.complete('x');
      await done.future;
      expect(chunks.join(), contains('product Shampoo'));
      // The head never changed.
      expect(chunks.join(), isNot(contains('<title>Shampoo')));
    },
  );

  test('past the budget a NotFound can not change the status', () async {
    budget = const Duration(milliseconds: 40);
    final r = await handler().handle(get('/p'));
    expect(r.status, 200);
    final chunks = <String>[];
    final done = Completer<void>();
    r.stream!.listen((c) => chunks.add(utf8.decode(c)), onDone: done.complete);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    product.completeError(const NotFound('gone'));
    related.complete('x');
    await done.future;
    expect(chunks.join(), contains('product failed: gone'));
  });

  test('no budget: a head future that fails with another error is a 500, '
      'reported, not a 200', () async {
    product.completeError(StateError('backend detail'));
    final r = await handler().handle(get('/p'));
    expect(r.status, 500);
    expect(utf8.decode(r.body), isNot(contains('backend detail')));
    expect(errors, hasLength(1));
    related.complete('x');
  });

  test('a budgeted (cosmetic) head future that fails with another error '
      'keeps streaming', () async {
    budget = const Duration(milliseconds: 200);
    product.completeError(StateError('backend detail'));
    final r = await handler().handle(get('/p'));
    expect(r.status, 200);
    final html = await shell(r);
    expect(html, contains('<title>Loading product</title>'));
    expect(html, contains('product failed:'));
    expect(html, isNot(contains('backend detail')));
    related.complete('x');
  });

  test(
    'the budget is per request, not a delay: a done future adds none',
    () async {
      product.complete(const _Product('Fast'));
      final started = DateTime.now();
      final r = await handler().handle(get('/p'));
      expect(
        DateTime.now().difference(started),
        lessThan(const Duration(milliseconds: 100)),
      );
      expect(await shell(r), contains('<title>Fast</title>'));
      related.complete('x');
    },
  );

  test('without head: the title can not read the value', () async {
    // `defer` alone, as before: meta runs at once with no value.
    expect(resolvedValue(defer(Future<int>.value(1))), isNull);
  });

  test(
    'resolvedValue: the value of a finished future, null otherwise',
    () async {
      final done = defer(Future<int>.value(7));
      await done;
      expect(resolvedValue(done), 7);
      expect(resolvedValue(Completer<int>().future), isNull);
      final failed = defer(Future<int>.error(StateError('x')));
      await failed.then((_) {}, onError: (_) {});
      expect(resolvedValue(failed), isNull);
      expect(resolvedValue<int>(null), isNull);
    },
  );

  test('thor_test client (not streamed): head flag changes nothing', () async {
    product.complete(const _Product('Shampoo'));
    related.complete('x');
    final r = await handler().handle(get('/p'), stream: false);
    expect(r.status, 200);
    expect(utf8.decode(r.body), contains('<title>Shampoo</title>'));
  });

  test(
    'a layout level: its NotFound is the layout error, page never runs',
    () async {
      final layoutFuture = Completer<String>();
      layoutFuture.future.ignore();
      var pageRan = false;
      final h = RouteHandler<Widget>(
        renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
        onError: (request, error, stack) => errors.add(error),
        routes: [
          LayoutRoute<Widget, ({Future<String> v})>(
            load: (r) => (v: defer(layoutFuture.future, head: true)),
            build: (s, child) =>
                Column(children: [const Text('layout'), child]),
            children: [
              PageRoute<Widget, void>(
                path: 'p',
                load: (r) {},
                build: (s) {
                  pageRan = true;
                  return const Text('page body');
                },
              ),
            ],
          ),
        ],
      );
      Future<void>.delayed(
        const Duration(milliseconds: 20),
        () => layoutFuture.completeError(const NotFound()),
      );
      final r = await h.handle(get('/p'));
      expect(r.status, 404);
      expect(pageRan, isFalse);
    },
  );

  test(
    'several head futures: each has its own budget, the first error wins',
    () async {
      final fast = Completer<String>()..future.ignore();
      final slow = Completer<String>()..future.ignore();
      final h = RouteHandler<Widget>(
        renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
        onError: (request, error, stack) => errors.add(error),
        routes: [
          PageRoute<Widget, void>(
            path: 'p',
            load: (r) {
              defer(
                slow.future,
                head: true,
                headBudget: const Duration(milliseconds: 40),
              );
              defer(
                fast.future,
                head: true,
                headBudget: const Duration(milliseconds: 400),
              );
            },
            build: (s) => const Text('body'),
          ),
        ],
      );
      // `slow` is pending past its own 40 ms; `fast` ends inside its 400 ms.
      Future<void>.delayed(
        const Duration(milliseconds: 120),
        () => fast.completeError(const NotFound()),
      );
      final r = await h.handle(get('/p'));
      expect(r.status, 404);
    },
  );

  PageRequest getAs(String agent) => PageRequest(
    method: HttpMethod.get,
    uri: Uri.parse('http://site.test/p'),
    headers: {HttpHeader.host: 'site.test', HttpHeader.userAgent: agent},
  );

  test(
    'a link-preview bot waits longer: its og tags need the real name',
    () async {
      budget = const Duration(milliseconds: 50);
      Future<void>.delayed(
        const Duration(milliseconds: 200),
        () => product.complete(const _Product('Shampoo')),
      );
      final r = await handler().handle(
        getAs(
          'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)',
        ),
      );
      expect(r.status, 200);
      expect(await shell(r), contains('<title>Shampoo</title>'));
      related.complete('x');
    },
  );

  test('a bot gets the real 404 of a slow product too', () async {
    budget = const Duration(milliseconds: 50);
    Future<void>.delayed(
      const Duration(milliseconds: 200),
      () => product.completeError(const NotFound()),
    );
    final r = await handler().handle(
      getAs('Mozilla/5.0 (compatible; Bingbot/2.0)'),
    );
    expect(r.status, 404);
    related.complete('x');
  });

  test('the bot wait is bounded by headBotBudget', () async {
    budget = const Duration(milliseconds: 50);
    final started = DateTime.now();
    final r = await handler(
      botBudget: const Duration(milliseconds: 120),
    ).handle(getAs('Twitterbot/1.0'));
    final waited = DateTime.now().difference(started);
    expect(waited, greaterThanOrEqualTo(const Duration(milliseconds: 100)));
    expect(waited, lessThan(const Duration(milliseconds: 600)));
    expect(r.status, 200);
    expect(await shell(r), contains('Loading product'));
    product.complete(const _Product('late'));
    related.complete('x');
  });

  test('a browser is not a bot: it keeps the short budget', () async {
    budget = const Duration(milliseconds: 50);
    Future<void>.delayed(
      const Duration(milliseconds: 300),
      () => product.complete(const _Product('Shampoo')),
    );
    final r = await handler().handle(
      getAs('Mozilla/5.0 (Macintosh) Chrome/120'),
    );
    expect(await shell(r), contains('<title>Loading product</title>'));
    related.complete('x');
  });
}

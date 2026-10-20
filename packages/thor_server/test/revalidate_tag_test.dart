// Tag-based page cache invalidation: pages declare `tags`, an action calls
// `revalidateTag`, every isolate hears it through the cache bus.
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:thor_server/src/cache_bus.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

PageRequest _get(String path) => PageRequest(
  method: HttpMethod.get,
  uri: Uri.parse('http://site.test$path'),
  headers: {HttpHeader.host: 'site.test'},
);

PageRequest _post(String path) => PageRequest(
  method: HttpMethod.post,
  uri: Uri.parse('http://site.test$path'),
  headers: {
    HttpHeader.host: 'site.test',
    HttpHeader.origin: 'http://site.test',
    HttpHeader.contentType: 'application/x-www-form-urlencoded',
  },
  body: Stream.value(utf8.encode('a=1')),
);

void main() {
  late ReceivePort probe;
  late List<Object?> heard;
  late Map<String, int> renders;
  late RouteHandler<String> handler;

  PageRoute<String, int> page(
    String path,
    List<String> tags, {
    bool onWrite = true,
  }) => PageRoute<String, int>(
    path: path,
    tags: tags,
    invalidateOnWrite: onWrite,
    load: (_) => renders[path] = (renders[path] ?? 0) + 1,
    build: (s) => '$path ${s.data}',
    cache: const Duration(minutes: 1),
    actions: {
      'buy': (_) {
        revalidateTag('cart');
        return null;
      },
      'plain': (_) => null,
      'fail': (_) {
        revalidateTag('cart');
        return const ActionResult.fail(422, {'error': 'x'});
      },
    },
  );

  setUp(() {
    CacheBus.reset();
    probe = ReceivePort();
    heard = [];
    probe.listen(heard.add);
    CacheBus.connect([probe.sendPort]);
    renders = {};
    handler = RouteHandler<String>(
      renderer: _Renderer(),
      routes: [
        page('cart', ['cart']),
        page('news', ['news']),
        page('both', ['cart', 'news']),
        page('plain', const []),
        page('pinned', ['pin'], onWrite: false),
      ],
    );
  });

  tearDown(() {
    CacheBus.reset();
    probe.close();
  });

  Future<void> until(bool Function() ok) async {
    final end = DateTime.now().add(const Duration(seconds: 20));
    while (!ok() && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  Future<void> settle() async {
    await until(() => !CacheBus.pending);
    probe.sendPort.send('flush');
    await until(() => heard.contains('flush'));
    heard.remove('flush');
  }

  Future<void> warm() async {
    for (final p in ['/cart', '/news', '/both', '/plain', '/pinned']) {
      await handler.handle(_get(p));
      await handler.handle(_get(p));
    }
    expect(renders.values, everyElement(1));
  }

  test('revalidateTag renders again only the pages with that tag', () async {
    await warm();
    revalidateTag('cart');
    for (final p in ['/cart', '/news', '/both', '/plain', '/pinned']) {
      await handler.handle(_get(p));
    }
    expect(renders, {'cart': 2, 'news': 1, 'both': 2, 'plain': 1, 'pinned': 1});
  });

  test(
    'an action that revalidates and succeeds is a write: every page renders again',
    () async {
      await warm();
      final r = await handler.handle(_post('/plain?/buy'));
      expect(r.status, lessThan(400));
      for (final p in ['/cart', '/news', '/both', '/pinned']) {
        await handler.handle(_get(p));
      }
      // Tags add a way to revalidate: an ordinary write still clears tagged
      // pages (stale data is worse than a miss).
      expect(renders, {
        'cart': 2,
        'news': 2,
        'both': 2,
        'plain': 1,
        'pinned': 1,
      });
    },
  );

  test('a successful write clears tagged pages too', () async {
    await warm();
    await handler.handle(_post('/plain?/plain'));
    await handler.handle(_get('/plain'));
    await handler.handle(_get('/cart'));
    expect(renders['plain'], 2);
    expect(renders['cart'], 2);
  });

  test(
    'invalidateOnWrite: false waits for its tag or its cache time',
    () async {
      await warm();
      await handler.handle(_post('/plain?/plain'));
      await handler.handle(_get('/pinned'));
      expect(renders['pinned'], 1, reason: 'a write does not clear it');
      revalidateTag('pin');
      await handler.handle(_get('/pinned'));
      expect(renders['pinned'], 2);
    },
  );

  test('a render that started before a write is not cached either', () async {
    final gate = Completer<void>();
    final started = Completer<void>();
    var first = true;
    PageRoute<String, int> slow(String path, {required bool onWrite}) =>
        PageRoute<String, int>(
          path: path,
          tags: const ['t'],
          invalidateOnWrite: onWrite,
          load: (_) async {
            if (first) {
              first = false;
              started.complete();
              await gate.future;
            }
            return 1;
          },
          build: (s) => 'v',
          cache: const Duration(minutes: 1),
        );
    final h = RouteHandler<String>(
      renderer: _Renderer(),
      routes: [
        slow('slow', onWrite: true),
        PageRoute<String, void>(
          path: 'w',
          build: (s) => 'w',
          actions: {'default': (_) => null},
        ),
      ],
    );
    final stale = h.handle(_get('/slow'), stream: false);
    await started.future;
    await h.handle(_post('/w'));
    gate.complete();
    await stale;
    expect(h.cachedPaths, isEmpty);
  });

  test('an unknown tag clears nothing', () async {
    await warm();
    revalidateTag('nope');
    for (final p in ['/cart', '/news', '/both', '/plain', '/pinned']) {
      await handler.handle(_get(p));
    }
    expect(renders.values, everyElement(1));
  });

  test('the peers are told which tag, once per burst', () async {
    revalidateTag('cart');
    revalidateTag('news');
    revalidateTag('cart');
    await settle();
    final tags = heard.whereType<List<Object?>>().expand((l) => l).toSet();
    expect(tags, {'cart', 'news'});
    expect(heard.length, lessThanOrEqualTo(2));
  });

  test(
    'a tag heard from a peer clears the local cache, not announced again',
    () async {
      await warm();
      CacheBus.inbox.send(['news']);
      await until(() => !handler.cachedPaths.any((p) => p.endsWith('/news')));
      for (final p in ['/cart', '/news', '/both', '/plain', '/pinned']) {
        await handler.handle(_get(p));
      }
      expect(renders, {
        'cart': 1,
        'news': 2,
        'both': 2,
        'plain': 1,
        'pinned': 1,
      });
      await settle();
      expect(heard, isEmpty);
    },
  );

  test('a render that started before the revalidation is not cached', () async {
    final gate = Completer<void>();
    final started = Completer<void>();
    var first = true;
    final h = RouteHandler<String>(
      renderer: _Renderer(),
      routes: [
        PageRoute<String, int>(
          path: 'slow',
          tags: const ['cart'],
          load: (_) async {
            if (first) {
              first = false;
              started.complete();
              await gate.future;
              return 1; // data read before the change
            }
            return 2;
          },
          build: (s) => 'v${s.data}',
          cache: const Duration(minutes: 1),
        ),
      ],
    );
    final stale = h.handle(_get('/slow'), stream: false);
    await started.future;
    revalidateTag('cart');
    gate.complete();
    await stale;
    expect(h.cachedPaths, isEmpty);
    final fresh = await h.handle(_get('/slow'), stream: false);
    expect(utf8.decode(fresh.body), 'v2');
  });

  test('a failed action may still revalidate (the app asked)', () async {
    await warm();
    await handler.handle(_post('/plain?/fail'));
    await handler.handle(_get('/cart'));
    expect(renders['cart'], 2);
  });

  test(
    'tags are compared as they are: spaces, newlines, unicode, case',
    () async {
      final h = RouteHandler<String>(
        renderer: _Renderer(),
        routes: [
          page('a', ['user: 1\n2']),
          page('b', ['Ñandú ☃']),
          page('c', ['Cart']),
        ],
      );
      for (final p in ['/a', '/b', '/c']) {
        await h.handle(_get(p));
      }
      revalidateTag('cart'); // another case: not the same tag
      revalidateTag('user: 1');
      for (final p in ['/a', '/b', '/c']) {
        await h.handle(_get(p));
      }
      expect(renders, {'a': 1, 'b': 1, 'c': 1});
      revalidateTag('user: 1\n2');
      revalidateTag('Ñandú ☃');
      for (final p in ['/a', '/b', '/c']) {
        await h.handle(_get(p));
      }
      expect(renders, {'a': 2, 'b': 2, 'c': 1});
    },
  );

  test(
    'a burst of thousands of tags goes out as one bounded message',
    () async {
      for (var i = 0; i < 5000; i++) {
        revalidateTag('user:$i');
      }
      await settle();
      final messages = heard.whereType<List<Object?>>().toList();
      expect(messages.length, lessThanOrEqualTo(2));
      for (final m in messages) {
        expect(m.length, lessThanOrEqualTo(1025));
      }
      // What the peers heard still clears every tagged page.
      final all = messages.expand((m) => m).toSet();
      expect(all, contains('*'));
    },
  );

  test('the wildcard a peer sends clears every tagged page', () async {
    await warm();
    CacheBus.inbox.send(['*']);
    await until(() => !handler.cachedPaths.any((p) => p.endsWith('/pinned')));
    for (final p in ['/cart', '/news', '/both', '/plain', '/pinned']) {
      await handler.handle(_get(p));
    }
    expect(renders, {'cart': 2, 'news': 2, 'both': 2, 'plain': 1, 'pinned': 2});
  });
}

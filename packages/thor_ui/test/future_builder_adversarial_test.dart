@TestOn('vm')
library;

// Fixtures: these builders tell waiting from done with `hasData` only, which
// is not the pattern the guide teaches for a nullable future.
// ignore_for_file: thor_lints/future_builder_nullable_has_data

// Streaming SSR, adversarial: hostile data in late pieces, odd
// futures, broken builders, errors after the shell went out.
import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class EvilState extends ThorState {
  EvilState();
  final note = state('');
  String label() => note.value;
}

final evilState = EvilState();

class RowsState extends ThorState {
  RowsState();
  final rows = state<List<int>>([1, 2, 3]);
  int idOf(int i) => i;
}

final rowsState = RowsState();

class _D {
  final a = Completer<Object?>();
  final b = Completer<Object?>();
  final c = Completer<Object?>();
}

const _evil =
    '</script><script>alert(1)</script><!--thor:2--><!--/thor:1-->--> </div>'
    '"\'  &amp;';

void main() {
  initializeThorTests();
  setUpAll(
    () => ThorState.register({
      EvilState: ThorStateType('EvilState', (state) {
        final s = state as EvilState;
        return [
          ThorMember.state('note', s.note),
          ThorMember('label', s.label, call: (_) => s.label()),
        ];
      }),
      RowsState: ThorStateType('RowsState', (state) {
        final s = state as RowsState;
        return [
          ThorMember.state('rows', s.rows),
          ThorMember(
            'idOf',
            s.idOf,
            arity: 1,
            callWithItem: (i) => s.idOf(i as int),
          ),
        ];
      }),
    }),
  );

  late _D data;
  late List<Object> errors;
  late Widget Function(_D) current;
  late Object? thrownInLoad;

  RouteHandler<Widget> handler({
    Duration timeout = const Duration(seconds: 30),
  }) => RouteHandler<Widget>(
    renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
    deferTimeout: timeout,
    onError: (request, error, stack) => errors.add(error),
    routes: [
      PageRoute<Widget, _D>(
        path: 'x',
        load: (r) {
          if (thrownInLoad != null) throw thrownInLoad!;
          return data;
        },
        build: (s) => current(s.data),
      ),
    ],
  );

  PageRequest get(String path) => PageRequest(
    method: HttpMethod.get,
    uri: Uri.parse('http://site.test$path'),
    headers: {HttpHeader.host: 'site.test'},
  );

  Future<List<String>> pieces(
    ThorResponse r, {
    void Function()? onShell,
  }) async {
    final chunks = <String>[];
    final done = Completer<void>();
    r.stream!.listen((c) => chunks.add(utf8.decode(c)), onDone: done.complete);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    onShell?.call();
    await done.future;
    return chunks;
  }

  setUp(() {
    data = _D();
    errors = [];
    thrownInLoad = null;
  });

  group('hostile data in a late piece', () {
    test('text and attributes cannot break out of the hidden div', () async {
      current = (d) => FutureBuilder<Object?>(
        future: d.a.future,
        builder: (context, snap) => snap.hasData
            ? Column(
                children: [
                  Text('${snap.data}'),
                  Semantics(label: '${snap.data}', child: const Text('x')),
                  Tooltip(message: '${snap.data}', child: const Text('t')),
                ],
              )
            : const Text('loading'),
      );
      final r = await handler().handle(get('/x'));
      final chunks = await pieces(r, onShell: () => data.a.complete(_evil));
      final late = chunks[1];
      // Only the markers the server wrote: none came from the data.
      expect(late, isNot(contains('<!--')));
      expect(late, isNot(contains('--></')));
      // A piece with no state carries no script at all.
      expect('</script'.allMatches(late), isEmpty);
      expect(late, isNot(contains('<script>alert')));
      // The only `</div>` that closes the hidden piece is the last of the
      // div; the data's own is escaped.
      expect(late, isNot(contains('--> </div>')));
      expect(late, contains('&lt;/div&gt;'));
      // Attributes escape their quotes.
      expect(late, contains('aria-label="'));
      expect(late, isNot(contains('aria-label="</')));
    });

    test('a value shaped like a marker cannot hijack another place', () async {
      current = (d) => Column(
        children: [
          FutureBuilder<Object?>(
            future: d.a.future,
            builder: (context, snap) =>
                snap.hasData ? Text('${snap.data}') : const Text('a loading'),
          ),
          FutureBuilder<Object?>(
            future: d.b.future,
            builder: (context, snap) =>
                snap.hasData ? Text('${snap.data}') : const Text('b loading'),
          ),
        ],
      );
      final r = await handler().handle(get('/x'));
      final chunks = await pieces(
        r,
        onShell: () {
          data.a.complete('<!--thor:2--> <!--/thor:2--> </div></div>');
          data.b.complete('B');
        },
      );
      for (final c in chunks.skip(1)) {
        expect('<!--'.allMatches(c), isEmpty);
      }
      // Two pieces, two swaps, ids 1 and 2.
      expect(
        RegExp(
          r'<template data-thor-end="(\d+)"></template>',
        ).allMatches(chunks.join()).map((m) => m[1]),
        unorderedEquals(['1', '2']),
      );
    });

    test(
      'state values with `</script>` and U+2028 stay inside the JSON',
      () async {
        current = (d) => FutureBuilder<Object?>(
          future: d.a.future,
          builder: (context, snap) =>
              snap.hasData ? Watch(evilState.label) : const Text('loading'),
        );
        evilState.note.value = _evil;
        final r = await handler().handle(get('/x'));
        final chunks = await pieces(r, onShell: () => data.a.complete('A'));
        final late = chunks[1];
        final start = late.indexOf('id="thor-s1">');
        expect(start, isNonNegative);
        final json = late.substring(
          start + 'id="thor-s1">'.length,
          late.indexOf('</script>', start),
        );
        expect(json, isNot(contains('<')));
        final decoded = jsonDecode(json) as Map<String, Object?>;
        expect(decoded['EvilState.note'], _evil);
        // json, engine, the engine's prefetch test (it is no longer in the head)
        expect('</script'.allMatches(late).length, 3);
        // Nothing but the server's own script tags opens.
        expect('<script'.allMatches(late).length, 3);
      },
    );
  });

  Widget slot(Future<Object?> f, String name, {Object? initial}) =>
      FutureBuilder<Object?>(
        future: f,
        initialData: initial,
        builder: (context, snap) => snap.hasError
            ? Text('$name failed: ${snap.error}')
            : snap.connectionState == ConnectionState.done
            ? Text('$name done ${snap.data}')
            : Text('$name loading'),
      );

  group('odd futures', () {
    test('null, an empty list and false complete like any value', () async {
      current = (d) => Column(
        children: [
          slot(d.a.future, 'a'),
          slot(d.b.future, 'b'),
          slot(d.c.future, 'c'),
        ],
      );
      final r = await handler().handle(get('/x'));
      final chunks = await pieces(
        r,
        onShell: () {
          data.a.complete(null);
          data.b.complete(<Object>[]);
          data.c.complete(false);
        },
      );
      final late = chunks.skip(1).join();
      expect(late, contains('a done null'));
      expect(late, contains('b done []'));
      expect(late, contains('c done false'));
      expect(errors, isEmpty);
    });

    test('two builders on the same future: two pieces, both filled', () async {
      current = (d) => Column(
        children: [slot(d.a.future, 'first'), slot(d.a.future, 'second')],
      );
      final r = await handler().handle(get('/x'));
      final chunks = await pieces(r, onShell: () => data.a.complete('V'));
      final all = chunks.join();
      expect(all, contains('first done V'));
      expect(all, contains('second done V'));
      expect(r.status, 200);
    });

    test(
      'the same failing future twice reports once per piece, no crash',
      () async {
        current = (d) => Column(
          children: [slot(d.a.future, 'first'), slot(d.a.future, 'second')],
        );
        final r = await handler().handle(get('/x'));
        final chunks = await pieces(
          r,
          onShell: () => data.a.completeError(StateError('x')),
        );
        final all = chunks.join();
        expect(all, contains('first failed'));
        expect(all, contains('second failed'));
        expect(all, endsWith('</body></html>\n'));
      },
    );

    test(
      'a NotFound or a redirect from a deferred value is an error state',
      () async {
        current = (d) =>
            Column(children: [slot(d.a.future, 'a'), slot(d.b.future, 'b')]);
        final r = await handler().handle(get('/x'));
        expect(r.status, 200);
        final chunks = await pieces(
          r,
          onShell: () {
            data.a.completeError(const NotFound('No such product'));
            data.b.completeError(const Redirect(RouteUrl('/login')));
          },
        );
        final late = chunks.skip(1).join();
        expect(late, contains('a failed: No such product'));
        expect(late, contains('b failed: Something went wrong'));
        expect(late, isNot(contains('/login')));
        expect(late, endsWith('</body></html>\n'));
      },
    );

    test(
      'a builder that throws for the result draws the error state',
      () async {
        current = (d) => Column(
          children: [
            FutureBuilder<Object?>(
              future: d.a.future,
              builder: (context, snap) {
                if (snap.hasError) return Text('recovered ${snap.error}');
                if (snap.hasData) throw StateError('bad builder');
                return const Text('loading');
              },
            ),
            slot(d.b.future, 'b'),
          ],
        );
        final r = await handler().handle(get('/x'));
        final chunks = await pieces(
          r,
          onShell: () {
            data.a.complete('A');
            data.b.complete('B');
          },
        );
        final late = chunks.skip(1).join();
        expect(late, contains('recovered'));
        expect(late, contains('b done B'));
        expect(late, endsWith('</body></html>\n'));
      },
    );

    test('a builder that always throws ends with an empty piece', () async {
      current = (d) => FutureBuilder<Object?>(
        future: d.a.future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Text('loading');
          }
          throw StateError('always');
        },
      );
      final r = await handler().handle(get('/x'));
      final chunks = await pieces(r, onShell: () => data.a.complete('A'));
      expect(chunks.last, endsWith('</body></html>\n'));
      expect(chunks.join(), contains('data-thor-end="1"'));
    });

    test(
      'a future that throws synchronously in load is a normal error page',
      () async {
        current = (d) => slot(d.a.future, 'a');
        thrownInLoad = StateError('load blew up');
        final r = await handler().handle(get('/x'));
        expect(r.status, 500);
        expect(r.stream, isNull);
        expect(r.text, isNot(contains(r'$thor')));
        expect(errors, hasLength(1));
      },
    );

    test('100 deferreds: all pieces arrive, ids are unique', () async {
      final cs = [for (var i = 0; i < 100; i++) Completer<Object?>()];
      current = (d) => Column(
        children: [for (var i = 0; i < 100; i++) slot(cs[i].future, 'n$i')],
      );
      final r = await handler().handle(get('/x'));
      final chunks = await pieces(
        r,
        onShell: () {
          for (var i = 99; i >= 0; i--) {
            cs[i].complete(i);
          }
        },
      );
      final all = chunks.join();
      final ids = RegExp(
        r'<template data-thor-end="(\d+)"></template>',
      ).allMatches(all).map((m) => m[1]).toList();
      expect(ids.toSet(), hasLength(100));
      for (var i = 0; i < 100; i++) {
        expect(all, contains('n$i done $i'));
      }
    });

    test('nested 30 deep: each level arrives after its parent', () async {
      const depth = 30;
      final cs = [for (var i = 0; i < depth; i++) Completer<Object?>()];
      Widget level(int i) => FutureBuilder<Object?>(
        future: cs[i].future,
        builder: (context, snap) => snap.hasData
            ? Column(
                children: [
                  Text('L$i'),
                  if (i + 1 < depth) level(i + 1) else const Text('bottom'),
                ],
              )
            : Text('wait $i'),
      );
      current = (d) => level(0);
      final r = await handler().handle(get('/x'));
      final chunks = await pieces(
        r,
        onShell: () {
          for (final c in cs) {
            c.complete('x');
          }
        },
      );
      final all = chunks.join();
      expect(all, contains('bottom'));
      for (var i = 1; i < depth; i++) {
        expect(
          all.indexOf('data-thor-end="$i"'),
          lessThan(all.indexOf('data-thor-end="${i + 1}"')),
        );
      }
      expect(all, endsWith('</body></html>\n'));
    });
  });

  group('where a future does not belong', () {
    test('a FutureBuilder in a Watch.list row: no stray late piece', () async {
      current = (d) => Watch.list<int, int>(
        rowsState.rows.call,
        itemKey: rowsState.idOf,
        each: (row) => FutureBuilder<Object?>(
          future: d.a.future,
          builder: (context, snap) =>
              snap.hasData ? const Text('row done') : const Text('row loading'),
        ),
      );
      final r = await handler().handle(get('/x'));
      final chunks = await pieces(r, onShell: () => data.a.complete('A'));
      final all = chunks.join();
      // The response ends, whatever it did with the template.
      expect(all, endsWith('</body></html>\n'));
      // Every swap that goes out has its markers in the page: a piece for a
      // place that is not there would be a hidden `<div>` nobody removes.
      for (final m in RegExp(
        r'<template data-thor-end="(\d+)"></template>',
      ).allMatches(all)) {
        expect(chunks.first, contains('<!--thor:${m[1]}-->'));
      }
    });

    test('a layout that defers: its place is filled like a page\'s', () async {
      final h = RouteHandler<Widget>(
        renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
        onError: (request, error, stack) => errors.add(error),
        routes: [
          LayoutRoute<Widget, _D>(
            load: (r) => data,
            build: (s, child) =>
                Column(children: [slot(s.data.a.future, 'layout'), child]),
            children: [
              PageRoute<Widget, void>(
                path: 'p',
                load: (r) {},
                build: (s) => const Text('page body'),
              ),
            ],
          ),
        ],
      );
      final r = await h.handle(get('/p'));
      final chunks = await pieces(r, onShell: () => data.a.complete('L'));
      expect(chunks.first, contains('page body'));
      expect(chunks.first, contains('layout loading'));
      expect(chunks.skip(1).join(), contains('layout done L'));
    });

    test('an error page after the shell: the visitor gets the error state '
        'in place, never a half page', () async {
      current = (d) =>
          Column(children: [const Text('shell text'), slot(d.a.future, 'a')]);
      final r = await handler().handle(get('/x'));
      final chunks = await pieces(
        r,
        onShell: () => data.a.completeError(const HttpError(503, 'Back soon')),
      );
      expect(r.status, 200);
      expect(chunks.first, contains('shell text'));
      expect(chunks.skip(1).join(), contains('a failed: Back soon'));
      expect(chunks.last, endsWith('</body></html>\n'));
    });

    test('HEAD is complete and has no body stream issues', () async {
      current = (d) => slot(d.a.future, 'a');
      data.a.complete('A');
      final head = PageRequest(
        method: HttpMethod.head,
        uri: Uri.parse('http://site.test/x'),
        headers: {HttpHeader.host: 'site.test'},
      );
      final r = await handler().handle(head);
      expect(r.status, 200);
      expect(r.stream, isNull);
    });
  });

  group('a client that leaves', () {
    test(
      'cancelling the stream stops the clock: no timeout reported',
      () async {
        current = (d) =>
            Column(children: [slot(d.a.future, 'a'), slot(d.b.future, 'b')]);
        final r = await handler(
          timeout: const Duration(milliseconds: 100),
        ).handle(get('/x'));
        final sub = r.stream!.listen((_) {});
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await sub.cancel();
        // Past the timeout the futures never completed: nobody is there to
        // tell, and the server's log stays clean.
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(errors, isEmpty);
      },
    );

    test(
      'a failure after the client left is not reported twice or at all',
      () async {
        current = (d) => slot(d.a.future, 'a');
        final r = await handler().handle(get('/x'));
        final sub = r.stream!.listen((_) {});
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await sub.cancel();
        data.a.completeError(StateError('late failure'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        // Reported at most once (the future's own error is `defer`-handled).
        expect(errors.length, lessThanOrEqualTo(1));
      },
    );
  });
}

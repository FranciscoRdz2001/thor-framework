// In the lite engine: the query part's `phase` (the finite state a
// QueryBuilder switches on) and `snapshot()` (Flutter's AsyncSnapshot as
// the translator reads it), under node with a fake `fetch`.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/src/lite_bundle.dart';

final _hasNode = Process.runSync('node', ['--version']).exitCode == 0;

String _bundle({required bool minify}) {
  String read(String f) => File('lib/lite/$f').readAsStringSync();
  return liteBundle(
    runtime: read('runtime.js'),
    parts: {
      'json': read('parts/json.js'),
      'server_call': read('parts/server_call.js'),
      'query': read('parts/query.js'),
    },
    stateJs: r'''
const $Q = thor.query;
const $ServerErrorKind$values = Object.freeze(['network', 'timeout', 'aborted', 'unauthorized', 'forbidden', 'validation', 'client', 'server'].map((n, i) => ({ index: i, name: n })));
thor.K = $ServerErrorKind$values;
const $ConnectionState$values = Object.freeze(['none', 'waiting', 'active', 'done'].map((n, i) => ({ index: i, name: n })));
thor.CS = $ConnectionState$values;
thor.def('FeedState', ($) => {
  const items = $Q($, 'FeedState', 'items', null, null);
  const page = $Q($, 'FeedState', 'page', 0, null, 1);
  const slow = $Q($, 'FeedState', 'slow', null, null, 0, 30);
  // `ssr: false`: the translator marks it, the server drew it waiting.
  const lazy = $Q($, 'FeedState', 'lazy', null, null);
  lazy.ssrOff = 1;
  return { items, page, slow, lazy };
});
''',
    minify: minify,
  );
}

// A page without markup, `fetch` answering from `answers` (in order) and
// recording each call; `step()` lets the pending promises settle.
const _page = r'''
globalThis.window = globalThis;
const root = { addEventListener() {}, querySelectorAll: () => [] };
globalThis.document = {
  documentElement: root, querySelectorAll: () => [],
  getElementById: (id) => (id === 'thor-state' && globalThis.__state ? { textContent: globalThis.__state } : null),
  dispatchEvent() {}, cookie: '', createElement: () => ({}),
};
globalThis.CustomEvent = class {};
globalThis.location = { pathname: '/cart', search: '', href: 'http://localhost/cart', assign(u) { calls.push({ assign: u }); } };
globalThis.reportError = () => {};
const calls = [], answers = [];
let inflight = 0, maxInflight = 0, aborts = 0;
const abortError = () => Object.assign(new Error('The operation was aborted'), { name: 'AbortError' });
// [status, body, wait, bodyWait]: status 0, the network fails (fetch
// rejects); -1, fetch rejects with an AbortError nobody asked for; `wait`
// ms until the headers come, `bodyWait` more until the body does (Infinity:
// never). An abort signal ends whatever is pending with an AbortError.
globalThis.fetch = (url, init) => {
  calls.push({ url, headers: init.headers, body: JSON.parse(init.body), signal: init.signal });
  const [status, body, wait = 0, bodyWait = 0] = answers.shift();
  const sig = init.signal;
  const gone = (no, h) => {
    const on = () => { clearTimeout(h); aborts++; no(abortError()); };
    if (sig?.aborted) on(); else sig?.addEventListener('abort', on, { once: true });
  };
  const r = {
    ok: status > 0 && status < 300, status,
    text: () => new Promise((done, no) => {
      if (bodyWait === 0) return done(JSON.stringify(body));
      const h = bodyWait === Infinity ? 0 : setTimeout(() => done(JSON.stringify(body)), bodyWait);
      gone(no, h);
    }),
  };
  maxInflight = Math.max(maxInflight, ++inflight);
  return new Promise((done, no) => {
    const h = setTimeout(() => {
      inflight--;
      if (status === 0) no(new TypeError('Failed to fetch'));
      else if (status < 0) no(abortError());
      else done(r);
    }, wait);
    gone((e) => { inflight--; no(e); }, h);
  });
};
const step = (ms = 0) => new Promise((r) => setTimeout(r, ms));
''';

Map<String, Object?> _run(
  String script, {
  required bool minify,
  String? state,
}) {
  final js =
      '$_page${state == null ? '' : 'globalThis.__state = ${jsonEncode(state)};\n'}'
      '${_bundle(minify: minify)}\n(async () => {\n'
      'await step();\nconst s = thor.use("FeedState");\nconst out = {};\n'
      '$script\nconsole.log(JSON.stringify(out));\n})();';
  final r = Process.runSync('node', ['-e', js]);
  if (r.exitCode != 0) fail('node failed:\n${r.stderr}');
  return jsonDecode((r.stdout as String).trim()) as Map<String, Object?>;
}

// What the page saved for the first paint: the server's value.
const _saved = r'{"FeedState.items$data":[1,2],"FeedState.page$arg":0}';

void main() {
  for (final minify in [false, true]) {
    group(
      minify ? 'minified' : 'as written',
      skip: _hasNode ? false : 'needs node',
      () {
        test('a page with its value is done; its snapshot has the data', () {
          final out = _run(
            r'''
out.phase = s.items.phase();
out.snap = s.items.snapshot();
''',
            minify: minify,
            state: _saved,
          );
          expect(out['phase'], 2);
          expect(out['snap'], {
            'connectionState': {'index': 3, 'name': 'done'},
            'data': [1, 2],
            'hasData': true,
            'error': null,
            'errorKind': null,
            'hasError': false,
          });
        });

        test('a query the browser has not asked yet is waiting, as drawn', () {
          // THOR-S037: the server draws a `ssr: false` query waiting (0); the
          // browser must start there too, or the first change looks like a
          // state the server never drew.
          final out = _run(r'''
out.before = s.lazy.phase();
out.plain = s.items.phase();
answers.push([200, { data: null }, 10]);
s.lazy.refresh();
out.loading = s.lazy.phase();
await step(30);
out.nullAnswer = s.lazy.phase();
answers.push([200, { data: [1] }, 10]);
s.lazy.refresh();
await step(30);
out.done = s.lazy.phase();
''', minify: minify);
          expect(out['before'], 0);
          // One that draws on the server keeps "done without data".
          expect(out['plain'], 4);
          expect(out['loading'], 0);
          expect(out['nullAnswer'], 4);
          expect(out['done'], 2);
        });

        test('a lazy query that fails is failed, one that is answered by a '
            'command leaves waiting', () {
          final out = _run(r'''
answers.push([500, { error: 'no' }]);
s.lazy.refresh();
await step(20);
out.failed = s.lazy.phase();
thor.qs['FeedState.lazy'].put([2], null, undefined);
out.put = s.lazy.phase();
''', minify: minify);
          expect(out['failed'], 3);
          expect(out['put'], 2);
        });

        test('a call on its way is waiting and keeps the stale value', () {
          final out = _run(
            r'''
answers.push([200, { data: [3] }, 20]);
s.items.refresh();
out.phase = s.items.phase();
out.snap = s.items.snapshot();
await step(40);
out.after = s.items.phase();
out.data = s.items.snapshot().data;
''',
            minify: minify,
            state: _saved,
          );
          expect(out['phase'], 1);
          expect((out['snap']! as Map)['connectionState'], {
            'index': 1,
            'name': 'waiting',
          });
          expect((out['snap']! as Map)['data'], [1, 2]);
          expect((out['snap']! as Map)['hasData'], isTrue);
          expect(out['after'], 2);
          expect(out['data'], [3]);
        });

        test('a query that has no value yet is waiting without data', () {
          final out = _run(r'''
answers.push([200, { data: [3] }, 20]);
s.items.refresh();
out.phase = s.items.phase();
out.snap = s.items.snapshot();
''', minify: minify);
          expect(out['phase'], 0);
          expect((out['snap']! as Map)['hasData'], isFalse);
          expect((out['snap']! as Map)['data'], isNull);
        });

        test(
          'a failure has no data, the message and the kind; a retry hides it',
          () {
            final out = _run(
              r'''
answers.push([500, { error: 'Se cayó' }]);
s.items.refresh();
await step(10);
out.phase = s.items.phase();
out.snap = s.items.snapshot();
out.stale = s.items.data.value;
answers.push([200, { data: [7] }, 20]);
s.items.refresh();
out.retry = s.items.phase();
out.retrySnap = s.items.snapshot().hasError;
await step(40);
out.ok = s.items.phase();
''',
              minify: minify,
              state: _saved,
            );
            expect(out['phase'], 3);
            final snap = out['snap']! as Map;
            expect(snap['hasError'], isTrue);
            expect(snap['hasData'], isFalse);
            expect(snap['data'], isNull);
            expect(snap['error'], 'Se cayó');
            expect((snap['errorKind']! as Map)['name'], 'server');
            expect((snap['connectionState']! as Map)['name'], 'done');
            // The signal keeps the last good value.
            expect(out['stale'], [1, 2]);
            expect(out['retry'], 1);
            expect(out['retrySnap'], isFalse);
            expect(out['ok'], 2);
          },
        );

        test(
          'a first paint that failed is a failure with the kind from the page',
          () {
            final out = _run(
              r'''
out.phase = s.items.phase();
out.snap = s.items.snapshot();
''',
              minify: minify,
              state:
                  r'{"FeedState.items$error":"Sin permiso","FeedState.items$errorKind":"forbidden"}',
            );
            expect(out['phase'], 3);
            final snap = out['snap']! as Map;
            expect(snap['error'], 'Sin permiso');
            expect((snap['errorKind']! as Map)['name'], 'forbidden');
          },
        );

        test(
          'a timeout ends as a failure of its kind, never stays waiting',
          () {
            final out = _run(r'''
answers.push([200, { data: 1 }, 500]);
s.slow.refresh();
out.mid = s.slow.phase();
await step(80);
out.phase = s.slow.phase();
out.snap = s.slow.snapshot();
''', minify: minify);
            expect(out['mid'], 0);
            expect(out['phase'], 3);
            expect(
              ((out['snap']! as Map)['errorKind']! as Map)['name'],
              'timeout',
            );
          },
        );

        test('failed, then a retry that times out, then a retry aborted by '
            'another: the phases follow and the last answer wins', () {
          final out = _run(r'''
answers.push([500, { error: 'Se cayó' }]);
s.slow.refresh();
await step(10);
out.failed = s.slow.phase();
answers.push([200, { data: 1 }, 500]);
s.slow.refresh();
out.retry = s.slow.phase();
await step(80);
out.timedOut = s.slow.phase();
out.kind = s.slow.snapshot().errorKind.name;
answers.push([200, { data: 9 }, 5000]);
s.slow.refresh();
answers.push([200, { data: 2 }, 5]);
s.slow.refresh(); // aborts the one before
out.mid = s.slow.phase();
out.midError = s.slow.snapshot().hasError;
await step(40);
out.done = s.slow.phase();
out.data = s.slow.snapshot().data;
out.aborts = aborts;
''', minify: minify);
          expect(out['failed'], 3);
          expect(out['retry'], 0);
          expect(out['timedOut'], 3);
          expect(out['kind'], 'timeout');
          expect(out['mid'], 0);
          expect(out['midError'], isFalse);
          expect(out['done'], 2);
          expect(out['data'], 2);
        });

        test('a null answer is done without data, a state of its own', () {
          final out = _run(
            r'''
answers.push([200, { data: null }, 5]);
s.items.refresh();
out.mid = s.items.phase();
await step(30);
out.phase = s.items.phase();
out.snap = s.items.snapshot();
answers.push([200, { data: [4] }, 5]);
s.items.refresh();
out.retry = s.items.phase();
await step(30);
out.back = s.items.phase();
''',
            minify: minify,
            state: _saved,
          );
          // The value it had is kept while the call is on its way.
          expect(out['mid'], 1);
          expect(out['phase'], 4);
          final snap = out['snap']! as Map;
          expect(snap['connectionState'], {'index': 3, 'name': 'done'});
          expect(snap['hasData'], isFalse);
          expect(snap['hasError'], isFalse);
          expect(out['retry'], 0);
          expect(out['back'], 2);
        });

        test('a new argument keeps the last value while it loads; the call it '
            'aborted never shows', () {
          final out = _run(
            r'''
answers.push([200, { data: 5 }, 5000]);
answers.push([200, { data: 6 }, 10]);
s.page.setArg(1);
s.page.setArg(2); // aborts the first
out.mid = s.page.phase();
await step(40);
out.done = s.page.phase();
out.data = s.page.snapshot().data;
out.error = s.page.snapshot().hasError;
''',
            minify: minify,
            state: r'{"FeedState.page$data":4,"FeedState.page$arg":0}',
          );
          expect(out['mid'], 1);
          expect(out['done'], 2);
          expect(out['data'], 6);
          expect(out['error'], isFalse);
        });
      },
    );
  }
}

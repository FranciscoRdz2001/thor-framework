// The lite parts `query` and `server_command` under node, with a fake
// `fetch`: pending toggles, the result and the error land in their
// signals, a run while pending is ignored, and the page's queries take the
// values the command's answer brings.
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
      'server_command': read('parts/server_command.js'),
    },
    stateJs: r'''
const $Q = thor.query, $SC = thor.command;
const $ServerErrorKind$values = Object.freeze(['network', 'timeout', 'aborted', 'unauthorized', 'forbidden', 'validation', 'client', 'server'].map((n, i) => ({ index: i, name: n })));
thor.K = $ServerErrorKind$values;
thor.def('HeaderState', ($) => {
  const count = $Q($, 'HeaderState', 'count', null, null);
  const items = $Q($, 'HeaderState', 'items', 5, null, 1);
  return { count, items };
});
// Its calls give up after 30 ms.
thor.def('SlowState', ($) => {
  const slow = $Q($, 'SlowState', 'slow', null, null, 0, 30);
  const slowArg = $Q($, 'SlowState', 'slowArg', 0, null, 1, 30);
  const hang = $SC($, 'SlowState', 'hang', null, 1, 30);
  return { slow, slowArg, hang };
});
// `timeout: Duration.zero`: no limit, whatever the page's default.
thor.def('NoLimitState', ($) => {
  const q = $Q($, 'NoLimitState', 'q', null, null, 0, 0);
  const c = $SC($, 'NoLimitState', 'c', null, 0, 0);
  return { q, c };
});
thor.def('CartState', ($) => {
  const lines = $Q($, 'CartState', 'lines', 2, (j) => j.map((x) => x.get('name')), 1);
  const total = $Q($, 'CartState', 'total', null, null);
  const add = $SC($, 'CartState', 'add', null, 1);
  return { lines, total, add };
});
''',
    minify: minify,
  );
}

// A page without markup, `fetch` answering from `answers` (in order) and
// recording each call; `step()` lets the pending promises settle.
const _page = r'''
globalThis.window = globalThis;
const root = { addEventListener(t, f) { (root.h ||= {})[t] = f; }, querySelectorAll: () => [] };
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
      'await step();\nconst s = thor.use("CartState");\nconst out = {};\n'
      '$script\nconsole.log(JSON.stringify(out));\n})();';
  final r = Process.runSync('node', ['-e', js]);
  if (r.exitCode != 0) fail('node failed:\n${r.stderr}');
  return jsonDecode((r.stdout as String).trim()) as Map<String, Object?>;
}

void main() {
  for (final minify in [false, true]) {
    group(
      minify ? 'minified' : 'as written',
      skip: _hasNode ? false : 'needs node',
      () {
        test('pending, result and the queries from the same answer', () {
          final out = _run(r'''
answers.push([200, {
  result: 3,
  queries: { 'CartState.lines': [{ name: 'Taza' }], 'CartState.total': 360 },
}]);
answers.push([200, { result: 4 }]);
s.add.run('taza');
out.pending = s.add.pending.value;
s.add.run('taza'); // while pending: queued, not sent yet
out.calls = calls.length;
out.request = { ...calls[0], signal: undefined };
await step(20);
out.callsAfter = calls.length;
out.after = s.add.pending.value;
out.result = s.add.result.value;
out.lines = s.lines.data.value;
out.total = s.total.data.value;
out.error = s.add.error.value;
''', minify: minify);
          expect(out['pending'], isTrue);
          expect(out['calls'], 1);
          expect(out['request'], {
            'url': '/cart',
            'headers': {
              'content-type': 'application/json',
              'x-thor-command': 'CartState.add',
            },
            // The argument, and the current argument of every query of the
            // page (null for one that takes none): the server refreshes
            // those and no others.
            'body': {
              'arg': 'taza',
              'queries': {'CartState.lines': 2, 'CartState.total': null},
            },
          });
          // The second run waited its turn and went out after the first.
          expect(out['callsAfter'], 2);
          expect(out['after'], isFalse);
          expect(out['result'], 4);
          expect(out['lines'], ['Taza']);
          expect(out['total'], 360);
          expect(out['error'], isNull);
        });

        test('a stay form that was answered asks the queries again', () {
          final out = _run(r'''
answers.push([200, { data: [{ name: 'Nueva' }] }]);
answers.push([200, { data: 360 }]);
root.h['thor:stay']({ detail: { ok: false } });
out.skipped = calls.length;
root.h['thor:stay']({ detail: { ok: true } });
await step(20);
out.asked = calls.map((c) => c.headers['x-thor-query']).sort();
out.lines = s.lines.data.value;
''', minify: minify);
          expect(out['skipped'], 0);
          expect(out['asked'], ['CartState.lines', 'CartState.total']);
          expect(out['lines'], ['Nueva']);
        });

        test(
          'an error keeps the queries, a failing query gets its message',
          () {
            final out = _run(r'''
answers.push([409, { error: 'Ya no hay existencias.' }]);
s.add.run('termo');
await step();
out.error = s.add.error.value;
out.pending = s.add.pending.value;
out.total = s.total.data.value;
answers.push([200, { data: [{ name: 'old' }] }, 30]);
answers.push([200, { result: 1, queries: { 'CartState.lines': [] }, errors: { 'CartState.total': 'Something went wrong' } }]);
s.lines.setArg(9); // the query's own call, slower…
s.add.run('taza');
await step(60);
out.cleared = s.add.error.value;
out.lines = s.lines.data.value; // …dropped: the command's answer is newer
out.linesLoading = s.lines.loading.value;
out.totalError = s.total.error.value;
out.sentArg = calls[2].body.queries['CartState.lines'];
''', minify: minify);
            expect(out['error'], 'Ya no hay existencias.');
            expect(out['pending'], isFalse);
            expect(out['total'], isNull);
            expect(out['cleared'], isNull);
            expect(out['lines'], isEmpty);
            expect(out['linesLoading'], isFalse);
            expect(out['totalError'], 'Something went wrong');
            expect(out['sentArg'], 9);
          },
        );

        group('runs queue', () {
          test('two runs go out in order, one at a time, both resolve', () {
            final out = _run(r'''
answers.push([200, { result: 1 }, 20]);
answers.push([200, { result: 2 }]);
const p1 = s.add.run('a'), p2 = s.add.run('b');
out.now = calls.length;
out.pendingFor = [s.add.pendingFor('a'), s.add.pendingFor('b'), s.add.pendingFor('c')];
out.rs = await Promise.all([p1, p2]);
out.order = calls.map((c) => c.body.arg);
out.max = maxInflight;
out.pending = s.add.pending.value;
out.result = s.add.result.value;
out.pendingFor2 = [s.add.pendingFor('a'), s.add.pendingFor('b')];
''', minify: minify);
            expect(out['now'], 1);
            expect(out['pendingFor'], [true, true, false]);
            expect(out['rs'], [1, 2]);
            expect(out['order'], ['a', 'b']);
            expect(out['max'], 1);
            expect(out['pending'], isFalse);
            expect(out['result'], 2);
            expect(out['pendingFor2'], [false, false]);
          });

          test('ten runs: in order, never two on the wire, none lost', () {
            final out = _run(r'''
for (let i = 0; i < 10; i++) answers.push([200, { result: i }, i % 3]);
const ps = [];
for (let i = 0; i < 10; i++) ps.push(s.add.run(`r${i}`));
out.pendingMid = s.add.pending.value;
out.rs = await Promise.all(ps);
out.order = calls.map((c) => c.body.arg);
out.max = maxInflight;
out.pending = s.add.pending.value;
''', minify: minify);
            expect(out['pendingMid'], isTrue);
            expect(out['rs'], List.generate(10, (i) => i));
            expect(out['order'], List.generate(10, (i) => 'r$i'));
            expect(out['max'], 1);
            expect(out['pending'], isFalse);
          });

          test('a failed run resolves null and the next one still goes', () {
            final out = _run(r'''
answers.push([409, { error: 'Ya no hay existencias.' }]);
answers.push([0, null]);
answers.push([200, { result: 7 }]);
const ps = [s.add.run('a'), s.add.run('b'), s.add.run('c')];
const rs = await Promise.all(ps);
out.rs = rs;
out.error = s.add.error.value;
out.calls = calls.length;
''', minify: minify);
            expect(out['rs'], [null, null, 7]);
            expect(out['error'], isNull);
            expect(out['calls'], 3);
          });

          test('a run made from inside an answer waits for the queue', () {
            final out = _run(r'''
answers.push([200, { result: 1 }, 10]);
answers.push([200, { result: 2 }]);
answers.push([200, { result: 3 }]);
const p1 = s.add.run('a');
const chained = p1.then(() => s.add.run('c'));
const p2 = s.add.run('b');
await Promise.all([p1, p2, chained]);
out.order = calls.map((c) => c.body.arg);
''', minify: minify);
            expect(out['order'], ['a', 'b', 'c']);
          });

          test(
            'a command run does not wait for a query refresh (and back)',
            () {
              final out = _run(r'''
answers.push([200, { data: [{ name: 'p2' }] }, 30]);
answers.push([200, { result: 5 }, 5]);
s.lines.setArg(3);
const p = s.add.run('a');
out.sent = calls.length; // both are already on the wire
out.loadingMid = s.lines.loading.value;
await p;
out.result = s.add.result.value;
await step(60);
out.lines = s.lines.data.value; // the command's answer had no queries: the refresh lands
out.loading = s.lines.loading.value;
''', minify: minify);
              expect(out['sent'], 2);
              expect(out['loadingMid'], isTrue);
              expect(out['result'], 5);
              expect(out['lines'], ['p2']);
              expect(out['loading'], isFalse);
            },
          );
        });

        group('the queries the page has', () {
          test('every query of the page is named, its argument sent', () {
            final out = _run(r'''
answers.push([200, { result: 1 }]);
s.lines.arg.value = 7;
await s.add.run('a');
out.queries = calls[0].body.queries;
''', minify: minify);
            expect(out['queries'], {
              'CartState.lines': 7,
              'CartState.total': null,
            });
          });

          test('a state the page drew but nobody touched is named too', () {
            final out = _run(
              r'''
out.before = Object.keys(thor.qs);
answers.push([200, { result: 1 }]);
await s.add.run('a');
out.queries = calls[0].body.queries;
''',
              minify: minify,
              state:
                  '{"!q":["CartState.lines","CartState.total",'
                  '"HeaderState.count","HeaderState.items"]}',
            );
            expect(out['before'], ['CartState.lines', 'CartState.total']);
            expect(out['queries'], {
              'CartState.lines': 2,
              'CartState.total': null,
              'HeaderState.count': null,
              'HeaderState.items': 5,
            });
          });

          test('a hostile list of the page is ignored, never thrown', () {
            for (final list in [
              '["__proto__.x","Nope.q",5,null,{},"a","..","HeaderState"]',
              '"HeaderState.count"',
              '{"0":"HeaderState.count"}',
              '7',
            ]) {
              final out = _run(
                r'''
answers.push([200, { result: 1 }]);
out.r = await s.add.run('a');
out.queries = calls[0].body.queries;
''',
                minify: minify,
                state: '{"!q":$list}',
              );
              expect(out['r'], 1, reason: list);
              expect(out['queries'], {
                'CartState.lines': 2,
                'CartState.total': null,
              }, reason: list);
            }
          });
        });

        group('a stale answer never lands', () {
          test('the argument moved on while the command flew: dropped', () {
            final out = _run(r'''
answers.push([200, { result: 1, queries: { 'CartState.lines': [{ name: 'p1' }] } }, 30]);
answers.push([200, { data: [{ name: 'p2' }] }, 70]);
s.lines.arg.value = 1;
const p = s.add.run('a');           // sent with lines at page 1
s.lines.setArg(2);                  // the user goes to page 2
await p;                            // the command's answer: page 1 data
out.mid = s.lines.data.value;
out.midArg = s.lines.arg.value;
out.midLoading = s.lines.loading.value; // page 2 is still on its way
await step(100);
out.lines = s.lines.data.value;
out.loading = s.lines.loading.value;
out.error = s.lines.error.value;
''', minify: minify);
            expect(out['mid'], isNull);
            expect(out['midArg'], 2);
            expect(out['midLoading'], isTrue);
            expect(out['lines'], ['p2']);
            expect(out['loading'], isFalse);
            expect(out['error'], isNull);
          });

          test('an error computed for the old argument is dropped too', () {
            final out = _run(r'''
answers.push([200, { result: 1, errors: { 'CartState.lines': 'Something went wrong' } }, 10]);
answers.push([200, { data: [{ name: 'p2' }] }, 30]);
s.lines.arg.value = 1;
const p = s.add.run('a');
s.lines.setArg(2);
await p;
out.mid = s.lines.error.value;
await step(50);
out.lines = s.lines.data.value;
out.error = s.lines.error.value;
''', minify: minify);
            expect(out['mid'], isNull);
            expect(out['lines'], ['p2']);
            expect(out['error'], isNull);
          });

          test('the argument came back to the one sent: it lands', () {
            final out = _run(r'''
answers.push([200, { result: 1, queries: { 'CartState.lines': [{ name: 'p1' }] } }, 20]);
answers.push([200, { data: [{ name: 'p2' }] }, 5]);
answers.push([200, { data: [{ name: 'p1-late' }] }, 60]);
s.lines.arg.value = 1;
const p = s.add.run('a');
s.lines.setArg(2);
s.lines.setArg(1);   // back to what the command sent, its own call still on its way
await p;
out.mid = s.lines.data.value;
out.loading = s.lines.loading.value;
await step(100);
out.late = s.lines.data.value; // the command's answer was newer: the slow call is dropped
''', minify: minify);
            expect(out['mid'], ['p1']);
            expect(out['loading'], isFalse);
            expect(out['late'], ['p1']);
          });

          test(
            'the same argument: the command answer wins over a slow refresh',
            () {
              final out = _run(r'''
answers.push([200, { data: [{ name: 'old' }] }, 40]);
answers.push([200, { result: 1, queries: { 'CartState.lines': [{ name: 'new' }] } }, 5]);
s.lines.refresh();
await s.add.run('a');
await step(60);
out.lines = s.lines.data.value;
''', minify: minify);
              expect(out['lines'], ['new']);
            },
          );

          test('a query without argument always takes the answer', () {
            final out = _run(r'''
answers.push([200, { result: 1, queries: { 'CartState.total': 99 } }]);
await s.add.run('a');
out.total = s.total.data.value;
''', minify: minify);
            expect(out['total'], 99);
          });
        });

        group('abort and timeout', () {
          test(
            'each keystroke aborts the call before it; only the last lands',
            () {
              final out = _run(r'''
answers.push([200, { data: [{ name: 'a' }] }, 50]);
answers.push([200, { data: [{ name: 'b' }] }, 50]);
answers.push([200, { data: [{ name: 'c' }] }, 5]);
s.lines.setArg(1);
s.lines.setArg(2);
s.lines.setArg(3);
out.mid = s.lines.loading.value;
await step(80);
out.aborted = calls.map((c) => c.signal.aborted);
out.max = maxInflight;
out.lines = s.lines.data.value;
out.loading = s.lines.loading.value;
out.error = s.lines.error.value;
''', minify: minify);
              expect(out['aborted'], [true, true, false]);
              expect(out['max'], 1);
              expect(out['mid'], isTrue);
              expect(out['lines'], ['c']);
              expect(out['loading'], isFalse);
              expect(out['error'], isNull);
            },
          );

          test(
            'refresh() again aborts the first, a network error ends loading',
            () {
              final out = _run(r'''
answers.push([200, { data: [{ name: 'a' }] }, 50]);
answers.push([0, null, 5]);
s.lines.refresh();
s.lines.refresh();
await step(30);
out.aborted = calls.map((c) => c.signal.aborted);
out.loading = s.lines.loading.value;
out.error = typeof s.lines.error.value;
''', minify: minify);
              expect(out['aborted'], [true, false]);
              expect(out['loading'], isFalse);
              expect(out['error'], 'string');
            },
          );

          test(
            'a hung call ends in an error at its timeout, loading back to false',
            () {
              final out = _run(r'''
const sl = thor.use('SlowState');
answers.push([200, { data: 1 }, 5000]);
sl.slow.refresh();
out.mid = sl.slow.loading.value;
await step(80);
out.aborted = calls[0].signal.aborted;
out.loading = sl.slow.loading.value;
out.error = typeof sl.slow.error.value;
out.data = sl.slow.data.value;
''', minify: minify);
              expect(out['mid'], isTrue);
              expect(out['aborted'], isTrue);
              expect(out['loading'], isFalse);
              expect(out['error'], 'string');
              expect(out['data'], isNull);
            },
          );

          test('a body that never finishes times out too', () {
            final out = _run(r'''
const sl = thor.use('SlowState');
answers.push([200, { data: 1 }, 2, Infinity]);
sl.slow.refresh();
await step(80);
out.loading = sl.slow.loading.value;
out.error = typeof sl.slow.error.value;
out.aborted = calls[0].signal.aborted;
''', minify: minify);
            expect(out['loading'], isFalse);
            expect(out['error'], 'string');
            expect(out['aborted'], isTrue);
          });

          test('an answer in time clears the timer: no error later', () {
            final out = _run(r'''
const sl = thor.use('SlowState');
answers.push([200, { data: 1 }, 5]);
sl.slow.refresh();
await step(80);
out.data = sl.slow.data.value;
out.error = sl.slow.error.value;
out.aborted = calls[0].signal.aborted;
''', minify: minify);
            expect(out['data'], 1);
            expect(out['error'], isNull);
            expect(out['aborted'], isFalse);
          });

          test('a call replaced before its timeout leaves no error behind', () {
            final out = _run(r'''
const sl = thor.use('SlowState');
answers.push([200, { data: 1 }, 5000]);
answers.push([200, { data: 2 }, 5]);
sl.slowArg.setArg(1);
sl.slowArg.setArg(2);
await step(80);
out.data = sl.slowArg.data.value;
out.error = sl.slowArg.error.value;
out.aborted = calls.map((c) => c.signal.aborted);
''', minify: minify);
            expect(out['data'], 2);
            expect(out['error'], isNull);
            expect(out['aborted'], [true, false]);
          });

          test('an abort nobody asked for still ends loading', () {
            final out = _run(r'''
answers.push([-1, null, 5]);
s.lines.refresh();
await step(30);
out.loading = s.lines.loading.value;
out.error = typeof s.lines.error.value;
''', minify: minify);
            expect(out['loading'], isFalse);
            expect(out['error'], 'string');
          });

          test(
            'a command answer aborts the refresh of the same query in flight',
            () {
              final out = _run(r'''
answers.push([200, { data: [{ name: 'old' }] }, 500]);
answers.push([200, { result: 1, queries: { 'CartState.lines': [{ name: 'new' }] } }, 5]);
s.lines.refresh();
await s.add.run('a');
out.aborted = calls.map((c) => c.signal.aborted);
out.lines = s.lines.data.value;
out.loading = s.lines.loading.value;
''', minify: minify);
              expect(out['aborted'], [true, false]);
              expect(out['lines'], ['new']);
              expect(out['loading'], isFalse);
            },
          );

          test(
            'a command that hangs times out; the next queued run still goes',
            () {
              final out = _run(r'''
const sl = thor.use('SlowState');
answers.push([200, { result: 1 }, 5000]);
answers.push([200, { result: 2 }, 5]);
const p1 = sl.hang.run('a'), p2 = sl.hang.run('b');
out.rs = await Promise.all([p1, p2]);
out.aborted = calls.map((c) => c.signal.aborted);
out.pending = sl.hang.pending.value;
out.error = sl.hang.error.value;
out.result = sl.hang.result.value;
''', minify: minify);
              expect(out['rs'], [null, 2]);
              expect(out['aborted'], [true, false]);
              expect(out['pending'], isFalse);
              expect(out['error'], isNull);
              expect(out['result'], 2);
            },
          );

          test(
            'a command that hangs alone: an error, pending back to false',
            () {
              final out = _run(r'''
const sl = thor.use('SlowState');
answers.push([200, { result: 1 }, 5000]);
out.r = await sl.hang.run('a');
out.pending = sl.hang.pending.value;
out.error = typeof sl.hang.error.value;
out.pendingFor = sl.hang.pendingFor('a');
''', minify: minify);
              expect(out['r'], isNull);
              expect(out['pending'], isFalse);
              expect(out['error'], 'string');
              expect(out['pendingFor'], isFalse);
            },
          );
        });

        group('messages and error kinds', () {
          // What the server wrote in the page for the browser to show.
          const messages =
              '"!m":{"network":"Sin conexión","timeout":"Tardó demasiado",'
              '"aborted":"Cancelado","generic":"Algo salió mal"}';
          Map<String, Object?> kinds(String script, {String? state}) =>
              _run(script, minify: minify, state: state ?? '{$messages}');

          test('a network error says what the server wrote, kind network', () {
            final out = kinds(r'''
answers.push([0, null]);
s.lines.refresh();
await step(10);
out.q = [s.lines.error.value, s.lines.errorKind.value?.name];
answers.push([0, null]);
await s.add.run('a');
out.c = [s.add.error.value, s.add.errorKind.value?.name];
''');
            expect(out['q'], ['Sin conexión', 'network']);
            expect(out['c'], ['Sin conexión', 'network']);
          });

          test(
            'timeout and an abort nobody asked for have their own kinds',
            () {
              final out = kinds(r'''
const sl = thor.use('SlowState');
answers.push([200, { data: 1 }, 5000]);
sl.slow.refresh();
await step(80);
out.timeout = [sl.slow.error.value, sl.slow.errorKind.value?.name, sl.slow.loading.value];
answers.push([-1, null]);
sl.slow.refresh();
await step(20);
out.aborted = [sl.slow.error.value, sl.slow.errorKind.value?.name];
answers.push([200, { result: 1 }, 5000]);
out.cmd = [await sl.hang.run('a'), sl.hang.error.value, sl.hang.errorKind.value?.name];
''');
              expect(out['timeout'], ['Tardó demasiado', 'timeout', false]);
              expect(out['aborted'], ['Cancelado', 'aborted']);
              expect(out['cmd'], [null, 'Tardó demasiado', 'timeout']);
            },
          );

          test('the status is the kind; the server\'s own message wins', () {
            final out = kinds(r'''
const rows = [];
for (const [status, body] of [
  [401, { error: 'Entra otra vez' }], [403, { error: 'No puedes' }],
  [400, { error: 'Mal dato' }], [422, { error: 'No válido' }],
  [404, { error: 'No existe' }], [409, { error: 'Conflicto' }],
  [429, { error: 'Calma' }], [500, { error: 'Falló' }],
]) {
  answers.push([status, body]);
  await s.add.run('a');
  rows.push([status, s.add.error.value, s.add.errorKind.value.name]);
}
out.rows = rows;
''');
            expect(out['rows'], [
              [401, 'Entra otra vez', 'unauthorized'],
              [403, 'No puedes', 'forbidden'],
              [400, 'Mal dato', 'validation'],
              [422, 'No válido', 'validation'],
              [404, 'No existe', 'client'],
              [409, 'Conflicto', 'client'],
              [429, 'Calma', 'client'],
              [500, 'Falló', 'server'],
            ]);
          });

          test('an answer that is not the server\'s (a proxy) is generic', () {
            final out = kinds(r'''
answers.push([502, '<html>Bad gateway</html>']);
s.lines.refresh();
await step(10);
out.q = [s.lines.error.value, s.lines.errorKind.value.name];
answers.push([504, null]);
await s.add.run('a');
out.c = [s.add.error.value, s.add.errorKind.value.name];
''');
            expect(out['q'], ['Algo salió mal', 'server']);
            expect(out['c'], ['Algo salió mal', 'server']);
          });

          test('success clears the kind with the error', () {
            final out = kinds(r'''
answers.push([500, { error: 'x' }]);
answers.push([200, { result: 1 }]);
await s.add.run('a');
out.a = s.add.errorKind.value?.name;
await s.add.run('a');
out.b = [s.add.error.value, s.add.errorKind.value];
''');
            expect(out['a'], 'server');
            expect(out['b'], [null, null]);
          });

          test('a query that failed inside a command answer has its kind', () {
            final out = kinds(r'''
answers.push([200, { result: 1, errors: { 'CartState.lines': 'No puedes' }, kinds: { 'CartState.lines': 'forbidden' } }]);
await s.add.run('a');
out.a = [s.lines.error.value, s.lines.errorKind.value?.name];
answers.push([200, { result: 1, errors: { 'CartState.total': 'Falló' }, kinds: { 'CartState.total': '__proto__' } }]);
await s.add.run('a');
out.b = [s.total.error.value, s.total.errorKind.value ?? null];
answers.push([200, { result: 1, queries: { 'CartState.lines': [] } }]);
await s.add.run('a');
out.c = [s.lines.error.value, s.lines.errorKind.value ?? null];
''');
            expect(out['a'], ['No puedes', 'forbidden']);
            // An unknown kind is not a kind: the message still shows.
            expect(out['b'], ['Falló', null]);
            expect(out['c'], [null, null]);
          });

          test(
            'a page without messages shows the kind, never invented prose',
            () {
              final out = kinds(r'''
answers.push([0, null]);
await s.add.run('a');
out.a = s.add.error.value;
''', state: '{}');
              expect(out['a'], 'network');
            },
          );

          test('hostile messages are ignored', () {
            for (final m in [
              '"!m":"network"',
              '"!m":[1]',
              '"!m":{"network":5,"timeout":null,"generic":{}}',
              '"!m":{"__proto__":"x","network":"ok"}',
            ]) {
              final out = kinds(r'''
answers.push([0, null]);
await s.add.run('a');
out.a = s.add.error.value;
answers.push([500, '<x>']);
await s.add.run('a');
out.b = s.add.error.value;
''', state: '{$m}');
              expect(
                out['a'],
                m.contains('"network":"ok"') ? 'ok' : 'network',
                reason: m,
              );
              expect(out['b'], isA<String>(), reason: m);
            }
          });

          test(
            'the server\'s kind of a failed first paint comes with the page',
            () {
              final out = kinds(
                r'''
out.q = [s.total.error.value, s.total.errorKind.value?.name];
''',
                state:
                    '{$messages,"CartState.total\$error":"Algo salió mal",'
                    '"CartState.total\$errorKind":"server"}',
              );
              expect(out['q'], ['Algo salió mal', 'server']);
              final bad = kinds(
                r'''
out.q = [s.total.error.value, s.total.errorKind.value ?? null];
''',
                state:
                    '{$messages,"CartState.total\$error":"x",'
                    '"CartState.total\$errorKind":"__proto__"}',
              );
              expect(bad['q'], ['x', null]);
            },
          );
        });

        group('default timeout of a call', () {
          // `setTimeout` is squeezed: the delay of a call (30000 by default)
          // is recorded and runs in 5 ms, so a hung call ends now.
          const squeeze = r'''
const realSet = globalThis.setTimeout, delays = [];
globalThis.setTimeout = (f, ms, ...a) => {
  if (ms >= 1000 && ms < 90000) { delays.push(ms); ms = 5; }
  return realSet(f, ms, ...a);
};
''';

          test('a call with no timeout: ends as `timeout` at 30 s', () {
            final out = _run('''$squeeze
answers.push([200, { data: 1 }, 100000]);
s.total.refresh();
await step(60);
out.delays = delays;
out.q = [s.total.loading.value, s.total.errorKind.value?.name, calls[0].signal.aborted];
answers.push([200, { result: 1 }, 100000]);
out.r = await s.add.run('a');
out.c = [s.add.error.value, s.add.errorKind.value?.name, s.add.pending.value];
''', minify: minify);
            expect(out['delays'], [30000, 30000]);
            expect(out['q'], [false, 'timeout', true]);
            expect(out['r'], isNull);
            expect(out['c'], ['timeout', 'timeout', false]);
          });

          test('the page sets it for all (`!t`); a call\'s own wins', () {
            final out = _run(
              '''$squeeze
const sl = thor.use('SlowState');
answers.push([200, { data: 1 }, 100000]);
s.total.refresh();
await step(60);
answers.push([200, { data: 1 }, 100000]);
sl.slow.refresh(); // its own 30 ms, under 1000: not squeezed
await step(80);
out.delays = delays;
out.kind = [s.total.errorKind.value?.name, sl.slow.errorKind.value?.name];
''',
              minify: minify,
              state: '{"!t":2000}',
            );
            expect(out['delays'], [2000]);
            expect(out['kind'], ['timeout', 'timeout']);
          });

          test('Duration.zero (per call or for the page) means none', () {
            final out = _run('''$squeeze
const nl = thor.use('NoLimitState');
answers.push([200, { data: 7 }, 100]);
nl.q.refresh();
await step(150);
out.q = [nl.q.data.value, nl.q.error.value];
answers.push([200, { result: 8 }, 100]);
out.c = await nl.c.run();
out.delays = delays;
''', minify: minify);
            expect(out['q'], [7, null]);
            expect(out['c'], 8);
            expect(out['delays'], isEmpty);

            final all = _run(
              '''$squeeze
answers.push([200, { data: 5 }, 100]);
s.total.refresh();
await step(150);
out.total = [s.total.data.value, s.total.error.value];
out.delays = delays;
''',
              minify: minify,
              state: '{"!t":0}',
            );
            expect(all['total'], [5, null]);
            expect(all['delays'], isEmpty);
          });

          test('each queued command gets its timer when it is SENT', () {
            // The timer is set with `calls.length` fetches already out: the
            // second command's timer starts after the first one is over.
            final out = _run(
              r'''
const realSet = globalThis.setTimeout, at = [];
globalThis.setTimeout = (f, ms, ...a) => {
  if (ms === 2000) { at.push(calls.length); ms = 5000; }
  return realSet(f, ms, ...a);
};
answers.push([200, { result: 1 }, 60]);
answers.push([200, { result: 2 }, 10]);
const a = s.add.run('a'), b = s.add.run('b');
out.r = [await a, await b];
out.at = at;
out.e = [s.add.error.value, calls[1].signal.aborted];
''',
              minify: minify,
              state: '{"!t":2000}',
            );
            expect(out['at'], [0, 1]);
            expect(out['r'], [1, 2]);
            expect(out['e'], [null, false]);
          });

          test('the timer is cleared on an answer: no late timeout', () {
            final out = _run(
              r'''
const realSet = globalThis.setTimeout, realClear = globalThis.clearTimeout;
const set = new Set(), cleared = new Set();
globalThis.setTimeout = (f, ms, ...a) => {
  const h = realSet(f, ms, ...a);
  if (ms === 80) set.add(h);
  return h;
};
globalThis.clearTimeout = (h) => { cleared.add(h); return realClear(h); };
answers.push([200, { result: 1 }, 10]);
out.r = await s.add.run('a');
await step(150);
out.e = [s.add.error.value, s.add.errorKind.value, calls[0].signal.aborted];
out.cleared = [...set].every((h) => cleared.has(h)) && set.size === 1;
''',
              minify: minify,
              state: '{"!t":80}',
            );
            expect(out['r'], 1);
            expect(out['e'], [null, null, false]);
            expect(out['cleared'], isTrue);
          });

          test('the timeout also covers a body that never ends', () {
            final out = _run(
              r'''
answers.push([200, { result: 1 }, 0, Infinity]);
out.r = await s.add.run('a');
out.e = [s.add.error.value, s.add.errorKind.value?.name, s.add.pending.value];
''',
              minify: minify,
              state: '{"!t":40}',
            );
            expect(out['r'], isNull);
            expect(out['e'], ['timeout', 'timeout', false]);
          });

          test(
            'an abort by hand is `aborted`, not `timeout`, under a limit',
            () {
              final out = _run(
                r'''
answers.push([200, { data: 1 }, 100000]);
s.total.refresh();
await step(10);
answers.push([200, { data: 2 }, 5]);
s.total.refresh(); // the newer call aborts the first
await step(30);
out.d = [s.total.data.value, s.total.error.value];
''',
                minify: minify,
                state: '{"!t":2000}',
              );
              expect(out['d'], [2, null]);
            },
          );

          test('a `!t` that is not a number of ms is ignored', () {
            final out = _run(
              '''$squeeze
answers.push([200, { data: 1 }, 100000]);
s.total.refresh();
await step(60);
out.delays = delays;
''',
              minify: minify,
              state: '{"!t":"soon"}',
            );
            expect(out['delays'], [30000]);
          });
        });

        test('a 401 with redirect goes there', () {
          final out = _run(r'''
answers.push([401, { error: 'Sign in again', redirect: '/login' }]);
s.add.run('taza');
await step();
out.last = calls.at(-1);
''', minify: minify);
          expect(out['last'], {'assign': '/login'});
        });
      },
    );
  }
}

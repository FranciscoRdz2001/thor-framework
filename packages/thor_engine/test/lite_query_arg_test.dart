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
class OrdersFilter {
  constructor(q = '', page = 1, tags = []) { this.q = q; this.page = page; this.tags = tags; }
  copyWith(q = null, page = null, tags = null) { return new OrdersFilter(q ?? this.q, page ?? this.page, tags ?? this.tags); }
  toJson() { return new Map([['q', this.q], ['page', this.page], ['tags', this.tags]]); }
  static fromJson(j) { return new OrdersFilter(j.get('q'), j.get('page'), j.get('tags')); }
}
thor.def('OrdersState', ($) => {
  const orders = $Q($, 'OrdersState', 'orders', new OrdersFilter(), (j) => j, 1, 0, (j) => OrdersFilter.fromJson(j), (a) => a.toJson());
  const byRecord = $Q($, 'OrdersState', 'byRecord', Object.freeze({ $1: '', page: 1 }), (j) => j, 1, 0, (j) => Object.freeze({ $1: j.get('$1'), page: j.get('page') }));
  const total = $Q($, 'OrdersState', 'total', null, null);
  const add = $SC($, 'OrdersState', 'add', null, 1);
  const edit = $SC($, 'OrdersState', 'edit', null, 1, null, (a) => a.toJson());
  return { orders, byRecord, total, add, edit, OrdersFilter };
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
      'await step();\nconst s = thor.use("OrdersState");\nconst out = {};\n'
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
        test(
          'the call carries the argument as JSON, nested lists in order',
          () {
            final out = _run(r"""
answers.push([200, { data: ['a'] }]);
s.orders.setArg(new s.OrdersFilter('ñandú', 2, ['b', 'a']));
await step(5);
out.body = calls[0].body;
out.data = s.orders.data.value;
""", minify: minify);
            expect(out['body'], {
              'arg': {
                'q': 'ñandú',
                'page': 2,
                'tags': ['b', 'a'],
              },
            });
            expect(out['data'], ['a']);
          },
        );

        test('setArg with an equal value asks nothing (compared as JSON)', () {
          final out = _run(r"""
answers.push([200, { data: ['a'] }]);
s.orders.setArg(new s.OrdersFilter('', 2, ['x']));
await step(5);
s.orders.setArg(new s.OrdersFilter('', 2, ['x'])); // another object, same value
s.orders.setArg(new s.OrdersFilter('', 2, ['x']));
await step(5);
out.calls = calls.length;
out.loading = s.orders.loading.value;
""", minify: minify);
          expect(out['calls'], 1);
          expect(out['loading'], isFalse);
        });

        test('a different value or list order does ask again', () {
          final out = _run(r"""
answers.push([200, { data: ['1'] }], [200, { data: ['2'] }], [200, { data: ['3'] }]);
s.orders.setArg(new s.OrdersFilter('', 1, ['a', 'b']));
await step(5);
s.orders.setArg(new s.OrdersFilter('', 1, ['b', 'a']));
await step(5);
s.orders.setArg(new s.OrdersFilter('', 1, ['b', 'a', 'c']));
await step(5);
out.calls = calls.length;
""", minify: minify);
          expect(out['calls'], 3);
        });

        test('an equal setArg still retries after a failure', () {
          final out = _run(r"""
answers.push([500, { error: 'boom' }], [200, { data: ['ok'] }]);
s.orders.setArg(new s.OrdersFilter('', 2));
await step(5);
out.error = s.orders.error.value;
s.orders.setArg(new s.OrdersFilter('', 2));
await step(5);
out.calls = calls.length;
out.data = s.orders.data.value;
out.errorAfter = s.orders.error.value;
""", minify: minify);
          expect(out['error'], isNotNull);
          expect(out['calls'], 2);
          expect(out['data'], ['ok']);
          expect(out['errorAfter'], isNull);
        });

        // `setArg(v); refresh();` in one method (the toggle of a
        // failing flag). The refresh aborts the call `setArg` started; the
        // failure of the one that stays lands at once, the first time.
        test('setArg then refresh in one tick: the first failure shows', () {
          final out = _run(r'''
answers.push([503, { error: 'Sin conexión' }, 5], [503, { error: 'Sin conexión' }, 5]);
s.orders.setArg(new s.OrdersFilter('', 2));
s.orders.refresh();
out.pending = s.orders.loading.value;
await step(30);
out.calls = calls.length;
out.aborts = aborts;
out.error = s.orders.error.value;
out.kind = s.orders.errorKind.value?.name;
out.loading = s.orders.loading.value;
out.phase = s.orders.phase();
''', minify: minify);
          expect(out['pending'], isTrue);
          expect(out['calls'], 2);
          expect(out['aborts'], 1);
          expect(out['error'], 'Sin conexión');
          expect(out['kind'], 'server');
          expect(out['loading'], isFalse);
          expect(out['phase'], 3);
        });

        test(
          'setArg then refresh, the first call answers first: still one answer, '
          'the error of the last call',
          () {
            final out = _run(r'''
// The aborted call's answer (fast 200) must not land over the kept call's.
answers.push([200, { data: ['stale'] }, 1], [503, { error: 'Sin conexión' }, 20]);
s.orders.setArg(new s.OrdersFilter('', 2));
s.orders.refresh();
await step(60);
out.data = s.orders.data.value;
out.error = s.orders.error.value;
out.phase = s.orders.phase();
out.loading = s.orders.loading.value;
''', minify: minify);
            expect(out['data'], isNull);
            expect(out['error'], 'Sin conexión');
            expect(out['phase'], 3);
            expect(out['loading'], isFalse);
          },
        );

        test(
          'the same pair over a failed query, and over data: no stale state',
          () {
            final out = _run(r'''
answers.push([503, { error: 'e1' }, 2], [200, { data: ['ok'] }, 2], [200, { data: ['ok2'] }, 2]);
s.orders.setArg(new s.OrdersFilter('', 2));
await step(20);
out.e1 = s.orders.error.value;
// Arg back to the start (a different value) + refresh.
s.orders.setArg(new s.OrdersFilter('', 1));
s.orders.refresh();
await step(30);
out.data = s.orders.data.value;
out.error = s.orders.error.value;
out.kind = s.orders.errorKind.value;
out.phase = s.orders.phase();
out.calls = calls.length;
''', minify: minify);
            expect(out['e1'], 'e1');
            expect(out['data'], ['ok2']);
            expect(out['error'], isNull);
            expect(out['kind'], isNull);
            expect(out['phase'], 2);
            expect(out['calls'], 3);
          },
        );

        test('the arg comes back from the page\'s state as a class', () {
          final out = _run(
            r'''
out.page = s.orders.arg.value.page;
out.isClass = s.orders.arg.value instanceof s.OrdersFilter;
out.tags = s.orders.arg.value.tags;
''',
            minify: minify,
            state: jsonEncode({
              'OrdersState.orders\$arg': {
                'q': 'x',
                'page': 3,
                'tags': ['t'],
              },
            }),
          );
          expect(out['page'], 3);
          expect(out['isClass'], isTrue);
          expect(out['tags'], ['t']);
        });

        test('a record argument is its fields', () {
          final out = _run(r"""
answers.push([200, { data: ['r'] }]);
s.byRecord.setArg(Object.freeze({ $1: 'q', page: 4 }));
await step(5);
out.body = calls[0].body;
s.byRecord.setArg(Object.freeze({ $1: 'q', page: 4 }));
await step(5);
out.calls = calls.length;
""", minify: minify);
          expect(out['body'], {
            'arg': {r'$1': 'q', 'page': 4},
          });
          expect(out['calls'], 1);
        });

        test(
          'a record written with its fields in another order is the same',
          () {
            // `(page: 4, q: 'x') == (q: 'x', page: 4)` in Dart, and the page
            // writes each literal in its own order.
            final out = _run(r"""
answers.push([200, { data: ['r'] }], [200, { data: ['again'] }]);
s.byRecord.setArg(Object.freeze({ $1: 'q', page: 4 }));
await step(5);
s.byRecord.setArg(Object.freeze({ page: 4, $1: 'q' }));
await step(5);
out.calls = calls.length;
out.loading = s.byRecord.loading.value;
""", minify: minify);
            expect(out['calls'], 1);
            expect(out['loading'], isFalse);
          },
        );

        test(
          'the argument key order of a class does not matter to the server',
          () {
            final out = _run(r"""
answers.push([200, { data: ['a'] }]);
s.orders.setArg(new s.OrdersFilter('x', 2, ['t']));
await step(5);
out.body = calls[0].body;
""", minify: minify);
            expect(out['body'], {
              'arg': {
                'q': 'x',
                'page': 2,
                'tags': ['t'],
              },
            });
          },
        );

        group('a command with a class argument', () {
          test('sends it as JSON and tells pendingFor by that JSON', () {
            final out = _run(r"""
answers.push([200, { result: 'ok' }, 20]);
answers.push([200, { result: 'ok' }, 5]);
const p = s.edit.run(new s.OrdersFilter('x', 3, ['t']));
// Another object, same value: the same call is waiting.
out.same = s.edit.pendingFor(new s.OrdersFilter('x', 3, ['t']));
out.other = s.edit.pendingFor(new s.OrdersFilter('y', 3, ['t']));
const r = await p;
await s.edit.run(new s.OrdersFilter('z', 1, []));
out.arg = calls[0].body.arg;
out.second = calls[1].body.arg;
out.r = r;
out.after = s.edit.pendingFor(new s.OrdersFilter('x', 3, ['t']));
""", minify: minify);
            expect(out['arg'], {
              'q': 'x',
              'page': 3,
              'tags': ['t'],
            });
            expect(out['second'], {'q': 'z', 'page': 1, 'tags': <Object?>[]});
            expect(out['same'], isTrue);
            expect(out['other'], isFalse);
            expect(out['r'], 'ok');
            expect(out['after'], isFalse);
          });
        });

        group('a command sends the arguments of the queries as JSON', () {
          test('and the answer for an equal-valued argument lands', () {
            final out = _run(r"""
answers.push([200, { result: 1, queries: { 'OrdersState.orders': ['fresh'] } }, 20]);
s.orders.arg.value = new s.OrdersFilter('', 2, ['a']);
const p = s.add.run('x');
// While the command flies the page rebuilds its argument: another object,
// same value. The answer is for that value: it must land.
s.orders.arg.value = new s.OrdersFilter('', 2, ['a']);
await p;
out.sent = calls[0].body.queries['OrdersState.orders'];
out.data = s.orders.data.value;
""", minify: minify);
            expect(out['sent'], {
              'q': '',
              'page': 2,
              'tags': ['a'],
            });
            expect(out['data'], ['fresh']);
          });

          test('A to B and back to A: the data is the one asked last', () {
            final out = _run(r"""
answers.push([200, { result: 1, queries: { 'OrdersState.orders': ['from-command-A'] } }, 20]);
answers.push([200, { data: ['B'] }, 60]);
answers.push([200, { data: ['A-again'] }, 5]);
s.orders.arg.value = new s.OrdersFilter('', 1, []);
const p = s.add.run('x');
s.orders.setArg(new s.OrdersFilter('', 2, []));   // B
s.orders.setArg(new s.OrdersFilter('', 1, []));   // back to A
await p;
await step(120);
out.data = s.orders.data.value;
out.loading = s.orders.loading.value;
out.page = s.orders.arg.value.page;
""", minify: minify);
            expect(out['page'], 1);
            expect(out['loading'], isFalse);
            expect(out['data'], isNot(['B']));
          });

          test('and one for an argument that moved on is dropped', () {
            final out = _run(r"""
answers.push([200, { result: 1, queries: { 'OrdersState.orders': ['old'] } }, 20]);
answers.push([200, { data: ['new'] }, 40]);
s.orders.arg.value = new s.OrdersFilter('', 1, []);
const p = s.add.run('x');
s.orders.setArg(new s.OrdersFilter('', 2, []));
await p;
out.mid = s.orders.data.value;
await step(60);
out.data = s.orders.data.value;
""", minify: minify);
            expect(out['mid'], isNull);
            expect(out['data'], ['new']);
          });
        });
      },
    );
  }
}

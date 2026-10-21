// Adversarial tests for the server calls of lite: what a hostile or broken answer, a timeout, a crowd of queued runs and an
// argument that isn't a string do to the parts `server_call`, `query` and
// `server_command`. Same fake `fetch` as lite_command_test.dart.
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
thor.def('BoomState', ($) => {
  // Decoders that throw on a shape the server didn't promise.
  const lines = $Q($, 'BoomState', 'lines', null, (j) => j.map((x) => x.get('name')));
  const boom = $SC($, 'BoomState', 'boom', (j) => j.get('x').get('y'), 1);
  const plain = $SC($, 'BoomState', 'plain', null, 0);
  return { lines, boom, plain };
});
thor.def('SlowState', ($) => {
  const slow = $Q($, 'SlowState', 'slow', null, null, 0, 30);
  const slowArg = $Q($, 'SlowState', 'slowArg', 0, null, 1, 30);
  const hang = $SC($, 'SlowState', 'hang', null, 1, 30);
  return { slow, slowArg, hang };
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
globalThis.__unhandled = [];
process.on('unhandledRejection', (e) => __unhandled.push(String(e)));
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
      'await step();\nconst s = thor.use("CartState");\nconst out = {};\n'
      '$script\nawait step(5);\nout.unhandled = __unhandled;\nconsole.log(JSON.stringify(out));\n})();';
  // Through a file, not `-e`: Linux caps one argument at 128 KiB.
  final dir = Directory.systemTemp.createTempSync('thor_cmd_');
  try {
    final file = File('${dir.path}/page.js')..writeAsStringSync(js);
    final r = Process.runSync('node', [file.path]);
    if (r.exitCode != 0) fail('node failed:\n${r.stderr}');
    return jsonDecode((r.stdout as String).trim()) as Map<String, Object?>;
  } finally {
    dir.deleteSync(recursive: true);
  }
}

void main() {
  for (final minify in [false, true]) {
    group(
      minify ? 'minified' : 'as written',
      skip: _hasNode ? false : 'needs node',
      () {
        Map<String, Object?> run(String script, {String? state}) =>
            _run(script, minify: minify, state: state);

        group('a run never rejects and the queue always drains', () {
          test('a decoder that throws on the result: null, queue goes on', () {
            final out = run(r'''
const b = thor.use('BoomState');
answers.push([200, { result: { x: null } }]);
answers.push([200, { result: { x: { y: 7 } } }]);
let threw = 0;
const p1 = b.boom.run('a').catch(() => { threw++; return 'rejected'; });
const p2 = b.boom.run('b').catch(() => { threw++; return 'rejected'; });
out.rs = await Promise.all([p1, p2]);
out.threw = threw;
out.pending = b.boom.pending.value;
out.pendingFor = [b.boom.pendingFor('a'), b.boom.pendingFor('b')];
out.calls = calls.length;
''');
            expect(out['threw'], 0, reason: 'run rejected');
            expect(out['rs'], [null, 7]);
            expect(out['pending'], isFalse);
            expect(out['pendingFor'], [false, false]);
            expect(out['calls'], 2);
            expect(out['unhandled'], isEmpty);
          });

          test('a decoder that throws: the run says why in error', () {
            final out = run(r'''
const b = thor.use('BoomState');
answers.push([200, { result: { x: null } }]);
await b.boom.run('a');
out.error = typeof b.boom.error.value;
out.kind = b.boom.errorKind.value?.name;
''');
            expect(out['error'], 'string');
            expect(out['kind'], 'server');
          });

          test(
            'an answer that is not JSON (a 200 from a proxy) is an error',
            () {
              final out = run(r'''
answers.push([200, '<html>captive portal</html>']);
out.r = await s.add.run('a');
out.error = typeof s.add.error.value;
out.kind = s.add.errorKind.value?.name;
out.result = s.add.result.value;
''');
              expect(out['r'], isNull);
              expect(out['error'], 'string');
              expect(out['kind'], 'server');
              expect(out['result'], isNull);
            },
          );

          test('a query answered with HTML keeps its data and says error', () {
            final out = run(r'''
answers.push([200, { data: [{ name: 'a' }] }]);
s.lines.refresh();
await step(10);
answers.push([200, '<html>captive portal</html>']);
s.lines.refresh();
await step(10);
out.data = s.lines.data.value;
out.error = typeof s.lines.error.value;
out.kind = s.lines.errorKind.value?.name;
out.loading = s.lines.loading.value;
''');
            expect(out['data'], ['a']);
            expect(out['error'], 'string');
            expect(out['kind'], 'server');
            expect(out['loading'], isFalse);
            expect(out['unhandled'], isEmpty);
          });

          test('a query decoder that throws: loading ends, no rejection', () {
            final out = run(r'''
const b = thor.use('BoomState');
answers.push([200, { data: 5 }]);
b.lines.refresh();
await step(10);
out.loading = b.lines.loading.value;
out.data = b.lines.data.value;
out.error = typeof b.lines.error.value;
''');
            expect(out['loading'], isFalse);
            expect(out['data'], isNull);
            expect(out['error'], 'string');
            expect(out['unhandled'], isEmpty);
          });

          test(
            'runs behind one that is redirected to sign in: one navigation, no more calls',
            () {
              // Three answers ready; only the first must be asked for. A second
              // `assign` would abort the first navigation (Chrome cancels the
              // pending one), and each further call is a 401 anyway.
              final out = run(r'''
answers.push([401, { error: 'Sign in again', redirect: '/login' }]);
answers.push([401, { error: 'Sign in again', redirect: '/login' }]);
answers.push([401, { error: 'Sign in again', redirect: '/login' }]);
out.rs = await Promise.all([s.add.run('a'), s.add.run('b'), s.add.run('c')]);
out.pending = s.add.pending.value;
out.kind = s.add.errorKind.value?.name;
out.fetches = calls.filter((c) => c.url).length;
out.assigns = calls.filter((c) => c.assign).length;
out.left = answers.length;
''');
              expect(out['rs'], [null, null, null]);
              expect(out['pending'], isFalse);
              expect(out['fetches'], 1);
              expect(out['assigns'], 1);
              expect(out['left'], 2);
              expect(out['kind'], 'aborted');
            },
          );

          test('two calls in flight that both answer 401: one navigation', () {
            // A query next to the command, both sent before either answers:
            // the second 401 must not start a second `assign`.
            final out = run(r'''
answers.push([401, { error: 'Sign in again', redirect: '/login' }]);
answers.push([401, { error: 'Sign in again', redirect: '/login' }]);
await Promise.all([
  thor.call('x-thor-command', 'CartState.add', { arg: 'a' }, 0),
  thor.call('x-thor-query', 'CartState.lines', {}, 0),
]);
out.fetches = calls.filter((c) => c.url).length;
out.assigns = calls.filter((c) => c.assign).length;
''');
            expect(out['fetches'], 2);
            expect(out['assigns'], 1);
          });

          test('a redirect that is not a web address never runs as script', () {
            final out = run(r'''
const rows = [];
for (const red of ['javascript:alert(1)', 'JaVaScRiPt:alert(1)', 'data:text/html,<b>x</b>', 'vbscript:x', {}, [1], 5, true]) {
  answers.push([401, { error: 'Sign in again', redirect: red }]);
  await s.add.run('a');
  rows.push(calls.at(-1).assign ?? null);
}
out.rows = rows;
answers.push([401, { error: 'Sign in again', redirect: '/login?next=%2Fcart' }]);
await s.add.run('a');
out.ok = calls.at(-1).assign;
''');
            expect(out['rows'], everyElement(isNull));
            expect(out['ok'], '/login?next=%2Fcart');
          });

          test('a redirect to another origin goes there', () {
            final out = run(r'''
answers.push([401, { error: 'Sign in again', redirect: 'https://sso.example.com/start' }]);
await s.add.run('a');
out.sso = calls.at(-1).assign;
''');
            expect(out['sso'], 'https://sso.example.com/start');
          });

          test('the page goes away: every queued run ends null, quietly', () {
            final out = run(r'''
// The browser drops each fetch when the page unloads.
for (let i = 0; i < 4; i++) answers.push([0, null, 1]);
const ps = [];
for (let i = 0; i < 4; i++) ps.push(s.add.run(`r${i}`));
out.rs = await Promise.all(ps);
out.pending = s.add.pending.value;
out.error = typeof s.add.error.value;
out.kind = s.add.errorKind.value?.name;
''');
            expect(out['rs'], [null, null, null, null]);
            expect(out['pending'], isFalse);
            expect(out['kind'], 'network');
            expect(out['unhandled'], isEmpty);
          });

          test('1000 queued runs: in order, one at a time, none left over', () {
            final out = run(r'''
const N = 1000;
for (let i = 0; i < N; i++) answers.push([200, { result: i }]);
const t0 = Date.now();
const ps = [];
for (let i = 0; i < N; i++) ps.push(s.add.run(i));
out.mid = s.add.pendingFor(N - 1) && !s.add.pendingFor(N + 5);
const rs = await Promise.all(ps);
out.ok = rs.every((r, i) => r === i);
out.order = calls.every((c, i) => c.body.arg === i);
out.max = maxInflight;
out.pending = s.add.pending.value;
out.left = s.add.pendingFor(0) || s.add.pendingFor(N - 1);
out.ms = Date.now() - t0;
''');
            expect(out['mid'], isTrue);
            expect(out['ok'], isTrue);
            expect(out['order'], isTrue);
            expect(out['max'], 1);
            expect(out['pending'], isFalse);
            expect(out['left'], isFalse);
            expect(out['ms'], lessThan(5000));
          });

          test('pendingFor: value for scalars, identity for objects', () {
            final out = run(r'''
const o = { id: 1 };
answers.push([200, { result: 1 }, 5]);
answers.push([200, { result: 1 }]);
answers.push([200, { result: 1 }]);
answers.push([200, { result: 1 }]);
const ps = [s.add.run(NaN), s.add.run(-0), s.add.run(o), s.add.run(null)];
out.nan = s.add.pendingFor(NaN);
out.zero = s.add.pendingFor(0);
out.same = s.add.pendingFor(o);
out.equal = s.add.pendingFor({ id: 1 });
out.nul = s.add.pendingFor(null);
out.undef = s.add.pendingFor(undefined);
await Promise.all(ps);
out.after = [s.add.pendingFor(NaN), s.add.pendingFor(o), s.add.pendingFor(null)];
''');
            expect(out['nan'], isTrue);
            expect(out['zero'], isTrue);
            expect(out['same'], isTrue);
            expect(out['equal'], isFalse);
            expect(out['nul'], isTrue);
            expect(out['undef'], isFalse);
            expect(out['after'], [false, false, false]);
          });

          test('the same argument twice: pendingFor holds until both end', () {
            final out = run(r'''
answers.push([200, { result: 1 }, 10]);
answers.push([200, { result: 1 }, 10]);
const p1 = s.add.run('x'), p2 = s.add.run('x');
await p1;
out.mid = s.add.pendingFor('x');
await p2;
out.end = s.add.pendingFor('x');
''');
            expect(out['mid'], isTrue);
            expect(out['end'], isFalse);
          });

          test('a run made from an effect of a query does not deadlock', () {
            final out = run(r'''
answers.push([200, { data: [{ name: 'a' }] }, 5]);
answers.push([200, { result: 9 }]);
let fired = 0;
thor.effect(() => {
  const d = s.lines.data.value;
  if (d && !fired++) s.add.run('from-effect');
});
s.lines.refresh();
await step(40);
out.fired = fired;
out.result = s.add.result.value;
out.pending = s.add.pending.value;
out.arg = calls.at(-1).body.arg;
''');
            expect(out['fired'], 1);
            expect(out['result'], 9);
            expect(out['pending'], isFalse);
            expect(out['arg'], 'from-effect');
          });

          test(
            'awaiting a run in a method that runs another (re-entrancy)',
            () {
              final out = run(r'''
answers.push([200, { result: 1 }, 5]);
answers.push([200, { result: 2 }, 5]);
answers.push([200, { result: 3 }]);
async function removeAB() {
  const first = await s.add.run('a');
  if (first != null) await s.add.run('b');
  return 'done';
}
const other = s.add.run('z'); // somebody else queued in between
out.end = await Promise.race([removeAB(), step(500).then(() => 'deadlock')]);
await other;
out.order = calls.map((c) => c.body.arg);
''');
              expect(out['end'], 'done');
              expect(out['order'], ['z', 'a', 'b']);
            },
          );

          test(
            'a void command (no decoder) resolves null and pending ends',
            () {
              final out = run(r'''
const b = thor.use('BoomState');
answers.push([200, { result: null }]);
out.r = await b.plain.run();
out.pending = b.plain.pending.value;
out.pendingFor = b.plain.pendingFor(undefined);
answers.push([200, { queries: {} }]);
out.r2 = await b.plain.run();
''');
              expect(out['r'], isNull);
              expect(out['pending'], isFalse);
              expect(out['pendingFor'], isFalse);
              expect(out['r2'], isNull);
            },
          );

          test('two hanging commands time out one after the other', () {
            final out = run(r'''
const sl = thor.use('SlowState');
answers.push([200, { result: 1 }, 5000]);
answers.push([200, { result: 2 }, 5000]);
answers.push([200, { result: 3 }, 1]);
out.rs = await Promise.all([sl.hang.run('a'), sl.hang.run('b'), sl.hang.run('c')]);
out.max = maxInflight;
out.aborted = calls.map((c) => c.signal.aborted);
out.pending = sl.hang.pending.value;
out.error = sl.hang.error.value;
''');
            expect(out['rs'], [null, null, 3]);
            expect(out['max'], 1);
            expect(out['aborted'], [true, true, false]);
            expect(out['pending'], isFalse);
            expect(out['error'], isNull);
          });
        });

        group('what the page names (browser side)', () {
          test(
            'a keyed state with ~ % ; in its key calls by its escaped id',
            () {
              final out = run(r'''
answers.push([200, { result: 1 }]);
const k = thor.use('CartState#a%7Eb%25c%3Bd');
out.key = k.$key;
out.r = await k.add.run('x');
out.ids = calls.map((c) => Object.values(c.headers).filter((v) => v.includes('.')).join());
out.names = Object.keys(calls[0].body.queries).filter((n) => n.includes('#')).sort();
''');
              expect(out['r'], 1);
              expect(out['ids'], ['CartState#a%7Eb%25c%3Bd.add']);
              expect(out['names'], [
                'CartState#a%7Eb%25c%3Bd.lines',
                'CartState#a%7Eb%25c%3Bd.total',
              ]);
            },
          );

          test(
            '10k ids in !q: no throw, only the real queries named, fast',
            () {
              final ids = [
                for (var i = 0; i < 10000; i++) 'Nope$i.q',
                for (var i = 0; i < 2000; i++) 'CartState#k$i.lines',
                '__proto__.x',
                'constructor.y',
                'HeaderState.count',
              ];
              final out = run(r'''
answers.push([200, { result: 1 }]);
const t0 = Date.now();
out.r = await s.add.run('a');
out.ms = Date.now() - t0;
const names = Object.keys(calls[0].body.queries);
out.named = names.filter((k) => !k.startsWith('CartState#k')).sort();
out.keyed = names.filter((k) => k.startsWith('CartState#k')).length;
''', state: jsonEncode({'!q': ids}));
              expect(out['r'], 1);
              expect(out['named'], [
                'CartState.lines',
                'CartState.total',
                'HeaderState.count',
                'HeaderState.items',
              ]);
              // A keyed id is a state of its own (its class has the query),
              // named once each.
              expect(out['keyed'], 4000);
              expect(out['ms'], lessThan(5000));
            },
          );

          test('waking the states of !q fetches nothing and runs once', () {
            final out = run(r'''
answers.push([200, { result: 1 }]);
answers.push([200, { result: 2 }]);
await s.add.run('a');
await s.add.run('b');
out.fetches = calls.length;
out.same = JSON.stringify(calls[0].body.queries) === JSON.stringify(calls[1].body.queries);
const h = thor.use('HeaderState');
out.loading = [h.count.loading.value, h.items.loading.value];
''', state: '{"!q":["HeaderState.count","HeaderState.items"]}');
            expect(out['fetches'], 2);
            expect(out['loading'], [false, false]);
            expect(out['same'], isTrue);
          });

          test('a tampered !q id with markup is just a name nobody has', () {
            final out = run(
              r'''
answers.push([200, { result: 1 }]);
out.r = await s.add.run('a');
out.queries = Object.keys(calls[0].body.queries).sort();
''',
              state: jsonEncode({
                '!q': [
                  '</script><img src=x onerror=alert(1)>.q',
                  'CartState.lines"};alert(1);//',
                  ' .q',
                ],
              }),
            );
            expect(out['r'], 1);
            expect(out['queries'], ['CartState.lines', 'CartState.total']);
          });
        });

        group('a stale answer never lands (adversarial)', () {
          test('an object argument is compared by its value (an equal copy is '
              'the same argument), not by reference', () {
            final out = run(r'''
answers.push([200, { result: 1, queries: { 'CartState.lines': [{ name: 'p1' }] } }, 15]);
const o = { p: 1 };
s.lines.arg.value = o;
await s.add.run('a');       // arg never touched again
out.same = s.lines.data.value;
answers.push([200, { result: 1, queries: { 'CartState.lines': [{ name: 'copy' }] } }, 10]);
const p = s.add.run('b');
s.lines.setArg({ p: 1 });   // an equal object, a different reference: nothing to ask
await p;
out.equalCopy = s.lines.data.value;   // the command's answer is for that value: it lands
out.callsAfterEqual = calls.length;   // the two runs only
answers.push([200, { result: 1, queries: { 'CartState.lines': [{ name: 'stale' }] } }, 10]);
answers.push([200, { data: [{ name: 'fresh' }] }, 40]);
const q = s.add.run('c');
s.lines.setArg({ p: 2 });   // another value: the answer of the command is stale
await q;
out.mid = s.lines.data.value;
await step(50);
out.after = s.lines.data.value; // the setArg's own call brings the data
out.loading = s.lines.loading.value;
''');
            expect(out['same'], ['p1']);
            expect(out['equalCopy'], ['copy']);
            expect(out['callsAfterEqual'], 2);
            expect(out['mid'], ['copy']);
            expect(out['after'], ['fresh']);
            expect(out['loading'], isFalse);
          });

          test('a stale error never sets errorKind either', () {
            final out = run(r'''
answers.push([200, { result: 1, errors: { 'CartState.lines': 'No puedes' }, kinds: { 'CartState.lines': 'forbidden' } }, 10]);
answers.push([200, { data: [{ name: 'p2' }] }, 40]);
s.lines.arg.value = 1;
const p = s.add.run('a');
s.lines.setArg(2);
await p;
out.mid = [s.lines.error.value, s.lines.errorKind.value ?? null];
await step(60);
out.end = [s.lines.error.value, s.lines.errorKind.value ?? null, s.lines.data.value];
''');
            expect(out['mid'], [null, null]);
            expect(out['end'], [
              null,
              null,
              ['p2'],
            ]);
          });

          test('A to B to A with three calls in flight: the newest wins', () {
            final out = run(r'''
answers.push([200, { data: [{ name: 'A-old' }] }, 40]);
answers.push([200, { data: [{ name: 'B' }] }, 20]);
answers.push([200, { data: [{ name: 'A-new' }] }, 60]);
s.lines.setArg('A');
s.lines.setArg('B');
s.lines.setArg('A');
await step(120);
out.data = s.lines.data.value;
out.aborted = calls.map((c) => c.signal.aborted);
out.loading = s.lines.loading.value;
''');
            expect(out['data'], ['A-new']);
            expect(out['aborted'], [true, true, false]);
            expect(out['loading'], isFalse);
          });

          test('a command answer beats a query call issued after it left', () {
            final out = run(r'''
answers.push([200, { result: 1, queries: { 'CartState.lines': [{ name: 'cmd' }] } }, 20]);
answers.push([200, { data: [{ name: 'own' }] }, 60]);
const p = s.add.run('a');
s.lines.refresh();  // same arg: a call issued after the command left
await p;
await step(100);
out.data = s.lines.data.value;
out.loading = s.lines.loading.value;
out.aborted = calls.map((c) => c.signal.aborted);
''');
            // The command's answer is newer than any call on its way: it
            // wins and the slow refresh is aborted (query.js `put`).
            expect(out['data'], ['cmd']);
            expect(out['loading'], isFalse);
            expect(out['aborted'], [false, true]);
          });
        });

        group('timeout, abort and offline (adversarial)', () {
          test('offline then online: the next call clears error and kind', () {
            final out = run(r'''
answers.push([0, null]);
s.lines.refresh();
await step(10);
out.off = [typeof s.lines.error.value, s.lines.errorKind.value?.name];
answers.push([200, { data: [{ name: 'back' }] }]);
s.lines.refresh();
await step(10);
out.on = [s.lines.error.value, s.lines.errorKind.value ?? null, s.lines.data.value, s.lines.loading.value];
''');
            expect(out['off'], ['string', 'network']);
            expect(out['on'], [
              null,
              null,
              ['back'],
              false,
            ]);
          });

          test('an abort while the body is read ends the call as aborted', () {
            final out = run(r'''
answers.push([200, { data: [{ name: 'a' }] }, 2, 50]);
const c = new AbortController();
const r = thor.call('x-thor-query', 'CartState.lines', {}, 0, c);
await step(15);
c.abort();
const x = await r;
out.x = [x.ok ?? null, x.k];
''');
            expect(out['x'], [null, 'aborted']);
          });

          test(
            'a timeout that would fire after the answer changes nothing',
            () {
              final out = run(r'''
const sl = thor.use('SlowState');
answers.push([200, { result: 1 }, 10]);
out.r = await sl.hang.run('a');
await step(80);
out.error = sl.hang.error.value;
out.result = sl.hang.result.value;
out.aborted = calls[0].signal.aborted;
''');
              expect(out['r'], 1);
              expect(out['error'], isNull);
              expect(out['result'], 1);
              expect(out['aborted'], isFalse);
            },
          );
        });

        group('messages and kinds (adversarial)', () {
          test('markup in a message stays text in the signal', () {
            final out = run(r'''
answers.push([0, null]);
await s.add.run('a');
out.a = s.add.error.value;
answers.push([422, { error: '<img src=x onerror=alert(1)>' }]);
await s.add.run('a');
out.b = [s.add.error.value, s.add.errorKind.value.name];
''', state: '{"!m":{"network":"<b>offline</b>","generic":"</script>"}}');
            expect(out['a'], '<b>offline</b>');
            expect(out['b'], ['<img src=x onerror=alert(1)>', 'validation']);
          });

          test('empty messages are kept as they come', () {
            final out = run(r'''
answers.push([0, null]);
await s.add.run('a');
out.a = s.add.error.value;
answers.push([500, { error: '' }]);
await s.add.run('a');
out.b = s.add.error.value;
''', state: '{"!m":{"network":""}}');
            expect(out['a'], '');
            expect(out['b'], '');
          });

          test('proxy statuses with HTML bodies keep their kind', () {
            final out = run(r'''
const rows = [];
for (const st of [400, 401, 403, 404, 422, 429, 500, 502, 503, 504]) {
  answers.push([st, '<html><h1>' + st + '</h1></html>']);
  await s.add.run('a');
  rows.push([st, typeof s.add.error.value, s.add.errorKind.value.name]);
}
out.rows = rows;
''');
            expect(out['rows'], [
              [400, 'string', 'validation'],
              [401, 'string', 'unauthorized'],
              [403, 'string', 'forbidden'],
              [404, 'string', 'client'],
              [422, 'string', 'validation'],
              [429, 'string', 'client'],
              [500, 'string', 'server'],
              [502, 'string', 'server'],
              [503, 'string', 'server'],
              [504, 'string', 'server'],
            ]);
          });

          test('an error body that is an array, a number or null', () {
            final out = run(r'''
const rows = [];
for (const b of [[1, 2], 5, null, 'text', { error: 5 }, { error: null }]) {
  answers.push([500, b]);
  await s.add.run('a');
  rows.push(s.add.error.value);
}
out.rows = rows;
''');
            expect(out['rows'], everyElement(isA<String>()));
            expect(out['unhandled'], isEmpty);
          });

          test(
            'kinds in an answer that is not a map, or with hostile keys',
            () {
              final out = run(r'''
answers.push([200, { result: 1, queries: [1], errors: 'x', kinds: 7 }]);
out.a = await s.add.run('a');
answers.push([200, { result: 1, errors: { '__proto__': 'x', 'constructor': 'y', 'CartState.lines': 'z' }, kinds: { 'CartState.lines': 'toString' } }]);
out.b = await s.add.run('a');
out.err = [s.lines.error.value, s.lines.errorKind.value ?? null];
''');
              expect(out['a'], 1);
              expect(out['b'], 1);
              expect(out['err'], ['z', null]);
              expect(out['unhandled'], isEmpty);
            },
          );
        });
      },
    );
  }
}

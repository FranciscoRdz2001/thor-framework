@TestOn('vm')
library;

// Adversarial tests for maps (every Dart Map is a JS Map): the lite runtime
// and its server parts under node, with a fake DOM and a fake `fetch`.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/src/lite_bundle.dart';

final _hasNode = Process.runSync('node', ['--version']).exitCode == 0;

String _bundle({
  required bool minify,
  required String stateJs,
  bool dev = false,
}) {
  String read(String f) => File('lib/lite/$f').readAsStringSync();
  return liteBundle(
    runtime: read('runtime.js'),
    parts: {
      'json': read('parts/json.js'),
      'server_call': read('parts/server_call.js'),
      'query': read('parts/query.js'),
      'server_command': read('parts/server_command.js'),
      if (dev) 'dev_state': read('parts/dev_state.js'),
    },
    stateJs: stateJs,
    minify: minify,
  );
}

const _page = r'''
globalThis.window = globalThis;
const root = { addEventListener() {}, querySelectorAll: () => [] };
const docListeners = {};
let stateText = null;
const store = new Map();
globalThis.sessionStorage = {
  getItem: (k) => (store.has(k) ? store.get(k) : null),
  setItem: (k, v) => store.set(k, v),
  removeItem: (k) => store.delete(k),
};
globalThis.document = {
  documentElement: root, cookie: '',
  getElementById: (id) => (id === 'thor-state' && stateText != null ? { textContent: stateText } : null),
  querySelectorAll: () => [],
  addEventListener: (t, f) => { docListeners[t] = f; },
  dispatchEvent(e) { docListeners[e?.type]?.(e); }, createElement: () => ({}),
};
globalThis.CustomEvent = class { constructor(t) { this.type = t; } };
globalThis.location = { pathname: '/cart', search: '', href: 'http://localhost/cart', assign(u) { calls.push({ assign: u }); } };
globalThis.reportError = (e) => reported.push(String(e && e.message || e));
const calls = [], answers = [], reported = [];
globalThis.fetch = (url, init) => {
  calls.push({ url, headers: init.headers, body: JSON.parse(init.body), raw: init.body });
  const [status, body, wait = 0] = answers.shift();
  const text = typeof body === 'string' ? body : JSON.stringify(body);
  const r = { ok: status < 300, status, text: async () => text, json: async () => JSON.parse(text) };
  return new Promise((done) => setTimeout(() => done(r), wait));
};
const step = (ms = 0) => new Promise((r) => setTimeout(r, ms));
const proto = () => Object.getOwnPropertyNames(Object.prototype).sort().join();
const P0 = proto();
''';

const _states = r'''
const $Q = thor.query, $SC = thor.command;
const keys = (j) => (j instanceof Map ? [...j.keys()].join(',') : 'NOT A MAP');
thor.def('S', ($) => {
  const m = $.state('m', new Map([['z', 0]]));
  const n = $.state('n', 7);
  const l = $.state('l', []);
  const data = $Q($, 'S', 'data', null, (j) => j, 1);
  const rows = $Q($, 'S', 'rows', null, (j) => (j == null ? j : [...j].map((r) => keys(r))), 0);
  const go = $SC($, 'S', 'go', null, 1);
  const noarg = $SC($, 'S', 'noarg', null, 0);
  return { m, n, l, data, rows, go, noarg, $s: { m, n, l } };
});
''';

Map<String, Object?> _run(
  String script, {
  required bool minify,
  String? state,
  bool dev = false,
  String pre = '',
  String stateJs = _states,
}) {
  final js =
      '$_page${state == null ? '' : 'stateText = ${jsonEncode(state)};\n'}$pre'
      '${_bundle(minify: minify, stateJs: stateJs, dev: dev)}\n(async () => {\n'
      'await step();\nconst s = thor.use("S");\nconst out = {};\n'
      '$script\nconsole.log(JSON.stringify(out));\n})();';
  final dir = Directory.systemTemp.createTempSync('thor_maps');
  final file = File('${dir.path}/t.js')..writeAsStringSync(js);
  final r = Process.runSync('node', [file.path]);
  dir.deleteSync(recursive: true);
  if (r.exitCode != 0) fail('node failed:\n${r.stderr}');
  return jsonDecode((r.stdout as String).trim().split('\n').last)
      as Map<String, Object?>;
}

void main() {
  for (final minify in [false, true]) {
    group(minify ? 'minified' : 'as written', skip: _hasNode ? false : 'needs node', () {
      Map<String, Object?> run(
        String script, {
        String? state,
        bool dev = false,
        String pre = '',
        String? stateJs,
      }) => _run(
        script,
        minify: minify,
        state: state,
        dev: dev,
        pre: pre,
        stateJs: stateJs ?? _states,
      );

      test('#thor-state: proto keys, order and no pollution', () {
        final out = run(
          r'''
const m = s.m.value;
out.isMap = m instanceof Map;
out.keys = keys(m);
out.proto = m.get('__proto__') instanceof Map ? [...m.get('__proto__').keys()].join(',') : String(m.get('__proto__'));
out.polluted = proto() === P0 && ({}).polluted === undefined && ({}).x === undefined;
out.l = JSON.stringify(s.l.value.map((x) => x instanceof Map ? keys(x) : x));
out.n = s.n.value;
''',
          state:
              '{"S.m":{"10":1,"9":2,"__proto__":{"polluted":1},"constructor":{"prototype":{"x":1}},"b":3},'
              '"S.l":[{"__proto__":1,"2":0,"1":0}],"S.n":5,"__proto__":{"polluted":2}}',
        );
        expect(out['isMap'], isTrue);
        expect(out['keys'], '10,9,__proto__,constructor,b');
        expect(out['proto'], 'polluted');
        expect(out['polluted'], isTrue);
        expect(out['l'], '["__proto__,2,1"]');
        expect(out['n'], 5);
      });

      for (final (name, text) in [
        ('a top-level array', '[1,2,{"S.n":9}]'),
        ('a top-level string', '"S.n"'),
        ('null', 'null'),
        ('a number', '5'),
        ('a broken payload', '{"S.n":'),
        ('an empty payload', ''),
        ('a payload with a trailing comma', '{"S.n":1,}'),
      ]) {
        test('#thor-state that is $name: the page starts from the code', () {
          final out = run(r'''
out.n = s.n.value;
out.keys = keys(s.m.value);
s.n.value = 8;
out.after = s.n.value;
''', state: text);
          expect(out['n'], 7);
          expect(out['keys'], 'z');
          expect(out['after'], 8);
        });
      }

      // The tokenizer was `"(?:[^"\\]|\\.)*"`: one backtrack frame per character,
      // so a string of a few MB overflowed the regex stack (RangeError) and the
      // whole payload was dropped as «not valid JSON».
      test('#thor-state with a string of 10 MB is read whole', () {
        final big = 'x' * 10000000;
        final out = run(r'''
out.n = s.n.value;
out.keys = keys(s.m.value);
''', state: '{"S.n":3,"S.m":{"k":"$big","j":1},"S.big":"$big"}');
        expect(out['n'], 3);
        expect(out['keys'], 'k,j');
      });

      test('thor.parse / thor.str: 30000 random documents, exact order', () {
        final out = run(r'''
let seed = 12345;
const rnd = () => ((seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0) / 4294967296);
const pick = (a) => a[Math.floor(rnd() * a.length)];
const KEYS = ['__proto__', 'constructor', 'toString', 'hasOwnProperty', '0', '1', '9', '10', '-1', '01', '4294967295', '4294967294', '', ' ', 'a', 'b', 'é', '😀', ' ', '"', '\\', '\n', '\u0000', 'k\ud800'.slice(0, 1) + 'x'];
const SCALARS = [0, -0, 1, -1, 1.5, 1e21, 1e-7, 123456789012345680000, 9007199254740992, true, false, null, '', 'x', '"', '\\', '\n\t', ' ', '😀', '</script>', '\u0001', 'é'];
const gen = (d) => {
  const r = rnd();
  if (d > 4 || r < 0.35) return pick(SCALARS);
  if (r < 0.6) return Array.from({ length: Math.floor(rnd() * 4) }, () => gen(d + 1));
  const n = Math.floor(rnd() * 6), seen = new Set(), es = [];
  for (let i = 0; i < n; i++) { const k = pick(KEYS); if (seen.has(k)) continue; seen.add(k); es.push([k, gen(d + 1)]); }
  return { $o: es };
};
const text = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)
  ? `{${v.$o.map(([k, x]) => `${JSON.stringify(k)}:${text(x)}`).join(',')}}`
  : Array.isArray(v) ? `[${v.map(text).join(',')}]` : JSON.stringify(v);
const same = (m, v) => {
  if (v !== null && typeof v === 'object' && !Array.isArray(v)) {
    if (!(m instanceof Map) || m.size !== v.$o.length) return false;
    let i = 0;
    for (const [k, x] of m) { const [k2, y] = v.$o[i++]; if (k !== k2 || !same(x, y)) return false; }
    return true;
  }
  if (Array.isArray(v)) return Array.isArray(m) && m.length === v.length && v.every((y, i) => same(m[i], y));
  return Object.is(m, v) || (typeof v === 'number' && v === 0 && m === 0);
};
let bad = 0, first = '', roundBad = 0, firstRound = '', polluted = 0;
for (let i = 0; i < 30000; i++) {
  const v = gen(0), t = text(v);
  let m;
  try { m = thor.parse(t); } catch (e) { bad++; first ||= 'THROW ' + t + ' ' + e; continue; }
  if (!same(m, v)) { bad++; first ||= t; }
  const back = thor.str(m);
  // -0 prints as 0 (JSON.stringify): compare through parse again.
  if (!same(thor.parse(back), v)) { roundBad++; firstRound ||= t + ' -> ' + back; }
  if (proto() !== P0) polluted++;
}
out.bad = bad; out.first = first; out.roundBad = roundBad; out.firstRound = firstRound; out.polluted = polluted;
''');
        expect(out['first'], '');
        expect(out['bad'], 0);
        expect(out['firstRound'], '');
        expect(out['roundBad'], 0);
        expect(out['polluted'], 0);
      });

      test('#thor-state with duplicate keys keeps the last value', () {
        final out = run(
          r'out.n = s.n.value; out.m = keys(s.m.value);',
          state: '{"S.n":1,"S.n":2,"S.m":{"a":1,"b":2,"a":3}}',
        );
        expect(out['n'], 2);
        expect(out['m'], 'a,b');
      });

      test('#thor-state: a deep payload (20k levels) does not overflow', () {
        final deep = '${'[' * 20000}1${']' * 20000}';
        final out = run(
          r'out.n = s.n.value; out.ok = 1;',
          state: '{"S.n":3,"S.l":$deep}',
        );
        expect(out['n'], 3);
        expect(out['ok'], 1);
      });

      test('#thor-state: 5 MB of state parses in the page', () {
        final items = [
          for (var i = 0; i < 40000; i++)
            {
              'id': i,
              'name': 'item $i',
              'tags': ['a', 'b'],
              'p': i * 1.5,
              'x': null,
            },
        ];
        final text = jsonEncode({'S.l': items, 'S.n': 4});
        expect(text.length, greaterThan(2 * 1024 * 1024));
        final out = run(
          r'out.n = s.n.value; out.len = s.l.value.length; out.first = keys(s.l.value[0]);',
          state: text,
        );
        expect(out['n'], 4);
        expect(out['len'], 40000);
        expect(out['first'], 'id,name,tags,p,x');
      });

      test('a command argument that is a Map reaches the server', () {
        final out = run(r'''
answers.push([200, { result: 1 }]);
s.go.run(new Map([['id', 5], ['tags', ['a']], ['nested', new Map([['k', 'v']])]]));
out.arg = JSON.stringify(calls[0].body.arg);
await step();
''');
        expect(out['arg'], '{"id":5,"tags":["a"],"nested":{"k":"v"}}');
      });

      test('a query argument that is a Map reaches the server', () {
        final out = run(r'''
answers.push([200, { data: 1 }]);
s.data.setArg(new Map([['page', 2], ['q', 'x']]));
out.arg = JSON.stringify(calls[0].body.arg);
await step();
''');
        expect(out['arg'], '{"page":2,"q":"x"}');
      });

      test('a command carries the Map argument of the page queries', () {
        final out = run(r'''
answers.push([200, { data: 1 }]);
s.data.setArg(new Map([['page', 2]]));
await step();
answers.push([200, { result: 1 }]);
s.noarg.run();
out.queries = JSON.stringify(calls[1].body.queries);
await step();
''');
        // Every query of the page (null: takes no argument) is named.
        expect(out['queries'], '{"S.data":{"page":2},"S.rows":null}');
      });

      test(
        'query answer: object with integer-like keys keeps the text order',
        () {
          final out = run(r'''
answers.push([200, '{"data":[{"10":1,"9":2,"a":3}],"x":1}']);
s.rows.refresh();
await step();
out.rows = JSON.stringify(s.rows.data.value);
out.err = s.rows.error.value;
''');
          expect(out['rows'], '["10,9,a"]');
          expect(out['err'], isNull);
        },
      );

      test('query answer: a data that is a Map arrives as a Map', () {
        final out = run(r'''
answers.push([200, '{"data":{"10":1,"9":{"__proto__":2,"8":3}}}']);
s.data.refresh();
await step();
const d = s.data.data.value;
out.keys = keys(d);
out.inner = keys(d.get('9'));
out.polluted = proto() === P0;
''');
        expect(out['keys'], '10,9');
        expect(out['inner'], '__proto__,8');
        expect(out['polluted'], isTrue);
      });

      for (final (name, body) in [
        ('html', '<html>502</html>'),
        ('an array', '[1,2]'),
        ('null', 'null'),
        ('a string', '"x"'),
        ('empty', ''),
      ]) {
        test(
          'query answer that is $name (status 502): the page\'s generic text, no throw',
          () {
            final out = run('''
answers.push([502, ${jsonEncode(body)}]);
s.data.refresh();
await step();
out.err = s.data.error.value;
out.loading = s.data.loading.value;
''');
            // No `!m` in this page: the kind's name, never invented prose.
            expect(out['err'], 'generic');
            expect(out['loading'], isFalse);
          },
        );
      }

      test(
        'query answer 200 without data sets undefined data to undefined-safe',
        () {
          final out = run(r'''
answers.push([200, '{}']);
s.data.refresh();
await step();
out.data = s.data.data.value === undefined ? 'undefined' : JSON.stringify(s.data.data.value);
out.loading = s.data.loading.value;
''');
          // The old code gave `undefined` too (j.data); the state must not stay loading.
          expect(out['loading'], isFalse);
        },
      );

      test(
        'PRE-EXISTING: command answer: queries/errors keyed by hostile names',
        () {
          final out = run(r'''
answers.push([200, '{"result":1,"queries":{"__proto__":5,"constructor":6,"S.data":{"10":1,"9":2}},"errors":{"toString":"e"}}']);
s.noarg.run();
await step();
out.pending = s.noarg.pending.value;
out.err = s.noarg.error.value;
out.data = keys(s.data.data.value);
out.polluted = proto() === P0;
''');
          expect(out['pending'], isFalse);
          expect(out['err'], isNull);
          expect(out['data'], '10,9');
          expect(out['polluted'], isTrue);
        },
      );

      test('command answer: queries that is not an object is ignored', () {
        final out = run(r'''
answers.push([200, '{"result":2,"queries":[1,2],"errors":"x"}']);
s.noarg.run();
await step();
out.pending = s.noarg.pending.value;
out.result = s.noarg.result.value;
''');
        expect(out['pending'], isFalse);
        expect(out['result'], 2);
      });

      test('command answer: result that is an object stays a Map', () {
        final out = run(r'''
answers.push([200, '{"result":{"10":1,"9":2}}']);
s.noarg.run();
await step();
out.result = keys(s.noarg.result.value);
''');
        expect(out['result'], '10,9');
      });

      test('401 with redirect still redirects', () {
        final out = run(r'''
answers.push([401, '{"redirect":"/login"}']);
s.noarg.run();
await step();
out.assign = calls.filter((c) => c.assign).map((c) => c.assign).join();
''');
        expect(out['assign'], '/login');
      });

      test('dev_state: a Map field survives the reload, order and nested', () {
        final out = run(r'''
s.m.value = new Map([['10', 1], ['9', new Map([['b', 1], ['1', 2]])], ['__proto__', 3]]);
s.l.value = [new Map([['2', 'x'], ['1', 'y']]), 5];
s.n.value = 42;
const snap = window.__thorDevState();
out.snap = snap;
sessionStorage.setItem('thor:state:/cart', snap);
s.m.value = new Map(); s.l.value = []; s.n.value = 0;
document.dispatchEvent(new CustomEvent('thor:hydrated'));
await step();
out.m = keys(s.m.value);
out.m9 = keys(s.m.value.get('9'));
out.mp = s.m.value.get('__proto__');
out.l = s.l.value.map((x) => (x instanceof Map ? keys(x) : x)).join('|');
out.n = s.n.value;
out.polluted = proto() === P0;
''', dev: true);
        expect(
          out['snap'],
          '{"v":1,"s":{"S.m":{"10":1,"9":{"b":1,"1":2},"__proto__":3},'
          '"S.n":42,"S.l":[{"2":"x","1":"y"},5]}}',
        );
        expect(out['m'], '10,9,__proto__');
        expect(out['m9'], 'b,1');
        expect(out['mp'], 3);
        expect(out['l'], '2,1|5');
        expect(out['n'], 42);
        expect(out['polluted'], isTrue);
      });

      test(
        'dev_state: a snapshot written by the old build (plain objects)',
        () {
          final out = run(r'''
sessionStorage.setItem('thor:state:/cart', '{"v":1,"s":{"S.m":{"b":1,"a":2},"S.n":9,"S.l":[{"k":1}]}}');
document.dispatchEvent(new CustomEvent('thor:hydrated'));
await step();
out.m = keys(s.m.value);
out.n = s.n.value;
out.l = keys(s.l.value[0]);
''', dev: true);
          expect(out['m'], 'b,a');
          expect(out['n'], 9);
          expect(out['l'], 'k');
        },
      );

      for (final (name, text) in [
        ('an array', '[1]'),
        ('a string', '"x"'),
        ('null', 'null'),
        ('s that is an array', '{"v":1,"s":[1]}'),
        ('s that is a string', '{"v":1,"s":"S.n"}'),
        ('a wrong version', '{"v":2,"s":{"S.n":1}}'),
        ('broken JSON', '{"v":1,'),
        (
          'a state that is gone',
          '{"v":1,"s":{"Nope.x":1,"__proto__":{"a":1},"S.n":11}}',
        ),
        (
          'a field of another kind',
          '{"v":1,"s":{"S.m":[1],"S.l":{"a":1},"S.n":"str"}}',
        ),
      ]) {
        test('dev_state: a snapshot that is $name never throws', () {
          final out = run('''
sessionStorage.setItem('thor:state:/cart', ${jsonEncode(text)});
let err = 'none';
try { document.dispatchEvent(new CustomEvent('thor:hydrated')); } catch (e) { err = String(e); }
await step();
out.err = err;
out.polluted = proto() === P0;
out.n = s.n.value;
out.mIsMap = s.m.value instanceof Map;
out.lIsList = Array.isArray(s.l.value);
''', dev: true);
          expect(out['err'], 'none');
          expect(out['polluted'], isTrue);
          expect(out['mIsMap'], isTrue);
          expect(out['lIsList'], isTrue);
        });
      }

      test(
        'dev_state: a Map with a non-string key is left out, not encoded',
        () {
          final out = run(r'''
s.m.value = new Map([[1, 'a']]);
const snap = window.__thorDevState();
out.snap = snap;
''', dev: true);
          expect(out['snap'], isNot(contains('"1"')));
        },
      );

      test(
        'PRE-EXISTING: dev_state: a self-referencing Map does not throw',
        () {
          final out = run(r'''
const c = new Map(); c.set('me', c);
s.m.value = c;
let err = 'none', snap = '';
try { snap = window.__thorDevState(); } catch (e) { err = String(e); }
out.err = err;
''', dev: true);
          expect(out['err'], 'none');
        },
      );

      test('dev_state: NaN and a class instance are left out', () {
        final out = run(r'''
s.n.value = NaN;
s.l.value = [new (class Foo { constructor() { this.a = 1; } })()];
out.snap = window.__thorDevState();
''', dev: true);
        expect(out['snap'], '{"v":1,"s":{"S.m":{"z":0}}}');
      });

      test('PRE-EXISTING: dev_state: a 10k-deep field does not throw', () {
        final out = run(r'''
let d = 1; for (let i = 0; i < 10000; i++) d = [d];
s.l.value = d;
let err = 'none', snap = '';
try { snap = window.__thorDevState(); } catch (e) { err = String(e); }
out.err = err;
''', dev: true);
        expect(out['err'], 'none');
      });
    });
  }
}

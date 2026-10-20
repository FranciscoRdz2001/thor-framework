@TestOn('vm')
library;

// The dev reload (part `dev_state`) and the fields with a codec: a
// `state(x, encode:, decode:)` field is saved through its `encode` and comes
// back through its `decode`; the fields of an `events()` stream are not kept
// (it re-subscribes) and are not reported either. Under node, fake DOM.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/src/lite_bundle.dart';

final _hasNode = Process.runSync('node', ['--version']).exitCode == 0;

// What the translator emits in `thor dev` for a field with `encode:` and
// `decode:`: the signal carries both (`enc`, `dec`).
const _states = r'''
const $EV = thor.events;
thor.CS = Object.freeze(['none', 'waiting', 'active', 'done'].map((n, i) => ({ index: i, name: n })));
const PANELS = Object.freeze(['tree', 'list'].map((n, i) => ({ index: i, name: n })));
globalThis.PANELS = PANELS;
const panelDec = (j) => PANELS.find((p) => p.name === j);
const panelEnc = (p) => p.name;
thor.def('S', ($) => {
  const panel = Object.assign($.state('panel', PANELS[0], panelDec), { enc: panelEnc, dec: panelDec });
  const bad = Object.assign($.state('bad', PANELS[0], panelDec), { enc: panelEnc, dec: (j) => { throw Error('nope'); } });
  const n = $.state('n', 1);
  const feed = $EV($, 'S', 'feed', null, { u: '/f', e: 'tick', k: null, m: null, i: 0 });
  return { panel, bad, n, feed, $s: { panel, bad, n, 'feed$data': feed.data, 'feed$connection': feed.connection, 'feed$loading': feed.loading, 'feed$error': feed.error } };
});
''';

const _page = r'''
globalThis.window = globalThis;
const root = { addEventListener() {}, querySelectorAll: () => [] };
const docListeners = {};
const store = new Map();
globalThis.sessionStorage = {
  getItem: (k) => (store.has(k) ? store.get(k) : null),
  setItem: (k, v) => store.set(k, v),
  removeItem: (k) => store.delete(k),
};
globalThis.document = {
  documentElement: root, cookie: '', hidden: false,
  getElementById: () => null,
  querySelectorAll: () => [],
  addEventListener: (t, f) => { docListeners[t] = f; },
  dispatchEvent(e) { docListeners[e?.type]?.(e); }, createElement: () => ({}),
};
globalThis.CustomEvent = class { constructor(t) { this.type = t; } };
globalThis.location = { pathname: '/p', search: '', href: 'http://localhost/p', origin: 'http://localhost' };
globalThis.reportError = () => {};
globalThis.addEventListener = () => {};
globalThis.EventSource = class { constructor() {} addEventListener() {} close() {} };
const warns = [], infos = [];
console.warn = (...a) => warns.push(a.join(' '));
console.info = (...a) => infos.push(a.join(' '));
const step = (ms = 0) => new Promise((r) => setTimeout(r, ms));
''';

Map<String, Object?> _run(String script, {required bool minify}) {
  String read(String f) => File('lib/lite/$f').readAsStringSync();
  final bundle = liteBundle(
    runtime: read('runtime.js'),
    parts: {
      'json': read('parts/json.js'),
      'server_call': read('parts/server_call.js'),
      'query': read('parts/query.js'),
      'events': read('parts/events.js'),
      'dev_state': read('parts/dev_state.js'),
    },
    stateJs: _states,
    minify: minify,
  );
  final js =
      '$_page$bundle\n(async () => {\nawait step();\n'
      'const s = thor.use("S");\nconst out = {};\n$script\n'
      'console.log(JSON.stringify(out));\n})();';
  final dir = Directory.systemTemp.createTempSync('thor_devcodec');
  final file = File('${dir.path}/t.js')..writeAsStringSync(js);
  final r = Process.runSync('node', [file.path]);
  dir.deleteSync(recursive: true);
  if (r.exitCode != 0) fail('node failed:\n${r.stderr}');
  return jsonDecode((r.stdout as String).trim().split('\n').last)
      as Map<String, Object?>;
}

void main() {
  for (final minify in [false, true]) {
    group(
      minify ? 'minified' : 'as written',
      skip: _hasNode ? false : 'needs node',
      () {
        test(
          'a codec field is saved through encode and restored through decode',
          () {
            final out = _run(r'''
s.panel.value = PANELS[1];
s.n.value = 5;
const snap = window.__thorDevState();
out.snap = snap;
sessionStorage.setItem('thor:state:/p', snap);
s.panel.value = PANELS[0]; s.n.value = 1;
document.dispatchEvent(new CustomEvent('thor:hydrated'));
await step();
out.same = s.panel.value === PANELS[1];
out.n = s.n.value;
out.warns = warns;
''', minify: minify);
            expect(out['snap'], contains('"S.panel":"list"'));
            expect(out['same'], isTrue);
            expect(out['n'], 5);
            expect(out['warns'], isEmpty);
          },
        );

        test('a decode that rejects the value drops that field only', () {
          final out = _run(r'''
sessionStorage.setItem('thor:state:/p', '{"v":1,"s":{"S.bad":"list","S.n":9}}');
document.dispatchEvent(new CustomEvent('thor:hydrated'));
await step();
out.n = s.n.value;
out.bad = s.bad.value === PANELS[0];
out.infos = infos;
''', minify: minify);
          expect(out['n'], 9);
          expect(out['bad'], isTrue);
          expect(out['infos'], [contains('S.bad not restored')]);
        });

        test('events() fields are skipped without a warning', () {
          final out = _run(r'''
const snap = window.__thorDevState();
out.snap = snap;
out.warns = warns;
''', minify: minify);
          expect(out['snap'], isNot(contains('feed')));
          expect(out['warns'], isEmpty);
        });
      },
    );
  }
}

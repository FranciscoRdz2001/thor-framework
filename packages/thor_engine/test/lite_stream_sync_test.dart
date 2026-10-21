@TestOn('vm')
library;

// The part `stream` applying the states' JSON a fragment brings
// (`Region(syncState: true)`): the fields of states that already run take the
// new values, the ones that do not run yet start from them, and a plain
// fragment keeps what the engine has.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/src/lite_bundle.dart';

final _hasNode = Process.runSync('node', ['--version']).exitCode == 0;

const _page = r'''
globalThis.window = globalThis;
const listeners = {};
let stateText = null;
let scanEls = []; // what the first activation finds in the page
const root = {
  addEventListener(t, f) { listeners[t] = f; },
  querySelectorAll: () => scanEls,
};
globalThis.document = {
  documentElement: root, cookie: '', querySelectorAll: () => [],
  getElementById: (id) => (id === 'thor-state' && stateText != null ? { textContent: stateText } : null),
  dispatchEvent() {}, createElement: () => ({}),
};
globalThis.CustomEvent = class {};
class El {
  constructor(attrs = {}, parent = null, tagName = 'DIV') {
    this.a = Object.assign(Object.create(null), attrs);
    this.parent = parent;
    this.tagName = tagName;
    this.isConnected = true;
    this.textContent = '';
  }
  get parentElement() { return this.parent; }
  getAttribute(n) { return n in this.a ? this.a[n] : null; }
  hasAttribute(n) { return n in this.a; }
  closest(sel) {
    const names = sel.split(',').map((s) => s.slice(1, -1));
    for (let e = this; e; e = e.parent) if (names.some((n) => e.hasAttribute(n))) return e;
    return null;
  }
}
const fire = (target, type, extra = {}) => {
  const e = { type, target, cancelBubble: false, defaultPrevented: false, preventDefault() { this.defaultPrevented = true; }, stopPropagation() { this.cancelBubble = true; }, ...extra };
  listeners[type](e);
  return e;
};
const step = () => new Promise((r) => setTimeout(r, 0));
const proto = () => Object.getOwnPropertyNames(Object.prototype).sort().join();
''';

Map<String, Object?> _run(
  String stateJs,
  String script, {
  required bool minify,
}) {
  final runtime = File('lib/lite/runtime.js').readAsStringSync();
  final bundle = liteBundle(
    runtime: runtime,
    parts: {
      for (final p in ['json', 'stream'])
        p: File('lib/lite/parts/$p.js').readAsStringSync(),
    },
    stateJs: stateJs,
    minify: minify,
  );
  final js =
      '$_page$bundle\n(async () => {\nawait step();\nconst out = {};\n'
      '$script\nconsole.log(JSON.stringify(out));\n})();';
  final r = Process.runSync('node', ['-e', js]);
  if (r.exitCode != 0) fail('node failed:\n${r.stderr}');
  return jsonDecode((r.stdout as String).trim()) as Map<String, Object?>;
}

const _states = r'''
thor.def('Slots', ($) => {
  const slots = $.state('slots', []);
  const week = $.state('week', 1);
  const day = $.state('day', 'mon', (v) => v.toUpperCase());
  return { slots: () => slots.value, week: () => week.value, day: () => day.value };
});
thor.def('Later', ($) => {
  const n = $.state('n', 0);
  return { n: () => n.value };
});
''';

void main() {
  for (final minify in [false, true]) {
    group(
      minify ? 'minified' : 'as written',
      skip: _hasNode ? false : 'needs node',
      () {
        test('sync: running fields take the values, with their decoder', () {
          final out = _run(_states, r'''
stateText = '{"Slots.slots":["a"],"Slots.week":1,"Slots.day":"x"}';
const S = thor.use('Slots');
out.before = [S.slots(), S.week(), S.day()];
listeners['thor:stream']({ detail: { nodes: [], sync: '{"Slots.slots":["b","c"],"Slots.week":2,"Slots.day":"tue"}' } });
out.after = [S.slots(), S.week(), S.day()];
''', minify: minify);
          expect(out['before'], [
            ['a'],
            1,
            'X',
          ]);
          expect(out['after'], [
            ['b', 'c'],
            2,
            'TUE',
          ]);
        });

        test(
          'sync: a state that does not run yet starts from the new value',
          () {
            final out = _run(_states, r'''
stateText = '{"Later.n":1}';
listeners['thor:stream']({ detail: { nodes: [], sync: '{"Later.n":7,"Nobody.x":1}' } });
out.n = thor.use('Later').n();
''', minify: minify);
            expect(out['n'], 7);
          },
        );

        test('no sync: the values the engine has stay, only new keys join', () {
          final out = _run(_states, r'''
stateText = '{"Slots.week":1}';
const S = thor.use('Slots');
S.week();
stateText = '{"Slots.week":9,"Later.n":4}';
listeners['thor:stream']({ detail: { nodes: [] } });
out.week = S.week();
out.n = thor.use('Later').n();
''', minify: minify);
          expect(out['week'], 1);
          expect(out['n'], 4);
        });

        test('a broken sync payload is reported and changes nothing', () {
          final out = _run(_states, r'''
stateText = '{"Slots.week":1}';
const S = thor.use('Slots');
const errors = [];
window.reportError = (x) => errors.push(String(x));
listeners['thor:stream']({ detail: { nodes: [], sync: '{nope' } });
out.week = S.week();
out.errors = errors.length;
''', minify: minify);
          expect(out['week'], 1);
          expect(out['errors'], 1);
        });
      },
    );
  }
}

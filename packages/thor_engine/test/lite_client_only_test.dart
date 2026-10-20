@TestOn('vm')
library;

// `WatchAttributes(clientOnly:)` in lite: the server leaves the attribute out
// and marks the element `data-tcs`; the lazy runtime starts the state at load
// (no event) and writes the attribute. Runs on a fake DOM in node, the
// runtime as written and minified.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/src/lite_bundle.dart';

final _hasNode = Process.runSync('node', ['--version']).exitCode == 0;

const _page = r'''
globalThis.window = globalThis;
const all = [];
const live = () => all.filter((e) => e.isConnected);
const presence = (sel) => sel.split(',').map((s) => [...s.matchAll(/\[([\w-]+)\]/g)].map((m) => m[1]));
const hits = (e, sel) => presence(sel).some((ns) => ns.every((a) => e.hasAttribute(a)));
let observer = null;
class MutationObserver {
  constructor(cb) { observer = this; this.cb = cb; }
  observe() {}
}
globalThis.MutationObserver = MutationObserver;
globalThis.addEventListener = () => {};
const root = {
  innerHTML: '',
  addEventListener() {},
  matches: () => false,
  querySelectorAll: (sel) => live().filter((e) => hits(e, sel)),
};
globalThis.document = {
  documentElement: root, cookie: '', querySelectorAll: (s) => root.querySelectorAll(s),
  querySelector: (s) => live().find((e) => hits(e, s)) || null,
  getElementById: () => null, dispatchEvent() {}, createElement: () => ({}),
};
globalThis.CustomEvent = class {};
class El {
  constructor(attrs = {}) {
    this.a = Object.assign(Object.create(null), attrs);
    this.tagName = 'BUTTON';
    this.nodeType = 1;
    this.isConnected = true;
    this.kids = [];
    all.push(this);
  }
  matches(sel) { return hits(this, sel); }
  querySelectorAll() { return []; }
  getAttribute(n) { return n in this.a ? this.a[n] : null; }
  hasAttribute(n) { return n in this.a; }
  setAttribute(n, v) { this.a[n] = `${v}`; }
  removeAttribute(n) { delete this.a[n]; }
  closest() { return null; }
}
const step = () => new Promise((r) => setTimeout(r, 0));
const errors = [];
globalThis.reportError = (x) => errors.push(x.message);
''';

const _state = r'''
thor.def('Create', ($) => {
  const name = $.state('name', '');
  return { invalid: () => name.value === '', name: () => `t:${name.value}` };
});
''';

Future<Map<String, Object?>> _run(
  String before,
  String script, {
  required bool minify,
}) async {
  final bundle = liteBundle(
    runtime: File('lib/lite/runtime.js').readAsStringSync(),
    parts: {
      for (final p in ['attributes', 'variables'])
        p: File('lib/lite/parts/$p.js').readAsStringSync(),
    },
    stateJs: _state,
    minify: minify,
  );
  final js =
      '$_page\n$before\n$bundle\n(async () => {\nawait step();\n'
      'const out = {};\n$script\nout.errors = errors;\n'
      'console.log(JSON.stringify(out));\nprocess.exit(0);\n})();';
  final p = await Process.start('node', ['-e', js]);
  final stdout = utf8.decodeStream(p.stdout);
  final stderr = utf8.decodeStream(p.stderr);
  final code = await p.exitCode.timeout(
    const Duration(seconds: 30),
    onTimeout: () {
      p.kill(ProcessSignal.sigkill);
      return -1;
    },
  );
  if (code != 0) fail('node failed ($code):\n${await stderr}');
  return jsonDecode((await stdout).trim()) as Map<String, Object?>;
}

void main() {
  for (final minify in [false, true]) {
    group(
      minify ? 'minified' : 'as written',
      skip: _hasNode ? false : 'needs node',
      () {
        test('a client-only attribute is written at load, no event', () async {
          final out = await _run(
            r'''
const go = new El({ 'data-tca': 'disabled:Create.invalid', 'data-tcs': '' });
const plain = new El({ 'data-tca': 'title:Create.name' });
''',
            r'''
out.disabled = go.getAttribute('disabled');
out.title = plain.getAttribute('title');
''',
            minify: minify,
          );
          // Started by the marked element: both bindings of the state run.
          expect(out['disabled'], '');
          expect(out['title'], 't:');
          expect(out['errors'], isEmpty);
        });

        test('without the marker the state stays lazy', () async {
          final out = await _run(
            r'''
const go = new El({ 'data-tca': 'disabled:Create.invalid' });
''',
            'out.disabled = go.getAttribute("disabled");',
            minify: minify,
          );
          expect(out['disabled'], isNull);
        });

        test('a marked element that arrives later starts its state', () async {
          final out = await _run('', r'''
const go = new El({ 'data-tca': 'disabled:Create.invalid', 'data-tcs': '' });
observer.cb([{ removedNodes: [], addedNodes: [go] }]);
await step();
out.disabled = go.getAttribute('disabled');
''', minify: minify);
          expect(out['disabled'], '');
          expect(out['errors'], isEmpty);
        });
      },
    );
  }
}

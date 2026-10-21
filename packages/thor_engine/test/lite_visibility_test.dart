// The lite `visibility` part under node with fake `IntersectionObserver` and
// `MutationObserver`: changes only, the first `false` is silent, `once`,
// options per observer, elements added later, elements removed.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/src/lite_bundle.dart';

final _hasNode = Process.runSync('node', ['--version']).exitCode == 0;

String _bundle({required bool minify}) {
  String read(String f) => File('lib/lite/$f').readAsStringSync();
  return liteBundle(
    runtime: read('runtime.js'),
    parts: {'visibility': read('parts/visibility.js')},
    stateJs: r'''
thor.def('SeenState', ($) => ({ seen: (a) => log.push(a), $s: {} }));
''',
    minify: minify,
  );
}

const _page = r'''
globalThis.window = globalThis;
const log = [];
const doc = {};
const list = [];
class El {
  constructor(a) { this.a = a; this.isConnected = true; }
  hasAttribute(n) { return n in this.a; }
  getAttribute(n) { return this.a[n] ?? null; }
  querySelectorAll(sel) { return sel.includes('visible:') ? list.filter((e) => e.isConnected && e !== this) : []; }
}
globalThis.Element = El;
const root = new El({});
root.addEventListener = () => {};
globalThis.document = {
  documentElement: root, querySelectorAll: () => [],
  getElementById: () => null,
  dispatchEvent(e) { (doc[e.type] || []).forEach((f) => f(e)); },
  addEventListener(n, f) { (doc[n] ||= []).push(f); },
  cookie: '', hidden: false,
};
globalThis.CustomEvent = class { constructor(type) { this.type = type; } };
globalThis.location = { pathname: '/', search: '', href: 'http://localhost/', origin: 'http://localhost' };
globalThis.reportError = (x) => log.push(`error:${x.message ?? x}`);
const ios = [];
if (!globalThis.noIO) {
  globalThis.IntersectionObserver = class {
    constructor(cb, o) { this.cb = cb; this.o = o; this.t = new Set(); ios.push(this); }
    observe(el) { this.t.add(el); }
    unobserve(el) { this.t.delete(el); }
    fire(el, now) { if (this.t.has(el)) this.cb([{ target: el, isIntersecting: now }]); }
  };
}
let mutate;
globalThis.MutationObserver = class { constructor(cb) { mutate = cb; } observe() {} };
const mk = (a) => { const e = new El({ 'data-t-ev': 'visible:SeenState.seen', ...a }); list.push(e); return e; };
const hit = (el, now) => ios.forEach((io) => io.fire(el, now));
const step = () => new Promise((r) => setTimeout(r, 0));
''';

Map<String, Object?> _run(String script, {required bool minify, String? head}) {
  final js =
      '${head ?? ''}$_page\n'
      'const a = mk({ "data-t-vis": "0.5|200|0" }), once = mk({ "data-t-vis": "0|0|1" }), plain = new El({ "data-t-ev": "enter:SeenState.seen" });\n'
      'list.push(plain);\n'
      '${_bundle(minify: minify)}\n(async () => {\n'
      'await step();\nconst out = {};\n$script\nout.log = log;\nconsole.log(JSON.stringify(out));\n})();';
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
        test('observes by threshold and margin, reports changes only', () {
          final out = _run(r'''
out.options = ios.map((io) => io.o);
hit(a, false);            // starts out of view: silent
out.silent = log.length;
hit(a, true); hit(a, true); // one true
hit(a, false);
hit(a, true);
''', minify: minify);
          expect(out['options'], [
            {'threshold': 0.5, 'rootMargin': '200px'},
            {'threshold': 0, 'rootMargin': '0px'},
          ]);
          expect(out['silent'], 0);
          expect(out['log'], ['true', 'false', 'true']);
        });

        test('once reports the first appearance and stops watching', () {
          final out = _run(r'''
hit(once, true);
out.watching = ios.some((io) => io.t.has(once));
hit(once, false); hit(once, true);
''', minify: minify);
          expect(out['log'], ['true']);
          expect(out['watching'], isFalse);
        });

        test('an element added later is watched; a removed one is dropped', () {
          final out = _run(r'''
const late = mk({ 'data-t-vis': '0|0|0' });
mutate([{ addedNodes: [late] }]);
hit(late, true);
a.isConnected = false;
hit(a, true);
out.dropped = ios.some((io) => io.t.has(a));
''', minify: minify);
          expect(out['log'], ['true']);
          expect(out['dropped'], isFalse);
        });

        test('an element without the marker is never watched', () {
          final out = _run(r'''
out.watched = ios.some((io) => io.t.has(plain));
''', minify: minify);
          expect(out['watched'], isFalse);
        });

        test('without IntersectionObserver nothing is reported', () {
          final out = _run(
            r'''
out.ios = typeof IntersectionObserver;
''',
            minify: minify,
            head: 'globalThis.noIO = true;\n',
          );
          expect(out['ios'], 'undefined');
          expect(out['log'], isEmpty);
        });
      },
    );
  }
}

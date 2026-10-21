// The lite `geolocation` and `share` parts under node with a fake
// `navigator`: one ask per tap, the answer in the state's methods, the
// reasons, the fallbacks of the share sheet.
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
      'geolocation': read('parts/geolocation.js'),
      'share': read('parts/share.js'),
    },
    stateJs: r'''
thor.def('NearState', ($) => ({
  found: (a) => log.push(`found:${a}`),
  failed: (a) => log.push(`failed:${a}`),
  shared: (a) => log.push(`shared:${a}`),
  $s: {},
}));
''',
    minify: minify,
  );
}

const _page = r'''
globalThis.window = globalThis;
const log = [];
const doc = {};
const clicks = [];
class El {
  constructor(a, link) { this.a = a; this.link = link; }
  hasAttribute(n) { return n in this.a; }
  getAttribute(n) { return this.a[n] ?? null; }
  closest(sel) {
    const attr = sel.match(/^\[([\w-]+)\]$/)?.[1];
    if (attr) return attr in this.a ? this : null;
    return sel === 'a[href]' && this.link ? this : null;
  }
}
globalThis.Element = El;
const root = { querySelectorAll: () => [], addEventListener(n, f, c) { (doc[n] ||= []).push(f); } };
globalThis.document = {
  documentElement: root, querySelectorAll: () => [], getElementById: () => null,
  dispatchEvent() {}, addEventListener() {}, cookie: '',
};
globalThis.CustomEvent = class {};
globalThis.location = { pathname: '/p', search: '', href: 'https://site.test/p', origin: 'https://site.test' };
globalThis.reportError = (x) => log.push(`error:${x.message ?? x}`);
let prevented = 0;
const click = (el) => { prevented = 0; (doc.click || []).forEach((f) => f({ target: el, preventDefault() { prevented++; } })); };
const setNav = (n) => Object.defineProperty(globalThis, "navigator", { value: n, configurable: true });
const step = () => new Promise((r) => setTimeout(r, 0));
const geoBtn = new El({ 'data-t-geo': 'ok:NearState.found;err:NearState.failed', 'data-t-geo-o': '1|5000|60000' });
const shareBtn = (d, link, on = 'result:NearState.shared') => new El({ 'data-t-share': on, 'data-t-share-d': JSON.stringify(d) }, link);
''';

Map<String, Object?> _run(String script, {required bool minify}) {
  final js =
      '$_page\n${_bundle(minify: minify)}\n(async () => {\n'
      'await step();\nconst out = {};\n$script\nawait step();\n'
      'out.log = log;\nconsole.log(JSON.stringify(out));\n})();';
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
        test('geolocation: asks once per tap, reports the position', () {
          final out = _run(r'''
const asks = [];
setNav({ geolocation: { getCurrentPosition(ok, err, o) { asks.push({ ok, err, o }); } } });
click(geoBtn);
out.prevented = prevented;
click(geoBtn); // the second one waits
out.asks = asks.length;
out.options = asks[0].o;
asks[0].ok({ coords: { latitude: 32.5, longitude: -117.03, accuracy: 20 } });
click(geoBtn);                // free again
out.asks2 = asks.length;
asks[1].err({ code: 1 });
click(geoBtn); asks[2].err({ code: 3 });
click(geoBtn); asks[3].err({ code: 2 });
''', minify: minify);
          expect(out['asks'], 1);
          expect(out['options'], {
            'enableHighAccuracy': true,
            'timeout': 5000,
            'maximumAge': 60000,
          });
          expect(out['prevented'], 1);
          expect(out['asks2'], 2);
          expect(out['log'], [
            'found:32.5~-117.03~20',
            'failed:denied',
            'failed:timeout',
            'failed:unavailable',
          ]);
        });

        test('geolocation: no support is a reason, not a throw', () {
          final out = _run(r'''
setNav({});
click(geoBtn);
''', minify: minify);
          expect(out['log'], ['failed:unsupported']);
        });

        test('share: the native sheet with an absolute link', () {
          final out = _run(r'''
const sent = [];
setNav({ share: (d) => { sent.push(d); return Promise.resolve(); } });
click(shareBtn({ title: 'T', text: 'x', url: '/places/a' }));
out.sent = sent.slice();
out.prevented = prevented;
await step();
click(shareBtn({ text: 'x' })); // no url: this page
out.page = sent[1].url;
''', minify: minify);
          expect(out['sent'], [
            {'title': 'T', 'text': 'x', 'url': 'https://site.test/places/a'},
          ]);
          expect(out['prevented'], 1);
          expect(out['page'], 'https://site.test/p');
          expect(out['log'], ['shared:shared', 'shared:shared']);
        });

        test('share: a closed sheet is cancelled, any other error failed', () {
          final out = _run(r'''
let n = 0;
setNav({ share: () => Promise.reject(Object.assign(new Error('x'), { name: n++ ? 'NotAllowedError' : 'AbortError' })) });
click(shareBtn({})); await step();
click(shareBtn({}));
''', minify: minify);
          expect(out['log'], ['shared:cancelled', 'shared:failed']);
        });

        test(
          'share: without a sheet a link is followed, else the text is copied',
          () {
            final out = _run(r'''
const copied = [];
setNav({ clipboard: { writeText: (t) => { copied.push(t); return Promise.resolve(); } } });
click(shareBtn({ text: 'hi', url: '/a' }, true));
out.linkPrevented = prevented;
click(shareBtn({ text: 'hi', url: '/a' }, false));
out.copyPrevented = prevented;
out.copied = copied;
setNav({});
click(shareBtn({}, false));
''', minify: minify);
            expect(out['linkPrevented'], 0);
            expect(out['copyPrevented'], 1);
            expect(out['copied'], ['hi https://site.test/a']);
            expect(out['log'], [
              'shared:link',
              'shared:copied',
              'shared:failed',
            ]);
          },
        );

        test('a share with no listener still shares', () {
          final out = _run(r'''
const sent = [];
setNav({ share: (d) => { sent.push(d); return Promise.resolve(); } });
click(shareBtn({ text: 'x' }, false, ''));
out.sent = sent.length;
''', minify: minify);
          expect(out['sent'], 1);
          expect(out['log'], isEmpty);
        });
      },
    );
  }
}

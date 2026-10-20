// The lite `events` part under node with a fake `EventSource`: one
// source per URL, JSON events, keyed merge, the connection, closing with the
// state and with the page, same-origin only.
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
      'events': read('parts/events.js'),
    },
    stateJs: r'''
const $EV = thor.events;
const $ConnectionState$values = Object.freeze(['none', 'waiting', 'active', 'done'].map((n, i) => ({ index: i, name: n })));
thor.CS = $ConnectionState$values;
class Item { constructor(id, n) { this.id = id; this.n = n; } static fromJson(j) { return new Item(j.get('id'), j.get('n')); } }
thor.def('FeedState', ($) => {
  const feed = $EV($, 'FeedState', 'feed', (j) => j.map((x) => Item.fromJson(x)), { u: '/f', e: 'tick', k: 'id', m: null, i: 1 });
  return { feed, $s: { 'feed$data': feed.data } };
});
thor.def('OtherState', ($) => {
  const last = $EV($, 'OtherState', 'last', null, { u: '/f', e: 'tick', k: null, m: null, i: 0 });
  const side = $EV($, 'OtherState', 'side', null, { u: '/f', e: 'other', k: null, m: null, i: 0 });
  const out = $EV($, 'OtherState', 'out', null, { u: 'https://evil.example/f', e: 'tick', k: null, m: null, i: 0 });
  return { last, side, out, $s: {} };
});
''',
    minify: minify,
  );
}

const _page = r'''
globalThis.window = globalThis;
const root = { addEventListener() {}, querySelectorAll: () => [] };
globalThis.document = {
  documentElement: root, querySelectorAll: () => [],
  getElementById: (id) => (id === 'thor-state' && globalThis.__state ? { textContent: globalThis.__state } : null),
  dispatchEvent() {}, cookie: '', createElement: () => ({}), hidden: false,
  addEventListener(n, f) { (doc[n] ||= []).push(f); },
};
const doc = {};
const vis = (hidden) => { document.hidden = hidden; (doc.visibilitychange || []).forEach((f) => f({})); };
globalThis.CustomEvent = class {};
globalThis.location = { pathname: '/', search: '', href: 'http://localhost/', origin: 'http://localhost' };
const errors = [];
globalThis.reportError = (x) => errors.push(`${x.message ?? x}`);
const win = {};
globalThis.addEventListener = (n, f) => (win[n] ||= []).push(f);
const sources = [];
globalThis.EventSource = class {
  constructor(u) { this.url = u; this.readyState = 0; this.l = {}; this.closed = false; sources.push(this); }
  addEventListener(n, f) { (this.l[n] ||= []).push(f); }
  close() { this.readyState = 2; this.closed = true; }
  open() { this.readyState = 1; this.onopen?.(); }
  send(n, data) { for (const f of this.l[n] || []) f({ data }); }
  drop() { this.readyState = 0; this.onerror?.(); }
  refuse() { this.readyState = 2; this.onerror?.(); }
};
const step = (ms = 0) => new Promise((r) => setTimeout(r, ms));
const show = (s) => s.feed.data.peek().map((i) => i.id + i.n).join(' ');
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
      '$script\nout.errors = errors;\nconsole.log(JSON.stringify(out));\n})();';
  final r = Process.runSync('node', ['-e', js]);
  if (r.exitCode != 0) fail('node failed:\n${r.stderr}');
  return jsonDecode((r.stdout as String).trim()) as Map<String, Object?>;
}

const _saved = r'{"FeedState.feed$data":[{"id":"a","n":1},{"id":"b","n":1}]}';

void main() {
  for (final minify in [false, true]) {
    group(
      minify ? 'minified' : 'as written',
      skip: _hasNode ? false : 'needs node',
      () {
        test('one source per url, events merge by key, the rest is kept', () {
          final out = _run(
            r'''
const o = thor.use("OtherState");
out.before = sources.length;
s.feed.start(); o.last.start(); o.side.start();
out.one = sources.length;
out.conn0 = s.feed.connection.value.name;
const es = sources[0];
es.open();
out.conn1 = s.feed.connection.value.name;
const a0 = s.feed.data.peek()[0];
es.send('tick', '[{"id":"b","n":2},{"id":"c","n":1}]');
out.merged = show(s);
out.keptA = s.feed.data.peek()[0] === a0;
es.send('tick', '{"remove":["a"],"upsert":[{"id":"c","n":5}]}');
out.removed = show(s);
out.plain = o.last.data.peek().get('remove').length;
out.snap = s.feed.snapshot().connectionState.name;
es.send('other', '{"x":1}');
out.side = o.side.data.peek()?.get('x');
es.send('tick', 'not json');
out.after = show(s);
''',
            minify: minify,
            state: _saved,
          );
          expect(out['before'], 0);
          expect(out['one'], 1);
          expect(out['conn0'], 'waiting');
          expect(out['conn1'], 'active');
          expect(out['merged'], 'a1 b2 c1');
          expect(out['keptA'], isTrue);
          expect(out['removed'], 'b2 c5');
          expect(out['plain'], 1);
          expect(out['snap'], 'active');
          expect(out['side'], 1);
          expect(out['after'], 'b2 c5');
          expect(out['errors'], hasLength(2));
        });

        test('a `thor-toast` event shows the message in the snack bar', () {
          final out = _run(
            r'''
const shown = [];
document.thorToast = (m, k, d) => shown.push([m, k, d]);
s.feed.start();
const es = sources[0];
es.open();
es.send('thor-toast', '{"message":"x.dart changed","kind":"success","duration":2500}');
es.send('thor-toast', '{"message":"plain"}');
es.send('thor-toast', '{"message":"odd","kind":"<b>","duration":-5}');
es.send('thor-toast', '{"message":"long","duration":999999}');
// Not a message: nothing shown, nothing thrown.
es.send('thor-toast', '{"kind":"error"}');
es.send('thor-toast', '{"message":""}');
es.send('thor-toast', '{"message":7}');
es.send('thor-toast', '[1]');
es.send('thor-toast', 'not json');
out.shown = shown;
out.state = show(s);
// A page without the snack bar says so, once per event.
document.thorToast = undefined;
es.send('thor-toast', '{"message":"lost"}');
''',
            minify: minify,
            state: _saved,
          );
          expect(out['shown'], [
            ['x.dart changed', 'success', 2500],
            ['plain', 'info', null],
            ['odd', 'info', null],
            ['long', 'info', 60000],
          ]);
          // The stream's own state is untouched by them.
          expect(out['state'], 'a1 b1');
          expect(out['errors'], hasLength(2));
          expect(out['errors'].toString(), contains('THOR-S031'));
        });

        test('closes when the last state lets go, and on pagehide', () {
          final out = _run(
            r'''
const o = thor.use("OtherState");
s.feed.start(); o.last.start();
const es = sources[0];
s.feed.stop();
out.stillOpen = !es.closed;
out.stoppedConn = s.feed.connection.value.name;
o.last.stop();
out.closed = es.closed;
s.feed.start();
out.reopened = sources.length;
win.pagehide.forEach((f) => f({}));
out.hidden = sources[1].closed;
out.hiddenConn = s.feed.connection.value.name;
win.pageshow.forEach((f) => f({ persisted: true }));
out.shown = sources.length;
''',
            minify: minify,
            state: _saved,
          );
          expect(out['stillOpen'], isTrue);
          expect(out['stoppedConn'], 'done');
          expect(out['closed'], isTrue);
          expect(out['reopened'], 2);
          expect(out['hidden'], isTrue);
          expect(out['hiddenConn'], 'done');
          expect(out['shown'], 3);
        });

        test(
          'a hidden tab closes the stream; showing it opens once and resyncs',
          () {
            final out = _run(
              r'''
s.feed.start();
let asked = 0;
const refresh = s.feed.refresh;
s.feed.refresh = () => asked++;
sources[0].open();
vis(true);
out.closed = sources[0].closed;
out.conn = s.feed.connection.value.name;
vis(true);
out.n1 = sources.length;
vis(false);
out.n2 = sources.length;
out.asked = asked;
vis(false);
out.n3 = sources.length;
out.asked2 = asked;
vis(true); vis(false); vis(true); vis(false);
out.n4 = sources.length;
out.live = sources.filter((e) => !e.closed).length;
out.msg = (sources[sources.length - 1].send('tick', '[{"id":"z","n":9}]'), show(s));
// a page that loads hidden does not open until it is shown
s.feed.stop();
vis(true);
s.feed.start();
out.hiddenStart = sources.length;
vis(false);
out.shownStart = sources.length;
''',
              minify: minify,
              state: _saved,
            );
            expect(out['closed'], isTrue);
            expect(out['conn'], 'done');
            expect(out['n1'], 1);
            expect(out['n2'], 2);
            expect(out['asked'], 1);
            expect(out['n3'], 2);
            expect(out['asked2'], 1);
            expect(out['n4'], 4);
            expect(out['live'], 1);
            expect(out['msg'], contains('z9'));
            expect(out['hiddenStart'], 4);
            expect(out['shownStart'], 5);
          },
        );

        test('a drop is waiting, a refusal is done and reconnect opens', () {
          final out = _run(
            r'''
s.feed.start();
const es = sources[0];
es.open();
es.drop();
out.drop = s.feed.connection.value.name;
es.open();
es.refuse();
out.refused = s.feed.connection.value.name;
s.feed.reconnect();
out.sources = sources.length;
sources[1].open();
out.back = s.feed.connection.value.name;
''',
            minify: minify,
            state: _saved,
          );
          expect(out['drop'], 'waiting');
          expect(out['refused'], 'done');
          expect(out['sources'], 2);
          expect(out['back'], 'active');
        });

        test('keyless items append; refresh without initial asks nothing', () {
          final out = _run(
            r'''
const o = thor.use("OtherState");
s.feed.start();
sources[0].send('tick', '[{"n":1},{"n":2}]');
out.n = s.feed.data.peek().length;
o.last.refresh();
out.loading = o.last.loading.peek();
''',
            minify: minify,
            state: _saved,
          );
          expect(out['n'], 4);
          expect(out['loading'], isFalse);
        });

        test('an unkeyed field takes the {replace} envelope', () {
          final out = _run(r'''
const o = thor.use("OtherState");
o.last.start();
sources[0].send('tick', '{"replace":[{"id":"a","n":1}]}');
out.a = o.last.data.peek().length;
sources[0].send('tick', '[{"id":"a"},{"id":"b"}]');
out.b = o.last.data.peek().length;
''', minify: minify);
          expect(out['a'], 1);
          expect(out['b'], 2);
        });

        test('another origin never opens', () {
          final out = _run(r'''
const o = thor.use("OtherState");
o.out.start();
out.sources = sources.length;
out.conn = o.out.connection.value.name;
''', minify: minify);
          expect(out['sources'], 0);
          expect(out['conn'], 'done');
          expect(out['errors'], [contains('not a path of this page')]);
        });
      },
    );
  }
}

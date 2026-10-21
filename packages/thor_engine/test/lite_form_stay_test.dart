// form_stay.js under node with a fake document and `fetch`: the post that
// stays, the toast, the files cleared, the redirect elsewhere, and the file
// input that sends its form. Also the queries part asking again on
// `thor:stay`.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/src/js_minify.dart';
import 'package:thor_engine/src/js_rename.dart';

final _hasNode = Process.runSync('node', ['--version']).exitCode == 0;

const _page = r'''
globalThis.window = globalThis;
const handlers = {};
const toasts = [], events = [], fetches = [], assigns = [];
globalThis.document = {
  addEventListener: (t, f) => (handlers[t] = f),
  thorToast: (m, k, ms) => toasts.push([m, k, ms]),
};
globalThis.location = { href: 'http://x.test/p', origin: 'http://x.test', assign: (u) => assigns.push(String(u)) };
globalThis.CustomEvent = class { constructor(t, i) { this.type = t; this.detail = i.detail; } };
globalThis.FormData = class { constructor() { this.items = []; } append(k, v) { this.items.push([k, v]); } };
globalThis.URLSearchParams = class { constructor(b) { this.items = b.items; } };
let reply;
globalThis.fetch = (url, init) => {
  fetches.push({ url: String(url), init });
  return reply instanceof Error ? Promise.reject(reply) : Promise.resolve(reply);
};
const answer = (status, headers = {}, extra = {}) => ({
  ok: status < 300, status, redirected: false, url: '',
  headers: { get: (n) => headers[n] ?? null }, ...extra,
});
const file = { type: 'file', files: [1], value: 'a.png' };
const send = { type: 'submit', disabled: false, name: 'go', value: '1', hasAttribute: () => false, getAttribute: (n) => (n === 'formaction' ? '/p?/store' : null) };
const form = (attrs = {}) => {
  const f = {
    method: 'post', enctype: 'application/x-www-form-urlencoded', action: '/p', target: '',
    attrs: { 'data-t-stay': '', ...attrs }, elements: [file, send], pending: false, events,
    hasAttribute(n) { return n === 'data-pending' ? this.pending : n in this.attrs; },
    toggleAttribute(n, on) { if (n === 'data-pending') this.pending = on; },
    setAttribute() {}, removeAttribute() {},
    dispatchEvent(e) { events.push(e); },
    requestSubmit(by) { f.requested = by || null; },
  };
  return f;
};
const submit = (f, submitter) => {
  const e = { target: f, submitter, defaultPrevented: false, preventDefault() { this.defaultPrevented = true; } };
  handlers.submit(e);
  return e;
};
const step = () => new Promise((r) => setTimeout(r, 0));
''';

String _script(bool minify) {
  final src = File('lib/lite/form_stay.js').readAsStringSync();
  return minify ? minifyJs(renameLocals(src)) : src;
}

Map<String, Object?> _run(String body, {required bool minify}) {
  final js =
      '$_page\n${_script(minify)}\n(async () => {\nconst out = {};\n'
      '$body\nconsole.log(JSON.stringify(out));\n})();';
  final r = Process.runSync('node', ['-e', js]);
  if (r.exitCode != 0) fail('node failed:\n${r.stderr}');
  return jsonDecode((r.stdout as String).trim()) as Map<String, Object?>;
}

void main() {
  for (final minify in [false, true]) {
    group(minify ? 'minified' : 'as written', skip: !_hasNode, () {
      test('posts in place, toasts the flash, clears files, announces', () {
        final out = _run(r'''
reply = answer(200, { 'x-thor-stay': '1', 'x-thor-flash': 'Saved%20%E2%9C%93', 'x-thor-flash-kind': 'success' });
const f = form();
const e = submit(f, send);
out.prevented = e.defaultPrevented;
out.pending = f.pending;
out.disabled = send.disabled;
await step();
out.header = fetches[0].init.headers;
out.method = fetches[0].init.method;
out.pendingAfter = f.pending;
out.disabledAfter = send.disabled;
out.toast = toasts[0];
out.file = file.value;
out.event = [events[0].type, events[0].detail];
out.navigated = assigns.length;
''', minify: minify);
        expect(out['prevented'], isTrue);
        expect(out['pending'], isTrue);
        expect(out['disabled'], isTrue);
        expect(out['header'], {'x-thor-stay': '1'});
        expect(out['method'], 'POST');
        expect(out['pendingAfter'], isFalse);
        expect(out['disabledAfter'], isFalse);
        expect(out['toast'], ['Saved ✓', 'success', null]);
        expect(out['file'], '');
        expect(out['event'], [
          'thor:stay',
          {'ok': true, 'status': 200, 'kind': 'success', 'message': 'Saved ✓'},
        ]);
        expect(out['navigated'], 0);
      });

      test('a failure toasts its message as an error and keeps the files', () {
        final out = _run(r'''
reply = answer(422, { 'x-thor-stay': '1', 'x-thor-flash': 'Name%20is%20required' });
const f = form();
submit(f, send);
await step();
out.toast = toasts[0];
out.file = file.value;
out.ok = events[0].detail.ok;
out.pending = f.pending;
''', minify: minify);
        expect(out['toast'], ['Name is required', 'error', null]);
        expect(out['file'], 'a.png');
        expect(out['ok'], isFalse);
        expect(out['pending'], isFalse);
      });

      test('a redirect elsewhere navigates; a foreign answer follows', () {
        final out = _run(r'''
reply = answer(200, { 'x-thor-stay': '1', 'x-thor-location': '/login' });
submit(form(), send);
await step();
out.first = assigns.slice();
reply = answer(200, {}, { redirected: true, url: 'http://x.test/signin' });
submit(form(), send);
await step();
out.second = assigns.slice();
out.toasts = toasts.length;
''', minify: minify);
        expect(out['first'], ['http://x.test/login']);
        expect(out['second'], ['http://x.test/login', 'http://x.test/signin']);
        expect(out['toasts'], 0);
      });

      test('a dropped connection frees the form', () {
        final out = _run(r'''
reply = new Error('down');
const f = form();
submit(f, send);
await step();
out.pending = f.pending;
out.ok = events[0].detail.ok;
''', minify: minify);
        expect(out['pending'], isFalse);
        expect(out['ok'], isFalse);
      });

      test(
        'leaves alone forms without the mark, GET forms and a second send',
        () {
          final out = _run(r'''
const plain = form();
delete plain.attrs['data-t-stay'];
out.plain = submit(plain, send).defaultPrevented;
const get = form();
get.method = 'get';
out.get = submit(get, send).defaultPrevented;
reply = answer(200, { 'x-thor-stay': '1' });
const f = form();
submit(f, send);
submit(f, send);
await step();
out.fetches = fetches.length;
''', minify: minify);
          expect(out['plain'], isFalse);
          expect(out['get'], isFalse);
          expect(out['fetches'], 1);
        },
      );

      test('files chosen send the form through the named button', () {
        final out = _run(r'''
const f = form();
const input = { type: 'file', files: [1], form: f, getAttribute: (n) => (n === 'data-t-submit-on-files' ? 'store' : null) };
handlers.change({ target: input });
out.named = f.requested === send;
input.getAttribute = () => '';
handlers.change({ target: input });
out.first = f.requested === null;
input.files = [];
f.requested = 'x';
handlers.change({ target: input });
out.empty = f.requested;
handlers.change({ target: { getAttribute: () => null } });
''', minify: minify);
        expect(out['named'], isTrue);
        expect(out['first'], isTrue);
        expect(out['empty'], 'x');
      });
    });
  }
}

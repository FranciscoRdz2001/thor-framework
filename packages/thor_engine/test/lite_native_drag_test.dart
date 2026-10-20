@TestOn('vm')
library;

// The lite part `native_drag` (NativeDraggable / NativeDragTarget) run in
// node over a fake document: the events the browser fires for a native drag
// (`dragstart`, `dragenter`, `dragover`, `drop`, `dragend`) and what the part
// writes to `dataTransfer`, marks and calls. No browser.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/src/lite_bundle.dart';

final _hasNode = Process.runSync('node', ['--version']).exitCode == 0;

const _harness = r'''
const handlers = {};
const R = { addEventListener(n, f) { (handlers[n] ??= []).push(f); } };
const document = { documentElement: R };
const log = [];
const accepts = {};
class El {
  constructor(attrs = {}, parent = null) {
    this.nodeType = 1;
    this.a = { ...attrs };
    this.parentElement = parent;
  }
  getAttribute(n) { return n in this.a ? this.a[n] : null; }
  hasAttribute(n) { return n in this.a; }
  setAttribute(n, v) { this.a[n] = v; }
  removeAttribute(n) { delete this.a[n]; }
  toggleAttribute(n, on) { if (on) this.a[n] = ''; else delete this.a[n]; }
  closest(sel) {
    const m = /^\[([\w-]+)\]$/.exec(sel);
    for (let e = this; e; e = e.parentElement) if (m ? m[1] in e.a : false) return e;
    return null;
  }
  getBoundingClientRect() { return { left: 10, top: 20 }; }
}
const timers = [];
globalThis.setTimeout = (f) => timers.push(f);
globalThis.requestAnimationFrame = (f) => { timers.push(f); return timers.length; };
const flush = () => { while (timers.length) timers.shift()(); };
globalThis.parseOn = (s) => Object.fromEntries(s.split(';').filter(Boolean).map((p) => p.split(/:(.*)/s).slice(0, 2)));
globalThis.run = (id, el, v) => log.push(['run', id, v ?? null]);
globalThis.fail = (x) => { throw x; };
const kit = PART_KIT;
const fits = new Function(kit.match(/const fits = [^\n]*/)[0] + '; return fits;')();
globalThis.thor = { dnd: { call: (el, id, v) => (log.push(['call', id, v]), accepts[id] ? accepts[id](v) : true), fits } };
globalThis.document = document;
eval(PART_JS);
const fire = (name, e) => {
  e.preventDefault = () => (e.prevented = true);
  for (const h of handlers[name] ?? []) h(e);
  return e;
};
const transfer = (init = {}) => {
  const store = {};
  return { types: init.types ?? [], effectAllowed: init.effectAllowed ?? 'uninitialized', dropEffect: 'none', store, setData(k, v) { store[k] = v; }, getData(k) { return init.data?.[k] ?? store[k] ?? ''; } };
};
const out = (v) => console.log(JSON.stringify(v));
''';

Future<Map<String, Object?>> _run(String script) async {
  final part = File('lib/lite/parts/native_drag.js').readAsStringSync();
  final kit = File('lib/lite/parts/drag_kit.js').readAsStringSync();
  final js =
      '''
${_harness.replaceAll('PART_KIT', jsonEncode(kit)).replaceAll('PART_JS', jsonEncode(part))}
$script
''';
  final r = await Process.run('node', ['-e', js]);
  expect(r.exitCode, 0, reason: '${r.stderr}');
  return jsonDecode('${r.stdout}'.trim().split('\n').last)
      as Map<String, Object?>;
}

void main() {
  final skip = _hasNode ? false : 'needs node';

  test(
    'dragstart writes the data and the extra entries, then marks the source',
    skip: skip,
    () async {
      final r = await _run(r'''
const src = new El({ 'data-t-nd': 'start:S.go;end:S.end', 'data-t-nd-data': 'n7', 'data-t-nd-type': 'String', 'data-t-nd-cfg': 'application/x-node|copy', 'data-t-nd-xfer': '{"text/uri-list":"https://x.test/7"}' });
const inner = new El({}, src);
const dt = transfer();
fire('dragstart', { target: inner, dataTransfer: dt });
const before = 'data-t-nd-active' in src.a;
flush();
out({ store: dt.store, effect: dt.effectAllowed, before, after: 'data-t-nd-active' in src.a, log });
''');
      expect(r['store'], {
        'application/x-node': 'n7',
        'text/uri-list': 'https://x.test/7',
      });
      expect(r['effect'], 'copy');
      // After the browser took the drag image, not before.
      expect(r['before'], isFalse);
      expect(r['after'], isTrue);
      expect(r['log'], [
        ['run', 'S.go', null],
      ]);
    },
  );

  test(
    'a target of this page takes a fitting drag and answers dropEffect',
    skip: skip,
    () async {
      final r = await _run(r'''
const src = new El({ 'data-t-nd': 'end:S.end;done:S.done;cancel:S.cancel', 'data-t-nd-data': 'n7', 'data-t-nd-type': 'String', 'data-t-nd-cfg': 'text/plain|copyMove' });
const yes = new El({ 'data-t-nt': 'accept:T.ok;drop:T.drop;leave:T.leave', 'data-t-nd-type': 'String' });
const no = new El({ 'data-t-nt': 'drop:T.never', 'data-t-nd-type': 'int' });
const object = new El({ 'data-t-nt': 'drop:T.any', 'data-t-nd-type': 'Object' });
const child = new El({}, yes);
fire('dragstart', { target: src, dataTransfer: transfer() });
const dt = transfer({ effectAllowed: 'copyMove' });
fire('dragenter', { target: child, dataTransfer: dt });
const over = fire('dragover', { target: child, dataTransfer: dt, clientX: 15, clientY: 30 });
const marked = 'data-t-dt-over' in yes.a;
const rejected = fire('dragover', { target: no, dataTransfer: dt });
const rejectMark = 'data-t-dt-reject' in no.a;
const anyOne = fire('dragover', { target: object, dataTransfer: dt });
out({ prevented: !!over.prevented, effect: dt.dropEffect, marked, rejectedPrevented: !!rejected.prevented, rejectMark, leftMark: 'data-t-dt-over' in yes.a, anyPrevented: !!anyOne.prevented, log });
''');
      expect(r['prevented'], isTrue);
      expect(r['effect'], 'copy');
      expect(r['marked'], isTrue);
      expect(r['rejectedPrevented'], isFalse);
      expect(r['rejectMark'], isTrue);
      // Moving to another target: the one before is unmarked and hears leave.
      expect(r['leftMark'], isFalse);
      expect(r['anyPrevented'], isTrue);
      expect(r['log'], contains(equals(['call', 'T.ok', 'n7'])));
      expect(r['log'], contains(equals(['run', 'T.leave', 'n7'])));
    },
  );

  test('a method that says no turns the drop down', skip: skip, () async {
    final r = await _run(r'''
accepts['T.ok'] = () => false;
const src = new El({ 'data-t-nd': 'end:S.end', 'data-t-nd-data': 'n7', 'data-t-nd-type': 'String' });
const t = new El({ 'data-t-nt': 'accept:T.ok;drop:T.drop', 'data-t-nd-type': 'String' });
fire('dragstart', { target: src, dataTransfer: transfer() });
const dt = transfer();
const over = fire('dragover', { target: t, dataTransfer: dt });
const reject = 'data-t-dt-reject' in t.a;
const dropped = fire('drop', { target: t, dataTransfer: dt });
out({ prevented: !!over.prevented, dropPrevented: !!dropped.prevented, reject, log });
''');
    expect(r['prevented'], isFalse);
    expect(r['dropPrevented'], isFalse);
    expect(r['reject'], isTrue);
    expect(
      (r['log']! as List).where((x) => (x as List)[1] == 'T.drop'),
      isEmpty,
    );
  });

  test(
    'drop runs the method with the data, dragend tells the source',
    skip: skip,
    () async {
      final r = await _run(r'''
const src = new El({ 'data-t-nd': 'end:S.end;done:S.done;cancel:S.cancel', 'data-t-nd-data': 'n7', 'data-t-nd-type': 'String' });
const t = new El({ 'data-t-nt': 'drop:T.drop', 'data-t-nd-type': 'Object' });
fire('dragstart', { target: src, dataTransfer: transfer() });
flush();
const dt = transfer();
fire('dragover', { target: t, dataTransfer: dt });
const dropped = fire('drop', { target: t, dataTransfer: dt });
const afterDrop = 'data-t-dt-over' in t.a;
fire('dragend', { target: src, dataTransfer: dt, clientX: 1, clientY: 2 });
const first = log.splice(0);
// A second drag that nothing takes.
fire('dragstart', { target: src, dataTransfer: transfer() });
fire('dragend', { target: src, dataTransfer: transfer(), clientX: 5.25, clientY: 6 });
out({ dropPrevented: !!dropped.prevented, afterDrop, active: 'data-t-nd-active' in src.a, first, second: log });
''');
      expect(r['dropPrevented'], isTrue);
      expect(r['afterDrop'], isFalse);
      expect(r['active'], isFalse);
      expect(r['first'], [
        ['run', 'T.drop', 'n7'],
        ['run', 'S.done', null],
        ['run', 'S.end', 'true'],
      ]);
      expect(r['second'], [
        ['run', 'S.cancel', '5.3~6'],
        ['run', 'S.end', 'false'],
      ]);
    },
  );

  test(
    'a drag from outside needs one of the target\'s MIME types',
    skip: skip,
    () async {
      final r = await _run(r'''
const t = new El({ 'data-t-nt': 'drop:T.drop', 'data-t-nd-type': 'String', 'data-t-nt-mime': 'text/uri-list\nFiles', 'data-t-nt-effect': 'link' });
const other = new El({ 'data-t-nt': 'drop:T.nope', 'data-t-nd-type': 'String' });
const dt = transfer({ types: ['text/uri-list'], data: { 'text/uri-list': 'https://x.test/a' } });
const over = fire('dragover', { target: t, dataTransfer: dt });
const refused = fire('dragover', { target: other, dataTransfer: dt });
const dropped = fire('drop', { target: t, dataTransfer: dt });
out({ prevented: !!over.prevented, effect: dt.dropEffect, refused: !!refused.prevented, dropPrevented: !!dropped.prevented, log });
''');
      expect(r['prevented'], isTrue);
      expect(r['effect'], 'link');
      expect(r['refused'], isFalse);
      expect(r['dropPrevented'], isTrue);
      expect(r['log'], [
        ['run', 'T.drop', 'https://x.test/a'],
      ]);
    },
  );

  test(
    'leaving the document unmarks the target and tells it',
    skip: skip,
    () async {
      final r = await _run(r'''
const src = new El({ 'data-t-nd': 'end:S.end', 'data-t-nd-data': 'n7', 'data-t-nd-type': 'String' });
const t = new El({ 'data-t-nt': 'leave:T.leave', 'data-t-nd-type': 'String' });
fire('dragstart', { target: src, dataTransfer: transfer() });
const dt = transfer();
fire('dragenter', { target: t, dataTransfer: dt });
fire('dragover', { target: t, dataTransfer: dt });
const during = 'data-t-dt-over' in t.a;
fire('dragleave', { target: t, dataTransfer: dt });
out({ during, after: 'data-t-dt-over' in t.a, log });
''');
      expect(r['during'], isTrue);
      expect(r['after'], isFalse);
      expect(r['log'], contains(equals(['run', 'T.leave', 'n7'])));
    },
  );

  test(
    'the part is valid JavaScript in a minified bundle with the drag parts',
    skip: skip,
    () {
      final bundle = liteBundle(
        runtime: File('lib/lite/runtime.js').readAsStringSync(),
        parts: {
          for (final p in ['drag_kit', 'drag_drop', 'native_drag'])
            p: File('lib/lite/parts/$p.js').readAsStringSync(),
        },
        stateJs: '',
      );
      final dir = Directory.systemTemp.createTempSync('thor_native_drag_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/bundle.js')..writeAsStringSync(bundle);
      final r = Process.runSync('node', ['--check', file.path]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
    },
  );
}

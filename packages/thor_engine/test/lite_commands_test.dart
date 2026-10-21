@TestOn('vm')
library;

// The lite part `commands` under node with a tiny fake DOM: a command on a
// box (not a button) opens and closes a dialog on click and on Enter /
// Space; on a button it only acts where the browser lacks Invoker Commands.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/src/lite_bundle.dart';

final _hasNode = Process.runSync('node', ['--version']).exitCode == 0;

const _page = r'''
globalThis.window = globalThis;
const listeners = {};
let nativeCommands = false;
const root = { addEventListener(t, f) { listeners[t] = f; } };
const dialog = { open: false, showModal() { this.open = true; }, close() { this.open = false; } };
class El {
  constructor(tagName, attrs) { this.tagName = tagName; this.a = attrs; }
  getAttribute(n) { return n in this.a ? this.a[n] : null; }
  hasAttribute(n) { return n in this.a; }
  closest(sel) { return this.hasAttribute('commandfor') ? this : null; }
}
globalThis.document = {
  documentElement: root,
  getElementById: (id) => (id === 'd' ? dialog : null),
  createElement: () => (nativeCommands ? { command: '' } : {}),
};
const mk = (tag, extra = {}) => new El(tag, { commandfor: 'd', command: 'show-modal', ...extra });
const click = (t) => listeners.click({ target: t });
const key = (t, k) => { const e = { target: t, key: k, defaultPrevented: false, preventDefault() { this.defaultPrevented = true; } }; listeners.keydown(e); return e; };
''';

String _part() => liteBundle(
  runtime: '// @thor-lite-parts\n',
  parts: {'commands': File('lib/lite/parts/commands.js').readAsStringSync()},
  stateJs: '',
  minify: false,
);

Map<String, Object?> _run(String script, {bool native = false}) {
  final js =
      '$_page${native ? 'nativeCommands = true;' : ''}${_part()}\n'
      '(() => { const out = {};\n$script\nconsole.log(JSON.stringify(out)); })();';
  final r = Process.runSync('node', ['-e', js]);
  expect(r.exitCode, 0, reason: '${r.stderr}');
  return jsonDecode(r.stdout as String) as Map<String, Object?>;
}

void main() {
  final skip = _hasNode ? null : 'needs node';

  test('a box opens and closes a dialog on click', () {
    final out = _run('''
const box = mk('DIV', { role: 'button', tabindex: '0' });
click(box); out.opened = dialog.open;
const close = mk('DIV', { command: 'close', role: 'button' });
click(close); out.closed = !dialog.open;
''', native: true);
    expect(out, {'opened': true, 'closed': true});
  }, skip: skip);

  test('Enter and Space press a box, other keys do not', () {
    final out = _run('''
const box = mk('DIV', { role: 'button', tabindex: '0' });
out.tab = key(box, 'Tab').defaultPrevented || dialog.open;
const e = key(box, 'Enter'); out.enter = dialog.open && e.defaultPrevented;
dialog.close();
key(box, ' '); out.space = dialog.open;
''', native: true);
    expect(out, {'tab': false, 'enter': true, 'space': true});
  }, skip: skip);

  test('an aria-disabled box does nothing', () {
    final out = _run('''
click(mk('DIV', { role: 'button', 'aria-disabled': 'true' }));
out.opened = dialog.open;
''', native: true);
    expect(out, {'opened': false});
  }, skip: skip);

  test('a button is left to the browser where it has commands', () {
    final out = _run('''
click(mk('BUTTON')); out.opened = dialog.open;
''', native: true);
    expect(out, {'opened': false});
  }, skip: skip);

  test('a button is polyfilled where the browser lacks commands', () {
    final out = _run('''
click(mk('BUTTON')); out.opened = dialog.open;
''');
    expect(out, {'opened': true});
  }, skip: skip);
}

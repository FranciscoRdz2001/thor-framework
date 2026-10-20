// The lite engine's `key_actions` part in a real browser
// (Chromium by default, or the one named):
// Flutter's Shortcuts + Actions and Focus(onKeyEvent:), with the markup
// thor_ui writes, in a page built in memory from lib/lite/runtime.js and the
// `shortcuts` + `key_actions` parts (no app to build). The same scenarios run
// against the dart2js oracle in
// packages/thor_engine_oracle/test/key_actions_client_test.dart.
//
//   node test/e2e/checks/lite_key_actions_check.mjs [chromium|firefox|webkit]
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import * as pw from '../runner/node_modules/playwright/index.mjs';
import { repo } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
const runtime = readFileSync(join(lite, 'runtime.js'), 'utf8');
const part = (n) => readFileSync(join(lite, 'parts', n), 'utf8');
const bundle = (...parts) => runtime.replace('// @thor-lite-parts', () => parts.map(part).join('\n'));

// The state: each method logs; onKey says what it did with the key, by its
// label (Enter handled, x skips the rest, anything else ignored).
const state = `window.log = [];
thor.def('K', () => ({
  save: () => log.push('save'), innerSave: () => log.push('innerSave'), open: () => log.push('open'),
  outerSave: () => log.push('outerSave'), outerEsc: () => log.push('outerEsc'), outerX: () => log.push('outerX'),
  search: () => log.push('search'),
  onKey: (a) => {
    const [r, l, c] = JSON.parse(a);
    log.push(\`key:\${l}:\${c ?? ''}:\${r}\${thor.keys.isMetaPressed ? ':meta' : ''}\`);
    return { name: l === 'Enter' ? 'handled' : l === 'x' ? 'skipRemainingHandlers' : 'ignored' };
  },
}));`;

const page = (body) =>
  `<!DOCTYPE html><html><head><meta charset="utf-8"></head><body>${body}<script>${bundle('shortcuts.js', 'key_actions.js')}
${state}</script></body></html>`;

// CallbackShortcuts outermost; Shortcuts with their Actions inside; an inner
// Actions that overrides Save; a Focus(onKeyEvent:) with a child.
const tree = `<div id="outer" data-tks="m+s>K.outerSave;+escape>K.outerEsc;+x>K.outerX" data-tai="Save>K.save">
<div id="shell" data-tsi="m+s>Save;+enter>Open;+escape>Close;+delete>Gone;c+1>Pass" data-tai="Open>K.open;Gone>;Pass>!">
<div id="inner" data-tai="Save>K.innerSave"><span id="deep" tabindex="0">deep</span></div>
<span id="page" tabindex="0">page</span><input id="field" type="text">
<div id="keys" tabindex="0" data-tke="K.onKey">keys <span id="child" tabindex="0">child</span></div>
</div></div>`;

// With nothing focused, the outermost Shortcuts answers (its Actions found
// from it); a Focus(onKeyEvent:) does not.
const root = `<div id="app" data-tsi="m+k>Search" data-tai="Search>K.search" data-tke="K.onKey"><span id="a" tabindex="0">a</span></div>`;

const pages = { '/tree': page(tree), '/root': page(root) };

const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} [${engine}] ${label}${detail !== '' ? ` (${detail})` : ''}`);
};

const engine = process.argv[2] ?? process.env.E2E_BROWSER ?? 'chromium';
const browser = await pw[engine].launch();
const open = async (path) => {
  const ctx = await browser.newContext();
  const p = await ctx.newPage();
  p.problems = [];
  p.on('pageerror', (e) => p.problems.push(e.message));
  await ctx.route('http://lite.test/**', (r) => {
    const body = pages[new URL(r.request().url()).pathname];
    return body ? r.fulfill({ contentType: 'text/html', body }) : r.fulfill({ status: 404, body: '' });
  });
  await p.goto(`http://lite.test${path}`);
  await p.waitForFunction(() => typeof thor !== 'undefined');
  return p;
};
// A keydown as the browser sends it, on the element `id` (focused first) or
// on <body> with nothing focused: [what the state logged, defaultPrevented].
const press = (p, id, key, code, mods = {}) =>
  p.evaluate(([id, key, code, mods]) => {
    document.activeElement?.blur();
    const target = id ? document.getElementById(id) : document.body;
    if (id) target.focus();
    const e = new KeyboardEvent('keydown', { key, code, bubbles: true, cancelable: true, ...mods });
    target.dispatchEvent(e);
    return [window.log.splice(0).join(), e.defaultPrevented];
  }, [id, key, code, mods]);
const meta = { metaKey: true };

try {
  {
    const p = await open('/tree');
    let [log, stopped] = await press(p, 'page', 's', 'KeyS', meta);
    check('Shortcuts: ⌘S is SaveIntent, run by the Actions above that has it', log === 'save' && stopped, log);
    [log] = await press(p, 'deep', 's', 'KeyS', meta);
    check('Actions: the nearest the focus wins (inner override)', log === 'innerSave', log);
    [log] = await press(p, 'page', 'Enter', 'Enter');
    check('Actions: on the Shortcuts element itself', log === 'open', log);
    [log] = await press(p, 'page', 'Escape', 'Escape');
    check('an intent with no action lets the key go on to outer shortcuts', log === 'outerEsc', log);
    [log, stopped] = await press(p, 'page', 'Delete', 'Delete');
    check('DoNothingAction stops the key and runs nothing', log === '' && stopped, `${log} ${stopped}`);
    [log, stopped] = await press(p, 'page', '1', 'Digit1', { ctrlKey: true });
    check('DoNothingAction(consumesKey: false) lets it go on', log === '' && !stopped, `${log} ${stopped}`);
    [log, stopped] = await press(p, 'page', 'ы', 'KeyS', meta);
    check('Shortcuts: Cyrillic ы on KeyS is ⌘S (physical fallback)', log === 'save' && stopped, log);
    [log] = await press(p, 'field', 'a', 'KeyA');
    check('a text field keeps its letters', log === '', log);
    [log] = await press(p, 'field', 'Enter', 'Enter');
    check('Enter reaches the shortcuts from a text field', log === 'open', log);

    [log, stopped] = await press(p, 'keys', 'Enter', 'Enter');
    check('onKeyEvent handled: the key stops there', log === 'key:Enter::0' && stopped, `${log} ${stopped}`);
    [log, stopped] = await press(p, 'child', 's', 'KeyS', meta);
    check('onKeyEvent ignored: the outer Shortcuts get it (from a descendant)', log === 'key:s:s:0:meta,save' && stopped, log);
    [log, stopped] = await press(p, 'keys', 'x', 'KeyX');
    check('onKeyEvent skipRemainingHandlers: nothing else, the browser keeps it', log === 'key:x:x:0' && !stopped, `${log} ${stopped}`);
    [log, stopped] = await press(p, 'keys', 'ArrowUp', 'ArrowUp', { repeat: true });
    check('onKeyEvent: a repeat, no character', log === 'key:ArrowUp::1' && !stopped, log);
    [log] = await press(p, 'keys', 'X', 'KeyX', { shiftKey: true });
    check('onKeyEvent: Shift+X is key x, character X', log === 'key:x:X:0', log);
    [log] = await press(p, 'keys', 'ы', 'KeyS');
    check('onKeyEvent: a non-Latin letter keeps its character, its key is physical', log === 'key:s:ы:0', log);
    check('no page errors', p.problems.length === 0, p.problems.join('; '));
    await p.context().close();
  }
  {
    const p = await open('/root');
    const [log, stopped] = await press(p, null, 'k', 'KeyK', meta);
    check('nothing focused: the outermost Shortcuts answer, not onKeyEvent', log === 'search' && stopped, log);
    const [log2] = await press(p, 'a', 'k', 'KeyK', meta);
    check('focused inside: onKeyEvent first, then the Shortcuts', log2 === 'key:k:k:0:meta,search', log2);
    check('root: no page errors', p.problems.length === 0, p.problems.join('; '));
    await p.context().close();
  }
} finally {
  await browser.close();
}
const failed = results.filter((r) => !r).length;
console.log(`${results.length - failed}/${results.length} checks passed`);
process.exit(failed ? 1 : 0);

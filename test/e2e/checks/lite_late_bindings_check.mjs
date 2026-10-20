// WatchVariables / WatchAttributes (`data-tcv`, `data-tca`) of the lite engine
// where the page gains markup after the state started: a late part
// (`thor:stream`), a copy put in place of a subtree (`thor:adopted`) and the
// rows the browser clones. Pages made in memory from lib/lite/runtime.js and
// the attributes / variables parts, real Chromium.
//
//   node test/e2e/checks/lite_late_bindings_check.mjs
//
// - a pair only a late part brings is followed (a variable in px, an attribute)
// - rows cloned from a template follow their own pair, rows that left stop
// - a pair a replaced subtree brings is followed
// - many swaps leave no binding behind (the signal's subscribers are counted)
// - a bound length (`state.field.px`): a variable named after a field, not a method
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { chromium, firefox, webkit } from '../runner/node_modules/playwright/index.mjs';
import { frames, repo } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
// Keyed lists are the runtime's part `lists`, sewn in first (an older
// runtime, without that part next to it, has them inside).
const withLists = (src, at) => {
  const p = join(dirname(at), 'parts/lists.js');
  return src.replace('// @thor-lite-parts', () => `${existsSync(p) ? readFileSync(p, 'utf8') : ''}\n// @thor-lite-parts`);
};
const runtimePath = join(lite, 'runtime.js');
const runtime = withLists(readFileSync(runtimePath, 'utf8'), runtimePath);
const parts = ['attributes.js', 'variables.js']
  .map((n) => readFileSync(join(lite, 'parts', n), 'utf8'))
  .join('\n');
const page = (body, script) =>
  `<!DOCTYPE html><html><head><base href="/"></head><body>${body}<script>${runtime.replace('// @thor-lite-parts', () => parts)}\n${script}</script></body></html>`;

// `m` is what every pair reads: its subscribers are the live bindings.
const STATE = `thor.def('V', ($) => {
  const m = $.state('m', 2), it = $.state('items', []);
  window.m = m;
  window.subs = () => { let n = 0; for (let l = m.sh; l; l = l.q) n++; return n; };
  return {
    items: () => it.value, key: (i) => i, title: (i) => i, m: () => m.value,
    w: (k) => Number(k) * m.value, lab: (k) => 'L' + k + ':' + m.value,
    set: (s) => { it.value = s === '' ? [] : s.split(','); },
  };
}, { eager: true });
window.late = (html) => {
  const h = document.getElementById('host');
  h.insertAdjacentHTML('beforeend', html);
  document.documentElement.dispatchEvent(new CustomEvent('thor:stream', { detail: { nodes: [...h.children].slice(-1) } }));
};`;

const PAGE = page(
  `<div id="s0" data-tcv="--a:V.w~1" data-tca="aria-label:V.lab~s" style="--a:2px" aria-label="Ls:2"></div>
<ul id="l" data-tl="V.items" data-tlk="V.key"><template data-tlt="V.items"><li data-tf="V.title" data-tcv="--r:V.w~{{key}}" data-tca="aria-label:V.lab~{{key}}"></li></template></ul>
<div id="swap"><p id="old" data-tcv="--o:V.w~9" style="--o:18px"></p></div>
<div id="bound" data-tcv="--tb-V-m:V.m;--tb-V-w_7e_3:V.w~3" style="--tb-V-m:2px;--tb-V-w_7e_3:6px"></div>
<div id="host"></div>`,
  STATE,
);

const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail !== '' ? ` (${detail})` : ''}`);
};

// Chromium, or the browser `E2E_BROWSER` names (tool/thor e2e --browsers).
const browser = await { chromium, firefox, webkit }[process.env.E2E_BROWSER ?? 'chromium'].launch();
const open = async () => {
  const ctx = await browser.newContext();
  const p = await ctx.newPage();
  p.problems = [];
  p.on('pageerror', (e) => p.problems.push(e.message));
  await ctx.route('http://lite.test/**', (r) => r.fulfill({ contentType: 'text/html', body: PAGE }));
  await p.goto('http://lite.test/');
  await p.waitForFunction(() => typeof thor !== 'undefined' && thor.use);
  await frames(p);
  return p;
};
const css = (p, sel, name) => p.evaluate(([s, n]) => document.querySelector(s)?.style.getPropertyValue(n), [sel, name]);
const attr = (p, sel, name) => p.evaluate(([s, n]) => document.querySelector(s)?.getAttribute(n), [sel, name]);
const subs = (p) => p.evaluate(() => subs());
const setM = async (p, v) => {
  await p.evaluate((v) => (m.value = v), v);
  await frames(p);
};
const items = async (p, s) => {
  await p.evaluate((s) => thor.use('V').set(s), s);
  await frames(p);
};

try {
  {
    const p = await open();
    check('first page: the pair of the first page follows', (await css(p, '#s0', '--a')) === '2px');
    await setM(p, 3);
    check('first page: and changes with the state', (await css(p, '#s0', '--a')) === '3px' && (await attr(p, '#s0', 'aria-label')) === 'Ls:3');

    // A late part.
    await p.evaluate(() => late('<div id="late" data-tcv="--w:V.w~5" data-tca="aria-label:V.lab~z" style="--w:0px"></div>'));
    await frames(p);
    check('late part: a late part\'s variable gets the state\'s value', (await css(p, '#late', '--w')) === '15px', await css(p, '#late', '--w'));
    check('late part: and its attribute', (await attr(p, '#late', 'aria-label')) === 'Lz:3', await attr(p, '#late', 'aria-label'));
    await setM(p, 4);
    check('late part: both follow the state afterwards', (await css(p, '#late', '--w')) === '20px' && (await attr(p, '#late', 'aria-label')) === 'Lz:4');

    // Rows.
    await items(p, '1,2,3');
    check('rows: cloned rows have their own value', (await css(p, '[data-tk="2"]', '--r')) === '8px' && (await attr(p, '[data-tk="3"]', 'aria-label')) === 'L3:4');
    await setM(p, 5);
    check('rows: and follow the state', (await css(p, '[data-tk="3"]', '--r')) === '15px' && (await attr(p, '[data-tk="1"]', 'aria-label')) === 'L1:5');
    await items(p, '2,4');
    await setM(p, 6);
    check('rows: a row added later follows too, the others still do', (await css(p, '[data-tk="4"]', '--r')) === '24px' && (await css(p, '[data-tk="2"]', '--r')) === '12px');

    // A subtree replaced by a copy with another pair.
    await p.evaluate(() => {
      const c = document.createElement('div');
      c.id = 'swap2';
      c.innerHTML = '<p id="new" data-tcv="--n:V.w~7" style="--n:0px"></p>';
      document.getElementById('swap').replaceWith(c);
      c.dispatchEvent(new CustomEvent('thor:adopted'));
    });
    await setM(p, 7);
    check('replaced subtree: the pair of a replaced subtree is followed', (await css(p, '#new', '--n')) === '49px', await css(p, '#new', '--n'));
    check('replaced subtree: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.context().close();
  }
  {
    // What a BoundLength writes: a field and a method with an argument.
    const p = await open();
    check('bound length: the first values are the server\'s', (await css(p, '#bound', '--tb-V-m')) === '2px');
    await setM(p, 5);
    check(
      'bound length: a field and a method with an argument follow the state',
      (await css(p, '#bound', '--tb-V-m')) === '5px' && (await css(p, '#bound', '--tb-V-w_7e_3')) === '15px',
      `${await css(p, '#bound', '--tb-V-m')} ${await css(p, '#bound', '--tb-V-w_7e_3')}`,
    );
    check('bound length: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.context().close();
  }
  {
    // Many swaps of rows with new keys leave no binding behind.
    const p = await open();
    const base = await subs(p);
    for (let i = 0; i < 400; i++) await items(p, `${i * 3 + 1},${i * 3 + 2},${i * 3 + 3}`);
    const grown = await subs(p);
    check('swaps: 400 swaps of 3 rows: the bindings of rows that left are released', grown < base + 700, `${base} -> ${grown}`);
    await setM(p, 9);
    const after = await subs(p);
    check('swaps: after the next change only the live ones are left', after === base + 6, `${base} -> ${after}`);
    check('swaps: the rows on the page follow', (await css(p, '[data-tk="1198"]', '--r')) === '10782px', await css(p, '[data-tk="1198"]', '--r'));
    await items(p, '');
    await setM(p, 10);
    check('swaps: an empty list leaves only the page\'s own', (await subs(p)) === base, `${await subs(p)}`);
    check('swaps: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.context().close();
  }
} finally {
  await browser.close();
}

const failed = results.filter((ok) => !ok).length;
console.log(`\n${results.length - failed}/${results.length} checks passed`);
if (failed > 0 || results.length === 0) process.exit(1);

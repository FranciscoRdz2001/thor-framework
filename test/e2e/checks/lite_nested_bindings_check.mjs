// Nested Watch bindings and list containers in the lite runtime, broken on
// purpose: pages made in memory from lib/lite/runtime.js and the
// row_states part, real Chromium.
//
//   node test/e2e/checks/lite_nested_bindings_check.mjs
//
// - a keyed list that only exists in the variant of another state (its own
//   state already running) follows its items, also with row states, and a
//   variant toggled many times leaves no container behind.
// - a Watch of ANOTHER state (a text and a variants Watch of `O`) inside the
//   rows of a keyed list: rows the server drew and rows the browser adds
//   after load all follow it; a row that comes in after the state changed
//   shows its current value; removed rows are not kept (a detached row is
//   not written, one effect per binding however many rows came and went).
// - the same nested: a row -> a variant of O -> a keyed list -> a text of O.
// - a `container:` that puts widgets after the rows (a footer): the list
//   keeps its marker and its rows go before the footer, also inside a
//   variant.
// - a `container:` with two roots (a ResponsiveLayout with a list per
//   breakpoint): the marker sits on a `display: contents` box and both
//   lists follow the items, rows added, moved and removed.
// - a `container:` whose rows are not its children (a Column holding the
//   carousel): the rows go into the carousel, before its template.
// - a finite state the server did not draw (a QueryBuilder whose builder reads
//   snapshot.data) is told to `thor.miss` (what `thor dev` prints as THOR-S037);
//   one it did draw is not.
// - the same text, finite state and list drawn twice on a page (a desktop
//   and a mobile copy, one hidden by CSS): every copy follows.
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { chromium } from '../runner/node_modules/playwright/index.mjs';
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
const parts = ['row_states.js'].map((n) => readFileSync(join(lite, 'parts', n), 'utf8')).join('\n');
const page = (body, script) =>
  `<!DOCTYPE html><html><head><base href="/"></head><body>${body}<script>${runtime.replace('// @thor-lite-parts', () => parts)}\n${script}</script></body></html>`;

const STATES = `thor.def('S', ($) => { const open = $.state('open', false); return { open: () => open.value, toggle: () => { open.value = !open.value; } }; }, { eager: true });
thor.def('M', ($) => {
  const it = $.state('items', ['x', 'q']);
  return {
    items: () => it.value, key: (i) => i, text: (i) => i, marked: (i) => i.startsWith('q'),
    set: (s) => { it.value = s ? s.split(',') : []; },
  };
}, { eager: true });`;

// The list, its row (a text and a row state) and its template.
const LIST = (extra = '') => `<ul class="l" data-tl="M.items" data-tlk="M.key"><li data-tk="x"><b data-tf="M.text">x</b><i data-tvf="M.marked" data-tvi="0" data-tp-1="|#|=*">.</i></li><li data-tk="q"><b data-tf="M.text">q</b><i data-tvf="M.marked" data-tvi="1" data-tp-1="|#|=*">*</i></li><template data-tlt="M.items"><li><b data-tf="M.text"></b><i data-tvf="M.marked" data-tvi="0" data-tp-1="|#|=*">.</i></li></template>${extra}</ul>`;

const pages = {
  // The list is on the page too; the variant brings a second one.
  '/variant': page(
    `<div id="out">${LIST()}</div><div id="box"><p data-tv="S.open">closed</p><template data-tvt="S.open" data-i="1"><div data-tv="S.open"><b>open</b>${LIST()}</div></template></div>`,
    STATES,
  ),
  // Widgets after the rows, on the page and in a variant.
  '/footer': page(
    `<div id="out"><div id="a" data-tl="M.items" data-tlk="M.key"><h4>head</h4><li data-tk="x"><b data-tf="M.text">x</b></li><li data-tk="q"><b data-tf="M.text">q</b></li><template data-tlt="M.items"><li><b data-tf="M.text"></b></li></template><h5>foot</h5></div></div>
<div id="box"><p data-tv="S.open">closed</p><template data-tvt="S.open" data-i="1"><div data-tv="S.open"><div id="b" data-tl="M.items" data-tlk="M.key"><h4>head</h4><li data-tk="x"><b data-tf="M.text">x</b></li><li data-tk="q"><b data-tf="M.text">q</b></li><template data-tlt="M.items"><li><b data-tf="M.text"></b></li></template><h5>foot</h5></div></div></template></div>`,
    STATES,
  ),
};

const TPL = `<template data-tlt="M.items"><li><b data-tf="M.text"></b></li></template>`;
const LI = (k) => `<li data-tk="${k}"><b data-tf="M.text">${k}</b></li>`;
Object.assign(pages, {
  '/multi-root': page(
    `<div id="mr" style="display: contents" data-tl="M.items" data-tlk="M.key"><ul id="m1">${LI('x')}${LI('q')}${TPL}</ul><ol id="m2" style="display:none">${LI('x')}${LI('q')}${TPL}</ol></div><p id="after">after</p>`,
    STATES,
  ),
  '/inner': page(
    `<div id="o" data-tl="M.items" data-tlk="M.key"><h4>head</h4><div class="car"><div class="track">${LI('x')}${LI('q')}${TPL}</div><span class="arrow">next</span></div><h5>foot</h5></div>`,
    STATES,
  ),
  // One state, every binding twice: the copies are in the page one after the other.
  '/copies': page(
    `<div class="c1"><u data-tt="C.label">L0</u><i data-tv="C.mode">a</i><template data-tvt="C.mode" data-i="1"><i data-tv="C.mode">b</i></template><ul data-tl="M.items" data-tlk="M.key">${LI('x')}${LI('q')}${TPL}</ul></div>
<div class="c2" style="display:none"><u data-tt="C.label">L0</u><i data-tv="C.mode">a</i><template data-tvt="C.mode" data-i="1"><i data-tv="C.mode">b</i></template><ul data-tl="M.items" data-tlk="M.key">${LI('x')}${LI('q')}${TPL}</ul></div>`,
    `${STATES}
thor.def('C', ($) => { const l = $.state('label', 'L0'), m = $.state('mode', 0); return { label: () => l.value, mode: () => m.value, setLabel: (v) => { l.value = v; }, setMode: (v) => { m.value = +v; } }; }, { eager: true });`,
  ),
});

pages['/miss'] = page(
  `<p id="a" data-tv="S.open">closed</p><p id="b" data-tv="S.open" data-tp-1="|#|=open">closed</p><p id="c" data-tv="S.open">closed</p><template data-tvt="S.open" data-i="1"><p data-tv="S.open">open</p></template>`,
  `${STATES}
window.misses = [];
thor.miss = (el, n) => window.misses.push(el.id + ':' + n);`,
);

const OSTATE = `thor.def('O', ($) => {
  const lab = $.state('lab', 'L0'), mode = $.state('mode', 0), calls = { l: 0, m: 0 };
  return {
    label: () => (calls.l++, lab.value), mode: () => (calls.m++, mode.value), calls: () => calls.l + ',' + calls.m,
    setLabel: (v) => { lab.value = v; }, setMode: (v) => { mode.value = +v; },
  };
}, { eager: EAGER });
thor.def('N', ($) => {
  const it = $.state('items', ['n1', 'n2']);
  return { items: () => it.value, key: (i) => i, text: (i) => i, set: (s) => { it.value = s ? s.split(',') : []; } };
}, { eager: true });`;
const ROW = (k, extra) => `<li data-tk="${k}"><b data-tf="M.text">${k}</b>${extra}</li>`;
const TROW = (extra) => `<li><b data-tf="M.text"></b>${extra}</li>`;
const OROW = `<u data-tt="O.label">L0</u><i data-tv="O.mode">a</i><template data-tvt="O.mode" data-i="1"><i data-tv="O.mode">b</i></template>`;
const NLIST = `<ul data-tl="N.items" data-tlk="N.key"><li data-tk="n1"><b data-tf="N.text">n1</b><u data-tt="O.label">L0</u></li><li data-tk="n2"><b data-tf="N.text">n2</b><u data-tt="O.label">L0</u></li><template data-tlt="N.items"><li><b data-tf="N.text"></b><u data-tt="O.label">L0</u></li></template></ul>`;
const NROW = `<div data-tv="O.mode"><span>-</span></div><template data-tvt="O.mode" data-i="1"><div data-tv="O.mode">${NLIST}</div></template>`;
const OLIST = (extra) => `<ul class="l" data-tl="M.items" data-tlk="M.key">${ROW('x', extra)}${ROW('q', extra)}<template data-tlt="M.items">${TROW(extra)}</template></ul>`;
const OPAGE = (extra, eager = true) => page(OLIST(extra), `${STATES}\n${OSTATE.replace('EAGER', eager)}`);

Object.assign(pages, {
  '/rows': OPAGE(OROW),
  '/rows-lazy': OPAGE(OROW, false),
  '/nested': OPAGE(NROW),
});

const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail !== '' ? ` (${detail})` : ''}`);
};

const browser = await chromium.launch();
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
  await p.waitForFunction(() => typeof thor !== 'undefined' && thor.use);
  await frames(p); // the first pass and frame
  return p;
};
const set = async (p, s) => {
  await p.evaluate((s) => thor.use('M').set(s), s);
  await frames(p);
};
const toggle = (p, n = 1) => p.evaluate((n) => { for (let i = 0; i < n; i++) thor.use('S').toggle(); }, n);
const rows = (p, sel) => p.evaluate((sel) => [...document.querySelectorAll(`${sel} [data-tk]`)].map((r) => r.innerText.replace(/\s+/g, '')).join(), sel);

try {
  {
    const p = await open('/variant');
    await toggle(p);
    await frames(p);
    check('variant list: the variant\'s list shows the items', (await rows(p, '#box')) === 'x.,q*', await rows(p, '#box'));
    await set(p, 'x,q,y');
    check('variant list: it follows the items', (await rows(p, '#box')) === 'x.,q*,y.', await rows(p, '#box'));
    check('variant list: the one outside too', (await rows(p, '#out')) === 'x.,q*,y.', await rows(p, '#out'));
    await set(p, 'q9,y,x');
    check('variant list: its row states follow (a row that came new)', (await rows(p, '#box')) === 'q9*,y.,x.', await rows(p, '#box'));
    await toggle(p, 100); // open again (an odd count in all)
    await frames(p);
    await set(p, 'a,q');
    check('variant list: after 101 toggles in all, still in step', (await rows(p, '#box')) === 'a.,q*', await rows(p, '#box'));
    check('variant list: exactly one list in the variant', (await p.locator('#box ul').count()) === 1);
    await toggle(p);
    await set(p, 'z');
    check('variant list: closed: the outside list still follows', (await rows(p, '#out')) === 'z.', await rows(p, '#out'));
    check('variant list: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }
  {
    const p = await open('/footer');
    const text = (id) => p.evaluate((id) => document.getElementById(id).innerText.replace(/\s+/g, ' ').trim(), id);
    check('footer container: the marker stays on the container', (await p.locator('#a[data-tl]').count()) === 1);
    await set(p, 'x,q,n');
    check('footer container: a row goes before the footer', (await text('a')) === 'head x q n foot', await text('a'));
    await set(p, 'n,q,x');
    check('footer container: reordered', (await text('a')) === 'head n q x foot', await text('a'));
    await set(p, 'q');
    check('footer container: removed', (await text('a')) === 'head q foot', await text('a'));
    await set(p, '');
    check('footer container: emptied: head and foot stay', (await text('a')) === 'head foot', await text('a'));
    await set(p, 'k,l');
    check('footer container: filled again', (await text('a')) === 'head k l foot', await text('a'));
    await toggle(p);
    await frames(p);
    check('footer container: in a variant: the footer list follows too', (await text('b')) === 'head k l foot', await text('b'));
    await set(p, 'm');
    check('footer container: and its changes', (await text('b')) === 'head m foot' && (await text('a')) === 'head m foot', `${await text('b')} | ${await text('a')}`);
    check('footer container: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }
  {
    const p = await open('/multi-root');
    const list = (id) => p.evaluate((id) => [...document.querySelectorAll(`#${id} > [data-tk]`)].map((r) => r.textContent).join(), id);
    check('two-root container: the marker is on the box only', (await p.locator('[data-tl]').count()) === 2 && (await p.locator('#mr[data-tl]').count()) === 0, await p.locator('[data-tl]').count());
    await set(p, 'x,q,n');
    check('two-root container: a row added to both lists', (await list('m1')) === 'x,q,n' && (await list('m2')) === 'x,q,n', `${await list('m1')} | ${await list('m2')}`);
    await set(p, 'n,x');
    check('two-root container: moved and removed in both', (await list('m1')) === 'n,x' && (await list('m2')) === 'n,x', `${await list('m1')} | ${await list('m2')}`);
    check('two-root container: nothing went into the box itself', (await p.locator('#mr > [data-tk]').count()) === 0);
    check('two-root container: the box has two lists, nothing else', (await p.locator('#mr > ul, #mr > ol').count()) === 2 && (await p.locator('#mr > template').count()) === 0);
    await set(p, '');
    check('two-root container: emptied', (await list('m1')) === '' && (await list('m2')) === '');
    check('two-root container: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }
  {
    const p = await open('/inner');
    const text = () => p.evaluate(() => document.getElementById('o').innerText.replace(/\s+/g, ' ').trim());
    const track = () => p.evaluate(() => [...document.querySelectorAll('.track > [data-tk]')].map((r) => r.textContent).join());
    await set(p, 'x,q,n,m');
    check('carousel container: new rows go into the carousel, not the Column', (await track()) === 'x,q,n,m' && (await p.locator('#o > [data-tk]').count()) === 0, await track());
    check('carousel container: head, arrow and foot keep their place', (await text()) === 'head x q n m next foot', await text());
    await set(p, 'm');
    check('carousel container: removed', (await track()) === 'm', await track());
    check('carousel container: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }
  {
    const p = await open('/copies');
    const C = (f, v) => p.evaluate(([f, v]) => thor.use('C')[f](v), [f, v]);
    const read = (c) => p.evaluate((c) => document.querySelector(`.${c}`).innerText.replace(/\s+/g, '') || document.querySelector(`.${c}`).textContent.replace(/\s+/g, ''), c);
    const rowsOf = (c) => p.evaluate((c) => [...document.querySelectorAll(`.${c} [data-tk]`)].map((r) => r.textContent).join(), c);
    await C('setLabel', 'L1');
    await C('setMode', 1);
    await set(p, 'x,q,n');
    const both = async (f) => (await f('c1')) === (await f('c2'));
    check('drawn twice: the text follows in both copies', (await p.evaluate(() => [...document.querySelectorAll('u')].map((u) => u.textContent).join())) === 'L1,L1');
    check('drawn twice: the state follows in both copies', (await p.evaluate(() => [...document.querySelectorAll('i')].map((u) => u.textContent).join())) === 'b,b');
    check('drawn twice: the list follows in both copies', (await rowsOf('c1')) === 'x,q,n' && (await both(rowsOf)), `${await rowsOf('c1')} | ${await rowsOf('c2')}`);
    await C('setMode', 0);
    await set(p, 'q');
    await C('setLabel', 'L2');
    check('drawn twice: and back, and shorter', (await p.evaluate(() => [...document.querySelectorAll('i')].map((u) => u.textContent).join())) === 'a,a' && (await rowsOf('c1')) === 'q' && (await rowsOf('c2')) === 'q' && (await p.evaluate(() => [...document.querySelectorAll('u')].map((u) => u.textContent).join())) === 'L2,L2');
    check('drawn twice: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }
  {
    // `a` has nothing for state 1; `b` has its patch.
    const p = await open('/miss');
    await toggle(p);
    await frames(p);
    const misses = await p.evaluate(() => window.misses);
    check('undrawn state: a state the server did not draw is reported', misses.includes('a:1'), misses.join());
    check('undrawn state: a state it did draw (a patch) is not', !misses.includes('b:1'), misses.join());
    check('undrawn state: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }
  for (const path of ['/rows', '/rows-lazy']) {
    const t = path === '/rows' ? 'other state in rows:' : 'other state in rows (O wakes late):';
    const p = await open(path);
    const O = (f, v) => p.evaluate(([f, v]) => thor.use('O')[f](v), [f, v]);
    const all = () => rows(p, '.l');
    await set(p, 'x,q,y,z');
    if (path === '/rows') check(`${t} rows added after load start as the page shows`, (await all()) === 'xL0a,qL0a,yL0a,zL0a', await all());
    await O('setLabel', 'L1');
    await frames(p);
    check(`${t} a text of another state follows in every row`, (await all()) === 'xL1a,qL1a,yL1a,zL1a', await all());
    await O('setMode', 1);
    await frames(p);
    check(`${t} a variants Watch of another state follows in every row`, (await all()) === 'xL1b,qL1b,yL1b,zL1b', await all());
    await set(p, 'x,y,w,z,v');
    check(`${t} rows that come after the state changed show its value`, (await all()) === 'xL1b,yL1b,wL1b,zL1b,vL1b', await all());
    await O('setLabel', 'L2');
    await O('setMode', 0);
    await frames(p);
    check(`${t} and both keep following`, (await all()) === 'xL2a,yL2a,wL2a,zL2a,vL2a', await all());
    // Removed rows: not kept, and one effect per binding however many rows came and went.
    await p.evaluate(() => { window.gone = [...document.querySelectorAll('.l [data-tk]')]; });
    await set(p, '');
    for (let n = 0; n < 3; n++) {
      await set(p, Array.from({ length: 200 }, (_, i) => `r${i}`).join(','));
      await set(p, '');
    }
    await set(p, 'x');
    const before = await O('calls');
    await O('setLabel', 'L3');
    await O('setMode', 1);
    await frames(p);
    const [l0, m0] = before.split(','), [l1, m1] = (await O('calls')).split(',');
    check(`${t} one run per change however many rows came and went`, +l1 - +l0 === 1 && +m1 - +m0 === 1, `${before} -> ${await O('calls')}`);
    check(`${t} the row that is left follows`, (await all()) === 'xL3b', await all());
    check(`${t} a removed row is not written any more`, await p.evaluate(() => window.gone.every((r) => !r.isConnected && r.textContent.includes('L2') && !r.textContent.includes('L3'))));
    check(`${t} no page errors`, p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }
  {
    const p = await open('/nested');
    const O = (f, v) => p.evaluate(([f, v]) => thor.use('O')[f](v), [f, v]);
    const N = (v) => p.evaluate((v) => thor.use('N').set(v), v);
    const all = () => p.evaluate(() => [...document.querySelectorAll('.l > [data-tk]')].map((r) => r.querySelector('b').textContent + ':' + [...r.querySelectorAll('ul li')].map((n) => n.innerText.replace(/\s+/g, '')).join('/')).join());
    await set(p, 'x,q,y');
    await O('setMode', 1);
    await frames(p);
    check('nested rows: a list in a variant in a row, in old and new rows', (await all()) === 'x:n1L0/n2L0,q:n1L0/n2L0,y:n1L0/n2L0', await all());
    await O('setLabel', 'L1');
    await N('n1,n2,n3');
    await frames(p);
    check('nested rows: the nested rows follow their list and the other state', (await all()) === 'x:n1L1/n2L1/n3L1,q:n1L1/n2L1/n3L1,y:n1L1/n2L1/n3L1', await all());
    await set(p, 'y,z');
    await O('setMode', 0);
    await O('setMode', 1);
    await O('setLabel', 'L2');
    await N('n9');
    await frames(p);
    check('nested rows: rows that come later, variant toggled and back, no duplicates', (await all()) === 'y:n9L2,z:n9L2', await all());
    check('nested rows: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }
} catch (e) {
  check('no exception', false, e?.stack ?? String(e));
}
await browser.close();
const failed = results.filter((r) => !r).length;
console.log(failed ? `${failed} of ${results.length} failed` : `${results.length} passed`);
process.exit(failed ? 1 : 0);

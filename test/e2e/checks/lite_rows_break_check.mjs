// The bindings of OTHER states inside the rows the browser clones after load
// (data-tt texts, data-tv variants), broken on purpose: rows moved
// (moveBefore in Chromium, insertBefore in WebKit), into a top layer and out of
// the page, states that are disposed or keyed, thousands of rows in and out,
// nested lists, a row whose root is the variant. Pages made in memory from
// lib/lite/runtime.js and its parts.
//
//   node test/e2e/checks/lite_rows_break_check.mjs
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { chromium, firefox, webkit } from '../runner/node_modules/playwright/index.mjs';
import { browsersFor, frames, repo } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
// Keyed lists are the runtime's part `lists`, sewn in first (an older
// runtime, without that part next to it, has them inside).
const withLists = (src, at) => {
  const p = join(dirname(at), 'parts/lists.js');
  return src.replace('// @thor-lite-parts', () => `${existsSync(p) ? readFileSync(p, 'utf8') : ''}\n// @thor-lite-parts`);
};
const runtimePath = join(lite, 'runtime.js');
const runtime = withLists(readFileSync(runtimePath, 'utf8'), runtimePath);
const parts = ['row_states.js', 'lifecycle.js'].map((n) => readFileSync(join(lite, 'parts', n), 'utf8')).join('\n');
const page = (body, script) =>
  `<!DOCTYPE html><html><head><base href="/"></head><body>${body}<script>${runtime.replace('// @thor-lite-parts', () => parts)}\n${script}</script></body></html>`;

const STATES = `thor.def('M', ($) => {
  const it = $.state('items', ['x', 'q']);
  return { items: () => it.value, key: (i) => i, text: (i) => i, set: (s) => { it.value = s ? s.split(',') : []; } };
}, { eager: true });
thor.def('O', ($) => {
  const lab = $.state('lab', 'L0'), mode = $.state('mode', 0);
  window.calls = { l: 0, m: 0 };
  return {
    label: () => (calls.l++, lab.value), mode: () => (calls.m++, mode.value),
    setLabel: (v) => { lab.value = v; }, setMode: (v) => { mode.value = +v; },
  };
}, { eager: true });`;
const OROW = `<u data-tt="O.label">L0</u><i data-tv="O.mode">a</i><template data-tvt="O.mode" data-i="1"><i data-tv="O.mode">b</i></template>`;
const LIST = (extra) => `<ul class="l" data-tl="M.items" data-tlk="M.key"><li data-tk="x"><b data-tf="M.text">x</b>${extra}</li><li data-tk="q"><b data-tf="M.text">q</b>${extra}</li><template data-tlt="M.items"><li><b data-tf="M.text"></b>${extra}</li></template></ul>`;

// N: a list whose rows are made of another list's states (variant row root).
const pages = {
  '/base': page(`${LIST(OROW)}<dialog id="dlg"></dialog><template id="tpl"></template>`, STATES),
  // A container with head and foot, and the list also inside a variant.
  '/foot': page(
    `<div id="a" data-tl="M.items" data-tlk="M.key"><h4>head</h4><template data-tlt="M.items"><li data-tk="{{key}}"><b data-tf="M.text"></b><u data-tt="O.label">L0</u></li></template><h5>foot</h5></div><p data-tv="S.open">closed</p><template data-tvt="S.open" data-i="1"><section data-tv="S.open"><div id="b" data-tl="M.items" data-tlk="M.key"><template data-tlt="M.items"><li><b data-tf="M.text"></b><u data-tt="O.label">L0</u></li></template></div></section></template>`,
    `${STATES}
thor.def('S', ($) => { const open = $.state('open', false); return { open: () => open.value, toggle: () => { open.value = !open.value; } }; }, { eager: true });`,
  ),
  // The state starts at 1: rows and template are drawn as 1, the patch is for 0.
  '/init1': page(
    `<ul class="l" data-tl="M.items" data-tlk="M.key"><li data-tk="x"><b data-tf="M.text">x</b><i class="one" data-tv="O.mode" data-tp-0="|class|=zero">.</i></li><template data-tlt="M.items"><li><b data-tf="M.text"></b><i class="one" data-tv="O.mode" data-tp-0="|class|=zero">.</i></li></template></ul>`,
    STATES.replace("$.state('mode', 0)", "$.state('mode', 1)"),
  ),
  // row -> variant of O -> list N -> row -> text of O.
  '/deep': page(
    `<ul class="l" data-tl="M.items" data-tlk="M.key"><template data-tlt="M.items"><li><b data-tf="M.text"></b><div data-tv="O.mode"><span>-</span></div><template data-tvt="O.mode" data-i="1"><div data-tv="O.mode"><ul class="n" data-tl="N.items" data-tlk="N.key"><template data-tlt="N.items"><li><b data-tf="N.text"></b><u data-tt="O.label">L0</u></li></template></ul></div></template></li></template></ul>`,
    `${STATES}
thor.def('N', ($) => { const it = $.state('items', ['n1']); return { items: () => it.value, key: (i) => i, text: (i) => i, set: (s) => { it.value = s ? s.split(',') : []; } }; }, { eager: true });`,
  ),
  // row -> list N (with rows of its own), the rows added after load.
  '/inner': page(
    `<ul class="l" data-tl="M.items" data-tlk="M.key"><template data-tlt="M.items"><li><b data-tf="M.text"></b><ol class="n" data-tl="N.items" data-tlk="N.key"><template data-tlt="N.items"><li><b data-tf="N.text"></b><u data-tt="O.label">L0</u></li></template></ol></li></template></ul>`,
    `${STATES}
thor.def('N', ($) => { const it = $.state('items', ['n1', 'n2']); return { items: () => it.value, key: (i) => i, text: (i) => i, set: (s) => { it.value = s ? s.split(',') : []; } }; }, { eager: true });`,
  ),
  // The row's root is the binding (a text, a variant of patches: a structure
  // cannot be a row's root, its templates would be siblings of the row).
  '/root': page(
    `<ul class="l" data-tl="M.items" data-tlk="M.key"><template data-tlt="M.items"><li class="off" data-tv="O.mode" data-tp-1="|class|=on"><b data-tf="M.text"></b></li></template></ul><ol class="l" data-tl="M.items" data-tlk="M.key"><template data-tlt="M.items"><li data-tt="O.label">-</li></template></ol>`,
    STATES,
  ),
  // Keyed states: Row#<key>.label, awake by an event before its rows come.
  '/keyed': page(
    `<ul class="l" data-tl="M.items" data-tlk="M.key"><template data-tlt="M.items"><li><b data-tf="M.text"></b><u data-tt="Row#{{key}}.label">-</u><a href="#{{key}}.notes">n</a></li></template></ul>`,
    `${STATES}
thor.def('Row', ($) => { const n = $.state('n', 0); return { label: () => $.key + ':' + n.value, bump: () => { n.value++; } }; });`,
  ),
  // A state with dispose that the rows name; another one, with dispose only.
  '/dispose': page(
    `${LIST('<u data-tt="D.label">d0</u>')}`,
    `${STATES}
window.log = [];
thor.def('D', ($) => { const n = $.state('n', 0); return { label: () => 'd' + n.value, bump: () => { n.value++; }, $l: { d: () => log.push('D') } }; });`,
  ),
  // O wakes in the middle of the list's own update (a field getter uses it).
  '/lazy': page(
    `<ul class="l" data-tl="M.items" data-tlk="M.key"><template data-tlt="M.items"><li><b data-tf="M.text"></b><u data-tt="O.label">L0</u></li></template></ul>`,
    `thor.def('M', ($) => {
  const it = $.state('items', []);
  return { items: () => it.value, key: (i) => i, text: (i) => (i === 'w' ? $.use('O').label() : i), set: (s) => { it.value = s ? s.split(',') : []; } };
}, { eager: true });
thor.def('O', ($) => { const lab = $.state('lab', 'L0'); return { label: () => lab.value, setLabel: (v) => { lab.value = v; } }; });`,
  ),
};

const results = [];
let tag = '';
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} ${tag}${label}${detail !== '' ? ` (${detail})` : ''}`);
};

const open = async (browser, path) => {
  const ctx = await browser.newContext();
  const p = await ctx.newPage();
  p.problems = [];
  p.on('pageerror', (e) => p.problems.push(e.message));
  p.on('console', (m) => m.type() === 'error' && p.problems.push(m.text()));
  await ctx.route('http://lite.test/**', (r) => {
    const body = pages[new URL(r.request().url()).pathname];
    return body ? r.fulfill({ contentType: 'text/html; charset=utf-8', body }) : r.fulfill({ status: 404, body: '' });
  });
  await p.goto(`http://lite.test${path}`);
  await p.waitForFunction(() => typeof thor !== 'undefined' && thor.use);
  await frames(p);
  return p;
};
const set = async (p, s) => {
  await p.evaluate((s) => thor.use('M').set(s), s);
  await frames(p);
};
const O = (p, f, v) => p.evaluate(([f, v]) => thor.use('O')[f](v), [f, v]);
const rows = (p) => p.evaluate(() => [...document.querySelectorAll('.l > [data-tk]')].map((r) => r.innerText.replace(/\s+/g, '')).join());
const uniq = (n) => Array.from({ length: n }, (_, i) => `r${i}`);

async function run(name, type) {
  tag = `${name} `;
  const browser = await type.launch({ args: name === 'chromium' ? ['--js-flags=--expose-gc'] : [] });
  try {
    // Rows moved: reversed and shuffled many times, other state changes between.
    {
      const p = await open(browser, '/base');
      await set(p, 'a,b,c,d,e');
      const ids = ['a,b,c,d,e', 'e,d,c,b,a', 'c,a,e,b,d', 'b,c,d,e,a', 'a,e,b,d,c'];
      for (let i = 0; i < 25; i++) {
        await set(p, ids[i % 5]);
        await O(p, 'setLabel', `L${i}`);
        await O(p, 'setMode', i % 2);
        await frames(p);
      }
      const want = ids[24 % 5].split(',').map((k) => `${k}L24${24 % 2 ? 'b' : 'a'}`).join();
      check('moved rows: moved rows still follow the other state (25 shuffles)', (await rows(p)) === want, `${await rows(p)} vs ${want}`);
      // 300 rows in a shuffle, so the compaction runs while rows move.
      const ks = uniq(300);
      await set(p, ks.join());
      await set(p, [...ks].reverse().join());
      await O(p, 'setLabel', 'Z');
      await frames(p);
      const all = await p.evaluate(() => [...document.querySelectorAll('.l > [data-tk] u')].every((u) => u.textContent === 'Z'));
      check('moved rows: 300 rows reversed: every text follows', all);
      const k2 = [...ks.slice(150), ...ks.slice(0, 150)];
      for (let i = 0; i < 5; i++) {
        await set(p, uniq(400).slice(i * 20).concat(k2.slice(0, 50)).join());
        await O(p, 'setLabel', `Y${i}`);
      }
      await frames(p);
      const all2 = await p.evaluate(() => [...document.querySelectorAll('.l > [data-tk] u')].every((u) => u.textContent === 'Y4'));
      check('moved rows: churn with moves and compactions: every text follows', all2);
      check('moved rows: no errors', p.problems.length === 0, p.problems.join(' | '));
      await p.close();
    }
    // Top layer and out of the page and back.
    {
      const p = await open(browser, '/base');
      await set(p, 'a,b');
      await p.evaluate(() => {
        const dlg = document.getElementById('dlg');
        dlg.showModal();
        dlg.append(document.querySelector('[data-tk=a]'));
      });
      await O(p, 'setLabel', 'T1');
      await O(p, 'setMode', 1);
      await frames(p);
      check('top layer: a row moved into a modal dialog follows', await p.evaluate(() => document.getElementById('dlg').innerText.replace(/\s+/g, '') === 'aT1b'), await p.evaluate(() => document.getElementById('dlg').innerText));
      // out of the page and back in the same task (a sort by code, a portal)
      await p.evaluate(() => {
        const r = document.querySelector('.l > [data-tk=b]'), ul = r.parentNode;
        r.remove();
        ul.insertBefore(r, ul.firstChild);
      });
      await O(p, 'setLabel', 'T2');
      await frames(p);
      check('top layer: a row removed and inserted in the same task follows', await p.evaluate(() => document.querySelector('.l > [data-tk=b] u').textContent === 'T2'));
      check('top layer: no errors', p.problems.length === 0, p.problems.join(' | '));
      await p.close();
    }
    // The row's root is the binding.
    {
      const p = await open(browser, '/root');
      await set(p, 'x,y');
      await O(p, 'setMode', 1);
      await O(p, 'setLabel', 'T');
      await frames(p);
      const t = () => p.evaluate(() => [...document.querySelectorAll('ul.l > li')].map((r) => r.className).join() + '|' + [...document.querySelectorAll('ol.l > li')].map((r) => r.textContent).join());
      check('row root: a row whose root is a patch variant / a text follows', (await t()) === 'on,on|T,T', await t());
      await set(p, 'x,y,z');
      await O(p, 'setMode', 0);
      await frames(p);
      check('row root: and back, with a row added later', (await t()) === 'off,off,off|T,T,T', await t());
      await p.close();
    }
    // Keyed states.
    {
      const p = await open(browser, '/keyed');
      // Keys with `.`, `~` and `%`: the id carries them escaped (`Row#e%7Ef`).
      const id = (k) => `Row#${k.replace(/[%~;]/g, (c) => (c === '%' ? '%25' : c === ';' ? '%3B' : '%7E'))}`;
      await p.evaluate((ids) => { for (const i of ids) thor.use(i); }, ['a', 'b', 'c.d', 'e~f', '100%', 'g;h', 'i%7Ej'].map(id));
      await set(p, 'a,c.d,b,e~f,100%,g;h,i%7Ej');
      const t = () => p.evaluate(() => [...document.querySelectorAll('.l u')].map((u) => u.textContent).join());
      check('keyed states: each row binds to its own keyed instance', (await t()) === 'a:0,c.d:0,b:0,e~f:0,100%:0,g;h:0,i%7Ej:0', await t());
      await p.evaluate((ids) => { for (const i of ids) thor.use(i).bump(); }, ['a', 'c.d', 'c.d', 'e~f', '100%', '100%', 'g;h', 'i%7Ej', 'i%7Ej'].map(id));
      await frames(p);
      check('keyed states: keys with . ~ % follow only their instance', (await t()) === 'a:1,c.d:2,b:0,e~f:1,100%:2,g;h:1,i%7Ej:2', await t());
      const hrefs = await p.evaluate(() => [...document.querySelectorAll('.l a')].map((a) => a.getAttribute('href')).join());
      check('keyed states: an anchor #{{key}}.notes keeps the raw key', hrefs === '#a.notes,#c.d.notes,#b.notes,#e~f.notes,#100%.notes,#g;h.notes,#i%7Ej.notes', hrefs);
      await p.close();
    }
    // Dispose.
    {
      const p = await open(browser, '/dispose');
      await set(p, 'a,b');
      await p.evaluate(() => thor.use('D'));
      await set(p, 'c,d,e');
      await p.evaluate(() => thor.use('D').bump());
      await frames(p);
      const t = () => p.evaluate(() => [...document.querySelectorAll('.l u')].map((u) => u.textContent).join());
      check('dispose: a state with dispose: rows added later follow', (await t()) === 'd1,d1,d1', await t());
      await set(p, '');
      await frames(p);
      check('dispose: the last row leaves: the state ends once', (await p.evaluate(() => log.join())) === 'D', await p.evaluate(() => log.join()));
      await set(p, 'g,h');
      await p.evaluate(() => thor.use('D').bump());
      await frames(p);
      check('dispose: rows that come after the end follow the new instance', (await t()) === 'd1,d1', await t());
      check('dispose: no errors', p.problems.length === 0, p.problems.join(' | '));
      await p.close();
    }
    // A state that wakes in the middle of the list's update.
    {
      const p = await open(browser, '/lazy');
      await set(p, 'w,y,z');
      await p.evaluate(() => thor.use('O').setLabel('K'));
      await frames(p);
      const t = await p.evaluate(() => [...document.querySelectorAll('.l u')].map((u) => u.textContent).join());
      check('late state: a state woken while its rows are made binds all of them', t === 'K,K,K', t);
      await p.close();
    }
    // Nested lists, every level adding rows after load, the variant toggled.
    {
      const p = await open(browser, '/deep');
      const N = (v) => p.evaluate((v) => thor.use('N').set(v), v);
      const t = () => p.evaluate(() => [...document.querySelectorAll('.l > li')].map((r) => [...r.querySelectorAll('.n u')].map((u) => u.textContent).join('/')).join());
      await set(p, 'a,b');
      await O(p, 'setMode', 1);
      await frames(p);
      for (let i = 0; i < 12; i++) {
        await set(p, uniq(2 + (i % 3)).join());
        await N(uniq(1 + (i % 4)).join());
        await O(p, 'setLabel', `V${i}`);
        await O(p, 'setMode', i % 2 ? 1 : 0);
        await O(p, 'setMode', 1);
        await frames(p);
      }
      const inner = 1 + (11 % 4), outer = 2 + (11 % 3);
      const want = Array.from({ length: outer }, () => Array.from({ length: inner }, () => 'V11').join('/')).join();
      check('nested lists: nested rows of every level follow the other state', (await t()) === want, `${await t()} vs ${want}`);
      const before = await p.evaluate(() => calls.l);
      await O(p, 'setLabel', 'END');
      await frames(p);
      check('nested lists: one getter run per change (no double binding)', (await p.evaluate(() => calls.l)) - before === 1, `${before} -> ${await p.evaluate(() => calls.l)}`);
      check('nested lists: no errors', p.problems.length === 0, p.problems.join(' | '));
      await p.close();
    }
    // A list inside a row, rows added after load.
    {
      const p = await open(browser, '/inner');
      const N = (v) => p.evaluate((v) => thor.use('N').set(v), v);
      const t = () => p.evaluate(() => [...document.querySelectorAll('.l > li')].map((r) => [...r.querySelectorAll('.n li')].map((u) => u.textContent).join('/')).join());
      await set(p, 'a,b');
      await O(p, 'setLabel', 'I1');
      await N('n1,n2,n3');
      await set(p, 'a,b,c');
      await frames(p);
      check('list in a row: the list of a row that came after load has its rows and follows', (await t()) === 'n1I1/n2I1/n3I1,n1I1/n2I1/n3I1,n1I1/n2I1/n3I1', await t());
      await p.close();
    }
    // The other state starts at another index than 0.
    {
      const p = await open(browser, '/init1');
      const t = () => p.evaluate(() => [...document.querySelectorAll('.l i')].map((i) => i.className).join());
      await set(p, 'x,y,z');
      check('start index: rows added while the state is at 1 look like 1', (await t()) === 'one,one,one', await t());
      await O(p, 'setMode', 0);
      await set(p, 'x,y,z,w');
      await frames(p);
      check('start index: at 0, old and new rows look like 0', (await t()) === 'zero,zero,zero,zero', await t());
      await O(p, 'setMode', 1);
      await frames(p);
      check('start index: and back', (await t()) === 'one,one,one,one', await t());
      await p.close();
    }
    // A container with head and foot, and the list inside a variant.
    {
      const p = await open(browser, '/foot');
      const t = (id) => p.evaluate((id) => document.getElementById(id)?.innerText.replace(/\s+/g, ' ').trim(), id);
      await set(p, 'x,y');
      await O(p, 'setLabel', 'A');
      await p.evaluate(() => thor.use('S').toggle());
      await frames(p);
      await set(p, 'y,z,x');
      await O(p, 'setLabel', 'B');
      await frames(p);
      check('head and foot: head, rows with another state, foot', (await t('a')) === 'head yB zB xB foot', await t('a'));
      check('head and foot: the same in the variant', (await t('b')) === 'yB zB xB', await t('b'));
      await p.close();
    }
    // Memory and time: rows in and out by thousands.
    if (name === 'chromium') {
      const p = await open(browser, '/base');
      await p.evaluate(() => { window.refs = []; });
      const t0 = Date.now();
      const N = 10000, B = 500;
      for (let n = 0; n < N; n += B) {
        await p.evaluate(([n, B]) => {
          const ks = Array.from({ length: B }, (_, i) => `k${n + i}`);
          thor.use('M').set(ks.join());
        }, [n, B]);
        await p.evaluate(() => {
          for (const r of document.querySelectorAll('.l > [data-tk]')) {
            r.big = new Array(2000).fill(1);
            window.refs.push(new WeakRef(r));
          }
        });
        await frames(p);
      }
      await set(p, 'x');
      await O(p, 'setLabel', 'F');
      await frames(p);
      await p.evaluate(async () => { for (let i = 0; i < 4; i++) { gc(); await new Promise((r) => setTimeout(r, 30)); } });
      const alive = await p.evaluate(() => refs.filter((r) => r.deref()).length);
      check('memory: 10k rows in and out: the removed are collectable', alive < 1500, `alive ${alive} of ${await p.evaluate(() => refs.length)}, ${Date.now() - t0} ms`);
      await p.close();
    }
    // Rows with a list inside, in and out: the containers of the rows gone are not kept.
    if (name === 'chromium') {
      const p = await open(browser, '/inner');
      await p.evaluate(() => { window.refs = []; });
      for (let n = 0; n < 2000; n += 200) {
        await p.evaluate((n) => thor.use('M').set(Array.from({ length: 200 }, (_, i) => `k${n + i}`).join()), n);
        await p.evaluate(() => { for (const r of document.querySelectorAll('.l > li')) { r.big = new Array(2000).fill(1); refs.push(new WeakRef(r)); } });
        await frames(p);
      }
      await set(p, 'x');
      await p.evaluate(() => thor.use('N').set('a,b'));
      await frames(p);
      await p.evaluate(async () => { for (let i = 0; i < 4; i++) { gc(); await new Promise((r) => setTimeout(r, 30)); } });
      const alive = await p.evaluate(() => refs.filter((r) => r.deref()).length);
      check('row lists memory: rows with a list inside: the removed are collectable', alive < 300, `alive ${alive} of 2000`);
      await p.close();
    }
    // Time of one big add (the includes in addText).
    if (name === 'chromium') {
      const p = await open(browser, '/base');
      const ms = await p.evaluate(() => {
        const t = performance.now();
        thor.use('M').set(Array.from({ length: 10000 }, (_, i) => `k${i}`).join());
        return performance.now() - t;
      });
      await frames(p);
      check('big add: 10k rows at once in linear time', ms < 1500, `${Math.round(ms)} ms`);
      await p.close();
    }
  } finally {
    await browser.close();
  }
}

try {
  for (const [name, type] of browsersFor([['chromium', chromium], ['webkit', webkit], ['firefox', firefox]])) await run(name, type);
} catch (e) {
  check('no exception', false, e?.stack ?? String(e));
}
const failed = results.filter((r) => !r).length;
console.log(failed ? `${failed} of ${results.length} failed` : `${results.length} passed`);
process.exit(failed ? 1 : 0);

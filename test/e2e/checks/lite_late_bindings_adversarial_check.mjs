// Adversarial pass over the late bindings of the lite engine: the pairs of
// WatchVariables / WatchAttributes (`variables.js`: one effect per pair, one
// observer, release on the next fire plus a sweep) and the views of a late
// part (`scroll_controller.js`, `page_view.js`). Pages made in memory from
// lib/lite/runtime.js and its parts; Chromium, or the browser `E2E_BROWSER`
// names (tool/thor e2e --browsers).
//
//   node test/e2e/checks/lite_late_bindings_adversarial_check.mjs
//
// - an observer with nothing to do: 10,000 unrelated nodes cost no pair work
// - a list of 2,000 rows re-rendered 50 times: the time stays bounded, no pair is left behind
// - an element moved, detached and put back, a pair nobody fires again is swept
// - odd names and arguments
// - the same pair in two late parts, a late part inside a late part
// - a method that throws: reported, and not a binding more each time its element is put in the page
// - no observer where the part is not in the bundle
// - a view a late part brings that is already scrolled is not a change
// - a copy in place of a PageView
// - a scroll view and a PageView that arrive hidden start from their initial offset / page when they get a size
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
const part = (n) => readFileSync(n.includes('/') ? n : join(lite, 'parts', n), 'utf8');
const bundle = (names) => runtime.replace('// @thor-lite-parts', () => names.map(part).join('\n'));

// Counts what the observer does: its callbacks' time and the reads of the two
// attributes a pair lives in (no pair work: no read).
const SPY = `window.__o = { ms: 0, calls: 0, records: 0, made: 0, reads: 0 };
{
  const MO = window.MutationObserver;
  window.MutationObserver = class extends MO {
    constructor(cb) {
      __o.made++;
      super((rs, o) => { const t = performance.now(); try { cb(rs, o); } finally { __o.ms += performance.now() - t; __o.calls++; __o.records += rs.length; } });
    }
  };
  const ga = Element.prototype.getAttribute;
  Element.prototype.getAttribute = function (n) { if (n === 'data-tcv' || n === 'data-tca') __o.reads++; return ga.call(this, n); };
}`;

const STATE = `thor.def('V', ($) => {
  const m = $.state('m', 2), it = $.state('items', []);
  window.m = m;
  window.subs = () => { let n = 0; for (let l = m.sh; l; l = l.q) n++; return n; };
  return {
    items: () => it.value, key: (i) => i, title: (i) => i,
    w: (k) => Number(k) * m.value,
    bad: (k) => { const v = m.value; if (k === 'bad') throw Error('bad pair ' + v); return v; }, lab: (k) => 'L' + k + ':' + m.value,
    set: (s) => { it.value = s === '' ? [] : s.split(','); },
  };
}, { eager: true });
window.late = (html, into) => {
  const h = into ? document.querySelector(into) : document.getElementById('host');
  const before = h.children.length;
  h.insertAdjacentHTML('beforeend', html);
  document.documentElement.dispatchEvent(new CustomEvent('thor:stream', { detail: { nodes: [...h.children].slice(before) } }));
};`;

const varsPage = (names = ['attributes.js', 'variables.js']) =>
  `<!DOCTYPE html><html><head><base href="/"></head><body>
<ul id="l" data-tl="V.items" data-tlk="V.key"><template data-tlt="V.items"><li data-tf="V.title" data-tcv="--r:V.w~{{key}}" data-tca="aria-label:V.lab~{{key}}"></li></template></ul>
<div id="a"></div><div id="b"></div><div id="host"></div><div id="bulk"></div>
<script>${SPY}</script><script>${bundle(names)}\n${STATE}</script></body></html>`;

const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail !== '' ? ` (${detail})` : ''}`);
};
const info = (label) => console.log(`INFO ${label}`);

const name = process.env.E2E_BROWSER ?? 'chromium';
const browser = await { chromium, firefox, webkit }[name].launch();
const open = async (html) => {
  const ctx = await browser.newContext();
  const p = await ctx.newPage();
  p.problems = [];
  p.on('pageerror', (e) => p.problems.push(e.message));
  await ctx.route('http://lite.test/**', (r) => r.fulfill({ contentType: 'text/html', body: html }));
  await p.goto('http://lite.test/');
  await p.waitForFunction(() => typeof thor !== 'undefined' && thor.use);
  await frames(p);
  return p;
};
const css = (p, sel, n) => p.evaluate(([s, k]) => document.querySelector(s)?.style.getPropertyValue(k), [sel, n]);
const attr = (p, sel, n) => p.evaluate(([s, k]) => document.querySelector(s)?.getAttribute(k), [sel, n]);
const subs = (p) => p.evaluate(() => subs());
const setM = async (p, v) => {
  await p.evaluate((v) => (m.value = v), v);
  await frames(p);
};
const tick = (p) => p.evaluate(() => new Promise((r) => setTimeout(r, 30)));
const PAIR = (id, k) => `<div id="${id}" data-tcv="--w:V.w~${k}" data-tca="aria-label:V.lab~${k}"></div>`;

try {
  // Unrelated nodes.
  {
    const p = await open(varsPage());
    const r = await p.evaluate(async () => {
      const s0 = subs(), o0 = { ...__o };
      const c = document.getElementById('bulk');
      const t0 = performance.now();
      for (let i = 0; i < 10000; i++) {
        const d = document.createElement('div');
        d.innerHTML = '<span>x</span>';
        c.appendChild(d);
      }
      const sync = performance.now() - t0;
      await new Promise((r) => setTimeout(r, 50));
      return { sync, ms: __o.ms - o0.ms, calls: __o.calls - o0.calls, records: __o.records - o0.records, reads: __o.reads - o0.reads, ds: subs() - s0 };
    });
    info(`unrelated nodes: 10,000 divs appended one by one: ${r.sync.toFixed(1)} ms to build, observer ${r.ms.toFixed(1)} ms in ${r.calls} call(s) over ${r.records} records`);
    check('unrelated nodes: no pair work for unrelated nodes (no read of data-tcv / data-tca)', r.reads === 0, `${r.reads} reads`);
    check('unrelated nodes: and no binding made', r.ds === 0);
    check('unrelated nodes: the observer callback is cheap', r.ms < 400, `${r.ms.toFixed(1)} ms`);
    const q = await p.evaluate(async () => {
      const o0 = { ...__o };
      const f = document.createDocumentFragment();
      for (let i = 0; i < 10000; i++) f.appendChild(document.createElement('p'));
      document.getElementById('bulk').appendChild(f);
      // One deep chain: every node is a child of the last.
      let n = document.getElementById('bulk');
      for (let i = 0; i < 2000; i++) n = n.appendChild(document.createElement('i'));
      await new Promise((r) => setTimeout(r, 50));
      return { ms: __o.ms - o0.ms, reads: __o.reads - o0.reads };
    });
    info(`unrelated nodes: a fragment of 10,000 and a chain 2,000 deep: observer ${q.ms.toFixed(1)} ms`);
    check('unrelated nodes: a fragment and a chain: no reads, cheap', q.reads === 0 && q.ms < 400, `${q.reads} reads, ${q.ms.toFixed(1)} ms`);
    check('unrelated nodes: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.context().close();
  }

  // A list of 2,000 rows re-rendered 50 times.
  {
    const p = await open(varsPage());
    const run = await p.evaluate(async () => {
      const ids = (a, n) => Array.from({ length: n }, (_, i) => a + i).join(',');
      const V = thor.use('V');
      const out = { churn: 0, same: 0, obs: 0 };
      const o0 = __o.ms;
      let t = performance.now();
      V.set(ids(1, 2000));
      await new Promise((r) => setTimeout(r, 30));
      out.first = performance.now() - t;
      t = performance.now();
      for (let i = 0; i < 50; i++) {
        V.set(ids(1 + (i + 1) * 2000, 2000)); // every key new
        await new Promise((r) => setTimeout(r));
      }
      out.churn = performance.now() - t;
      const peak = subs();
      t = performance.now();
      for (let i = 0; i < 50; i++) {
        V.set(ids(1 + 51 * 2000, 2000)); // the same keys again: rows kept
        await new Promise((r) => setTimeout(r));
      }
      out.same = performance.now() - t;
      out.obs = __o.ms - o0;
      out.peak = peak;
      out.rows = document.querySelectorAll('#l > li').length;
      out.settled = subs();
      return out;
    });
    info(`list churn: 2,000 rows: first ${run.first.toFixed(0)} ms, 50 full renders ${run.churn.toFixed(0)} ms, 50 renders with the same keys ${run.same.toFixed(0)} ms (observer in all: ${run.obs.toFixed(0)} ms), subscribers after the churn ${run.peak}, rows ${run.rows}`);
    check('list churn: the rows are there', run.rows === 2000, `${run.rows}`);
    // Every row has 2 pairs: 4,000 live. Released ones must not pile up past the sweep's doubling.
    check('list churn: the churn leaves a bounded number of bindings', run.peak <= 2 * 4000 + 256 + 4000, `${run.peak}`);
    await setM(p, 3);
    const live = await subs(p);
    check('list churn: after the next change only the live bindings are left', live === 4000, `${live}`);
    check('list churn: a row follows', (await css(p, '[data-tk="102001"]', '--r')) === '306003px', await css(p, '[data-tk="102001"]', '--r'));
    check('list churn: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.context().close();
    // The cost of following the pairs of the rows, against the same list with no pair part (the old
    // `drop` scanned the state's list of effects: quadratic in the rows alive).
    const churn = (p) =>
      p.evaluate(async () => {
        const V = thor.use('V');
        const yieldTask = () => new Promise((r) => { const c = new MessageChannel(); c.port1.onmessage = r; c.port2.postMessage(0); });
        const keys = (a) => Array.from({ length: 2000 }, (_, i) => a + i).join(',');
        V.set(keys(0));
        await yieldTask();
        const t = performance.now();
        for (let i = 1; i <= 20; i++) {
          V.set(keys(i * 2000));
          await yieldTask();
        }
        return performance.now() - t;
      });
    const bare = await open(varsPage(['attributes.js']));
    const base = await churn(bare);
    await bare.context().close();
    const withPairs = await open(varsPage());
    const cost = await churn(withPairs);
    await withPairs.context().close();
    info(`list churn: 20 renders of 2,000 rows: ${base.toFixed(0)} ms with no pair part, ${cost.toFixed(0)} ms with it (x${(cost / base).toFixed(1)})`);
    check('list churn: following the pairs of the rows costs a bounded multiple of the list', cost < base * (name === 'chromium' ? 3.4 : 5), `x${(cost / base).toFixed(1)}`);
  }

  // Release correctness.
  {
    const p = await open(varsPage());
    await p.evaluate(([a, b]) => {
        late(a);
        late(b, '#b');
      },[PAIR('x', 1), PAIR('y', 1)]);
    await frames(p);
    const s0 = await subs(p);
    check('release: two elements, one pair: one binding', s0 === 2, `${s0}`); // w and lab
    // Moved, not removed.
    await p.evaluate(() => {
      const x = document.getElementById('x');
      document.getElementById('b').insertBefore(x, document.getElementById('y'));
      document.getElementById('a').appendChild(x);
      document.getElementById('host').insertBefore(x, null);
    });
    await setM(p, 3);
    check('release: a moved element stays bound', (await css(p, '#x', '--w')) === '3px' && (await attr(p, '#x', 'aria-label')) === 'L1:3');
    check('release: and no binding was added', (await subs(p)) === s0, `${await subs(p)}`);
    // Detached, the signal fires, put back.
    await p.evaluate(() => (window.det = document.getElementById('x')).remove());
    await setM(p, 4);
    check('release: y (still there) follows while x is detached', (await css(p, '#y', '--w')) === '4px');
    await p.evaluate(() => document.getElementById('a').appendChild(det));
    await frames(p);
    check('release: x put back after a fire gets the current value', (await css(p, '#x', '--w')) === '4px' && (await attr(p, '#x', 'aria-label')) === 'L1:4', await css(p, '#x', '--w'));
    await setM(p, 5);
    check('release: and keeps following', (await css(p, '#x', '--w')) === '5px');
    check('release: still one binding per pair', (await subs(p)) === s0, `${await subs(p)}`);
    // Every element of the pair gone, fire, put back later.
    await p.evaluate(() => {
      window.det = [document.getElementById('x'), document.getElementById('y')];
      det.forEach((e) => e.remove());
    });
    await setM(p, 6);
    check('release: with every element gone the bindings are released', (await subs(p)) === 0, `${await subs(p)}`);
    await p.evaluate(() => det.forEach((e) => document.getElementById('a').appendChild(e)));
    await frames(p);
    check('release: both put back later: bound again, current value', (await css(p, '#x', '--w')) === '6px' && (await css(p, '#y', '--w')) === '6px', `${await css(p, '#x', '--w')} ${await css(p, '#y', '--w')}`);
    await setM(p, 7);
    check('release: and following', (await css(p, '#x', '--w')) === '7px' && (await attr(p, '#y', 'aria-label')) === 'L1:7' && (await subs(p)) === s0);
    // Through a fragment, held while the signal fires.
    await p.evaluate(() => {
      const f = document.createDocumentFragment();
      f.appendChild(document.getElementById('x'));
      window.frag = f;
    });
    await setM(p, 8);
    await p.evaluate(() => document.getElementById('b').appendChild(frag));
    await frames(p);
    check('release: through a fragment: current value after the move', (await css(p, '#x', '--w')) === '8px', await css(p, '#x', '--w'));
    // Removed and re-added in one task (sort-like churn) while the signal fires between.
    await p.evaluate(() => {
      const x = document.getElementById('x');
      x.remove();
      m.value = 9;
      document.getElementById('a').appendChild(x);
    });
    await frames(p);
    check('release: removed, fired, re-added in one task', (await css(p, '#x', '--w')) === '9px' && (await attr(p, '#x', 'aria-label')) === 'L1:9', await css(p, '#x', '--w'));
    check('release: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.context().close();
  }
  {
    // 10,000 swaps of an element with its own pair, the signal never fires again.
    const p = await open(varsPage());
    const r = await p.evaluate(async () => {
      const V = thor.use('V');
      let peak = 0;
      const t = performance.now();
      for (let i = 0; i < 10000; i++) {
        const c = document.getElementById('bulk');
        c.innerHTML = '';
        const d = document.createElement('div');
        d.setAttribute('data-tcv', `--w:V.w~${i}`);
        d.setAttribute('data-tca', `aria-label:V.lab~${i}`);
        c.appendChild(d);
        if (i % 50 === 49) await new Promise((r) => setTimeout(r)); // the observer runs
        peak = Math.max(peak, subs());
      }
      await new Promise((r) => setTimeout(r, 30));
      return { peak, end: subs(), ms: performance.now() - t };
    });
    info(`release: 10,000 swaps, nobody fires: peak ${r.peak} subscribers, at the end ${r.end}, ${r.ms.toFixed(0)} ms`);
    // Live: 2 pairs. The sweep keeps at most ~2x the live count, 256 at least (x2 pairs per swap: 2 per element).
    check('release: 10,000 swaps: memory stays bounded (cap 256, doubling)', r.peak < 700 && r.end < 700, `${r.peak} / ${r.end}`);
    await setM(p, 5);
    check('release: after the next change only the live pair is left', (await subs(p)) === 2, `${await subs(p)}`);
    await p.context().close();
  }
  {
    // 10,000 live elements (cap doubles, no sweep storm) then all leave.
    const p = await open(varsPage());
    const r = await p.evaluate(async () => {
      const c = document.getElementById('bulk');
      let html = '';
      for (let i = 0; i < 10000; i++) html += `<i data-tcv="--w:V.w~${i}"></i>`;
      const t = performance.now();
      c.innerHTML = html;
      await new Promise((r) => setTimeout(r, 30));
      const up = performance.now() - t;
      const live = subs();
      c.innerHTML = '';
      const t2 = performance.now();
      m.value = 3;
      return { up, live, down: performance.now() - t2, end: subs() };
    });
    info(`release: 10,000 live pairs bound in ${r.up.toFixed(0)} ms; all leave and the signal fires in ${r.down.toFixed(0)} ms`);
    check('release: 10,000 live pairs are bound', r.live === 10000, `${r.live}`);
    check('release: and all released at the next fire', r.end === 0, `${r.end}`);
    await p.context().close();
  }

  // Odd names and arguments.
  {
    const p = await open(varsPage());
    await p.evaluate(() =>
      late(
        `<div id="n1" data-tcv="--a_b-C1:V.w~2;--x.y:V.w~2;--:V.w~2;-- sp:V.w~2;--ñ:V.w~2;--ok:V.w~2" data-tca="data-x-y:V.lab~a:b|c;aria-label:V.lab~ü ñ;data-x_y:V.lab~1;Data-X:V.lab~1;onclick:V.lab~1;href:V.lab~javascript:1;title:V.lab~;a|b:V.lab~1"></div>`,
      ),
    );
    await frames(p);
    const el = '#n1';
    check('odd names: a valid mixed-case name is written', (await css(p, el, '--a_b-C1')) === '4px', await css(p, el, '--a_b-C1'));
    check('odd names: dots, empty, spaces and non-ASCII names are not', (await css(p, el, '--x.y')) === '' && (await css(p, el, '--')) === '' && (await css(p, el, '--ñ')) === '');
    check('odd names: an argument with a colon and a pipe', (await attr(p, el, 'data-x-y')) === 'La:b|c:2', await attr(p, el, 'data-x-y'));
    check('odd names: an argument with spaces and non-ASCII', (await attr(p, el, 'aria-label')) === 'Lü ñ:2', await attr(p, el, 'aria-label'));
    check('odd names: names a binding may not write are not written', (await attr(p, el, 'data-x_y')) === null && (await attr(p, el, 'Data-X')) === null && (await attr(p, el, 'onclick')) === null);
    check('odd names: an unsafe URL is not written', (await attr(p, el, 'href')) === null);
    await setM(p, 3);
    check('odd names: the odd ones follow too', (await css(p, el, '--a_b-C1')) === '6px' && (await attr(p, el, 'data-x-y')) === 'La:b|c:3');
    check('odd names: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.context().close();
  }

  // The same pair in two late parts; a late part in a late part.
  {
    const p = await open(varsPage());
    await p.evaluate((h) => late(h), PAIR('p1', 5));
    const s1 = await subs(p);
    await p.evaluate((h) => late(h, '#b'), PAIR('p2', 5));
    await frames(p);
    check('two late parts: the same pair in a second late part joins the first binding', (await subs(p)) === s1 && s1 === 2, `${s1} -> ${await subs(p)}`);
    await setM(p, 4);
    check('two late parts: both follow', (await css(p, '#p1', '--w')) === '20px' && (await css(p, '#p2', '--w')) === '20px');
    // Nested: the second part lands inside the first and the stream names the nodes in both.
    await p.evaluate((h) => {
      late('<section id="outer"></section>');
      late(h, '#outer');
      document.documentElement.dispatchEvent(new CustomEvent('thor:stream', { detail: { nodes: [document.getElementById('outer')] } }));
    }, PAIR('p3', 5));
    await frames(p);
    check('two late parts: nested late parts, announced twice: still one binding', (await subs(p)) === s1, `${await subs(p)}`);
    await setM(p, 5);
    check('two late parts: the nested one follows', (await css(p, '#p3', '--w')) === '25px');
    // A late part that carries a pair of another, unknown state.
    await p.evaluate(() => late('<div id="u" data-tcv="--z:Nope.w~1" data-tca="aria-label:Nope.lab~1"></div>'));
    await frames(p);
    check('two late parts: a pair of a state that does not run binds nothing and fails nothing', (await subs(p)) === s1 && p.problems.length === 0, p.problems.join(' | '));
    await p.context().close();
  }

  // A method that throws.
  {
    const p = await open(varsPage());
    const r = await p.evaluate(async () => {
      const el = document.createElement('div');
      el.setAttribute('data-tcv', '--w:V.bad~bad');
      el.id = 'th';
      document.getElementById('a').appendChild(el);
      await new Promise((r) => setTimeout(r, 10));
      const s0 = subs();
      for (let i = 0; i < 50; i++) {
        document.getElementById('b').appendChild(el);
        document.getElementById('a').appendChild(el);
        await new Promise((r) => setTimeout(r, 0));
      }
      return { s0, s1: subs() };
    });
    info(`throwing method: a throwing pair moved 50 times: ${r.s0} -> ${r.s1} subscribers; page errors: ${p.problems.length}`);
    check('throwing method: a pair whose method throws is not bound again each time its element moves', r.s1 === r.s0 && r.s0 <= 1, `${r.s0} -> ${r.s1}`);
    check('throwing method: and the error is reported', p.problems.length > 0);
    await p.evaluate(() => late('<div id="t2" data-tcv="--w:V.bad~bad" style="--w:7px"></div>'));
    await frames(p);
    check('throwing method: an element that joins it keeps the value the server wrote', (await css(p, '#t2', '--w')) === '7px', await css(p, '#t2', '--w'));
    await p.context().close();
  }

  // No observer unless the part is in the bundle.
  {
    const p = await open(varsPage(['attributes.js']));
    const base = await p.evaluate(() => __o.made); // the runtime's own (toast)
    await p.context().close();
    const q = await open(varsPage());
    check('no part: the variables part adds exactly one MutationObserver, and only with it', (await q.evaluate(() => __o.made)) === base + 1, `${base} -> ${await q.evaluate(() => __o.made)}`);
    await q.context().close();
  }

  // Views of a late part.
  {
    const views = ['controllers.js', 'scroll_controller.js', 'page_controller.js', 'page_view.js'];
    const viewsPage = `<!DOCTYPE html><html><head><base href="/"></head><body><div id="host"></div><script>${bundle(views)}
thor.def('L', ($) => {
  const sc = thor.ctl.scroll('L.sc', 60), pg = thor.ctl.page('L.pg', 2), p2 = thor.ctl.page('L.p2', 0);
  window.went = [];
  Object.assign(window, { sc, pg, p2 });
  return { go: (v) => window.went.push(Number(v)), go2: (v) => window.went.push('b' + Number(v)) };
}, { eager: true });
window.stream = (html) => {
  const host = document.getElementById('host');
  host.insertAdjacentHTML('beforeend', html);
  document.documentElement.dispatchEvent(new CustomEvent('thor:stream', { detail: { nodes: [...host.children] } }));
};</script></body></html>`;
    const pv = (id, ctl, cb, extra = '') =>
      `<div id="${id}" data-tsc="${ctl}" data-tsc-h data-t-ev="page:${cb}" style="display:flex;width:200px;height:100px;overflow-x:auto;scroll-snap-type:x mandatory;${extra}">${'<div style="flex:0 0 100%;min-width:0;scroll-snap-align:start"></div>'.repeat(4)}</div>`;
    const p = await open(viewsPage);
    const r = await p.evaluate(async (html) => {
      // A restored page: the browser (or another part) scrolled the view before the controller saw it.
      const host = document.getElementById('host');
      host.insertAdjacentHTML('beforeend', html);
      const v = document.getElementById('r');
      v.scrollLeft = 200;
      document.documentElement.dispatchEvent(new CustomEvent('thor:stream', { detail: { nodes: [...host.children] } }));
      await new Promise((r) => setTimeout(r, 400));
      v.dispatchEvent(new Event('scrollend'));
      await new Promise((r) => setTimeout(r, 200));
      return { left: v.scrollLeft, page: p2.page, went: [...went] };
    }, pv('r', 'L.p2', 'L.go2'));
    check('scrolled view: a view that arrives already on page 1 keeps it (restored wins)', r.left === 200, JSON.stringify(r));
    check('scrolled view: arriving on a restored page is not an onPageChanged', r.went.length === 0, JSON.stringify(r.went));
    await p.evaluate(() => (document.getElementById('r').scrollLeft = 400));
    await p.waitForFunction(() => went.length > 0, null, { timeout: 3000 }).catch(() => {});
    check('scrolled view: the next change still reports (page 2)', JSON.stringify(await p.evaluate(() => went)) === '["b2"]', JSON.stringify(await p.evaluate(() => went)));
    await p.context().close();

    // The same view arrives twice (a copy in place): the second arrival is a baseline again.
    const q = await open(viewsPage);
    const s = await q.evaluate(async (html) => {
      stream(html);
      await new Promise((r) => setTimeout(r, 300));
      const old = document.getElementById('v');
      const copy = old.cloneNode(true);
      old.replaceWith(copy);
      copy.dispatchEvent(new CustomEvent('thor:adopted', { bubbles: true }));
      await new Promise((r) => setTimeout(r, 300));
      copy.dispatchEvent(new Event('scrollend'));
      await new Promise((r) => setTimeout(r, 200));
      return { left: copy.scrollLeft, went: [...went] };
    }, pv('v', 'L.pg', 'L.go'));
    // The copy is a new element at 0 for a controller whose initialPage is 2: it starts there again (no change event).
    check('copied view: a copy in place of a PageView is not a change either', s.went.length === 0, JSON.stringify(s));
    await q.context().close();

    // Hidden when it arrives (a closed tab, `display: none`), shown later.
    const h = await open(viewsPage);
    const t = await h.evaluate(async (html) => {
      stream(`<div id="wrap" style="display:none">${html}<div id="sv" style="height:100px;overflow:auto" data-tsc="L.sc"><div style="height:1000px"></div></div></div>`);
      await new Promise((r) => setTimeout(r, 300));
      const hidden = [document.getElementById('v').scrollLeft, document.getElementById('sv').scrollTop];
      document.getElementById('wrap').style.display = 'block';
      await new Promise((r) => setTimeout(r, 600));
      const v = document.getElementById('v');
      v.dispatchEvent(new Event('scrollend'));
      await new Promise((r) => setTimeout(r, 300));
      return { hidden, left: v.scrollLeft, page: pg.page, top: document.getElementById('sv').scrollTop, off: sc.offset, went: [...went] };
    }, pv('v', 'L.pg', 'L.go'));
    check('hidden view: hidden: nothing moved while it has no size', t.hidden[0] === 0 && t.hidden[1] === 0, JSON.stringify(t.hidden));
    check('hidden view: a PageView starts on its initialPage when it gets a size', t.left === 400 && t.page === 2, JSON.stringify(t));
    check('hidden view: and it is not an onPageChanged', t.went.length === 0, JSON.stringify(t.went));
    check('hidden view: a scroll view starts at its initialScrollOffset when it gets a size', t.top === 60 && t.off === 60, JSON.stringify(t));
    await h.evaluate(() => (document.getElementById('v').scrollLeft = 600));
    await h.waitForFunction(() => went.length === 1, null, { timeout: 3000 }).catch(() => {});
    check('hidden view: the next change reports', JSON.stringify(await h.evaluate(() => went)) === '[3]', JSON.stringify(await h.evaluate(() => went)));
    check('hidden view: no page errors', h.problems.length === 0, h.problems.join(' | '));
    await h.context().close();
  }
} finally {
  await browser.close();
}

const failed = results.filter((ok) => !ok).length;
console.log(`\n${results.length - failed}/${results.length} checks passed`);
if (failed > 0 || results.length === 0) process.exit(1);

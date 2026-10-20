// The controllers attacked, in real browsers: ScrollController.animateTo and
// TextEditingController.selection pushed where the happy path never goes
// (a view that can't scroll, is hidden, detached or replaced; a hundred calls
// in a row; no `scrollend`; NaN; emoji, textareas, IME, two fields).
//
//   node test/e2e/checks/controllers_break_check.mjs
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { chromium, firefox, webkit } from '../runner/node_modules/playwright/index.mjs';
import { frames, repo } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
const runtime = readFileSync(join(lite, 'runtime.js'), 'utf8');
const part = (n) => readFileSync(join(lite, 'parts', n), 'utf8');
const parts = ['controllers.js', 'scroll_controller.js', 'text_controller.js'];
const bundle = runtime.replace('// @thor-lite-parts', () => parts.map(part).join('\n'));
const page = (body, script, before = '') =>
  `<!DOCTYPE html><html><head><base href="/"></head><body>${body}<script>${before}</script><script>${bundle}\n${script}</script></body></html>`;

const tall = (id, ctl, extra = '') =>
  `<div id="${id}" style="height:100px;overflow:auto" data-tsc="${ctl}" ${extra}><div style="height:1000px"></div></div>`;
const scrollState = (...ids) => `thor.def('S', ($) => {
  ${ids.map((i) => `window.${i} = thor.ctl.scroll('S.${i}', 0);`).join('\n  ')}
  return { noop: () => {} };
}, { eager: true });`;

const pages = {
  '/short': page(`<div id="a" style="height:100px;overflow:auto" data-tsc="S.a"><div style="height:50px"></div></div>`, scrollState('a')),
  '/one': page(tall('a', 'S.a'), scrollState('a')),
  '/hor': page(
    `<div id="h" dir="rtl" style="width:100px;height:30px;overflow:auto" data-tsc="S.h" data-tsc-h><div style="width:1000px;height:10px"></div></div>`,
    scrollState('h'),
  ),
  '/text': page(
    `<input id="i" data-ttc="T.name" value="Ana"><input id="n" data-ttc="T.name">
<textarea id="t" data-ttc="T.area">uno
dos
tres</textarea><input id="o" data-ttc="T.other" value="otro">`,
    `thor.def('T', ($) => {
  const C = thor.ctl;
  window.nm = C.text('T.name', 'Ana'); window.area = C.text('T.area', 'uno\\ndos\\ntres'); window.other = C.text('T.other', 'otro');
  return { noop: () => {} };
}, { eager: true });`,
  ),
};

const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail !== '' ? ` (${detail})` : ''}`);
};

const launchers = { chromium, webkit, firefox };
for (const name of (process.env.BROWSERS ?? process.env.E2E_BROWSER ?? 'chromium,webkit,firefox').split(',')) {
  const browser = await launchers[name].launch();
  const open = async (path, { reduced = false, before } = {}) => {
    const ctx = await browser.newContext({ viewport: { width: 700, height: 900 }, reducedMotion: reduced ? 'reduce' : 'no-preference' });
    const p = await ctx.newPage();
    p.problems = [];
    p.on('pageerror', (e) => p.problems.push(e.message));
    await ctx.route('http://lite.test/**', (r) => {
      const body = pages[new URL(r.request().url()).pathname];
      return body ? r.fulfill({ contentType: 'text/html', body }) : r.fulfill({ status: 404, body: '' });
    });
    await p.addInitScript(race0 + (before ?? ''));
    await p.goto(`http://lite.test${path}`);
    await p.waitForFunction(() => typeof thor !== 'undefined');
    await frames(p); // the engine's first pass and frame
    return p;
  };
  const L = (s) => `[${name}] ${s}`;
  const race0 = `window.race = (p, ms = 2500) => Promise.race([p.then(() => 'done'), new Promise((r) => setTimeout(() => r('hung'), ms))]);`;

  try {
    // ---- scroll ----
    {
      const p = await open('/short');
      const r = await p.evaluate(async () => {
        const t0 = performance.now();
        const s = await race(a.animateTo(300));
        return [s, Math.round(performance.now() - t0), a.offset, document.getElementById('a').scrollTop];
      });
      check(L('animateTo on a view that cannot scroll completes at once'), r[0] === 'done' && r[1] < 300 && r[2] === 0, JSON.stringify(r));
      await p.context().close();
    }
    {
      const p = await open('/one');
      const r = await p.evaluate(async () => {
        const el = document.getElementById('a');
        el.scrollTop = 100;
        await new Promise((r) => setTimeout(r, 50));
        const t0 = performance.now();
        const s = await race(a.animateTo(100.4));
        return [s, Math.round(performance.now() - t0), a.offset];
      });
      check(L('animateTo to the offset it is at (sub-pixel off) completes at once'), r[0] === 'done' && r[1] < 300, JSON.stringify(r));
      // hidden view
      const h = await p.evaluate(async () => {
        const el = document.getElementById('a');
        el.style.display = 'none';
        const t0 = performance.now();
        const s = await race(a.animateTo(500));
        const took = Math.round(performance.now() - t0);
        el.style.display = '';
        return [s, took, a.offset, el.scrollTop];
      });
      check(L('animateTo on a display:none view completes'), h[0] === 'done' && h[1] < 2300, JSON.stringify(h));
      // NaN / Infinity
      const n = await p.evaluate(async () => {
        const out = [];
        for (const v of [NaN, Infinity, -Infinity]) out.push([String(v), await race(a.animateTo(v), 3000), a.offset]);
        return out;
      });
      check(L('animateTo(NaN/±Infinity) completes and offset stays finite'), n.every((x) => x[1] === 'done' && Number.isFinite(x[2])), JSON.stringify(n));
      const nj = await p.evaluate(() => { a.jumpTo(NaN); return [a.offset, document.getElementById('a').scrollTop]; });
      check(L('jumpTo(NaN) keeps offset finite'), Number.isFinite(nj[0]) && Number.isFinite(nj[1]), JSON.stringify(nj));
      check(L('no page errors (scroll one)'), p.problems.length === 0, p.problems.join('; '));
      await p.context().close();
    }
    {
      // detached mid-animation, and replaced by a copy (adopt)
      const p = await open('/one');
      const r = await p.evaluate(async () => {
        const el = document.getElementById('a');
        const done = a.animateTo(900);
        await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
        const t0 = performance.now();
        el.remove();
        const s = await race(done, 4000);
        return [s, Math.round(performance.now() - t0)];
      });
      check(L('a view removed mid-animation: the future completes'), r[0] === 'done', JSON.stringify(r));
      await p.context().close();
    }
    {
      const p = await open('/one');
      const r = await p.evaluate(async () => {
        const el = document.getElementById('a');
        const done = a.animateTo(900);
        await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
        // a copy takes its place (what a variant switch does), the engine says so
        const copy = el.cloneNode(true);
        copy.scrollTop = 0;
        el.replaceWith(copy);
        const t0 = performance.now();
        copy.dispatchEvent(new CustomEvent('thor:adopted', { bubbles: true }));
        const s = await race(done, 4000);
        return [s, Math.round(performance.now() - t0)];
      });
      check(L('a view replaced mid-animation resolves promptly (not after the 2 s timer)'), r[0] === 'done' && r[1] < 500, JSON.stringify(r));
      await p.context().close();
    }
    {
      // 100 in a row: all resolve, in order, without leaking timers or listeners
      const p = await open('/one');
      const r = await p.evaluate(async () => {
        const el = document.getElementById('a');
        let timers = 0, listeners = 0;
        const st = window.setTimeout, ct = window.clearTimeout;
        const live = new Set();
        window.setTimeout = (f, ms, ...r) => { const id = st(() => { live.delete(id); f(...r); }, ms); if (ms <= 2000) live.add(id); return id; };
        window.clearTimeout = (id) => { live.delete(id); ct(id); };
        const add = el.addEventListener.bind(el), rem = el.removeEventListener.bind(el);
        el.addEventListener = (t, f, o) => { if (t === 'scrollend') listeners++; return add(t, f, o); };
        el.removeEventListener = (t, f, o) => { if (t === 'scrollend') listeners--; return rem(t, f, o); };
        const order = [];
        const all = [];
        for (let i = 0; i < 100; i++) all.push(a.animateTo(i % 2 ? 100 + i : 800 - i).then(() => order.push(i)));
        const s = await race(Promise.all(all), 5000);
        await new Promise((r) => st(r, 100));
        window.setTimeout = st; window.clearTimeout = ct;
        return [s, order.length, order.every((v, i) => v === i), live.size, listeners];
      });
      check(L('100 animateTo in a row: all resolve, in order'), r[0] === 'done' && r[1] === 100 && r[2], JSON.stringify(r));
      check(L('100 animateTo leave no timer and no scrollend listener behind'), r[3] === 0 && r[4] === 0, JSON.stringify(r));
      check(L('no page errors (100)'), p.problems.length === 0, p.problems.join('; '));
      await p.context().close();
    }
    {
      // no scrollend (older WebKit): the fallback timer path still resolves
      const before = `delete HTMLElement.prototype.onscrollend; const a = EventTarget.prototype.addEventListener; EventTarget.prototype.addEventListener = function (t, ...r) { return t === 'scrollend' ? undefined : a.call(this, t, ...r); };`;
      const p = await open('/one', { before });
      const r = await p.evaluate(async () => {
        const el = document.getElementById('a');
        const t0 = performance.now();
        const s = await race(a.animateTo(900), 4000);
        const took = Math.round(performance.now() - t0);
        const at = el.scrollTop;
        await new Promise((r) => setTimeout(r, 1200));
        return [s, took, at, el.scrollTop, a.offset, 'onscrollend' in el];
      });
      check(L('no scrollend: animateTo completes'), r[0] === 'done', JSON.stringify(r));
      check(L('no scrollend: the future does not resolve before the view is there'), r[2] === 900 && r[4] === 900, JSON.stringify(r));
      await p.context().close();
    }
    {
      // GridView-like: the attribute is the same; horizontal RTL at max
      const p = await open('/hor');
      const r = await p.evaluate(async () => {
        const el = document.getElementById('h');
        const s1 = await race(h.animateTo(1e9));
        const at = [el.scrollLeft, h.offset, h.maxScrollExtent];
        const s2 = await race(h.animateTo(0));
        const back = [el.scrollLeft, h.offset];
        h.jumpTo(1e9);
        return [s1, s2, at, back, [el.scrollLeft, h.offset]];
      });
      check(L('RTL: animateTo past the end lands on the max (leftmost) and back to 0'), r[0] === 'done' && r[1] === 'done' && r[2][0] === -900 && r[2][1] === 900 && r[3][0] === 0 && r[4][1] === 900, JSON.stringify(r));
      await p.context().close();
    }

    {
      // a controller with no view: the offset it keeps is never negative
      const p = await open('/one');
      const r = await p.evaluate(() => {
        document.getElementById('a').remove();
        a.jumpTo(-50);
        const neg = a.offset;
        a.jumpTo(30);
        return [neg, a.offset];
      });
      check(L('jumpTo(-50) with no view keeps 0, like animateTo'), r[0] === 0 && r[1] === 30, JSON.stringify(r));
      await p.context().close();
    }

    // ---- text ----
    {
      const p = await open('/text');
      const sel = (id) => p.evaluate((i) => { const e = document.getElementById(i); return [e.selectionStart, e.selectionEnd, e.selectionDirection]; }, id);
      const read = () => p.evaluate(() => [nm.selection.baseOffset, nm.selection.extentOffset]);
      const readArea = () => p.evaluate(() => [area.selection.baseOffset, area.selection.extentOffset]);
      // The controller reads back what its field (id) really has.
      const synced = (id, ctl, extra = () => true) =>
        p.waitForFunction(([id, ctl, extra]) => {
          const e = document.getElementById(id), c = window[ctl].selection, back = e.selectionDirection === 'backward';
          return c.baseOffset === (back ? e.selectionEnd : e.selectionStart) && c.extentOffset === (back ? e.selectionStart : e.selectionEnd) && new Function('e', 'c', `return (${extra})(e, c)`)(e, c);
        }, [id, ctl, String(extra)]);
      // textarea: newlines count one
      await p.evaluate(() => { area.selection = thor.ctl.sel(4, 7); });
      await synced('t', 'area', (e) => e.selectionStart === 4 && e.selectionEnd === 7);
      check(L('textarea: a range over the second line'), JSON.stringify((await sel('t')).slice(0, 2)) === '[4,7]' && JSON.stringify(await readArea()) === '[4,7]', `${await sel('t')} ${await readArea()}`);
      await p.evaluate(() => { area.selection = thor.ctl.sel(1e6, 0); });
      await synced('t', 'area', (e) => e.selectionEnd === e.value.length && e.selectionStart === 0);
      const len = 'uno\ndos\ntres'.length;
      check(L('textarea: a backward range past the end clamps'), JSON.stringify(await readArea()) === `[${len},0]`, `${await readArea()} ${await sel('t')}`);
      // CRLF text through the controller
      await p.evaluate(() => { area.text = 'a\r\nb'; area.selection = thor.ctl.sel(4, 4); });
      await synced('t', 'area', (e) => e.value === 'a\nb');
      check(L('textarea with CRLF text: selection reads what the field really has'), (await readArea())[0] === (await sel('t'))[0], `${await readArea()} ${await sel('t')} ${await p.inputValue('#t')}`);
      // emoji / surrogates (UTF-16 offsets, as Dart)
      await p.evaluate(() => { nm.text = '😀ab'; nm.selection = thor.ctl.sel(2, 2); });
      await synced('i', 'nm', (e) => e.value === '😀ab' && e.selectionStart === 2);
      check(L('emoji: offset 2 is after the emoji (UTF-16 like Dart)'), JSON.stringify(await read()) === '[2,2]' && (await sel('i'))[0] === 2, `${await read()} ${await sel('i')}`);
      await p.evaluate(() => { nm.selection = thor.ctl.sel(1, 1); });
      await synced('i', 'nm');
      const mid = await read();
      check(L('emoji: an offset inside the pair reads back what the field has'), mid[0] === (await sel('i'))[0], `${mid} ${await sel('i')}`);
      await p.evaluate(() => { nm.selection = thor.ctl.sel(0, 4); });
      await synced('i', 'nm', (e) => e.selectionStart === 0 && e.selectionEnd === 4);
      check(L('emoji: length 4 is the whole text'), JSON.stringify(await read()) === '[0,4]', `${await read()}`);
      // unfocused field, then focused
      await p.evaluate(() => { other.selection = thor.ctl.sel(1, 3); });
      await p.waitForFunction(() => other.selection.baseOffset === 1 && other.selection.extentOffset === 3);
      const u = await sel('o');
      await p.focus('#o');
      await p.waitForFunction(() => document.activeElement.id === 'o');
      const f = await sel('o');
      check(L('a selection set on an unfocused field is there when it is focused'), u[0] === 1 && u[1] === 3 && f[0] === 1 && f[1] === 3, `${u} ${f}`);
      const rd = await p.evaluate(() => [other.selection.baseOffset, other.selection.extentOffset]);
      check(L('and the controller says so'), JSON.stringify(rd) === '[1,3]', `${rd}`);
      // two fields, one controller: only the focused one reports the caret
      await p.focus('#i');
      await p.evaluate(() => { nm.text = 'abcdef'; nm.selection = thor.ctl.sel(2, 2); });
      await synced('i', 'nm', (e) => e.value === 'abcdef' && e.selectionStart === 2);
      await p.keyboard.type('XY');
      await synced('i', 'nm', (e) => e.value === 'abXYcdef' && e.selectionStart === 4);
      const other2 = await sel('n');
      check(L('typing in one field: the controller follows the focused field\'s caret'), JSON.stringify(await read()) === `[${(await sel('i'))[0]},${(await sel('i'))[0]}]`, `${await read()} i=${await sel('i')} n=${other2} v=${await p.inputValue('#i')}|${await p.inputValue('#n')}`);
      // select all on the field, then Home
      await p.keyboard.press(process.platform === 'darwin' ? 'Meta+A' : 'Control+A');
      await synced('i', 'nm', (e) => e.selectionStart === 0 && e.selectionEnd === e.value.length);
      const all = await read();
      await p.keyboard.press('ArrowLeft');
      await synced('i', 'nm', (e) => e.selectionStart === 0 && e.selectionEnd === 0);
      check(L('select all then ArrowLeft: range then caret at 0'), all[0] === 0 && all[1] === 'abXYcdef'.length && JSON.stringify(await read()) === '[0,0]', `${all} ${await read()}`);
      // setting the text the field already has (an onChanged that trims) moves nothing
      await p.focus('#i');
      await p.evaluate(() => { nm.text = 'abcdef'; nm.selection = thor.ctl.sel(2, 2); });
      await synced('i', 'nm', (e) => e.value === 'abcdef' && e.selectionStart === 2);
      // Same text again: nothing changes, so there is no event to wait for; one
      // frame lets any (wrong) late caret move happen before the check.
      await p.evaluate(() => { nm.text = nm.text; });
      await p.evaluate(() => new Promise((ok) => requestAnimationFrame(() => requestAnimationFrame(ok))));
      check(L('the same text again keeps the caret where the field has it'), JSON.stringify(await read()) === JSON.stringify([(await sel('i'))[0], (await sel('i'))[1]]) && (await sel('i'))[0] === 2, `${await read()} ${await sel('i')}`);
      // what a state prints: Dart's TextSelection(base, extent), not [object Object]
      const str = await p.evaluate(() => { nm.selection = thor.ctl.sel(1, 3); return [`${nm.selection}`, String(thor.ctl.sel(2)), `${thor.ctl.sel(-1)}`]; });
      check(L('a selection in a string reads like Dart\'s TextSelection'), JSON.stringify(str) === JSON.stringify(['TextSelection(1, 3)', 'TextSelection(2, 2)', 'TextSelection(-1, -1)']), JSON.stringify(str));
      check(L('no page errors (text)'), p.problems.length === 0, p.problems.join('; '));
      await p.context().close();
    }
  } catch (e) {
    check(L(`script crashed: ${e.message.split('\n')[0]}`), false);
  } finally {
    await browser.close();
  }
}
process.exit(results.every(Boolean) ? 0 : 1);

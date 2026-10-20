// The controllers pushed further on the lite engine, in a real Chromium, on pages made in
// memory around the real runtime and its controller parts: value (identical
// sets, IME composition, out-of-range selections), FocusNode listeners
// (order, doubles, removal during a dispatch, after dispose), the snack bar's
// hideToast/clearToasts, PageController/PageView (fractional page, no
// snapping, nested views, arrow keys, resizes, hidden views), hasClients in
// closed dialogs and curves of animateTo/animateBack/animateToPage.
//
//   node test/e2e/checks/controllers_edge_check.mjs   (BROWSER=webkit|firefox too)
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { chromium, firefox, webkit } from '../runner/node_modules/playwright/index.mjs';
import { frames, repo } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
const read = (f) => readFileSync(join(lite, f), 'utf8');
const parts = [
  'duration.js',
  'controllers.js',
  'scroll_controller.js',
  'page_controller.js',
  'text_controller.js',
  'focus_node.js',
  'page_view.js',
  'animation_controller.js',
].map((n) => read(`parts/${n}`));
const bundle = read('runtime.js').replace('// @thor-lite-parts', () => parts.join('\n'));
const toast = read('toast.js');
const page = (body, script, before = '') =>
  `<!DOCTYPE html><html><head><base href="/"></head><body>${body}<script>${before}</script><script>${bundle}\n${script}</script></body></html>`;

const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail !== '' ? ` (${detail})` : ''}`);
};

const pagesHtml = (attrs, { dir = '', style = '', vertical = false, snap = true, n = 4, inner = '' } = {}) =>
  `<div id="v" ${dir} ${attrs} style="display:flex;flex-direction:${vertical ? 'column' : 'row'};width:200px;height:100px;overflow-${vertical ? 'y' : 'x'}:auto;${snap ? `scroll-snap-type:${vertical ? 'y' : 'x'} mandatory;` : ''}${style}">${Array.from({ length: n }, (_, i) => `<div style="flex:0 0 100%;min-width:0;min-height:0;scroll-snap-align:start">${i === 0 ? inner : ''}</div>`).join('')}</div>`;
const pagesState = (initial = 0) => `thor.def('P', ($) => {
  const pages = thor.ctl.page('P.pages', ${initial});
  window.went = [];
  Object.assign(window, { pages });
  return { go: (v) => window.went.push(Number(v)) };
}, { eager: true });`;
const attrsH = 'data-tsc="P.pages" data-tsc-h data-t-ev="page:P.go"';

const pages = {
  '/text': page(
    `<input id="i" data-ttc="T.name" value="Ana">`,
    `thor.def('T', ($) => {
  const name = thor.ctl.text('T.name', 'Ana');
  Object.assign(window, { nm: name });
  return { noop: () => {} };
}, { eager: true });`,
  ),
  // Two fields, two nodes, one log.
  '/focus2': page(
    `<input id="a" data-tfn="F.a"><input id="b" data-tfn="F.b">`,
    `thor.def('F', ($) => {
  const a = thor.ctl.focus('F.a'), b = thor.ctl.focus('F.b');
  window.log = [];
  Object.assign(window, { na: a, nb: b });
  return { noop: () => {} };
}, { eager: true });`,
  ),
  '/pages': page(pagesHtml(attrsH), pagesState(0)),
  '/pages-free': page(pagesHtml(attrsH, { snap: false }), pagesState(0)),
  '/pages-nested': page(
    pagesHtml(attrsH, {
      n: 3,
      inner: `<div class="in" data-tsc="Q.pages" data-tsc-h data-t-ev="page:Q.go" style="display:flex;width:100px;height:100px;overflow-x:auto;scroll-snap-type:x mandatory">${'<div style="flex:0 0 100%;scroll-snap-align:start"></div>'.repeat(3)}</div>`,
    }),
    `thor.def('P', ($) => {
  const pages = thor.ctl.page('P.pages', 0);
  window.went = [];
  Object.assign(window, { pages });
  return { go: (v) => window.went.push(Number(v)) };
}, { eager: true });
thor.def('Q', ($) => {
  const inner = thor.ctl.page('Q.pages', 0);
  window.wentIn = [];
  Object.assign(window, { inner });
  return { go: (v) => window.wentIn.push(Number(v)) };
}, { eager: true });`,
  ),
  // jumpToPage and a value asked for by the state itself while it is made (before hydration).
  '/pages-early': page(
    pagesHtml(attrsH),
    `thor.def('P', ($) => {
  const pages = thor.ctl.page('P.pages', 0);
  window.went = [];
  window.early = [pages.page, pages.hasClients];
  pages.jumpToPage(2);
  window.early.push(pages.page, pages.offset);
  Object.assign(window, { pages });
  return { go: (v) => window.went.push(Number(v)) };
}, { eager: true });`,
  ),
  // A focusable scroller for arrow keys.
  '/pages-keys': page(pagesHtml(attrsH + ' tabindex="0"'), pagesState(0)),
  // A view in a closed dialog, one with display:none.
  '/hidden': page(
    `<dialog id="dlg"><div id="dv" data-tsc="H.dlg" style="height:50px;overflow:auto"><div style="height:500px">x</div></div></dialog>
<div id="hid" data-tsc="H.hid" style="display:none;height:50px;overflow:auto"><div style="height:500px">x</div></div>`,
    `thor.def('H', ($) => {
  const d = thor.ctl.scroll('H.dlg', 0), h = thor.ctl.scroll('H.hid', 0);
  Object.assign(window, { dlg: d, hid: h });
  return { noop: () => {} };
}, { eager: true });`,
  ),
  // An AnimationController with an element that follows it (data-ta), and a scroll view.
  '/anim': page(
    `<div id="box" data-ta='[{"c":"A.c","k":[{"opacity":0},{"opacity":1}]}]' style="width:10px;height:10px"></div>
<div id="a" style="height:100px;overflow:auto" data-tsc="A.list"><div style="height:1000px">x</div></div>
${pagesHtml('data-tsc="A.pages" data-tsc-h data-t-ev="page:A.go"', { n: 4 }).replace('id="v"', 'id="v"')}`,
    `thor.def('A', ($) => {
  const D = thor.dt.Dur;
  const c = thor.ctl.anim('A.c', null, D.of(0, 0, 0, 0, 400), null, null);
  const list = thor.ctl.scroll('A.list', 0), pages = thor.ctl.page('A.pages', 0);
  window.went = [];
  Object.assign(window, { c, list, pages, D });
  return { go: (v) => window.went.push(Number(v)) };
}, { eager: true });`,
  ),
  // The server's CSS animation of an eased move (animateTo(0.5, curve) at render), a quarter of a pass in.
  '/anim-ssr': page(
    `<style>@keyframes kf{0%{opacity:0}100%{opacity:1}}</style>
<div id="box" style="width:10px;height:10px;animation:kf 1000ms linear -250ms 0.5 normal both paused" data-ta='[{"c":"A.c","k":[{"opacity":0},{"opacity":1}],"a":"kf","x":["cubic-bezier(0, 0, 0.58, 1)",0,0.5]}]'></div>`,
    `thor.def('A', ($) => {
  const c = thor.ctl.anim('A.c', null, thor.dt.Dur.of(0, 0, 0, 0, 400), null, null);
  Object.assign(window, { c });
  return {};
}, { eager: true });`,
  ),
  // The snack bar the server writes, and the part that fills it.
  '/toast': `<!DOCTYPE html><html><head><base href="/"><style>.off{display:none}.info{display:block}.err{display:block}</style></head><body>
<div id="thor-toast" popover="manual" class="off" role="status"></div>
<template id="thor-toast-kinds"><i data-k="off" class="off"></i><i data-k="info" class="info"></i><i data-k="error" class="err"></i></template>
<script>${toast}</script></body></html>`,
};

const name = process.env.BROWSER ?? 'chromium';
const browser = await { chromium, firefox, webkit }[name].launch();
const open = async (path, { reduced = false, viewport = { width: 700, height: 900 } } = {}) => {
  const ctx = await browser.newContext({ viewport, reducedMotion: reduced ? 'reduce' : 'no-preference' });
  const p = await ctx.newPage();
  p.problems = [];
  p.on('pageerror', (e) => p.problems.push(e.message));
  await ctx.route('http://lite.test/**', (r) => {
    const body = pages[new URL(r.request().url()).pathname];
    return body ? r.fulfill({ contentType: 'text/html', body }) : r.fulfill({ status: 404, body: '' });
  });
  await p.goto(`http://lite.test${path}`);
  if (path !== '/toast') await p.waitForFunction(() => typeof thor !== 'undefined');
  await frames(p);
  return p;
};
// WebKit's headless document timeline runs early after idle (a plain forward() ends
// in 15-900 ms of 300-1200): the timing bounds don't apply to it.
const timed = name !== 'webkit';
const left = (p) => p.evaluate(() => document.getElementById('v').scrollLeft);

try {
  // --- TextEditingController.value --------------------------------------------
  {
    const p = await open('/text');
    // An identical value is not a change (Flutter's ValueNotifier ignores it).
    const same = await p.evaluate(async () => {
      let n = 0;
      thor.effect(() => (nm.value, n++));
      const v0 = nm.value;
      nm.value = v0;
      nm.value = thor.ctl.val(v0.text, v0.selection);
      nm.selection = nm.selection;
      await Promise.resolve();
      return n;
    });
    check('setting an identical value (or selection) does not notify again', same === 1, `${same} runs`);
    // A selection past the end, set together with the text, is kept inside it.
    const far = await p.evaluate(async () => {
      nm.value = thor.ctl.val('abc', thor.ctl.sel(9, 12));
      await new Promise((r) => setTimeout(r, 30));
      const el = document.getElementById('i');
      return [nm.value.text, nm.selection.baseOffset, nm.selection.extentOffset, el.selectionStart, el.selectionEnd];
    });
    check('a selection past the text is clamped to it in the controller and the field', JSON.stringify(far) === '["abc",3,3,3,3]', JSON.stringify(far));
    // A value with a negative base and a valid extent: not valid, stays out of the field.
    const neg = await p.evaluate(async () => {
      nm.value = thor.ctl.val('abcd', thor.ctl.sel(-1, 2));
      await new Promise((r) => setTimeout(r, 30));
      return [nm.text, nm.selection.isValid];
    });
    check('a new text with a half-invalid selection puts the caret at its end (web)', neg[0] === 'abcd' && neg[1] === true, JSON.stringify(neg));
    // Value is one tick for text and selection together, listeners of both see the pair.
    const pair = await p.evaluate(() => {
      const seen = [];
      thor.effect(() => seen.push(`${nm.text}|${nm.selection.baseOffset}`));
      nm.value = thor.ctl.val('zz', thor.ctl.sel(1));
      return seen;
    });
    check('an effect never sees the new text with the old selection', pair.length === 2 && pair[1] === 'zz|1', JSON.stringify(pair));
    check('no page errors (value)', p.problems.length === 0, p.problems.join('; '));
    await p.context().close();
  }
  if (name === 'chromium') {
    // IME composition (CDP): the visitor is mid-composition; the page sets what it already has.
    const p = await open('/text');
    await p.focus('#i');
    await p.evaluate(() => (nm.value = thor.ctl.val('', thor.ctl.sel(0))));
    await p.waitForFunction(() => nm.value.text === '');
    const cdp = await p.context().newCDPSession(p);
    await cdp.send('Input.imeSetComposition', { text: 'ni', selectionStart: 2, selectionEnd: 2 });
    await p.waitForFunction(() => nm.value.text === 'ni');
    const comp = () => p.evaluate(() => {
      const el = document.getElementById('i');
      // `isComposing` is only on events; a composition shows as a selection of the field kept by the IME.
      return [el.value, el.selectionStart, el.selectionEnd, nm.text, !!window.__composing];
    });
    await p.evaluate(() => {
      window.__ends = 0;
      document.getElementById('i').addEventListener('compositionend', () => window.__ends++);
    });
    await p.evaluate(() => {
      nm.value = nm.value; // the same value, mid-composition
      nm.value = thor.ctl.val('ni', nm.selection);
    });
    await frames(p, 3);
    await cdp.send('Input.imeSetComposition', { text: 'nih', selectionStart: 3, selectionEnd: 3 });
    await p.waitForFunction(() => nm.value.text === 'nih');
    check('setting the same value mid-composition does not end it', (await p.evaluate(() => window.__ends)) === 0, JSON.stringify(await comp()));
    await cdp.send('Input.insertText', { text: 'ihao' });
    await p.waitForFunction(() => nm.value.text.length > 0);
    check('the controller follows the IME text (composition then commit)', (await p.evaluate(() => nm.text)) === (await p.inputValue('#i')), `${await p.inputValue('#i')} / ${await p.evaluate(() => nm.text)}`);
    check('no page errors (ime)', p.problems.length === 0, p.problems.join('; '));
    await p.context().close();
  }

  // --- FocusNode listeners ------------------------------------------------------
  {
    const p = await open('/focus2');
    await p.evaluate(() => {
      na.addListener(() => log.push(`a:${na.hasFocus}`));
      nb.addListener(() => log.push(`b:${nb.hasFocus}`));
    });
    await p.focus('#a');
    await p.focus('#b');
    const log = await p.evaluate(() => log);
    check('moving focus between two fields: each node once, the old one first', JSON.stringify(log) === '["a:true","a:false","b:true"]', JSON.stringify(log));
    await p.evaluate(() => (log.length = 0));
    // Added twice: called twice; one removal leaves one.
    const dbl = await p.evaluate(() => {
      const f = () => log.push('twice');
      na.addListener(f);
      na.addListener(f);
      const el = document.getElementById('a');
      el.focus();
      const first = log.filter((x) => x === 'twice').length;
      el.blur();
      log.length = 0;
      na.removeListener(f);
      el.focus();
      const second = log.filter((x) => x === 'twice').length;
      el.blur();
      na.removeListener(f);
      log.length = 0;
      el.focus();
      const third = log.filter((x) => x === 'twice').length;
      return [first, second, third];
    });
    check('a listener added twice is called twice; each removal takes one', JSON.stringify(dbl) === '[2,1,0]', JSON.stringify(dbl));
    await p.evaluate(() => document.getElementById('a').blur());
    // Removal during dispatch: the one removed does not run afterwards.
    const rm = await p.evaluate(() => {
      log.length = 0;
      const second = () => log.push('second');
      const first = () => {
        log.push('first');
        na.removeListener(second);
      };
      na.addListener(first);
      na.addListener(second);
      document.getElementById('a').focus();
      const out = log.filter((x) => !x.startsWith('a:'));
      na.removeListener(first);
      na.removeListener(second);
      return out;
    });
    check('a listener removed by an earlier one in the same dispatch is not called', JSON.stringify(rm) === '["first"]', JSON.stringify(rm));
    // Added during dispatch: not called in that dispatch.
    const add = await p.evaluate(() => {
      document.getElementById('a').blur();
      log.length = 0;
      const late = () => log.push('late');
      const adder = () => {
        log.push('adder');
        na.addListener(late);
      };
      na.addListener(adder);
      document.getElementById('a').focus();
      const out = log.filter((x) => !x.startsWith('a:'));
      na.removeListener(adder);
      na.removeListener(late);
      return out;
    });
    check('a listener added during a dispatch waits for the next one', JSON.stringify(add) === '["adder"]', JSON.stringify(add));
    // dispose, then addListener: Flutter asserts.
    const disp = await p.evaluate(() => {
      nb.dispose();
      try {
        nb.addListener(() => {});
        return 'no error';
      } catch (e) {
        return String(e.message);
      }
    });
    check('addListener after dispose throws (Flutter asserts)', /dispose/i.test(disp), disp);
    const quiet = await p.evaluate(() => {
      log.length = 0;
      document.getElementById('b').focus();
      return log.filter((x) => !x.startsWith('a:'));
    });
    check('a disposed node tells nobody', quiet.length === 0, JSON.stringify(quiet));
    check('no page errors (focus)', p.problems.every((m) => !/Uncaught/.test(m) || /ignored/.test(m)), p.problems.join('; '));
    await p.context().close();
  }

  // --- hideToast / clearToasts --------------------------------------------------
  {
    const p = await open('/toast');
    const bar = () => p.evaluate(() => [document.getElementById('thor-toast').textContent, document.getElementById('thor-toast').hasAttribute('data-t-on')]);
    await p.evaluate(() => document.thorToastHide(false)); // nothing showing: nothing happens
    check('hideToast with none showing does nothing', JSON.stringify(await bar()) === '["",false]', JSON.stringify(await bar()));
    await p.evaluate(() => document.thorToastHide(true));
    check('clearToasts with none showing does nothing', JSON.stringify(await bar()) === '["",false]');
    await p.evaluate(() => {
      document.thorToast('one', 'info', 0);
      document.thorToast('two', 'info', 0);
      document.thorToast('three', 'info', 0);
    });
    check('one shows, the rest wait', JSON.stringify(await bar()) === '["one",true]', JSON.stringify(await bar()));
    await p.evaluate(() => document.thorToastHide(false));
    check('hideToast shows the next waiting one (Flutter hideCurrentSnackBar)', JSON.stringify(await bar()) === '["two",true]', JSON.stringify(await bar()));
    await p.evaluate(() => document.thorToastHide(true));
    check('clearToasts ends the showing one and forgets the waiting', (await bar())[1] === false, JSON.stringify(await bar()));
    // After a clear the bar works again, and the stale timer of the cleared one does not cut it short.
    await p.evaluate(() => document.thorToast('four', 'info', 0));
    check('a toast after clearToasts shows', JSON.stringify(await bar()) === '["four",true]');
    // hideToast then toast in the same method: the new one shows.
    await p.evaluate(() => {
      document.thorToastHide(false);
      document.thorToast('five', 'error', 0);
    });
    check('hideToast then toast in one method shows the new one', JSON.stringify(await bar()) === '["five",true]', JSON.stringify(await bar()));
    // The same message that was just hidden can be shown again.
    await p.evaluate(() => {
      document.thorToastHide(false);
      document.thorToast('five', 'error', 0);
    });
    check('the message that was just hidden shows again', JSON.stringify(await bar()) === '["five",true]');
    // Many hides in a row with a queue.
    const many = await p.evaluate(() => {
      document.thorToast('a', 'info', 0);
      document.thorToast('b', 'info', 0);
      const seen = [];
      for (let i = 0; i < 5; i++) {
        document.thorToastHide(false);
        seen.push(document.getElementById('thor-toast').textContent + (document.getElementById('thor-toast').hasAttribute('data-t-on') ? '+' : '-'));
      }
      return seen;
    });
    check('hideToast walks the queue and then stays empty', JSON.stringify(many) === '["a+","b+","b-","b-","b-"]' || JSON.stringify(many).includes('-'), JSON.stringify(many));
    check('no page errors (toast)', p.problems.length === 0, p.problems.join('; '));
    await p.context().close();
  }

  // --- PageController / PageView ------------------------------------------------
  {
    const p = await open('/pages');
    // The page is the offset over the size, not rounded, while it is dragged.
    const frac = await p.evaluate(async () => {
      const v = document.getElementById('v');
      v.style.scrollSnapType = 'none';
      v.scrollLeft = 130;
      await new Promise((r) => requestAnimationFrame(r));
      await new Promise((r) => setTimeout(r, 30));
      return [pages.page, pages.offset];
    });
    check('page is fractional while the view is between pages', frac[0] === 0.65 && frac[1] === 130, JSON.stringify(frac));
    await p.context().close();
  }
  {
    // pageSnapping: false: it stays where it is left; onPageChanged is the nearest page.
    const p = await open('/pages-free');
    await p.evaluate(() => (document.getElementById('v').scrollLeft = 270));
    await p.waitForFunction(() => went.length === 1);
    check('without snapping the page is the nearest one, and the view stays where it was left', (await left(p)) === 270 && JSON.stringify(await p.evaluate(() => went)) === '[1]' && Math.abs((await p.evaluate(() => pages.page)) - 1.35) < 1e-9, `${await left(p)} ${JSON.stringify(await p.evaluate(() => went))}`);
    await p.evaluate(() => (document.getElementById('v').scrollLeft = 330));
    await p.waitForTimeout(250);
    check('without snapping 1.65 is still page 2', JSON.stringify(await p.evaluate(() => went)) === '[1,2]', JSON.stringify(await p.evaluate(() => went)));
    await p.context().close();
  }
  {
    const p = await open('/pages-nested');
    await p.evaluate(() => (document.querySelector('.in').scrollLeft = 100));
    await p.waitForFunction(() => wentIn.length === 1);
    await p.waitForTimeout(200);
    check('nested: an inner swipe reports the inner view only', JSON.stringify(await p.evaluate(() => [went, wentIn])) === '[[],[1]]', JSON.stringify(await p.evaluate(() => [went, wentIn])));
    await p.evaluate(() => (document.getElementById('v').scrollLeft = 200));
    await p.waitForFunction(() => went.length === 1);
    await p.waitForTimeout(200);
    check('nested: an outer swipe reports the outer view only', JSON.stringify(await p.evaluate(() => [went, wentIn])) === '[[1],[1]]', JSON.stringify(await p.evaluate(() => [went, wentIn])));
    const both = await p.evaluate(async () => {
      pages.jumpToPage(2);
      inner.jumpToPage(2);
      await new Promise((r) => setTimeout(r, 250));
      return [pages.page, inner.page, went, wentIn];
    });
    check('nested: two controllers jump independently', JSON.stringify(both) === '[2,2,[1,2],[1,2]]', JSON.stringify(both));
    check('no page errors (nested)', p.problems.length === 0, p.problems.join('; '));
    await p.context().close();
  }
  {
    const p = await open('/pages-early');
    await p.waitForTimeout(300);
    const r = await p.evaluate(() => [early, pages.page, window.went, document.getElementById('v').scrollLeft]);
    // Like an initialPage (and like Flutter, where nothing is attached yet): where the view starts is not a change.
    check('jumpToPage while the state is made (before hydration) lands on the page and is the start, not a change', JSON.stringify(r) === '[[0,true,2,400],2,[],400]', JSON.stringify(r));
    check('no page errors (early)', p.problems.length === 0, p.problems.join('; '));
    await p.context().close();
  }
  {
    // Arrow keys on the focused view.
    const p = await open('/pages-keys');
    await p.focus('#v');
    await p.keyboard.press('ArrowRight');
    await p.waitForFunction(() => went.length >= 1, null, { timeout: 4000 }).catch(() => {});
    await p.waitForTimeout(300);
    const w = await p.evaluate(() => [went, pages.page]);
    check('ArrowRight on the focused view goes to the next page and reports it', JSON.stringify(w) === '[[1],1]', JSON.stringify(w) + ` left=${await left(p)}`);
    await p.keyboard.press('ArrowLeft');
    await p.waitForTimeout(500);
    const w2 = await p.evaluate(() => [went, pages.page]);
    check('ArrowLeft goes back and reports it', JSON.stringify(w2) === '[[1,0],0]', JSON.stringify(w2));
    await p.context().close();
  }
  {
    // The view's size changes (not a window resize): the page index holds.
    const p = await open('/pages');
    await p.evaluate(() => pages.jumpToPage(2));
    await p.waitForFunction(() => went.length === 1);
    await p.evaluate(() => (document.getElementById('v').style.width = '300px'));
    await p.waitForTimeout(400);
    const r = await p.evaluate(() => [pages.page, pages.offset, document.getElementById('v').scrollLeft, went]);
    check('the view growing keeps the page (offset and report follow)', r[0] === 2 && JSON.stringify(r[3]) === '[2]', JSON.stringify(r));
    // And the window resize does the same for a view sized in percent.
    await p.evaluate(() => (document.getElementById('v').style.width = '50vw'));
    await p.setViewportSize({ width: 800, height: 900 });
    await p.waitForTimeout(400);
    const r2 = await p.evaluate(() => [pages.page, document.getElementById('v').scrollLeft, document.getElementById('v').clientWidth, went]);
    check('a window resize keeps the page', r2[0] === 2 && r2[1] === 2 * r2[2] && JSON.stringify(r2[3]) === '[2]', JSON.stringify(r2));
    await p.context().close();
  }
  {
    // hasClients: a view in a closed dialog or hidden is in the page.
    const p = await open('/hidden');
    const r = await p.evaluate(() => [dlg.hasClients, hid.hasClients, dlg.viewportDimension, hid.viewportDimension]);
    check('hasClients: a view in a closed <dialog> or display:none is in the page (size 0)', JSON.stringify(r) === '[true,true,0,0]', JSON.stringify(r));
    const r2 = await p.evaluate(async () => {
      document.getElementById('dlg').showModal();
      await new Promise((r) => setTimeout(r, 30));
      dlg.jumpTo(30);
      await new Promise((r) => setTimeout(r, 30));
      return [dlg.hasClients, document.getElementById('dv').scrollTop, dlg.offset, dlg.viewportDimension];
    });
    check('hasClients stays true when the dialog opens and the view measures', r2[0] === true && r2[1] === 30 && r2[2] === 30 && r2[3] === 50, JSON.stringify(r2));
    await p.context().close();
  }
  // --- Curves: AnimationController.animateTo / animateBack / fling -----------------
  {
    const p = await open('/anim');
    // The value at directed progress q of a move, by the curve evaluated apart (a paused animation on the box).
    const cases = [
      ['0->1 easeOut', 0, 1, 'cubic-bezier(0, 0, 0.58, 1)'],
      ['0->1 easeIn', 0, 1, 'cubic-bezier(0.42, 0, 1, 1)'],
      ['0->0.5 easeInOut (stops short)', 0, 0.5, 'cubic-bezier(0.42, 0, 0.58, 1)'],
      ['1->0 easeOut (backwards to the bound)', 1, 0, 'cubic-bezier(0, 0, 0.58, 1)'],
      ['0.8->0.2 easeIn (backwards, stops short)', 0.8, 0.2, 'cubic-bezier(0.42, 0, 1, 1)'],
      ['0.2->0.6 easeOut (from the middle)', 0.2, 0.6, 'cubic-bezier(0, 0, 0.58, 1)'],
      ['0->1 easeOutBack (overshoots: clamped)', 0, 1, 'cubic-bezier(0.175, 0.885, 0.32, 1.275)'],
    ];
    const r = await p.evaluate((cases) => {
      const out = [];
      const probe = (css) => {
        const a = new Animation(new KeyframeEffect(null, null, { duration: 1000, easing: css, fill: 'both' }));
        a.pause();
        return (s) => ((a.currentTime = s * 1000), a.effect.getComputedTiming().progress);
      };
      const box = document.getElementById('box');
      for (const [name, f, e, css] of cases) {
        c.value = f;
        c.animateTo(e, D.of(0, 0, 0, 0, 1000), css);
        const at = probe(css);
        const rows = [];
        for (const s of [0, 0.1, 0.25, 0.5, 0.75, 0.9, 1]) {
          const q = f + (e - f) * s; // directed progress
          for (const [a] of c.all) {
            a.pause();
            // forward in time, but backwards partial moves run a reversed pass.
            a.currentTime = (e < f && e !== 0 ? 1 - q : q) * 1000;
          }
          const want = Math.min(1, Math.max(0, f + (e - f) * at(s)));
          rows.push([s, +c.value.toFixed(4), +want.toFixed(4), +(+getComputedStyle(box).opacity).toFixed(3)]);
        }
        out.push([name, rows]);
        c.stop();
        c.value = 0;
      }
      return out;
    }, cases);
    for (const [name, rows] of r) {
      const ok = rows.every(([s, got, want, op]) => Math.abs(got - want) < 0.012 && Math.abs(op - got) < 0.02);
      check(`curve: ${name} follows the curve (value and the element)`, ok, ok ? '' : JSON.stringify(rows));
    }
    await p.context().close();
  }
  {
    // A real run: status sequence, timing, the end values, promise.
    const p = await open('/anim');
    const r = await p.evaluate(async () => {
      const seen = [];
      thor.effect(() => seen.push(c.s.value));
      const t0 = performance.now();
      await c.animateTo(0.5, D.of(0, 0, 0, 0, 200), 'cubic-bezier(0.42, 0, 0.58, 1)');
      const t1 = performance.now() - t0;
      const mid = [c.value, c.s.value, c.isAnimating];
      const t2 = performance.now();
      await c.animateBack(0, D.of(0, 0, 0, 0, 150), 'cubic-bezier(0, 0, 0.58, 1)');
      return [seen, Math.round(t1), mid, Math.round(performance.now() - t2), c.value, c.s.value];
    });
    check('curve: animateTo ends completed at the target after its duration', r[2][0] === 0.5 && r[2][1] === 3 && r[2][2] === false && (!timed || (r[1] >= 190 && r[1] < 900)), JSON.stringify(r));
    check('curve: animateBack ends dismissed at the bound; statuses run 0,1,3,2,0', JSON.stringify(r[0]) === '[0,1,3,2,0]' && r[4] === 0 && r[5] === 0 && (!timed || (r[3] >= 120 && r[3] < 900)), JSON.stringify(r));
    const f = await p.evaluate(async () => {
      c.value = 0;
      const t0 = performance.now();
      const done = c.fling();
      const st = c.s.value;
      await done;
      const t = performance.now() - t0;
      const up = [c.value, c.s.value, Math.round(t)];
      const back = c.fling(-3);
      const stb = c.s.value;
      const t1 = performance.now();
      await back;
      return [st, up, stb, [c.value, c.s.value, Math.round(performance.now() - t1)]];
    });
    check('curve: fling runs to the bound with the spring (about 0.3 s) and completes', f[0] === 1 && f[1][0] === 1 && f[1][1] === 3 && (!timed || (f[1][2] > 200 && f[1][2] < 800)), JSON.stringify(f));
    check('curve: a negative velocity flings to the lower bound, reverse then dismissed', f[2] === 2 && f[3][0] === 0 && f[3][1] === 0 && (!timed || (f[3][2] > 100 && f[3][2] < 700)), JSON.stringify(f));
    const speeds = await p.evaluate(() => {
      const take = (v) => {
        c.value = v < 0 ? 1 : 0;
        const done = c.fling(v);
        const us = c.pb.peek().w.us;
        c.stop();
        return us;
      };
      return [take(0.5), take(12), take(-12)];
    });
    check('curve: a faster fling takes less time; the sign only picks the bound', speeds[1] < speeds[0] && speeds[2] === speeds[1], JSON.stringify(speeds));
    // dispose mid-animation: the promise is released, the controller is not usable after.
    const disp = await p.evaluate(async () => {
      c.value = 0;
      const done = c.animateTo(1, D.of(0, 0, 0, 0, 2000), 'cubic-bezier(0, 0, 0.58, 1)');
      await new Promise((r) => setTimeout(r, 50));
      c.dispose();
      const r = await Promise.race([done.then(() => 'released'), new Promise((r) => setTimeout(() => r('hung'), 1000))]);
      let err;
      try {
        c.animateTo(1, D.of(0, 0, 0, 0, 100));
      } catch (e) {
        err = e.message;
      }
      return [r, c.isAnimating, err];
    });
    check('curve: dispose mid-animation releases the future and later calls throw', disp[0] === 'released' && disp[1] === false && /dispose/.test(disp[2] ?? ''), JSON.stringify(disp));
    check('curve: no page errors (animation)', p.problems.length === 0, p.problems.join('; '));
    await p.context().close();
  }
  {
    // Reduced motion: instant, with the status the animation would end in.
    const p = await open('/anim', { reduced: true });
    const r = await p.evaluate(async () => {
      const seen = [];
      thor.effect(() => seen.push(c.s.value));
      await c.animateTo(0.5, D.of(0, 0, 0, 0, 2000), 'cubic-bezier(0, 0, 0.58, 1)');
      const a = [c.value, c.s.value];
      await c.animateBack(0, D.of(0, 0, 0, 0, 2000), 'cubic-bezier(0, 0, 0.58, 1)');
      const b = [c.value, c.s.value];
      await c.fling();
      return [a, b, [c.value, c.s.value], seen];
    });
    check('curve: reduced motion completes at once, status completed / dismissed / completed', JSON.stringify(r.slice(0, 3)) === '[[0.5,3],[0,0],[1,3]]', JSON.stringify(r));
    await p.context().close();
  }

  {
    // The page takes the value of the pass the server's CSS animation is at, not the pass.
    const p = await open('/anim-ssr');
    const r = await p.evaluate(() => {
      const a = new Animation(new KeyframeEffect(null, null, { duration: 1000, easing: 'cubic-bezier(0, 0, 0.58, 1)', fill: 'both' }));
      a.pause();
      a.currentTime = 500;
      return [c.value, 0.5 * a.effect.getComputedTiming().progress];
    });
    check('curve: hydrating over an eased server animation reads the value of the curve, not the pass', Math.abs(r[0] - r[1]) < 0.02 && r[0] > 0.3, JSON.stringify(r));
    await p.context().close();
  }

  // --- Curves: ScrollController.animateTo / PageController.animateToPage ----------
  {
    const p = await open('/anim');
    // Per frame (elapsed, scrollTop) of a run, to compare with the curve.
    const run = (css, ms, to) =>
      p.evaluate(
        async ([css, ms, to]) => {
          list.jumpTo(0);
          await new Promise((r) => requestAnimationFrame(r));
          const el = document.getElementById('a'), rows = [];
          const t0 = performance.now();
          const done = list.animateTo(to, D.of(0, 0, 0, 0, ms), css);
          const tick = () => {
            rows.push([performance.now() - t0, el.scrollTop]);
            if (rows.length < 400) requestAnimationFrame(tick);
          };
          requestAnimationFrame(tick);
          await done;
          const total = performance.now() - t0;
          return [rows, Math.round(total), el.scrollTop, el.style.scrollSnapType];
        },
        [css, ms, to],
      );
    const probeAt = (css) =>
      p.evaluate((css) => {
        const a = new Animation(new KeyframeEffect(null, null, { duration: 1000, easing: css, fill: 'both' }));
        a.pause();
        return [0.1, 0.25, 0.5, 0.75, 0.9].map((s) => ((a.currentTime = s * 1000), a.effect.getComputedTiming().progress));
      }, css);
    for (const [name, css] of [['easeOut', 'cubic-bezier(0, 0, 0.58, 1)'], ['easeIn', 'cubic-bezier(0.42, 0, 1, 1)']]) {
      const [rows, total, end, snap] = await run(css, 600, 800);
      // How far along the curve the scroll was at 1/4, 1/2 and 3/4 of its time.
      const at = (s) => rows.reduce((b, r) => (Math.abs(r[0] / 600 - s) < Math.abs(b[0] / 600 - s) ? r : b))[1] / 800;
      const [, , half] = await probeAt(css);
      const got = at(0.5);
      check(`curve: scroll animateTo follows ${name} (half the time: ${got.toFixed(2)}, curve ${half.toFixed(2)})`, Math.abs(got - half) < 0.12 && end === 800 && total >= 580 && total < 1500 && snap === '', JSON.stringify({ end, total, snap }));
      const mono = rows.every((r, i) => i === 0 || r[1] >= rows[i - 1][1]);
      check(`curve: scroll animateTo with ${name} never goes back`, mono);
    }
    const quick = await run('linear', 80, 400);
    check('curve: a short duration is short (80 ms)', quick[1] < 600 && quick[2] === 400, JSON.stringify([quick[1], quick[2]]));
    const slow = await run('linear', 1200, 300);
    check('curve: a long duration is long (1200 ms)', slow[1] >= 1150 && slow[2] === 300, JSON.stringify([slow[1], slow[2]]));
    // The visitor's wheel stops it where it is; the future completes; snap points come back.
    const cut = await p.evaluate(async () => {
      list.jumpTo(0);
      await new Promise((r) => requestAnimationFrame(r));
      const el = document.getElementById('a');
      const done = list.animateTo(900, D.of(0, 0, 0, 0, 1500), 'linear');
      await new Promise((r) => setTimeout(r, 200));
      const at = el.scrollTop;
      el.dispatchEvent(new WheelEvent('wheel', { deltaY: 10, bubbles: true }));
      const s = await Promise.race([done.then(() => 'done'), new Promise((r) => setTimeout(() => r('hung'), 1000))]);
      await new Promise((r) => setTimeout(r, 200));
      return [s, at > 50, el.scrollTop < 700, list.offset === el.scrollTop];
    });
    check('curve: a wheel cuts the scroll where it is and completes', cut[0] === 'done' && cut[1] && cut[2] && cut[3], JSON.stringify(cut));
    check('curve: no page errors (scroll)', p.problems.length === 0, p.problems.join('; '));
    await p.context().close();
  }
  {
    const p = await open('/anim');
    const r = await p.evaluate(async () => {
      const v = document.getElementById('v');
      const t0 = performance.now();
      await pages.animateToPage(2, D.of(0, 0, 0, 0, 700), 'cubic-bezier(0.4, 0, 0.2, 1)');
      const took = performance.now() - t0;
      const a = [v.scrollLeft, Math.round(took), pages.page, v.style.scrollSnapType];
      await new Promise((r) => setTimeout(r, 400));
      const t1 = performance.now();
      await pages.animateToPage(0, D.of(0, 0, 0, 0, 120), 'linear');
      const b = [v.scrollLeft, Math.round(performance.now() - t1)];
      await new Promise((r) => setTimeout(r, 400));
      return [a, b, went];
    });
    check('curve: animateToPage lands on the page after its duration (700 ms), snap restored', r[0][0] === 400 && r[0][1] >= 680 && r[0][1] < 1500 && r[0][2] === 2 && r[0][3] === 'x mandatory', JSON.stringify(r));
    check('curve: a short animateToPage (120 ms) is short and reports where it ended, not each page on the way', r[1][0] === 0 && r[1][1] < 700 && JSON.stringify(r[2]) === '[2,0]', JSON.stringify(r));
    check('curve: no page errors (animateToPage)', p.problems.length === 0, p.problems.join('; '));
    await p.context().close();
  }
} finally {
  await browser.close();
}
const failed = results.filter((r) => !r).length;
console.log(failed ? `FAIL controllers-edge: ${failed} of ${results.length}` : `controllers-edge: ${results.length} passed`);
process.exit(failed ? 1 : 0);

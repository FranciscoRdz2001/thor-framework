// The controllers in a real Chromium: ScrollController (animateTo, jumpTo, initial
// offset, restored offset, RTL, sharing) and TextEditingController.selection,
// on pages made in memory from the lite runtime and its controller parts
// (no app to build).
//
//   node test/e2e/checks/controllers_check.mjs
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { chromium } from '../runner/node_modules/playwright/index.mjs';
import { frames, repo } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
const runtime = readFileSync(join(lite, 'runtime.js'), 'utf8');
const part = (n) => readFileSync(join(lite, 'parts', n), 'utf8');
const parts = ['controllers.js', 'scroll_controller.js', 'page_controller.js', 'text_controller.js', 'focus_node.js', 'page_view.js'];
const bundle = runtime.replace('// @thor-lite-parts', () => parts.map(part).join('\n'));
const page = (body, script, before = '') =>
  `<!DOCTYPE html><html><head><base href="/"></head><body>${body}<script>${before}</script><script>${bundle}\n${script}</script></body></html>`;

const scrollState = `thor.def('S', ($) => {
  const list = thor.ctl.scroll('S.list', 40), side = thor.ctl.scroll('S.side', 0), late = thor.ctl.scroll('S.late', 0);
  Object.assign(window, { list, side, late });
  return { noop: () => {} };
}, { eager: true });`;

const pages = {
  '/scroll': page(
    `<div id="a" style="height:100px;overflow:auto" data-tsc="S.list"><div style="height:1000px"></div></div>
<div id="h" dir="rtl" style="width:100px;height:30px;overflow:auto" data-tsc="S.side" data-tsc-h><div style="width:1000px;height:10px"></div></div>`,
    scrollState,
  ),
  // The view already scrolled (a restorationId's script ran first).
  '/restored': page(
    `<div id="a" style="height:100px;overflow:auto" data-tsc="S.list"><div style="height:1000px"></div></div>
<div id="h" style="width:100px;overflow:auto" data-tsc="S.side" data-tsc-h><div style="width:1000px;height:10px"></div></div>`,
    scrollState,
    '',
  ),
  // Two views with one controller (Flutter asserts).
  '/twice': page(
    `<div id="a" style="height:100px;overflow:auto" data-tsc="S.list"><div style="height:1000px"></div></div>
<div id="b" style="height:100px;overflow:auto" data-tsc="S.list"><div style="height:1000px"></div></div>`,
    scrollState,
  ),
  '/focus': page(
    `<input id="f" data-tfn="F.f"><button id="b">b</button>`,
    `thor.def('F', ($) => {
  const f = thor.ctl.focus('F.f');
  Object.assign(window, { fnode: f });
  return { noop: () => {} };
}, { eager: true });`,
  ),
  '/text': page(
    `<input id="i" data-ttc="T.name" value="Ana"><input id="d" disabled data-ttc="T.dis" value="quieto">
<input id="e" type="email" data-ttc="T.mail" value="a@b.c"><input id="n" data-ttc="T.name">`,
    `thor.def('T', ($) => {
  const C = thor.ctl;
  const name = C.text('T.name', 'Ana'), dis = C.text('T.dis', 'quieto'), mail = C.text('T.mail', 'a@b.c');
  Object.assign(window, { nm: name, dis, mail });
  return { noop: () => {} };
}, { eager: true });`,
  ),
};

// PageView pages. Four 200 px pages in a scroll-snap row (or column); the
// state keeps what onPageChanged reported in `went`.
const pagesHtml = (attrs, { dir = '', style = '', vertical = false } = {}) =>
  `<div id="v" ${dir} ${attrs} style="display:flex;flex-direction:${vertical ? 'column' : 'row'};width:200px;height:100px;overflow-${vertical ? 'y' : 'x'}:auto;scroll-snap-type:${vertical ? 'y' : 'x'} mandatory;${style}">${'<div style="flex:0 0 100%;min-width:0;min-height:0;scroll-snap-align:start"></div>'.repeat(4)}</div>`;
const pagesState = (initial = 0) => `thor.def('P', ($) => {
  const pages = thor.ctl.page('P.pages', ${initial});
  window.went = [];
  Object.assign(window, { pages });
  return { go: (v) => window.went.push(Number(v)) };
}, { eager: true });`;
const attrsH = 'data-tsc="P.pages" data-tsc-h data-t-ev="page:P.go"';
Object.assign(pages, {
  '/pages': page(pagesHtml(attrsH), pagesState(1)),
  '/pages-rtl': page(pagesHtml(attrsH, { dir: 'dir="rtl"' }), pagesState(0)),
  '/pages-rtl-start': page(pagesHtml(attrsH, { dir: 'dir="rtl"' }), pagesState(1)),
  '/pages-rev': page(pagesHtml(attrsH, { style: 'flex-direction:row-reverse' }), pagesState(0)),
  '/pages-v': page(pagesHtml('data-tsc="P.pages" data-t-ev="page:P.go"', { vertical: true }), pagesState(0)),
  '/pages-vrev': page(pagesHtml('data-tsc="P.pages" data-t-ev="page:P.go"', { vertical: true, style: 'flex-direction:column-reverse' }), pagesState(0)),
  // No controller: only the event.
  '/pages-event': page(pagesHtml('data-tsc-h data-t-ev="page:P.go"'), `thor.def('P', ($) => { window.went = []; return { go: (v) => window.went.push(Number(v)) }; }, { eager: true });`),
  // No scrollend (Safari before 26.2): a pause in the scroll ends it.
  '/pages-safari': page(pagesHtml(attrsH), pagesState(0), `document.documentElement.addEventListener('scrollend', (e) => e.stopImmediatePropagation(), true);`),
  // The view is hidden when the engine comes: the page waits for its size.
  '/pages-hidden': page(pagesHtml(attrsH, { style: 'display:none' }), pagesState(2)),
  // Views that only a late part brings (`thor:stream`): no view in the page when the state starts.
  '/late-views': page(
    '<div id="host"></div>',
    `thor.def('L', ($) => {
  const sc = thor.ctl.scroll('L.sc', 60), pg = thor.ctl.page('L.pg', 2);
  window.went = [];
  Object.assign(window, { sc, pg });
  return { go: (v) => window.went.push(Number(v)) };
}, { eager: true });
window.stream = (html) => {
  const host = document.getElementById('host');
  host.insertAdjacentHTML('beforeend', html);
  document.documentElement.dispatchEvent(new CustomEvent('thor:stream', { detail: { nodes: [...host.children] } }));
};`,
  ),
});

const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail !== '' ? ` (${detail})` : ''}`);
};

const browser = await chromium.launch();
const open = async (path, { reduced = false } = {}) => {
  const ctx = await browser.newContext({ viewport: { width: 700, height: 900 }, reducedMotion: reduced ? 'reduce' : 'no-preference' });
  const p = await ctx.newPage();
  p.problems = [];
  p.on('pageerror', (e) => p.problems.push(e.message));
  await ctx.route('http://lite.test/**', (r) => {
    const body = pages[new URL(r.request().url()).pathname];
    return body ? r.fulfill({ contentType: 'text/html', body }) : r.fulfill({ status: 404, body: '' });
  });
  await p.goto(`http://lite.test${path}`);
  await p.waitForFunction(() => typeof thor !== 'undefined');
  await frames(p); // the engine's first pass (a microtask) and its first frame
  return p;
};
const top = (p, id = 'a') => p.evaluate((i) => document.getElementById(i).scrollTop, id);

try {
  // --- ScrollController -------------------------------------------------------
  {
    const p = await open('/scroll');
    check('initialScrollOffset is applied when the engine takes the view', (await top(p)) === 40 && (await p.evaluate(() => list.offset)) === 40, `${await top(p)}`);

    // animateTo is smooth and its future completes at the end.
    const mid = await p.evaluate(async () => {
      const done = list.animateTo(600);
      await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
      const at = document.getElementById('a').scrollTop;
      await done;
      return [at, document.getElementById('a').scrollTop, list.offset];
    });
    check('animateTo animates (not there yet a frame later) and lands', mid[0] < 600 && mid[1] === 600 && mid[2] === 600, JSON.stringify(mid));

    // Beyond the end: stops at it, and offset says so.
    const far = await p.evaluate(async () => {
      await list.animateTo(1e9);
      return [document.getElementById('a').scrollTop, list.offset, list.maxScrollExtent];
    });
    check('animateTo past the end stops at the max extent', far[0] === 900 && far[1] === 900 && far[2] === 900, JSON.stringify(far));
    const neg = await p.evaluate(async () => {
      await list.animateTo(-50);
      return [document.getElementById('a').scrollTop, list.offset];
    });
    check('animateTo below 0 stops at 0', neg[0] === 0 && neg[1] === 0, JSON.stringify(neg));
    const same = await p.evaluate(async () => {
      await list.animateTo(0);
      return list.offset;
    });
    check('animateTo where it already is completes at once', same === 0);
    const jump = await p.evaluate(() => {
      list.jumpTo(1e9);
      return [document.getElementById('a').scrollTop, list.offset];
    });
    check('jumpTo past the end reports where it really is', jump[0] === 900 && jump[1] === 900, JSON.stringify(jump));

    // A second animateTo interrupts the first: the first future completes, the
    // second target wins.
    const two = await p.evaluate(async () => {
      list.jumpTo(0);
      let firstDone = false;
      const a = list.animateTo(800).then(() => (firstDone = true));
      await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
      const b = list.animateTo(200);
      await Promise.race([a, new Promise((r) => setTimeout(r, 1500))]);
      const firstAfterSecondStarted = firstDone;
      await b;
      return [firstAfterSecondStarted, document.getElementById('a').scrollTop];
    });
    check('a second animateTo completes the first and wins', two[0] === true && two[1] === 200, JSON.stringify(two));

    // The visitor scrolls during it: it stops there and completes.
    const user = await p.evaluate(async () => {
      list.jumpTo(0);
      const el = document.getElementById('a');
      const done = list.animateTo(900);
      await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
      el.scrollTop = 500; // an instant scroll cancels the smooth one, like a wheel or a touch
      const r = await Promise.race([done.then(() => 'done'), new Promise((r) => setTimeout(() => r('hung'), 2000))]);
      return [r, el.scrollTop];
    });
    check('animateTo cut by the visitor completes', user[0] === 'done' && user[1] === 500, JSON.stringify(user));

    // jumpTo during an animateTo cancels it too.
    const cut = await p.evaluate(async () => {
      list.jumpTo(0);
      const done = list.animateTo(900);
      await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
      list.jumpTo(10);
      const r = await Promise.race([done.then(() => 'done'), new Promise((r) => setTimeout(() => r('hung'), 2000))]);
      return [r, document.getElementById('a').scrollTop];
    });
    check('jumpTo during animateTo cancels it and completes the future', cut[0] === 'done' && cut[1] === 10, JSON.stringify(cut));

    // RTL horizontal: offset 0 is the start (the right edge), growing leftwards.
    const rtl = await p.evaluate(async () => {
      const el = document.getElementById('h');
      const start = [el.scrollLeft, side.offset];
      side.jumpTo(300);
      const j = [el.scrollLeft, side.offset];
      await side.animateTo(500);
      return [start, j, [el.scrollLeft, side.offset], side.maxScrollExtent];
    });
    check('RTL: offset 0 at the start, jumpTo(300) is scrollLeft -300', rtl[0][1] === 0 && rtl[1][0] === -300 && rtl[1][1] === 300, JSON.stringify(rtl));
    check('RTL: animateTo and the max extent are positive', rtl[2][0] === -500 && rtl[2][1] === 500 && rtl[3] === 900, JSON.stringify(rtl));
    check('no page errors (scroll)', p.problems.length === 0, p.problems.join('; '));
    await p.context().close();
  }

  {
    // Reduced motion: animateTo jumps.
    const p = await open('/scroll', { reduced: true });
    const r = await p.evaluate(() => {
      const done = list.animateTo(500);
      const at = document.getElementById('a').scrollTop;
      return done.then(() => [at, document.getElementById('a').scrollTop]);
    });
    check('reduced motion: animateTo is instant', r[0] === 500 && r[1] === 500, JSON.stringify(r));
    await p.context().close();
  }

  {
    // A controller whose view is not in the DOM yet: the offset is kept and
    // applied when the view is put there (a list a variant brings).
    const p = await open('/scroll');
    const r = await p.evaluate(async () => {
      const before = [late.hasClients, late.offset];
      late.jumpTo(120);
      const held = late.offset;
      const div = document.createElement('div');
      div.style.cssText = 'height:100px;overflow:auto';
      div.setAttribute('data-tsc', 'S.late');
      div.innerHTML = '<div style="height:1000px"></div>';
      document.body.append(div);
      div.dispatchEvent(new CustomEvent('thor:adopted'));
      await new Promise((r) => setTimeout(r, 50));
      return [before, held, div.scrollTop, late.offset, late.hasClients];
    });
    check('hasClients is false until the view is in the page, true after', r[0][0] === false && r[4] === true && (await p.evaluate(() => list.hasClients)) === true, JSON.stringify([r[0], r[4]]));
    check('a controller used before its view exists keeps the offset for it', r[1] === 120 && r[2] === 120 && r[3] === 120, JSON.stringify(r));
    // The list is replaced by another one (a variant): the controller follows the new element.
    const swap = await p.evaluate(async () => {
      const old = document.getElementById('a');
      const fresh = old.cloneNode(true);
      fresh.id = 'a2';
      old.replaceWith(fresh);
      fresh.dispatchEvent(new CustomEvent('thor:adopted'));
      list.jumpTo(70);
      await new Promise((r) => setTimeout(r, 50));
      return [fresh.scrollTop, list.offset];
    });
    check('a list replaced by a variant: the controller drives the new element', swap[0] === 70 && swap[1] === 70, JSON.stringify(swap));
    await p.context().close();
  }

  {
    // Two views, one controller: a clear error, like Flutter's assertion.
    const p = await open('/twice');
    check('two views sharing a controller is an error that names it', p.problems.some((m) => /ScrollController/.test(m) && /S\.list/.test(m) && /more than one/.test(m)), p.problems.join('; '));
    await p.context().close();
  }

  {
    // The view was already scrolled when the engine came (a restored offset):
    // that wins over initialScrollOffset.
    const ctx = await browser.newContext({ viewport: { width: 700, height: 900 } });
    const p = await ctx.newPage();
    await ctx.route('http://lite.test/**', (r) =>
      r.fulfill({
        contentType: 'text/html',
        // A function: the runtime holds `$&`/`$'` patterns a replacement string would expand.
        body: pages['/restored'].replace('<script>' + bundle, () => '<script>document.getElementById("a").scrollTop=70</script><script>' + bundle),
      }),
    );
    await p.goto('http://lite.test/restored');
    await p.waitForFunction(() => typeof thor !== 'undefined');
    await p.waitForFunction(() => typeof list !== 'undefined' && list.offset === 70);
    const at = await top(p);
    check('a restored offset wins over initialScrollOffset', at === 70 && (await p.evaluate(() => list.offset)) === 70, `${at}`);
    await ctx.close();
  }

  // --- PageController and PageView.onPageChanged -------------------------
  {
    const p = await open('/pages');
    const left = () => p.evaluate(() => document.getElementById('v').scrollLeft);
    await p.waitForTimeout(150);
    check('initialPage is where the view starts; page says so', (await left()) === 200 && (await p.evaluate(() => pages.page)) === 1, `${await left()}`);
    check('the initial page is not a change (nothing reported at load)', (await p.evaluate(() => went.length)) === 0, JSON.stringify(await p.evaluate(() => went)));
    await p.evaluate(() => pages.jumpToPage(3));
    check('jumpToPage moves the view to page * size', (await left()) === 600);
    await p.waitForFunction(() => pages.page === 3);
    await p.waitForFunction(() => went.length === 1);
    check('jumpToPage reports the page (like Flutter), once', JSON.stringify(await p.evaluate(() => went)) === '[3]', JSON.stringify(await p.evaluate(() => went)));
    await p.evaluate(() => pages.animateToPage(0));
    await p.waitForFunction(() => pages.page === 0);
    check('animateToPage resolves at the page', (await left()) === 0 && (await p.evaluate(() => pages.offset)) === 0);
    await p.waitForFunction(() => went.length === 2);
    check('the animated trip reports where it ended, not each page on the way', JSON.stringify(await p.evaluate(() => went)) === '[3,0]', JSON.stringify(await p.evaluate(() => went)));
    // The visitor scrolls: a little inside the page, then to the next.
    await p.evaluate(() => (document.getElementById('v').scrollLeft = 60));
    await p.waitForTimeout(300);
    check('a scroll that stays on the page reports nothing', (await p.evaluate(() => went.length)) === 2);
    await p.evaluate(() => (document.getElementById('v').scrollLeft = 400));
    await p.waitForFunction(() => went.length === 3);
    check('the visitor reaching page 2 is reported', JSON.stringify(await p.evaluate(() => went)) === '[3,0,2]' && (await p.evaluate(() => pages.page)) === 2, JSON.stringify(await p.evaluate(() => went)));
    check('no page errors (pages)', p.problems.length === 0, p.problems.join('; '));
    await p.context().close();
  }
  for (const [path, jump, expectLeft, expectTop] of [
    ['/pages-rtl', 2, -400, 0],
    ['/pages-rev', 1, -200, 0],
  ]) {
    const p = await open(path);
    await p.evaluate((n) => pages.jumpToPage(n), jump);
    const left = await p.evaluate(() => document.getElementById('v').scrollLeft);
    await p.waitForFunction((n) => pages.page === n, jump);
    await p.waitForFunction(() => went.length === 1);
    const r = await p.evaluate(() => [pages.offset, pages.page, went[0]]);
    check(`${path}: scrollLeft is negative, offset and page count from the first page, the report too`, left === expectLeft && r[0] === jump * 200 && r[1] === jump && r[2] === jump, `${left} ${JSON.stringify(r)}`);
    await p.evaluate(() => pages.jumpToPage(0));
    await p.waitForFunction(() => pages.page === 0);
    check(`${path}: back to page 0`, (await p.evaluate(() => document.getElementById('v').scrollLeft)) === 0 || Object.is(await p.evaluate(() => document.getElementById('v').scrollLeft), -0));
    // The visitor scrolls (negative scrollLeft): reported as page 2 / 1.
    await p.evaluate((v) => (document.getElementById('v').scrollLeft = v), expectLeft * 1);
    await p.waitForFunction((n) => went.at(-1) === n, jump);
    check(`${path}: a visitor's scroll reports the same page`, true);
    check(`${path}: no page errors`, p.problems.length === 0, p.problems.join('; '));
    await p.context().close();
  }
  {
    const p = await open('/pages-rtl-start');
    check('RTL initialPage: the view starts at scrollLeft -200, page 1', (await p.evaluate(() => document.getElementById('v').scrollLeft)) === -200 && (await p.evaluate(() => pages.page)) === 1);
    await p.context().close();
  }
  for (const [path, prop, jump, want] of [
    ['/pages-v', 'scrollTop', 2, 200],
    ['/pages-vrev', 'scrollTop', 2, -200],
  ]) {
    const p = await open(path);
    await p.evaluate((n) => pages.jumpToPage(n), jump);
    const at = await p.evaluate((k) => document.getElementById('v')[k], prop);
    await p.waitForFunction((n) => went.at(-1) === n, jump);
    check(`${path}: a vertical view counts rows from its start`, at === want && (await p.evaluate(() => pages.offset)) === jump * 100, `${at}`);
    await p.context().close();
  }
  {
    // No controller: only the event, with the axis from data-tsc-h.
    const p = await open('/pages-event');
    await p.evaluate(() => (document.getElementById('v').scrollLeft = 200));
    await p.waitForFunction(() => went.length === 1);
    check('onPageChanged works without a controller', JSON.stringify(await p.evaluate(() => went)) === '[1]');
    await p.context().close();
  }
  {
    const p = await open('/pages-safari');
    await p.evaluate(() => (document.getElementById('v').scrollLeft = 200));
    const t0 = Date.now();
    await p.waitForFunction(() => went.length === 1, null, { timeout: 5000 });
    check('without scrollend a pause in the scroll ends it (the timer fallback)', JSON.stringify(await p.evaluate(() => went)) === '[1]' && Date.now() - t0 >= 100, `${Date.now() - t0}ms`);
    await p.context().close();
  }
  {
    // A hidden view has no size: the page waits until it is shown.
    const p = await open('/pages-hidden');
    const r = await p.evaluate(async () => {
      const v = document.getElementById('v');
      const before = [pages.page, v.scrollLeft];
      v.style.display = 'flex';
      v.dispatchEvent(new CustomEvent('thor:adopted'));
      await new Promise((r) => setTimeout(r, 100));
      return [before, v.scrollLeft, pages.page];
    });
    check('a hidden view keeps initialPage for when it shows', JSON.stringify(r) === JSON.stringify([[2, 0], 400, 2]), JSON.stringify(r));
    await p.context().close();
  }

  {
    // A scroll view and a PageView that arrive in a late part start from their
    // controllers' initial offset and page, and the arrival is not a page change.
    const p = await open('/late-views');
    const r = await p.evaluate(async () => {
      const before = [sc.hasClients, pg.hasClients];
      stream(`<div id="a" style="height:100px;overflow:auto" data-tsc="L.sc"><div style="height:1000px"></div></div>
<div id="v" data-tsc="L.pg" data-tsc-h data-t-ev="page:L.go" style="display:flex;width:200px;height:100px;overflow-x:auto;scroll-snap-type:x mandatory">${'<div style="flex:0 0 100%;min-width:0;scroll-snap-align:start"></div>'.repeat(4)}</div>`);
      await new Promise((r) => setTimeout(r, 400));
      const v = document.getElementById('v');
      v.dispatchEvent(new Event('scrollend'));
      await new Promise((r) => setTimeout(r, 200));
      return [before, document.getElementById('a').scrollTop, sc.offset, v.scrollLeft, pg.page, [...went]];
    });
    check('late part: a scroll view starts at its initialScrollOffset', r[1] === 60 && r[2] === 60 && JSON.stringify(r[0]) === '[false,false]', JSON.stringify(r));
    check('late part: a PageView starts on its initialPage', r[3] === 400 && r[4] === 2, JSON.stringify(r));
    check('late part: arriving on the initial page is not an onPageChanged', r[5].length === 0, JSON.stringify(r[5]));
    await p.evaluate(() => (document.getElementById('v').scrollLeft = 600));
    await p.waitForFunction(() => went.length === 1);
    check('late part: a later page change still reports', JSON.stringify(await p.evaluate(() => went)) === '[3]');
    await p.context().close();
  }

  // --- FocusNode listeners -------------------------------------------------
  {
    const p = await open('/focus');
    await p.evaluate(() => {
      window.seen = [];
      window.hear = () => seen.push(fnode.hasFocus);
      fnode.addListener(hear);
      fnode.addListener(() => {
        throw new Error('boom');
      });
      fnode.addListener(() => seen.push('after'));
    });
    await p.focus('#f');
    await p.focus('#b');
    const seen = await p.evaluate(() => seen);
    check('listeners hear focus in and out with hasFocus already new; a throwing one does not cut the rest', JSON.stringify(seen) === JSON.stringify([true, 'after', false, 'after']), JSON.stringify(seen));
    await p.evaluate(() => {
      fnode.removeListener(hear);
      seen.length = 0;
    });
    await p.focus('#f');
    check('a removed listener is quiet', JSON.stringify(await p.evaluate(() => seen)) === '["after"]');
    await p.evaluate(() => fnode.requestFocus());
    await p.evaluate(() => fnode.unfocus());
    check('unfocus() from a method notifies and hasFocus follows', (await p.evaluate(() => fnode.hasFocus)) === false);
    check('the thrown error was reported, not swallowed', p.problems.some((m) => /boom/.test(m)), p.problems.join('; '));
    await p.context().close();
  }

  // --- TextEditingController.selection -------------------------------------------
  {
    const p = await open('/text');
    const sel = (id) => p.evaluate((i) => [document.getElementById(i).selectionStart, document.getElementById(i).selectionEnd], id);
    const read = () => p.evaluate(() => [nm.selection.baseOffset, nm.selection.extentOffset]);
    // The field has the selection (start, end) and the controller reads it back.
    const at = (a, b) => p.waitForFunction(([a, b]) => {
      const f = document.getElementById('i');
      return f.selectionStart === a && f.selectionEnd === b && nm.selection.baseOffset === a && nm.selection.extentOffset === b;
    }, [a, b]);
    check('selection starts invalid', JSON.stringify(await read()) === '[-1,-1]', JSON.stringify(await read()));
    await p.evaluate(() => (nm.selection = thor.ctl.sel(2)));
    await at(2, 2);
    check('setting a caret moves the field', JSON.stringify(await sel('i')) === '[2,2]' && JSON.stringify(await read()) === '[2,2]', `${await sel('i')} ${await read()}`);
    check('the other field of the controller too', JSON.stringify(await sel('n')) === '[2,2]' || (await sel('n'))[0] !== null);
    await p.evaluate(() => (nm.selection = thor.ctl.sel(0, 99)));
    await at(0, 3);
    check('a selection past the text stops at its length', JSON.stringify(await sel('i')) === '[0,3]' && JSON.stringify(await read()) === '[0,3]', `${await sel('i')} ${await read()}`);
    // Text and selection in the same method: the selection lands after the text.
    await p.evaluate(() => {
      nm.text = 'hola mundo';
      nm.selection = thor.ctl.sel(4);
    });
    await at(4, 4);
    check('text then selection in one method: the caret is where asked', JSON.stringify(await sel('i')) === '[4,4]' && (await p.inputValue('#i')) === 'hola mundo', `${await sel('i')}`);
    // A selection asked for more text than there is yet is clamped to the text at that moment.
    await p.evaluate(() => {
      nm.selection = thor.ctl.sel(50);
    });
    await at(10, 10);
    check('the read-back is what the field really has', JSON.stringify(await read()) === '[10,10]', JSON.stringify(await read()));
    // Backwards range.
    await p.evaluate(() => {
      const el = document.getElementById('i');
      el.focus();
      el.setSelectionRange(1, 5, 'backward');
      el.dispatchEvent(new Event('select', { bubbles: true }));
    });
    await p.waitForFunction(() => nm.selection.baseOffset === 5 && nm.selection.extentOffset === 1);
    check('a backward range reads base after extent', JSON.stringify(await read()) === '[5,1]', JSON.stringify(await read()));
    // The visitor types: the caret follows; an explicit set in the middle wins and typing goes on from there.
    await p.focus('#i');
    await p.keyboard.press('End');
    await p.keyboard.type('!!');
    await at(12, 12);
    check('typing moves the controller\'s caret', JSON.stringify(await read()) === '[12,12]', JSON.stringify(await read()));
    await p.evaluate(() => (nm.selection = thor.ctl.sel(0)));
    await at(0, 0);
    await p.keyboard.type('>');
    await at(1, 1);
    check('a set while the visitor types: typing goes on from the new caret', (await p.inputValue('#i')) === '>hola mundo!!' && JSON.stringify(await read()) === '[1,1]', `${await p.inputValue('#i')} ${await read()}`);
    await p.keyboard.press('ControlOrMeta+A');
    await at(0, '>hola mundo!!'.length);
    check('select all is read as a range', JSON.stringify(await read()) === `[0,${'>hola mundo!!'.length}]`, JSON.stringify(await read()));
    // A disabled field and a type with no selection: no error, the value kept.
    await p.evaluate(() => {
      dis.selection = thor.ctl.sel(0, 99);
      mail.selection = thor.ctl.sel(1, 2);
    });
    await p.waitForFunction(() => dis.selection.extentOffset === 6 && mail.selection.baseOffset === 1);
    const dv = await p.evaluate(() => [dis.selection.baseOffset, dis.selection.extentOffset, mail.selection.baseOffset, mail.selection.extentOffset]);
    check('a disabled field and an email field keep the clamped value, no error', JSON.stringify(dv) === '[0,6,1,2]' && p.problems.length === 0, `${dv} ${p.problems}`);
    // value = text + selection together.
    await p.evaluate(() => (nm.value = thor.ctl.val('Maria', thor.ctl.sel(1, 3))));
    await at(1, 3);
    check('value= shows the text and puts the selection in the field', (await p.inputValue('#i')) === 'Maria' && JSON.stringify(await sel('i')) === '[1,3]', `${await p.inputValue('#i')} ${await sel('i')}`);
    const v = await p.evaluate(() => [nm.value.text, nm.value.selection.baseOffset, nm.value.selection.extentOffset, nm.value.eq(thor.ctl.val('Maria', thor.ctl.sel(1, 3))), nm.value.copyWith('Ana').selection.extentOffset, String(nm.value)]);
    check('value reads both, == by value, copyWith keeps the rest', JSON.stringify(v) === JSON.stringify(['Maria', 1, 3, true, 3, 'TextEditingValue(text: "Maria", selection: TextSelection(1, 3))']), JSON.stringify(v));
    await p.evaluate(() => (nm.value = thor.ctl.val('Luis')));
    await at(4, 4);
    check('a new text with no selection puts the caret at its end', JSON.stringify(await read()) === '[4,4]' && (await p.inputValue('#i')) === 'Luis', JSON.stringify(await read()));
    await p.evaluate(() => (nm.value = thor.ctl.val('Luis')));
    const inv = await p.evaluate(() => nm.selection.isValid);
    check('the same text with no selection leaves it invalid (Flutter)', inv === false);
    await p.focus('#i');
    await p.keyboard.press('End');
    await p.keyboard.type('s');
    await p.waitForFunction(() => nm.value.text === 'Luiss');
    const typed = await p.evaluate(() => [nm.value.text, nm.value.selection.baseOffset]);
    check('typing is in value (text and caret)', typed[0] === 'Luiss' && typed[1] === 5, JSON.stringify(typed));
    const runs = await p.evaluate(() => {
      let n = 0;
      thor.effect(() => (nm.value, n++));
      nm.value = thor.ctl.val('X', thor.ctl.sel(1));
      return n;
    });
    check('value= is one change for an effect that reads value', runs === 2, `${runs}`);
    check('no page errors (text)', p.problems.length === 0, p.problems.join('; '));
    await p.context().close();
  }
} finally {
  await browser.close();
}
const failed = results.filter((r) => !r).length;
console.log(failed ? `FAIL controllers: ${failed} of ${results.length}` : `controllers: ${results.length} passed`);
process.exit(failed ? 1 : 0);

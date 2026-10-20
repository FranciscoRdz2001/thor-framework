// ReorderableListView in the lite engine (parts/drag_kit.js and
// parts/reorderable.js) on a page made in memory from lib/lite/runtime.js and
// the markup thor_ui writes: the same cases as the dart2js feature's browser
// test (packages/thor_engine_oracle/test/reorderable_client_test.dart). Chromium,
// Firefox and WebKit (E2E_BROWSER).
//
//   node test/e2e/checks/lite_reorder_check.mjs
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import * as engines from '../runner/node_modules/playwright/index.mjs';
import { browsersFor, repo } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
const runtime = readFileSync(join(lite, 'runtime.js'), 'utf8');
const part = (n) => readFileSync(join(lite, 'parts', n), 'utf8');
const bundle = (...parts) => runtime.replace('// @thor-lite-parts', () => parts.map(part).join('\n'));

const css = `<style>[data-t-ro-item]{position:relative;height:40px;margin-bottom:10px;background:#ddd;translate:var(--t-ro-x,0px) var(--t-ro-y,0px)}[data-t-ro-shift],[data-t-ro-settle]{transition:translate 120ms}[data-t-ro-h]{position:absolute;right:0;top:5px;width:30px;height:30px}</style>`;
const items = (n, { handle = 'data-t-ro-h aria-label="Reorder"', extra = '' } = {}) =>
  Array.from({ length: n }, (_, i) => `<div id="i${i + 1}" data-t-ro-item role="listitem">Fila ${i + 1}${extra}<button id="h${i + 1}" type="button" ${handle}>::</button></div>`).join('');
const list = (body, { ids = 'reorder:L.reorder;start:L.start;end:L.end', cfg = 'v|1', extra = '', dir = 'ltr', style = '' } = {}) =>
  `${css}<div id="list" dir="${dir}" data-t-ro="${ids}" data-tx="x" data-t-ro-cfg="${cfg}" style="position:fixed;left:20px;top:20px;width:200px;${style}" ${extra}>${body}</div>`;

const state = `window.log = [];
const rec = (n) => (v) => window.log.push(n + '(' + v + ')');
thor.def('L', () => ({ reorder: rec('reorder'), start: rec('start'), end: rec('end') }));`;
const page = (body) => `<!DOCTYPE html><html><head><base href="/"><meta charset="utf-8"></head><body style="margin:0">${body}<script>${bundle('drag_kit.js', 'reorderable.js')}\n${state}</script></body></html>`;

const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail !== '' ? ` (${detail})` : ''}`);
};

for (const [name, type] of browsersFor([['chromium', 'chromium'], ['firefox', 'firefox'], ['webkit', 'webkit']])) {
  console.log(`▸ ${name}`);
  const browser = await engines[type].launch();
  const open = async (body) => {
    const ctx = await browser.newContext({ viewport: { width: 520, height: 600 } });
    await ctx.route('http://lite.test/**', (r) => r.fulfill({ contentType: 'text/html', body: page(body) }));
    const p = await ctx.newPage();
    p.problems = [];
    p.on('pageerror', (e) => p.problems.push(e.message));
    await p.goto('http://lite.test/');
    await p.waitForFunction(() => typeof thor !== 'undefined');
    return p;
  };
  const log = (p) => p.evaluate(() => window.log.splice(0));
  const wait = (p, ms) => p.waitForTimeout(ms);
  const order = (p) => p.evaluate(() => [...document.querySelector('#list').children].filter((c) => c.hasAttribute('data-t-ro-item')).map((c) => c.id));
  const live = (p) => p.evaluate(() => document.querySelector('[aria-live=assertive]')?.textContent ?? '');
  const until = async (p, fn, arg) => {
    for (let i = 0; i < 300; i++) {
      if (await p.evaluate(fn, arg)) return true;
      await p.waitForTimeout(10);
    }
    return false;
  };
  const pointer = (p, sel, t, x, y, kind = 'mouse') =>
    p.evaluate(([s, t, x, y, k]) => document.querySelector(s).dispatchEvent(new PointerEvent(t, { bubbles: true, cancelable: true, clientX: x, clientY: y, pointerId: 1, pointerType: k, isPrimary: true, button: 0 })), [sel, t, x, y, kind]);
  const key = (p, sel, k, o = {}) => p.evaluate(([s, k, o]) => { const e = new KeyboardEvent('keydown', { key: k, bubbles: true, cancelable: true, ...o }); document.querySelector(s).dispatchEvent(e); return e.defaultPrevented; }, [sel, k, o]);
  const hy = (n) => 20 + 50 * (n - 1) + 20;
  const drag = async (p, n, toY, up = true) => {
    await pointer(p, `#h${n}`, 'pointerdown', 190, hy(n));
    await pointer(p, `#h${n}`, 'pointermove', 190, hy(n) + (toY > hy(n) ? 6 : -6));
    await pointer(p, `#h${n}`, 'pointermove', 190, toY);
    // A frame has run: the dragged item has its offset.
    await until(p, (n) => document.querySelector(`#i${n}`).style.getPropertyValue('--t-ro-y') !== '', n);
    await wait(p, 40);
    if (up) await pointer(p, `#h${n}`, 'pointerup', 190, toY);
  };
  const yvar = (p, sel) => p.evaluate((s) => document.querySelector(s).style.getPropertyValue('--t-ro-y'), sel);
  const attr = (p, sel, a) => p.evaluate(([s, a]) => document.querySelector(s).hasAttribute(a), [sel, a]);

  {
    const p = await open(list(items(4)));
    await drag(p, 1, hy(1) + 110, false);
    check('drag: the item follows the pointer, the ones it passed give way', (await yvar(p, '#i1')) === '110px' && (await yvar(p, '#i2')) === '-50px' && (await yvar(p, '#i3')) === '-50px' && (await yvar(p, '#i4')) === '' && (await attr(p, '#i2', 'data-t-ro-shift')), `${await yvar(p, '#i1')} ${await yvar(p, '#i2')} ${await yvar(p, '#i3')}`);
    check('drag: the item is marked and the state hears the start', (await attr(p, '#i1', 'data-t-ro-drag')) && JSON.stringify(await log(p)) === '["start(x~0)"]');
    await pointer(p, '#i1', 'pointerup', 190, hy(1) + 110);
    check('drop: it settles first, the page has not changed yet', (await attr(p, '#i1', 'data-t-ro-settle')) && JSON.stringify(await order(p)) === '["i1","i2","i3","i4"]');
    check('drop: then the page changes', await until(p, () => document.querySelector('#list').children[2].id === 'i1'), JSON.stringify(await order(p)));
    const l = await log(p);
    check('drop: reorder with Flutter\'s indexes, then the end', JSON.stringify(l) === '["reorder(x~0~3)","end(x~2)"]', JSON.stringify(l));
    check('drop: every offset and mark is gone', await p.evaluate(() => [...document.querySelectorAll('[data-t-ro-item]')].every((e) => !e.style.getPropertyValue('--t-ro-y') && !e.hasAttribute('data-t-ro-shift') && !e.hasAttribute('data-t-ro-settle'))));
    check('no page errors (drag)', p.problems.length === 0, p.problems.join(' | '));
  }
  {
    const p = await open(list(items(4)));
    await drag(p, 3, hy(3) - 110);
    check('up: moves to the top, indexes as Flutter counts them', await until(p, () => document.querySelector('#list').children[0].id === 'i3'));
    check('up: reorder 2~0, end 0', JSON.stringify(await log(p)) === '["start(x~2)","reorder(x~2~0)","end(x~0)"]');
    const q = await open(list(items(3)));
    await drag(q, 1, 600);
    await until(q, () => document.querySelector('#list').children[2].id === 'i1');
    check('end: past the end it holds in the list; the last place is index n', (await log(q)).includes('reorder(x~0~3)') && JSON.stringify(await order(q)) === '["i2","i3","i1"]');
    const r = await open(list(items(3)));
    await drag(r, 2, hy(2) + 8);
    await until(r, () => window.log.length >= 2);
    check('same place: nothing reorders, the end is told', JSON.stringify(await log(r)) === '["start(x~1)","end(x~1)"]' && JSON.stringify(await order(r)) === '["i1","i2","i3"]');
  }
  {
    const p = await open(list(items(3)));
    await drag(p, 1, hy(1) + 60, false);
    const prevented = await key(p, '#h1', 'Escape');
    await until(p, () => window.log.length >= 2);
    check('Escape puts everything back', prevented && JSON.stringify(await log(p)) === '["start(x~0)","end(x~0)"]' && JSON.stringify(await order(p)) === '["i1","i2","i3"]' && (await yvar(p, '#i2')) === '');
    await pointer(p, '#h2', 'pointerdown', 190, hy(2));
    await pointer(p, '#h2', 'pointermove', 190, hy(2) + 10);
    await pointer(p, '#h2', 'pointermove', 190, hy(2) + 70);
    await wait(p, 60);
    await pointer(p, '#h2', 'pointercancel', 190, hy(2) + 70);
    await until(p, () => window.log.length >= 2);
    check('a cancelled pointer too', JSON.stringify(await log(p)) === '["start(x~1)","end(x~1)"]' && JSON.stringify(await order(p)) === '["i1","i2","i3"]');
  }
  {
    const p = await open(list(items(3)));
    await p.evaluate(() => { window.clicks = 0; document.querySelector('#h1').addEventListener('click', () => window.clicks++); });
    await pointer(p, '#h1', 'pointerdown', 190, hy(1));
    await pointer(p, '#h1', 'pointerup', 190, hy(1));
    await p.evaluate(() => document.querySelector('#h1').click());
    check('click: a press that does not move is a click', (await p.evaluate(() => window.clicks)) === 1 && (await log(p)).length === 0);
    await drag(p, 1, hy(1) + 60);
    await p.evaluate(() => document.querySelector('#h1').click());
    check('click: a drag swallows its own click', (await p.evaluate(() => window.clicks)) === 1);
  }
  {
    const p = await open(list(`<div id="head">cabecera</div>${items(2)}<div id="foot">pie</div>`));
    await pointer(p, '#head', 'pointerdown', 100, 25);
    await pointer(p, '#head', 'pointermove', 100, 40);
    await pointer(p, '#head', 'pointermove', 100, 90);
    await wait(p, 60);
    check('header: not an item, not dragged', !(await attr(p, '#i1', 'data-t-ro-drag')) && (await log(p)).length === 0);
    await drag(p, 1, hy(1) + 200);
    await until(p, () => window.log.length >= 3);
    check('footer: stays last', JSON.stringify(await order(p)) === '["i2","i1"]' && (await p.evaluate(() => document.querySelector('#list').lastElementChild.id)) === 'foot');
  }
  {
    const p = await open(list(items(3)));
    await pointer(p, '#i1', 'pointerdown', 60, 40, 'touch');
    await pointer(p, '#i1', 'pointermove', 60, 60, 'touch');
    await wait(p, 650);
    check('touch: moving before the hold is a scroll', !(await attr(p, '#i1', 'data-t-ro-drag')) && (await log(p)).length === 0);
    await pointer(p, '#i1', 'pointerup', 60, 60, 'touch');
    await pointer(p, '#i1', 'pointerdown', 60, 40, 'touch');
    check('touch: a held finger drags the item', await until(p, () => document.querySelector('#i1').hasAttribute('data-t-ro-drag')));
    await pointer(p, '#i1', 'pointermove', 60, 140, 'touch');
    await wait(p, 60);
    await pointer(p, '#i1', 'pointerup', 60, 140, 'touch');
    await until(p, () => window.log.length >= 3);
    check('touch: and drops it', JSON.stringify(await order(p)) === '["i2","i3","i1"]', JSON.stringify(await order(p)));
  }
  {
    const p = await open(list('<div id="i1" data-t-ro-item>uno<span id="d" data-t-ro-h="delayed">::</span></div><div id="i2" data-t-ro-item>dos</div>', { cfg: 'v|0' }));
    await pointer(p, '#i1', 'pointerdown', 60, 20, 'touch');
    await wait(p, 650);
    check('touch off: a held finger on the item does nothing', !(await attr(p, '#i1', 'data-t-ro-drag')));
    await pointer(p, '#i1', 'pointerup', 60, 20, 'touch');
    await pointer(p, '#d', 'pointerdown', 60, 20, 'touch');
    check('a delayed handle waits for its hold', await until(p, () => document.querySelector('#i1').hasAttribute('data-t-ro-drag')));
    await pointer(p, '#d', 'pointerup', 60, 20, 'touch');
    const q = await open(list(items(2, { extra: '<input id="f">' })));
    await pointer(q, '#f', 'pointerdown', 60, 30, 'touch');
    await wait(q, 650);
    check('a field inside keeps its pointer', !(await attr(q, '#i1', 'data-t-ro-drag')));
  }
  {
    const p = await open(list(items(3)));
    await p.focus('#h1');
    const prevented = await key(p, '#h1', ' ');
    check('keyboard: Space on a handle picks up', prevented && JSON.stringify(await log(p)) === '["start(x~0)"]');
    check('keyboard: it says so', await until(p, () => document.querySelector('[aria-live=assertive]')?.textContent.startsWith('Picked up Fila 1, position 1 of 3.')), await live(p));
    await key(p, '#h1', 'ArrowDown');
    check('keyboard: an arrow moves it in the page, the focus stays', JSON.stringify(await order(p)) === '["i2","i1","i3"]' && (await p.evaluate(() => document.activeElement.id)) === 'h1');
    check('keyboard: and says where', await until(p, () => document.querySelector('[aria-live=assertive]')?.textContent === 'Fila 1, position 2 of 3.'), await live(p));
    await key(p, '#h1', 'ArrowDown');
    await key(p, '#h1', 'ArrowDown');
    check('keyboard: the end of the list holds', JSON.stringify(await order(p)) === '["i2","i3","i1"]');
    await key(p, '#h1', ' ');
    check('keyboard: Space drops: reorder, then end', JSON.stringify(await log(p)) === '["reorder(x~0~3)","end(x~2)"]');
    check('keyboard: and says so', await until(p, () => document.querySelector('[aria-live=assertive]')?.textContent === 'Dropped Fila 1 at position 3 of 3.'), await live(p));
  }
  {
    const p = await open(list(items(3)));
    await p.focus('#h2');
    await key(p, '#h2', 'Enter');
    await key(p, '#h2', 'ArrowUp');
    await key(p, '#h2', 'Escape');
    check('keyboard: Escape puts it back', JSON.stringify(await order(p)) === '["i1","i2","i3"]' && JSON.stringify(await log(p)) === '["start(x~1)","end(x~1)"]');
    check('keyboard: and says so', await until(p, () => document.querySelector('[aria-live=assertive]')?.textContent === 'Cancelled. Fila 2 is back at position 2 of 3.'), await live(p));
    await key(p, '#h2', ' ');
    await key(p, '#h2', 'End');
    const end = JSON.stringify(await order(p));
    await key(p, '#h2', 'Home');
    check('keyboard: End and Home go to the ends', end === '["i1","i3","i2"]' && JSON.stringify(await order(p)) === '["i2","i1","i3"]');
    await key(p, '#h2', 'Escape');
  }
  {
    const p = await open(list(items(3, { extra: '<a class="lnk" href="#x">enlace</a>' })));
    const prevented = await key(p, '#h1', 'ArrowDown', { altKey: true });
    check('Alt+arrow on a handle moves at once and calls reorder', prevented && JSON.stringify(await order(p)) === '["i2","i1","i3"]' && JSON.stringify(await log(p)) === '["reorder(x~0~2)"]');
    await key(p, '#i3 a', 'ArrowUp', { altKey: true });
    check('Alt+arrow from inside an item too', JSON.stringify(await order(p)) === '["i2","i3","i1"]' && JSON.stringify(await log(p)) === '["reorder(x~2~1)"]');
    await key(p, '#h2', 'ArrowUp', { altKey: true });
    check('the top of the list: nothing moves', (await log(p)).length === 0);
    check('a plain arrow is not ours', !(await key(p, '#h1', 'ArrowDown')));
    const q = await open(list(items(2, { extra: '<input id="f">' })));
    check('a field keeps Alt+arrow', !(await key(q, '#f', 'ArrowDown', { altKey: true })) && JSON.stringify(await order(q)) === '["i1","i2"]');
  }
  {
    const p = await open(list(items(2)));
    await p.focus('#h2');
    check('the handle is named for its item on focus', (await p.evaluate(() => document.querySelector('#h2').getAttribute('aria-label'))) === 'Reorder Fila 2', await p.evaluate(() => document.querySelector('#h2').getAttribute('aria-label')));
    const q = await open(list(items(2), { extra: 'data-t-ro-say="Levantaste {item}, {position}/{count}&#10;{item}: {position}/{count}&#10;Soltaste {item}: {position}&#10;Cancelado&#10;Reordenar {item}"' }));
    await q.focus('#h1');
    await key(q, '#h1', ' ');
    await key(q, '#h1', 'ArrowDown');
    await key(q, '#h1', ' ');
    check('the words of the page replace the English ones', (await until(q, () => document.querySelector('[aria-live=assertive]')?.textContent === 'Soltaste Fila 1: 2')) && (await q.evaluate(() => document.querySelector('#h1').getAttribute('aria-label'))) === 'Reordenar Fila 1', await live(q));
  }
  {
    const p = await open(list(items(3), { cfg: 'h|1', dir: 'rtl', style: 'display:flex;flex-direction:row;' }));
    await p.focus('#h1');
    await key(p, '#h1', ' ');
    await key(p, '#h1', 'ArrowLeft');
    const left = JSON.stringify(await order(p));
    await key(p, '#h1', 'ArrowRight');
    check('rtl: the left arrow goes on, the right goes back', left === '["i2","i1","i3"]' && JSON.stringify(await order(p)) === '["i1","i2","i3"]');
    await key(p, '#h1', 'Escape');
  }
  {
    const p = await open(list(items(2)) + '<button id="out">fuera</button>');
    await p.focus('#h1');
    await key(p, '#h1', ' ');
    await key(p, '#h1', 'ArrowDown');
    await p.focus('#out');
    await wait(p, 60);
    check('losing the focus drops a picked-up item back', JSON.stringify(await order(p)) === '["i1","i2"]' && (await log(p)).slice(-1)[0] === 'end(x~0)');
  }
  await browser.close();
}
const failed = results.filter((r) => !r).length;
console.log(failed ? `✗ lite reorder: ${failed} of ${results.length} failed` : `✓ lite reorder: ${results.length} passed`);
process.exit(failed ? 1 : 0);

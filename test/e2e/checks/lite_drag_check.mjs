// Draggable / DragTarget in the lite engine (parts/drag_kit.js and
// parts/drag_drop.js) on a page made in memory from lib/lite/runtime.js and
// the markup thor_ui writes: the same cases as the dart2js feature's browser
// test (packages/thor_engine_oracle/test/drag_drop_client_test.dart), so the two
// engines answer alike. Chromium, Firefox and WebKit (E2E_BROWSER).
//
//   node test/e2e/checks/lite_drag_check.mjs
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import * as engines from '../runner/node_modules/playwright/index.mjs';
import { browsersFor, repo } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
const runtime = readFileSync(join(lite, 'runtime.js'), 'utf8');
const part = (n) => readFileSync(join(lite, 'parts', n), 'utf8');
const bundle = (...parts) => runtime.replace('// @thor-lite-parts', () => parts.map(part).join('\n'));

const source = (id, { data = 'task-1', type = 'String', cfg = 'f|0|c|1|0|0', left = 10, top = 10, ids = 'start:Board.started;done:Board.done;cancel:Board.canceled;end:Board.ended', extra = '', say = '' } = {}) =>
  `<div id="${id}" tabindex="0" role="button" data-t-dg="${ids}" data-tx="x" data-t-dg-data="${data}" ${say ? `data-t-dg-say="${say}"` : ''} data-t-dg-type="${type}" data-t-dg-cfg="${cfg}" style="position:fixed;left:${left}px;top:${top}px;width:80px;height:30px;background:#ccc">Tarea ${id}<template data-t-dg-fb><div data-t-dg-ghost style="position:fixed;inset:0 auto auto 0;margin:0;width:80px;height:30px;translate:var(--t-dg-x,0px) var(--t-dg-y,0px);pointer-events:none">fantasma</div></template>${extra}</div>`;
const target = (id, { type = 'String', left = 200, top = 10, ids = 'accept:Board.canDrop;drop:Board.dropped;leave:Board.left;move:Board.moved' } = {}) =>
  `<div id="${id}" data-t-dt="${ids}" data-tx="${id}" data-t-dg-type="${type}" style="position:fixed;left:${left}px;top:${top}px;width:150px;height:100px;background:#9cf">Columna ${id}</div>`;

const state = `window.log = [];
window.accepts = () => true;
const rec = (n) => (v) => window.log.push(n + '(' + v + ')');
thor.def('Board', () => ({ started: (v) => window.log.push('started(' + v + ')'), done: (v) => window.log.push('done(' + v + ')'), canceled: rec('canceled'), ended: rec('ended'), dropped: rec('dropped'), left: rec('left'), moved: rec('moved'),
  canDrop: (v) => { window.log.push('canDrop(' + v + ')'); return window.accepts(v); } }));`;

const page = (body) => `<!DOCTYPE html><html><head><base href="/"><meta charset="utf-8"></head><body style="margin:0">${body}<script>${bundle('drag_kit.js', 'drag_drop.js')}\n${state}</script></body></html>`;

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
  const frame = (p) => p.evaluate(() => new Promise((r) => setTimeout(() => requestAnimationFrame(() => requestAnimationFrame(r)), 20)));
  const ghost = (p) => p.evaluate(() => !!document.querySelector('[data-t-dg-ghost]'));
  const live = (p) => p.evaluate(() => document.querySelector('[aria-live=assertive]')?.textContent ?? '');
  const has = (p, sel, attr) => p.evaluate(([s, a]) => document.querySelector(s)?.hasAttribute(a), [sel, attr]);
  const pointer = (p, sel, type, x, y, kind = 'mouse') =>
    p.evaluate(([s, t, x, y, k]) => document.querySelector(s).dispatchEvent(new PointerEvent(t, { bubbles: true, cancelable: true, clientX: x, clientY: y, pointerId: 1, pointerType: k, isPrimary: true, button: 0 })), [sel, type, x, y, kind]);
  const grab = async (p, sel, x, y, tx, ty) => {
    await pointer(p, sel, 'pointerdown', x, y);
    await pointer(p, sel, 'pointermove', x + 8, y + 2);
    await pointer(p, sel, 'pointermove', tx, ty);
    await frame(p);
  };
  const vars = (p) => p.evaluate(() => { const g = document.querySelector('[data-t-dg-ghost]'); return [g.style.getPropertyValue('--t-dg-x'), g.style.getPropertyValue('--t-dg-y')]; });
  const key = (p, sel, k, opts = {}) => p.evaluate(([s, k, o]) => { const e = new KeyboardEvent('keydown', { key: k, bubbles: true, cancelable: true, ...o }); document.querySelector(s).dispatchEvent(e); return e.defaultPrevented; }, [sel, k, opts]);
  const until = async (p, fn, arg) => { for (let i = 0; i < 200; i++) { if (await p.evaluate(fn, arg)) return true; await p.waitForTimeout(10); } return false; };

  {
    const p = await open(source('a') + target('todo'));
    await grab(p, '#a', 20, 20, 250, 60);
    check('drag: the feedback is cloned into the body', await ghost(p));
    check('drag: it keeps the distance the child had from the pointer', JSON.stringify(await vars(p)) === '["240px","50px"]', JSON.stringify(await vars(p)));
    check('drag: the source and the target are marked', (await has(p, '#a', 'data-t-dg-active')) && (await has(p, '#todo', 'data-t-dt-over')));
    await pointer(p, '#a', 'pointerup', 250, 60);
    const l = await log(p);
    check('drop: start, accept (asked once), move, then drop, done, end', l.includes('started(x)') && l.filter((x) => x === 'canDrop(todo~task-1)').length === 1 && l.includes('moved(todo~50~50)'), JSON.stringify(l));
    check('drop: drop, done, end(true) in that order, and no leave', JSON.stringify(l.slice(l.indexOf('dropped(todo~task-1)'))) === '["dropped(todo~task-1)","done(x)","ended(x~true)"]' && !l.includes('left(todo~task-1)'), JSON.stringify(l));
    check('drop: the ghost and the marks go', !(await ghost(p)) && !(await has(p, '#a', 'data-t-dg-active')) && !(await has(p, '#todo', 'data-t-dt-over')));
    check('no page errors (drop)', p.problems.length === 0, p.problems.join(' | '));
  }
  {
    const p = await open(source('a') + target('todo'));
    await grab(p, '#a', 20, 20, 120, 300);
    await pointer(p, '#a', 'pointerup', 120, 300);
    check('cancel: where the pointer was, then end(false)', JSON.stringify(await log(p)) === '["started(x)","canceled(x~120~300)","ended(x~false)"]');
  }
  {
    const p = await open(source('a') + target('num', { type: 'int' }) + target('no', { left: 200, top: 150 }));
    await p.evaluate(() => (window.accepts = (v) => !v.startsWith('no~')));
    await grab(p, '#a', 20, 20, 250, 60);
    check('reject: another type rejects, without asking the method', (await has(p, '#num', 'data-t-dt-reject')) && !(await has(p, '#num', 'data-t-dt-over')) && !(await log(p)).some((x) => x.startsWith('canDrop(num')));
    await pointer(p, '#a', 'pointermove', 250, 190);
    await frame(p);
    check('reject: a method that says no rejects', (await has(p, '#no', 'data-t-dt-reject')) && !(await has(p, '#num', 'data-t-dt-reject')));
    await pointer(p, '#a', 'pointerup', 250, 190);
    const l = await log(p);
    check('reject: nothing is dropped', !l.some((x) => x.startsWith('dropped')) && l.includes('ended(x~false)'), JSON.stringify(l));
  }
  {
    const p = await open(source('a', { type: 'double' }) + target('any', { type: 'Object' }) + target('number', { type: 'num', left: 200, top: 150 }));
    await grab(p, '#a', 20, 20, 250, 60);
    const anyOk = await has(p, '#any', 'data-t-dt-over');
    await pointer(p, '#a', 'pointermove', 250, 190);
    await frame(p);
    check('types: Object takes any, num takes a double', anyOk && (await has(p, '#number', 'data-t-dt-over')));
    await pointer(p, '#a', 'pointerup', 250, 190);
  }
  {
    const p = await open(source('a') + target('todo', { top: 10 }) + target('done', { left: 200, top: 150 }));
    await grab(p, '#a', 20, 20, 250, 60);
    await pointer(p, '#a', 'pointermove', 260, 70);
    await frame(p);
    await pointer(p, '#a', 'pointermove', 250, 190);
    await frame(p);
    let l = await log(p);
    check('leave: asked once per entry, leave called', l.filter((x) => x === 'canDrop(todo~task-1)').length === 1 && l.includes('left(todo~task-1)'), JSON.stringify(l));
    await pointer(p, '#a', 'pointermove', 250, 60);
    await frame(p);
    l = await log(p);
    check('leave: asked again on re-entry', l.includes('canDrop(todo~task-1)'), JSON.stringify(l));
    await pointer(p, '#a', 'pointerup', 250, 60);
  }
  {
    const p = await open(source('a', { data: 'a~b%c' }) + target('todo'));
    await grab(p, '#a', 20, 20, 250, 60);
    await pointer(p, '#a', 'pointerup', 250, 60);
    const l = await log(p);
    check('move: the pointer inside the target', l.includes('moved(todo~50~50)'), JSON.stringify(l));
    check('drop: the data is the last part, as it is', l.includes('dropped(todo~a~b%c)'), JSON.stringify(l));
  }
  {
    const p = await open(source('a', { cfg: 'h|0|c|1|0|0' }) + target('todo'));
    await grab(p, '#a', 20, 20, 250, 90);
    check('axis: the feedback stays on its line', JSON.stringify(await vars(p)) === '["240px","10px"]', JSON.stringify(await vars(p)));
    await pointer(p, '#a', 'pointerup', 250, 90);
    const q = await open(source('a', { cfg: 'f|0|p|1|4|-8' }) + target('todo'));
    await grab(q, '#a', 20, 20, 250, 60);
    check('anchor: the corner is at the pointer, plus the offset', JSON.stringify(await vars(q)) === '["254px","52px"]', JSON.stringify(await vars(q)));
  }
  {
    const p = await open(source('a', { extra: '<template data-t-dg-ph><div id="ph" style="width:80px;height:30px">hueco</div></template>' }) + target('todo'));
    await grab(p, '#a', 20, 20, 250, 60);
    check('childWhenDragging: stands in, source hidden', (await has(p, '#ph', 'id')) && (await has(p, '#a', 'data-t-dg-gone')));
    await pointer(p, '#a', 'pointerup', 250, 60);
    check('childWhenDragging: goes back', !(await p.evaluate(() => !!document.querySelector('#ph'))) && !(await has(p, '#a', 'data-t-dg-gone')));
  }
  {
    const p = await open(source('a') + target('todo'));
    await p.evaluate(() => { window.clicks = 0; document.querySelector('#a').addEventListener('click', () => window.clicks++); });
    await pointer(p, '#a', 'pointerdown', 20, 20);
    await pointer(p, '#a', 'pointermove', 22, 21);
    await pointer(p, '#a', 'pointerup', 22, 21);
    await p.evaluate(() => document.querySelector('#a').click());
    check('click: a press that does not move is a click', (await p.evaluate(() => window.clicks)) === 1 && (await log(p)).length === 0);
    await grab(p, '#a', 20, 20, 250, 60);
    await pointer(p, '#a', 'pointerup', 250, 60);
    await p.evaluate(() => document.querySelector('#a').click());
    check('click: a drag swallows its own click', (await p.evaluate(() => window.clicks)) === 1);
  }
  {
    const p = await open(source('a') + target('todo'));
    await grab(p, '#a', 20, 20, 250, 60);
    const prevented = await key(p, '#a', 'Escape');
    const l = await log(p);
    check('Escape gives a pointer drag up', prevented && !(await ghost(p)) && l.includes('ended(x~false)') && l.includes('left(todo~task-1)'), JSON.stringify(l));
    await pointer(p, '#a', 'pointerup', 250, 60);
    check('Escape: the release afterwards says nothing more', (await log(p)).length === 0);
  }
  {
    const p = await open(source('a', { cfg: 'f|120|c|1|0|0' }) + target('todo'));
    await pointer(p, '#a', 'pointerdown', 20, 20, 'touch');
    await pointer(p, '#a', 'pointermove', 60, 80, 'touch');
    await p.waitForTimeout(220);
    check('long press: moving before the hold is a scroll', !(await ghost(p)) && (await log(p)).length === 0);
    await pointer(p, '#a', 'pointerup', 60, 80, 'touch');
    await pointer(p, '#a', 'pointerdown', 20, 20, 'touch');
    check('long press: held still, the drag starts by itself', await until(p, () => !!document.querySelector('[data-t-dg-ghost]')));
    await pointer(p, '#a', 'pointermove', 250, 60, 'touch');
    await frame(p);
    await pointer(p, '#a', 'pointerup', 250, 60, 'touch');
    check('long press: it drops', (await log(p)).includes('dropped(todo~task-1)'));
  }
  {
    const p = await open(source('a', { extra: '<input id="f" style="position:absolute">' }) + source('off', { cfg: 'f|0|c|0|0|0', left: 10, top: 300 }) + target('todo'));
    await pointer(p, '#f', 'pointerdown', 20, 20);
    await pointer(p, '#f', 'pointermove', 100, 60);
    await pointer(p, '#f', 'pointermove', 250, 60);
    await frame(p);
    check('a field inside keeps its pointer', !(await ghost(p)));
    await grab(p, '#off', 20, 310, 250, 60);
    check('a draggable that is turned off does not drag', !(await ghost(p)));
  }
  {
    const p = await open(source('a') + target('one') + target('skip', { type: 'int', left: 200, top: 120 }) + target('two', { left: 200, top: 240 }));
    await p.focus('#a');
    const prevented = await key(p, '#a', ' ');
    check('keyboard: Space picks up', prevented && (await ghost(p)) && (await has(p, '#a', 'data-t-dg-active')));
    check('keyboard: it says so', await until(p, () => document.querySelector('[aria-live=assertive]')?.textContent.includes('Picked up Tarea a')), await live(p));
    await key(p, '#a', 'ArrowDown');
    check('keyboard: the arrow goes to the first target that fits', await has(p, '#one', 'data-t-dt-over'));
    check('keyboard: and says it', await until(p, () => document.querySelector('[aria-live=assertive]')?.textContent === 'Columna one: it can be dropped here.'), await live(p));
    await key(p, '#a', 'ArrowDown');
    check('keyboard: the target of another type is skipped', await has(p, '#two', 'data-t-dt-over'));
    await key(p, '#a', 'ArrowUp');
    await key(p, '#a', 'Tab');
    check('keyboard: Tab goes on like the arrow', await has(p, '#two', 'data-t-dt-over'));
    await key(p, '#a', ' ');
    const l = await log(p);
    check('keyboard: Space drops', !(await ghost(p)) && l.includes('dropped(two~task-1)') && l.includes('ended(x~true)'), JSON.stringify(l));
    check('keyboard: it says so, and the focus comes back', (await until(p, () => document.querySelector('[aria-live=assertive]')?.textContent === 'Dropped Tarea a on Columna two.')) && (await p.evaluate(() => document.activeElement.id)) === 'a', await live(p));
  }
  {
    const p = await open(source('a') + target('no') + target('ok', { left: 200, top: 150 }));
    await p.evaluate(() => (window.accepts = (v) => !v.startsWith('no~')));
    await p.focus('#a');
    await key(p, '#a', 'Enter');
    await key(p, '#a', 'ArrowDown');
    check('keyboard: a target that says no is announced', (await has(p, '#no', 'data-t-dt-reject')) && (await until(p, () => document.querySelector('[aria-live=assertive]')?.textContent === 'Columna no: it cannot be dropped here.')), await live(p));
    await key(p, '#a', ' ');
    check('keyboard: Space there does not drop', (await ghost(p)) && !(await log(p)).some((x) => x.startsWith('dropped')));
    await key(p, '#a', 'Escape');
    check('keyboard: Escape cancels and says so', !(await ghost(p)) && (await until(p, () => document.querySelector('[aria-live=assertive]')?.textContent === 'Cancelled. Tarea a was not moved.')), await live(p));
  }
  {
    const p = await open(source('a', { say: 'Levantaste {item}&#10;{target}: cabe&#10;{target}: no cabe&#10;Soltaste {item} en {target}&#10;Cancelado' }) + target('one'));
    await p.focus('#a');
    await key(p, '#a', ' ');
    await key(p, '#a', 'ArrowDown');
    await key(p, '#a', ' ');
    check('keyboard: the words of the page replace the English ones', await until(p, () => document.querySelector('[aria-live=assertive]')?.textContent === 'Soltaste Tarea a en Columna one'), await live(p));
  }
  {
    const p = await open(source('a', { extra: '<input id="f">' }) + target('one'));
    check('keyboard: keys inside a field are the field\'s', !(await key(p, '#f', ' ')) && !(await ghost(p)));
  }
  await browser.close();
}
const failed = results.filter((r) => !r).length;
console.log(failed ? `✗ lite drag: ${failed} of ${results.length} failed` : `✓ lite drag: ${results.length} passed`);
process.exit(failed ? 1 : 0);

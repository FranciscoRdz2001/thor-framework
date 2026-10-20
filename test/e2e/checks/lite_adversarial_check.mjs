// Adversarial browser checks of the lite runtime hardening:
// real Chromium, pages built in memory from lib/lite/runtime.js (no app to
// build). Each case was a failing repro; it guards the fix now.
//
//   node test/e2e/checks/lite_adversarial_check.mjs
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { chromium } from '../runner/node_modules/playwright/index.mjs';
import { repo } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
// Keyed lists are the runtime's part `lists`, sewn in first (an older
// runtime, without that part next to it, has them inside).
const withLists = (src, at) => {
  const p = join(dirname(at), 'parts/lists.js');
  return src.replace('// @thor-lite-parts', () => `${existsSync(p) ? readFileSync(p, 'utf8') : ''}\n// @thor-lite-parts`);
};
const runtimePath = join(lite, 'runtime.js');
const runtime = withLists(readFileSync(runtimePath, 'utf8'), runtimePath);
const part = (n) => readFileSync(join(lite, 'parts', n), 'utf8');
const bundle = (...parts) => runtime.replace('// @thor-lite-parts', () => parts.map(part).join('\n'));
const page = (body, script, parts = []) =>
  `<!DOCTYPE html><html><head><base href="/"></head><body>${body}<script>${bundle(...parts)}\n${script}</script></body></html>`;

const pages = {
  // A keyed list whose row text throws for the key `bad`.
  '/list': page(
    `<button id="set" data-t-on="click:L.set" data-tx=""></button><button id="fix" data-t-on="click:L.fix"></button>
<ul data-tl="L.items" data-tlk="L.key"><li data-tk="a"><b data-tf="L.text">a</b></li><template data-tlt="L.items"><li><b data-tf="L.text"></b></li></template></ul>
<span id="n" data-tt="L.count">0</span>`,
    `thor.def('L', ($) => {
  const items = $.state('items', [{ k: 'a', t: 'a' }]), n = $.state('n', 0), ok = $.state('ok', false);
  return {
    items: () => items.value, key: (i) => i.k,
    text: (i) => { if (i.k === 'bad' && !ok.value) throw Error('row boom'); return i.t; },
    count: () => String(n.value),
    set: (arg) => { n.value++; items.value = arg ? arg.split(',').map((k) => ({ k, t: k })) : []; },
    fix: () => { ok.value = true; },
  };
});`,
  ),
  // Nested handlers, a drag inside a clickable card, transitions, a form in a card.
  '/tree': page(
    `<div id="card" data-t-on="click:T.card;transitionend:T.card"><div id="box" style="width:200px;height:100px;background:#ccc;transition:opacity .05s" data-tg="drag:T.drag" data-tg-drag="f|0"><span id="deep">x</span></div>
<button id="own" data-t-on="click:T.own">own</button>
<form id="f" data-t-on="submit:T.submit" onsubmit="return false"><input id="in" data-t-on="input:T.typed"><button id="sub" type="submit">go</button></form>
<div id="rb" role="button" tabindex="0" data-t-on="click:T.rb">rb</div></div>
<div id="lvl1" data-t-on="click:T.l1"><div id="lvl2" data-t-on="click:T.l2"><div id="lvl3" data-t-on="click:T.l3"><i id="leaf">l</i></div></div></div>
<div id="gone" data-t-on="click:T.gone">gone <b id="victim" data-t-on="click:T.remove">v</b></div>`,
    `window.log = [];
thor.def('T', ($) => {
  const l = (n) => (v) => window.log.push(n + (v == null ? '' : ':' + v));
  return { card: l('card'), drag: l('drag'), own: l('own'), submit: l('submit'), typed: l('typed'), rb: l('rb'), l1: l('l1'), l2: l('l2'), l3: l('l3'), gone: l('gone'),
    remove: () => { window.log.push('remove'); document.getElementById('victim').remove(); } };
});`,
    ['gestures.js'],
  ),
};

const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail !== '' ? ` (${detail})` : ''}`);
};

const browser = await chromium.launch();
const open = async (path) => {
  const ctx = await browser.newContext({ viewport: { width: 700, height: 900 } });
  const p = await ctx.newPage();
  p.problems = [];
  p.on('pageerror', (e) => p.problems.push(e.message));
  await ctx.route('http://lite.test/**', (r) => {
    const body = pages[new URL(r.request().url()).pathname];
    return body ? r.fulfill({ contentType: 'text/html', body }) : r.fulfill({ status: 404, body: '' });
  });
  await p.goto(`http://lite.test${path}`);
  await p.waitForFunction(() => typeof thor !== 'undefined');
  await p.waitForTimeout(50);
  return p;
};
const log = (p) => p.evaluate(() => window.log.splice(0).join());

try {
  // A row text that throws during a keyed list render.
  {
    const p = await open('/list');
    await p.evaluate(() => (document.querySelector('#set').dataset.tx = 'a,bad,c'));
    await p.click('#set');
    await p.waitForTimeout(100);
    const rows = await p.evaluate(() => [...document.querySelectorAll('li')].map((l) => l.textContent));
    check('throwing code: a row that throws does not leave the list half-rendered', rows.length === 3 && rows[0] === 'a' && rows[2] === 'c', JSON.stringify(rows));
    await p.evaluate(() => (document.querySelector('#set').dataset.tx = 'a,c,d'));
    await p.click('#set');
    await p.waitForTimeout(100);
    const rows2 = await p.evaluate(() => [...document.querySelectorAll('li')].map((l) => l.textContent));
    check('throwing code: the next interaction after a throwing row updates the list', rows2.join() === 'a,c,d', JSON.stringify(rows2));
    // Fix the row, ask for the same keys again: the half-registered `bad` must not linger.
    await p.click('#fix');
    await p.evaluate(() => (document.querySelector('#set').dataset.tx = 'a,bad,c'));
    await p.click('#set');
    await p.waitForTimeout(100);
    const rows3 = await p.evaluate(() => [...document.querySelectorAll('li')].map((l) => l.textContent));
    check('throwing code: after a row failed once and was fixed, the same keys render fully', rows3.join() === 'a,bad,c', JSON.stringify(rows3));
    check('throwing code: the counter label follows the state through the failures', (await p.textContent('#n')) === '3', await p.textContent('#n'));
    await p.close();
  }

  // Nested handlers in a real browser.
  {
    const p = await open('/tree');
    await p.click('#deep'); // no handler on box or deep: the card gets it
    check('nested handlers: click on a handler-less child reaches the card', (await log(p)) === 'card');
    await p.click('#own');
    check('nested handlers: a button with its own click handler stops the card (innermost wins)', (await log(p)) === 'own');
    await p.click('#leaf');
    check('nested handlers: three nested click handlers: only the innermost', (await log(p)) === 'l3');
    await p.click('#victim');
    check('nested handlers: a handler that removes its own element leaves the ancestor quiet', (await log(p)) === 'remove');
    await p.click('#gone', { position: { x: 3, y: 3 } });
    check('nested handlers: the parent of a removed handler still works', (await log(p)) === 'gone');

    // Drag inside the card: the card's click must not fire.
    const b = await p.locator('#box').boundingBox();
    await p.mouse.move(b.x + 20, b.y + 20);
    await p.mouse.down();
    for (let i = 1; i <= 8; i++) await p.mouse.move(b.x + 20 + i * 10, b.y + 20 + i * 4);
    await p.mouse.up();
    await p.waitForTimeout(80);
    const drag = await log(p);
    check('nested handlers: a drag inside a clickable card runs the drag and not the card click', /^drag:/.test(drag) && !drag.includes('card'), drag);

    // Drag out of the box and release over the card outside it.
    await p.mouse.move(b.x + 20, b.y + 20);
    await p.mouse.down();
    for (let i = 1; i <= 12; i++) await p.mouse.move(b.x + 20 + i * 20, b.y + 20);
    await p.mouse.up();
    await p.waitForTimeout(80);
    const out = await log(p);
    check('nested handlers: dragging out of the box and releasing on the card does not click the card', !out.includes('card'), out);

    // Transition ends on a child of a card that handles transitionend.
    await p.evaluate(() => {
      const b = document.getElementById('box');
      b.style.opacity = '0.5';
    });
    await p.waitForTimeout(200);
    check('nested handlers: a child transitionend does not run the card transitionend handler', !(await log(p)).includes('card'));
    await p.evaluate(() => (document.getElementById('card').style.transition = 'opacity .05s'));
    await p.evaluate(() => (document.getElementById('card').style.opacity = '0.9'));
    await p.waitForTimeout(200);
    check('nested handlers: the card own transitionend still runs its handler', (await log(p)).includes('card'));

    // A form in a clickable card: click on submit fires card click and the form's submit, once each.
    await p.click('#sub');
    const sub = (await log(p)).split(',').sort().join();
    check('nested handlers: submit button in a form in a clickable card: one card click and one submit', sub === 'card,submit', sub);
    // A text field with `input` inside the card.
    await p.click('#in');
    const inl = await log(p);
    check('nested handlers: clicking a text field inside the card clicks the card once (browser semantics)', inl.startsWith('card'), inl);
    await p.keyboard.type('ab');
    check('nested handlers: typing in the field runs input, not the card', (await log(p)) === 'typed:a,typed:ab');
    // Enter on role=button.
    await p.focus('#rb');
    await p.keyboard.press('Enter');
    const rb = await log(p);
    check('nested handlers: Enter on a role=button handler runs only its own click', rb === 'rb', rb);
    await p.keyboard.press(' ');
    const rb2 = await log(p);
    check('nested handlers: Space on a role=button handler runs only its own click', rb2 === 'rb', rb2);
    check('nested handlers: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }
} catch (e) {
  check('no exception', false, e?.stack ?? String(e));
}
await browser.close();
const failed = results.filter((r) => !r).length;
console.log(failed ? `${failed} of ${results.length} failed` : `${results.length} passed`);
process.exit(failed ? 1 : 0);

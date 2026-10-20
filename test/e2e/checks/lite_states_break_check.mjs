// The lite runtime's finite states (`data-tv`) switching between structures
// that look alike (same tags, same child count) but bind different things:
// pages made in memory from lib/lite/runtime.js, real Chromium.
//
//   node test/e2e/checks/lite_states_break_check.mjs
//
// S1  a state whose bound child is another binding (a text of another
//     member) must not keep the previous state's binding.
// S2  the way back to the server's state from such a state: same.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { chromium } from '../runner/node_modules/playwright/index.mjs';
import { frames, repo } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
const runtime = readFileSync(join(lite, 'runtime.js'), 'utf8');
const bundle = runtime.replace('// @thor-lite-parts', () => '');
const page = (body, script) =>
  `<!DOCTYPE html><html><head><base href="/"></head><body>${body}<script>${bundle}\n${script}</script></body></html>`;

const pages = {
  '/states': page(
    // The server's state 0: a row with a text bound to V.a. State 1 (a
    // template): a column with a text bound to V.b, and a nested watcher.
    // State 2 (a template): a column with a plain span where 0 had the text.
    `<div id="s" class="row" data-tv="V.mode"><span>uno</span><b id="b" data-tt="V.a">A</b></div>
<template data-tvt="V.mode" data-i="1"><div class="col"><span>dos</span><b data-tt="V.b">B</b></div></template>
<template data-tvt="V.mode" data-i="2"><div class="col"><span>tres</span><i>plain</i></div></template>
<template data-tvt="V.mode" data-i="3"><div class="col"><span>cuatro</span><em data-tv="V.inner"><u>x</u></em></div></template>`,
    `thor.def('V', ($) => {
  const mode = $.state('mode', 0), a = $.state('a', 'a-text'), b = $.state('b', 'b-text'), inner = $.state('inner', 0);
  window.set = (n) => (mode.value = n);
  window.setA = (v) => (a.value = v);
  window.setB = (v) => (b.value = v);
  return { mode: () => mode.value, a: () => a.value, b: () => b.value, inner: () => inner.value };
}, { eager: true });`,
  ),
};

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
  await p.waitForFunction(() => typeof thor !== 'undefined' && typeof set === 'function');
  await frames(p);
  return p;
};
const html = (p) => p.evaluate(() => document.getElementById('s')?.outerHTML ?? document.body.innerHTML);
const view = (p) => p.evaluate(() => [...document.querySelectorAll('body > div')].map((d) => d.innerText.replace(/\s+/g, ' ').trim()).join('|'));

try {
  {
    const p = await open('/states');
    await p.evaluate(() => set(1));
    await frames(p);
    check('S1 state 1 shows its own binding (b-text), not the old one', (await view(p)) === 'dosb-text', await view(p));
    await p.evaluate(() => setB('B2'));
    await frames(p);
    check('S1 and follows it', (await view(p)) === 'dosB2', await view(p));
    await p.evaluate(() => setA('A2'));
    await frames(p);
    check('S1 the old binding does not move it', (await view(p)) === 'dosB2', await view(p));
    // Back to the server's state: its binding again.
    await p.evaluate(() => set(0));
    await frames(p);
    check('S2 back to state 0: its own binding (a) and its texts', (await view(p)) === 'unoA2', await view(p));
    // 1 -> 2: the bound element is gone (a plain one), the binding stops.
    await p.evaluate(() => set(1));
    await frames(p);
    await p.evaluate(() => set(2));
    await frames(p);
    check('S2 state 2 has a plain element where 1 had a binding', (await view(p)) === 'tresplain', await view(p));
    await p.evaluate(() => setB('B3'));
    await frames(p);
    check('S2 and nothing writes into it', (await view(p)) === 'tresplain', await view(p));
    // 3: nested states; then back to 0 (the server's state has no nested one).
    await p.evaluate(() => set(3));
    await frames(p);
    await p.evaluate(() => set(0));
    await frames(p);
    check('S2 from a state with a nested one back to the server\'s', (await view(p)) === 'unoA2' && !(await html(p)).includes('data-tv="V.inner"'), (await html(p)).slice(0, 300));
    check('S no page errors', p.problems.length === 0, p.problems.join('; '));
    await p.context().close();
  }
} finally {
  await browser.close();
}
process.exit(results.every(Boolean) ? 0 : 1);

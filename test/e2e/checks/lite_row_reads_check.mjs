// Keyed rows whose row state reads a signal outside the item (a set of
// starred keys), with variants of different structure: a page made in memory
// from lib/lite/runtime.js and the row_states part, real Chromium.
//
//   node test/e2e/checks/lite_row_reads_check.mjs
//
// - Starring a key flips its kept row (same item) to the other variant and
//   back, twice; the row's bound text inside the variant keeps the item's.
// - A row the browser clones follows the set too.
// - An `<svg>` row template (no `.content`) does not stop the page.
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
  `<!DOCTYPE html><html><head><meta charset="utf-8"><base href="/"></head><body>${body}<script>${runtime.replace('// @thor-lite-parts', () => parts)}\n${script}</script></body></html>`;

const STATE = `thor.def('S', ($) => {
  const it = $.state('items', ['a', 'b']);
  const st = $.state('starred', []);
  return {
    items: () => it.value, key: (i) => i, label: (i) => 'label ' + i,
    on: (i) => st.value.includes(i),
    star: (s) => { st.value = s; },
    set: (s) => { it.value = s; },
  };
}, { eager: true });
thor.def('P', ($) => {
  const n = $.state('n', 0);
  return { n: () => n.value, bump: () => { n.value++; } };
}, { eager: true });`;

const PLAIN = (t) => `<b data-tf="S.label">${t}</b><button>Agregar</button>`;
const FAV = (t) => `<b data-tf="S.label">${t}</b><i>★</i><button>Quitar</button>`;
const ROW = (k) => `<li data-tk="${k}"><span data-tvf="S.on" data-tvi="0">${PLAIN('label ' + k)}</span></li>`;
const PAGE = page(
  `<ul id="l" data-tl="S.items" data-tlk="S.key">${ROW('a')}${ROW('b')}` +
    `<template data-tlt="S.items"><li><span data-tvf="S.on" data-tvi="0">${PLAIN('')}` +
    `<template data-tvft="S.on" data-i="1"><span>${FAV('')}</span></template></span></li></template></ul>` +
    `<svg><g data-tl="S.items" data-tlk="S.key"><template data-tlt="S.items"><text data-tf="S.label"></text></template></g></svg>` +
    `<p id="n" data-tt="P.n">0</p>`,
  STATE,
);

const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail !== '' ? ` (${detail})` : ''}`);
};

const browser = await chromium.launch();
try {
  const ctx = await browser.newContext();
  const p = await ctx.newPage();
  const problems = [];
  p.on('pageerror', (e) => problems.push(e.message));
  await ctx.route('http://lite.test/**', (r) => r.fulfill({ contentType: 'text/html', body: PAGE }));
  await p.goto('http://lite.test/');
  await p.waitForFunction(() => typeof thor !== 'undefined' && thor.use);
  await frames(p);
  const call = async (s, m, v) => {
    await p.evaluate(([s, m, v]) => thor.use(s)[m](v), [s, m, v]);
    await frames(p);
  };
  const row = (k) => p.evaluate((k) => document.querySelector(`#l [data-tk="${k}"]`).textContent, k);
  const tvi = (k) => p.evaluate((k) => document.querySelector(`#l [data-tk="${k}"] span`).getAttribute('data-tvi'), k);
  for (let round = 0; round < 2; round++) {
    await call('S', 'star', ['a']);
    check(`starred key: kept row starred, round ${round}`, (await row('a')) === 'label a★Quitar' && (await tvi('a')) === '1', await row('a'));
    check(`starred key: the other row stays, round ${round}`, (await row('b')) === 'label bAgregar', await row('b'));
    await call('S', 'star', []);
    check(`starred key: kept row back, round ${round}`, (await row('a')) === 'label aAgregar' && (await tvi('a')) === '0', await row('a'));
  }
  await call('S', 'set', ['a', 'b', 'c']);
  await call('S', 'star', ['a', 'c']);
  check('cloned row: a row the browser made follows the set', (await row('c')) === 'label c★Quitar', await row('c'));
  check('cloned row: kept rows too', (await row('a')) === 'label a★Quitar' && (await row('b')) === 'label bAgregar');
  await call('P', 'bump');
  check('svg template: the svg list wires and the other bindings live', (await p.textContent('#n')) === '1' && (await p.locator('svg text[data-tk]').count()) === 3, await p.textContent('#n'));
  check('no page errors', problems.length === 0, problems.join(' | '));
  await ctx.close();
} finally {
  await browser.close();
}
process.exit(results.every(Boolean) ? 0 : 1);

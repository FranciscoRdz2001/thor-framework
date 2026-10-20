// A row state whose variant keeps the row's root and child count but swaps a
// child for another tag replaces that subtree; the `{{key}}` of its
// attributes must hold the row's key there too (real Chromium, a page made
// in memory from lib/lite/runtime.js and the row_states part).
//
//   node test/e2e/checks/lite_row_variant_key_check.mjs
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { chromium } from '../runner/node_modules/playwright/index.mjs';
import { frames, repo } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
const runtimePath = join(lite, 'runtime.js');
const listsPath = join(dirname(runtimePath), 'parts/lists.js');
const runtime = readFileSync(runtimePath, 'utf8').replace(
  '// @thor-lite-parts',
  () => `${existsSync(listsPath) ? readFileSync(listsPath, 'utf8') : ''}\n// @thor-lite-parts`,
);
const parts = ['row_states.js', 'attributes.js', 'row_attributes.js']
  .map((n) => readFileSync(join(lite, 'parts', n), 'utf8'))
  .join('\n');

// Items are "key|kind" (kind 0 = button, 1 = link).
const STATE = `thor.def('T', ($) => {
  const it = $.state('items', ['a|0']);
  const f = (i) => i.split('|');
  return {
    items: () => it.value, key: (i) => f(i)[0], kind: (i) => +f(i)[1],
    set: (s) => { it.value = s === '' ? [] : s.split('#'); },
  };
}, { eager: true });`;
const ROW = (k) => `<li data-tk="${k}" data-tvf="T.kind" data-tvi="0"><i>x</i><button title="go-${k}"></button></li>`;
const PAGE =
  `<!DOCTYPE html><html><head><base href="/"></head><body><ul id="l" data-tl="T.items" data-tlk="T.key">${ROW('a')}` +
  `<template data-tlt="T.items"><li data-tvf="T.kind" data-tvi="0"><i>x</i><button title="go-{{key}}"></button></li>` +
  `<template data-tvft="T.kind" data-i="1"><li><i>x</i><a title="go-{{key}}"></a></li></template></template></ul>` +
  `<script>${runtime.replace('// @thor-lite-parts', () => parts)}\n${STATE}</script></body></html>`;

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
  await p.evaluate(() => thor.use('T').set('a|0#b|1#c|0'));
  await frames(p);
  const titles = await p.evaluate(() =>
    Object.fromEntries(
      [...document.querySelectorAll('#l > [data-tk]')].map((r) => [r.dataset.tk, r.lastElementChild.tagName + ':' + r.lastElementChild.getAttribute('title')]),
    ),
  );
  check('a plain variant keeps its key', titles.c === 'BUTTON:go-c', titles.c);
  check('a replaced subtree has the row key, not {{key}}', titles.b === 'A:go-b', titles.b);
  await p.evaluate(() => thor.use('T').set('a|1#b|1#c|0'));
  await frames(p);
  const a = await p.evaluate(() => document.querySelector('#l > [data-tk=a]').lastElementChild.getAttribute('title'));
  check('an existing row that changes variant gets its key', a === 'go-a', a);
  check('no page errors', problems.length === 0, problems.join(' | '));
  await ctx.close();
} finally {
  await browser.close();
}
process.exit(results.every(Boolean) ? 0 : 1);

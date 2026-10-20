// What a row's bound text and bound attributes do when the row is added by
// the browser (cloned from the template) and its row state changes: pages
// made in memory from lib/lite/runtime.js and the row_states /
// row_attributes / attributes parts, real Chromium.
//
//   node test/e2e/checks/lite_row_bound_check.mjs
//
// B1  `row.text(style: …)` inside `row.watch`: the look of the text (its
//     class) follows the row state, in rows the server drew and in rows the
//     browser added after load. Before the fix the state patch skipped every
//     bound text, so a done task was not struck through.
// B2  `row.bind` (`aria-label`, `title` bound to row fields): in rows the
//     browser adds, the attribute has the row's own value, escaped (quotes,
//     markup, a `;`, a `:`), follows a changed item, survives a reorder and a
//     removal, and an empty value is an empty attribute.
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
const parts = ['row_states.js', 'attributes.js', 'row_attributes.js']
  .map((n) => readFileSync(join(lite, 'parts', n), 'utf8'))
  .join('\n');
const page = (body, script) =>
  `<!DOCTYPE html><html><head><base href="/"></head><body>${body}<script>${runtime.replace('// @thor-lite-parts', () => parts)}\n${script}</script></body></html>`;

// Items are "key|title|done" (a title may hold anything but `|`).
const STATE = `thor.def('T', ($) => {
  const it = $.state('items', ['a|first|0', 'b|second|1']);
  const f = (i) => i.split('|');
  return {
    items: () => it.value, key: (i) => f(i)[0], title: (i) => f(i)[1], done: (i) => f(i)[2] === '1',
    label: (i) => (f(i)[1] === '' ? '' : 'Mark ' + f(i)[1]),
    set: (s) => { it.value = s === '' ? [] : s.split('#'); },
  };
}, { eager: true });`;

// A row: the state root holds a bound text whose class changes with the
// state (what `row.text(style:)` renders) and a checkbox whose aria-label is
// bound to a field (`row.bind`). State 1 = done.
const INNER = (t, label) =>
  `<span class="plain" data-tf="T.title">${t}</span><input type="checkbox" aria-label="${label}" data-tfa="aria-label:T.label;title:T.title">`;
const ROW = (k, t, done) =>
  `<li class="${done ? 'rdone' : 'rtodo'}" data-tk="${k}" data-tvf="T.done" data-tvi="${done ? 1 : 0}" data-tp-1="|class|=rdone;0|class|=strike">${INNER(t, 'Mark ' + t)}</li>`;
const PAGE = page(
  `<ul id="l" data-tl="T.items" data-tlk="T.key">${ROW('a', 'first', 0)}${ROW('b', 'second', 1).replace('class="plain"', 'class="strike"')}` +
    `<template data-tlt="T.items"><li class="rtodo" data-tvf="T.done" data-tvi="0" data-tp-1="|class|=rdone;0|class|=strike">${INNER('', '')}</li></template></ul>`,
  STATE,
);

const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail !== '' ? ` (${detail})` : ''}`);
};

const browser = await chromium.launch();
const open = async () => {
  const ctx = await browser.newContext();
  const p = await ctx.newPage();
  p.problems = [];
  p.on('pageerror', (e) => p.problems.push(e.message));
  await ctx.route('http://lite.test/**', (r) => r.fulfill({ contentType: 'text/html', body: PAGE }));
  await p.goto('http://lite.test/');
  await p.waitForFunction(() => typeof thor !== 'undefined' && thor.use);
  await frames(p);
  return p;
};
const set = async (p, s) => {
  await p.evaluate((s) => thor.use('T').set(s), s);
  await frames(p);
};
// key → {text class, label, title}
const view = (p) =>
  p.evaluate(() =>
    Object.fromEntries(
      [...document.querySelectorAll('#l > [data-tk]')].map((r) => [
        r.dataset.tk,
        {
          cls: r.querySelector('[data-tf]').className,
          text: r.querySelector('[data-tf]').textContent,
          label: r.querySelector('input').getAttribute('aria-label'),
          title: r.querySelector('input').getAttribute('title'),
        },
      ]),
    ),
  );
const order = (p) => p.evaluate(() => [...document.querySelectorAll('#l > [data-tk]')].map((r) => r.dataset.tk).join());

try {
  const p = await open();
  // B1: a row the browser adds, in both states.
  await set(p, 'a|first|0#b|second|1#c|third|1#d|fourth|0');
  let v = await view(p);
  check('B1 server row, pending: plain text', v.a.cls === 'plain', v.a.cls);
  check('B1 server row, done: struck text', v.b.cls === 'strike', v.b.cls);
  check('B1 new row, done: struck text', v.c.cls === 'strike', v.c.cls);
  check('B1 new row, pending: plain text', v.d.cls === 'plain', v.d.cls);
  await set(p, 'a|first|1#b|second|0#c|third|0#d|fourth|1');
  v = await view(p);
  check('B1 every row follows the state (all four flipped)', v.a.cls === 'strike' && v.b.cls === 'plain' && v.c.cls === 'plain' && v.d.cls === 'strike', JSON.stringify(Object.values(v).map((r) => r.cls)));
  check('B1 the bound text keeps its own content', v.c.text === 'third' && v.d.text === 'fourth', `${v.c.text},${v.d.text}`);

  // B2: bound attributes on rows the browser adds.
  await set(p, 'a|first|0#e|say "hi" <b>x</b> & a;b:c|1#f||0');
  v = await view(p);
  check('B2 a new row gets its own label', v.e.label === 'Mark say "hi" <b>x</b> & a;b:c', v.e.label);
  check('B2 and its title (quotes, markup, ; and : are data)', v.e.title === 'say "hi" <b>x</b> & a;b:c', v.e.title);
  check('B2 markup in a label stayed text (no elements made)', (await p.locator('#l b').count()) === 0);
  check('B2 an empty value is an empty attribute (never the word null)', v.f.label === '', String(v.f.label));
  await set(p, 'f||0#a|first|0#e|say "hi" <b>x</b> & a;b:c|1');
  v = await view(p);
  check('B2 reordered: order follows the items', (await order(p)) === 'f,a,e', await order(p));
  check('B2 reordered: each row keeps its own label', v.a.label === 'Mark first' && v.e.title === 'say "hi" <b>x</b> & a;b:c' && v.f.label === '', JSON.stringify(v));
  await set(p, 'a|renamed|0');
  v = await view(p);
  check('B2 an item that changes rewrites its attribute', v.a.label === 'Mark renamed' && v.a.title === 'renamed', JSON.stringify(v.a));
  check('B2 removed rows are gone', (await order(p)) === 'a', await order(p));
  await set(p, 'z|last one|0#a|renamed|0');
  v = await view(p);
  check('B2 a row added after removals has its own label', v.z.label === 'Mark last one' && v.a.label === 'Mark renamed', JSON.stringify(v));
  check('no page errors', p.problems.length === 0, p.problems.join(' | '));
  await p.context().close();
} finally {
  await browser.close();
}
process.exit(results.every(Boolean) ? 0 : 1);

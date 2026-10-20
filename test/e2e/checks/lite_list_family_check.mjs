// A list per instance (`Watch.list(state.branchOf.withArg(slug), …)`) in the lite
// runtime, in a real browser: pages made in memory from lib/lite/runtime.js.
//
//  - each list id carries its argument (`F.branch~food`): the list calls the
//    method with it, so two lists of the same state show different rows;
//  - rows the server drew and rows the browser clones from the template;
//  - a change of the state moves only the lists it touches;
//  - a list whose argument has nothing is empty, and an argument that needs
//    escaping (`%7E`) reaches the method as the page wrote it.
//
//  - arguments that look like the markup or the id around them (`a~b`, `x/y`, unicode, quotes,
//    `<b>&amp;`, empty, `%7E`, spaces) reach the method exactly as the page wrote them, in both
//    the rows the server drew and the ones the browser clones, and moving one list moves only it.
//
//   node test/e2e/checks/lite_list_family_check.mjs
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
const runtimePath = process.env.LITE_RUNTIME ?? join(lite, 'runtime.js');
const runtime = withLists(readFileSync(runtimePath, 'utf8'), runtimePath);
const page = (body, script) =>
  `<!DOCTYPE html><html><head><base href="/"></head><body>${body}<script>${runtime.replace('// @thor-lite-parts', '')}\n${script}</script></body></html>`;

const list = (arg, rows = '') =>
  `<ul class="${arg}" data-tl="F.branch~${arg}" data-tlk="F.key">${rows}<template data-tlt="F.branch~${arg}"><li data-tf="F.name"></li></template></ul>`;

const FAMILY = page(
  `${list('food', '<li data-tk="fruit"><b data-tf="F.name">fruit</b></li>')}${list('home')}${list('none')}`,
  `thor.def('F', ($) => {
  const data = $.state('data', { food: ['fruit', 'bread'], home: ['lamp'] });
  return {
    branch: (slug) => data.value[slug] ?? [],
    key: (i) => i, name: (i) => i,
    setHome: () => { data.value = { ...data.value, home: ['lamp', 'sofa', 'rug'] }; },
  };
});`,
);

const ODD = ['a~b', 'x/y', 'é☃😀', 'q"uo\'te', '<b>&amp;', '', '%7E', ' sp '];
const attr = (v) => v.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
// Each list: the first row drawn by the server, the others cloned from its template.
const oddList = (arg, i) =>
  `<ul id="o${i}" data-tl="F.branch~${attr(arg)}" data-tlk="F.key"><li data-tk="s${i}"><b data-tf="F.name">s${i}</b></li><template data-tlt="F.branch~${attr(arg)}"><li data-tf="F.name"></li></template></ul>`;
const ODDPAGE = page(
  ODD.map(oddList).join(''),
  `thor.def('F', ($) => {
  const rows = {};
  ${JSON.stringify(ODD)}.forEach((a, i) => { rows[a] = ['s' + i, 'c' + i]; });
  const data = $.state('data', rows);
  return {
    branch: (slug) => data.value[slug] ?? [],
    key: (i) => i, name: (i) => i,
    grow: () => { const n = { ...data.value }; for (const k in n) n[k] = [...n[k], 'g']; data.value = n; },
    growOne: (a) => { data.value = { ...data.value, [a]: [...data.value[a], 'one'] }; },
  };
});`,
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
  await ctx.route('http://lite.test/**', (r) => r.fulfill({ contentType: 'text/html', body: FAMILY }));
  await p.goto('http://lite.test/');
  await p.waitForFunction(() => typeof thor !== 'undefined');
  await p.evaluate(() => thor.use('F'));
  const rows = (cls) => p.evaluate((c) => [...document.querySelectorAll(`.${c} > li`)].map((l) => l.textContent), cls);
  const settled = async (cls, want) => {
    await p.waitForFunction(([c, w]) => [...document.querySelectorAll(`.${c} > li`)].map((l) => l.textContent).join() === w, [cls, want], { timeout: 2000 }).catch(() => {});
    return (await rows(cls)).join();
  };
  check('food shows its own two rows (one drawn by the server, one cloned)', (await settled('food', 'fruit,bread')) === 'fruit,bread', (await rows('food')).join());
  check('home shows its own single row', (await settled('home', 'lamp')) === 'lamp', (await rows('home')).join());
  check('an argument with nothing is an empty list', (await rows('none')).length === 0);
  await p.evaluate(() => thor.use('F').setHome());
  check('a change of the state updates the list it touches', (await settled('home', 'lamp,sofa,rug')) === 'lamp,sofa,rug', (await rows('home')).join());
  check('and leaves the others as they were', (await rows('food')).join() === 'fruit,bread');
  check('no page errors', problems.length === 0, problems.join(' | '));

  // --- Arguments that look like the markup or like the id -----------------------------------------
  const odd = await ctx.newPage();
  const oddProblems = [];
  odd.on('pageerror', (e) => oddProblems.push(e.message));
  await ctx.route('http://lite.test/odd', (r) => r.fulfill({ contentType: 'text/html', body: ODDPAGE }));
  await odd.goto('http://lite.test/odd');
  await odd.waitForFunction(() => typeof thor !== 'undefined');
  await odd.evaluate(() => thor.use('F'));
  const oddRows = (i) => odd.evaluate((n) => [...document.querySelectorAll(`#o${n} > li`)].map((l) => l.textContent).join(), i);
  const oddSettled = async (i, want) => {
    await odd.waitForFunction(([n, w]) => [...document.querySelectorAll(`#o${n} > li`)].map((l) => l.textContent).join() === w, [i, want], { timeout: 2000 }).catch(() => {});
    return oddRows(i);
  };
  for (const [i, arg] of ODD.entries()) {
    const got = await oddSettled(i, `s${i},c${i}`);
    check(`argument ${JSON.stringify(arg)}: its rows are its own (server row + clone)`, got === `s${i},c${i}`, got);
  }
  await odd.evaluate(() => thor.use('F').growOne('x/y'));
  check('one list moves and no other', (await oddSettled(1, 's1,c1,one')) === 's1,c1,one' && (await oddRows(0)) === 's0,c0' && (await oddRows(5)) === 's5,c5', `${await oddRows(1)} | ${await oddRows(0)}`);
  await odd.evaluate(() => thor.use('F').grow());
  let all = true;
  for (const [i] of ODD.entries()) {
    const want = i === 1 ? 's1,c1,one,g' : `s${i},c${i},g`;
    all = all && (await oddSettled(i, want)) === want;
  }
  check('a change of the state moves every list', all);
  check('no page errors (odd arguments)', oddProblems.length === 0, oddProblems.join(' | '));
} finally {
  await browser.close();
}
const failed = results.filter((r) => !r).length;
console.log(failed ? `${failed} of ${results.length} failed` : `${results.length} passed`);
process.exit(failed ? 1 : 0);

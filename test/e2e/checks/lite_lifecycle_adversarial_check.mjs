// The life of a lite state where the page is not polite, in
// Chromium, Firefox and WebKit: pages made in memory from lib/lite/runtime.js
// and its `lifecycle` part, no app to build.
//
//  - A keyed list reordered (`moveBefore` in Chromium, `insertBefore` in the
//    others) and a row moved into a modal <dialog> (the top layer) are not
//    disposals: the observer reads the settled page.
//  - 2000 rows removed at once are swept in linear time (the sweep used to
//    scan the page once per state), and a toast leaving costs nothing.
//  - `onHydrated` wakes at idle where `requestIdleCallback` does not exist
//    (WebKit) and where it does.
//
//   node test/e2e/checks/lite_lifecycle_adversarial_check.mjs
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { chromium, firefox, webkit } from '../runner/node_modules/playwright/index.mjs';
import { browsersFor, repo } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
// Keyed lists are the runtime's part `lists`, sewn in first (an older
// runtime, without that part next to it, has them inside).
const withLists = (src, at) => {
  const p = join(dirname(at), 'parts/lists.js');
  return src.replace('// @thor-lite-parts', () => `${existsSync(p) ? readFileSync(p, 'utf8') : ''}\n// @thor-lite-parts`);
};
const runtimePath = join(lite, 'runtime.js');
const runtime = withLists(readFileSync(runtimePath, 'utf8'), runtimePath);
const part = readFileSync(join(lite, 'parts/lifecycle.js'), 'utf8');
const page = (body, script) =>
  `<!DOCTYPE html><html><head><base href="/"></head><body>${body}<script>${runtime.replace('// @thor-lite-parts', () => part)}\n${script}</script></body></html>`;

const ROWS = page(
  `<ul id="ul" data-tl="L.items" data-tlk="L.key"><template data-tlt="L.items"><li><b data-tf="L.text"></b><i data-tt="Row#{{key}}.label"></i></li></template></ul><dialog id="dlg"></dialog><div id="toasts"></div>`,
  `window.log = [];
window.timers = 0;
thor.def('L', ($) => {
  const items = $.state('items', []);
  return { items: () => items.value, key: (i) => i, text: (i) => i, set: (s) => { items.value = s ? s.split(',') : []; } };
});
thor.def('Row', ($) => ({
  label: () => $.key,
  $l: { h: () => { timers++; log.push('h' + $.key); }, d: () => { timers--; log.push('d' + $.key); } },
}), { idle: true });`,
);
const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail !== '' ? ` (${detail})` : ''}`);
};

async function run(name, type) {
  const browser = await type.launch();
  try {
    const ctx = await browser.newContext();
    const p = await ctx.newPage();
    const problems = [];
    p.on('pageerror', (e) => problems.push(e.message));
    await ctx.route('http://lite.test/**', (r) => r.fulfill({ contentType: 'text/html', body: ROWS }));
    await p.goto('http://lite.test/x');
    await p.waitForFunction(() => typeof thor !== 'undefined');
    const set = (s) => p.evaluate((s) => thor.use('L').set(s), s);
    const settle = () => p.evaluate(() => new Promise((r) => setTimeout(r, 80)));
    const log = () => p.evaluate(() => log.join());
    const ric = await p.evaluate(() => typeof requestIdleCallback);

    await set('a,b,c,d');
    await p.waitForFunction(() => timers === 4);
    check(`${name} (rIC ${ric}): rows wake at idle without an event`, (await log()) === 'ha,hb,hc,hd', await log());

    await set('d,c,b,a');
    await settle();
    check(`${name}: a list reordered disposes nothing`, (await log()) === 'ha,hb,hc,hd', await log());
    check(`${name}: reordered, the texts follow`, (await p.locator('i').allTextContents()).join() === 'd,c,b,a');

    // A row into a modal dialog (top layer) and back.
    await p.evaluate(() => {
      const dlg = document.getElementById('dlg');
      dlg.showModal();
      dlg.append(document.querySelector('li'));
    });
    await settle();
    check(`${name}: a row moved into a modal <dialog> is not a disposal`, (await log()) === 'ha,hb,hc,hd', await log());
    await p.evaluate(() => document.getElementById('dlg').close());
    await p.evaluate(() => document.getElementById('dlg').remove());
    await settle();
    check(`${name}: the dialog removed with the row inside disposes that row once`, (await log()).split(',').filter((x) => x[0] === 'd').length === 1, await log());

    // Toasts leaving cost nothing.
    const scans = await p.evaluate(async () => {
      let n = 0;
      const q = Document.prototype.querySelectorAll;
      Document.prototype.querySelectorAll = function (...a) { n++; return q.apply(this, a); };
      const qs = Document.prototype.querySelector;
      Document.prototype.querySelector = function (...a) { n++; return qs.apply(this, a); };
      for (let i = 0; i < 20; i++) {
        const t = document.createElement('p');
        t.textContent = 'toast';
        document.getElementById('toasts').append(t);
        await new Promise((r) => setTimeout(r, 0));
        t.remove();
        await new Promise((r) => setTimeout(r, 0));
      }
      Document.prototype.querySelectorAll = q;
      Document.prototype.querySelector = qs;
      return n;
    });
    check(`${name}: elements with no state attribute leaving do not scan the page`, scans === 0, String(scans));

    // 2000 rows out at once.
    const keys = Array.from({ length: 2000 }, (_, i) => `r${i}`).join();
    await set(keys);
    await p.waitForFunction(() => timers === 2000, null, { timeout: 60000 });
    const ms = await p.evaluate(async () => {
      const t = performance.now();
      thor.use('L').set('');
      await new Promise((r) => setTimeout(r, 0));
      await new Promise((r) => setTimeout(r, 0));
      while (timers !== 0) await new Promise((r) => setTimeout(r, 0));
      return performance.now() - t;
    });
    check(`${name}: 2000 rows removed at once are swept in linear time`, ms < 1500, `${Math.round(ms)} ms`);
    check(`${name}: no page errors`, problems.length === 0, problems.join(' | '));
  } finally {
    await browser.close();
  }
}

try {
  for (const [name, type] of browsersFor([['chromium', chromium], ['firefox', firefox], ['webkit', webkit]])) await run(name, type);
} catch (e) {
  check('no exception', false, e?.stack ?? String(e));
}
const failed = results.filter((r) => !r).length;
console.log(failed ? `${failed} of ${results.length} failed` : `${results.length} passed`);
process.exit(failed || !results.length ? 1 : 0);

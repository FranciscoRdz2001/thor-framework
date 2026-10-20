// Checks of the lite engine's `local_storage` part (`state(…, local:)`):
// real Chromium, WebKit and Firefox (those Playwright has installed), pages
// built in memory from lib/lite/runtime.js, the `json` and `local_storage`
// parts and a state shaped like thor_builder's translation. A value survives
// a reload, follows another tab (the `storage` event) without echoing, is
// written once per frame, and blocked storage leaves a working page.
//
//   node test/e2e/checks/lite_local_storage_check.mjs [chromium|webkit|firefox…]
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import * as pw from '../runner/node_modules/playwright/index.mjs';
import { repo } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
const runtime = readFileSync(join(lite, 'runtime.js'), 'utf8');
const part = (n) => readFileSync(join(lite, 'parts', `${n}.js`), 'utf8');
const bundle = runtime.replace('// @thor-lite-parts', () => ['json', 'local_storage'].map(part).join('\n'));

// What thor_builder writes for
//   class DraftViewModel extends ThorState {
//     final count = state(0, local: 'count');
//     final text = state('', local: 'draft');
//     String label() => '${text.value}|${count.value}';
//     void inc() => count.value++;
//     void hola() => text.value = 'hola';
//   }
const state = `{
const $local = thor.local;
thor.def('Draft', ($) => {
  const count = $local($.state('count', 0), 'count', null, (x) => Number.isInteger(x), null);
  const text = $local($.state('text', ''), 'draft', null, (x) => typeof x === 'string', null);
  return {
    count: () => count.value,
    text: () => text.value,
    label: () => \`\${text.value}|\${count.value}\`,
    inc: () => { count.value++; },
    hola: () => { text.value = 'hola'; },
    $s: { count, text },
  };
}, { eager: $local.has('Draft', 'count', 'draft') });
}`;

// The engine as an app ships it: an external `<script defer>`, cached.
const html = `<!DOCTYPE html><html><head><meta charset="utf-8">
<script>
// Every write to the storage, counted (the page's own, not another tab's).
window.writes = [];
try {
  const set = Storage.prototype.setItem;
  Storage.prototype.setItem = function (k, v) { window.writes.push(k + '=' + v); return set.call(this, k, v); };
} catch {}
// What the label says at the first frame it is in (a rAF runs before the
// paint): the default there is a visible flash.
const tick = () => { const l = document.getElementById('label'); if (!l) return requestAnimationFrame(tick); window.firstFrame = l.textContent; };
requestAnimationFrame(tick);
</script>
<script defer src="/engine.js"></script></head><body>
<p id="label" data-tt="Draft.label">|0</p>
<button id="inc" data-t-on="click:Draft.inc">inc</button>
<button id="hola" data-t-on="click:Draft.hola">hola</button>
</body></html>`;
const engine = `${bundle}\n${state}`;

// Storage blocked as a browser that blocks site data does it: the getter
// throws a SecurityError.
const blocked = `Object.defineProperty(window, 'localStorage', { configurable: true, get() { throw new DOMException('blocked', 'SecurityError'); } });`;

const results = [];
const check = (name, label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} [${name}] ${label}${detail !== '' ? ` (${detail})` : ''}`);
};

const wanted = process.argv.slice(2);
const engines = wanted.length ? wanted : [process.env.E2E_BROWSER || ['chromium', 'webkit', 'firefox']].flat();
const label = (p) => p.textContent('#label');
const frame = (p) => p.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
const writes = (p) => p.evaluate(() => window.writes.splice(0));

for (const name of engines) {
  let browser;
  try {
    browser = await pw[name].launch();
  } catch (e) {
    console.log(`SKIP [${name}] not installed (${e.message.split('\n')[0]})`);
    continue;
  }
  const context = async (init) => {
    const ctx = await browser.newContext();
    if (init) await ctx.addInitScript(init);
    await ctx.route('http://lite.test/**', (r) =>
      new URL(r.request().url()).pathname === '/engine.js'
        ? r.fulfill({ contentType: 'text/javascript', headers: { 'cache-control': 'max-age=3600' }, body: engine })
        : r.fulfill({ contentType: 'text/html', body: html }),
    );
    return ctx;
  };
  const open = async (ctx) => {
    const p = await ctx.newPage();
    p.problems = [];
    p.on('pageerror', (e) => p.problems.push(e.message));
    p.on('console', (m) => m.type() === 'error' && p.problems.push(m.text()));
    await p.goto('http://lite.test/');
    await p.waitForFunction(() => typeof thor !== 'undefined');
    await frame(p);
    return p;
  };
  try {
    // Reload, batching, invalid values.
    {
      const ctx = await context();
      const a = await open(ctx);
      check(name, 'nothing stored: the server value, the state not started', (await label(a)) === '|0' && !(await a.evaluate(() => localStorage.length)));
      await a.click('#inc');
      await a.click('#inc');
      await a.click('#hola');
      await frame(a);
      const w = await writes(a);
      check(name, 'a change is stored as JSON at thor-s.<key>', (await a.evaluate(() => localStorage.getItem('thor-s.count'))) === '2' && (await a.evaluate(() => localStorage.getItem('thor-s.draft'))) === '"hola"', w.join(' '));
      // 20 clicks in one task: 20 changes (an action is a batch), no write yet.
      const during = await a.evaluate(() => {
        for (let i = 0; i < 20; i++) document.getElementById('inc').click();
        return window.writes.splice(0).length;
      });
      check(name, 'a burst writes nothing before the frame', during === 0, during);
      await frame(a);
      const bw = await writes(a);
      check(name, 'a burst of 20 changes is one write, with the last value', bw.length === 1 && bw[0] === 'thor-s.count=22', bw.join(' '));
      await a.reload();
      await a.waitForFunction(() => typeof thor !== 'undefined');
      await frame(a);
      check(name, 'a reload shows the stored values (the state starts at load)', (await label(a)) === 'hola|22', await label(a));
      check(name, 'starting does not rewrite the stored values', (await writes(a)).length === 0);
      // Not a check: whether the first frame showed the default (a flash)
      // depends on when the deferred engine ran (a known, documented trade-off).
      console.log(`INFO [${name}] first frame after a reload: ${await a.evaluate(() => window.firstFrame)}`);
      await a.evaluate(() => { localStorage.setItem('thor-s.count', '"x"'); localStorage.setItem('thor-s.draft', '{'); });
      await a.reload();
      await a.waitForFunction(() => typeof thor !== 'undefined');
      await frame(a);
      check(name, 'a stored value of another type or broken JSON is ignored', (await label(a)) === '|0', await label(a));
      check(name, 'no errors on the page', a.problems.length === 0, a.problems.join(' | '));
      await ctx.close();
    }
    // Two tabs.
    {
      const ctx = await context();
      const a = await open(ctx);
      const b = await open(ctx);
      await a.click('#inc');
      await frame(a);
      await b.waitForFunction(() => document.getElementById('label').textContent === '|1', null, { timeout: 3000 }).catch(() => {});
      check(name, 'another tab follows a change (storage event)', (await label(b)) === '|1', await label(b));
      await frame(b);
      await frame(b);
      check(name, 'the tab that follows does not write it back', (await writes(b)).length === 0);
      await b.click('#inc');
      await b.click('#hola');
      await frame(b);
      await a.waitForFunction(() => document.getElementById('label').textContent === 'hola|2', null, { timeout: 3000 }).catch(() => {});
      check(name, 'and the other way round', (await label(a)) === 'hola|2', await label(a));
      await frame(a);
      check(name, 'no echo back', (await writes(a)).length === 1, 'the first tab wrote only its own change');
      await b.evaluate(() => localStorage.removeItem('thor-s.count'));
      await a.waitForTimeout(150);
      check(name, 'a removed key leaves the other tab as it is', (await label(a)) === 'hola|2', await label(a));
      check(name, 'no errors in either tab', a.problems.length + b.problems.length === 0, [...a.problems, ...b.problems].join(' | '));
      await ctx.close();
    }
    // Blocked storage.
    {
      const ctx = await context(blocked);
      const a = await open(ctx);
      const threw = await a.evaluate(() => { try { localStorage; return false; } catch { return true; } });
      check(name, 'the test blocks storage (the getter throws)', threw);
      await a.click('#inc');
      await a.click('#inc');
      await frame(a);
      check(name, 'blocked storage: the page still works, in memory', (await label(a)) === '|2', await label(a));
      check(name, 'blocked storage: no exception, no console error', a.problems.length === 0, a.problems.join(' | '));
      await ctx.close();
    }
  } finally {
    await browser.close();
  }
}

const failed = results.filter((ok) => !ok).length;
console.log(`\n${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);

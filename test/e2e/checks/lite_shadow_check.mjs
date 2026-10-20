// App names that are JS globals, in a real browser (Chromium, Firefox,
// WebKit): a lite state whose app has `class Date`, `class Promise`,
// `class Reflect` and a top-level `int document`, `window()`,
// `setTimeout`. The node oracle (thor_builder/test/lite_shadow_test.dart)
// cannot see what only a browser has: `document` and `window` already
// belong to the page (a `let document` at the top of a script is a
// SyntaxError there), `Date` and `Promise` are what the emitted code and the
// `await` of the runtime use. The bundle is the real one (the runtime, its
// parts, the translated states), made by thor_builder's
// test/lite_shadow_dump.dart.
//
//   node test/e2e/checks/lite_shadow_check.mjs
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { chromium, firefox, webkit } from '../runner/node_modules/playwright/index.mjs';
import { browsersFor, repo } from './lib/e2e.mjs';

const out = join(mkdtempSync(join(tmpdir(), 'thor-lite-shadow-')), 'bundle.js');
const dump = spawnSync('dart', ['run', 'test/lite_shadow_dump.dart', out], { cwd: join(repo, 'packages/thor_builder'), encoding: 'utf8' });
if (dump.status !== 0) {
  console.log(`FAIL the bundle was not made\n${dump.stdout}${dump.stderr}`);
  process.exit(1);
}
const bundle = readFileSync(out, 'utf8');
const html = `<!DOCTYPE html><html><head><base href="/"><title>shadow</title></head><body><p id="p">hola</p><script>${bundle}</script></body></html>`;

let failed = 0;
const check = (label, ok, detail = '') => {
  if (!ok) failed++;
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail !== '' ? ` (${detail})` : ''}`);
};

for (const [name, type] of browsersFor([['chromium', chromium], ['firefox', firefox], ['webkit', webkit]])) {
  const browser = await type.launch();
  try {
    const ctx = await browser.newContext();
    const p = await ctx.newPage();
    const problems = [];
    p.on('pageerror', (e) => problems.push(e.message));
    await ctx.route('http://lite.test/**', (r) => r.fulfill({ contentType: 'text/html', body: html }));
    await p.goto('http://lite.test/x');
    await p.waitForFunction(() => typeof thor !== 'undefined', null, { timeout: 10_000 }).catch(() => {});
    check(`${name}: the bundle loads without an error`, problems.length === 0 && (await p.evaluate(() => typeof thor)) === 'object', problems.join('; '));
    const got = await p.evaluate(() => thor.use('ShadowState').run());
    check(`${name}: the state with app names that shadow globals runs`, got === 'day 3 p reflect 4 w [1, 2] loc 6 fast,slow 5', got);
    check(`${name}: the page's own globals are untouched`, await p.evaluate(() => document.getElementById('p').textContent === 'hola' && typeof window.Date === 'function' && new Date(2020, 0, 2).getDate() === 2 && typeof Promise.resolve === 'function' && document.title === 'shadow'));
    check(`${name}: no error afterwards`, problems.length === 0, problems.join('; '));
  } finally {
    await browser.close();
  }
}
process.exit(failed ? 1 : 0);

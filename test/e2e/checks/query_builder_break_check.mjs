// Adversarial cases in a real browser: QueryBuilder over the ways a query can
// end that the happy path never draws, on test/fixtures/apps/server_query's public `/qb`
// (build/server, the lite engine).
//
//   tool/thor e2e qb-break                 (builds test/fixtures/apps/server_query, runs)
//   node test/e2e/checks/query_builder_break_check.mjs
//
// N1  a query that answers null is "done without data", its own state: the
//     builder's no-data branch, not the list with an empty value.
// N2  a failed first paint with `initialData`: the argument moves while it is
//     failed (error, then data, then error again) and every builder over the
//     same query follows, also the nested one and the ones inside list rows.
// N3  no JavaScript: each builder shows the state the server saw.
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { e2e, hydrated, repo, settle, trackHydration } from './lib/e2e.mjs';

const children = [];
const tmp = mkdtempSync(join(tmpdir(), 'thor-qb-'));
writeFileSync(join(tmp, 'index.html'), '<!doctype html><title>placeholder</title>');
process.on('exit', () => {
  for (const c of children) if (c.exitCode === null) c.kill('SIGKILL');
  rmSync(tmp, { recursive: true, force: true });
});

const freePort = () =>
  new Promise((ok) => {
    const s = createServer().listen(0, '127.0.0.1', () => {
      const { port } = s.address();
      s.close(() => ok(port));
    });
  });

async function waitFor(url, timeout = 20_000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    try {
      if ((await fetch(url, { redirect: 'manual' })).status < 500) return;
    } catch {}
    await new Promise((r) => setTimeout(r, 100));
  }
  throw new Error(`nothing answered at ${url}`);
}

await e2e('qb-break', { site: tmp, timeout: 120_000 }, async (t) => {
  const bin = join(repo, 'test/fixtures/apps/server_query/build/server');
  if (!existsSync(bin)) throw new Error('test/fixtures/apps/server_query/build/server is missing: build it first (tool/thor e2e builds it)');
  const port = await freePort();
  children.push(spawn(bin, [], { cwd: join(repo, 'test/fixtures/apps/server_query'), env: { ...process.env, PORT: `${port}` }, stdio: 'ignore' }));
  const app = `http://127.0.0.1:${port}`;
  await waitFor(`${app}/qb`);

  const open = async (options = {}) => {
    const page = await t.page(options);
    await trackHydration(page);
    await page.goto(`${app}/qb`);
    await hydrated(page);
    return page;
  };
  const text = (page) => page.locator('body').innerText();
  const lines = async (page, prefix) => (await text(page)).split('\n').filter((l) => l.startsWith(prefix));
  const has = async (page, want, timeout = 4000) => !!(await settle(page, (w) => document.body.innerText.includes(w), want, { timeout }));
  const gone = async (page, want, timeout = 4000) => !!(await settle(page, (w) => !document.body.innerText.includes(w), want, { timeout }));
  const click = (page, name) => page.getByRole('button', { name, exact: true }).click();
  // A real error is a page error: a 5xx is logged by Chrome on its own.
  const clean = (page) => page.problems.filter((p) => !/Failed to load resource/.test(p));

  // --- N3 · without JavaScript ---------------------------------------------------
  {
    const bare = await t.page({ javaScriptEnabled: false });
    await bare.goto(`${app}/qb`);
    const body = await text(bare);
    t.check('N3 no JS: the query with data', body.includes('maybe: done con dato') && body.includes('maybe=3'), body);
    t.check('N3 no JS: the failed query, its builder and the twin one', body.includes('flaky: error sin dato') && body.includes('Servicio caído.') && body.includes('otro: error sin dato'), body);
    t.check('N3 no JS: the builder inside the rows says the same in every row', (await lines(bare, 'fila:')).length === 4 && (await lines(bare, 'fila:')).every((l) => l === 'fila: done con dato'));
    await bare.context().close();
  }

  // --- N1 · a null answer ---------------------------------------------------------
  {
    const page = await open();
    await click(page, 'Maybe 0');
    t.check('N1 a null answer shows the no-data branch', await has(page, 'maybe: done sin dato'), await text(page));
    t.check('N1 and not the branch with data', !(await text(page)).includes('maybe: done con dato') && !(await text(page)).includes('maybe=-'));
    // The outer builder failed on the first paint: it shows the nested one once it heals.
    await click(page, 'Flaky 5');
    t.check('N1 the builder inside another one follows', await has(page, 'dentro: done sin dato'), await text(page));
    t.check('N1 the builders in the rows follow', (await lines(page, 'fila:')).every((l) => l === 'fila: done sin dato'), (await lines(page, 'fila:')).join('|'));
    await click(page, 'Maybe 7');
    t.check('N1 data again: the branch with data comes back with its value', (await has(page, 'maybe: done con dato')) && (await has(page, 'maybe=7')), await text(page));
    await click(page, 'Maybe 0');
    t.check('N1 and null once more', await has(page, 'maybe: done sin dato'));
    // Quick alternation: the last answer wins.
    await page.evaluate(() => {
      const press = (n) => [...document.querySelectorAll('button')].find((b) => b.innerText.trim() === n).click();
      for (const n of ['Maybe 7', 'Maybe 0', 'Maybe 7', 'Maybe 0', 'Maybe 7']) press(n);
    });
    t.check('N1 five quick changes end on the last (with data)', (await has(page, 'maybe=7')) && (await has(page, 'maybe: done con dato')), await text(page));
    t.check('N1 no page errors', clean(page).length === 0, clean(page).join('; '));
    await page.context().close();
  }

  // --- N2 · error → data → error while the argument moves ---------------------------
  {
    const page = await open();
    t.check('N2 the first paint failed', (await text(page)).includes('flaky: error sin dato'));
    await click(page, 'Flaky 5');
    t.check('N2 the retry lands: done with data in both builders', (await has(page, 'flaky: done con dato')) && (await has(page, 'otro: done con dato')), await text(page));
    t.check('N2 the nested builder appears with its state', await has(page, 'dentro: done con dato'));
    t.check('N2 the error is gone', !(await text(page)).includes('Servicio caído.'));
    await click(page, 'Flaky 0');
    t.check('N2 failing again: error in both, the twin too', (await has(page, 'flaky: error sin dato')) && (await has(page, 'otro: error sin dato')) && (await has(page, 'Servicio caído.')), await text(page));
    t.check('N2 the error state has no nested builder', !(await text(page)).includes('dentro:'));
    // Two quick changes on top of an error: the last one wins, no flash of the old error.
    await page.evaluate(() => {
      const press = (n) => [...document.querySelectorAll('button')].find((b) => b.innerText.trim() === n).click();
      press('Flaky 5');
      press('Flaky 0');
      press('Flaky 5');
    });
    t.check('N2 three quick changes end on the last (done)', (await has(page, 'flaky: done con dato')) && (await gone(page, 'Servicio caído.')), await text(page));
    t.check('N2 no page errors', clean(page).length === 0, clean(page).join('; '));
    await page.context().close();
  }
});

// Streaming SSR in a real browser: a page whose data is slow goes
// out with its skeletons and the values replace them as they arrive, on
// test/fixtures/apps/server_query's public `/defer?ms=` (build/server, the lite engine).
//
//   tool/thor e2e defer                    (builds test/fixtures/apps/server_query, runs)
//   node test/e2e/checks/defer_check.mjs
//
// - the first paint shows the skeletons and the rest of the page well
//   before the slow data (an artificial delay of 1.5 s): the response
//   starts at once, no skeleton is left when it ends.
// - each value replaces its skeleton in the order it arrives; a failed
//   one shows the builder's error state with the visitor's message, never
//   the exception.
// - a ThorState button inside content that arrived late works (it is wired
//   by the engine, which may have loaded before the content came).
// - no JavaScript: the late content is shown (at the end of the page), the
//   skeletons are not.
// - navigation never pauses: a link followed while the data is still on its
//   way goes at once, and the swap script leaves no console errors.
// - a strict CSP (`script-src 'self' 'sha256-…'`, no `'unsafe-inline'`): the
//   one hashed script of the page swaps every late piece; the hash is the
//   one docs/guia/es/sesion-y-seguridad.md lists.
// - head future: `defer(f, head: true)` is awaited until it is
//   done before the head goes out: the title is the real one and a NotFound
//   is a real 404 however slow the backend is. Only an opt-in `headBudget`
//   gives up (fallback title, status 200).
// - one result in two places (a ResponsiveLayout's variants): the piece is
//   sent once and fills both, at both viewports.
// - measurement: first byte and first contentful paint against the same
//   page that waits for its data (`?sync=1`, what thor did before).
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { e2e, hydrated, repo, settle, trackHydration } from './lib/e2e.mjs';

const children = [];
const tmp = mkdtempSync(join(tmpdir(), 'thor-defer-'));
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

const median = (xs) => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)];

await e2e('defer', { site: tmp, timeout: 180_000 }, async (t) => {
  const bin = join(repo, 'test/fixtures/apps/server_query/build/server');
  if (!existsSync(bin)) throw new Error('test/fixtures/apps/server_query/build/server is missing: build it first (tool/thor e2e builds it)');
  const port = await freePort();
  children.push(spawn(bin, [], { cwd: join(repo, 'test/fixtures/apps/server_query'), env: { ...process.env, PORT: `${port}` }, stdio: 'ignore' }));
  const app = `http://127.0.0.1:${port}`;
  await waitFor(`${app}/defer?ms=10`);

  const skeletons = (page) => page.locator('[data-thor-skeleton]:visible').count();
  const has = async (page, want, timeout = 6000) => !!(await settle(page, (w) => document.body.innerText.includes(w), want, { timeout }));
  const clean = (page) => page.problems.filter((p) => !/Failed to load resource/.test(p));

  // --- the first paint has the skeletons, before the data ---------------------
  {
    const page = await t.page();
    await trackHydration(page);
    const started = Date.now();
    await page.goto(`${app}/defer?ms=1500`, { waitUntil: 'commit' });
    const seen = await settle(
      page,
      () => document.querySelectorAll('[data-thor-skeleton]').length === 3 && document.body.innerText.includes('Footer (not deferred)'),
      null,
      { timeout: 4000 },
    );
    const at = Date.now() - started;
    t.check('the skeletons and the whole page are there before the slow data', !!seen && at < 1000, `${at} ms`);
    t.check('the slow data is not there yet', !(await page.locator('body').innerText()).includes('Loaded:'));
    t.check('the title (head) came with the shell', (await page.title()) === 'Deferred');

    // --- each value replaces its skeleton ---------------------------------------
    t.check('the first value replaces its skeleton', await has(page, 'Loaded: slow value', 4000));
    const afterFirst = await page.locator('body').innerText();
    t.check('…before the slower one', !afterFirst.includes('Loaded: slower value'), afterFirst);
    t.check('the slower one follows', await has(page, 'Loaded: slower value', 6000));
    t.check('the failed one shows the error state', await has(page, 'Failed: Something went wrong'));
    t.check('…and never the exception', !(await page.locator('body').innerText()).includes('secret backend detail'));
    await page.waitForLoadState('load');
    t.check('no skeleton is left', (await skeletons(page)) === 0, `${await skeletons(page)}`);
    t.check('no comment markers or hidden pieces are left behind', (await page.locator('[data-thor-late]').count()) === 0);

    // --- a state inside late content --------------------------------------------
    await hydrated(page);
    await page.getByRole('button', { name: 'Count', exact: true }).click();
    t.check('a ThorState button inside streamed content works', await has(page, 'clicks=1', 3000));
    await page.getByRole('button', { name: 'Count', exact: true }).click();
    t.check('…and again', await has(page, 'clicks=2', 3000));
    t.check('no console errors', clean(page).length === 0, clean(page).join(' | '));
    await page.context().close();
  }

  // --- …also when the state woke before the content came ---------------------
  {
    const page = await t.page();
    await trackHydration(page);
    // The engine loads after `load`, which waits for the end of the response: a
    // slow stream keeps the document open, and a click on the page's own button
    // raises the engine and wakes the state before the late content is in.
    await page.goto(`${app}/defer?ms=1500&early=1`, { waitUntil: 'commit' });
    await settle(page, () => document.body.innerText.includes('Count early'), null, { timeout: 3000 });
    await page.getByRole('button', { name: 'Count early', exact: true }).click();
    t.check('the state woke (engine and click) before the late content is in', !!(await settle(page, () => window.__thorHydrated === true && document.body.innerText.includes('clicks=1'), null, { timeout: 4000 })) && !(await page.locator('body').innerText()).includes('Loaded:'));
    t.check('the content comes after', await has(page, 'Loaded: slow value', 5000));
    // The late Watch shows the state as it is in the browser, not as the server drew it.
    const labels = await page.locator('[data-tt="DeferState.label"]').allInnerTexts();
    t.check('the late Watch is bound to the running state', labels.length === 2 && labels.every((l) => l === 'clicks=1'), labels.join(','));
    await page.getByRole('button', { name: 'Count', exact: true }).click();
    const after = await page.locator('[data-tt="DeferState.label"]').allInnerTexts();
    t.check('a button of the late content moves both', after.every((l) => l === 'clicks=2'), after.join(','));
    await page.context().close();
  }

  // --- without JavaScript -----------------------------------------------------
  {
    const bare = await t.page({ javaScriptEnabled: false });
    await bare.goto(`${app}/defer?ms=300`);
    const body = await bare.locator('body').innerText();
    t.check('no JS: the data is on the page', body.includes('Loaded: slow value') && body.includes('Loaded: slower value') && body.includes('Failed: Something went wrong'), body);
    t.check('no JS: no skeleton shows', (await skeletons(bare)) === 0);
    t.check('no JS: the header and the footer are there', body.includes('Header (not deferred)') && body.includes('Footer (not deferred)'));
    await bare.context().close();
  }

  // --- navigation never pauses ------------------------------------------------
  {
    const page = await t.page();
    await page.goto(`${app}/defer?ms=3000`, { waitUntil: 'commit' });
    await settle(page, () => !!document.querySelector('a[href="/lab"]'), null, { timeout: 3000 });
    const clicked = Date.now();
    await Promise.all([page.waitForURL('**/lab', { timeout: 2500 }), page.locator('a[href="/lab"]').click()]);
    const went = Date.now() - clicked;
    t.check('a link followed while the data is on its way goes at once', went < 1500, `${went} ms`);
    t.check('the next page is there', (await page.locator('body').innerText()).length > 0);
    await page.waitForTimeout(300);
    t.check('no console errors', clean(page).length === 0, clean(page).join(' | '));
    await page.context().close();
  }

  // --- a strict CSP ------------------------------------------------------------
  {
    const html = await (await fetch(`${app}/defer?ms=50`)).text();
    const swap = [...html.matchAll(/<script>([^<]*function \$thor[^<]*)<\/script>/g)].map((m) => m[1]);
    t.check('the page has exactly one script that swaps pieces', swap.length === 1, `${swap.length}`);
    const hash = `'sha256-${createHash('sha256').update(swap[0] ?? '').digest('base64')}'`;
    const guide = readFileSync(join(repo, 'docs/guia/es/sesion-y-seguridad.md'), 'utf8');
    t.check('its hash is in the security guide (CSP table)', guide.includes(hash), hash);
    t.check('no piece carries a script of its own', !/<script>\$thor\(/.test(html));
    const page = await t.page();
    await page.route(`${app}/defer*`, async (route) => {
      const r = await route.fetch();
      await route.fulfill({ response: r, headers: { ...r.headers(), 'content-security-policy': `script-src 'self' ${hash}` } });
    });
    await page.goto(`${app}/defer?ms=300`, { waitUntil: 'load' });
    t.check('under the CSP every late value is in place', await has(page, 'Loaded: slow value', 6000) && await has(page, 'Loaded: slower value', 6000));
    t.check('…and no skeleton is left', (await skeletons(page)) === 0);
    await page.context().close();
  }

  // --- the head budget ----------------------------------------------------------
  {
    const timed = async (url) => {
      const started = Date.now();
      const res = await fetch(url);
      const headers = Date.now() - started;
      return { res, headers, text: await res.text() };
    };
    const ok = await timed(`${app}/defer?ms=50&head=ok`);
    t.check('inside the budget: 200 with the real title in the head', ok.res.status === 200 && ok.text.includes('<title>Real product name</title>'));
    t.check('…and the product is drawn in the shell, no skeleton', ok.text.includes('Product: Real product name') && !ok.text.includes('Product loading'));
    const missing = await timed(`${app}/defer?ms=50&head=missing`);
    t.check('a NotFound inside the budget is a real 404', missing.res.status === 404, `${missing.res.status}`);
    t.check('…with no page content', !missing.text.includes('Header (not deferred)'));
    const slow = await timed(`${app}/defer?ms=50&head=slow`);
    t.check('no budget: a slow product (1.5 s) still gives the real title in a 200', slow.res.status === 200 && slow.text.includes('<title>Real product name</title>'));
    t.check('…the response waited for it', slow.headers >= 1400, `${slow.headers} ms`);
    const slowMissing = await timed(`${app}/defer?ms=50&head=slowmissing`);
    t.check('no budget: a missing product that answers after 900 ms (past 300) is a real 404', slowMissing.res.status === 404, `${slowMissing.res.status}`);
    t.check('…the response waited for it', slowMissing.headers >= 800, `${slowMissing.headers} ms`);
    t.check('…and does not vary by User-Agent', !(slow.res.headers.get('vary') ?? '').includes('User-Agent'));
    const budget = await timed(`${app}/defer?ms=50&head=budget`);
    t.check('opt-in budget: past it, 200 and the fallback title', budget.res.status === 200 && budget.text.includes('<title>Deferred</title>'));
    t.check('…the response started once the budget was over, not when the product came', budget.headers >= 250 && budget.headers < 1200, `${budget.headers} ms`);
    t.check('…says Vary: User-Agent (bots wait longer)', (budget.res.headers.get('vary') ?? '').includes('User-Agent'));
    t.check('…and the product still came, late', budget.text.includes('Product: Real product name'));
    const page = await t.page();
    await page.goto(`${app}/defer?ms=50&head=budget`, { waitUntil: 'load' });
    t.check('the late product fills its place', await has(page, 'Product: Real product name', 4000));
    t.check('the title stays the fallback', (await page.title()) === 'Deferred');
    await page.context().close();
  }

  // --- one result in two places ----------------------------------------------------
  {
    const html = await (await fetch(`${app}/defer?ms=50&responsive=1`)).text();
    t.check('the page holds both variants', html.includes('Mobile shell') && html.includes('Desktop shell'));
    const items = html.split('Item 0 of').length - 1;
    t.check('the result is in the response once', items === 1, `${items}`);
    t.check('one piece ends for two places', /data-thor-end="\d+,\d+"/.test(html));
    for (const [name, width] of [['desktop', 1280], ['mobile', 400]]) {
      const view = await t.page({ viewport: { width, height: 800 } });
      await view.goto(`${app}/defer?ms=300&responsive=1`, { waitUntil: 'load' });
      t.check(`${name}: the visible variant has its list`, await has(view, 'Item 2 of slow value', 5000));
      await view.waitForLoadState('load');
      const shown = await view.locator('text=Item 0 of slow value').evaluateAll((els) => els.filter((e) => e.offsetParent !== null).length);
      const all = await view.locator('text=Item 0 of slow value').count();
      t.check(`${name}: both places filled, one visible`, all === 2 && shown === 1, `${all} in the DOM, ${shown} visible`);
      t.check(`${name}: no skeleton or marker is left`, (await skeletons(view)) === 0 && (await view.locator('[data-thor-late]').count()) === 0);
      t.check(`${name}: no console errors`, clean(view).length === 0, clean(view).join(' | '));
      await view.context().close();
    }
  }

  // --- one result in two places: hostile attributes and state ---------------------
  {
    const html = await (await fetch(`${app}/defer?ms=50&responsive=1`)).text();
    t.check('the other place gets its start tag in data-thor-cls', /data-thor-cls="/.test(html));
    for (const [name, width] of [['desktop', 1280], ['mobile', 400]]) {
      const view = await t.page({ viewport: { width, height: 800 } });
      await view.goto(`${app}/defer?ms=300&responsive=1`, { waitUntil: 'load' });
      t.check(`${name}: filled`, await has(view, 'Item 2 of slow value', 5000));
      const bad = await view.evaluate(() => ({
        pwned: window.__pwned ?? null,
        handlers: [...document.querySelectorAll('*')].filter((e) => [...e.attributes].some((a) => /^on/i.test(a.name))).length,
        labels: [...document.querySelectorAll('[aria-label*="onerror"]')].map((e) => e.getAttribute('aria-label')),
      }));
      t.check(`${name}: nothing ran, no handler attribute appeared`, bad.pwned === null && bad.handlers === 0, JSON.stringify(bad));
      t.check(`${name}: the hostile text is the label of both places, whole`, bad.labels.length === 2 && bad.labels[0] === bad.labels[1] && bad.labels[0].includes('onmouseover=window.__pwned=2 x='), JSON.stringify(bad.labels));
      const shown = view.locator('button:has-text("Count shared"):visible');
      await shown.click();
      await view.waitForTimeout(150);
      const labels = await view.locator('text=clicks=1').evaluateAll((els) => els.length);
      t.check(`${name}: the state reaches both copies`, labels >= 2, `${labels} with clicks=1`);
      t.check(`${name}: no console errors`, clean(view).length === 0, clean(view).join(' | '));
      await view.context().close();
    }
  }

  // --- measurement ------------------------------------------------------------
  {
    const measure = async (url) => {
      const page = await t.page();
      const cdp = await page.context().newCDPSession(page);
      await cdp.send('Emulation.setCPUThrottlingRate', { rate: 4 });
      await page.goto(url, { waitUntil: 'load' });
      await page.waitForTimeout(100);
      const m = await page.evaluate(() => {
        const nav = performance.getEntriesByType('navigation')[0];
        const fcp = performance.getEntriesByName('first-contentful-paint')[0];
        return { ttfb: nav.responseStart, fcp: fcp?.startTime ?? -1, end: nav.responseEnd };
      });
      await page.context().close();
      return m;
    };
    const runs = { stream: [], sync: [] };
    for (let i = 0; i < 5; i++) {
      runs.stream.push(await measure(`${app}/defer?ms=1500`));
      runs.sync.push(await measure(`${app}/defer?ms=1500&sync=1`));
    }
    const num = (k, f) => Math.round(median(runs[k].map(f)));
    const row = (k) => `${k}: TTFB ${num(k, (m) => m.ttfb)} ms, FCP ${num(k, (m) => m.fcp)} ms, response end ${num(k, (m) => m.end)} ms`;
    console.log(`  (4x CPU, median of 5, the slowest call takes 3 s)\n  ${row('sync')}   <- awaits every call before the first byte\n  ${row('stream')}  <- the page, then the values`);
    t.check('the streamed page paints at least 2 s before the one that waits', num('sync', (m) => m.fcp) - num('stream', (m) => m.fcp) > 2000, `${num('sync', (m) => m.fcp)} vs ${num('stream', (m) => m.fcp)}`);
    t.check('the streamed page is not slower to finish', num('stream', (m) => m.end) < num('sync', (m) => m.end) + 400);
  }
});

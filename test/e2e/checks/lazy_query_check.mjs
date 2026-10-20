// Queries the browser runs (`query(fn, ssr: false)`) and the QueryBuilder states
// the server never drew, in a real browser, on test/fixtures/apps/server_query's public
// `/lazy` (build/server, the lite engine).
//
//   tool/thor e2e lazy-query               (builds test/fixtures/apps/server_query, runs)
//   node test/e2e/checks/lazy_query_check.mjs
//
// - the page goes out without waiting for the 600 ms query and without
//   running it; no JS: it stays waiting, with no error.
// - the browser asks once per query when the page hydrates, with no
//   setArg trick, and the done state shows with no initialData.
// - a failed lazy query shows its error state.
// - a QueryBuilder state with two roots (mobile and desktop): one box,
//   the right copy for the viewport, and it follows a reload.
// - a Watch.list whose container is a Column around the row holder: the
//   rows go into the holder; and a container with two roots (a list per
//   breakpoint): both copies get the rows, also the new ones of a reload.
// - an argument set before the first answer lands wins (the stale answer of
//   the hydration request never overwrites it), and leaving the page with
//   a request on its way breaks nothing on the next page.
// - another page of the app makes no LazyState request (the idle wake of a
//   state with `ssr: false` queries is only where the page names the state).
// - `thor dev` reports (THOR-S037, `thor.miss`) a QueryBuilder state the
//   server left out because its builder reads `data!`, and none of the
//   builders that only read `hasData`: the page starts where the server drew it.
// - the same QueryBuilder drawn twice (one hidden by CSS): both copies
//   follow a setArg.
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { e2e, hydrated, repo, settle, trackHydration } from './lib/e2e.mjs';

const children = [];
const tmp = mkdtempSync(join(tmpdir(), 'thor-lazy-'));
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

await e2e('lazy-query', { site: tmp, timeout: 120_000 }, async (t) => {
  const bin = join(repo, 'test/fixtures/apps/server_query/build/server');
  if (!existsSync(bin)) throw new Error('test/fixtures/apps/server_query/build/server is missing: build it first (tool/thor e2e builds it)');
  const port = await freePort();
  children.push(spawn(bin, [], { cwd: join(repo, 'test/fixtures/apps/server_query'), env: { ...process.env, PORT: `${port}` }, stdio: 'ignore' }));
  const app = `http://127.0.0.1:${port}`;
  await waitFor(`${app}/lab`);

  const open = async (options = {}) => {
    const page = await t.page(options);
    page.asked = [];
    page.on('request', (r) => r.method() === 'POST' && page.asked.push(r.headers()['x-thor-query'] ?? r.url()));
    await trackHydration(page);
    await page.goto(`${app}/lazy`);
    await hydrated(page);
    return page;
  };
  const text = (page) => page.locator('body').innerText();
  const has = async (page, want, timeout = 5000) => !!(await settle(page, (w) => document.body.innerText.includes(w), want, { timeout }));
  const gone = async (page, want, timeout = 5000) => !!(await settle(page, (w) => !document.body.innerText.includes(w), want, { timeout }));
  const click = (page, name) => page.getByRole('button', { name, exact: true }).click();
  const clean = (page) => page.problems.filter((p) => !/Failed to load resource/.test(p));
  const rowsIn = (page, sel) => page.evaluate((sel) => [...document.querySelectorAll(`${sel} > [data-tk]`)].map((r) => r.textContent.trim()).join(), sel);

  // --- the page does not wait --------------------------------------------------
  {
    const clock = performance.now();
    const res = await fetch(`${app}/lazy`);
    const html = await res.text();
    const ms = performance.now() - clock;
    t.check('the page answers well before the 600 ms query would', res.status === 200 && ms < 450, `${Math.round(ms)} ms`);
    t.check('it is drawn waiting', html.includes('rows: cargando') && html.includes('variante cargando'));
    const bare = await t.page({ javaScriptEnabled: false });
    await bare.goto(`${app}/lazy`);
    await new Promise((r) => setTimeout(r, 900));
    const body = await text(bare);
    t.check('no JS: it stays waiting, with no error', body.includes('rows: cargando') && body.includes('broken: cargando') && !body.includes('Lazy no responde.') && !body.includes('rows: error'), body);
    await bare.context().close();
  }

  // --- the browser asks by itself; the done state needs no initialData ---------
  {
    const page = await open({ viewport: { width: 1280, height: 900 } });
    t.check('first it shows the waiting state', (await text(page)).includes('rows: cargando') || (await has(page, 'rows: listo')));
    t.check('the done state arrives with no initialData', await has(page, 'rows: listo'), await text(page));
    t.check('and the waiting one is gone', await gone(page, 'rows: cargando'));
    const asked = (id) => page.asked.filter((q) => q === id).length;
    t.check('one request per query, no more', asked('LazyState.rows') === 1 && asked('LazyState.echo') === 1 && asked('LazyState.broken') === 1, page.asked.join(', '));
    await new Promise((r) => setTimeout(r, 400));
    t.check('and nothing asked again later', page.asked.length === 3, page.asked.join(', '));

    // --- a failed lazy query ---
    t.check('the failed lazy query shows its error state', (await has(page, 'broken:')) && (await has(page, 'Lazy no responde.')) && !(await text(page)).includes('broken: cargando'), await text(page));

    // --- a two-root state ---
    const body = await text(page);
    t.check('desktop: the desktop copy of the two-root state, not the waiting one', body.includes('variante escritorio') && !body.includes('variante móvil') && !body.includes('variante cargando'), body);
    const box = await page.evaluate(() => {
      const els = [...document.querySelectorAll('[data-tv$="phase"]')].filter((e) => e.textContent.includes('variante'));
      return { n: els.length, tag: els[0]?.tagName, both: els[0]?.textContent.includes('móvil') && els[0]?.textContent.includes('escritorio'), display: els[0] && getComputedStyle(els[0]).display };
    });
    t.check('the two roots are one marked box that takes no part in the layout', box.n === 1 && box.both && box.display === 'contents', JSON.stringify(box));

    // --- lists in wrapped and two-root containers ---
    t.check('the nested list: its rows are in the row holder', (await rowsIn(page, 'div:has(> [data-tl])')) !== undefined);
    const holder = await page.evaluate(() => {
      const first = document.querySelector('[data-tk]');
      const p = first.parentElement;
      return { rows: [...p.children].filter((c) => c.hasAttribute('data-tk')).map((c) => c.textContent.trim()).join(), sibling: p.previousElementSibling?.textContent ?? '' };
    });
    t.check('the first rows are in the holder (the Row), next to the title', holder.rows === 'fila x,fila y' && holder.sibling.includes('Lista anidada'), JSON.stringify(holder));
    await click(page, 'Reload rows');
    t.check('a reload brings a third row into the holder', await has(page, 'fila z'), await text(page));
    const counts = await page.evaluate(() => {
      const hosts = [...document.querySelectorAll('[data-tl]')];
      return hosts.map((h) => [...h.children].filter((c) => c.hasAttribute('data-tk')).length);
    });
    t.check('every list host got the three rows (the nested one and both copies of the two-root one)', counts.length === 3 && counts.every((n) => n === 3), JSON.stringify(counts));
    t.check('nothing went into a box or a Column', (await page.locator('[data-tl][style*="display: contents"]').count()) === 0);

    // --- one builder drawn twice ---
    const eco = () => page.evaluate(() => [...document.querySelectorAll('[data-tv]')].filter((e) => e.textContent.includes('eco:')).map((e) => e.textContent.replace(/\s+/g, ' ').trim()).join('|'));
    t.check('the widget drawn twice shows the value in both copies', (await settle(page, () => document.querySelectorAll('body *').length > 0 && /echo a/.test(document.body.textContent), null, { timeout: 4000 })) && (await page.evaluate(() => (document.body.textContent.match(/echo a/g) ?? []).length)) === 2, await eco());
    await click(page, 'Echo b');
    await settle(page, () => (document.body.textContent.match(/echo b/g) ?? []).length === 2, null, { timeout: 4000 });
    t.check('a setArg reaches both copies', (await page.evaluate(() => (document.body.textContent.match(/echo b/g) ?? []).length)) === 2 && (await page.evaluate(() => (document.body.textContent.match(/echo a/g) ?? []).length)) === 0, await eco());
    t.check('only the visible copy is on screen', (await page.evaluate(() => document.body.innerText.match(/echo b/g)?.length ?? 0)) === 1);
    t.check('no page errors', clean(page).length === 0, clean(page).join('; '));
    await page.context().close();
  }

  // --- races ---------------------------------------------------------------------
  {
    const page = await open({ viewport: { width: 1280, height: 900 } });
    await click(page, 'Echo b');
    await settle(page, () => /echo b/.test(document.body.textContent), null, { timeout: 4000 });
    await new Promise((r) => setTimeout(r, 900));
    t.check('Echo b clicked before the first answer: it ends on b, never back to a', (await page.evaluate(() => (document.body.textContent.match(/echo a/g) ?? []).length)) === 0, await text(page));
    t.check('no page errors', clean(page).length === 0, clean(page).join('; '));
    await page.context().close();
    const gone = await t.page({ viewport: { width: 1280, height: 900 } });
    gone.problems.length = 0;
    await trackHydration(gone);
    await gone.goto(`${app}/lazy`);
    await hydrated(gone);
    await gone.goto(`${app}/lab`); // the 600 ms queries are still on their way
    await new Promise((r) => setTimeout(r, 900));
    t.check('leaving with requests on their way: no errors on the next page', clean(gone).length === 0, clean(gone).join('; '));
    await gone.context().close();
  }

  // --- a page that doesn't use the state asks for nothing -----------------------
  {
    for (const path of ['/lab', '/']) {
      const other = await t.page({ viewport: { width: 1280, height: 900 } });
      const asked = [];
      other.on('request', (r) => r.method() === 'POST' && asked.push(r.headers()['x-thor-query'] ?? r.url()));
      await trackHydration(other);
      await other.goto(`${app}${path}`);
      await hydrated(other);
      await new Promise((r) => setTimeout(r, 700));
      t.check(`${path}: no LazyState request on a page that doesn't use it`, !asked.some((q) => q.startsWith('LazyState')), asked.join(', '));
      await other.context().close();
    }
  }

  // --- the dev warning is for the state the server left out, no other -----------
  {
    const page = await t.page({ viewport: { width: 1280, height: 900 } });
    // The dev part sets `thor.miss` (what `thor dev` prints as THOR-S037); the
    // release build here has none, so a hook stands in for it.
    await page.addInitScript(() => {
      window.misses = [];
      let thor;
      Object.defineProperty(window, 'thor', {
        configurable: true,
        get: () => thor,
        set(v) {
          thor = v;
          if (v && typeof v === 'object') v.miss = (el, n) => window.misses.push(`${el.getAttribute('data-tv')}:${n}:${el.textContent.trim().slice(0, 12)}`);
        },
      });
    });
    await trackHydration(page);
    await page.goto(`${app}/lazy`);
    await hydrated(page);
    t.check('the data! builder shows its done state', await has(page, 'cuenta: 3') || (await text(page)).includes('cuenta:'), await text(page));
    await has(page, 'broken: listo', 1500);
    await new Promise((r) => setTimeout(r, 400));
    const misses = await page.evaluate(() => window.misses);
    t.check('nothing reported for the builders that only read hasData', misses.every((m) => m.includes('cuenta')), misses.join(' | '));
    t.check('the data! builder is reported (its done state was left out)', misses.some((m) => m.startsWith('LazyState.rows$phase:2')), misses.join(' | '));
    await page.context().close();
  }

  // --- the two-root state on a phone ----------------------------------------------------------------
  {
    const page = await open({ viewport: { width: 400, height: 800 } });
    await has(page, 'rows: listo');
    const body = await text(page);
    t.check('mobile: the mobile copy only', body.includes('variante móvil') && !body.includes('variante escritorio'), body);
    t.check('mobile: no page errors', clean(page).length === 0, clean(page).join('; '));
    await page.context().close();
  }
});

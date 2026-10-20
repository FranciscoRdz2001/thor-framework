// Fast navigation (PageNavigation, docs/guia/es/navegacion.md): the page's
// speculation rules fetch exactly the links they should, a hover on a real
// app prefetches and the click uses that response, and everything still
// navigates with JavaScript disabled.
//
//   tool/thor e2e navigation                (builds test/fixtures/apps/realworld, runs)
//   node test/e2e/checks/navigation_check.mjs
//
// 1. Link matrix (packages/thor_ui/test/fixtures/navigation_page.dart,
//    `immediate` eagerness): every `/yes-*` link is prefetched and no
//    `/no-*` one is (other origin, new tab, download, nofollow,
//    `Link(prefetch: false)`, excluded patterns, a POST form).
// 2. test/fixtures/apps/realworld (build/server) against test/e2e/mock_api: hover an
//    article → prefetch; click → served from it; a page prefetched while
//    signed in is not shown after logging out (POST); no JS still works.
import { spawn, spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, readFileSync, existsSync } from 'node:fs';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { e2e, repo } from './lib/e2e.mjs';

const children = [];
const tmp = mkdtempSync(join(tmpdir(), 'thor-nav-'));
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
      if ((await fetch(url)).status < 500) return;
    } catch {}
    await new Promise((r) => setTimeout(r, 100));
  }
  throw new Error(`nothing answered at ${url}`);
}

// --- the matrix page -------------------------------------------------------
const render = spawnSync(
  'dart',
  ['run', '-Dthor.release=true', 'test/fixtures/navigation_page.dart'],
  { cwd: join(repo, 'packages/thor_ui'), env: { ...process.env, THOR_RENDER_TO: join(tmp, 'index.html') } },
);
if (render.status !== 0) {
  console.log(`FAIL navigation: fixture did not render\n${render.stderr}`);
  process.exit(1);
}
const matrix = readFileSync(join(tmp, 'index.html'), 'utf8');

/** Requests the matrix server saw: path → `sec-purpose` header (or ''). */
const seen = new Map();
let crossOrigin = '';
function handle(req, res) {
  const url = new URL(req.url, 'http://x');
  if (url.pathname === '/' || url.pathname === '/index.html') {
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-cache' });
    res.end(matrix.replace('__CROSS__', crossOrigin));
    return true;
  }
  seen.set(url.pathname, req.headers['sec-purpose'] ?? '');
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
  res.end(`<!doctype html><title>${url.pathname}</title><a href="/">back</a>`);
  return true;
}

const yes = ['/yes-plain', '/yes-query', '/yes-hash', '/yes-span', '/yes-destination'];
const no = ['/no-cross', '/no-blank', '/no-optout', '/no-logout', '/no-admin/users', '/no-file', '/no-nofollow', '/no-post'];

await e2e('navigation', { site: tmp, timeout: 180_000, handle }, async (t) => {
  // `localhost` and `127.0.0.1` are different origins of the same server.
  crossOrigin = t.url.replace('127.0.0.1', 'localhost').replace(/\/$/, '');

  {
    const page = await t.page();
    await page.goto(t.url);
    // Immediate eagerness: every candidate is fetched right after load.
    const deadline = Date.now() + 5000;
    while (Date.now() < deadline && !yes.every((p) => seen.has(p))) await new Promise((r) => setTimeout(r, 50));
    await new Promise((r) => setTimeout(r, 500)); // late extras would show up here
    for (const p of yes) t.check(`matrix: ${p} is prefetched`, seen.get(p)?.includes('prefetch'), `saw ${JSON.stringify(seen.get(p))}`);
    for (const p of no) t.check(`matrix: ${p} is never fetched`, !seen.has(p), `saw ${JSON.stringify(seen.get(p))}`);
    t.check('matrix: no console errors (rules parsed)', page.problems.length === 0, page.problems.join('; '));
    await page.context().close();
  }

  {
    seen.clear();
    const page = await t.page({ javaScriptEnabled: false });
    await page.goto(t.url);
    await page.click('a[href="/yes-plain"]');
    t.check('no JS: a link still navigates', (await page.title()) === '/yes-plain', await page.title());
    t.check('no JS: the navigation was a plain GET', seen.get('/yes-plain') === '', JSON.stringify(seen.get('/yes-plain')));
    await page.context().close();
  }

  // --- test/fixtures/apps/realworld ----------------------------------------------------------
  const server = join(repo, 'test/fixtures/apps/realworld/build/server');
  if (!existsSync(server)) throw new Error('test/fixtures/apps/realworld/build/server is missing: build it first (tool/thor e2e builds it)');
  const [mockPort, appPort] = [await freePort(), await freePort()];
  children.push(
    spawn('node', [join(repo, 'test/e2e/mock_api/server.mjs'), '--port', `${mockPort}`, '--latency', '20'], {
      stdio: 'ignore',
      env: { ...process.env, MOCK_PORT: `${mockPort}` },
    }),
  );
  await waitFor(`http://127.0.0.1:${mockPort}/api/tags`);
  children.push(
    spawn(server, [], {
      cwd: join(repo, 'test/fixtures/apps/realworld'),
      env: {
        ...process.env,
        PORT: `${appPort}`,
        ISOLATES: '1',
        REALWORLD_API: `http://localhost:${mockPort}/api`,
        SESSION_SECRET: 'navigation-check-secret-of-at-least-32-bytes',
      },
      stdio: 'ignore',
    }),
  );
  const app = `http://127.0.0.1:${appPort}`;
  await waitFor(`${app}/`);

  const delivery = () => {
    const e = performance.getEntriesByType('navigation')[0];
    return { deliveryType: e.deliveryType, wait: Math.round(e.responseStart - e.startTime) };
  };
  const pause = (ms) => new Promise((r) => setTimeout(r, ms));

  /** A page whose CDP session records prefetch statuses by path. */
  async function watched(options) {
    const page = await t.page(options);
    const cdp = await page.context().newCDPSession(page);
    page.prefetch = new Map();
    await cdp.send('Preload.enable');
    cdp.on('Preload.prefetchStatusUpdated', (e) =>
      page.prefetch.set(new URL(e.prefetchUrl).pathname, `${e.status}${e.prefetchStatus ? `:${e.prefetchStatus}` : ''}`),
    );
    return page;
  }
  async function until(fn, timeout = 5000) {
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline && !fn()) await pause(50);
    return fn();
  }
  /** Clicks `link` and resolves with the ms until the next page's DOMContentLoaded. */
  async function follow(page, link) {
    const href = await link.getAttribute('href');
    const start = Date.now();
    await link.click();
    await page.waitForURL(`${app}${href}`, { waitUntil: 'domcontentloaded' });
    return Date.now() - start;
  }

  // Guest: hover an article, the click uses the prefetched response.
  {
    const page = await watched();
    await page.goto(`${app}/`);
    const rules = await page.locator('script[type=speculationrules]').count();
    t.check('realworld: one speculation rule set', rules === 1, `${rules}`);
    const link = page.locator('a[href^="/article/"]').first();
    const href = await link.getAttribute('href');
    await link.hover();
    const ready = await until(() => /^(Ready|Success)/.test(page.prefetch.get(href) ?? ''));
    t.check('realworld: hovering an article prefetches it', ready, `${href}: ${page.prefetch.get(href)}`);
    const ms = await follow(page, link);
    const nav = await page.evaluate(delivery);
    t.check('realworld: the click used the prefetched response', nav.deliveryType === 'navigational-prefetch', JSON.stringify(nav));
    t.check('realworld: the article is shown', (await page.locator('h1').count()) > 0);
    console.log(`  hover, then click → DOMContentLoaded: ${ms} ms (response wait ${nav.wait} ms)`);
    await page.goBack();
    t.check('realworld: back returns to the list', new URL(page.url()).pathname === '/', page.url());

    // Baseline: the same kind of click with the rules removed.
    await page.evaluate(() => document.querySelector('script[type=speculationrules]')?.remove());
    const cold = await follow(page, page.locator('a[href^="/article/"]').nth(3));
    const coldNav = await page.evaluate(delivery);
    t.check('realworld: without rules the click goes to the network', coldNav.deliveryType === '', JSON.stringify(coldNav));
    console.log(`  cold click (rules removed) → DOMContentLoaded: ${cold} ms (response wait ${coldNav.wait} ms)`);
    t.check('realworld: no console errors', page.problems.length === 0, page.problems.join('; '));
    await page.context().close();
  }

  // Signed in: a page prefetched before a POST (logout) is never shown after
  // it (the action answers Clear-Site-Data: "prefetchCache").
  {
    const page = await watched();
    await page.goto(`${app}/login`);
    await page.fill('input[name=email]', 'johndoe@example.com');
    await page.fill('input[name=password]', 'password123');
    await Promise.all([page.waitForURL(`${app}/`), page.click('button[type=submit]')]);
    t.check('realworld: signed in', (await page.locator('a[href="/settings"]').count()) > 0);
    await page.goto(`${app}/settings`);
    await page.hover('a[href="/"]');
    const ready = await until(() => /^(Ready|Success)/.test(page.prefetch.get('/') ?? ''));
    t.check('realworld: the signed-in home is prefetched on hover', ready, page.prefetch.get('/'));
    await Promise.all([page.waitForURL(`${app}/`), page.locator('form[action="?/logout"] button').click()]);
    const nav = await page.evaluate(delivery);
    t.check('realworld: after logout the home is fetched again', nav.deliveryType !== 'navigational-prefetch', JSON.stringify(nav));
    t.check(
      'realworld: after logout the home is the guest one',
      (await page.locator('a[href="/settings"]').count()) === 0 && (await page.locator('a[href="/login"]').count()) > 0,
    );
    await page.context().close();
  }

  // Without JavaScript: no speculation at all, links still navigate.
  {
    const page = await watched({ javaScriptEnabled: false });
    await page.goto(`${app}/`);
    const link = page.locator('a[href^="/article/"]').first();
    const href = await link.getAttribute('href');
    await link.hover();
    await pause(500);
    await follow(page, link);
    t.check('realworld (no JS): the click lands on the article', new URL(page.url()).pathname === href, page.url());
    console.log(`  (no JS: prefetch status of ${href}: ${page.prefetch.get(href) ?? 'none'})`);
    await page.context().close();
  }
});

// The engine's low-priority preload against real browsers (adversarial
// cases): the file the page preloads and the file its loader asks
// for must be ONE request in Chromium, WebKit and Firefox, whatever the
// caching headers (a dev server's no-store, no-cache, immutable), whether the
// engine sits on the page's origin or a CDN's (with or without CORS
// headers), whether the visitor taps before the engine is there or waits for
// idle, and however slow the file is. A page must also stay quiet in the
// console (no "preloaded but not used", no CSP report under a policy that
// allows the loader), and without JavaScript nothing is downloaded.
//
//   tool/thor e2e engine-preload      (builds test/fixtures/apps/counter, runs)
//   node test/e2e/checks/engine_preload_check.mjs
import { createServer } from 'node:http';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { chromium, firefox, webkit } from '../runner/node_modules/playwright/index.mjs';
import { browsersFor, repo } from './lib/e2e.mjs';

const site = join(repo, process.env.E2E_SITE ?? 'test/fixtures/apps/counter/build/site');
const page0 = readFileSync(join(site, 'index.html'), 'utf8');
const engineName = page0.match(/engine\.(dart|lite)\.[0-9a-f]{8}\.js/)?.[0];
if (!engineName) throw new Error(`no content-hashed engine in ${site}/index.html`);
const engineJs = readFileSync(join(site, engineName));

const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail !== '' ? ` (${detail})` : ''}`);
};

// A server for the page (and, unless `cdn`, its engine); `hits` are the
// engine requests it saw. `cdn` puts the engine on a second origin.
function serve({ cache, delay = 0, cors = false, csp, cdnPort } = {}) {
  const hits = [];
  const server = createServer((req, res) => {
    const path = new URL(req.url, 'http://x').pathname;
    if (path === '/' || path === '/index.html') {
      const head = { 'content-type': 'text/html', 'cache-control': 'no-store' };
      if (csp) head['content-security-policy'] = csp;
      const html = cdnPort ? page0.split(engineName).join(`http://127.0.0.1:${cdnPort}/${engineName}`) : page0;
      res.writeHead(200, head).end(html);
    } else if (path.endsWith(engineName)) {
      hits.push({ dest: req.headers['sec-fetch-dest'], mode: req.headers['sec-fetch-mode'] });
      const head = { 'content-type': 'text/javascript' };
      if (cache) head['cache-control'] = cache;
      if (cors) head['access-control-allow-origin'] = '*';
      setTimeout(() => res.writeHead(200, head).end(engineJs), delay);
    } else res.writeHead(404).end();
  });
  return new Promise((ok) => server.listen(0, '127.0.0.1', () => ok({ server, hits, port: server.address().port })));
}
const stop = ({ server }) => new Promise((ok) => (server.close(ok), server.closeAllConnections()));

const SCENARIOS = {
  'plain headers': {},
  'no-store (a dev server)': { cache: 'no-store' },
  'no-cache': { cache: 'no-cache' },
  'immutable': { cache: 'public, max-age=31536000, immutable' },
  'a slow engine': { delay: 1500 },
  'engine on a CDN origin': { cdn: {} },
  'CDN origin with CORS headers': { cdn: { cors: true } },
};

async function run(name, type) {
  const browser = await type.launch();
  try {
    for (const [label, o] of Object.entries(SCENARIOS)) {
      for (const how of ['idle', 'tap first']) {
        const cdn = o.cdn ? await serve({ cache: o.cache, ...o.cdn }) : null;
        const app = await serve(o.cdn ? { cdnPort: cdn.port } : o);
        const ctx = await browser.newContext();
        const p = await ctx.newPage();
        const msgs = [];
        p.on('console', (m) => ['warning', 'error'].includes(m.type()) && msgs.push(m.text().slice(0, 160)));
        await p.addInitScript(() => document.addEventListener('thor:hydrated', () => (window.__hyd = 1)));
        await p.goto(`http://127.0.0.1:${app.port}/`, { waitUntil: 'commit' });
        if (how === 'tap first') await p.locator('button').first().click({ force: true, noWaitAfter: true }).catch(() => {});
        await p.waitForFunction(() => window.__hyd === 1, null, { timeout: 15000 });
        await p.waitForTimeout(400); // a second request would be on the wire by now
        const hits = (cdn ?? app).hits;
        const link = await p.evaluate(() => {
          const l = document.querySelector('link[rel=preload][as=script]');
          return l && { crossorigin: l.getAttribute('crossorigin'), type: l.getAttribute('type') };
        });
        check(`${name} · ${label} · ${how}: the engine is requested once`, hits.length === 1, `${hits.length}: ${JSON.stringify(hits)}`);
        check(`${name} · ${label} · ${how}: a script fetch without CORS on both sides`, hits.every((h) => h.dest === 'script' && h.mode === 'no-cors') && link?.crossorigin === null, JSON.stringify([hits[0], link]));
        check(`${name} · ${label} · ${how}: no console warnings or errors`, msgs.length === 0, msgs.join(' | '));
        await ctx.close();
        await Promise.all([stop(app), cdn && stop(cdn)]);
      }
    }
    // Without JavaScript the engine has nothing to do: the preload must not
    // fetch it either.
    {
      const app = await serve();
      const ctx = await browser.newContext({ javaScriptEnabled: false });
      const p = await ctx.newPage();
      await p.goto(`http://127.0.0.1:${app.port}/`);
      await p.waitForTimeout(800);
      // WebKit fetches a preload even with scripting off (one request, the
      // file is cached and unused): accepted, it is the browser's rule.
      check(`${name} · no JavaScript: the engine is ${name === 'webkit' ? 'downloaded at most once' : 'never downloaded'}`, app.hits.length <= (name === 'webkit' ? 1 : 0), `${app.hits.length} requests`);
      await ctx.close();
      await stop(app);
    }
  } finally {
    await browser.close();
  }
}

// A policy that lets the inline loader run keeps the page clean; the
// documented strict policy (`eager`, no inline script) has no preload at all.
async function policies() {
  const browser = await chromium.launch();
  try {
    const hash = page0.match(/<script data-thor-engine[^>]*>/) && (await import('node:crypto')).createHash('sha256').update(page0.match(/<script data-thor-engine[^>]*>([\s\S]*?)<\/script>/)[1]).digest('base64');
    for (const [label, csp, clean] of [
      ["loader hash + 'self'", `script-src 'self' 'sha256-${hash}'`, true],
      // strict-dynamic trusts what the hashed loader inserts but not a
      // <link rel=preload>: the engine still loads (once); the preload is
      // reported. Such a page uses EngineLoading.eager (docs/guia/es/sesion-y-seguridad.md).
      ["loader hash + 'strict-dynamic'", `script-src 'sha256-${hash}' 'strict-dynamic'`, false],
    ]) {
      const app = await serve({ csp });
      const ctx = await browser.newContext();
      const p = await ctx.newPage();
      const msgs = [];
      p.on('console', (m) => ['warning', 'error'].includes(m.type()) && msgs.push(m.text().slice(0, 160)));
      await p.addInitScript(() => document.addEventListener('thor:hydrated', () => (window.__hyd = 1)));
      await p.goto(`http://127.0.0.1:${app.port}/`);
      await p.waitForFunction(() => window.__hyd === 1, null, { timeout: 15000 });
      await p.waitForTimeout(300);
      check(`CSP ${label}: the engine loads and hydrates, once`, app.hits.length === 1, String(app.hits.length));
      check(`CSP ${label}: console ${clean ? 'clean' : 'reports the preload (known, documented)'}`, clean ? msgs.length === 0 : msgs.length > 0, msgs.join(' | '));
      await ctx.close();
      await stop(app);
    }
  } finally {
    await browser.close();
  }
}

try {
  for (const [name, type] of browsersFor([['chromium', chromium], ['webkit', webkit], ['firefox', firefox]])) await run(name, type);
  // The CSP cases are Chromium's (the loader's hash under a strict policy).
  if (!process.env.E2E_BROWSER || process.env.E2E_BROWSER === 'chromium') await policies();
} catch (e) {
  check('no exception', false, e?.stack ?? String(e));
}
const failed = results.filter((r) => !r).length;
console.log(failed ? `${failed} of ${results.length} failed` : `${results.length} passed`);
process.exit(failed ? 1 : 0);

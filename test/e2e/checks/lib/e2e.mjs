// Shared harness of the browser checks (test/e2e/checks/*_check.mjs):
// a pass/fail program with a clear report, no dependence on the machine's
// state and nothing left running.
//
//   await e2e('landing', { site: 'test/fixtures/apps/landing/build/site' }, async (t) => {
//     const page = await t.page({ javaScriptEnabled: false });
//     await page.goto(t.url);
//     t.check('title is set', (await page.title()) !== '');
//   });
//
// - Serves `site` (a thor static build) on a free port of 127.0.0.1, or
//   uses the URL given as the first argument (`node x_check.mjs http://…`).
//   `path` (`'rows'`) is the page of a multi-page site that `t.url` points at.
//   `site: null` serves nothing (`t.url` is empty): the body starts what it
//   checks, and stops it (the harness only closes its browser).
// - Exit code 1 when any check fails, the body throws, nothing was checked
//   (fail closed) or the whole run exceeds `timeout`; 130/143 on Ctrl-C /
//   SIGTERM. The browser and the server are closed in every case.
// - `E2E_HEADED=1` shows the browser.
// - `E2E_ENGINE=<file>` answers the engine's URL (`engine.dart*.js`) with
//   that file on every page: the same check against another engine build
//   (the lite bundle).
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { createServer as createNetServer } from 'node:net';
import { existsSync, readFileSync, statSync } from 'node:fs';
import { extname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import * as engines from '../../runner/node_modules/playwright/index.mjs';

/**
 * The key that moves the focus to the next control. WebKit on macOS (Safari's
 * default) does not Tab to buttons, only to fields and links: Option+Tab does.
 * Elsewhere (Chromium, Firefox, WebKit on Linux) it is Tab. `name` is the
 * browser: the one `E2E_BROWSER` chose by default.
 */
export const tabKey = (name = process.env.E2E_BROWSER ?? 'chromium') => (name === 'webkit' && process.platform === 'darwin' ? 'Alt+Tab' : 'Tab');

/** The repository root. */
/**
 * The browsers a check that launches its own run in: `all` (a list of
 * `[name, type]`), or only the one `E2E_BROWSER` names (`tool/thor e2e
 * --browsers` runs the check once per browser).
 */
export const browsersFor = (all) => (process.env.E2E_BROWSER ? all.filter(([name]) => name === process.env.E2E_BROWSER) : all);

export const repo = fileURLToPath(new URL('../../../..', import.meta.url));

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain',
  // Flutter web builds (FlutterView): CanvasKit and the icon font.
  '.wasm': 'application/wasm',
  '.otf': 'font/otf',
};

/**
 * Serves the directory `dir` like a static host: `/x/` → `x/index.html`,
 * clean URLs (`/x` → `x.html`), 404 outside `dir`. `port` 0 = a free one.
 * `handle(req, res)` runs first and returns true when it answered. `host`
 * null = every interface.
 */
export function serveStatic(dir, { port = 0, host = '127.0.0.1', handle } = {}) {
  const root = resolve(dir);
  const server = createServer((req, res) => {
    if (handle?.(req, res)) return;
    let file;
    try {
      file = join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname));
    } catch {
      res.writeHead(400).end();
      return;
    }
    // A folder with no index (`api/thor_ui/widgets/` next to `widgets.html`)
    // is the page of the same name, as on a host with clean URLs.
    if (existsSync(file) && statSync(file).isDirectory()) {
      file = existsSync(join(file, 'index.html')) ? join(file, 'index.html') : `${file}.html`;
    }
    if (!existsSync(file) && existsSync(`${file}.html`)) file = `${file}.html`;
    if ((file !== root && !file.startsWith(root + sep)) || !existsSync(file)) {
      res.writeHead(404).end();
      return;
    }
    res.writeHead(200, {
      'content-type': MIME[extname(file)] ?? 'application/octet-stream',
      'cache-control': 'no-store',
    });
    res.end(readFileSync(file));
  });
  return new Promise((ok, ko) => {
    server.once('error', ko);
    server.listen(port, host ?? undefined, () => ok(server));
  });
}

/** Closes `server` and drops its keep-alive connections. */
export function closeServer(server) {
  if (!server?.listening) return Promise.resolve();
  return new Promise((ok) => {
    server.close(() => ok());
    server.closeAllConnections();
  });
}

/**
 * Runs one check program; see the header. Options: `site` (directory to
 * serve, relative to the repo), `path` (the page `t.url` points at, without
 * the slash: `'rows'`; default the site's root), `handle` (see [serveStatic]),
 * `timeout` (ms, whole run; default 120 s or `E2E_TIMEOUT`).
 */
export async function e2e(name, { site, path = '', handle, timeout } = {}, body) {
  const limit = Number(process.env.E2E_TIMEOUT ?? timeout ?? 120_000);
  const engine = process.env.E2E_ENGINE ? readFileSync(process.env.E2E_ENGINE) : null;
  const results = [];
  let browser, server, finished = false;

  const cleanup = async () => {
    await Promise.allSettled([browser?.close(), closeServer(server)]);
  };
  const finish = async (code, message) => {
    if (finished) return;
    finished = true;
    if (message) console.log(message);
    await cleanup();
    process.exit(code);
  };
  process.once('SIGINT', () => finish(130, `\n${name}: interrupted`));
  process.once('SIGTERM', () => finish(143, `\n${name}: terminated`));
  const watchdog = setTimeout(
    () => finish(1, `FAIL ${name}: timed out after ${limit} ms`),
    limit,
  );

  const t = {
    url: '',
    browser: null,
    /** Records one assertion; `detail` explains a failure. */
    check(label, ok, detail = '') {
      if (finished) return;
      results.push({ label, ok: !!ok });
      console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail !== '' ? ` (${detail})` : ''}`);
    },
    /**
     * A new page in its own context; its console errors and page errors
     * accumulate in `page.problems`.
     */
    async page(options = {}) {
      const ctx = await browser.newContext(options);
      ctx.setDefaultTimeout(10_000);
      if (engine) {
        await ctx.route(/\/engine\.dart[^/]*\.js(\?|$)/, (r) =>
          r.fulfill({ contentType: 'text/javascript', body: engine }),
        );
      }
      const page = await ctx.newPage();
      page.problems = [];
      page.on('pageerror', (e) => page.problems.push(e.message));
      page.on('console', (m) => m.type() === 'error' && page.problems.push(m.text()));
      // E2E_CPU_THROTTLE=6 runs every page 6x slower (CDP): the order of
      // queued tasks that a loaded machine would shuffle, on demand (raise
      // E2E_TIMEOUT with it).
      const rate = Number(process.env.E2E_CPU_THROTTLE ?? 1);
      if (rate > 1) {
        const cdp = await ctx.newCDPSession(page);
        await cdp.send('Emulation.setCPUThrottlingRate', { rate });
      }
      return page;
    },
  };

  console.log(`▸ ${name}`);
  try {
    const external = process.argv.slice(2).find((a) => /^https?:\/\//.test(a));
    if (external) {
      t.url = external;
    } else if (site === null) {
      // The body starts what it checks (`thor dev` on an app of its own).
      t.url = '';
    } else {
      const dir = resolve(repo, site);
      if (!existsSync(join(dir, 'index.html'))) {
        throw new Error(`${site}/index.html is missing: build it first (tool/thor e2e builds it)`);
      }
      server = await serveStatic(dir, { handle });
      t.url = `http://127.0.0.1:${server.address().port}/${path}`;
    }
    browser = await engines[process.env.E2E_BROWSER ?? 'chromium'].launch({ headless: !process.env.E2E_HEADED });
    t.browser = browser;
    await body(t);
  } catch (e) {
    // Closing the browser on Ctrl-C or on timeout makes the body throw: the
    // run is already over, don't report that as another failure.
    if (finished) return;
    results.push({ label: 'no exception', ok: false });
    console.log(`FAIL ${name}: ${e?.stack ?? e}`);
  }
  clearTimeout(watchdog);
  const failed = results.filter((r) => !r.ok).length;
  if (results.length === 0) return finish(1, `FAIL ${name}: no checks ran`);
  return finish(
    failed ? 1 : 0,
    failed ? `✗ ${name}: ${failed} of ${results.length} failed` : `✓ ${name}: ${results.length} passed`,
  );
}

/**
 * Waits until `fn(arg)` (evaluated in the page) returns a truthy value, up
 * to `timeout` ms, and returns its last value: the caller checks it and
 * reports what it saw instead of a bare timeout. It polls from Node, not
 * with `page.waitForFunction`: a page without JavaScript runs no timers or
 * `requestAnimationFrame` callbacks, so an in-page poll never fires there.
 */
export async function settle(page, fn, arg, { timeout = 5000, interval = 16 } = {}) {
  const deadline = Date.now() + timeout;
  for (;;) {
    // A navigation in between destroys the context: poll the next document.
    const value = await page.evaluate(fn, arg).catch((e) => {
      if (/context was destroyed|navigat/i.test(String(e?.message))) return undefined;
      throw e;
    });
    if (value || Date.now() >= deadline) return value;
    await new Promise((next) => setTimeout(next, interval));
  }
}

/**
 * Resolves after `n` animation frames of the page: whatever the last
 * interaction queued for the next frame (and the microtasks and tasks queued
 * before it) has run. Waits for the page's own clock, not a number of ms, so
 * a loaded machine only makes it slower, not wrong.
 */
export function frames(page, n = 2) {
  return page.evaluate(
    (n) =>
      new Promise((done) => {
        const tick = (left) => (left ? requestAnimationFrame(() => tick(left - 1)) : done());
        tick(n);
      }),
    n,
  );
}

/**
 * Resolves once the DOM of the page has not changed for `quiet` ms (measured
 * by the page: a task that was queued first, like a dialog's `toggle`, runs
 * before the timer that ends the wait), up to `timeout`.
 */
export function domQuiet(page, quiet = 50, timeout = 5000) {
  return page.evaluate(
    ([quiet, timeout]) =>
      new Promise((done) => {
        let timer;
        const finish = () => {
          observer.disconnect();
          clearTimeout(cap);
          done();
        };
        const arm = () => {
          clearTimeout(timer);
          timer = setTimeout(finish, quiet);
        };
        const observer = new MutationObserver(arm);
        observer.observe(document, { subtree: true, childList: true, attributes: true, characterData: true });
        const cap = setTimeout(finish, timeout);
        arm();
      }),
    [quiet, timeout],
  );
}

/**
 * Resolves once the page stops scrolling: the same position over `quiet`
 * ms (smooth scrolls and lazy layout), up to `timeout`.
 */
export async function scrollEnd(page, { quiet = 150, timeout = 5000 } = {}) {
  const deadline = Date.now() + timeout;
  let last = null;
  let since = Date.now();
  while (Date.now() < deadline) {
    const now = await page.evaluate(() => `${scrollX},${scrollY}`);
    if (now !== last) [last, since] = [now, Date.now()];
    else if (Date.now() - since >= quiet) return;
    await new Promise((next) => setTimeout(next, 16));
  }
}

/**
 * Brings `locator` into view and resolves once it stops moving: the same
 * box over `quiet` ms (a height transition above it, lazily laid out
 * sections taking their real height), up to `timeout`. Call it before a
 * click that may land while things still move in a page without
 * JavaScript: Playwright's click retries an element that moved after an
 * in-page timer, and such a page runs no timers, so the click would wait
 * until its timeout. It polls from Node, like [settle].
 */
export async function still(locator, { quiet = 100, timeout = 5000 } = {}) {
  await locator.evaluate((e) => e.scrollIntoView({ block: 'center' }));
  const deadline = Date.now() + timeout;
  let last = null;
  let since = Date.now();
  while (Date.now() < deadline) {
    const now = await locator.evaluate((e) => {
      const r = e.getBoundingClientRect();
      return `${r.x},${r.y},${r.width},${r.height}`;
    });
    if (now !== last) [last, since] = [now, Date.now()];
    else if (Date.now() - since >= quiet) return;
    await new Promise((next) => setTimeout(next, 16));
  }
}

/**
 * Makes every document of `page` record the engine's hydration
 * (`thor:hydrated`) in `window.__thorHydrated`, and a failed engine
 * script in `window.__thorEngineFailed`; call before `goto`.
 */
export function trackHydration(page) {
  return page.addInitScript(() => {
    window.__thorHydrated = false;
    window.__thorEngineFailed = false;
    document.addEventListener('thor:hydrated', () => (window.__thorHydrated = true), { once: true });
    document.addEventListener(
      'error',
      (e) => {
        if (e.target instanceof HTMLScriptElement && /engine/.test(e.target.src)) window.__thorEngineFailed = true;
      },
      true,
    );
  });
}

/** Waits for the engine to hydrate the current document (see [trackHydration]). */
export function hydrated(page, timeout = 10_000) {
  return page.waitForFunction(() => window.__thorHydrated === true, null, { timeout });
}

/** A free port of 127.0.0.1. */
export const freePort = () =>
  new Promise((ok) => {
    const s = createNetServer().listen(0, '127.0.0.1', () => {
      const { port } = s.address();
      s.close(() => ok(port));
    });
  });

/**
 * Starts a server app (`bin`, a thor `build/server`) on a free port, given as
 * `PORT`, and waits until it answers. The child's output is kept: when it
 * dies or does not answer within `timeout` (ms) this throws with that output,
 * instead of leaving the checks to fail on a page that never came. It is
 * killed when the process exits. Returns `{ url, port, stop() }`.
 */
export async function serveApp({ bin, cwd, env = {}, timeout = 15_000 }) {
  const port = await freePort();
  const child = spawn(bin, [], { cwd, env: { ...process.env, ...env, PORT: String(port) } });
  // Only the tail is reported: a server that logs every request must not grow it forever.
  let log = '';
  const keep = (d) => (log = (log + d).slice(-16_384));
  child.stdout.on('data', keep);
  child.stderr.on('data', keep);
  let failure = null;
  child.on('error', (e) => (failure = `could not start: ${e.message}`));
  child.on('exit', (code, signal) => (failure ??= `exited early (${code ?? signal})`));
  const stop = () => child.exitCode === null && child.kill('SIGKILL');
  process.on('exit', stop);
  const url = `http://127.0.0.1:${port}/`;
  const deadline = Date.now() + timeout;
  for (;;) {
    if (failure === null) {
      try {
        if ((await fetch(url)).ok) return { url, port, stop };
      } catch {}
    }
    if (failure !== null || Date.now() > deadline) {
      stop();
      throw new Error(`${bin} ${failure ?? `did not answer in ${timeout} ms`}\n${log.trim().split('\n').slice(-20).join('\n')}`);
    }
    await new Promise((r) => setTimeout(r, 100));
  }
}

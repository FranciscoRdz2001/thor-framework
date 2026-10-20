// The prefetch fallback for browsers without Speculation Rules
// (docs/guia/en/navigation.md): a routed page carries a tiny inline test that loads
// `/_thor/prefetch.<hash>.js` only where `<script type=speculationrules>` is
// unsupported; the file adds `<link rel=prefetch>` on hover or focus.
//
//   tool/thor e2e prefetch-fallback                    (Chromium)
//   E2E_BROWSER=firefox tool/thor e2e prefetch-fallback
//   E2E_BROWSER=webkit tool/thor e2e prefetch-fallback
//
// test/fixtures/apps/server_query (build/server) behind a counting proxy that sees every
// request with a prefetch purpose. `/` ships the engine (so carries the
// inline test); `/scroll` has no JavaScript of its own and carries none:
// the fallback never makes a page without JavaScript load a script.
// - Where the rules are supported (Chromium, a recent WebKit): the fallback
//   file is never requested.
// - Without them (Firefox): the file is requested after load on the engine
//   page and never on the one without JavaScript; hovering a
//   link prefetches it, focus does too, a press does at once; never links that opt out, open
//   elsewhere, download, are another origin, are the current page or action
//   URLs; at most three in flight; nothing with Save-Data; nothing without
//   JavaScript.
import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { createServer as httpServer, request as httpRequest } from 'node:http';
import { createServer } from 'node:net';
import { join } from 'node:path';
import { closeServer, e2e, repo } from './lib/e2e.mjs';

const children = [];
process.on('exit', () => {
  for (const c of children) if (c.exitCode === null) c.kill('SIGKILL');
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

const pause = (ms) => new Promise((r) => setTimeout(r, ms));
const browserName = process.env.E2E_BROWSER ?? 'chromium';

await e2e('prefetch-fallback', { site: null, timeout: 180_000 }, async (t) => {
  const server = join(repo, 'test/fixtures/apps/server_query/build/server');
  if (!existsSync(server)) throw new Error('test/fixtures/apps/server_query/build/server is missing: build it first (tool/thor e2e builds it)');
  const appPort = await freePort();
  children.push(
    spawn(server, [], {
      cwd: join(repo, 'test/fixtures/apps/server_query'),
      env: { ...process.env, PORT: `${appPort}`, ISOLATES: '1' },
      stdio: 'ignore',
    }),
  );
  await waitFor(`http://127.0.0.1:${appPort}/scroll`);

  // The counting proxy: every request, whether it asked ahead, held for
  // `slow` ms when it did (to keep it in flight).
  const seen = [];
  let slow = 0;
  const proxy = httpServer((req, res) => {
    const purpose = `${req.headers['sec-purpose'] ?? ''} ${req.headers.purpose ?? ''} ${req.headers['x-moz'] ?? ''}`.toLowerCase();
    const ahead = purpose.includes('prefetch');
    const entry = { path: req.url, ahead, at: Date.now() };
    seen.push(entry);
    const forward = () => {
      const up = httpRequest(
        { host: '127.0.0.1', port: appPort, path: req.url, method: req.method, headers: req.headers },
        (r) => {
          res.writeHead(r.statusCode, r.headers);
          entry.cc = r.headers['cache-control'];
          r.pipe(res);
        },
      );
      up.on('error', () => res.destroy());
      req.pipe(up);
    };
    if (ahead && slow) setTimeout(forward, slow);
    else forward();
  });
  await new Promise((ok) => proxy.listen(0, '127.0.0.1', ok));
  const base = `http://127.0.0.1:${proxy.address().port}`;
  const ahead = (pred = () => true) => seen.filter((r) => r.ahead && pred(r.path));
  const files = () => seen.filter((r) => r.path.startsWith('/_thor/prefetch.'));
  const mark = () => seen.length;


  // A page fetched ahead is used by the click: the server answers it
  // `private, max-age=5`, so the visit makes no second document request
  // (a no-cache page would revalidate, and a 304 still renders on the server).
  const clickAfterHover = async (page, label) => {
    await page.evaluate(() => document.body.insertAdjacentHTML('afterbegin', '<a id="real" href="/acts">real</a>'));
    const at = mark();
    await page.locator('#real').hover();
    await pause(1200);
    t.check(`${label}: hovering a real page prefetches it once`, ahead((p) => p === '/acts').length === 1, JSON.stringify(seen.slice(at)));
    const cc = ahead((p) => p === '/acts')[0]?.cc;
    t.check(`${label}: a prefetch answer is kept a few seconds`, cc === 'private, max-age=5', `${cc}`);
    const clickAt = mark();
    await Promise.all([page.waitForURL(`${base}/acts`, { waitUntil: 'load' }), page.locator('#real').click()]);
    await pause(400);
    const visit = seen.slice(clickAt).filter((r) => r.path === '/acts' && !r.ahead);
    t.check(`${label}: the click after a hover makes no second document request`, visit.length === 0, JSON.stringify(visit));
  };

  try {
    // --- supported: Chromium, and a WebKit that has the rules --------------------
    const probe = await t.page();
    await probe.goto(`${base}/`);
    const supported = await probe.evaluate(
      () => !!HTMLScriptElement.supports && HTMLScriptElement.supports('speculationrules'),
    );
    await probe.context().close();
    seen.length = 0;
    console.log(`  ${browserName}: Speculation Rules ${supported ? 'supported' : 'not supported'}`);
    if (supported) {
      const page = await t.page();
      await page.goto(`${base}/`);
      await pause(800);
      t.check(`${browserName}: the page carries the inline test`, (await page.locator('script[data-thor-prefetch]').count()) === 1);
      t.check(`${browserName}: the fallback file is never requested`, files().length === 0, JSON.stringify(files()));
      // WebKit denies the rules' prefetch over plain http: nothing to click on.
      if (browserName !== 'webkit') await clickAfterHover(page, browserName);
      await page.goto(`${base}/scroll`);
      t.check(`${browserName}: a page without JavaScript carries no prefetch script`, (await page.locator('script[data-thor-prefetch]').count()) === 0);
      // WebKit denies the rules' prefetch over plain http (a secure origin only): not ours.
      const own = page.problems.filter((p) => !/Prefetch request denied/.test(p));
      t.check(`${browserName}: no console errors`, own.length === 0, own.join('; '));
      await page.context().close();
      return;
    }

    // --- unsupported: Firefox / WebKit -----------------------------------------
    const page = await t.page();
    await page.goto(`${base}/`);
    await page.waitForLoadState('load');
    await pause(1000);
    t.check('the engine page carries the inline test', (await page.locator('script[data-thor-prefetch]').count()) === 1);
    t.check('the fallback file is requested after load', files().length === 1, JSON.stringify(files()));
    // Links added after load (a Watch.list row, a streamed piece): the file
    // listens on the document, so they count like the first ones.
    await page.evaluate(() => {
      const nav = document.createElement('nav');
      for (let i = 0; i < 5; i++) {
        const a = document.createElement('a');
        a.href = `/article/late-${i}`;
        a.textContent = `late ${i}`;
        nav.append(a, ' ');
      }
      document.body.prepend(nav);
    });
    const articles = page.locator('a[href^="/article/"]');
    const count = await articles.count();
    t.check('the page has the late links', count >= 4, `${count}`);
    const hrefOf = (i) => articles.nth(i).getAttribute('href');

    // Links that must never prefetch: made on the page after load.
    await page.evaluate(() => {
      const box = document.createElement('div');
      box.id = 'probe';
      box.innerHTML = [
        '<a id="x-optout" href="/about-x" data-no-prefetch>a</a>',
        '<a id="x-blank" href="/blank-x" target="_blank">b</a>',
        '<a id="x-down" href="/down-x" download>c</a>',
        '<a id="x-nofollow" href="/nofollow-x" rel="nofollow">d</a>',
        '<a id="x-other" href="https://other.test/o">e</a>',
        '<a id="x-action" href="/login?/signIn">f</a>',
        '<a id="x-self" href="/#frag">g</a>',
      ].join('');
      document.body.prepend(box);
    });
    const before = mark();
    for (const id of ['x-optout', 'x-blank', 'x-down', 'x-nofollow', 'x-other', 'x-action', 'x-self']) {
      await page.locator(`#${id}`).hover();
      await pause(350);
    }
    t.check(
      'nothing prefetches for links that opt out, open elsewhere, download, are another origin, an action or the page itself',
      ahead((p) => true).filter((r) => seen.indexOf(r) >= before).length === 0,
      JSON.stringify(seen.slice(before)),
    );

    // A touch (pointerover with pointerType touch) never prefetches: no flood
    // while the finger scrolls; its press does.
    const touchHref = await hrefOf(4);
    const touchAt = mark();
    await articles.nth(4).dispatchEvent('pointerover', { pointerType: 'touch' });
    await pause(700);
    t.check('a touch hover does not prefetch', ahead((p) => p === touchHref).length === 0, JSON.stringify(seen.slice(touchAt)));

    // Hover: after a small delay, not at once.
    const first = await hrefOf(0);
    const hoverAt = mark();
    await articles.nth(0).hover();
    await pause(60);
    const early = ahead((p) => p === first).length;
    await pause(900);
    const late = ahead((p) => p === first).length;
    t.check('a short hover does not prefetch yet', early === 0, `${early}`);
    t.check('hovering a link prefetches it after the delay', late === 1, JSON.stringify(seen.slice(hoverAt)));
    // Leaving before the delay cancels.
    const second = await hrefOf(1);
    await articles.nth(1).hover();
    await pause(60);
    await page.mouse.move(2, 2);
    await pause(700);
    t.check('leaving before the delay cancels it', ahead((p) => p === second).length === 0);
    // The same link twice: once.
    await articles.nth(0).hover();
    await pause(500);
    t.check('a link already prefetched is not asked again', ahead((p) => p === first).length === 1);

    // Focus.
    const third = await hrefOf(2);
    await articles.nth(2).focus();
    await pause(900);
    t.check('focusing a link prefetches it', ahead((p) => p === third).length === 1, `${third} ${JSON.stringify(seen.slice(-4))}`);

    // A press goes at once.
    const fourth = await hrefOf(3);
    await articles.nth(3).dispatchEvent('pointerdown', { pointerType: 'mouse' });
    await pause(250);
    t.check('a press prefetches at once', ahead((p) => p === fourth).length === 1);

    // At most three in flight (the proxy holds each for 1.5 s).
    slow = 1500;
    const inflightBefore = mark();
    const extra = await page.evaluate(() => {
      const box = document.getElementById('probe');
      for (let i = 0; i < 6; i++) {
        const a = document.createElement('a');
        a.id = `q${i}`;
        a.href = `/queue-${i}`;
        a.textContent = `q${i}`;
        box.append(a);
      }
      return 6;
    });
    for (let i = 0; i < extra; i++) {
      await page.locator(`#q${i}`).dispatchEvent('pointerdown', { pointerType: 'mouse' });
      await pause(40);
    }
    await pause(400);
    const flying = seen.slice(inflightBefore).filter((r) => r.ahead && r.path.startsWith('/queue-'));
    t.check('at most three prefetches in flight', flying.length === 3, JSON.stringify(flying));
    slow = 0;
    await pause(1800);
    // Every prefetch that finished took its <link> out of the head.
    const left = await page.locator('link[rel=prefetch]').count();
    t.check('finished prefetches leave no <link> in the head', left === 0, `${left}`);
    await clickAfterHover(page, browserName);
    await page.context().close();

    // Save-Data: nothing.
    {
      const p = await t.page();
      await p.addInitScript(() => sessionStorage.setItem('save-data', '1'));
      await p.addInitScript(() => {
        if (sessionStorage.getItem('save-data')) {
          Object.defineProperty(navigator, 'connection', { value: { saveData: true }, configurable: true });
        }
      });
      await p.goto(`${base}/`);
      await pause(800);
      const at = mark();
      await p.evaluate(() => document.body.insertAdjacentHTML('afterbegin', '<a id="sd" href="/article/sd">sd</a>'));
      const link = p.locator('#sd');
      await link.hover();
      await pause(900);
      t.check('with Save-Data nothing is prefetched', ahead().filter((r) => seen.indexOf(r) >= at).length === 0, JSON.stringify(seen.slice(at)));
      await p.context().close();
    }

    // A page without JavaScript (no engine, no state) carries no script of the fallback and
    // loads no file, whatever the browser.
    {
      const p = await t.page();
      const at = mark();
      await p.goto(`${base}/scroll`);
      await p.waitForLoadState('load');
      await pause(800);
      t.check('a page without JavaScript carries no prefetch script', (await p.locator('script[data-thor-prefetch]').count()) === 0);
      t.check('and requests no fallback file', files().filter((r) => seen.indexOf(r) >= at).length === 0, JSON.stringify(seen.slice(at)));
      await p.context().close();
    }

    // No JavaScript: nothing to load, the link still works.
    {
      const p = await t.page({ javaScriptEnabled: false });
      const at = mark();
      await p.goto(`${base}/`);
      await p.locator('a[href="/profile"]').first().hover();
      await pause(700);
      t.check('without JavaScript nothing is prefetched', ahead().filter((r) => seen.indexOf(r) >= at).length === 0);
      await p.context().close();
    }
    t.check('no console errors', page.problems.length === 0, page.problems.join('; '));
  } finally {
    await closeServer(proxy);
  }
});

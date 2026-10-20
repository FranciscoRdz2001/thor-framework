// A form action that answers the page it was sent from keeps the visitor where
// they were (scroll and the pressed button), in a real browser, on
// test/fixtures/apps/server_query's public `/scroll` page (build/server).
//
//   tool/thor e2e scroll                     (builds test/fixtures/apps/server_query, runs)
//   node test/e2e/checks/scroll_check.mjs
//
// S1  a button whose action redirects back to the page (+ a flash), answers the
//     page itself (`?/answer`) or fails with a 422: scrollY stays (±40 px) and
//     the pressed button has the focus.
// S2  a redirect to another page starts at its top, and takes the saved place
//     with it (a link back to the first page is a normal navigation).
// S3  a link, a reload and back/forward are the browser's: nothing restores on
//     a link, the saved place is not applied twice.
// S4  a place saved long ago, or by another page, is not applied; a `#hash`
//     target wins.
// S5  streamed content (`?late=1`): the list arrives after the script ran, the
//     place and the focus are applied once it is there.
// S6  no JS: the page starts at its top, as a plain HTML form does.
// S7  a post that never navigates (a 204) leaves nothing behind: a link to the
//     same URL afterwards starts at the top; a GET form (search) saves nothing.
// S8  `Redirect.back(request)` keeps the query and the place; a hand-written
//     redirect that drops the query is the same PATH: the place is kept too.
// S9  hostile layouts: `scroll-behavior: smooth`, RTL, late images without a
//     size above the button, a visitor who scrolls (no wheel, key or pointer
//     event: a scrollbar drag) while the page loads, Enter in a field.
// S11 the rule is the PATH: a stepper whose action redirects to the same path
//     with another query, the cart's `withArgs` buttons answering the page or
//     `Redirect.back`: the place is kept. `Redirect(resetScroll: true)` and
//     `Form(resetScroll: true)` start at the top; another path too; a plain
//     GET link to `?page=2` is no action (the top). The `thor-scroll` cookie
//     is used up, and does not reset a later landing on another path.
// S10 sessionStorage that throws (private mode, quota), a strict CSP with the
//     script's hash, a double submit.
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { createServer } from 'node:net';
import { createServer as http } from 'node:http';
import { createHash } from 'node:crypto';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { e2e, repo, settle } from './lib/e2e.mjs';

const children = [];
const tmp = mkdtempSync(join(tmpdir(), 'thor-scroll-'));
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

await e2e('scroll', { site: tmp, timeout: 120_000 }, async (t) => {
  const check = (label, ok, detail = '') => t.check(label, ok, ok ? '' : detail);
  const bin = join(repo, 'test/fixtures/apps/server_query/build/server');
  if (!existsSync(bin)) throw new Error('test/fixtures/apps/server_query/build/server is missing: build it first (tool/thor e2e builds it)');
  const port = await freePort();
  children.push(
    spawn(bin, [], { cwd: join(repo, 'test/fixtures/apps/server_query'), env: { ...process.env, PORT: `${port}` }, stdio: 'ignore' }),
  );
  const app = `http://127.0.0.1:${port}`;
  await waitFor(`${app}/scroll`);

  const open = async (options = {}) => {
    const page = await t.page({ viewport: { width: 800, height: 600 }, ...options });
    return page;
  };
  const go = (page, click) => Promise.all([page.waitForNavigation({ waitUntil: 'load' }), click]);
  const y = (page) => page.evaluate(() => Math.round(scrollY));
  // Scrolls so the button is in the middle of the window, as a visitor would.
  const reach = async (page, name) => {
    const b = page.getByRole('button', { name, exact: true });
    await b.evaluate((el) => el.scrollIntoView({ block: 'center', behavior: 'instant' }));
    return b;
  };
  const focused = (page) => page.evaluate(() => (document.activeElement === document.body ? '(body)' : document.activeElement?.textContent?.trim().slice(0, 30)));
  const near = (a, b) => Math.abs(a - b) <= 40;
  // WebKit's parser yields mid-document (about 10 ms in), and a frame is
  // painted with the part that is there, at the top, before the script at the
  // end of the body can scroll: a short flash that nothing in the page can
  // prevent (a render-blocking `<link rel=expect>` is Chromium-only). Its
  // first-frame checks only run where the first frame is the whole page.
  const earlyPaint = t.browser.browserType().name() === 'webkit';

  // ------------------------------------------------ S1 · the same page
  for (const [name, path, label] of [
    ['Add 40', '/scroll', 'a redirect back to the page'],
    ['Answer', '/scroll?/answer', 'the page answered by the POST'],
    ['Fail', '/scroll?/fail', 'a 422 re-render'],
  ]) {
    const page = await open();
    // scrollY at the first frame of every document: no visible jump from the top.
    await page.addInitScript(() => requestAnimationFrame(() => (window.__first = scrollY)));
    await page.goto(`${app}/scroll`);
    const b = await reach(page, name);
    const before = await y(page);
    check(`S1 setup (${name}): the button is far down`, before > 300, `${before}`);
    await go(page, b.click());
    const after = await y(page);
    check(`S1 ${label}: scrollY stays (${before} -> ${after})`, near(before, after), `${before} -> ${after}`);
    const first = await page.evaluate(() => window.__first);
    if (!earlyPaint) check(`S1 ${label}: already there at the first frame (${first})`, near(before, first), `${before} vs ${first}`);
    check(`S1 ${label}: the pressed button has the focus`, (await focused(page)) === name, await focused(page));
    check(`S1 ${label}: it is the page we expected (${new URL(page.url()).pathname + new URL(page.url()).search})`, new URL(page.url()).pathname === '/scroll');
    if (name === 'Add 40') {
      const toast = await page.evaluate(() => document.getElementById('thor-toast')?.textContent);
      check('S1 the flash toast still shows', toast === 'Agregado 40', toast);
    }
    check('S1 nothing is left stored once applied', await page.evaluate(() => sessionStorage.length === 0), 'left');
    check(`S1 ${label}: no page problems`, page.problems.filter((p) => !/422/.test(p)).length === 0, page.problems.join(' | '));
    await page.context().close();
  }

  // ------------------------------------------------ S2 · another page, S3 · links
  {
    const page = await open();
    await page.goto(`${app}/scroll`);
    await go(page, (await reach(page, 'Leave')).click());
    check('S2 a redirect to another page starts at its top', new URL(page.url()).pathname === '/acts' && (await y(page)) === 0, `${page.url()} ${await y(page)}`);
    check('S2 the saved place does not wait for another day', await page.evaluate(() => sessionStorage.length === 0), 'left');
    // A visit to the first page afterwards is a normal navigation.
    await page.goto(`${app}/scroll`);
    check('S3 a navigation to the page afterwards starts at its top', (await y(page)) === 0, `${await y(page)}`);
    await page.context().close();
  }
  {
    const page = await open();
    await page.goto(`${app}/scroll`);
    await go(page, (await reach(page, 'Add 40')).click());
    const kept = await y(page);
    // A link to the very same URL, after the place was applied.
    await page.evaluate(() => scrollTo(0, 0));
    await go(page, page.getByRole('link', { name: 'To scroll' }).click());
    check('S3 a link to the same URL starts at its top', (await y(page)) === 0, `${await y(page)}`);
    // Back to the page we came from: the browser restores its own place.
    await page.goto(`${app}/scroll`);
    await go(page, (await reach(page, 'Add 30')).click());
    const kept2 = await y(page);
    const toActs = page.getByRole('link', { name: 'To acts' });
    await toActs.evaluate((el) => el.scrollIntoView({ block: 'center', behavior: 'instant' }));
    const left = await y(page);
    await go(page, toActs.click());
    await page.goBack({ waitUntil: 'load' });
    await settle(page, () => true, 0);
    check(`S3 back/forward: the browser's place (${left}), not applied twice`, near(await y(page), left), `${await y(page)} vs ${left}`);
    await page.reload({ waitUntil: 'load' });
    check('S3 a reload keeps the place the browser gives it', near(await y(page), left), `${await y(page)} vs ${left}`);
    check('S3 setup: the place was far down', kept > 300);
    await page.context().close();
  }

  // ------------------------------------------------ S4 · stale, hash
  {
    const page = await open();
    await page.goto(`${app}/scroll`);
    const old = () => page.evaluate(() => sessionStorage.setItem('thor:keep', JSON.stringify(['/scroll', 900, 5, Date.now() - 60_000, ''])));
    await old();
    await page.goto(`${app}/scroll?x=1`);
    check('S4 a place saved a minute ago is not applied', (await y(page)) === 0, `${await y(page)}`);
    await page.evaluate(() => sessionStorage.setItem('thor:keep', JSON.stringify(['/other', 900, 5, Date.now(), ''])));
    await page.goto(`${app}/scroll`);
    check('S4 a place saved by another page is not applied', (await y(page)) === 0, `${await y(page)}`);
    await page.evaluate(() => sessionStorage.setItem('thor:keep', JSON.stringify(['/scroll', 900, 5, Date.now(), ''])));
    await page.goto(`${app}/scroll#bottom`);
    check('S4 a #hash target is not overridden', (await y(page)) !== 900, `${await y(page)}`);
    await page.evaluate(() => sessionStorage.setItem('thor:keep', '{not json'));
    await page.goto(`${app}/scroll`);
    check('S4 garbage in storage is ignored', (await y(page)) === 0 && page.problems.length === 0, page.problems.join(' | '));
    await page.context().close();
  }

  // ------------------------------------------------ S5 · streamed
  {
    const page = await open();
    await page.goto(`${app}/scroll?late=1`);
    await settle(page, () => document.querySelectorAll('button').length > 20, 0, { timeout: 8000 });
    const b = await reach(page, 'Add 40');
    const before = await y(page);
    await go(page, b.click());
    await settle(page, () => document.querySelectorAll('button').length > 20, 0, { timeout: 8000 });
    await settle(page, () => true, 0);
    await new Promise((r) => setTimeout(r, 300));
    const after = await y(page);
    check(`S5 streamed: scrollY is applied once the list is there (${before} -> ${after})`, near(before, after), `${before} -> ${after}`);
    check('S5 streamed: the pressed button has the focus', (await focused(page)) === 'Add 40', await focused(page));
    await page.context().close();
  }

  // ------------------------------------------------ S6 · no JS
  {
    const page = await open({ javaScriptEnabled: false });
    await page.goto(`${app}/scroll`);
    await page.getByRole('button', { name: 'Add 40', exact: true }).evaluate((el) => el.scrollIntoView());
    await go(page, page.getByRole('button', { name: 'Add 40', exact: true }).click());
    check('S6 no JS: the page starts at its top, as a plain HTML form', new URL(page.url()).pathname === '/scroll' && (await page.evaluate(() => scrollY)) === 0, `${page.url()}`);
    await page.context().close();
  }

  // ------------------------------------------------ S7 · nothing kept
  {
    const page = await open();
    await page.route(/\/scroll\?\/answer$/, (r) => r.fulfill({ status: 204 }));
    await page.goto(`${app}/scroll`);
    const b = await reach(page, 'Answer');
    await b.click();
    await new Promise((r) => setTimeout(r, 400));
    check('S7 a 204 stays on the page', new URL(page.url()).pathname === '/scroll');
    await page.evaluate(() => scrollTo(0, 0));
    await go(page, page.getByRole('link', { name: 'To scroll' }).click());
    check('S7 a post that never navigated keeps nothing: a link to the page starts at its top', (await y(page)) === 0, `${await y(page)}`);
    await page.context().close();
  }
  {
    const page = await open();
    await page.goto(`${app}/scroll`);
    await reach(page, 'Search');
    await page.getByLabel('Search').fill('abc');
    await go(page, page.getByRole('button', { name: 'Search', exact: true }).click());
    check('S7 a GET form (search) starts at the top of its result', new URL(page.url()).search === '?q=abc' && (await y(page)) === 0, `${page.url()} ${await y(page)}`);
    await page.context().close();
  }
  {
    // A post cancelled by another handler, then a plain visit.
    const page = await open();
    await page.goto(`${app}/scroll`);
    await page.evaluate(() => document.addEventListener('submit', (e) => e.preventDefault()));
    await (await reach(page, 'Add 40')).click();
    await page.evaluate(() => scrollTo(0, 0));
    await go(page, page.getByRole('link', { name: 'To scroll' }).click());
    check('S7 a cancelled submit keeps nothing', (await y(page)) === 0, `${await y(page)}`);
    await page.context().close();
  }

  // ------------------------------------------------ S8 · Redirect.back
  {
    const page = await open();
    await page.goto(`${app}/scroll?x=1`);
    const b = await reach(page, 'Add 40');
    const before = await y(page);
    await go(page, b.click());
    check(`S8 Redirect.back from a page with a query: the same URL, the same place (${before} -> ${await y(page)})`, new URL(page.url()).search === '?x=1' && near(before, await y(page)), `${page.url()} ${await y(page)}`);
    await page.context().close();
  }
  {
    const page = await open();
    await page.goto(`${app}/scroll?x=1`);
    await go(page, (await reach(page, 'Drop')).click());
    check('S8 a redirect that drops the query is the same path: the place is kept', new URL(page.url()).search === '' && (await y(page)) > 300, `${page.url()} ${await y(page)}`);
    await page.context().close();
  }

  // ------------------------------------------------ S9 · hostile layouts
  // The page's HTML is edited on its way (an image above, smooth scrolling,
  // RTL); the POST's answer too (the route does not see a redirect's target,
  // so the answer is the page itself).
  const png = '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="400"><rect width="10" height="400"/></svg>';
  const edited = async (options, edit, imageDelay = 0) => {
    const page = await open(options);
    await page.route('**/late.svg*', async (r) => {
      await new Promise((ok) => setTimeout(ok, imageDelay));
      await r.fulfill({ contentType: 'image/svg+xml', body: png });
    });
    await page.route(/\/scroll(\?.*)?$/, async (r) => {
      const res = await r.fetch();
      await r.fulfill({ response: res, body: edit(await res.text()) });
    });
    return page;
  };
  const sleep = (n) => new Promise((r) => setTimeout(r, n));
  {
    const page = await edited({}, (h) => h.replace('</head>', '<style>html{scroll-behavior:smooth}</style></head>'));
    await page.addInitScript(() => requestAnimationFrame(() => (window.__first = scrollY)));
    await page.goto(`${app}/scroll`);
    const b = await reach(page, 'Add 40');
    const before = await y(page);
    await go(page, b.click());
    await sleep(600);
    const first = await page.evaluate(() => window.__first);
    check(`S9 scroll-behavior: smooth: instant, not animated (${before} -> first ${first} -> ${await y(page)})`, (earlyPaint || near(before, first)) && near(before, await y(page)), `${first}`);
    await page.context().close();
  }
  {
    const page = await edited({}, (h) => h.replace('<html', '<html dir="rtl"'));
    await page.goto(`${app}/scroll`);
    const b = await reach(page, 'Add 40');
    const before = await y(page);
    await go(page, b.click());
    check('S9 rtl: the place is kept', near(before, await y(page)), `${before} -> ${await y(page)}`);
    await page.context().close();
  }
  {
    const page = await edited({}, (h) => h.replace('<body>', '<body><img src="/late.svg?' + Math.random() + '">'), 900);
    await page.goto(`${app}/scroll`);
    await page.waitForLoadState('load');
    const b = await reach(page, 'Add 40');
    const top = () => b.evaluate((e) => Math.round(e.getBoundingClientRect().top));
    const at = await top();
    await Promise.all([page.waitForNavigation({ waitUntil: 'commit' }), b.click()]);
    await sleep(2000);
    const now = await page.getByRole('button', { name: 'Add 40', exact: true }).evaluate((e) => Math.round(e.getBoundingClientRect().top));
    check(`S9 an image without a size that arrives late: the button is where it was (${at} -> ${now})`, near(at, now), `${at} -> ${now}`);
    await page.context().close();
  }
  {
    // The visitor drags the scrollbar while the page loads: the page's script
    // sees a `scroll` and no wheel, key or pointer event. It must not pull the
    // page back at `load`.
    const page = await edited({}, (h) => h.replace('<body>', '<body><img src="/late.svg?' + Math.random() + '">'), 1500);
    await page.goto(`${app}/scroll`);
    await page.waitForLoadState('load');
    const b = await reach(page, 'Add 40');
    await Promise.all([page.waitForNavigation({ waitUntil: 'commit' }), b.click()]);
    await page.waitForLoadState('domcontentloaded');
    await sleep(150);
    await page.evaluate(() => scrollTo({ top: 0, behavior: 'instant' }));
    await sleep(2200);
    check(`S9 the visitor scrolled during load: not fought at load (${await y(page)})`, (await y(page)) < 100, `${await y(page)}`);
    await page.context().close();
  }
  {
    const page = await open();
    await page.goto(`${app}/scroll`);
    await reach(page, 'Save note');
    const before = await y(page);
    await page.getByLabel('Note').focus();
    await page.keyboard.type('hi');
    await go(page, page.keyboard.press('Enter'));
    check('S9 Enter in a field: the place and the default button', near(before, await y(page)) && (await focused(page)) === 'Save note', `${before} -> ${await y(page)} ${await focused(page)}`);
    await page.context().close();
  }

  // ------------------------------------------------ S11 · the path is the page
  for (const [name, expectUrl, label] of [
    ['Qty 4', '/scroll?qty=4', 'a stepper: same path, another query'],
    ['Cart plus', '/scroll?/setQuantity', 'a cart button (withArgs) answering the page'],
    ['Cart back', '/scroll', 'a cart button (withArgs) with Redirect.back'],
  ]) {
    const page = await open();
    await page.goto(`${app}/scroll`);
    const b = await reach(page, name);
    const before = await y(page);
    await go(page, b.click());
    const u = new URL(page.url());
    check(`S11 ${label}: stays (${before} -> ${await y(page)}, ${u.pathname + u.search})`, u.pathname === '/scroll' && before > 300 && near(before, await y(page)), `${before} -> ${await y(page)} ${page.url()}`);
    check(`S11 ${label}: the pressed button has the focus`, (await focused(page)) === name, await focused(page));
    await page.context().close();
  }
  {
    // A stepper pressed twice in a row: each answer keeps the place.
    const page = await open();
    await page.goto(`${app}/scroll`);
    await go(page, (await reach(page, 'Qty 4')).click());
    const first = await y(page);
    await go(page, page.getByRole('button', { name: 'Qty 4', exact: true }).click());
    check(`S11 a stepper pressed twice keeps the place (${first} -> ${await y(page)})`, first > 300 && near(first, await y(page)), `${first} -> ${await y(page)}`);
    await page.context().close();
  }
  {
    const page = await open();
    await page.goto(`${app}/scroll`);
    await go(page, (await reach(page, 'Restart')).click());
    check(`S11 Redirect(resetScroll: true) on the same path: the top (${await y(page)})`, new URL(page.url()).search === '?page=1' && (await y(page)) === 0, `${page.url()} ${await y(page)}`);
    check('S11 the thor-scroll cookie is used up', !(await page.evaluate(() => document.cookie)).includes('thor-scroll'), await page.evaluate(() => document.cookie));
    check('S11 nothing is left stored', await page.evaluate(() => sessionStorage.length === 0), 'left');
    // The next action works as always.
    await go(page, (await reach(page, 'Add 40')).click());
    check('S11 the next action afterwards keeps the place again', (await y(page)) > 300, `${await y(page)}`);
    await page.context().close();
  }
  {
    const page = await open();
    await page.goto(`${app}/scroll`);
    await go(page, (await reach(page, 'Reset form')).click());
    check(`S11 Form(resetScroll: true): the top (${await y(page)})`, new URL(page.url()).pathname === '/scroll' && (await y(page)) === 0, `${page.url()} ${await y(page)}`);
    await page.context().close();
  }
  {
    // Another path: the top (S2 covers it with a flash); and a pagination link
    // is not an action: the browser's default.
    const page = await open();
    await page.goto(`${app}/scroll`);
    const link = page.getByRole('link', { name: 'Page 2' });
    await link.evaluate((el) => el.scrollIntoView({ block: 'center', behavior: 'instant' }));
    await go(page, link.click());
    check('S11 a plain GET link to ?page=2 starts at the top (not an action)', new URL(page.url()).search === '?page=2' && (await y(page)) === 0, `${page.url()} ${await y(page)}`);
    await page.context().close();
  }
  {
    // A reset cookie that nobody read (a landing without the script) must not
    // reset a later action: it names the tab that asked, and this is not it.
    const page = await open();
    await page.goto(`${app}/scroll`);
    await page.evaluate(() => (document.cookie = 'thor-scroll=zzzzzz; Path=/'));
    await go(page, (await reach(page, 'Add 40')).click());
    check('S11 a stale reset cookie of another tab does not reset', (await y(page)) > 300, `${await y(page)}`);
    await page.context().close();
  }

  // ------------------------------------------------ S12 · edge cases of the rule
  // The path is the rule, whatever its shape: a trailing slash, an encoded
  // or odd character, a very long one; `Redirect.back` + resetScroll resets
  // them all (the cookie never carries the path).
  const slugs = [
    ['a trailing slash', '/scroll/'],
    ['an encoded path', '/scroll/caf%C3%A9'],
    ['the same path typed raw', '/scroll/caf\u00e9'],
    ['a lowercase escape', '/scroll/caf%c3%a9'],
    ['an escaped unreserved character', '/scroll/a%7eb'],
    ['; , and a space', '/scroll/a%3Bb%2Cc%20d'],
    ['emoji', '/scroll/%F0%9F%94%A5'],
    ['a very long path', `/scroll/${'x'.repeat(3000)}`],
  ];
  for (const [label, path] of slugs) {
    const page = await open();
    const res = await page.goto(`${app}${path}`);
    if (!res || res.status() !== 200) {
      check(`S12 ${label}: the page loads (${res?.status()})`, false, `${res?.status()} ${page.url().slice(0, 80)}`);
      await page.context().close();
      continue;
    }
    // The server writes the escapes back normalized (`%c3` is `%C3`).
    const norm = (u) => decodeURI(new URL(u).pathname);
    const here = norm(page.url());
    await go(page, (await reach(page, 'Add 40')).click());
    const kept = await y(page);
    check(`S12 ${label}: Redirect.back keeps the place (${kept})`, norm(page.url()) === here && kept > 300, `${new URL(page.url()).pathname.slice(0, 60)} ${kept}`);
    await go(page, (await reach(page, 'Restart here')).click());
    check(`S12 ${label}: Redirect.back(resetScroll: true) starts at the top`, norm(page.url()) === here && (await y(page)) === 0, `${new URL(page.url()).pathname.slice(0, 60)} ${await y(page)}`);
    check(`S12 ${label}: nothing left in cookies or storage`, await page.evaluate(() => !/thor-scroll/.test(document.cookie) && sessionStorage.length === 0), await page.evaluate(() => document.cookie));
    await page.context().close();
  }
  {
    // A hash on the page the post came from: the answer has none, the place is kept.
    const page = await open();
    await page.goto(`${app}/scroll#top`);
    await go(page, (await reach(page, 'Add 40')).click());
    check('S12 a post from a page with a #hash lands without it and keeps the place', new URL(page.url()).hash === '' && (await y(page)) > 300, `${page.url()} ${await y(page)}`);
    await page.context().close();
  }
  {
    // A same-path GET form (search) is no action: the browser's top, and the
    // place of an earlier post is not left behind to be applied.
    const page = await open();
    await page.goto(`${app}/scroll`);
    await go(page, (await reach(page, 'Add 40')).click());
    await reach(page, 'Search');
    await page.getByLabel('Search').fill('abc');
    await go(page, page.getByRole('button', { name: 'Search', exact: true }).click());
    check('S12 a same-path GET form after a post starts at the top', new URL(page.url()).search === '?q=abc' && (await y(page)) === 0, `${page.url()} ${await y(page)}`);
    await page.context().close();
  }
  {
    // Two tabs share cookies and not sessionStorage. Tab A restarts (its
    // cookie is set, its landing is slow); tab B posts on the same path in
    // between: B keeps its place, A starts at the top.
    const a = await open();
    await a.goto(`${app}/scroll`);
    const ctx = a.context();
    const b = await ctx.newPage();
    b.problems = [];
    await b.goto(`${app}/scroll`);
    const restart = (await reach(a, 'Restart slow')).click();
    await sleep(500);
    await go(b, (await reach(b, 'Add 40')).click());
    const bKept = await y(b);
    await restart;
    await a.waitForLoadState('load');
    await sleep(300);
    check(`S12 two tabs: B's post keeps B's place although A's reset cookie is around (${bKept})`, bKept > 300, `${bKept}`);
    check(`S12 two tabs: A still starts at the top (${await y(a)})`, (await y(a)) === 0, `${await y(a)}`);
    await ctx.close();
  }
  {
    // Cookies unavailable (blocked, a sandboxed frame): the submit still goes
    // through and the place is kept; only the reset cannot be asked for.
    const page = await open();
    await page.addInitScript(() =>
      Object.defineProperty(Document.prototype, 'cookie', {
        get() { throw new DOMException('denied', 'SecurityError'); },
        set() { throw new DOMException('denied', 'SecurityError'); },
      }),
    );
    await page.goto(`${app}/scroll`);
    await go(page, (await reach(page, 'Add 40')).click());
    check(`S12 cookies throw: the post goes through and keeps the place (${await y(page)})`, new URL(page.url()).pathname === '/scroll' && (await y(page)) > 300 && page.problems.length === 0, `${page.url()} ${await y(page)} ${page.problems.join('|')}`);
    await page.context().close();
  }
  {
    // Form(resetScroll: true) needs no cookie at all.
    const page = await open();
    await page.addInitScript(() =>
      Object.defineProperty(Document.prototype, 'cookie', {
        get() { throw new DOMException('denied', 'SecurityError'); },
        set() { throw new DOMException('denied', 'SecurityError'); },
      }),
    );
    await page.goto(`${app}/scroll`);
    await go(page, (await reach(page, 'Reset form')).click());
    check('S12 cookies throw: Form(resetScroll: true) still starts at the top', (await y(page)) === 0, `${await y(page)}`);
    await page.context().close();
  }

  // ------------------------------------------------ S10 · storage, CSP, double submit
  for (const [label, init] of [
    ['sessionStorage throws on access', () => Object.defineProperty(window, 'sessionStorage', { get() { throw new DOMException('denied', 'SecurityError'); } })],
    ['sessionStorage throws on write (quota)', () => (Storage.prototype.setItem = () => { throw new DOMException('full', 'QuotaExceededError'); })],
  ]) {
    const page = await open();
    await page.addInitScript(init);
    await page.goto(`${app}/scroll`);
    const b = await reach(page, 'Add 40');
    await go(page, b.click());
    check(`S10 ${label}: the submit still goes through`, new URL(page.url()).pathname === '/scroll' && page.problems.length === 0, `${page.url()} ${page.problems.join('|')}`);
    await page.context().close();
  }
  {
    // Strict CSP with the inline script's hash (docs/guia/es/sesion-y-seguridad.md), through a proxy.
    const html = await (await fetch(`${app}/scroll`)).text();
    const inline = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]).find((c) => c.includes('thor:keep'));
    const hash = createHash('sha256').update(inline).digest('base64');
    const proxy = http(async (req, res) => {
      const body = ['GET', 'HEAD'].includes(req.method) ? undefined : Buffer.concat(await req.toArray());
      const up = await fetch(app + req.url, { method: req.method, headers: { ...req.headers, origin: app, referer: app + new URL(req.headers.referer ?? '/', app).pathname + new URL(req.headers.referer ?? '/', app).search }, body, redirect: 'manual' });
      const headers = {};
      up.headers.forEach((v, k) => (headers[k] = v));
      headers['set-cookie'] = up.headers.getSetCookie();
      delete headers['content-encoding'];
      delete headers['content-length'];
      headers['content-security-policy'] = `script-src 'sha256-${hash}' 'strict-dynamic'; object-src 'none'`;
      res.writeHead(up.status, headers);
      res.end(Buffer.from(await up.arrayBuffer()));
    });
    await new Promise((ok) => proxy.listen(0, '127.0.0.1', ok));
    const csp = `http://127.0.0.1:${proxy.address().port}`;
    const page = await open();
    const violations = [];
    page.on('console', (m) => /Content Security Policy/i.test(m.text()) && !/speculation/i.test(m.text()) && violations.push(m.text()));
    await page.goto(`${csp}/scroll`);
    const b = await reach(page, 'Add 40');
    const before = await y(page);
    await go(page, b.click());
    check(`S10 strict CSP with the documented hash: the place is kept (${before} -> ${await y(page)})`, near(before, await y(page)) && (await focused(page)) === 'Add 40', `${await y(page)} ${await focused(page)} ${violations.join('|')}`);
    await page.context().close();
    proxy.close();
  }
  {
    const page = await open();
    await page.goto(`${app}/scroll`);
    const b = await reach(page, 'Add 40');
    const before = await y(page);
    await Promise.all([page.waitForNavigation({ waitUntil: 'load' }), b.dispatchEvent('click').then(() => b.dispatchEvent('click').catch(() => {}))]);
    await sleep(300);
    check('S10 a double submit keeps the place of the first', near(before, await y(page)), `${before} -> ${await y(page)}`);
    await page.context().close();
  }
});

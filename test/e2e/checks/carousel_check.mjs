// CarouselView in a real browser (Chromium: ::scroll-button, ::scroll-marker):
// the arrows sit inside the carousel and the page never scrolls sideways
// (390 and 320 px, outside arrows included); an arrow moves the carousel by a
// page; the dots show where it is and jump to an item; all of it with no
// JavaScript; autoplay (lite part) advances, pauses on hover and focus and
// stays still with prefers-reduced-motion; and the fallback controls (real
// buttons the lite part shows where the browser draws no ::scroll-button), and
// a live list's carousel (rows added after load: controls appear with two rows):
// Chromium with the native support switched off, and Firefox and WebKit as they are.
//
//   tool/thor e2e carousel                       (renders the page, serves, runs)
//   node test/e2e/checks/carousel_check.mjs
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { firefox, webkit } from '../runner/node_modules/playwright/index.mjs';
import { closeServer, e2e, repo, serveStatic, tabKey } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
const bundle = readFileSync(join(lite, 'runtime.js'), 'utf8').replace('// @thor-lite-parts', () =>
  readFileSync(join(lite, 'parts/carousel.js'), 'utf8'),
);

// What runs where. The native arrows and dots (::scroll-button, ::scroll-marker,
// CSS carousels) are Chromium's: their sections only make sense when the run's
// browser is Chromium (E2E_BROWSER unset). Firefox and WebKit are driven by the
// check itself (the fallback controls are theirs), so a Chromium run covers all
// three and `E2E_BROWSER=firefox|webkit` runs the one it names.
const chosen = process.env.E2E_BROWSER ?? 'chromium';
const native = chosen === 'chromium';
const browsers = [['firefox', firefox], ['webkit', webkit]].filter(([name]) => native || name === chosen);

const dir = mkdtempSync(join(tmpdir(), 'thor-carousel-'));
let server;

await e2e('carousel', { site: null, timeout: 300_000 }, async (t) => {
  try {
    await run(t);
  } finally {
    await closeServer(server);
    rmSync(dir, { recursive: true, force: true });
  }
});

async function run(t) {
  execFileSync('dart', ['run', 'tool/e2e_pages.dart', dir], {
    cwd: join(repo, 'packages/thor_ui'),
    stdio: ['ignore', 'inherit', 'inherit'],
  });
  server = await serveStatic(dir);
  const url = `http://127.0.0.1:${server.address().port}/carousel.html`;

  const open = async (options, { engine = false } = {}) => {
    const page = await t.page(options);
    await page.route(/\/engine[^/]*\.js(\?|$)/, (r) => r.fulfill({ contentType: 'text/javascript', body: '' }));
    await page.goto(url);
    if (engine) await page.addScriptTag({ content: bundle });
    return page;
  };
  // The page of the carousel named `name`: where it is and what it has.
  const info = (page, name) =>
    page.evaluate((name) => {
      const el = document.querySelector(`[aria-label="${name}"]`);
      const r = el.getBoundingClientRect();
      const pe = (s, p) => {
        const c = getComputedStyle(s, p);
        return { left: parseFloat(c.left), top: parseFloat(c.top), width: parseFloat(c.width), opacity: Number(c.opacity), bg: c.backgroundColor };
      };
      return {
        rect: { left: r.left + scrollX, top: r.top + scrollY, width: r.width, height: r.height },
        scrollLeft: el.scrollLeft,
        client: el.clientWidth,
        prev: pe(el, '::scroll-button(left)'),
        next: pe(el, '::scroll-button(right)'),
        group: pe(el, '::scroll-marker-group'),
        dots: [...el.children].map((c) => getComputedStyle(c, '::scroll-marker').backgroundColor),
        items: el.children.length,
      };
    }, name);
  // Waits until the carousel `name` has not moved for 3 samples 80 ms apart.
  const resting = async (page, name) => {
    let last = null;
    let same = 0;
    for (let i = 0; i < 80 && same < 3; i++) {
      const now = (await info(page, name)).scrollLeft;
      same = now === last ? same + 1 : 0;
      last = now;
      await page.waitForTimeout(80);
    }
  };
  const overflow = (page) => page.evaluate(() => ({ sw: document.documentElement.scrollWidth, w: innerWidth }));
  const near = (a, b, tol = 3) => Math.abs(a - b) <= tol;
  const scrollTo = async (page, name, x, tol = 3) => {
    await page
      .waitForFunction(([n, x, tol]) => Math.abs(document.querySelector(`[aria-label="${n}"]`).scrollLeft - x) <= tol, [name, x, tol], { timeout: 4000 })
      .catch(() => {});
    return (await info(page, name)).scrollLeft;
  };

  for (const js of native ? [false, true] : []) {
    const label = js ? 'with JS' : 'without JS';
    for (const width of [390, 320, 1280]) {
      const page = await open({ javaScriptEnabled: js, viewport: { width, height: 800 } }, { engine: js });
      const o = await overflow(page);
      t.check(`${label}, ${width}px: the page does not scroll sideways`, o.sw <= o.w, JSON.stringify(o));
      for (const name of ['Hero', 'Outside']) {
        const i = await info(page, name);
        const box = i.rect;
        t.check(
          `${label}, ${width}px: ${name} arrows are inside the carousel`,
          i.prev.left >= box.left - 0.5 &&
            i.next.left + i.next.width <= box.left + box.width + 0.5 &&
            i.prev.left + i.prev.width <= i.next.left,
          JSON.stringify([box, i.prev, i.next]),
        );
      }
      await page.context().close();
    }

    // Arrows and dots, by mouse, on a phone.
    const page = await open({ javaScriptEnabled: js, viewport: { width: 390, height: 800 } }, { engine: js });
    let i = await info(page, 'Hero');
    const w = i.rect.width;
    const gap = 16;
    const page1 = w + gap;
    t.check(`${label}: starts at the first item, previous disabled`, i.scrollLeft === 0 && i.prev.opacity < 1 && i.next.opacity === 1, JSON.stringify(i.prev));
    t.check(`${label}: the arrow has the style it was given`, i.next.width === 34 && i.next.bg === 'rgb(27, 42, 107)', JSON.stringify(i.next));
    t.check(`${label}: the first dot is the current one`, i.dots[0] === 'rgb(27, 42, 107)' && i.dots[1] === 'rgb(204, 204, 204)', JSON.stringify(i.dots));

    await page.mouse.click(i.next.left + i.next.width / 2, i.next.top);
    const after = await scrollTo(page, 'Hero', page1);
    t.check(`${label}: next moves by a page`, near(after, page1, 4), `scrollLeft ${after}, a page is ${page1}`);
    await page.waitForTimeout(300);
    i = await info(page, 'Hero');
    t.check(`${label}: the dots follow`, i.dots[1] === 'rgb(27, 42, 107)' && i.dots[0] === 'rgb(204, 204, 204)', JSON.stringify(i.dots));

    await page.mouse.click(i.prev.left + i.prev.width / 2, i.prev.top);
    t.check(`${label}: previous goes back`, near(await scrollTo(page, 'Hero', 0), 0, 2));

    // A dot: its centre is one dot size + spacing from its neighbours', around the group's centre.
    const dotX = (n) => i.group.left + (n - (i.items - 1) / 2) * 16;
    await page.mouse.click(dotX(3), i.group.top + 4);
    const last = await scrollTo(page, 'Hero', 3 * page1);
    t.check(`${label}: a dot jumps to its item`, near(last, 3 * page1, 4), `scrollLeft ${last}`);
    await page.waitForTimeout(300);
    i = await info(page, 'Hero');
    t.check(`${label}: the last dot is current, next disabled`, i.dots[3] === 'rgb(27, 42, 107)' && i.next.opacity < 1, JSON.stringify([i.dots, i.next]));

    // arrowIcon / arrowInset: the glyph is the given icon (mirrored on the left)
    // and the arrows sit 20 px in from the edges.
    const ic = await info(page, 'Icon');
    t.check(`${label}: arrowInset puts the arrows 20 px from the carousel's edges`, near(ic.prev.left, ic.rect.left + 20, 1) && near(ic.next.left + ic.next.width, ic.rect.left + ic.rect.width - 20, 1), JSON.stringify([ic.rect, ic.prev, ic.next]));
    const glyphs = await page.evaluate(() => {
      const el = document.querySelector('[aria-label="Icon"]');
      const img = (p) => decodeURIComponent(getComputedStyle(el, p).backgroundImage);
      return { prev: img('::scroll-button(left)'), next: img('::scroll-button(right)') };
    });
    t.check(`${label}: arrowIcon is the glyph, mirrored on the previous arrow`, glyphs.next.includes('M8 4l8 8-8 8') && !glyphs.next.includes('matrix') && glyphs.prev.includes('M8 4l8 8-8 8') && glyphs.prev.includes('matrix(-1 0 0 1 24 0)'), JSON.stringify(glyphs));

    // The carousel with no controls draws none.
    const plain = await info(page, 'Plain');
    t.check(`${label}: showArrows: false and no dots draw nothing`, Number.isNaN(plain.prev.width) && Number.isNaN(plain.group.width), JSON.stringify([plain.prev, plain.group]));

    // The keyboard still scrolls it (the region is focusable).
    await page.focus('[aria-label="Plain"]');
    await page.keyboard.press('ArrowRight');
    await page.waitForFunction(() => document.querySelector('[aria-label=Plain]').scrollLeft > 0, null, { timeout: 3000 }).catch(() => {});
    const key = (await info(page, 'Plain')).scrollLeft;
    t.check(`${label}: the arrow keys scroll it`, key > 0, `scrollLeft ${key}`);
    t.check(`${label}: no page errors`, page.problems.length === 0, page.problems.join('; '));
    await page.context().close();
  }

  // The fallback controls: real buttons, shown by the engine where the browser
  // has no ::scroll-button. Chromium is made to look like one that has none;
  // Firefox and WebKit are the real thing (skipped when not installed).
  {
    const page = await open({ javaScriptEnabled: false, viewport: { width: 390, height: 800 } });
    const vis = await page.evaluate(() =>
      ['[data-t-cv-prev]', '[data-t-cv-next]', '[data-t-cv-dots]'].map((q) => document.querySelector(q).offsetParent !== null),
    );
    t.check('fallback: without JS no control is shown (no dead buttons)', vis.every((v) => !v), JSON.stringify(vis));
    await page.context().close();
  }
  if (native) {
    const page = await t.page({ viewport: { width: 390, height: 800 } });
    await page.addInitScript(() => {
      const supports = CSS.supports.bind(CSS);
      CSS.supports = (a, b) => (typeof a === 'string' && a.includes('::scroll-button') ? false : supports(a, b));
    });
    await page.route(/\/engine[^/]*\.js(\?|$)/, (r) => r.fulfill({ contentType: 'text/javascript', body: '' }));
    await page.goto(url);
    await page.addStyleTag({ content: '*::scroll-button(*), *::scroll-marker-group { display: none !important; }' });
    await page.addScriptTag({ content: bundle });
    await fallback(page, 'chromium (native off)');
    await page.context().close();
  }
  for (const [name, type] of browsers) {
    let browser;
    try {
      browser = await type.launch();
    } catch (e) {
      console.log(`skip ${name}: ${String(e.message).split('\n')[0]}`);
      continue;
    }
    try {
      const ctx = await browser.newContext({ viewport: { width: 390, height: 800 } });
      const page = await ctx.newPage();
      page.problems = [];
      page.on('pageerror', (e) => page.problems.push(e.message));
      await page.route(/\/engine[^/]*\.js(\?|$)/, (r) => r.fulfill({ contentType: 'text/javascript', body: '' }));
      await page.goto(url);
      await page.addScriptTag({ content: bundle });
      await fallback(page, name);
      t.check(`fallback ${name}: no page errors`, page.problems.length === 0, page.problems.join('; '));
    } finally {
      await browser.close();
    }
  }

  async function fallback(page, label) {
    const hero = (q) => page.locator('[aria-label=Hero]').locator('xpath=..').locator(q);
    const st = () =>
      page.evaluate(() => {
        const sc = document.querySelector('[aria-label=Hero]');
        const w = sc.parentElement;
        const shown = (q) => {
          const e = w.querySelector(q);
          const r = e.getBoundingClientRect();
          return { visible: e.offsetParent !== null && r.width > 0, disabled: e.disabled || e.getAttribute('aria-disabled') === 'true', left: r.left, right: r.right };
        };
        const dots = [...w.querySelectorAll('[data-t-cv-dots] button')];
        return {
          sl: Math.abs(sc.scrollLeft),
          box: sc.getBoundingClientRect().toJSON(),
          prev: shown('[data-t-cv-prev]'),
          next: shown('[data-t-cv-next]'),
          dots: dots.map((d) => d.getAttribute('aria-current') === 'true'),
          dotsVisible: w.querySelector('[data-t-cv-dots]').offsetParent !== null,
          sw: document.documentElement.scrollWidth,
          iw: innerWidth,
        };
      });
    const until = async (x) => {
      await page.waitForFunction((x) => Math.abs(Math.abs(document.querySelector('[aria-label=Hero]').scrollLeft) - x) <= 4, x, { timeout: 4000 }).catch(() => {});
      await page.waitForTimeout(250);
      return st();
    };
    let s = await st();
    t.check(`fallback ${label}: arrows and dots are shown`, s.prev.visible && s.next.visible && s.dotsVisible && s.dots.length === 4, JSON.stringify(s));
    t.check(
      `fallback ${label}: arrows sit inside the carousel, the page does not scroll sideways`,
      s.prev.left >= s.box.left && s.next.right <= s.box.right + 0.5 && s.sw <= s.iw,
      JSON.stringify([s.prev, s.next, s.box, s.sw, s.iw]),
    );
    t.check(`fallback ${label}: first item, previous disabled, first dot current`, s.sl === 0 && s.prev.disabled && !s.next.disabled && s.dots[0] && s.dots.filter(Boolean).length === 1, JSON.stringify(s));
    const pg = s.box.width + 16;
    await hero('[data-t-cv-next]').click();
    s = await until(pg);
    t.check(`fallback ${label}: next moves by a page`, Math.abs(s.sl - pg) <= 4, `scrollLeft ${s.sl}, a page is ${pg}`);
    t.check(`fallback ${label}: the dots follow`, s.dots[1] && s.dots.filter(Boolean).length === 1 && !s.prev.disabled, JSON.stringify(s.dots));
    await hero('[data-t-cv-dots] button').nth(3).click();
    s = await until(3 * pg);
    t.check(`fallback ${label}: a dot jumps to its item`, Math.abs(s.sl - 3 * pg) <= 4, `scrollLeft ${s.sl}`);
    t.check(`fallback ${label}: at the end next is disabled and the last dot current`, s.next.disabled && s.dots[3], JSON.stringify(s));
    await hero('[data-t-cv-prev]').click();
    s = await until(2 * pg);
    t.check(`fallback ${label}: previous goes back`, Math.abs(s.sl - 2 * pg) <= 4 && !s.next.disabled, `scrollLeft ${s.sl}`);
  }

  // What the page downloads: the page's own conditional loader asks for the
  // engine only where the browser draws no ::scroll-button (here the e2e page
  // has autoplay, so the page also has the full loader: use a page without it).
  {
    const only = `http://127.0.0.1:${server.address().port}/carousel-static.html`;
    const load = async (type, name, from = only, body = bundle) => {
      let browser;
      try {
        browser = await type.launch();
      } catch (e) {
        console.log(`skip ${name}: ${String(e.message).split('\n')[0]}`);
        return;
      }
      try {
        const page = await (await browser.newContext({ viewport: { width: 390, height: 800 } })).newPage();
        let asked = 0;
        await page.route(/\/engine[^/]*\.js(\?|$)/, (r) => {
          asked++;
          return r.fulfill({ contentType: 'text/javascript', body });
        });
        await page.goto(from);
        await page.waitForTimeout(800);
        const shown = await page.evaluate(() => document.querySelector('[data-t-cv-next]').offsetParent !== null);
        return { asked, shown, ran: await page.evaluate(() => window.__engineRuns ?? null) };
      } finally {
        await browser.close();
      }
    };
    if (native) {
      const chromiumPage = await t.page({ viewport: { width: 390, height: 800 } });
      let asked = 0;
      await chromiumPage.route(/\/engine[^/]*\.js(\?|$)/, (r) => {
        asked++;
        return r.fulfill({ contentType: 'text/javascript', body: bundle });
      });
      await chromiumPage.goto(only);
      await chromiumPage.waitForTimeout(800);
      t.check('static carousel in Chromium: the engine is never downloaded', asked === 0, `asked ${asked}`);
      t.check('static carousel in Chromium: native arrows only, no fallback buttons', await chromiumPage.evaluate(() => document.querySelector('[data-t-cv-next]').offsetParent === null));
      await chromiumPage.context().close();
    }
    for (const [name, type] of browsers) {
      const r = await load(type, name);
      if (!r) continue;
      t.check(`static carousel in ${name}: the engine loads once and the buttons show`, r.asked === 1 && r.shown, JSON.stringify(r));
    }
    // A late piece that needs the engine too brings its own loader: the
    // browser that had the conditional one still downloads the engine once.
    const late = `http://127.0.0.1:${server.address().port}/carousel-late.html`;
    for (const [name, type] of browsers) {
      // The engine here counts how many times it runs (the preload may be
      // fetched apart from the script in some browsers: runs are what matter).
      const r = await load(type, name, late, 'window.__engineRuns = (window.__engineRuns ?? 0) + 1;');
      if (!r) continue;
      t.check(`carousel + a late engine loader in ${name}: the engine runs once`, r.ran === 1, JSON.stringify(r));
    }
    // The engine the carousel's loader added fails (a stale hashed file after
    // a deploy): the page reloads once to get the new HTML, as the engine's
    // own loader does when it is the one that asked (no loop: one reload).
    for (const [name, type] of browsers) {
      let browser;
      try {
        browser = await type.launch();
      } catch {
        continue;
      }
      try {
        const page = await (await browser.newContext({ viewport: { width: 390, height: 800 } })).newPage();
        let docs = 0;
        page.on('request', (req) => {
          if (req.isNavigationRequest() && req.url().endsWith('/carousel-late.html')) docs++;
        });
        await page.route(/\/engine[^/]*\.js(\?|$)/, (r) => r.abort());
        await page.goto(late);
        await page.waitForTimeout(2500);
        t.check(`carousel + a late loader in ${name}: a failing engine reloads the page once`, docs === 2, `document requests ${docs}`);
      } finally {
        await browser.close();
      }
    }
  }

  // Native arrows in a right-to-left page: the button on the left goes
  // forward, so it is the one called Next.
  if (native) {
    const page = await open({ javaScriptEnabled: false, viewport: { width: 390, height: 800 } });
    await page.evaluate(() => (document.documentElement.dir = 'rtl'));
    const c = await page.evaluate(() => {
      const el = document.querySelector('[aria-label=Hero]');
      const t = (s) => getComputedStyle(el, s).content;
      return { left: t('::scroll-button(left)'), right: t('::scroll-button(right)') };
    });
    t.check('native rtl: the left arrow is Next and the right one Previous', c.left.includes('Next') && c.right.includes('Previous'), JSON.stringify(c));
    const ltr = await page.evaluate(() => {
      document.documentElement.dir = 'ltr';
      const el = document.querySelector('[aria-label=Hero]');
      return getComputedStyle(el, '::scroll-button(left)').content;
    });
    t.check('native ltr: the left arrow is Previous', ltr.includes('Previous'), ltr);
    await page.context().close();
  }

  // Edge cases of the fallback controls, in Chromium made to look like a
  // browser without ::scroll-button, Firefox and WebKit. `edge` is the page
  // carousel-edge.html; `setup(page)` runs before the engine is added.
  {
    const edge = `http://127.0.0.1:${server.address().port}/carousel-edge.html`;
    const engines = [...(native ? [['chromium (native off)', null]] : []), ...browsers];
    const run = async (name, type, options, body, { url = edge, setup, wire = true } = {}) => {
      let browser, ctx;
      try {
        if (type) browser = await type.launch();
      } catch (e) {
        console.log(`skip ${name}: ${String(e.message).split('\n')[0]}`);
        return;
      }
      try {
        let page;
        if (type) {
          ctx = await browser.newContext({ viewport: { width: 390, height: 800 }, ...options });
          page = await ctx.newPage();
          page.problems = [];
          page.on('pageerror', (e) => page.problems.push(e.message));
        } else {
          page = await t.page({ viewport: { width: 390, height: 800 }, ...options });
          await page.addInitScript(() => {
            const supports = CSS.supports.bind(CSS);
            CSS.supports = (a, b) => (typeof a === 'string' && a.includes('::scroll-button') ? false : supports(a, b));
          });
        }
        await page.route(/\/engine[^/]*\.js(\?|$)/, (r) => r.fulfill({ contentType: 'text/javascript', body: '' }));
        await page.goto(url);
        if (!type) await page.addStyleTag({ content: '*::scroll-button(*), *::scroll-marker-group { display: none !important; }' });
        if (setup) await setup(page);
        if (wire) await page.addScriptTag({ content: bundle });
        try {
          await body(page, name);
        } catch (e) {
          t.check(`${name}: scenario ran`, false, String(e.message).split('\n')[0]);
        }
        t.check(`${name}: no page errors`, page.problems.length === 0, page.problems.join('; '));
      } finally {
        if (type) await browser.close();
        else await ctx?.close?.();
      }
    };
    // The state of the carousel `n`: scroll position, controls, current dot.
    const state = (page, n) =>
      page.evaluate((n) => {
        const sc = document.querySelector(`[aria-label="${n}"]`);
        const w = sc.parentElement;
        const q = (s) => w.querySelector(s);
        const shown = (e) => !!e && e.offsetParent !== null;
        const dots = [...w.querySelectorAll('[data-t-cv-dots] button')];
        const off = (b) => !!b && (b.disabled || b.getAttribute('aria-disabled') === 'true');
        return {
          sl: sc.scrollLeft,
          client: sc.clientWidth,
          prevShown: shown(q('[data-t-cv-prev]')),
          nextShown: shown(q('[data-t-cv-next]')),
          dotsShown: shown(q('[data-t-cv-dots]')),
          prevOff: off(q('[data-t-cv-prev]')),
          nextOff: off(q('[data-t-cv-next]')),
          cur: dots.findIndex((d) => d.getAttribute('aria-current') === 'true'),
          nDots: dots.length,
        };
      }, n);
    const reach = async (page, n, x) => {
      await page.waitForFunction(([n, x]) => Math.abs(document.querySelector(`[aria-label="${n}"]`).scrollLeft - x) <= 4, [n, x], { timeout: 4000 }).catch(() => {});
      await page.waitForTimeout(250);
      return state(page, n);
    };
    const live = `http://127.0.0.1:${server.address().port}/carousel-live.html`;
    // What the engine does for a list: rows (a copy of the template's) before the template.
    const setRows = (page, n) =>
      page.evaluate((n) => {
        const sc = document.querySelector('[aria-label=Live]');
        const tpl = sc.querySelector(':scope > template');
        for (const r of sc.querySelectorAll(':scope > [data-tk]')) r.remove();
        for (let i = 0; i < n; i++) {
          const r = tpl.content.firstElementChild.cloneNode(true);
          r.setAttribute('data-tk', String(i));
          r.textContent = `live ${i}`;
          sc.insertBefore(r, tpl);
        }
      }, n);
    const ctl = (page, n, q) => page.locator(`[aria-label="${n}"]`).locator('xpath=..').locator(q);
    const click = (loc) => loc.click({ timeout: 3000 });

    for (const [name, type] of engines) {
      // RTL: previous is the button at the start (the right) and goes back.
      await run(name, type, {}, async (page, name) => {
        let s = await state(page, 'A');
        const pg = s.client + 16;
        t.check(`${name} rtl: at the start previous is off and next on`, s.prevOff && !s.nextOff && s.cur === 0, JSON.stringify(s));
        const pos = await page.evaluate(() => {
          const w = document.querySelector('[aria-label=A]').parentElement;
          const prev = w.querySelector('[data-t-cv-prev]').getBoundingClientRect();
          const next = w.querySelector('[data-t-cv-next]').getBoundingClientRect();
          return { prev: prev.left, next: next.left };
        });
        t.check(`${name} rtl: previous sits at the start (right), next at the end (left)`, pos.prev > pos.next, JSON.stringify(pos));
        await click(ctl(page, 'A', '[data-t-cv-next]'));
        s = await reach(page, 'A', -pg);
        t.check(`${name} rtl: next moves forward by a page`, Math.abs(s.sl + pg) <= 4 && s.cur === 1 && !s.prevOff, JSON.stringify(s));
        await click(ctl(page, 'A', '[data-t-cv-prev]'));
        s = await reach(page, 'A', 0);
        t.check(`${name} rtl: previous goes back`, Math.abs(s.sl) <= 4 && s.cur === 0 && s.prevOff, JSON.stringify(s));
        await click(ctl(page, 'A', '[data-t-cv-dots] button').nth(3));
        s = await reach(page, 'A', -3 * pg);
        t.check(`${name} rtl: a dot jumps to its item`, Math.abs(s.sl + 3 * pg) <= 4 && s.cur === 3 && s.nextOff, JSON.stringify(s));
      }, { setup: (page) => page.evaluate(() => (document.documentElement.dir = 'rtl')) });

      // Late nodes (rows of a list, a streamed piece): wired where they land.
      await run(name, type, {}, async (page, name) => {
        await page.evaluate(() => {
          const host = document.createElement('div');
          host.id = 'late';
          document.body.append(host);
          host.innerHTML = window.__clone;
          host.querySelector('[aria-label=A]').setAttribute('aria-label', 'Late');
        });
        await page.waitForTimeout(300);
        let s = await state(page, 'Late');
        t.check(`${name} late: a carousel inserted after the engine is wired`, s.nextShown && s.dotsShown && s.prevOff && s.cur === 0, JSON.stringify(s));
        await click(ctl(page, 'Late', '[data-t-cv-next]'));
        s = await reach(page, 'Late', s.client + 16);
        t.check(`${name} late: its next works`, s.cur === 1, JSON.stringify(s));
        const other = await state(page, 'A');
        t.check(`${name} late: the one that was there is untouched`, other.sl === 0 && other.cur === 0, JSON.stringify(other));
        // Two with the same markup (a list's rows): each moves alone.
        await click(ctl(page, 'A', '[data-t-cv-next]'));
        const a = await reach(page, 'A', other.client + 16);
        const l = await state(page, 'Late');
        t.check(`${name} two carousels: one moves, the other stays`, a.cur === 1 && l.cur === 1 && Math.abs(l.sl - (l.client + 16)) <= 4, JSON.stringify([a, l]));
      }, {
        setup: (page) => page.evaluate(() => (window.__clone = document.querySelector('[aria-label=A]').parentElement.outerHTML)),
      });

      // Hidden at load (a dialog, a drawer): measured when it is shown.
      await run(name, type, {}, async (page, name) => {
        let s = await state(page, 'A');
        t.check(`${name} hidden: nothing is shown while it is hidden`, !s.nextShown, JSON.stringify(s));
        await page.evaluate(() => (document.querySelector('[aria-label=A]').parentElement.style.display = ''));
        await page.waitForTimeout(300);
        s = await state(page, 'A');
        t.check(`${name} hidden: shown, previous off, first dot current`, s.nextShown && s.prevOff && !s.nextOff && s.cur === 0, JSON.stringify(s));
        await click(ctl(page, 'A', '[data-t-cv-next]'));
        s = await reach(page, 'A', s.client + 16);
        t.check(`${name} hidden: next moves by a page of the real width`, s.cur === 1 && s.client > 300, JSON.stringify(s));
      }, { setup: (page) => page.evaluate(() => (document.querySelector('[aria-label=A]').parentElement.style.display = 'none')) });

      // Resize and zoom: the page and the current dot are recomputed.
      await run(name, type, {}, async (page, name) => {
        await click(ctl(page, 'A', '[data-t-cv-next]'));
        let s = await reach(page, 'A', 390 - 16 + 16);
        await page.setViewportSize({ width: 600, height: 800 });
        await page.waitForTimeout(400);
        s = await state(page, 'A');
        t.check(`${name} resize: the carousel keeps a current dot and a consistent state`, s.cur >= 0 && s.cur < 4 && s.client > 500, JSON.stringify(s));
        const before = s.sl;
        await click(ctl(page, 'A', '[data-t-cv-next]'));
        s = await reach(page, 'A', before + s.client + 16);
        t.check(`${name} resize: next moves by the new page`, Math.abs(s.sl - before - (s.client + 16)) <= 4 || s.nextOff, JSON.stringify(s));
        await page.setViewportSize({ width: 320, height: 800 });
        await page.waitForTimeout(400);
        const n = await state(page, 'A');
        const total = await page.evaluate(() => document.documentElement.scrollWidth);
        t.check(`${name} resize: 320 px, still four dots and no sideways page`, n.nDots === 4 && total <= 320, JSON.stringify([n, total]));
      });

      // Items wider than the viewport: one item per page.
      await run(name, type, {}, async (page, name) => {
        let s = await state(page, 'Wide');
        t.check(`${name} wide: three dots, previous off`, s.nDots === 3 && s.prevOff && !s.nextOff && s.client === 374, JSON.stringify(s));
        await click(ctl(page, 'Wide', '[data-t-cv-next]'));
        s = await reach(page, 'Wide', 616);
        t.check(`${name} wide: next moves exactly one item`, Math.abs(s.sl - 616) <= 4 && s.cur === 1, JSON.stringify(s));
        await click(ctl(page, 'Wide', '[data-t-cv-next]'));
        s = await reach(page, 'Wide', 1232);
        t.check(`${name} wide: the last item is reached, last dot current`, Math.abs(s.sl - 1232) <= 4 && s.cur === 2, JSON.stringify(s));
        await click(ctl(page, 'Wide', '[data-t-cv-next]'));
        s = await reach(page, 'Wide', 1458);
        t.check(`${name} wide: the end shows the last item whole, next off`, s.nextOff, JSON.stringify(s));
      });

      // One item: nothing to move, nothing drawn.
      await run(name, type, {}, async (page, name) => {
        const one = await page.evaluate(() => {
          const w = document.querySelector('[aria-label=One]').parentElement;
          return { wrapper: w.hasAttribute('data-t-cv'), btn: w.querySelectorAll(':scope > button').length };
        });
        t.check(`${name} one item: no wrapper, no buttons`, !one.wrapper && one.btn === 0, JSON.stringify(one));
      });

      // A live list (rows the browser adds after load; the server drew only
      // the row template): the controls appear with two rows or more, dots are
      // cloned per row, and fewer than two rows draw nothing.
      await run(name, type, {}, async (page, name) => {
        const live = async (n) => {
          await setRows(page, n);
          await page.waitForTimeout(350);
          return page.evaluate(() => {
            const sc = document.querySelector('[aria-label=Live]');
            const w = sc.parentElement;
            const shown = (q) => w.querySelector(q).offsetParent !== null;
            const dots = [...w.querySelectorAll('[data-t-cv-dots] > button')];
            const cur = dots.findIndex((d) => d.getAttribute('aria-current') === 'true');
            const r = dots[cur]?.getBoundingClientRect();
            const o = dots[cur === 0 ? 1 : 0]?.getBoundingClientRect();
            return {
              prev: shown('[data-t-cv-prev]'), next: shown('[data-t-cv-next]'), dotsShown: shown('[data-t-cv-dots]'),
              labels: dots.map((d) => d.getAttribute('aria-label')), cur, active: r && r.width, plain: o && o.width,
              glyph: getComputedStyle(w.querySelector('[data-t-cv-next]')).backgroundSize,
              sl: sc.scrollLeft, client: sc.clientWidth, nextOff: w.querySelector('[data-t-cv-next]').getAttribute('aria-disabled') === 'true',
            };
          });
        };
        let s = await live(0);
        t.check(`${name} live: 0 rows, no controls`, !s.prev && !s.next && !s.dotsShown && s.labels.length === 0, JSON.stringify(s));
        s = await live(1);
        t.check(`${name} live: 1 row, no controls`, !s.prev && !s.next && !s.dotsShown, JSON.stringify(s));
        s = await live(3);
        t.check(`${name} live: 3 rows, arrows and three dots appear`, s.prev && s.next && s.dotsShown && JSON.stringify(s.labels) === JSON.stringify(['Slide 1 of 3', 'Slide 2 of 3', 'Slide 3 of 3']) && s.cur === 0, JSON.stringify(s));
        t.check(`${name} live: the active dot is a 48 px pill, the others 12`, Math.round(s.active) === 48 && Math.round(s.plain) === 12, JSON.stringify([s.active, s.plain]));
        t.check(`${name} live: the arrow glyph is 28 px`, s.glyph.startsWith('28px'), s.glyph);
        const pg = s.client + 16;
        await click(ctl(page, 'Live', '[data-t-cv-next]'));
        s = await reach(page, 'Live', pg);
        t.check(`${name} live: next moves a page and the dot follows`, Math.abs(s.sl - pg) <= 4, JSON.stringify(s));
        s = await live(3);
        await click(ctl(page, 'Live', '[data-t-cv-dots] > button').nth(2));
        s = await reach(page, 'Live', 2 * pg);
        t.check(`${name} live: a cloned dot jumps to its row`, Math.abs(s.sl - 2 * pg) <= 4 && s.cur === 2 && s.nextOff, JSON.stringify(s));
        s = await live(5);
        t.check(`${name} live: more rows, more dots`, s.labels.length === 5 && s.labels[4] === 'Slide 5 of 5' && s.labels[0] === 'Slide 1 of 5', JSON.stringify(s.labels));
        s = await live(1);
        t.check(`${name} live: back to 1 row, the controls are gone`, !s.prev && !s.next && !s.dotsShown, JSON.stringify(s));
      }, { url: live, wire: true });

      // Keyboard: the arrows are reachable and a disabled end keeps the focus.
      await run(name, type, {}, async (page, name) => {
        await page.focus('[aria-label=A]');
        const order = [];
        for (let i = 0; i < 7; i++) {
          await page.keyboard.press(tabKey(name));
          order.push(await page.evaluate(() => {
            const e = document.activeElement;
            return e.getAttribute('aria-label') || e.tagName;
          }));
        }
        // Safari's Tab skips buttons unless the user asks otherwise: tabKey() is Option+Tab there.
        t.check(`${name} keys: Tab reaches the arrows (an end stays focusable), then the dots, with accessible names`, order[0] === 'Previous' && order[1] === 'Next' && order[2] === 'Slide 1 of 4' && order[5] === 'Slide 4 of 4' && order[6] === 'B', JSON.stringify(order));
        const names = await page.evaluate(() => [...document.querySelectorAll('[aria-label=A]')[0].parentElement.querySelectorAll('button')].map((b) => b.getAttribute('aria-label')));
        t.check(`${name} keys: the buttons are named Previous, Next and Slide n of m`, JSON.stringify(names) === JSON.stringify(['Previous', 'Next', 'Slide 1 of 4', 'Slide 2 of 4', 'Slide 3 of 4', 'Slide 4 of 4']), JSON.stringify(names));
        // Press Next to the end: the focus must stay on a control of this carousel.
        await ctl(page, 'A', '[data-t-cv-next]').focus();
        for (let i = 0; i < 5; i++) {
          await page.keyboard.press('Enter');
          await page.waitForTimeout(450);
        }
        const kept = await page.evaluate(() => {
          const e = document.activeElement;
          return { tag: e.tagName, label: e.getAttribute('aria-label') };
        });
        t.check(`${name} keys: reaching the end does not drop the focus to the page`, kept.tag !== 'BODY' && kept.label === 'Next', JSON.stringify(kept));
        const end = await state(page, 'A');
        t.check(`${name} keys: at the end next is off and the last dot current`, end.nextOff && end.cur === 3, JSON.stringify(end));
      });

      // Reduced motion: no smooth scrolling.
      await run(name, type, { reducedMotion: 'reduce' }, async (page, name) => {
        const pg = (await state(page, 'A')).client + 16;
        await click(ctl(page, 'A', '[data-t-cv-next]'));
        await page.waitForTimeout(60);
        const s = await state(page, 'A');
        t.check(`${name} reduced motion: next jumps at once`, Math.abs(s.sl - pg) <= 4, JSON.stringify([s, pg]));
      });

      // Print: no controls on paper.
      await run(name, type, {}, async (page, name) => {
        await page.emulateMedia({ media: 'print' });
        await page.waitForTimeout(100);
        const s = await state(page, 'A');
        t.check(`${name} print: the fallback controls are not printed`, !s.prevShown && !s.nextShown && !s.dotsShown, JSON.stringify(s));
      });

      // Autoplay with the fallback controls: the controls pause it.
      await run(name, type, {}, async (page, name) => {
        await page.evaluate(() => document.querySelector('[aria-label=Both]').scrollIntoView());
        await page.waitForTimeout(1300);
        const moved = (await state(page, 'Both')).sl;
        t.check(`${name} autoplay+controls: advances by itself`, Math.abs(moved) > 100, `scrollLeft ${moved}`);
        await ctl(page, 'Both', '[data-t-cv-dots] button').nth(0).focus();
        await page.waitForTimeout(900);
        const a = (await state(page, 'Both')).sl;
        await page.waitForTimeout(1500);
        const b = (await state(page, 'Both')).sl;
        t.check(`${name} autoplay+controls: stays while a dot has the focus`, Math.abs(a - b) <= 1, `${a} -> ${b}`);
        await page.evaluate(() => document.activeElement.blur());
        await ctl(page, 'Both', '[data-t-cv-next]').hover();
        await page.waitForTimeout(900);
        const c = (await state(page, 'Both')).sl;
        await page.waitForTimeout(1500);
        const d = (await state(page, 'Both')).sl;
        t.check(`${name} autoplay+controls: stays while the pointer is on an arrow`, Math.abs(c - d) <= 1, `${c} -> ${d}`);
      });
    }
  }

  // A live list in Chromium's native controls (no JS: the CSS alone decides):
  // fewer than two rows draw nothing, then the arrows and one marker per row.
  if (native) {
    const page = await t.page({ javaScriptEnabled: false, viewport: { width: 390, height: 800 } });
    await page.goto(`http://127.0.0.1:${server.address().port}/carousel-live.html`);
    const rows = (n) =>
      page.evaluate((n) => {
        const sc = document.querySelector('[aria-label=Live]');
        const tpl = sc.querySelector(':scope > template');
        for (const r of sc.querySelectorAll(':scope > [data-tk]')) r.remove();
        for (let i = 0; i < n; i++) {
          const r = tpl.content.firstElementChild.cloneNode(true);
          r.setAttribute('data-tk', String(i));
          r.textContent = `live ${i}`;
          sc.insertBefore(r, tpl);
        }
        const c = (p) => getComputedStyle(sc, p);
        const kids = [...sc.querySelectorAll(':scope > [data-tk]')];
        return {
          prev: c('::scroll-button(left)').display, next: c('::scroll-button(right)').display, group: c('::scroll-marker-group').display,
          glyph: c('::scroll-button(right)').backgroundSize,
          markers: kids.map((k) => parseFloat(getComputedStyle(k, '::scroll-marker').width)),
          groupWidth: parseFloat(c('::scroll-marker-group').width),
        };
      }, n);
    for (const n of [0, 1]) {
      const s = await rows(n);
      t.check(`native live: ${n} rows, no arrows and no dots`, s.prev === 'none' && s.next === 'none' && s.group === 'none', JSON.stringify(s));
    }
    let s = await rows(3);
    // The markers settle on the next frame: :target-current is not in the first one.
    await page.waitForTimeout(400);
    s.groupWidth = await page.evaluate(() => parseFloat(getComputedStyle(document.querySelector('[aria-label=Live]'), '::scroll-marker-group').width));
    t.check('native live: 3 rows, arrows and dots are drawn', s.prev !== 'none' && s.next !== 'none' && s.group !== 'none' && s.markers.length === 3, JSON.stringify(s));
    // getComputedStyle can't see :target-current: the group's width is 48 + 12 + 12 + two 8 px gaps.
    t.check('native live: the active marker is a 48 px pill, the others 12', Math.abs(s.groupWidth - 88) <= 1, JSON.stringify(s));
    t.check('native live: the arrow glyph is 28 px', s.glyph.startsWith('28px'), s.glyph);
    const geo = await page.evaluate(() => {
      const sc = document.querySelector('[aria-label=Live]');
      return { client: sc.clientWidth };
    });
    const pe = await page.evaluate(() => {
      const c = getComputedStyle(document.querySelector('[aria-label=Live]'), '::scroll-button(right)');
      return { left: parseFloat(c.left), top: parseFloat(c.top), width: parseFloat(c.width) };
    });
    await page.mouse.click(pe.left + pe.width / 2, pe.top);
    await page.waitForFunction((x) => Math.abs(document.querySelector('[aria-label=Live]').scrollLeft - x) <= 4, geo.client + 16, { timeout: 4000 }).catch(() => {});
    const sl = await page.evaluate(() => document.querySelector('[aria-label=Live]').scrollLeft);
    t.check('native live: the arrow moves a page', Math.abs(sl - (geo.client + 16)) <= 4, `scrollLeft ${sl}`);
    s = await rows(1);
    t.check('native live: back to 1 row, the controls are gone', s.prev === 'none' && s.group === 'none', JSON.stringify(s));
    t.check('native live: no page errors', page.problems.length === 0, page.problems.join('; '));
    await page.context().close();
  }

  // Autoplay (lite part): advances, pauses, respects reduced motion.
  {
    const page = await open({ viewport: { width: 390, height: 800 } }, { engine: true });
    await page.evaluate(() => document.querySelector('[aria-label=Auto]').scrollIntoView());
    await page.waitForTimeout(1500);
    const moved = (await info(page, 'Auto')).scrollLeft;
    t.check('autoplay: advances by itself', moved > 100, `scrollLeft ${moved}`);
    // Hover pauses it.
    const box = await page.locator('[aria-label=Auto]').boundingBox();
    await page.mouse.move(box.x + 50, box.y + 50);
    // A smooth scroll that started just before the pointer arrived finishes
    // first (Firefox's takes longer): wait for the carousel to rest.
    await resting(page, 'Auto');
    const a = (await info(page, 'Auto')).scrollLeft;
    await page.waitForTimeout(1500);
    const b = (await info(page, 'Auto')).scrollLeft;
    t.check('autoplay: stays while the pointer is over it', near(a, b, 1), `${a} -> ${b}`);
    await page.mouse.move(2, 2);
    // It goes on: sampled along the way, not at one instant (it loops, and a
    // lap can end where it started).
    let far = 0;
    for (let i = 0; i < 40 && far <= 50; i++) {
      await page.waitForTimeout(100);
      far = Math.max(far, Math.abs((await info(page, 'Auto')).scrollLeft - b));
    }
    t.check('autoplay: goes on when the pointer leaves', far > 50, `${b} -> moved ${far}`);
    // Focus inside pauses it.
    await page.focus('[aria-label=Auto]');
    // A scroll that started just before the focus finishes first.
    await page.waitForTimeout(800);
    const f1 = (await info(page, 'Auto')).scrollLeft;
    await page.waitForTimeout(1500);
    const f2 = (await info(page, 'Auto')).scrollLeft;
    t.check('autoplay: stays while the focus is in it', near(f1, f2, 1), `${f1} -> ${f2}`);
    t.check('autoplay: no page errors', page.problems.length === 0, page.problems.join('; '));
    await page.context().close();
  }
  {
    const page = await open({ viewport: { width: 390, height: 800 }, reducedMotion: 'reduce' }, { engine: true });
    await page.evaluate(() => document.querySelector('[aria-label=Auto]').scrollIntoView());
    await page.waitForTimeout(1500);
    t.check('autoplay: never moves with prefers-reduced-motion', (await info(page, 'Auto')).scrollLeft === 0);
    await page.context().close();
  }
  {
    const page = await open({ javaScriptEnabled: false, viewport: { width: 390, height: 800 } });
    await page.evaluate(() => document.querySelector('[aria-label=Auto]').scrollIntoView());
    await page.waitForTimeout(1500);
    t.check('autoplay: static without JS (and still scrollable by hand)', (await info(page, 'Auto')).scrollLeft === 0);
    await page.context().close();
  }
}

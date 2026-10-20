// Page transitions (PageTransition, Hero; docs/guia/es/animaciones.md): a
// navigation between two pages of an app runs a cross-document view
// transition, a Hero's element travels as its own group, and without
// support (reduced motion, JavaScript off, a browser without it) the page
// just navigates.
//
//   tool/thor e2e transitions                (builds test/fixtures/apps/realworld, runs)
//   node test/e2e/checks/view_transitions_check.mjs
//
// 1. test/fixtures/apps/realworld (build/server, test/e2e/mock_api): list → article
//    transitions (`PageTransition.fadeUp` on the article route) and the
//    title's group is `t-hero-article-<slug>`; back to the list
//    transitions too (the app's fade); `prefers-reduced-motion: reduce`
//    and JavaScript off navigate without one.
// 2. apps/docs (static export): guide → guide transitions; the frame (top
//    bar, sidebar) is its own groups, the page fades on the site's timing
//    and the app's `PageTransition.fade` 150 ms reach the groups.
// 3. Slide (own pages, packages/thor_ui/tool/slide_pages.dart): forward
//    slides in (`t-vt-slide-in`); back (history traversal to an earlier
//    entry) is tagged with the view-transition type `back` and reverses
//    (`t-vt-slide-in-back`); forward again is not back; reduced motion and
//    the first load have none.
// 4. WebKit (when Playwright has it): the same navigation works, with a
//    transition where WebKit supports them.
import { execFileSync, spawn, spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { createServer } from 'node:net';
import { join } from 'node:path';
import { closeServer, e2e, repo, serveStatic } from './lib/e2e.mjs';
import { webkit } from '../runner/node_modules/playwright/index.mjs';

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

// Runs in every page before its scripts: records, per navigation, whether
// the page was revealed with a view transition and which groups animated.
function probe() {
  addEventListener('pagereveal', (e) => {
    const vt = e.viewTransition;
    const read = () => JSON.parse(sessionStorage.getItem('t-vt') || '[]');
    const log = read();
    log.push({ path: location.pathname, vt: !!vt, groups: [] });
    sessionStorage.setItem('t-vt', JSON.stringify(log));
    vt?.ready
      .then(() => {
        const groups = [
          ...new Set(
            document
              .getAnimations()
              .map((a) => a.effect?.pseudoElement)
              .filter(Boolean),
          ),
        ];
        const durations = {};
        const names = {};
        for (const a of document.getAnimations()) {
          const pseudo = a.effect?.pseudoElement;
          if (pseudo) durations[pseudo] = a.effect.getComputedTiming().duration;
          if (pseudo) names[pseudo] = a.animationName;
        }
        const now = read();
        now[now.length - 1].types = [...vt.types];
        now[now.length - 1].names = names;
        now[now.length - 1].groups = groups;
        now[now.length - 1].durations = durations;
        sessionStorage.setItem('t-vt', JSON.stringify(now));
      })
      .catch(() => {});
  });
}

/** The last reveal the probe recorded (after the transition had time). */
async function lastReveal(page) {
  await pause(700);
  const log = await page.evaluate(() => JSON.parse(sessionStorage.getItem('t-vt') || '[]'));
  return log.at(-1) ?? {};
}

async function follow(page, base, link) {
  const href = await link.getAttribute('href');
  await link.click();
  await page.waitForURL(`${base}${href}`, { waitUntil: 'load' });
  return href;
}

// The docs site (a static export): built here when missing.
const docsSite = join(repo, 'apps/docs/build/site');
if (!existsSync(join(docsSite, 'index.html'))) {
  const r = spawnSync('dart', ['run', 'thor_cli:thor', 'export', 'apps/docs'], { cwd: repo, stdio: 'ignore' });
  if (r.status !== 0) {
    console.log('FAIL transitions: apps/docs did not export');
    process.exit(1);
  }
}

await e2e('transitions', { site: docsSite, timeout: 240_000 }, async (t) => {
  // --- test/fixtures/apps/realworld --------------------------------------------------------
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
        SESSION_SECRET: 'transitions-check-secret-of-at-least-32-bytes',
      },
      stdio: 'ignore',
    }),
  );
  const app = `http://127.0.0.1:${appPort}`;
  await waitFor(`${app}/`);

  {
    const page = await t.page();
    await page.addInitScript(probe);
    await page.goto(`${app}/`);
    const first = await lastReveal(page);
    t.check('realworld: a first load has no transition', first.vt === false, JSON.stringify(first));
    const href = await follow(page, app, page.locator('a[href^="/article/"]').first());
    const slug = href.split('/').at(-1);
    const reveal = await lastReveal(page);
    t.check('realworld: list → article runs a view transition', reveal.vt === true, JSON.stringify(reveal));
    t.check(
      "realworld: the article's title travels as its own group (Hero)",
      reveal.groups?.includes(`::view-transition-group(t-hero-article-${slug})`),
      JSON.stringify(reveal.groups),
    );
    t.check(
      'realworld: the article rises in (fadeUp on its route)',
      reveal.groups?.includes('::view-transition-new(root)'),
      JSON.stringify(reveal.groups),
    );
    t.check(
      "realworld: the route's timing reaches the page's snapshot (300 ms)",
      reveal.durations?.['::view-transition-new(root)'] === 300,
      JSON.stringify(reveal.durations),
    );
    await page.goBack({ waitUntil: 'load' });
    const back = await lastReveal(page);
    // Back may come from the back/forward cache: a revealed page either way.
    t.check('realworld: back to the list shows the list', new URL(page.url()).pathname === '/', page.url());
    t.check('realworld: back is revealed with a transition too', back.vt === true, JSON.stringify(back));
    t.check('realworld: no console errors', page.problems.length === 0, page.problems.join('; '));
    await page.context().close();
  }

  {
    const page = await t.page({ reducedMotion: 'reduce' });
    await page.addInitScript(probe);
    await page.goto(`${app}/`);
    await follow(page, app, page.locator('a[href^="/article/"]').first());
    const reveal = await lastReveal(page);
    t.check('realworld: reduced motion navigates without a transition', reveal.vt === false, JSON.stringify(reveal));
    await page.context().close();
  }

  {
    const page = await t.page({ javaScriptEnabled: false });
    await page.goto(`${app}/`);
    await follow(page, app, page.locator('a[href^="/article/"]').first());
    t.check('realworld: no JS still navigates to the article', (await page.locator('h1').count()) > 0);
    await page.context().close();
  }

  // --- apps/docs (static) ------------------------------------------------------
  {
    const page = await t.page();
    await page.addInitScript(probe);
    await page.goto(`${t.url}es/empezar/instalacion`);
    await follow(page, t.url.replace(/\/$/, ''), page.locator('a[href="/es/empezar/primera-app"]').first());
    const reveal = await lastReveal(page);
    t.check('docs: guide → guide runs a view transition', reveal.vt === true, JSON.stringify(reveal));
    // The frame stays put: the top bar and the sidebar are their own groups
    // (apps/docs/lib/core/theme/motion.dart), not part of the page's fade.
    t.check(
      'docs: the top bar and the sidebar travel as their own groups',
      ['docs-bar', 'docs-nav'].every((n) => reveal.groups?.includes(`::view-transition-group(${n})`)),
      JSON.stringify(reveal.groups),
    );
    // The page fades on the site's own motion: out in 90 ms, in over 120 ms.
    t.check(
      "docs: the page's own fade reaches its snapshots (90 ms out, 120 ms in)",
      reveal.names?.['::view-transition-old(root)'] === 'docs-leave' &&
        reveal.names?.['::view-transition-new(root)'] === 'docs-arrive' &&
        reveal.durations?.['::view-transition-old(root)'] === 90 &&
        reveal.durations?.['::view-transition-new(root)'] === 120,
      JSON.stringify({ names: reveal.names, durations: reveal.durations }),
    );
    t.check(
      "docs: the app's 150 ms reach the groups",
      ['root', 'docs-bar', 'docs-nav'].every((n) => reveal.durations?.[`::view-transition-group(${n})`] === 150),
      JSON.stringify(reveal.durations),
    );
    t.check('docs: no console errors', page.problems.length === 0, page.problems.join('; '));
    await page.context().close();
  }

  // --- slide: forward and back ------------------------------------------------
  const slideDir = mkdtempSync(join(tmpdir(), 'slide-pages-'));
  const slideServer = await (async () => {
    execFileSync('dart', ['run', 'tool/slide_pages.dart', slideDir], {
      cwd: join(repo, 'packages/thor_ui'),
      stdio: 'inherit',
    });
    // `POST /post` answers like an action: a 303 to /c.
    return serveStatic(slideDir, {
      handle(req, res) {
        if (req.method !== 'POST' || req.url !== '/post') return false;
        res.writeHead(303, { location: '/c' }).end();
        return true;
      },
    });
  })();
  try {
    const slide = `http://127.0.0.1:${slideServer.address().port}`;
    {
      const page = await t.page();
      await page.addInitScript(probe);
      await page.goto(`${slide}/a`);
      const first = await lastReveal(page);
      t.check('slide: a first load has no transition', first.vt === false, JSON.stringify(first));
      await follow(page, slide, page.locator('a[href="/b"]'));
      const fwd = await lastReveal(page);
      t.check('slide: forward slides in', fwd.names?.['::view-transition-new(root)'] === 't-vt-slide-in', JSON.stringify(fwd));
      t.check('slide: forward is not tagged back', !fwd.types?.includes('back'), JSON.stringify(fwd.types));
      await follow(page, slide, page.locator('a[href="/c"]'));
      await lastReveal(page);
      await page.goBack({ waitUntil: 'load' });
      const back = await lastReveal(page);
      t.check('slide: back is a view transition', back.vt === true, JSON.stringify(back));
      t.check('slide: back is tagged with the type back', back.types?.includes('back'), JSON.stringify(back.types));
      t.check(
        'slide: back reverses (new enters from the start, old leaves to the end)',
        back.names?.['::view-transition-new(root)'] === 't-vt-slide-in-back' &&
          back.names?.['::view-transition-old(root)'] === 't-vt-slide-out-back',
        JSON.stringify(back.names),
      );
      await page.goForward({ waitUntil: 'load' });
      const again = await lastReveal(page);
      t.check('slide: forward through history is not back', again.vt === true && !again.types?.includes('back') && again.names?.['::view-transition-new(root)'] === 't-vt-slide-in', JSON.stringify(again));
      t.check('slide: no console errors', page.problems.length === 0, page.problems.join('; '));
      await page.context().close();
    }
    // History traversals of every shape: the type is on the transition, never
    // left behind for the next navigation.
    {
      const page = await t.page();
      await page.addInitScript(probe);
      await page.goto(`${slide}/a`);
      await follow(page, slide, page.locator('a[href="/b"]'));
      await follow(page, slide, page.locator('a[href="/c"]'));
      await lastReveal(page);
      await page.evaluate(() => history.go(-2));
      await page.waitForURL(`${slide}/a`, { waitUntil: 'load' });
      const two = await lastReveal(page);
      t.check('slide: history.go(-2) is back', two.types?.includes('back') && two.names?.['::view-transition-new(root)'] === 't-vt-slide-in-back', JSON.stringify(two));
      await follow(page, slide, page.locator('a[href="/b"]'));
      const next = await lastReveal(page);
      t.check('slide: a forward link after a back is forward again', !next.types?.includes('back') && next.names?.['::view-transition-new(root)'] === 't-vt-slide-in', JSON.stringify(next));
      t.check('slide: no stale back type on the document', (await page.evaluate(() => document.documentElement.matches(':active-view-transition-type(back)'))) === false, 'a type left on <html>');
      await page.evaluate(() => history.go(+0));
      await page.waitForLoadState('load');
      const reload = await lastReveal(page);
      t.check('slide: a reload is not back', !reload.types?.includes('back'), JSON.stringify(reload));
      await page.context().close();
    }
    {
      // A form posted to a page that redirects: the new entry is forward, the
      // way back is back.
      const page = await t.page();
      await page.addInitScript(probe);
      await page.goto(`${slide}/a`);
      await Promise.all([page.waitForURL(`${slide}/c`, { waitUntil: 'load' }), page.locator('button[type=submit]').click()]);
      const posted = await lastReveal(page);
      t.check('slide: after a post and its redirect, forward', !posted.types?.includes('back'), JSON.stringify(posted));
      await page.goBack({ waitUntil: 'load' });
      const back = await lastReveal(page);
      t.check('slide: back after a post and its redirect reverses', back.types?.includes('back'), JSON.stringify(back));
      t.check('slide: no console errors after a post', page.problems.length === 0, page.problems.join('; '));
      await page.context().close();
    }
    {
      // Only one side slides: the page being opened decides.
      const page = await t.page();
      await page.addInitScript(probe);
      await page.goto(`${slide}/a`);
      await follow(page, slide, page.locator('a[href="/plain"]'));
      const fwd = await lastReveal(page);
      t.check('slide: to a page that fades, it fades (no slide, no back)', !fwd.types?.includes('back') && !/slide/.test(JSON.stringify(fwd.names)), JSON.stringify(fwd));
      await page.goBack({ waitUntil: 'load' });
      const back = await lastReveal(page);
      t.check('slide: back to a sliding page from one that fades reverses', back.types?.includes('back') && back.names?.['::view-transition-new(root)'] === 't-vt-slide-in-back', JSON.stringify(back));
      await follow(page, slide, page.locator('a[href="/b"]'));
      await page.goBack({ waitUntil: 'load' });
      await follow(page, slide, page.locator('a[href="/plain"]'));
      await follow(page, slide, page.locator('a[href="/a"]'));
      const toA = await lastReveal(page);
      t.check('slide: a forward link from a page that fades to a sliding one is forward', !toA.types?.includes('back') && toA.names?.['::view-transition-new(root)'] === 't-vt-slide-in', JSON.stringify(toA));
      await page.context().close();
    }
    {
      const page = await t.page({ reducedMotion: 'reduce' });
      await page.addInitScript(probe);
      await page.goto(`${slide}/a`);
      await follow(page, slide, page.locator('a[href="/b"]'));
      await page.goBack({ waitUntil: 'load' });
      const back = await lastReveal(page);
      t.check('slide: reduced motion goes back without a transition', back.vt === false, JSON.stringify(back));
      await page.context().close();
    }
    {
      const page = await t.page({ javaScriptEnabled: false });
      await page.goto(`${slide}/a`);
      await follow(page, slide, page.locator('a[href="/b"]'));
      await page.goBack({ waitUntil: 'load' });
      t.check('slide: no JS still navigates back', (await page.locator('body').innerText()).includes('Page a'));
      await page.context().close();
    }
  } finally {
    await closeServer(slideServer);
    rmSync(slideDir, { recursive: true, force: true });
  }

  // --- WebKit --------------------------------------------------------------------
  let browser;
  try {
    browser = await webkit.launch();
  } catch {
    console.log('  (WebKit is not installed: skipped)');
  }
  if (browser) {
    try {
      const page = await browser.newPage();
      await page.addInitScript(probe);
      await page.goto(`${app}/`);
      await follow(page, app, page.locator('a[href^="/article/"]').first());
      t.check('webkit: list → article navigates', (await page.locator('h1').count()) > 0);
      const reveal = await lastReveal(page);
      console.log(`  webkit: view transition ${reveal.vt ? 'ran' : 'not supported here: plain navigation'}`);
    } finally {
      await browser.close();
    }
  }
});

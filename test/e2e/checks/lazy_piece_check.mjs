// `LazyPiece` in a real browser: parts of the page the server draws
// only when the browser asks (GET the page with `?thor-piece=id`), on
// test/fixtures/apps/server_query's public `/piece` (build/server, the lite engine).
//
//   tool/thor e2e lazy-piece               (builds test/fixtures/apps/server_query, runs)
//   node test/e2e/checks/lazy_piece_check.mjs
//
// - the page carries the placeholders and the fallback links, not the content,
//   and asks for nothing before something opens
// - opening an accordion tile asks for its piece once (closing and opening it
//   again does not ask again), and the content is in place of the fallback
// - a ThorState button and Watch inside the piece are bound by the engine
// - a piece whose request failed keeps its fallback and tries again the next
//   time it opens
// - a dialog's piece loads when the dialog opens; a piece far down the page
//   loads when it comes near the viewport (not before)
// - no JavaScript: the fallback links are the content; following one works
// - a strict CSP: the one hashed script loads the pieces; the hash is the one
//   docs/guia/es/sesion-y-seguridad.md lists
// - the fragment itself: a piece alone (no document), noindex, a 404 for a
//   piece that does not exist
// - (test/fixtures/apps/lazy_pieces) a piece inside a piece: the inner one loads when its own tile opens,
//   once, and its state is bound; the URL names both (outer:inner); a bare inner id is a 404
// - (test/fixtures/apps/lazy_pieces) a FutureBuilder's late result is bound too (a button and a Watch in it)
// - (test/fixtures/apps/lazy_pieces) pieces that load together on a page with no engine: one request each, one
//   engine script, all bound, a list in one of them, the rule of the class only the piece has
// - (test/fixtures/apps/lazy_pieces) an opening tapped many times asks once; a dialog closed and opened again does
//   not insert twice; back and forward leave a page that still works
// - (test/fixtures/apps/lazy_pieces) Save-Data: a piece that is `idle` waits until it comes near
//
// `LAZY_APP=lazy_pieces` drives test/fixtures/apps/lazy_pieces instead (built with either engine: lite or
// dart2js, `tool/thor e2e lazy-pieces lazy-pieces-dart`).
import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { appDir } from '../../../tool/app_dir.mjs';
import { e2e, hydrated, repo, settle, trackHydration } from './lib/e2e.mjs';

// The app it drives: test/fixtures/apps/server_query (lite), or test/fixtures/apps/lazy_pieces (either engine).
const appName = process.env.LAZY_APP ?? 'server_query';
const children = [];
const tmp = mkdtempSync(join(tmpdir(), 'thor-lazy-piece-'));
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

await e2e('lazy-piece', { site: tmp, timeout: 180_000 }, async (t) => {
  const bin = join(repo, appDir(appName), 'build/server');
  if (!existsSync(bin)) throw new Error(`${appDir(appName)}/build/server is missing: build it first (tool/thor e2e builds it)`);
  const port = await freePort();
  children.push(spawn(bin, [], { cwd: join(repo, appDir(appName)), env: { ...process.env, PORT: `${port}` }, stdio: 'ignore' }));
  const app = `http://127.0.0.1:${port}`;
  await waitFor(`${app}/piece`);

  const has = async (page, want, timeout = 5000) => !!(await settle(page, (w) => document.body.innerText.includes(w), want, { timeout }));
  const clean = (page) => page.problems.filter((p) => !/Failed to load resource|Prefetch request denied/.test(p));
  const tile = (page, slug) => page.locator(`details:has(summary:text-is("Department ${slug}"))`);
  const open = (page, slug) => page.locator(`summary:text-is("Department ${slug}")`).click();
  const requests = (page) => {
    const urls = [];
    page.on('request', (r) => r.url().includes('thor-piece=') && urls.push(new URL(r.url()).searchParams.get('thor-piece')));
    return urls;
  };

  // --- with JavaScript ---------------------------------------------------------
  {
    const page = await t.page({ viewport: { width: 900, height: 700 } });
    await trackHydration(page);
    const asked = requests(page);
    await page.goto(`${app}/piece`);
    const body = await page.locator('body').innerText();
    t.check('the page has the fallback links', await page.locator('a:text-is("See all of food")').count() === 1);
    t.check('…and not the content', !body.includes('Branch food') && !body.includes('Inside the dialog'));
    t.check('the placeholders have their URL and trigger', await page.evaluate(() => [...document.querySelectorAll('[data-thor-lazy]')].map((e) => e.getAttribute('data-thor-lazy-on')).join()) === 'open,open,open,open,visible');
    await page.waitForTimeout(400);
    t.check('nothing is asked for before something opens', asked.length === 0, asked.join());

    // open a tile.
    await open(page, 'food');
    t.check('the piece arrives in the open tile', await has(page, 'Branch food drawn 1'));
    t.check('…with its links', (await tile(page, 'food').locator('a:text-is("Item bread")').count()) === 1);
    t.check('…in place of the fallback', (await tile(page, 'food').locator('a:text-is("See all of food")').count()) === 0);
    t.check('one request for it', asked.join() === 'branch-food', asked.join());
    const state = await page.locator('[data-thor-lazy]').first().getAttribute('data-thor-lazy-state');
    t.check('the piece says it is done', state === 'done', String(state));
    t.check('no longer busy', (await page.locator('[aria-busy]').count()) === 0);

    // the engine binds what came late.
    // The first open raised the engine (a click on the page); the lite engine has `thor.def`.
    await hydrated(page).catch(() => {});
    const lite = true; // either engine
    if (lite) {
      await page.getByRole('button', { name: 'Count food', exact: true }).click();
      t.check('a ThorState button in the piece works', await has(page, 'clicks=1', 3000));
      await page.getByRole('button', { name: 'Count food', exact: true }).click();
      t.check('…and again', await has(page, 'clicks=2', 3000));
    }

    // Close and open again: no new request. Opening another one (an accordion) closes it.
    await open(page, 'home');
    t.check('the other tile loads its own piece', await has(page, 'Branch home drawn 1'));
    t.check('the accordion closed the first tile', !(await tile(page, 'food').evaluate((d) => d.open)));
    await open(page, 'food');
    await page.waitForTimeout(300);
    t.check('opening it again does not ask again', asked.join() === 'branch-food,branch-home', asked.join());
    t.check('and its content is still there', await has(page, 'Branch food drawn 1'));

    // the first request fails.
    await open(page, 'broken');
    await settle(page, () => document.querySelector('details:has(summary) [data-thor-lazy-state=error]'), null, { timeout: 4000 });
    t.check('a failed request leaves the fallback', (await tile(page, 'broken').locator('a:text-is("See all of broken")').count()) === 1);
    t.check('…marked as an error', (await tile(page, 'broken').locator('[data-thor-lazy-state=error]').count()) === 1);
    await open(page, 'food'); // the accordion closes it
    await open(page, 'broken');
    t.check('it tries again when it opens again', await has(page, 'Branch broken drawn 2'));
    t.check('…and the fallback is gone', (await tile(page, 'broken').locator('a:text-is("See all of broken")').count()) === 0);

    // a dialog and a block far down.
    t.check('the dialog piece is not asked for before it opens', !asked.includes('dialog'));
    t.check('the footer piece is not asked for before it is near', !asked.includes('footer'));
    await page.getByRole('button', { name: 'Open more' }).click();
    t.check('the dialog piece loads when the dialog opens', await has(page, 'Inside the dialog'));
    await page.keyboard.press('Escape');
    await page.locator('text=Footer waits').scrollIntoViewIfNeeded();
    t.check('the footer piece loads when it comes near', await has(page, 'Footer piece'));
    t.check('each piece was asked for once', asked.filter((a) => a === 'dialog').length === 1 && asked.filter((a) => a === 'footer').length === 1, asked.join());
    t.check('no console errors', clean(page).length === 0, clean(page).join(' | '));
    await page.context().close();
  }

  // --- the page has the engine already (it uses the state outside the piece) -----
  {
    const page = await t.page({ viewport: { width: 900, height: 700 } });
    await trackHydration(page);
    await page.goto(`${app}/piece?engine=1`);
    await page.getByRole('button', { name: 'Count page', exact: true }).click();
    await hydrated(page).catch(() => {});
    const lite = true; // either engine
    t.check('the page does not bring the engine twice for the piece', (await page.locator('script[src*="engine"]').count()) <= 1);
    await open(page, 'food');
    t.check('(engine already there) the piece arrives', await has(page, 'Branch food drawn'));
    if (lite) {
      await page.getByRole('button', { name: 'Count food', exact: true }).click();
      t.check('(engine already there) a button in the piece is bound', await has(page, 'clicks=2', 3000), await page.locator('[data-tt]').allInnerTexts().then((x) => x.join()));
      // Both Watches show the one state.
      const labels = await page.locator('[data-tt="PieceState.label"]').allInnerTexts();
      t.check('(engine already there) the page and the piece share the state', labels.length === 2 && labels.every((l) => l === 'clicks=2'), labels.join());
    }
    t.check('no console errors', clean(page).length === 0, clean(page).join(' | '));
    await page.context().close();
  }

  // --- without JavaScript ----------------------------------------------------------
  {
    const bare = await t.page({ javaScriptEnabled: false });
    await bare.goto(`${app}/piece`);
    const markup = await bare.content();
    t.check('no JS: the fallbacks are on the page', markup.includes('See all of food') && markup.includes('See all of home'));
    t.check('no JS: no content, no error', !markup.includes('Branch food'));
    await bare.locator('summary:text-is("Department food")').click();
    await bare.getByRole('link', { name: 'See all of food' }).click();
    t.check('no JS: the link goes to a real page', new URL(bare.url()).search === '?all=food', bare.url());
    await bare.context().close();
  }

  // --- a strict CSP -----------------------------------------------------------------
  {
    const html = await (await fetch(`${app}/piece`)).text();
    const scripts = [...html.matchAll(/<script>((?:(?!<\/script>)[\s\S])*data-thor-lazy[\s\S]*?)<\/script>/g)].map((m) => m[1]);
    t.check('the page has exactly one loader script', scripts.length === 1, `${scripts.length}`);
    const hash = `'sha256-${createHash('sha256').update(scripts[0] ?? '').digest('base64')}'`;
    const guide = readFileSync(join(repo, 'docs/guia/es/sesion-y-seguridad.md'), 'utf8');
    t.check('its hash is in the security guide (CSP table)', guide.includes(hash), hash);
    t.check('no piece carries a script of its own', (html.match(/<script>/g) ?? []).length <= 2);
    const page = await t.page();
    await page.route(`${app}/piece*`, async (route) => {
      const r = await route.fetch();
      await route.fulfill({ response: r, headers: { ...r.headers(), 'content-security-policy': `script-src 'self' ${hash}` } });
    });
    await page.goto(`${app}/piece`);
    await open(page, 'home');
    t.check('under the CSP the piece loads', await has(page, 'Branch home drawn'));
    await page.context().close();
  }

  // --- the fragment -----------------------------------------------------------------
  {
    const r = await fetch(`${app}/piece?thor-piece=branch-food`);
    const text = await r.text();
    t.check('the fragment is a 200 of HTML', r.status === 200 && /text\/html/.test(r.headers.get('content-type') ?? ''));
    t.check('…that is the piece alone', text.includes('Branch food drawn') && !/<html|<body|Header \(not lazy\)/.test(text), text.slice(0, 120));
    t.check('…kept out of search engines', /noindex/.test(r.headers.get('x-robots-tag') ?? ''));
    const missing = await fetch(`${app}/piece?thor-piece=nope`);
    t.check('a piece that does not exist is a 404', missing.status === 404, `${missing.status}`);
    const page = await fetch(`${app}/piece`);
    t.check('the page itself is not a fragment', (await page.text()).includes('<html'));
  }

  if (appName !== 'lazy_pieces') return;

  // --- a piece inside a piece -------------------------------------------------------------
  {
    const page = await t.page({ viewport: { width: 900, height: 700 } });
    await trackHydration(page);
    const asked = requests(page);
    await page.goto(`${app}/nested`);
    t.check('only the outer placeholder is on the page', (await page.locator('[data-thor-lazy]').count()) === 1);
    await page.locator('summary:text-is("Outer tile")').click();
    t.check('the outer piece arrives with the inner fallback', await has(page, 'outer says hi') && (await page.locator('text=Inner needs JavaScript').count()) === 1);
    t.check('the inner piece did not load with it', asked.join() === 'outer', asked.join());
    t.check('the inner placeholder names both ids', (await page.locator('[data-thor-lazy*="outer"][data-thor-lazy*="inner"]').count()) === 1);
    await page.locator('summary:text-is("Inner tile")').click();
    t.check('the inner piece loads when its tile opens', await has(page, 'inner says hi'));
    t.check('…once', asked.join() === 'outer,outer:inner', asked.join());
    await hydrated(page).catch(() => {});
    await page.getByRole('button', { name: 'Count outer', exact: true }).click();
    await page.getByRole('button', { name: 'Count inner', exact: true }).click();
    t.check('the buttons of both pieces work and the Watch shows both', await has(page, 'clicks=2', 3000));
    const bare = await fetch(`${app}/nested?thor-piece=inner`);
    t.check('an inner id without its outer one is a 404', bare.status === 404, `${bare.status}`);
    const frag = await fetch(`${app}/nested?thor-piece=outer%3Ainner`);
    const text = await frag.text();
    t.check('the inner fragment is its own answer', frag.status === 200 && text.includes('inner says hi') && !text.includes('outer says hi'), text.slice(0, 120));
    t.check('no console errors', clean(page).length === 0, clean(page).join(' | '));
    await page.context().close();
  }

  // --- what a FutureBuilder sends after the page is bound -----------------------------------
  {
    const page = await t.page({ viewport: { width: 900, height: 700 } });
    await trackHydration(page);
    await page.goto(`${app}/stream`);
    t.check('the result replaces the skeleton', await has(page, 'Late ready', 6000));
    await hydrated(page).catch(() => {});
    await page.getByRole('button', { name: 'Count late', exact: true }).click();
    t.check('a button in the late content works', await has(page, 'clicks=1', 3000));
    t.check('no console errors', clean(page).length === 0, clean(page).join(' | '));
    await page.context().close();
  }

  // --- pieces that load together, in a page with no engine ---------------------------------
  {
    const page = await t.page({ viewport: { width: 900, height: 700 } });
    await trackHydration(page);
    const asked = requests(page);
    await page.goto(`${app}/burst`);
    t.check('the page has no engine of its own', (await page.locator('script[src*="engine"]').count()) === 0);
    t.check('the three pieces and the far one arrive', await has(page, 'p1 ready') && await has(page, 'p2 ready') && await has(page, 'p3 ready') && await has(page, 'far ready'));
    t.check('one request each', ['p1', 'p2', 'p3', 'far'].every((id) => asked.filter((a) => a === id).length === 1), asked.join());
    await settle(page, () => document.querySelectorAll('script[src*="engine"]').length >= 1, null, { timeout: 4000 });
    t.check('one engine script, not one per piece', (await page.locator('script[src*="engine"]').count()) === 1, `${await page.locator('script[src*="engine"]').count()}`);
    await hydrated(page).catch(() => {});
    await page.getByRole('button', { name: 'Count p1', exact: true }).click();
    await page.getByRole('button', { name: 'Count p2', exact: true }).click();
    t.check('the buttons of the pieces are bound', await has(page, 'clicks=2', 3000));
    const labels = await page.locator('[data-tt="PieceState.label"]').allInnerTexts();
    t.check('every Watch of every piece shows the one state', labels.length >= 4 && labels.every((l) => l === 'clicks=2'), labels.join());
    t.check('the list in a piece has its rows', (await page.locator('[data-tk]').allInnerTexts()).join() === 'x', (await page.locator('[data-tk]').allInnerTexts()).join());
    const color = await page.locator('text=p3 ready').evaluate((el) => getComputedStyle(el.closest('div')).backgroundColor);
    t.check('the rule of a class only the piece has is applied', color === 'rgb(26, 43, 60)', color);
    t.check('no console errors', clean(page).length === 0, clean(page).join(' | '));
    await page.context().close();
  }

  // --- taps, dialogs, history -------------------------------------------------------------
  {
    const page = await t.page({ viewport: { width: 900, height: 700 } });
    await trackHydration(page);
    const asked = requests(page);
    await page.goto(`${app}/piece`);
    const summary = page.locator('summary:text-is("Department food")');
    for (let i = 0; i < 5; i++) {
      await summary.click({ delay: 0 });
      await page.waitForTimeout(25);
    }
    await page.waitForTimeout(600);
    t.check('five taps on a tile ask once', asked.filter((a) => a === 'branch-food').length === 1, asked.join());
    t.check('and the content is in once', (await page.locator('text=/Branch food drawn/').count()) === 1, `${await page.locator('text=/Branch food drawn/').count()}`);
    // A dialog closed and opened again.
    await page.getByRole('button', { name: 'Open more' }).click();
    t.check('the dialog piece arrives', await has(page, 'Inside the dialog'));
    await page.keyboard.press('Escape');
    await page.getByRole('button', { name: 'Open more' }).click();
    await page.waitForTimeout(300);
    await page.keyboard.press('Escape');
    t.check('a dialog opened again does not insert twice nor ask twice', (await page.locator('text=Inside the dialog').count()) === 1 && asked.filter((a) => a === 'dialog').length === 1, asked.join());
    // History: follow a link, go back.
    await open(page, 'home');
    await has(page, 'Branch home drawn');
    await page.locator('a:text-is("Item lamp")').click();
    await page.waitForURL(/item=lamp/);
    await page.goBack();
    await page.waitForURL(/\/piece$/);
    await page.waitForTimeout(500);
    const alive = async (slug) => {
      await open(page, slug);
      return has(page, `Branch ${slug} drawn`);
    };
    t.check('after back the tiles still load their pieces', await alive('food'));
    t.check('…once each', (await page.locator('text=/Branch food drawn/').count()) === 1);
    await page.goForward();
    await page.goBack();
    await page.waitForTimeout(300);
    t.check('after forward and back again it still works', await alive('home'));
    t.check('no console errors', clean(page).length === 0, clean(page).join(' | '));
    await page.context().close();
  }

  // --- Save-Data ---------------------------------------------------------------------------
  {
    const saving = await t.page({ viewport: { width: 900, height: 700 } });
    await saving.addInitScript(() => Object.defineProperty(navigator, 'connection', { value: { saveData: true }, configurable: true }));
    const asked = requests(saving);
    await saving.goto(`${app}/burst`);
    t.check('Save-Data: what is on screen still loads', await has(saving, 'p1 ready') && await has(saving, 'p3 ready'));
    await saving.waitForTimeout(600);
    t.check('…but the idle piece far down waits', !asked.includes('far'), asked.join());
    await saving.locator('text=far waits').scrollIntoViewIfNeeded();
    t.check('…and loads when it comes near', await has(saving, 'far ready'));
    await saving.context().close();
  }
});

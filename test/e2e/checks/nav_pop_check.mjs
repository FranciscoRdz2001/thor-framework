// PageNavigator.pop / canPop where it is hard: no Navigation API (what
// Firefox and older Safari have), so canPop is the heuristic of both
// engines (history entry state, hash entries, a same-origin referrer with
// more than one entry), and pop must never leave the user stuck.
//
//   THOR_INTERNAL_ENGINE=dart tool/thor export lab && node tool/thor_lite.mjs lab
//   node test/e2e/checks/nav_pop_check.mjs          # dart2js engine
//   NAV_SITE=test/fixtures/apps/lab/build/site-lite node test/e2e/checks/nav_pop_check.mjs
import { e2e, hydrated, trackHydration } from './lib/e2e.mjs';

const site = process.env.NAV_SITE ?? 'test/fixtures/apps/lab/build/site';
const note = '[data-tt="ControlsState.navNote"]';
// The controls page of the lab: the fallbacks (`?vista=3`) resolve against it.
const pagePath = '/controls';

await e2e(`nav pop (${site})`, { site, path: 'controls', timeout: 90_000 }, async (t) => {
  // A page of the site opened in a tab of its own, no Navigation API.
  const open = async (url, { referer } = {}) => {
    const page = await t.page();
    await trackHydration(page.context());
    await page.context().addInitScript(() => {
      Object.defineProperty(window, 'navigation', { value: undefined, configurable: true });
    });
    await page.goto(url, referer ? { referer } : {});
    await hydrated(page);
    return page;
  };
  // A new tab from a same-origin link (`target=_blank`): the referrer is
  // the opener's, the tab's history has one entry.
  const newTab = async (opener, href = pagePath) => {
    await opener.evaluate((h) => {
      document.getElementById('nt')?.remove();
      const a = document.createElement('a');
      a.href = h;
      a.target = '_blank';
      a.id = 'nt';
      a.textContent = 'open';
      a.style.cssText = 'display:block;position:fixed;top:0;left:0;z-index:99999;background:#fff';
      document.body.append(a);
    }, href);
    const [tab] = await Promise.all([opener.context().waitForEvent('page'), opener.click('#nt')]);
    tab.problems = [];
    tab.on('pageerror', (e) => tab.problems.push(e.message));
    await tab.waitForLoadState();
    await hydrated(tab);
    return tab;
  };
  const press = (page, name) => page.getByRole('button', { name, exact: true }).click();
  const canPop = async (page) => {
    await press(page, '¿Puedo volver?');
    await page.waitForFunction(
      (s) => /Puede volver: (true|false)/.test(document.querySelector(s)?.textContent ?? ''),
      note,
    );
    return (await page.textContent(note)).endsWith('true');
  };
  const atFallback = (page) => page.waitForURL(/[?]vista=3$/, { timeout: 4000 }).then(() => true, () => false);
  const origin = new URL(t.url).origin;

  // A new tab from a same-origin link: a referrer, history.length 1.
  const home = await open(t.url);
  let p = await newTab(home);
  t.check('the tab has one history entry', (await p.evaluate(() => history.length)) === 1);
  t.check('new tab with a same-origin referrer: canPop is false', (await canPop(p)) === false);
  await press(p, 'Volver');
  t.check('new tab: pop loads the fallback', await atFallback(p));

  // The same after a reload of that first entry.
  p = await newTab(home);
  await p.reload();
  await hydrated(p);
  t.check('reload of a first entry: canPop is false', (await canPop(p)) === false);
  await press(p, 'Volver');
  t.check('reload of a first entry: pop loads the fallback', await atFallback(p));

  // Reached from this site in the same tab: there is an entry to go back to.
  p = await open(t.url);
  await p.evaluate(() => (window.__first = 1));
  await Promise.all([p.waitForNavigation(), p.evaluate(() => (location.href = '?a=1'))]);
  await hydrated(p);
  t.check('same tab, same-origin referrer: canPop is true', (await canPop(p)) === true);
  await Promise.all([p.waitForNavigation(), press(p, 'Volver')]);
  t.check('same tab: pop goes back, not to the fallback', !/vista=3/.test(p.url()) && !/a=1/.test(p.url()), p.url());

  // Back to the first entry of a tab (a forward entry exists) and pop again:
  // the guess is wrong, the fallback must still load.
  p = await newTab(home);
  await Promise.all([p.waitForNavigation(), p.evaluate(() => (location.href = '?n=2'))]);
  await hydrated(p);
  await Promise.all([p.waitForNavigation(), press(p, 'Volver')]);
  await hydrated(p);
  t.check('back at the first entry', !/n=2/.test(p.url()), p.url());
  await press(p, 'Volver').catch(() => {});
  t.check('first entry with a forward entry: pop reaches the fallback', await atFallback(p), p.url());

  // rel=noreferrer: no referrer, so nothing to go back to is claimed; the
  // fallback loads (conservative, never stuck).
  p = await open(t.url);
  await p.evaluate(() => {
    const a = document.createElement('a');
    a.href = '?b=1';
    a.rel = 'noreferrer';
    a.id = 'nr';
    a.textContent = 'x';
    a.style.cssText = 'display:block;position:fixed;top:0;left:0;z-index:99999;background:#fff';
    document.body.append(a);
  });
  await Promise.all([p.waitForNavigation(), p.click('#nr')]);
  await hydrated(p);
  t.check('noreferrer link: canPop is false (conservative)', (await canPop(p)) === false);
  await press(p, 'Volver');
  t.check('noreferrer link: pop loads the fallback', await atFallback(p));

  // A referrer of another origin (a cross-origin redirect chain): false.
  p = await open(t.url, { referer: 'http://other.test/x' });
  t.check('cross-origin referrer: canPop is false', (await canPop(p)) === false);

  // Hash entries: back goes to the entry before the hash, then the fallback.
  p = await open(t.url);
  await p.evaluate(() => (location.hash = '#a'));
  t.check('hash entry: canPop is true', (await canPop(p)) === true);
  await press(p, 'Volver');
  await p.waitForFunction(() => location.hash === '');
  t.check('hash entry: pop went back within the document', !/vista=3/.test(p.url()), p.url());
  await press(p, 'Volver');
  t.check('first entry after a hash entry: pop reaches the fallback', await atFallback(p), p.url());

  // A fallback equal to the current URL: a load of that URL, no error.
  p = await open(`${origin}${pagePath}?vista=3`);
  await p.evaluate(() => (window.__same = 1));
  await Promise.all([p.waitForNavigation(), press(p, 'Volver')]);
  t.check('fallback equal to the current URL reloads it', await p.evaluate(() => window.__same) == null);

  // bfcache / history restore: going back to the page keeps canPop working.
  p = await newTab(home);
  await press(p, 'Volver');
  await atFallback(p);
  await p.goBack();
  await hydrated(p);
  const again = await canPop(p);
  t.check('restored page answers canPop', typeof again === 'boolean');
  t.check('no page errors', p.problems.length === 0, p.problems.join(' | '));
});

// Three store-page cases in a real browser, on test/fixtures/apps/lab (/store-lists), in both
// engines (`tool/thor e2e store-lists` is lite, `store-lists-dart` dart2js):
//  - a list per instance: `Watch.list(store.branchOf.withArg(slug))` shows its
//    own rows in each tile, and a change of the state moves only that list;
//  - a `Link` with no href under `row.attribute('href', …)`: the rows the
//    server drew and the ones the browser clones have their own href;
//  - the exclusive accordion's `onExpansionChanged` hears the tile that closes
//    before the one that opens;
//  - the list container: Flutter's Column (centered) by default, the one given
//    to `container:` otherwise.
//
//   tool/thor e2e store-lists                 (builds, serves, runs)
//   node test/e2e/checks/store_lists_check.mjs [url]
import { e2e, hydrated, settle, trackHydration } from './lib/e2e.mjs';

await e2e('store-lists', { site: 'test/fixtures/apps/lab/build/site', path: 'store-lists' }, async (t) => {
  const page = await t.page({ viewport: { width: 700, height: 1200 } });
  await trackHydration(page);
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(t.url);
  const tile = (slug) => page.locator(`details:has(> summary:text-is("Dept ${slug}"))`);
  const rows = (slug) => tile(slug).locator('[data-tk]').evaluateAll((els) => els.map((e) => ({ text: e.textContent.trim(), href: e.getAttribute('href') })));
  const summary = (slug) => page.locator(`summary:text-is("Dept ${slug}")`);
  const log = () => page.locator('[data-tt="StoreState.logText"]').innerText();
  const logIs = async (want) => !!(await settle(page, (w) => document.querySelector('[data-tt="StoreState.logText"]').textContent.trim() === w, want, { timeout: 3000 }));

  // --- A list per instance, a Link with no href in the rows the server drew ---------------
  const food = await rows('food');
  t.check('each tile shows its own rows (food)', food.map((r) => r.text).join() === 'fruit,bread', JSON.stringify(food));
  t.check('the server rows have their own href', food.map((r) => r.href).join() === '/c/fruit,/c/bread', JSON.stringify(food));
  t.check('each tile shows its own rows (home, toys)', (await rows('home')).map((r) => r.text).join() === 'lamp' && (await rows('toys')).length === 0);

  // The first tap loads the engine: open a tile, then add a row to it (cloned by the browser).
  await summary('home').click();
  await hydrated(page);
  await page.getByRole('button', { name: 'Add to home', exact: true }).click();
  const homeRows = async () => {
    const got = await settle(page, () => document.querySelectorAll('details:nth-of-type(2) [data-tk]').length === 2, null, { timeout: 3000 });
    return got ? rows('home') : rows('home');
  };
  const home = await homeRows();
  t.check('a change of the state moves that list only', home.map((r) => r.text).join() === 'lamp,new1' && (await rows('food')).map((r) => r.text).join() === 'fruit,bread', JSON.stringify(home));
  t.check('the row the browser cloned has its own href too', home[1]?.href === '/c/new1', JSON.stringify(home));
  t.check('the cloned row is a real link', (await tile('home').locator('a[href="/c/new1"]').count()) === 1);
  t.check('the template has no placeholder href', (await page.evaluate(() => [...document.querySelectorAll('template[data-tlt]')].every((tp) => !tp.innerHTML.includes('href="#"')))));

  // --- The accordion: the tile that closes is heard before the one that opens ------------
  await page.reload();
  await page.mouse.move(1, 1);
  await summary('food').click();
  await hydrated(page);
  t.check('opening food reports +food', await logIs('+food'), await log());
  await summary('home').click();
  t.check('opening home closes food first, then opens home', await logIs('+food -food +home'), await log());
  await summary('toys').click();
  t.check('and again: -home before +toys', await logIs('+food -food +home -home +toys'), await log());
  await summary('toys').click();
  t.check('closing the open one reports once', await logIs('+food -food +home -home +toys -toys'), await log());

  // --- The container ---------------------------------------------------------------------
  const layout = await page.evaluate(() => {
    const tileList = document.querySelector('details [data-tl]');
    const lists = [...document.querySelectorAll('[data-tl]')];
    const last = lists[lists.length - 1];
    return { tile: getComputedStyle(tileList).alignItems, def: getComputedStyle(last).alignItems };
  });
  t.check('the given container is a Column from the start', layout.tile === 'flex-start', JSON.stringify(layout));
  t.check('the default container is Flutter\'s Column: it centers', layout.def === 'center', JSON.stringify(layout));
  t.check('no page errors', errors.length === 0, errors.join(' | '));
});

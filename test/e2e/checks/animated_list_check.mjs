// AnimatedList in a real browser (test/fixtures/apps/lab (/animated-list)): the rows the server
// drew rest, a row the browser adds grows in (@starting-style) and a row that
// is removed stays (inert, marked) until its transition ends; with reduced
// motion neither animates. Runs on both engines.
//
//   tool/thor e2e animated-list animated-list-dart  (builds, serves, runs)
//   node test/e2e/checks/animated_list_check.mjs [url]
import { e2e, hydrated, settle, trackHydration } from './lib/e2e.mjs';

await e2e('animated-list', { site: 'test/fixtures/apps/lab/build/site', path: 'animated-list' }, async (t) => {
  const rows = '[data-tk]';
  const count = (page) => page.locator(rows).count();
  const state = (page, sel) =>
    page.$$eval(sel, (els) =>
      els.map((e) => ({
        key: e.getAttribute('data-tk'),
        entering: e.hasAttribute('data-tli'),
        leaving: e.hasAttribute('data-tlo'),
        inert: e.inert,
        // The fade is on an element inside the row's own.
        opacity: Math.min(...[e, ...e.querySelectorAll('*')].map((x) => Number(getComputedStyle(x).opacity))),
        height: e.getBoundingClientRect().height,
      })),
    );

  // 1. Before the engine: the rows the server drew, still, with no marks.
  {
    const page = await t.page();
    const errors = [];
    page.on('pageerror', (e) => errors.push(String(e)));
    await page.goto(t.url);
    const first = await state(page, rows);
    t.check('three rows, at rest (opacity 1, not entering)', first.length === 3 && first.every((r) => r.opacity === 1 && !r.entering && !r.leaving), JSON.stringify(first));
    t.check('they have a height', first.every((r) => r.height > 20), JSON.stringify(first.map((r) => r.height)));
    t.check('no page errors', errors.length === 0, errors.join('; '));
  }

  // 2. With the engine: a row enters, a row leaves.
  {
    const page = await t.page();
    const errors = [];
    page.on('pageerror', (e) => errors.push(String(e)));
    page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
    await trackHydration(page);
    await page.goto(t.url);
    await page.mouse.move(1, 1);
    await page.mouse.down();
    await page.mouse.up();
    t.check('engine hydrates', await hydrated(page).then(() => true, () => false));
    const rest = await state(page, rows);
    t.check('the rows of the first paint did not animate', rest.every((r) => r.opacity === 1 && !r.leaving), JSON.stringify(rest));

    // Enter: sample the new row while it transitions.
    await page.getByRole('button', { name: 'Agregar' }).click();
    const seen = [];
    for (let i = 0; i < 12; i++) {
      await page.waitForTimeout(25);
      const s = (await state(page, `${rows}[data-tk="4"]`))[0];
      if (s) seen.push(s);
    }
    t.check('the new row is in the list, first', (await count(page)) === 4 && (await page.locator(rows).first().getAttribute('data-tk')) === '4');
    t.check('it starts from nothing: height and opacity grow', seen.length > 3 && seen[0].opacity < 0.9 && seen[0].height < seen[seen.length - 1].height, JSON.stringify(seen.slice(0, 3)));
    const done = await settle(page, () => {
      const e = document.querySelector('[data-tk="4"]');
      return !!e && [e, ...e.querySelectorAll('*')].every((x) => getComputedStyle(x).opacity === '1') && e.getBoundingClientRect().height > 20;
    });
    t.check('and ends at rest', done === true, JSON.stringify(await state(page, `${rows}[data-tk="4"]`)));
    await page.waitForTimeout(100);
    t.check('the entering mark is gone once it appeared', (await state(page, `${rows}[data-tk="4"]`))[0]?.entering === false);

    // Leave: the row stays, inert, while it fades and shrinks.
    await page.locator('[data-tk="2"] button').click();
    await page.waitForTimeout(80);
    const leaving = (await state(page, `${rows}[data-tk="2"]`))[0];
    t.check('the removed row is still there, marked and inert', !!leaving && leaving.leaving && leaving.inert, JSON.stringify(leaving));
    t.check('and on its way out (opacity below 1)', !!leaving && leaving.opacity < 1, JSON.stringify(leaving));
    t.check('the list does not count it', (await page.textContent('[data-tt="NotesState.countLabel"]')) === '3 notas', await page.textContent('[data-tt="NotesState.countLabel"]'));
    const gone = await settle(page, () => !document.querySelector('[data-tk="2"]'));
    t.check('it goes after its transition', gone === true);
    t.check('the others stay', (await count(page)) === 3);

    // Everything out at once, and back.
    await page.getByRole('button', { name: 'Vaciar' }).click();
    await page.waitForTimeout(80);
    t.check('clearing keeps every row while they leave', (await state(page, rows)).every((r) => r.leaving), JSON.stringify(await state(page, rows)));
    const empty = await settle(page, () => document.querySelectorAll('[data-tk]').length === 0);
    t.check('and then the list is empty', empty === true);
    await page.getByRole('button', { name: 'Restaurar' }).click();
    const back = await settle(page, () => document.querySelectorAll('[data-tk]').length === 3 && [...document.querySelectorAll('[data-tk] *')].every((e) => getComputedStyle(e).opacity === '1'));
    t.check('restoring brings three rows in', back === true);

    // The same key coming back while the old row leaves: no row is lost.
    await page.locator('[data-tk="1"] button').click();
    await page.getByRole('button', { name: 'Restaurar' }).click();
    const same = await settle(page, () => document.querySelectorAll('[data-tk]:not([data-tlo])').length === 3 && !document.querySelector('[data-tlo]'));
    t.check('a removed row that comes back leaves one row, not two', same === true, String(await count(page)));
    t.check('no errors', errors.length === 0, errors.join('; '));
  }

  // 3. Reduced motion: rows appear and disappear at once.
  {
    const page = await t.page({ reducedMotion: 'reduce' });
    const errors = [];
    page.on('pageerror', (e) => errors.push(String(e)));
    await trackHydration(page);
    await page.goto(t.url);
    await page.mouse.move(1, 1);
    await page.mouse.down();
    await page.mouse.up();
    await hydrated(page);
    await page.getByRole('button', { name: 'Agregar' }).click();
    await page.waitForTimeout(60);
    const added = (await state(page, `${rows}[data-tk="4"]`))[0];
    t.check('reduced motion: the new row is whole at once', !!added && added.opacity === 1 && added.height > 20, JSON.stringify(added));
    await page.locator('[data-tk="2"] button').click();
    await page.waitForTimeout(60);
    t.check('reduced motion: the removed row is gone at once', (await state(page, `${rows}[data-tk="2"]`)).length === 0);
    t.check('no errors', errors.length === 0, errors.join('; '));
  }
});

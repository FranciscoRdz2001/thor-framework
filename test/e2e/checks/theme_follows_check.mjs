// `Theme.of(context).colorScheme` follows the dark mode in a real browser:
// the colors a page takes from it are the theme's variables, so
// switching the color scheme repaints them with no reload, with and without
// JavaScript. Also `Watch.field` reacting on the same page.
//
//   tool/thor e2e theme-follows                 (builds, serves, runs)
//   node test/e2e/checks/theme_follows_check.mjs [url]
import { e2e, hydrated, settle, trackHydration } from './lib/e2e.mjs';

// Material 3 baseline primary: light #6750a4, dark #d0bcff.
const LIGHT = 'rgb(103, 80, 164)';
const DARK = 'rgb(208, 188, 255)';

await e2e('theme-follows', { site: 'test/fixtures/apps/lab/build/site', path: 'widgets' }, async (t) => {
  for (const js of [false, true]) {
    const tag = js ? '[js]' : '[no js]';
    const check = (label, ok, detail) => t.check(`${tag} ${label}`, ok, detail);
    const page = await t.page({ colorScheme: 'light', javaScriptEnabled: js });
    if (js) await trackHydration(page);
    await page.goto(t.url);
    // The box itself carries the id (Semantics(identifier:) is on the child).
    const paint = (id) =>
      page.evaluate((id) => getComputedStyle(document.getElementById(id)).backgroundColor, id);
    const surface = () => paint('theme-surface');

    check('light: the primary is the light role', (await paint('theme-primary')) === LIGHT, await paint('theme-primary'));
    const lightSoft = await paint('theme-soft');
    const lightSurface = await surface();
    // A marker that a reload would lose.
    await page.evaluate(() => (window.__noReload = 1));

    await page.emulateMedia({ colorScheme: 'dark' });
    const dark = await settle(page, (l) => {
      const c = getComputedStyle(document.getElementById('theme-primary')).backgroundColor;
      return c !== l && c;
    }, LIGHT);
    check('dark: the primary changes to the dark role, no reload', dark === DARK, String(dark));
    check(
      'dark: withValues(alpha:) follows too',
      (await paint('theme-soft')) !== lightSoft && /^color\(srgb 0\.81\d* 0\.73\d* 1 \/ 0\.5\)$/.test(await paint('theme-soft')),
      `${lightSoft} -> ${await paint('theme-soft')}`,
    );
    check('dark: the surface follows', (await surface()) !== lightSurface, `${lightSurface} -> ${await surface()}`);
    check('the page was not reloaded', (await page.evaluate(() => window.__noReload)) === 1);

    await page.emulateMedia({ colorScheme: 'light' });
    const back = await settle(page, (l) => getComputedStyle(document.getElementById('theme-primary')).backgroundColor === l, LIGHT);
    check('back to light', back === true, await paint('theme-primary'));
    check('no page errors', page.problems.length === 0, page.problems.join(' | '));
  }

  // Watch.field: a bool field, its builder typed, reacting in the browser.
  const page = await t.page({ viewport: { width: 700, height: 2400 } });
  await trackHydration(page);
  await page.goto(t.url);
  const field = page.locator('[data-tv="LabState.flag"]');
  t.check('Watch.field: first paint shows the field\'s value', (await field.textContent()) === 'Campo: no', await field.textContent());
  await page.getByRole('button', { name: 'Alternar el campo' }).click();
  await hydrated(page).catch(() => {});
  const on = await settle(page, () => document.querySelector('[data-tv="LabState.flag"]')?.textContent === 'Campo: sí', null);
  t.check('Watch.field: reacts to the state', on === true, await field.textContent());
  await page.getByRole('button', { name: 'Alternar el campo' }).click();
  const off = await settle(page, () => document.querySelector('[data-tv="LabState.flag"]')?.textContent === 'Campo: no', null);
  t.check('Watch.field: and back', off === true, await field.textContent());
  t.check('no page errors', page.problems.length === 0, page.problems.join(' | '));
});

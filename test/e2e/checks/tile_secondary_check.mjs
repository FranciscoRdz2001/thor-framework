// A `CheckboxListTile` whose `secondary` is a delete `IconButton`, in a
// `Watch.list` with rows added in the browser (a classic to-do list).
// The secondary sits outside the <label>, so the checkbox keeps
// its exact accessible name, toggling and the strike-through work, and the
// delete button removes exactly its row, on server rows and cloned ones.
//
//   tool/thor e2e tile-secondary                (builds test/fixtures/apps/lab (/edge-cases), runs)
//   node test/e2e/checks/tile_secondary_check.mjs [url]
import { e2e, hydrated, settle, trackHydration } from './lib/e2e.mjs';

const site = process.env.E2E_SITE ?? 'test/fixtures/apps/lab/build/site';

await e2e('tile-secondary', { site, path: 'edge-cases' }, async (t) => {
  // Without JS: the structure is already right.
  {
    const page = await t.page({ javaScriptEnabled: false });
    await page.goto(t.url);
    const inLabel = await page.evaluate(() => document.querySelectorAll('.tile-lab label button, .tile-lab label [role=button]').length);
    t.check('no JS: no button inside a label', inLabel === 0, String(inLabel));
    t.check('no JS: the checkbox is named by its title only', (await page.locator('.tile-lab').getByRole('checkbox', { name: 'Comprar leche', exact: true }).count()) === 1);
  }

  const page = await t.page();
  await trackHydration(page);
  await page.goto(t.url);
  await hydrated(page);
  const summary = () => page.evaluate(() => document.body.innerText.match(/\d+ de \d+ completadas/)?.[0]);
  const lab = page.locator('.tile-lab');
  const box = (name) => lab.getByRole('checkbox', { name, exact: true });
  const del = () => lab.getByRole('button', { name: 'Eliminar' });

  // Rows added in the browser (cloned from the template).
  for (const title of ['Sacar la basura', 'Pagar la luz']) {
    await page.getByLabel('Nueva pendiente').fill(title);
    await page.getByRole('button', { name: 'Agregar pendiente' }).click();
  }
  await settle(page, () => document.querySelectorAll('.tile-lab input[type=checkbox]').length === 4);

  for (const title of ['Comprar leche', 'Sacar la basura']) {
    const label = lab.locator('label', { has: page.locator('input[type=checkbox]') }).filter({ hasText: title });
    t.check(`"${title}": checkbox found by its exact name`, (await box(title).count()) === 1);
    t.check(`"${title}": no button inside its label`, (await label.locator('button').count()) === 0);
    t.check(`"${title}": the row holds the label and the delete button`, (await label.locator('xpath=..').locator('button[aria-label="Eliminar"]').count()) === 1);
  }
  t.check('four delete buttons, one per row', (await del().count()) === 4);

  // Toggle on a row added in the browser.
  const cb = box('Sacar la basura');
  await cb.check();
  t.check('check: the checkbox is checked', await cb.isChecked());
  t.check('check: the counter says 1 de 4', (await settle(page, () => /1 de 4 completadas/.test(document.body.innerText))) === true, await summary());
  const strike = () => page.evaluate(() => {
    const row = [...document.querySelectorAll('.tile-lab label')].find((l) => l.textContent.includes('Sacar la basura'));
    const el = [...row.querySelectorAll('*')].find((e) => e.textContent.trim() === 'Sacar la basura' && e.children.length === 0) ?? row;
    return getComputedStyle(el).textDecorationLine;
  });
  t.check('done: the title has line-through', (await strike()).includes('line-through'), await strike());
  await cb.uncheck();
  t.check('uncheck: the counter says 0 de 4', (await settle(page, () => /0 de 4 completadas/.test(document.body.innerText))) === true, await summary());
  t.check('undone: no line-through', !(await strike()).includes('line-through'));

  // Clicking the delete button toggles nothing.
  const milk = box('Comprar leche');
  const before = await milk.isChecked();
  // Delete the row added in the browser, then a server one.
  await lab.locator('label', { hasText: 'Pagar la luz' }).locator('xpath=..').getByRole('button', { name: 'Eliminar' }).click();
  t.check('delete: exactly that row is gone', (await settle(page, () => document.querySelectorAll('.tile-lab input[type=checkbox]').length === 3)) === true && (await box('Pagar la luz').count()) === 0 && (await box('Sacar la basura').count()) === 1);
  t.check('delete: no other checkbox changed', (await milk.isChecked()) === before && !(await box('Sacar la basura').isChecked()));
  await lab.locator('label', { hasText: 'Comprar leche' }).locator('xpath=..').getByRole('button', { name: 'Eliminar' }).click();
  t.check('delete a server row: only it is gone', (await settle(page, () => document.querySelectorAll('.tile-lab input[type=checkbox]').length === 2)) === true && (await box('Comprar leche').count()) === 0 && (await box('Llamar a Ana').count()) === 1);
  t.check('the counter follows the list', (await settle(page, () => /0 de 2 completadas/.test(document.body.innerText))) === true, await summary());
  // A tile with a non-interactive secondary toggles wherever it is pressed
  // (Flutter: the whole ListTile is the target): the icon, the padding, the gaps.
  {
    const st = page.locator('.tile-static');
    const row = (title) => st.locator('label', { hasText: new RegExp(`^${title}$`) }).locator('xpath=..');
    const box = (title) => st.getByRole('checkbox', { name: title, exact: true });
    const clickAt = async (title, where) => {
      const r = await row(title).boundingBox();
      const x = where === 'left' ? r.x + 4 : where === 'right' ? r.x + r.width - 4 : r.x + r.width / 2;
      await page.mouse.click(x, r.y + r.height / 2);
    };
    for (const [title, where] of [['Icono', 'right'], ['Icono', 'left'], ['Icono final', 'left'], ['Icono final', 'right']]) {
      const cb = box(title);
      const was = await cb.isChecked();
      await clickAt(title, where);
      t.check(`"${title}": a click at the ${where} edge of the row toggles`, (await cb.isChecked()) === !was);
    }
    {
      const icon = row('Icono').locator('svg');
      const cb = box('Icono');
      const was = await cb.isChecked();
      // A real press at the icon's center (the icon lets it through, so the
      // locator's own actionability check would refuse it).
      const r = await icon.boundingBox();
      await page.mouse.click(r.x + r.width / 2, r.y + r.height / 2);
      t.check('the non-interactive icon secondary toggles on click', (await cb.isChecked()) === !was);
    }
    // An interactive secondary (a Switch) keeps its own click.
    {
      const cb = box('Con interruptor');
      const sw = row('Con interruptor').getByRole('switch');
      await sw.click();
      t.check('switch secondary: clicking it toggles the switch', await sw.isChecked());
      t.check('switch secondary: and not the checkbox', !(await cb.isChecked()));
      t.check('switch secondary: the checkbox keeps its exact name', (await cb.count()) === 1);
      await clickAt('Con interruptor', 'center');
      t.check('switch secondary: the label still toggles the checkbox', await cb.isChecked());
    }
    // Disabled: neither the icon nor the row toggles it.
    {
      const cb = box('Apagado');
      await row('Apagado').locator('svg').click({ force: true });
      await clickAt('Apagado', 'left');
      t.check('disabled tile: nothing toggles it', !(await cb.isChecked()) && await cb.isDisabled());
      const cur = await row('Apagado').evaluate((e) => getComputedStyle(e).cursor);
      t.check('disabled tile: default cursor', cur === 'default', cur);
    }
    const cur = await row('Icono').locator('svg').evaluate((e) => {
      const r = e.getBoundingClientRect();
      return getComputedStyle(document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2)).cursor;
    });
    t.check('enabled tile: a press on the secondary shows the pointer cursor', cur === 'pointer', cur);
  }

  t.check('no console or page errors', page.problems.length === 0, page.problems.join('; '));
});

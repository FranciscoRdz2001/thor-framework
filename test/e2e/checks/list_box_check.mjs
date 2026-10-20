// ListBox (`<select size>`, `multiple`) on test/fixtures/apps/lab (/list-box):
// 7GUIs' CRUD over `ListBox.list` (filter, select, create, update, delete,
// the keyboard), the static lists reporting to their state, a disabled one,
// axe-core on the page, and the form sending both kinds with no JS.
//
//   tool/thor e2e list-box                    (builds, serves, runs)
//   node test/e2e/checks/list_box_check.mjs [url]
import { join } from 'node:path';
import { e2e, hydrated, repo, settle, trackHydration } from './lib/e2e.mjs';

// `AXE=<path to axe.min.js>` uses another copy of axe-core.
const AXE = process.env.AXE ?? join(repo, 'test/e2e/runner/node_modules/axe-core/axe.min.js');

await e2e('list-box', { site: 'test/fixtures/apps/lab/build/site', path: 'list-box' }, async (t) => {
  // --- With JS ---------------------------------------------------------------
  {
    const page = await t.page({ viewport: { width: 1000, height: 1200 } });
    await trackHydration(page);
    await page.goto(t.url);
    await page.mouse.move(1, 1); // the first pointer event loads the engine
    await page.mouse.down();
    await page.mouse.up();
    t.check('engine hydrates', await hydrated(page).then(() => true, () => false));

    const people = page.getByRole('listbox', { name: 'People', exact: true });
    const read = () =>
      people.evaluate((s) => ({
        options: [...s.options].map((o) => o.textContent),
        chosen: [...s.selectedOptions].map((o) => o.textContent),
        size: s.size,
        multiple: s.multiple,
      }));
    const text = (id) => page.locator(`#${id}`).innerText().then((x) => x.replace(/\s+/g, ' '));
    const field = (label) => page.getByLabel(label, { exact: true });
    const until = async (label, fn, arg) => {
      const got = await settle(page, fn, arg);
      t.check(label, got === true, got === true ? '' : JSON.stringify(await read()) + ' ' + (await text('crud')));
    };
    const crudSays = (want) => (w) => document.querySelector('#crud').innerText.replace(/\s+/g, ' ').includes(w);

    const first = await read();
    t.check(
      'CRUD: a native listbox of the people, nobody chosen',
      first.options.join('|') === 'Emil, Hans|Mustermann, Max|Tisch, Roman' && first.chosen.length === 0 && first.size === 6 && !first.multiple,
      JSON.stringify(first),
    );
    t.check('CRUD: the count and no selection', (await text('crud')).includes('3 of 3') && (await text('crud')).includes('Selected: 0'));
    t.check('CRUD: Update starts disabled', await page.getByRole('button', { name: 'Update' }).isDisabled());

    await people.selectOption({ label: 'Mustermann, Max' });
    await until('CRUD: choosing an entry sets the state', crudSays(), 'Selected: 2');
    t.check('CRUD: the fields show the person', (await field('Name').inputValue()) === 'Max' && (await field('Surname').inputValue()) === 'Mustermann');
    t.check('CRUD: Update is enabled', await page.getByRole('button', { name: 'Update' }).isEnabled());

    await field('Filter prefix').fill('M');
    await until(
      'CRUD: the filter leaves the matching entry, still chosen',
      (w) => {
        const s = document.querySelector('select[aria-label="People"]');
        return [...s.options].map((o) => o.textContent).join('|') === w && s.selectedOptions[0]?.textContent === w;
      },
      'Mustermann, Max',
    );
    t.check('CRUD: the count follows the filter', (await text('crud')).includes('1 of 3'));
    await field('Filter prefix').fill('');
    await until('CRUD: clearing the filter brings every entry back', (w) => document.querySelector('select[aria-label="People"]').options.length === w, 3);

    await field('Name').fill('Ada');
    await field('Surname').fill('Lovelace');
    await page.getByRole('button', { name: 'Create' }).click();
    await until(
      'CRUD: Create adds an entry the state chooses',
      (w) => {
        const s = document.querySelector('select[aria-label="People"]');
        return s.options.length === 4 && s.selectedOptions.length === 1 && s.selectedOptions[0].textContent === w && s.selectedOptions[0].value === '4';
      },
      'Lovelace, Ada',
    );
    await until('CRUD: and the page says so', crudSays(), 'Selected: 4');

    await people.selectOption({ label: 'Emil, Hans' });
    await until('CRUD: choosing another one', crudSays(), 'Selected: 1');
    await field('Name').fill('Hansi');
    await page.getByRole('button', { name: 'Update' }).click();
    await until(
      'CRUD: Update rewrites the entry in place, still chosen',
      (w) => {
        const s = document.querySelector('select[aria-label="People"]');
        return s.options[0].textContent === w && s.selectedOptions[0]?.textContent === w;
      },
      'Emil, Hansi',
    );

    await page.getByRole('button', { name: 'Delete' }).click();
    await until(
      'CRUD: Delete removes the entry and the selection',
      (w) => {
        const s = document.querySelector('select[aria-label="People"]');
        return [...s.options].map((o) => o.textContent).join('|') === w && s.selectedOptions.length === 0;
      },
      'Mustermann, Max|Tisch, Roman|Lovelace, Ada',
    );
    await until('CRUD: nobody chosen after Delete', crudSays(), 'Selected: 0');

    // The keyboard is the browser's: arrows choose, and report the change.
    await people.focus();
    await page.keyboard.press('ArrowDown');
    await until('keyboard: an arrow chooses the first entry', crudSays(), 'Selected: 2');
    await page.keyboard.press('End');
    await until('keyboard: End chooses the last one', crudSays(), 'Selected: 4');
    await page.keyboard.press('t');
    await until('keyboard: type-ahead finds an entry', crudSays(), 'Selected: 3');

    // The static lists report to their state.
    const language = page.getByRole('listbox', { name: 'Language', exact: true });
    t.check('static: the value starts chosen', (await language.inputValue()) === 'en');
    await language.selectOption('fr');
    await until('static: one value reaches the state', (w) => document.querySelector('#picks').innerText.includes(w), 'Language: fr');
    t.check('static: a disabled entry is disabled', await language.locator('option[value=de]').evaluate((o) => o.disabled));

    const toppings = page.getByRole('listbox', { name: 'Toppings', exact: true });
    t.check('static: several start chosen', JSON.stringify(await toppings.evaluate((s) => [...s.selectedOptions].map((o) => o.value))) === '["cheese"]');
    await toppings.selectOption(['ham', 'olives']);
    await until('static: every chosen value reaches the state, as a Set', (w) => document.querySelector('#picks').innerText.includes(w), 'Toppings: ham,olives');
    await toppings.click({ modifiers: [process.platform === 'darwin' ? 'Meta' : 'Control'], position: { x: 20, y: 12 } });
    await until('static: a Ctrl/Cmd click adds one', (w) => document.querySelector('#picks').innerText.includes(w), 'Toppings: cheese,ham,olives');

    t.check('static: onChanged null disables the list', await page.getByRole('listbox', { name: 'Locked language' }).isDisabled());

    // The look: the chosen entry takes the theme's selected tile colors.
    const look = await people.evaluate((s) => {
      const o = s.selectedOptions[0] ?? s.options[0];
      return { chosen: getComputedStyle(o).backgroundColor, select: getComputedStyle(s).borderTopStyle };
    });
    t.check('look: an outlined box, the chosen entry filled', look.select === 'solid' && look.chosen !== 'rgba(0, 0, 0, 0)', JSON.stringify(look));

    // axe-core on the page: no violation in the list boxes' parts.
    await page.addScriptTag({ path: AXE });
    const axe = await page.evaluate(async () => {
      const r = await window.axe.run(document, { resultTypes: ['violations'] });
      return r.violations.map((v) => `${v.id} (${v.impact}): ${v.nodes.map((n) => n.target.join(' ')).join(', ')}`);
    });
    t.check('axe-core: no violations', axe.length === 0, axe.join('; '));

    t.check('no page errors', page.problems.length === 0, page.problems.join(' | '));
  }

  // --- Without JS: the form sends both kinds ----------------------------------
  {
    const page = await t.page({ viewport: { width: 1000, height: 1200 }, javaScriptEnabled: false });
    await page.goto(t.url, { waitUntil: 'load' });
    const people = await page.getByRole('listbox', { name: 'People', exact: true }).evaluate((s) => [...s.options].map((o) => o.textContent).join('|'));
    t.check('no JS: the CRUD list is in the page', people === 'Emil, Hans|Mustermann, Max|Tisch, Roman', people);
    const lang = page.getByRole('listbox', { name: 'Form language', exact: true });
    t.check('no JS: the form list is enabled with its value', (await lang.isEnabled()) && (await lang.inputValue()) === 'es');
    await lang.selectOption('fr');
    await page.getByRole('listbox', { name: 'Form toppings', exact: true }).selectOption(['cheese', 'pepper']);
    await Promise.all([page.waitForURL(/\?/), page.getByRole('button', { name: 'Send' }).click()]);
    const sent = new URL(page.url()).searchParams;
    t.check(
      'no JS: the form sends one value and every chosen one',
      sent.get('lang') === 'fr' && sent.getAll('top').join(',') === 'cheese,pepper',
      page.url(),
    );
  }
});

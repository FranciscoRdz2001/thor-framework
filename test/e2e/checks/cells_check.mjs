// test/fixtures/apps/cells (7GUIs Cells) in a real browser: each
// cell computes from the cells it reads (`cells.value[name]`, one entry per
// reader in the lite engine), so the texts must follow every edit: A1 with
// 100 dependents and their total, a formula written after the page loaded
// (a new dependency), a cell emptied, Escape that does not commit; no
// console errors.
//
//   tool/thor e2e cells                   (exports test/fixtures/apps/cells, runs)
//   node test/e2e/checks/cells_check.mjs
import { e2e, settle } from './lib/e2e.mjs';

const COLS = 26;
const index = (name) => name.charCodeAt(0) - 65 + (Number(name.slice(1)) - 1) * COLS;
const cell = (name) => `[data-tt="CellsViewModel.text~${index(name)}"]`;

await e2e('cells', { site: 'test/fixtures/apps/cells/build/site' }, async (t) => {
  const page = await t.page({ viewport: { width: 1280, height: 900 } });
  await page.goto(t.url, { waitUntil: 'networkidle' });
  const text = (name) => page.locator(cell(name)).first().textContent();
  const wait = (name, want) =>
    settle(page, ([s, w]) => document.querySelector(s)?.textContent === w, [cell(name), want]).then(
      () => text(name),
    );
  const edit = async (name, value, key = 'Enter') => {
    await page.locator(cell(name)).first().dblclick();
    const input = page.getByLabel('Cell formula');
    await input.fill(value);
    await input.press(key);
  };

  t.check('the server drew the formulas', (await text('A4')) === '6' && (await text('B1')) === '2');

  await page.getByText('Load 100 dependents of A1').click();
  t.check('C1 sums the 100 dependents', (await wait('C1', '5150')) === '5150');
  t.check('the loaded map dropped A4', (await wait('A4', '')) === '');

  await edit('A1', '7');
  t.check('C1 follows A1', (await wait('C1', '5750')) === '5750');
  t.check('B100 follows A1', (await text('B100')) === '107');
  t.check('B1 follows A1', (await text('B1')) === '8');

  await edit('D5', '=A1*2+C1');
  t.check('a formula written later reads A1 and C1', (await wait('D5', '5764')) === '5764');
  await edit('A1', '1');
  t.check('the new dependency follows A1', (await wait('D5', '5152')) === '5152');

  await edit('B1', '');
  t.check('an emptied cell leaves the sum', (await wait('C1', '5148')) === '5148');
  t.check('and shows nothing', (await text('B1')) === '');

  await edit('A1', '9', 'Escape');
  await page.waitForTimeout(100);
  t.check('Escape does not commit', (await text('A1')) === '1' && (await text('C1')) === '5148');

  t.check('no console errors', page.problems.length === 0, page.problems.join(' | '));
});

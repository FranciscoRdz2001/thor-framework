// test/fixtures/apps/grid (a spreadsheet-like data grid, 2,000 records) in a
// real browser: keyboard navigation, editing (also by typing on a cell),
// copy/paste as tab-separated text, undo/redo, filter, sort, group, hidden
// fields, search, live column resize, native row checkboxes, bulk actions,
// the expanded record (a native modal drawer), virtualization (rows in the
// DOM), the ARIA grid (roles, row and column indices, selected cells, links
// and the active cell read aloud; from Chromium's accessibility tree) and the view in the URL; then the
// same URL without JavaScript (the
// server renders the view).
//
//   tool/thor e2e grid                     (builds test/fixtures/apps/grid, runs)
//   node test/e2e/checks/grid_check.mjs
import { join } from 'node:path';
import { e2e, hydrated, repo, serveApp, settle, trackHydration } from './lib/e2e.mjs';

// Throws, with the server's output, if it does not start.
const app = join(repo, 'test/fixtures/apps/grid');
const { url: base } = await serveApp({ bin: join(app, 'build/server'), cwd: app });
process.argv.push(base);

const cell = (row, col) => `[data-tk="r${row}"] .gc${col}`;
const name = (row) => `[data-tk="r${row}"] [data-tf="GridState.nameOf"]`;
const count = '[data-tt="GridState.recordCount"]';
const cssVar = (page, v) =>
  page.evaluate((v) => getComputedStyle(document.querySelector('.grid-root')).getPropertyValue(v), v);
const focused = (page) => page.evaluate(() => document.activeElement?.getAttribute('data-tfn') ?? '');
const rowsInDom = (page) => page.locator('[data-tk^="r"]').count();
// Chromium's accessibility tree (what a screen reader gets), without the
// ignored nodes.
const axTree = async (page) => {
  const cdp = await page.context().newCDPSession(page);
  const { nodes } = await cdp.send('Accessibility.getFullAXTree');
  await cdp.detach();
  return nodes.filter((n) => !n.ignored);
};
const axRole = (n) => n.role?.value;
const axProp = (n, name) => n.properties?.find((p) => p.name === name)?.value?.value;
// Every rendered record row: its number, aria-rowindex, and its link's
// href and text.
const recordRows = (page) =>
  page.$$eval('[role=grid] [data-tk^="r"]', (rows) =>
    rows.map((r) => ({
      number: Number(r.querySelector('[data-tf="GridState.numberOf"]').textContent),
      rowIndex: Number(r.getAttribute('aria-rowindex')),
      href: r.querySelector('a[data-tfa]')?.getAttribute('href') ?? null,
      text: r.querySelector('a[data-tfa]')?.textContent ?? '',
    })));
const linksMatch = (rows) => rows.every((r) => r.href === `https://${r.text}`);

await e2e('grid', { timeout: 180_000 }, async (t) => {
  const page = await t.page({
    viewport: { width: 1440, height: 900 },
    permissions: ['clipboard-read', 'clipboard-write'],
  });
  await trackHydration(page);
  await page.goto(t.url);
  await page.mouse.move(2, 2);
  await hydrated(page);

  t.check('first screen: a window of rows, not 2,000', (await rowsInDom(page)) <= 60, `${await rowsInDom(page)} rows`);
  t.check('2,000 records in the footer', (await page.textContent(count)) === '2000 records');

  // ARIA grid: Chromium's accessibility tree.
  const ax = await axTree(page);
  const byRole = (r) => ax.filter((n) => axRole(n) === r);
  const grids = byRole('grid');
  t.check('one grid, named', grids.length === 1 && grids[0].name?.value === 'Launches');
  t.check('the grid counts every row, not the window',
    (await page.getAttribute('[role=grid]', 'aria-rowcount')) === '2001' &&
    (await page.getAttribute('[role=grid]', 'aria-colcount')) === '13');
  const rendered = await rowsInDom(page);
  t.check('rows, column headers, row headers and cells in the tree',
    byRole('row').length === rendered + 1 && byRole('columnheader').length === 13 &&
    byRole('rowheader').length === rendered && byRole('gridcell').length >= rendered * 11,
    `${byRole('row').length} rows, ${byRole('columnheader').length} headers, ` +
    `${byRole('rowheader').length} row headers, ${byRole('gridcell').length} cells`);
  t.check('the active cell is selected',
    ax.filter((n) => ['gridcell', 'rowheader'].includes(axRole(n)) && axProp(n, 'selected') === true).length === 1);
  const links = byRole('link').filter((n) => String(axProp(n, 'url')).startsWith('https://launch.example.com/'));
  t.check('the URL column is a link per row', links.length === rendered, `${links.length} links`);
  const initial = await recordRows(page);
  t.check('rows know their place (the header is row 1)', initial.every((r) => r.rowIndex === r.number + 1));
  t.check('row controls are named after their record',
    (await page.getAttribute('[data-tk="r1"] input[type=checkbox]', 'aria-label')) ===
      `Select ${await page.textContent(name(1))}`);

  // Selection and keyboard.
  await page.click(cell(1, 1));
  t.check('a click selects the cell and focuses the grid', (await focused(page)) === 'GridState.cellFocus');
  const top = await cssVar(page, '--sel-top');
  await page.keyboard.press('ArrowDown');
  await page.keyboard.press('ArrowRight');
  t.check('arrows move the selection', (await cssVar(page, '--sel-top')) !== top && (await cssVar(page, '--sel-x')) === '140px');
  const said = await page.textContent('[aria-live="polite"]');
  t.check('a live region reads the active cell', /^Platforms, .+: /.test(said.trim()), said);
  await page.keyboard.press('Shift+ArrowDown');
  await page.keyboard.press('Shift+ArrowDown');
  t.check('Shift+arrows extend a range', (await cssVar(page, '--sel-h')) === '96px');
  const selected = await page.$$eval('[role=grid] [aria-selected="true"]', (els) =>
    els.map((e) => e.getAttribute('aria-colindex')));
  t.check('aria-selected follows the range', selected.length === 3 && selected.every((c) => c === '4'), selected.join(' '));
  await page.keyboard.press('Tab');
  t.check('Tab moves to the next cell (and collapses the range)', (await cssVar(page, '--sel-h')) === '32px');

  // Edit the primary field, undo, redo.
  const before = await page.textContent(name(2));
  await page.click(name(2));
  await page.keyboard.press('Enter');
  t.check('Enter opens the text editor with the value', (await focused(page)) === 'GridState.leadEditorFocus' &&
    (await page.evaluate(() => document.activeElement.value)) === before);
  await page.keyboard.type(' X');
  await page.keyboard.press('Enter');
  t.check('Enter saves', (await page.textContent(name(2))) === `${before} X`);
  await page.keyboard.press('Escape');
  await page.click(name(4));
  await page.keyboard.press('Enter');
  await page.keyboard.type('nope');
  await page.keyboard.press('Escape');
  t.check('Escape cancels an edit', !(await page.textContent(name(4))).endsWith('nope'));
  await page.keyboard.press('Meta+z');
  t.check('⌘Z undoes', (await page.textContent(name(2))) === before);
  await page.keyboard.press('Meta+Shift+z');
  t.check('⇧⌘Z redoes', (await page.textContent(name(2))) === `${before} X`);

  // Type-specific editors.
  await page.click(cell(1, 1));
  await page.keyboard.press('Enter');
  await page.keyboard.type('pau');
  await page.keyboard.press('Enter');
  t.check('select editor: search and pick with Enter', (await page.textContent(cell(1, 1))) === 'Paused');
  await page.click(cell(1, 5));
  await page.keyboard.press('Enter');
  await page.keyboard.press('ControlOrMeta+a');
  await page.keyboard.type('123456');
  await page.keyboard.press('Enter');
  t.check('number editor', (await page.textContent(cell(1, 5))) === '$123,456');
  const link = `${cell(2, 9)} a`;
  const href = await page.getAttribute(link, 'href');
  // (A click on the link would open it: select the cell from its neighbor.)
  await page.click(cell(2, 10));
  await page.keyboard.press('ArrowLeft');
  await page.keyboard.press('Enter');
  await page.keyboard.press('ControlOrMeta+a');
  await page.keyboard.type('javascript:alert(1)');
  await page.keyboard.press('Enter');
  t.check('a javascript: URL typed into a cell is no link',
    (await page.textContent(link)) === 'javascript:alert(1)' && (await page.getAttribute(link, 'href')) === null);
  await page.keyboard.press('Meta+z');
  t.check('undo gives the link its address back', (await page.getAttribute(link, 'href')) === href);
  await page.evaluate(() => (document.querySelector('[data-tsc]').scrollLeft = 0));
  await page.click(cell(3, 7), { position: { x: 70, y: 10 } });
  const box = page.locator(`${cell(3, 7)} input[type=checkbox]`);
  const shipped = await box.isChecked();
  await page.keyboard.press('Space');
  t.check('Space toggles a checkbox cell (a native checkbox)', (await box.isChecked()) !== shipped);
  await box.click();
  t.check('a click on the checkbox toggles it back', (await box.isChecked()) === shipped);

  // Typing on a cell edits it, starting with that character.
  const typedBefore = await page.textContent(name(7));
  await page.click(name(7));
  await page.keyboard.type('Zed');
  t.check('typing on a cell opens its editor with the character', (await focused(page)) === 'GridState.leadEditorFocus' &&
    (await page.evaluate(() => document.activeElement.value)) === 'Zed');
  await page.keyboard.press('Enter');
  t.check('… and Enter saves it', (await page.textContent(name(7))) === 'Zed' && typedBefore !== 'Zed');

  // Copy and paste as tab-separated text (as spreadsheets do).
  await page.click(name(8));
  await page.keyboard.press('Shift+ArrowDown');
  await page.keyboard.press('Shift+ArrowRight');
  await page.keyboard.press('Meta+c');
  const copied = await page.evaluate(() => navigator.clipboard.readText());
  const lines = copied.split('\n');
  t.check('⌘C copies the range as TSV', lines.length === 2 && lines.every((l) => l.split('\t').length === 2) &&
    lines[0].startsWith(await page.textContent(name(8))), JSON.stringify(copied));
  const status8 = await page.textContent(cell(8, 1));
  const text = (sel) => page.evaluate((s) => document.querySelector(s)?.textContent, sel);
  const name10 = await text(name(10));
  await page.click(name(10));
  await page.keyboard.press('Meta+v');
  t.check('⌘V pastes the block', (await settle(page, ([a, b]) =>
    document.querySelector(a)?.textContent === document.querySelector(b)?.textContent, [name(10), name(8)])) &&
    (await text(cell(10, 1))) === status8 &&
    (await cssVar(page, '--sel-h')) === '64px', await cssVar(page, '--sel-h'));
  const range = [await text(cell(12, 1)), await text(cell(13, 1))];
  const one = ['Idea', 'Planned', 'Paused'].find((x) => !range.includes(x));
  await page.evaluate((v) => navigator.clipboard.writeText(v), one);
  await page.click(cell(12, 1));
  await page.keyboard.press('Shift+ArrowDown');
  await page.keyboard.press('Meta+v');
  t.check('one value fills the selected range', (await settle(page,
    ([v, s]) => s.every((x) => document.querySelector(x)?.textContent === v), [one, [cell(12, 1), cell(13, 1)]])) === true);
  await page.keyboard.press('Meta+z');
  t.check('a paste is one undo step', (await text(cell(12, 1))) === range[0] && (await text(cell(13, 1))) === range[1],
    JSON.stringify(range));
  // The data goes back as the server has it (the reload check below).
  await page.keyboard.press('Meta+z');
  t.check('… and so is the block', (await text(name(10))) === name10);
  await page.locator(`${cell(4, 8)} button`).nth(4).click();
  t.check('a click on a star rates', (await page.locator(`${cell(4, 8)} [aria-label]`).count()) === 5);

  // Virtualization.
  await page.evaluate(() => (document.querySelector('[data-tsc]').scrollTop = 32 * 1000));
  const first = await settle(page, () => {
    const n = Number(document.querySelector('[data-tk^="r"] [data-tf="GridState.numberOf"]')?.textContent);
    return n > 900 ? n : 0;
  });
  t.check('scrolling renders the rows in view', first > 900, `first row ${first}`);
  t.check('still a window of rows after scrolling', (await rowsInDom(page)) <= 60, `${await rowsInDom(page)} rows`);
  const scrolled = await recordRows(page);
  t.check('rows rendered on scroll: row index and link follow each record',
    scrolled.every((r) => r.rowIndex === r.number + 1) && linksMatch(scrolled),
    scrolled.filter((r) => r.rowIndex !== r.number + 1 || r.href !== `https://${r.text}`)
      .map((r) => `${r.number}:${r.rowIndex}:${r.href}`).slice(0, 3).join(' '));
  await page.evaluate(() => (document.querySelector('[data-tsc]').scrollTop = 0));

  // Column resize (drag the header edge).
  const edge = await page.locator('[aria-label="Resize Status"]').boundingBox();
  await page.mouse.move(edge.x + 3, edge.y + 10);
  await page.mouse.down();
  await page.mouse.move(edge.x + 50, edge.y + 10, { steps: 5 });
  const live = await settle(page, () =>
    getComputedStyle(document.querySelector('.grid-root')).getPropertyValue('--w1') === '187px');
  t.check('the column follows the pointer while dragging', live === true, await cssVar(page, '--w1'));
  await page.mouse.move(edge.x + 103, edge.y + 10, { steps: 5 });
  await page.mouse.up();
  t.check('dragging a header edge resizes the column', (await settle(page, () =>
    getComputedStyle(document.querySelector('.grid-root')).getPropertyValue('--w1') === '240px')) === true);

  // Row checkboxes and bulk actions.
  await page.hover('[data-tk="r2"]');
  await page.click('[data-tk="r2"] [aria-label^="Select "]');
  await page.hover('[data-tk="r5"]');
  await page.click('[data-tk="r5"] [aria-label^="Select "]');
  t.check('checked rows show the bulk bar', (await page.textContent('[data-tt="GridState.checkedLabel"]')) === '2 records selected');
  await page.getByRole('button', { name: 'Clear selection' }).click();
  t.check('a row checkbox follows the state after the user touched it',
    !(await page.isChecked('[data-tk="r2"] input[type=checkbox]')));
  await page.hover('[data-tk="r2"]');
  await page.click('[data-tk="r2"] input[type=checkbox]');
  await page.hover('[data-tk="r5"]');
  await page.click('[data-tk="r5"] input[type=checkbox]');
  await page.click('[popovertarget="pop-bulk-status"]');
  await page.click('#pop-bulk-status >> text=Beta');
  t.check('bulk: set status', (await page.textContent(cell(2, 1))) === 'Beta' && (await page.textContent(cell(5, 1))) === 'Beta');
  await page.keyboard.press('Escape');
  await page.getByRole('button', { name: 'Delete' }).click();
  t.check('bulk: delete', (await page.textContent(count)) === '1998 records' && (await page.locator('[data-tk="r2"]').count()) === 0);
  await page.click(cell(1, 1));
  await page.keyboard.press('Meta+z');
  t.check('undo brings deleted rows back', (await page.textContent(count)) === '2000 records');

  // Expanded record.
  await page.hover('[data-tk="r6"]');
  await page.click('[data-tk="r6"] [aria-label^="Expand "]');
  t.check('expand opens the drawer (a native modal)', await page.isVisible('[data-tt="GridState.drawerTitle"]') &&
    (await page.evaluate(() => document.querySelector('dialog[data-tdc]').matches(':modal'))));
  await page.locator('[data-ttc="GridState.drawerName"]').fill('Edited in the drawer');
  t.check('drawer edits reach the grid', (await page.textContent(name(6))) === 'Edited in the drawer');
  // Closed once its slide-out ends (the title leaves the rendering).
  const drawerGone = () => settle(page, () => !document.querySelector('[data-tt="GridState.drawerTitle"]').checkVisibility());
  await page.keyboard.press('Escape');
  t.check('Escape closes the drawer', await drawerGone());
  await page.click(cell(6, 1));
  await page.keyboard.press('Space');
  t.check('Space opens the drawer from the keyboard', await page.isVisible('[data-tt="GridState.drawerTitle"]'));
  await page.getByRole('button', { name: 'Close' }).click();
  t.check('its close button closes it and the focus goes back to the grid',
    (await drawerGone()) && (await focused(page)) === 'GridState.cellFocus', await focused(page));

  // Toolbar: filter, sort, group, hide, search — and the URL.
  await page.click('[popovertarget="pop-filter"]');
  await page.click('#pop-filter >> text=+ Add condition');
  await page.locator('#pop-filter select[aria-label="Field"]').first().selectOption('status');
  t.check('operators follow the field type', (await page.locator('#pop-filter select[aria-label="Operator"]').first().inputValue()) === 'isValue');
  await page.locator('#pop-filter [data-ttc="GridState.filterValue0"]').fill('Launched');
  const launched = await page.textContent(count);
  t.check('filter', launched !== '2000 records' && Number.parseInt(launched) > 0, launched);
  t.check('aria-rowcount follows the filter',
    (await page.getAttribute('[role=grid]', 'aria-rowcount')) === String(Number.parseInt(launched) + 1));
  await page.keyboard.press('Escape');
  await page.click('[popovertarget="pop-sort"]');
  await page.click('#pop-sort >> text=+ Add sort');
  await page.locator('#pop-sort select[aria-label="Sort field"]').first().selectOption('budget');
  await page.locator('#pop-sort select[aria-label="Direction"]').first().selectOption('desc');
  const budgets = await page.$$eval('[data-tk^="r"] [data-tf="GridState.budgetOf"]', (els) =>
    els.slice(0, 6).map((e) => Number(e.textContent.replace(/[$,]/g, ''))));
  t.check('sort', budgets.every((b, i) => i === 0 || budgets[i - 1] >= b), budgets.join(' '));
  const sorted = await recordRows(page);
  t.check('reordered rows: indices by position, links by record',
    sorted.every((r, i) => i === 0 || r.rowIndex === sorted[i - 1].rowIndex + 1) && linksMatch(sorted));
  await page.keyboard.press('Escape');
  await page.click('[popovertarget="pop-group"]');
  await page.locator('#pop-group select').selectOption('owner');
  await page.keyboard.press('Escape');
  const group = await page.locator('[data-tk^="g"]').first().getAttribute('data-tk');
  t.check('group headers', group !== null);
  const rowsBefore = await rowsInDom(page);
  await page.click(`[data-tk="${group}"] [data-tf="GridState.nameOf"]`);
  t.check('a click collapses a group', (await page.locator(`[data-tk="${group}"]`).getAttribute('data-tvi')) === '5' ||
    (await rowsInDom(page)) !== rowsBefore);
  await page.click(`[data-tk="${group}"] [data-tf="GridState.nameOf"]`);
  await page.click('[popovertarget="pop-hide"]');
  await page.locator('#pop-hide input[type=checkbox]').nth(9).click();
  await page.keyboard.press('Escape');
  t.check('hide a field', !(await page.locator(`[data-tk^="r"] .gc10`).first().isVisible()));
  await page.fill('input[name=q]', 'aurora');
  const found = await page.textContent('[data-tt="GridState.searchCount"]');
  await page.keyboard.press('Enter');
  const next = await page.textContent('[data-tt="GridState.searchCount"]');
  t.check('search counts matches and Enter goes to the next', /^1 of \d+$/.test(found) && /^2 of \d+$/.test(next), `${found} → ${next}`);
  const url = new URL(page.url());
  t.check('the view is in the URL', ['f', 's', 'g', 'h', 'q'].every((k) => url.searchParams.has(k)), url.search);
  t.check('no errors in the console', page.problems.length === 0, page.problems.join(' | '));

  // Reload: the server renders the same view.
  await page.reload();
  await hydrated(page);
  t.check('reload keeps the view', (await page.textContent(count)) === launched &&
    (await page.inputValue('input[name=q]')) === 'aurora');

  // Without JavaScript: the URL's view, read-only; the search box posts.
  const nojs = await t.page({ javaScriptEnabled: false, viewport: { width: 1440, height: 900 } });
  await nojs.goto(`${t.url}?f=status:isValue:Beta&s=budget:desc`);
  const noJsCount = await nojs.textContent(count);
  const noJsBudgets = await nojs.$$eval('[data-tk^="r"] [data-tf="GridState.budgetOf"]', (els) =>
    els.slice(0, 6).map((e) => Number(e.textContent.replace(/[$,]/g, ''))));
  t.check('no JS: filtered and sorted from the URL', noJsCount !== '2000 records' &&
    noJsBudgets.every((b, i) => i === 0 || noJsBudgets[i - 1] >= b), `${noJsCount} ${noJsBudgets.join(' ')}`);
  await nojs.fill('input[name=q]', 'zephyr');
  await Promise.all([nojs.waitForNavigation(), nojs.press('input[name=q]', 'Enter')]);
  t.check('no JS: the search form is a GET', new URL(nojs.url()).searchParams.get('q') === 'zephyr' &&
    /of \d+/.test(await nojs.textContent('[data-tt="GridState.searchCount"]')));
});

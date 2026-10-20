// The date and time pickers of test/fixtures/apps/lab (/dates) in a real browser: the calendar
// (mouse, keyboard, month event), the dialog (OK, Esc, a controller), the
// date field in a GET form with and without JavaScript, and the time dialog.
//
//   tool/thor e2e dates                      (builds, serves, runs)
//   node test/e2e/checks/dates_check.mjs [url]
import { e2e, hydrated, settle, trackHydration } from './lib/e2e.mjs';

await e2e('dates', { site: 'test/fixtures/apps/lab/build/site', path: 'dates' }, async (t) => {
  // --- With JavaScript.
  const page = await t.page({ viewport: { width: 480, height: 1600 } });
  await trackHydration(page);
  await page.goto(t.url);
  await page.mouse.move(1, 1); // the first pointer event loads the engine
  await page.mouse.down();
  await page.mouse.up();
  t.check('engine hydrates', await hydrated(page).then(() => true, () => false));

  const text = (sel) => page.locator(sel).first().textContent();
  const expectText = async (label, sel, want) => {
    const got = await settle(page, ([s, w]) => document.querySelector(s)?.textContent === w, [sel, want]);
    t.check(label, got === true, got === true ? '' : `${JSON.stringify(await text(sel))}, expected ${JSON.stringify(want)}`);
  };
  const cal = page.locator('main [data-t-date]').first();
  const day = (root, n) => root.locator('td', { hasText: new RegExp(`^${n}$`) });
  const month = (root) => root.locator('[data-t-years] [aria-live]').textContent();

  // Inline calendar.
  await cal.locator('[data-t-nav="1"]').click();
  t.check('next month', (await month(cal)) === 'October 2026', await month(cal));
  await expectText('onDisplayedMonthChanged', '[data-tt="DatesState.shownLabel"]', 'Mes a la vista: 2026-10');
  await day(cal, 7).click();
  await expectText('picking a day calls onDateChanged', '[data-tt="DatesState.dayLabel"]', 'Elegiste: 2026-10-07');
  await page.keyboard.press('ArrowRight');
  await page.keyboard.press('ArrowDown');
  await page.keyboard.press('Enter');
  await expectText('arrows move, Enter picks', '[data-tt="DatesState.dayLabel"]', 'Elegiste: 2026-10-15');
  await page.keyboard.press('PageDown');
  t.check('Page Down: next month', (await month(cal)) === 'November 2026', await month(cal));
  await cal.locator('[data-t-years]').click();
  await cal.locator('[data-t-year-list] button', { hasText: '2027' }).click();
  t.check('the year list', (await month(cal)) === 'November 2027', await month(cal));

  // Dialog, weekends disabled.
  const due = page.locator('dialog#due');
  await page.getByRole('button', { name: 'Elegir entrega' }).click();
  t.check('the trigger opens the dialog', await due.evaluate((d) => d.open));
  t.check('focus on the calendar', await page.evaluate(() => document.activeElement?.localName === 'td'));
  await day(due, 26).click({ force: true }); // a Saturday (aria-disabled)
  t.check('a disabled day is not picked', (await due.locator('[data-t-headline]').textContent()) === 'Date');
  await day(due, 22).click();
  t.check('the headline follows', (await due.locator('[data-t-headline]').textContent()) === 'Tue, Sep 22');
  await due.getByRole('button', { name: 'OK' }).click();
  await expectText('OK calls onDatePicked', '[data-tt="DatesState.dueLabel"]', 'Entrega: 2026-09-22');
  t.check('OK closes', !(await due.evaluate((d) => d.open)));
  await page.getByRole('button', { name: 'Desde el estado' }).click();
  t.check('a DialogController opens it', await settle(page, () => document.querySelector('dialog#due').open) === true);
  await day(due, 24).click();
  await page.keyboard.press('Escape');
  await settle(page, () => !document.querySelector('dialog#due').open);
  t.check('Esc drops the change', (await text('[data-tt="DatesState.dueLabel"]')) === 'Entrega: 2026-09-22');
  const reset = await settle(page, () => document.querySelector('dialog#due [data-t-headline]').textContent === 'Tue, Sep 22');
  t.check('and resets the dialog', reset === true, await due.locator('[data-t-headline]').textContent());

  // The date field (Spanish), in a GET form.
  const field = page.locator('#from-input');
  const open = page.locator('[data-t-date-open]');
  t.check('the calendar button shows with the engine', await open.isVisible());
  await field.fill('2026-11-02');
  await open.click();
  const fromDialog = page.locator('dialog#from');
  t.check('the field dialog opens', await fromDialog.evaluate((d) => d.open));
  t.check('it starts from the typed date', (await month(fromDialog)) === 'noviembre de 2026', await month(fromDialog));
  await day(fromDialog, 12).click();
  await fromDialog.getByRole('button', { name: 'Aceptar' }).click();
  t.check('OK writes into the field', (await field.inputValue()) === '2026-11-12', await field.inputValue());
  await page.getByRole('button', { name: 'Buscar' }).click();
  await page.waitForURL(/from=/);
  t.check('the form posts yyyy-mm-dd', new URL(page.url()).searchParams.get('from') === '2026-11-12', page.url());

  // Time.
  await page.goto(t.url);
  await hydrated(page).catch(() => {});
  await page.getByRole('button', { name: 'Elegir hora' }).click();
  await hydrated(page).catch(() => {});
  const timeDialog = page.locator('dialog#time');
  await settle(page, () => document.querySelector('dialog#time').open);
  await timeDialog.locator('input[type=time]').fill('14:45');
  await timeDialog.getByRole('button', { name: 'OK' }).click();
  await expectText('OK calls onTimePicked', '[data-tt="DatesState.atLabel"]', 'Hora: 14:45');
  t.check('no page errors', page.problems.length === 0, page.problems.join(' | '));

  // --- Without JavaScript: the native date input is the whole field.
  const plain = await t.page({ viewport: { width: 480, height: 1600 }, javaScriptEnabled: false });
  await plain.goto(t.url);
  t.check('no calendar button without JS', !(await plain.locator('[data-t-date-open]').isVisible()));
  await plain.locator('#from-input').fill('2026-12-03');
  await plain.getByRole('button', { name: 'Buscar' }).click();
  await plain.waitForURL(/from=/);
  const q = new URL(plain.url()).searchParams;
  t.check('no JS: the form posts the typed date', q.get('from') === '2026-12-03', plain.url());
  t.check('no JS: an empty optional date posts empty', q.get('to') === '', plain.url());
});

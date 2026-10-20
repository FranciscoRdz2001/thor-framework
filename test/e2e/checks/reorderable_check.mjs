// `ReorderableListView` of test/fixtures/apps/lab (/drag) in a real browser, with either engine: a
// live list (rows the browser clones) reordered by its handles, by a held
// finger and by the keyboard, the state and the page agreeing, a horizontal row
// with handles of its own, the page scrolling at its edge, RTL, reduced motion
// and the page with no JavaScript.
//
//   tool/thor e2e reorderable reorderable-dart          (builds, serves, runs)
//   E2E_BROWSER=firefox tool/thor e2e reorderable       (or webkit)
//   node test/e2e/checks/reorderable_check.mjs [url]
import { e2e, hydrated, settle, trackHydration } from './lib/e2e.mjs';

await e2e('reorderable', { site: 'test/fixtures/apps/lab/build/site', path: 'drag' }, async (t) => {
  const page = await t.page({ viewport: { width: 480, height: 640 } });
  await trackHydration(page);
  await page.goto(t.url);
  await page.mouse.move(1, 1); // the first pointer event loads the engine
  await page.mouse.down();
  await page.mouse.up();
  t.check('engine hydrates', await hydrated(page).then(() => true, () => false));

  const text = (sel) => page.locator(sel).first().textContent();
  const expectText = async (label, sel, want) => {
    const got = await settle(page, ([s, w]) => document.querySelector(s)?.textContent === w, [sel, want], { timeout: 6000 });
    t.check(label, got === true, got === true ? '' : `${JSON.stringify(await text(sel))}, expected ${JSON.stringify(want)}`);
  };
  const order = '[data-tt="ReorderState.order"]';
  const status = '[data-tt="ReorderState.status"]';
  const events = '[data-tt="ReorderState.eventsLabel"]';
  const chipOrder = '[data-tt="ReorderState.chipOrder"]';
  const list = page.locator('[data-t-ro][data-tl="ReorderState.todos"]');
  const chips = page.locator('[data-t-ro][data-t-ro-cfg^="h"]');
  // The titles of the items, in the page's order, and their keys.
  const titles = () => list.evaluate((l) => [...l.children].filter((c) => c.hasAttribute('data-t-ro-item')).map((c) => c.textContent.trim()));
  const keys = () => list.evaluate((l) => [...l.children].filter((c) => c.hasAttribute('data-t-ro-item')).map((c) => c.dataset.tk));
  const item = (title) => list.locator('[data-t-ro-item]', { hasText: title });
  const handle = (title) => item(title).locator('[data-t-ro-h]');
  const center = async (loc) => {
    await loc.scrollIntoViewIfNeeded();
    const b = await loc.boundingBox();
    return { ...b, cx: b.x + b.width / 2, cy: b.y + b.height / 2 };
  };
  const tick = (ms = 40) => page.waitForTimeout(ms);
  // Drags the handle of an item `rows` rows down (or up, negative), by the pointer.
  const drag = async (title, rows, { up = true } = {}) => {
    const h = await center(handle(title));
    const row = await center(item(title));
    await page.mouse.move(h.cx, h.cy);
    await page.mouse.down();
    await page.mouse.move(h.cx, h.cy + Math.sign(rows) * 8, { steps: 2 });
    await tick(60);
    await page.mouse.move(h.cx, h.cy + (row.height + 8) * rows + Math.sign(rows) * 14, { steps: 8 });
    await tick(100);
    if (up) await page.mouse.up();
  };
  const settled = (n) => settle(page, (n) => !document.querySelector('[data-t-ro] > [data-t-ro-item][data-t-ro-settle], [data-t-ro] > [data-t-ro-item][data-t-ro-shift]') && document.querySelectorAll('[data-t-ro-drag]').length === 0 && n === n, n, { timeout: 5000 });

  // The markup.
  t.check('the list says it is one, and so are its items', (await list.getAttribute('role')) === 'list' && (await item('Pedir café').getAttribute('role')) === 'listitem');
  t.check('every item has a handle that is a named button', (await list.locator('[data-t-ro-item] > button[data-t-ro-h][aria-label="Reorder"]').count()) === 4);
  // The header and the footer are siblings of the list (`role="list"` holds
  // only its items), in the box around them.
  t.check('the header and the footer are not items', (await list.locator(':scope > :not([data-t-ro-item]):not(template)').count()) === 0);
  t.check(
    'the header and the footer are around the list',
    JSON.stringify(await list.evaluate((l) => [...l.parentElement.children].map((c) => (c === l ? 'list' : c.textContent.trim())))) === '["Lista","list","Fin de la lista"]',
    await list.evaluate((l) => l.parentElement.outerHTML.slice(0, 200)),
  );
  t.check('the order starts as the state\'s', JSON.stringify(await titles()) === '["Pedir café","Contar caja","Armar pedido","Cerrar turno"]', JSON.stringify(await titles()));

  // Drag the first item down over two others.
  await drag('Pedir café', 2, { up: false });
  const moving = await item('Pedir café').evaluate((e) => ({ drag: e.hasAttribute('data-t-ro-drag'), y: e.style.getPropertyValue('--t-ro-y') }));
  t.check('the dragged item follows the pointer (translate, no layout)', moving.drag && Number.parseFloat(moving.y) > 40, JSON.stringify(moving));
  const gave = await item('Contar caja').evaluate((e) => ({ shift: e.hasAttribute('data-t-ro-shift'), y: e.style.getPropertyValue('--t-ro-y') }));
  t.check('the ones it passed slide out of the way', gave.shift && Number.parseFloat(gave.y) < -20, JSON.stringify(gave));
  t.check('the page has not changed yet', JSON.stringify(await titles()) === '["Pedir café","Contar caja","Armar pedido","Cerrar turno"]');
  t.check('the dragged item is lifted', (await item('Pedir café').evaluate((e) => getComputedStyle(e).boxShadow)) !== 'none');
  await expectText('onReorderStart ran', events, 'inicio 0');
  await page.mouse.up();
  await expectText('the state heard it, with Flutter\'s indexes', status, 'a: 0 a 3');
  await expectText('and the order is the state\'s', order, 'Orden: b,c,a,d');
  await expectText('and the end was told, with the item\'s index', events, 'inicio 0 fin 2');
  t.check('the page has the same order', JSON.stringify(await titles()) === '["Contar caja","Armar pedido","Pedir café","Cerrar turno"]', JSON.stringify(await titles()));
  t.check('every row kept its key, in that order', JSON.stringify(await keys()) === '["b","c","a","d"]', JSON.stringify(await keys()));
  t.check('no offset or mark is left behind', await page.evaluate(() => [...document.querySelectorAll('[data-t-ro-item]')].every((e) => !e.style.getPropertyValue('--t-ro-y') && !e.hasAttribute('data-t-ro-shift') && !e.hasAttribute('data-t-ro-settle') && !e.hasAttribute('data-t-ro-drag'))));

  // Up.
  await drag('Cerrar turno', -3);
  await expectText('dragging up: the new index is where it lands', status, 'd: 3 a 0');
  await expectText('and the order follows', order, 'Orden: d,b,c,a');

  // Dropped where it was: nothing for the state to do.
  const before = await text(status);
  await drag('Contar caja', 0);
  await settle(page, () => document.querySelector('[data-tt="ReorderState.eventsLabel"]')?.textContent.endsWith('fin 1'), null, { timeout: 4000 });
  t.check('dropped where it was changes nothing', (await text(status)) === before && (await text(order)) === 'Orden: d,b,c,a', await text(order));

  // The keyboard (WCAG 2.5.7): Space on the handle, the arrows, Space.
  const live = () => page.locator('[aria-live="assertive"]').textContent();
  const liveIs = async (label, re) => {
    const ok = await settle(page, (src) => new RegExp(src).test(document.querySelector('[aria-live="assertive"]')?.textContent ?? ''), re.source, { timeout: 4000 });
    t.check(label, ok === true, await live().catch(() => ''));
  };
  await handle('Armar pedido').focus();
  t.check('the handle is named for its item when focused', (await handle('Armar pedido').getAttribute('aria-label')) === 'Reorder Armar pedido', await handle('Armar pedido').getAttribute('aria-label'));
  await page.keyboard.press('Space');
  await liveIs('Space picks up and says where', /^Picked up Armar pedido, position 3 of 4\./);
  await page.keyboard.press('ArrowUp');
  await liveIs('the arrow moves it and says where', /^Armar pedido, position 2 of 4\.$/);
  t.check('the item moved in the page', JSON.stringify(await titles()) === '["Cerrar turno","Armar pedido","Contar caja","Pedir café"]', JSON.stringify(await titles()));
  t.check('the focus stayed on the handle', (await page.evaluate(() => document.activeElement?.getAttribute('aria-label'))) === 'Reorder Armar pedido');
  t.check('the state has not heard it yet', (await text(order)) === 'Orden: d,b,c,a');
  await page.keyboard.press('Space');
  await liveIs('Space drops and says so', /^Dropped Armar pedido at position 2 of 4\.$/);
  await expectText('the state heard the drop', order, 'Orden: d,c,b,a');
  await handle('Contar caja').focus();
  await page.keyboard.press('Enter');
  await page.keyboard.press('ArrowUp');
  await page.keyboard.press('Escape');
  await liveIs('Escape says it is back', /^Cancelled\. Contar caja is back at position 3 of 4\.$/);
  t.check('Escape put it back', JSON.stringify(await titles()) === '["Cerrar turno","Armar pedido","Contar caja","Pedir café"]', JSON.stringify(await titles()));
  await handle('Pedir café').focus();
  await page.keyboard.press('Alt+ArrowUp');
  await expectText('Alt+arrow moves one place at once', order, 'Orden: d,c,a,b');

  // A row the browser cloned from the template.
  await page.locator('button', { hasText: 'Añadir pendiente' }).click();
  await settle(page, () => document.querySelectorAll('[data-tl="ReorderState.todos"] > [data-t-ro-item]').length === 5);
  const fresh = item('Nueva 0');
  t.check('a cloned row is an item with a handle too', (await fresh.getAttribute('role')) === 'listitem' && (await fresh.locator('button[data-t-ro-h]').count()) === 1);
  await drag('Nueva 0', -4);
  await expectText('and it is dragged like the others', order, 'Orden: n0,d,c,a,b');

  // A held finger on the row (touch) is covered below; a press on the text with a mouse is not a drag.
  const row = await center(item('Contar caja'));
  await page.mouse.move(row.x + 20, row.cy);
  await page.mouse.down();
  await page.mouse.move(row.x + 20, row.cy + 60, { steps: 4 });
  await tick(100);
  t.check('a mouse on the item (not its handle) does not drag', (await page.locator('[data-t-ro-drag]').count()) === 0);
  await page.mouse.up();

  // The page scrolls under a pointer near its edge.
  await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
  const top = await center(handle('Nueva 0'));
  await page.mouse.move(top.cx, top.cy);
  await page.mouse.down();
  await page.mouse.move(top.cx, top.cy - 8, { steps: 2 });
  await page.mouse.move(top.cx, 8, { steps: 4 });
  const y0 = await page.evaluate(() => window.scrollY);
  await page.waitForTimeout(600);
  const y1 = await page.evaluate(() => window.scrollY);
  t.check('the page scrolls while the pointer is near its top edge', y1 < y0, `${y0} -> ${y1}`);
  await page.mouse.up();
  await settled(0);
  await page.evaluate(() => window.scrollTo(0, 0));

  // A row of chips with handles of its own (a ReorderableDragStartListener), static, horizontal.
  const chipTitles = () => chips.evaluate((l) => [...l.children].filter((c) => c.hasAttribute('data-t-ro-item')).map((c) => c.textContent.trim()));
  t.check('the chips have no default handle, only their own', (await chips.locator('button[data-t-ro-h]').count()) === 0 && (await chips.locator('[data-t-ro-h]').count()) === 3);
  const chipHandle = (name) => chips.locator('[data-t-ro-item]', { hasText: name }).locator('[data-t-ro-h]');
  const ch = await center(chipHandle('uno'));
  const target = await center(chipHandle('dos'));
  await page.mouse.move(ch.cx, ch.cy);
  await page.mouse.down();
  await page.mouse.move(ch.cx + 8, ch.cy, { steps: 2 });
  await tick(60);
  await page.mouse.move(target.cx + 30, ch.cy, { steps: 8 });
  await tick(100);
  await page.mouse.up();
  await expectText('a horizontal list reorders along x', chipOrder, 'Fichas: dos,uno,tres');
  t.check('and the page agrees', JSON.stringify(await chipTitles()) === '["dos","uno","tres"]', JSON.stringify(await chipTitles()));
  await chipHandle('tres').focus();
  await page.keyboard.press('Alt+ArrowLeft');
  await expectText('Alt+arrow in a row goes along it', chipOrder, 'Fichas: dos,tres,uno');
  await page.evaluate(() => (document.documentElement.dir = 'rtl'));
  await chipHandle('dos').focus();
  await page.keyboard.press('Alt+ArrowLeft');
  await expectText('in rtl the left arrow goes on', chipOrder, 'Fichas: tres,dos,uno');
  await page.evaluate(() => (document.documentElement.dir = 'ltr'));

  t.check('no page errors', page.problems.length === 0, page.problems.join(' | '));

  // Reduced motion: the same drop is not slower than a few frames.
  {
    const calm = await t.page({ viewport: { width: 480, height: 640 }, reducedMotion: 'reduce' });
    await trackHydration(calm);
    await calm.goto(t.url);
    await calm.mouse.move(1, 1);
    await calm.mouse.down();
    await calm.mouse.up();
    await hydrated(calm);
    const h = calm.locator('[data-tl="ReorderState.todos"] [data-t-ro-item]', { hasText: 'Pedir café' }).locator('[data-t-ro-h]');
    await h.scrollIntoViewIfNeeded();
    const b = await h.boundingBox();
    await calm.mouse.move(b.x + 20, b.y + 20);
    await calm.mouse.down();
    await calm.mouse.move(b.x + 20, b.y + 28, { steps: 2 });
    await calm.waitForTimeout(60);
    await calm.mouse.move(b.x + 20, b.y + 140, { steps: 6 });
    await calm.waitForTimeout(100);
    const t0 = Date.now();
    await calm.mouse.up();
    const ok = await settle(calm, () => document.querySelector('[data-tt="ReorderState.status"]')?.textContent.startsWith('a: 0 a'), null, { timeout: 5000 });
    const took = Date.now() - t0;
    t.check('reduced motion: the drop is not animated', ok === true && took < 400, `${took} ms`);
    t.check('no page errors (reduced motion)', calm.problems.length === 0, calm.problems.join(' | '));
  }

  // Real touch (Chromium): a held finger on the row drags it; moving first scrolls.
  if ((process.env.E2E_BROWSER ?? 'chromium') === 'chromium') {
    const touch = await t.page({ viewport: { width: 480, height: 800 }, hasTouch: true, isMobile: true });
    await trackHydration(touch);
    await touch.goto(t.url);
    await touch.touchscreen.tap(5, 5);
    await hydrated(touch);
    const cdp = await touch.context().newCDPSession(touch);
    const body = touch.locator('[data-tl="ReorderState.todos"] [data-t-ro-item]', { hasText: 'Contar caja' });
    await body.scrollIntoViewIfNeeded();
    const b = await body.boundingBox();
    const at = (y) => [{ x: b.x + 30, y, id: 1 }];
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: at(b.y + b.height / 2) });
    await touch.waitForTimeout(650);
    t.check('touch: a hold on the row starts the drag', await body.evaluate((e) => e.hasAttribute('data-t-ro-drag')));
    for (let i = 1; i <= 8; i++) {
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: at(b.y + b.height / 2 + i * 14) });
      await touch.waitForTimeout(25);
    }
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    const moved = await settle(touch, () => document.querySelector('[data-tt="ReorderState.status"]')?.textContent === 'b: 1 a 3', null, { timeout: 6000 });
    t.check('touch: and drops it', moved === true, await touch.locator(status).textContent());
    t.check('no page errors (touch)', touch.problems.length === 0, touch.problems.join(' | '));
  }

  // No JavaScript: the items and their handles are there, nothing else.
  {
    const plain = await t.page({ viewport: { width: 480, height: 900 }, javaScriptEnabled: false });
    await plain.goto(t.url);
    const l = plain.locator('[data-t-ro][data-tl="ReorderState.todos"]');
    t.check('without JavaScript the items are all there', (await l.locator(':scope > [data-t-ro-item]').count()) === 4);
    t.check('without JavaScript each item has its handle button', (await l.locator('[data-t-ro-item] > button[data-t-ro-h]').count()) === 4);
    const b = await l.locator('[data-t-ro-item]').first().boundingBox();
    t.check('without JavaScript an item has its natural size', b.height > 30 && b.width > 150, JSON.stringify(b));
  }
});

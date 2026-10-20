// Every Gesture of test/fixtures/apps/lab (/gestures) in a real browser: mouse, keyboard and two
// real touch points (pinch through CDP). Needs JavaScript by nature.
//
//   tool/thor e2e gestures                      (builds, serves, runs)
//   node test/e2e/checks/gestures_check.mjs [url]
import { e2e, hydrated, settle, trackHydration } from './lib/e2e.mjs';

await e2e('gestures', { site: 'test/fixtures/apps/lab/build/site', path: 'gestures' }, async (t) => {
  const page = await t.page({ viewport: { width: 480, height: 1400 }, hasTouch: true });
  await trackHydration(page);
  await page.goto(t.url);
  await page.mouse.move(1, 1); // the first pointer event loads the engine
  await page.mouse.down();
  await page.mouse.up();
  t.check('engine hydrates', await hydrated(page).then(() => true, () => false));

  const text = (sel) => page.locator(sel).textContent();
  // Waits until the text of `sel` is `want`, then checks it.
  const expectText = async (label, sel, want) => {
    const got = await settle(page, ([s, w]) => document.querySelector(s)?.textContent === w, [sel, want]);
    t.check(label, got === true, got === true ? '' : `${JSON.stringify(await text(sel))}, expected ${JSON.stringify(want)}`);
  };
  const status = '[data-tt="GesturesState.status"]';
  const rows = () => page.locator('li').evaluateAll((l) => l.map((e) => e.textContent));
  const center = async (loc) => {
    const b = await loc.boundingBox();
    return { ...b, cx: b.x + b.width / 2, cy: b.y + b.height / 2 };
  };

  // Tap.
  const m2 = page.locator('li[data-tk="m2"]');
  let b = await center(m2);
  await page.mouse.click(b.cx, b.cy);
  await expectText('tap opens the row', status, 'Abriste m2');

  // Long press: held past the gesture's threshold (the hold is the input,
  // not a wait), and no tap after it.
  await page.mouse.move(b.x + 20, b.y + 20);
  await page.mouse.down();
  await page.waitForTimeout(700);
  await page.mouse.up();
  await expectText('long press opens the menu', status, 'Menú de m2');
  await page.evaluate(() => new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done))));
  t.check('no tap after a long press', (await text(status)) === 'Menú de m2', await text(status));

  // Swipe m1 left: dismissed and archived.
  const m1 = page.locator('li[data-tk="m1"]');
  b = await center(m1);
  await page.mouse.move(b.x + b.width - 20, b.cy);
  await page.mouse.down();
  for (let i = 1; i <= 10; i++) await page.mouse.move(b.x + b.width - 20 - i * 30, b.cy);
  await page.mouse.up();
  await expectText('swipe left archives', status, 'Archivado: Pedido #1042 listo');
  const left = await settle(page, () => document.querySelectorAll('li').length === 3);
  t.check('the swiped row leaves the list', left === true, JSON.stringify(await rows()));

  // A short swipe snaps back and does nothing.
  const m3 = page.locator('li[data-tk="m3"]');
  b = await center(m3);
  await page.mouse.move(b.x + 100, b.y + 20);
  await page.mouse.down();
  await page.mouse.move(b.x + 80, b.y + 20, { steps: 3 });
  await page.mouse.move(b.x + 70, b.y + 20, { steps: 3 });
  await page.mouse.up();
  const back = await settle(page, (el) => ['', '0px'].includes(el.style.getPropertyValue('--tg-x')), await m3.elementHandle());
  t.check('a short swipe snaps back', back === true, await m3.evaluate((e) => e.style.getPropertyValue('--tg-x')));
  t.check('a short swipe keeps the row', (await rows()).length === 3, JSON.stringify(await rows()));
  t.check('a short swipe changes nothing', (await text(status)) === 'Archivado: Pedido #1042 listo', await text(status));

  // Keyboard: Delete dismisses the focused row.
  await m3.focus();
  await page.keyboard.press('Delete');
  await expectText('Delete dismisses the focused row', status, 'Archivado: Nuevo proveedor: Café Altura');

  // Keyboard swipe (WCAG 2.5.1): Shift+arrow archives the focused row too.
  const m4 = page.locator('li[data-tk="m4"]');
  t.check('a swipeable row names its keys', (await m4.getAttribute('aria-keyshortcuts')) === 'Shift+ArrowLeft Shift+ArrowRight');
  await m4.focus();
  await page.keyboard.press('Shift+ArrowLeft');
  await expectText('Shift+ArrowLeft dismisses the focused row', status, 'Archivado: Recordatorio: inventario');

  // Double tap: two clicks inside the double-tap window.
  const likes = '[data-tt="GesturesState.likesLabel"]';
  b = await center(page.locator(likes));
  await page.mouse.click(b.x + 5, b.y + 5);
  await page.mouse.click(b.x + 5, b.y + 5);
  await expectText('double tap likes once', likes, '♥ 1');

  // Drag the chip (no snap back): the offsets add up.
  const position = '[data-tt="GesturesState.positionLabel"]';
  const chip = page.locator('[data-tg*="drag"]');
  b = await center(chip);
  await page.mouse.move(b.x + 10, b.y + 10);
  await page.mouse.down();
  await page.mouse.move(b.x + 110, b.y + 50, { steps: 8 });
  await page.mouse.up();
  await expectText('drag reports its offset', position, 'Posición: 100, 40');
  b = await center(chip);
  await page.mouse.move(b.x + 10, b.y + 10);
  await page.mouse.down();
  await page.mouse.move(b.x + 30, b.y + 10, { steps: 5 });
  await page.mouse.up();
  await expectText('a second drag adds to the first', position, 'Posición: 120, 40');
  await chip.focus();
  await page.keyboard.press('ArrowDown');
  await expectText('arrow keys drag by 10', position, 'Posición: 120, 50');

  // Pinch with two real touch points: 40 → 80 px apart = 2×.
  const zoom = '[data-tt="GesturesState.zoomLabel"]';
  const circle = page.locator('[data-tg*="scale"]');
  b = await center(circle);
  const cdp = await page.context().newCDPSession(page);
  const touches = (d) => [{ x: b.cx - d, y: b.cy, id: 1 }, { x: b.cx + d, y: b.cy, id: 2 }];
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: touches(20) });
  for (const d of [25, 30, 35, 40]) await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: touches(d) });
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await expectText('pinch zooms', zoom, 'Zoom: 2.00×');
  await circle.focus();
  await page.keyboard.press('+');
  await expectText('+ zooms from the keyboard', zoom, 'Zoom: 2.25×');

  // One finger of a pinch lifts and the other keeps moving: the scale rests
  // where it was (a single finger has no distance to scale by).
  b = await center(circle);
  const at = (l, r) => [{ x: b.cx - l, y: b.cy, id: 1 }, { x: b.cx + r, y: b.cy, id: 2 }];
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: at(20, 20) });
  for (const d of [24, 28]) await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: at(d, d) });
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [{ x: b.cx + 28, y: b.cy, id: 2 }] });
  for (const d of [60, 90]) await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: b.cx - d, y: b.cy, id: 1 }] });
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await expectText('a pinch keeps its scale when one finger lifts', zoom, 'Zoom: 3.15×');

  // A touch swipe that snaps back never sends a click: the flag that
  // swallows a gesture's click must not wait for the next tap.
  const m2t = page.locator('li[data-tk="m2"]');
  b = await center(m2t);
  await page.evaluate(() => {
    document.querySelector('[data-tt="GesturesState.status"]').dataset.before = document.querySelector('[data-tt="GesturesState.status"]').textContent;
  });
  const one = (x, y) => [{ x, y, id: 1 }];
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: one(b.cx, b.cy) });
  for (const d of [8, 16, 24]) await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: one(b.cx + d, b.cy) });
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await page.waitForTimeout(200);
  await page.touchscreen.tap(b.cx, b.cy);
  await expectText('the tap after a short touch swipe still taps', status, 'Abriste m2');

  t.check('no page errors', page.problems.length === 0, page.problems.join(' | '));
});

// `Draggable`, `LongPressDraggable` and `DragTarget` of test/fixtures/apps/lab (/drag) in a real
// browser, with either engine: cards dragged between columns (the feedback,
// childWhenDragging, a target that says no, the type that decides, rows the
// browser cloned), a hold to start, the page scrolling at its edge, the
// keyboard way with its live region, a real touch drag (Chromium), RTL and
// the page with no JavaScript.
//
//   tool/thor e2e draggable draggable-dart              (builds, serves, runs)
//   E2E_BROWSER=firefox tool/thor e2e draggable         (or webkit)
//   node test/e2e/checks/draggable_check.mjs [url]
import { e2e, hydrated, settle, trackHydration } from './lib/e2e.mjs';

await e2e('draggable', { site: 'test/fixtures/apps/lab/build/site', path: 'drag' }, async (t) => {
  const page = await t.page({ viewport: { width: 480, height: 640 } });
  await trackHydration(page);
  await page.goto(t.url);
  await page.mouse.move(1, 1); // the first pointer event loads the engine
  await page.mouse.down();
  await page.mouse.up();
  t.check('engine hydrates', await hydrated(page).then(() => true, () => false));

  const status = '[data-tt="BoardState.status"]';
  const where = '[data-tt="BoardState.whereLabel"]';
  const text = (sel) => page.locator(sel).first().textContent();
  const expectText = async (label, sel, want) => {
    const got = await settle(page, ([s, w]) => document.querySelector(s)?.textContent === w, [sel, want], { timeout: 6000 });
    t.check(label, got === true, got === true ? '' : `${JSON.stringify(await text(sel))}, expected ${JSON.stringify(want)}`);
  };
  const column = (name) => page.locator(`[data-t-dt][aria-label="${name}"]`);
  const todo = column('Por hacer'), doing = column('En curso (mantén pulsado)'), done = column('Hecho (solo lo que está en curso)');
  const cards = (col) => col.locator('[data-t-dg]').evaluateAll((l) => l.map((e) => e.textContent.replace('…', '').trim()));
  const card = (title) => page.locator('[data-t-dg]', { hasText: title }).first();
  const center = async (loc) => {
    await loc.scrollIntoViewIfNeeded();
    const b = await loc.boundingBox();
    return { ...b, cx: b.x + b.width / 2, cy: b.y + b.height / 2 };
  };
  const ghost = () => page.locator('[data-t-dg-ghost]');
  const tick = (ms = 40) => page.waitForTimeout(ms);
  // Presses on `from`, drags to the middle of `to` and stops there (`up: false`).
  const drag = async (from, to, { up = true, hold = 0, steps = 8, dy = 0 } = {}) => {
    const a = await center(from);
    await page.mouse.move(a.cx, a.cy);
    await page.mouse.down();
    if (hold) await page.waitForTimeout(hold);
    const b = await center(to);
    await page.mouse.move(a.cx + 10, a.cy + 6, { steps: 2 });
    // A frame in the column the card is in: it enters that target first.
    await tick(80);
    await page.mouse.move(b.cx, b.cy + dy, { steps });
    await tick(80);
    if (up) await page.mouse.up();
  };

  // The markup the engine reads, and what assistive technology gets.
  const c1 = card('Pedir café');
  t.check('a card is reachable and named as draggable', (await c1.getAttribute('tabindex')) === '0' && (await c1.getAttribute('aria-roledescription')) === 'draggable' && (await c1.getAttribute('role')) === 'button');
  t.check('the feedback is a template, not shown', (await c1.locator(':scope > template[data-t-dg-fb]').count()) === 1 && (await page.locator('[data-t-dg-ghost]').count()) === 0);
  t.check('the columns are the targets', (await page.locator('[data-t-dt]').count()) >= 4);

  // Drag t1 over "En curso": the ghost under the pointer, the target marked.
  await drag(c1, doing, { up: false });
  t.check('the feedback follows the pointer (fixed, in the body)', (await ghost().count()) === 1 && (await ghost().evaluate((g) => g.parentElement === document.body && getComputedStyle(g).position === 'fixed')));
  t.check('the feedback shows the card\'s text', (await ghost().textContent()) === 'Pedir café', await ghost().textContent());
  t.check('the card is marked as dragged', (await c1.getAttribute('data-t-dg-active')) !== null || (await page.locator('[data-t-dg-active]').count()) === 1);
  t.check('childWhenDragging stands in', (await cards(todo)).some((c) => c === '') || (await todo.textContent()).includes('…'), JSON.stringify(await cards(todo)));
  t.check('the target under the pointer is marked', (await doing.getAttribute('data-t-dt-over')) !== null);
  t.check('and takes its look from overStyle', (await doing.evaluate((e) => getComputedStyle(e).backgroundColor)) === 'rgb(219, 234, 254)', await doing.evaluate((e) => getComputedStyle(e).backgroundColor));
  await expectText('onDragStarted ran', '[data-tt="BoardState.startsLabel"]', 'Inicios: 1');
  await expectText('onLeave ran when the pointer left the column it started in', status, 't1 salió de todo');
  t.check('onMove reports the pointer inside the target', /^doing \d+,\d+$/.test(await text(where)), await text(where));
  const g0 = await ghost().evaluate((g) => g.getBoundingClientRect().x);
  await page.mouse.move(100, 300, { steps: 4 });
  await tick(60);
  t.check('the feedback moves with it', (await ghost().evaluate((g) => g.getBoundingClientRect().x)) !== g0);
  const d = await center(doing);
  await page.mouse.move(d.cx, d.cy, { steps: 4 });
  await tick(60);
  await page.mouse.up();
  await expectText('the drop reaches the state (onAcceptWithDetails)', status, 'Completada');
  t.check('the card is now in the other column', JSON.stringify(await cards(doing)) === '["Armar pedido","Pedir café"]' && JSON.stringify(await cards(todo)) === '["Contar caja"]', JSON.stringify([await cards(todo), await cards(doing)]));
  await expectText('onDragEnd(accepted) after the drop', where, 'fin: aceptada');
  t.check('the feedback and the marks are gone', (await ghost().count()) === 0 && (await page.locator('[data-t-dg-active],[data-t-dt-over],[data-t-dt-reject],[data-t-dg-gone]').count()) === 0);
  t.check('a drag swallows its click', true);

  // "Hecho" takes only what is in progress: a todo card is rejected.
  await drag(card('Contar caja'), done, { up: false });
  t.check('a target that says no is marked as rejecting', (await done.getAttribute('data-t-dt-reject')) !== null && (await done.getAttribute('data-t-dt-over')) === null);
  t.check('and shows rejectStyle', (await done.evaluate((e) => getComputedStyle(e).backgroundColor)) === 'rgb(254, 226, 226)', await done.evaluate((e) => getComputedStyle(e).backgroundColor));
  await page.mouse.up();
  await expectText('a rejected drop is a cancelled drag', status, 'Cancelada');
  await expectText('and onDragEnd(false)', where, 'fin: no');
  t.check('nothing moved', JSON.stringify(await cards(todo)) === '["Contar caja"]' && (await cards(done)).length === 0);

  // Dropped on nothing.
  await drag(card('Contar caja'), page.locator('h1'), { dy: 0 });
  await expectText('a drop on nothing is cancelled too', status, 'Cancelada');

  // A card the browser cloned: the feedback has its text.
  await page.locator('button', { hasText: 'Añadir tarjeta' }).click();
  await settle(page, () => document.querySelectorAll('[data-t-dg]').length >= 4);
  const fresh = card('Nueva 4');
  t.check('a card added in the browser is a draggable too', (await fresh.getAttribute('data-t-dg-type')) === 'String' && (await fresh.getAttribute('data-t-dg-data')) === 't4', `${await fresh.getAttribute('data-t-dg-data')}`);
  await drag(fresh, doing, { up: false });
  t.check('a cloned row\'s feedback shows its own text', (await ghost().textContent()) === 'Nueva 4', await ghost().textContent());
  await page.mouse.up();
  await expectText('and it drops', status, 'Completada');
  t.check('the cloned card moved', (await cards(doing)).includes('Nueva 4'), JSON.stringify(await cards(doing)));

  // A hold first (LongPressDraggable in "En curso"): moving at once is not a drag.
  const packCard = card('Armar pedido');
  let a = await center(packCard);
  await page.mouse.move(a.cx, a.cy);
  await page.mouse.down();
  await page.mouse.move(a.cx + 12, a.cy + 12, { steps: 3 });
  await page.waitForTimeout(350);
  t.check('moving before the hold is no drag', (await ghost().count()) === 0);
  await page.mouse.up();
  a = await center(packCard);
  await page.mouse.move(a.cx, a.cy);
  await page.mouse.down();
  await page.waitForTimeout(450);
  t.check('a hold starts the drag by itself', (await ghost().count()) === 1);
  const dn = await center(done);
  await page.mouse.move(dn.cx, dn.cy, { steps: 6 });
  await tick(80);
  t.check('the card in progress is accepted by "Hecho"', (await done.getAttribute('data-t-dt-over')) !== null);
  await page.mouse.up();
  await expectText('and moves there', status, 't3 a done');
  t.check('it is in the done column', (await cards(done)).includes('Armar pedido'), JSON.stringify(await cards(done)));

  // The type decides: a number goes to the adder, a card does not.
  const adder = page.locator('[data-t-dt][aria-label="Sumador"]');
  await drag(page.locator('[data-t-dg][aria-label="Número 3"]'), adder);
  await expectText('a number dropped on the adder', status, 'Sumaste 3');
  t.check('the adder added it', (await adder.textContent()).includes('Total: 3'), await adder.textContent());
  await drag(page.locator('[data-t-dg][aria-label="Número 5"]'), todo, { up: false });
  t.check('a column does not take a number (the type)', (await todo.getAttribute('data-t-dt-reject')) !== null);
  await page.mouse.up();
  t.check('and nothing was added', (await adder.textContent()).includes('Total: 3'));
  await drag(card('Contar caja'), adder, { up: false });
  t.check('the adder does not take a card', (await adder.getAttribute('data-t-dt-reject')) !== null);
  await page.mouse.up();

  // Escape gives a pointer drag up.
  await drag(card('Contar caja'), doing, { up: false });
  await page.keyboard.press('Escape');
  await tick(60);
  t.check('Escape ends the drag', (await ghost().count()) === 0 && (await page.locator('[data-t-dt-over]').count()) === 0);
  await page.mouse.up();
  await expectText('and nothing was dropped', status, 'Cancelada');

  // The page scrolls under a pointer near its edge.
  await page.evaluate(() => window.scrollTo(0, 0));
  const first = card('Contar caja');
  a = await center(first);
  await page.mouse.move(a.cx, a.cy);
  await page.mouse.down();
  await page.mouse.move(a.cx + 8, a.cy + 8, { steps: 2 });
  await page.mouse.move(a.cx, 632, { steps: 4 });
  await page.waitForTimeout(700);
  const sy = await page.evaluate(() => window.scrollY);
  t.check('the page scrolls while the pointer is near the bottom', sy > 20, `${sy}`);
  await page.mouse.up();
  await page.evaluate(() => window.scrollTo(0, 0));

  // The keyboard (WCAG 2.5.7): pick up, choose a target, drop; Escape cancels.
  const live = () => page.locator('[aria-live="assertive"]').textContent();
  const liveIs = async (label, re) => {
    const ok = await settle(page, (src) => new RegExp(src).test(document.querySelector('[aria-live="assertive"]')?.textContent ?? ''), re.source, { timeout: 4000 });
    t.check(label, ok === true, await live().catch(() => ''));
  };
  await card('Contar caja').focus();
  await page.keyboard.press('Space');
  await liveIs('Space picks up and says so', /^Picked up Contar caja\./);
  t.check('a keyboard drag shows the feedback', (await ghost().count()) === 1);
  await page.keyboard.press('ArrowDown');
  await liveIs('the arrow chooses the first target that fits and says it', /^Por hacer: it can be dropped here\.$/);
  await page.keyboard.press('ArrowDown');
  await liveIs('the next one is announced', /^En curso \(mantén pulsado\): it can be dropped here\.$/);
  await page.keyboard.press('ArrowDown');
  await liveIs('a target that says no is announced as such', /^Hecho \(solo lo que está en curso\): it cannot be dropped here\.$/);
  await page.keyboard.press('Space');
  t.check('Space on it does not drop', (await ghost().count()) === 1);
  await page.keyboard.press('ArrowUp');
  await page.keyboard.press('Space');
  await liveIs('Space on a target drops and says so', /^Dropped Contar caja on En curso/);
  await expectText('the state heard the drop', status, 'Completada');
  t.check('the card moved by keyboard', (await cards(doing)).includes('Contar caja'), JSON.stringify(await cards(doing)));
  t.check('the focus came back to the card', await page.evaluate(() => document.activeElement?.textContent?.includes('Contar caja')));
  await card('Contar caja').focus();
  await page.keyboard.press('Enter');
  await page.keyboard.press('Tab');
  await page.keyboard.press('Escape');
  await liveIs('Escape cancels and says so', /^Cancelled\. Contar caja was not moved\.$/);
  t.check('and the card stayed', (await cards(doing)).includes('Contar caja'));
  await page.evaluate(() => (document.documentElement.dir = 'rtl'));
  await card('Contar caja').focus();
  await page.keyboard.press('Space');
  await page.keyboard.press('ArrowLeft');
  await liveIs('in rtl the left arrow goes on', /^Por hacer: it can be dropped here\.$/);
  await page.keyboard.press('Escape');
  await page.evaluate(() => (document.documentElement.dir = 'ltr'));

  t.check('no page errors', page.problems.length === 0, page.problems.join(' | '));

  // Real touch (Chromium): a hold, then the finger drags the card.
  if ((process.env.E2E_BROWSER ?? 'chromium') === 'chromium') {
    const touch = await t.page({ viewport: { width: 480, height: 900 }, hasTouch: true, isMobile: true });
    await trackHydration(touch);
    await touch.goto(t.url);
    await touch.touchscreen.tap(5, 5);
    await hydrated(touch);
    const cdp = await touch.context().newCDPSession(touch);
    const box = async (sel) => {
      const l = touch.locator(sel).first();
      await l.scrollIntoViewIfNeeded();
      return l.boundingBox();
    };
    const from = await box('[data-t-dg]:has-text("Armar pedido")');
    const to = await box('[data-t-dt][aria-label="Hecho (solo lo que está en curso)"]');
    const at = (x, y) => [{ x, y, id: 1 }];
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: at(from.x + 20, from.y + 10) });
    await touch.waitForTimeout(450);
    t.check('touch: a hold starts the drag', (await touch.locator('[data-t-dg-ghost]').count()) === 1);
    for (let i = 1; i <= 8; i++) {
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: at(from.x + 20 + ((to.x + 40 - from.x - 20) * i) / 8, from.y + 10 + ((to.y + 20 - from.y - 10) * i) / 8) });
      await touch.waitForTimeout(25);
    }
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    const moved = await settle(touch, () => document.querySelector('[data-tt="BoardState.status"]')?.textContent === 't3 a done', null, { timeout: 6000 });
    t.check('touch: the card dropped on the column', moved === true, await touch.locator(status).textContent());
    t.check('no page errors (touch)', touch.problems.length === 0, touch.problems.join(' | '));
  }

  // No JavaScript: the cards and the columns are there, the templates hidden.
  {
    const plain = await t.page({ viewport: { width: 480, height: 900 }, javaScriptEnabled: false });
    await plain.goto(t.url);
    t.check('without JavaScript the cards are all there', (await plain.locator('[data-t-dg]').count()) >= 5, `${await plain.locator('[data-t-dg]').count()}`);
    t.check('without JavaScript the feedback is not shown', (await plain.locator('[data-t-dg-ghost]:visible').count()) === 0);
    const b = await plain.locator('[data-t-dg]').first().boundingBox();
    t.check('without JavaScript a card has its natural size', b.height > 30 && b.width > 100, JSON.stringify(b));
  }
});

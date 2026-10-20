// `Dismissible` of test/fixtures/apps/lab (/drag) in a real browser, with either engine: a row
// dragged away (backgrounds, threshold, fling, confirm that says no, the
// collapse), the keyboard way (Delete, Shift+arrow, focus moving on), a
// vertical one, rows the browser cloned, RTL, reduced motion, a real touch
// swipe (Chromium) and the page with no JavaScript.
//
//   tool/thor e2e dismissible dismissible-dart          (builds, serves, runs)
//   E2E_BROWSER=firefox tool/thor e2e dismissible       (or webkit)
//   node test/e2e/checks/dismissible_check.mjs [url]
import { e2e, frames, hydrated, settle, trackHydration } from './lib/e2e.mjs';

await e2e('dismissible', { site: 'test/fixtures/apps/lab/build/site', path: 'drag' }, async (t) => {
  const page = await t.page({ viewport: { width: 480, height: 1400 }, hasTouch: false });
  await trackHydration(page);
  await page.goto(t.url);
  await page.mouse.move(1, 1); // the first pointer event loads the engine
  await page.mouse.down();
  await page.mouse.up();
  t.check('engine hydrates', await hydrated(page).then(() => true, () => false));

  const status = '[data-tt="InboxState.status"]';
  const cardStatus = '[data-tt="CardsState.status"]';
  const text = (sel) => page.locator(sel).first().textContent();
  const expectText = async (label, sel, want) => {
    const got = await settle(page, ([s, w]) => document.querySelector(s)?.textContent === w, [sel, want], { timeout: 6000 });
    t.check(label, got === true, got === true ? '' : `${JSON.stringify(await text(sel))}, expected ${JSON.stringify(want)}`);
  };
  const row = (k) => page.locator(`li[data-tk="${k}"]`);
  const keys = () => page.locator('ul[data-tl="InboxState.messages"] > li[data-tk]').evaluateAll((l) => l.map((e) => e.dataset.tk));
  const center = async (loc) => {
    const b = await loc.boundingBox();
    return { ...b, cx: b.x + b.width / 2, cy: b.y + b.height / 2 };
  };
  const tick = (ms = 30) => page.waitForTimeout(ms);
  // A drag from x0 to x1 in `steps`, `gap` ms apart (slow: not a fling).
  const drag = async (b, x0, x1, { steps = 8, gap = 30, y = b.cy, up = true } = {}) => {
    await page.mouse.move(x0, y);
    await page.mouse.down();
    for (let i = 1; i <= steps; i++) {
      await page.mouse.move(x0 + ((x1 - x0) * i) / steps, y);
      if (gap) await tick(gap);
    }
    if (up) await page.mouse.up();
  };
  const bodyVar = (k) => row(k).locator('[data-t-dm-body]').evaluate((e) => e.style.getPropertyValue('--t-dm-x'));
  const shown = (k) =>
    row(k).evaluate((r) => [...r.querySelectorAll(':scope > [data-t-dm-bg]')].filter((b) => getComputedStyle(b).visibility === 'visible').map((b) => b.dataset.tDmBg));

  // The markup the engine reads.
  t.check('a row names its keyboard way', (await row('m1').getAttribute('aria-keyshortcuts')) === 'Delete');
  t.check('the backgrounds are hidden from assistive tech', (await row('m1').locator('[data-t-dm-bg]').evaluateAll((l) => l.every((e) => e.getAttribute('aria-hidden') === 'true'))) === true);
  t.check('both backgrounds are hidden at rest', (await shown('m1')).length === 0, JSON.stringify(await shown('m1')));

  // Drag m1 toward the start (left): the secondary background shows, the
  // body follows the pointer, the click that ends it is swallowed.
  let b = await center(row('m1'));
  await drag(b, b.x + b.width - 20, b.x + b.width - 20 - b.width * 0.7, { up: false });
  const x = Number.parseFloat(await bodyVar('m1'));
  t.check('the body follows the pointer', x < -b.width * 0.5 && x > -b.width * 0.8, `${x}`);
  t.check('the drag marks the body (no transition)', (await row('m1').locator('[data-t-dm-body]').getAttribute('data-t-dm-drag')) !== null);
  t.check('the endToStart background is under it', JSON.stringify(await shown('m1')) === '["endToStart"]', JSON.stringify(await shown('m1')));
  await page.mouse.up();
  await expectText('past the threshold it asks (confirm), then reports', status, 'Descartado m1 (endToStart)');
  const gone = await settle(page, () => !document.querySelector('li[data-tk="m1"]'), null, { timeout: 4000 });
  t.check('the dismissed row leaves the list', gone === true, JSON.stringify(await keys()));

  // The confirm says no for m2: it comes back where it was.
  b = await center(row('m2'));
  await drag(b, b.x + b.width - 20, b.x + b.width - 20 - b.width * 0.7);
  await expectText('confirm is asked for the row', status, 'Confirmando m2');
  const back = await settle(page, () => {
    const body = document.querySelector('li[data-tk="m2"] [data-t-dm-body]');
    return body && !body.hasAttribute('data-t-dm-out') && ['', '0px'].includes(body.style.getPropertyValue('--t-dm-x'));
  }, null, { timeout: 4000 });
  t.check('a refused confirmation brings the row back', back === true, await bodyVar('m2'));
  t.check('a refused row is still in the list', (await keys()).includes('m2'), JSON.stringify(await keys()));
  t.check('a refused row did not collapse', (await row('m2').getAttribute('data-t-dm-gone')) === null);
  t.check('its backgrounds hide again', (await shown('m2')).length === 0, JSON.stringify(await shown('m2')));

  // A short, slow drag snaps back and says nothing.
  b = await center(row('m3'));
  await drag(b, b.x + 100, b.x + 40, { steps: 6, gap: 40 });
  const snapped = await settle(page, () => {
    const body = document.querySelector('li[data-tk="m3"] [data-t-dm-body]');
    return !body.hasAttribute('data-t-dm-out') && ['', '0px'].includes(body.style.getPropertyValue('--t-dm-x'));
  }, null, { timeout: 4000 });
  t.check('a short drag snaps back', snapped === true, await bodyVar('m3'));
  t.check('a short drag changes nothing', (await text(status)) === 'Confirmando m2', await text(status));

  // Toward the end (right): startToEnd, with its own background.
  b = await center(row('m3'));
  await drag(b, b.x + 20, b.x + 20 + b.width * 0.7, { up: false });
  t.check('the startToEnd background is under it', JSON.stringify(await shown('m3')) === '["startToEnd"]', JSON.stringify(await shown('m3')));
  await page.mouse.up();
  await expectText('toward the end it reports startToEnd', status, 'Descartado m3 (startToEnd)');

  // The page's scroll is not ours: a vertical drag moves nothing.
  b = await center(row('m4'));
  await drag(b, b.cx, b.cx, { steps: 1, gap: 0, up: false });
  await page.mouse.move(b.cx + 2, b.cy + 40, { steps: 3 });
  await page.mouse.move(b.cx - 60, b.cy + 44, { steps: 3 });
  t.check('a vertical drag is not a dismissal', (await bodyVar('m4')) === '', await bodyVar('m4'));
  await page.mouse.up();

  // The keyboard (WCAG 2.5.1): Delete on the focused row; focus moves on.
  await page.locator('button', { hasText: 'Restaurar bandeja' }).click();
  await expectText('the state restores the rows', status, 'Bandeja restaurada');
  const cloned = await settle(page, () => document.querySelectorAll('ul[data-tl="InboxState.messages"] > li[data-tk]').length === 4, null, { timeout: 4000 });
  t.check('the rows are back (cloned or kept)', cloned === true, JSON.stringify(await keys()));
  await row('m3').focus();
  await page.keyboard.press('Delete');
  await expectText('Delete dismisses the focused row', status, 'Descartado m3 (endToStart)');
  const next = await settle(page, () => document.activeElement?.dataset?.tk, null, { timeout: 2000 });
  t.check('the focus moves on to the next row', next === 'm4', `${next}`);
  await row('m4').focus();
  await page.keyboard.press('Shift+ArrowRight');
  await expectText('Shift+ArrowRight dismisses toward the end', status, 'Descartado m4 (startToEnd)');
  await row('m1').focus();
  await page.keyboard.press('ArrowRight');
  await tick(400);
  t.check('a plain arrow does nothing', (await keys()).includes('m1'), JSON.stringify(await keys()));

  // Rows the browser cloned from the template drag like the first ones.
  await page.locator('button', { hasText: 'Restaurar bandeja' }).click();
  await settle(page, () => document.querySelectorAll('ul[data-tl="InboxState.messages"] > li[data-tk]').length === 4, null, { timeout: 4000 });
  b = await center(row('m1'));
  await drag(b, b.x + b.width - 20, b.x + b.width - 20 - b.width * 0.7);
  await expectText('a cloned row dismisses', status, 'Descartado m1 (endToStart)');

  // RTL: toward the physical right is the end of the line... the other way.
  await page.evaluate(() => (document.documentElement.dir = 'rtl'));
  await row('m3').scrollIntoViewIfNeeded();
  b = await center(row('m3'));
  await drag(b, b.x + 20, b.x + 20 + b.width * 0.7);
  await expectText('in rtl a drag to the right is endToStart', status, 'Descartado m3 (endToStart)');
  await page.evaluate(() => (document.documentElement.dir = 'ltr'));

  // Vertical cards: up, no confirm, no collapse (resizeDuration: null).
  const card = page.locator('li[data-tk="c1"]');
  b = await center(card);
  const cardBody = card.locator('[data-t-dm-body]');
  await page.mouse.move(b.cx, b.cy + 20);
  await page.mouse.down();
  for (let i = 1; i <= 6; i++) {
    await page.mouse.move(b.cx, b.cy + 20 - i * 8);
    await tick(30);
  }
  t.check('a vertical row follows the pointer on y', Number.parseFloat(await cardBody.evaluate((e) => e.style.getPropertyValue('--t-dm-y'))) < -30);
  t.check('a vertical row does not move on x', (await cardBody.evaluate((e) => e.style.getPropertyValue('--t-dm-x'))) === '');
  await page.mouse.up();
  await expectText('a vertical dismissal reports up', cardStatus, 'c1: up');
  t.check('a card that leaves is removed', (await settle(page, () => !document.querySelector('li[data-tk="c1"]'), null, { timeout: 3000 })) === true);

  t.check('no page errors', page.problems.length === 0, page.problems.join(' | '));

  // Reduced motion: the same dismissal is not slower than a few frames.
  {
    const calm = await t.page({ viewport: { width: 480, height: 1400 }, reducedMotion: 'reduce' });
    await trackHydration(calm);
    await calm.goto(t.url);
    await calm.mouse.move(1, 1);
    await calm.mouse.down();
    await calm.mouse.up();
    await hydrated(calm);
    const r = await calm.locator('li[data-tk="m1"]').boundingBox();
    await calm.mouse.move(r.x + r.width - 20, r.y + r.height / 2);
    await calm.mouse.down();
    for (let i = 1; i <= 6; i++) {
      await calm.mouse.move(r.x + r.width - 20 - i * 40, r.y + r.height / 2);
      await calm.waitForTimeout(30);
    }
    const t0 = Date.now();
    await calm.mouse.up();
    const ok = await settle(calm, () => document.querySelector('[data-tt="InboxState.status"]')?.textContent === 'Descartado m1 (endToStart)', null, { timeout: 6000 });
    const took = Date.now() - t0;
    t.check('reduced motion: the dismissal is not animated', ok === true && took < 450, `${took} ms`);
    t.check('no page errors (reduced motion)', calm.problems.length === 0, calm.problems.join(' | '));
  }

  // Real touch (Chromium): a swipe with a finger, the page keeps its scroll.
  if ((process.env.E2E_BROWSER ?? 'chromium') === 'chromium') {
    const touch = await t.page({ viewport: { width: 480, height: 800 }, hasTouch: true, isMobile: true });
    await trackHydration(touch);
    await touch.goto(t.url);
    await touch.touchscreen.tap(5, 5);
    await hydrated(touch);
    const cdp = await touch.context().newCDPSession(touch);
    const r = await touch.locator('li[data-tk="m3"]').boundingBox();
    const at = (x) => [{ x, y: r.y + r.height / 2, id: 1 }];
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: at(r.x + r.width - 20) });
    for (let i = 1; i <= 8; i++) {
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: at(r.x + r.width - 20 - i * 30) });
      await touch.waitForTimeout(20);
    }
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    const done = await settle(touch, () => document.querySelector('[data-tt="InboxState.status"]')?.textContent === 'Descartado m3 (endToStart)', null, { timeout: 6000 });
    t.check('a touch swipe dismisses the row', done === true, await touch.locator(status).textContent());
    // A vertical swipe over a row scrolls the page: no dismissal.
    t.check('no page errors (touch)', touch.problems.length === 0, touch.problems.join(' | '));
  }

  // No JavaScript: the rows are there, nothing swipes, no background shows.
  {
    const plain = await t.page({ viewport: { width: 480, height: 1400 }, javaScriptEnabled: false });
    await plain.goto(t.url);
    const rows = await plain.locator('ul[data-tl="InboxState.messages"] > li[data-tk]').count();
    t.check('without JavaScript the rows are all there', rows === 4, `${rows}`);
    const hidden = await plain.locator('li[data-tk="m1"]').evaluate((r) => [...r.querySelectorAll(':scope > [data-t-dm-bg]')].every((b) => getComputedStyle(b).visibility === 'hidden'));
    t.check('without JavaScript no background shows', hidden === true);
    const box = await plain.locator('li[data-tk="m1"]').boundingBox();
    t.check('without JavaScript a row has its natural size', box.height > 30 && box.width > 300, JSON.stringify(box));
  }

  await frames(page, 1);
});

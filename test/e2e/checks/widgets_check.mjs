// The Flutter-feel widgets of test/fixtures/apps/lab (/widgets) in a real browser and the
// lite engine: MouseRegion, Focus, ExpansionTile
// callbacks with the translated state, and AnimatedSize, AnimatedCrossFade
// and SizeTransition with the CSS the server wrote.
//
//   tool/thor e2e widgets                       (builds, serves, runs)
//   node test/e2e/checks/widgets_check.mjs [url]
import { e2e, hydrated, settle, trackHydration } from './lib/e2e.mjs';

await e2e('widgets', { site: 'test/fixtures/apps/lab/build/site', path: 'widgets' }, async (t) => {
  // Without JS: the first frame is right.
  {
    const page = await t.page({ javaScriptEnabled: false });
    await page.goto(t.url);
    const panel = page.locator('[data-ta*="LabState.panel"]');
    t.check('collapsed SizeTransition has no height and is hidden', (await panel.evaluate((e) => e.getBoundingClientRect().height)) === 0 && (await page.locator('text=Panel que se pliega').isHidden()));
    const fade = await page.evaluate(() => [...document.querySelectorAll('[data-tsz]')[1].firstElementChild.children].map((d) => getComputedStyle(d).visibility).join());
    t.check('AnimatedCrossFade shows the first child only', fade === 'visible,hidden', fade);
  }

  const page = await t.page({ viewport: { width: 700, height: 2000 } });
  await trackHydration(page);
  await page.goto(t.url);
  const text = (sel) => page.locator(sel).textContent();
  const expectText = async (label, sel, want) => {
    const got = await settle(page, ([s, w]) => document.querySelector(s)?.textContent === w, [sel, want]);
    t.check(label, got === true, got === true ? '' : `${JSON.stringify(await text(sel))}, expected ${JSON.stringify(want)}`);
  };
  const center = async (loc) => {
    const b = await loc.boundingBox();
    return [b.x + b.width / 2, b.y + b.height / 2];
  };
  const hoverLabel = '[data-tt="LabState.hoverLabel"]';
  const focusLabel = '[data-tt="LabState.focusLabel"]';
  const expansion = '[data-tt="LabState.expansionLabel"]';

  // The first click loads the engine (hover alone does not).
  await page.mouse.move(1, 1);
  await page.mouse.down();
  await page.mouse.up();
  t.check('engine hydrates', await hydrated(page).then(() => true, () => false));

  // MouseRegion.
  const region = page.locator(hoverLabel);
  await page.mouse.move(...(await center(region)), { steps: 4 });
  await expectText('onEnter runs the translated state', hoverLabel, 'Encima · 1');
  await page.mouse.move(...(await center(region.locator('xpath=..'))), { steps: 2 });
  await page.mouse.move(1, 1, { steps: 4 });
  await expectText('onExit runs once', hoverLabel, 'Fuera · 2');

  // Focus: the first click into a field is what wakes the engine on a fresh page.
  await page.locator('#one').focus();
  await expectText('onFocusChange(true)', focusLabel, 'Con foco · 1');
  await page.keyboard.press('Tab');
  await page.waitForTimeout(80);
  t.check('moving to the next field is no change', (await text(focusLabel)) === 'Con foco · 1', await text(focusLabel));
  await page.keyboard.press('Tab');
  await expectText('leaving the fields is onFocusChange(false)', focusLabel, 'Sin foco · 2');

  // ExpansionTile.
  await page.locator('summary').click();
  await expectText('onExpansionChanged(true)', expansion, 'Abierto');
  await page.locator('summary').click();
  await expectText('onExpansionChanged(false)', expansion, 'Cerrado');

  // AnimatedSize: the shell grows through the middle to the new content.
  const shells = page.locator('[data-tsz]');
  const h = (i) => shells.nth(i).evaluate((e) => e.getBoundingClientRect().height);
  const start = await h(0);
  await page.getByRole('button', { name: 'Ver más' }).click();
  await page.waitForTimeout(120);
  const mid = await h(0);
  t.check('AnimatedSize grows through the middle', mid > start && mid < 160, `${start} -> ${mid}`);
  const end = await settle(page, () => Math.round(document.querySelector('[data-tsz]').getBoundingClientRect().height) === 160);
  t.check('AnimatedSize ends at the content', end === true, `${await h(0)}`);

  // AnimatedCrossFade: both children stay, the states swap by class.
  const sides = () => page.evaluate(() => [...document.querySelectorAll('[data-tsz]')[1].firstElementChild.children].map((d) => `${getComputedStyle(d).visibility}:${getComputedStyle(d).opacity}`).join());
  await page.getByRole('button', { name: 'Cambiar' }).click();
  await page.waitForTimeout(120);
  const fh = await h(1);
  t.check('AnimatedCrossFade grows while it cross-fades', fh > 15 && fh < 120, `${fh}`);
  const done = await settle(page, () => [...document.querySelectorAll('[data-tsz]')[1].firstElementChild.children].map((d) => getComputedStyle(d).visibility).join() === 'hidden,visible');
  t.check('AnimatedCrossFade leaves the first child hidden after the fade', done === true, await sides());
  await page.getByRole('button', { name: 'Cambiar' }).click();
  await page.getByRole('button', { name: 'Cambiar' }).click();
  await page.getByRole('button', { name: 'Cambiar' }).click();
  const back = await settle(page, () => [...document.querySelectorAll('[data-tsz]')[1].firstElementChild.children].map((d) => getComputedStyle(d).visibility).join() === 'visible,hidden');
  t.check('AnimatedCrossFade survives a burst of switches (four in all: back to the first)', back === true, await sides());

  // SizeTransition: the engine plays the grid track and the visibility.
  const panel = page.locator('[data-ta*="LabState.panel"]');
  const ph = () => panel.evaluate((e) => e.getBoundingClientRect().height);
  await page.getByRole('button', { name: 'Abrir o cerrar' }).click();
  await page.waitForTimeout(150);
  const open = await ph();
  t.check('SizeTransition opens through the middle', open > 5 && open < 95, `${open}`);
  t.check('and is visible while it opens', await page.locator('text=Panel que se pliega').isVisible());
  const full = await settle(page, () => Math.round(document.querySelector('[data-ta*="LabState.panel"]').getBoundingClientRect().height) === 100);
  t.check('SizeTransition ends at the child height', full === true, `${await ph()}`);
  await page.getByRole('button', { name: 'Abrir o cerrar' }).click();
  const shut = await settle(page, () => document.querySelector('[data-ta*="LabState.panel"]').getBoundingClientRect().height === 0);
  t.check('SizeTransition closes to nothing', shut === true, `${await ph()}`);
  const gone = await settle(page, () => getComputedStyle(document.querySelector('[data-ta*="LabState.panel"]')).visibility === 'hidden');
  t.check('and leaves the accessibility tree', gone === true && (await page.locator('text=Panel que se pliega').isHidden()));
  // AnimatedSize(animateWidth: true, onEnd:): the width goes through the
  // middle, the height too, and onEnd runs once when it settles.
  const wide = shells.nth(2);
  const box = () => wide.evaluate((e) => [e.getBoundingClientRect().width, e.getBoundingClientRect().height]);
  const endLabel = '[data-tt="LabState.sizeEndLabel"]';
  t.check('animateWidth: the shell hugs the content at rest', (await box()).join() === '60,40', (await box()).join());
  await expectText('onEnd has not run yet', endLabel, 'Fin: 0');
  await page.getByRole('button', { name: 'Ensanchar' }).click();
  await page.waitForTimeout(120);
  const [mw, mh] = await box();
  t.check('animateWidth: width and height go through the middle', mw > 60 && mw < 240 && mh > 40 && mh < 60, `${mw}x${mh}`);
  const wideDone = await settle(page, () => {
    const r = document.querySelectorAll('[data-tsz]')[2].getBoundingClientRect();
    return Math.round(r.width) === 240 && Math.round(r.height) === 60;
  });
  t.check('animateWidth: ends at the content width', wideDone === true, (await box()).join());
  await expectText('onEnd runs once, when the size animation ends', endLabel, 'Fin: 1');
  await page.waitForTimeout(300);
  t.check('and not again', (await text(endLabel)) === 'Fin: 1', await text(endLabel));
  // Cut short by a second change: onEnd only for the one that finishes.
  await page.getByRole('button', { name: 'Ensanchar' }).click();
  await page.waitForTimeout(100);
  await page.getByRole('button', { name: 'Ensanchar' }).click();
  await expectText('a change in the middle of an animation ends once, not twice', endLabel, 'Fin: 2');
  t.check('no page errors', page.problems.length === 0, page.problems.join(' | '));

  // Reduced motion: the size is instant and onEnd still runs.
  {
    const rm = await t.page({ reducedMotion: 'reduce', viewport: { width: 700, height: 2000 } });
    await trackHydration(rm);
    await rm.goto(t.url);
    await rm.mouse.move(1, 1);
    await rm.mouse.down();
    await rm.mouse.up();
    await hydrated(rm);
    await rm.getByRole('button', { name: 'Ensanchar' }).click();
    const instant = await settle(rm, () => {
      const r = document.querySelectorAll('[data-tsz]')[2].getBoundingClientRect();
      return Math.round(r.width) === 240;
    });
    t.check('reduced motion: the width is instant', instant === true);
    const ended = await settle(rm, (sel) => document.querySelector(sel).textContent === 'Fin: 1', endLabel);
    t.check('reduced motion: onEnd runs', ended === true, await rm.locator(endLabel).textContent());
  }
});

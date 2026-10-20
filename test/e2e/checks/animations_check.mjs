// Explicit animations of test/fixtures/apps/lab (/animations) in a real browser: CSS entrances
// and loops with no JavaScript, AnimationControllers of a ThorState played
// by the engine (Web Animations), stop mid-way, reduced motion.
//
//   tool/thor e2e animations                    (builds, serves, runs)
//   node test/e2e/checks/animations_check.mjs [url]
import { e2e, hydrated, settle, trackHydration } from './lib/e2e.mjs';

await e2e('animations', { site: 'test/fixtures/apps/lab/build/site', path: 'animations' }, async (t) => {
  // The element of a transition driven by `id` (its data-ta names it).
  const byController = (id) => `[data-ta*='"${id}"']`;
  const panel = byController('MotionState.reveal');
  const spinner = byController('MotionState.spin');
  const label = '[data-tt="MotionState.revealLabel"]';
  const style = (page, sel, prop) =>
    page.$eval(sel, (el, p) => getComputedStyle(el).getPropertyValue(p), prop);
  const opacity = async (page, sel) => Number(await style(page, sel, 'opacity'));

  // 1. Before the engine: the first frame and the CSS animations.
  {
    const page = await t.page();
    const errors = [];
    page.on('pageerror', (e) => errors.push(String(e)));
    await page.goto(t.url);
    t.check('the panel starts hidden (first frame, no engine)', (await opacity(page, panel)) === 0);
    t.check('and in its first decoration', (await style(page, panel, 'border-top-left-radius')) === '12px' && (await style(page, panel, 'background-color')) === 'rgb(238, 242, 255)');
    const css = await page.$$eval('*', (els) =>
      els.flatMap((e) => e.getAnimations().filter((a) => a instanceof CSSAnimation).map((a) => a.animationName)),
    );
    t.check('the entrance and the loop are CSS animations', css.length === 2, JSON.stringify(css));
    const heading = page.locator('h1');
    await page.waitForTimeout(700);
    t.check('the entrance ends in place', (await heading.evaluate((e) => getComputedStyle(e).translate)).startsWith('0'),
      await heading.evaluate((e) => getComputedStyle(e).translate));
    t.check('no page errors', errors.length === 0, errors.join('; '));
  }

  // 2. With the engine: the state's controllers.
  {
    const page = await t.page();
    const errors = [];
    page.on('pageerror', (e) => errors.push(String(e)));
    page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
    await trackHydration(page);
    await page.goto(t.url);
    await page.mouse.move(1, 1);
    await page.mouse.down();
    await page.mouse.up();
    t.check('engine hydrates', await hydrated(page).then(() => true, () => false));
    t.check('the loop keeps running after hydration',
      (await page.$$eval('*', (els) => els.flatMap((e) => e.getAnimations()).filter((a) => a instanceof CSSAnimation && a.playState === 'running').length)) >= 1);

    await page.getByRole('button', { name: 'Mostrar' }).click();
    t.check('status: appearing', (await page.textContent(label)) === 'Apareciendo…', await page.textContent(label));
    const shown = await settle(page, ([s, l]) =>
      getComputedStyle(document.querySelector(s)).opacity === '1' && document.querySelector(l).textContent === 'Visible', [panel, label]);
    t.check('forward: the panel shows, the status completes', shown === true, await page.textContent(label));

    const radius = () => style(page, panel, 'border-top-left-radius').then(parseFloat);
    t.check('DecoratedBoxTransition: the panel has gone through its corners (12 → 24 px)', (await radius()) > 12 && (await radius()) <= 24, String(await radius()));
    t.check('and its colour (the second decoration at the end)', (await style(page, panel, 'background-color')) === 'rgb(199, 210, 254)', await style(page, panel, 'background-color'));
    await page.getByRole('button', { name: 'Ocultar' }).click();
    const hidden = await settle(page, ([s, l]) =>
      getComputedStyle(document.querySelector(s)).opacity === '0' && document.querySelector(l).textContent === 'Oculto', [panel, label]);
    t.check('reverse: hidden and dismissed', hidden === true, await page.textContent(label));

    // animateTo / animateBack / fling: stop part of the way.
    await page.getByRole('button', { name: 'A la mitad', exact: true }).click();
    const halfWay = await settle(page, ([s, l]) => Math.abs(Number(getComputedStyle(document.querySelector(s)).opacity) - 0.5) < 0.02 && document.querySelector(l).textContent === 'Visible', [panel, label]);
    t.check('animateTo(0.5): the panel stops half way and the status completes', halfWay === true, `${await opacity(page, panel)} ${await page.textContent(label)}`);
    await page.waitForTimeout(400);
    t.check('animateTo(0.5): it stays there', Math.abs((await opacity(page, panel)) - 0.5) < 0.02, String(await opacity(page, panel)));
    await page.getByRole('button', { name: 'Bajar a un cuarto', exact: true }).click();
    const quarter = await settle(page, ([s, l]) => Math.abs(Number(getComputedStyle(document.querySelector(s)).opacity) - 0.25) < 0.02 && document.querySelector(l).textContent === 'Oculto', [panel, label]);
    t.check('animateBack(0.25): it goes down to a quarter and the status dismisses', quarter === true, `${await opacity(page, panel)} ${await page.textContent(label)}`);
    await page.getByRole('button', { name: 'Lanzar', exact: true }).click();
    const flung = await settle(page, ([s, l]) => getComputedStyle(document.querySelector(s)).opacity === '1' && document.querySelector(l).textContent === 'Visible', [panel, label]);
    t.check('fling(): it runs to the end', flung === true, `${await opacity(page, panel)} ${await page.textContent(label)}`);
    await page.getByRole('button', { name: 'Ocultar', exact: true }).click();
    await settle(page, ([s]) => getComputedStyle(document.querySelector(s)).opacity === '0', [panel]);

    await page.getByRole('button', { name: 'Girar' }).click();
    await page.waitForTimeout(200);
    const a = await style(page, spinner, 'rotate');
    await page.waitForTimeout(200);
    const b = await style(page, spinner, 'rotate');
    t.check('repeat: it spins', a !== b, `${a} → ${b}`);
    await page.getByRole('button', { name: 'Detener' }).click();
    const c = await style(page, spinner, 'rotate');
    await page.waitForTimeout(250);
    t.check('stop: it freezes where it was', c === (await style(page, spinner, 'rotate')), c);
    t.check('the button follows the controller (Watch of isAnimating)',
      (await page.getByRole('button', { name: 'Girar' }).count()) === 1);

    // repeat(min: 0.25, max: 0.5, reverse: true): a quarter turn back and forth.
    await page.getByRole('button', { name: 'Mecer' }).click();
    const angles = [];
    for (let i = 0; i < 40; i++) {
      await page.waitForTimeout(30);
      angles.push(parseFloat(await style(page, spinner, 'rotate')));
    }
    const [lo, hi] = [Math.min(...angles), Math.max(...angles)];
    t.check('repeat(min:, max:): it moves', hi - lo > 40, `${lo} ${hi}`);
    t.check('repeat(min:, max:): it stays between a quarter and a half turn', lo >= 89 && hi <= 181, `${lo} ${hi}`);
    await page.getByRole('button', { name: 'Detener' }).click();
    const rocked = await style(page, spinner, 'rotate');
    await page.waitForTimeout(250);
    t.check('and stop freezes it there', rocked === (await style(page, spinner, 'rotate')) && parseFloat(rocked) >= 89, rocked);

    const heart = byController('MotionState.beat');
    await page.getByRole('button', { name: 'Latir' }).click();
    await page.waitForTimeout(120);
    const mid = Number(await style(page, heart, 'scale'));
    t.check('TweenSequence: the beat grows first', mid > 1.05, String(mid));
    const rest = await settle(page, (s) => ['1', 'none'].includes(getComputedStyle(document.querySelector(s)).scale), heart);
    t.check('and settles back at 1', rest === true, await style(page, heart, 'scale'));
    t.check('no errors', errors.length === 0, errors.join('; '));

    // Implicit animations: the element transitions between the states.
    const tilt = '[data-tv="ImplicitState.isTilted"]';
    t.check('AnimatedContainer starts untransformed', (await style(page, tilt, 'transform')) === 'none');
    await page.getByRole('button', { name: 'Inclinar' }).click();
    await page.waitForTimeout(120);
    const midT = (await style(page, tilt, 'transform')).match(/matrix\(([^)]+)\)/)?.[1].split(',').map(Number);
    t.check('the transform goes through the middle (translation between 0 and 24 along a rotation)',
      midT && midT[4] > 0 && midT[4] < 24 && midT[1] > 0 && midT[1] < Math.sin(0.6), JSON.stringify(midT));
    const doneT = await settle(page, (s) => {
      const m = getComputedStyle(document.querySelector(s)).transform.match(/matrix\(([^)]+)\)/);
      return !!m && Math.abs(Number(m[1].split(',')[1]) - Math.sin(0.6)) < 0.001;
    }, tilt);
    t.check('and ends at the matrix', doneT === true, await style(page, tilt, 'transform'));
    t.check('the transform does not move the layout',
      (await page.locator(tilt).evaluate((e) => e.offsetWidth)) === 40);

    const liftEl = page.locator('[data-tv="ImplicitState.isLifted"]');
    t.check('TweenAnimationBuilder starts at its first target', Number(await liftEl.evaluate((e) => getComputedStyle(e).opacity)) === 1);
    await page.getByRole('button', { name: 'Subir' }).click();
    await page.waitForTimeout(120);
    const midO = Number(await liftEl.evaluate((e) => getComputedStyle(e).opacity));
    t.check('TweenAnimationBuilder: opacity goes through the middle', midO < 1 && midO > 0.3, String(midO));
    const doneO = await settle(page, () => Math.abs(Number(getComputedStyle(document.querySelector('[data-tv="ImplicitState.isLifted"]')).opacity) - 0.3) < 0.01);
    t.check('and ends at the target', doneO === true, String(await liftEl.evaluate((e) => getComputedStyle(e).opacity)));

    const type = '[data-tv="ImplicitState.isBold"]';
    const spacing = () => page.locator(type).evaluate((e) => (parseFloat(getComputedStyle(e).letterSpacing) || 0));
    const weight = () => page.locator(type).evaluate((e) => Number(getComputedStyle(e).fontWeight));
    t.check('AnimatedDefaultTextStyle starts light', (await weight()) === 300 && (await spacing()) === 0);
    await page.getByRole('button', { name: 'Resaltar' }).click();
    await page.waitForTimeout(120);
    const [w1, ls1] = [await weight(), await spacing()];
    t.check('weight and letter-spacing go through the middle', w1 > 300 && w1 < 800 && ls1 > 0 && ls1 < 4, `${w1} ${ls1}`);
    const doneW = await settle(page, (s) => Number(getComputedStyle(document.querySelector(s)).fontWeight) === 800 && parseFloat(getComputedStyle(document.querySelector(s)).letterSpacing) === 4, type);
    t.check('and end at the target', doneW === true, `${await weight()} ${await spacing()}`);
    t.check('no errors after the implicit animations', errors.length === 0, errors.join('; '));
  }

  // 3. Reduced motion: nothing moves, everything shows where it rests.
  {
    const page = await t.page({ reducedMotion: 'reduce' });
    await trackHydration(page);
    await page.goto(t.url);
    await page.mouse.move(1, 1);
    await page.mouse.down();
    await page.mouse.up();
    await hydrated(page);
    const dot = await page.$$eval('*', (els) => {
      const loop = els.find((e) => e.getAnimations().some((x) => x instanceof CSSAnimation && getComputedStyle(e).width === '16px'));
      return loop ? getComputedStyle(loop).opacity : 'none';
    });
    t.check('the loop rests at its end', dot === '1' || dot === 'none', dot);
    await page.getByRole('button', { name: 'A la mitad', exact: true }).click();
    t.check('animateTo(0.5) with reduced motion: it jumps there', Math.abs((await opacity(page, panel)) - 0.5) < 0.02 && (await page.textContent(label)) === 'Visible', `${await opacity(page, panel)} ${await page.textContent(label)}`);
    await page.getByRole('button', { name: 'Mostrar' }).click();
    t.check('forward jumps to the end', (await page.textContent(label)) === 'Visible' && (await opacity(page, panel)) === 1,
      await page.textContent(label));
    t.check('DecoratedBoxTransition with reduced motion rests in the second decoration', (await style(page, panel, 'background-color')) === 'rgb(199, 210, 254)', await style(page, panel, 'background-color'));
    await page.getByRole('button', { name: 'Mecer' }).click();
    await page.waitForTimeout(100);
    t.check('repeat(min:, max:) with reduced motion rests at the top of its stretch', Math.abs(parseFloat(await style(page, spinner, 'rotate')) - 180) < 1, await style(page, spinner, 'rotate'));
  }
});

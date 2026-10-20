// A burst of rapid clicks on the controllers of
// test/fixtures/apps/lab (/animations) with the CPU throttled 4x; the label (status), the panel's
// opacity (value) and the Girar/Detener button (isAnimating) must agree once it
// settles, with no page errors.
//
//   tool/thor export lab && node test/e2e/checks/animations_burst_check.mjs
import { e2e, hydrated, settle, trackHydration } from './lib/e2e.mjs';

await e2e('animations-burst', { site: 'test/fixtures/apps/lab/build/site', path: 'animations' }, async (t) => {
  const panel = "[data-ta*='\"MotionState.reveal\"']";
  const label = '[data-tt="MotionState.revealLabel"]';
  const page = await t.page();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
  await trackHydration(page);
  await page.goto(t.url);
  await page.mouse.move(1, 1);
  await page.mouse.down();
  await page.mouse.up();
  await hydrated(page);
  const cdp = await page.context().newCDPSession(page);
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: 4 });

  // Every text the label ever shows, in order.
  await page.evaluate((l) => {
    window.__labels = [];
    new MutationObserver(() => window.__labels.push(document.querySelector(l).textContent)).observe(
      document.querySelector(l), { childList: true, characterData: true, subtree: true });
  }, label);

  const click = (n) => page.getByRole('button', { name: n }).click({ noWaitAfter: true, timeout: 5000 });
  const names = ['Mostrar', 'Ocultar', 'Girar', 'Detener', 'Latir'];
  // A burst: no waiting between clicks.
  for (let i = 0; i < 40; i++) {
    const pick = names[(i * 7 + (i >> 1)) % names.length];
    try { await click(pick); } catch { /* the button is swapped while spinning */ }
  }
  const ended = await settle(page, ([s, l]) => {
    const text = document.querySelector(l).textContent;
    const o = getComputedStyle(document.querySelector(s)).opacity;
    return (text === 'Visible' && o === '1') || (text === 'Oculto' && o === '0');
  }, [panel, label], { timeout: 8000 });
  const text = await page.textContent(label);
  const op = await page.$eval(panel, (e) => getComputedStyle(e).opacity);
  t.check('burst then settle: label and panel opacity agree', ended === true, `${text} / ${op}`);
  const labels = await page.evaluate(() => window.__labels);
  t.check('the label only ever shows a real status', labels.every((x) => ['Oculto', 'Apareciendo…', 'Ocultándose…', 'Visible'].includes(x)), JSON.stringify(labels.slice(-6)));

  // Show then hide with no gap, 25 times: it must end dismissed.
  for (let i = 0; i < 25; i++) {
    await click('Mostrar').catch(() => {});
    await click('Ocultar').catch(() => {});
  }
  const back = await settle(page, ([s, l]) => document.querySelector(l).textContent === 'Oculto' &&
    getComputedStyle(document.querySelector(s)).opacity === '0', [panel, label], { timeout: 8000 });
  t.check('show/hide x25 ends dismissed and hidden', back === true, `${await page.textContent(label)}`);

  // Spinning state and its button.
  const spinning = (await page.getByRole('button', { name: 'Detener' }).count()) === 1;
  const idle = (await page.getByRole('button', { name: 'Girar' }).count()) === 1;
  t.check('exactly one of Girar/Detener shows', spinning !== idle);
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: 1 });
  t.check('no page errors', errors.length === 0, errors.join('; '));
});

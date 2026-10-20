// Hybrid mode (FlutterView) of test/fixtures/apps/hybrid in a real browser: the page is
// complete without Flutter, each view mounts on its own trigger, both views
// share one engine, nothing moves when Flutter paints, and messages from
// Flutter reach the page's ThorState.
//
//   thor build test/fixtures/apps/hybrid && node test/e2e/checks/hybrid_check.mjs [url]
import { e2e, hydrated, settle, trackHydration } from './lib/e2e.mjs';

const chart = '[data-thor-flutter][aria-label="Ventas por mes"]';
const counter = '[data-thor-flutter][aria-label="Contador de Flutter"]';
const viewport = { width: 800, height: 900 };

await e2e('hybrid', { site: 'test/fixtures/apps/hybrid/build/site', timeout: 180_000 }, async (t) => {
  // 1. Without JS: the placeholders are the page (no JS), in their final size.
  {
    const page = await t.page({ javaScriptEnabled: false, viewport });
    await page.goto(t.url);
    const box = await page.locator(chart).boundingBox();
    t.check('no JS: chart placeholder visible', await page.getByText('Ventas por mes: ene 12').isVisible());
    t.check('no JS: host sized 16:9 without Flutter', Math.abs(box.width / box.height - 16 / 9) < 0.01, JSON.stringify(box));
    t.check('no JS: counter placeholder in the page', (await page.getByText('Contador: 3').count()) === 1);
    t.check('no JS: no flutter-view', (await page.locator('flutter-view').count()) === 0);
    await page.context().close();
  }

  // 2. With JS: the bootstrap is held back 800 ms to see the page before it.
  const page = await t.page({ viewport });
  await trackHydration(page);
  await page.addInitScript(() => {
    window.__cls = 0;
    new PerformanceObserver((l) => {
      for (const e of l.getEntries()) if (!e.hadRecentInput) window.__cls += e.value;
    }).observe({ type: 'layout-shift', buffered: true });
  });
  const requests = [];
  page.on('request', (r) => requests.push(new URL(r.url()).pathname));
  await page.route('**/flutter/flutter_bootstrap.js', async (route) => {
    await new Promise((ok) => setTimeout(ok, 800));
    await route.continue();
  });
  await page.goto(t.url);
  const before = await page.locator(chart).boundingBox();
  const state = (sel) => page.locator(sel).getAttribute('data-thor-flutter-state');
  t.check('placeholder visible before Flutter loads', await page.getByText('Ventas por mes: ene 12').isVisible());
  t.check('chart in view is loading', (await state(chart)) === 'loading', await state(chart));
  t.check('counter below the fold not mounted yet', (await state(counter)) === null, await state(counter));

  const ready = await settle(page, (s) => document.querySelector(s)?.getAttribute('data-thor-flutter-state') === 'ready', chart, { timeout: 30_000 });
  t.check('chart view paints (ready)', ready === true, await state(chart));
  const after = await page.locator(chart).boundingBox();
  t.check('host keeps its box when Flutter paints', JSON.stringify(before) === JSON.stringify(after), `${JSON.stringify(before)} → ${JSON.stringify(after)}`);
  t.check('placeholder removed after the first frame', (await page.locator(`${chart} [data-thor-flutter-placeholder]`).count()) === 0);
  const view = await page.locator(`${chart} > flutter-view`).boundingBox();
  t.check('flutter-view fills the host', view && Math.abs(view.width - after.width) < 1 && Math.abs(view.height - after.height) < 1, JSON.stringify(view));
  t.check('aria-busy cleared', (await page.locator(chart).getAttribute('aria-busy')) === null);
  const labels = await page.locator(`${chart} [aria-label], ${chart} flt-semantics`).evaluateAll((l) => l.map((e) => e.getAttribute('aria-label') ?? e.textContent).join('|'));
  t.check('Flutter semantics inside the host', /abr: 24/.test(labels), labels.slice(0, 200));

  // Messages from Flutter → ThorState (the engine must be running).
  await page.mouse.move(5, 5);
  await page.mouse.down();
  await page.mouse.up();
  t.check('engine hydrates', await hydrated(page).then(() => true, () => false));
  const w = (after.width - 32 - 8 * 4) / 5;
  await page.mouse.click(after.x + 16 + 3 * (w + 8) + w / 2, after.y + after.height - 60);
  const bar = await settle(page, () => document.querySelector('[data-tt="HybridState.barLabel"]')?.textContent, null, { timeout: 5000 });
  t.check('tap on a bar reaches the page', bar === 'Tocaste abr: 24 ventas.', bar);

  // Second view: mounts when scrolled to, same engine.
  await page.locator(counter).scrollIntoViewIfNeeded();
  const ready2 = await settle(page, (s) => document.querySelector(s)?.getAttribute('data-thor-flutter-state') === 'ready', counter, { timeout: 20_000 });
  t.check('counter view paints after scrolling to it', ready2 === true, await state(counter));
  t.check('two flutter-views, one per host', (await page.locator('[data-thor-flutter] > flutter-view').count()) === 2);
  const once = (name) => requests.filter((r) => r.endsWith(name)).length;
  t.check('one bootstrap and one main.dart.js for both views', once('flutter_bootstrap.js') === 1 && once('main.dart.js') === 1, `${once('flutter_bootstrap.js')} / ${once('main.dart.js')}`);
  // Through Flutter's semantics tree: a real button a screen reader sees.
  const plus = page.locator(counter).getByRole('button', { name: 'Sumar' });
  t.check('Flutter button exposed to assistive tech', (await plus.count()) === 1);
  await plus.click();
  const count = await settle(page, () => document.querySelector('[data-tt="HybridState.countLabel"]')?.textContent?.includes(' 4'), null, { timeout: 5000 });
  t.check('counter message reaches the page', count === true, await page.locator('[data-tt="HybridState.countLabel"]').textContent());
  const cls = await page.evaluate(() => window.__cls);
  t.check('no layout shift (CLS 0)', cls === 0, `CLS ${cls}`);
  t.check('no console errors', page.problems.length === 0, page.problems.join(' | '));

  // 3. The other triggers, on the same markup: the chart `eager`, the
  // counter `interaction` (mounts on the first pointerdown, not on sight).
  const modes = await t.page({ viewport });
  await modes.route(t.url, async (route) => {
    const res = await route.fetch();
    let html = await res.text();
    html = html.replace(/data-thor-flutter-load="visible"/, 'data-thor-flutter-load="eager"');
    html = html.replace(/data-thor-flutter-load="visible"/, 'data-thor-flutter-load="interaction"');
    await route.fulfill({ response: res, body: html });
  });
  await modes.goto(t.url);
  const eager = await settle(modes, (s) => document.querySelector(s)?.getAttribute('data-thor-flutter-state') === 'ready', chart, { timeout: 20_000 });
  t.check('eager view paints', eager === true);
  await modes.locator(counter).scrollIntoViewIfNeeded();
  await modes.waitForTimeout(500);
  t.check('interaction view does not mount on sight', (await modes.locator(counter).getAttribute('data-thor-flutter-state')) === null);
  await modes.locator(counter).click();
  const tapped = await settle(modes, (s) => document.querySelector(s)?.getAttribute('data-thor-flutter-state') === 'ready', counter, { timeout: 20_000 });
  t.check('interaction view mounts on the first tap', tapped === true);
  t.check('no console errors (other triggers)', modes.problems.length === 0, modes.problems.join(' | '));

  // 4. A missing build: placeholder stays, state=error, the page works.
  const broken = await t.page({ viewport });
  await broken.route('**/flutter/flutter_bootstrap.js', (r) => r.fulfill({ status: 404, body: '' }));
  await broken.goto(t.url);
  const err = await settle(broken, (s) => document.querySelector(s)?.getAttribute('data-thor-flutter-state') === 'error', chart);
  t.check('missing build: state error', err === true);
  t.check('missing build: placeholder stays', await broken.getByText('Ventas por mes: ene 12').isVisible());
});

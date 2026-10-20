// A cookie-persisted field (`state(…, cookie:)`, test/fixtures/apps/lab (/controls), «compacto») is
// written once per frame, not once per change, and the last value survives a
// reload right after a burst (the write is flushed on `pagehide`). Both engines.
//
//   tool/thor e2e persist                    (lite)    tool/thor e2e persist-dart
//   node test/e2e/checks/persist_check.mjs [url]
import { e2e, hydrated, settle, trackHydration } from './lib/e2e.mjs';

await e2e('persist', { site: 'test/fixtures/apps/lab/build/site', path: 'controls' }, async (t) => {
  const page = await t.page({ viewport: { width: 480, height: 1400 } });
  // Counts the writes to this field's cookie (and keeps the last), per document.
  await page.addInitScript(() => {
    const d = Object.getOwnPropertyDescriptor(Document.prototype, 'cookie');
    window.__writes = [];
    Object.defineProperty(document, 'cookie', {
      configurable: true,
      get: () => d.get.call(document),
      set(v) {
        if (String(v).startsWith('thor-s.compacto=')) window.__writes.push(String(v).split(';')[0]);
        d.set.call(document, v);
      },
    });
  });
  await trackHydration(page);
  await page.goto(t.url);
  await page.mouse.move(1, 1); // the first pointer event loads the engine
  await page.mouse.down();
  await page.mouse.up();
  t.check('engine hydrates', await hydrated(page).then(() => true, () => false));
  const label = () => page.locator('main').getByText(/^Vista (compacta|amplia)$/).first().textContent();
  const cookie = () => page.evaluate(() => /thor-s\.compacto=(\w+)/.exec(document.cookie)?.[1] ?? null);
  const clicks = (n, gap) =>
    page.evaluate(
      async ([n, gap]) => {
        const b = [...document.querySelectorAll('button')].find((x) => x.textContent.trim() === 'Cambiar vista');
        for (let i = 0; i < n; i++) {
          b.click();
          if (gap) await new Promise((r) => setTimeout(r, gap));
        }
      },
      [n, gap],
    );

  // A burst in one task: one write at most (the frame's), the final value in it.
  await clicks(51, 0); // odd: ends compact
  const sync = await settle(page, () => window.__writes.length > 0 && window.__writes.length);
  t.check('a synchronous burst of 51 changes is one cookie write', sync === 1, String(sync));
  t.check('the write holds the last value', (await cookie()) === 'true', await cookie());

  // A drag: 41 changes 5 ms apart (~200 ms, a dozen frames): far fewer writes.
  await page.evaluate(() => (window.__writes.length = 0));
  await clicks(41, 5); // odd: back to wide
  await settle(page, () => window.__writes.length > 0);
  await page.waitForTimeout(100);
  const drag = await page.evaluate(() => window.__writes.length);
  t.check('a drag writes per frame, not per change', drag >= 1 && drag < 25, String(drag));
  t.check('the drag ends on its last value', (await cookie()) === 'false', await cookie());

  // A burst and a reload right after it, not waiting for the frame.
  await clicks(31, 0); // odd: compact
  await page.reload();
  t.check('the value written right before a reload survives', (await cookie()) === 'true', await cookie());
  await page.mouse.move(1, 1);
  await page.mouse.down();
  await page.mouse.up();
  const shown = await settle(page, () => /Vista compacta/.test(document.body.textContent));
  t.check('the reloaded page starts from it', shown === true, await label());
  t.check('no console errors', page.problems.length === 0, page.problems.join(' | '));
});

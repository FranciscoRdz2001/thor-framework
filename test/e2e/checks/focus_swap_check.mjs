// A `Watch` that swaps its variant while the user types in a field inside
// it (test/fixtures/apps/lab (/edge-cases), `case-focus-swap`): the old subtree is replaced, so
// the focused field must be found again in the new one and keep its focus,
// caret and typed text; focus the user moved elsewhere is not taken back.
//
//   tool/thor e2e focus-swap                     (builds test/fixtures/apps/lab (/edge-cases), runs)
//   node test/e2e/checks/focus_swap_check.mjs [url]
import { e2e, hydrated, settle, trackHydration } from './lib/e2e.mjs';

const site = process.env.E2E_SITE ?? 'test/fixtures/apps/lab/build/site';

await e2e('focus-swap', { site, path: 'edge-cases' }, async (t) => {
  const page = await t.page();
  await trackHydration(page);
  await page.goto(t.url);
  await hydrated(page);

  const root = page.locator('.case-focus-swap');
  const where = () =>
    page.evaluate(() => {
      const a = document.activeElement;
      return { name: a?.name ?? a?.tagName, value: a?.value, start: a?.selectionStart, end: a?.selectionEnd };
    });

  // By id: typing a character swaps the variant (the hint of the other
  // field is gone/there) and the caret stays after the typed text.
  const first = root.locator('#swap-first');
  await first.click();
  await first.evaluate((el) => (el.__mark = 1));
  await page.keyboard.type('ab');
  let w = await where();
  t.check('by id: focus stays on the field after the variant swap', w.name === 'swapFirst', JSON.stringify(w));
  t.check('by id: the typed text and the caret survive', w.value === 'ab' && w.start === 2 && w.end === 2, JSON.stringify(w));
  await page.keyboard.type('c'); // first leaves the short state: another swap
  w = await where();
  t.check('by id: still focused after the hint goes', w.name === 'swapFirst' && w.value === 'abc' && w.start === 3, JSON.stringify(w));
  t.check('by id: the field is a new node (the swap replaced it)', (await first.evaluate((el) => el.__mark)) !== 1);

  // A caret in the middle is restored too.
  await page.keyboard.press('ArrowLeft');
  await page.keyboard.press('ArrowLeft');
  await page.keyboard.press('Delete'); // "ac": short again, swap
  w = await where();
  t.check('by id: a caret in the middle survives', w.name === 'swapFirst' && w.value === 'ac' && w.start === 1 && w.end === 1, JSON.stringify(w));

  // By name (no id).
  const second = root.locator('[name=swapSecond]');
  await second.click();
  await page.keyboard.type('xy');
  w = await where();
  t.check('by name: focus stays after the swap', w.name === 'swapSecond' && w.value === 'xy' && w.start === 2, JSON.stringify(w));
  await page.keyboard.type('z');
  w = await where();
  t.check('by name: and after the hint goes', w.name === 'swapSecond' && w.value === 'xyz', JSON.stringify(w));

  // Focus moved elsewhere meanwhile is not stolen: blur then type in the
  // other control; a swap triggered by the state must not refocus.
  await first.click();
  await page.keyboard.type('q'); // "acq" -> no longer short: swap
  await settle(page, () => document.activeElement?.name === 'swapFirst');
  await page.evaluate(() => document.activeElement.blur());
  await page.evaluate(() => {
    document.body.tabIndex = -1;
    document.body.focus();
  });
  w = await where();
  t.check('the user can leave: nothing refocuses a blurred field', w.name !== 'swapFirst' && w.name !== 'swapSecond', JSON.stringify(w));
});

// Keys pressed before the engine loads: the inline loader must queue
// the keydowns the engine would handle and replay them, with their `key`,
// once it hydrates. The engine request is held by the network while the user
// presses ⌘K / Ctrl+K (a `CallbackShortcuts` on the page, nothing focused),
// Enter in a field with `onSubmitted`, and Enter / Space on a `Gesture`
// (`role="button"`). A key on an element the engine ignores is not replayed,
// and a click is still replayed once.
//
//   tool/thor e2e early-keys                  (builds test/fixtures/apps/lab (/rows), runs)
//   node test/e2e/checks/early_keys_check.mjs
import { e2e, hydrated, settle, trackHydration } from './lib/e2e.mjs';

const site = process.env.E2E_SITE ?? 'test/fixtures/apps/lab/build/site';

await e2e('early-keys', { site, path: 'rows' }, async (t) => {
  const page = await t.page();
  await trackHydration(page);
  // Every keydown the page sees that the browser did not produce is a
  // replay: the loader's own, dispatched after hydration.
  await page.addInitScript(() => {
    window.__replays = [];
    document.addEventListener(
      'keydown',
      (e) => {
        if (!e.isTrusted) window.__replays.push(`${e.key}@${e.target.tagName}:${e.ctrlKey ? 'C' : ''}${e.metaKey ? 'M' : ''}`);
      },
      true,
    );
  });

  // The engine's request is held until `release()`.
  let release;
  const gate = new Promise((ok) => (release = ok));
  let engineAsked = false;
  await page.route(/\/engine\.[a-z]+\.[0-9a-f]+\.js(\?|$)|\/engine\.dart\.js(\?|$)/, async (route) => {
    engineAsked = true;
    await gate;
    await route.continue();
  });

  await page.goto(t.url, { waitUntil: 'domcontentloaded' });
  const state = () =>
    page.evaluate(() => ({
      pings: document.body.innerText.match(/atajos: (\d+)/)?.[1],
      taps: document.body.innerText.match(/toques: (\d+)/)?.[1],
      titles: [...document.querySelectorAll('li')].map((li) => li.innerText.split('\n')[0].trim()),
      quick: document.querySelector('input[name=quick]').value,
      hydrated: window.__thorHydrated,
    }));
  const before = await state();
  t.check('the page starts unhydrated with its first task', before.hydrated === false && before.titles.length === 4, JSON.stringify(before));

  // 1. Shortcuts with nothing focused (the key's target is <body>).
  await page.keyboard.press('Meta+k');
  await page.keyboard.press('Control+k');
  // 2. Enter in a text field with onSubmitted.
  await page.locator('input[name=quick]').focus();
  await page.keyboard.type('tarea temprana');
  await page.keyboard.press('Enter');
  // 3. Enter and Space on a role=button tap target.
  const tap = page.locator('[role=button]', { hasText: 'toques' });
  await tap.focus();
  await page.keyboard.press('Enter');
  await page.keyboard.press(' ');
  // 4. A key on an element the engine ignores, and a click.
  await page.locator('button', { hasText: 'Invertir' }).focus();
  await page.keyboard.press('Enter');
  await page.keyboard.press('a');
  t.check('the engine is still held while the keys were pressed', engineAsked && (await state()).hydrated === false);

  release();
  await hydrated(page);
  const done = await settle(page, () => /atajos: 2/.test(document.body.innerText) && /toques: 2/.test(document.body.innerText));
  const after = await state();
  const replays = await page.evaluate(() => window.__replays);

  t.check('⌘K and Ctrl+K each ran the shortcut once', done === true && after.pings === '2', `pings ${after.pings}`);
  t.check('Enter and Space on the role=button ran its tap once each', after.taps === '2', `taps ${after.taps}`);
  t.check(
    'Enter in the field added its task with the typed text, once',
    after.titles.length === 5 && after.titles.filter((x) => x.includes('tarea temprana')).length === 1,
    after.titles.join(' | '),
  );
  t.check('the field was cleared after its action', after.quick === '', after.quick);
  // Enter on the native button: its click replays once → one reverse → the
  // list starts with the task that was last (the new one, appended before).
  t.check(
    'the click on a native button still ran once (list reversed once)',
    after.titles[0].includes('tarea temprana') && after.titles.at(-1).includes('Comprar pan'),
    after.titles.join(' | '),
  );
  t.check(
    'the replays carried their key and modifiers',
    replays.includes('k@BODY:M') && replays.includes('k@BODY:C') && replays.includes('Enter@INPUT:') && replays.includes('Enter@DIV:') && replays.includes(' @DIV:'),
    replays.join(', '),
  );
  t.check(
    'a key on an element without engine handlers was not replayed',
    !replays.some((r) => r.endsWith('@BUTTON:')) && !replays.some((r) => r.startsWith('a@')),
    replays.join(', '),
  );

  // Once hydrated the loader is out of the way: a live ⌘K runs once, no replay.
  await page.locator('body').click({ position: { x: 5, y: 5 } });
  await page.keyboard.press('Control+k');
  const live = await settle(page, () => /atajos: 3/.test(document.body.innerText));
  t.check('after hydration a key runs once, straight', live === true);
  t.check('nothing else replayed after hydration', (await page.evaluate(() => window.__replays.length)) === replays.length);
  t.check('no console or page errors', page.problems.length === 0, page.problems.join('; '));
});

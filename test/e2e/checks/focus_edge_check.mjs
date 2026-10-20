// Adversarial cases of the focus kept across a `Watch` swap (test/fixtures/apps/lab (/edge-cases),
// `case-focus-edge`): a deliberately different new value, a vanished field,
// fields reordered, input types, fast typing, IME, nested Watches, rows,
// special and duplicated ids.
//
//   tool/thor e2e focus-edge focus-edge-dart
//   node test/e2e/checks/focus_edge_check.mjs [url]
import { e2e, hydrated, settle, trackHydration } from './lib/e2e.mjs';

const site = process.env.E2E_SITE ?? 'test/fixtures/apps/lab/build/site';

await e2e('focus-edge', { site, path: 'edge-cases' }, async (t) => {
  const page = await t.page();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  await trackHydration(page);
  await page.goto(t.url);
  await hydrated(page);

  const where = () =>
    page.evaluate(() => {
      const a = document.activeElement;
      return {
        tag: a?.tagName,
        name: a?.name ?? null,
        k: a?.dataset?.k ?? null,
        id: a?.id ?? null,
        value: a?.value,
        checked: a?.checked,
        text: a?.textContent,
        start: a?.selectionStart,
        end: a?.selectionEnd,
      };
    });
  const J = JSON.stringify;
  const field = (cls, sel) => page.locator(`.case-focus-edge .${cls} ${sel}`);

  // 1. The new variant sets another value on purpose: it wins over the old text.
  {
    const f = field('edge-reset', '#reset-f');
    await f.click();
    await page.keyboard.type('abc!');
    await settle(page, () => document.querySelector('.edge-reset input')?.value === 'server').catch(() => {});
    const w = await where();
    t.check('reset: the new variant value wins over the typed text', w.value === 'server', J(w));
    t.check('reset: and the field keeps the focus', w.name === 'resetF', J(w));
  }

  // 2. The focused field has no counterpart: the focus does not jump to
  // another field at the same index.
  {
    await field('edge-vanish', '[name=vb]').click();
    await page.keyboard.type('x');
    await settle(page, () => !!document.querySelector('[name=vz1]')).catch(() => {});
    const w = await where();
    t.check('vanished: focus does not land on another field', w.tag !== 'INPUT', J(w));
  }

  // 3. Unnamed fields and an inserted one: no refocus on a different field.
  {
    await field('edge-insert', '[data-k=u1]').click();
    await page.keyboard.type('x');
    await settle(page, () => document.querySelectorAll('.edge-insert input').length === 3).catch(() => {});
    const w = await where();
    t.check('unnamed + inserted: focus does not land on a different field', w.k !== 'u0' && w.k !== 'x', J(w));
  }

  // 4. Types without a (working) selection API, and a textarea.
  for (const [name, text, sel] of [
    ['tEmail', 'a@b.co', null],
    ['tNum', '1234', null],
  ]) {
    const f = field('edge-types', `[name=${name}]`);
    await f.click();
    await page.keyboard.type(text);
    const w = await where();
    t.check(`type ${name}: focus and text survive the swaps`, w.name === name && w.value === text, J(w));
  }
  {
    const f = field('edge-types', '[name=tDate]');
    await f.click();
    await f.fill('2024-05-06');
    const w = await where();
    t.check('type date: focus and value survive', w.name === 'tDate' && w.value === '2024-05-06', J(w));
  }
  {
    const f = field('edge-types', '[name=tArea]');
    await f.click();
    await page.keyboard.type('ab');
    await page.keyboard.press('Enter');
    await page.keyboard.type('cd');
    await page.keyboard.press('ArrowLeft');
    await page.keyboard.press('ArrowLeft');
    await page.keyboard.type('Z');
    const w = await where();
    t.check('textarea: text and caret survive', w.name === 'tArea' && w.value === 'ab\nZcd' && w.start === 4, J(w));
  }

  // 5. Fast typing: every char swaps; nothing lost or duplicated.
  {
    const f = field('edge-fast', '[name=fast]');
    await f.click();
    const text = 'abcdefghij0123456789';
    await page.keyboard.type(text, { delay: 0 });
    const w = await where();
    t.check('fast: 20 chars, each swapping, none lost or doubled', w.name === 'fast' && w.value === text && w.start === 20, J(w));
  }

  // 6. Checkbox and button.
  {
    const c = field('edge-controls', '[name=fcCheck]');
    await c.focus();
    await page.keyboard.press('Space');
    let w = await where();
    t.check('checkbox: focus stays after the swap', w.name === 'fcCheck' && w.checked === true, J(w));
    await page.keyboard.press('Space');
    w = await where();
    t.check('checkbox: again, and the state follows', w.name === 'fcCheck' && w.checked === false, J(w));
    await field('edge-controls', 'button').focus();
    await page.keyboard.press('Enter');
    w = await where();
    t.check('button: focus stays after the swap', w.tag === 'BUTTON' && /Press/.test(w.text), J(w));
  }

  // 7. Nested Watches swapping at once.
  {
    const f = field('edge-nested', '[name=nest]');
    await f.click();
    await page.keyboard.type('abc');
    const w = await where();
    t.check('nested: focus, text and caret survive', w.name === 'nest' && w.value === 'abc' && w.start === 3, J(w));
  }

  // 8. A swap inside a Watch.list row.
  {
    const f = field('edge-list', 'input').nth(1);
    await f.click();
    await page.keyboard.type('abc');
    const r = await page.evaluate(() => {
      const a = document.activeElement;
      const all = [...document.querySelectorAll('.edge-list input')];
      return { index: all.indexOf(a), value: a?.value };
    });
    t.check('row: the second row keeps focus and text', r.index === 1 && r.value === 'abc', J(r));
  }

  // 9. Special characters in ids and a duplicated id.
  {
    await field('edge-ids', '[data-k=special]').click();
    await page.keyboard.type('ab');
    let w = await where();
    t.check('id with CSS-special characters', w.k === 'special' && w.value === 'ab', J(w));
    await field('edge-ids', '[data-k=dup2]').click();
    await page.keyboard.type('xy');
    w = await where();
    t.check('duplicated id: the same one of them keeps the focus', w.k === 'dup2' && w.value === 'xy', J(w));
  }

  // 10. IME composition in progress is not cut by a swap: the same
  // sequence in a field outside any Watch is the reference.
  {
    const cdp = await page.context().newCDPSession(page);
    const compose = async () => {
      await cdp.send('Input.imeSetComposition', { text: 'に', selectionStart: 1, selectionEnd: 1 });
      await cdp.send('Input.imeSetComposition', { text: 'にほ', selectionStart: 2, selectionEnd: 2 });
      await cdp.send('Input.insertText', { text: 'にほん' });
    };
    await page.evaluate(() => {
      const i = document.createElement('input');
      i.id = 'ime-ref';
      document.body.append(i);
    });
    await page.locator('#ime-ref').click();
    await compose();
    const ref = await where();
    const f = field('edge-fast', '[name=fast]');
    await f.fill('');
    await f.click();
    await compose();
    const w = await where();
    t.check('IME: a composition inside a swapping Watch ends as outside one', w.name === 'fast' && w.value === ref.value, J({ ref: ref.value, w }));
  }

  t.check('no page errors', errors.length === 0, errors.join('; '));
});

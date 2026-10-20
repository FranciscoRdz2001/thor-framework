// Checks thor_ui's DropdownMenu in a real browser, with and without
// JavaScript (test/fixtures/apps/lab (/edge-cases), `case-dropdown-menu`): opening, keyboard
// (arrows, type-ahead, Enter, Esc), the pointer, the filter field, the
// picked value reaching the button, the hidden <select>, a ThorState
// method and a plain GET form; without JS the native <select> takes over.
//
//   tool/thor e2e dropdown                       (builds test/fixtures/apps/lab (/edge-cases), runs)
//   node test/e2e/checks/dropdown_check.mjs [url]
import { e2e, settle, trackHydration } from './lib/e2e.mjs';

await e2e('dropdown', { site: 'test/fixtures/apps/lab/build/site', path: 'edge-cases' }, async (t) => {
  // --- With JS ---------------------------------------------------------
  {
    const page = await t.page({ viewport: { width: 1024, height: 900 } });
    await trackHydration(page);
    await page.goto(t.url, { waitUntil: 'load' });
    // The engine loads on idle or on the first interaction.
    await page.mouse.move(1, 1);
    const hydrated = await settle(page, () => window.__thorHydrated);
    t.check('[js] engine hydrates', hydrated);

    const menus = page.locator('.case-dropdown-menu [data-t-dd]');
    const fruit = menus.nth(0);
    const color = menus.nth(1);
    const state = (menu) =>
      menu.evaluate((root) => {
        const button = root.querySelector('button[aria-haspopup]');
        const panel = root.querySelector('[popover]');
        const active = document.getElementById(button.getAttribute('aria-activedescendant') ?? '');
        return {
          open: panel.matches(':popover-open'),
          expanded: button.getAttribute('aria-expanded'),
          label: root.querySelector('[data-tdl]').textContent,
          hint: root.querySelector('[data-tdl]').hasAttribute('data-hint'),
          value: root.querySelector('select').value,
          active: active?.textContent ?? null,
          selected: [...root.querySelectorAll('[role=option][aria-selected=true]')].map((o) => o.textContent),
          focused: document.activeElement === button ? 'button' : document.activeElement?.tagName.toLowerCase(),
        };
      });
    // `toggle` events are queued: poll until [ok] holds (or give up and
    // return the last state, which the check then reports).
    const until = async (menu, ok) => {
      for (let i = 0; i < 60; i++) {
        const now = await state(menu);
        if (ok(now)) return now;
        await page.waitForTimeout(16);
      }
      return state(menu);
    };
    const button = (menu) => menu.locator('button[aria-haspopup]');
    const picked = () => page.locator('.case-dropdown-menu').evaluate((c) => c.textContent.match(/Picked: [^)]*\)/)?.[0]);

    let s = await state(fruit);
    t.check('[js] starts closed on the initial selection', !s.open && s.expanded === 'false' && s.label === 'Banana' && s.value === 'banana', JSON.stringify(s));

    await button(fruit).click();
    s = await until(fruit, (x) => x.expanded === 'true');
    t.check('[js] click opens, highlighting the picked entry', s.open && s.expanded === 'true' && s.active === 'Banana', JSON.stringify(s));

    await page.keyboard.press('ArrowDown');
    await page.keyboard.press('ArrowDown');
    await page.keyboard.press('ArrowDown'); // Grape is disabled: stays on Cherry
    s = await state(fruit);
    t.check('[js] arrows move the highlight, skipping disabled entries', s.active === 'Cherry', JSON.stringify(s));

    await page.keyboard.press('Enter');
    s = await state(fruit);
    t.check(
      '[js] Enter picks: label, value, aria-selected, closes, focus stays',
      !s.open && s.expanded === 'false' && s.label === 'Cherry' && s.value === 'cherry' && s.selected.join() === 'Cherry' && s.focused === 'button',
      JSON.stringify(s),
    );
    t.check('[js] onSelected reaches the ThorState', (await settle(page, () => document.body.textContent.includes('Picked: cherry (1)'))) === true, await picked());

    await page.keyboard.type('apr');
    s = await state(fruit);
    t.check('[js] type-ahead on the button opens and finds "apr…"', s.open && s.active === 'Apricot', JSON.stringify(s));
    await page.keyboard.press(' ');
    await page.waitForTimeout(800);
    await page.keyboard.press(' ');
    s = await state(fruit);
    t.check('[js] Space picks once typing pauses', !s.open && s.label === 'Apricot', JSON.stringify(s));

    await page.keyboard.press('ArrowDown');
    await page.keyboard.press('Escape');
    s = await until(fruit, (x) => x.expanded === 'false');
    t.check('[js] Esc closes without picking; focus back on the button', !s.open && s.expanded === 'false' && s.label === 'Apricot' && s.focused === 'button', JSON.stringify(s));

    await button(fruit).click();
    await until(fruit, (x) => x.expanded === 'true');
    await fruit.locator('[role=option]', { hasText: 'Apple' }).hover();
    s = await state(fruit);
    t.check('[js] the pointer highlights', s.active === 'Apple', JSON.stringify(s));
    await fruit.locator('[role=option]', { hasText: 'Apple' }).click();
    s = await state(fruit);
    t.check('[js] a click picks', !s.open && s.label === 'Apple' && s.value === 'apple', JSON.stringify(s));
    t.check('[js] every pick reaches the state', (await settle(page, () => document.body.textContent.includes('Picked: apple (3)'))) === true, await picked());

    await button(fruit).click();
    await page.mouse.click(900, 880);
    s = await until(fruit, (x) => x.expanded === 'false');
    t.check('[js] a click outside closes (light dismiss)', !s.open && s.expanded === 'false', JSON.stringify(s));

    // Room below the button (the page ends right under the case).
    await page.evaluate(() => (document.body.style.paddingBottom = '600px'));
    await button(fruit).evaluate((b) => b.scrollIntoView({ block: 'center' }));
    await button(fruit).click();
    await until(fruit, (x) => x.expanded === 'true');
    const under = await fruit.evaluate((root) => {
      const b = root.querySelector('button[aria-haspopup]').getBoundingClientRect();
      const p = root.querySelector('[popover]').getBoundingClientRect();
      return { gap: Math.round(p.top - b.bottom), left: Math.round(p.left - b.left), wider: p.width >= b.width - 0.5, bh: b.height };
    });
    t.check('[js] with room, the menu opens right under its button', under.gap === 0 && under.left === 0 && under.wider && under.bh === 56, JSON.stringify(under));
    if (process.env.E2E_SHOT) await page.screenshot({ path: process.env.E2E_SHOT.replace('.png', '-material.png') });
    await page.keyboard.press('Escape');
    await until(fruit, (x) => x.expanded === 'false');

    // The searchable one: filter field, check on the picked entry.
    s = await state(color);
    t.check('[js] shows the hint while nothing is picked', s.hint && s.label === 'Select a color' && s.value === '', JSON.stringify(s));
    await button(color).scrollIntoViewIfNeeded();
    await button(color).click();
    s = await until(color, (x) => x.focused === 'input');
    t.check('[js] opening focuses the filter field', s.open && s.focused === 'input', JSON.stringify(s));
    await page.keyboard.type('bl');
    const visible = await color.locator('[role=option]:not([hidden])').allTextContents();
    s = await state(color);
    t.check('[js] typing filters the entries and highlights the first match', visible.join() === 'Blue' && s.active === 'Blue', `${visible} ${JSON.stringify(s)}`);
    await page.keyboard.press('Enter');
    s = await state(color);
    t.check('[js] Enter in the field picks and closes', !s.open && !s.hint && s.label === 'Blue' && s.value === 'blue' && s.focused === 'button', JSON.stringify(s));
    await button(color).click();
    await until(color, (x) => x.expanded === 'true');
    const shown = await color.evaluate((root) => ({
      filter: root.querySelector('[popover] input').value,
      all: root.querySelectorAll('[role=option]:not([hidden])').length,
      checks: [...root.querySelectorAll('[role=option] svg')].map((i) => getComputedStyle(i).visibility),
    }));
    t.check(
      '[js] reopening clears the filter; only the picked entry shows its check',
      shown.filter === '' && shown.all === 5 && shown.checks.join() === 'hidden,hidden,visible,hidden,hidden',
      JSON.stringify(shown),
    );
    const box = await color.evaluate((root) => {
      const b = root.querySelector('button[aria-haspopup]').getBoundingClientRect();
      const p = root.querySelector('[popover]').getBoundingClientRect();
      const below = p.top >= b.bottom;
      return {
        bh: b.height,
        side: below ? 'below' : 'above',
        gap: Math.round(below ? p.top - b.bottom : b.top - p.bottom),
        left: Math.round(p.left - b.left),
        width: Math.round(p.width - b.width),
        room: Math.round(innerHeight - b.bottom),
      };
    });
    // Below its button, or above when the room below is too short.
    t.check(
      '[js] the menu sits next to its button (4px), as wide, flipping only without room',
      box.bh === 40 && box.gap === 4 && box.left === 0 && box.width === 0 && (box.side === 'below') === box.room > 260,
      JSON.stringify(box),
    );
    if (process.env.E2E_SHOT) await page.screenshot({ path: process.env.E2E_SHOT });
    await page.keyboard.press('Escape');
    await until(color, (x) => x.expanded === 'false');

    // The pointer opens the popover and its `toggle` is queued: a filter typed
    // before it arrives must survive it (one task makes the order certain).
    await color.evaluate((root) => {
      root.querySelector('button[aria-haspopup]').click();
      const field = root.querySelector('[popover] input');
      field.focus();
      field.value = 'gr';
      field.dispatchEvent(new Event('input', { bubbles: true }));
    });
    s = await until(color, (x) => x.expanded === 'true');
    const kept = await color.locator('[role=option]:not([hidden])').allTextContents();
    t.check('[js] a filter typed before the queued toggle is kept', kept.join() === 'Green' && s.active === 'Green', `${kept} ${JSON.stringify(s)}`);
    await page.keyboard.press('Enter');
    s = await state(color);
    t.check('[js] and Enter picks the filtered entry', !s.open && s.label === 'Green' && s.value === 'green', JSON.stringify(s));
    await button(color).click();
    await until(color, (x) => x.expanded === 'true');
    await page.keyboard.type('bl');
    await page.keyboard.press('Enter');
    s = await state(color);
    t.check('[js] back on Blue', s.label === 'Blue' && s.value === 'blue', JSON.stringify(s));

    const [request] = await Promise.all([
      page.waitForRequest((r) => r.url().includes('fruit=')),
      page.locator('.case-dropdown-menu button[type=submit]').click(),
    ]);
    const query = new URL(request.url()).searchParams;
    t.check('[js] a GET form posts the picked values', query.get('fruit') === 'apple' && query.get('color') === 'blue', request.url());

    const a11y = await fruit.evaluate((root) => {
      const b = root.querySelector('button[aria-haspopup]');
      const list = document.getElementById(b.getAttribute('aria-controls'));
      return { role: b.getAttribute('role'), name: b.getAttribute('aria-label'), list: list?.getAttribute('role') };
    });
    t.check('[js] combobox → listbox', a11y.role === 'combobox' && a11y.name === 'Fruit' && a11y.list === 'listbox', JSON.stringify(a11y));
    t.check('[js] clean console', page.problems.length === 0, page.problems.join(' | '));
    await page.context().close();
  }

  // --- Without JS: the native <select> is the control ---------------------
  {
    const page = await t.page({ viewport: { width: 1024, height: 900 }, javaScriptEnabled: false });
    await page.goto(t.url, { waitUntil: 'load' });
    const selects = page.locator('.case-dropdown-menu select');
    const look = await page.locator('.case-dropdown-menu').evaluate((c) => ({
      buttons: [...c.querySelectorAll('button[aria-haspopup]')].map((b) => getComputedStyle(b).display),
      selects: [...c.querySelectorAll('select')].map((s) => getComputedStyle(s).visibility),
      value: c.querySelector('select').value,
    }));
    t.check(
      '[no js] the native selects replace the buttons, on the initial selection',
      look.buttons.every((d) => d === 'none') && look.selects.every((v) => v === 'visible') && look.value === 'banana',
      JSON.stringify(look),
    );
    await selects.nth(0).selectOption('cherry');
    await selects.nth(1).selectOption('green');
    await Promise.all([page.waitForURL(/fruit=/), page.locator('.case-dropdown-menu button[type=submit]').click()]);
    const query = new URL(page.url()).searchParams;
    t.check('[no js] the form posts the chosen values', query.get('fruit') === 'cherry' && query.get('color') === 'green', page.url());
    await page.context().close();
  }
});

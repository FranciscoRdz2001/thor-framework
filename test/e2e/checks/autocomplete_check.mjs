// Checks thor_ui's Autocomplete / RawAutocomplete in a real browser, with
// and without JavaScript (test/fixtures/apps/lab (/edge-cases), `case-autocomplete`): the panel
// opens under the field in the top layer, narrows as the user types, the
// arrows highlight, Enter or a click picks (the field takes the text and the
// state hears the option), Esc / Tab / a click outside close it, a state's
// list in the panel opens and closes it, and a panel inside a clipping box
// with a later sibling that has a z-index still shows whole above both.
//
//   tool/thor e2e autocomplete                   (builds test/fixtures/apps/lab (/edge-cases), runs)
//   node test/e2e/checks/autocomplete_check.mjs [url]
import { e2e, settle, trackHydration } from './lib/e2e.mjs';

const vvStub = () => {
  // The visual viewport the test moves (the on-screen keyboard):
  // `window.__vv(bottom)` makes it end at `bottom` (layout-viewport
  // pixels) and fires `resize`; `__vv(null)` gives the real one back.
  const real = window.visualViewport;
  const fake = new EventTarget();
  let h = null;
  const get = (k) => (k === 'height' && h != null ? h : real[k]);
  for (const k of ['height', 'width', 'offsetTop', 'offsetLeft', 'scale', 'pageTop', 'pageLeft']) Object.defineProperty(fake, k, { get: () => get(k) });
  Object.defineProperty(window, 'visualViewport', { get: () => fake, configurable: true });
  window.__vv = (v) => {
    h = v == null ? null : v - real.offsetTop;
    fake.dispatchEvent(new Event('resize'));
  };
  addEventListener('keydown', (e) => (window.__lastKey = { key: e.key, prevented: e.defaultPrevented }));
};

await e2e('autocomplete', { site: 'test/fixtures/apps/lab/build/site', path: 'edge-cases' }, async (t) => {
  // --- With JS ---------------------------------------------------------
  {
    const page = await t.page({ viewport: { width: 1024, height: 900 } });
    await trackHydration(page);
    await page.goto(t.url, { waitUntil: 'load' });
    await page.mouse.move(1, 1);
    t.check('[js] engine hydrates', await settle(page, () => window.__thorHydrated));

    const roots = page.locator('.case-autocomplete [data-t-ac]');
    const fruit = roots.nth(0);
    const search = roots.nth(1);
    const field = (root) => root.locator('input');
    const state = (root) =>
      root.evaluate((r) => {
        const panel = r.querySelector('[popover]');
        const input = r.querySelector('input');
        const active = document.getElementById(input.getAttribute('aria-activedescendant') ?? '');
        const box = panel.getBoundingClientRect();
        const inputBox = input.getBoundingClientRect();
        return {
          open: panel.matches(':popover-open'),
          expanded: input.getAttribute('aria-expanded'),
          role: input.getAttribute('role'),
          value: input.value,
          visible: [...r.querySelectorAll('[role=option]:not([hidden])')].map((o) => o.textContent.trim()),
          active: active?.textContent.trim() ?? null,
          below: Math.round(box.top - r.getBoundingClientRect().bottom),
          sameWidth: Math.abs(box.width - inputBox.width) < 2 || box.width >= inputBox.width,
          focused: document.activeElement === input,
        };
      });
    const until = async (root, ok) => {
      for (let i = 0; i < 60; i++) {
        const now = await state(root);
        if (ok(now)) return now;
        await page.waitForTimeout(16);
      }
      return state(root);
    };
    const picked = () => page.locator('.case-autocomplete').evaluate((c) => c.textContent.match(/Picked: [^)]*\)/)?.[0]);

    // Static options.
    let s = await state(fruit);
    t.check('[js] starts closed, a plain field', !s.open && s.role === null, JSON.stringify(s));
    await field(fruit).click();
    s = await until(fruit, (x) => x.open);
    t.check('[js] focusing opens the panel with every option', s.open && s.role === 'combobox' && s.visible.length === 5 && s.expanded === 'true', JSON.stringify(s));
    t.check('[js] the panel sits right under the field', Math.abs(s.below) <= 1 && s.sameWidth, JSON.stringify(s));
    t.check('[js] nothing is highlighted yet', s.active === null, JSON.stringify(s));

    await page.keyboard.type('ap');
    s = await until(fruit, (x) => x.visible.length === 2);
    t.check('[js] typing narrows the options', s.open && s.visible.join() === 'apple,apricot', JSON.stringify(s));
    await page.keyboard.press('ArrowDown');
    await page.keyboard.press('ArrowDown');
    s = await state(fruit);
    t.check('[js] arrows move the highlight', s.active === 'apricot', JSON.stringify(s));
    await page.keyboard.press('Enter');
    s = await state(fruit);
    t.check('[js] Enter picks: field text, closed, focus stays', s.value === 'apricot' && !s.open && s.focused, JSON.stringify(s));
    await settle(page, () => /Picked: apricot \(1\)/.test(document.body.textContent));
    t.check('[js] the state heard the option (once)', (await picked()) === 'Picked: apricot (1)', await picked());

    await field(fruit).fill('');
    await page.keyboard.type('b');
    s = await until(fruit, (x) => x.visible.join() === 'banana,blueberry');
    await page.locator('.case-autocomplete [role=option]', { hasText: 'blueberry' }).click();
    s = await state(fruit);
    t.check('[js] a click picks', s.value === 'blueberry' && !s.open, JSON.stringify(s));
    await settle(page, () => /Picked: blueberry \(2\)/.test(document.body.textContent));
    t.check('[js] and the state heard it', (await picked()) === 'Picked: blueberry (2)', await picked());

    await field(fruit).fill('');
    await page.keyboard.type('zzz');
    s = await until(fruit, (x) => x.visible.length === 0);
    t.check('[js] no match: the panel closes', !s.open, JSON.stringify(s));
    await field(fruit).fill('a');
    s = await until(fruit, (x) => x.open);
    await page.keyboard.press('Escape');
    s = await state(fruit);
    t.check('[js] Esc closes and keeps the text', !s.open && s.value === 'a' && s.focused, JSON.stringify(s));
    await page.keyboard.type('p');
    s = await until(fruit, (x) => x.open);
    t.check('[js] typing opens it again', s.open, JSON.stringify(s));
    await page.mouse.click(900, 20);
    s = await until(fruit, (x) => !x.open);
    t.check('[js] a click outside closes it', !s.open && s.expanded === 'false', JSON.stringify(s));

    // A state's list in the panel, in a clipping box under a sibling with a z-index.
    await field(search).click();
    s = await state(search);
    t.check('[js] no suggestions yet: nothing to show', !s.open, JSON.stringify(s));
    await page.keyboard.type('ca');
    s = await until(search, (x) => x.open && x.visible.length === 2);
    t.check('[js] the state\'s suggestions open the panel', s.open && s.visible.join() === 'Café,Cacao', JSON.stringify(s));
    const over = await search.evaluate((r) => {
      const panel = r.querySelector('[popover]');
      const o = panel.querySelectorAll('[role=option]')[1];
      const b = o.getBoundingClientRect();
      const at = document.elementFromPoint(b.left + b.width / 2, b.top + b.height / 2);
      const clip = r.closest('.case-autocomplete > * > *, [style*="overflow"]');
      const later = document.querySelector('.ac-later').getBoundingClientRect();
      return {
        hit: at?.textContent.trim(),
        covers: b.bottom > r.getBoundingClientRect().bottom + 40,
        reachesLater: b.bottom > later.top,
      };
    });
    t.check('[js] the panel is above a later sibling and outside the clipping box', over.hit === 'Cacao' && over.covers && over.reachesLater, JSON.stringify(over));
    await page.keyboard.press('ArrowDown');
    await page.keyboard.press('ArrowDown');
    await page.keyboard.press('Enter');
    s = await state(search);
    t.check('[js] a state\'s list picks by the keyboard too', s.value === 'Cacao' && !s.open, JSON.stringify(s));
    await field(search).fill('');
    s = await until(search, (x) => !x.open);
    t.check('[js] the list emptying closes the panel', !s.open, JSON.stringify(s));
  }

  // --- Adversarial: IME, ids, a form's Enter -----------------------------
  {
    const page = await t.page({ viewport: { width: 1024, height: 900 } });
    await trackHydration(page);
    await page.goto(t.url, { waitUntil: 'load' });
    await settle(page, () => window.__thorHydrated);
    const fruit = page.locator('.case-autocomplete [data-t-ac]').nth(0);
    const search = page.locator('.case-autocomplete [data-t-ac]').nth(1);
    const visible = () =>
      fruit.evaluate((r) => [...r.querySelectorAll('[role=option]:not([hidden])')].map((o) => o.textContent.trim()).join());

    // A composition in progress (IME) is not the query yet.
    await fruit.locator('input').click();
    const cdp = await page.context().newCDPSession(page);
    await cdp.send('Input.imeSetComposition', { text: 'b', selectionStart: 1, selectionEnd: 1 });
    await page.waitForTimeout(100);
    t.check('[js] a composition in progress does not narrow', (await visible()).split(',').length === 5, await visible());
    await cdp.send('Input.insertText', { text: 'b' });
    await page.waitForTimeout(100);
    t.check('[js] the committed text narrows', (await visible()) === 'banana,blueberry', await visible());

    // Option ids stay unique when rows are inserted ahead of a highlighted one.
    await fruit.locator('input').fill('');
    await page.keyboard.press('ArrowDown');
    await fruit.evaluate((r) => {
      const first = r.querySelector('[role=option]');
      const x = first.cloneNode(true);
      x.removeAttribute('id');
      x.removeAttribute('data-active');
      x.removeAttribute('data-tx');
      x.textContent = 'zzz';
      first.parentNode.insertBefore(x, first);
    });
    await page.keyboard.press('ArrowUp');
    await page.waitForTimeout(50);
    const ids = await fruit.evaluate((r) => [...r.querySelectorAll('[role=option]')].map((o) => o.id).filter(Boolean));
    t.check('[js] option ids stay unique', ids.length >= 2 && new Set(ids).size === ids.length, ids.join());
    await search.locator('input').focus();
    const ctl = await page.evaluate(() => {
      const ids = [...document.querySelectorAll('.case-autocomplete [data-t-ac]')].map((r) => r.querySelector('input').getAttribute('aria-controls'));
      return ids;
    });
    t.check('[js] two autocompletes control different panels', ctl[0] && ctl[1] && ctl[0] !== ctl[1], ctl.join());

    // Enter with nothing highlighted submits the surrounding GET form.
    await search.locator('input').fill('zz');
    await page.keyboard.press('Enter');
    await page.waitForURL(/[?&]q=zz/, { timeout: 3000 }).catch(() => {});
    t.check('[js] Enter with no highlight submits the form', /[?&]q=zz/.test(page.url()), page.url());
  }

  // --- A11y: live region, APG keys, flip above, row ids -----------
  {
    const page = await t.page({ viewport: { width: 390, height: 700 }, hasTouch: true });
    await page.addInitScript(vvStub);
    await trackHydration(page);
    await page.goto(t.url, { waitUntil: 'load' });
    await settle(page, () => window.__thorHydrated);
    // No smooth scrolling under the test's own scrolls.
    await page.addStyleTag({ content: 'html{scroll-behavior:auto !important}' });
    const root = page.locator('.case-autocomplete [data-t-ac]').nth(0);
    const info = () =>
      root.evaluate((r) => {
        const panel = r.querySelector('[popover]');
        const input = r.querySelector('input');
        const status = r.querySelector('[data-t-ac-status]');
        const box = panel.getBoundingClientRect();
        const fb = r.getBoundingClientRect();
        return {
          open: panel.matches(':popover-open'),
          status: status.textContent,
          live: status.getAttribute('aria-live'),
          active: input.getAttribute('aria-activedescendant'),
          activeText: document.getElementById(input.getAttribute('aria-activedescendant') || '__')?.textContent.trim() ?? null,
          caret: [input.selectionStart, input.selectionEnd],
          up: panel.hasAttribute('data-t-up'),
          above: box.bottom <= fb.top + 1,
          below: box.top >= fb.bottom - 1,
          room: panel.style.getPropertyValue('--t-ac-room'),
          boxH: Math.round(box.height),
        };
      });
    const wait = async (ok) => {
      for (let i = 0; i < 60; i++) {
        const now = await info();
        if (ok(now)) return now;
        await page.waitForTimeout(16);
      }
      return info();
    };
    await root.locator('input').click();
    let s = await wait((x) => x.open && x.status === '5 results');
    t.check('[a11y] the region is polite and says how many results', s.live === 'polite' && s.status === '5 results', JSON.stringify(s));
    // Fast typing: a screen reader would read every step. One write at most
    // per pause, and the same text twice is not a write at all.
    await root.locator('input').evaluate((el) => {
      const status = el.closest('[data-t-ac]').querySelector('[data-t-ac-status]');
      window.__writes = [];
      new MutationObserver(() => window.__writes.push(status.textContent)).observe(status, { childList: true, characterData: true, subtree: true });
    });
    await page.keyboard.type('apple', { delay: 10 });
    s = await wait((x) => x.status === '1 result');
    await page.waitForTimeout(400);
    const writes = await page.evaluate(() => window.__writes);
    t.check('[a11y] fast typing writes the region once, where it stopped', writes.length <= 2 && writes.at(-1) === '1 result', JSON.stringify(writes));
    await root.locator('input').fill('');
    await wait((x) => x.status === '5 results');
    // {count} more than once in a translation.
    await root.evaluate((r) => r.querySelector('[data-t-ac-status]').setAttribute('data-t-ac-status', '{count} of {count}'));
    await page.keyboard.type('a');
    s = await wait((x) => x.status === '3 of 3');
    t.check('[a11y] every {count} in the text is replaced', s.status === '3 of 3', JSON.stringify(s));
    await root.evaluate((r) => r.querySelector('[data-t-ac-status]').setAttribute('data-t-ac-status', '{count} results'));
    await root.locator('input').fill('');
    await wait((x) => x.status === '5 results');
    await page.keyboard.type('ap');
    s = await wait((x) => x.status === '2 results');
    t.check('[a11y] typing updates the count', s.status === '2 results', JSON.stringify(s));
    await page.keyboard.type('ple');
    s = await wait((x) => x.status === '1 result');
    t.check('[a11y] one result has its own text', s.status === '1 result', JSON.stringify(s));
    await page.keyboard.type('zz');
    s = await wait((x) => x.status === 'No results');
    t.check('[a11y] no result says so', s.status === 'No results' && !s.open, JSON.stringify(s));
    await root.locator('input').fill('');
    s = await wait((x) => x.status === '5 results');
    await page.keyboard.press('Escape');
    s = await wait((x) => x.status === '');
    t.check('[a11y] closed: the region is emptied (no stale count)', s.status === '' && !s.open, JSON.stringify(s));
    await page.keyboard.press('ArrowDown');
    s = await wait((x) => x.open && x.status === '5 results');
    t.check('[a11y] ArrowDown reopens and announces again', s.open && s.status === '5 results', JSON.stringify(s));

    // APG: ArrowDown/Up wrap; Home/End return to the field's caret.
    await root.locator('input').fill('a');
    s = await wait((x) => x.status === '3 results');
    t.check('[a11y] "a" matches apple, apricot, banana', s.status === '3 results', JSON.stringify(s));
    for (let i = 0; i < 3; i++) await page.keyboard.press('ArrowDown');
    s = await info();
    t.check('[a11y] three ArrowDowns reach the last', s.activeText === 'banana', JSON.stringify(s));
    await root.locator('input').fill('a');
    await wait((x) => x.status === '3 results');
    await page.keyboard.press('ArrowUp');
    s = await info();
    t.check('[a11y] ArrowUp with none highlighted goes to the last', s.activeText === 'banana', JSON.stringify(s));
    await page.keyboard.press('ArrowDown');
    s = await info();
    t.check('[a11y] ArrowDown on the last goes to the first', s.activeText === 'apple', JSON.stringify(s));
    await page.keyboard.press('ArrowUp');
    s = await info();
    t.check('[a11y] ArrowUp on the first goes to the last', s.activeText === 'banana', JSON.stringify(s));
    await page.keyboard.press('Home');
    s = await info();
    // The caret itself is the platform's (macOS scrolls on Home/End): what is
    // ours is that the highlight returns to the field and the key is not eaten.
    const homeKey = await page.evaluate(() => window.__lastKey);
    t.check('[a11y] Home: the highlight returns to the field, the key is left to it, still open', s.active === null && s.open && homeKey.key === 'Home' && !homeKey.prevented, JSON.stringify([s, homeKey]));
    await page.keyboard.press('ArrowDown');
    await page.keyboard.press('End');
    s = await info();
    const endKey = await page.evaluate(() => window.__lastKey);
    t.check('[a11y] End: no highlight either, key not eaten', s.active === null && s.open && endKey.key === 'End' && !endKey.prevented, JSON.stringify([s, endKey]));
    await page.keyboard.press('Escape');

    // One panel id per row, also for rows added later.
    await page.getByRole('button', { name: 'Add row' }).click();
    await page.waitForTimeout(120);
    const ids = await page.evaluate(() => {
      const rows = [...document.querySelectorAll('.case-autocomplete-rows [data-t-ac]')];
      return rows.map((r) => r.querySelector('[popover]').id);
    });
    t.check('[a11y] rows of a live list: unique panel ids, token filled', ids.length === 3 && new Set(ids).size === 3 && ids.every((i) => i && !i.includes('{{')), ids.join());
    const last = page.locator('.case-autocomplete-rows [data-t-ac]').nth(2);
    await last.locator('input').focus();
    await page.keyboard.press('ArrowDown');
    const ctl = await last.evaluate((r) => ({
      controls: r.querySelector('input').getAttribute('aria-controls'),
      panel: r.querySelector('[popover]').id,
      active: r.querySelector('input').getAttribute('aria-activedescendant'),
      dup: document.querySelectorAll('[id="' + r.querySelector('[popover]').id + '"]').length,
    }));
    t.check('[a11y] a row added later controls its own panel', ctl.controls === ctl.panel && ctl.dup === 1 && !!ctl.active, JSON.stringify(ctl));
  }

  // --- The on-screen keyboard: the visual viewport leaves no room below ---
  {
    const page = await t.page({ viewport: { width: 390, height: 700 }, hasTouch: true });
    await page.addInitScript(vvStub);
    await trackHydration(page);
    await page.goto(t.url, { waitUntil: 'load' });
    await settle(page, () => window.__thorHydrated);
    // No smooth scrolling under the test's own scrolls.
    await page.addStyleTag({ content: 'html{scroll-behavior:auto !important}' });
    const root = page.locator('.case-autocomplete [data-t-ac]').nth(0);
    const info = () =>
      root.evaluate((r) => {
        const panel = r.querySelector('[popover]');
        const box = panel.getBoundingClientRect();
        const fb = r.getBoundingClientRect();
        return {
          open: panel.matches(':popover-open'),
          up: panel.hasAttribute('data-t-up'),
          above: box.bottom <= fb.top + 1,
          below: box.top >= fb.bottom - 1,
          room: panel.style.getPropertyValue('--t-ac-room'),
          boxH: Math.round(box.height),
        };
      });
    const wait = async (ok) => {
      for (let i = 0; i < 60; i++) {
        const now = await info();
        if (ok(now)) return now;
        await page.waitForTimeout(16);
      }
      return info();
    };
    await root.evaluate((r) => {
      const b = r.getBoundingClientRect();
      scrollTo({ top: scrollY + b.top - document.documentElement.clientHeight / 3, behavior: 'instant' });
    });
    await page.waitForTimeout(100);
    await root.locator('input').focus();
    let s = await wait((x) => x.open);
    t.check('[kbd] with room, the panel opens below', s.open && s.below && !s.up && s.room === '', JSON.stringify(s));
    const fieldBottom = await root.evaluate((r) => r.getBoundingClientRect().bottom);
    await page.evaluate((b) => window.__vv(b), Math.round(fieldBottom + 30));
    s = await wait((x) => x.up);
    t.check('[kbd] the keyboard leaves no room below: it flips above the field', s.up && s.above && s.open, JSON.stringify(s));
    t.check('[kbd] and its height is capped by the room above', Number.parseFloat(s.room) > 0 && s.boxH <= Number.parseFloat(s.room) + 1, JSON.stringify(s));
    await page.evaluate(() => window.__vv(null));
    s = await wait((x) => !x.up);
    t.check('[kbd] the keyboard gone: back below, uncapped', !s.up && s.below && s.room === '', JSON.stringify(s));
  }

  // --- Adversarial: a capped panel keeps its own scroll; listeners do not leak
  {
    const page = await t.page({ viewport: { width: 390, height: 700 }, hasTouch: true });
    await page.addInitScript(vvStub);
    // Counts what the page keeps listening to (add minus remove, by type).
    await page.addInitScript(() => {
      const live = new Map();
      window.__live = live;
      const key = (t, type, cap) => `${type}|${typeof cap === 'object' ? !!cap?.capture : !!cap}`;
      const add = EventTarget.prototype.addEventListener;
      const rem = EventTarget.prototype.removeEventListener;
      const tag = (t) => (t === window ? 'window' : t === window.visualViewport || t?.constructor?.name === 'EventTarget' ? 'vv' : t === document ? 'document' : null);
      EventTarget.prototype.addEventListener = function (type, fn, cap) {
        const k = tag(this);
        if (k && fn) {
          const set = live.get(`${k}|${key(this, type, cap)}`) ?? new Set();
          set.add(fn);
          live.set(`${k}|${key(this, type, cap)}`, set);
        }
        return add.call(this, type, fn, cap);
      };
      EventTarget.prototype.removeEventListener = function (type, fn, cap) {
        const k = tag(this);
        if (k && fn) live.get(`${k}|${key(this, type, cap)}`)?.delete(fn);
        return rem.call(this, type, fn, cap);
      };
    });
    await trackHydration(page);
    await page.goto(t.url, { waitUntil: 'load' });
    await settle(page, () => window.__thorHydrated);
    await page.addStyleTag({ content: 'html{scroll-behavior:auto !important}' });
    const root = page.locator('.case-autocomplete [data-t-ac]').nth(0);
    const counts = () =>
      page.evaluate(() => Object.fromEntries([...window.__live].filter(([, v]) => v.size).map(([k, v]) => [k, v.size])));
    const before = await counts();
    for (let i = 0; i < 50; i++) {
      await root.locator('input').focus();
      await page.keyboard.press('ArrowDown');
      await page.keyboard.press('Escape');
      await root.locator('input').blur();
    }
    const after = await counts();
    const grew = Object.keys(after).filter((k) => /window|vv/.test(k) && (after[k] ?? 0) > (before[k] ?? 0) + 4);
    t.check('[leak] 50 open/close cycles do not pile up listeners on window / visualViewport', grew.length === 0, JSON.stringify({ before, after }));

    // The keyboard leaves ~90 px above the field: the capped panel scrolls.
    await root.evaluate((r) => {
      const b = r.getBoundingClientRect();
      scrollTo({ top: scrollY + b.top - 110, behavior: 'instant' });
    });
    await page.waitForTimeout(100);
    await root.locator('input').focus();
    await page.keyboard.press('ArrowDown');
    const fieldBottom = await root.evaluate((r) => r.getBoundingClientRect().bottom);
    await page.evaluate((b) => window.__vv(b), Math.round(fieldBottom + 30));
    await page.waitForTimeout(150);
    const cap = await root.evaluate((r) => {
      const p = r.querySelector('[popover]');
      return { up: p.hasAttribute('data-t-up'), room: p.style.getPropertyValue('--t-ac-room'), over: p.scrollHeight - p.clientHeight };
    });
    t.check('[scroll] the capped panel opens above and overflows', cap.up && cap.over > 20, JSON.stringify(cap));
    await root.evaluate((r) => {
      r.querySelector('[popover]').scrollTop = 40;
    });
    await page.waitForTimeout(250);
    const kept = await root.evaluate((r) => r.querySelector('[popover]').scrollTop);
    t.check('[scroll] scrolling the panel itself does not reset its scroll', kept >= 30, String(kept));
    await page.keyboard.press('Escape');
    await page.evaluate(() => window.__vv(null));
  }

  // --- A browser without CSS anchor positioning ------------------------
  {
    const page = await t.page({ viewport: { width: 1024, height: 600 } });
    await page.addInitScript(() => {
      CSS.supports = () => false;
    });
    await trackHydration(page);
    await page.goto(t.url, { waitUntil: 'load' });
    await settle(page, () => window.__thorHydrated);
    // The anchored rules are what the fallback replaces: drop them.
    await page.addStyleTag({ content: '[popover]{position-area:none !important;position-anchor:none !important}' });
    const fruit = page.locator('.case-autocomplete [data-t-ac]').nth(0);
    await fruit.locator('input').click();
    await page.waitForTimeout(150);
    const gap = () =>
      fruit.evaluate((r) => {
        const b = r.querySelector('[popover]').getBoundingClientRect();
        const i = r.getBoundingClientRect();
        return { open: r.querySelector('[popover]').matches(':popover-open'), dy: Math.round(b.top - i.bottom), dx: Math.round(b.left - i.left) };
      });
    let g = await gap();
    t.check('[js] no anchoring: the panel is placed under the field, not at 0,0', g.open && g.dy === 0 && g.dx === 0, JSON.stringify(g));
    await page.evaluate(() => scrollBy(0, 120));
    await page.waitForTimeout(150);
    g = await gap();
    t.check('[js] no anchoring: the panel follows the field on scroll', g.open && g.dy === 0 && g.dx === 0, JSON.stringify(g));
  }

  // --- Without JS ------------------------------------------------------
  {
    const page = await t.page({ viewport: { width: 1024, height: 900 }, javaScriptEnabled: false });
    await page.goto(t.url, { waitUntil: 'load' });
    const root = page.locator('.case-autocomplete [data-t-ac]').first();
    const r = await root.evaluate((el) => {
      const panel = el.querySelector('[popover]');
      return {
        panel: getComputedStyle(panel).display,
        input: el.querySelector('input').type,
        role: el.querySelector('input').getAttribute('role'),
      };
    });
    t.check('[nojs] a plain text field, the panel never shows', r.panel === 'none' && r.input === 'text' && r.role === null, JSON.stringify(r));
    await root.locator('input').click();
    await page.keyboard.type('ap');
    const v = await root.locator('input').inputValue();
    t.check('[nojs] the field is usable', v === 'ap', v);
  }
});

// Keyboard checks of the lite engine's `tabs`, `menu` and `shortcuts` parts
// (accessibility): real Chromium, pages built in memory from
// lib/lite/runtime.js and the part under test (no app to build), with the
// markup thor_ui writes for TabBar, MenuAnchor, SubmenuButton,
// PopupMenuButton and CallbackShortcuts (other keyboard layouts).
//
//   node test/e2e/checks/lite_keyboard_check.mjs
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { chromium } from '../runner/node_modules/playwright/index.mjs';
import { repo } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
const runtime = readFileSync(join(lite, 'runtime.js'), 'utf8');
const part = (n) => readFileSync(join(lite, 'parts', n), 'utf8');
const bundle = (...parts) => runtime.replace('// @thor-lite-parts', () => parts.map(part).join('\n'));
const page = (body, parts = [], attrs = '', script = '') =>
  `<!DOCTYPE html><html${attrs}><head><base href="/"><meta charset="utf-8"><style>
[popover]{padding:4px;border:1px solid #888}
[popover]:popover-open{display:flex;flex-direction:column}
:root:has(input[name="p"]:checked:not([value="0"])) #p-panel-0{display:none}
:root:has(input[name="p"]:checked:not([value="1"])) #p-panel-1{display:none}
:root:has(input[name="p"]:checked:not([value="2"])) #p-panel-2{display:none}
label{display:inline-block;padding:8px 16px;position:relative}
input[type=radio]{position:absolute;opacity:0;width:1px;height:1px;margin:0}
</style></head><body>${body}<script>${bundle(...parts)}
window.log = [];
document.addEventListener('change', (e) => window.log.push('change:' + e.target.value));
document.addEventListener('click', (e) => { const b = e.target.closest('[data-pick]'); if (b) window.log.push('pick:' + b.dataset.pick); });
${script}</script></body></html>`;

// CallbackShortcuts (the `shortcuts` part): ⌘S, Ctrl+1 and ⌘C as thor_ui
// writes them, on a focusable page and a text field.
const shortcuts = `<div data-tks="m+s>K.save;c+1>K.first;m+c>K.copy">
<span id="page" tabindex="0">page</span><input id="field" type="text"></div>`;
const shortcutsState = `thor.def('K', () => ({
  save: () => window.log.push('save'), first: () => window.log.push('first'), copy: () => window.log.push('copy'),
}));`;

const tabs = `<button id="before">before</button>
<div role="radiogroup" data-t-tabs>
<label id="p-tab-0"><input type="radio" name="p" value="0" checked aria-controls="p-panel-0">One</label>
<label id="p-tab-1"><input type="radio" name="p" value="1" aria-controls="p-panel-1">Two</label>
<label id="p-tab-2"><input type="radio" name="p" value="2" aria-controls="p-panel-2">Three</label>
</div>
<div id="p-panel-0" role="group" aria-labelledby="p-tab-0" tabindex="0">a</div>
<div id="p-panel-1" role="group" aria-labelledby="p-tab-1" tabindex="0">b</div>
<div id="p-panel-2" role="group" aria-labelledby="p-tab-2" tabindex="0">c</div>
<button id="after">after</button>`;

const menus = `<button id="acct" popovertarget="m" aria-haspopup="true" type="button">Acct</button>
<div id="m" popover="auto" data-t-menu>
<button type="button" popovertarget="m" popovertargetaction="hide" data-pick="share">Share</button>
<button type="button" popovertarget="m" popovertargetaction="hide" disabled data-pick="off">Disabled</button>
<a href="#orders" data-pick="orders">Orders</a>
<button id="more" type="button" popovertarget="sm" aria-haspopup="true">More</button>
<div id="sm" popover="auto" data-t-menu>
<button type="button" popovertarget="m" popovertargetaction="hide" data-pick="deep">Deep</button>
<button type="button" popovertarget="m" popovertargetaction="hide" data-pick="deeper">Deeper</button>
</div>
<button type="button" popovertarget="m" popovertargetaction="hide" data-pick="out">Sign out</button>
</div>
<button id="pop" type="button" popovertarget="pm" aria-haspopup="true">Pop</button>
<div id="pm" popover="auto" data-t-menu>
<button type="button" popovertarget="pm" popovertargetaction="hide" data-pick="alpha">Alpha</button>
<button type="button" popovertarget="pm" popovertargetaction="hide" data-pick="beta">Beta</button>
</div>
<button id="after">after</button>`;

const pages = {
  '/tabs': page(tabs, ['tabs.js']),
  '/tabs-rtl': page(tabs, ['tabs.js'], ' dir="rtl"'),
  '/tabs-none': page(tabs),
  '/menus': page(menus, ['menu.js']),
  '/menus-none': page(menus),
  '/shortcuts': page(shortcuts, ['shortcuts.js'], '', shortcutsState),
};

const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail !== '' ? ` (${detail})` : ''}`);
};

const browser = await chromium.launch();
const open = async (path) => {
  const ctx = await browser.newContext({ viewport: { width: 700, height: 600 } });
  const p = await ctx.newPage();
  p.problems = [];
  p.on('pageerror', (e) => p.problems.push(e.message));
  await ctx.route('http://lite.test/**', (r) => {
    const body = pages[new URL(r.request().url()).pathname];
    return body ? r.fulfill({ contentType: 'text/html', body }) : r.fulfill({ status: 404, body: '' });
  });
  await p.goto(`http://lite.test${path}`);
  await p.waitForFunction(() => typeof thor !== 'undefined');
  await p.waitForTimeout(50);
  return p;
};
const focused = (p) => p.evaluate(() => document.activeElement?.id || document.activeElement?.textContent.trim());
const log = (p) => p.evaluate(() => window.log.splice(0).join());
const selected = (p) => p.evaluate(() => [...document.querySelectorAll('[role="tab"]')].map((t) => t.getAttribute('aria-selected')).join());
const tabindexes = (p) => p.evaluate(() => [...document.querySelectorAll('[role="tab"]')].map((t) => t.tabIndex).join());
const checkedRadio = (p) => p.evaluate(() => document.querySelector('input[name="p"]:checked').value);

try {
  // Tabs.
  {
    const p = await open('/tabs');
    const roles = await p.evaluate(() => ({
      bar: document.querySelector('[data-t-tabs]').getAttribute('role'),
      tabs: [...document.querySelectorAll('[data-t-tabs] > label')].map((l) => l.getAttribute('role')).join(),
      controls: [...document.querySelectorAll('[role="tab"]')].map((l) => l.getAttribute('aria-controls')).join(),
      panels: [...document.querySelectorAll('[id^="p-panel"]')].map((l) => l.getAttribute('role')).join(),
      radios: [...document.querySelectorAll('input')].map((i) => `${i.getAttribute('aria-hidden')}/${i.tabIndex}/${i.hasAttribute('aria-controls')}`).join(),
    }));
    check('tabs: the bar is a tablist', roles.bar === 'tablist', roles.bar);
    check('tabs: labels are tabs with aria-controls', roles.tabs === 'tab,tab,tab' && roles.controls === 'p-panel-0,p-panel-1,p-panel-2', `${roles.tabs} ${roles.controls}`);
    check('tabs: panels are tabpanels', roles.panels === 'tabpanel,tabpanel,tabpanel', roles.panels);
    check('tabs: radios leave the tree and the tab order', roles.radios === 'true/-1/false,true/-1/false,true/-1/false', roles.radios);
    check('tabs: aria-selected and roving tabindex follow the checked radio', (await selected(p)) === 'true,false,false' && (await tabindexes(p)) === '0,-1,-1');

    await p.focus('#p-tab-0');
    await p.keyboard.press('ArrowRight');
    check('tabs: ArrowRight moves the focus and selects', (await focused(p)) === 'p-tab-1' && (await selected(p)) === 'false,true,false' && (await checkedRadio(p)) === '1' && (await tabindexes(p)) === '-1,0,-1');
    check('tabs: the move fires change (onTap) once', (await log(p)) === 'change:1');
    check('tabs: the selected panel shows', await p.evaluate(() => getComputedStyle(document.getElementById('p-panel-1')).display !== 'none' && getComputedStyle(document.getElementById('p-panel-0')).display === 'none'));
    await p.keyboard.press('End');
    check('tabs: End goes to the last tab', (await focused(p)) === 'p-tab-2' && (await checkedRadio(p)) === '2');
    await p.keyboard.press('ArrowRight');
    check('tabs: ArrowRight wraps to the first', (await focused(p)) === 'p-tab-0' && (await checkedRadio(p)) === '0');
    await p.keyboard.press('ArrowLeft');
    check('tabs: ArrowLeft wraps to the last', (await focused(p)) === 'p-tab-2');
    await p.keyboard.press('Home');
    check('tabs: Home goes to the first tab', (await focused(p)) === 'p-tab-0' && (await selected(p)) === 'true,false,false');
    await log(p);
    await p.keyboard.press('Home');
    check('tabs: a key that changes nothing fires no change', (await log(p)) === '');
    await p.keyboard.press('Tab');
    check('tabs: Tab leaves the bar for the panel (one tab stop)', (await focused(p)) === 'p-panel-0', await focused(p));
    await p.keyboard.press('Shift+Tab');
    check('tabs: Shift+Tab comes back to the selected tab', (await focused(p)) === 'p-tab-0', await focused(p));

    await p.click('#p-tab-2');
    check('tabs: a click selects and updates the roving state', (await selected(p)) === 'false,false,true' && (await tabindexes(p)) === '-1,-1,0' && (await log(p)) === 'change:2');
    check('tabs: after a click the focus is on the tab, not the hidden radio', (await focused(p)) === 'p-tab-2', await focused(p));
    await p.keyboard.press('Enter');
    check('tabs: Enter on the focused tab keeps it selected', (await selected(p)) === 'false,false,true' && (await log(p)) === '');
    check('tabs: no page errors', p.problems.length === 0, p.problems.join('; '));
    await p.context().close();
  }
  {
    const p = await open('/tabs-rtl');
    await p.focus('#p-tab-0');
    await p.keyboard.press('ArrowLeft');
    check('tabs: in a right-to-left bar ArrowLeft goes forward', (await focused(p)) === 'p-tab-1');
    await p.keyboard.press('ArrowRight');
    check('tabs: in a right-to-left bar ArrowRight goes back', (await focused(p)) === 'p-tab-0');
    await p.context().close();
  }
  {
    const p = await open('/tabs-none');
    const role = await p.evaluate(() => document.querySelector('[data-t-tabs]').getAttribute('role'));
    check('tabs: without the part the bar stays a native radio group', role === 'radiogroup' && (await tabindexes(p)) === '');
    await p.context().close();
  }

  // Menus.
  {
    const p = await open('/menus');
    check('menu: before it opens it is the plain disclosure the server wrote', await p.evaluate(() => !document.getElementById('m').hasAttribute('role') && !document.querySelector('#m button').hasAttribute('role')));
    check('menu: the items are in the Tab order while closed', await p.evaluate(() => [...document.querySelectorAll('#m > [role="menuitem"]')].every((i) => i.tabIndex === 0)));
    await p.focus('#acct');
    await p.keyboard.press('ArrowDown');
    check('menu: opened, the panel is a menu and its buttons and links menuitems', await p.evaluate(() => {
      const m = document.getElementById('m');
      const own = [...m.querySelectorAll('button,a[href]')].filter((i) => i.closest('[data-t-menu]') === m);
      return m.getAttribute('role') === 'menu' && own.every((i) => i.getAttribute('role') === 'menuitem') && !document.getElementById('sm').hasAttribute('role') && !document.getElementById('pm').hasAttribute('role');
    }));
    check('menu: ArrowDown on the trigger opens it on the first item', (await p.evaluate(() => document.getElementById('m').matches(':popover-open'))) && (await focused(p)) === 'Share', await focused(p));
    check('menu: the items leave the Tab order, the focused one rests in it', await p.evaluate(() => {
      const items = [...document.querySelectorAll('#m > [role="menuitem"]')].filter((i) => !i.disabled);
      return items.filter((i) => i.tabIndex === 0).length === 1 && document.activeElement.tabIndex === 0;
    }));
    await p.keyboard.press('ArrowDown');
    check('menu: ArrowDown skips a disabled item', (await focused(p)) === 'Orders', await focused(p));
    await p.keyboard.press('ArrowDown');
    check('menu: ArrowDown reaches the submenu button', (await focused(p)) === 'more');
    await p.keyboard.press('ArrowDown');
    await p.keyboard.press('ArrowDown');
    check('menu: ArrowDown wraps to the first item', (await focused(p)) === 'Share', await focused(p));
    await p.keyboard.press('ArrowUp');
    check('menu: ArrowUp wraps to the last item', (await focused(p)) === 'Sign out', await focused(p));
    await p.keyboard.press('Home');
    check('menu: Home goes to the first item', (await focused(p)) === 'Share');
    await p.keyboard.press('End');
    check('menu: End goes to the last item', (await focused(p)) === 'Sign out');
    await p.keyboard.press('o');
    check('menu: a letter goes to the next item starting with it', (await focused(p)) === 'Orders', await focused(p));
    await p.waitForTimeout(800);
    await p.keyboard.press('s');
    check('menu: the same search again cycles from the current item', (await focused(p)) === 'Sign out', await focused(p));
    await p.keyboard.press('Escape');
    check('menu: Escape closes it and returns the focus to the trigger', !(await p.evaluate(() => document.getElementById('m').matches(':popover-open'))) && (await focused(p)) === 'acct', await focused(p));
    await p.waitForTimeout(100);
    check('menu: closed, the items are back in the Tab order', await p.evaluate(() => [...document.querySelectorAll('#m > [role="menuitem"]')].every((i) => i.tabIndex === 0)));

    await p.keyboard.press('ArrowUp');
    check('menu: ArrowUp on the trigger opens it on the last item', (await focused(p)) === 'Sign out', await focused(p));
    await p.keyboard.press('Escape');

    // Enter on the trigger (keyboard): the first item has the focus.
    await p.focus('#acct');
    await p.keyboard.press('Enter');
    await p.waitForFunction(() => document.activeElement?.getAttribute('role') === 'menuitem');
    check('menu: opening with Enter focuses the first item', (await focused(p)) === 'Share', await focused(p));
    await p.keyboard.press('Enter');
    check('menu: Enter on an item activates it and closes the menu', !(await p.evaluate(() => document.getElementById('m').matches(':popover-open'))) && (await log(p)) === 'pick:share' && (await focused(p)) === 'acct');

    // Submenu.
    await p.keyboard.press('ArrowDown');
    await p.keyboard.press('ArrowDown');
    await p.keyboard.press('ArrowDown');
    check('menu: reached the submenu button', (await focused(p)) === 'more', await focused(p));
    await p.keyboard.press('ArrowRight');
    check('menu: the submenu becomes a menu when it opens', await p.evaluate(() => document.getElementById('sm').getAttribute('role') === 'menu' && document.querySelector('#sm button').getAttribute('role') === 'menuitem'));
    check('menu: ArrowRight opens the submenu on its first item', (await p.evaluate(() => document.getElementById('sm').matches(':popover-open'))) && (await focused(p)) === 'Deep', await focused(p));
    await p.keyboard.press('ArrowDown');
    check('menu: arrows move inside the submenu only', (await focused(p)) === 'Deeper');
    await p.keyboard.press('ArrowDown');
    check('menu: the submenu wraps by itself', (await focused(p)) === 'Deep');
    await p.keyboard.press('ArrowLeft');
    check('menu: ArrowLeft closes the submenu and returns to its button', !(await p.evaluate(() => document.getElementById('sm').matches(':popover-open'))) && (await p.evaluate(() => document.getElementById('m').matches(':popover-open'))) && (await focused(p)) === 'more', await focused(p));
    await p.keyboard.press('ArrowRight');
    await p.keyboard.press('Escape');
    check('menu: Escape closes only the submenu and returns to its button', !(await p.evaluate(() => document.getElementById('sm').matches(':popover-open'))) && (await p.evaluate(() => document.getElementById('m').matches(':popover-open'))) && (await focused(p)) === 'more', await focused(p));
    await p.keyboard.press('ArrowLeft');
    check('menu: ArrowLeft on the root menu does nothing', await p.evaluate(() => document.getElementById('m').matches(':popover-open')));
    await p.keyboard.press('Tab');
    check('menu: Tab closes the whole menu', !(await p.evaluate(() => document.getElementById('m').matches(':popover-open'))));

    // Mouse: opening with the pointer leaves the focus alone.
    await p.click('#pop');
    await p.waitForTimeout(100);
    check('menu: a click opens it without moving the focus into it', (await p.evaluate(() => document.getElementById('pm').matches(':popover-open'))) && (await focused(p)) === 'pop', await focused(p));
    check('menu: a menu opened by the pointer is promoted too', await p.evaluate(() => document.getElementById('pm').getAttribute('role') === 'menu' && document.querySelector('#pm button').getAttribute('role') === 'menuitem'));
    await p.keyboard.press('ArrowDown');
    check('menu: arrows from the focused trigger enter an already open menu', (await focused(p)) === 'Alpha', await focused(p));
    await p.keyboard.press('ArrowDown');
    await p.keyboard.press('Enter');
    check('menu: PopupMenuButton items pick with Enter', (await log(p)) === 'pick:beta' && (await focused(p)) === 'pop');
    check('menu: no page errors', p.problems.length === 0, p.problems.join('; '));
    await p.context().close();
  }
  {
    const p = await open('/menus-none');
    await p.focus('#acct');
    await p.keyboard.press('ArrowDown');
    check('menu: without the part arrows do nothing (native popover only)', !(await p.evaluate(() => document.getElementById('m').matches(':popover-open'))));
    await p.context().close();
  }

  // Shortcuts with other keyboard layouts: a keydown as the browser
  // sends it, `key` from the layout and `code` from the physical key.
  {
    const p = await open('/shortcuts');
    const press = (id, key, code, mods = {}) => p.evaluate(([id, key, code, mods]) => {
      const e = new KeyboardEvent('keydown', { key, code, bubbles: true, cancelable: true, ...mods });
      document.getElementById(id).dispatchEvent(e);
      return e.defaultPrevented;
    }, [id, key, code, mods]);
    const meta = { metaKey: true };
    await press('page', 's', 'KeyS', meta);
    check('shortcuts: ⌘S on a Latin layout', (await log(p)) === 'save');
    const stopped = await press('page', 'ы', 'KeyS', meta);
    check('shortcuts: Cyrillic ы on KeyS falls back to ⌘S', (await log(p)) === 'save' && stopped);
    await press('page', 'σ', 'KeyS', meta);
    check('shortcuts: Greek σ on KeyS falls back to ⌘S', (await log(p)) === 'save');
    await press('page', 'ש', 'Digit1', { ctrlKey: true });
    check('shortcuts: a digit falls back to its physical key', (await log(p)) === 'first');
    await press('page', 'o', 'KeyS', meta);
    check("shortcuts: Dvorak's o on KeyS is an o, not ⌘S", (await log(p)) === '');
    await press('page', 'ы', 'KeyS');
    await press('page', 'ф', 'KeyA', meta);
    check('shortcuts: the fallback keeps exact modifiers and the physical key', (await log(p)) === '');
    await press('field', 'с', 'KeyC', meta);
    check('shortcuts: a text field keeps ⌘C on any layout', (await log(p)) === '');
    await press('field', 'ы', 'KeyS', meta);
    check('shortcuts: ⌘S still reaches from a text field', (await log(p)) === 'save');
    check('shortcuts: no page errors', p.problems.length === 0, p.problems.join('; '));
    await p.context().close();
  }
} finally {
  await browser.close();
}
const failed = results.filter((r) => !r).length;
console.log(`${results.length - failed}/${results.length} checks passed`);
process.exit(failed ? 1 : 0);

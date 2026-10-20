// MenuAnchor and the chips that navigate or delete, in a real browser: the
// menu opens, anchors, closes and moves between submenus with no JavaScript
// (the Popover API), a link item closes it on the tap, a disabled item does
// nothing, and the chips are links with a named delete control beside them
// (never nested), with a visible focus ring, a 24 px target and the selected
// look on the whole chip. The page is rendered by the real widgets
// (packages/thor_ui/tool/menu_chips_page.dart).
//
//   tool/thor e2e menu-chips                  (renders, serves, runs)
//   node test/e2e/checks/menu_chips_check.mjs
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { closeServer, e2e, repo, serveStatic, tabKey } from './lib/e2e.mjs';

const dir = mkdtempSync(join(tmpdir(), 'menu-chips-'));
let server;
try {
  execFileSync('dart', ['run', 'tool/menu_chips_page.dart', join(dir, 'index.html')], {
    cwd: join(repo, 'packages/thor_ui'),
    stdio: 'inherit',
  });
  writeFileSync(join(dir, 'target.html'), '<!doctype html><title>target</title><p id="sub">target');
  server = await serveStatic(dir);
  const base = `http://127.0.0.1:${server.address().port}/`;

  await e2e('menu-chips', { site: null }, async (t) => {
    const ok = (label, cond, detail) => t.check(label, cond, detail);
    const open = (page, id) => page.evaluate((i) => document.getElementById(i).matches(':popover-open'), id);

    // Menu without JavaScript: the Popover API alone.
    for (const js of [false, true]) {
      const tag = js ? '[js]' : '[no js]';
      const page = await t.page({ viewport: { width: 700, height: 600 }, javaScriptEnabled: js });
      await page.goto(base);
      const account = page.getByRole('button', { name: 'Account' });
      ok(`${tag} closed at first`, !(await open(page, 'account-menu')));
      await account.click();
      ok(`${tag} the anchor opens the menu`, await open(page, 'account-menu'));
      const geo = await page.evaluate(() => {
        const a = document.querySelector('[popovertarget="account-menu"]').getBoundingClientRect();
        const m = document.getElementById('account-menu').getBoundingClientRect();
        return { aLeft: a.left, aBottom: a.bottom, mLeft: m.left, mTop: m.top };
      });
      ok(`${tag} the menu is anchored under the button`, Math.abs(geo.mLeft - geo.aLeft) <= 2 && geo.mTop >= geo.aBottom, JSON.stringify(geo));

      await page.keyboard.press('Escape');
      ok(`${tag} Esc closes it`, !(await open(page, 'account-menu')));

      await account.click();
      const disabled = page.locator('#account-menu button:disabled', { hasText: 'Disabled' });
      ok(`${tag} an item without a handler is disabled`, (await disabled.count()) === 1);
      await page.locator('#account-menu button', { hasText: 'Share' }).click();
      ok(`${tag} choosing a button item closes the menu`, !(await open(page, 'account-menu')));

      await account.click();
      await page.locator('#account-menu button', { hasText: 'Stay open' }).click();
      ok(`${tag} closeOnActivate: false keeps it open`, await open(page, 'account-menu'));

      await page.locator('#account-menu button', { hasText: 'More' }).click();
      ok(`${tag} a submenu opens beside its button, the menu stays`, (await open(page, 'more-menu')) && (await open(page, 'account-menu')));
      const side = await page.evaluate(() => {
        const b = document.querySelector('[popovertarget="more-menu"]').getBoundingClientRect();
        const m = document.getElementById('more-menu').getBoundingClientRect();
        return { right: b.right, left: m.left, top: m.top, btop: b.top };
      });
      ok(`${tag} the submenu is at the inline end of its button`, Math.abs(side.left - side.right) <= 8 && Math.abs(side.top - side.btop) <= 8, JSON.stringify(side));
      await page.locator('#more-menu button', { hasText: 'Export' }).click();
      ok(`${tag} an item of the submenu closes all of it`, !(await open(page, 'more-menu')) && !(await open(page, 'account-menu')));

      // A link item: followed natively (no JS), and the menu closes on the tap with JS.
      await account.click();
      await page.locator('#account-menu a', { hasText: 'Orders' }).click();
      await page.waitForURL('**/target.html');
      ok(`${tag} a link item navigates`, page.url().endsWith('/target.html'), page.url());
      await page.goBack();
      if (js) {
        await account.click();
        await page.locator('#more-menu', { hasText: 'Help' }).waitFor({ state: 'attached' });
        await page.locator('#account-menu button', { hasText: 'More' }).click();
        await page.locator('#more-menu a', { hasText: 'Help' }).click();
        ok('[js] following a link of a submenu closes the whole menu', !(await open(page, 'more-menu')) && !(await open(page, 'account-menu')));
        ok('[js] the link was followed', page.url().endsWith('#help'), page.url());
      }
      ok(`${tag} no page errors`, page.problems.length === 0, page.problems.join(' | '));
    }

    // Chips.
    const page = await t.page({ viewport: { width: 700, height: 600 }, javaScriptEnabled: false });
    await page.goto(base);
    const bad = await page.evaluate(
      () => document.querySelectorAll('a a, a button, button a, button button, button a[href], a [role=button]').length,
    );
    ok('no control inside another control', bad === 0, await page.evaluate(() =>
      [...document.querySelectorAll('a a, a button, button a, button button, button a[href], a [role=button]')].map((e) => e.outerHTML.slice(0, 80)).join(' | ')));

    const names = await page.evaluate(() =>
      [...document.querySelectorAll('#chips a, #chips button')].map((e) => ({
        tag: e.tagName.toLowerCase(),
        name: e.getAttribute('aria-label') ?? e.textContent.trim(),
        href: e.getAttribute('href'),
        disabled: e.disabled === true,
      })),
    );
    const find = (n) => names.find((x) => x.name === n);
    ok('Red: the delete is a link named "Delete Red"', find('Delete Red')?.tag === 'a' && find('Delete Red').href === '/', JSON.stringify(names));
    ok('Blue: a link, and its delete is "Remove Blue"', find('Blue')?.tag === 'a' && find('Remove Blue')?.tag === 'a');
    ok('a disabled chip has a disabled delete button', find('Delete Off')?.tag === 'button' && find('Delete Off').disabled);
    ok('the link chips are <a href>', ['Link filter', 'Link action', 'Picked'].every((n) => find(n)?.tag === 'a' && find(n).href));
    ok('a plain Chip is no control', find('Plain') === undefined);

    const geo = await page.evaluate(() => {
      const box = (el) => el.getBoundingClientRect();
      const wrap = (n) => [...document.querySelectorAll('#chips [data-thor=InputChip]')].find((w) => w.textContent.includes(n));
      const blue = wrap('Blue');
      const del = blue.querySelector('a[aria-label="Remove Blue"]');
      const body = blue.querySelector('a:not([aria-label])');
      return {
        chipH: box(blue).height,
        delW: box(del).width,
        delH: box(del).height,
        bodyH: box(body).height,
        ltrDeleteAfterBody: box(del).left >= box(body).right - 1,
        deleteInside: box(del).right <= box(blue).right && box(del).left >= box(blue).left,
      };
    });
    ok('the chip is 32 px high and its controls are at least 24 px', geo.chipH === 32 && geo.delW >= 24 && geo.delH >= 24, JSON.stringify(geo));
    ok('the body spans the chip height inside its border (a target to the edge)', geo.bodyH === 30, JSON.stringify(geo));
    ok('the delete sits after the body, inside the chip', geo.ltrDeleteAfterBody && geo.deleteInside, JSON.stringify(geo));

    // Selected: aria-current on the link, the look on the whole chip (also with a delete beside it).
    const looks = await page.evaluate(() => {
      const bg = (el) => getComputedStyle(el).backgroundColor;
      const wrap = (n) => [...document.querySelectorAll('#chips [data-thor=InputChip]')].find((w) => w.textContent.includes(n));
      const plainBlue = bg(wrap('Blue'));
      const both = wrap('Both');
      const picked = wrap('Picked');
      return {
        plainBlue,
        both: bg(both),
        picked: bg(picked),
        current: both.querySelector('a[aria-current="true"]') !== null,
        off: getComputedStyle(wrap('Off')).opacity,
      };
    });
    ok('a selected link chip has aria-current', looks.current, JSON.stringify(looks));
    ok('selected: the whole wrapper (body + delete) takes the selected fill', looks.both !== looks.plainBlue && looks.both === looks.picked, JSON.stringify(looks));
    ok('a disabled chip is dimmed', looks.off === '0.38', looks.off);

    // Keyboard: Tab reaches the body and the delete of a chip; both show a ring; Enter follows.
    await page.evaluate(() => document.body.focus());
    const seen = [];
    for (let i = 0; i < 20; i++) {
      await page.keyboard.press(tabKey());
      const s = await page.evaluate(() => {
        const e = document.activeElement;
        const c = getComputedStyle(e);
        return { name: e.getAttribute('aria-label') ?? e.textContent.trim(), ring: c.outlineStyle !== 'none' && parseFloat(c.outlineWidth) > 0 };
      });
      seen.push(s);
      if (s.name === 'Remove Blue') break;
    }
    const order = seen.map((s) => s.name);
    ok('Tab order: Account, Delete Red, Blue, Remove Blue', ['Account', 'Delete Red', 'Blue', 'Remove Blue'].every((n, i) => order[i] === n), order.join(' > '));
    ok('every stop shows a focus ring', seen.every((s) => s.ring), JSON.stringify(seen));
    await Promise.all([page.waitForURL('**/target.html#unblue'), page.keyboard.press('Enter')]);
    ok('Enter on a delete link follows it', page.url().endsWith('#unblue'), page.url());

    // Right-to-left: the delete is on the other side.
    const rtl = await t.page({ viewport: { width: 700, height: 600 }, javaScriptEnabled: false });
    await rtl.goto(base);
    await rtl.evaluate(() => (document.documentElement.dir = 'rtl'));
    const flipped = await rtl.evaluate(() => {
      const blue = [...document.querySelectorAll('#chips [data-thor=InputChip]')].find((w) => w.textContent.includes('Blue'));
      const del = blue.querySelector('a[aria-label="Remove Blue"]').getBoundingClientRect();
      const body = blue.querySelector('a:not([aria-label])').getBoundingClientRect();
      return { del: del.left, body: body.left };
    });
    ok('rtl: the delete is before the body (on the left)', flipped.del < flipped.body, JSON.stringify(flipped));
    for (const p of [page, rtl]) ok('no page errors', p.problems.length === 0, p.problems.join(' | '));
  });
} finally {
  await closeServer(server);
  rmSync(dir, { recursive: true, force: true });
}

// Scaffold(drawer:, endDrawer:) in a real browser: the AppBar's menu
// buttons open native <dialog>s with no id written anywhere, with and
// without JavaScript, by mouse and keyboard; Esc, the backdrop and
// DialogClose() close them and the focus goes back to the button; the page
// behind is inert; the automatic ids never repeat and every button finds
// its dialog.
//
//   tool/thor e2e drawer                       (renders the page, serves, runs)
//   node test/e2e/checks/drawer_check.mjs
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { closeServer, e2e, repo, serveStatic, tabKey } from './lib/e2e.mjs';

const dir = mkdtempSync(join(tmpdir(), 'thor-drawer-'));
let server;

// A click focuses a button in Chromium and Firefox; in WebKit on macOS it does
// not (Safari's default), so the dialog has no button to give the focus back to.
// There the button is focused and pressed with Enter: the same thing for a keyboard user.
const clickFocuses = !(process.env.E2E_BROWSER === 'webkit' && process.platform === 'darwin');
const activate = async (page, button) => {
  if (clickFocuses) return button.click();
  await button.focus();
  await page.keyboard.press('Enter');
};

await e2e('drawer', { site: null }, async (t) => {
  try {
    await run(t);
  } finally {
    // `e2e` exits when the body ends: clean up here.
    await closeServer(server);
    rmSync(dir, { recursive: true, force: true });
  }
});

async function run(t) {
  execFileSync('dart', ['run', 'tool/e2e_pages.dart', dir], {
    cwd: join(repo, 'packages/thor_ui'),
    stdio: ['ignore', 'inherit', 'inherit'],
  });
  server = await serveStatic(dir);
  const url = `http://127.0.0.1:${server.address().port}/drawer.html`;

  const state = (page, id) =>
    page.evaluate((id) => {
      const d = document.getElementById(id);
      const r = d?.getBoundingClientRect();
      return {
        open: !!d?.open,
        modal: !!d?.matches(':modal'),
        left: r?.left,
        right: r?.right,
        width: r?.width,
        active: document.activeElement?.getAttribute('aria-label') ?? document.activeElement?.textContent?.trim(),
      };
    }, id);

  for (const js of [false, true]) {
    const label = js ? 'with JS' : 'without JS';
    const page = await t.page({ javaScriptEnabled: js, viewport: { width: 900, height: 600 } });
    await page.goto(url);

    const ids = await page.evaluate(() => ({
      dup: [...document.querySelectorAll('[id]')].map((e) => e.id).filter((id, i, all) => all.indexOf(id) !== i),
      buttons: [...document.querySelectorAll('[commandfor]')].map((b) => ({
        target: b.getAttribute('commandfor'),
        found: !!document.getElementById(b.getAttribute('commandfor')),
        name: b.getAttribute('aria-label'),
      })),
    }));
    t.check(`${label}: no DOM id repeats`, ids.dup.length === 0, ids.dup.join());
    t.check(`${label}: every commandfor finds its dialog`, ids.buttons.every((b) => b.found), JSON.stringify(ids.buttons));

    const menu = page.getByRole('button', { name: 'Open navigation menu' });
    const end = page.getByRole('button', { name: 'Open secondary menu' });
    t.check(`${label}: the two buttons have distinct names`, (await menu.count()) === 1 && (await end.count()) === 1);
    const drawerId = await menu.getAttribute('commandfor');
    const endId = await end.getAttribute('commandfor');
    t.check(`${label}: two drawers, two ids`, drawerId && endId && drawerId !== endId, `${drawerId} ${endId}`);

    // Closed at first.
    let d = await state(page, drawerId);
    t.check(`${label}: closed at first`, !d.open);

    // Open with the mouse: a modal panel on the start edge.
    await activate(page, menu);
    d = await state(page, drawerId);
    t.check(`${label}: the menu button opens the drawer (modal)`, d.open && d.modal, JSON.stringify(d));
    await page.waitForTimeout(400);
    d = await state(page, drawerId);
    t.check(`${label}: it sits at the start edge with a width`, d.left === 0 && d.width > 200 && d.width <= 320, JSON.stringify(d));
    t.check(`${label}: the focus moved into the drawer`, await page.evaluate((id) => document.getElementById(id).contains(document.activeElement), drawerId));

    // Esc closes it and the focus returns to the button.
    await page.keyboard.press('Escape');
    d = await state(page, drawerId);
    t.check(`${label}: Esc closes it`, !d.open);
    t.check(`${label}: the focus goes back to the menu button`, d.active === 'Open navigation menu', d.active);

    // Keyboard, on a fresh load: the Scaffold's skip link is the first Tab
    // stop (WCAG 2.4.1) and points at the <main>; the menu button is the next
    // one and Enter opens the drawer. The skip link is not followed here: the
    // page has a `<base href="/">`, so its `#main-content` leaves the page.
    await page.reload();
    await page.keyboard.press(tabKey());
    const skip = await page.evaluate(() => {
      const a = document.activeElement;
      const target = a?.getAttribute('href')?.startsWith('#') ? document.getElementById(a.getAttribute('href').slice(1)) : null;
      return { text: a?.textContent?.trim(), target: target?.localName };
    });
    t.check(`${label}: the skip link is the first Tab stop and leads to <main>`, skip.text === 'Skip to content' && skip.target === 'main', JSON.stringify(skip));
    await page.keyboard.press(tabKey());
    const second = (await state(page, drawerId)).active;
    t.check(`${label}: the menu button is the next Tab stop`, second === 'Open navigation menu', second);
    await page.keyboard.press('Enter');
    d = await state(page, drawerId);
    t.check(`${label}: Enter on the button opens it`, d.open);
    await page.waitForTimeout(400);

    // The page behind is inert: the button there cannot be clicked.
    const behind = await page.evaluate(() => {
      const b = [...document.querySelectorAll('main button')].find((x) => x.textContent === 'Behind');
      const r = b.getBoundingClientRect();
      const hit = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2);
      return { covered: hit !== b, inert: !!document.getElementById('dlg-1') };
    });
    t.check(`${label}: the page behind is not reachable while it is open`, behind.covered, JSON.stringify(behind));

    // DialogClose() without an id closes the nearest dialog.
    await page.getByRole('button', { name: 'Close', exact: true }).click();
    d = await state(page, drawerId);
    t.check(`${label}: DialogClose() closes its own drawer`, !d.open);

    // A click on the backdrop closes it (closedby="any").
    await menu.click();
    await page.waitForTimeout(300);
    await page.mouse.click(800, 300);
    d = await state(page, drawerId);
    t.check(`${label}: a click outside closes it`, !d.open);

    // The end drawer: from the end edge, closed by its own DialogClose().
    await activate(page, end);
    await page.waitForTimeout(400);
    const e = await state(page, endId);
    t.check(`${label}: the end button opens the end drawer at the end edge`, e.open && Math.abs(e.right - 900) <= 1, JSON.stringify(e));
    t.check(`${label}: the start drawer stays closed`, !(await state(page, drawerId)).open);
    await page.getByRole('button', { name: 'Close settings' }).click();
    t.check(`${label}: its DialogClose() closes it`, !(await state(page, endId)).open);
    t.check(`${label}: the focus returns to the end button`, (await state(page, endId)).active === 'Open secondary menu');

    // Dialogs of a list, named by their keys, each closed by its own button.
    await page.getByRole('button', { name: 'Open 2' }).click();
    t.check(`${label}: a keyed dialog opens by its derived id`, (await state(page, 'dlg-2')).open);
    await page.getByRole('button', { name: 'Close 2' }).click();
    t.check(`${label}: its DialogClose() closes that one only`, !(await state(page, 'dlg-2')).open);

    t.check(`${label}: no console or page errors`, page.problems.length === 0, page.problems.join(' | '));
    await page.context().close();
  }

  // With JS only: following a link inside the drawer closes it on the tap.
  {
    const page = await t.page({ viewport: { width: 900, height: 600 } });
    await page.goto(url);
    const menu = page.getByRole('button', { name: 'Open navigation menu' });
    const id = await menu.getAttribute('commandfor');
    await menu.click();
    await page.getByRole('link', { name: 'Inside' }).click();
    t.check('with JS: a link inside the drawer closes it', !(await state(page, id)).open);
    await page.context().close();
  }

  // A phone: the drawer is at most 85% of the width.
  {
    const page = await t.page({ viewport: { width: 360, height: 640 } });
    await page.goto(url);
    const menu = page.getByRole('button', { name: 'Open navigation menu' });
    const id = await menu.getAttribute('commandfor');
    await menu.click();
    await page.waitForTimeout(400);
    const d = await state(page, id);
    t.check('phone: the drawer leaves room for the backdrop', d.width <= 360 * 0.85 + 1, JSON.stringify(d));
    await page.context().close();
  }

  // RTL: the start drawer slides from the right, the end drawer from the left.
  {
    const page = await t.page({ viewport: { width: 900, height: 600 } });
    await page.goto(url);
    await page.evaluate(() => (document.documentElement.dir = 'rtl'));
    const menu = page.getByRole('button', { name: 'Open navigation menu' });
    const end = page.getByRole('button', { name: 'Open secondary menu' });
    const id = await menu.getAttribute('commandfor');
    const endId = await end.getAttribute('commandfor');
    await menu.click();
    await page.waitForTimeout(400);
    const s = await state(page, id);
    t.check('RTL: the start drawer sits at the right edge', s.open && Math.abs(s.right - 900) <= 1, JSON.stringify(s));
    await page.keyboard.press('Escape');
    await end.click();
    await page.waitForTimeout(400);
    const e = await state(page, endId);
    t.check('RTL: the end drawer sits at the left edge', e.open && e.left === 0, JSON.stringify(e));
    await page.context().close();
  }

  // GridView.extent is a cap like Flutter's SliverGridDelegateWithMaxCrossAxisExtent
  // (ceil(width / (max + spacing)) columns, tiles never wider than max) and an
  // IndexedStack keeps its hidden children out of reach.
  {
    const gridUrl = url.replace('drawer.html', 'grid.html');
    const page = await t.page({ viewport: { width: 900, height: 900 } });
    await page.goto(gridUrl);
    const measure = () =>
      page.evaluate(() => {
                const grids = [...document.querySelectorAll('[data-thor=GridViewGrid]')];
        return grids.map((g) => {
          const cs = getComputedStyle(g);
          const kids = [...g.children];
          const lefts = new Set(kids.map((k) => Math.round(k.getBoundingClientRect().left)));
          const w = kids[0].getBoundingClientRect().width;
          const width = g.clientWidth - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight);
          return { cols: lefts.size, tile: w, width, gap: parseFloat(cs.columnGap) || 0 };
        });
      });
    const maxes = [200, 150, 100];
    const widths = [320, 360, 399, 400, 401, 600, 799, 800, 801, 900, 1200, 1500];
    const bad = [];
    const samples = [];
    for (const vw of widths) {
      await page.setViewportSize({ width: vw, height: 900 });
      const rows = await measure();
      rows.forEach((r, i) => {
        const M = maxes[i];
        const want = Math.max(1, Math.ceil(r.width / (M + r.gap)));
        samples.push(`${vw}:${'PSN'[i]}=${r.cols}`);
        // Flutter's tile is (width - gaps) / columns: it can pass `max` by up to the spacing.
        const tile = (r.width - (want - 1) * r.gap) / want;
        if (r.cols !== want || Math.abs(r.tile - tile) > 0.05) bad.push(`${vw}px grid ${i}: ${r.cols} cols, tile ${r.tile.toFixed(1)}; Flutter ${want} (max ${M}, content ${r.width})`);
      });
    }
    t.check('GridView.extent: columns = ceil(width / (max + spacing)), the tile is (width - gaps) / columns, at 12 widths', bad.length === 0, bad.join(' | '));
    console.log('  samples ' + samples.join(' '));

    // The extra container does not stop the grid from scrolling in a bounded box.
    const scroll = await page.evaluate(() => {
      const g = document.querySelector('[data-thor=GridViewGrid]');
      return { h: g.clientHeight, sh: g.scrollHeight };
    });
    t.check('GridView.extent still scrolls inside its bounded height', scroll.h > 250 && scroll.h <= 300 && scroll.sh > scroll.h, JSON.stringify(scroll));

    // The exact edges: 400px is two columns of 200, one pixel more is three.
    for (const [w, want] of [[200, 1], [201, 2], [400, 2], [401, 3], [600, 3], [601, 4]]) {
      const cols = await page.evaluate((w) => {
        const scope = document.querySelector('[data-thor=GridView]');
        scope.style.width = w + 'px';
        const g = scope.firstElementChild;
        return new Set([...g.children].map((k) => Math.round(k.getBoundingClientRect().left))).size;
      }, w);
      t.check(`GridView.extent max 200 at ${w}px: ${want} columns`, cols === want, String(cols));
    }

    // A hidden IndexedStack child is out of the tab order and unreachable.
    await page.setViewportSize({ width: 900, height: 900 });
    const stack = await page.evaluate(() => {
      const inputs = [...document.querySelectorAll('[data-stack-index] input')];
      const vis = inputs.map((i) => getComputedStyle(i).visibility);
      const s = document.querySelector('[data-stack-index]');
      return { vis, index: s.getAttribute('data-stack-index'), n: inputs.length };
    });
    t.check('IndexedStack: only the index child is visible', stack.vis.join() === 'hidden,visible', JSON.stringify(stack));
    await page.locator('[data-stack-index] input').nth(1).focus();
    await page.keyboard.type('kept');
    await page.evaluate(() => document.querySelector('[data-stack-index]').setAttribute('data-stack-index', '0'));
    await page.locator('[data-stack-index] input').nth(0).focus();
    await page.keyboard.type('first');
    // Tab from the shown input never lands in the hidden one.
    await page.keyboard.press(tabKey());
    const active = await page.evaluate(() => document.activeElement === document.querySelectorAll('[data-stack-index] input')[1]);
    t.check('IndexedStack: Tab skips the hidden child', !active);
    await page.evaluate(() => document.querySelector('[data-stack-index]').setAttribute('data-stack-index', '1'));
    const kept = await page.evaluate(() => [...document.querySelectorAll('[data-stack-index] input')].map((i) => i.value));
    t.check('IndexedStack: switching keeps each child state', kept.join() === 'first,kept', kept.join());
    await page.evaluate(() => document.querySelector('[data-stack-index]').removeAttribute('data-stack-index'));
    const none = await page.evaluate(() => [...document.querySelectorAll('[data-thor=IndexedStack] input')].map((i) => getComputedStyle(i).visibility));
    t.check('IndexedStack: no index attribute shows none', none.every((v) => v === 'hidden'), none.join());
    await page.context().close();
  }
}

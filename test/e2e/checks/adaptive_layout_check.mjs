// GridLayout(columnWidth:) and Drawer(permanentFrom:) in a real browser
// (Chromium), at 390 and 1280 px, with and without JS:
//  - GridLayout(columnWidth:) from md: two fluid columns on a phone, exact 260 px
//    tracks with a 73 px gap on a desktop (one grid, no JS needed);
//  - Drawer(permanentFrom: md): one <dialog> that is a modal on a phone (opened by
//    its button, focus trap, Esc, page behind unreachable) and an inline panel on
//    a desktop (visible with no JS, no trigger, no trap, the page behind usable).
//
//  - the attacks: a column wider than its box, a gap larger than the room, every
//    alignment, RTL, container thresholds, many variants, GridView with a layout
//    on top, a per-breakpoint aspect ratio; two permanent drawers (one per side,
//    RTL, Esc, Tab order, a modal that meets the breakpoint), and a Scaffold whose
//    drawers are panels from md and lg.
//
//   tool/thor e2e adaptive-layout                (renders the pages, serves, runs)
//   E2E_BROWSER=firefox|webkit tool/thor e2e adaptive-layout   (the same, in another engine)
//   node test/e2e/checks/adaptive_layout_check.mjs
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { closeServer, e2e, repo, serveStatic, tabKey } from './lib/e2e.mjs';

const dir = mkdtempSync(join(tmpdir(), 'thor-adaptive-layout-'));
let server;
/** The cell of a grid that holds the text `name` (the element that is the grid's child). */
const CELLS = `(name) => {
  const leaf = [...document.querySelectorAll('div')].find((d) => d.textContent === name && !d.children.length);
  let e = leaf;
  while (e.parentElement && getComputedStyle(e.parentElement).display !== 'grid') e = e.parentElement;
  return e;
}`;

const TAB = tabKey();

await e2e('adaptive-layout', { site: null }, async (t) => {
  try {
    await run(t);
  } finally {
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
  const base = `http://127.0.0.1:${server.address().port}`;

  for (const js of [false, true]) {
    const mode = js ? 'with JS' : 'without JS';
    await attacks(t, base, js, mode);

    // --- The grid.
    for (const [width, label] of [[390, 'phone'], [1280, 'desktop']]) {
      const page = await t.page({ javaScriptEnabled: js, viewport: { width, height: 800 } });
      await page.goto(`${base}/adaptive-grid.html`);
      const g = await page.evaluate(() => {
        const cards = [...document.querySelectorAll('div')].filter((d) => /^card \d$/.test(d.textContent));
        const rects = cards.map((c) => c.getBoundingClientRect());
        const left = rects[0].left;
        const first = rects.filter((r) => Math.abs(r.top - rects[0].top) < 1);
        return {
          n: cards.length,
          perRow: first.length,
          widths: [...new Set(first.map((r) => Math.round(r.width * 10) / 10))],
          gap: first.length > 1 ? Math.round((first[1].left - first[0].right) * 10) / 10 : null,
          left,
          overflow: document.documentElement.scrollWidth > innerWidth,
        };
      });
      if (width === 390) {
        t.check(`${mode} ${label}: two fluid columns`, g.perRow === 2 && g.widths.length === 1 && g.widths[0] > 150 && g.widths[0] !== 260, JSON.stringify(g));
        t.check(`${mode} ${label}: the 16 px gap`, g.gap === 16, JSON.stringify(g));
      } else {
        t.check(`${mode} ${label}: tracks of exactly 260 px`, g.widths.length === 1 && g.widths[0] === 260, JSON.stringify(g));
        t.check(`${mode} ${label}: exactly the 73 px gap`, g.gap === 73, JSON.stringify(g));
        // 1280 - 32 padding = 1248: floor((1248 + 73) / (260 + 73)) = 3.
        t.check(`${mode} ${label}: as many as fit`, g.perRow === 3, JSON.stringify(g));
      }
      t.check(`${mode} ${label}: no sideways scroll`, !g.overflow, JSON.stringify(g));
      await page.close();
    }

    // --- The drawer.
    const state = (page) =>
      page.evaluate(() => {
        const d = document.getElementById('filters');
        const r = d.getBoundingClientRect();
        const btn = [...document.querySelectorAll('button')].find((b) => b.textContent.trim() === 'Show filters');
        const behind = [...document.querySelectorAll('button')].find((b) => b.textContent.trim() === 'Behind');
        const br = behind.getBoundingClientRect();
        const hit = document.elementFromPoint(br.left + br.width / 2, br.top + br.height / 2);
        return {
          dialogs: document.querySelectorAll('dialog').length,
          open: d.open,
          modal: d.matches(':modal'),
          display: getComputedStyle(d).display,
          position: getComputedStyle(d).position,
          visible: r.width > 0 && r.height > 0 && getComputedStyle(d).visibility === 'visible',
          left: r.left,
          width: r.width,
          height: r.height,
          trigger: btn ? getComputedStyle(btn).display : null,
          behindReachable: hit === behind,
        };
      });

    // Desktop: a panel in the page from the first paint.
    const wide = await t.page({ javaScriptEnabled: js, viewport: { width: 1280, height: 800 } });
    await wide.goto(`${base}/permanent-drawer.html`);
    let s = await state(wide);
    t.check(`${mode} 1280: one dialog, shown inline without being opened`, s.dialogs === 1 && !s.open && s.display === 'flex' && s.visible, JSON.stringify(s));
    t.check(`${mode} 1280: static, the width the drawer asks for`, s.position === 'static' && Math.round(s.width) === 304 && s.left < 40, JSON.stringify(s));
    t.check(`${mode} 1280: the trigger is gone`, s.trigger === 'none', JSON.stringify(s));
    t.check(`${mode} 1280: it is not modal and the page behind is usable`, !s.modal && s.behindReachable, JSON.stringify(s));
    const side = await wide.evaluate(() => {
      const d = document.getElementById('filters').getBoundingClientRect();
      const b = [...document.querySelectorAll('button')].find((e) => e.textContent.trim() === 'Behind');
      return { dRight: d.right, resultsLeft: b.getBoundingClientRect().left };
    });
    t.check(`${mode} 1280: the content sits beside it`, side.resultsLeft >= side.dRight - 1, JSON.stringify(side));
    const name = await wide.evaluate(() => document.getElementById('filters').getAttribute('aria-label'));
    t.check(`${mode} 1280: it keeps its accessible name`, name === 'Filters');
    // Tab goes through the panel like through any block (no trap).
    await wide.keyboard.press(TAB);
    await wide.keyboard.press(TAB);
    await wide.keyboard.press(TAB);
    const focus = await wide.evaluate(() => document.activeElement?.textContent?.trim());
    t.check(`${mode} 1280: Tab leaves the panel (no focus trap)`, focus === 'Behind', focus);
    await wide.close();

    // Phone: the usual modal.
    const phone = await t.page({ javaScriptEnabled: js, viewport: { width: 390, height: 800 } });
    await phone.goto(`${base}/permanent-drawer.html`);
    s = await state(phone);
    t.check(`${mode} 390: closed, out of the flow`, s.dialogs === 1 && !s.open && s.display === 'none' && !s.visible, JSON.stringify(s));
    t.check(`${mode} 390: the trigger shows`, s.trigger !== 'none' && s.trigger !== null, JSON.stringify(s));
    // Opened with the keyboard: Safari does not focus a button that is clicked, so it
    // has no focus to give back (the click is checked below, with Done).
    await phone.getByRole('button', { name: 'Show filters' }).focus();
    await phone.keyboard.press('Enter');
    await phone.waitForTimeout(400);
    s = await state(phone);
    t.check(`${mode} 390: the button opens it as a modal (Enter)`, s.open && s.modal && s.left === 0 && s.width > 200 && s.width < 390, JSON.stringify(s));
    t.check(`${mode} 390: the page behind is not reachable`, !s.behindReachable, JSON.stringify(s));
    t.check(`${mode} 390: the focus is inside`, await phone.evaluate(() => document.getElementById('filters').contains(document.activeElement)));
    // The focus is trapped: Tab never reaches the page behind.
    for (let i = 0; i < 6; i++) await phone.keyboard.press(TAB);
    t.check(`${mode} 390: Tab stays in the drawer`, await phone.evaluate(() => document.getElementById('filters').contains(document.activeElement)));
    await phone.keyboard.press('Escape');
    await phone.waitForTimeout(400); // the slide out
    s = await state(phone);
    t.check(`${mode} 390: Esc closes it`, !s.open && s.display === 'none', JSON.stringify(s));
    t.check(`${mode} 390: the focus goes back to the trigger`, await phone.evaluate(() => document.activeElement?.textContent?.trim() === 'Show filters'));
    await phone.getByRole('button', { name: 'Show filters' }).click();
    await phone.waitForTimeout(400);
    await phone.getByRole('button', { name: 'Done' }).click();
    t.check(`${mode} 390: DialogClose closes it`, !(await state(phone)).open);
    await phone.close();
  }
}

// ---------------------------------------------------------------------------
// The attacks.

async function attacks(t, base, js, mode) {
  const near = (a, b, eps = 0.6) => Math.abs(a - b) <= eps;

  // --- Grid tracks.
  for (const rtl of [false, true]) {
    const label = `${mode}${rtl ? ' RTL' : ''}`;
    const page = await t.page({ javaScriptEnabled: js, viewport: { width: 1280, height: 800 } });
    await page.goto(`${base}/grid-attacks${rtl ? '-rtl' : ''}.html`);
    const lefts = (prefix) =>
      page.evaluate(
        ([prefix, cells]) => {
          const cell = eval(cells);
          const out = [];
          for (let i = 0; i < 6; i++) {
            const name = `${prefix}-${i}`;
            if (![...document.querySelectorAll('div')].some((d) => d.textContent === name && !d.children.length)) break;
            const r = cell(name).getBoundingClientRect();
            out.push({ left: Math.round(r.left * 10) / 10, right: Math.round(r.right * 10) / 10, top: Math.round(r.top), width: Math.round(r.width * 10) / 10 });
          }
          return out;
        },
        [prefix, CELLS],
      );
    const sign = rtl ? -1 : 1;
    // The edge of a 1000 px box that starts the line (the page has an 8 px margin).
    const boxStart = rtl ? 1272 : 8;
    const edge = (c) => (rtl ? c.right : c.left);

    const wide = await lefts('wide');
    t.check(`${label}: a column wider than its box is the box`, wide.length === 2 && wide.every((c) => near(c.width, 300)), JSON.stringify(wide));
    const gap = await lefts('gap');
    t.check(`${label}: a gap larger than the room leaves one column of the track width`, gap.length === 2 && near(gap[0].width, 260) && gap[1].top > gap[0].top && near(edge(gap[0]), edge(gap[1])), JSON.stringify(gap));

    const start = await lefts('start');
    t.check(`${label}: alignment start packs the tracks at the start`, near(edge(start[0]), boxStart) && near(Math.abs(edge(start[1]) - edge(start[0])), 220), JSON.stringify(start));
    const center = await lefts('center');
    // 1000 - (4 * 200 + 3 * 20) = 140 left over: half before the tracks.
    t.check(`${label}: alignment center puts half the room before`, near(edge(center[0]), boxStart + sign * 70), JSON.stringify(center));
    const end = await lefts('end');
    t.check(`${label}: alignment end puts all the room before`, near(edge(end[0]), boxStart + sign * 140), JSON.stringify(end));
    const between = await lefts('between');
    t.check(`${label}: alignment spaceBetween spreads the room between the tracks`, near(edge(between[0]), boxStart) && near(Math.abs(edge(between[1]) - edge(between[0])), 200 + 20 + 140 / 3, 1), JSON.stringify(between));

    const full = await lefts('full');
    t.check(`${label}: columnStart 1 / columnEnd -1 runs the whole row`, near(full[0].width, 640) && near(edge(full[0]), boxStart) && full[1].top > full[0].top, JSON.stringify(full));
    t.check(`${label}: no sideways scroll`, !(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth)));

    // Container thresholds that are not whole, written out of order. The fractional
    // edges are left out on purpose: WebKit compares a container's width in whole
    // pixels (a threshold of 592.02 first applies at 593), the others to the 1/64.
    const columnsAt = async (w) =>
      page.evaluate(
        ([w, cells]) => {
          const cell = eval(cells);
          const first = cell('cont-0');
          const grid = first.parentElement;
          grid.parentElement.parentElement.style.width = `${w}px`;
          const rects = [...grid.children].map((c) => c.getBoundingClientRect());
          return rects.filter((r) => Math.abs(r.top - rects[0].top) < 1).length;
        },
        [w, CELLS],
      );
    const got = {};
    for (const w of [399, 400, 500, 592, 593, 700, 925, 926, 1000]) got[w] = await columnsAt(w);
    t.check(
      `${label}: container keys 400 / 592.02 / 925.5 apply from their width, in order`,
      got[399] === 1 && got[400] === 3 && got[500] === 3 && got[592] === 3 && got[593] === 2 && got[700] === 2 && got[925] === 2 && got[926] === 6 && got[1000] === 6,
      JSON.stringify(got),
    );

    if (!rtl) {
      // Many variants: the larger breakpoint wins, at the pixel.
      const perRow = {};
      for (const w of [599, 600, 839, 840, 1199, 1200, 1599, 1600]) {
        await page.setViewportSize({ width: w, height: 800 });
        perRow[w] = await page.evaluate((cells) => {
          const cell = eval(cells);
          const rects = [...cell('many-0').parentElement.children].map((c) => c.getBoundingClientRect());
          return rects.filter((r) => Math.abs(r.top - rects[0].top) < 1).length;
        }, CELLS);
      }
      t.check(
        `${label}: medium / expanded / large / extraLarge variants cascade (1, 2, 3, 150 px tracks, 5)`,
        perRow[599] === 1 && perRow[600] === 2 && perRow[839] === 2 && perRow[840] === 3 && perRow[1199] === 3 && perRow[1200] === 6 && perRow[1599] === 6 && perRow[1600] === 5,
        JSON.stringify(perRow),
      );
    }
    await page.close();
  }

  // --- GridView with a layout on top.
  const gv = await t.page({ javaScriptEnabled: js, viewport: { width: 800, height: 800 } });
  await gv.goto(`${base}/gridview-attacks.html`);
  const tiles = (prefix) =>
    gv.evaluate(
      ([prefix, cells]) => {
        const cell = eval(cells);
        return [0, 1, 2, 3, 4, 5].map((i) => {
          const r = cell(`${prefix}-${i}`).getBoundingClientRect();
          return { left: Math.round(r.left * 10) / 10, top: Math.round(r.top), width: Math.round(r.width * 10) / 10, height: Math.round(r.height * 10) / 10 };
        });
      },
      [prefix, CELLS],
    );
  const perRowOf = (cs) => cs.filter((c) => Math.abs(c.top - cs[0].top) < 1).length;
  for (const [width, expectCount, expectExtent, expectExtcols] of [[390, 2, 2, 2], [800, 2, 2, 2], [1280, 4, 4, 2]]) {
    await gv.setViewportSize({ width, height: 800 });
    const count = await tiles('count');
    const extent = await tiles('extent');
    const extcols = await tiles('extcols');
    if (width >= 768) {
      t.check(`${mode} GridView.count ${width}: fixed 260 px tracks from md`, count.every((c) => near(c.width, 260)) && near(count[1].left - count[0].left, 333) && perRowOf(count) === expectCount, JSON.stringify(count.slice(0, 2)));
      t.check(`${mode} GridView.extent ${width}: the layout's tracks beat the counted columns`, extent.every((c) => near(c.width, 260)) && near(extent[1].left - extent[0].left, 333) && perRowOf(extent) === expectExtent, JSON.stringify(extent.slice(0, 2)));
      t.check(`${mode} GridView.extent ${width}: the layout's two columns beat the counted ones`, perRowOf(extcols) === expectExtcols, JSON.stringify(extcols.slice(0, 3)));
    } else {
      t.check(`${mode} GridView.extent ${width}: below md the counted columns stay`, perRowOf(extent) === 2 && perRowOf(extcols) === 2 && perRowOf(count) === 2, `${perRowOf(count)} ${perRowOf(extent)} ${perRowOf(extcols)}`);
    }
    const ratio = await tiles('ratio');
    const r = ratio[0].width / ratio[0].height;
    t.check(
      `${mode} GridView.count ${width}: tile ratio ${width >= 768 ? '2:1 from md' : '1:1 below'}`,
      near(r, width >= 768 ? 2 : 1, 0.05) && perRowOf(ratio) === (width >= 768 ? 3 : 2),
      JSON.stringify(ratio[0]),
    );
  }
  await gv.close();

  // --- Two permanent drawers.
  for (const rtl of [false, true]) {
    const label = `${mode}${rtl ? ' RTL' : ''}`;
    const wide = await t.page({ javaScriptEnabled: js, viewport: { width: 1280, height: 800 } });
    await wide.goto(`${base}/drawer-attacks${rtl ? '-rtl' : ''}.html`);
    const geo = () =>
      wide.evaluate(() =>
        ['left', 'right'].map((id) => {
          const d = document.getElementById(id);
          const r = d.getBoundingClientRect();
          const rowH = d.parentElement.getBoundingClientRect().height;
          return { id, open: d.open, display: getComputedStyle(d).display, left: Math.round(r.left), width: Math.round(r.width), height: Math.round(r.height), spill: d.scrollHeight - d.clientHeight, rowH: Math.round(rowH) };
        }),
      );
    let g = await geo();
    t.check(`${label} 1280: both panels are inline and closed`, g.every((d) => !d.open && d.display === 'flex'), JSON.stringify(g));
    // The start panel is the tall one: the row is as tall as it is, nothing spills out of either box.
    t.check(`${label} 1280: the panels are as tall as the row, none spills`, g.every((d) => d.height === d.rowH && d.spill <= 0) && g[0].height > 400, JSON.stringify(g));
    t.check(
      `${label} 1280: the start panel sits at the start edge, the end panel at the end`,
      rtl ? g[0].left + g[0].width >= 1270 && g[1].left <= 12 : g[0].left <= 12 && g[1].left + g[1].width >= 1270,
      JSON.stringify(g),
    );

    // Esc inside an inline panel does nothing (it is not an open dialog).
    await wide.getByRole('button', { name: 'S1', exact: true }).focus();
    await wide.keyboard.press('Escape');
    g = await geo();
    t.check(`${label} 1280: Esc inside an inline panel leaves it there`, g.every((d) => d.display === 'flex'), JSON.stringify(g));
    // Click works inside the panel, and the page behind is not inert.
    await wide.getByRole('button', { name: 'S2', exact: true }).click();
    t.check(`${label} 1280: a button of the panel takes the click and the focus (WebKit: the click only)`, (await wide.evaluate(() => document.activeElement?.textContent?.trim())) === 'S2' || process.env.E2E_BROWSER === 'webkit');

    // Tab: the panel's controls in the order of the page, no stop on the dialog itself.
    await wide.goto(`${base}/drawer-attacks${rtl ? '-rtl' : ''}.html`);
    const order = [];
    for (let i = 0; i < 16; i++) {
      await wide.keyboard.press(TAB);
      order.push(await wide.evaluate(() => document.activeElement?.id || document.activeElement?.textContent?.trim().slice(0, 8)));
    }
    const expected = ['S0', 'S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8', 'S9', 'S10', 'S11', 'Done S', 'Behind', 'E0'];
    t.check(`${label} 1280: Tab goes through the panels in page order, the dialogs are no stops`, expected.every((x, i) => order[i] === x), order.join(' > '));

    // The accessible name of an inline panel.
    const aria = await wide.locator('body').ariaSnapshot();
    t.check(`${label} 1280: the panels keep their names as dialogs`, /dialog "Start panel"/.test(aria) && /dialog "End panel"/.test(aria), aria.slice(0, 300));

    // Printing: a sidebar is not paper.
    await wide.emulateMedia({ media: 'print' });
    await wide.waitForTimeout(400);
    g = await geo();
    t.check(`${label} print: the panels are not printed`, g.every((d) => d.display === 'none'), JSON.stringify(g));
    await wide.emulateMedia({ media: 'screen' });
    await wide.close();
  }

  // A modal that is open when the window grows past the breakpoint.
  const grow = await t.page({ javaScriptEnabled: js, viewport: { width: 390, height: 800 } });
  await grow.goto(`${base}/drawer-attacks.html`);
  const stateOf = (id) =>
    grow.evaluate((id) => {
      const d = document.getElementById(id);
      return { open: d.open, modal: d.matches(':modal'), display: getComputedStyle(d).display, position: getComputedStyle(d).position };
    }, id);
  await grow.getByRole('button', { name: 'Open end' }).focus();
  await grow.getByRole('button', { name: 'Open end' }).click();
  await grow.waitForTimeout(400);
  let s = await stateOf('right');
  t.check(`${mode} 390: the second drawer opens as its own modal`, s.open && s.modal && (await stateOf('left')).display === 'none', JSON.stringify(s));
  await grow.setViewportSize({ width: 1280, height: 800 });
  await grow.waitForTimeout(500);
  s = await stateOf('right');
  if (js) {
    t.check(`${mode} 390 → 1280: a modal open at the breakpoint closes into the inline panel`, !s.open && !s.modal && s.display === 'flex' && s.position === 'static', JSON.stringify(s));
  } else {
    // No script, no `animationstart` handler: the documented limit.
    t.check(`${mode} 390 → 1280: without JS an open modal stays modal until it is closed`, s.open && s.modal, JSON.stringify(s));
  }
  await grow.setViewportSize({ width: 390, height: 800 });
  await grow.waitForTimeout(400);
  if (js) {
    s = await stateOf('right');
    t.check(`${mode} 1280 → 390: back to a closed drawer that a button can open again`, !s.open && s.display === 'none', JSON.stringify(s));
    await grow.getByRole('button', { name: 'Open start' }).focus();
    await grow.getByRole('button', { name: 'Open start' }).click();
    await grow.waitForTimeout(400);
    t.check(`${mode} 390: and it does open`, (await stateOf('left')).modal);
  }
  await grow.close();

  // --- A Scaffold whose drawers are panels.
  for (const rtl of [false, true]) {
    const label = `${mode}${rtl ? ' RTL' : ''}`;
    const sc = await t.page({ javaScriptEnabled: js, viewport: { width: 390, height: 800 } });
    await sc.goto(`${base}/scaffold-permanent${rtl ? '-rtl' : ''}.html`);
    const lay = () =>
      sc.evaluate(() => {
        const R = (el) => {
          const r = el.getBoundingClientRect();
          return { left: Math.round(r.left), right: Math.round(r.right), top: Math.round(r.top), height: Math.round(r.height), display: getComputedStyle(el).display };
        };
        const buttons = [...document.querySelectorAll('header button')].map((b) => getComputedStyle(b).display);
        return { header: R(document.querySelector('header')), nav: R(document.getElementById('nav')), info: R(document.getElementById('info')), main: R(document.querySelector('main')), footer: R(document.querySelector('footer')), buttons, overflow: document.documentElement.scrollWidth > innerWidth };
      });
    let l = await lay();
    t.check(`${label} 390: no panels, the body takes the width and the menu buttons show`, l.nav.display === 'none' && l.info.display === 'none' && l.main.right - l.main.left > 360 && l.buttons.every((d) => d !== 'none') && !l.overflow, JSON.stringify(l));
    await sc.getByRole('button', { name: 'Open navigation menu' }).focus();
    await sc.getByRole('button', { name: 'Open navigation menu' }).click();
    await sc.waitForTimeout(400);
    t.check(`${label} 390: the app bar button opens the drawer as a modal`, await sc.evaluate(() => document.getElementById('nav').matches(':modal')));
    await sc.keyboard.press('Escape');
    await sc.waitForTimeout(400);

    await sc.setViewportSize({ width: 800, height: 800 });
    l = await lay();
    const nearStart = (r, edge) => (rtl ? r.right >= edge - 12 : r.left <= 12);
    t.check(`${label} 800 (md): the start drawer is a column under the app bar, the body beside it`, l.nav.display === 'flex' && l.info.display === 'none' && l.nav.top === l.header.top + l.header.height && l.nav.top === l.main.top && l.nav.height === l.main.height && (rtl ? l.main.right <= l.nav.left + 1 : l.main.left >= l.nav.right - 1) && nearStart(l.nav, 800), JSON.stringify(l));
    t.check(`${label} 800 (md): the app bar spans the page and loses the start menu button`, l.header.right - l.header.left > 770 && l.buttons.filter((d) => d === 'none').length === 1 && !l.overflow, JSON.stringify(l));

    await sc.setViewportSize({ width: 1280, height: 800 });
    l = await lay();
    t.check(`${label} 1280 (lg): the end drawer is the last column, the body in the middle`, l.nav.display === 'flex' && l.info.display === 'flex' && l.main.height === l.nav.height && l.main.height === l.info.height && (rtl ? l.info.right <= l.main.left + 1 && l.main.right <= l.nav.left + 1 : l.nav.right <= l.main.left + 1 && l.main.right <= l.info.left + 1), JSON.stringify(l));
    t.check(`${label} 1280 (lg): both menu buttons are gone`, l.buttons.every((d) => d === 'none') && !l.overflow, JSON.stringify(l));
    t.check(`${label} 1280 (lg): the footer sits under the three columns`, l.footer.top >= l.main.top + l.main.height - 1, JSON.stringify(l));
    await sc.close();
  }
}

// Two adaptive layout widgets of a store in a real browser (Chromium; E2E_BROWSER=firefox|webkit for the others):
//  - Drawer(permanentWidth:, permanentPadding:): a 320 px modal on a phone and a
//    200 px inline panel with its own padding on a desktop;
//  - ExpansionTile(permanentFrom: md): an accordion on a phone (closed, its
//    content hidden, it opens on a tap) and an open block on a desktop (content
//    visible while the tile is closed, the header is no control), with and
//    without JS; a tile without permanentFrom stays an accordion everywhere.
//
//   tool/thor e2e store-gaps                (renders the page, serves, runs)
//   node test/e2e/checks/store_gaps_check.mjs
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { closeServer, e2e, repo, serveStatic } from './lib/e2e.mjs';

const dir = mkdtempSync(join(tmpdir(), 'thor-store-gaps-'));
let server;

await e2e('store-gaps', { site: null }, async (t) => {
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

    // --- The drawer.
    const desk = await t.page({ javaScriptEnabled: js, viewport: { width: 1280, height: 800 } });
    await desk.goto(`${base}/store-gaps.html`);
    const panel = await desk.evaluate(() => {
      const d = document.getElementById('side');
      const cs = getComputedStyle(d);
      return { w: d.getBoundingClientRect().width, pl: cs.paddingLeft, pt: cs.paddingTop, open: d.open };
    });
    t.check(`${mode} desktop: the inline panel is 200 px wide`, panel.w === 200, JSON.stringify(panel));
    t.check(`${mode} desktop: its own padding`, panel.pl === '4px' && panel.pt === '12px', JSON.stringify(panel));

    const phone = await t.page({ javaScriptEnabled: js, viewport: { width: 390, height: 800 } });
    await phone.goto(`${base}/store-gaps.html`);
    if (js) {
      await phone.getByRole('button', { name: 'Open side' }).click();
      await phone.waitForFunction(() => document.getElementById('side').open);
      const modal = await phone.evaluate(() => {
        const d = document.getElementById('side');
        return { w: d.getBoundingClientRect().width, pl: getComputedStyle(d).paddingLeft };
      });
      // min(320px, 85vw) at 390 px is 320.
      t.check('phone: the modal is 320 px with the 16 px padding', modal.w === 320 && modal.pl === '16px', JSON.stringify(modal));
      await phone.keyboard.press('Escape');
      await phone.waitForFunction(() => !document.getElementById('side').open);
    }

    // --- The tiles.
    const state = (page, key) =>
      page.evaluate((key) => {
        const tiles = [...document.querySelectorAll('details')];
        const d = tiles.find((x) => x.querySelector('summary').textContent.trim() === key);
        const body = [...d.querySelectorAll('div')].find((e) => e.textContent.trim() && !e.children.length);
        const s = d.querySelector('summary');
        return {
          open: d.open,
          visible: body.checkVisibility(),
          pointer: getComputedStyle(s).pointerEvents,
          chevron: getComputedStyle(s, '::after').display,
        };
      }, key);

    let help = await state(desk, 'Help');
    t.check(`${mode} desktop: Help shows its content while closed`, !help.open && help.visible, JSON.stringify(help));
    t.check(`${mode} desktop: Help's header is no control`, help.pointer === 'none' && help.chevron === 'none', JSON.stringify(help));
    let plain = await state(desk, 'Plain');
    t.check(`${mode} desktop: Plain is an accordion`, !plain.open && !plain.visible && plain.pointer !== 'none', JSON.stringify(plain));

    // --- The header out of the Tab order (needs the page's small script; a no-JS visitor keeps the stop).
    const tabbable = async (page) => {
      // Tabs through the page and says which summaries took the focus.
      await page.evaluate(() => document.activeElement?.blur());
      const seen = new Set();
      // Forward and back: a browser starts from where the focus last was.
      for (let i = 0; i < 50; i++) {
        await page.keyboard.press(i < 25 ? 'Tab' : 'Shift+Tab');
        const name = await page.evaluate(() => (document.activeElement?.tagName === 'SUMMARY' ? document.activeElement.textContent.trim() : ''));
        if (name) seen.add(name);
      }
      return [...seen].sort().join();
    };
    const supported = await desk.evaluate(() => CSS.supports('selector(::details-content)'));
    if (js && supported) {
      t.check('desktop: Help\'s header is out of the Tab order', (await desk.evaluate(() => document.querySelector('details[data-thor-pf] > summary').getAttribute('tabindex'))) === '-1');
      t.check('desktop: Tab reaches the Plain tile\'s header, not Help\'s', (await tabbable(desk)) === 'Plain', await tabbable(desk));
      t.check('phone: Tab reaches Help\'s header (an accordion)', (await tabbable(phone)).split(',').includes('Help'));
      // The viewport crosses the breakpoint: the script follows the media query.
      // One pixel under the tile's own breakpoint (read from the page, so a new
      // breakpoint value does not leave the check on the wrong side of it).
      const from = await desk.evaluate(() => Number(document.querySelector('details[data-thor-pf]').getAttribute('data-thor-pf')));
      await desk.setViewportSize({ width: from - 1, height: 800 });
      await desk.waitForFunction(() => !document.querySelector('details[data-thor-pf] > summary').hasAttribute('tabindex'));
      const again = await tabbable(desk);
      t.check('below the breakpoint Help\'s header is a Tab stop again', again.split(',').includes('Help'), again);
      await desk.setViewportSize({ width: 1280, height: 800 });
      await desk.waitForFunction(() => document.querySelector('details[data-thor-pf] > summary').getAttribute('tabindex') === '-1');
      t.check('and out of it again from the breakpoint', !(await tabbable(desk)).split(',').includes('Help'));
    } else if (!js) {
      // Without JavaScript, CSS alone can not take it out of the Tab order (documented).
      t.check('without JS the header stays a Tab stop (documented)', (await tabbable(desk)).split(',').includes('Help'));
    }

    help = await state(phone, 'Help');
    t.check(`${mode} phone: Help is a closed accordion`, !help.open && !help.visible && help.pointer !== 'none', JSON.stringify(help));
    await phone.getByText('Help', { exact: true }).click();
    // The content grows in 200 ms (ExpansionTile's transition): probe after it.
    await phone.waitForTimeout(300);
    help = await state(phone, 'Help');
    t.check(`${mode} phone: Help opens on a tap`, help.open && help.visible, JSON.stringify(help));
  }
}

// The snack bar above modals in a real browser: `toast(…)` from a
// drawer item, from a dialog or with the confirm open shows ON TOP of the
// modal (Flutter's ScaffoldMessenger draws over routes). The bar is a
// `popover="manual"` (the top layer) and, while a modal <dialog> is open,
// lives inside it so the rest of the page being inert does not take it from
// the screen reader; it goes home when that dialog closes. Also: a flood of
// toasts, stacking with drawer + confirm, Esc, RTL, reduced motion, and the
// page with no JS.
//
//   tool/thor e2e toast-modal                   (renders the page, serves, runs)
//   node test/e2e/checks/toast_modal_check.mjs
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { closeServer, e2e, repo, serveStatic } from './lib/e2e.mjs';

const dir = mkdtempSync(join(tmpdir(), 'thor-toast-'));
let server;

await e2e('toast-modal', { site: null }, async (t) => {
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
  const url = `http://127.0.0.1:${server.address().port}/toast.html`;

  // What the eye and the pointer find at the bar's center.
  const bar = (page) =>
    page.evaluate(() => {
      const b = document.getElementById('thor-toast');
      const r = b.getBoundingClientRect();
      const cs = getComputedStyle(b);
      const hit = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2);
      return {
        shown: cs.visibility === 'visible' && Number(cs.opacity) > 0.9 && r.width > 0,
        onTop: !!hit && (hit === b || b.contains(hit)),
        hit: hit ? `${hit.tagName}#${hit.id}` : null,
        text: b.textContent,
        open: b.matches(':popover-open'),
        parent: `${b.parentElement.tagName}#${b.parentElement.id}`,
        cx: r.left + r.width / 2,
        bottom: r.bottom,
      };
    });
  const toast = (page, m, kind = 'info', ms) => page.evaluate(([m, k, ms]) => document.thorToast(m, k, ms), [m, kind, ms]);
  const settle = (page) => page.waitForTimeout(350);
  const open = (page, id) => page.evaluate((id) => document.getElementById(id)?.open, id);
  const drawerButton = (page) => page.getByRole('button', { name: 'Open navigation menu' });

  const load = async (options = {}) => {
    const page = await t.page({ viewport: { width: 900, height: 600 }, ...options });
    // The page has no app behind it: an empty engine, or its loader reloads.
    await page.route('**/engine.dart.js', (r) => r.fulfill({ contentType: 'text/javascript', body: '' }));
    await page.goto(url);
    return page;
  };
  const errors = (page) => page.problems.filter((p) => !/Failed to load resource/.test(p));

  // 1. No modal: the bar is where it always was.
  {
    const page = await load();
    await toast(page, 'Hello');
    await settle(page);
    const b = await bar(page);
    t.check('no modal: the toast shows, on top', b.shown && b.onTop && b.text === 'Hello', JSON.stringify(b));
    t.check('no modal: it is a popover in the top layer, in the page', b.open && b.parent.startsWith('BODY'), JSON.stringify(b));
    await page.context().close();
  }

  // 2. A drawer item toasts while the drawer (a modal) is open.
  {
    const page = await load();
    await drawerButton(page).click();
    await page.waitForTimeout(400);
    await toast(page, 'Abriste Ajustes');
    await settle(page);
    const b = await bar(page);
    t.check('drawer open: the toast shows ABOVE the drawer and its backdrop', b.shown && b.onTop && b.text === 'Abriste Ajustes', JSON.stringify(b));
    t.check('drawer open: the bar sits inside the open dialog (reachable, read by a screen reader)', b.parent.startsWith('DIALOG'), JSON.stringify(b));
    // Esc closes the drawer (the first one), the toast stays and goes home.
    await page.keyboard.press('Escape');
    await settle(page);
    const a = await bar(page);
    t.check('Esc closes the drawer, not the toast', !(await page.evaluate(() => [...document.querySelectorAll('dialog')].some((d) => d.open))), JSON.stringify(a));
    t.check('after the drawer closes the toast is still shown, back in the page, on top', a.shown && a.onTop && a.text === 'Abriste Ajustes' && a.parent.startsWith('BODY'), JSON.stringify(a));
    t.check('no page errors', errors(page).length === 0, errors(page).join(' | '));
    await page.context().close();
  }

  // 3. A drawer item that closes the drawer AND toasts (the click of a
  // DialogClose around a tile whose handler toasts): the toast survives.
  {
    const page = await load();
    await drawerButton(page).click();
    await page.waitForTimeout(400);
    await page.evaluate(() => {
      // What the engine does on the click, in the same task as the native close.
      const item = [...document.querySelectorAll('dialog button')].find((b) => b.textContent.includes('Settings'));
      item.addEventListener('click', () => document.thorToast('Saved', 'success'));
      item.click();
    });
    await settle(page);
    await page.waitForTimeout(300);
    const b = await bar(page);
    const opened = await page.evaluate(() => [...document.querySelectorAll('dialog')].some((d) => d.open));
    t.check('a tile that closes the drawer and toasts: the drawer closes', !opened);
    t.check('... and the toast stays visible on top', b.shown && b.onTop && b.text === 'Saved' && b.parent.startsWith('BODY'), JSON.stringify(b));
    await page.context().close();
  }

  // 4. The confirm dialog open, and a toast while it asks.
  {
    const page = await load();
    await page.evaluate(() => {
      window.answer = document.thorConfirm('Delete?', 'No undo', 'Delete', 'Cancel');
    });
    await page.waitForTimeout(300);
    await toast(page, 'Behind the question?');
    await settle(page);
    const b = await bar(page);
    t.check('confirm open: the toast shows above it', b.shown && b.onTop && b.parent.startsWith('DIALOG'), JSON.stringify(b));
    await page.getByRole('dialog').getByRole('button', { name: 'Cancel' }).click();
    const res = await page.evaluate(() => window.answer);
    t.check('the confirm still answers no', res === false, String(res));
    await settle(page);
    const a = await bar(page);
    t.check('the toast outlives the confirm, back in the page', a.shown && a.onTop && a.parent.startsWith('BODY'), JSON.stringify(a));
    await page.context().close();
  }

  // 5. Stacking: the drawer, the confirm over it, and a toast over both.
  {
    const page = await load();
    await drawerButton(page).click();
    await page.waitForTimeout(400);
    await page.evaluate(() => {
      window.answer = document.thorConfirm('Sure?');
    });
    await page.waitForTimeout(300);
    await toast(page, 'Top of everything', 'error');
    await settle(page);
    const b = await bar(page);
    t.check('drawer + confirm + toast: the toast is over both', b.shown && b.onTop && b.text === 'Top of everything', JSON.stringify(b));
    await page.keyboard.press('Escape');
    const res = await page.evaluate(() => window.answer);
    t.check('Esc answers the confirm (no) and leaves the drawer', res === false && (await open(page, await drawerButton(page).getAttribute('commandfor'))) === true);
    await settle(page);
    const a = await bar(page);
    t.check('the toast moved to the drawer still open, still on top', a.shown && a.onTop && a.parent.startsWith('DIALOG'), JSON.stringify(a));
    await page.context().close();
  }

  // 6. A flood with the drawer open: one bar, the newest, on top.
  {
    const page = await load();
    await drawerButton(page).click();
    await page.waitForTimeout(400);
    await page.evaluate(() => {
      for (let i = 0; i < 40; i++) document.thorToast(`n${i}`, i % 2 ? 'info' : 'error', 600);
    });
    await settle(page);
    const count = await page.evaluate(() => document.querySelectorAll('#thor-toast').length);
    const first = await bar(page);
    t.check('flood: there is one bar and it shows on top', count === 1 && first.shown && first.onTop, JSON.stringify(first));
    // Each waits its turn: the ones that are left are the first shown plus the newest three.
    const seen = new Set([first.text]);
    for (let i = 0; i < 12; i++) {
      await page.waitForTimeout(400);
      const b = await bar(page);
      if (b.shown) seen.add(b.text);
      if (b.shown && !b.onTop) seen.add('HIDDEN:' + b.text);
    }
    t.check('flood: every toast that was shown was on top, and the newest three came', !([...seen].some((s) => s.startsWith('HIDDEN'))) && seen.has('n39'), [...seen].join());
    t.check('flood: no page errors', errors(page).length === 0, errors(page).join(' | '));
    await page.context().close();
  }

  // 7. A dialog the app wrote, with its own id.
  {
    const page = await load();
    await page.getByRole('button', { name: 'Open mine' }).click();
    await toast(page, 'From a dialog');
    await settle(page);
    const b = await bar(page);
    t.check('own dialog open: the toast shows above it', b.shown && b.onTop, JSON.stringify(b));
    await page.context().close();
  }

  // 8. RTL: centered by physical edges, not mirrored off the screen.
  {
    const page = await load();
    await page.evaluate(() => (document.documentElement.dir = 'rtl'));
    await drawerButton(page).click();
    await page.waitForTimeout(400);
    await toast(page, 'Rtl');
    await settle(page);
    const b = await bar(page);
    t.check('RTL: centered, on top', b.shown && b.onTop && Math.abs(b.cx - 450) <= 2, JSON.stringify(b));
    await page.context().close();
  }

  // 9. Reduced motion: it still hides after its time, no slide.
  {
    const page = await load({ reducedMotion: 'reduce' });
    await drawerButton(page).click();
    await page.waitForTimeout(300);
    await toast(page, 'Brief', 'info', 500);
    await page.waitForTimeout(100);
    const b = await bar(page);
    t.check('reduced motion: shows on top', b.shown && b.onTop, JSON.stringify(b));
    await page.waitForTimeout(1500);
    const a = await bar(page);
    t.check('reduced motion: and hides itself after its time', !a.shown, JSON.stringify(a));
    await page.context().close();
  }

  // 10. No JS: the bar is the markup the server wrote, not a popover in the
  // top layer, and a server flash (here simulated by its attribute) still shows.
  {
    const page = await load({ javaScriptEnabled: false });
    const before = await bar(page);
    t.check('no JS: nothing shows and nothing opened a popover', !before.shown && !before.open, JSON.stringify(before));
    await page.evaluate(() => {
      const b = document.getElementById('thor-toast');
      b.className = document.getElementById('thor-toast-kinds').content.querySelector('[data-k=info]').className;
      b.textContent = 'Flash';
      b.setAttribute('data-t-on', '');
    });
    await page.waitForTimeout(350);
    const f = await bar(page);
    t.check('no JS: a flash the server wrote shows as before, at the bottom', f.shown && f.onTop && f.text === 'Flash' && f.bottom > 500 && !f.open, JSON.stringify(f));
    await page.context().close();
  }

  // 11. A toast already showing when a modal opens (no new toast call): it
  // must go over the modal, not stay under its backdrop.
  {
    const page = await load();
    await toast(page, 'Before', 'info', 3000);
    await settle(page);
    await drawerButton(page).click();
    await page.waitForTimeout(400);
    const b = await bar(page);
    t.check('a toast showing when the drawer opens ends up over it', b.shown && b.onTop && b.parent.startsWith('DIALOG'), JSON.stringify(b));
    await page.context().close();
  }

  // 12. Moving the bar does not restart its time: it hides when it was going to.
  {
    const page = await load();
    await toast(page, 'Timed', 'info', 1200);
    await page.waitForTimeout(800);
    await drawerButton(page).click();
    // 800 ms in, 1200 + 200 total: gone by ~1.6 s from the start, not ~2.6 s.
    await page.waitForTimeout(1100);
    const b = await bar(page);
    t.check('opening a modal does not restart the toast time', !b.shown, JSON.stringify(b));
    await page.context().close();
  }

  // 13. A transformed dialog does not take the bar's fixed box with it.
  {
    const page = await load();
    await drawerButton(page).click();
    await page.waitForTimeout(400);
    await page.evaluate(() => {
      for (const d of document.querySelectorAll('dialog[open]')) d.style.transform = 'translateX(10px) scale(0.9)';
    });
    await toast(page, 'Fixed');
    await settle(page);
    const b = await bar(page);
    t.check('transformed dialog: the bar sits at the viewport bottom center', b.shown && b.onTop && b.bottom > 560 && Math.abs(b.cx - 450) <= 2, JSON.stringify(b));
    await page.context().close();
  }

  // 14. A browser without popovers keeps the old fixed bar, no errors.
  {
    const page = await t.page({ viewport: { width: 900, height: 600 } });
    await page.addInitScript(() => delete HTMLElement.prototype.showPopover);
    await page.route('**/engine.dart.js', (r) => r.fulfill({ contentType: 'text/javascript', body: '' }));
    await page.goto(url);
    await drawerButton(page).click();
    await page.waitForTimeout(400);
    await toast(page, 'Old browser');
    await settle(page);
    const b = await bar(page);
    t.check('no popover support: the bar still shows (under the modal, as before), no errors', b.shown && b.text === 'Old browser' && b.parent.startsWith('BODY') && errors(page).length === 0, JSON.stringify(b) + errors(page).join());
    await page.context().close();
  }
}

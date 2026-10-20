// The visitor's light/dark choice in a real browser: chosen once, it holds
// across reloads and navigation with no flash of the other theme (the
// computed color at the first `DOMContentLoaded`, and a screenshot of the
// first frame), the system's preference rules while nothing is chosen,
// blocked storage raises no error, and with no JS the switch works per view.
//
//   tool/thor e2e theme-persist                (renders the pages, serves, runs)
//   node test/e2e/checks/theme_persist_check.mjs
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { closeServer, e2e, repo, serveStatic } from './lib/e2e.mjs';

const dir = mkdtempSync(join(tmpdir(), 'thor-theme-'));
let server;

await e2e('theme-persist', { site: null }, async (t) => {
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
  const origin = `http://127.0.0.1:${server.address().port}`;
  const url = (n) => `${origin}/${n}.html`;

  const scheme = (page) => page.evaluate(() => getComputedStyle(document.documentElement).colorScheme);
  const bg = (page) => page.evaluate(() => getComputedStyle(document.body).backgroundColor);
  // The scheme at the first DOMContentLoaded: registered before the page's own scripts ran.
  const early = (ctx) =>
    ctx.addInitScript(() => {
      document.addEventListener('DOMContentLoaded', () => {
        window.__early = getComputedStyle(document.documentElement).colorScheme;
      });
    });

  for (const system of ['light', 'dark']) {
    const other = system === 'light' ? 'dark' : 'light';
    const ctxOptions = { colorScheme: system, viewport: { width: 500, height: 400 } };

    // No choice: the system rules.
    const page = await t.page(ctxOptions);
    await early(page.context());
    await page.goto(url('theme'));
    t.check(`system ${system}: no choice follows the system`, (await scheme(page)) === system, await scheme(page));
    t.check(`system ${system}: nothing stored`, (await page.evaluate(() => localStorage.getItem('thor:theme'))) === null);

    // Choose the other scheme with the toggle.
    await page.click('label[for=thor-theme]');
    t.check(`system ${system}: the toggle flips`, (await scheme(page)) === other, await scheme(page));
    t.check(
      `system ${system}: the choice is stored`,
      (await page.evaluate(() => localStorage.getItem('thor:theme'))) === other,
    );

    // Reload: the choice holds, already at DOMContentLoaded (no flash).
    await page.reload();
    t.check(`system ${system}: reload keeps ${other}`, (await scheme(page)) === other, await scheme(page));
    t.check(
      `system ${system}: ${other} at the first DOMContentLoaded`,
      (await page.evaluate(() => window.__early)) === other,
      await page.evaluate(() => window.__early),
    );

    // Navigate to another page: same.
    await page.click('text=Next page');
    await page.waitForURL(url('theme2'));
    t.check(`system ${system}: navigation keeps ${other}`, (await scheme(page)) === other);
    t.check(`system ${system}: ${other} at DOMContentLoaded after navigating`, (await page.evaluate(() => window.__early)) === other);
    t.check(
      `system ${system}: the switch is checked only when it differs from the system`,
      (await page.evaluate(() => document.getElementById('thor-theme').checked)) === true,
    );

    // Back to the system's scheme by toggling again: stored as the system's.
    await page.click('label[for=thor-theme]');
    t.check(`system ${system}: toggling back returns to ${system}`, (await scheme(page)) === system);
    await page.reload();
    t.check(`system ${system}: reload keeps the explicit ${system}`, (await scheme(page)) === system);
    t.check(
      `system ${system}: unchecked switch while it matches the system`,
      (await page.evaluate(() => document.getElementById('thor-theme').checked)) === false,
    );
    await page.context().close();
  }

  // The color painted at the first DOMContentLoaded is already the stored theme's.
  {
    const ctx = await t.browser.newContext({ colorScheme: 'light' });
    await ctx.addInitScript(() => {
      try {
        localStorage.setItem('thor:theme', 'dark');
      } catch {}
      document.addEventListener('DOMContentLoaded', () => {
        window.__bg = getComputedStyle(document.body).backgroundColor;
      });
    });
    const page = await ctx.newPage();
    await page.goto(url('theme'));
    const early = await page.evaluate(() => window.__bg);
    t.check('the body color at DOMContentLoaded is the dark one', early !== 'rgb(255, 255, 255)' && early === (await bg(page)), early);
    await ctx.close();
  }

  // Storage blocked: no error, the switch still flips for the view.
  {
    const ctx = await t.browser.newContext({ colorScheme: 'light' });
    await ctx.addInitScript(() => {
      const block = () => {
        throw new DOMException('blocked', 'SecurityError');
      };
      Object.defineProperty(window, 'localStorage', { get: block });
    });
    const page = await ctx.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(String(e)));
    page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
    await page.goto(url('theme'));
    await page.click('label[for=thor-theme]');
    t.check('blocked storage: the switch still flips', (await scheme(page)) === 'dark');
    await page.reload();
    t.check('blocked storage: reload starts from the system', (await scheme(page)) === 'light');
    t.check('blocked storage: no error', errors.length === 0, errors.join('; '));
    await ctx.close();
  }

  // A value that is not ours in storage is ignored.
  {
    const ctx = await t.browser.newContext({ colorScheme: 'light' });
    await ctx.addInitScript(() => localStorage.setItem('thor:theme', '<b>sepia</b>'));
    const page = await ctx.newPage();
    await page.goto(url('theme'));
    t.check('a foreign stored value is ignored', (await scheme(page)) === 'light');
    await ctx.close();
  }


  // A system preference that changes while a choice is stored: the choice wins.
  {
    const ctx = await t.browser.newContext({ colorScheme: 'light' });
    await ctx.addInitScript(() => {
      try {
        if (!localStorage.getItem('thor:theme')) localStorage.setItem('thor:theme', 'dark');
      } catch {}
    });
    const page = await ctx.newPage();
    await page.goto(url('theme'));
    t.check('stored dark over a light system', (await scheme(page)) === 'dark');
    await page.emulateMedia({ colorScheme: 'dark' });
    await page.waitForTimeout(300);
    t.check('the system turns dark: the stored dark stays', (await scheme(page)) === 'dark', await scheme(page));
    await page.emulateMedia({ colorScheme: 'light' });
    await page.waitForTimeout(300);
    t.check('the system turns light again: still dark', (await scheme(page)) === 'dark', await scheme(page));
    await ctx.close();
  }

  // Two tabs of one origin: a choice in one reaches the other, no reload.
  {
    const ctx = await t.browser.newContext({ colorScheme: 'light' });
    const a = await ctx.newPage();
    const b = await ctx.newPage();
    await a.goto(url('theme'));
    await b.goto(url('theme2'));
    await a.click('label[for=thor-theme]');
    await b.waitForFunction(() => getComputedStyle(document.documentElement).colorScheme === 'dark', null, { timeout: 3000 }).catch(() => {});
    t.check('another tab follows the choice', (await scheme(b)) === 'dark', await scheme(b));
    await a.click('label[for=thor-theme]');
    await b.waitForFunction(() => getComputedStyle(document.documentElement).colorScheme === 'light', null, { timeout: 3000 }).catch(() => {});
    t.check('and the choice back', (await scheme(b)) === 'light', await scheme(b));
    // Storage cleared elsewhere: back to the system.
    await a.click('label[for=thor-theme]');
    await b.waitForFunction(() => getComputedStyle(document.documentElement).colorScheme === 'dark', null, { timeout: 3000 }).catch(() => {});
    await a.evaluate(() => localStorage.clear());
    await b.waitForFunction(() => getComputedStyle(document.documentElement).colorScheme === 'light', null, { timeout: 3000 }).catch(() => {});
    t.check('storage cleared in another tab: the system rules again', (await scheme(b)) === 'light', await scheme(b));
    await ctx.close();
  }

  // Every frame before the first paint settles already shows the stored scheme (sampled at
  // each animation frame from document start; `normal` is before any stylesheet).
  for (const [system, stored] of [['light', 'dark'], ['dark', 'light']]) {
    const ctx = await t.browser.newContext({ colorScheme: system });
    await ctx.addInitScript((stored) => {
      try {
        localStorage.setItem('thor:theme', stored);
      } catch {}
      window.__samples = [];
      const sample = (src) => {
        const b = document.body;
        window.__samples.push([typeof src === 'string' ? src : 'rs', getComputedStyle(document.documentElement).colorScheme, b ? getComputedStyle(b).backgroundColor : null]);
      };
      const frame = () => {
        sample('raf');
        if (document.readyState !== 'complete' || window.__samples.length < 3) requestAnimationFrame(frame);
      };
      requestAnimationFrame(frame);
          }, stored);
    const page = await ctx.newPage();
    await page.goto(url('theme'));
    // A frame after load too (some engines finish a small page before their first frame).
    await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
    const samples = (await page.evaluate(() => window.__samples)).filter(([src]) => src === 'raf');
    const wrong = samples.filter(([, c]) => c !== 'normal' && c !== stored);
    t.check(`no frame shows ${system} before ${stored} (${samples.length} samples)`, samples.length > 0 && wrong.length === 0, JSON.stringify(wrong.slice(0, 3)));
    await ctx.close();
  }

  // No JS: the switch works for the view, as before.
  {
    const page = await t.page({ javaScriptEnabled: false, colorScheme: 'light' });
    await page.goto(url('theme'));
    await page.click('label[for=thor-theme]');
    t.check('no JS: the switch flips for the view', (await scheme(page)) === 'dark');
    await page.context().close();
  }
}

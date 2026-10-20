// The Material buttons in a real browser: every kind takes a visible
// focus ring from the keyboard, a disabled one is out of the tab order and
// does not click, an `IconButton(href:)` is a named link that Enter follows,
// an icon that Flutter mirrors flips in right-to-left text (and `add` does
// not), a long extended FAB wraps at 320 px, the pressed and disabled looks
// exist, reduced motion stops the transitions and the dark mode repaints
// them from the theme's tokens. The page is rendered by the real widgets
// (packages/thor_ui/tool/material_buttons_page.dart).
//
//   tool/thor e2e material-buttons              (renders, serves, runs)
//   node test/e2e/checks/material_buttons_check.mjs
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { closeServer, e2e, repo, serveStatic, tabKey } from './lib/e2e.mjs';

const dir = mkdtempSync(join(tmpdir(), 'material-buttons-'));
let server;
try {
  execFileSync('dart', ['run', 'tool/material_buttons_page.dart', join(dir, 'index.html')], {
    cwd: join(repo, 'packages/thor_ui'),
    stdio: 'inherit',
  });
  writeFileSync(join(dir, 'target.html'), '<!doctype html><title>target</title><p>target');
  server = await serveStatic(dir);
  const base = `http://127.0.0.1:${server.address().port}/`;

  await e2e('material-buttons', { site: null }, async (t) => {
    const page = await t.page({ colorScheme: 'light', javaScriptEnabled: false });
    const ok = (label, cond, detail) => t.check(label, cond, detail);
    await page.goto(base);

    // Right-to-left: the icons Flutter mirrors flip, the others don't.
    const transforms = () =>
      page.evaluate(() =>
        [...document.querySelectorAll('#rtl-icons > svg')].map((s) => getComputedStyle(s).transform),
      );
    const ltr = await transforms();
    ok('ltr: no icon is flipped', ltr.every((x) => x === 'none'), ltr.join(' | '));
    await page.evaluate(() => (document.documentElement.dir = 'rtl'));
    const rtl = await transforms();
    ok('rtl: arrow_back, send and arrow_back_ios flip', [0, 2, 3].every((i) => rtl[i] === 'matrix(-1, 0, 0, 1, 0, 0)'), rtl.join(' | '));
    ok('rtl: add does not flip', rtl[1] === 'none', rtl[1]);
    await page.evaluate(() => (document.documentElement.dir = 'ltr'));

    // Keyboard: every enabled control shows a focus ring, disabled ones are skipped.
    const enabled = await page.evaluate(
      () => [...document.querySelectorAll('button:not(:disabled), a[href]')].length,
    );
    const disabled = await page.evaluate(() => document.querySelectorAll('button:disabled').length);
    ok('the page has 19 enabled controls and 9 disabled', enabled === 19 && disabled === 9, `${enabled}/${disabled}`);
    await page.evaluate(() => document.body.focus());
    const rings = [];
    for (let i = 0; i < enabled; i++) {
      await page.keyboard.press(tabKey());
      rings.push(
        await page.evaluate(() => {
          const e = document.activeElement;
          const s = getComputedStyle(e);
          return {
            name: e.getAttribute('aria-label') ?? e.textContent,
            disabled: e.disabled === true,
            ring: s.outlineStyle !== 'none' && parseFloat(s.outlineWidth) > 0,
          };
        }),
      );
    }
    ok('Tab visits every enabled control', new Set(rings.map((r) => r.name)).size === enabled, JSON.stringify(rings.map((r) => r.name)));
    ok('never a disabled control', rings.every((r) => !r.disabled));
    const bare = rings.filter((r) => !r.ring).map((r) => r.name);
    ok('every kind shows a focus ring', bare.length === 0, bare.join(', '));

    // Disabled: not clickable, dimmed, no pointer cursor.
    const dis = await page.evaluate(() =>
      [...document.querySelectorAll('button:disabled')].map((b) => {
        const s = getComputedStyle(b);
        return { name: b.getAttribute('aria-label') ?? b.textContent, opacity: s.opacity, cursor: s.cursor };
      }),
    );
    const flat = dis.filter((d) => d.cursor === 'pointer');
    ok('a disabled button has no pointer cursor', flat.length === 0, flat.map((d) => d.name).join(', '));
    // Elevated/Filled/Tonal/Outlined/Text/FAB/Icon are all visibly disabled.
    const solid = dis.filter((d) => d.opacity === '1' && !/text|elevated|filled|tonal|outlined/i.test(d.name) === false);
    ok('a disabled button looks disabled', dis.every((d) => d.opacity !== '1' || d.name.startsWith('D ')), JSON.stringify(solid));
    const clicked = await page
      .locator('button:disabled')
      .first()
      .click({ timeout: 500, trial: true })
      .then(() => true, () => false);
    ok('a disabled button cannot be clicked', !clicked);

    // The pressed look of every kind: the background changes while :active.
    const pressed = [];
    for (const name of ['Icon plain', 'Icon filled', 'Icon tonal', 'Icon outlined', 'Filled', 'Tonal', 'Elevated', 'Outlined', 'Text', 'FAB']) {
      const b = page.locator(`button[aria-label="${name}"], button:text-is("${name}")`).first();
      const box = await b.boundingBox();
      await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
      await page.waitForTimeout(250);
      const hover = await b.evaluate((e) => getComputedStyle(e).backgroundColor);
      await page.mouse.down();
      await page.waitForTimeout(250);
      const down = await b.evaluate((e) => getComputedStyle(e).backgroundColor);
      await page.mouse.up();
      await page.mouse.move(0, 0);
      if (hover === down) pressed.push(name);
    }
    ok('every kind changes from hover to pressed', pressed.length === 0, pressed.join(', '));

    // The link: a named <a> that Enter follows.
    const link = page.getByRole('link', { name: 'Icon link' });
    ok('IconButton(href:) is a link named by its tooltip', (await link.count()) === 1);
    await link.focus();
    await Promise.all([page.waitForURL('**/target'), page.keyboard.press('Enter')]);
    ok('Enter follows the icon link', page.url().endsWith('/target'), page.url());

    // 320 px: a long extended FAB wraps and nothing overflows.
    const narrow = await t.page({ viewport: { width: 320, height: 800 }, javaScriptEnabled: false });
    await narrow.goto(base);
    const over = await narrow.evaluate(() => {
      const fab = [...document.querySelectorAll('button')].find((b) => b.textContent.startsWith('FAB extended'));
      const r = fab.getBoundingClientRect();
      return {
        doc: document.documentElement.scrollWidth - document.documentElement.clientWidth,
        right: r.right,
        lines: fab.scrollWidth - fab.clientWidth,
        height: r.height,
      };
    });
    ok('320 px: no horizontal scroll', over.doc <= 0, JSON.stringify(over));
    ok('320 px: the extended FAB stays inside the viewport and wraps', over.right <= 320 && over.height > 56 && over.lines <= 0, JSON.stringify(over));

    // Reduced motion.
    const calm = await t.page({ reducedMotion: 'reduce', javaScriptEnabled: false });
    await calm.goto(base);
    const slow = await calm.evaluate(() =>
      [...document.querySelectorAll('button:not(:disabled), a[href]')]
        .filter((e) => getComputedStyle(e).transitionDuration.split(',').some((d) => parseFloat(d) > 0.01))
        .map((e) => e.getAttribute('aria-label') ?? e.textContent),
    );
    ok('reduced motion: no transition lasts more than 10 ms', slow.length === 0, slow.join(', '));

    // Dark mode: the fills follow the theme's tokens.
    const fills = async (p) =>
      p.evaluate(() => {
        const bg = (sel) => getComputedStyle(document.querySelector(sel)).backgroundColor;
        return [
          bg('button[aria-label="Icon filled"]'),
          bg('button[aria-label="Icon tonal"]'),
          bg('button[aria-label="FAB"]'),
          bg('button:not(:disabled)[data-thor="FilledButton"]'),
        ];
      });
    await page.goto(base);
    const light = await fills(page);
    const dark = await t.page({ colorScheme: 'dark', javaScriptEnabled: false });
    await dark.goto(base);
    const night = await fills(dark);
    ok('dark: every fill changes with the theme', night.every((c, i) => c !== light[i]), `${light} -> ${night}`);
    ok('dark: the filled ones are the dark primary', night[0] === 'rgb(208, 188, 255)' && night[3] === 'rgb(208, 188, 255)', night.join(' | '));
    for (const p of [page, narrow, calm, dark]) ok('no page errors', p.problems.length === 0, p.problems.join(' | '));
  });
} finally {
  await closeServer(server);
  rmSync(dir, { recursive: true, force: true });
}

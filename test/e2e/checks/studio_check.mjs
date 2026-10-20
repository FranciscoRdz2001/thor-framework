// Checks a page built with thor_studio in a real browser, with and without
// JavaScript: layout (no horizontal scroll, panels in place and sticky),
// the phone navigation drawer, anchors below the sticky bar, the search
// form, the self-hosted fonts and a clean console. In light and in dark
// (the system's, then the switch's, with no flash on load): the computed
// contrast of every text and icon on the page, AA (4.5:1 text, 3:1 icons and
// large text).
//
//   tool/thor e2e studio                        (builds test/fixtures/apps/studio_gallery, runs)
//   node test/e2e/checks/studio_check.mjs [url]
import { e2e, scrollEnd, settle } from './lib/e2e.mjs';


// Contrast of what the page paints, as the browser computed it: every
// element with its own text against the opaque background behind it (the
// backgrounds of its ancestors composited), and every icon's stroke.
// Returns the worst ratio per component (its tag + text) and the failures.
async function contrast(page) {
  return page.evaluate(() => {
    const parse = (c) => {
      const m = c.match(/^(rgba?|color)\((.*)\)$/);
      if (!m) return null;
      let v = m[2].replace('srgb', '').split(/[ ,/]+/).filter(Boolean).map(Number);
      if (m[1] === 'color') v = [v[0] * 255, v[1] * 255, v[2] * 255, v[3] ?? 1];
      return { r: v[0], g: v[1], b: v[2], a: v[3] ?? 1 };
    };
    const over = (top, bottom) => {
      const a = top.a + bottom.a * (1 - top.a);
      const mix = (x, y) => (x * top.a + y * bottom.a * (1 - top.a)) / a;
      return { r: mix(top.r, bottom.r), g: mix(top.g, bottom.g), b: mix(top.b, bottom.b), a };
    };
    // A segmented control's chosen cell sits on its groove's `::before` (the
    // thumb, moved under the checked cell by anchor positioning), not on the
    // groove: under a cell that holds the checked radio, that is the layer.
    const thumb = (e) => {
      const groove = e.parentElement;
      if (!groove || !e.querySelector(':scope > input:checked')) return null;
      const b = getComputedStyle(groove, '::before');
      if (b.content === 'none' || b.position !== 'absolute') return null;
      const c = parse(b.backgroundColor);
      return c && c.a > 0 ? c : null;
    };
    const background = (el) => {
      let acc = { r: 0, g: 0, b: 0, a: 0 };
      for (let e = el; e && acc.a < 1; e = e.parentElement) {
        const bg = parse(getComputedStyle(e).backgroundColor);
        if (bg && bg.a > 0) acc = over(acc, bg);
        const under = acc.a < 1 ? thumb(e) : null;
        if (under) acc = over(acc, under);
      }
      return acc.a < 1 ? over(acc, { r: 255, g: 255, b: 255, a: 1 }) : acc;
    };
    const lin = (v) => ((v /= 255) <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);
    const lum = (c) => 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    const ratio = (a, b) => {
      const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p);
      return (x + 0.05) / (y + 0.05);
    };
    const rows = [];
    const visible = (el) => {
      const r = el.getBoundingClientRect();
      const cs = getComputedStyle(el);
      return r.width > 0 && r.height > 0 && cs.visibility !== 'hidden' && cs.display !== 'none';
    };
    for (const el of document.body.querySelectorAll('*')) {
      if (el.closest('svg') && el.tagName !== 'svg') continue;
      if (el.closest('dialog:not([open])') || !visible(el)) continue;
      const own = [...el.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim());
      const cs = getComputedStyle(el);
      if (own) {
        const bg = background(el);
        const fg = over(parse(cs.color), bg);
        const size = parseFloat(cs.fontSize);
        const large = size >= 24 || (size >= 18.66 && +cs.fontWeight >= 700);
        rows.push({
          kind: 'text',
          name: `${el.tagName.toLowerCase()} "${el.textContent.trim().slice(0, 24)}"`,
          ratio: ratio(fg, bg),
          need: large ? 3 : 4.5,
        });
      } else if (el.tagName === 'svg' && el.getAttribute('aria-hidden') === 'true') {
        const stroke = parse(cs.color);
        const bg = background(el);
        rows.push({ kind: 'icon', name: `icon ${el.querySelector('use')?.getAttribute('href') ?? ''}`, ratio: ratio(over(stroke, bg), bg), need: 3 });
      }
    }
    return rows.map((r) => ({ ...r, ratio: Math.round(r.ratio * 100) / 100 }));
  });
}

await e2e('studio', { site: 'test/fixtures/apps/studio_gallery/build/site' }, async (t) => {
  async function open(width, height, js) {
    const page = await t.page({ viewport: { width, height }, javaScriptEnabled: js });
    page.on('console', (m) => m.type() === 'warning' && page.problems.push(m.text()));
    await page.goto(t.url, { waitUntil: 'networkidle' });
    return page;
  }

  for (const js of [true, false]) {
    const tag = js ? '[js]' : '[no js]';
    const check = (label, ok, detail) => t.check(`${tag} ${label}`, ok, detail);

    for (const [w, h] of [[390, 844], [768, 1024], [1440, 900]]) {
      const page = await open(w, h, js);
      // Faces load on use: wait for them instead of a fixed delay.
      await settle(page, () => document.fonts.status === 'loaded');
      const m = await page.evaluate(() => ({
        scrollW: document.documentElement.scrollWidth,
        fonts: [...document.fonts].filter((f) => f.status === 'loaded').length,
        // Script files: the copy buttons' enhancement (deferred, in the
        // HTML; without it they are hidden) and, with JS, the engine that
        // thor's inline loader adds. Nothing else.
        scripts: [...document.scripts]
          .filter((s) => s.src)
          .filter((s) => !(/\/scripts\/studio-code\.\w+\.js$/.test(s.src) && s.defer) && !/\/engine\.[\w.]+\.js$/.test(s.src))
          .map((s) => s.src),
      }));
      check(`${w}px: no horizontal scroll`, m.scrollW === w, `scrollWidth ${m.scrollW}`);
      check(`${w}px: fonts loaded`, m.fonts >= 2, `${m.fonts} faces`);
      check(`${w}px: no script files but the enhancements`, m.scripts.length === 0, m.scripts.join(' '));
      check(`${w}px: clean console`, page.problems.length === 0, page.problems.join(' | '));
      await page.context().close();
    }

    {
      const page = await open(1440, 900, js);
      // The page's sticky boxes: the sidebar's (flush under the bar) and the
      // table of contents' (level with the body's first line).
      const tops = () =>
        page.evaluate(() => {
          const sticky = (e) => {
            for (; e; e = e.parentElement) if (getComputedStyle(e).position === 'sticky') return e;
            return null;
          };
          const top = (e) => (e ? Math.round(e.getBoundingClientRect().top) : null);
          return {
            bar: top(document.querySelector('header')) + document.querySelector('header').offsetHeight,
            side: top(document.querySelector('[data-studio-sidebar-scroll]')),
            toc: top(sticky(document.querySelector('aside nav[aria-label="En esta página"]'))),
          };
        });
      const before = await tops();
      const lead = await page.evaluate(() => Math.round(document.querySelector('main').firstElementChild.getBoundingClientRect().top));
      check('panels under the bar', before.side === before.bar && before.toc === lead, JSON.stringify({ ...before, lead }));
      await page.mouse.wheel(0, 700);
      await settle(page, () => scrollY > 0);
      await scrollEnd(page);
      const after = await tops();
      check('panels stay while scrolling', after.side === before.side && after.toc === before.toc && after.bar === before.bar, JSON.stringify(after));
      await page.evaluate(() => scrollTo(0, 0));
      const first = await page.evaluate(
        () => document.querySelector('aside nav[aria-label="En esta página"] a[href^="#"]')?.getAttribute('href') ?? null,
      );
      check('page has an in-page navigation', first !== null);
      if (first) {
        await page.click(`aside nav[aria-label="En esta página"] a[href="${first}"]`);
        await settle(page, (id) => location.hash === id, first);
        await scrollEnd(page);
        const a = await page.evaluate((id) => {
          const el = document.getElementById(id.slice(1));
          return {
            top: el ? Math.round(el.getBoundingClientRect().top) : null,
            bar: document.querySelector('header').getBoundingClientRect().bottom,
            atEnd: Math.round(scrollY) >= document.documentElement.scrollHeight - innerHeight - 1,
          };
        }, first);
        check('anchors land below the bar', a.top !== null && (a.top >= a.bar || a.atEnd), JSON.stringify(a));
      }
      if (await page.locator('input[name="q"]').count()) {
        await page.fill('input[name="q"]', 'cache');
        const [req] = await Promise.all([
          page.waitForRequest((r) => r.url().includes('q=cache')),
          page.press('input[name="q"]', 'Enter'),
        ]);
        check('search submits ?q=', /[?&]q=cache/.test(req.url()), req.url());
      }
      await page.context().close();
    }

    {
      const page = await open(390, 844, js);
      const hidden = await page.evaluate(() =>
        [document.querySelector('[data-studio-sidebar-scroll]'), document.querySelector('aside nav[aria-label="En esta página"]')]
          .every((a) => a && a.getBoundingClientRect().width === 0),
      );
      check('phone: panels hidden', hidden);
      // The page's own bar (the first header; the gallery shows others).
      const menu = page.locator('header').first().locator('button[commandfor]');
      const nav = await menu.getAttribute('commandfor');
      await menu.click();
      const drawer = await settle(page, (id) => {
        const d = document.getElementById(id);
        const state = d ? { open: d.open, current: d.querySelectorAll('[aria-current="page"]').length } : null;
        return state?.open && state.current > 0 ? state : false;
      }, nav);
      check('phone: the menu opens the navigation', drawer !== false, JSON.stringify(drawer));
      await page.keyboard.press('Escape');
      const closed = await settle(page, (id) => !document.getElementById(id)?.open, nav);
      check('phone: Esc closes it', closed === true);
      await page.context().close();
    }
  }

  // Light and dark: the system's scheme, the stored choice with no flash,
  // the switch, and contrast AA in each.
  {
    const report = {};
    for (const scheme of ['light', 'dark']) {
      const ctx = await t.browser.newContext({ colorScheme: scheme, viewport: { width: 1440, height: 900 } });
      const page = await ctx.newPage();
      await page.goto(t.url, { waitUntil: 'networkidle' });
      await settle(page, () => document.fonts.status === 'loaded');
      const mode = await page.evaluate(() => getComputedStyle(document.documentElement).colorScheme);
      t.check(`${scheme}: the system's scheme rules`, mode === scheme, mode);
      const rows = await contrast(page);
      const bad = rows.filter((r) => r.ratio < r.need);
      t.check(`${scheme}: ${rows.length} texts and icons meet AA`, rows.length > 40 && bad.length === 0, JSON.stringify(bad.slice(0, 5)));
      report[scheme] = rows;
      // The layers: a dialog and the phone drawer paint the panel (not a
      // Material fallback) and their text reads on it, in each scheme.
      const nav = await page.locator('header').first().locator('button[commandfor]').getAttribute('commandfor');
      const panelOf = () => {
        const probe = document.body.appendChild(document.createElement('div'));
        probe.style.background = 'var(--t-panel)';
        const c = getComputedStyle(probe).backgroundColor;
        probe.remove();
        return c;
      };
      // The panel color of the scheme (`--t-panel`, what cards and layers paint).
      const panel = await page.evaluate(panelOf);
      for (const id of ['studio-dialog', nav]) {
        // The drawer is a layer only below lg (above it, the page's column).
        if (id === nav) await page.setViewportSize({ width: 390, height: 844 });
        const r = await page.evaluate(([id, panel]) => {
          const d = document.getElementById(id);
          d.showModal();
          const cs = getComputedStyle(d);
          const out = { bg: cs.backgroundColor, panel, color: cs.color, scheme: cs.colorScheme };
          d.close();
          return out;
        }, [id, panel]);
        if (id === nav) await page.setViewportSize({ width: 1440, height: 900 });
        t.check(`${scheme}: #${id === nav ? 'the drawer' : id} paints the panel`, r.bg === r.panel, JSON.stringify(r));
      }
      // A bare Popover paints the panel and the ink, not the browser's Canvas.
      const pop = await page.evaluate((panel) => {
        const trigger = [...document.querySelectorAll('[popovertarget]')].find((b) => b.textContent.trim() === 'Popover');
        const p = document.getElementById(trigger.getAttribute('popovertarget'));
        const ink = getComputedStyle(document.querySelector('h1')).color;
        p.showPopover();
        const cs = getComputedStyle(p);
        const out = { bg: cs.backgroundColor, panel, color: cs.color, ink, scheme: cs.colorScheme };
        p.hidePopover();
        return out;
      }, panel);
      t.check(`${scheme}: a bare Popover paints the panel and the ink`, pop.bg === pop.panel && pop.color === pop.ink && pop.scheme === scheme, JSON.stringify(pop));
      // Fields: the disabled one is not focusable, the invalid one is named.
      t.check(`${scheme}: a disabled and an invalid field`, (await page.locator('input[type=text][disabled]').count()) === 1 && (await page.locator('input[aria-invalid="true"]').count()) === 1);
      // Scrollbars and controls follow the scheme (color-scheme of every scroller).
      const sch = await page.evaluate(() => [...document.querySelectorAll('*')].filter((e) => /auto|scroll/.test(getComputedStyle(e).overflowY) && e.scrollHeight > e.clientHeight).map((e) => getComputedStyle(e).colorScheme));
      t.check(`${scheme}: scrollers use the ${scheme} color-scheme`, sch.length > 0 && sch.every((c) => c === scheme), JSON.stringify(sch));
      await ctx.close();
    }
    if (process.env.STUDIO_CONTRAST) {
      const worst = (rows) => {
        const by = {};
        for (const r of rows) by[r.name] = Math.min(by[r.name] ?? 99, r.ratio);
        return by;
      };
      const [l, d] = [worst(report.light), worst(report.dark)];
      for (const name of Object.keys(l)) console.log(`CONTRAST\t${name}\t${l[name]}\t${d[name] ?? '-'}`);
    }

    for (const system of ['light', 'dark']) {
      const other = system === 'light' ? 'dark' : 'light';
      const ctx = await t.browser.newContext({ colorScheme: system, viewport: { width: 390, height: 844 } });
      await ctx.addInitScript(() => {
        document.addEventListener('DOMContentLoaded', () => {
          window.__early = getComputedStyle(document.documentElement).colorScheme;
        });
      });
      const page = await ctx.newPage();
      await page.goto(t.url, { waitUntil: 'networkidle' });
      const scheme = () => page.evaluate(() => getComputedStyle(document.documentElement).colorScheme);
      // The page's own bar: the first header (the gallery shows other bars).
      const toggle = page.locator('header').first().locator('label[for=thor-theme]');
      t.check(`switch (${system}): present in the top bar`, (await toggle.count()) === 1);
      await toggle.click();
      t.check(`switch (${system}): flips to ${other}`, (await scheme()) === other, await scheme());
      const painted = await page.evaluate(() => getComputedStyle(document.body.firstElementChild).backgroundColor);
      await page.reload({ waitUntil: 'networkidle' });
      t.check(`switch (${system}): ${other} kept on reload, already at DOMContentLoaded`,
        (await scheme()) === other && (await page.evaluate(() => window.__early)) === other, await page.evaluate(() => window.__early));
      t.check(`switch (${system}): same paint after reload`,
        (await page.evaluate(() => getComputedStyle(document.body.firstElementChild).backgroundColor)) === painted);
      await ctx.close();
    }
  }
});

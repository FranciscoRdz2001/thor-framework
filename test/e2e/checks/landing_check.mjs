// test/fixtures/apps/landing in a real browser, without and with JavaScript: theme,
// drawer, dropdown, accordion, carousel, anchors, hover groups, no
// horizontal overflow and no page errors. Everything must work natively
// (no JS); with JS it must keep working.
//
//   tool/thor e2e landing                       (builds, serves, runs)
//   node test/e2e/checks/landing_check.mjs [url]
import { e2e, scrollEnd, settle, still } from './lib/e2e.mjs';

await e2e('landing', { site: 'test/fixtures/apps/landing/build/site' }, async (t) => {
  for (const js of [false, true]) {
    const tag = js ? '[js]' : '[no js]';
    const check = (label, ok, detail) => t.check(`${tag} ${label}`, ok, detail);

    // Desktop.
    let p = await t.page({ viewport: { width: 1280, height: 900 }, javaScriptEnabled: js });
    const problems = p.problems;
    await p.goto(t.url);
    const bg = () => p.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const light = await bg();
    await p.click('label[for=thor-theme] >> visible=true');
    const dark = await settle(
      p,
      (l) => {
        const c = getComputedStyle(document.body).backgroundColor;
        return c !== l && c;
      },
      light,
    );
    check('theme toggle', dark !== false, `${light} -> ${await bg()}`);
    // One hero <img> showing (a <picture> and its hidden twins), the dark
    // file: what the browser shows, not which <img> names it.
    const heroes = () =>
      p.locator('img[alt^="dashboard"]:visible').evaluateAll((els) => els.map((e) => e.currentSrc));
    // The dark file is `loading=lazy` (a browser with scripting on defers it
    // until it nears the viewport; the theme toggle sits in the footer, so
    // the hero is thousands of pixels away): bring it into view first, as a
    // visitor scrolling back up would. Without scripting the browser ignores
    // `lazy`, which is why only the [js] pass needed it.
    await p.locator('img[alt^="dashboard"]:visible').first().scrollIntoViewIfNeeded();
    await p.waitForFunction(() => [...document.images].some((i) => /hero-image-dark/.test(i.currentSrc) && i.offsetParent && i.complete));
    const shown = await heroes();
    check('dark hero image shown', shown.length === 1 && /hero-image-dark/.test(shown[0]), shown.join(' '));
    check('light hero image hidden', !shown.some((s) => /hero-image-light/.test(s)));
    await p.focus('#thor-theme');
    await p.keyboard.press('Space');
    const back = await settle(p, (l) => getComputedStyle(document.body).backgroundColor === l, light);
    check('theme switch works from the keyboard', back === true, await bg());

    await p.click('button[popovertarget=features-menu]');
    check('features dropdown opens', await p.locator('#features-menu').isVisible());
    await p.keyboard.press('Escape');
    check('dropdown closes on Esc', await p.locator('#features-menu').isHidden());

    // The FAQ section is laid out lazily (it takes its real height once in
    // view) and an opening item grows over 250 ms, moving the ones below:
    // click each header once it stands still (see `still`).
    const question = (n) => p.locator('#faq summary').nth(n);
    await still(question(1));
    await question(1).click();
    check('faq item opens', await p.locator('#faq details').nth(1).evaluate((d) => d.open));
    await still(question(2));
    await question(2).click();
    check('faq is exclusive', !(await p.locator('#faq details').nth(1).evaluate((d) => d.open)));

    const car = p.locator('[aria-roledescription=carousel]');
    await car.evaluate((e) => e.scrollBy({ left: 500, behavior: 'instant' }));
    check('carousel scrolls', (await car.evaluate((e) => e.scrollLeft)) > 0);

    await p.click('a[href="#pricing"] >> nth=0');
    check('CTA anchors to #pricing', (await p.evaluate(() => location.hash)) === '#pricing');
    check('social icons are svg inside <a>', (await p.locator('#team a[aria-label] svg').count()) > 0);

    // Hover groups: hovering a team card zooms its photo (CSS transition).
    const photo = p.locator('#team img').first();
    const before = await photo.evaluate((e) => getComputedStyle(e).scale);
    await p.locator('#team .t-group').first().hover();
    const after = await settle(
      p,
      (e) => getComputedStyle(e).scale === '1.05' && '1.05',
      await photo.elementHandle(),
    );
    check('team photo zooms on card hover', before !== '1.05' && after === '1.05', `${before} -> ${after}`);
    await p.context().close();

    // Anchors land exactly on a first visit, although sections below the
    // fold are laid out lazily (estimated heights until rendered).
    for (const width of [1280, 390]) {
      p = await t.page({ viewport: { width, height: 900 }, javaScriptEnabled: js });
      await p.goto(`${t.url}#faq`);
      await scrollEnd(p);
      const top = await settle(p, () => {
        const top = Math.round(document.getElementById('faq').getBoundingClientRect().top);
        return Math.abs(top) <= 1 && `${top}`;
      });
      const now = await p.locator('#faq').evaluate((e) => Math.round(e.getBoundingClientRect().top));
      check(`#faq anchor on first visit at ${width}px`, top !== false, `top ${now}`);
      problems.push(...p.problems);
      await p.context().close();
    }

    // Phone drawer.
    p = await t.page({ viewport: { width: 390, height: 844 }, javaScriptEnabled: js });
    await p.goto(t.url);
    await p.click('button[commandfor=nav-drawer]');
    const drawer = p.locator('#nav-drawer');
    const becomes = (state) => drawer.waitFor({ state, timeout: 3000 }).then(() => true, () => false);
    check('phone drawer opens', await becomes('visible'));
    await p.keyboard.press('Escape');
    check('drawer closes on Esc', await becomes('hidden'));
    const overflow = await p.evaluate(() => document.documentElement.scrollWidth - innerWidth);
    check('no horizontal overflow', overflow <= 0, `${overflow}px`);
    problems.push(...p.problems);
    await p.context().close();
    check('no page errors', problems.length === 0, problems.join(' | '));
  }
});

// The docs sidebar keeps its scroll across pages (StudioScaffold's
// sidebarRestorationId, a SingleChildScrollView restorationId): desktop and
// the phone drawer (one scroll view, one offset), back, another area's
// list, storage that throws and no JavaScript; and between pages (the
// prev/next cards at a page's end) the sidebar stays still in every frame of
// the view transition.
//
//   tool/thor e2e sidebar                    (exports, serves, runs)
//   node test/e2e/checks/sidebar_scroll_check.mjs [url]
import { e2e } from './lib/e2e.mjs';

// The sidebar shows one area's list with only the current section open, so
// it fits a tall window: short windows (a laptop with its dock, a phone on
// its side, below the drawer's breakpoint) are where it scrolls.
const DESKTOP = { viewport: { width: 1280, height: 480 } };
const PHONE = { viewport: { width: 667, height: 375 } };
// The API area's list: long enough to scroll in those windows.
const START = 'es/api/thor_ui/widgets';
const DEEP = 'es/api/thor_ui/thor_studio';

/** The scroll view of [id] and its numbers, from the page. */
const view = (page, id) =>
  page.evaluate((id) => {
    const e = [...document.querySelectorAll('script[data-thor-restore]')]
      .find((s) => s.textContent.includes(`thor-scroll:${id}`))?.parentElement;
    if (!e) return null;
    // The shown one: the area tabs at the top of the list are a phone's only.
    const a = [...e.querySelectorAll('[aria-current=page]')].filter((x) => x.getClientRects().length).pop();
    const d = a ? a.getBoundingClientRect().top - e.getBoundingClientRect().top : null;
    return {
      top: e.scrollTop,
      height: e.clientHeight,
      current: a?.getAttribute('href') ?? null,
      currentAt: d,
      currentVisible: d != null && d >= 0 && d + a.clientHeight <= e.clientHeight,
      max: e.scrollHeight - e.clientHeight,
      windowY: scrollY,
    };
  }, id);

/** Scrolls view [id] to [top] and clicks a guide link in sight; its offset. */
const scrollAndClick = (page, id, top) =>
  page.evaluate(
    ([id, top]) => {
      const e = [...document.querySelectorAll('script[data-thor-restore]')]
        .find((s) => s.textContent.includes(`thor-scroll:${id}`)).parentElement;
      e.scrollTop = top;
      const r = e.getBoundingClientRect();
      const link = [...e.querySelectorAll('a[href^="/es/"]')].find((a) => {
        const b = a.getBoundingClientRect();
        return b.top > r.top + 80 && b.bottom < r.bottom - 80 && a.getAttribute('aria-current') !== 'page';
      });
      const at = link.getBoundingClientRect().top - r.top;
      link.click();
      return { href: link.getAttribute('href'), at, top: e.scrollTop };
    },
    [id, top],
  );

const near = (a, b) => Math.abs(a - b) <= 2;

// Runs in every page before its scripts: each frame from the reveal on, the
// sidebar's view-transition group (where the browser draws it), the list
// and the current link, kept per page in sessionStorage. From the first
// frame: at the reveal itself the group has no geometry yet.
function frames() {
  const log = [];
  let n = 0;
  let vt = null;
  const snap = () => {
    const e = document.querySelector('script[data-thor-restore]')?.parentElement;
    if (!e) return;
    const a = [...e.querySelectorAll('[aria-current=page]')].filter((x) => x.getClientRects().length).pop();
    const g = getComputedStyle(document.documentElement, '::view-transition-group(docs-nav)');
    const active = document.documentElement.matches(':active-view-transition');
    const m = active ? new DOMMatrix(g.transform === 'none' ? undefined : g.transform) : null;
    log.push({
      active,
      groupY: m ? Math.round(m.m42) : null,
      groupHeight: active ? Math.round(parseFloat(g.height)) : null,
      top: e.scrollTop,
      listY: Math.round(e.getBoundingClientRect().top),
      listHeight: Math.round(e.getBoundingClientRect().height),
      currentAt: a ? Math.round(a.getBoundingClientRect().top - e.getBoundingClientRect().top) : null,
    });
  };
  const save = () => sessionStorage.setItem(`t-frames:${location.pathname}`, JSON.stringify({ vt, log }));
  addEventListener('pagereveal', (ev) => {
    vt = !!ev.viewTransition;
    const f = () => {
      snap();
      save();
      if (++n < 30) requestAnimationFrame(f);
    };
    requestAnimationFrame(f);
  });
}

await e2e('sidebar', { site: 'apps/docs/build/site' }, async (t) => {
  const errors = [];
  const watch = (page) => {
    page.on('pageerror', (e) => errors.push(e.message));
    page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
  };

  // --- Desktop.
  const page = await t.page(DESKTOP);
  watch(page);
  await page.goto(`${t.url}${START}`);
  let v = await view(page, 'docs-sidebar');
  t.check('desktop: the list is taller than the window (a range to keep)', v.max >= 200, `${v.max}`);
  const before = await scrollAndClick(page, 'docs-sidebar', 150);
  await page.waitForURL(`**${before.href}`);
  v = await view(page, 'docs-sidebar');
  t.check('desktop: the offset was not the top', before.top > 0, `${before.top}`);
  t.check('desktop: the offset survives the page change', near(v.top, before.top), `${v.top} vs ${before.top}`);
  t.check('desktop: the clicked link stays where it was', near(v.currentAt, before.at), `${v.currentAt} vs ${before.at}`);
  t.check('desktop: the page itself does not scroll', v.windowY === 0, `${v.windowY}`);

  // Back and forward: each page's own offset, not the last one.
  const end = await page.evaluate(() => {
    const e = [...document.querySelectorAll('script[data-thor-restore]')]
      .find((s) => s.textContent.includes('thor-scroll:docs-sidebar')).parentElement;
    e.scrollTop = e.scrollHeight;
    history.replaceState({ app: 'kept' }, '');
    return e.scrollTop;
  });
  await page.goto(`${t.url}es/datos-y-estado/estado`);
  await page.goBack();
  await page.waitForURL(`**${before.href}`);
  v = await view(page, 'docs-sidebar');
  t.check('back: this page\'s own offset', near(v.top, end) && !near(end, before.top), `${v.top} vs ${end}`);
  t.check('back: the app\'s history state is kept', (await page.evaluate(() => history.state?.app)) === 'kept');
  await page.goBack();
  await page.waitForURL(`**/${START}`);
  v = await view(page, 'docs-sidebar');
  t.check('back again: the first page\'s offset', near(v.top, before.top), `${v.top} vs ${before.top}`);
  await page.goForward();
  await page.waitForURL(`**${before.href}`);
  v = await view(page, 'docs-sidebar');
  t.check('forward: its offset again', near(v.top, end), `${v.top} vs ${end}`);

  // A page reached from the text, far down the list, after the offset was
  // left at the top.
  await page.evaluate(() => {
    [...document.querySelectorAll('script[data-thor-restore]')]
      .find((s) => s.textContent.includes('thor-scroll:docs-sidebar')).parentElement.scrollTop = 0;
  });
  await page.goto(`${t.url}${DEEP}`);
  v = await view(page, 'docs-sidebar');
  t.check('desktop: the current link shows when it was out of sight', v.currentVisible && v.top > 0, JSON.stringify(v));

  // Another area: another list under the same id.
  await page.goto(`${t.url}es/interfaz/flutter-embebido`);
  v = await view(page, 'docs-sidebar');
  t.check('desktop: another area shows its current link', v.currentVisible, JSON.stringify(v));

  // A first visit (new tab state), deep in the list.
  const fresh = await t.page(DESKTOP);
  watch(fresh);
  await fresh.goto(`${t.url}${DEEP}`);
  v = await view(fresh, 'docs-sidebar');
  t.check('first visit: the current link shows', v.currentVisible, JSON.stringify(v));

  // --- Prev/next from a page's end: the sticky list was pushed up by the
  // footer and the page changes at its top. The sidebar group is the list
  // (not the page-tall column) and never travels; the offset and the
  // current link hold in every frame.
  const cards = await t.page(DESKTOP);
  watch(cards);
  await cards.addInitScript(frames);
  await cards.goto(`${t.url}es/publicar/pruebas`);
  for (const rel of ['next', 'prev']) {
    const link = cards.locator(`a[rel=${rel}]`).last();
    await link.scrollIntoViewIfNeeded();
    const was = await view(cards, 'docs-sidebar');
    const href = await link.getAttribute('href');
    await link.click();
    await cards.waitForURL(`**${href}`);
    await cards.waitForTimeout(500);
    const { vt, log } = await cards.evaluate((p) => JSON.parse(sessionStorage.getItem(`t-frames:${p}`) ?? '{}'), href);
    const during = (log ?? []).filter((f) => f.active);
    const last = log?.at(-1) ?? {};
    t.check(`${rel} card: the page changes with a view transition`, vt === true && during.length > 0, JSON.stringify({ vt, frames: log?.length }));
    t.check(
      `${rel} card: the sidebar group is the list, where the new page has it, in every frame`,
      during.every((f) => f.groupY === last.listY && f.groupHeight === last.listHeight),
      JSON.stringify(during.map((f) => [f.groupY, f.groupHeight])) + ` list ${last.listY}/${last.listHeight}`,
    );
    t.check(
      `${rel} card: the list keeps its offset in every frame`,
      log.every((f) => near(f.top, was.top)),
      `${was.top} -> ${JSON.stringify([...new Set(log.map((f) => f.top))])}`,
    );
    t.check(
      `${rel} card: the current link holds still and shows`,
      log.every((f) => f.currentAt === last.currentAt) && last.currentAt >= 0 && last.currentAt < last.listHeight,
      JSON.stringify([...new Set(log.map((f) => f.currentAt))]),
    );
  }

  // --- Phone: the sidebar is a drawer, hidden until opened.
  const phone = await t.page(PHONE);
  watch(phone);
  const openDrawer = () => phone.getByRole('button', { name: 'Abrir navegación' }).click();
  await phone.goto(`${t.url}${START}`);
  await openDrawer();
  await phone.waitForTimeout(300);
  const onPhone = await scrollAndClick(phone, 'docs-sidebar', 150);
  t.check('phone: the drawer was scrolled', onPhone.top > 0, `${onPhone.top}`);
  await phone.waitForURL(`**${onPhone.href}`);
  await openDrawer();
  await phone.waitForTimeout(100);
  v = await view(phone, 'docs-sidebar');
  t.check('phone: the drawer opens where it was left', near(v.top, onPhone.top), `${v.top} vs ${onPhone.top}`);
  t.check('phone: its current link shows', v.currentVisible, JSON.stringify(v));

  // Closed drawer, a link in the text: what was saved stays.
  await phone.keyboard.press('Escape');
  await phone.goto(`${t.url}es/datos-y-estado/estado`);
  const kept = await phone.evaluate(() => sessionStorage.getItem('thor-scroll:docs-sidebar'));
  t.check('phone: navigating with the drawer closed keeps the offset', kept === String(onPhone.top), `${kept}`);

  // --- Storage that throws (private or sandboxed contexts).
  const locked = await t.page(DESKTOP);
  const lockedErrors = [];
  locked.on('pageerror', (e) => lockedErrors.push(e.message));
  await locked.addInitScript(() => {
    Object.defineProperty(window, 'sessionStorage', {
      get() {
        throw new DOMException('denied', 'SecurityError');
      },
    });
  });
  await locked.goto(`${t.url}es/datos-y-estado/formularios`);
  v = await view(locked, 'docs-sidebar');
  t.check('storage that throws: no error, the page works', lockedErrors.length === 0 && v !== null, lockedErrors.join('; '));

  // --- No JavaScript: the sidebar is there and its links work.
  const plain = await t.page({ ...DESKTOP, javaScriptEnabled: false });
  await plain.goto(`${t.url}es/empezar/que-es-thor`);
  await plain.locator('nav a[href="/es/empezar/instalacion"]').first().click();
  await plain.waitForURL('**/es/empezar/instalacion');
  t.check('no JavaScript: the sidebar links navigate', true);

  t.check('no errors in the console', errors.length === 0, errors.join('; '));
});

// PageView, AutofillGroup and the dialog they must not close, in a real
// browser: arrows page a snapping PageView (and a locked one ignores the
// wheel but obeys scrollTo), the scroller takes the keyboard's focus; a
// login group outside a form is a `method=dialog` form whose Enter fires
// submit and never navigates, one inside a dialog adds no form (Enter does
// not close it); every `autocomplete` is a valid token sequence (HTML
// «autofill detail tokens»); with no JavaScript. A page rendered in memory
// (packages/thor_ui/tool/e2e_pages.dart), no app.
//
//   tool/thor e2e catalog                       (renders the pages, serves, runs)
//   node test/e2e/checks/catalog_check.mjs
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { closeServer, e2e, repo, serveStatic, tabKey } from './lib/e2e.mjs';

const dir = mkdtempSync(join(tmpdir(), 'thor-catalog-'));
let server;

// The HTML spec's autofill detail tokens: [section-*] [shipping|billing]
// [home|work|mobile|fax|pager] field-name [webauthn], or `on` / `off`.
const FIELDS = new Set(
  'name honorific-prefix given-name additional-name family-name honorific-suffix nickname organization-title username new-password current-password one-time-code organization street-address address-line1 address-line2 address-line3 address-level4 address-level3 address-level2 address-level1 country country-name postal-code cc-name cc-given-name cc-additional-name cc-family-name cc-number cc-exp cc-exp-month cc-exp-year cc-csc cc-type transaction-currency transaction-amount language bday bday-day bday-month bday-year sex url photo tel tel-country-code tel-national tel-area-code tel-local tel-local-prefix tel-local-suffix tel-extension email impp'.split(' '),
);
function validAutocomplete(value) {
  if (value === 'on' || value === 'off') return true;
  const tokens = value.split(/\s+/);
  let i = 0;
  if (tokens[i]?.startsWith('section-') && tokens[i].length > 8) i++;
  if (['shipping', 'billing'].includes(tokens[i])) i++;
  const tel = ['tel', 'tel-country-code', 'tel-national', 'tel-area-code', 'tel-local', 'tel-local-prefix', 'tel-local-suffix', 'tel-extension', 'impp', 'email'];
  if (['home', 'work', 'mobile', 'fax', 'pager'].includes(tokens[i]) && tokens.slice(i + 1).some((x) => tel.includes(x))) i++;
  if (!FIELDS.has(tokens[i])) return false;
  i++;
  if (tokens[i] === 'webauthn') i++;
  return i === tokens.length;
}

await e2e('catalog', { site: null, timeout: 120_000 }, async (t) => {
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
  const scroller = (page, key) => page.locator(`[data-thor="PageView"]`).nth(key);

  // PageView.
  {
    const page = await t.page({ viewport: { width: 400, height: 900 } });
    await page.goto(`${base}/pageview.html`);
    const free = scroller(page, 0);
    await free.focus();
    t.check('the scroller takes focus (tabindex)', await free.evaluate((e) => document.activeElement === e));
    await page.keyboard.press('ArrowRight');
    await page.waitForTimeout(700);
    const left = await free.evaluate((e) => Math.round(e.scrollLeft));
    const width = await free.evaluate((e) => e.clientWidth);
    t.check('ArrowRight snaps to the next page', left === width, `scrollLeft ${left}, page ${width}`);
    const vertical = scroller(page, 1);
    await vertical.focus();
    await page.keyboard.press('ArrowDown');
    await page.waitForTimeout(700);
    const top = await vertical.evaluate((e) => [Math.round(e.scrollTop), e.clientHeight]);
    t.check('ArrowDown snaps the vertical one', top[0] === top[1], JSON.stringify(top));

    const locked = scroller(page, 2);
    t.check('the locked one is not in the tab order', (await locked.getAttribute('tabindex')) === null);
    const box = await locked.boundingBox();
    await page.mouse.move(box.x + 20, box.y + 20);
    await page.mouse.wheel(300, 0);
    await page.waitForTimeout(300);
    t.check('wheel does not move the locked one', (await locked.evaluate((e) => e.scrollLeft)) === 0);
    await locked.evaluate((e) => e.scrollTo({ left: e.clientWidth, behavior: 'instant' }));
    t.check('scrollTo still moves it', (await locked.evaluate((e) => Math.round(e.scrollLeft))) > 0);

    // Tab reaches a link in the second page and pages the view to it.
    const links = scroller(page, 3);
    await links.focus();
    await page.keyboard.press(tabKey());
    await page.waitForTimeout(500);
    t.check('Tab into an off-screen page scrolls it into view', (await links.evaluate((e) => e.scrollLeft)) > 0 && (await page.evaluate(() => document.activeElement?.tagName)) === 'A');
  }

  // AutofillGroup.
  {
    const page = await t.page({ viewport: { width: 700, height: 900 } });
    let navigated = 0;
    page.on('framenavigated', () => navigated++);
    await page.goto(`${base}/autofill.html`);
    navigated = 0;
    await page.evaluate(() => {
      window.__submits = [];
      document.addEventListener('submit', (e) => __submits.push(e.target.querySelector('input')?.name));
    });
    const tokens = await page.$$eval('[autocomplete]', (els) => els.map((e) => e.getAttribute('autocomplete')));
    t.check('every autocomplete is a valid token sequence', tokens.every(validAutocomplete), tokens.filter((x) => !validAutocomplete(x)).join(' | '));
    t.check('no form is inside another', (await page.evaluate(() => document.querySelectorAll('form form').length)) === 0);

    await page.fill('#user', 'ana');
    await page.fill('#pass', 'secret');
    await page.press('#pass', 'Enter');
    await page.waitForTimeout(300);
    t.check('Enter submits the group (submit event fires)', (await page.evaluate(() => __submits.length)) === 1);
    t.check('and nothing navigates, the fields keep their value', navigated === 0 && (await page.inputValue('#pass')) === 'secret', `navigated ${navigated}`);
    t.check('the password is not in the URL', !page.url().includes('secret') && !page.url().includes('?'));

    await page.click('text=Open');
    t.check('the dialog opens', await page.locator('dialog#login').evaluate((d) => d.open));
    t.check('its group adds no form', (await page.locator('dialog#login form').count()) === 0);
    await page.fill('#dlguser', 'bob');
    await page.press('#dlguser', 'Enter');
    await page.waitForTimeout(300);
    t.check('Enter in the dialog\'s field does not close it', await page.locator('dialog#login').evaluate((d) => d.open));
  }

  // No JavaScript: the same markup.
  {
    const page = await t.page({ javaScriptEnabled: false });
    await page.goto(`${base}/autofill.html`);
    await page.fill('#user', 'ana');
    await page.press('#user', 'Enter');
    await page.waitForTimeout(300);
    t.check('with no JS Enter does not navigate either', page.url() === `${base}/autofill.html`, page.url());
  }
}

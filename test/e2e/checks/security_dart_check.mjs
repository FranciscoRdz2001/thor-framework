// The runtime half of the adversarial battery (security_check.mjs, B) on the
// dart2js engine: the lite runtime has its own hand-written pages there; this
// is the same hostile input against a real build of test/fixtures/apps/counter and the rows page of test/fixtures/apps/lab
// (the internal oracle engine, never shipped). A malformed or hostile
// `#thor-state` (broken JSON, `__proto__` and `constructor` keys at any depth,
// wrong types, huge values), forged `data-t-on` ids, hostile row data and keys.
// Nothing runs, nothing is polluted, the page keeps working.
//
//   tool/thor e2e security-dart                 (builds both apps, runs)
//   node test/e2e/checks/security_dart_check.mjs
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { closeServer, e2e, hydrated, repo, serveStatic, settle, trackHydration } from './lib/e2e.mjs';

const counterDir = join(repo, process.env.E2E_SITE ?? 'test/fixtures/apps/counter/build/site');
const rowsDir = join(repo, process.env.E2E_ROWS_SITE ?? 'test/fixtures/apps/lab/build/site');
const counterHtml = readFileSync(join(counterDir, 'index.html'), 'utf8');
const rowsHtml = readFileSync(join(rowsDir, 'rows.html'), 'utf8');

// Every payload sets `window.__pwned`: the setter reports it to the console.
async function watch(page) {
  page.hits = [];
  await page.addInitScript(() => {
    Object.defineProperty(window, '__pwned', { configurable: true, set: (v) => console.log(`PWNED:${v}`), get: () => undefined });
  });
  page.on('console', (m) => m.text().startsWith('PWNED:') && page.hits.push(m.text().slice(6)));
}

const polluted = (page) =>
  page
    .evaluate(() => ({
      proto: Object.keys(Object.prototype),
      probe: ({}).polluted ?? ({}).isAdmin ?? null,
      array: Object.keys(Array.prototype),
    }))
    .then((w) => ({ ...w, pwned: page.hits.length ? page.hits.join(',') : null }));

const stash = new Map();
const withBody = (html, extra) => html.replace('</body>', () => `${extra}</body>`);
const stateScript = (text) => `<script type="application/json" id="thor-state">${text.replace(/</g, '\\u003c')}</script>`;

// What the server would have written, per request: `?c=<name>` picks the page.
function handle(req, res) {
  const url = new URL(req.url, 'http://x');
  if (url.pathname !== '/' || !url.searchParams.has('c')) return false;
  const page = stash.get(url.searchParams.get('c'));
  if (!page) return false;
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
  res.end(page);
  return true;
}

const P = 'CounterState';
const inc = `[data-t-on="click:${P}.inc"]`;
const label = `[data-tt="${P}.label"]`;
const big = (n) => 'x'.repeat(n);

async function hydration(t, base) {
  const cases = [
    // [label, #thor-state text, what the page must show after the first tap]
    ['broken JSON', `{"${P}.count": 5`, { n: '1' }],
    ['an array', '[1, 2, 3]', { n: '1' }],
    ['null', 'null', { n: '1' }],
    ['a string', `"${P}.count"`, { n: '1' }],
    ['a number', '123', { n: '1' }],
    ['empty', '', { n: '1' }],
    ['a byte order mark', `\uFEFF{"${P}.count": 9}`, { n: '1' }],
    ['a restored field', `{"${P}.count": 5}`, { n: '6' }],
    ['duplicate keys (the last wins)', `{"${P}.count": 1, "${P}.count": 2}`, { n: '3' }],
    ['__proto__ at the top', `{"__proto__": {"polluted": true, "isAdmin": true}, "${P}.count": 6}`, { n: '7' }],
    ['constructor.prototype at the top', `{"constructor": {"prototype": {"polluted": true}}, "${P}.count": 7}`, { n: '8' }],
    ['__proto__ nested deep', `{"${P}.items": [{"k": "a", "x": {"y": {"__proto__": {"polluted": true}}}}], "${P}.count": 1}`, { n: '2' }],
    ['__proto__ as a field name of the state', `{"${P}.__proto__": 1, "${P}.constructor": 2, "${P}.count": 3}`, { n: '4' }],
    // A value that does not fit its field: that field starts from its code value (the others restore) and the console says so.
    ['wrong types', `{"${P}.count": "x"}`, { n: '1', error: /does not fit/ }],
    ['a list for a number', `{"${P}.count": [1, 2]}`, { n: '1', error: /does not fit/ }],
    ['an object for a number', `{"${P}.count": {"a": 1}}`, { n: '1', error: /does not fit/ }],
    ['null for a number', `{"${P}.count": null}`, { n: '1', error: /does not fit/ }],
    ['a fraction for a number', `{"${P}.count": 1.5}`, { n: '1', error: /does not fit/ }],
    ['an infinite number', `{"${P}.count": 1e999}`, { survives: true }],
    ['a huge integer', `{"${P}.count": 123456789012345678901234567890}`, { survives: true }],
    ['a 10 MB string', JSON.stringify({ [`${P}.tag`]: big(10_000_000), [`${P}.count`]: 2 }), { n: '3' }],
    ['20 000 levels of nesting', `{"${P}.items": ${'['.repeat(20_000)}${']'.repeat(20_000)}}`, { survives: true }],
    ['100 000 unknown fields', JSON.stringify(Object.fromEntries(Array.from({ length: 100_000 }, (_, i) => [`Nope.f${i}`, i]))), { n: '1' }],
  ];
  for (const [name, text, want] of cases) {
    const key = `state ${name}`;
    stash.set(key, withBody(counterHtml, stateScript(text)));
    const page = await t.page();
    await watch(page);
    await trackHydration(page);
    const pageErrors = [];
    page.on('pageerror', (e) => pageErrors.push(e.message));
    await page.goto(`${base}/?c=${encodeURIComponent(key)}`);
    const up = await hydrated(page).then(() => true, () => false);
    await page.click(inc).catch(() => {});
    await page.waitForTimeout(80);
    const n = await page.locator(label).textContent();
    const where = await polluted(page);
    const clean = where.proto.length === 0 && where.array.length === 0 && where.probe === null && where.pwned === null;
    const l = `#thor-state ${name}`;
    t.check(`${l}: nothing is polluted`, clean, JSON.stringify(where));
    if (want.n !== undefined) t.check(`${l}: the page shows ${want.n}`, n === want.n, `${n}${up ? '' : ' (engine did not hydrate)'}`);
    if (want.survives) {
      // The state may be nonsense, the page is not: it still shows a number and answers the tap.
      t.check(`${l}: the page survives`, (await page.locator(inc).isVisible()) && /^-?\d|^Infinity|^NaN|^\d/.test(n ?? ''), n);
    }
    t.check(`${l}: no uncaught error`, pageErrors.length === 0, pageErrors.join(' | ').slice(0, 300));
    if (want.error) {
      t.check(`${l}: says so in the console`, page.problems.some((e) => want.error.test(e)), page.problems.join(' | ').slice(0, 200));
    }
    await page.context().close();
  }
}

// Forged ids in `data-t-on`: what is not a state's own function is ignored.
async function registry(t, base) {
  const forged = [
    `${P}.constructor`, `${P}.__proto__`, `${P}.toString`, `${P}.hasOwnProperty`, `${P}.valueOf`, `${P}.__defineGetter__`,
    '__proto__.polluted', 'constructor.constructor', 'Object.assign', 'Function.call', 'window.alert',
    `${P}.nope`, `Nope.inc`, `${P}.`, '.inc', P, '', `${P}..inc`, `${P}.inc.x`, `${P} #1.inc`, `${P}#.inc`,
    `${P}.inc;${P}.inc`, 'javascript:window.__pwned=1', `${P}.inc\nwindow.__pwned=1`, `${P}.${'a'.repeat(100_000)}`,
    `${'A'.repeat(100_000)}.inc`, `${P}.inc~`.repeat(1000), `\u0000${P}.inc`, `${P.toLowerCase()}.inc`, `${P}.INC`, `${P}.іnc`,
    `${P}.reset~`, `${P}.dec`.toUpperCase(),
  ];
  const buttons = forged
    .map((id, i) => `<button class="forged" id="f${i}" data-t-on="click:${id.replace(/&/g, '&amp;').replace(/"/g, '&quot;')}">f${i}</button>`)
    .join('');
  stash.set('forged', withBody(counterHtml, buttons));
  const page = await t.page();
  await watch(page);
  await trackHydration(page);
  await page.goto(`${base}/?c=forged`);
  await hydrated(page);
  await page.evaluate(() => {
    window.__calls = [];
    for (const k of ['alert']) {
      const original = window[k];
      window[k] = (...a) => (window.__calls.push(k), original?.apply(window, a));
    }
  });
  for (let i = 0; i < forged.length; i++) await page.click(`#f${i}`, { timeout: 2000 }).catch(() => {});
  await page.waitForTimeout(100);
  const n = Number(await page.locator(label).textContent());
  const where = await polluted(page);
  const calls = await page.evaluate(() => window.__calls);
  t.check(`forged data-t-on ids (${forged.length}): none ran code`, where.pwned === null && calls.length === 0, JSON.stringify([where.pwned, calls]));
  t.check('forged data-t-on ids: nothing is polluted', where.proto.length === 0 && where.array.length === 0, JSON.stringify(where));
  // `inc;inc` is two of the state's own handlers and `inc~…` calls inc with an argument.
  t.check("forged data-t-on ids: only the state's own functions ran", Number.isInteger(n) && n >= 0 && n <= 4, String(n));
  await page.click(inc);
  t.check('forged data-t-on ids: the real button still works', Number(await page.locator(label).textContent()) === n + 1);
  t.check('forged data-t-on ids: no page errors', page.problems.filter((p) => !/Failed to load resource/.test(p)).length === 0, page.problems.join(' | '));
  await page.context().close();
}

// Row data and row keys are data: whatever they say, a row is a row.
async function rows(t, rowsBase) {
  const titles = [
    '"><img src=x onerror="window.__pwned=\'attribute\'">',
    "'><svg/onload=window.__pwned='svg'>",
    '</script><script>window.__pwned="script"</script>',
    '</style><script>window.__pwned="style"</script>',
    '<!--<script>window.__pwned="comment"</script>-->',
    '</textarea><script>window.__pwned="textarea"</script>',
    '&lt;b&gt; &#60;b&#62; &amp; &#x3c;',
    '{{key}} $& %7E ~ ; __proto__ constructor',
    'x'.repeat(5000),
    'é中😀',
  ];
  const page = await t.page();
  await watch(page);
  await trackHydration(page);
  await page.goto(`${rowsBase}/rows`);
  await hydrated(page);
  const field = page.locator('input[name=quick]');
  for (const title of titles) {
    await field.fill(title);
    await field.press('Enter');
  }
  await settle(page, (n) => document.querySelectorAll('li').length === n, 4 + titles.length);
  const made = await page.evaluate(() =>
    [...document.querySelectorAll('li')].slice(4).map((li) => ({
      text: li.querySelector('a')?.textContent,
      hidden: li.querySelector('input[type=hidden]')?.value,
      label: li.querySelector('button[aria-label]')?.getAttribute('aria-label'),
    })),
  );
  const where = await polluted(page);
  t.check(`${titles.length} hostile titles make ${titles.length} rows`, made.length === titles.length, String(made.length));
  // The state trims the title (`add`), as the page does for any text.
  const trimmed = titles.map((s) => s.trim());
  t.check("each row's text is its title, as text", trimmed.every((s, i) => made[i]?.text === s), JSON.stringify(made.map((m) => m.text)).slice(0, 200));
  t.check("and its field's value", trimmed.every((s, i) => made[i]?.hidden === s), JSON.stringify(made.map((m) => m.hidden)).slice(0, 200));
  t.check("and its label", trimmed.every((s, i) => made[i]?.label === `Quitar «${s}»`), JSON.stringify(made.map((m) => m.label)).slice(0, 200));
  t.check(
    'no element was born of a title',
    (await page.locator('li img, li script, li svg, li iframe, li [onerror], li [onclick], li style').count()) === 0 && where.pwned === null,
    JSON.stringify(where),
  );
  t.check('nothing is polluted', where.proto.length === 0 && where.array.length === 0, JSON.stringify(where));

  // A bound link that would run code is not written (`unsafe` sets `javascript:alert(1)` as the URL).
  await page.locator('li').first().locator('button', { hasText: 'js' }).click();
  await page.waitForTimeout(80);
  const href = await page.locator('li').first().locator('a').getAttribute('href');
  t.check('a bound href that runs code is dropped', href === null || !/^\s*javascript:/i.test(href), String(href));
  t.check('and following the link runs nothing', where.pwned === null && page.hits.length === 0, page.hits.join(','));

  // The reverse button reorders keyed rows: every row keeps its own data.
  await page.getByText('Invertir', { exact: true }).click();
  await page.waitForTimeout(80);
  const reversed = await page.evaluate(() => [...document.querySelectorAll('li')].map((li) => li.querySelector('a')?.textContent));
  t.check('a keyed reorder keeps every row', reversed.length === 4 + titles.length && reversed.at(-1) === 'Comprar pan', JSON.stringify(reversed).slice(0, 200));
  t.check('no page errors', page.problems.filter((p) => !/Failed to load resource/.test(p)).length === 0, page.problems.join(' | '));
  await page.context().close();

  // Hostile keys in the server's markup: the row's key is an attribute the engine reads back.
  const keys = [
    '__proto__', 'constructor', 'toString', 'hasOwnProperty', 'a~b', 'a;b', 'a%7Eb', '50%', '{{key}}', '$&', '$1',
    "'\"><img src=x onerror=\"window.__pwned='row'\">", 'x'.repeat(5000), 'é中😀', ' leading and trailing ',
  ];
  const esc = (s) => s.replace(/&/g, '&amp;').replace(/"/g, '&quot;');
  for (const key of keys) {
    const html = rowsHtml.replace(/data-tk="t1"/, () => `data-tk="${esc(key)}"`).replace(/data-tx="t1"/g, () => `data-tx="${esc(key)}"`);
    stash.set(`key ${key}`, html);
    const p = await t.page();
    await watch(p);
    await trackHydration(p);
    await p.goto(`${rowsBase}/?c=${encodeURIComponent(`key ${key}`)}`);
    await hydrated(p);
    // Reorder (the reconciler reads every key) and tap the hostile row's buttons.
    await p.getByText('Invertir', { exact: true }).click();
    await p.waitForTimeout(60);
    const order = await p.evaluate(() => [...document.querySelectorAll('li')].map((li) => li.getAttribute('data-tk')));
    await p.locator('li button').first().click({ timeout: 1000 }).catch(() => {});
    const w = await polluted(p);
    const l = `row key ${JSON.stringify(key.slice(0, 24))}`;
    // The engine does not read a row's key back from the markup: the rows are the state's, so the server's hostile key is replaced by the real one.
    t.check(`${l}: reorder keeps the four rows, with the state's own keys`, order.length === 4 && ['t1', 't2', 't3', 't4'].every((k) => order.includes(k)), JSON.stringify(order).slice(0, 120));
    t.check(`${l}: nothing ran, nothing is polluted`, w.pwned === null && w.proto.length === 0 && w.array.length === 0, JSON.stringify(w));
    t.check(`${l}: no page errors`, p.problems.filter((e) => !/Failed to load resource/.test(e)).length === 0, p.problems.join(' | ').slice(0, 200));
    await p.context().close();
  }
}

await e2e('security-dart', { site: process.env.E2E_SITE ?? 'test/fixtures/apps/counter/build/site', handle, timeout: 300_000 }, async (t) => {
  const rowsServer = await serveStatic(rowsDir, { handle });
  try {
    await hydration(t, t.url.replace(/\/$/, ''));
    await registry(t, t.url.replace(/\/$/, ''));
    await rows(t, `http://127.0.0.1:${rowsServer.address().port}`);
  } finally {
    await closeServer(rowsServer);
  }
});

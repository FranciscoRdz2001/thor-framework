// The adversarial battery of the threat model:
// what a hostile string, URL, JSON or attribute does in a real browser.
//
//   A. A page the server rendered from hostile data (packages/thor_ui/tool/
//      security_pages.dart): text, semantic labels, fields, links, a state's
//      JSON, a keyed list and `HtmlWidget` content. Nothing runs
//      (`window.__pwned` stays unset), no element or attribute is born of a
//      string, the data survives as data, and a link that runs code is inert.
//   B. The lite runtime (the real file, in pages made by hand) against a
//      malformed or hostile `#thor-state` (broken JSON, `__proto__` and
//      `constructor` keys at any depth, wrong types, huge values), against
//      forged `data-t-on` ids (`constructor`, `__proto__`, ids of 100 000
//      characters), against row keys that are `__proto__`, `a~b`, `{{key}}`,
//      `$&`, markup or 5 000 characters, and against oversized arguments and
//      lists. The page keeps working and nothing is polluted or called.
//
//   tool/thor e2e security                      (renders the page, serves, runs)
//   node test/e2e/checks/security_check.mjs
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { closeServer, e2e, repo, serveStatic, settle } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
// Keyed lists are the runtime's part `lists`, sewn in first (an older
// runtime, without that part next to it, has them inside).
const withLists = (src, at) => {
  const p = join(dirname(at), 'parts/lists.js');
  return src.replace('// @thor-lite-parts', () => `${existsSync(p) ? readFileSync(p, 'utf8') : ''}\n// @thor-lite-parts`);
};
const runtimePath = join(lite, 'runtime.js');
const runtime = withLists(readFileSync(runtimePath, 'utf8'), runtimePath);
const part = (n) => readFileSync(join(lite, 'parts', n), 'utf8');
const bundle = (...parts) => runtime.replace('// @thor-lite-parts', () => parts.map(part).join('\n'));

const dir = mkdtempSync(join(tmpdir(), 'thor-security-'));
let server;

// The strings of tool/security_pages.dart (kept in step with it: the check
// reads them back from the page, so a change there fails here).
const unsafeSchemes = /^(javascript|vbscript|data):/i;

async function run(t) {
  execFileSync('dart', ['run', 'tool/security_pages.dart', dir], {
    cwd: join(repo, 'packages/thor_ui'),
    stdio: ['ignore', 'inherit', 'inherit'],
  });
  server = await serveStatic(dir, { handle: handleLite });
  const base = `http://127.0.0.1:${server.address().port}`;

  await rendered(t, base);
  await hydration(t, base);
  await registry(t, base);
  await rows(t, base);
  await oversized(t, base);
}

// ---------------------------------------------------------------------------
// A. The page the server rendered.
async function rendered(t, base) {
  for (const js of [false, true]) {
    const label = js ? 'rendered (JS)' : 'rendered (no JS)';
    const page = await t.page({ javaScriptEnabled: js, viewport: { width: 1000, height: 900 } });
    await watch(page);
    // The page has no app behind it: an empty engine, or its loader reloads.
    await page.route('**/engine.dart.js', (r) => r.fulfill({ contentType: 'text/javascript', body: '' }));
    await page.goto(`${base}/security.html`);
    await page.waitForTimeout(300);

    const dom = await page.evaluate(() => {
      const known = ['thor-debug-inspector', 'thor-state'];
      return {
        // Elements that only a string could have made (an <img src> is what the sanitizer lets through).
        born: [...document.querySelectorAll('img, svg, math, iframe, object, embed, frame, form')].filter((e) => !e.closest('[data-thor="HtmlWidget"]') || !['IMG'].includes(e.tagName)).length,
        scripts: [...document.querySelectorAll('script')].map((s) => s.id || s.getAttribute('data-thor-engine') || (s.src ? `src:${s.getAttribute('src')}` : s.type || 'inline')),
        handlers: [...document.querySelectorAll('*')].flatMap((e) => [...e.attributes].filter((a) => /^on/i.test(a.name)).map((a) => `${e.tagName}.${a.name}`)),
        styleTags: document.querySelectorAll('style').length,
        links: [...document.querySelectorAll('a')].map((a) => ({ text: a.textContent, href: a.getAttribute('href'), protocol: a.protocol })),
        labels: [...document.querySelectorAll('[aria-label]')].map((e) => e.getAttribute('aria-label')),
        fields: [...document.querySelectorAll('input')].map((e) => ({ value: e.value, placeholder: e.placeholder, label: e.getAttribute('aria-label') })),
        body: document.body.textContent,
        state: document.getElementById('thor-state')?.textContent ?? null,
        keys: [...document.querySelectorAll('[data-tk]')].map((e) => e.getAttribute('data-tk')),
        html: [...document.querySelectorAll('[data-thor="HtmlWidget"], [class]')].length,
      };
    });
    t.check(`${label}: nothing ran`, page.hits.length === 0, page.hits.join(','));
    t.check(`${label}: no element was born of a string`, dom.born === 0, String(dom.born));
    // The engine's loader adds its own <script src> (no id) once the page is idle.
    t.check(`${label}: the page's scripts are its own`, dom.scripts.every((s) => ['thor-debug-inspector', 'thor-state', 'engine.dart.js', 'src:engine.dart.js'].includes(s)), dom.scripts.join(', '));
    t.check(`${label}: no event handler attribute came out of a string`, dom.handlers.length === 0, dom.handlers.join(', '));

    // The strings come back as they went in.
    const expected = HOSTILE_TEXT;
    t.check(`${label}: every hostile string is text on the page`, expected.every((h) => dom.body.includes(h)), expected.filter((h) => !dom.body.includes(h)).join(' | '));
    t.check(`${label}: and the label of an element`, expected.every((h) => dom.labels.includes(h)), expected.filter((h) => !dom.labels.includes(h)).join(' | '));
    t.check(
      `${label}: and the value, hint and label of a field`,
      expected.every((h) => dom.fields.some((f) => f.value === h && f.placeholder === h)),
      JSON.stringify(dom.fields.slice(0, 2)),
    );
    const queries = expected.every((h) => dom.links.some((l) => l.href === `/page?q=${h}`));
    t.check(`${label}: and the query of a link (the attribute is the text, nothing more)`, queries, dom.links.slice(0, 3).map((l) => l.href).join(' | '));

    // The links that run code.
    const code = dom.links.filter((l) => /^url \d$/.test(l.text));
    t.check(`${label}: all ${HOSTILE_URLS} code URLs are links on the page`, code.length === HOSTILE_URLS, String(code.length));
    t.check(
      `${label}: a link that would run code has no such href`,
      code.every((l) => l.href === null || !/^[\s\u0000-\u001f]*(javascript|vbscript|data)\s*:/i.test(l.href.replace(/[\t\n\r]/g, ''))),
      JSON.stringify(code.filter((l) => l.href !== null).map((l) => l.href)),
    );
    // The state as `#thor-state`: JSON the browser parses to the same strings.
    const state = JSON.parse(dom.state);
    t.check(`${label}: #thor-state is JSON of the same strings`, state['HostileState.names'].length === HOSTILE_TEXT.length + 3 && HOSTILE_TEXT.every((h) => state['HostileState.names'].includes(h)), dom.state?.slice(0, 120));
    t.check(`${label}: its text can not close the script (every < is escaped)`, !/<\//.test(dom.state) && !/<!--/.test(dom.state), dom.state?.slice(0, 120));
    t.check(`${label}: the keyed list's keys are the strings`, HOSTILE_TEXT.every((h) => dom.keys.includes(h)), dom.keys.join(' | ').slice(0, 200));

    // What the sanitizer let through of the HTML a user wrote.
    const html = await page.evaluate(() =>
      [...document.querySelectorAll('[data-thor="HtmlWidget"]')].map((w) => ({
        banned: w.querySelectorAll('script, style, iframe, svg, math, form, input, button, object, embed, template, noscript').length,
        handlers: [...w.querySelectorAll('*')].flatMap((e) => [...e.attributes].filter((a) => /^on|^style$|^id$|^srcdoc$|^data-/i.test(a.name)).map((a) => a.name)),
        links: [...w.querySelectorAll('a')].map((a) => a.getAttribute('href')),
        text: w.textContent,
      })),
    );
    t.check(`${label}: HtmlWidget: ${html.length} hostile snippets, none keeps a script, frame, form or handler`, html.length >= 13 && html.every((h) => h.banned === 0 && h.handlers.length === 0), JSON.stringify(html.filter((h) => h.banned || h.handlers.length)).slice(0, 300));
    t.check(`${label}: HtmlWidget: no link runs code`, html.every((h) => h.links.every((l) => !/^[\s\u0000-\u001f]*(javascript|vbscript|data)\s*:/i.test((l ?? '').replace(/[\t\n\r]/g, '')))), JSON.stringify(html.flatMap((h) => h.links)));
    t.check(`${label}: HtmlWidget: the clean part is kept`, html[0].text.includes('fine bold') && html.some((h) => h.links.includes('https://example.com/x')), html[0]?.text);
    t.check(`${label}: HtmlWidget: a forged #thor-state or hook has no id and no data-t-on`, (await page.locator('#thor-state').count()) === 1 && (await page.locator('[data-t-on][data-tx=forged]').count()) === 0);
    if (js) {
      let navigated = 0;
      page.on('framenavigated', () => navigated++);
      const before = page.url();
      for (let i = 0; i < HOSTILE_URLS; i++) {
        await page.getByText(`url ${i}`, { exact: true }).click({ force: true, timeout: 2000 }).catch(() => {});
      }
      await page.waitForTimeout(200);
      t.check(`${label}: following every one of them runs nothing`, page.hits.length === 0, page.hits.join(','));
      t.check(`${label}: and goes nowhere`, page.url() === before && navigated === 0, `${page.url()} (${navigated} navigations)`);
    }

    t.check(`${label}: no page errors`, page.problems.filter((p) => !/Failed to load resource/.test(p)).length === 0, page.problems.join(' | '));
    await page.context().close();
  }
}

// The strings of the fixture, in the same order as tool/security_pages.dart.
const HOSTILE_TEXT = [
  '"><img src=x onerror="window.__pwned=\'attribute\'">',
  "'><svg/onload=window.__pwned='svg'>",
  '</script><script>window.__pwned="script"</script>',
  '</style><script>window.__pwned="style"</script>',
  '<!--<script>window.__pwned="comment"</script>-->',
  '</textarea><script>window.__pwned="textarea"</script>',
  '  ',
  '&lt;b&gt; &#60;b&#62; &amp; &#x3c;',
  '{{key}} $& %7E ~ ; __proto__ constructor',
];
const HOSTILE_URLS = 8;

// ---------------------------------------------------------------------------
// B. The lite runtime, in pages made by hand.
const pages = new Map();
function handleLite(req, res) {
  const url = new URL(req.url, 'http://x');
  const make = pages.get(url.pathname);
  if (!make) return false;
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
  res.end(make(url.searchParams));
  return true;
}

// (`#thor-state` is written the way the server writes it: every `<` as \u003c.)
// A page with one state, `C`: a counter, a text, a keyed list of strings
// whose rows have a button that reports its key, and a button that does
// not exist in the state. `thorState` is the text of `#thor-state`.
const statePage = (thorState, { json = false, extra = '' } = {}) => `<!DOCTYPE html><html><head><base href="/"></head><body>
<button id="inc" data-t-on="click:C.inc">+</button><span id="n" data-tt="C.label">0</span><span id="tag" data-tt="C.tag">-</span>
<ul id="rows" data-tl="C.items" data-tlk="C.key"><template data-tlt="C.items"><li><button class="row" data-t-on="click:C.pick" data-tx="{{key}}"><b data-tf="C.text"></b></button></li></template></ul>
${extra}
<script type="application/json" id="thor-state">${thorState.replace(/</g, '\\u003c')}</script>
<script>${bundle(...(json ? ['json.js'] : []))}
window.picked = [];
thor.def('C', ($) => {
  const count = $.state('count', 0), tag = $.state('tag', '-'), items = $.state('items', []);
  return {
    label: () => String(count.value), tag: () => String(tag.value).slice(0, 40),
    items: () => items.value, key: (i) => (i && i.k !== undefined ? i.k : i), text: (i) => (i && i.k !== undefined ? i.k : i),
    inc: () => { count.value = typeof count.value === 'number' ? count.value + 1 : 1; },
    pick: (k) => { window.picked.push(k); },
  };
});
</script></body></html>`;

// The payloads are kept here, not in the URL (10 MB does not fit in one).
const stash = new Map();
pages.set('/state', (q) => statePage(stash.get(q.get('c')) ?? q.get('s') ?? '{}', { json: q.get('json') === '1' }));

const opened = async (t, url, options) => {
  const page = await t.page(options);
  await watch(page);
  await page.goto(url);
  return page;
};

// Every payload sets `window.__pwned`: the setter reports it to the console, so a
// document replaced by a `javascript:` URL (its window goes with it) still counts.
async function watch(page) {
  page.hits = [];
  await page.addInitScript(() => {
    Object.defineProperty(window, '__pwned', { configurable: true, set: (v) => console.log(`PWNED:${v}`), get: () => undefined });
  });
  page.on('console', (m) => m.text().startsWith('PWNED:') && page.hits.push(m.text().slice(6)));
}

const polluted = (page) =>
  page.evaluate(() => ({
    proto: Object.keys(Object.prototype),
    probe: ({}).polluted ?? ({}).isAdmin ?? null,
    array: Object.keys(Array.prototype),
  })).then((w) => ({ ...w, pwned: page.hits.length ? page.hits.join(',') : null }));

async function hydration(t, base) {
  const big = (n) => 'x'.repeat(n);
  const cases = [
    // [label, #thor-state text, what the page must show after the first tap]
    ['broken JSON', '{"C.count": 5', { n: '1', error: /not valid JSON/ }],
    ['an array', '[1, 2, 3]', { n: '1' }],
    ['null', 'null', { n: '1' }],
    ['a string', '"C.count"', { n: '1' }],
    ['a number', '123', { n: '1' }],
    ['empty', '', { n: '1' }],
    ['a byte order mark', '﻿{"C.count": 9}', { n: '1', error: /not valid JSON/ }],
    ['a restored field', '{"C.count": 5}', { n: '6' }],
    ['duplicate keys (the last wins)', '{"C.count": 1, "C.count": 2}', { n: '3' }],
    ['__proto__ at the top', '{"__proto__": {"polluted": true, "isAdmin": true}, "C.count": 6}', { n: '7' }],
    ['constructor.prototype at the top', '{"constructor": {"prototype": {"polluted": true}}, "C.count": 7}', { n: '8' }],
    ['__proto__ inside a list item', '{"C.items": [{"k": "a", "__proto__": {"polluted": true}}, {"__proto__": {"polluted": true}, "k": "b"}]}', { n: '1', rows: 2 }],
    ['__proto__ nested deep', '{"C.items": [{"k": "a", "x": {"y": {"__proto__": {"polluted": true}}}}]}', { n: '1', rows: 1 }],
    ['__proto__ as a field name of the state', '{"C.__proto__": 1, "C.constructor": 2, "C.count": 3}', { n: '4' }],
    ['wrong types', '{"C.count": "x", "C.items": 5, "C.tag": {"a": 1}}', { survives: true }],
    ['null for a list', '{"C.items": null, "C.count": 4}', { survives: true }],
    ['an object where a list goes', '{"C.items": {"0": "a", "length": 3}}', { survives: true }],
    ['an infinite number', '{"C.count": 1e999}', { survives: true }],
    ['a 10 MB string', JSON.stringify({ 'C.tag': big(10_000_000), 'C.count': 2 }), { n: '3' }],
    ['20 000 levels of nesting', `{"C.items": ${'['.repeat(20_000)}${']'.repeat(20_000)}}`, { survives: true }],
    ['100 000 unknown fields', JSON.stringify(Object.fromEntries(Array.from({ length: 100_000 }, (_, i) => [`Nope.f${i}`, i]))), { n: '1' }],
  ];
  for (const json of [false, true]) {
    for (const [name, text, want] of cases) {
      const label = `#thor-state ${json ? '(json part) ' : ''}${name}`;
      stash.set(name, text);
      const url = `${base}/state?json=${json ? 1 : 0}&c=${encodeURIComponent(name)}`;
      const page = await opened(t, url);
      let pageErrors = [];
      page.on('pageerror', (e) => pageErrors.push(e.message));
      await page.click('#inc').catch(() => {});
      await page.waitForTimeout(60);
      const n = await page.locator('#n').textContent();
      const rows = await page.locator('#rows li').count();
      const where = await polluted(page);
      const clean = where.proto.length === 0 && where.array.length === 0 && where.probe === null && where.pwned === null;
      t.check(`${label}: nothing is polluted`, clean, JSON.stringify(where));
      if (want.n !== undefined) t.check(`${label}: the page shows ${want.n}`, n === want.n, n);
      if (want.rows !== undefined) t.check(`${label}: ${want.rows} rows`, rows === want.rows, String(rows));
      if (want.survives) {
        // The state may be nonsense, the page is not: another tap still works.
        const handled = await page.evaluate(() => typeof window.thor?.use === 'function');
        t.check(`${label}: the page survives`, handled && (await page.locator('#inc').isVisible()));
      }
      const errors = page.problems.filter((p) => !/Failed to load resource/.test(p));
      if (want.error) t.check(`${label}: says so in the console`, errors.some((e) => want.error.test(e)), errors.join(' | '));
      else if (!want.survives) t.check(`${label}: no page error`, pageErrors.length === 0 && errors.every((e) => /not valid JSON|reportError/.test(e) === false), `${pageErrors.join(' | ')} ${errors.join(' | ')}`.slice(0, 300));
      await page.context().close();
    }
  }
}

// Forged ids in `data-t-on`: what is not a state's own function is ignored.
async function registry(t, base) {
  const forged = [
    'C.constructor', 'C.__proto__', 'C.toString', 'C.hasOwnProperty', 'C.valueOf', 'C.__defineGetter__',
    '__proto__.polluted', 'constructor.constructor', 'Object.assign', 'Function.call', 'window.alert',
    'C.nope', 'Nope.inc', 'C.', '.inc', 'C', '', 'C..inc', 'C.inc.x', 'C #1.inc', 'C#.inc', 'C.inc;C.inc',
    'javascript:window.__pwned=1', 'C.inc\nwindow.__pwned=1', `C.${'a'.repeat(100_000)}`, `${'A'.repeat(100_000)}.inc`,
    'C.inc~'.repeat(1000), '\u0000C.inc', 'c.inc', 'C.INC', 'C.іnc',
  ];
  const forgeds = forged.map((id, i) => `<button class="forged" id="f${i}" data-t-on="click:${id.replace(/&/g, '&amp;').replace(/"/g, '&quot;')}">f${i}</button>`).join('');
  pages.set('/forged', () => statePage('{}', { extra: forgeds }));
  const page = await opened(t, `${base}/forged`);
  await page.addInitScript(() => {});
  await page.evaluate(() => {
    window.__calls = [];
    for (const k of ['alert']) {
      const original = window[k];
      window[k] = (...a) => (window.__calls.push(k), original?.apply(window, a));
    }
  });
  for (let i = 0; i < forged.length; i++) await page.click(`#f${i}`, { timeout: 2000 }).catch(() => {});
  await page.waitForTimeout(100);
  const n = await page.locator('#n').textContent();
  const where = await polluted(page);
  const calls = await page.evaluate(() => window.__calls);
  t.check(`forged data-t-on ids (${forged.length}): none ran code`, where.pwned === null && calls.length === 0, JSON.stringify([where.pwned, calls]));
  t.check('forged data-t-on ids: nothing is polluted', where.proto.length === 0 && where.array.length === 0, JSON.stringify(where));
  // Of them all, `C.inc;C.inc` has two handlers (both are the state's own functions) and `C.inc~...` calls inc with an argument.
  t.check('forged data-t-on ids: only the state\'s own functions ran', ['0', '1', '2', '3', '4', '5'].includes(n) || Number(n) >= 0, n);
  await page.click('#inc');
  t.check('forged data-t-on ids: the real button still works', Number(await page.locator('#n').textContent()) === Number(n) + 1);
  t.check('forged data-t-on ids: no page errors', page.problems.filter((p) => !/Failed to load resource/.test(p)).length === 0, page.problems.join(' | '));
  await page.context().close();
}

// Row keys are data: whatever they say, a row is a row.
async function rows(t, base) {
  const keys = [
    '__proto__', 'constructor', 'toString', 'hasOwnProperty', 'a~b', 'a;b', 'a%7Eb', '50%', '%', '%7E', '{{key}}', '$&', '$1', "'\"><img src=x onerror=\"window.__pwned='row'\">",
    '</script><script>window.__pwned="row2"</script>', 'x'.repeat(5000), 'é中😀', ' leading and trailing ', '',
  ];
  const state = JSON.stringify({ 'C.items': keys });
  for (const json of [false, true]) {
    const label = `row keys ${json ? '(json part) ' : ''}`;
    stash.set('rows', state);
    const page = await opened(t, `${base}/state?json=${json ? 1 : 0}&c=rows`);
    await page.click('#inc'); // wakes the state: the rows are made from the template
    await page.waitForTimeout(100);
    const made = await page.evaluate(() => [...document.querySelectorAll('#rows li')].map((li) => ({ text: li.querySelector('b')?.textContent, tx: li.querySelector('button')?.getAttribute('data-tx'), tk: li.getAttribute('data-tk') })));
    const where = await polluted(page);
    t.check(`${label}${keys.length} hostile keys make ${keys.length} rows`, made.length === keys.length, String(made.length));
    t.check(`${label}each row's text is its key, as text`, keys.every((k, i) => made[i]?.text === k), JSON.stringify(made.map((m) => m.text)).slice(0, 200));
    t.check(`${label}no element was born of a key`, (await page.locator('#rows img, #rows script, #rows svg, #rows iframe, #rows [onerror], #rows [onclick]').count()) === 0 && where.pwned === null, JSON.stringify(where));
    t.check(`${label}nothing is polluted`, where.proto.length === 0, JSON.stringify(where));
    // Tap each row: the state hears one key per tap, and it is the row's own.
    await page.evaluate(() => (window.picked.length = 0));
    for (let i = 0; i < keys.length; i++) await page.locator('#rows li button').nth(i).click({ timeout: 2000 }).catch(() => {});
    const picked = await page.evaluate(() => window.picked);
    t.check(`${label}one tap, one call each (${keys.length})`, picked.length === keys.length, String(picked.length));
    const same = keys.filter((k, i) => picked[i] === k);
    t.check(`${label}the key a row sends is its own`, same.length === keys.length, keys.filter((k, i) => picked[i] !== k).map((k) => `${k.slice(0, 20)} -> ${String(picked[keys.indexOf(k)]).slice(0, 20)}`).join(' | '));
    t.check(`${label}no page errors`, page.problems.filter((p) => !/Failed to load resource/.test(p)).length === 0, page.problems.join(' | '));
    await page.context().close();
  }
}

// Sizes: an argument of 2 MB, a list of 20 000 rows, 20 000 handlers.
async function oversized(t, base) {
  pages.set('/big', () => {
    const arg = 'q'.repeat(2_000_000);
    const handlers = Array.from({ length: 20_000 }, (_, i) => `<i data-t-on="click:C.pick" data-tx="${i}"></i>`).join('');
    return statePage(JSON.stringify({ 'C.items': Array.from({ length: 20_000 }, (_, i) => `k${i}`) }), {
      extra: `<button id="huge" data-t-on="click:C.pick" data-tx="${arg}">huge</button><div id="many">${handlers}</div>`,
    });
  });
  const page = await opened(t, `${base}/big`);
  const started = Date.now();
  await page.click('#inc');
  await settle(page, () => document.querySelectorAll('#rows li').length === 20_000, null, { timeout: 15_000 });
  const took = Date.now() - started;
  t.check('a list of 20 000 rows is made from #thor-state', (await page.locator('#rows li').count()) === 20_000);
  t.check(`and in a bounded time (${took} ms)`, took < 12_000, `${took} ms`);
  await page.evaluate(() => (window.picked.length = 0));
  await page.click('#huge');
  const got = await page.evaluate(() => window.picked.map((x) => String(x).length));
  t.check('an argument of 2 MB reaches the method whole, once', got.length === 1 && got[0] === 2_000_000, JSON.stringify(got));
  await page.locator('#many i').nth(19_999).dispatchEvent('click');
  const last = await page.evaluate(() => window.picked.at(-1));
  t.check('the last of 20 000 handlers answers', last === '19999', String(last));
  t.check('no page errors', page.problems.filter((p) => !/Failed to load resource/.test(p)).length === 0, page.problems.join(' | '));
  await page.context().close();
}

await e2e('security', { site: null, timeout: 240_000 }, async (t) => {
  try {
    await run(t);
  } finally {
    await closeServer(server);
    rmSync(dir, { recursive: true, force: true });
  }
});

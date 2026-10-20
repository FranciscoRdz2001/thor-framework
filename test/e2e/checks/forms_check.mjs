// Forms in a real browser: the «sending» state
// of a submitted form and the focus of the first server error, on pages
// made in memory around the real script (packages/thor_ui/lib/src/engine/
// form_script.dart, the one a page with a `Form` inlines) and a small
// server that answers slow, redirects, fails with 422 or downloads.
//
//   tool/thor e2e forms            (no app to build)
//   node test/e2e/checks/forms_check.mjs
//
// - data-pending + aria-busy + disabled submit buttons after a submit
//   nobody cancelled; the clicked button's name/value still goes; no
//   double submit (double click, Enter twice); only the submitted form;
//   cleared on a bfcache restore; nothing on a cancelled submit, a
//   client validation failure, a dialog/_blank/mailto form or an opt-out;
//   works with the engine still loading and with no JS at all.
// - the ways a lock could stay: Stop, a download, <base target>;
//   outside/image submitters, formnovalidate, a later cancel, form.submit(),
//   a real bfcache restore (headless=new), WebKit.
// - the first invalid field is focused after a 422, also inside a closed
//   <details> or a hidden tab.
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { e2e, repo } from './lib/e2e.mjs';
import { chromium, webkit } from '../runner/node_modules/playwright/index.mjs';

const source = readFileSync(join(repo, 'packages/thor_ui/lib/src/engine/form_script.dart'), 'utf8');
const script = /r"""([\s\S]*?)"""/.exec(source)[1];

// A page's own state can't be read with `page.evaluate` while its form is
// being sent (Playwright waits for the navigation to commit), so the page
// reports every change of its forms to the console ("S <json>").
const probe = `<script>const snap=()=>console.log('S '+JSON.stringify([...document.forms].map((f)=>({id:f.id,pending:f.hasAttribute('data-pending'),busy:f.getAttribute('aria-busy'),disabled:[...f.elements,...f.querySelectorAll('input[type=image]')].filter((b)=>b.disabled).map((b)=>b.id)}))));new MutationObserver(snap).observe(document,{subtree:true,attributes:true});addEventListener('pageshow',snap);snap();</script>`;

// The release delay of a lock nothing ended (Stop, a download), 15 s in the
// script: the pages that wait for it run a copy with 1.5 s. (No fake clock:
// a page whose navigation is pending can't be evaluated.)
const RELEASE = '15e3';
const quick = script.replace(RELEASE, '1500');
const doc = (body, { engine = false, s = script } = {}) =>
  `<!doctype html><html><head><meta charset="utf-8"><title>t</title></head><body>${body}<script>${s}</script>${probe}${engine ? '<script async src="/engine.js"></script>' : ''}</body></html>`;

const field = (n, { error = false } = {}) =>
  `<label for="f-${n}">${n}</label><input id="f-${n}" name="${n}" aria-describedby="f-${n}-msg" ${error ? 'aria-invalid="true" autofocus' : ''}><span id="f-${n}-msg">${error ? 'mal ' + n : ''}</span>`;

// The lite runtime, for the page whose engine swaps in a field with an error.
const runtime = readFileSync(join(repo, 'packages/thor_engine/lib/lite/runtime.js'), 'utf8').replace('// @thor-lite-parts', () => '');

const pages = {
  // A state variant that brings a wrong field (autofocus, aria-invalid): the
  // structure changes (span → div), so the engine replaces the subtree.
  '/variant': doc(`<div id="host" data-tv="V.mode"><span>todo bien</span></div><template data-tvt="V.mode" data-i="err"><div><input id="bad" name="bad" autofocus aria-invalid="true"></div></template><input id="other" name="other"><button id="fail" data-t-on="click:V.fail">fallar</button>
<script>${runtime}\nthor.def('V', ($) => { const m = $.state('m', 'ok'); return { mode: () => m.value, fail: () => { m.value = 'err'; } }; });</script>`),
  '/simple': doc(`<form id="f" method="post" action="/slow"><input id="name" name="name" value="x"><button id="save" type="submit" name="intent" value="save">Guardar</button><button id="pub" type="submit" name="intent" value="publish" formaction="/publish">Publicar</button></form>
<form id="g" method="post" action="/slow"><button id="other" type="submit">Otro</button></form>`),
  // The page itself plays a cache restore while the form is sent.
  '/restore': doc(`<form id="f" method="post" action="/slow"><button id="save" type="submit" name="intent" value="save">Guardar</button></form>
<script>document.getElementById('f').addEventListener('submit', () => {
  setTimeout(() => dispatchEvent(new PageTransitionEvent('pageshow', { persisted: false })), 100);
  setTimeout(() => dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true })), 200);
  setTimeout(() => document.getElementById('f').requestSubmit(), 300);
}, { once: true });</script>`),
  '/done': doc('<p id="done">listo</p>'),
  '/validate': doc(`<form id="f" method="post" action="/slow"><input id="req" name="req" required><button id="save" type="submit">Guardar</button></form>`),
  '/cancel': doc(`<form id="f" method="post" action="/slow"><button id="save" type="submit">Guardar</button></form>
<script>let block = true; document.getElementById('f').addEventListener('submit', (e) => { if (block) e.preventDefault(); }); window.unblock = () => (block = false);</script>`),
  '/skip': doc(`<form id="dialog" method="dialog"><button id="d" type="submit">ok</button></form>
<form id="mail" method="post" action="mailto:a@b.c"><button id="m" type="submit">correo</button></form>
<form id="out" method="post" action="/slow" data-t-nopending><button id="o" type="submit">sigue</button></form>
<form id="dl" method="post" action="/download"><button id="dlb" type="submit" formtarget="_blank">bajar</button></form>`),
  '/engine': doc(`<form id="f" method="post" action="/slow"><button id="save" type="submit">Guardar</button></form>`, { engine: true }),
  '/nojs': `<!doctype html><title>t</title><form id="f" method="post" action="/slow"><input name="name" value="x"><button id="save" type="submit" name="intent" value="save">Guardar</button></form>`,
  // A 422 page: the error is in the 3rd field.
  '/errors': doc(`<form method="post" action="/slow">${field('a')}${field('b')}${field('c', { error: true })}${field('d', { error: true })}<button type="submit">ok</button></form>`),
  '/errors-details': doc(`<form method="post" action="/slow">${field('a')}<details id="more"><summary>más</summary>${field('b', { error: true })}</details><button type="submit">ok</button></form>`),
  '/errors-tab': doc(`<style>:root:has(input[name="t"]:checked:not([value="1"])) #t-panel-1 { display: none }</style><form method="post" action="/slow"><div role="radiogroup"><label><input type="radio" name="t" value="0" checked aria-controls="t-panel-0">uno</label><label><input type="radio" name="t" value="1" aria-controls="t-panel-1">dos</label></div>
<div id="t-panel-0" role="group">${field('a')}</div><div id="t-panel-1" role="group">${field('b', { error: true })}</div></form>`),
  // Adversarial cases.
  '/hang': doc(`<form id="f" method="post" action="/hang"><input name="name" value="x"><button id="save" type="submit">Guardar</button></form>`, { s: quick }),
  '/download': doc(`<form id="f" method="post" action="/download"><button id="save" type="submit" name="intent" value="csv">Bajar</button></form>`, { s: quick }),
  '/base-blank': `<!doctype html><html><head><meta charset="utf-8"><title>t</title><base target="_blank"></head><body><form id="f" method="post" action="/slow"><button id="save" type="submit">Guardar</button></form><script>${quick}</script>${probe}</body></html>`,
  '/outside': doc(`<form id="f" method="post" action="/slow"><input name="name" value="x"></form><button id="ext" type="submit" form="f" name="intent" value="ext">fuera</button>`),
  '/image': doc(`<form id="f" method="post" action="/slow"><input id="img" type="image" name="pos" alt="ir" src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width="40" height="40"></form>`),
  '/novalidate': doc(`<form id="f" method="post" action="/slow"><input id="req" name="req" required><button id="save" type="submit" formnovalidate name="intent" value="draft">Borrador</button></form>`),
  '/late-cancel': doc(`<form id="f" method="post" action="/slow"><button id="save" type="submit">Guardar</button></form>
<script>let block = true; addEventListener('submit', (e) => { if (block) e.preventDefault(); }); window.unblock = () => (block = false);</script>`),
  '/direct': doc(`<form id="f" method="post" action="/slow"><button id="save" type="submit">Guardar</button></form>`),
  '/bf': `<!doctype html><html><head><meta charset="utf-8"><title>t</title></head><body><form id="f" method="post" action="/slow"><button id="save" type="submit">Guardar</button></form><script>${script}</script>${probe}</body></html>`,
  '/errors-two': doc(`<form id="one" method="post" action="/slow">${field('a', { error: true })}<button type="submit">ok</button></form><form id="two" method="post" action="/slow">${field('z', { error: true })}<button type="submit">ok</button></form>`),
  '/errors-nested': doc(`<form method="post" action="/slow"><details id="o"><summary>o</summary><details id="i"><summary>i</summary>${field('b', { error: true })}</details></details><button type="submit">ok</button></form>`),
  '/errors-tab-free': doc(`<form method="post" action="/slow"><div id="t-panel-1" role="group" style="display:none">${field('b', { error: true })}</div><button type="submit">ok</button></form>`),
  '/errors-quotes': doc(`<style>div[role=group]:last-of-type{display:none}:root:has(input[value="1"]:checked) div[role=group]:last-of-type{display:block}</style><form method="post" action="/slow"><div role="radiogroup"><label><input type="radio" name="t" value="0" checked aria-controls="p-0">uno</label><label><input id="q'q" type="radio" name="t" value="1" aria-controls='a"b'>dos</label></div><div id="p-0" role="group">${field('a')}</div><div id='a"b' role="group">${field('b', { error: true })}<span id="x">&lt;script&gt;window.pwned=1&lt;/script&gt;</span></div></form>`),
  '/errors-none': doc(`<form method="post" action="/slow">${field('a')}<button type="submit">ok</button></form>`),
};

const posts = [];
const handle = (req, res) => {
  const url = new URL(req.url, 'http://x');
  if (req.method === 'POST') {
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', () => {
      posts.push({ path: url.pathname, body });
      if (url.pathname === '/hang') return; // never answers
      if (url.pathname === '/download') {
        res.writeHead(200, { 'content-type': 'text/csv', 'content-disposition': 'attachment; filename=a.csv' }).end('a,b');
        return;
      }
      setTimeout(() => res.writeHead(303, { location: '/done' }).end(), 500);
    });
    return true;
  }
  if (url.pathname === '/engine.js') return true; // never answers: the engine "still loading"
  const page = pages[url.pathname];
  if (!page) return false;
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': url.pathname === '/bf' ? 'max-age=60' : 'no-store' }).end(page);
  return true;
};

const tmp = mkdtempSync(join(tmpdir(), 'thor-forms-'));
writeFileSync(join(tmp, 'index.html'), '<!doctype html><title>placeholder</title>');
await e2e('forms', { site: tmp, handle, timeout: 90_000 }, async (t) => {
  // The last state a page reported for the form `#id` (see `probe`).
  const state = async (page, id = 'f') => {
    const last = page.snaps.findLast((snap) => snap.some((f) => f.id === id));
    return last?.find((f) => f.id === id);
  };
  const open = async (path, options = {}) => {
    const page = await t.page(options);
    page.snaps = [];
    page.on('console', (m) => m.text().startsWith('S ') && page.snaps.push(JSON.parse(m.text().slice(2))));
    await page.goto(t.url + path.slice(1), { waitUntil: 'domcontentloaded' });
    return page;
  };
  const tick = (page, ms = 60) => page.waitForTimeout(ms);
  const idle = (s) => !s.pending && s.busy === null && s.disabled.length === 0;

  // The sending state and the clicked button's data.
  {
    posts.length = 0;
    const p = await open('/simple');
    t.check('an idle form is not pending', idle(await state(p)));
    await p.click('#pub', { noWaitAfter: true });
    await tick(p);
    const s = await state(p);
    t.check('after submit the form is pending, busy and its submit buttons disabled', s.pending && s.busy === 'true' && s.disabled.join() === 'save,pub', JSON.stringify(s));
    const g = await state(p, 'g');
    t.check('the other form of the page is untouched', idle(g), JSON.stringify(g));
    await p.waitForURL('**/done');
    t.check('the second submitter\'s name/value and formaction reached the server', posts.length === 1 && posts[0].path === '/publish' && /intent=publish/.test(posts[0].body) && /name=x/.test(posts[0].body), JSON.stringify(posts));
    await p.goBack();
    await p.waitForSelector('#f');
    await tick(p);
    const back = await state(p);
    t.check('back navigation leaves the form idle (fresh load or bfcache)', idle(back), JSON.stringify(back));
    await p.close();
  }

  // Double click / Enter twice.
  {
    posts.length = 0;
    const p = await open('/simple');
    await p.locator('#save').dblclick({ noWaitAfter: true });
    await p.waitForURL('**/done');
    t.check('a double click sends one request', posts.length === 1, `${posts.length}`);
    t.check('the clicked button\'s value went with it', /intent=save/.test(posts[0]?.body ?? ''), posts[0]?.body);
    await p.close();

    posts.length = 0;
    const q = await open('/simple');
    await q.focus('#name');
    await q.keyboard.press('Enter');
    await q.keyboard.press('Enter');
    await q.keyboard.press('Enter');
    await q.waitForURL('**/done');
    t.check('Enter three times sends one request', posts.length === 1, `${posts.length}`);
    t.check('Enter sends the default submit button\'s value', /intent=save/.test(posts[0]?.body ?? ''), posts[0]?.body);
    await q.close();

    posts.length = 0;
    const r = await open('/simple');
    await r.click('#save', { noWaitAfter: true });
    await tick(r);
    await r.evaluate(() => document.getElementById('f').requestSubmit(document.getElementById('pub'))).catch(() => {});
    await r.waitForURL('**/done');
    t.check('requestSubmit(other button) while pending is refused', posts.length === 1 && posts[0].path === '/slow', JSON.stringify(posts));
    await r.close();
  }

  // A cache restore (pageshow persisted) while the form is pending: played by
  // the page itself (/restore): 100 ms a pageshow that is not from the cache,
  // 200 ms one that is, 300 ms a new submit.
  {
    posts.length = 0;
    const p = await open('/restore');
    await p.click('#save', { noWaitAfter: true });
    await tick(p, 150);
    t.check('a pageshow that is not from the cache leaves it pending', (await state(p)).pending);
    await tick(p, 100);
    const s = await state(p);
    t.check('pageshow persisted clears pending, aria-busy and disabled', idle(s), JSON.stringify(s));
    await tick(p, 150);
    const again = await state(p);
    t.check('after the restore the form can be sent again', again.pending && posts.length >= 1, JSON.stringify(again));
    await p.waitForURL('**/done');
    await p.close();
  }

  // Cancelled submits leave nothing behind.
  {
    posts.length = 0;
    const p = await open('/validate');
    await p.click('#save', { noWaitAfter: true });
    await tick(p, 150);
    const s = await state(p);
    t.check('a submit blocked by native validation is not pending', idle(s) && posts.length === 0, JSON.stringify(s));
    await p.fill('#req', 'ok');
    await p.click('#save', { noWaitAfter: true });
    await p.waitForURL('**/done');
    t.check('once valid, the form sends', posts.length === 1);
    await p.close();

    const c = await open('/cancel');
    await c.click('#save', { noWaitAfter: true });
    await tick(c, 100);
    const cs = await state(c);
    t.check('a submit another handler cancelled is not pending', idle(cs), JSON.stringify(cs));
    await c.evaluate(() => window.unblock());
    posts.length = 0;
    await c.click('#save', { noWaitAfter: true });
    await c.waitForURL('**/done');
    t.check('after a cancelled submit the next one goes through (once)', posts.length === 1, `${posts.length}`);
    await c.close();
  }

  // Forms the script leaves alone (their navigation is stopped here).
  {
    const p = await open('/skip');
    await p.evaluate(() => {
      for (const f of document.forms) if (f.id !== 'dialog') f.addEventListener('submit', (e) => e.preventDefault());
    });
    for (const [form, btn] of [['dialog', 'd'], ['out', 'o'], ['mail', 'm'], ['dl', 'dlb']]) {
      await p.click(`#${btn}`, { noWaitAfter: true });
      await tick(p, 100);
      const s = await state(p, form);
      t.check(`form "${form}" is never pending`, idle(s), JSON.stringify(s));
    }
    await p.close();
  }

  // The engine has not loaded: the script does not need it.
  {
    posts.length = 0;
    const p = await open('/engine');
    await p.locator('#save').dblclick({ noWaitAfter: true });
    await tick(p);
    const s = await state(p);
    t.check('pending works while the engine has not loaded', s.pending && s.disabled.join() === 'save', JSON.stringify(s));
    await p.waitForURL('**/done');
    t.check('and it sent once', posts.length === 1, `${posts.length}`);
    await p.close();
  }

  // No JavaScript at all: plain HTML.
  {
    posts.length = 0;
    const p = await open('/nojs', { javaScriptEnabled: false });
    await p.click('#save', { noWaitAfter: true });
    await p.waitForURL('**/done');
    t.check('without JS the form still posts, with the button\'s value', posts.length === 1 && /intent=save/.test(posts[0].body), JSON.stringify(posts));
    await p.close();
  }

  // The error focus.
  {
    const p = await open('/errors');
    const id = await p.evaluate(() => document.activeElement?.id);
    t.check('after a 422 the first invalid field (3rd) has focus', id === 'f-c', id);
    await p.close();

    const d = await open('/errors-details');
    const dv = await d.evaluate(() => ({ id: document.activeElement?.id, open: document.getElementById('more').open }));
    t.check('a field inside a closed <details> is revealed and focused', dv.id === 'f-b' && dv.open, JSON.stringify(dv));
    await d.close();

    const tab = await open('/errors-tab');
    const tv = await tab.evaluate(() => ({ id: document.activeElement?.id, checked: document.querySelector('input[value="1"]').checked }));
    t.check('a field in a hidden tab selects the tab and takes focus', tv.id === 'f-b' && tv.checked, JSON.stringify(tv));
    await tab.close();

    const v = await open('/variant');
    await v.evaluate(() => document.getElementById('other').focus());
    await v.click('#fail');
    await tick(v, 100);
    const vid = await v.evaluate(() => document.activeElement?.id);
    t.check('an engine swap that brings a wrong field focuses it', vid === 'bad', vid);
    await v.close();

    const n = await open('/errors-none');
    t.check('no error, no focus stolen', (await n.evaluate(() => document.activeElement?.tagName)) === 'BODY');
    await n.close();

    const j = await open('/errors', { javaScriptEnabled: false });
    // `autofocus` is the browser's, and WebKit applies it only to a page that has the focus.
    await j.bringToFront();
    await j.reload();
    // It may take a moment to be granted (several browsers run side by side).
    let jid = '';
    for (let i = 0; i < 40 && jid !== 'f-c'; i++) {
      jid = await j.evaluate(() => document.activeElement?.id).catch(() => 'n/a');
      if (jid !== 'f-c') await new Promise((r) => setTimeout(r, 75));
    }
    t.check('without JS the native autofocus still works', jid === 'f-c', jid);
    await j.close();
  }

  // ---- Adversarial cases: the ways a locked form could stay locked. ----
  const clocked = open;
  t.check('break: the script has one release delay (15e3)', script.split(RELEASE).length === 2);
  const stop = async (page) => (await page.context().newCDPSession(page)).send('Page.stopLoading');

  // The browser's Stop button (or Esc): the navigation ends and the page
  // stays; nothing tells the page. The form must not stay locked forever.
  // (Chromium only: the Stop button is Chrome DevTools Protocol's `Page.stopLoading`.)
  if ((process.env.E2E_BROWSER ?? 'chromium') === 'chromium') {
    posts.length = 0;
    const p = await clocked('/hang');
    await p.click('#save', { noWaitAfter: true });
    await tick(p, 100);
    t.check('break: a form waiting for a slow answer is pending', (await state(p)).pending);
    await tick(p, 500);
    t.check('break: a slow answer still holds the lock inside the delay (no double submit)', (await state(p)).pending);
    await stop(p);
    await tick(p, 2200);
    const s = await state(p);
    t.check('break: after Stop the form is not locked forever', idle(s), JSON.stringify(s));
    await p.click('#save', { noWaitAfter: true, timeout: 1000 }).catch(() => {});
    await tick(p, 200);
    t.check('break: and it can be sent again (pending anew)', (await state(p)).pending && posts.length === 2, `${posts.length}`);
    await p.close();
  }

  // The answer is a download: no pagehide, the page stays.
  {
    posts.length = 0;
    const p = await clocked('/download');
    await p.click('#save', { noWaitAfter: true });
    await tick(p, 200);
    t.check('break: a download answer leaves the form pending at first', (await state(p)).pending);
    await tick(p, 2000);
    const s = await state(p);
    t.check('break: a download answer does not lock the form forever', idle(s), JSON.stringify(s));
    await p.close();
  }

  // <base target=_blank> sends the form to a new tab (the form has no target).
  {
    posts.length = 0;
    const p = await clocked('/base-blank');
    const popup = p.waitForEvent('popup').catch(() => null);
    await p.click('#save', { noWaitAfter: true });
    await tick(p, 200);
    (await popup)?.close().catch(() => {});
    await tick(p, 2000);
    const s = await state(p);
    t.check('break: a form sent to a new tab through <base target> is not locked forever', idle(s), JSON.stringify(s));
    await p.close();
  }

  // A submit button outside the form (form="id").
  {
    posts.length = 0;
    const p = await open('/outside');
    await p.click('#ext', { noWaitAfter: true });
    await tick(p);
    const s = await state(p);
    t.check('break: an outside button (form=id) is disabled with the form', s.pending && s.disabled.join() === 'ext', JSON.stringify(s));
    await p.waitForURL('**/done');
    t.check('break: the outside button\'s name/value went', posts.length === 1 && /intent=ext/.test(posts[0].body), JSON.stringify(posts));
    await p.close();
  }

  // <input type=image>: the coordinates go, then it is disabled.
  {
    posts.length = 0;
    const p = await open('/image');
    await p.click('#img', { position: { x: 7, y: 9 }, noWaitAfter: true });
    await tick(p);
    const s = await state(p);
    t.check('break: an image submitter is disabled while sending', s.pending && s.disabled.join() === 'img', JSON.stringify(s));
    await p.waitForURL('**/done');
    t.check('break: the image submitter\'s coordinates went', posts.length === 1 && /pos\.x=7/.test(posts[0].body) && /pos\.y=9/.test(posts[0].body), JSON.stringify(posts));
    await p.close();
  }

  // formnovalidate: the submit goes even with an invalid field.
  {
    posts.length = 0;
    const p = await open('/novalidate');
    await p.click('#save', { noWaitAfter: true });
    await p.waitForURL('**/done');
    t.check('break: formnovalidate submits and keeps the button\'s value', posts.length === 1 && /intent=draft/.test(posts[0].body), JSON.stringify(posts));
    await p.close();
  }

  // A cancel from a listener that runs after the script's (window, bubbling).
  {
    posts.length = 0;
    const p = await open('/late-cancel');
    await p.click('#save', { noWaitAfter: true });
    await tick(p, 100);
    t.check('break: a window listener that cancels afterwards leaves it idle', idle(await state(p)), JSON.stringify(await state(p)));
    await p.evaluate(() => window.unblock());
    await p.click('#save', { noWaitAfter: true });
    await p.waitForURL('**/done');
    t.check('break: and the next submit goes through once', posts.length === 1, `${posts.length}`);
    await p.close();
  }

  // form.submit() fires no submit event: nothing to hook (Turbo, Rails UJS
  // and htmx don't see it either). Documented behavior, checked so it stays.
  {
    posts.length = 0;
    const p = await open('/direct');
    await p.evaluate(() => document.getElementById('f').submit());
    await p.waitForURL('**/done');
    t.check('break: form.submit() still posts (no state, no crash)', posts.length === 1 && p.problems.length === 0, JSON.stringify(p.problems));
    await p.close();
  }

  // A real bfcache restore (Chromium with it enabled), not a simulated one.
  {
    const browser = await chromium.launch({ headless: false, args: ['--headless=new'], ignoreDefaultArgs: ['--disable-back-forward-cache'] }); // the old headless shell never keeps pages in the cache
    const ctx = await browser.newContext();
    const p = await ctx.newPage();
    p.snaps = [];
    p.on('console', (m) => m.text().startsWith('S ') && p.snaps.push(JSON.parse(m.text().slice(2))));
    await p.addInitScript(() => addEventListener('pageshow', (e) => console.log('P ' + e.persisted)));
    const shows = [];
    p.on('console', (m) => m.text().startsWith('P ') && shows.push(m.text()));
    await p.goto(t.url + 'bf', { waitUntil: 'domcontentloaded' });
    await p.click('#save', { noWaitAfter: true });
    await tick(p, 100);
    await p.waitForURL('**/done');
    await p.goBack({ waitUntil: 'commit' }); // a restore fires no load
    await tick(p, 500);
    const restored = shows.includes('P true');
    const s = await state(p);
    t.check(`break: after a real back navigation the form is idle (bfcache ${restored ? 'used' : 'NOT used by this Chromium'})`, s && idle(s), JSON.stringify(s));
    t.check('break: a real bfcache restore fired pageshow persisted', restored, shows.join());
    await browser.close();
  }

  // The error focus, adversarial.
  {
    const two = await open('/errors-two');
    t.check('two forms with errors: the first in the page has the focus', (await two.evaluate(() => document.activeElement?.id)) === 'f-a');
    await two.close();

    const nest = await open('/errors-nested');
    const nv = await nest.evaluate(() => ({ id: document.activeElement?.id, o: document.getElementById('o').open, i: document.getElementById('i').open }));
    t.check('a field in two closed <details> opens both and takes focus', nv.id === 'f-b' && nv.o && nv.i, JSON.stringify(nv));
    await nest.close();

    const free = await open('/errors-tab-free');
    t.check('a hidden panel no tab controls: no crash', free.problems.length === 0, JSON.stringify(free.problems));
    await free.close();

    const q = await open('/errors-quotes');
    const qv = await q.evaluate(() => ({ id: document.activeElement?.id, pwned: !!window.pwned, checked: document.querySelector('input[value="1"]').checked }));
    t.check('ids with quotes and error text with markup: tab chosen, focus set, nothing runs', qv.id === 'f-b' && qv.checked && !qv.pwned && q.problems.length === 0, JSON.stringify([qv, q.problems]));
    await q.close();
  }

  // WebKit (Safari's engine), when Playwright has it installed: the same
  // script, another form-submission and focus implementation.
  {
    let wk = null;
    try {
      wk = await webkit.launch();
    } catch (e) {
      console.log(`skip: WebKit is not installed (${String(e.message).split('\n')[0]})`);
    }
    if (wk) {
      const wp = await (await wk.newContext()).newPage();
      wp.snaps = [];
      wp.on('console', (m) => m.text().startsWith('S ') && wp.snaps.push(JSON.parse(m.text().slice(2))));
      posts.length = 0;
      await wp.goto(t.url + 'simple', { waitUntil: 'domcontentloaded' });
      await wp.click('#pub', { noWaitAfter: true });
      await tick(wp, 150);
      const ws = await state(wp);
      t.check('WebKit: after submit the form is pending, busy and its submit buttons disabled', ws?.pending && ws.busy === 'true' && ws.disabled.join() === 'save,pub', JSON.stringify(ws));
      await wp.waitForURL('**/done');
      t.check('WebKit: the submitter\'s name/value and formaction reached the server', posts.length === 1 && posts[0].path === '/publish' && /intent=publish/.test(posts[0].body), JSON.stringify(posts));
      await wp.goto(t.url + 'errors-details', { waitUntil: 'domcontentloaded' });
      const wv = await wp.evaluate(() => ({ id: document.activeElement?.id, open: document.getElementById('more').open }));
      t.check('WebKit: a wrong field in a closed <details> is revealed and focused', wv.id === 'f-b' && wv.open, JSON.stringify(wv));
      posts.length = 0;
      await wp.goto(t.url + 'download', { waitUntil: 'domcontentloaded' });
      await wp.click('#save', { noWaitAfter: true });
      await tick(wp, 3000);
      const wd = await state(wp);
      t.check('WebKit: a download answer does not lock the form forever', wd && idle(wd), JSON.stringify(wd));
      await wk.close();
    }
  }
});

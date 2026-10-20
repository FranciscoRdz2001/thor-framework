// Adversarial checks of the keys queued by the inline loader. Every
// scenario holds the engine's request, presses keys, releases it and
// compares with what the same keys do on an already hydrated page ("live").
// Each check was a failing repro; they guard the fix now.
//
//   E2E_SITE=<dir with the lab app build> node test/e2e/checks/early_keys_break_check.mjs
//   E2E_TIMEOUT=300000 CPU=4 ...   (CPU = throttling rate of the page)
import { e2e, hydrated, settle, trackHydration } from './lib/e2e.mjs';

const site = process.env.E2E_SITE ?? 'test/fixtures/apps/lab/build/site';
const cpu = Number(process.env.CPU ?? 1);
const ENGINE = /\/engine\.[a-z]+\.[0-9a-f]+\.js(\?|$)|\/engine\.dart\.js(\?|$)/;

// Extra markup appended to the rows page (real engine state ids).
const INJECT = `<div id="inj">
<input id="plain"><input id="plain2"><textarea id="ta"></textarea>
<input type="checkbox" id="cb">
<button id="nb" type="button" onclick="window.__nb=(window.__nb||0)+1">nb</button>
<form id="pf" action="/post-plain" method="post"><input id="pfin" name="a"><button type="submit">go</button></form>
<form id="nf" action="/post-nested" method="post"><div data-t-on="enter:RowsState.ping"><input id="nestin" name="a" data-t-on="input:RowsState.setDraft"></div></form>
<div id="wrap" data-tks="k>RowsState.ping"><input id="wrapin"><button id="wrapbtn" type="button" data-t-on="click:RowsState.tap">wb</button><textarea id="wrapta"></textarea></div>
<button id="rbtn" type="button" role="button" data-t-on="click:RowsState.tap">rb</button>
<span id="det" role="button" tabindex="0" data-t-on="click:RowsState.tap">d</span>
<form id="ef" action="/post-enterform" method="post"><input id="efin" name="a" data-t-on="enter:RowsState.ping"></form>
<textarea id="tae" data-t-on="enter:RowsState.ping"></textarea>
</div>`;

await e2e('early-keys-break', { site, path: 'rows', timeout: 280_000 }, async (t) => {
  const posts = [];

  /** A page with the engine held (`hold`) or free, extra markup, tracking. */
  async function open({ hold = true, abort = false, inject = true, url = t.url } = {}) {
    const page = await t.page();
    await trackHydration(page);
    await page.addInitScript(() => {
      window.__replays = [];
      window.__keys = [];
      window.__long = 0;
      document.addEventListener(
        'keydown',
        (e) => {
          const id = e.target.id || e.target.tagName;
          if (e.isTrusted) window.__keys.push({ key: e.key, comp: e.isComposing, id, dp: e.defaultPrevented });
          else window.__replays.push({ key: e.key, id, rep: e.repeat, code: e.code, kc: e.keyCode, loc: e.location, ctrl: e.ctrlKey, meta: e.metaKey, shift: e.shiftKey });
        },
        true,
      );
      try {
        new PerformanceObserver((l) => l.getEntries().forEach((x) => (window.__long = Math.max(window.__long, x.duration)))).observe({ type: 'longtask', buffered: true });
      } catch {}
    });
    if (cpu > 1) await (await page.context().newCDPSession(page)).send('Emulation.setCPUThrottlingRate', { rate: cpu });
    let release;
    const gate = new Promise((ok) => (release = ok));
    page.docRequests = 0;
    await page.route(ENGINE, async (route) => {
      if (abort) return route.abort();
      if (hold) await gate;
      await route.continue();
    });
    await page.route(/\/post-[a-z]+$/, (route) => {
      posts.push(new URL(route.request().url()).pathname);
      return route.fulfill({ contentType: 'text/html', body: '<p>posted</p>' });
    });
    if (inject) {
      await page.route((u) => u.pathname === new URL(t.url).pathname, async (route) => {
        page.docRequests++;
        const res = await route.fetch();
        const body = (await res.text()).replace('</main>', `${INJECT}</main>`);
        await route.fulfill({ response: res, body });
      });
    }
    await page.goto(url, { waitUntil: 'domcontentloaded' });
    page.release = release;
    return page;
  }

  const snap = (page) =>
    page
      .evaluate(() => ({
        pings: document.body.innerText.match(/atajos: (\d+)/)?.[1],
        taps: document.body.innerText.match(/toques: (\d+)/)?.[1],
        titles: [...document.querySelectorAll('ul li')].map((li) => li.innerText.split('\n')[0].trim()),
        quick: document.querySelector('#f-quick')?.value,
        ta: document.querySelector('#ta')?.value,
        cb: document.querySelector('#cb')?.checked,
        nb: window.__nb ?? 0,
        plain: document.querySelector('#plain')?.value,
      }))
      .catch(() => null);

  const quiet = (page, ms = 400) => new Promise((ok) => setTimeout(ok, ms));

  /** Runs `keys(page)` on a held page and on a live one; returns both. */
  async function parity(keys) {
    posts.length = 0;
    const a = await open();
    await keys(a);
    const before = { posts: [...posts] };
    a.release();
    await hydrated(a).catch(() => {});
    await quiet(a, 600);
    const pre = { snap: await snap(a), posts: [...posts], before, replays: await a.evaluate(() => window.__replays).catch(() => []) };
    posts.length = 0;
    const b = await open({ hold: false });
    await hydrated(b);
    await keys(b);
    await quiet(b, 600);
    const live = { snap: await snap(b), posts: [...posts] };
    const errs = [...a.problems, ...b.problems];
    await a.context().close();
    await b.context().close();
    return { pre, live, errs };
  }
  const same = (r) => JSON.stringify({ s: r.pre.snap, p: r.pre.posts }) === JSON.stringify({ s: r.live.snap, p: r.live.posts });
  const show = (r) => `pre ${JSON.stringify(r.pre.snap)} posts ${r.pre.posts} | live ${JSON.stringify(r.live.snap)} posts ${r.live.posts}`;
  const brk = (label, ok, detail) => t.check(label, ok, ok ? '' : detail);

  // ---- 1. double handling -------------------------------------------------
  {
    const page = await open();
    await page.keyboard.press('Control+k');
    page.release();
    await hydrated(page);
    await settle(page, () => /atajos: 1/.test(document.body.innerText));
    await page.locator('body').click({ position: { x: 5, y: 5 } });
    await page.keyboard.press('Control+k');
    await settle(page, () => /atajos: 2/.test(document.body.innerText));
    await quiet(page);
    const s = await snap(page);
    brk('a key before hydration plus the same key after runs twice in total, not more', s.pings === '2', `pings ${s.pings}`);
    await page.context().close();
  }
  for (const [key, id] of [['Enter', 'role=button div'], [' ', 'role=button div']]) {
    const page = await open();
    const tap = page.locator('[role=button]', { hasText: 'toques' });
    await tap.focus();
    await page.keyboard.down(key);
    page.release();
    await hydrated(page);
    await quiet(page);
    await page.keyboard.up(key);
    await quiet(page);
    const s = await snap(page);
    brk(`hydration between keydown and keyup of ${JSON.stringify(key)} on a ${id} runs the tap once`, s.taps === '1', `taps ${s.taps}`);
    await page.context().close();
  }
  for (const key of ['Enter', ' ']) {
    const r = await parity(async (p) => {
      await p.locator('#rbtn').focus();
      await p.keyboard.press(key);
    });
    brk(`${JSON.stringify(key)} on a native <button role=button> behaves like live (taps)`, same(r), show(r));
    const r2 = await parity(async (p) => {
      await p.locator('#rbtn').focus();
      await p.keyboard.down(key);
      if (p.release && !(await p.evaluate(() => window.__thorHydrated))) p.release();
      await p.waitForFunction(() => window.__thorHydrated === true).catch(() => {});
      await p.keyboard.up(key);
    });
    brk(`${JSON.stringify(key)} keydown, hydrate, keyup on a native <button role=button> behaves like live`, same(r2), show(r2));
  }

  // ---- 2. native behaviour not stolen -------------------------------------
  {
    const page = await open();
    await page.locator('#plain').focus();
    await page.keyboard.type('hello world');
    await page.keyboard.press('Tab');
    const afterTab = await page.evaluate(() => document.activeElement.id);
    await page.keyboard.press('Shift+Tab');
    const afterShiftTab = await page.evaluate(() => document.activeElement.id);
    await page.locator('#cb').focus();
    await page.keyboard.press(' ');
    await page.locator('#nb').focus();
    await page.keyboard.press(' ');
    await page.keyboard.press('Enter');
    await page.locator('#ta').focus();
    await page.keyboard.type('a');
    await page.keyboard.press('Enter');
    await page.keyboard.type('b');
    const pre = await snap(page);
    const dp = await page.evaluate(() => window.__keys.filter((k) => k.dp).map((k) => `${k.key}@${k.id}`));
    page.release();
    await hydrated(page);
    await quiet(page);
    const post = await snap(page);
    const replays = (await page.evaluate(() => window.__replays)).map((r) => `${r.key}@${r.id}`);
    brk('typing in a plain input types normally', pre.plain === 'hello world', pre.plain);
    brk('typed characters of a plain input are not replayed', !replays.some((r) => /@plain$/.test(r)), replays.join(','));
    brk('Tab and Shift+Tab move focus natively', afterTab === 'plain2' && afterShiftTab === 'plain', `${afterTab} ${afterShiftTab}`);
    brk('Space on a native checkbox toggles once and stays toggled after hydration', pre.cb === true && post.cb === true && !replays.some((r) => /@cb$/.test(r)), `${pre.cb} ${post.cb} ${replays}`);
    brk('Space and Enter on a native button without handlers click natively (2 clicks)', pre.nb === 2 && post.nb === 2, `${pre.nb} ${post.nb}`);
    brk('Enter in a plain textarea inserts a newline and is not replayed', pre.ta === 'a\nb' && !replays.some((r) => /@ta$/.test(r)), JSON.stringify(pre.ta) + replays);
    brk('no plain-element key was preventDefaulted', !dp.some((x) => /@(plain|plain2|cb|nb|ta)$/.test(x)), dp.join(','));
    await page.context().close();
  }
  {
    posts.length = 0;
    const page = await open();
    await page.locator('#pfin').focus();
    await page.keyboard.type('x');
    await page.keyboard.press('Enter');
    await quiet(page, 800);
    brk('Enter in a field of a plain <form> with a server action submits natively before hydration', posts.includes('/post-plain'), `posts ${posts}`);
    await page.context().close();
  }
  {
    const r = await parity(async (p) => {
      await p.locator('#nestin').focus();
      await p.keyboard.type('abc');
      await p.keyboard.press('Enter');
    });
    brk('Enter in a field under an ancestor with enter: (engine uses the closest data-t-on) behaves like live (native submit)', same(r), show(r));
  }
  {
    // The real form of the app (`submit:` handler, `required`, action /nueva).
    posts.length = 0;
    const page = await open();
    await page.locator('#f-title').focus();
    await page.keyboard.type('Tarea larga');
    await page.keyboard.press('Enter');
    page.release();
    await hydrated(page);
    await quiet(page, 600);
    const s = await snap(page);
    brk('Enter in the app form with submit: adds the task once and does not navigate', s.titles.length === 5 && posts.length === 0, `${s.titles.length} posts ${posts}`);
    await page.context().close();
  }
  {
    const r = await parity(async (p) => {
      await p.locator('#tae').focus();
      await p.keyboard.type('a');
      await p.keyboard.press('Enter');
      await p.keyboard.type('b');
    });
    brk('textarea with enter: replays like live', same(r), show(r));
  }
  {
    const r = await parity(async (p) => {
      await p.locator('#wrapin').focus();
      await p.keyboard.type('kk');
      await p.keyboard.press('Control+k');
      await p.locator('#wrapta').focus();
      await p.keyboard.type('kk');
      await p.keyboard.press('Enter');
      await p.locator('#wrapbtn').focus();
      await p.keyboard.press('Enter');
      await p.keyboard.press(' ');
    });
    brk('keys under a data-tks wrapper (fields, button) replay like live', same(r), show(r));
  }

  // ---- 3. IME, dead keys, 229 -------------------------------------------
  {
    const page = await open();
    await page.locator('#f-quick').focus();
    const cdp = await page.context().newCDPSession(page);
    await cdp.send('Input.imeSetComposition', { text: 'にほ', selectionStart: 2, selectionEnd: 2 });
    await cdp.send('Input.dispatchKeyEvent', { type: 'rawKeyDown', key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13 });
    await cdp.send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13 });
    const seen = await page.evaluate(() => window.__keys.filter((k) => k.key === 'Enter'));
    await page.evaluate(() =>
      document.querySelector('#f-quick').dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', isComposing: true, bubbles: true, cancelable: true })),
    );
    const dp = await page.evaluate(() => window.__keys.map((k) => k.dp));
    const own = await page.evaluate(() => window.__replays.length);
    page.release();
    await hydrated(page);
    await quiet(page);
    const s = await snap(page);
    const rep = (await page.evaluate(() => window.__replays)).slice(own).filter((r) => r.key === 'Enter');
    t.check(`(info) CDP composition produced a keydown Enter with isComposing: ${JSON.stringify(seen)}`, true);
    brk('Enter while composing is not replayed and adds no task', rep.length === 0 && s.titles.length === 4, `${JSON.stringify(rep)} titles ${s.titles.length}`);
    brk('a composing Enter is not preventDefaulted by the loader', !dp.some(Boolean), dp.join(','));
    await page.context().close();
  }
  {
    // Safari fires the keydown that commits a composition with
    // isComposing=false and keyCode 229: the same check as the engine's.
    const r = await parity(async (p) => {
      await p.evaluate(() => {
        const f = document.querySelector('#f-quick');
        f.focus();
        f.value = 'compuesto';
        f.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', keyCode: 229, isComposing: false, bubbles: true, cancelable: true }));
      });
    });
    const added = r.pre.snap?.titles?.length === 5;
    t.check('(info, engine-level: live behaves the same) Enter with keyCode 229 and isComposing=false adds a task', true, `added=${added}, live adds=${r.live.snap?.titles?.length === 5}`);
    brk('keyCode 229 Enter replays like live', same(r), show(r));
  }
  {
    const r = await parity(async (p) => {
      const cdp = await p.context().newCDPSession(p);
      await p.locator('body').click({ position: { x: 5, y: 5 } });
      await cdp.send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Dead', code: 'Quote', windowsVirtualKeyCode: 222 });
      await cdp.send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Dead', code: 'Quote', windowsVirtualKeyCode: 222 });
      await p.keyboard.press('Control+k');
    });
    brk('a dead key on <body> plus ⌘K replays like live', same(r), show(r));
  }

  // ---- 4. repeat ------------------------------------------------------
  {
    const r = await parity(async (p) => {
      await p.keyboard.down('Control');
      for (let i = 0; i < 6; i++) await p.keyboard.down('k');
      await p.keyboard.up('k');
      await p.keyboard.up('Control');
    });
    const nrep = r.pre.replays.filter((x) => x.key === 'k').length;
    brk(`holding Ctrl+k (6 keydowns, repeat) replays like live (replays of k: ${nrep})`, same(r), show(r));
    brk('the replay keeps `repeat` on the clones', r.pre.replays.filter((x) => x.key === 'k' && x.rep).length === 5, JSON.stringify(r.pre.replays.filter((x) => x.key === 'k')));
    const r2 = await parity(async (p) => {
      await p.locator('#f-quick').focus();
      await p.keyboard.type('x');
      for (let i = 0; i < 4; i++) await p.keyboard.down('Enter');
      await p.keyboard.up('Enter');
    });
    brk('holding Enter in a field with enter: adds like live', same(r2), show(r2));
  }
  {
    const page = await open();
    await page.keyboard.press('Shift+A');
    await page.keyboard.down('Meta');
    await page.keyboard.press('Enter'); // NumpadEnter-like: location
    await page.keyboard.up('Meta');
    await page.locator('#rbtn').focus();
    await page.evaluate(() =>
      document.querySelector('#rbtn').dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'NumpadEnter', keyCode: 13, location: 3, shiftKey: true, bubbles: true, cancelable: true })),
    );
    page.release();
    await hydrated(page);
    await quiet(page);
    const rep = await page.evaluate(() => window.__replays.find((r) => r.id === 'rbtn' && r.key === 'Enter'));
    brk('the replayed clone keeps code, keyCode, location and modifiers', rep && rep.code === 'NumpadEnter' && rep.kc === 13 && rep.loc === 3 && rep.shift === true, JSON.stringify(rep));
    await page.context().close();
  }

  // ---- 5. ordering ----------------------------------------------------
  {
    const page = await open();
    await page.locator('button', { hasText: 'Invertir' }).click();
    await page.locator('#f-quick').focus();
    await page.keyboard.type('X');
    await page.keyboard.press('Enter');
    await page.locator('button', { hasText: 'Invertir' }).click();
    page.release();
    await hydrated(page);
    await quiet(page, 600);
    const s = await snap(page);
    brk('click, Enter, click replay in order (reverse, add, reverse)', s.titles[0]?.includes('X') && s.titles.length === 5, s.titles.join(' | '));
    await page.context().close();
  }
  {
    // Enter with "ab", the user keeps typing "cd" before hydration: Flutter
    // (and live) submit "ab"; the replay reads the field when it runs.
    const page = await open();
    await page.locator('#f-quick').focus();
    await page.keyboard.type('ab');
    await page.keyboard.press('Enter');
    await page.keyboard.type('cd');
    page.release();
    await hydrated(page);
    await quiet(page, 600);
    const s = await snap(page);
    const added = s.titles.filter((x) => /^(ab|abcd)$/.test(x));
    brk('Enter submits the value typed at the keypress ("ab"), and the later "cd" is not lost', added.includes('ab') && s.quick === 'cd', `titles ${s.titles.join('|')} field "${s.quick}"`);
    await page.context().close();
  }
  {
    // Two Enters with different text in between: each must add its own.
    const page = await open();
    await page.locator('#f-quick').focus();
    await page.keyboard.type('uno');
    await page.keyboard.press('Enter');
    await page.evaluate(() => document.querySelector('#f-quick').select());
    await page.keyboard.type('dos');
    await page.keyboard.press('Enter');
    page.release();
    await hydrated(page);
    await quiet(page, 600);
    const s = await snap(page);
    brk('two Enters with different text add "uno" and "dos" (not "dos" twice)', s.titles.includes('uno') && s.titles.includes('dos'), s.titles.join('|'));
    await page.context().close();
  }

  // ---- 6. detached target ---------------------------------------------
  {
    const page = await open();
    await page.locator('#f-quick').focus();
    await page.keyboard.type('fantasma');
    await page.keyboard.press('Enter');
    await page.locator('#det').focus();
    await page.keyboard.press('Enter');
    await page.locator('body').click({ position: { x: 5, y: 5 } });
    await page.keyboard.press('Control+k');
    await page.evaluate(() => {
      // The field's wrapper div (class names are shortened per build).
      document.querySelector('#f-quick').closest('div').remove();
      document.querySelector('#det').remove();
    });
    page.release();
    await hydrated(page);
    await quiet(page, 600);
    const s = await snap(page);
    brk('replaying on detached targets throws nothing and ⌘K (body) still runs', page.problems.length === 0 && s.pings === '1', `${page.problems.join(';')} pings ${s.pings}`);
    await page.context().close();
  }

  // ---- 7. the engine fails ---------------------------------------------
  {
    const page = await open({ abort: true, hold: false });
    let navs = 0;
    page.on('framenavigated', (f) => f === page.mainFrame() && navs++);
    await page.keyboard.press('Control+k');
    await page.locator('#f-quick').focus();
    await page.keyboard.type('sin motor');
    await page.keyboard.press('Enter');
    await page.locator('#det').focus();
    await page.keyboard.press(' ');
    await quiet(page, 3000);
    const docs = page.docRequests;
    brk('engine fails with keys queued: reloads exactly once, no loop', docs === 2, `document requests ${docs}, navigations ${navs}`);
    const errs = page.problems.filter((p) => !/Failed to load resource|ERR_FAILED/.test(p));
    brk('engine fails with keys queued: no script errors', errs.length === 0, errs.join(';'));
    const s = await snap(page);
    brk('engine fails: the page is still usable natively (typed text still there or page reloaded cleanly)', s !== null, '');
    await page.context().close();
  }

  {
    posts.length = 0;
    const page = await open({ abort: true, hold: false });
    // The loader reloads once when the engine fails, then gives up and stops
    // intercepting. Type only after that: a reload in the middle of the keys
    // (or an Enter it queued and cancelled) is not what this checks. The
    // condition: an Enter on the field is no longer cancelled by the loader.
    for (let ok = false, n = 0; !ok; n++) {
      ok = await page
        .waitForFunction(() => {
          const f = document.querySelector('#efin');
          const e = new KeyboardEvent('keydown', { key: 'Enter', bubbles: true, cancelable: true });
          return !!f && (f.dispatchEvent(e), !e.defaultPrevented);
        }, null, { timeout: 15_000 })
        .then(() => true, (x) => {
          if (n > 3) throw x; // a navigation in the middle of a poll: try again
          return false;
        });
    }
    await page.locator('#efin').focus();
    await page.keyboard.type('x');
    await page.keyboard.press('Enter');
    for (let i = 0; i < 100 && !posts.includes('/post-enterform'); i++) await quiet(page, 50);
    brk('engine never loads: Enter in an enter: field of a <form action> still submits natively (progressive enhancement)', posts.includes('/post-enterform'), `posts ${posts}`);
    await page.context().close();
  }

  // ---- 8. no shortcuts on the page --------------------------------------
  if (process.env.E2E_NOKEYS_SITE) {
    // (the counter app, no data-tks): nothing may be queued or replayed.
  }
  {
    const page = await open({ inject: false });
    await page.evaluate(() => document.querySelectorAll('[data-tks]').forEach((e) => e.removeAttribute('data-tks')));
    for (let i = 0; i < 30; i++) await page.keyboard.press(i % 2 ? 'a' : 'Control+k');
    page.release();
    await hydrated(page);
    await quiet(page);
    const rep = await page.evaluate(() => window.__replays.length);
    const s = await snap(page);
    brk('a page without data-tks queues no body keydown at all (60 presses, 0 replays)', rep === 0 && s.pings === '0', `replays ${rep} pings ${s.pings}`);
    await page.context().close();
  }

  // ---- 9. flood ----------------------------------------------------------
  for (const [label, combo, expectPings] of [
    ['1000 ⌘K', 'Control+k', 1000],
    ['1000 unbound "a"', 'a', 0],
  ]) {
    const page = await open();
    const t0 = Date.now();
    for (let i = 0; i < 1000; i++) await page.keyboard.press(combo);
    const pressed = Date.now() - t0;
    const heap0 = await page.evaluate(() => performance.memory?.usedJSHeapSize ?? 0);
    const t1 = Date.now();
    page.release();
    await hydrated(page);
    const done = await settle(page, (n) => new RegExp(`atajos: ${n}\\b`).test(document.body.innerText), expectPings, { timeout: 30_000 });
    const took = Date.now() - t1;
    const s = await snap(page);
    const long = await page.evaluate(() => Math.round(window.__long));
    const nrep = await page.evaluate(() => window.__replays.length);
    t.check(`(info) flood ${label}: pressed in ${pressed} ms, replay ${took} ms, longest task ${long} ms, replays ${nrep}, heap ${Math.round(heap0 / 1e6)} MB, cpu ${cpu}x`, true);
    brk(`flood ${label}: every ⌘K runs exactly once (${expectPings} pings)`, done && s.pings === String(expectPings), `pings ${s.pings}`);
    brk(`flood ${label}: replay finishes under 2 s and no task blocks over 500 ms`, took < 2000 && long < 500, `took ${took} ms, longest task ${long} ms`);
    t.check(`(info) flood ${label}: ${nrep} clones replayed (no cap, keys with no binding are kept too)`, true);
    await page.context().close();
  }
});

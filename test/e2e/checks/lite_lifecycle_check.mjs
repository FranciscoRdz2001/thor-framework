// The life of a lite state in a real browser: pages made in memory
// from lib/lite/runtime.js and its `lifecycle` part, no app to build.
//
//  - `onHydrated` wakes at idle without an event; a throw is reported and
//    the other states go on; its writes paint.
//  - `dispose` runs once when a keyed list removes the row that held the
//    state's text (the MutationObserver), never for a variant swapped in
//    place, and once for every live state on `pagehide` (not persisted).
//  - Rows added again wake a new instance; a timer started by each
//    `onHydrated` is stopped by its `dispose`; 1000 rows in and out leave no
//    effect on the shared signal and no timer.
//
//   node test/e2e/checks/lite_lifecycle_check.mjs
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { chromium, firefox, webkit } from '../runner/node_modules/playwright/index.mjs';
import { repo } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
// Keyed lists are the runtime's part `lists`, sewn in first (an older
// runtime, without that part next to it, has them inside).
const withLists = (src, at) => {
  const p = join(dirname(at), 'parts/lists.js');
  return src.replace('// @thor-lite-parts', () => `${existsSync(p) ? readFileSync(p, 'utf8') : ''}\n// @thor-lite-parts`);
};
const runtimePath = join(lite, 'runtime.js');
const runtime = withLists(readFileSync(runtimePath, 'utf8'), runtimePath);
const part = readFileSync(join(lite, 'parts/lifecycle.js'), 'utf8');
const page = (body, script) =>
  `<!DOCTYPE html><html><head><base href="/"></head><body>${body}<script>${runtime.replace('// @thor-lite-parts', () => part)}\n${script}</script></body></html>`;

// Each row of the list has a text of its own state `Row#<key>` (the runtime
// puts the row's key in the template's attributes); every Row starts an
// interval when it wakes and stops it when it ends.
const ROWS = page(
  `<ul id="ul" data-tl="L.items" data-tlk="L.key"><template data-tlt="L.items"><li><b data-tf="L.text"></b><i data-tt="Row#{{key}}.label"></i></li></template></ul>`,
  `window.log = [];
window.tick = thor.signal(0);
window.timers = 0;
thor.def('L', ($) => {
  const items = $.state('items', []);
  return { items: () => items.value, key: (i) => i, text: (i) => i, set: (s) => { items.value = s ? s.split(',') : []; } };
});
thor.def('Row', ($) => {
  let iv;
  return {
    label: () => $.key + ':' + tick.value,
    $l: {
      h: () => { log.push('h' + $.key); timers++; iv = setInterval(() => {}, 1000); },
      d: () => { log.push('d' + $.key); timers--; clearInterval(iv); },
    },
  };
}, { idle: true });`,
);

// A state whose text lives inside a variant of another state: the swap puts
// a copy in place of it.
const SWITCH = page(
  `<div id="box"><p data-tv="S.open"><i data-tt="V.label">x</i></p><template data-tvt="S.open" data-i="1"><p data-tv="S.open"><i data-tt="V.label">x</i><b>open</b></p></template></div>`,
  `window.log = [];
thor.def('S', ($) => { const open = $.state('open', false); return { open: () => open.value, toggle: () => { open.value = !open.value; } }; });
thor.def('V', ($) => ({ label: () => 'v', $l: { h: () => log.push('h'), d: () => log.push('d') } }), { idle: true });`,
);

const IDLE = page(
  `<span id="a" data-tt="Good.n">0</span><span id="b" data-tt="Bad.n">0</span><span id="c" data-tt="Fill.n">0</span>`,
  `window.log = [];
thor.def('Good', ($) => { const n = $.state('n', 0); return { n: () => '' + n.value, $l: { h: () => { log.push('good'); n.value = 5; n.value = 6; } } }; }, { idle: true });
thor.def('Bad', ($) => { const n = $.state('n', 0); return { n: () => '' + n.value, inc: () => { n.value++; }, $l: { h: () => { throw Error('init boom'); } } }; }, { idle: true });
thor.def('Fill', ($) => { const n = $.state('n', 0); return { n: () => '' + n.value }; });`,
);

const pages = { '/rows': ROWS, '/switch': SWITCH, '/idle': IDLE };
const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail !== '' ? ` (${detail})` : ''}`);
};

// Chromium, or the browser `E2E_BROWSER` names (tool/thor e2e --browsers).
const browser = await { chromium, firefox, webkit }[process.env.E2E_BROWSER ?? 'chromium'].launch();
const open = async (path) => {
  const ctx = await browser.newContext();
  const p = await ctx.newPage();
  p.problems = [];
  p.on('pageerror', (e) => p.problems.push(e.message));
  await ctx.route('http://lite.test/**', (r) => {
    const body = pages[new URL(r.request().url()).pathname];
    return body ? r.fulfill({ contentType: 'text/html', body }) : r.fulfill({ status: 404, body: '' });
  });
  await p.goto(`http://lite.test${path}`);
  await p.waitForFunction(() => typeof thor !== 'undefined');
  return p;
};
const set = (p, s) => p.evaluate((s) => thor.use('L').set(s), s);
const settle = (p) => p.evaluate(() => new Promise((r) => setTimeout(r, 60)));
const log = (p) => p.evaluate(() => log.join());
const subs = (p) => p.evaluate(() => { let n = 0; for (let l = tick.sh; l; l = l.q) n++; return n; });
const pagehide = (p, persisted) => p.evaluate((x) => dispatchEvent(new PageTransitionEvent('pagehide', { persisted: x })), persisted);

try {
  // ---- onHydrated at idle, errors, paint --------------------------------------
  {
    const p = await open('/idle');
    await p.waitForFunction(() => log.includes('good'));
    await settle(p);
    check('idle: a state with onHydrated wakes with no event', (await log(p)) === 'good', await log(p));
    check('idle: its writes are on the page', (await p.textContent('#a')) === '6');
    check('idle: the error of one onHydrated is reported (the console/pageerror)', p.problems.some((m) => m.includes('init boom')), p.problems.join('|'));
    await p.evaluate(() => thor.use('Bad').inc());
    check('idle: the state that threw still works', (await p.textContent('#b')) === '1');
    check('idle: a state without onHydrated stays lazy (not woken at idle)', await p.evaluate(() => thor.use('Fill') !== undefined && document.getElementById('c').textContent === '0'));
    await p.close();
  }

  // ---- rows of a keyed list, each with its own state ---------------------------
  {
    const p = await open('/rows');
    await set(p, 'a,b,c');
    await settle(p);
    check('rows: every row wakes its state', (await log(p)) === 'ha,hb,hc', await log(p));
    check('rows: their texts are bound', (await p.locator('i').allTextContents()).join() === 'a:0,b:0,c:0');
    await p.evaluate(() => (tick.value = 1));
    check('rows: a shared signal reaches the rows\' texts', (await p.locator('i').allTextContents()).join() === 'a:1,b:1,c:1');
    await set(p, 'a,c');
    await settle(p);
    check('rows: the row removed by the list disposes its state once', (await log(p)) === 'ha,hb,hc,db', await log(p));
    check('rows: its timer stopped, two remain', (await p.evaluate(() => timers)) === 2);
    check('rows: its effect left the shared signal', (await subs(p)) === 2, String(await subs(p)));
    await set(p, 'a,b,c');
    await settle(p);
    check('rows: the same key back is a new instance, woken again', (await log(p)) === 'ha,hb,hc,db,hb', await log(p));
    check('rows: the returning row is bound', (await p.locator('i').allTextContents()).join() === 'a:1,b:1,c:1');
    await set(p, '');
    await settle(p);
    check('rows: the list cleared disposes every state, once', (await log(p)).split(',').filter((x) => x[0] === 'd').sort().join() === 'da,db,db,dc', await log(p));
    check('rows: no timer and no effect left', (await p.evaluate(() => timers)) === 0 && (await subs(p)) === 0);
    check('rows: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }

  // ---- 1000 rows in and out, three times ---------------------------------------
  {
    const p = await open('/rows');
    const keys = Array.from({ length: 1000 }, (_, i) => `r${i}`).join();
    for (let round = 0; round < 3; round++) {
      await set(p, keys);
      await p.waitForFunction(() => timers === 1000, null, { timeout: 15000 });
      if (round === 0) check('1000 rows: one effect per live state', (await subs(p)) === 1000, String(await subs(p)));
      await set(p, '');
      await p.waitForFunction(() => timers === 0, null, { timeout: 15000 });
    }
    const counts = await p.evaluate(() => [log.filter((x) => x[0] === 'h').length, log.filter((x) => x[0] === 'd').length]);
    check('1000 rows: 3000 woken, 3000 disposed', counts.join() === '3000,3000', counts.join());
    check('1000 rows: no effect left on the shared signal', (await subs(p)) === 0, String(await subs(p)));
    check('1000 rows: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }

  // ---- pagehide: bfcache keeps, unload ends ------------------------------------
  {
    const p = await open('/rows');
    await set(p, 'a,b');
    await settle(p);
    await pagehide(p, true);
    check('pagehide (persisted, bfcache): nothing is disposed', (await log(p)) === 'ha,hb', await log(p));
    await p.evaluate(() => dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true })));
    await pagehide(p, false);
    check('pagehide (unload): every live state disposed once', (await log(p)) === 'ha,hb,da,db', await log(p));
    await pagehide(p, false);
    check('pagehide twice: not again', (await log(p)) === 'ha,hb,da,db', await log(p));
    check('pagehide: timers stopped', (await p.evaluate(() => timers)) === 0);
    await p.close();
  }

  // ---- a variant swapped in place is not a disposal ------------------------------
  {
    const p = await open('/switch');
    await p.waitForFunction(() => log.includes('h'));
    for (let i = 0; i < 4; i++) {
      await p.evaluate(() => thor.use('S').toggle());
      await settle(p);
    }
    check('variant: swapping back and forth never disposes the state', (await log(p)) === 'h', await log(p));
    await p.evaluate(() => document.getElementById('box').remove());
    await settle(p);
    check('variant: the box removed for good disposes it once', (await log(p)) === 'h,d', await log(p));
    await p.close();
  }
} catch (e) {
  check('no exception', false, e?.stack ?? String(e));
}
await browser.close();
const failed = results.filter((r) => !r).length;
console.log(failed ? `${failed} of ${results.length} failed` : `${results.length} passed`);
process.exit(failed || !results.length ? 1 : 0);

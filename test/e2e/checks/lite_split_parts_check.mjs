// The parts split out of the lite core: keyed lists (`lists`) and the
// view transitions of an AnimatedSwitcher (`view_transition`), with and
// without the part, on pages made in memory from lib/lite/runtime.js (no
// app to build), real Chromium. Without its part the page does what the
// server drew and nothing throws; with it the list reconciles and the switch
// runs in `document.startViewTransition`.
//
//   node test/e2e/checks/lite_split_parts_check.mjs
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { chromium } from '../runner/node_modules/playwright/index.mjs';
import { repo } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
const runtime = readFileSync(join(lite, 'runtime.js'), 'utf8');
const part = (n) => readFileSync(join(lite, 'parts', `${n}.js`), 'utf8');
const page = (body, script, parts) =>
  `<!DOCTYPE html><html><head><base href="/"></head><body>${body}<script>${runtime.replace('// @thor-lite-parts', () => parts.map(part).join('\n'))}\n${script}</script></body></html>`;

// A keyed list and a counter on one state.
const listBody = `<button id="add" data-t-on="click:L.add">add</button><span id="n" data-tt="L.count">2</span>
<ul id="ul" data-tl="L.items" data-tlk="L.key"><li data-tk="a"><b data-tf="L.text">a</b></li><li data-tk="b"><b data-tf="L.text">b</b></li><template data-tlt="L.items"><li><b data-tf="L.text"></b></li></template></ul>`;
const listState = `thor.def('L', ($) => {
  const items = $.state('items', ['a', 'b']);
  return {
    items: () => items.value, key: (i) => i, text: (i) => i,
    count: () => String(items.value.length),
    add: () => { items.value = ['c', ...items.value.slice().reverse()]; },
  };
});`;

// An AnimatedSwitcher's states: OFF as the server drew it, ON as a patch.
const switchBody = `<button id="flip" data-t-on="click:V.flip">flip</button><button id="twice" data-t-on="click:V.twice">twice</button>
<div id="sw" data-tv="V.on" data-t-vt="t0" data-tp-1="|#|=ON">OFF</div>`;
const switchState = `window.vts = 0;
if (document.startViewTransition) {
  const real = document.startViewTransition.bind(document);
  document.startViewTransition = (f) => { window.vts++; window.during = null; return real(() => { window.during = document.documentElement.getAttribute('data-t-vt'); return f(); }); };
}
thor.def('V', ($) => {
  const on = $.state('on', false);
  return { on: () => on.value, flip: () => { on.value = !on.value; }, twice: () => { on.value = !on.value; on.value = !on.value; on.value = !on.value; } };
});`;

const pages = {
  '/list-core': page(listBody, listState, []),
  '/list': page(listBody, listState, ['lists']),
  '/switch-core': page(switchBody, switchState, []),
  '/switch': page(switchBody, switchState, ['view_transition']),
  '/switch-reduced': page(switchBody, switchState, ['view_transition']),
};

const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail !== '' ? ` (${detail})` : ''}`);
};

const browser = await chromium.launch();
const open = async (path, options = {}) => {
  const ctx = await browser.newContext({ viewport: { width: 700, height: 500 }, ...options });
  const p = await ctx.newPage();
  p.problems = [];
  p.on('pageerror', (e) => p.problems.push(e.message));
  p.on('console', (m) => m.type() === 'error' && p.problems.push(m.text()));
  await ctx.route('http://lite.test/**', (r) => {
    const body = pages[new URL(r.request().url()).pathname];
    return body ? r.fulfill({ contentType: 'text/html', body }) : r.fulfill({ status: 404, body: '' });
  });
  await p.goto(`http://lite.test${path}`);
  await p.waitForFunction(() => typeof thor !== 'undefined');
  await p.waitForTimeout(50);
  return p;
};
const rows = (p) => p.evaluate(() => [...document.querySelectorAll('#ul li')].map((l) => `${l.dataset.tk}:${l.textContent}`).join());

try {
  {
    const p = await open('/list-core');
    await p.click('#add');
    await p.waitForTimeout(50);
    check('core alone: the texts still follow the state', (await p.textContent('#n')) === '3', await p.textContent('#n'));
    check('core alone: the list keeps the rows the server drew', (await rows(p)) === 'a:a,b:b', await rows(p));
    check('core alone: a page with a list and no lists part has no errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }
  {
    const p = await open('/list');
    await p.click('#add');
    await p.waitForTimeout(50);
    check('lists: the rows follow the state (new, moved)', (await rows(p)) === 'c:c,b:b,a:a', await rows(p));
    check('lists: the template stays last', await p.evaluate(() => document.querySelector('#ul').lastElementChild.tagName === 'TEMPLATE'));
    check('lists: no errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }
  {
    const p = await open('/switch-core');
    await p.click('#flip');
    await p.waitForTimeout(50);
    check('core alone: the switch happens in place', (await p.textContent('#sw')) === 'ON', await p.textContent('#sw'));
    check('core alone: no view transition', (await p.evaluate(() => window.vts)) === 0);
    check('core alone: no errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }
  {
    const p = await open('/switch');
    const has = await p.evaluate(() => !!document.startViewTransition);
    await p.click('#flip');
    await p.waitForFunction(() => document.getElementById('sw').textContent === 'ON', null, { timeout: 2000 }).catch(() => {});
    check('view_transition: the switch lands', (await p.textContent('#sw')) === 'ON', await p.textContent('#sw'));
    if (has) {
      check('view_transition: it runs in one view transition', (await p.evaluate(() => window.vts)) === 1, String(await p.evaluate(() => window.vts)));
      check('view_transition: <html> carries its timing during the update', (await p.evaluate(() => window.during)) === 't0', String(await p.evaluate(() => window.during)));
      await p.waitForFunction(() => !document.documentElement.hasAttribute('data-t-vt'), null, { timeout: 3000 }).catch(() => {});
      check('view_transition: the timing leaves <html> when it ends', !(await p.evaluate(() => document.documentElement.hasAttribute('data-t-vt'))));
      // Three toggles in one batch: one transition, to the last value (ON → OFF).
      await p.click('#twice');
      await p.waitForFunction(() => document.getElementById('sw').textContent === 'OFF', null, { timeout: 2000 }).catch(() => {});
      check('view_transition: one batch, one transition', (await p.textContent('#sw')) === 'OFF' && (await p.evaluate(() => window.vts)) === 2, `${await p.textContent('#sw')} ${await p.evaluate(() => window.vts)}`);
      await p.waitForFunction(() => !document.documentElement.hasAttribute('data-t-vt'), null, { timeout: 3000 }).catch(() => {});
      // Two switches before the first transition's update: the second only
      // moves its target (back to OFF), no second transition.
      await p.evaluate(() => {
        document.getElementById('flip').click();
        document.getElementById('flip').click();
      });
      await p.waitForFunction(() => !document.documentElement.hasAttribute('data-t-vt'), null, { timeout: 3000 }).catch(() => {});
      check('view_transition: a switch before the update only moves its target', (await p.textContent('#sw')) === 'OFF' && (await p.evaluate(() => window.vts)) === 3, `${await p.textContent('#sw')} ${await p.evaluate(() => window.vts)}`);
    }
    check('view_transition: no errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }
  {
    const p = await open('/switch-reduced', { reducedMotion: 'reduce' });
    await p.click('#flip');
    await p.waitForTimeout(50);
    check('view_transition with reduced motion: in place, no transition', (await p.textContent('#sw')) === 'ON' && (await p.evaluate(() => window.vts)) === 0);
    await p.close();
  }
} catch (e) {
  check('no exception', false, e?.stack ?? String(e));
}
await browser.close();
const failed = results.filter((r) => !r).length;
console.log(failed ? `${failed} of ${results.length} failed` : `${results.length} passed`);
process.exit(failed ? 1 : 0);

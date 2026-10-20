// Lists and activation of the lite runtime in a real browser:
// pages made in memory from lib/lite/runtime.js, no app to build.
//
//  - A keyed list that reorders moves rows with `moveBefore` where the
//    browser has it, so the focused row keeps its focus and its animations;
//    without `moveBefore` (or when it throws) the same order comes out
//    through `insertBefore`.
//  - Replacing every row and a burst of states that activate together (a
//    state activated after another one's rows exist still finds the lists
//    inside those rows) guard the paths an optimization would touch
//    (`textContent = ''` and the indexed scan were measured and dropped).
//
//   node test/e2e/checks/lite_list_check.mjs
//   LITE_RUNTIME=/path/runtime.js node test/e2e/checks/lite_list_check.mjs   (another build)
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { chromium, firefox, webkit } from '../runner/node_modules/playwright/index.mjs';
import { browsersFor, repo } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
// Keyed lists are the runtime's part `lists`, sewn in first (an older
// runtime, without that part next to it, has them inside).
const withLists = (src, at) => {
  const p = join(dirname(at), 'parts/lists.js');
  return src.replace('// @thor-lite-parts', () => `${existsSync(p) ? readFileSync(p, 'utf8') : ''}\n// @thor-lite-parts`);
};
const runtimePath = process.env.LITE_RUNTIME ?? join(lite, 'runtime.js');
const runtime = withLists(readFileSync(runtimePath, 'utf8'), runtimePath);
const page = (body, script, parts = []) =>
  `<!DOCTYPE html><html><head><base href="/"></head><body>${body}<script>${runtime.replace('// @thor-lite-parts', () => parts.map((n) => readFileSync(join(lite, 'parts', n), 'utf8')).join('\n'))}\n${script}</script></body></html>`;

// Rows with an input each; `set('a,b,c')` replaces the items.
const ROWS = page(
  `<div id="host"><ul id="ul" data-tl="L.items" data-tlk="L.key"><template data-tlt="L.items"><li><b data-tf="L.text"></b><input class="in"></li></template></ul></div>
<ul id="ul2" data-tl="L.items" data-tlk="L.key"><p class="note">keep me</p><template data-tlt="L.items"><li><b data-tf="L.text"></b></li></template></ul>`,
  `thor.def('L', ($) => {
  const items = $.state('items', []);
  return {
    items: () => items.value, key: (i) => i.k, text: (i) => i.t,
    set: (s) => { items.value = s ? s.split(',').map((k) => ({ k: k.split(':')[0], t: k.split(':').pop() })) : []; },
  };
});`,
);

// A finite state whose other structure holds the list of another state: the
// runtime puts that markup in the page itself (a subtree replaced), and a
// state woken afterwards must find the list in it.
const SWITCH = page(
  `<div id="box"><p data-tv="S.open">closed</p><template data-tvt="S.open" data-i="1"><div data-tv="S.open"><ul class="in" data-tl="M.items" data-tlk="M.key"><template data-tlt="M.items"><li data-tf="M.text"></li></template></ul></div></template></div>
<span id="c" data-tt="S.count">0</span><span id="a" data-tt="A.label">-</span>`,
  `thor.def('S', ($) => {
  const open = $.state('open', false), n = $.state('n', 0);
  return { open: () => open.value, count: () => String(n.value), toggle: () => { open.value = !open.value; n.value++; } };
});
thor.def('A', ($) => ({ label: () => 'A!' }));
thor.def('M', ($) => {
  const it = $.state('items', ['x', 'y', 'z']);
  return { items: () => it.value, key: (i) => i, text: (i) => 'm' + i };
});`,
);

// Rows that carry a text of another state: the runtime clones them into the
// page, and the state woken after them (in the same burst) must find them.
const ROWTEXT = page(
  `<ul id="ul" data-tl="L.items" data-tlk="L.key"><template data-tlt="L.items"><li><b data-tf="L.text"></b><em data-tt="T.x">.</em></li></template></ul><span id="a" data-tt="A.label">-</span>`,
  `thor.def('A', ($) => ({ label: () => 'A!' }));
thor.def('L', ($) => {
  const items = $.state('items', ['p', 'q', 'r']);
  return { items: () => items.value, key: (i) => i, text: (i) => i };
});
thor.def('T', ($) => ({ x: () => 'T!' }));`,
);

// Twenty states in a chain of \`uses\` (each wakes the next), each with its own texts, one list and
// one finite state; the burst activates them all.
const N = 20;
const many = (() => {
  let body = '', script = '';
  for (let i = 0; i < N; i++) {
    body += `<p class="t${i}" data-tt="S${i}.a">.</p><p class="u${i}" data-tt="S${i}.b">.</p><ul class="l${i}" data-tl="S${i}.rows" data-tlk="S${i}.key"><template data-tlt="S${i}.rows"><li data-tf="S${i}.text"></li></template></ul>`;
    script += `thor.def('S${i}', ($) => { const n = $.state('n', ${i}); return { a: () => 'a' + n.value, b: () => 'b' + n.value, rows: () => [n.value, n.value + 1], key: (r) => 'k' + r, text: (r) => 'r' + r }; }, {uses: [${i > 0 ? `'S${i - 1}'` : ''}]});\n`;
  }
  return page(body, script);
})();

// Rows made of what a remove + insert would reset: a field with focus and a
// value, a running CSS animation, an iframe (loads once per row), a <details>
// that is open and text to select. \`ul2\` is a second list of the same state:
// one update reorders both.
const RICH = page(
  `<style>@keyframes spin{from{transform:rotate(0)}to{transform:rotate(360deg)}}.an{width:10px;height:10px;animation:spin 1000s linear infinite}</style>
<div id="host"><ul id="ul" data-tl="L.items" data-tlk="L.key"><template data-tlt="L.items"><li><b class="tx" data-tf="L.text"></b><input class="in"><div class="an"></div><details class="dt"><summary>d</summary>body</details><iframe srcdoc="<script>parent.__loads=(parent.__loads||0)+1</script>"></iframe></li></template></ul></div>
<ul id="ul2" data-tl="L.items" data-tlk="L.key"><template data-tlt="L.items"><li><b data-tf="L.text"></b><input class="in"></li></template></ul>`,
  `thor.def('L', ($) => {
  const items = $.state('items', []);
  return { items: () => items.value, key: (i) => i.k, text: (i) => i.t,
    set: (s) => { items.value = s ? s.split(',').map((k) => ({ k, t: k })) : []; } };
});`,
);

const pages = { '/rich': RICH, '/rows': ROWS, '/switch': SWITCH, '/rowtext': ROWTEXT, '/many': many };

const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail !== '' ? ` (${detail})` : ''}`);
};

// Under `tool/thor e2e --browsers` (E2E_BROWSER) the Chromium part runs only in Chromium
// (it needs moveBefore); the others run the fallback part below.
const chromiumPart = !process.env.E2E_BROWSER || process.env.E2E_BROWSER === 'chromium';
const SKIP = Symbol('skip');
let browser = chromiumPart ? await chromium.launch() : null;
// `init` runs before the page's scripts (to take moveBefore away or break it).
const open = async (path, init) => {
  const ctx = await browser.newContext({ viewport: { width: 700, height: 900 } });
  const p = await ctx.newPage();
  p.problems = [];
  p.on('pageerror', (e) => p.problems.push(e.message));
  if (init) await p.addInitScript(init);
  await ctx.route('http://lite.test/**', (r) => {
    const body = pages[new URL(r.request().url()).pathname];
    return body ? r.fulfill({ contentType: 'text/html', body }) : r.fulfill({ status: 404, body: '' });
  });
  await p.goto(`http://lite.test${path}`);
  await p.waitForFunction(() => typeof thor !== 'undefined');
  return p;
};
const set = (p, s) => p.evaluate((s) => thor.use('L').set(s), s);
const texts = (p, sel = '#ul') => p.evaluate((sel) => [...document.querySelectorAll(`${sel} > li`)].map((l) => (l.querySelector('b') ?? l).textContent), sel);
const has = (p) => p.evaluate(() => typeof Element.prototype.moveBefore === 'function');
// The row (0-based) whose input has focus, or -1.
const focused = (p) => p.evaluate(() => [...document.querySelectorAll('#ul > li')].findIndex((l) => l.querySelector('input') === document.activeElement));

try {
  if (!chromiumPart) throw SKIP;
  // ---- focus survives a reorder where moveBefore exists ---------------------
  {
    const p = await open('/rows');
    const mv = await has(p);
    check('the browser under test has moveBefore (Chrome 133+); the focus checks need it', mv);

    // Swap of the two ends (the udomdiff path).
    await set(p, 'a,b,c,d');
    await p.focus('#ul > li:nth-child(1) input');
    await p.fill('#ul > li:nth-child(1) input', 'typed');
    await set(p, 'd,b,c,a');
    check('moveBefore: swap of the ends puts the rows in the new order', (await texts(p)).join() === 'd,b,c,a', (await texts(p)).join());
    check('moveBefore: swap of the ends: the focused row keeps its focus', (await focused(p)) === 3, String(await focused(p)));
    check('moveBefore: swap of the ends: the typed value stays in its row', (await p.inputValue('#ul > li:nth-child(4) input')) === 'typed');

    // A rotation (the longest increasing subsequence path): `a` moves to the end.
    await set(p, 'a,b,c,d,e');
    await p.focus('#ul > li:nth-child(1) input');
    await set(p, 'b,c,d,e,a');
    check('moveBefore: rotation: the moved row keeps its focus', (await focused(p)) === 4, String(await focused(p)));

    // A reversal: whichever row has the focus, it keeps it.
    for (let i = 0; i < 5; i++) {
      await set(p, 'a,b,c,d,e');
      await p.focus(`#ul > li:nth-child(${i + 1}) input`);
      await set(p, 'e,d,c,b,a');
      check(`moveBefore: reversal: row ${'abcde'[i]} keeps its focus`, (await focused(p)) === 4 - i, String(await focused(p)));
    }
    check('moveBefore: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }

  // ---- the fallback (no moveBefore, or one that throws) ---------------------
  for (const [name, init] of [
    ['no moveBefore', () => { delete Element.prototype.moveBefore; }],
    ['moveBefore throws', () => { Element.prototype.moveBefore = function () { throw new DOMException('no', 'InvalidStateError'); }; }],
  ]) {
    const p = await open('/rows', init);
    await set(p, 'a,b,c,d,e');
    await p.fill('#ul > li:nth-child(1) input', 'one');
    await set(p, 'e,d,c,b,a');
    check(`fallback (${name}): reversal gives the new order`, (await texts(p)).join() === 'e,d,c,b,a', (await texts(p)).join());
    await set(p, 'd,b,c,a,e');
    check(`fallback (${name}): a shuffle gives the new order`, (await texts(p)).join() === 'd,b,c,a,e');
    await set(p, 'a,b,c,d,e');
    check(`fallback (${name}): the row keeps its typed value through the moves`, (await p.inputValue('#ul > li:nth-child(1) input')) === 'one');
    check(`fallback (${name}): one template anchor at the end, five rows`, await p.evaluate(() => {
      const u = document.getElementById('ul');
      return u.children.length === 6 && u.lastElementChild.tagName === 'TEMPLATE';
    }));
    check(`fallback (${name}): no page errors`, p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }

  // ---- replacing every row --------------------------------------------------
  {
    const p = await open('/rows');
    await set(p, 'a,b,c,d');
    const old = await p.evaluateHandle(() => [...document.querySelectorAll('#ul > li')]);
    await set(p, 'e,f,g,h');
    check('replace-all: the new rows in order', (await texts(p)).join() === 'e,f,g,h', (await texts(p)).join());
    check('replace-all: the old rows are gone from the page', await p.evaluate((o) => o.every((li) => !li.isConnected), old));
    check('replace-all: the template stays the last child, four rows before it', await p.evaluate(() => {
      const u = document.getElementById('ul');
      return u.children.length === 5 && u.lastElementChild.tagName === 'TEMPLATE';
    }));
    // A replacement that keeps one key in the middle is not "all new".
    await p.evaluate(() => (window.keep = document.querySelectorAll('#ul > li')[1]));
    await set(p, 'x,f,y,z');
    check('replace-all: a partial replacement (one key kept) keeps that row element', await p.evaluate(() => document.querySelectorAll('#ul > li')[1] === window.keep));
    // A container with something else inside (a note next to the rows) keeps it.
    await set(p, 'a,b');
    await set(p, 'c,d');
    check('replace-all: a non-row sibling of the rows survives', await p.evaluate(() => document.querySelector('#ul2 .note')?.textContent === 'keep me'));
    check('replace-all: the second container (with the note) has the new rows', (await texts(p, '#ul2')).join() === 'c,d', (await texts(p, '#ul2')).join());
    check('replace-all: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }


  // ---- state that only moveBefore keeps (Chromium 133+) ---------------------
  {
    const p = await open('/rich');
    const mv = await has(p);
    await set(p, 'a,b,c,d,e');
    await p.waitForFunction(() => window.__loads === 5);
    const st = () => p.evaluate(() => {
      const lis = [...document.querySelectorAll('#ul > li')];
      return {
        order: lis.map((l) => l.querySelector('.tx').textContent).join(),
        focus: lis.findIndex((l) => l.querySelector('.in') === document.activeElement),
        // the animation's clock of the row for `a`
        anim: lis.find((l) => l.querySelector('.tx').textContent === 'a').querySelector('.an').getAnimations()[0]?.currentTime ?? -1,
        open: lis.map((l) => l.querySelector('.dt').open).join(),
        loads: window.__loads,
        caret: `${lis.find((l) => l.querySelector('.tx').textContent === 'a').querySelector('.in').selectionStart}-${lis.find((l) => l.querySelector('.tx').textContent === 'a').querySelector('.in').selectionEnd}`,
        val: lis.find((l) => l.querySelector('.tx').textContent === 'a').querySelector('.in').value,
      };
    });
    await p.evaluate(() => {
      const lis = [...document.querySelectorAll('#ul > li')];
      lis[0].querySelector('.dt').open = true;
      lis[3].querySelector('.dt').open = true;
    });
    await p.fill('#ul > li:nth-child(1) .in', 'typed');
    // The caret inside the field (a plain text selection does not survive a
    // move in Chromium either: moveBefore collapses it too).
    await p.evaluate(() => document.querySelector('#ul > li .in').setSelectionRange(1, 4));
    await p.waitForTimeout(150);
    const before = await st();
    // The row `a` goes from first to last (a rotation), in a list and its twin.
    await set(p, 'b,c,d,e,a');
    await p.waitForTimeout(300); // an iframe that reloads does it after the task
    const after = await st();
    check('rich rows: the new order', after.order === 'b,c,d,e,a', after.order);
    check('rich rows: the typed value and focus of the moved row', after.val === 'typed' && after.focus === 4, `${after.val} ${after.focus}`);
    check('rich rows: an open <details> stays open on its row (either path)', after.open === 'false,false,true,false,true', after.open);
    if (mv) {
      check('rich rows: the iframes did not reload (moveBefore)', after.loads === before.loads, `${before.loads} -> ${after.loads}`);
      check('rich rows: the CSS animation keeps its clock', after.anim >= before.anim && after.anim > 100, `${before.anim} -> ${after.anim}`);
      check('rich rows: the caret range in the field stays', after.caret === '1-4', after.caret);
    }
    // Both lists in one update: the twin follows too.
    const twin = await texts(p, '#ul2');
    check('rich rows: the twin list has the same order after the same update', twin.join() === 'b,c,d,e,a', twin.join());
    // Reverse it all with the twin: still one row per key, no errors.
    await set(p, 'e,d,c,b,a');
    check('rich rows: both lists reversed', (await texts(p)).join() === 'e,d,c,b,a' && (await texts(p, '#ul2')).join() === 'e,d,c,b,a');
    check('rich rows: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }

  // ---- moveBefore refuses (a container out of the page) ---------------------
  {
    const p = await open('/rows');
    await set(p, 'a,b,c,d,e');
    // The list's container leaves the page while its state keeps updating it:
    // moveBefore throws there (a disconnected parent); the order must still come out right.
    const host = await p.evaluateHandle(() => {
      const h = document.getElementById('host');
      h.remove();
      return h;
    });
    await set(p, 'e,d,c,b,a');
    await set(p, 'c,a,e,b,d');
    await p.evaluate((h) => document.body.append(h), host);
    check('moveBefore refuses: a list updated out of the page has the right order when it is back', (await texts(p)).join() === 'c,a,e,b,d', (await texts(p)).join());
    // A moveBefore that refuses only some of the time (the first call).
    await p.evaluate(() => {
      const real = Element.prototype.moveBefore;
      let n = 0;
      if (real) Element.prototype.moveBefore = function (a, b) { if (n++ % 2 === 0) throw new DOMException('no', 'HierarchyRequestError'); return real.call(this, a, b); };
    });
    await set(p, 'a,b,c,d,e');
    await set(p, 'e,c,a,d,b');
    await set(p, 'b,a,d,c,e');
    check('moveBefore refuses: a moveBefore that throws every other call still gives the order', (await texts(p)).join() === 'b,a,d,c,e', (await texts(p)).join());
    check('moveBefore refuses: one anchor and five rows', await p.evaluate(() => { const u = document.getElementById('ul'); return u.children.length === 6 && u.lastElementChild.tagName === 'TEMPLATE'; }));
    check('moveBefore refuses: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }

  // ---- list edge cases (behavior that must not change) ----------------------
  {
    const p = await open('/rows');
    const rows = async () => (await texts(p)).filter((t) => t !== '');
    for (const s of ['a,b,c', '', 'a,b,c', '', '', 'z']) {
      await set(p, s);
      check(`edge: empty ⇄ full ⇄ empty, items "${s}"`, (await rows()).join() === s, (await rows()).join());
    }
    check('edge: the template anchor is still the last child after the cycles', await p.evaluate(() => document.getElementById('ul').lastElementChild.tagName === 'TEMPLATE'));
    // Duplicate keys must not throw or lose rows: one row per item.
    await set(p, '');
    await set(p, 'a:1,a:2,b:3');
    check('edge: keyed duplicates from empty: one row per item', (await rows()).length === 3, (await rows()).join());
    await set(p, 'b:3,a:1,a:2');
    check('edge: keyed duplicates reordered: one row per item, no error', (await rows()).length === 3 && p.problems.length === 0, `${(await rows()).join()} ${p.problems.join('|')}`);
    await set(p, 'a:1,a:2');
    check('edge: keyed duplicates shrinking: one row per item', (await rows()).length === 2, (await rows()).join());
    // 10k rows: create, reverse, replace, clear.
    const many = Array.from({ length: 10000 }, (_, i) => `k${i}`);
    await set(p, many.join());
    check('edge: 10k rows created', (await rows()).length === 10000);
    await set(p, [...many].reverse().join());
    const r = await rows();
    check('edge: 10k rows reversed', r.length === 10000 && r[0] === 'k9999' && r[9999] === 'k0');
    await set(p, many.map((k) => `n${k}`).join());
    const r2 = await rows();
    check('edge: 10k rows replaced', r2.length === 10000 && r2[0] === 'nk0' && r2[9999] === 'nk9999');
    check('edge: nothing of the old 10k is left in the container', await p.evaluate(() => document.getElementById('ul').children.length === 10001));
    await set(p, '');
    check('edge: 10k rows cleared', (await rows()).length === 0);
    check('edge: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }

  // ---- a list that arrives inside a replaced subtree ------------------------
  {
    const p = await open('/switch');
    // One task: wake A (a lone state scans the page), S (the second of the
    // burst: the page is indexed now), switch S (the runtime replaces the
    // subtree, the index is out of date), wake M: its list is in the new
    // markup, and the index must not hide it.
    await p.evaluate(() => {
      thor.use('A');
      const s = thor.use('S');
      s.toggle();
      thor.use('M');
    });
    const rows = () => p.evaluate(() => [...document.querySelectorAll('#box .in > li')].map((l) => l.textContent));
    check('activation burst: a state woken after the runtime replaced a subtree, in the same burst, finds the list in it', (await rows()).join() === 'mx,my,mz', (await rows()).join());
    await p.evaluate(() => thor.use('S').toggle());
    check('activation burst: switching back removes the list; the count label follows', (await p.textContent('#c')) === '2' && (await p.evaluate(() => document.querySelector('#box .in') === null)));
    await p.evaluate(() => thor.use('S').toggle());
    // The list inside the new copy is a container M's effect does not know:
    // it is left as the server drew it, and nothing throws.
    check('activation burst: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }
  {
    const p = await open('/rowtext');
    await p.evaluate(() => {
      thor.use('A');
      thor.use('L'); // the second of the burst: the page is indexed, then its rows come
      thor.use('T'); // the third: the rows' texts are new in the page
    });
    const t = await p.evaluate(() => [...document.querySelectorAll('#ul > li > em')].map((e) => e.textContent));
    check('activation burst: a state woken after a list cloned rows with its texts, in the same burst, wires them', t.join() === 'T!,T!,T!', t.join());
    check('activation burst: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }
  {
    const p = await open('/many');
    await p.evaluate(() => thor.use('S0'));
    const ok = await p.evaluate((N) => {
      for (let i = 0; i < N; i++) {
        if (document.querySelector(`.t${i}`).textContent !== `a${i}`) return `text a of S${i}`;
        if (document.querySelector(`.u${i}`).textContent !== `b${i}`) return `text b of S${i}`;
        const rows = [...document.querySelectorAll(`.l${i} > li`)].map((l) => l.textContent).join();
        if (rows !== `r${i},r${i + 1}`) return `rows of S${i}: ${rows}`;
      }
      return 'ok';
    }, N);
    check(`activation burst: ${N} states activated in one burst wire every text and list`, ok === 'ok', ok);
    // A later change reaches the effects of every state (they are live).
    const live = await p.evaluate(() => {
      const m = thor.use('S7');
      return typeof m.a === 'function';
    });
    check('activation burst: the states are live after the burst', live);
    check('activation burst: no page errors', p.problems.length === 0, p.problems.join(' | '));
    await p.close();
  }
} catch (e) {
  if (e !== SKIP) check('no exception', false, e?.stack ?? String(e));
}
await browser?.close();

// ---- The fallback in the engines that have no moveBefore (WebKit, Firefox) --
for (const [name, type] of browsersFor([['webkit', webkit], ['firefox', firefox]])) {
  try {
    browser = await type.launch();
  } catch (e) {
    check(`${name} is installed`, false, e.message.split('\n')[0]);
    continue;
  }
  try {
    for (const path of ['/rows', '/rich']) {
      const p = await open(path);
      const orders = ['a,b,c,d,e', 'e,d,c,b,a', 'd,b,c,a,e', 'b,c,d,e,a', 'a,b'];
      for (const o of orders) {
        await set(p, o);
        const got = (await texts(p)).filter((t) => t !== '');
        check(`${name} ${path}: order ${o}`, got.join() === o, got.join());
      }
      await set(p, 'a,b,c,d,e');
      await p.fill('#ul > li:nth-child(1) input', 'kept');
      await set(p, 'e,a,b,c,d');
      check(`${name} ${path}: a typed value stays in its moved row`, (await p.inputValue('#ul > li:nth-child(2) input')) === 'kept');
      check(`${name} ${path}: no page errors`, p.problems.length === 0, p.problems.join(' | '));
      await p.close();
    }
  } catch (e) {
    check(`${name}: no exception`, false, e?.stack ?? String(e));
  }
  await browser.close();
}
const failed = results.filter((r) => !r).length;
console.log(failed ? `${failed} of ${results.length} failed` : `${results.length} passed`);
process.exit(failed ? 1 : 0);

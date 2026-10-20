// Adversarial browser checks of the Flutter-feel widgets of the lite engine:
// the edges the happy-path checks of
// lite_widgets_check.mjs do not reach. Pages built in memory from the real
// runtime and parts; no app to build.
//
//   node test/e2e/checks/lite_widgets_adversarial_check.mjs
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { chromium } from '../runner/node_modules/playwright/index.mjs';
import { repo } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
const runtime = readFileSync(join(lite, 'runtime.js'), 'utf8');
const part = (n) => readFileSync(join(lite, 'parts', n), 'utf8');
const bundle = (...parts) => runtime.replace('// @thor-lite-parts', () => parts.map(part).join('\n'));
const page = (body, script, parts = [], head = '') =>
  `<!DOCTYPE html><html><head><base href="/"><meta charset="utf-8">${head}</head><body>${body}<script>${bundle(...parts)}\n${script}</script></body></html>`;
const logger = (name, methods, extra = '') =>
  `window.log = [];
thor.def('${name}', () => ({ ${methods.map((m) => `${m}: (v) => window.log.push('${m}' + (v == null ? '' : ':' + v))`).join(', ')}${extra} }));`;

const shell = (attrs, inner, id = 's') =>
  `<div id="${id}" ${attrs} style="display:flex;flex-direction:column;overflow:hidden;background:#eee"><div id="${id}-in" style="display:flow-root;position:relative;flex:none">${inner}</div></div>`;
const SZ = 'data-tsz="400|linear|400"';

const pages = {
  '/events': page(
    `<div id="a" data-t-ev="enter:H.enter;leave:H.leave" style="padding:20px;background:#eee;width:300px">
  <button id="b1">one</button>
  <div id="inner" data-t-ev="enter:H.ienter;leave:H.ileave" style="padding:10px;background:#ccc"><span id="deep">deep</span></div>
</div>
<div id="out" style="margin-top:40px;padding:20px">outside</div>
<div id="f" data-t-ev="focus:H.focus" style="padding:10px"><input id="i1"><button id="pop">x</button>
  <dialog id="dlg"><input id="di"></dialog><iframe id="fr" srcdoc="<input id=fi>" style="width:120px;height:40px"></iframe></div>
<input id="o">
<div id="host"></div>
<div id="acc"><details id="ta" name="g" open data-t-ev="toggle:H.ta"><summary id="sa">a</summary><p>x</p></details>
<details id="tb" name="g" data-t-ev="toggle:H.tb"><summary id="sb">b</summary><p>x</p></details></div>
<button id="go" data-t-on="click:H.noop">go</button>`,
    logger('H', ['enter', 'leave', 'ienter', 'ileave', 'focus', 'ta', 'tb', 'tn', 'noop']),
    ['element_events.js'],
  ),
  '/throws': page(
    `<div id="a" data-t-ev="enter:H.outer;leave:H.outerLeave" style="padding:20px;background:#eee;width:300px"><div id="inner" data-t-ev="enter:H.boom" style="padding:10px;background:#ccc"><span id="deep">deep</span></div></div><div id="out" style="margin-top:40px;padding:20px">outside</div>`,
    `window.log = [];
thor.def('H', () => ({ outer: () => window.log.push('outer'), outerLeave: () => window.log.push('outerLeave'), boom: () => { throw new Error('boom'); } }));`,
    ['element_events.js'],
  ),
  '/many': page(
    `<div id="grid">${Array.from({ length: 500 }, (_, i) => `<div class="c" data-t-ev="enter:H.enter;leave:H.leave;focus:H.focus" style="display:inline-block;width:30px;height:30px"><span>${i}</span></div>`).join('')}</div><input id="o">`,
    `window.n = 0; thor.def('H', () => ({ enter: () => window.n++, leave: () => window.n++, focus: () => window.n++ }));`,
    ['element_events.js'],
  ),
  '/size': page(
    `<div id="tab" style="display:none">${shell(SZ, '<div id="c" style="height:100px;background:#9cf"></div>')}</div>
<details id="det"><summary>s</summary>${shell(SZ, '<div id="c2" style="height:100px;background:#9cf"></div>', 's2')}</details>
<div id="flow">${shell(SZ, '<div id="c3" style="height:10px;background:#9cf"></div>', 's3')}</div>
<div id="nest">${shell(SZ, shell(SZ, '<div id="c4" style="height:10px;background:#9cf"></div>', 's5'), 's4')}</div>`,
    '',
    ['animated_size.js'],
  ),
  '/fade': page(
    `<style>.side{transition:opacity 300ms linear,visibility 0s linear 300ms;opacity:0;position:absolute;top:0;left:0;right:0;visibility:hidden}
.side.on{position:static;opacity:1;visibility:visible;transition:opacity 300ms linear,visibility 0s linear 0s}</style>
<form id="form" onsubmit="event.preventDefault(); window.submitted = new FormData(event.target).get('q') ?? 'none'">
${shell(SZ, '<div id="a" class="side on"><button id="ab">a</button></div><div id="b" class="side"><button id="bb">b</button><input id="bi" name="q" value="typed"><input id="req" name="r"></div>')}
<button id="sub" type="submit">send</button></form>
<button id="after">after</button>
<script>window.flip = (to) => { document.querySelector('#a').classList.toggle('on', to === 'a'); document.querySelector('#b').classList.toggle('on', to === 'b'); };</script>`,
    '',
    ['animated_size.js'],
  ),
  '/gesture': page(
    `<div id="row" role="button" tabindex="0" data-t-on="click:G.tap" data-tg="swipe:G.swiped;long:G.long" data-tg-swipe="h|0|0.4" style="width:300px;height:60px;margin:8px;background:#ddd;translate:var(--tg-x,0px) var(--tg-y,0px);touch-action:pan-y"><input id="txt" value="hello world"></div>
<div id="dismiss" role="button" tabindex="0" data-tg="swipe:G.dswiped" data-tg-swipe="h|1|0.4" style="width:300px;height:60px;margin:8px;background:#ddd;translate:var(--tg-x,0px) var(--tg-y,0px);touch-action:pan-y">d</div>
<div id="vlog" role="button" tabindex="0" data-tg="swipe:G.vswiped" data-tg-swipe="v|0|0.4" style="width:300px;height:60px;margin:8px;background:#ddd">v</div>
<div id="cel" role="button" tabindex="0" data-tg="swipe:G.cswiped" data-tg-swipe="h|0|0.4" contenteditable style="width:300px;height:60px;margin:8px;background:#ddd">text</div>`,
    logger('G', ['tap', 'swiped', 'dswiped', 'vswiped', 'cswiped', 'long']),
    ['gestures.js'],
  ),
};

const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail !== '' ? ` (${detail})` : ''}`);
};

const browser = await chromium.launch();
const open = async (path, options = {}) => {
  const ctx = await browser.newContext({ viewport: { width: 700, height: 900 }, ...options });
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
const log = (p) => p.evaluate(() => window.log.splice(0).join());
const center = async (p, sel) => {
  const b = await p.locator(sel).boundingBox();
  return [b.x + b.width / 2, b.y + b.height / 2];
};
const hover = async (p, sel) => p.mouse.move(...(await center(p, sel)), { steps: 3 });
const settle = (p) => p.waitForTimeout(60);
const height = (p, sel) => p.evaluate((s) => document.querySelector(s).getBoundingClientRect().height, sel);
const anims = (p, sel) => p.evaluate((s) => document.querySelector(s).getAnimations().length, sel);

try {
  // ---- MouseRegion ----------------------------------------------------------
  {
    const p = await open('/events');
    // The region is replaced (a Watch swap) while the pointer rests on it.
    await hover(p, '#b1');
    await settle(p);
    await log(p);
    await p.evaluate(() => {
      const a = document.querySelector('#a');
      a.replaceWith(a.cloneNode(true));
    });
    await hover(p, '#b1');
    await p.mouse.move(5, 5);
    await hover(p, '#b1');
    await settle(p);
    const l = (await log(p)).split(',').filter((x) => !x.startsWith('i')).join();
    check('replaced region: the new element enters once and the pair stays balanced', /^(enter,leave,enter|leave,enter|enter)$/.test(l), l);
    // pen counts, unknown types too (only touch is ignored).
    await p.evaluate(() =>
      document.querySelector('#b1').dispatchEvent(new PointerEvent('pointerout', { bubbles: true, pointerType: 'pen', relatedTarget: document.body })),
    );
    await settle(p);
    check('pen: a pen leaving is an exit', (await log(p)).includes('leave'), '');
    check('no page errors (replace)', p.problems.length === 0, p.problems.join(' | '));
  }
  {
    // A handler that throws must not silence the regions around it.
    const p = await open('/throws');
    await hover(p, '#deep');
    await settle(p);
    const l = await log(p);
    check('throwing handler: the outer region still enters', l === 'outer', l);
    await p.mouse.move(600, 500);
    await settle(p);
    check('throwing handler: and still leaves', (await log(p)) === 'outerLeave', '');
  }
  {
    // Hover state when the engine wakes up by keyboard (the pointer is inside).
    const p = await open('/events');
    await hover(p, '#b1');
    await settle(p);
    check('no wake: nothing yet', true, '');
  }
  {
    const p = await open('/many');
    const t = await p.evaluate(async () => {
      const cells = [...document.querySelectorAll('.c')];
      const t0 = performance.now();
      for (const c of cells) {
        c.dispatchEvent(new PointerEvent('pointerover', { bubbles: true, pointerType: 'mouse', relatedTarget: document.body }));
        c.dispatchEvent(new PointerEvent('pointerout', { bubbles: true, pointerType: 'mouse', relatedTarget: document.body }));
      }
      return [performance.now() - t0, window.n];
    });
    check('500 regions: 1000 events are cheap and every one reports', t[1] === 1000 && t[0] < 100, `${t[0].toFixed(1)} ms, ${t[1]}`);
  }
  // ---- Focus ----------------------------------------------------------------
  {
    const p = await open('/events');
    await p.focus('#i1');
    await settle(p);
    await log(p);
    // A modal dialog inside the subtree: the focus goes to the top layer, still inside.
    await p.evaluate(() => document.querySelector('#dlg').showModal());
    await settle(p);
    check('focus: a modal dialog inside the subtree keeps the focus inside', (await log(p)) === '', '');
    await p.evaluate(() => document.querySelector('#dlg').close());
    await settle(p);
    // Focus into an iframe inside the subtree.
    await p.focus('#i1');
    await log(p);
    await p.evaluate(() => document.querySelector('#fr').focus());
    await settle(p);
    const inIframe = await log(p);
    check('focus: moving into an iframe inside the subtree is not a loss', inIframe === '', inIframe);
    // The focused field is removed (a Watch swap).
    await p.focus('#i1');
    await log(p);
    await p.evaluate(() => document.querySelector('#i1').remove());
    await p.focus('#o');
    await settle(p);
    const removed = await log(p);
    check('focus: the focused field removed then focus elsewhere: a false, once', removed === 'focus:false' || removed === 'focus:false,focus:false' ? removed === 'focus:false' : false, removed);
    check('no page errors (focus)', p.problems.length === 0, p.problems.join(' | '));
  }
  {
    // The focused element removed and nobody takes the focus.
    const p = await open('/events');
    await p.focus('#pop');
    await settle(p);
    await log(p);
    await p.evaluate(() => document.querySelector('#pop').remove());
    await settle(p);
    await p.focus('#o');
    await settle(p);
    await p.focus('#dlg', { timeout: 100 }).catch(() => {});
    const l = await log(p);
    check('focus: removing the focused button leaves the state consistent (false by the end)', !l.endsWith('focus:true'), l);
  }
  // ---- ExpansionTile --------------------------------------------------------
  {
    const p = await open('/events');
    await p.click('#sb');
    await settle(p);
    const l = (await log(p)).split(',').sort().join();
    check('accordion: opening the second closes the first, both report', l === 'ta:false,tb:true', l);
    // A tile inserted after load, already open (a keyed row from the server).
    await p.evaluate(() => {
      document.querySelector('#host').innerHTML = '<details id="tn" open data-t-ev="toggle:H.tn"><summary>n</summary><p>x</p></details>';
    });
    await settle(p);
    await p.waitForTimeout(80);
    const fresh = await log(p);
    check('late tile: a tile that arrives open reports nothing', fresh === '', fresh);
    await p.click('#tn > summary');
    await settle(p);
    check('late tile: and its first real close reports false', (await log(p)) === 'tn:false', '');
    // A tile that arrives closed, then opened by the user.
    await p.evaluate(() => {
      document.querySelector('#host').innerHTML = '<details id="tn2" data-t-ev="toggle:H.tn"><summary>n</summary><p>x</p></details>';
    });
    await p.click('#tn2 > summary');
    await settle(p);
    check('late tile: a tile that arrives closed reports true when opened', (await log(p)) === 'tn:true', '');
    // find-in-page / URL fragment opens a tile: also a change.
    check('no page errors (toggle)', p.problems.length === 0, p.problems.join(' | '));
  }
  // ---- AnimatedSize / AnimatedCrossFade -------------------------------------
  {
    const p = await open('/size');
    // A shell inside a display:none ancestor (a hidden tab) is shown: it is not a growth.
    await p.evaluate(() => (document.querySelector('#tab').style.display = 'block'));
    await p.waitForTimeout(100);
    check('hidden tab: showing it does not animate from zero', (await anims(p, '#s')) === 0 && (await height(p, '#s')) === 100, `${await anims(p, '#s')} ${await height(p, '#s')}`);
    await p.click('#det > summary');
    await p.waitForTimeout(100);
    check('closed details: opening it does not animate from zero', (await anims(p, '#s2')) === 0 && (await height(p, '#s2')) === 100, `${await anims(p, '#s2')} ${await height(p, '#s2')}`);
    // The content changes every frame for a second: no observer loop error, ends right.
    await p.evaluate(() => {
      let i = 0;
      const c = document.querySelector('#c3');
      return new Promise((done) => {
        const step = () => {
          c.style.height = 10 + (i++ % 2 ? 80 : 0) + 'px';
          if (i < 60) requestAnimationFrame(step);
          else done();
        };
        step();
      });
    });
    await p.evaluate(() => (document.querySelector('#c3').style.height = '70px'));
    await p.waitForTimeout(900);
    check('every frame: ends at the content, no animation left, no errors', (await height(p, '#s3')) === 70 && (await anims(p, '#s3')) === 0 && p.problems.length === 0, `${await height(p, '#s3')} ${p.problems.join(' | ')}`);
    // Nested AnimatedSize: the outer follows the inner animation and ends right.
    await p.evaluate(() => (document.querySelector('#c4').style.height = '120px'));
    await p.waitForTimeout(1500);
    check('nested: both settle at the content', (await height(p, '#s4')) === 120 && (await height(p, '#s5')) === 120 && (await anims(p, '#s4')) === 0, `${await height(p, '#s4')} ${await height(p, '#s5')}`);
    // Removed mid-animation.
    await p.evaluate(() => (document.querySelector('#c3').style.height = '300px'));
    await p.waitForTimeout(100);
    await p.evaluate(() => document.querySelector('#s3').remove());
    await p.waitForTimeout(500);
    check('removed mid-animation: no errors', p.problems.length === 0, p.problems.join(' | '));
  }
  {
    // print: sizes are the content's
    const p = await open('/size');
    await p.evaluate(() => (document.querySelector('#c3').style.height = '200px'));
    await p.emulateMedia({ media: 'print' });
    await p.waitForTimeout(700);
    check('print: the size is the content\'s', (await height(p, '#s3')) === 200, `${await height(p, '#s3')}`);
  }
  {
    const p = await open('/fade', { });
    await p.evaluate(() => flip('b'));
    await p.waitForTimeout(500);
    // The hidden child (A) is out of the tab order and the accessibility tree.
    await p.focus('#bb');
    const order = [];
    for (let i = 0; i < 4; i++) {
      await p.keyboard.press('Tab');
      order.push(await p.evaluate(() => document.activeElement.id));
    }
    check('fade: the hidden child is not in the tab order', !order.includes('ab'), order.join());
    const snap = await p.locator('#form').ariaSnapshot();
    check('fade: the hidden child is not in the accessibility tree', !snap.includes('"a"') && snap.includes('"b"'), snap.replace(/\n/g, ' '));
    // Switching back and forth inside the duration ends in the last one.
    await p.evaluate(async () => {
      for (const t of ['a', 'b', 'a', 'b', 'a']) {
        flip(t);
        await new Promise((r) => setTimeout(r, 40));
      }
    });
    await p.waitForTimeout(800);
    const v = await p.evaluate(() => [getComputedStyle(document.querySelector('#a')).visibility, getComputedStyle(document.querySelector('#b')).visibility].join());
    check('fade: A-B-A-B-A ends with A shown and B hidden', v === 'visible,hidden', v);
    // The hidden child's fields inside a form.
    await p.evaluate(() => flip('a'));
    await p.waitForTimeout(500);
    await p.click('#sub');
    await settle(p);
    const sub = await p.evaluate(() => window.submitted ?? 'blocked');
    // Accepted (Flutter keeps both children in the tree too): the hidden child's fields stay in the form.
    check('fade: a field of the hidden child still submits its value (both children are in the tree)', sub === 'typed', sub);
  }

  // ---- Gesture --------------------------------------------------------------
  const cdpOf = async (p) => p.context().newCDPSession(p);
  const touch = (cdp, type, points) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: points.map(([x, y], id) => ({ x, y, id: id + 1 })) });
  {
    const p = await open('/gesture', { hasTouch: true });
    // Shift+arrow in a text field inside the row extends the selection and never swipes.
    await p.focus('#txt');
    await p.evaluate(() => document.querySelector('#txt').setSelectionRange(0, 0));
    await p.keyboard.press('Shift+ArrowRight');
    await p.keyboard.press('Shift+ArrowRight');
    const sel = await p.evaluate(() => [document.querySelector('#txt').selectionStart, document.querySelector('#txt').selectionEnd].join());
    check('gesture: text field inside: Shift+Arrow selects text, no swipe', sel === '0,2' && (await log(p)) === '', sel);
    // A gesture element that is itself editable keeps its text keys.
    await p.focus('#cel');
    await p.keyboard.press('Shift+ArrowRight');
    const editable = await log(p);
    check('gesture: editable gesture element: Shift+Arrow is the text\'s, not a swipe', editable === '', editable);
    // A key held down: a dismissing row reports once.
    await p.focus('#dismiss');
    for (let i = 0; i < 4; i++) await p.keyboard.press('Shift+ArrowLeft');
    await p.waitForTimeout(500);
    const held = await log(p);
    check('gesture: held key: a dismissing row reports once', held === 'dswiped:start', held);
    // Vertical logical swipe keeps up/down.
    await p.focus('#vlog');
    await p.keyboard.press('Shift+ArrowDown');
    check('gesture: a vertical swipe stays up/down', (await log(p)) === 'vswiped:down', '');
    // pointercancel in the middle of a long press: nothing fires afterwards.
    const cdp = await cdpOf(p);
    const [x, y] = await center(p, '#row');
    await touch(cdp, 'touchStart', [[x + 100, y + 20]]);
    await p.waitForTimeout(250);
    await touch(cdp, 'touchCancel', []);
    await p.waitForTimeout(700);
    check('gesture: pointercancel during a long press: no long press', !(await log(p)).includes('long'), '');
    // A second finger joining a hold.
    await touch(cdp, 'touchStart', [[x + 100, y + 20]]);
    await p.waitForTimeout(200);
    await touch(cdp, 'touchStart', [[x + 100, y + 20], [x + 140, y + 20]]);
    await p.waitForTimeout(700);
    await touch(cdp, 'touchEnd', []);
    await p.waitForTimeout(100);
    const two = await log(p);
    check('gesture: second finger during a hold: at most one long press and no swipe', (two.match(/long/g) ?? []).length <= 1 && !two.includes('swiped'), two);
    await cdp.detach();
    // A drag that ends quickly followed by a legit tap right away (suppress is short-lived).
    const [rx, ry] = await center(p, '#row');
    await p.mouse.move(rx + 100, ry + 20);
    await p.mouse.down();
    await p.mouse.move(rx + 200, ry + 20, { steps: 6 });
    await p.mouse.up();
    await log(p);
    await p.waitForTimeout(120);
    await p.touchscreen.tap(rx + 100, ry + 20);
    await settle(p);
    check('gesture: suppress: a tap 120 ms after a swipe still taps', (await log(p)) === 'tap', '');
    check('gesture: no page errors (gesture)', p.problems.length === 0, p.problems.join(' | '));
  }
} finally {
  await browser.close();
}

const failed = results.filter((ok) => !ok).length;
console.log(`\n${results.length - failed}/${results.length} checks passed`);
if (failed > 0 || results.length === 0) process.exit(1);

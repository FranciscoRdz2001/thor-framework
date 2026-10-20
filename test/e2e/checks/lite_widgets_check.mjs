// Browser checks of the Flutter-feel widgets of the lite engine: real
// Chromium, pages built in memory from lib/lite/runtime.js
// and the parts the markup names (no app to build), with the markers
// thor_ui writes. A check was a failing repro before the part existed.
//
//   node test/e2e/checks/lite_widgets_check.mjs
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { chromium } from '../runner/node_modules/playwright/index.mjs';
import { frames, repo } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
const runtime = readFileSync(join(lite, 'runtime.js'), 'utf8');
const part = (n) => readFileSync(join(lite, 'parts', n), 'utf8');
const bundle = (...parts) => runtime.replace('// @thor-lite-parts', () => parts.map(part).join('\n'));
const page = (body, script, parts = [], head = '') =>
  `<!DOCTYPE html><html><head><base href="/"><meta charset="utf-8">${head}</head><body>${body}<script>${bundle(...parts)}\n${script}</script></body></html>`;

// A state whose every method logs its name and argument.
const logger = (name, methods) =>
  `window.log = [];
thor.def('${name}', () => ({ ${methods.map((m) => `${m}: (v) => window.log.push('${m}' + (v == null ? '' : ':' + v))`).join(', ')} }));`;

const pages = {
  // MouseRegion, Focus, ExpansionTile.
  '/events': page(
    `<div id="a" data-t-ev="enter:H.enter;leave:H.leave" style="padding:20px;background:#eee;width:300px">
  <button id="b1">one</button><button id="b2">two</button>
  <div id="inner" data-t-ev="enter:H.ienter;leave:H.ileave" style="padding:10px;background:#ccc"><span id="deep">deep</span></div>
</div>
<div id="out" style="margin-top:40px;padding:20px">outside</div>
<div id="f" data-t-ev="focus:H.focus" style="padding:10px"><input id="i1"><input id="i2"></div>
<input id="o">
<details id="d" data-t-ev="toggle:H.toggle"><summary id="s">s</summary><p>content</p></details>
<details id="dopen" open data-t-ev="toggle:H.toggle2"><summary>s2</summary><p>content</p></details>
<details id="dx" data-t-ev="toggle:H.tagged" data-tx="faq"><summary>s3</summary><p>content</p></details>`,
    logger('H', ['enter', 'leave', 'ienter', 'ileave', 'focus', 'toggle', 'toggle2', 'tagged']),
    ['element_events.js'],
  ),
  // An exclusive accordion (`name`): the toggles of the tile that closes and the one that opens.
  '/accordion': page(
    `<details id="a" name="g" open data-t-ev="toggle:H.toggle" data-tx="a"><summary id="sa">a</summary><p>content</p></details>
<details id="b" name="g" data-t-ev="toggle:H.toggle" data-tx="b"><summary id="sb">b</summary><p>content</p></details>
<details id="c" name="g" data-t-ev="toggle:H.toggle" data-tx="c"><summary id="sc">c</summary><p>content</p></details>
<details id="solo" data-t-ev="toggle:H.toggle" data-tx="solo"><summary id="ss">solo</summary><p>content</p></details>`,
    logger('H', ['toggle']),
    ['element_events.js'],
  ),
  '/events-none': page(
    `<div id="a" data-t-ev="enter:H.enter;leave:H.leave" style="padding:20px;background:#eee;width:300px"><button id="b1">one</button></div><div id="out" style="margin-top:40px">outside</div>
<button id="pre">pre</button>`,
    logger('H', ['enter', 'leave']),
    ['element_events.js'],
  ),
};

// The engine loaded by the first click, like the real loader: the bundle
// runs when the button inside the regions is pressed.
const late = (body, script, parts) =>
  `<!DOCTYPE html><html><head><base href="/"><meta charset="utf-8"></head><body>${body}<script>window.boot = () => {\n${bundle(...parts)}\n${script}\n};</script></body></html>`;
pages['/late'] = late(
  `<div id="a" data-t-ev="enter:H.enter;leave:H.leave" style="padding:20px;background:#eee;width:300px"><button id="b1" onclick="boot()">one</button></div>
<div id="out" style="margin-top:40px;padding:20px">outside</div>
<div id="f" data-t-ev="focus:H.focus" style="padding:10px"><input id="i1"></div><input id="o">`,
  logger('H', ['enter', 'leave', 'focus']),
  ['element_events.js'],
);

// A swipeable row, a long-press target and a pinch circle, with the
// markers thor_ui's Gesture writes (the CSS is what its class would say).
const row = (id, attrs, extra = '') =>
  `<div id="${id}" role="button" tabindex="0" ${attrs} style="width:300px;height:60px;margin:8px;background:#ddd;translate:var(--tg-x,0px) var(--tg-y,0px);touch-action:pan-y;${extra}">${id}</div>`;
pages['/gesture'] = page(
  `${row('row', 'data-t-on="click:G.tap" data-tg="swipe:G.swiped;long:G.long" data-tg-swipe="h|0|0.4" aria-keyshortcuts="Shift+ArrowLeft Shift+ArrowRight"')}
${row('dismiss', 'data-t-on="click:G.tap" data-tg="swipe:G.dswiped" data-tg-swipe="h|1|0.4"')}
<div dir="rtl">${row('rtl', 'data-tg="swipe:G.rswiped" data-tg-swipe="h|0|0.4"')}</div>
<div dir="rtl">${row('rtlphys', 'data-tg="swipe:G.pswiped" data-tg-swipe="h|0|0.4"')}</div>
${row('col', 'data-tg="swipe:G.cswiped" data-tg-swipe="v|0|0.4"', 'touch-action:pan-x')}
${row('drag', 'data-tg="drag:G.dragged" data-tg-drag="f|1|10"', 'touch-action:none')}
<div id="pinch" data-tg="scale:G.scaled" data-tg-scale="1|4|0|0.25" tabindex="0" role="button" style="width:120px;height:120px;background:#fa0;scale:var(--tg-s,1);touch-action:none"></div>
<input id="after">`,
  logger('G', ['tap', 'swiped', 'dswiped', 'rswiped', 'pswiped', 'cswiped', 'long', 'dragged', 'scaled']),
  ['gestures.js'],
);

// The shell thor_ui's AnimatedSize writes (a clipping flex column around
// a measuring element), with the content's height set by the checks.
const shell = (attrs, inner, id = 's') =>
  `<div id="${id}" ${attrs} style="display:flex;flex-direction:column;overflow:hidden;background:#eee"><div id="${id}-in" style="display:flow-root;position:relative;flex:none">${inner}</div></div>`;
const growth = 'const H = (h) => (document.querySelector("#c").style.height = h + "px");';
pages['/size'] = page(
  `${shell('data-tsz="400|linear|400"', '<div id="c" style="height:50px;background:#9cf"></div>')}<p id="after">after</p>`,
  growth,
  ['animated_size.js'],
);
// The change lands in the same task as the part: before the observer's first report.
pages['/size-early'] = page(
  `${shell('data-tsz="400|linear|400"', '<div id="c" style="height:50px;background:#9cf"></div>')}`,
  `${growth}\nH(150);`,
  ['animated_size.js'],
);
pages['/fade'] = page(
  `<style>.side{transition:opacity 300ms linear,visibility 0s linear 300ms;opacity:0;position:absolute;top:0;left:0;right:0;visibility:hidden}
.side.on{position:static;opacity:1;visibility:visible;transition:opacity 300ms linear,visibility 0s linear 0s}</style>
${shell('data-tsz="400|linear|400"', '<div id="a" class="side on"><div style="height:40px">A</div></div><div id="b" class="side"><div style="height:160px">B</div></div>')}`,
  `window.flip = (to) => { document.querySelector('#a').classList.toggle('on', to === 'a'); document.querySelector('#b').classList.toggle('on', to === 'b'); };`,
  ['animated_size.js'],
);

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
  await ctx.route('http://lite.test/**', (r) => {
    const body = pages[new URL(r.request().url()).pathname];
    return body ? r.fulfill({ contentType: 'text/html', body }) : r.fulfill({ status: 404, body: '' });
  });
  await p.goto(`http://lite.test${path}`);
  if (!path.startsWith('/late')) await p.waitForFunction(() => typeof thor !== 'undefined');
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

try {
  // ---- MouseRegion ----------------------------------------------------------
  {
    const p = await open('/events');
    await hover(p, '#b1');
    await settle(p);
    check('enter: the pointer entering the region calls onEnter once', (await log(p)) === 'enter', '');
    // Between children of the region, and into a nested region: no exit, no re-enter.
    await hover(p, '#b2');
    await hover(p, '#b1');
    await settle(p);
    check('enter: moving between children is no flicker', (await log(p)) === '', '');
    await hover(p, '#deep');
    await settle(p);
    check('nested: the inner region enters, the outer stays', (await log(p)) === 'ienter', '');
    await hover(p, '#b1');
    await settle(p);
    check('nested: back to the outer leaves only the inner', (await log(p)) === 'ileave', '');
    await hover(p, '#out');
    await settle(p);
    // The path down to #out crosses the inner region: its own pair is fine.
    const lv = (await log(p)).split(',').filter((x) => !x.startsWith('i')).join();
    check('leave: the pointer leaving calls onExit once', lv === 'leave', lv);
    // Straight from deep inside to outside: both regions leave.
    await hover(p, '#deep');
    await log(p);
    await hover(p, '#out');
    await settle(p);
    const both = (await log(p)).split(',').sort().join();
    check('nested: leaving from the inner leaves both', both === 'ileave,leave', both);
    // The pointer leaving the window.
    await hover(p, '#b1');
    await log(p);
    await p.evaluate(() =>
      document.querySelector('#b1').dispatchEvent(new PointerEvent('pointerout', { bubbles: true, pointerType: 'mouse', relatedTarget: null })),
    );
    await settle(p);
    check('window: leaving the window is an exit', (await log(p)) === 'leave', '');
    // Coming back in from outside the window enters again.
    await p.evaluate(() =>
      document.querySelector('#b1').dispatchEvent(new PointerEvent('pointerover', { bubbles: true, pointerType: 'mouse', relatedTarget: null })),
    );
    await settle(p);
    check('window: coming back is an enter', (await log(p)) === 'enter', '');
    // A stray exit with no enter is not reported (balanced pairs).
    await p.evaluate(() => {
      const b = document.querySelector('#b1');
      b.dispatchEvent(new PointerEvent('pointerout', { bubbles: true, pointerType: 'mouse', relatedTarget: null }));
      b.dispatchEvent(new PointerEvent('pointerout', { bubbles: true, pointerType: 'mouse', relatedTarget: null }));
    });
    await settle(p);
    check('balance: a second exit without an enter says nothing', (await log(p)) === 'leave', '');
    check('no page errors (hover)', p.problems.length === 0, p.problems.join(' | '));
  }
  // Touch never hovers (Flutter's MouseRegion is a mouse's).
  {
    const p = await open('/events', { hasTouch: true });
    const [x, y] = await center(p, '#b1');
    await p.touchscreen.tap(x, y);
    await settle(p);
    check('touch: a tap enters nothing', !(await log(p)).includes('enter'), '');
    await p.touchscreen.tap(...(await center(p, '#out')));
    await settle(p);
    check('touch: and leaves nothing', (await log(p)) === '', '');
    await p.evaluate(() =>
      document.querySelector('#b1').dispatchEvent(new PointerEvent('pointerover', { bubbles: true, pointerType: 'touch', relatedTarget: null })),
    );
    check('touch: a touch pointerover is ignored', (await log(p)) === '', '');
  }
  // The pointer already inside when the engine wakes up (the click that loads it).
  {
    const p = await open('/late');
    await hover(p, '#b1');
    await p.mouse.down();
    await p.mouse.up();
    await settle(p);
    check('late engine: a pointer already inside counts as entered', (await log(p)) === 'enter', '');
    await p.mouse.move(...(await center(p, '#out')), { steps: 3 });
    await settle(p);
    check('late engine: and its exit is reported', (await log(p)) === 'leave', '');
  }
  {
    const p = await open('/late');
    await p.focus('#i1');
    await p.evaluate(() => window.boot());
    await settle(p);
    check('late engine: the focus that woke the engine is reported', (await log(p)) === 'focus:true', '');
    await p.focus('#o');
    await settle(p);
    check('late engine: and its loss', (await log(p)) === 'focus:false', '');
  }
  // ---- Focus ----------------------------------------------------------------
  {
    const p = await open('/events');
    await p.focus('#i1');
    await settle(p);
    check('focus: entering the subtree reports true', (await log(p)) === 'focus:true', '');
    await p.focus('#i2');
    await settle(p);
    check('focus: moving between two inner inputs is no false and no true', (await log(p)) === '', '');
    await p.keyboard.press('Tab');
    await settle(p);
    check('focus: leaving the subtree reports false', (await log(p)) === 'focus:false', '');
    await p.focus('#i1');
    await log(p);
    // The window (or devtools) taking the focus: a focusout with no related target.
    await p.evaluate(() => document.activeElement.blur());
    await settle(p);
    check('focus: a blur with no target (window, devtools) reports false', (await log(p)) === 'focus:false', '');
    await p.focus('#i1');
    await settle(p);
    check('focus: coming back reports true again', (await log(p)) === 'focus:true', '');
    check('no page errors (focus)', p.problems.length === 0, p.problems.join(' | '));
  }
  // ---- ExpansionTile --------------------------------------------------------
  {
    const p = await open('/events');
    check('toggle: an initially open tile reports nothing at load', !(await log(p)).includes('toggle2'), '');
    await p.click('#s');
    await settle(p);
    check('toggle: opening reports true', (await log(p)) === 'toggle:true', '');
    await p.click('#s');
    await settle(p);
    check('toggle: closing reports false', (await log(p)) === 'toggle:false', '');
    // Rapid toggles: every settled change reports, in order, ending on the truth.
    await p.evaluate(() => {
      const d = document.querySelector('#d');
      d.open = true;
      d.open = false;
      d.open = true;
    });
    await settle(p);
    const burst = await log(p);
    check('toggle: a burst of changes ends on the real state', burst === 'toggle:true', burst);
    // The `open` attribute set by the server's own patch is a change too.
    await p.evaluate(() => document.querySelector('#d').removeAttribute('open'));
    await settle(p);
    check('toggle: the attribute removed reports false', (await log(p)) === 'toggle:false', '');
    await p.click('#dx > summary');
    await settle(p);
    check('toggle: withArg gives the fixed argument first', (await log(p)) === 'tagged:faq~true', '');
    check('no page errors (toggle)', p.problems.length === 0, p.problems.join(' | '));
  }
  // ---- ExpansionTile accordion: close, then open ----------------------------
  {
    const p = await open('/accordion');
    await p.click('#sb');
    await settle(p);
    check('accordion: opening b reports a closing first, then b opening', (await log(p)) === 'toggle:a~false,toggle:b~true', '');
    await p.click('#sc');
    await settle(p);
    check('accordion: the same again (b closes, c opens)', (await log(p)) === 'toggle:b~false,toggle:c~true', '');
    // The browser's events may come the other way round: the settled state is what reports.
    await p.evaluate(() => {
      const a = document.querySelector('#a'), c = document.querySelector('#c');
      a.open = true; // closes c natively
      for (const el of [a, c]) el.dispatchEvent(new Event('toggle')); // opener first
    });
    await settle(p);
    check('accordion: events in the opener-first order still report the close first', (await log(p)) === 'toggle:c~false,toggle:a~true', '');
    await p.click('#sa');
    await settle(p);
    check('accordion: closing the open one reports once', (await log(p)) === 'toggle:a~false', '');
    await p.click('#ss');
    await settle(p);
    check('accordion: a tile with no group reports at once', (await log(p)) === 'toggle:solo~true', '');
    check('accordion: no page errors', p.problems.length === 0, p.problems.join(' | '));
  }
  // ---- Gesture --------------------------------------------------------------
  const cdpOf = async (p) => p.context().newCDPSession(p);
  const touch = (cdp, type, points) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: points.map(([x, y], id) => ({ x, y, id: id + 1 })) });
  const swipeTouch = async (p, sel, dx, dy = 0, { cancel = false, steps = 6 } = {}) => {
    const cdp = await cdpOf(p);
    const [x, y] = await center(p, sel);
    await touch(cdp, 'touchStart', [[x, y]]);
    for (let i = 1; i <= steps; i++) await touch(cdp, 'touchMove', [[x + (dx * i) / steps, y + (dy * i) / steps]]);
    await touch(cdp, cancel ? 'touchCancel' : 'touchEnd', []);
    await cdp.detach();
  };
  const swipeMouse = async (p, sel, dx) => {
    const [x, y] = await center(p, sel);
    await p.mouse.move(x, y);
    await p.mouse.down();
    await p.mouse.move(x + dx, y, { steps: 8 });
    await p.mouse.up();
  };
  const shift = async (p, sel, key) => {
    await p.focus(sel);
    await p.keyboard.press(`Shift+${key}`);
    await settle(p);
  };
  {
    const p = await open('/gesture', { hasTouch: true });
    // Keyboard alternative (WCAG 2.5.1, 2.1.1): Shift+arrow along the axis swipes.
    await shift(p, '#row', 'ArrowLeft');
    check('keyboard: Shift+ArrowLeft swipes start (ltr), no dismiss needed', (await log(p)) === 'swiped:start', '');
    await shift(p, '#row', 'ArrowRight');
    check('keyboard: Shift+ArrowRight swipes end (ltr)', (await log(p)) === 'swiped:end', '');
    await shift(p, '#row', 'ArrowUp');
    check('keyboard: the other axis does nothing', (await log(p)) === '', '');
    await p.focus('#row');
    await p.keyboard.press('ArrowLeft');
    await settle(p);
    check('keyboard: a plain arrow keeps scrolling/reading (no swipe)', (await log(p)) === '', '');
    await shift(p, '#col', 'ArrowDown');
    check('keyboard: a vertical swipe answers Shift+ArrowDown', (await log(p)) === 'cswiped:down', '');
    await p.focus('#dismiss');
    await p.keyboard.press('Shift+ArrowLeft');
    await p.waitForTimeout(400);
    const dis = await log(p);
    check('keyboard: a dismissing row flies out, then reports once', dis === 'dswiped:start', dis);
    // Delete still dismisses (kept).
    await p.evaluate(() => document.querySelector('#dismiss').removeAttribute('data-tg-out'));
    await p.focus('#dismiss');
    await p.keyboard.press('Delete');
    await p.waitForTimeout(400);
    check('keyboard: Delete still dismisses', (await log(p)) === 'dswiped:start', '');
    // Logical directions: the same physical swipe is start/end depending on dir.
    await swipeMouse(p, '#rtl', 200);
    const r1 = await log(p);
    check('rtl: a swipe toward the physical right is start in rtl', r1 === 'rswiped:start', r1);
    await swipeMouse(p, '#rtl', -200);
    const r2 = await log(p);
    check('rtl: toward the physical left is end', r2 === 'rswiped:end', r2);
    await shift(p, '#rtl', 'ArrowLeft');
    check('rtl: Shift+ArrowLeft is end (the arrow is physical, the answer logical)', (await log(p)) === 'rswiped:end', '');
    await swipeMouse(p, '#rtlphys', 200);
    const r3 = await log(p);
    check('rtl: always logical (no fourth field any more)', r3 === 'pswiped:start', r3);
    await swipeMouse(p, '#row', 200);
    check('ltr: physical default unchanged', (await log(p)) === 'swiped:end', '');
    // suppress must not stick on touch: a moved touch never clicks.
    await swipeTouch(p, '#row', 40); // short: snaps back, no swipe
    await settle(p);
    await log(p);
    await p.touchscreen.tap(...(await center(p, '#row')));
    await settle(p);
    check('suppress: after a short touch swipe the next tap still taps', (await log(p)) === 'tap', '');
    // A cancelled swipe (the browser took the touch) leaves nothing behind.
    await swipeTouch(p, '#row', 120, 0, { cancel: true });
    await settle(p);
    const cancelled = await p.evaluate(() => {
      const e = document.querySelector('#row');
      return [e.hasAttribute('data-tg-active'), e.style.getPropertyValue('--tg-x')].join();
    });
    check('pointercancel: the swipe ends, the row snaps back, nothing reported', cancelled === 'false,0px' && (await log(p)) === '', cancelled);
    await p.touchscreen.tap(...(await center(p, '#row')));
    await settle(p);
    check('pointercancel: and the next tap taps', (await log(p)) === 'tap', '');
    // The same with the mouse: a real swipe swallows its own click, not the next.
    await swipeMouse(p, '#row', 200);
    await log(p);
    await p.waitForTimeout(150);
    await p.mouse.click(...(await center(p, '#row')));
    await settle(p);
    check('suppress: after a mouse swipe the next click clicks', (await log(p)) === 'tap', '');
    // Long press (touch): once, even when the browser also sends contextmenu.
    {
      const cdp = await cdpOf(p);
      const [x, y] = await center(p, '#row');
      await touch(cdp, 'touchStart', [[x, y]]);
      await p.waitForTimeout(900);
      await touch(cdp, 'touchEnd', []);
      await cdp.detach();
      await settle(p);
      const l = await log(p);
      check('long press: a touch hold fires once', l === 'long', l);
    }
    // Android sends its own contextmenu around the timer, and a pointercancel
    // with it: whatever the order, one call.
    const androidLong = async (ctxAt, cancelAt) => {
      await p.evaluate(({ ctxAt, cancelAt }) => {
        const e = document.querySelector('#row');
        const r = e.getBoundingClientRect();
        const at = { bubbles: true, cancelable: true, clientX: r.x + 5, clientY: r.y + 5, pointerId: 7, pointerType: 'touch', isPrimary: true, button: 0 };
        e.dispatchEvent(new PointerEvent('pointerdown', at));
        const send = (t, f) => setTimeout(f, t);
        send(ctxAt, () => e.dispatchEvent(new MouseEvent('contextmenu', at)));
        if (cancelAt != null) send(cancelAt, () => e.dispatchEvent(new PointerEvent('pointercancel', at)));
        else send(800, () => e.dispatchEvent(new PointerEvent('pointerup', at)));
      }, { ctxAt, cancelAt });
      await p.waitForTimeout(950);
      return log(p);
    };
    const a1 = await androidLong(300, null);
    check('long press: contextmenu before the timer, then the timer, is one call', a1 === 'long', a1);
    const a2 = await androidLong(650, 620);
    check('long press: timer, pointercancel, then the browser contextmenu is one call', a2 === 'long', a2);
    const a3 = await androidLong(700, null);
    check('long press: timer then contextmenu while held is one call', a3 === 'long', a3);
    // Long press then move: never a long press.
    {
      const cdp = await cdpOf(p);
      const [x, y] = await center(p, '#row');
      await touch(cdp, 'touchStart', [[x, y]]);
      await p.waitForTimeout(250);
      await touch(cdp, 'touchMove', [[x + 30, y]]);
      await touch(cdp, 'touchMove', [[x + 40, y]]);
      await p.waitForTimeout(700);
      await touch(cdp, 'touchEnd', []);
      await cdp.detach();
      await settle(p);
      const m = await log(p);
      check('long press: moving before the hold cancels it', !m.includes('long'), m);
    }
    // Mouse long press: once, and no click after it.
    {
      const [x, y] = await center(p, '#row');
      await p.mouse.move(x, y);
      await p.mouse.down();
      await p.waitForTimeout(700);
      await p.mouse.up();
      await settle(p);
      const l3 = await log(p);
      check('long press: a mouse hold fires once and does not click', l3 === 'long', l3);
      await p.mouse.click(x, y);
      await settle(p);
      check('long press: and the next click clicks', (await log(p)) === 'tap', '');
    }
    check('no page errors (gesture)', p.problems.length === 0, p.problems.join(' | '));
  }
  // Multi-touch: lifting one finger of a pinch must not collapse the scale,
  // and another finger's cancel must not end the press.
  {
    const p = await open('/gesture', { hasTouch: true });
    const cdp = await cdpOf(p);
    const [x, y] = await center(p, '#pinch');
    const at = (a, b) => [[x - a, y], [x + b, y]];
    await touch(cdp, 'touchStart', at(20, 20));
    for (const d of [25, 30, 40]) await touch(cdp, 'touchMove', at(d, d));
    await settle(p);
    const during = await p.evaluate(() => document.querySelector('#pinch').style.getPropertyValue('--tg-s'));
    // One finger lifts; the other keeps moving.
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [{ x: x + 40, y, id: 2 }] });
    await touch(cdp, 'touchMove', [[x - 60, y]]);
    await touch(cdp, 'touchMove', [[x - 90, y]]);
    await settle(p);
    const after = await p.evaluate(() => document.querySelector('#pinch').style.getPropertyValue('--tg-s'));
    await touch(cdp, 'touchEnd', []);
    await settle(p);
    const l = await log(p);
    check('multi-touch: the scale holds when one finger lifts and the other moves', after === during && during !== '', `${during} -> ${after}`);
    check('multi-touch: the release still reports the scale once', /^scaled:(1\.[5-9]\d*|2)$/.test(l), l);
    await cdp.detach();
  }
  // ---- AnimatedSize / AnimatedCrossFade -------------------------------------
  const height = (p, sel = '#s') => p.evaluate((s) => document.querySelector(s).getBoundingClientRect().height, sel);
  const anims = (p, sel = '#s') => p.evaluate((s) => document.querySelector(s).getAnimations().length, sel);
  {
    const p = await open('/size');
    check('load: nothing animates at load', (await anims(p)) === 0 && (await height(p)) === 50, '');
    await p.evaluate(() => H(150));
    await p.waitForTimeout(150);
    const mid = await height(p);
    check('grow: the shell is between the two sizes mid-way', mid > 55 && mid < 145, `${mid}`);
    await p.waitForTimeout(500);
    check('grow: it ends at the content and leaves no animation', (await height(p)) === 150 && (await anims(p)) === 0, `${await height(p)}`);
    await p.evaluate(() => H(20));
    await p.waitForTimeout(150);
    const down = await height(p);
    check('shrink: it goes down through the middle', down > 25 && down < 145, `${down}`);
    await p.waitForTimeout(500);
    // Content changing mid-animation: continue from the height it has, no jump.
    await p.evaluate(() => H(20));
    await p.evaluate(() => H(200));
    await p.waitForTimeout(150);
    const before = await height(p);
    await p.evaluate(() => H(40));
    await frames(p, 1); // one frame into the new target
    const after = await height(p);
    check('mid-way change: no jump to the new size', Math.abs(after - before) < 40 && after > 40, `${before} -> ${after}`);
    await p.waitForTimeout(600);
    check('mid-way change: it ends at the last size', (await height(p)) === 40, `${await height(p)}`);
    // Zero -> auto -> zero.
    await p.evaluate(() => H(0));
    await p.waitForTimeout(600);
    check('zero: collapses to nothing', (await height(p)) === 0, `${await height(p)}`);
    await p.evaluate(() => H(100));
    await p.waitForTimeout(150);
    const z = await height(p);
    check('zero: opens from nothing through the middle', z > 5 && z < 95, `${z}`);
    await p.waitForTimeout(500);
    check('zero: and settles', (await height(p)) === 100, `${await height(p)}`);
    check('no page errors (size)', p.problems.length === 0, p.problems.join(' | '));
  }
  {
    const p = await open('/size-early');
    await p.waitForTimeout(120);
    const h = await height(p);
    check('first change: a change right after the part loads still animates', h > 55 && h < 145, `${h}`);
  }
  {
    const p = await open('/size', { reducedMotion: 'reduce' });
    await p.evaluate(() => H(150));
    await p.waitForTimeout(60);
    check('reduced motion: the size changes at once', (await height(p)) === 150 && (await anims(p)) === 0, `${await height(p)}`);
  }
  {
    const p = await open('/fade');
    check('fade: the first state is A (40px), B is out of the flow', (await height(p)) === 40, `${await height(p)}`);
    await p.evaluate(() => flip('b'));
    await p.waitForTimeout(120);
    const mid = await height(p);
    check('fade: A to B grows through the middle while it cross-fades', mid > 45 && mid < 155, `${mid}`);
    // A -> B -> A quickly: comes back from where it is.
    await p.evaluate(() => flip('a'));
    await p.waitForTimeout(700);
    check('fade: B then A ends at A\'s height', (await height(p)) === 40, `${await height(p)}`);
    const vis = await p.evaluate(() => [getComputedStyle(document.querySelector('#a')).visibility, getComputedStyle(document.querySelector('#b')).visibility, getComputedStyle(document.querySelector('#a')).opacity, getComputedStyle(document.querySelector('#b')).opacity].join());
    check('fade: A shown, B out of the accessibility tree', vis === 'visible,hidden,1,0', vis);
    await p.evaluate(() => flip('b'));
    await p.waitForTimeout(700);
    const vis2 = await p.evaluate(() => [getComputedStyle(document.querySelector('#a')).visibility, getComputedStyle(document.querySelector('#b')).visibility].join());
    check('fade: and back to B, A leaves after the fade', vis2 === 'hidden,visible' && (await height(p)) === 160, `${vis2} ${await height(p)}`);
    check('no page errors (fade)', p.problems.length === 0, p.problems.join(' | '));
  }
} finally {
  await browser.close();
}

const failed = results.filter((ok) => !ok).length;
console.log(`\n${results.length - failed}/${results.length} checks passed`);
if (failed > 0 || results.length === 0) process.exit(1);

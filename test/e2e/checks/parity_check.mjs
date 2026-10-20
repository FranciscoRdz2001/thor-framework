// Parity of the two engines: the same scenarios on the same server HTML, once
// with the dart2js oracle engine (`THOR_INTERNAL_ENGINE=dart`, internal) and once with the
// lite one (the default), the DOM of the case compared after every step. A
// difference is a bug of the engine that diverged (the lite one is the
// reference), and it fails the check.
//
// What each check covers (the scenario list of the whole suite):
//
//   counter, lists (Watch.list), forms, controllers, dialogs, pickers,
//   animations, rows, dropdowns, hybrid views  ->  lite_conformance.mjs (the
//                                                  `lite` entry of tool/thor e2e)
//   gestures, autocomplete, confirm() and toast() from a state  ->  this file
//
//   tool/thor e2e parity                     (builds, serves, runs)
//   node test/e2e/checks/parity_check.mjs (after
//     THOR_INTERNAL_ENGINE=dart tool/thor export lab
//     node tool/thor_lite.mjs lab)
//
// `E2E_STAGE=<dir>` (tool/e2e.mjs): the builds were copied to
// <dir>/<app>/{site,site-lite}.
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { appDir } from '../../../tool/app_dir.mjs';
import { domQuiet, e2e, hydrated, repo, settle, trackHydration } from './lib/e2e.mjs';

const stage = process.env.E2E_STAGE;
const dir = (app, kind) => (stage ? `${stage}/${app}/${kind}` : `${appDir(app)}/build/${kind}`);
// `/<key>/` serves one build's page; `/engine.*` the engine files of any.
const sites = {
  g: dir('lab', 'site'),
  gl: dir('lab', 'site-lite'),
  x: dir('lab', 'site'),
  xl: dir('lab', 'site-lite'),
};
// The page of each key in the one multi-page app (test/fixtures/apps/lab).
const pages = { g: 'gestures', gl: 'gestures', x: 'edge-cases', xl: 'edge-cases' };
const html = (key) => readFileSync(resolve(repo, sites[key], `${pages[key]}.html`), 'utf8');

function handle(req, res) {
  const path = new URL(req.url, 'http://x').pathname;
  const page = /^\/([a-z]{1,2})\/$/.exec(path);
  if (page && sites[page[1]]) {
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
    res.end(html(page[1]));
    return true;
  }
  if (/^\/engine\./.test(path)) {
    for (const d of Object.values(sites)) {
      const file = resolve(repo, d, path.slice(1));
      if (existsSync(file)) {
        res.writeHead(200, { 'content-type': 'text/javascript', 'cache-control': 'no-store' });
        res.end(readFileSync(file));
        return true;
      }
    }
  }
  return false;
}

/** The markup of what a case shows, plus what markup does not say (live
 * properties of the controls, the focus). */
const snapshot = (selectors) => {
  // Markup with the attributes sorted: the order a script set them in is not a difference.
  const ser = (n) =>
    n.nodeType === 3
      ? n.data
      : n.nodeType === 1
        ? `<${n.localName}${[...n.attributes].map((a) => ` ${a.name}="${a.value}"`).sort().join('')}>${[...n.childNodes].map(ser).join('')}</${n.localName}>`
        : '';
  const parts = selectors.map((s) => [...document.querySelectorAll(s)].map(ser).join('\n'));
  const scope = selectors.flatMap((s) => [...document.querySelectorAll(`${s} input, ${s} button`)]);
  const props = scope.map((e) => `${e.disabled}${e.checked ?? ''}${e.value ?? ''}`).join(',');
  const a = document.activeElement;
  const focus = a && a !== document.body ? `${a.tagName}.${a.className}#${[...document.querySelectorAll(a.tagName)].indexOf(a)}` : '-';
  return `${parts.join('\n--\n')}\n${props}\n${focus}`;
};

const diff = (a, b) => {
  let i = 0;
  while (i < a.length && a[i] === b[i]) i++;
  return `dart …${a.slice(Math.max(0, i - 80), i + 100)}… vs lite …${b.slice(Math.max(0, i - 80), i + 100)}…`;
};

await e2e('parity', { site: sites.g, handle, timeout: 240_000 }, async (t) => {
  /**
   * Runs `steps` ([label, async (page) => void]) on both engines, from a page
   * loaded fresh each; compares the case's snapshot after every step.
   * `selectors`: what to snapshot. `view`: the page options.
   */
  async function scenario(name, dart, lite, selectors, steps, { view, quiet = 120, clock = false } = {}) {
    const trace = {};
    for (const [engine, key] of [['dart', dart], ['lite', lite]]) {
      const p = await t.page(view);
      await trackHydration(p);
      // `clock`: the page's timers can be run ahead (`p.clock.runFor`): a toast's 4 s is a step.
      if (clock) await p.clock.install();
      await p.goto(`${t.url}${key}/`, { waitUntil: 'load' });
      await p.mouse.move(1, 1);
      await hydrated(p);
      const snaps = [['load', await p.evaluate(snapshot, selectors)]];
      for (const [label, step] of steps) {
        await step(p);
        await domQuiet(p, quiet);
        await p.evaluate(() => new Promise((ok) => requestAnimationFrame(() => ok())));
        snaps.push([label, await p.evaluate(snapshot, selectors)]);
      }
      trace[engine] = { snaps, problems: p.problems };
      await p.context().close();
    }
    t.check(`${name}: no console errors`, !trace.dart.problems.length && !trace.lite.problems.length, [...trace.dart.problems, ...trace.lite.problems].join(' | '));
    let same = 0;
    for (let i = 0; i < trace.dart.snaps.length; i++) {
      const [label, d] = trace.dart.snaps[i];
      const l = trace.lite.snaps[i][1];
      if (d === l) same++;
      else t.check(`${name}: same DOM after "${label}"`, false, diff(d, l));
    }
    t.check(`${name}: same DOM in ${same} of ${trace.dart.snaps.length} snapshots`, same === trace.dart.snaps.length);
    return trace;
  }
  const lastOf = (trace) => trace.lite.snaps.at(-1)[1];
  const dialog = '#thor-confirm';
  const bar = '#thor-toast';

  // --- gestures (test/fixtures/apps/lab, /gestures): tap, long press, swipe, keys, drag, pinch ---
  {
    const center = async (loc) => {
      const b = await loc.boundingBox();
      return { ...b, cx: b.x + b.width / 2, cy: b.y + b.height / 2 };
    };
    const cdp = new WeakMap();
    const touches = async (p) => {
      if (!cdp.has(p)) cdp.set(p, await p.context().newCDPSession(p));
      return cdp.get(p);
    };
    const swipe = (key, dx, steps) => async (p) => {
      const b = await center(p.locator(`li[data-tk="${key}"]`));
      const x0 = b.x + b.width - 20;
      await p.mouse.move(x0, b.cy);
      await p.mouse.down();
      for (let i = 1; i <= steps; i++) await p.mouse.move(x0 + (dx * i) / steps, b.cy);
      await p.mouse.up();
      // A short swipe snaps back: wait for the row to rest before the next input.
      await settle(p, (k) => ['', '0px'].includes(document.querySelector(`li[data-tk="${k}"]`)?.style.getPropertyValue('--tg-x') ?? ''), key);
    };
    const drag = (dx, dy, n) => async (p) => {
      const b = await center(p.locator('[data-tg*="drag"]'));
      await p.mouse.move(b.x + 10, b.y + 10);
      await p.mouse.down();
      await p.mouse.move(b.x + 10 + dx, b.y + 10 + dy, { steps: n });
      await p.mouse.up();
    };
    const pinch = (from, to) => async (p) => {
      const b = await center(p.locator('[data-tg*="scale"]'));
      const c = await touches(p);
      const at = (d) => [{ x: b.cx - d, y: b.cy, id: 1 }, { x: b.cx + d, y: b.cy, id: 2 }];
      await c.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: at(from) });
      for (let d = from + 5; d <= to; d += 5) await c.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: at(d) });
      await c.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    };
    const g = await scenario(
      'gestures',
      'g',
      'gl',
      ['main'],
      [
        ['tap m2', async (p) => {
          const b = await center(p.locator('li[data-tk="m2"]'));
          await p.mouse.click(b.cx, b.cy);
        }],
        ['long press m2', async (p) => {
          const b = await center(p.locator('li[data-tk="m2"]'));
          await p.mouse.move(b.x + 20, b.y + 20);
          await p.mouse.down();
          await p.waitForTimeout(700);
          await p.mouse.up();
        }],
        ['swipe m1 left', swipe('m1', -300, 10)],
        ['short swipe m3 (snaps back)', swipe('m3', -30, 6)],
        ['Delete on m3', async (p) => {
          await p.locator('li[data-tk="m3"]').focus();
          await p.keyboard.press('Delete');
        }],
        ['Shift+ArrowLeft on m4', async (p) => {
          await p.locator('li[data-tk="m4"]').focus();
          await p.keyboard.press('Shift+ArrowLeft');
        }],
        ['restore the tray', async (p) => p.getByRole('button', { name: 'Restaurar bandeja' }).click()],
        ['double tap likes', async (p) => {
          const b = await center(p.locator('[data-tt="GesturesState.likesLabel"]'));
          await p.mouse.click(b.x + 5, b.y + 5);
          await p.mouse.click(b.x + 5, b.y + 5);
        }],
        ['drag the chip', drag(100, 40, 8)],
        ['drag it again', drag(20, 0, 5)],
        ['ArrowDown moves it by 10', async (p) => {
          await p.locator('[data-tg*="drag"]').focus();
          await p.keyboard.press('ArrowDown');
        }],
        ['pinch 40 -> 80 px', pinch(20, 40)],
        ['a touch swipe that snaps back', async (p) => {
          const b = await center(p.locator('li[data-tk="m2"]'));
          const c = await touches(p);
          const one = (x, y) => [{ x, y, id: 1 }];
          await c.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: one(b.cx, b.cy) });
          for (const d of [8, 16, 24]) await c.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: one(b.cx + d, b.cy) });
          await c.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
          await settle(p, () => ['', '0px'].includes(document.querySelector('li[data-tk="m2"]')?.style.getPropertyValue('--tg-x') ?? ''));
        }],
        ['the tap after it still taps', async (p) => {
          const b = await center(p.locator('li[data-tk="m2"]'));
          await p.waitForTimeout(200);
          await p.touchscreen.tap(b.cx, b.cy);
        }],
        ['+ zooms from the keyboard', async (p) => {
          await p.locator('[data-tg*="scale"]').focus();
          await p.keyboard.press('+');
        }],
      ],
      { view: { viewport: { width: 480, height: 1400 }, hasTouch: true }, quiet: 200 },
    );
    const end = lastOf(g);
    t.check('gestures: the lite run ended where gestures_check says', end.includes('Zoom: 2.25') && end.includes('♥ 1'), end.match(/Zoom[^<]*|♥[^<]*/g)?.join(' | '));
  }

  // --- autocomplete (test/fixtures/apps/lab (/edge-cases)): the panel, narrowing, arrows, picks ---
  {
    const root = (p, i) => p.locator('.case-autocomplete [data-t-ac]').nth(i);
    const field = (p, i = 0) => root(p, i).locator('input');
    const a = await scenario(
      'autocomplete',
      'x',
      'xl',
      ['.case-autocomplete'],
      [
        ['focus opens the panel', async (p) => field(p).click()],
        ['type "ap" narrows', async (p) => p.keyboard.type('ap')],
        ['ArrowDown x2 highlights', async (p) => {
          await p.keyboard.press('ArrowDown');
          await p.keyboard.press('ArrowDown');
        }],
        ['Enter picks', async (p) => p.keyboard.press('Enter')],
        ['clear and type "b"', async (p) => {
          await field(p).fill('');
          await p.keyboard.type('b');
        }],
        ['click blueberry', async (p) => p.locator('.case-autocomplete [role=option]', { hasText: 'blueberry' }).click()],
        ['no match closes', async (p) => {
          await field(p).fill('');
          await p.keyboard.type('zzz');
        }],
        ['Escape keeps the text', async (p) => {
          await field(p).fill('a');
          await p.keyboard.press('Escape');
        }],
        ['typing opens it again', async (p) => p.keyboard.type('p')],
        ['Home and End', async (p) => {
          await p.keyboard.press('ArrowDown');
          await p.keyboard.press('Home');
        }],
        ['a click outside closes', async (p) => p.mouse.click(900, 20)],
        ['the state\'s own list: type "ca"', async (p) => {
          await field(p, 1).click();
          await p.keyboard.type('ca');
        }],
        ['pick the highlighted', async (p) => {
          await p.keyboard.press('ArrowDown');
          await p.keyboard.press('Enter');
        }],
      ],
      { view: { viewport: { width: 1024, height: 900 } } },
    );
    t.check('autocomplete: the lite run picked', /Picked: [a-z]+ \(\d\)/.test(lastOf(a)), lastOf(a).slice(0, 200));
  }

  // --- autocomplete in rows that arrive later: ids stay unique per row ---
  {
    const a = await scenario(
      'autocomplete in rows',
      'x',
      'xl',
      ['.case-autocomplete-rows'],
      [
        ['Add row', async (p) => p.locator('.case-autocomplete-rows').getByRole('button', { name: 'Add row' }).click()],
        ['type in the new row', async (p) => {
          await p.locator('.case-autocomplete-rows input').last().click();
          await p.keyboard.type('a');
        }],
        ['highlight and pick', async (p) => {
          await p.keyboard.press('ArrowDown');
          await p.keyboard.press('Enter');
        }],
        ['the first row opens too', async (p) => {
          await p.locator('.case-autocomplete-rows input').first().click();
          await p.keyboard.type('b');
        }],
      ],
      { view: { viewport: { width: 1024, height: 900 } } },
    );
    const end = lastOf(a);
    const ids = end.match(/ id="ac-[^"]+-list"/g) ?? [];
    t.check('autocomplete in rows: three rows, each with its own list id', ids.length === 3 && new Set(ids).size === 3, ids.join(' '));
  }

  // --- an ask before the engine loads is not lost, on either engine ---
  {
    const outcome = {};
    for (const [engine, key] of [['dart', 'x'], ['lite', 'xl']]) {
      const p = await t.page({ viewport: { width: 800, height: 900 } });
      await trackHydration(p);
      let release;
      const held = new Promise((r) => (release = r));
      await p.route(/\/engine\.[^/]*\.js(\?|$)/, async (route) => {
        await held;
        await route.continue();
      });
      await p.goto(`${t.url}${key}/`, { waitUntil: 'domcontentloaded' });
      await p.locator('.case-feedback').getByRole('button', { name: 'Remove', exact: true }).nth(1).click();
      release();
      await hydrated(p);
      const opened = await settle(p, () => document.getElementById('thor-confirm')?.open === true);
      await p.locator('#thor-confirm [data-t-c=o]').click();
      await settle(p, () => document.querySelector('.case-feedback')?.textContent.includes('removed Luis'));
      await domQuiet(p, 120);
      outcome[engine] = { opened, snap: await p.evaluate(snapshot, ['.case-feedback', dialog, bar]), problems: p.problems };
      await p.context().close();
    }
    t.check('early ask: both engines open the dialog when they load', outcome.dart.opened === true && outcome.lite.opened === true, JSON.stringify([outcome.dart.opened, outcome.lite.opened]));
    t.check('early ask: same DOM at the end', outcome.dart.snap === outcome.lite.snap, diff(outcome.dart.snap, outcome.lite.snap));
    t.check('early ask: no console errors', !outcome.dart.problems.length && !outcome.lite.problems.length, [...outcome.dart.problems, ...outcome.lite.problems].join(' | '));
  }

  // --- confirm() and toast() from a state (test/fixtures/apps/lab (/edge-cases), the feedback case) ---
  {
    const feedback = ['.case-feedback', dialog, bar];
    const remove = (i) => async (p) => p.locator('.case-feedback').getByRole('button', { name: 'Remove', exact: true }).nth(i).click();
    const waitDialog = (open) => async (p) => settle(p, (o) => (document.getElementById('thor-confirm')?.open === true) === o, open);
    const no = async (p) => {
      await waitDialog(true)(p);
      await p.locator(`${dialog} [data-t-c=n]`).click();
      await waitDialog(false)(p);
    };
    const yes = async (p) => {
      await waitDialog(true)(p);
      await p.locator(`${dialog} [data-t-c=o]`).click();
    };
    const view = { viewport: { width: 800, height: 900 } };

    const cancelled = await scenario('feedback: confirm(), No', 'x', 'xl', feedback, [
      ['Remove Luis asks', remove(1)],
      ['No: nothing removed', no],
      ['Remove Luis, Esc', async (p) => {
        await remove(1)(p);
        await waitDialog(true)(p);
        await p.keyboard.press('Escape');
        await waitDialog(false)(p);
      }],
    ], { view });
    t.check('feedback: No leaves the row and says so', lastOf(cancelled).includes('cancelled Luis') && lastOf(cancelled).includes('Luis'), lastOf(cancelled).slice(0, 300));

    const removed = await scenario('feedback: confirm(), Yes, toast()', 'x', 'xl', feedback, [
      ['Remove Luis asks', remove(1)],
      ['Yes: the row goes and the toast says so', yes],
    ], { view });
    t.check('feedback: Yes removes the row and toasts', lastOf(removed).includes('removed Luis') && lastOf(removed).includes('Luis removed'), lastOf(removed).slice(0, 300));

    const twice = await scenario('feedback: two asks at once', 'x', 'xl', feedback, [
      ['Two asks: the first asks first', async (p) => p.locator('.case-feedback').getByRole('button', { name: 'Two asks' }).click()],
      ['Yes to the first', async (p) => {
        await yes(p);
        await settle(p, () => document.querySelector('#thor-confirm [data-t-c=t]')?.textContent === 'Second');
      }],
      ['No to the second', no],
    ], { view });
    t.check('feedback: each answer reaches its own ask', lastOf(twice).includes('both true false'), lastOf(twice).slice(0, 300));

    const say = await scenario('feedback: toast() text and duplicates', 'x', 'xl', feedback, [
      ['Say', async (p) => p.locator('.case-feedback').getByRole('button', { name: 'Say' }).click()],
      ['Say again (the same message is one)', async (p) => p.locator('.case-feedback').getByRole('button', { name: 'Say' }).click()],
      ['Fail waits its turn', async (p) => p.locator('.case-feedback').getByRole('button', { name: 'Fail' }).click()],
    ], { view });
    t.check('feedback: the message is text, never an element', !lastOf(say).includes('<b>Hello'), lastOf(say).slice(0, 300));

    // The toasts' own timers, run ahead on a fake clock: one at a time, the next waits, the bar hides.
    const timers = await scenario('feedback: toast() timers', 'x', 'xl', feedback, [
      ['Say', async (p) => p.locator('.case-feedback').getByRole('button', { name: 'Say' }).click()],
      ['Fail waits its turn', async (p) => p.locator('.case-feedback').getByRole('button', { name: 'Fail' }).click()],
      ['3.9 s: still the first', async (p) => p.clock.runFor(3900)],
      ['4.2 s: the second shows, with its own look', async (p) => p.clock.runFor(300)],
      ['8.5 s: the bar hides', async (p) => p.clock.runFor(4300)],
      ['Say, then 4.5 s', async (p) => {
        await p.locator('.case-feedback').getByRole('button', { name: 'Say' }).click();
        await p.clock.runFor(4500);
      }],
    ], { view, clock: true });
    const toastText = (i) => timers.lite.snaps[i][1].match(/id="thor-toast"[^>]*>([^<]*)/)?.[1];
    t.check('feedback timers: the first toast holds, then the second takes its place (with its own look)', toastText(4) === 'Hello ' && toastText(5) === 'Failed', timers.lite.snaps.map(([l], i) => `${l}: ${toastText(i)}`).join(' | '));
  }
});

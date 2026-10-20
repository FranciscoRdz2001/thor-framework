// Conformance of thor-lite (packages/thor_engine/lib/lite/runtime.js) against
// the dart2js engine: the same scenarios on the same server HTML, DOM
// snapshots compared after every step. Plus a fuzz of the lite keyed
// reconciliation (random permutations, inserts and removals) that checks
// order, node reuse and texts.
//
//   tool/thor build counter list_engine content_engine gallery_engine
//   tool/thor export lab          (with THOR_INTERNAL_ENGINE=dart: the dart2js oracle build)
//   tool/thor build-server realworld grid intl_store
//   node tool/thor_lite.mjs counter list_engine lab content_engine gallery_engine realworld grid intl_store
//   (optional, with the Flutter SDK: tool/thor build hybrid && node tool/thor_lite.mjs hybrid)
//   node test/e2e/checks/lite_conformance.mjs
//
// test/fixtures/apps/realworld is a server app: it runs against test/e2e/mock_api, and
// the lite pages are the same server's with the engine's URL answered by
// the lite bundle (test/fixtures/apps/realworld/build/lite).
import { spawn } from 'node:child_process';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { createServer } from 'node:net';
import { join, resolve } from 'node:path';
import { domQuiet, e2e, hydrated, repo, trackHydration } from './lib/e2e.mjs';

const sites = {
  c: 'test/fixtures/apps/counter/build/site',
  cl: 'test/fixtures/apps/counter/build/site-lite',
  l: 'test/fixtures/apps/list_engine/build/site',
  ll: 'test/fixtures/apps/list_engine/build/site-lite',
  d: 'test/fixtures/apps/lab/build/site',
  dl: 'test/fixtures/apps/lab/build/site-lite',
  k: 'test/fixtures/apps/lab/build/site',
  kl: 'test/fixtures/apps/lab/build/site-lite',
  r: 'test/fixtures/apps/lab/build/site',
  rl: 'test/fixtures/apps/lab/build/site-lite',
  e: 'test/fixtures/apps/content_engine/build/site',
  el: 'test/fixtures/apps/content_engine/build/site-lite',
  x: 'test/fixtures/apps/lab/build/site',
  xl: 'test/fixtures/apps/lab/build/site-lite',
  g: 'test/fixtures/apps/gallery_engine/build/site',
  gl: 'test/fixtures/apps/gallery_engine/build/site-lite',
  a: 'test/fixtures/apps/lab/build/site',
  al: 'test/fixtures/apps/lab/build/site-lite',
};
// The sites of several scenarios are one multi-page app (test/fixtures/apps/lab):
// the page of each key, where it is not the site's index.
const pages = { d: 'dates', dl: 'dates', k: 'controls', kl: 'controls', r: 'rows', rl: 'rows', x: 'edge-cases', xl: 'edge-cases', a: 'animations', al: 'animations' };
// `E2E_STAGE=<dir>` (tool/e2e.mjs): the static apps' builds were copied to
// <dir>/<app>/{site,site-lite}, so the next engine's build of an app can
// replace apps/<app>/build while this check still runs.
if (process.env.E2E_STAGE) {
  for (const key of Object.keys(sites)) {
    sites[key] = sites[key].replace(/^test\/fixtures\/apps\/(\w+)\/build\//, `${process.env.E2E_STAGE}/$1/`);
  }
}
// test/fixtures/apps/hybrid needs the Flutter SDK to build: its scenario runs when it was
// built (and copied to lite), and says it skipped otherwise.
const hybridBuilt = existsSync(join(repo, 'test/fixtures/apps/hybrid/build/site-lite'));
if (hybridBuilt) Object.assign(sites, { h: 'test/fixtures/apps/hybrid/build/site', hl: 'test/fixtures/apps/hybrid/build/site-lite' });
const runtime = readFileSync(join(repo, 'packages/thor_engine/lib/lite/runtime.js'), 'utf8');
const html = (key) => readFileSync(resolve(repo, sites[key], `${pages[key] ?? 'index'}.html`), 'utf8');

// A page with only a keyed list whose items an action sets from `data-tx`
// (keys separated by commas; a key with `*` changes its text): the runtime
// with its `lists` part.
const listsPart = readFileSync(join(repo, 'packages/thor_engine/lib/lite/parts/lists.js'), 'utf8');
const fuzzPage = `<!DOCTYPE html><html><head><base href="/"></head><body>
<button id="set" data-t-on="click:FuzzState.set" data-tx=""></button>
<ul data-tl="FuzzState.items" data-tlk="FuzzState.key"><li data-tk="a"><b data-tf="FuzzState.text">a</b></li><template data-tlt="FuzzState.items"><li><b data-tf="FuzzState.text"></b><i data-x="{{key}}"></i></li></template></ul>
<script>${runtime.replace('// @thor-lite-parts', () => listsPart)}
thor.def('FuzzState', ($) => {
  const items = $.state('items', [{ k: 'a', t: 'a' }]);
  return {
    items: () => items.value,
    key: (i) => i.k,
    text: (i) => i.t,
    set: (arg) => { items.value = arg ? arg.split(',').map((k) => ({ k: k.replace('*', ''), t: k })) : []; },
  };
});
</script></body></html>`;

// thor dev's lite bundle (`lite_bundle --dev`): the runtime with the
// json and dev_state parts, and a state with a number, a list and a date (not JSON).
const devPart = ['json', 'dev_state'].map((p) => readFileSync(join(repo, `packages/thor_engine/lib/lite/parts/${p}.js`), 'utf8')).join('\n');
const devPage = `<!DOCTYPE html><html><head><base href="/"></head><body>
<button id="inc" data-t-on="click:DevState.inc">+</button><span id="n" data-tt="DevState.label">0</span><span id="tags" data-tt="DevState.tags">a</span>
<script>${runtime.replace('// @thor-lite-parts', () => devPart)}
thor.def('DevState', ($) => {
  const count = $.state('count', 0), tags = $.state('tags', ['a']), when = $.state('when', new Date(0));
  return {
    label: () => String(count.value),
    tags: () => tags.value.join(','),
    inc: () => { count.value++; tags.value = [...tags.value, 'x']; when.value = new Date(count.value); },
    $s: { count, tags, when },
  };
});
</script></body></html>`;

function handle(req, res) {
  const path = new URL(req.url, 'http://x').pathname;
  const send = (type, body) => {
    res.writeHead(200, { 'content-type': type, 'cache-control': 'no-store' });
    res.end(body);
    return true;
  };
  const page = /^\/([a-z]{1,2})\/$/.exec(path);
  if (page && sites[page[1]]) return send('text/html; charset=utf-8', html(page[1]));
  if (path === '/f/') return send('text/html; charset=utf-8', fuzzPage);
  if (path === '/ds/') return send('text/html; charset=utf-8', devPage);
  if (/^\/engine\./.test(path)) {
    for (const dir of Object.values(sites)) {
      const file = resolve(repo, dir, path.slice(1));
      if (existsSync(file)) return send('text/javascript', readFileSync(file));
    }
  }
  return false;
}

// Body markup plus the live properties markup doesn't show (and where the
// keyboard focus is).
const snapshot = () => {
  const props = [...document.querySelectorAll('input,button')].map((e) => `${e.disabled}${e.checked ?? ''}${e.value ?? ''}`).join(',');
  const a = document.activeElement;
  const focus = a && a !== document.body ? `${a.tagName}#${[...document.querySelectorAll(a.tagName)].indexOf(a)}` : '-';
  return document.body.outerHTML + '\n' + props + '\n' + focus;
};

await e2e('lite-conformance', { site: sites.c, handle, timeout: 300_000 }, async (t) => {
  for (const dir of Object.values(sites)) {
    if (!readdirSync(resolve(repo, dir)).some((f) => f.startsWith('engine.'))) throw new Error(`no engine in ${dir}`);
  }

  // Runs `steps` ([label, async (page) => void]) on both engines; compares.
  // `lazyLoad`: the page's JSON disagrees with its markup (injected), so at
  // load only the eager engine rewrites the DOM; lite must leave it as sent.
  async function scenario(name, dart, lite, steps, { inject, lazyLoad, settle = 0, prepare, pageOptions } = {}) {
    const trace = {};
    for (const [engine, path] of [['dart', dart], ['lite', lite]]) {
      const p = await t.page(pageOptions);
      await trackHydration(p);
      if (prepare) await prepare(p, engine);
      if (inject) await p.route(`**/${path}/`, async (route) => {
        const r = await route.fetch();
        await route.fulfill({ response: r, body: inject(await r.text()) });
      });
      await p.goto(path.startsWith('http') ? path : t.url + path + '/');
      await hydrated(p);
      const snaps = [['load', await p.evaluate(snapshot)]];
      for (const [label, step] of steps) {
        await step(p);
        // Dialogs report open/close in a task of their own (`toggle`): wait
        // until the DOM has been quiet `settle` ms (by the page's own clock).
        if (settle) await domQuiet(p, settle);
        await p.evaluate(() => new Promise((ok) => requestAnimationFrame(() => ok())));
        snaps.push([label, await p.evaluate(snapshot)]);
      }
      trace[engine] = { snaps, problems: p.problems };
      await p.context().close();
    }
    t.check(`${name}: no console errors`, !trace.dart.problems.length && !trace.lite.problems.length, [...trace.dart.problems, ...trace.lite.problems].join(' | '));
    let same = 0;
    if (lazyLoad) {
      const [d, l] = [trace.dart.snaps.shift()[1], trace.lite.snaps.shift()[1]];
      t.check(`${name}: at load dart applied the JSON, lite left the server's DOM`, d !== l && l.includes('>0</span>'), diff(d, l));
    }
    for (let i = 0; i < trace.dart.snaps.length; i++) {
      const [label, d] = trace.dart.snaps[i], l = trace.lite.snaps[i][1];
      if (d === l) same++;
      else t.check(`${name}: same DOM after "${label}"`, false, diff(d, l));
    }
    t.check(`${name}: same DOM in ${same} of ${trace.dart.snaps.length} snapshots`, same === trace.dart.snaps.length);
    return trace;
  }

  const diff = (a, b) => {
    let i = 0;
    while (i < a.length && a[i] === b[i]) i++;
    return `dart …${a.slice(Math.max(0, i - 60), i + 80)}… vs lite …${b.slice(Math.max(0, i - 60), i + 80)}…`;
  };
  const click = (text) => async (p) => p.locator('button', { hasText: text }).first().click();
  const clicks = (text, n) => async (p) => {
    for (let i = 0; i < n; i++) await p.locator('button', { hasText: text }).first().click();
  };

  // --- counter ---------------------------------------------------------------
  const counter = await scenario('counter', 'c', 'cl', [
    ['+', click('+')],
    ['reset enabled → reset', click('Reiniciar')],
    ['+ ×5 (high label appears)', clicks('+', 5)],
    ['+ (label inside the swapped subtree updates)', click('+')],
    ['− ×2 (back below 5)', clicks('−', 2)],
    ['+ ×3 (appears again)', clicks('+', 3)],
    ['reset', click('Reiniciar')],
    ['− (negative)', click('−')],
    ['keyboard: Enter on +', async (p) => {
      await p.locator('button', { hasText: '+' }).first().focus();
      await p.keyboard.press('Enter');
    }],
    ['keyboard: Space on +', async (p) => p.keyboard.press(' ')],
  ]);
  const last = counter.lite.snaps.at(-1)[1];
  t.check('counter: lite ends at 1 with reset enabled', /data-tt="CounterState.label">1</.test(last) && !/<button class="f"[^>]*disabled=""/.test(last), last.slice(0, 200));
  const high = counter.lite.snaps[3][1];
  t.check('counter: high label shows the count', high.includes('¡Ya van 5!'), high.slice(0, 300));

  // The server's JSON (`#thor-state`) restores fields: lite reads it lazily.
  await scenario('counter with #thor-state', 'c', 'cl', [['+', click('+')], ['+', click('+')], ['−', click('−')]], {
    lazyLoad: true,
    inject: (h) => h.replace('</body>', '<script type="application/json" id="thor-state">{"CounterState.count":7}</script></body>'),
  });

  // A tap before the engine loaded is queued by the loader and replayed.
  for (const [engine, path] of [['dart', 'c'], ['lite', 'cl']]) {
    const p = await t.page();
    await trackHydration(p);
    await p.goto(t.url + path + '/', { waitUntil: 'domcontentloaded' });
    await p.locator('button', { hasText: '+' }).first().click();
    await hydrated(p);
    // Negative check (the tap must not be replayed twice): let any late replay
    // happen, 300 ms with the DOM quiet.
    await domQuiet(p, 300);
    const label = await p.locator('[data-tt="CounterState.label"]').textContent();
    t.check(`counter (${engine}): early tap counted once`, label === '1', label);
    await p.context().close();
  }

  // --- list --------------------------------------------------------------------
  const removeRow = (i) => async (p) => p.locator('li button').nth(i).click();
  const list = await scenario('list_engine', 'l', 'll', [
    ['create 1k', click('Crear 1,000')],
    ['update every 10th', click('Actualizar cada 10ª')],
    ['swap', click('Intercambiar')],
    ['remove row 5', removeRow(4)],
    ['remove first', click('Quitar primera')],
    ['swap again', click('Intercambiar')],
    ['append 1k', click('Agregar 1,000')],
    ['remove last row', async (p) => p.locator('li button').last().click()],
    ['remove row 500', removeRow(500)],
    ['update every 10th again', click('Actualizar cada 10ª')],
    ['create 1k (replace)', click('Crear 1,000')],
    ['clear', click('Limpiar')],
    ['swap on empty (no-op)', click('Intercambiar')],
    ['append 1k to empty', click('Agregar 1,000')],
    ['remove first ×3', clicks('Quitar primera', 3)],
    ['clear again', click('Limpiar')],
  ]);
  const rows = (s) => (s.match(/<li [^>]*data-tk=/g) || []).length;
  t.check(
    'list: row counts along the way',
    list.lite.snaps.map(([, s]) => rows(s)).join(',') === '0,1000,1000,1000,999,998,998,1998,1997,1996,1996,1000,0,0,1000,997,0',
    list.lite.snaps.map(([, s]) => rows(s)).join(','),
  );

  // --- dates: DateTime / TimeOfDay arguments, DialogController, the pickers ---
  const cal = (p) => p.locator('main > div').first().locator('[data-t-date]');
  const day = (root, n) => root.locator('td', { hasText: new RegExp(`^${n}$`) }).first();
  const dlg = (p, id) => p.locator(`dialog#${id}`);
  const key = (k) => async (p) => p.keyboard.press(k);
  const dates = await scenario(
    'dates',
    'd',
    'dl',
    [
      ['calendar: pick the 10th', async (p) => day(cal(p), 10).click()],
      ['calendar: next month', async (p) => cal(p).locator('[data-t-nav="1"]').click()],
      ['calendar: next month again', async (p) => cal(p).locator('[data-t-nav="1"]').click()],
      ['calendar: previous month', async (p) => cal(p).locator('[data-t-nav="-1"]').click()],
      ['calendar: pick the 3rd there', async (p) => day(cal(p), 3).click()],
      ['keyboard: ArrowRight', key('ArrowRight')],
      ['keyboard: ArrowDown', key('ArrowDown')],
      ['keyboard: End', key('End')],
      ['keyboard: PageDown (next month)', key('PageDown')],
      ['keyboard: Shift+PageUp (a year back, clamped)', key('Shift+PageUp')],
      ['keyboard: Enter selects', key('Enter')],
      ['years: open the list', async (p) => cal(p).locator('[data-t-years]').click()],
      ['years: pick 2027', async (p) => cal(p).locator('[data-t-year-list] button', { hasText: '2027' }).click()],
      ['dialog (DialogTrigger): open', click('Elegir entrega')],
      ['dialog: a Saturday is disabled', async (p) => day(dlg(p, 'due'), 26).click({ force: true })],
      ['dialog: pick a weekday', async (p) => day(dlg(p, 'due'), 14).click()],
      ['dialog: OK', async (p) => dlg(p, 'due').locator('[data-t-pick-ok]').click()],
      ['dialog (DialogController.open from the state)', click('Desde el estado')],
      ['dialog: pick another day', async (p) => day(dlg(p, 'due'), 22).click()],
      ['dialog: Escape cancels', key('Escape')],
      ['dialog: open from the state again', click('Desde el estado')],
      ['dialog: next month, pick, OK', async (p) => {
        await dlg(p, 'due').locator('[data-t-nav="1"]').click();
        await day(dlg(p, 'due'), 5).click();
        await dlg(p, 'due').locator('[data-t-pick-ok]').click();
      }],
      ['time dialog: open', click('Elegir hora')],
      ['time dialog: 14:45, OK', async (p) => {
        await dlg(p, 'time').locator('input[type=time]').fill('14:45');
        await dlg(p, 'time').locator('[data-t-pick-ok]').click();
      }],
      ['form field: open its calendar', async (p) => p.locator('[data-t-date-open]').first().click()],
      ['form field: pick, OK', async (p) => {
        await day(dlg(p, 'from'), 20).click();
        await dlg(p, 'from').locator('[data-t-pick-ok]').click();
      }],
    ],
    { settle: 40 },
  );
  const lastDates = dates.lite.snaps.at(-1)[1];
  t.check(
    'dates: lite labels after the scenario',
    ['Elegiste: 2026-01-01', 'Mes a la vista: 2027-01', 'Entrega: 2026-10-05', 'Hora: 14:45'].every((s) => lastDates.includes(s)),
    lastDates.match(/data-tt="DatesState\.\w+">[^<]*/g)?.join(' | '),
  );
  t.check('dates: the form field got the picked day', /2026-10-20/.test(lastDates.split('\n').at(-2)), '');

  // The dialog opened natively first: its `toggle` creates the (lazy) state
  // that owns its DialogController, then the pick reaches that state.
  await scenario(
    'dates (dialog before any state event)',
    'd',
    'dl',
    [
      ['open with DialogTrigger', click('Elegir entrega')],
      ['pick, OK', async (p) => {
        await day(dlg(p, 'due'), 16).click();
        await dlg(p, 'due').locator('[data-t-pick-ok]').click();
      }],
      ['open from the state, Escape', async (p) => {
        await click('Desde el estado')(p);
        await p.locator('dialog[open]').waitFor();
        await p.keyboard.press('Escape');
      }],
    ],
    { settle: 40 },
  );

  // --- controls: every controller, Duration / DateTime / TimeOfDay -------------
  const field = (p) => p.locator('input[data-ttc]');
  const controls = await scenario(
    'controls',
    'k',
    'kl',
    [
      ['scroll the feed to 150', async (p) => {
        await p.locator('[data-tsc]').evaluate((el) => (el.scrollTop = 150));
      }],
      ['Al final (jumpTo max)', click('Al final')],
      ['Arriba (jumpTo 0)', click('Arriba')],
      ['type in the field', async (p) => field(p).fill('Carla')],
      ['Limpiar (clear)', click('Limpiar')],
      ['Poner Bea (text =)', click('Poner Bea')],
      ['Enfocar (requestFocus)', click('Enfocar')],
      ['type while focused', async (p) => p.keyboard.type('triz')],
      ['Quitar foco (unfocus)', click('Quitar foco')],
      ['click into the field', async (p) => field(p).click()],
      ['Tab away', key('Tab')],
      ['Abrir desde el estado (open)', click('Abrir desde el estado')],
      ['Cerrar (close from the state)', async (p) => p.locator('dialog#hoja button', { hasText: 'Cerrar' }).click()],
      ['Abrir sin estado (native)', click('Abrir sin estado')],
      ['Escape (isOpen follows)', key('Escape')],
      ['+95 s', click('+95 s')],
      ['+95 s again (over 2 min)', click('+95 s')],
      ['+1 h (afternoon? no)', click('+1 h')],
      ['+1 h ×3 (afternoon)', clicks('+1 h', 3)],
      ['−200 s', click('−200 s')],
      ['+1 día', click('+1 día')],
      ['+31 días (next month)', click('+31 días')],
      ['−7 días ×10 (back in time)', clicks('−7 días', 10)],
      ['−200 s ×80 (negative duration)', clicks('−200 s', 80)],
      // A persisted field (state(cookie:)): the reload starts from it.
      ['Cambiar vista (persisted)', click('Cambiar vista')],
      ['reload (the cookie comes back)', async (p) => {
        await p.reload();
        await p.waitForFunction(() => document.body.textContent.includes('Vista compacta'));
      }],
      // PageNavigator: an unsafe location is refused (THOR-S008), a safe
      // one loads the next page as a document (the URL must change).
      ['Probar javascript: (refused)', click('Probar javascript:')],
      ['Ir a la vista 2 (a new document)', async (p) => {
        await Promise.all([p.waitForURL(/[?]vista=2$/), click('Ir a la vista 2')(p)]);
        await p.waitForLoadState('load');
      }],
    ],
    { settle: 40 },
  );
  const refused = controls.lite.snaps.find(([n]) => n.startsWith('Probar javascript:'))?.[1] ?? '';
  t.check(
    'controls: an unsafe PageNavigator location is refused (lite)',
    refused.includes('Bloqueado (THOR-S008)'),
    refused.match(/data-tt="ControlsState\.navNote">[^<]*/)?.[0],
  );
  const reloaded = controls.lite.snaps.find(([n]) => n.startsWith('reload'))?.[1] ?? '';
  t.check('controls: a persisted field survives a reload (lite)', reloaded.includes('Vista compacta'), reloaded.match(/Vista \w+/)?.[0]);
  // Before the reload (which starts every field but the persisted one over).
  const lastControls = controls.lite.snaps.find(([n]) => n.startsWith('−200 s ×80'))[1];
  t.check(
    'controls: lite labels after the scenario',
    ['Hola, Beatriz (7)', 'Sin foco', 'Hoja cerrada', 'Desplazado: 0 de'].every((s) => lastControls.includes(s)),
    lastControls.match(/data-tt="ControlsState\.\w+">[^<]*/g)?.join(' | '),
  );

  // PageNavigator.pop / canPop / reload: a fresh page has nothing to go back to
  // (pop loads the fallback), a page reached from this site has (pop goes back),
  // reload loads the document again.
  // `click` matches a substring, any case: "¿Puedo volver?" has "Volver" in it.
  const exact = (text) => async (p) => p.getByRole('button', { name: text, exact: true }).click();
  const noteIs = (text) => async (p) =>
    p.waitForFunction((t) => document.querySelector('[data-tt="ControlsState.navNote"]').textContent === t, text);
  // A back may restore the page from the back-forward cache, which fires no `load`.
  const navigates = (re, step) => async (p) => {
    await Promise.all([p.waitForURL(re, { waitUntil: 'commit' }), step(p)]);
    await p.waitForTimeout(200);
    await hydrated(p);
  };
  // (`<base href="/">`: the fallback `?vista=3` is the site's root, the counter.)
  let home;
  const back = await scenario(
    'controls (back)',
    'k',
    'kl',
    [
      ['¿Puedo volver? (a fresh page)', async (p) => {
        home = p.url();
        await click('¿Puedo volver?')(p);
        await noteIs('Puede volver: false')(p);
      }],
      ['Volver (the fallback)', navigates(/[?]vista=3$/, exact('Volver'))],
      ['the controls page again (an entry to go back to)', async (p) => {
        await p.goto(home);
        await hydrated(p);
      }],
      ['Recargar (a new document)', async (p) => {
        await p.evaluate(() => (window.__same = 1));
        await Promise.all([p.waitForNavigation(), exact('Recargar')(p)]);
        await hydrated(p);
        t.check('controls: reload loads the document again', (await p.evaluate(() => window.__same)) == null);
      }],
      ['¿Puedo volver? (an entry before this one)', async (p) => {
        await click('¿Puedo volver?')(p);
        await noteIs('Puede volver: true')(p);
      }],
      ['Volver (history back)', navigates(/[?]vista=3$/, exact('Volver'))],
    ],
    { settle: 40 },
  );
  t.check(
    'controls: pop, canPop and reload on both engines',
    ['dart', 'lite'].every((e) => back[e].snaps.length === 7),
    JSON.stringify(back.lite.snaps.map(([n]) => n)),
  );

  // --- gallery_engine: native controls, a static helper, an encoded enum ------
  const control = (sel, i = 0) => async (p) => p.locator(sel).nth(i).click();
  const gallery = await scenario('gallery_engine', 'g', 'gl', [
    ['checkbox 1', control('input[type=checkbox]', 0)],
    ['checkbox 2', control('input[type=checkbox]', 1)],
    ['tristate: all', control('[data-t-on="change:GalleryState.cycleAll"]')],
    ['tristate: none', control('[data-t-on="change:GalleryState.cycleAll"]')],
    ['tristate: mixed', control('[data-t-on="change:GalleryState.cycleAll"]')],
    ['switch', control('[data-t-on="change:GalleryState.setDark"]')],
    ['radio 2', control('input[type=radio]', 1)],
    ['radio 3', control('input[type=radio]', 2)],
    ['range', async (p) => p.locator('input[type=range]').fill('25')],
    ['select', async (p) => p.locator('[data-t-on="change:GalleryState.setBranch"]').selectOption({ index: 2 })],
  ]);
  t.check('gallery_engine: lite summary after the scenario', /Propina: 25%/.test(gallery.lite.snaps.at(-1)[1]), gallery.lite.snaps.at(-1)[1].match(/Ticket:[^<]*/)?.[0]);

  // --- animations: AnimationController (status, isAnimating, repeat, stop) -------
  // The keyframes run in the compositor (no DOM change); the status texts and
  // the Watch of isAnimating are what the DOM shows. Reduced motion: every
  // playback jumps to its end, so each step is deterministic.
  const revealIs = (text) => async (p) =>
    p.waitForFunction((t) => document.querySelector('[data-tt="MotionState.revealLabel"]').textContent === t, text);
  for (const [label, pageOptions] of [
    ['animations (reduced motion)', { reducedMotion: 'reduce' }],
    ['animations', {}],
  ]) {
    // Without reduced motion, a step waits for the playback to end before
    // the snapshot, so both engines are compared at rest.
    const rest = (text) => (pageOptions.reducedMotion ? [] : [[`until ${text}`, revealIs(text)]]);
    const anim = await scenario(
      label,
      'a',
      'al',
      [
        ['Mostrar (forward)', click('Mostrar')],
        ...rest('Visible'),
        ['Ocultar (reverse)', click('Ocultar')],
        ...rest('Oculto'),
        ['Alternar (toggle)', click('Alternar')],
        ...rest('Visible'),
        ['Alternar again', click('Alternar')],
        ...rest('Oculto'),
        ['Girar (repeat)', click('Girar')],
        // Reduced motion: repeat jumps to the end, nothing plays, no Detener.
        ...(pageOptions.reducedMotion ? [] : [['Detener (stop)', click('Detener')]]),
        ['Latir (forward from 0)', click('Latir')],
      ],
      { pageOptions },
    );
    const lastAnim = anim.lite.snaps.at(-1)[1];
    t.check(`${label}: lite ends hidden with the spinner stopped`, lastAnim.includes('data-tt="MotionState.revealLabel">Oculto<') && lastAnim.includes('Girar'), lastAnim.match(/data-tt="MotionState\.revealLabel">[^<]*/)?.[0]);
  }

  // --- rows: row states (the row itself, enum, int), row attributes, fields ----
  const row = (p, i) => p.locator('[data-tl] > [data-tk]').nth(i);
  const inRow = (i, text) => async (p) => row(p, i).locator('button', { hasText: text }).first().click();
  const quick = (p) => p.locator('input[name=quick]');
  const titleField = (p) => p.locator('input[name=title]');
  const rowsRun = await scenario('rows', 'r', 'rl', [
    ['row 1: star (int state 0 → 1)', inRow(0, '0/3')],
    ['row 1: star again', inRow(0, '1/3')],
    ['row 1: priority low → mid (enum state + data-prio)', inRow(0, 'baja')],
    ['row 1: check (the row element changes state)', async (p) => row(p, 0).locator('input[type=checkbox]').click()],
    ['row 2: uncheck', async (p) => row(p, 1).locator('input[type=checkbox]').click()],
    ['row 3: rename (text, hidden field, aria-label)', inRow(2, '!')],
    ['row 3: unsafe URL (href removed)', inRow(2, 'js')],
    ['row 4: star ×3 (3 → 0 wraps)', async (p) => {
      for (let i = 0; i < 1; i++) await inRow(3, '3/3')(p);
    }],
    ['reverse', click('Invertir')],
    ['quick field: Enter adds a row (cloned, states from the template)', async (p) => {
      await quick(p).fill('Regar plantas');
      await quick(p).press('Enter');
    }],
    ['new row: star, priority, check', async (p) => {
      const last = (p) => p.locator('[data-tl] > [data-tk]').last();
      await last(p).locator('button', { hasText: '0/3' }).click();
      await last(p).locator('button', { hasText: 'media' }).click();
      await last(p).locator('input[type=checkbox]').click();
    }],
    ['quick field: blank Enter (ignored)', async (p) => {
      await quick(p).fill('   ');
      await quick(p).press('Enter');
    }],
    ['remove row 2', inRow(1, '×')],
    ['all done', click('Todas hechas')],
    ['form: submit empty (message instead of the bubble)', click('Guardar')],
    ['form: 2 letters, leave the field', async (p) => {
      await titleField(p).fill('ab');
      await titleField(p).blur();
    }],
    ['form: fixed while typing', async (p) => titleField(p).fill('abc')],
    ['form: valid submit adds a row', async (p) => {
      await titleField(p).fill('Hacer la tarea');
      await click('Guardar')(p);
    }],
    ['clear', click('Vaciar')],
    ['reset (server rows back, reused templates)', click('Restaurar')],
    ['row 4: priority ×3 (back to low)', async (p) => {
      for (const t of ['baja', 'media', 'alta']) await inRow(3, t)(p);
    }],
  ]);
  const lastRows = rowsRun.lite.snaps.at(-1)[1];
  t.check(
    'rows: lite ends with 4 rows, one done',
    (lastRows.match(/<[a-z]+ [^>]*data-tk=/g) || []).length === 4 && /1 de 4 hechas/.test(lastRows),
    lastRows.match(/data-tt="RowsState\.summary">[^<]*/)?.[0],
  );
  const unsafe = rowsRun.lite.snaps[7][1];
  t.check('rows: an unsafe URL never reaches href', !/href="javascript:/.test(unsafe), '');

  // --- content_engine: form validation, chips, Timer, dialogs -----------------
  const email = (p) => p.locator('input[name=email]');
  const password = (p) => p.locator('input[name=password]');
  const content = await scenario(
    'content_engine',
    'e',
    'el',
    [
      ['chip Postres', click('Postres')],
      ['chip Café (off)', click('Café')],
      ['login: submit empty', click('Entrar')],
      ['login: bad email, leave', async (p) => {
        await email(p).fill('ana');
        await email(p).blur();
      }],
      ['login: fix email while typing', async (p) => email(p).fill('ana@x.mx')],
      ['login: short password, submit', async (p) => {
        await password(p).fill('abc');
        await click('Entrar')(p);
      }],
      ['login: valid, submit (welcome)', async (p) => {
        await password(p).fill('abcdefgh');
        await click('Entrar')(p);
      }],
      ['menu: Duplicar (snackbar, 3 s Timer)', async (p) => {
        await p.locator('button', { hasText: '⋮' }).click();
        await p.locator('[popover] button, [popover] [role=menuitem]', { hasText: 'Duplicar' }).first().click();
      }],
      ['menu: Eliminar before it hides (Timer cancelled, restarted)', async (p) => {
        await p.waitForTimeout(1500);
        await p.locator('button', { hasText: '⋮' }).click();
        await p.locator('[popover] button, [popover] [role=menuitem]', { hasText: 'Eliminar' }).first().click();
      }],
      ['2 s later: still shown', async (p) => p.waitForTimeout(2000)],
      ['1.3 s later: hidden', async (p) => p.waitForTimeout(1300)],
      ['dialog: Cobrar, Cancelar', async (p) => {
        await click('Cobrar')(p);
        await p.locator('dialog#confirm[open]').waitFor();
        await p.locator('dialog#confirm button', { hasText: 'Cancelar' }).click();
      }],
    ],
    { settle: 40 },
  );
  const cs = (label) => content.lite.snaps.find(([l]) => l === label)[1];
  t.check('content_engine: empty submit shows the page\'s messages', cs('login: submit empty').includes('Escribe tu correo') && cs('login: submit empty').includes('aria-invalid="true"'), '');
  t.check('content_engine: welcome after a valid submit', cs('login: valid, submit (welcome)').includes('Hola, ana@x.mx'), '');
  t.check(
    'content_engine: the snackbar outlives the first Timer, then hides',
    /Elegiste: Eliminar/.test(cs('2 s later: still shown')) && cs('2 s later: still shown') !== cs('1.3 s later: hidden'),
    '',
  );

  // --- edge_cases: transitions (onEnd once per change) and DropdownMenu -----------
  const menus = (p) => p.locator('.case-dropdown-menu [data-t-dd]');
  const opener = (p, i) => menus(p).nth(i).locator('button[aria-haspopup]');
  // One Cycle click, then until its `onEnd` was counted: under the parallel
  // e2e load a fixed wait is shorter than the transitions of the slower engine.
  const endsOf = (p) => p.evaluate(() => Number(/onEnd: (\d+)/.exec(document.body.innerText)?.[1] ?? -1));
  const cycle = async (p) => {
    const before = await endsOf(p);
    await p.locator('button', { hasText: 'Cycle (' }).click();
    await p.waitForFunction((n) => Number(/onEnd: (\d+)/.exec(document.body.innerText)?.[1] ?? -1) > n, before, { timeout: 10_000 });
    await p.waitForTimeout(700);
  };
  const edge = await scenario(
    'edge_cases',
    'x',
    'xl',
    [
      ['cycle (transitions run, onEnd once)', cycle],
      ['cycle twice', async (p) => {
        await cycle(p);
        await cycle(p);
      }],
      ['fruit: open with ArrowDown', async (p) => {
        await opener(p, 0).focus();
        await p.keyboard.press('ArrowDown');
      }],
      ['fruit: ArrowDown, Enter', async (p) => {
        await p.keyboard.press('ArrowDown');
        await p.keyboard.press('Enter');
      }],
      ['fruit: type-ahead "a" (closed)', async (p) => p.keyboard.press('a')],
      ['fruit: "a" again cycles, End, Enter', async (p) => {
        await p.keyboard.press('a');
        await p.keyboard.press('End');
        await p.keyboard.press('Enter');
      }],
      ['fruit: open by click, pick Cherry', async (p) => {
        await opener(p, 0).click();
        await menus(p).nth(0).locator('[role=option]', { hasText: 'Cherry' }).click();
      }],
      ['fruit: disabled Grape does nothing', async (p) => {
        await opener(p, 0).click();
        await menus(p).nth(0).locator('[role=option]', { hasText: 'Grape' }).click({ force: true });
      }],
      ['fruit: Escape', key('Escape')],
      ['color: open, filter "bl"', async (p) => {
        await opener(p, 1).click();
        await menus(p).nth(1).locator('[popover] input').fill('bl');
      }],
      ['color: Enter picks Blue', key('Enter')],
      ['color: reopen (filter reset), Tab closes', async (p) => {
        await opener(p, 1).click();
        await p.keyboard.press('Tab');
      }],
      // The race that made "filter" flaky under load: the pointer opens the
      // popover, its `toggle` is queued, and the filter input lands first.
      // One task makes it deterministic (a loaded CI only made it likely).
      ['color: open and filter "gr" before the queued toggle', async (p) => {
        await p.evaluate(() => {
          const root = document.querySelectorAll('.case-dropdown-menu [data-t-dd]')[1];
          root.querySelector('button[aria-haspopup]').click();
          const field = root.querySelector('[popover] input');
          field.focus(); // what typing in it (or Playwright's fill) does
          field.value = 'gr';
          field.dispatchEvent(new Event('input', { bubbles: true }));
        });
      }],
      ['color: Enter picks Green', key('Enter')],
    ],
    { settle: 60 },
  );
  t.check(
    'edge_cases: a filter typed before the queued toggle survives (lite picks Green)',
    /data-tdl="">Green</.test(edge.lite.snaps.at(-1)[1]),
    edge.lite.snaps.at(-1)[1].match(/data-tdl="[^>]*>[^<]*/g)?.join(' | '),
  );
  const lastEdge = edge.lite.snaps.at(-1)[1];
  t.check('edge_cases: onEnd once per change (3 cycles → 3)', lastEdge.includes('onEnd: 3'), lastEdge.match(/onEnd: \d+/)?.[0]);
  t.check('edge_cases: picks reached the state', /Picked: cherry \(\d+\)/.test(lastEdge), lastEdge.match(/Picked: [^<]*/)?.[0]);

  // --- hybrid: messages from its Flutter views (the event a view sends), ------
  // decoded as JSON and matched with map patterns; bad JSON is ignored ------------
  if (!hybridBuilt) {
    console.log('skip hybrid: tool/thor build hybrid (Flutter SDK), then node tool/thor_lite.mjs hybrid');
  } else {
    const say = (state, detail) => async (p) =>
      p.evaluate(
        ([s, d]) => document.querySelector(`[data-t-on^="thor-flutter-message:HybridState.${s}"]`).dispatchEvent(new CustomEvent('thor-flutter-message', { bubbles: true, detail: d })),
        [state, detail],
      );
    const hy = await scenario(
      'hybrid',
      'h',
      'hl',
      [
        ['a bar', say('onBar', '{"bar": "abr", "value": 24}')],
        ['a bar with a decimal value', say('onBar', '{"bar": "may", "value": 2.5, "extra": true}')],
        ['a bar whose value is not a number', say('onBar', '{"bar": "jun", "value": "no"}')],
        ['not JSON', say('onBar', 'nope')],
        ['a count', say('onCount', '{"count": 4}')],
        ['a count that is not an int', say('onCount', '{"count": 4.5}')],
        ['a list', say('onCount', '[4]')],
        ['a count again', say('onCount', '{"count": 7}')],
      ],
      {
        // Without the Flutter build (an empty bootstrap): the views stay
        // placeholders, the same on both engines.
        prepare: (p) => p.route('**/flutter/flutter_bootstrap.js', (r) => r.fulfill({ contentType: 'text/javascript', body: '' })),
      },
    );
    const lastHy = hy.lite.snaps.at(-1)[1];
    t.check('hybrid: the count reached the page', lastHy.includes('El contador de Flutter va en 7.'), lastHy.match(/El contador[^<]*/)?.[0]);
    const badBar = hy.lite.snaps[4][1];
    t.check('hybrid: bad JSON shows the prompt again', badBar.includes('Toca una barra de la gráfica.'), badBar.match(/Toca[^<]*|Tocaste[^<]*/)?.[0]);
  }

  // --- intl_store (server app): the cart's plural message in en and es, -------
  // from intl's rules in the lite `intl` part ---------------------------------------
  {
    const dir = join(repo, 'test/fixtures/apps/intl_store');
    const liteDir = join(dir, 'build/lite');
    const bundle = existsSync(liteDir) ? readdirSync(liteDir).find((f) => f.startsWith('engine.lite.')) : null;
    if (!existsSync(join(dir, 'build/server')) || !bundle) throw new Error('test/fixtures/apps/intl_store: tool/thor build-server intl_store, then node tool/thor_lite.mjs intl_store');
    const liteJs = readFileSync(join(liteDir, bundle));
    const port = await new Promise((ok) => {
      const srv = createServer().listen(0, '127.0.0.1', () => {
        const { port } = srv.address();
        srv.close(() => ok(port));
      });
    });
    const kid = spawn(join(dir, 'build/server'), [], { cwd: dir, env: { ...process.env, PORT: `${port}`, ISOLATES: '1' }, stdio: 'ignore' });
    const kill = () => kid.exitCode === null && kid.kill('SIGKILL');
    process.on('exit', kill);
    try {
      const app = `http://127.0.0.1:${port}`;
      for (let i = 0; i < 200; i++) {
        try {
          if ((await fetch(`${app}/en`)).ok) break;
        } catch {}
        await new Promise((r) => setTimeout(r, 100));
      }
      let served = 0;
      const prepare = async (p, engine) => {
        if (engine === 'lite') {
          await p.route(/\/engine\.dart[^/]*\.js(\?|$)/, (r) => {
            served++;
            return r.fulfill({ contentType: 'text/javascript', body: liteJs });
          });
        }
      };
      for (const [lang, add, empty] of [['en', 'Add to cart', 'Empty cart'], ['es', 'Agregar al carrito', 'Vaciar el carrito']]) {
        const shop = await scenario(
          `intl_store ${lang}`,
          `${app}/${lang}`,
          `${app}/${lang}`,
          [
            ['add one', click(add)],
            ['add another (plural)', click(add)],
            ['add three more', clicks(add, 3)],
            ['empty the cart', click(empty)],
            ['add one again', click(add)],
          ],
          { prepare },
        );
        const one = shop.lite.snaps[1][1];
        t.check(`intl_store ${lang}: one item reads as one`, lang === 'en' ? one.includes('1 item in your cart') : one.includes('1 artículo en tu carrito'), one.match(/data-tt="CartState.label"[^<]*/)?.[0]);
      }
      t.check('intl_store: the lite pages ran the lite bundle', served > 0, `${served}`);
    } finally {
      kill();
    }
  }

  // --- realworld (server app): the tag editor on the editor page ------------------
  {
    const server = join(repo, 'test/fixtures/apps/realworld/build/server');
    const liteDir = join(repo, 'test/fixtures/apps/realworld/build/lite');
    const bundle = existsSync(liteDir) ? readdirSync(liteDir).find((f) => f.startsWith('engine.lite.')) : null;
    if (!existsSync(server) || !bundle) throw new Error('test/fixtures/apps/realworld: tool/thor build-server realworld, then node tool/thor_lite.mjs realworld');
    const liteJs = readFileSync(join(liteDir, bundle));
    const freePort = () =>
      new Promise((ok) => {
        const srv = createServer().listen(0, '127.0.0.1', () => {
          const { port } = srv.address();
          srv.close(() => ok(port));
        });
      });
    const [mockPort, appPort] = [await freePort(), await freePort()];
    const kids = [
      spawn('node', [join(repo, 'test/e2e/mock_api/server.mjs'), '--port', `${mockPort}`], { stdio: 'ignore', env: { ...process.env, MOCK_PORT: `${mockPort}` } }),
    ];
    const kill = () => kids.forEach((k) => k.exitCode === null && k.kill('SIGKILL'));
    process.on('exit', kill);
    const waitFor = async (url) => {
      for (let i = 0; i < 200; i++) {
        try {
          if ((await fetch(url)).status < 500) return;
        } catch {}
        await new Promise((r) => setTimeout(r, 100));
      }
      throw new Error(`nothing at ${url}`);
    };
    try {
      await waitFor(`http://127.0.0.1:${mockPort}/api/tags`);
      kids.push(
        spawn(server, [], {
          cwd: join(repo, 'test/fixtures/apps/realworld'),
          env: { ...process.env, PORT: `${appPort}`, ISOLATES: '1', REALWORLD_API: `http://localhost:${mockPort}/api`, SESSION_SECRET: 'lite-conformance-secret-of-at-least-32-bytes!' },
          stdio: 'ignore',
        }),
      );
      const app = `http://127.0.0.1:${appPort}`;
      await waitFor(`${app}/`);
      let served = 0;
      const tag = (p) => p.locator('input[name=tagInput]');
      const addTag = (v) => async (p) => {
        await tag(p).fill(v);
        await tag(p).press('Enter');
      };
      const removeTag = (v) => async (p) => p.locator('.tag-pill', { hasText: v }).locator('button').click();
      const rw = await scenario(
        'realworld editor',
        `${app}/editor`,
        `${app}/editor`,
        [
          ['tag uno', addTag('uno')],
          ['tag dos', addTag('dos')],
          ['tag uno again (ignored)', addTag(' uno ')],
          ['tag tres', addTag('tres')],
          ['remove dos', removeTag('dos')],
          ['remove uno', removeTag('uno')],
          ['tag cuatro', addTag('cuatro')],
        ],
        {
          prepare: async (p, engine) => {
            if (engine === 'lite') {
              await p.route('**/engine.dart.js*', (r) => {
                served++;
                return r.fulfill({ contentType: 'text/javascript', body: liteJs });
              });
            }
            await p.goto(`${app}/login`);
            await p.fill('input[name=email]', 'johndoe@example.com');
            await p.fill('input[name=password]', 'password123');
            await Promise.all([p.waitForURL(`${app}/`), p.locator('form button[type=submit]').last().click()]);
          },
        },
      );
      t.check('realworld: the lite pages ran the lite bundle', served > 0, `${served}`);
      const lastRw = rw.lite.snaps.at(-1)[1];
      const tags = [...lastRw.matchAll(/name="tag" value="([^"]+)"/g)].map((m) => m[1]).join();
      t.check('realworld: tags tres, cuatro post as hidden fields', tags === 'tres,cuatro', tags);
    } finally {
      kill();
    }
  }

  // --- grid (server app): the whole Grid view, with gestures, shortcuts, --------
  // variables, the clipboard, the drawer and the toolbar ---------------------------
  {
    const dir = join(repo, 'test/fixtures/apps/grid');
    const liteDir = join(dir, 'build/lite');
    const bundle = existsSync(liteDir) ? readdirSync(liteDir).find((f) => f.startsWith('engine.lite.')) : null;
    if (!existsSync(join(dir, 'build/server')) || !bundle) throw new Error('test/fixtures/apps/grid: tool/thor build-server grid, then node tool/thor_lite.mjs grid');
    const liteJs = readFileSync(join(liteDir, bundle));
    const port = await new Promise((ok) => {
      const srv = createServer().listen(0, '127.0.0.1', () => {
        const { port } = srv.address();
        srv.close(() => ok(port));
      });
    });
    const kid = spawn(join(dir, 'build/server'), [], { cwd: dir, env: { ...process.env, PORT: `${port}`, ISOLATES: '1' }, stdio: 'ignore' });
    const kill = () => kid.exitCode === null && kid.kill('SIGKILL');
    process.on('exit', kill);
    try {
      const app = `http://127.0.0.1:${port}/`;
      for (let i = 0; i < 200; i++) {
        try {
          if ((await fetch(app)).ok) break;
        } catch {}
        await new Promise((r) => setTimeout(r, 100));
      }
      const cell = (row, col) => `[data-tk="r${row}"] .gc${col}`;
      const name = (row) => `[data-tk="r${row}"] [data-tf="GridState.nameOf"]`;
      const press = (...keys) => async (p) => {
        for (const k of keys) await p.keyboard.press(k);
      };
      const clickThen = (sel, ...keys) => async (p) => {
        await p.click(sel);
        for (const k of keys) await p.keyboard.press(k);
      };
      let served = 0;
      const grid = await scenario(
        'grid',
        app,
        app,
        [
          ['click a cell', clickThen(cell(1, 1))],
          ['arrows', press('ArrowDown', 'ArrowRight')],
          ['shift+arrows', press('Shift+ArrowDown', 'Shift+ArrowDown')],
          ['tab', press('Tab')],
          ['edit the name', async (p) => {
            await p.click(name(2));
            await p.keyboard.press('Enter');
            await p.keyboard.type(' X');
            await p.keyboard.press('Enter');
          }],
          ['escape, undo, redo', press('Escape', 'Meta+z', 'Meta+Shift+z')],
          ['select editor', async (p) => {
            await p.click(cell(1, 1));
            await p.keyboard.press('Enter');
            await p.keyboard.type('pau');
            await p.keyboard.press('Enter');
          }],
          ['number editor', async (p) => {
            await p.click(cell(1, 5));
            await p.keyboard.press('Enter');
            await p.keyboard.press('Meta+a');
            await p.keyboard.type('123456');
            await p.keyboard.press('Enter');
          }],
          ['space on a checkbox cell', async (p) => {
            await p.click(cell(3, 7), { position: { x: 70, y: 10 } });
            await p.keyboard.press('Space');
          }],
          ['type on a cell', async (p) => {
            await p.click(name(7));
            await p.keyboard.type('Zed');
            await p.keyboard.press('Enter');
          }],
          ['copy a range', async (p) => {
            await p.click(name(8));
            await p.keyboard.press('Shift+ArrowDown');
            await p.keyboard.press('Shift+ArrowRight');
            await p.keyboard.press('Meta+c');
          }],
          ['paste it', async (p) => {
            await p.click(name(10));
            await p.keyboard.press('Meta+v');
            await p.waitForFunction(([a, b]) => document.querySelector(a)?.textContent === document.querySelector(b)?.textContent, [name(10), name(8)]);
          }],
          ['undo the paste', press('Meta+z')],
          ['rate with a star', async (p) => p.locator(`${cell(4, 8)} button`).nth(4).click()],
          ['scroll down', async (p) => {
            await p.evaluate(() => (document.querySelector('[data-tsc]').scrollTop = 32 * 1000));
            await p.waitForFunction(() => Number(document.querySelector('[data-tk^="r"] [data-tf="GridState.numberOf"]')?.textContent) > 900);
          }],
          ['scroll back', async (p) => {
            await p.evaluate(() => (document.querySelector('[data-tsc]').scrollTop = 0));
            await p.waitForFunction(() => document.querySelector('[data-tk="r1"]'));
          }],
          ['resize a column', async (p) => {
            const edge = await p.locator('[aria-label="Resize Status"]').boundingBox();
            await p.mouse.move(edge.x + 3, edge.y + 10);
            await p.mouse.down();
            await p.mouse.move(edge.x + 50, edge.y + 10, { steps: 5 });
            await p.mouse.move(edge.x + 103, edge.y + 10, { steps: 5 });
            await p.mouse.up();
          }],
          ['check two rows', async (p) => {
            for (const r of [2, 5]) {
              await p.hover(`[data-tk="r${r}"]`);
              await p.click(`[data-tk="r${r}"] input[type=checkbox]`);
            }
          }],
          ['bulk status', async (p) => {
            await p.click('[popovertarget="pop-bulk-status"]');
            await p.click('#pop-bulk-status >> text=Beta');
            await p.keyboard.press('Escape');
          }],
          ['bulk delete', async (p) => p.getByRole('button', { name: 'Delete' }).click()],
          ['undo the delete', clickThen(cell(1, 1), 'Meta+z')],
          ['expand a record', async (p) => {
            await p.hover('[data-tk="r6"]');
            await p.click('[data-tk="r6"] [aria-label^="Expand "]');
          }],
          ['edit in the drawer', async (p) => p.locator('[data-ttc="GridState.drawerName"]').fill('Edited in the drawer')],
          ['close the drawer', press('Escape')],
          ['filter', async (p) => {
            await p.click('[popovertarget="pop-filter"]');
            await p.click('#pop-filter >> text=+ Add condition');
            await p.locator('#pop-filter select[aria-label="Field"]').first().selectOption('status');
            await p.locator('#pop-filter [data-ttc="GridState.filterValue0"]').fill('Launched');
            await p.keyboard.press('Escape');
          }],
          ['sort', async (p) => {
            await p.click('[popovertarget="pop-sort"]');
            await p.click('#pop-sort >> text=+ Add sort');
            await p.locator('#pop-sort select[aria-label="Sort field"]').first().selectOption('budget');
            await p.locator('#pop-sort select[aria-label="Direction"]').first().selectOption('desc');
            await p.keyboard.press('Escape');
          }],
          ['group', async (p) => {
            await p.click('[popovertarget="pop-group"]');
            await p.locator('#pop-group select').selectOption('owner');
            await p.keyboard.press('Escape');
          }],
          ['collapse a group', async (p) => p.click('[data-tk^="g"] [data-tf="GridState.nameOf"]')],
          ['hide a field', async (p) => {
            await p.click('[popovertarget="pop-hide"]');
            await p.locator('#pop-hide input[type=checkbox]').nth(9).click();
            await p.keyboard.press('Escape');
          }],
          ['search', async (p) => {
            await p.fill('input[name=q]', 'aurora');
            await p.keyboard.press('Enter');
          }],
        ],
        {
          settle: 400,
          pageOptions: { viewport: { width: 1440, height: 900 }, permissions: ['clipboard-read', 'clipboard-write'] },
          prepare: async (p, engine) => {
            if (engine === 'lite') {
              await p.route(/\/engine\.dart[^/]*\.js(\?|$)/, (r) => {
                served++;
                return r.fulfill({ contentType: 'text/javascript', body: liteJs });
              });
            }
          },
        },
      );
      t.check('grid: the lite pages ran the lite bundle', served > 0, `${served}`);
      const lastGrid = grid.lite.snaps.at(-1)[1];
      t.check('grid: the search reached the state', /data-tt="GridState.searchCount">\d+ of \d+</.test(lastGrid), lastGrid.match(/data-tt="GridState.searchCount">[^<]*/)?.[0]);
    } finally {
      kill();
    }
  }

  // --- thor dev: the states' values across a live reload (dev_state part) -------
  {
    const p = await t.page();
    const warnings = [];
    p.on('console', (m) => ['warning', 'info'].includes(m.type()) && warnings.push(m.text()));
    await trackHydration(p);
    const load = async (reload) => {
      await (reload ? p.reload() : p.goto(t.url + 'ds/'));
      await hydrated(p);
      return [await p.textContent('#n'), await p.textContent('#tags')];
    };
    await load(false);
    await p.click('#inc');
    await p.click('#inc');
    const snap = JSON.parse(await p.evaluate(() => window.__thorDevState()));
    t.check('dev state: the snapshot has the JSON fields, not the date',
      snap.v === 1 && snap.s['DevState.count'] === 2 && snap.s['DevState.tags'].join() === 'a,x,x' && !('DevState.when' in snap.s),
      JSON.stringify(snap));
    t.check('dev state: the date left out is named', warnings.some((w) => w.includes('DevState.when')), warnings.join(' | '));
    const store = (v) => p.evaluate((v) => sessionStorage.setItem('thor:state:/ds/', v), v);
    await store(JSON.stringify(snap));
    const back = await load(true);
    t.check('dev state: the reload shows the kept values', back.join() === '2,a,x,x', back.join());
    t.check('dev state: read once', (await p.evaluate(() => sessionStorage.getItem('thor:state:/ds/'))) === null);
    const again = await load(true);
    t.check('dev state: a manual reload starts from the server', again.join() === '0,a', again.join());
    warnings.length = 0;
    await store(JSON.stringify({ v: 1, s: { 'DevState.count': 'nope', 'DevState.gone': 1, 'DevState.tags': ['q'] } }));
    const partial = await load(true);
    t.check('dev state: what no longer fits keeps the server value', partial.join() === '0,q', partial.join());
    t.check('dev state: and says why', ['DevState.count not restored: was string, now number', 'DevState.gone not restored: no longer on the page'].every((w) => warnings.some((x) => x.includes(w))), warnings.join(' | '));
    await store('{nope');
    const corrupt = await load(true);
    t.check('dev state: a corrupt snapshot is ignored', corrupt.join() === '0,a', corrupt.join());
    await p.context().close();
  }

  // --- the hardening of the lite runtime on real apps ---------------------------
  // The hostile input is injected into the real pages (an init script that
  // wraps `thor.def`, page.route, markup added by the test): no test-only
  // feature in any app. Where the dart2js engine can take the same input the
  // two are compared; where the input only exists in lite (a JS runtime's
  // internals) the check runs on lite alone and says why. dart2js is in
  // maintenance: it gets no new behavior, only the parity it already has.
  //
  // The init script that lets a scenario wrap a state's members before the
  // engine builds it (`thor` is assigned by the bundle's own script).
  const hookSrc = `(() => {
    const H = (window.__hook = { calls: [], wrap: null, ctls: [] });
    let real;
    Object.defineProperty(window, 'thor', {
      configurable: true,
      get: () => real,
      set: (T) => {
        real = T;
        const def = T.def;
        T.def = (name, f, o) => def(name, ($) => {
          const a = T.ctl?.anim;
          if (a && !a.w) {
            const w = (...x) => (H.ctls.push(a(...x)), H.ctls.at(-1));
            w.w = 1;
            T.ctl.anim = w;
          }
          const m = f($);
          return H.wrap?.(name, m, T) ?? m;
        }, o);
      },
    });
  })();`;
  // A lite-only page: the hook plus `wrap` (source of a function), then the app.
  async function litePage(path, wrap, { inject, pageOptions } = {}) {
    const p = await t.page(pageOptions);
    await trackHydration(p);
    await p.addInitScript(`${hookSrc}; window.__hook.wrap = ${wrap ?? 'null'};`);
    if (inject) await p.route(`**/${path}/`, async (route) => {
      const r = await route.fetch();
      await route.fulfill({ response: r, body: inject(await r.text()) });
    });
    await p.goto(t.url + path + '/');
    await hydrated(p);
    return p;
  }
  const label = (p) => p.locator('[data-tt="CounterState.label"]').textContent();
  const resetOff = (p) => p.locator('button', { hasText: 'Reiniciar' }).first().isDisabled();
  // Page errors a step provoked on purpose: taken out of `problems`.
  const errors = (p) => p.problems.splice(0);

  // A method and an effect that throw once; the next interaction works.
  // lite-only: dart2js runs Dart, there is nowhere to make a JS binding throw.
  {
    const p = await litePage('cl', `(name, m) => {
      if (name !== 'CounterState') return m;
      const H = window.__hook, inc = m.inc, lbl = m.label;
      m.inc = (a) => { inc(a); if (H.incBoom) { H.incBoom = false; throw Error('inc boom'); } };
      m.label = () => { const v = lbl(); if (H.labelBoom) { H.labelBoom = false; throw Error('label boom'); } return v; };
      return m;
    }`);
    await p.evaluate(() => (window.__hook.incBoom = true));
    await p.locator('button', { hasText: '+' }).first().click();
    t.check('throwing code (lite): a method that throws after writing still shows its write', (await label(p)) === '1', await label(p));
    t.check('throwing code (lite): its error reaches the console', errors(p).some((e) => e.includes('inc boom')));
    await p.locator('button', { hasText: '+' }).first().click();
    t.check('throwing code (lite): the next click updates', (await label(p)) === '2', await label(p));
    // A text effect that throws: the rest of the batch (the Reiniciar state) ran.
    await p.locator('button', { hasText: 'Reiniciar' }).first().click();
    t.check('throwing code (lite): reset back to 0 (Reiniciar disabled again)', (await label(p)) === '0' && (await resetOff(p)), await label(p));
    await p.evaluate(() => (window.__hook.labelBoom = true));
    await p.locator('button', { hasText: '+' }).first().click();
    t.check('throwing code (lite): an effect that throws does not stop the other effects of its batch', (await resetOff(p)) === false, 'Reiniciar still disabled');
    t.check('throwing code (lite): the effect error is reported once', errors(p).filter((e) => e.includes('label boom')).length === 1);
    await p.locator('button', { hasText: '+' }).first().click();
    t.check('throwing code (lite): after the throwing effect the next click updates the text', (await label(p)) === '2', await label(p));
    await p.context().close();
  }

  // A computed in error throws on every read and recovers with its source.
  {
    const p = await litePage('cl', `(name, m, T) => {
      if (name !== 'CounterState') return m;
      const H = window.__hook, lbl = m.label;
      H.c = T.computed(() => { const v = lbl(); if (H.bad) throw Error('computed boom'); return v; });
      m.label = () => H.c.value;
      return m;
    }`);
    await p.evaluate(() => (window.__hook.bad = true));
    await p.locator('button', { hasText: '+' }).first().click();
    t.check('failing computed (lite): a computed that throws reports it through its effect', errors(p).some((e) => e.includes('computed boom')));
    const twice = await p.evaluate(() => [0, 1, 2].map(() => { try { window.__hook.c.value; return 'ok'; } catch (e) { return e.message; } }));
    t.check('failing computed (lite): three reads in a row throw the same error', twice.join() === 'computed boom,computed boom,computed boom', twice.join());
    t.check('failing computed (lite): meanwhile the text keeps its last value', (await label(p)) === '0', await label(p));
    await p.evaluate(() => (window.__hook.bad = false));
    await p.locator('button', { hasText: '+' }).first().click();
    t.check('failing computed (lite): a changed source recomputes and the text recovers', (await label(p)) === '2', await label(p));
    t.check('failing computed (lite): no further errors', errors(p).length === 0);
    await p.context().close();
  }

  // Effects that feed each other end with an error, not a hang.
  {
    const p = await litePage('cl', `(name, m, T) => {
      if (name !== 'CounterState') return m;
      const H = window.__hook, inc = m.inc;
      H.a = T.signal(0);
      T.effect(() => { const v = H.a.value; if (H.cyc) H.a.value = v + 1; });
      m.inc = (a) => { inc(a); if (H.cyc) H.a.value = H.a.peek() + 1; };
      return m;
    }`);
    // The state exists before the cycle starts (a factory that loops is another story).
    await p.evaluate(() => thor.use('CounterState'));
    await p.evaluate(() => (window.__hook.cyc = true));
    const t0 = Date.now();
    await p.locator('button', { hasText: '+' }).first().click({ timeout: 10_000 });
    const errs = errors(p);
    t.check('effect cycle (lite): a cycle of effects ends with a thor: cycle error', errs.some((e) => e.includes('thor: cycle')), errs.join(' | '));
    t.check('effect cycle (lite): and it ends quickly', Date.now() - t0 < 8000, `${Date.now() - t0} ms`);
    t.check('effect cycle (lite): the write before the cycle is on the page', (await label(p)) === '1', await label(p));
    await p.evaluate(() => (window.__hook.cyc = false));
    await p.locator('button', { hasText: '+' }).first().click();
    await p.locator('button', { hasText: '−' }).first().click();
    await p.locator('button', { hasText: '+' }).first().click();
    t.check('effect cycle (lite): the page stays interactive after the cycle', (await label(p)) === '2' && errors(p).length === 0, await label(p));
    await p.context().close();
  }

  // Ids forged into data-t-on / data-tt. Both engines get the same
  // hostile markup and must end in the same DOM; the lite runtime must also
  // leave Object.prototype alone.
  {
    const big = 'x'.repeat(1 << 20);
    const forged = (big) => async (p) => {
      await p.evaluate((big) => {
        const ids = ['__proto__.polluted', 'CounterState.__proto__', 'CounterState.constructor', 'CounterState.toString',
          'CounterState.hasOwnProperty', 'constructor.constructor', 'toString.call', 'CounterState#__proto__.inc',
          'CounterState.inc~' + big, `${big}.inc`, 'CounterState.$s', 'CounterState..inc', ' CounterState.inc'];
        const box = document.createElement('div');
        box.id = 'forged';
        box.innerHTML = ids.map((id, i) => `<button id="fb${i}" type="button" data-t-on="click:${id}">f${i}</button>`).join('') +
          '<span data-tt="__proto__.x">a</span><span data-tt="CounterState.__proto__">b</span><span data-tt="constructor.name">c</span>' +
          `<button id="fbig" type="button" data-t-on="click:CounterState.inc" data-tx="${big}">big</button>`;
        document.body.append(box);
      }, big);
      for (const b of await p.locator('#forged button').all()) await b.click();
    };
    const intact = async (p) =>
      p.evaluate(() => Object.getOwnPropertyNames(Object.prototype).sort().join() === Object.getOwnPropertyNames(Object.getPrototypeOf({})).sort().join() &&
        ({}).polluted === undefined && ({}).inc === undefined && ({}).x === undefined);
    const run = await scenario('forged ids', 'c', 'cl', [
      ['forged data-t-on and data-tt, every button clicked', forged(big)],
      ['a real + still works', click('+')],
      ['and −', click('−')],
    ]);
    // Every forged button but the big-arg legit one is ignored; that one runs inc once.
    t.check('forged ids: only the legitimate button with a 1 MB argument acted (lite label 1, then +1)', /data-tt="CounterState.label">2</.test(run.lite.snaps[2][1]) && /data-tt="CounterState.label">1</.test(run.lite.snaps[3][1]), run.lite.snaps.map(([, s]) => s.match(/CounterState.label">[^<]*/)?.[0]).join(' | '));
    const p = await litePage('cl');
    await forged(big)(p);
    t.check('forged ids (lite): Object.prototype is untouched after the forged ids', await intact(p));
    t.check('forged ids (lite): no page errors from the forged ids', p.problems.length === 0, p.problems.join(' | '));
    await p.context().close();
  }

  // A malformed #thor-state keeps the page interactive with the values
  // of the code, on both engines (dart2js used to throw "Unexpected end of
  // JSON input" at load and stay dead). A broken payload reports one console
  // error; a well-formed one that is not an object is ignored quietly.
  for (const [engine, path] of [['dart', 'c'], ['lite', 'cl']]) {
    for (const [name, json] of [
      ['truncated', '{"CounterState.count":'],
      ['not JSON', 'nope'],
      ['an array', '[1,2]'],
      ['null', 'null'],
      ['a string', '"7"'],
      ['empty', ''],
    ]) {
      const inject = (h) => h.replace('</body>', `<script type="application/json" id="thor-state">${json}</script></body>`);
      let p;
      if (engine === 'lite') p = await litePage(path, null, { inject });
      else {
        p = await t.page();
        await trackHydration(p);
        await p.route(`**/${path}/`, async (route) => {
          const r = await route.fetch();
          await route.fulfill({ response: r, body: inject(await r.text()) });
        });
        await p.goto(t.url + path + '/');
        await hydrated(p);
      }
      await p.locator('button', { hasText: '+' }).first().click();
      await p.locator('button', { hasText: '+' }).first().click();
      await p.locator('button', { hasText: '−' }).first().click();
      const broken = ['truncated', 'not JSON'].includes(name);
      const errs = errors(p);
      t.check(`broken #thor-state (${engine}): #thor-state ${name}: the page works from the code's values`, (await label(p)) === '1' && (await resetOff(p)) === false, await label(p));
      t.check(`broken #thor-state (${engine}): #thor-state ${name}: ${broken ? 'one clear console error' : 'no errors'}`, broken ? errs.length === 1 && errs[0].includes('thor-state') : errs.length === 0, errs.join(' | '));
      await p.context().close();
    }
  }

  // A child with only `input:` inside a parent with `click:`. Both
  // engines follow the event to the next ancestor that handles its type, like
  // the browser (dart2js too since the loader queues by the same rule).
  // Typing runs the child's own handler.
  {
    const markup = '<div id="bp" data-t-on="click:CounterState.inc" style="padding:20px"><input id="bc" data-t-on="input:CounterState.dec"></div>';
    const shown = {};
    let calls;
    for (const [engine, path] of [['dart', 'c'], ['lite', 'cl']]) {
      const p = await t.page();
      await trackHydration(p);
      if (engine === 'lite') {
        await p.addInitScript(`${hookSrc}; window.__hook.wrap = (name, m) => {
          if (name !== 'CounterState') return m;
          for (const k of ['inc', 'dec']) { const f = m[k]; m[k] = (a) => (window.__hook.calls.push(k + ':' + a), f(a)); }
          return m;
        };`);
      }
      await p.route(`**/${path}/`, async (route) => {
        const r = await route.fetch();
        await route.fulfill({ response: r, body: (await r.text()).replace('</body>', `${markup}</body>`) });
      });
      await p.goto(t.url + path + '/');
      await hydrated(p);
      const seen = [await label(p)];
      for (const step of [
        () => p.locator('#bc').click(),
        () => p.locator('#bc').pressSequentially('ab'),
        () => p.locator('#bc').click(),
        () => p.locator('#bp').click({ position: { x: 3, y: 3 } }),
      ]) {
        await step();
        seen.push(await label(p));
      }
      shown[engine] = seen.join();
      if (engine === 'lite') calls = await p.evaluate(() => window.__hook.calls);
      t.check(`nested handlers (${engine}): no page errors`, p.problems.length === 0, p.problems.join(' | '));
      await p.context().close();
    }
    t.check('nested handlers (lite): child click reaches the parent (+1), typing runs the child (a, ab: −2), click again +1, padding click +1', shown.lite === '0,1,-1,0,1', shown.lite);
    t.check('nested handlers (dart): the same as lite (child click reaches the parent, typing runs the child)', shown.dart === '0,1,-1,0,1', shown.dart);
    t.check('nested handlers (lite): the parent got the click without the child\'s text, the child got its own', calls?.join() === 'inc:null,dec:a,dec:ab,inc:null,inc:null', calls?.join());
  }

  // AnimationController under a burst of clicks. Parity: once at rest,
  // the label, the panel's opacity and the spinner button agree, the same on
  // both engines. lite: no effect ever saw a value beside a stale status.
  {
    const rest = async (p, engine) => {
      const cdp = await p.context().newCDPSession(p);
      await cdp.send('Emulation.setCPUThrottlingRate', { rate: 4 });
      const names = ['Mostrar', 'Ocultar', 'Girar', 'Detener', 'Latir', 'Alternar'];
      for (let i = 0; i < 30; i++) {
        await p.getByRole('button', { name: names[(i * 7 + (i >> 1)) % names.length] }).click({ noWaitAfter: true, timeout: 3000 }).catch(() => {});
      }
      await p.getByRole('button', { name: 'Ocultar' }).click({ noWaitAfter: true, timeout: 3000 }).catch(() => {});
      await cdp.send('Emulation.setCPUThrottlingRate', { rate: 1 });
      await p.waitForFunction(() => document.querySelector('[data-tt="MotionState.revealLabel"]').textContent === 'Oculto', null, { timeout: 8000 });
      await p.waitForTimeout(150);
      return p.evaluate(() => {
        const el = [...document.querySelectorAll('*')].find((e) => e.children.length === 0 && e.textContent === 'Hola: sé aparecer y ocultarme.');
        let op = 1;
        for (let e = el; e; e = e.parentElement) op *= +getComputedStyle(e).opacity;
        return {
          label: document.querySelector('[data-tt="MotionState.revealLabel"]').textContent,
          opacity: op,
          spin: ['Girar', 'Detener'].map((n) => [...document.querySelectorAll('button')].filter((b) => b.textContent.trim() === n).length).join(''),
        };
      });
    };
    const seen = {};
    for (const [engine, path] of [['dart', 'a'], ['lite', 'al']]) {
      const p = await t.page();
      await trackHydration(p);
      if (engine === 'lite') {
        await p.addInitScript(`${hookSrc}; window.__hook.wrap = (name, m, T) => {
          if (name !== 'MotionState') return m;
          const H = window.__hook;
          H.log = []; H.torn = [];
          const c = H.ctls.find((x) => x.id.endsWith('.reveal'));
          T.effect(() => {
            const r = { v: c.v.value, s: c.s.value, pb: c.pb.value };
            H.log.push(r);
            // Playing: the status follows the direction; at rest at a bound: that bound's status.
            if ((r.pb && r.s !== (r.pb.a ? 1 : r.pb.r ? 2 : 1)) || (!r.pb && r.v === 0 && r.s !== 0) || (!r.pb && r.v === 1 && r.s !== 3)) H.torn.push(r);
          });
          return m;
        };`);
      }
      await p.goto(t.url + path + '/');
      await hydrated(p);
      seen[engine] = await rest(p, engine);
      if (engine === 'lite') {
        const h = await p.evaluate(() => ({ n: window.__hook.log.length, torn: window.__hook.torn }));
        t.check('animation burst (lite): the effect on the controller ran during the burst', h.n > 10, `${h.n} runs`);
        t.check('animation burst (lite): no effect saw a new value beside an old status', h.torn.length === 0, JSON.stringify(h.torn.slice(0, 3)));
      }
      t.check(`animation burst (${engine}): no page errors in the burst`, p.problems.length === 0, p.problems.join(' | '));
      await p.context().close();
    }
    t.check('animation burst: at rest label, opacity and spinner button are the same on both engines', JSON.stringify(seen.dart) === JSON.stringify(seen.lite), `${JSON.stringify(seen.dart)} vs ${JSON.stringify(seen.lite)}`);
    t.check('animation burst: hidden means label Oculto, opacity 0, one spinner button', seen.lite.label === 'Oculto' && seen.lite.opacity === 0 && ['10', '01'].includes(seen.lite.spin), JSON.stringify(seen.lite));
  }

  // Keys pressed before the engine loads are replayed once, on both
  // engines. The engine's request is held while ⌘K / Ctrl+K, Enter in a field
  // and Enter / Space on a role=button are pressed.
  for (const [engine, path] of [['dart', 'r'], ['lite', 'rl']]) {
    const p = await t.page();
    await trackHydration(p);
    await p.addInitScript(() => {
      window.__replays = [];
      document.addEventListener('keydown', (e) => {
        if (!e.isTrusted) window.__replays.push(`${e.key}@${e.target.tagName}:${e.ctrlKey ? 'C' : ''}${e.metaKey ? 'M' : ''}`);
      }, true);
    });
    let release;
    const gate = new Promise((ok) => (release = ok));
    await p.route(/\/engine\.[a-z]+\.[0-9a-f]+\.js(\?|$)|\/engine\.dart\.js(\?|$)/, async (route) => {
      await gate;
      await route.continue();
    });
    await p.goto(t.url + path + '/', { waitUntil: 'domcontentloaded' });
    await p.keyboard.press('Meta+k');
    await p.keyboard.press('Control+k');
    await p.locator('input[name=quick]').focus();
    await p.keyboard.type('tarea temprana');
    await p.keyboard.press('Enter');
    await p.locator('[role=button]', { hasText: 'toques' }).focus();
    await p.keyboard.press('Enter');
    await p.keyboard.press(' ');
    await p.locator('button', { hasText: 'Invertir' }).focus();
    await p.keyboard.press('a');
    t.check(`early keys (${engine}): the engine was still held while the keys were pressed`, (await p.evaluate(() => window.__thorHydrated)) === false);
    release();
    await hydrated(p);
    await p.waitForFunction(() => /atajos: 2/.test(document.body.innerText) && /toques: 2/.test(document.body.innerText), null, { timeout: 5000 }).catch(() => {});
    await p.waitForTimeout(100);
    const after = await p.evaluate(() => ({
      pings: document.body.innerText.match(/atajos: (\d+)/)?.[1],
      taps: document.body.innerText.match(/toques: (\d+)/)?.[1],
      titles: [...document.querySelectorAll('li')].map((li) => li.innerText.split('\n')[0].trim()),
      quick: document.querySelector('input[name=quick]').value,
      replays: window.__replays,
    }));
    t.check(`early keys (${engine}): ⌘K and Ctrl+K each ran once, Enter and Space on the role=button once each`, after.pings === '2' && after.taps === '2', `${after.pings} / ${after.taps}`);
    t.check(`early keys (${engine}): Enter in the field added its task once and cleared the field`, after.titles.filter((x) => x.includes('tarea temprana')).length === 1 && after.titles.length === 5 && after.quick === '', after.titles.join(' | '));
    t.check(`early keys (${engine}): the replays carried key and modifiers; a key on an ignored element was not replayed`,
      ['k@BODY:M', 'k@BODY:C', 'Enter@INPUT:', 'Enter@DIV:', ' @DIV:'].every((r) => after.replays.includes(r)) && !after.replays.some((r) => r.startsWith('a@')), after.replays.join(', '));
    await p.context().close();
  }

  // --- fuzz of the lite reconciliation ------------------------------------------
  const p = await t.page();
  await trackHydration(p);
  await p.goto(t.url + 'f/');
  await hydrated(p);
  let seed = 7;
  const rnd = (n) => ((seed = (seed * 1103515245 + 12345) % 2147483648), seed % n);
  let ok = 0, bad = '';
  const universe = Array.from({ length: 40 }, (_, i) => `k${i}`);
  for (let round = 0; round < 400; round++) {
    // A random subset in a random order; some rows change text.
    const pool = universe.filter(() => rnd(3) > 0);
    for (let i = pool.length - 1; i > 0; i--) {
      if (rnd(4) === 0) continue; // keep runs in order sometimes
      const j = rnd(i + 1);
      [pool[i], pool[j]] = [pool[j], pool[i]];
    }
    const next = round % 50 === 49 ? [] : pool.map((k) => (rnd(8) === 0 ? `${k}*` : k));
    const res = await p.evaluate((next) => {
      const ul = document.querySelector('ul');
      const before = new Map([...ul.querySelectorAll('li')].map((li) => [li.dataset.tk, li]));
      const b = document.getElementById('set');
      b.setAttribute('data-tx', next.join(','));
      b.click();
      const lis = [...ul.children].filter((c) => c.tagName === 'LI');
      const keys = next.map((k) => k.replace('*', ''));
      const order = lis.map((li) => li.dataset.tk).join(',') === keys.join(',');
      const reused = lis.every((li) => !before.has(li.dataset.tk) || before.get(li.dataset.tk) === li);
      const texts = lis.every((li, i) => li.firstChild.textContent === next[i]);
      const placeholders = lis.every((li) => !li.querySelector('i') || li.querySelector('i').dataset.x === li.dataset.tk);
      const templateLast = ul.lastElementChild.tagName === 'TEMPLATE';
      return order && reused && texts && placeholders && templateLast ? '' : JSON.stringify({ order, reused, texts, placeholders, templateLast });
    }, next);
    if (res) bad ||= `round ${round}: ${res}`;
    else ok++;
  }
  t.check(`fuzz: 400 random reconciliations keep order, nodes, texts and keys (${ok} ok)`, ok === 400, bad);
  t.check('fuzz: no console errors', !p.problems.length, p.problems.join(' | '));
  await p.context().close();
});

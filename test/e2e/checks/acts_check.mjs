// Actions with arguments, confirm, toast and the flash in a real browser,
// on test/fixtures/apps/server_query's public `/acts` page
// (build/server, the lite engine).
//
//   tool/thor e2e acts                       (builds test/fixtures/apps/server_query, runs)
//   node test/e2e/checks/acts_check.mjs
//
// - a button `onPost: delete.withArg(id)` posts its typed argument with no JS:
//   an int, an enum + an int, a hostile value at the server is a 400.
// - `confirm:` on a submit button (asks in the page's one native dialog; without
//   JS the server asks on a page of its own and runs the action only after the
//   yes, a cancel goes back), `confirm()` and `toast()` from a state
//   method (queue of two asks, a flood, a duplicate, an ask before the
//   engine loads), and `Redirect(...).flash(...)` on the next page (no JS,
//   escaped, cleared, through a second redirect, not shared, not taken by
//   a prefetch).
// - a bound button inside a `Form` submits that Form: its arguments AND its
//   fields arrive (no JS and with the engine). An action of another page
//   posts to that page (`/acts/other?/ping`), from a button and from a Form,
//   and a submit button in a Form is enabled with no handler.
// - `toggle()`, a set field and `withArgs` from state methods.
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { e2e, hydrated, repo, settle, trackHydration } from './lib/e2e.mjs';

const children = [];
const tmp = mkdtempSync(join(tmpdir(), 'thor-acts-'));
writeFileSync(join(tmp, 'index.html'), '<!doctype html><title>placeholder</title>');
process.on('exit', () => {
  for (const c of children) if (c.exitCode === null) c.kill('SIGKILL');
  rmSync(tmp, { recursive: true, force: true });
});

const freePort = () =>
  new Promise((ok) => {
    const s = createServer().listen(0, '127.0.0.1', () => {
      const { port } = s.address();
      s.close(() => ok(port));
    });
  });

async function waitFor(url, timeout = 20_000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    try {
      if ((await fetch(url, { redirect: 'manual' })).status < 500) return;
    } catch {}
    await new Promise((r) => setTimeout(r, 100));
  }
  throw new Error(`nothing answered at ${url}`);
}

await e2e('acts', { site: tmp, timeout: 150_000 }, async (t) => {
  // A detail is for a failure only.
  const check = (label, ok, detail = '') => t.check(label, ok, ok ? '' : detail);
  const bin = join(repo, 'test/fixtures/apps/server_query/build/server');
  if (!existsSync(bin)) throw new Error('test/fixtures/apps/server_query/build/server is missing: build it first (tool/thor e2e builds it)');
  const port = await freePort();
  children.push(
    spawn(bin, [], {
      cwd: join(repo, 'test/fixtures/apps/server_query'),
      env: { ...process.env, PORT: `${port}` },
      stdio: 'ignore',
    }),
  );
  const app = `http://127.0.0.1:${port}`;
  await waitFor(`${app}/acts`);

  const post = (page, path, form = {}, headers = {}) =>
    page.request.post(`${app}${path}`, { form, headers: { origin: app, ...headers }, maxRedirects: 0 });
  const reset = (page) => post(page, '/acts?/reset');
  const open = async (options = {}) => {
    const page = await t.page(options);
    page.on('dialog', (d) => {
      page.problems.push(`native dialog: ${d.message()}`);
      d.dismiss();
    });
    await trackHydration(page);
    return page;
  };
  // Click and wait for the navigation it starts (a POST, its redirects, the page).
  const go = async (page, click) => {
    await Promise.all([page.waitForNavigation({ waitUntil: 'load' }), click]);
  };
  const text = (page, sel) => page.locator(sel).first().innerText();
  const bodyText = (page) => page.evaluate(() => document.body.innerText);
  const toastState = (page) =>
    page.evaluate(() => {
      const b = document.getElementById('thor-toast');
      return b && { on: b.hasAttribute('data-t-on'), text: b.textContent, role: b.getAttribute('role') };
    });
  const dialogOpen = (page) => page.evaluate(() => document.getElementById('thor-confirm')?.open === true);
  const waitDialog = (page, open = true) => settle(page, (o) => (document.getElementById('thor-confirm')?.open === true) === o, open);

  // ------------------------------------------------------------ no JS
  {
    const page = await open({ javaScriptEnabled: false });
    await reset(page);
    await page.goto(`${app}/acts`);
    check('no JS: the page has the argument buttons as submit buttons', (await page.locator('button[form=thor-post][name=thor-arg]').count()) >= 6);
    await go(page, page.getByRole('button', { name: 'A Luis 3' }).click());
    check('no JS: an int and an enum reach the method typed (#3 is luis now)', (await bodyText(page)).includes('#3 Ana (luis)'), await bodyText(page));
    check('no JS: a POST that is answered with a 303 leaves the URL clean', new URL(page.url()).pathname === '/acts' && new URL(page.url()).search === '', page.url());

    // A confirm: button asks on a page of its own without JS (the dialog never ran): nothing
    // is deleted until the yes; the way back and the question stay on this site.
    await go(page, page.getByRole('button', { name: 'Eliminar 4', exact: true }).click());
    check('no JS: a confirm: button answers a confirmation page with its question and message', (await text(page, 'main h1')) === '¿Eliminar #4?' && (await bodyText(page)).includes('Se borra en el servidor'), await bodyText(page));
    check('no JS: the yes carries the label of the question', (await text(page, 'main button')) === 'Eliminar');
    check('no JS: the confirmation page is not indexed nor cached', (await page.locator('meta[name=robots][content=noindex]').count()) === 1);
    check('no JS: asking deleted nothing', (await (await page.request.get(`${app}/acts`)).text()).includes('#4 Luis'));
    await go(page, page.locator('main a').click());
    check('no JS: the way back is the page, with order 4 still there', new URL(page.url()).pathname === '/acts' && (await bodyText(page)).includes('#4 Luis'), page.url());
    await go(page, page.getByRole('button', { name: 'Eliminar 4', exact: true }).click());
    await go(page, page.locator('main button').click());
    let body = await bodyText(page);
    check('no JS: the yes runs the action with its argument (order 4 is gone)', !body.includes('#4 Luis') && new URL(page.url()).pathname === '/acts', body);
    const flash = await toastState(page);
    check('flash, no JS: the message shows as a live region on the next page', flash?.on && flash.text === 'Pedido eliminado' && flash.role === 'status', JSON.stringify(flash));
    check('flash: the cookie is cleared once shown', !(await page.context().cookies()).some((c) => c.name === 'thor-flash'));
    await page.reload();
    check('flash: gone on the next page (the bar stays, empty and hidden)', (await toastState(page))?.on === false);

    // Hostile flash through a second redirect (/acts/next → /acts).
    await go(page, page.getByRole('button', { name: 'Aviso hostil' }).click());
    const hostile = await toastState(page);
    check('flash: survives a second redirect and lands on the page that draws', new URL(page.url()).pathname === '/acts' && hostile?.on, page.url());
    check('flash: HTML in it is text', hostile?.text === '<img src=x onerror=alert(1)> & "q"' && (await page.locator('#thor-toast img').count()) === 0, hostile?.text);
    await reset(page);
    check('no JS: no page problems', page.problems.length === 0, page.problems.join(' | '));
    await page.context().close();
  }

  // The flash belongs to the visitor who got it; a prefetch never takes it.
  {
    const page = await open({ javaScriptEnabled: false });
    await reset(page);
    await page.goto(`${app}/acts`);
    await go(page, page.getByRole('button', { name: 'Eliminar 5', exact: true }).click());
    await go(page, page.locator('main button').click());
    const other = await open({ javaScriptEnabled: false });
    await other.goto(`${app}/acts`);
    check('flash: another visitor sees none', (await toastState(other))?.on === false);
    await reset(other);
    const cookie = { name: 'thor-flash', value: 'success%3AHola', url: app };
    await other.context().addCookies([cookie]);
    const pre = await other.request.get(`${app}/acts`, { headers: { 'sec-purpose': 'prefetch' } });
    check('flash: a prefetch is declined (503) and leaves the cookie', pre.status() === 503 && (await other.context().cookies()).some((c) => c.name === 'thor-flash'), `${pre.status()}`);
    await other.goto(`${app}/acts`);
    check('flash: the visit takes it', (await toastState(other))?.text === 'Hola');
    await page.context().close();
    await other.context().close();
  }

  // ------------- arguments with the Form's fields, another page's action
  for (const js of [false, true]) {
    const tag = js ? 'JS' : 'no JS';
    const page = await open({ javaScriptEnabled: js });
    await reset(page);
    await page.goto(`${app}/acts`);
    if (js) await hydrated(page);
    const line = page.getByRole('button', { name: 'Agregar línea' });
    check(`${tag}: the button has no form= (it submits the Form it is in)`, (await line.getAttribute('form')) === null && (await line.getAttribute('name')) === 'thor-arg');
    await page.getByLabel('Cantidad').fill('3');
    await go(page, line.click());
    check(`${tag}: the arguments and the Form's fields (typed and hidden) arrive together`, (await toastState(page))?.text === 'línea sku9/seller2 x3 nota oculto', JSON.stringify(await toastState(page)));
    check(`${tag}: the answer lands back on /acts`, new URL(page.url()).pathname === '/acts', page.url());

    const ping = page.getByRole('button', { name: 'Ping otra página' });
    check(`${tag}: a button of another page's only action posts to that page, no key`, (await ping.getAttribute('formaction')) === '/acts/other', await ping.getAttribute('formaction'));
    await go(page, ping.click());
    check(`${tag}: the other page's action ran`, (await toastState(page))?.text === 'ping de otra página', JSON.stringify(await toastState(page)));
    const inForm = page.getByRole('button', { name: 'Ping en Form' });
    check(`${tag}: a submit button in a Form is enabled with no handler`, await inForm.isEnabled());
    await go(page, inForm.click());
    check(`${tag}: a Form of another page's action posts to that page`, (await toastState(page))?.text === 'ping de otra página', JSON.stringify(await toastState(page)));
    // Two bound submit buttons in one Form: the pressed one's argument only;
    // Enter in a text field is the browser's implicit submission, with the
    // FIRST submit button (its argument).
    await page.locator('input[name=picknote]').fill('n1');
    await go(page, page.getByRole('button', { name: 'Pick B' }).click());
    check(`${tag}: pressing the second button posts only its argument`, (await toastState(page))?.text === 'pick B de 1 nota n1', JSON.stringify(await toastState(page)));
    await page.locator('input[name=picknote]').fill('n2');
    await go(page, page.locator('input[name=picknote]').press('Enter'));
    check(`${tag}: Enter in a field submits with the first button's argument`, (await toastState(page))?.text === 'pick A de 1 nota n2', JSON.stringify(await toastState(page)));
    check(`${tag}: no page problems`, page.problems.length === 0, page.problems.join(' | '));
    await page.context().close();
  }

  // The server never trusts what a button posts.
  {
    const page = await open({ javaScriptEnabled: false });
    await page.goto(`${app}/acts`);
    const bad = [];
    for (const v of ['abc', '', '7.5', '9'.repeat(40), '"><script>', '%00']) bad.push((await post(page, '/acts?/delete', { 'thor-arg': v })).status());
    check('hostile: a value of another type is a 400', bad.every((s) => s === 400), bad.join(','));
    check('hostile: no argument at all is a 400', (await post(page, '/acts?/delete')).status() === 400);
    check('hostile: an enum that does not exist is a 400', (await post(page, '/acts?/assign', { 'thor-arg': '3~root' })).status() === 400);
    check('hostile: a cross-origin POST is a 403', (await post(page, '/acts?/delete', { 'thor-arg': '3' }, { origin: 'http://evil.test' })).status() === 403);
    // The question of `confirm:` is data the request carries: it is text on the page that asks,
    // and a cross-origin post never gets that far.
    const ask = JSON.stringify({ t: '<img src=x onerror=alert(1)>"', m: '</main><script>alert(2)</script>' });
    const forged = await post(page, '/acts?/delete', { 'thor-arg': '3', 'thor-ask': ask });
    const forgedHtml = await forged.text();
    check('hostile: a forged question is escaped text on the confirmation page', forged.status() === 200 && forgedHtml.includes('&lt;img src=x onerror=alert(1)&gt;') && !forgedHtml.includes('<img') && !forgedHtml.includes('<script>alert(2)'), forgedHtml.slice(0, 400));
    check('hostile: a cross-origin post with a question is a 403, not a page', (await post(page, '/acts?/delete', { 'thor-arg': '3', 'thor-ask': ask }, { origin: 'http://evil.test' })).status() === 403);
    check('hostile: nothing was deleted', (await bodyText(page)).includes('#3 Ana') && (await (await page.request.get(`${app}/acts`)).text()).includes('#3 Ana'));
    await page.context().close();
  }

  // -------------------------------------------- confirm: on a button
  {
    const page = await open();
    await reset(page);
    await page.goto(`${app}/acts`);
    await hydrated(page);
    const deletes = [];
    page.on('request', (r) => r.method() === 'POST' && r.url().includes('?/delete') && deletes.push(r.url()));

    check('the page has one dialog, closed', (await page.locator('dialog#thor-confirm').count()) === 1 && !(await dialogOpen(page)));
    await page.getByRole('button', { name: 'Eliminar 3', exact: true }).click();
    await waitDialog(page);
    check('confirm: opens the native dialog with its question, message and labels', (await text(page, '#thor-confirm [data-t-c=t]')) === '¿Eliminar #3?' && (await text(page, '#thor-confirm [data-t-c=m]')) === 'Se borra en el servidor' && (await text(page, '#thor-confirm [data-t-c=o]')) === 'Eliminar');
    check('confirm: the focus starts on Cancel (the answer that does nothing)', await page.evaluate(() => document.activeElement?.getAttribute('data-t-c') === 'n'));
    await page.keyboard.press('Escape');
    await waitDialog(page, false);
    await page.waitForTimeout(150);
    check('confirm: Esc says no, nothing is sent', deletes.length === 0);
    check('confirm: the order is still there', (await bodyText(page)).includes('#3 Ana'));

    // Cancel with the button, then a double click that must ask once.
    await page.getByRole('button', { name: 'Eliminar 3', exact: true }).click();
    await waitDialog(page);
    await page.locator('#thor-confirm [data-t-c=n]').click();
    await waitDialog(page, false);
    check('confirm: Cancel says no', deletes.length === 0);
    await page.getByRole('button', { name: 'Eliminar 3', exact: true }).dblclick({ delay: 10 }).catch(() => {});
    await waitDialog(page);
    check('confirm: a double click opens one dialog', (await page.locator('dialog#thor-confirm[open]').count()) === 1);
    await go(page, page.locator('#thor-confirm [data-t-c=o]').click());
    await settle(page, () => document.getElementById('thor-toast')?.hasAttribute('data-t-on'));
    check('confirm: a yes submits once, and the flash shows', deletes.length === 1 && (await toastState(page))?.text === 'Pedido eliminado', `${deletes.length} ${JSON.stringify(await toastState(page))}`);
    check('confirm: the order is gone', !(await bodyText(page)).includes('#3 Ana'));
    await reset(page);
    check('confirm: no page problems', page.problems.length === 0, page.problems.join(' | '));
    await page.context().close();
  }

  // -------------------------------- confirm() and toast() of a state
  {
    const page = await open();
    await reset(page);
    await page.goto(`${app}/acts`);
    await hydrated(page);
    const row = (id) => page.getByRole('button', { name: 'Quitar', exact: true }).nth(id);
    check('state: the page has the dialog and the bar', (await page.locator('dialog#thor-confirm').count()) === 1 && (await toastState(page))?.on === false);

    await row(1).click();
    await waitDialog(page);
    check('state confirm(): asks with the call\'s text and label', (await text(page, '#thor-confirm [data-t-c=t]')) === '¿Eliminar el pedido 4?' && (await text(page, '#thor-confirm [data-t-c=o]')) === 'Eliminar');
    await page.locator('#thor-confirm [data-t-c=n]').click();
    await waitDialog(page, false);
    await settle(page, () => document.body.innerText.includes('cancelado 4'));
    check('state confirm(): No → the method returns early', (await bodyText(page)).includes('cancelado 4') && (await bodyText(page)).includes('Luis'), await bodyText(page));
    await row(1).click();
    await waitDialog(page);
    await page.locator('#thor-confirm [data-t-c=o]').click();
    await waitDialog(page, false);
    await settle(page, () => document.body.innerText.includes('eliminado 4'));
    const shown = await settle(page, () => document.getElementById('thor-toast')?.hasAttribute('data-t-on') && document.getElementById('thor-toast').textContent);
    check('state confirm(): Yes → the row goes and toast() says so', shown === 'Pedido 4 eliminado' && !(await bodyText(page)).includes('\nLuis'), shown);
    check('toast: a live region (role=status)', (await toastState(page)).role === 'status');
    const successLook = await page.evaluate(() => document.getElementById('thor-toast').className);
    const looks = await page.evaluate(() => [...document.getElementById('thor-toast-kinds').content.children].map((e) => [e.dataset.k, e.className]));
    check('toast: the look is the server\'s success class (no client style)', looks.find(([k]) => k === 'success')[1] === successLook, successLook);

    // Two asks at once: one dialog at a time, in order.
    await page.getByRole('button', { name: 'Dos', exact: true }).click();
    await waitDialog(page);
    check('two confirms at once: the first asks first', (await text(page, '#thor-confirm [data-t-c=t]')) === 'Primera');
    await page.locator('#thor-confirm [data-t-c=o]').click();
    await settle(page, () => document.getElementById('thor-confirm').open && document.querySelector('#thor-confirm [data-t-c=t]').textContent === 'Segunda');
    check('two confirms at once: the second waits its turn', (await text(page, '#thor-confirm [data-t-c=t]')) === 'Segunda' && (await dialogOpen(page)));
    await page.locator('#thor-confirm [data-t-c=n]').click();
    await settle(page, () => document.body.innerText.includes('dobles'));
    check('two confirms at once: answers reach their own ask', (await bodyText(page)).includes('dobles true false'), await text(page, 'body'));

    // A duplicate shows once; the text is text.
    await page.getByRole('button', { name: 'Decir', exact: true }).click();
    await page.getByRole('button', { name: 'Decir', exact: true }).click();
    await settle(page, () => document.getElementById('thor-toast').textContent === 'Hola <b>');
    check('toast: HTML is text, never an element', (await toastState(page)).text === 'Hola <b>' && (await page.locator('#thor-toast b').count()) === 0);
    check('toast: the same message twice in a row is one', await page.evaluate(() => document.getElementById('thor-toast').textContent === 'Hola <b>'));
    await page.getByRole('button', { name: 'Fallar', exact: true }).click();
    // Waits for the first to end (4 s) and the next to take its place.
    const err = await settle(page, () => document.getElementById('thor-toast').textContent === 'Falló', null, { timeout: 8000 });
    const errorLook = await page.evaluate(() => document.getElementById('thor-toast').className);
    check('toast: the next waits its turn, with its own look (error)', err && looks.find(([k]) => k === 'error')[1] === errorLook, errorLook);
    await page.waitForTimeout(5500);
    check('toast: the bar hides itself', !(await toastState(page)).on);

    // A flood keeps the newest few and shows one at a time.
    await page.getByRole('button', { name: 'Diluvio', exact: true }).click();
    const seen = [];
    const until = Date.now() + 4500;
    while (Date.now() < until) {
      const s = await toastState(page);
      if (s.on && seen.at(-1) !== s.text) seen.push(s.text);
      await page.waitForTimeout(40);
    }
    check('toast flood: the first shows at once, then only the newest few, in order', seen[0] === 'Aviso 0' && seen.length <= 4 && seen.slice(1).join() === ['Aviso 7', 'Aviso 8', 'Aviso 9'].slice(0, seen.length - 1).join(), seen.join(','));
    check('toast flood: it ends', !(await toastState(page)).on);

    // hideToast() ends the one showing and the next waiting shows at once;
    // clearToasts() ends it and forgets the waiting ones.
    await page.getByRole('button', { name: 'Diluvio', exact: true }).click();
    await settle(page, () => document.getElementById('thor-toast').textContent === 'Aviso 0');
    await page.getByRole('button', { name: 'Ocultar aviso', exact: true }).click();
    const next = await settle(page, () => document.getElementById('thor-toast').textContent === 'Aviso 7', null, { timeout: 2000 });
    check('hideToast: the showing one goes and the next waiting shows', next === true || next === 'Aviso 7', String(next));
    await page.getByRole('button', { name: 'Limpiar avisos', exact: true }).click();
    await page.waitForTimeout(900);
    check('clearToasts: the bar is empty and none of the waiting ones shows', !(await toastState(page)).on, JSON.stringify(await toastState(page)));
    await page.getByRole('button', { name: 'Ocultar aviso', exact: true }).click();
    check('hideToast with nothing showing does nothing', !(await toastState(page)).on && page.problems.length === 0, page.problems.join(' | '));
    check('state: no page problems', page.problems.length === 0, page.problems.join(' | '));
    await page.context().close();
  }

  // ------------------ an ask before the engine loads is not lost
  {
    const page = await open();
    await reset(page);
    let release;
    const held = new Promise((r) => (release = r));
    await page.route(/\/engine\.dart[^/]*\.js(\?|$)/, async (route) => {
      await held;
      await route.continue();
    });
    await page.goto(`${app}/acts`, { waitUntil: 'domcontentloaded' });
    await page.getByRole('button', { name: 'Quitar', exact: true }).first().click();
    check('early: nothing asks while the engine is still loading', !(await dialogOpen(page)));
    release();
    await waitDialog(page);
    check('early: the click is replayed and asks when the engine is there', (await text(page, '#thor-confirm [data-t-c=t]')).startsWith('¿Eliminar el pedido'));
    await page.locator('#thor-confirm [data-t-c=n]').click();
    await page.context().close();
  }

  // ------------------------------------ toggle, sets and withArgs
  {
    const page = await open();
    await page.goto(`${app}/acts`);
    await hydrated(page);
    const has = (s) => settle(page, (x) => document.body.innerText.includes(x), s);
    check('toggle(): starts closed', await has('cerrado'));
    await page.getByRole('button', { name: 'Alternar' }).click();
    check('toggle(): flips to open', await has('abierto'));
    await page.getByRole('button', { name: 'Alternar' }).click();
    check('toggle(): and back', await has('cerrado'));
    await page.getByRole('button', { name: 'Elegir ana' }).click();
    check('set: toggle adds', await has('elegidos: ana'));
    await page.getByRole('button', { name: 'Elegir luis' }).click();
    check('set: a second member', await has('elegidos: ana,luis'));
    await page.getByRole('button', { name: 'Elegir ana' }).click();
    check('set: toggle removes', await has('elegidos: luis'));
    await page.getByRole('button', { name: 'Etiquetar' }).click();
    check('withArgs(4, "a~b"): both arguments arrive, the ~ intact', await has('etiqueta 4 a~b'));
    // `row.text((o) => o.customer)`: a lambda over the row, no method per field.
    const rowTexts = () => page.evaluate(() => [...document.querySelectorAll('[data-tf]')].filter((e) => !e.closest('template')).map((e) => e.textContent));
    check('row.text(lambda): the server drew the rows', (await rowTexts()).join() === 'Ana,Luis,Marta', (await rowTexts()).join());
    await page.getByRole('button', { name: 'Añadir' }).click();
    await settle(page, () => document.querySelectorAll('[data-tf]').length > 3);
    check('row.text(lambda): a row the browser adds shows its customer', (await rowTexts()).join() === 'Ana,Luis,Marta,Nueva 3', (await rowTexts()).join());
    await page.getByRole('button', { name: 'Renombrar' }).click();
    await settle(page, () => document.body.innerText.includes('Ana*'));
    check('row.text(lambda): a change of the item reaches the text', (await rowTexts()).join() === 'Ana*,Luis,Marta,Nueva 3', (await rowTexts()).join());
    check('no page problems', page.problems.length === 0, page.problems.join(' | '));
    await page.context().close();
  }
  // ------------------------------------------------ adversarial cases
  {
    const page = await open();
    await reset(page);
    await page.goto(`${app}/acts`);
    await hydrated(page);
    const on = (p) => p.evaluate(() => document.getElementById('thor-toast').hasAttribute('data-t-on'));

    // A hovered bar keeps showing, past the script's own timer (WCAG 2.2.1).
    await page.getByRole('button', { name: 'Decir', exact: true }).click();
    await settle(page, () => document.getElementById('thor-toast').hasAttribute('data-t-on'));
    await page.hover('#thor-toast');
    await page.waitForTimeout(6500);
    check('toast: hovered, it stays past the 5 s timer', await on(page));
    await page.mouse.move(0, 0);
    check('toast: unhovered, it goes', await settle(page, () => !document.getElementById('thor-toast').hasAttribute('data-t-on'), null, { timeout: 5000 }));

    // The focus goes back to the button that asked, whatever closed the dialog.
    const del3 = page.getByRole('button', { name: 'Eliminar 3', exact: true });
    await del3.click();
    await waitDialog(page);
    await page.keyboard.press('Escape');
    await waitDialog(page, false);
    check('confirm: after Esc the focus is back on the trigger', await page.evaluate(() => document.activeElement?.textContent === 'Eliminar 3'), await page.evaluate(() => document.activeElement?.outerHTML));
    await del3.click();
    await waitDialog(page);
    await page.locator('#thor-confirm [data-t-c=n]').click();
    await waitDialog(page, false);
    check('confirm: after Cancel the focus is back on the trigger', await page.evaluate(() => document.activeElement?.textContent === 'Eliminar 3'));

    // A click on the backdrop is not an answer (barrierDismissible: false).
    await del3.click();
    await waitDialog(page);
    await page.mouse.click(2, 2);
    await page.waitForTimeout(150);
    check('confirm: a click outside leaves the question open', await dialogOpen(page));
    await page.locator('#thor-confirm [data-t-c=n]').click();
    await waitDialog(page, false);

    // A confirm inside another modal dialog opens above it and gives it back.
    await page.evaluate(() => {
      const x = document.createElement('dialog');
      x.id = 'outer';
      x.style.cssText = 'padding:40px';
      const b = [...document.querySelectorAll('button')].find((e) => e.textContent === 'Eliminar 4');
      x.append(b);
      document.body.append(x);
      x.showModal();
    });
    await page.locator('#outer button').click();
    await waitDialog(page);
    const above = await page.evaluate(() => {
      const r = document.getElementById('thor-confirm').getBoundingClientRect();
      const top = document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2);
      return !!top?.closest('#thor-confirm');
    });
    check('confirm: inside another modal dialog it is on top', above);
    await page.locator('#thor-confirm [data-t-c=n]').click();
    await waitDialog(page, false);
    check('confirm: the other dialog is still open, the focus is back inside it', await page.evaluate(() => document.getElementById('outer').open && document.activeElement?.closest('#outer') !== null));
    await page.evaluate(() => document.getElementById('outer').remove());

    // Enter in a text field of a form with confirm: asks; a no sends nothing.
    const posts = [];
    page.on('request', (r) => r.method() === 'POST' && r.url().includes('?/note') && posts.push(r.url()));
    await page.getByLabel('Nota').fill('hola');
    await page.keyboard.press('Enter');
    await waitDialog(page);
    check('form confirm: Enter in the field asks', (await text(page, '#thor-confirm [data-t-c=t]')) === '¿Guardar la nota?');
    await page.keyboard.press('Escape');
    await waitDialog(page, false);
    await page.waitForTimeout(150);
    check('form confirm: a no sends nothing', posts.length === 0);
    await page.keyboard.press('Enter');
    await waitDialog(page);
    await go(page, page.locator('#thor-confirm [data-t-c=o]').click());
    check('form confirm: a yes sends the field once, the flash follows', posts.length === 1 && (await toastState(page))?.text === 'Nota: hola', `${posts.length} ${JSON.stringify(await toastState(page))}`);

    // A confirm while a toast shows: the dialog works and the toast still ends.
    await page.getByRole('button', { name: 'Decir', exact: true }).click();
    await settle(page, () => document.getElementById('thor-toast').hasAttribute('data-t-on'));
    await del3.click();
    await waitDialog(page);
    await page.locator('#thor-confirm [data-t-c=n]').click();
    await waitDialog(page, false);
    // (the flash of the note shows first, then this one: two toasts of 4 s)
    check('confirm over a toast: the toast ends by itself', await settle(page, () => !document.getElementById('thor-toast').hasAttribute('data-t-on'), null, { timeout: 14000 }));

    // A very long text and a right-to-left page keep the bar on screen.
    for (const dir of ['ltr', 'rtl']) {
      await page.evaluate((d) => {
        document.documentElement.dir = d;
        document.thorToast('x'.repeat(600), 'info', 2500);
      }, dir);
      await settle(page, () => document.getElementById('thor-toast').hasAttribute('data-t-on'));
      const r = await page.evaluate(() => {
        const b = document.getElementById('thor-toast').getBoundingClientRect();
        return { l: b.left, r: b.right, w: innerWidth, sw: document.documentElement.scrollWidth };
      });
      check(`toast: 600 characters stay inside the viewport (${dir})`, r.l >= 0 && r.r <= r.w + 1 && r.sw <= r.w, JSON.stringify(r));
      await settle(page, () => !document.getElementById('thor-toast').hasAttribute('data-t-on'), null, { timeout: 8000 });
    }
    await page.evaluate(() => (document.documentElement.dir = 'ltr'));
    await page.context().close();
  }

  // Reduced motion: the bar still hides after its time.
  {
    const page = await open({ reducedMotion: 'reduce' });
    await page.goto(`${app}/acts`);
    await hydrated(page);
    await page.getByRole('button', { name: 'Decir', exact: true }).click();
    await settle(page, () => document.getElementById('thor-toast').hasAttribute('data-t-on'));
    check('toast, reduced motion: it hides after its time', await settle(page, () => !document.getElementById('thor-toast').hasAttribute('data-t-on'), null, { timeout: 8000 }));
    await page.context().close();
  }

  // Two tabs: the flash goes to the first page that draws, once.
  {
    const a = await open({ javaScriptEnabled: false });
    await reset(a);
    await a.goto(`${app}/acts`);
    const b = await a.context().newPage();
    await go(a, a.getByRole('button', { name: 'Eliminar 5', exact: true }).click());
    await go(a, a.locator('main button').click());
    await b.goto(`${app}/acts`);
    check('flash, two tabs: the tab that did not act draws no flash after the first took it', (await toastState(b))?.on === false);
    // A forged, half-escaped cookie is text or nothing, never a 500.
    await a.context().addCookies([{ name: 'thor-flash', value: '%E0%A4%A', url: app }]);
    const r = await a.request.get(`${app}/acts`);
    check('flash: a malformed cookie is not a server error', r.status() === 200, `${r.status()}`);
    await reset(a);
    await a.context().close();
  }
  // The shared form: a double click sends once; a row the browser adds carries
  // its own key in the button it clones.
  {
    const page = await open();
    await reset(page);
    await page.goto(`${app}/acts`);
    await hydrated(page);
    const assigns = [];
    page.on('request', (r) => r.method() === 'POST' && r.url().includes('?/assign') && assigns.push(r.postData()));
    // The server answers late: a fast 303 plus the new page could land between
    // the two clicks of a loaded machine, and the second click would then be a
    // real click on a new document (a second POST that is not a double submit).
    await page.route(/\?\/assign$/, async (route) => {
      await new Promise((ok) => setTimeout(ok, 400));
      await route.continue();
    });
    await Promise.all([page.waitForNavigation({ waitUntil: 'load' }), page.getByRole('button', { name: 'A Luis 3' }).dblclick({ delay: 10 }).catch(() => {})]);
    check('a double click on an argument button posts once', assigns.length === 1, `${assigns.length}`);
    // Two clicks in the same task (before the form script's own timer runs).
    await reset(page);
    await page.goto(`${app}/acts`);
    await hydrated(page);
    assigns.length = 0;
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'load' }),
      page.evaluate(() => {
        const b = [...document.querySelectorAll('button[name=thor-arg]')].find((e) => e.textContent === 'A Luis 3');
        b.click();
        b.click();
      }),
    ]);
    check('two clicks in one task on an argument button post once', assigns.length === 1, `${assigns.length}`);
    await page.unroute(/\?\/assign$/);
    await page.getByRole('button', { name: 'Añadir' }).click();
    await settle(page, () => document.querySelectorAll('[data-tf]').length > 3);
    const cloned = await page.evaluate(() => {
      const b = [...document.querySelectorAll('button[name=thor-arg]')].filter((e) => !e.closest('template') && e.getAttribute('formaction') === '?/delete').at(-1);
      return b && { value: b.value, form: b.getAttribute('form'), formaction: b.getAttribute('formaction'), attached: b.form?.id };
    });
    check('a row the browser adds: the cloned button carries its key and the shared form', cloned?.value === '13' && cloned.attached === 'thor-post' && cloned.formaction === '?/delete', JSON.stringify(cloned));
    await reset(page);
    await page.context().close();
  }
  // A row key with `~` and `%` before another argument: the server escapes it,
  // and so must the row the browser clones from the template.
  {
    const page = await open();
    await reset(page);
    await page.goto(`${app}/acts`);
    await hydrated(page);
    const has = (x) => settle(page, (t) => document.body.innerText.includes(t), x);
    await page.getByRole('button', { name: 'Marcar', exact: true }).first().click();
    check('withArgs(row.key, …): a server-drawn row with "~" in its key', await has('marca a~b|ok'), await bodyText(page));
    await page.getByRole('button', { name: 'Nueva clave' }).click();
    await settle(page, () => document.querySelectorAll('[data-tk]').length >= 6);
    await page.getByRole('button', { name: 'Marcar', exact: true }).last().click();
    check('withArgs(row.key, …): a row the browser adds keeps "~" and "%" in its key', await has('marca x~y%7E|ok'), await bodyText(page));
    const added = await page.evaluate(() => [...document.querySelectorAll('button[name=thor-arg]')].filter((e) => !e.closest('template') && e.value.endsWith('~ok')).map((e) => e.value));
    check('bind(row.key, …): every row posts its key escaped', added.join() === 'a%7Eb~ok,50%25~ok,x%7Ey%257E~ok', added.join());
    await go(page, page.getByRole('button', { name: 'Marcar (servidor)' }).last().click());
    check('bind(row.key, …): the server reads the key of a row the browser added', (await toastState(page))?.text === 'marca x~y%7E|ok', JSON.stringify(await toastState(page)));
    await page.context().close();
  }

  // A dialog that can't open (someone left it `open`) is a no, and the
  // questions behind it still get their turn: nothing hangs.
  {
    const page = await open();
    await page.goto(`${app}/acts`);
    await hydrated(page);
    const answers = await page.evaluate(async () => {
      const d = document.getElementById('thor-confirm');
      if (!d || !document.thorConfirm) return 'no dialog';
      d.setAttribute('open', '');
      const first = await Promise.race([document.thorConfirm('a'), new Promise((r) => setTimeout(() => r('hung'), 2000))]);
      d.removeAttribute('open');
      const second = document.thorConfirm('b');
      await new Promise((r) => setTimeout(r, 50));
      const shown = d.open;
      d.close('ok');
      return [first, shown, await second];
    });
    check('confirm: a dialog that cannot open answers no and the next ask still shows', JSON.stringify(answers) === '[false,true,true]', JSON.stringify(answers));
    await page.context().close();
  }
});

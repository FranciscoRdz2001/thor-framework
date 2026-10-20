// Forms and lists in a real browser, on test/fixtures/apps/server_query's
// `/orders` and `/edit` (build/server, the lite engine).
//
//   tool/thor e2e query-forms   (builds test/fixtures/apps/server_query, runs)
//   node test/e2e/checks/query_forms_check.mjs
//
// - the list state lives in the URL: `Pagination` links are real links that
//   keep the query (no JavaScript); an action keeps `?q=a&page=3`, the
//   answer of a failed post does not double the action key, and the
//   redirect after a successful post lands on the page without `?/touch`.
//   A hostile or unicode query is text, never markup.
// - a query takes a class as its argument: the call carries its JSON, an
//   equal value asks nothing, a different one asks once.
// - a failed post refills every named field with what was sent (an
//   unchecked box stays unchecked whatever the saved record says), shows
//   every message, focuses the first wrong field and works with no JS;
//   `noValidate` lets the server's messages show; saving redirects clean.
// - a repeated field over the limit is a field error, not a 500.
import { spawn } from 'node:child_process';
import { existsSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { e2e, hydrated, repo, settle, trackHydration } from './lib/e2e.mjs';

const children = [];
const tmp = mkdtempSync(join(tmpdir(), 'thor-query-forms-'));
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

await e2e('query-forms', { site: tmp, timeout: 150_000 }, async (t) => {
  const bin = join(repo, 'test/fixtures/apps/server_query/build/server');
  if (!existsSync(bin)) throw new Error('test/fixtures/apps/server_query/build/server is missing: build it first (tool/thor e2e builds it)');
  const port = await freePort();
  children.push(spawn(bin, [], { cwd: join(repo, 'test/fixtures/apps/server_query'), env: { ...process.env, PORT: `${port}` }, stdio: 'ignore' }));
  const app = `http://127.0.0.1:${port}`;
  await waitFor(`${app}/orders`);

  const path = (page) => {
    const u = new URL(page.url());
    return u.pathname + u.search;
  };
  const clean = (page) => page.problems.filter((p) => !/Failed to load resource/.test(p));
  const hrefs = (page, label) => page.locator(`nav[aria-label="Pagination"] a`).evaluateAll((as) => as.map((a) => [a.textContent.trim(), a.getAttribute('href')]));

  // --- no JavaScript ----------------------------------------------------
  {
    const ctx = await t.page({ javaScriptEnabled: false });
    await ctx.goto(`${app}/orders?q=a&page=2`);
    const nav = await ctx.locator('nav[aria-label="Pagination"]').count();
    t.check('a nav with the pagination', nav === 1);
    const current = await ctx.locator('nav a[aria-current="page"]').allTextContents();
    t.check('the current page is marked', current.length === 1 && current[0].trim() === '2', JSON.stringify(current));
    const links = await hrefs(ctx);
    const three = links.find(([label]) => label === '3');
    t.check('a page link keeps the search', three?.[1] === '/orders?q=a&page=3', JSON.stringify(three));
    await ctx.locator('nav a', { hasText: '3' }).first().click();
    await ctx.waitForURL(/page=3/);
    t.check('following it lands on that page', path(ctx) === '/orders?q=a&page=3', path(ctx));
    t.check('the summary says page 3', (await ctx.locator('body').innerText()).includes('page: 3'));

    // An action keeps the query and goes back without it (PRG).
    await ctx.locator('input[name=note]').fill('hola');
    await ctx.getByRole('button', { name: 'Guardar', exact: true }).click();
    await ctx.waitForURL((u) => !u.search.includes('/touch'));
    t.check('after a successful post the URL is the page with its query', path(ctx) === '/orders?q=a&page=3', path(ctx));

    // A failed post: its answer keeps the query in the links and does not double the action.
    await ctx.getByRole('button', { name: 'Fallar', exact: true }).click();
    await ctx.waitForURL(/\/fail/);
    t.check('the failed post answered on the same page', (await ctx.locator('body').innerText()).includes('page: 3'));
    const after = await hrefs(ctx);
    t.check('its pagination links do not carry the action key', after.every(([, h]) => !h.includes('fail')), JSON.stringify(after.map((a) => a[1])));
    const action = await ctx.locator('form[action*="touch"]').getAttribute('action');
    t.check('its form does not double the action key', action === '?q=a&page=3&/touch', action);
    await ctx.locator('input[name=note]').fill('otra');
    await ctx.getByRole('button', { name: 'Guardar', exact: true }).click();
    await ctx.waitForURL((u) => !u.search.includes('/'), { timeout: 5000 }).catch(() => {});
    t.check('saving from the failed page ends on the clean URL', path(ctx) === '/orders?q=a&page=3', path(ctx));
    await ctx.context().close();
  }

  // --- hostile and unicode queries -------------------------------------
  {
    const ctx = await t.page({ javaScriptEnabled: false });
    let dialog = false;
    ctx.on('dialog', (d) => ((dialog = true), d.dismiss()));
    const evil = '"><img src=x onerror=alert(1)>';
    await ctx.goto(`${app}/orders?q=${encodeURIComponent(evil)}`);
    t.check('a hostile q is text in the field', (await ctx.locator('input[name=q]').inputValue()) === evil);
    t.check('nothing was injected', (await ctx.locator('img[src=x]').count()) === 0 && !dialog);
    await ctx.goto(`${app}/orders?q=${encodeURIComponent('ñ')}`);
    const body = await ctx.locator('body').innerText();
    t.check('unicode search finds the rows', /Ñandú/i.test(body) || body.includes('total: 0') === false, body.slice(0, 80));
    for (const bad of ['0', '-1', 'abc', '99999999999999999999']) {
      const r = await ctx.goto(`${app}/orders?page=${bad}`);
      t.check(`page=${bad} is a page, not an error`, r.status() === 200);
    }
    await ctx.goto(`${app}/orders?sort=${encodeURIComponent('password;DROP')}`);
    t.check('an unknown sort falls back', (await ctx.locator('body').innerText()).includes('total: 45'));
    await ctx.context().close();
  }

  // --- a class argument --------------------------------------------------
  {
    const page = await t.page();
    await trackHydration(page);
    const calls = [];
    page.on('request', (r) => r.headers()['x-thor-query'] && calls.push({ id: r.headers()['x-thor-query'], body: JSON.parse(r.postData()) }));
    await page.goto(`${app}/orders`);
    await hydrated(page);
    const click = (name) => page.getByRole('button', { name, exact: true }).click();
    const has = (w) => settle(page, (x) => document.body.innerText.includes(x), w, { timeout: 5000 });
    await click('Siguiente');
    t.check('next asks with the class as JSON', !!(await has('arg: |2|a,b')));
    await settle(page, () => true, null, { timeout: 200 });
    t.check('the call carried its fields, the list in order', calls.length === 1 && JSON.stringify(calls[0].body.arg) === JSON.stringify({ q: '', page: 2, tags: ['a', 'b'], status: null }), JSON.stringify(calls));
    t.check('the answer is drawn', !!(await has('found: ')) && /found: \d+:/.test(await page.locator('body').innerText()));
    await click('Igual');
    await new Promise((r) => setTimeout(r, 300));
    t.check('an equal value asks nothing', calls.length === 1, `${calls.length}`);
    await click('Buscar ñ');
    await has('arg: ñ|1|a,b');
    await new Promise((r) => setTimeout(r, 300));
    t.check('a different value asks once', calls.length === 2 && calls[1].body.arg.q === 'ñ' && calls[1].body.arg.page === 1, JSON.stringify(calls.map((c) => c.body.arg)));
    await click('Buscar ñ');
    await new Promise((r) => setTimeout(r, 300));
    t.check('the same search again asks nothing', calls.length === 2, `${calls.length}`);
    t.check('no page errors', clean(page).length === 0, clean(page).join('; '));
    await page.context().close();
  }

  // --- edit form, with and without JavaScript ----------------------------
  // The record is shared: the second pass starts from what the first saved.
  let saved = ['Saved name', '9.5'];
  for (const js of [false, true]) {
    const label = js ? 'JS' : 'no JS';
    const page = await t.page({ javaScriptEnabled: js });
    await page.goto(`${app}/edit`);
    const val = (name) => page.locator(`[name=${name}]`).first().inputValue();
    t.check(`${label}: the saved record fills the form`, (await val('name')) === saved[0] && (await val('price')) === saved[1] && (await val('born')) === '1990-05-03' && (await val('plan')) === 'pro');
    t.check(`${label}: its box is checked`, await page.locator('[name=terms]').isChecked());
    // Break it: taken name, negative price, a short nick, the box off.
    await page.locator('[name=name]').fill('taken');
    await page.locator('[name=price]').fill('-3');
    await page.locator('[name=nick]').fill('ab');
    await page.locator('[name=terms]').uncheck();
    // The page's only action posts to its own path: the failed answer
    // stays at /edit, with no `?/save` in the URL.
    await Promise.all([page.waitForNavigation({ waitUntil: 'load' }), page.getByRole('button', { name: 'Guardar', exact: true }).click()]);
    t.check(`${label}: a failed save stays at the page's own URL`, path(page) === '/edit', path(page));
    const body = await page.locator('body').innerText();
    t.check(`${label}: every server message shows (noValidate)`, ['That name is taken.', 'No negatives.', 'Nick is short.', 'Accept the terms.'].every((m) => body.includes(m)), body.slice(0, 200));
    t.check(`${label}: what was typed is back`, (await val('name')) === 'taken' && (await val('price')) === '-3' && (await val('nick')) === 'ab');
    t.check(`${label}: the unchecked box stays unchecked, whatever the record says`, !(await page.locator('[name=terms]').isChecked()));
    t.check(`${label}: the select kept its option`, (await val('plan')) === 'pro');
    t.check(`${label}: the first wrong field has the focus`, (await page.evaluate(() => document.activeElement?.getAttribute('name'))) === 'name');
    t.check(`${label}: the field is marked invalid`, (await page.locator('[name=name]').getAttribute('aria-invalid')) === 'true');
    // Fix it and save: redirect to the clean URL, the record changed.
    await page.locator('[name=name]').fill('Nuevo nombre');
    await page.locator('[name=price]').fill('12.25');
    await page.locator('[name=nick]').fill('');
    await page.locator('[name=terms]').check();
    await Promise.all([page.waitForNavigation({ waitUntil: 'load' }), page.getByRole('button', { name: 'Guardar', exact: true }).click()]);
    t.check(`${label}: after saving the URL has no action`, path(page) === '/edit', path(page));
    t.check(`${label}: the record shows what was saved`, (await val('name')) === 'Nuevo nombre' && (await val('price')) === '12.25');
    saved = ['Nuevo nombre', '12.25'];
    if (js) t.check('JS: no page errors', clean(page).length === 0, clean(page).join('; '));
    await page.context().close();
  }

  // --- a repeated field over its limit is a message ----------------------
  {
    const res = await fetch(`${app}/edit?/save`, {
      method: 'POST',
      redirect: 'manual',
      headers: { 'content-type': 'application/x-www-form-urlencoded', origin: app },
      body: 'id=7&name=ok&plan=free&terms=on&tags=a&tags=b&tags=c&tags=d&price=1e999&born=2023-02-29',
    });
    const text = await res.text();
    t.check('too many repeated values is a 422, not a 500', res.status === 422, `${res.status}`);
    t.check('its message', text.includes('At most three tags.'));
    t.check('a number nobody can hold and an impossible date are field messages', text.includes('Price is a number.') && text.includes('Not a real date.'));
  }
});

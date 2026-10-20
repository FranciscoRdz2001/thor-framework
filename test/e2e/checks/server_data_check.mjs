// Server data in a real browser: the timing of
// `query` and `command` calls and their errors, on test/fixtures/apps/server_query's
// public `/lab` page (build/server, the lite engine).
//
//   tool/thor e2e server-data                (builds test/fixtures/apps/server_query, runs)
//   node test/e2e/checks/server_data_check.mjs
//
// - runs queue: two clicks on two rows send two calls, one after the
//   other, in order; a state method awaits `run` and goes on.
// - a command refreshes only the queries it invalidates.
// - a command's answer computed for an old query argument never lands.
// - a new call of a query aborts the one before it; a timeout ends a
//   call in an error and `loading` / `pending` go back to false; offline.
// - the errors' texts and kinds (network, timeout, forbidden, server,
//   client) come from the page; a failed first paint has them too.
// - `QueryBuilder(query:, builder: (context, snapshot) => …)`: the server
//   draws the state the query is in (also without JavaScript); the browser
//   switches waiting → failed → done with the snapshot's own words.
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { e2e, hydrated, repo, settle, trackHydration } from './lib/e2e.mjs';

const children = [];
const tmp = mkdtempSync(join(tmpdir(), 'thor-data-'));
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

await e2e('server-data', { site: tmp, timeout: 150_000 }, async (t) => {
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
  await waitFor(`${app}/lab`);

  const open = async (options = {}) => {
    const page = await t.page(options);
    await trackHydration(page);
    // Every call of the browser to the server, with when it started and ended.
    page.calls = [];
    page.on('request', (r) => {
      const id = r.headers()['x-thor-command'] ?? r.headers()['x-thor-query'];
      if (!id) return;
      const call = { id, body: r.postData(), start: Date.now(), end: 0, status: 0, failed: '' };
      r.call = call;
      page.calls.push(call);
    });
    page.on('response', (r) => {
      if (r.request().call) Object.assign(r.request().call, { end: Date.now(), status: r.status() });
    });
    page.on('requestfailed', (r) => r.call && Object.assign(r.call, { end: Date.now(), failed: r.failure()?.errorText ?? 'failed' }));
    await page.goto(`${app}/lab`);
    await hydrated(page);
    return page;
  };
  const text = (page) => page.locator('body').innerText();
  // The rows the page shows (the first line of the lab).
  const rows = async (page) => (await text(page)).split('\n')[0].trim().replace(/^filas: ?/, '');
  const rowsAre = (page, want, timeout = 6000) => settle(page, (w) => document.body.innerText.split('\n')[0].trim() === `filas: ${w}`.trim(), want, { timeout });
  const has = async (page, want, timeout = 5000) =>
    !!(await settle(page, (w) => document.body.innerText.includes(w), want, { timeout }));
  const click = (page, name) => page.getByRole('button', { name, exact: true }).click();
  const arg = (call) => JSON.parse(call.body).arg;
  // Polls [ok] in node until it is true (the browser's events reach node a
  // moment after the page's own state changes): a condition, never a sleep.
  const until = async (ok, timeout = 5000) => {
    for (const end = Date.now() + timeout; Date.now() < end && !ok(); ) await new Promise((r) => setTimeout(r, 16));
    return ok();
  };
  // A real error is a page error: a 4xx or a 5xx is logged by Chrome on its own.
  const clean = (page) => page.problems.filter((p) => !/Failed to load resource/.test(p));

  // --- a failed first paint has its text and its kind ------------------------
  {
    const page = await open();
    const body = await text(page);
    t.check('errors: first paint: an HttpError keeps its message', body.includes('Solo para administradores.'));
    t.check('errors: first paint: the kind of it', body.includes('forbidden'));
    t.check('errors: first paint: an unexpected failure is generic', body.includes('Something went wrong') && body.includes('server'));
    t.check('errors: first paint: a status with no message', body.includes('Error 429') && body.includes('client'));
    t.check('errors: no request on load', page.calls.length === 0, `${page.calls.length}`);
    await page.context().close();
  }

  // --- runs queue ------------------------------------------------------------
  {
    const page = await open();
    await click(page, 'Reiniciar');
    t.check('queue: reset answers', await rowsAre(page, 'a,b,c,d'));
    page.calls.length = 0;
    // Two clicks in the same task: the second run waits for the first.
    await page.evaluate(() => {
      for (const name of ['Borrar a', 'Borrar b']) [...document.querySelectorAll('button')].find((b) => b.innerText.trim() === name).click();
    });
    t.check('queue: both rows are gone', await rowsAre(page, 'c,d'), await rows(page));
    const [first, second] = page.calls;
    t.check('queue: two calls, in order', page.calls.length === 2 && arg(first) === 'a' && arg(second) === 'b', JSON.stringify(page.calls.map((c) => c.body)));
    t.check('queue: the second one started after the first was answered', second && second.start >= first.end, `${second?.start - first?.end} ms`);
    t.check('queue: neither was dropped (two 200)', page.calls.every((c) => c.status === 200));
    // Ten quick runs of the same command: none lost either.
    await click(page, 'Reiniciar');
    await rowsAre(page, 'a,b,c,d');
    page.calls.length = 0;
    await page.evaluate(() => {
      const press = (name) => [...document.querySelectorAll('button')].find((b) => b.innerText.trim() === name).click();
      for (const n of ['Borrar a', 'Borrar b', 'Borrar c', 'Borrar d', 'Borrar a', 'Borrar b', 'Borrar c', 'Borrar d']) press(n);
    });
    const emptied = await rowsAre(page, '', 8000); t.check('queue: eight quick runs, the rows end empty', emptied, await rows(page));
    for (let i = 0; i < 100 && !(page.calls.length === 8 && page.calls.every((c) => c.end)); i++) await new Promise((r) => setTimeout(r, 50));
    t.check('queue: eight calls, one at a time', page.calls.length === 8 && page.calls.every((c, i) => i === 0 || c.start >= page.calls[i - 1].end), `${page.calls.length}`);
    // A state method that awaits `run` (removeAB) goes on when it is answered.
    await click(page, 'Reiniciar');
    await rowsAre(page, 'a,b,c,d');
    page.calls.length = 0;
    await click(page, 'Borrar a y b');
    t.check('queue: a method awaits run and runs the next', (await rowsAre(page, 'c,d')) && page.calls.length === 2 && arg(page.calls[0]) === 'a' && arg(page.calls[1]) === 'b');
    // `remove` invalidates rows only: the other queries were not asked again.
    const refreshed = page.calls.map((c) => JSON.parse(c.body).queries);
    t.check('invalidation: the request names every query of the page', refreshed.every((q) => q && 'LabState.rows' in q && 'LabState.slow' in q), JSON.stringify(refreshed[0]));
    t.check('invalidation: no query request after a command', page.calls.every((c) => c.id.startsWith('LabState.remove')));
    t.check('queue: no page errors', clean(page).length === 0, clean(page).join('; '));
    await page.context().close();
  }

  // --- a new call aborts the one before, a timeout ends a call ---------------
  {
    const page = await open();
    // A slow call (1.5 s, the state waits 0.6 s) replaced by a fast one.
    await click(page, 'Lenta 1500');
    await click(page, 'Lenta 50');
    t.check('abort: the last call lands', await has(page, 'valor 50') && (await text(page)).includes('Quieta'), await text(page));
    const slow = page.calls.filter((c) => c.id === 'LabState.slow');
    t.check('abort: two calls, the first one aborted by the second', slow.length === 2 && slow[0].failed !== '' && slow[1].status === 200, JSON.stringify(slow.map((c) => [c.status, c.failed])));
    t.check('abort: no error from an aborted call', !(await text(page)).includes('cancelled'));

    // A call that doesn't answer in time ends in an error; loading goes back.
    page.calls.length = 0;
    await click(page, 'Lenta 1500');
    t.check('abort: loading shows', await has(page, 'Cargando', 1000));
    t.check('abort: the timeout ends the call in an error', await has(page, 'The server took too long to answer', 3000));
    t.check('abort: its kind is timeout', (await text(page)).includes('timeout'));
    t.check('abort: loading went back to false', await has(page, 'Quieta', 1000));
    t.check('abort: the fetch was aborted (the server stops being waited for)', page.calls[0].failed !== '', JSON.stringify(page.calls[0]));
    // The next call clears the error and its kind.
    await click(page, 'Lenta 50');
    t.check('abort: the next call clears the error', await settle(page, () => !document.body.innerText.includes('took too long'), null, { timeout: 3000 }));

    // A command that hangs: pending goes back, the error says timeout.
    await click(page, 'Colgar');
    t.check('abort: a command that hangs ends in a timeout error', await has(page, 'The server took too long to answer', 3000));
    t.check('abort: a next command still goes (the queue is free)', (await click(page, 'Negar'), await has(page, 'No puedes hacer eso.')));
    t.check('errors: 403 is forbidden', (await text(page)).includes('forbidden'));
    await click(page, 'Limitar');
    t.check('errors: a status with no message, kind client', (await has(page, 'Error 429')) && (await text(page)).includes('client'));

    // Offline: a network error with the app's text, kind network.
    await page.context().setOffline(true);
    await click(page, 'Negar');
    t.check('errors: offline: the network text', await has(page, 'Network error', 3000));
    t.check('errors: offline: kind network', (await text(page)).includes('network'));
    await page.context().setOffline(false);
    await click(page, 'Negar');
    t.check('errors: back online: the server says forbidden again', await has(page, 'No puedes hacer eso.'));
    t.check('abort: no page errors', clean(page).length === 0, clean(page).join('; '));
    await page.context().close();
  }

  // --- an answer computed for an old argument never lands --------------------
  {
    const page = await open();
    await click(page, 'Lenta 50');
    t.check('stale answer: the query has its value for argument 50', await has(page, 'valor 50'));
    await click(page, 'Lenta 1500'); // the argument moves to 1500 (its own call times out)
    await click(page, 'Reiniciar'); // sent with 1500: the server takes 1.8 s to answer
    await click(page, 'Lenta 50'); // the argument moves back on while it flies
    t.check('stale answer: the query shows 50 again', await has(page, 'valor 50'));
    await new Promise((r) => setTimeout(r, 2600));
    const answered = page.calls.find((c) => c.id === 'LabState.reset');
    t.check('stale answer: the command was answered', answered?.status === 200, JSON.stringify(answered));
    const body = await text(page);
    t.check("stale answer: the query kept its own value, not the command's for 1500", body.includes('valor 50') && !body.includes('valor 1500'), body);
    t.check('stale answer: not loading', body.includes('Quieta'));
    await page.context().close();
  }
  // --- QueryBuilder: the snapshot's states, on the server and in the browser ---
  {
    // Without JavaScript: the first paint says what the server knows.
    const bare = await t.page({ javaScriptEnabled: false });
    await bare.goto(`${app}/lab`);
    const html = await bare.locator('body').innerText();
    t.check('QueryBuilder: no JS: a done query with data', html.includes('lenta: done con dato'), html);
    t.check('QueryBuilder: no JS: a failed query, with its message', html.includes('negada: error') && html.includes('Solo para administradores.'));
    await bare.context().close();

    const page = await open();
    const body0 = await text(page);
    t.check('QueryBuilder: first paint: done with data', body0.includes('lenta: done con dato'));
    t.check('QueryBuilder: first paint: failed, its message follows the query', body0.includes('negada: error'));
    // waiting with the last value → failed by timeout → done again
    await click(page, 'Lenta 1500');
    t.check('QueryBuilder: a call on its way is waiting and keeps the data', await has(page, 'lenta: waiting con dato', 1000), await text(page));
    t.check('QueryBuilder: the timeout switches to the failed state', await has(page, 'lenta: error', 3000), await text(page));
    t.check('QueryBuilder: the failed state shows the message', (await text(page)).includes('The server took too long to answer'));
    await click(page, 'Lenta 50');
    t.check('QueryBuilder: the next call is waiting again', await has(page, 'lenta: waiting con dato', 1000) || (await text(page)).includes('lenta: done con dato'));
    t.check('QueryBuilder: and the answer is done with data', await has(page, 'lenta: done con dato', 3000), await text(page));
    t.check('QueryBuilder: the failed state is gone', !(await text(page)).includes('lenta: error'));
    // A retry of the failed first paint: waiting (no data), then failed again.
    await page.route(
      (u) => u.pathname === '/lab',
      async (r) => {
        if (r.request().headers()['x-thor-query'] === 'LabState.denied') await new Promise((ok) => setTimeout(ok, 400));
        return r.continue();
      },
    );
    await click(page, 'Reintentar negada');
    t.check('QueryBuilder: a retry after a failed first paint is waiting without data', await has(page, 'negada: waiting', 1500), await text(page));
    t.check('QueryBuilder: and fails again with the server\'s message', (await has(page, 'negada: error', 3000)) && (await text(page)).includes('Solo para administradores.'));
    t.check('QueryBuilder: the retry made one request', page.calls.filter((c) => c.id === 'LabState.denied').length === 1);
    t.check('QueryBuilder: no page errors', clean(page).length === 0, clean(page).join('; '));
    await page.context().close();
  }

  // --- adversarial: what a proxy, a redirect and a closing page do -----------
  {
    // A 200 with an HTML body (a captive portal, a proxy): not the server's
    // answer, so an error of kind server; the data stays; no page error.
    const page = await open();
    await click(page, 'Lenta 50');
    t.check('ADV the query has its value', await has(page, 'valor 50'));
    await page.route(
      (u) => u.pathname === '/lab',
      (r) => {
        const h = r.request().headers();
        if (r.request().method() === 'POST' && h['x-thor-query']) return r.fulfill({ status: 200, contentType: 'text/html', body: '<html><h1>portal</h1></html>' });
        if (r.request().method() === 'POST' && h['x-thor-command']) return r.fulfill({ status: 502, contentType: 'text/html', body: '<html>Bad gateway</html>' });
        return r.continue();
      },
    );
    await click(page, 'Lenta 1500');
    t.check('ADV a 200 that is HTML is an error of kind server', (await has(page, 'Something went wrong')) && (await text(page)).includes('server'), await text(page));
    t.check('ADV loading went back', await has(page, 'Quieta', 1500));
    await click(page, 'Borrar a');
    t.check('ADV a 502 with HTML to a command: generic text, run is over', await has(page, 'Something went wrong', 2000), await text(page));
    t.check('ADV no page errors from proxy answers', clean(page).length === 0, clean(page).join('; '));
    await page.context().close();
  }

  {
    // A 401 with `redirect` in the middle of a queue: the page goes there
    // and nothing throws.
    const page = await open();
    // The page must answer a command before the route lies: `hydrated` says
    // the engine started, a real round trip says the buttons are wired (the
    // three clicks below are synchronous, nothing retries a lost one).
    await click(page, 'Reiniciar');
    await until(() => page.calls.some((c) => c.status === 200));
    page.calls.length = 0;
    await page.route(
      (u) => u.pathname === '/lab',
      (r) =>
        r.request().method() === 'POST' && r.request().headers()['x-thor-command']
          ? r.fulfill({ status: 401, contentType: 'application/json', body: JSON.stringify({ error: 'Sign in again', redirect: '/login' }) })
          : r.continue(),
    );
    // The page asks for /login once: a second `assign` would abort the first
    // navigation (`waitForURL` rejects with net::ERR_ABORTED, the flake this
    // block had), and the queued runs behind a 401 go nowhere.
    const logins = [];
    page.on('request', (r) => r.isNavigationRequest() && new URL(r.url()).pathname === '/login' && logins.push(r.url()));
    await page.evaluate(() => {
      for (const name of ['Borrar a', 'Borrar b', 'Borrar c']) [...document.querySelectorAll('button')].find((b) => b.innerText.trim() === name).click();
    });
    // The navigation itself (its request), not `load` of the sign-in page
    // (a 404 here): what the product does is ask for /login.
    const went = await page.waitForURL((u) => u.pathname === '/login', { timeout: 10_000, waitUntil: 'commit' }).then(() => true, () => false);
    t.check('ADV a 401 with redirect goes to sign in', went, `${page.url()} calls ${JSON.stringify(page.calls.map((c) => [c.id, c.status, c.failed]))}`);
    await new Promise((r) => setTimeout(r, 300));
    t.check('ADV the redirect navigates once and the queue behind it sends nothing', logins.length === 1 && page.calls.length === 1, `${logins.length} navigations, ${page.calls.length} calls`);
    t.check('ADV no page errors on the redirect', clean(page).length === 0, clean(page).join('; '));
    await page.context().close();
  }

  {
    // Leaving the page with runs queued: the browser drops the fetches; no
    // rejection reaches the console.
    const page = await open();
    await click(page, 'Reiniciar');
    await rowsAre(page, 'a,b,c,d');
    await page.evaluate(() => {
      for (const name of ['Borrar a', 'Borrar b', 'Borrar c', 'Borrar d']) [...document.querySelectorAll('button')].find((b) => b.innerText.trim() === name).click();
    });
    await page.goto(`${app}/login`);
    await new Promise((r) => setTimeout(r, 600));
    t.check('ADV leaving with runs queued: no page errors', clean(page).length === 0, clean(page).join('; '));
    await page.context().close();
  }

  {
    // Twenty quick changes of a query's argument: one request survives, the
    // last one lands, the rest were aborted; no error text from them.
    const page = await open();
    page.calls.length = 0;
    await page.evaluate(() => {
      const press = (name) => [...document.querySelectorAll('button')].find((b) => b.innerText.trim() === name).click();
      for (let i = 0; i < 20; i++) press(i % 2 ? 'Lenta 1500' : 'Lenta 50');
      press('Lenta 50');
    });
    t.check('ADV the last argument lands', await has(page, 'valor 50', 4000), await text(page));
    const slow = page.calls.filter((c) => c.id === 'LabState.slow');
    t.check('ADV 21 calls, only the last one was not aborted', slow.length === 21 && slow.slice(0, -1).every((c) => c.failed !== '') && slow.at(-1).status === 200, JSON.stringify(slow.map((c) => [c.status, c.failed])));
    await new Promise((r) => setTimeout(r, 900));
    const body = await text(page);
    t.check('ADV no error text from aborted or timed out calls', !body.includes('cancelled') && !body.includes('took too long') && body.includes('Quieta'), body);
    t.check('ADV no page errors after the burst', clean(page).length === 0, clean(page).join('; '));
    await page.context().close();
  }

  {
    // A page whose `!q` was tampered with (markup, made-up ids, keyed
    // states): the command still runs, only known ids come back.
    const page = await t.page();
    await trackHydration(page);
    page.calls = [];
    page.on('request', (r) => r.headers()['x-thor-command'] && page.calls.push(r.postData()));
    await page.route(
      (u) => u.pathname === '/lab',
      async (r) => {
        if (r.request().method() !== 'GET') return r.continue();
        const res = await r.fetch();
        const html = (await res.text()).replace('"!q":[', '"!q":["\\u003c/script\\u003e.q","Nope.x","LabState#\\u003cimg\\u003e.rows","__proto__.a",5,');
        return r.fulfill({ response: res, body: html });
      },
    );
    await page.goto(`${app}/lab`);
    await hydrated(page);
    await click(page, 'Reiniciar');
    // The rows are a,b,c,d already: only the call proves the command ran.
    await until(() => page.calls.length > 0);
    t.check('ADV a tampered !q: the command still runs and lands', page.calls.length > 0 && (await rowsAre(page, 'a,b,c,d')));
    const queries = Object.keys(JSON.parse(page.calls[0]).queries);
    t.check('ADV the request names the real queries', ['LabState.rows', 'LabState.slow'].every((q) => queries.includes(q)), queries.join(','));
    t.check('ADV no page errors on a tampered !q', clean(page).length === 0, clean(page).join('; '));
    await page.context().close();
  }
});

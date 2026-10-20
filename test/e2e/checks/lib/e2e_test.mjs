// The harness fails closed: every way a check can go wrong ends in a
// non-zero exit with the reason, and nothing is left running.
//
//   node --test test/e2e/checks/lib/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { get } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { closeServer, serveApp, serveStatic } from './e2e.mjs';

const lib = new URL('./e2e.mjs', import.meta.url).href;
const dir = mkdtempSync(join(tmpdir(), 'thor-e2e-'));
const site = join(dir, 'site');
mkdirSync(join(site, 'guia'), { recursive: true });
writeFileSync(join(site, 'index.html'), '<title>t</title><button>+</button>');
writeFileSync(join(site, 'guia', 'x.html'), '<p>x</p>');
writeFileSync(join(dir, 'secret.txt'), 'outside');
process.on('exit', () => rmSync(dir, { recursive: true, force: true }));

// Runs a check program whose body is `body`; resolves {code, out}.
function run(body, { options = `{ site: ${JSON.stringify(site)} }`, signal, env = {} } = {}) {
  const file = join(dir, `c${Math.random().toString(36).slice(2)}.mjs`);
  writeFileSync(file, `import { e2e } from ${JSON.stringify(lib)};\nawait e2e('fixture', ${options}, async (t) => {\n${body}\n});\n`);
  // Its own process group (`detached`): a Ctrl-C at the terminal running the
  // tests, or a parent that ignores SIGINT (a job started with `&`), reaches
  // the test and not the check; the signal below goes to the child alone.
  const child = spawn(process.execPath, [file], { env: { ...process.env, ...env }, detached: true });
  let out = '';
  let sent = 0;
  let resend;
  child.stdout.on('data', (d) => {
    out += d;
    if (signal && !sent && out.includes('READY')) {
      // A signal sent before the child's handler is in place is lost, and one
      // that is ignored never arrives: ask again, and kill it in the end so
      // the test fails with the output instead of hanging.
      const send = () => {
        child.kill(++sent > 4 ? 'SIGKILL' : signal);
      };
      send();
      resend = setInterval(send, 1500);
    }
  });
  child.stderr.on('data', (d) => (out += d));
  return new Promise((ok) =>
    child.on('exit', (code, sig) => {
      clearInterval(resend);
      ok({ code: code ?? (sig ? 128 + 9 : null), out });
    }),
  );
}

test('passes when every check passes', async () => {
  const r = await run(`const p = await t.page(); await p.goto(t.url); t.check('button', await p.locator('button').count() === 1);`);
  assert.equal(r.code, 0, r.out);
  assert.match(r.out, /✓ fixture: 1 passed/);
});

test('one failed check fails the run and says which', async () => {
  const r = await run(`t.check('good', true); t.check('bad one', false, 'saw 3');`);
  assert.equal(r.code, 1, r.out);
  assert.match(r.out, /FAIL bad one \(saw 3\)/);
  assert.match(r.out, /1 of 2 failed/);
});

test('an exception fails the run with its stack', async () => {
  const r = await run(`t.check('before', true); throw new Error('boom');`);
  assert.equal(r.code, 1, r.out);
  assert.match(r.out, /FAIL fixture: Error: boom/);
});

test('a run that checks nothing fails (fail closed)', async () => {
  const r = await run(``);
  assert.equal(r.code, 1, r.out);
  assert.match(r.out, /no checks ran/);
});

test('a missing build fails with how to build it', async () => {
  const r = await run(`t.check('x', true);`, { options: `{ site: ${JSON.stringify(join(dir, 'nope'))} }` });
  assert.equal(r.code, 1, r.out);
  assert.match(r.out, /index\.html is missing: build it first/);
});

test('site null: nothing is served, the body brings its own', async () => {
  const r = await run(`t.check('no url', t.url === ''); const p = await t.page(); await p.goto('data:text/html,<b>x</b>'); t.check('page', await p.locator('b').count() === 1);`, { options: '{ site: null }' });
  assert.equal(r.code, 0, r.out);
  assert.match(r.out, /✓ fixture: 2 passed/);
});

test('a hung check times out and exits', async () => {
  const r = await run(`t.check('x', true); await new Promise(() => {});`, { env: { E2E_TIMEOUT: '1500' } });
  assert.equal(r.code, 1, r.out);
  assert.match(r.out, /timed out after 1500 ms/);
});

test('Ctrl-C closes the browser and the server, exit 130', async () => {
  const r = await run(`const p = await t.page(); await p.goto(t.url); console.log('READY'); await new Promise(() => {});`, {
    signal: 'SIGINT',
  });
  assert.equal(r.code, 130, r.out);
  assert.match(r.out, /interrupted/);
});

test('the static server stays inside its directory', async () => {
  const server = await serveStatic(site);
  const port = server.address().port;
  const status = (path) =>
    new Promise((ok, ko) => get({ host: '127.0.0.1', port, path }, (res) => (res.resume(), ok(res.statusCode))).on('error', ko));
  try {
    assert.equal(await status('/'), 200);
    assert.equal(await status('/guia/x'), 200); // clean URL
    assert.equal(await status('/%2e%2e/secret.txt'), 404);
    assert.equal(await status('/..%2fsecret.txt'), 404);
    assert.equal(await status('/%E0%A4%A'), 400); // malformed escape
    assert.equal(await status('/missing'), 404);
  } finally {
    await closeServer(server);
  }
  assert.equal(server.listening, false);
});

test('serveApp throws with the server output when the app does not start', async () => {
  const bin = join(dir, 'broken-server');
  writeFileSync(bin, '#!/bin/sh\necho "boom: no database" >&2\nexit 3\n', { mode: 0o755 });
  await assert.rejects(serveApp({ bin, cwd: dir }), /exited early \(3\)[\s\S]*boom: no database/);
});

test('serveApp throws when the app never answers', async () => {
  const bin = join(dir, 'silent-server');
  // `exec`: the kill reaches the sleep itself, nothing is left running.
  writeFileSync(bin, '#!/bin/sh\nexec sleep 30\n', { mode: 0o755 });
  await assert.rejects(serveApp({ bin, cwd: dir, timeout: 400 }), /did not answer in 400 ms/);
});

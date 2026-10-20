// `thor dev` shows what is wrong with the code ON the page: a new
// app, `thor dev` on a free port, a real Chromium. A closure as a button's
// callback (THOR-S011: the button would do nothing) covers the page with the
// error, its file:line, the fix and the code's page; fixed, the page reloads
// clean by itself. A warning is a small dismissible badge. The dev-only
// overlay is 0 bytes in `thor build` and in a page with nothing to show.
//
//   tool/thor e2e dev-overlay          (no app to build: it makes its own)
//   node test/e2e/checks/dev_overlay_check.mjs
import { spawn, spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync, mkdirSync } from 'node:fs';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { e2e, repo, settle } from './lib/e2e.mjs';

const cli = join(repo, 'packages/thor_cli/bin/thor.dart');
const work = mkdtempSync(join(tmpdir(), 'thor_dev_overlay_'));
const app = join(work, 'shop');
const shots = process.env.E2E_SHOTS ?? work;
const children = new Set();

// Nothing is left running or on disk, whatever the way out.
function cleanup() {
  for (const c of children) c.kill('SIGTERM');
  if (!process.env.E2E_KEEP) {
    try {
      rmSync(work, { recursive: true, force: true });
    } catch {}
  }
}
process.on('exit', cleanup);

const freePort = () =>
  new Promise((ok, ko) => {
    const s = createServer().once('error', ko);
    s.listen(0, '127.0.0.1', () => {
      const { port } = s.address();
      s.close(() => ok(port));
    });
  });

function run(args, cwd, label) {
  const r = spawnSync('dart', args, { cwd, encoding: 'utf8' });
  if (r.status !== 0) throw new Error(`${label} failed:\n${r.stdout}${r.stderr}`);
  return r.stdout;
}

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    statSync(p).isDirectory() ? walk(p, out) : out.push(p);
  }
  return out;
}

const file = (rel) => join(app, rel);
const read = (rel) => readFileSync(file(rel), 'utf8');
const write = (rel, text) => writeFileSync(file(rel), text);
const CARD = 'lib/modules/home/widgets/counter_card.dart';
const CLOSURE = 'onPressed: () {\n                  counter.increment();\n                },';
const OK = 'onPressed: counter.increment,';

// What the overlay shows, read from its shadow root (it is `open`).
// A reload in the middle (the page navigates) is tried again.
const overlay = async (page) => {
  for (let i = 0; ; i++) {
    try {
      return await snapshot(page);
    } catch (e) {
      if (i >= 20 || !/navigat|context was destroyed/i.test(String(e?.message))) throw e;
      await new Promise((r) => setTimeout(r, 100));
    }
  }
};
const snapshot = (page) =>
  page.evaluate(() => {
    const host = document.querySelector('thor-dev-overlay');
    if (!host) return null;
    const r = host.shadowRoot;
    const box = r.querySelector('.box');
    return {
      modal: !!box,
      badge: r.querySelector('.badge')?.innerText ?? null,
      badgeWarn: !!r.querySelector('.badge.w'),
      text: (box ?? r).textContent,
      html: (box ?? r).innerHTML,
      pill: r.querySelector('.pill')?.textContent ?? null,
      docHref: r.querySelector('h2 a')?.getAttribute('href') ?? null,
      editorHref: r.querySelector('.loc a')?.getAttribute('href') ?? null,
      fix: r.querySelector('.fix')?.textContent ?? null,
      fixCode: r.querySelector('.fix code')?.textContent ?? null,
      hit: r.querySelector('.code .hit')?.textContent ?? null,
      injected: !!r.querySelector('.msg b, .msg img, img'),
      overflowX: box ? box.scrollWidth > box.clientWidth + 1 : false,
      msgOverflow: box && r.querySelector('.msg') ? r.querySelector('.msg').scrollWidth > box.clientWidth : false,
    };
  });

const has = (page, pred) => settle(page, pred, undefined, { timeout: 30_000, interval: 100 });

await e2e('dev-overlay', { site: null, timeout: 420_000 }, async (t) => {
  // A new app that resolves thor from this checkout.
  run(['run', cli, 'create', app, '--no-pub'], repo, 'thor create');
  run(['pub', 'get', '--offline'], app, 'pub get');

  const port = await freePort();
  const dev = spawn('dart', ['run', cli, 'dev', '--port', String(port)], {
    cwd: app,
    env: { ...process.env, THOR_EDITOR: 'cursor' },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  children.add(dev);
  let log = '';
  dev.stdout.on('data', (d) => (log += d));
  dev.stderr.on('data', (d) => (log += d));
  const up = Date.now() + 240_000;
  while (!log.includes(`http://localhost:${port}`)) {
    if (Date.now() > up || dev.exitCode !== null) throw new Error(`thor dev did not start:\n${log}`);
    await new Promise((r) => setTimeout(r, 200));
  }
  const url = `http://localhost:${port}/`;

  const page = await t.page({ viewport: { width: 1100, height: 800 } });
  await page.goto(url);

  // 0 diagnostics: nothing of the overlay in the page, and the button works.
  t.check('0 diagnostics: no overlay script', (await page.locator('#thor-dev-overlay').count()) === 0);
  t.check('0 diagnostics: no overlay host', (await overlay(page)) === null);
  const plain = await (await fetch(url)).text();
  t.check('0 diagnostics: the page carries no diagnostics', !plain.includes('__thorDevErrors'));

  let docs = 0;
  page.on('request', (r) => r.resourceType() === 'document' && docs++);
  // 1. A closure as a callback: the overlay appears by itself (live reload).
  write(CARD, read(CARD).replace(OK, CLOSURE));
  await has(page, () => !!document.querySelector('thor-dev-overlay'));
  let o = await overlay(page);
  t.check('error: the overlay covers the page', o?.modal === true, `${JSON.stringify(o)?.slice(0, 200)} PROBLEMS ${page.problems.join(' | ')}`);
  t.check('error: says error', o?.pill === 'error');
  t.check('error: THOR-S011 links to its page', /\/errores\/THOR-S011$/.test(o?.docHref ?? ''), o?.docHref);
  t.check('error: file:line:col in the text', /counter_card\.dart:29:28/.test(o?.text ?? ''));
  t.check('error: click-to-open in THOR_EDITOR (cursor)', /^cursor:\/\/file\/.+counter_card\.dart:29:28$/.test(o?.editorHref ?? ''), o?.editorHref);
  t.check('error: the fix is written, with the code as code', o?.fix?.includes('counter.increment') && o?.fixCode === 'counter.increment', o?.fix);
  t.check('error: the line is marked in the excerpt', /onPressed: \(\) \{/.test(o?.hit ?? ''), o?.hit);
  t.check('error: the stack section is not there (nothing to show)', !/stack \(/.test(o?.text ?? ''));
  await page.screenshot({ path: join(shots, 'overlay-error.png') });

  // Esc closes it, and a badge is left to open it again.
  await page.keyboard.press('Escape');
  o = await overlay(page);
  t.check('esc: the dialog is gone and an error badge stays', o?.modal === false && /1 error/.test(o?.badge ?? ''), o?.badge);
  await page.locator('thor-dev-overlay .open').click();
  t.check('badge: opens the dialog again', (await overlay(page))?.modal === true);

  // 2. A second error, in the layout every page shares, and the 404 page.
  // The footer of the template (`const` or not): a missing anchor fails here,
  // not as a silent no-op that leaves one error instead of two.
  const shell = read('lib/shell/app_shell.dart');
  const footer = /^( *)((?:const )?Semantics\(\n *role: SemanticsRole\.contentInfo,)/m;
  if (!footer.test(shell)) throw new Error(`app_shell.dart: no contentInfo footer to put the button before:\n${shell}`);
  write(
    'lib/shell/app_shell.dart',
    "import 'package:shop/modules/home/state/counter_view_model.dart';\n" +
      shell.replace(
        footer,
        (_, pad, rest) => `${pad}TextButton(\n${pad}  onPressed: () { counter.reset(); },\n${pad}  child: const Text('reset'),\n${pad}),\n${pad}${rest}`,
      ),
  );
  t.check(
    'two errors in two files: both entries',
    (await has(page, () => document.querySelector('thor-dev-overlay')?.shadowRoot.querySelectorAll('h2').length === 2)) === true,
  );
  const missing = await page.context().newPage();
  await missing.goto(`${url}no-such-page`);
  await has(missing, () => !!document.querySelector('thor-dev-overlay'));
  const m = await overlay(missing);
  t.check('layout error: the 404 page shows both too', /app_shell\.dart/.test(m?.text ?? '') && /counter_card\.dart/.test(m?.text ?? ''));
  await missing.close();

  // 3. Fixed one at a time; no manual reload; the page is alive.
  write('lib/shell/app_shell.dart', read('lib/shell/app_shell.dart').replace('onPressed: () { counter.reset(); },', 'onPressed: counter.reset,'));
  t.check(
    'fix one: only the other is left',
    (await has(page, () => document.querySelector('thor-dev-overlay')?.shadowRoot.querySelectorAll('h2').length === 1)) === true,
  );
  // A restart of the server keeps showing the error (the proxy holds it).
  write('bin/server.dart', `${read('bin/server.dart')}\n// restart\n`);
  await new Promise((r) => setTimeout(r, 1500));
  await has(page, () => !!document.querySelector('thor-dev-overlay'));
  o = await overlay(page);
  t.check('server restarted: the error is still on the page', !!o && /counter_card\.dart/.test(o.text));
  write(CARD, read(CARD).replace(CLOSURE, OK));
  t.check('fixed: the overlay goes without touching the page', (await has(page, () => !document.querySelector('thor-dev-overlay'))) === true);
  await has(page, () => document.body.innerText.includes('Add'));
  await page.locator('button', { hasText: 'Add' }).click();
  t.check(
    'fixed: the button works',
    (await settle(page, () => /\b1\b/.test(document.body.innerText), undefined, { timeout: 10_000 })) === true,
  );

  // 4. A warning of another tool: a badge, dismissible, remembered per tab.
  mkdirSync(file('.dart_tool/thor'), { recursive: true });
  const warn = (text) =>
    write('.dart_tool/thor/diagnostics.txt', `lib/modules/home/pages/home_page.dart:12:1: Warning: ${text} (THOR-S013 · https://thor-docs.vercel.app/errores/THOR-S013) Use \`Watch\` here.\n`);
  const touch = () => write('lib/modules/home/pages/home_page.dart', `${read('lib/modules/home/pages/home_page.dart')}\n// touch\n`);
  warn('careful');
  touch();
  await has(page, () => !!document.querySelector('thor-dev-overlay'));
  o = await overlay(page);
  t.check('warning: a small badge, no dialog', o?.modal === false && /1 warning/.test(o?.badge ?? '') && o?.badgeWarn, JSON.stringify(o)?.slice(0, 200));
  t.check('warning: the page under it is usable', (await page.locator('button', { hasText: 'Add' }).count()) === 1);
  await page.screenshot({ path: join(shots, 'overlay-warning-badge.png') });
  await page.locator('thor-dev-overlay .open').click();
  o = await overlay(page);
  t.check('warning: the badge opens its details', o?.modal === true && o?.pill === 'warning' && /careful/.test(o.text));
  await page.keyboard.press('Escape');
  await page.locator('thor-dev-overlay .x').click();
  t.check('warning: dismissed', (await overlay(page)) === null);
  touch();
  await new Promise((r) => setTimeout(r, 2500));
  t.check('warning: stays dismissed across a reload', (await overlay(page)) === null);
  warn('another one');
  touch();
  t.check('warning: a different one comes back', (await has(page, () => !!document.querySelector('thor-dev-overlay'))) === true);

  // 5. Hostile text: HTML is text, a very long word does not break the box.
  const long = 'x'.repeat(4000);
  warn(`<img src=x onerror=window.__pwned=1><b>bold</b> ${long}`);
  touch();
  await has(page, () => /bold/.test(document.querySelector('thor-dev-overlay')?.shadowRoot.textContent ?? ''));
  await page.locator('thor-dev-overlay .open').click();
  o = await overlay(page);
  t.check('hostile: markup shows as text', /<img src=x/.test(o?.text ?? '') && o?.injected === false);
  t.check('hostile: nothing ran', (await page.evaluate(() => window.__pwned)) === undefined);
  t.check('hostile: a 4000 chars word stays inside the box', o?.overflowX === false && o?.msgOverflow === false);
  await page.screenshot({ path: join(shots, 'overlay-hostile.png') });

  // 6. Cleared: the file goes, the page is clean again.
  rmSync(file('.dart_tool/thor/diagnostics.txt'));
  touch();
  t.check('cleared: nothing left on the page', (await has(page, () => !document.querySelector('thor-dev-overlay'))) === true);
  t.check('no page errors of its own', page.problems.filter((p) => !/EventSource|favicon/.test(p)).length === 0, page.problems.join(' | '));

  // Dev cost: the script only exists while there is something to show.
  write(CARD, read(CARD).replace(OK, CLOSURE));
  let withError = '';
  for (let i = 0; i < 100 && !withError.includes('__thorDevErrors'); i++) {
    await new Promise((r) => setTimeout(r, 150));
    withError = await (await fetch(url)).text();
  }
  const cleanHtml = (await (await fetch(`${url}nope`)).text()).length;
  const scriptBytes = Buffer.byteLength(withError.match(/<script id="thor-dev-overlay">[\s\S]*?<\/script>/)?.[0] ?? '');
  console.log(`  dev: overlay script ${scriptBytes} bytes in a page with an error; 0 with nothing to show (${cleanHtml} bytes 404 page)`);
  t.check('dev: the script is there only with an error', scriptBytes > 0);
  write(CARD, read(CARD).replace(CLOSURE, OK));
  await has(page, () => !document.querySelector('thor-dev-overlay'));

  // 7. Production: `thor build` has none of it, and neither has its page.
  dev.kill('SIGTERM');
  await new Promise((r) => dev.once('exit', r));
  children.delete(dev);
  run(['run', cli, 'build'], app, 'thor build');
  const built = walk(file('build'));
  const markers = /thor-dev-overlay|__thorDevErrors|thor-live-reload|thor-inspect/;
  const hits = built.filter((f) => markers.test(readFileSync(f, 'latin1')));
  t.check('build: 0 bytes of the overlay in build/', hits.length === 0, hits.join(', '));
  const prodPort = await freePort();
  const prod = spawn(file('build/server'), [], { cwd: app, env: { ...process.env, PORT: String(prodPort) }, stdio: 'ignore' });
  children.add(prod);
  let prodHtml = '';
  for (let i = 0; i < 100 && !prodHtml; i++) {
    await new Promise((r) => setTimeout(r, 200));
    prodHtml = await fetch(`http://127.0.0.1:${prodPort}/`).then((r) => r.text(), () => '');
  }
  t.check('build: the served page is a page and has none of it', prodHtml.includes('Hello, Thor') && !markers.test(prodHtml));
  console.log(`  prod: 0 overlay bytes (${built.length} files in build/ checked)`);
  console.log(`  screenshots: ${shots}`);
});

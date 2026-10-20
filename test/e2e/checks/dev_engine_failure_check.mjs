// A lite engine that does not build in `thor dev` is loud ON the page: the app
// is served without its engine (every button does nothing), so the overlay
// covers it with the THOR code (THOR-B012), the file:line and the fact that
// interactivity is off, the browser console gets a console.error, the
// terminal a banner, and a good build clears it all. Broken from the very
// first start, fixed, broken again (an outdated engine is still served),
// back to the old text, two states failing, with a warning already shown;
// and `thor build` still fails hard. Makes its own app.
//
//   tool/thor e2e dev-engine-failure
//   node test/e2e/checks/dev_engine_failure_check.mjs
import { spawn, spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync, mkdirSync } from 'node:fs';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { e2e, repo, settle } from './lib/e2e.mjs';

const cli = join(repo, 'packages/thor_cli/bin/thor.dart');
const work = mkdtempSync(join(tmpdir(), 'thor_dev_engine_fail_'));
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


const STATE = 'lib/modules/home/state/counter_view_model.dart';
const OTHER = 'lib/modules/home/state/other_state.dart';
const BAD = (good) =>
  "import 'dart:async';\n" + good.replace('void increment() => count.value++;', 'void increment() { Timer.run(() {}); count.value++; }');

await e2e('dev-engine-failure', { site: null, timeout: 600_000 }, async (t) => {
  run(['run', cli, 'create', app, '--no-pub'], repo, 'thor create');
  run(['pub', 'get', '--offline'], app, 'pub get');
  const good = read(STATE);
  const broken = BAD(good);

  // 1. Broken BEFORE the first start: no engine was ever built.
  write(STATE, broken);
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

  t.check('terminal: a banner line names the code', /ENGINE BUILD FAILED · THOR-B012/.test(log), log.slice(0, 400));
  await has(page, () => !!document.querySelector('thor-dev-overlay'));
  let o = await overlay(page);
  t.check('first start: the overlay covers the page', o?.modal === true, JSON.stringify(o)?.slice(0, 200));
  t.check('first start: an error', o?.pill === 'error');
  t.check('first start: THOR-B012 links to its page', /\/errores\/THOR-B012$/.test(o?.docHref ?? ''), o?.docHref);
  t.check('first start: file:line', /counter_view_model\.dart:14/.test(o?.text ?? ''), o?.text?.slice(0, 300));
  t.check('first start: says the page has no engine', /WITHOUT its engine/.test(o?.text ?? '') && /interactivity disabled/.test(o?.text ?? ''));
  t.check('first start: the message names the construct', /Timer.run/.test(o?.text ?? ''));
  t.check('first start: console.error for headless tools', page.problems.some((p) => /THOR-B012/.test(p)), page.problems.join(' | '));
  // The picture is for a person, not a check: under load Chromium can refuse
  // a capture ("Unable to capture screenshot"), so retry once and go on.
  for (let i = 0; i < 2; i++) {
    try {
      await page.screenshot({ path: join(shots, 'engine-failure.png') });
      break;
    } catch (e) {
      if (i === 1) console.log(`  screenshot skipped: ${e.message.split('\n')[0]}`);
    }
  }

  // 2. Fixed: the overlay goes by itself and the button works.
  write(STATE, good);
  t.check('fixed: the overlay goes', (await has(page, () => !document.querySelector('thor-dev-overlay'))) === true);
  await has(page, () => document.body.innerText.includes('Add'));
  await page.locator('button', { hasText: 'Add' }).click();
  t.check('fixed: the button works (the engine is there)', (await settle(page, () => /\b1\b/.test(document.body.innerText), undefined, { timeout: 15_000 })) === true);
  t.check('terminal: says the engine built again', /the engine built/.test(log));

  // 3. Broken again, after a good build: an outdated engine is served.
  write(STATE, broken);
  await has(page, () => /OUTDATED/.test(document.querySelector('thor-dev-overlay')?.shadowRoot.textContent ?? ''));
  o = await overlay(page);
  t.check('broken again: says the engine is outdated', /OUTDATED/.test(o?.text ?? '') && o?.pill === 'error', o?.text?.slice(0, 200));

  // 4. Back to the exact text of the last good build: nothing to rebuild, and
  // the error must still go.
  write(STATE, good);
  t.check('back to the good text: the overlay goes', (await has(page, () => !document.querySelector('thor-dev-overlay'))) === true);

  // 5. Two states failing: two entries.
  write(STATE, broken);
  write(
    OTHER,
    "import 'dart:async';\nimport 'package:thor_ui/thor_ui.dart';\n\nclass OtherState extends ThorState {\n  final n = state(0);\n  void go() { Timer.run(() {}); }\n}\n\nfinal other = OtherState();\n",
  );
  t.check(
    'two states failing: two entries',
    (await has(page, () => document.querySelector('thor-dev-overlay')?.shadowRoot.querySelectorAll('h2').length === 2)) === true,
  );

  // 6. A warning is already shown when another state fails: both are there.
  rmSync(file(OTHER));
  write(STATE, good);
  await has(page, () => !document.querySelector('thor-dev-overlay'));
  mkdirSync(file('.dart_tool/thor'), { recursive: true });
  write('.dart_tool/thor/diagnostics.txt', 'lib/modules/home/pages/home_page.dart:12:1: Warning: careful (THOR-S013 · https://thor-docs.vercel.app/errores/THOR-S013) Use `Watch` here.\n');
  write('lib/modules/home/pages/home_page.dart', `${read('lib/modules/home/pages/home_page.dart')}\n// touch\n`);
  await has(page, () => /1 warning/.test(document.querySelector('thor-dev-overlay')?.shadowRoot.textContent ?? ''));
  write(STATE, broken);
  await has(page, () => /1 error/.test(document.querySelector('thor-dev-overlay')?.shadowRoot.textContent ?? '') || !!document.querySelector('thor-dev-overlay')?.shadowRoot.querySelector('.box'));
  await page.locator('thor-dev-overlay .open').click().catch(() => {});
  o = await overlay(page);
  t.check('warning shown first: the engine error comes with it', o?.modal === true && /THOR-B012/.test(o.html ?? '') && /careful/.test(o.text ?? ''), o?.text?.slice(0, 200));
  write(STATE, good);
  await has(page, () => !document.querySelector('thor-dev-overlay')?.shadowRoot.querySelector('.box'));
  o = await overlay(page);
  t.check('engine fixed: the warning stays', !!o && o.modal === false && /1 warning/.test(o.badge ?? ''), o?.text?.slice(0, 200));

  // 7. An unrelated save does not clear the error (the state is still broken),
  // and a second tab opened meanwhile sees it too.
  const HOME = 'lib/modules/home/pages/home_page.dart';
  // The warning of step 6 is over.
  rmSync(file('.dart_tool/thor/diagnostics.txt'), { force: true });
  write(HOME, `${read(HOME)}\n// diagnostics gone\n`);
  await has(page, () => !document.querySelector('thor-dev-overlay'));
  write(STATE, broken);
  await has(page, () => !!document.querySelector('thor-dev-overlay')?.shadowRoot.querySelector('.box'));
  write(HOME, `${read(HOME)}\n// unrelated\n`);
  await new Promise((r) => setTimeout(r, 4_000));
  o = await overlay(page);
  t.check('unrelated save: the engine error stays', o?.modal === true && /THOR-B012/.test(o.html ?? ''), o?.text?.slice(0, 200));
  const page2 = await t.page({ viewport: { width: 900, height: 700 } });
  await page2.goto(url);
  await has(page2, () => !!document.querySelector('thor-dev-overlay'));
  t.check('second tab: sees the error', /THOR-B012/.test((await overlay(page2))?.html ?? ''));
  t.check('second tab: console.error', page2.problems.some((p) => /THOR-B012/.test(p)), page2.problems.join(' | '));
  write(STATE, good);
  t.check('fixed: both tabs clear', (await has(page, () => !document.querySelector('thor-dev-overlay'))) === true && (await has(page2, () => !document.querySelector('thor-dev-overlay'))) === true);
  await page2.close();

  // 8. Broken -> fixed -> broken -> fixed inside a debounce: it ends fixed; and
  // broken -> fixed -> broken ends broken (never a stale answer).
  write(STATE, broken);
  write(STATE, good);
  write(STATE, broken);
  write(STATE, good);
  await new Promise((r) => setTimeout(r, 6_000));
  o = await overlay(page);
  t.check('rapid saves ending good: no overlay', o === null, o?.text?.slice(0, 200));
  write(STATE, broken);
  write(STATE, good);
  write(STATE, broken);
  await has(page, () => /THOR-B012/.test(document.querySelector('thor-dev-overlay')?.shadowRoot.textContent ?? ''));
  await new Promise((r) => setTimeout(r, 4_000));
  o = await overlay(page);
  t.check('rapid saves ending broken: the error is shown and stays', o?.modal === true && /THOR-B012/.test(o.html ?? ''), o?.text?.slice(0, 200));
  write(STATE, good);
  await has(page, () => !document.querySelector('thor-dev-overlay'));

  // 9. A missing import (not a subset violation): it fails, and creating
  // the file fixes it with no edit of the state.
  write(STATE, `import 'missing_helper.dart';\n${good}`);
  await has(page, () => !!document.querySelector('thor-dev-overlay'));
  o = await overlay(page);
  t.check('missing import: the page says something is wrong', o?.modal === true && /engine|missing_helper/i.test(o.text ?? ''), o?.text?.slice(0, 300));
  write('lib/modules/home/state/missing_helper.dart', '// now it is here\n');
  t.check('missing import created: the overlay goes', (await has(page, () => !document.querySelector('thor-dev-overlay'))) === true);
  write(STATE, good);
  rmSync(file('lib/modules/home/state/missing_helper.dart'), { force: true });
  await has(page, () => !document.querySelector('thor-dev-overlay'));

  // 10. A syntax error in the state file: loud, not silent.
  write(STATE, `${good}\nclass {{{ \n`);
  await has(page, () => !!document.querySelector('thor-dev-overlay'));
  o = await overlay(page);
  t.check('syntax error: the overlay is there', o?.modal === true, o?.text?.slice(0, 200));
  write(STATE, good);
  t.check('syntax error fixed: the overlay goes', (await has(page, () => !document.querySelector('thor-dev-overlay'))) === true);

  // 11. Production: `thor build` still fails hard.
  dev.kill('SIGTERM');
  await new Promise((r) => dev.once('exit', r));
  children.delete(dev);
  rmSync(file('.dart_tool/thor/diagnostics.txt'), { force: true });
  write(STATE, broken);
  const build = spawnSync('dart', ['run', cli, 'build'], { cwd: app, encoding: 'utf8' });
  t.check('build: exits non-zero with the engine broken', build.status !== 0, `status ${build.status}`);
  t.check('build: the output names THOR-B012 and the file', /THOR-B012/.test(build.stdout + build.stderr) && /counter_view_model\.dart:14/.test(build.stdout + build.stderr));
  console.log(`  screenshots: ${shots}`);
});

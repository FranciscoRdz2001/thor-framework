// Visual and accessibility checks of real pages (tool/thor visual, tool/thor a11y).
//
//   node test/e2e/checks/visual_check.mjs record   screenshots → build/visual/refs
//   node test/e2e/checks/visual_check.mjs check    screenshots vs refs → report
//   node test/e2e/checks/visual_check.mjs a11y     axe-core on the same pages
//
// The apps must be built first (tool/thor visual|a11y builds them):
// landing (static), docs (export), realworld, grid and recipes (servers).
//
// - Pages × widths 390/800/1440 × light/dark × browsers (Chromium, WebKit,
//   and Firefox where Playwright has it installed; VISUAL_BROWSERS limits).
// - Deterministic frames: reduced motion, animations and transitions off,
//   no caret, fixed clock, lazy images loaded, fonts ready, 1× pixels,
//   UTC; a page is cut at 3 000 px so a long guide stays a small file.
// - Refs are the same machine's own screenshots (font rendering differs
//   between systems): CI keeps the last master run's set as a cache; a
//   developer records before a change (`tool/thor visual record`, or
//   `tool/thor visual check --base master`). Nothing is committed.
// - Compare: pixelmatch (anti-aliasing ignored); a page fails when more
//   than VISUAL_MAX_PIXELS pixels changed (default 0: the frames are
//   exact run to run on one machine, and a text color change touches only
//   a hundred pixels of a guide) or its size changed.
//   build/visual/report.html shows ref, current and diff.
// - a11y: axe-core, serious and critical violations fail unless listed in
//   test/e2e/checks/a11y_known.json with the reason recorded next
//   to them; a listed rule that no longer fires fails too (fail closed).
// - VISUAL_ALLOW=1 (a PR labelled `visual-change`): diffs are reported,
//   exit 0. Every browser and server is closed in every case.
import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:net';
import { dirname, join, relative } from 'node:path';
import pixelmatch from '../runner/node_modules/pixelmatch/index.js';
import { PNG } from '../runner/node_modules/pngjs/lib/png.js';
import { chromium, firefox, webkit } from '../runner/node_modules/playwright/index.mjs';
import { appDir } from '../../../tool/app_dir.mjs';
import { closeServer, repo, serveStatic } from './lib/e2e.mjs';

const mode = process.argv[2];
if (!['record', 'check', 'a11y'].includes(mode)) {
  console.error('usage: visual_check.mjs record|check|a11y');
  process.exit(2);
}

const OUT = process.env.VISUAL_OUT ?? join(repo, 'build/visual');
// Where the built apps live: another checkout for `--base` (its builds,
// this script and mock API).
const APPS = process.env.VISUAL_APPS_ROOT ?? repo;
const REFS = process.env.VISUAL_REFS ?? join(OUT, 'refs');
const WIDTHS = [390, 800, 1440];
const SCHEMES = ['light', 'dark'];
const MAX_HEIGHT = 3000;
const MAX_PIXELS = Number(process.env.VISUAL_MAX_PIXELS ?? '0');
const ALLOW = process.env.VISUAL_ALLOW === '1';
const FIXED_TIME = new Date('2026-01-15T12:00:00Z');

/** The pages: id → [site, path] (VISUAL_PAGES=id,id limits them). */
const ALL_PAGES = [
  ['landing', 'landing', '/'],
  ['docs-home', 'docs', '/es'],
  ['docs-guide', 'docs', '/es/interfaz/tema-y-estilos'],
  ['realworld-home', 'realworld', '/'],
  ['realworld-article', 'realworld', '/article/server-rendering-without-the-hydration-tax'],
  ['realworld-login', 'realworld', '/login'],
  ['grid', 'grid', '/'],
  ['recipes-card', 'recipes', '/card'],
  ['recipes-dashboard', 'recipes', '/panel'],
];
const PAGES = process.env.VISUAL_PAGES
  ? ALL_PAGES.filter(([id]) => process.env.VISUAL_PAGES.split(',').includes(id))
  : ALL_PAGES;

// --- servers -----------------------------------------------------------------
const children = [];
const statics = [];
const kill = () => {
  for (const c of children) if (c.exitCode === null) c.kill('SIGKILL');
};
process.on('exit', kill);
for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => {
    kill();
    process.exit(sig === 'SIGINT' ? 130 : 143);
  });
}

const freePort = () =>
  new Promise((ok) => {
    const s = createServer().listen(0, '127.0.0.1', () => {
      const { port } = s.address();
      s.close(() => ok(port));
    });
  });

async function waitFor(url, timeout = 30_000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    try {
      if ((await fetch(url)).status < 500) return;
    } catch {}
    await new Promise((r) => setTimeout(r, 100));
  }
  throw new Error(`nothing answered at ${url}`);
}

function need(path) {
  if (!existsSync(join(APPS, path))) {
    throw new Error(`${path} is missing: build the apps first (tool/thor ${mode === 'a11y' ? 'a11y' : 'visual'} builds them)`);
  }
}

async function startSites() {
  const bases = {};
  for (const [name, dir] of [['landing', `${appDir('landing', APPS)}/build/site`], ['docs', 'apps/docs/build/site']]) {
    need(dir);
    const server = await serveStatic(join(APPS, dir));
    statics.push(server);
    bases[name] = `http://127.0.0.1:${server.address().port}`;
  }
  for (const app of ['realworld', 'grid', 'recipes']) need(`${appDir(app, APPS)}/build/server`);
  const mock = await freePort();
  children.push(
    spawn('node', [join(repo, 'test/e2e/mock_api/server.mjs'), '--port', `${mock}`], { stdio: 'ignore' }),
  );
  await waitFor(`http://127.0.0.1:${mock}/api/tags`);
  for (const app of ['realworld', 'grid', 'recipes']) {
    const port = await freePort();
    children.push(
      spawn(join(APPS, `${appDir(app, APPS)}/build/server`), [], {
        cwd: join(APPS, appDir(app, APPS)),
        env: {
          ...process.env,
          PORT: `${port}`,
          ISOLATES: '1',
          REALWORLD_API: `http://localhost:${mock}/api`,
          SESSION_SECRET: 'visual-check-secret-of-at-least-32-bytes',
        },
        stdio: 'ignore',
      }),
    );
    bases[app] = `http://127.0.0.1:${port}`;
    await waitFor(`${bases[app]}/`);
  }
  return bases;
}

// --- browsers ----------------------------------------------------------------
function browsers() {
  const all = { chromium, webkit, firefox };
  const wanted = (process.env.VISUAL_BROWSERS ?? 'chromium,webkit,firefox').split(',');
  const out = [];
  for (const name of wanted) {
    const type = all[name.trim()];
    if (!type) throw new Error(`unknown browser ${name}`);
    let installed = false;
    try {
      installed = existsSync(type.executablePath());
    } catch {}
    if (installed) out.push([name.trim(), type]);
    else console.log(`skip ${name}: not installed (npx playwright install ${name})`);
  }
  if (out.length === 0) throw new Error('no browser installed');
  return out;
}

const FREEZE = `*,*::before,*::after{animation:none!important;transition:none!important;
caret-color:transparent!important;scroll-behavior:auto!important}`;

/** Loads `url` and waits until the frame no longer changes on its own. */
async function steady(page, url) {
  await page.goto(url, { waitUntil: 'load' });
  await page.waitForLoadState('networkidle', { timeout: 10_000 }).catch(() => {});
  await page.addStyleTag({ content: FREEZE });
  await page.evaluate(() => {
    for (const img of document.images) {
      if (img.loading === 'lazy') img.loading = 'eager';
    }
  });
  // The lazy images now load: wait for the network, then for every image
  // to be decoded (WebKit paints a scaled image in steps until then).
  await page.waitForLoadState('networkidle', { timeout: 10_000 }).catch(() => {});
  await page.evaluate(async () => {
    await Promise.all([...document.images].map((img) => img.decode().catch(() => {})));
    await document.fonts.ready;
    await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
  });
}

// --- screenshots -----------------------------------------------------------------
const shotName = (browser, id, width, scheme) => join(browser, `${id}-${width}-${scheme}.png`);

async function screenshots(bases, dir) {
  const taken = [];
  for (const [bname, type] of browsers()) {
    const browser = await type.launch();
    try {
      for (const width of WIDTHS) {
        for (const scheme of SCHEMES) {
          const context = await browser.newContext({
            viewport: { width, height: 900 },
            deviceScaleFactor: 1,
            colorScheme: scheme,
            reducedMotion: 'reduce',
            timezoneId: 'UTC',
            locale: 'es-ES',
          });
          await context.clock.setFixedTime(FIXED_TIME);
          const page = await context.newPage();
          for (const [id, site, path] of PAGES) {
            await steady(page, bases[site] + path);
            const height = Math.min(
              MAX_HEIGHT,
              await page.evaluate(() => document.documentElement.scrollHeight),
            );
            const file = join(dir, shotName(bname, id, width, scheme));
            mkdirSync(dirname(file), { recursive: true });
            await page.screenshot({ path: file, fullPage: true, clip: { x: 0, y: 0, width, height } });
            taken.push({ browser: bname, id, width, scheme, file: shotName(bname, id, width, scheme) });
          }
          await context.close();
        }
      }
    } finally {
      await browser.close();
    }
  }
  return taken;
}

function compare(taken) {
  const cur = join(OUT, 'current');
  const diffDir = join(OUT, 'diff');
  const rows = [];
  for (const shot of taken) {
    const refFile = join(REFS, shot.file);
    const row = { ...shot, status: 'same', ratio: 0 };
    if (!existsSync(refFile)) {
      row.status = 'new';
      rows.push(row);
      continue;
    }
    const a = PNG.sync.read(readFileSync(refFile));
    const b = PNG.sync.read(readFileSync(join(cur, shot.file)));
    if (a.width !== b.width || a.height !== b.height) {
      row.status = 'changed';
      row.note = `size ${a.width}×${a.height} → ${b.width}×${b.height}`;
      rows.push(row);
      continue;
    }
    const diff = new PNG({ width: a.width, height: a.height });
    const n = pixelmatch(a.data, b.data, diff.data, a.width, a.height, { threshold: 0.1 });
    row.ratio = n / (a.width * a.height);
    if (n > MAX_PIXELS) {
      row.status = 'changed';
      row.note = `${n} px (${(row.ratio * 100).toFixed(3)} %)`;
      const file = join(diffDir, shot.file);
      mkdirSync(dirname(file), { recursive: true });
      writeFileSync(file, PNG.sync.write(diff));
    }
    rows.push(row);
  }
  return rows;
}

function report(rows) {
  const rel = (p) => relative(OUT, p);
  const changed = rows.filter((r) => r.status !== 'same');
  const img = (p) => (existsSync(p) ? `<img src="${rel(p)}" loading="lazy">` : '<em>—</em>');
  const body = changed
    .map(
      (r) => `<section><h2>${r.browser} · ${r.id} · ${r.width} px · ${r.scheme} — ${r.status}${r.note ? ` (${r.note})` : ''}</h2>
<div class="row"><figure>${img(join(REFS, r.file))}<figcaption>ref</figcaption></figure>
<figure>${img(join(OUT, 'current', r.file))}<figcaption>current</figcaption></figure>
<figure>${img(join(OUT, 'diff', r.file))}<figcaption>diff</figcaption></figure></div></section>`,
    )
    .join('\n');
  writeFileSync(
    join(OUT, 'report.html'),
    `<!doctype html><meta charset="utf-8"><title>thor visual report</title>
<style>body{font:14px system-ui;margin:16px}.row{display:flex;gap:8px;overflow-x:auto}
figure{margin:0}img{max-width:420px;border:1px solid #ccc}h2{font-size:15px}</style>
<h1>${changed.length} of ${rows.length} screenshots differ</h1>
<p>Changed pixels allowed per screenshot: ${MAX_PIXELS}; refs: ${REFS}</p>${body}`,
  );
}

// --- accessibility -----------------------------------------------------------------
const AXE = join(repo, 'test/e2e/runner/node_modules/axe-core/axe.min.js');
const KNOWN_FILE = join(repo, 'test/e2e/checks/a11y_known.json');

async function audit(bases) {
  const known = JSON.parse(readFileSync(KNOWN_FILE, 'utf8'));
  const found = new Map(); // `${id} ${rule}` → { impact, help, nodes, where }
  const browser = await chromium.launch();
  try {
    for (const width of [390, 1440]) {
      for (const scheme of SCHEMES) {
        const context = await browser.newContext({ viewport: { width, height: 900 }, colorScheme: scheme, reducedMotion: 'reduce' });
        const page = await context.newPage();
        for (const [id, site, path] of PAGES) {
          await steady(page, bases[site] + path);
          await page.addScriptTag({ path: AXE });
          const violations = await page.evaluate(async () => {
            const r = await window.axe.run(document, { resultTypes: ['violations'] });
            return r.violations.map((v) => ({
              id: v.id,
              impact: v.impact,
              help: v.help,
              nodes: v.nodes.slice(0, 3).map((n) => n.target.join(' ')),
            }));
          });
          for (const v of violations) {
            if (!['serious', 'critical'].includes(v.impact)) continue;
            const key = `${id} ${v.id}`;
            const entry = found.get(key) ?? { ...v, page: id, where: [] };
            entry.where.push(`${width}/${scheme}`);
            found.set(key, entry);
          }
        }
        await context.close();
      }
    }
  } finally {
    await browser.close();
  }
  const fresh = [...found.values()].filter((v) => !known[v.page]?.[v.id]);
  const stale = Object.entries(known).flatMap(([page, rules]) =>
    Object.keys(rules)
      .filter((rule) => !found.has(`${page} ${rule}`))
      .map((rule) => `${page} ${rule}`),
  );
  mkdirSync(OUT, { recursive: true });
  writeFileSync(join(OUT, 'a11y.json'), JSON.stringify([...found.values()], null, 2));
  for (const v of found.values()) {
    const tag = known[v.page]?.[v.id] ? `known (${known[v.page][v.id]})` : 'NEW';
    console.log(`${tag.startsWith('known') ? '  ' : '✗ '}${v.page} ${v.id} [${v.impact}] ${v.help} — ${v.where.join(', ')} — ${v.nodes.join(' | ')} — ${tag}`);
  }
  for (const s of stale) console.log(`✗ ${s}: listed in a11y_known.json but no longer found; remove it`);
  const ok = fresh.length === 0 && stale.length === 0;
  console.log(ok ? `a11y: ${found.size} known, 0 new serious/critical` : `a11y: ${fresh.length} new, ${stale.length} stale`);
  return ok;
}

// --- main ------------------------------------------------------------------------
let code = 0;
try {
  const bases = await startSites();
  if (mode === 'a11y') {
    code = (await audit(bases)) ? 0 : 1;
  } else if (mode === 'record') {
    rmSync(REFS, { recursive: true, force: true });
    const taken = await screenshots(bases, REFS);
    console.log(`recorded ${taken.length} screenshots in ${relative(repo, REFS) || REFS}`);
  } else {
    if (!existsSync(REFS)) throw new Error(`no refs in ${REFS}: record them first (tool/thor visual record, or --base <ref>)`);
    rmSync(join(OUT, 'current'), { recursive: true, force: true });
    rmSync(join(OUT, 'diff'), { recursive: true, force: true });
    const taken = await screenshots(bases, join(OUT, 'current'));
    const rows = compare(taken);
    report(rows);
    const changed = rows.filter((r) => r.status === 'changed');
    const fresh = rows.filter((r) => r.status === 'new');
    for (const r of changed) console.log(`✗ ${r.file}: ${r.note}`);
    for (const r of fresh) console.log(`  ${r.file}: no ref (new page, browser or size)`);
    console.log(`visual: ${changed.length} changed, ${fresh.length} new, ${rows.length - changed.length - fresh.length} same — ${relative(repo, join(OUT, 'report.html'))}`);
    if (changed.length > 0 && !ALLOW) code = 1;
    if (changed.length > 0 && ALLOW) console.log('VISUAL_ALLOW=1: the changes are accepted (labelled PR)');
  }
} catch (e) {
  console.error(`visual: ${e.message}`);
  code = 1;
} finally {
  kill();
  await Promise.allSettled(statics.map(closeServer));
}
process.exit(code);

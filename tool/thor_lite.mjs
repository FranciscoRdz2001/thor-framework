// Makes a lite copy of an app's dart2js build, for the conformance check
// and the parity check: the same pages with the lite engine in
// place of the dart2js one.
//
//   tool/thor build counter                 # the normal build (kept as is; an exported app: tool/thor export lab)
//   node tool/thor_lite.mjs counter [...] [--defer]   # → test/fixtures/apps/counter/build/site-lite
//
// Copies build/site to build/site-lite and replaces the engine file the
// pages' loader points at (every page of an exported app, like test/fixtures/apps/lab;
// `engine.dart.<hash>.js`) with
// `engine.lite.<hash>.js`, the bundle `thor build` ships:
// thor_builder's lite_state (the app's states in JS; a construct outside
// the subset stops here with its file and line) and thor_engine's
// lite_bundle (runtime + the parts the pages need, minified). The HTML is
// the server's, byte for byte, except that file name.
//
// A server app (build/server + build/public) gets its bundle in build/lite:
// whoever serves the app answers the engine's URL with it (the
// conformance check does).
//
// `--defer` also writes build/site-lite-defer: the page as
// `ThorApp(engineLoading: EngineLoading.eager)` emits it (a plain
// `<script src defer>` instead of the ~0.7 KB inline idle loader).
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { cpSync, existsSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { brotliCompressSync, gzipSync, constants } from 'node:zlib';

import { appDir } from './app_dir.mjs';
const root = fileURLToPath(new URL('..', import.meta.url));
const kb = (n) => `${(n / 1024).toFixed(2)} KB`;
const run = (args, cwd) => {
  const r = spawnSync('dart', args, { cwd, stdio: 'inherit' });
  if (r.status !== 0) process.exit(r.status ?? 1);
};
const defer = process.argv.includes('--defer');
const apps = process.argv.slice(2).filter((a) => !a.startsWith('--'));
if (!apps.length) {
  console.error('usage: node tool/thor_lite.mjs <app> [...]');
  process.exit(64);
}
for (const app of apps) {
  const dir = join(root, appDir(app));
  const site = join(dir, 'build/site'), out = join(dir, 'build/site-lite');
  // A server app is the one with build/server (a stale `thor export` leaves a
  // build/site next to it).
  const server = existsSync(join(dir, 'build/server'));
  if (server ? !existsSync(join(dir, 'build/public')) : !existsSync(join(site, 'index.html'))) throw new Error(`${site}/index.html missing: tool/thor build ${app} (or build-server)`);
  const lite = join(dir, 'build/lite');
  rmSync(lite, { recursive: true, force: true });
  run(['run', 'thor_builder:lite_state', '.', 'build/lite/state.js'], dir);
  run(['run', 'thor_engine:lite_bundle', 'build/lite/state.js', '.', 'build/lite/engine.js', ...(server ? [] : ['build/site'])], dir);
  const js = readFileSync(join(lite, 'engine.js'));
  rmSync(join(lite, 'engine.js'));
  const name = `engine.lite.${createHash('sha256').update(js).digest('hex').slice(0, 8)}.js`;
  const sizes = ` ${kb(js.length)}, gz ${kb(gzipSync(js, { level: 9 }).length)}, br ${kb(brotliCompressSync(js, { params: { [constants.BROTLI_PARAM_QUALITY]: 11 } }).length)}`;
  if (server) {
    writeFileSync(join(lite, name), js);
    const dart = readFileSync(join(dir, 'build/public/engine.dart.js'));
    console.log(`${app}: ${name}${sizes} (dart2js engine.dart.js: ${kb(dart.length)}, gz ${kb(gzipSync(dart, { level: 9 }).length)}) → ${resolve(lite, name)}`);
    continue;
  }
  rmSync(out, { recursive: true, force: true });
  cpSync(site, out, { recursive: true });
  // Every page of the site (an exported app has several, all pointing at the one
  // dart2js engine) loads the lite bundle in its place.
  const pages = readdirSync(out).filter((f) => f.endsWith('.html') || f === '_headers');
  let engine;
  for (const file of pages) {
    const p = join(out, file);
    const text = readFileSync(p, 'utf8').replace(/engine\.dart\.[0-9a-f]{8}\.js/g, (m) => ((engine = m), name));
    writeFileSync(p, text);
  }
  if (!engine) throw new Error(`${app}: no engine.dart.<hash>.js in the page`);
  rmSync(join(out, engine));
  writeFileSync(join(out, name), js);
  if (defer) {
    const eager = join(dir, 'build/site-lite-defer');
    rmSync(eager, { recursive: true, force: true });
    cpSync(out, eager, { recursive: true });
    const loader = /<script data-thor-engine="([^"]+)">.*?<\/script>/s;
    let found = false;
    for (const file of pages.filter((f) => f.endsWith('.html'))) {
      const p = join(eager, file);
      const page = readFileSync(p, 'utf8');
      if (!loader.test(page)) continue;
      found = true;
      writeFileSync(p, page.replace(loader, (_, src) => `<script src="${src}" defer></script>`));
    }
    if (!found) throw new Error(`${app}: no engine loader in the page`);
  }
  const dart = readFileSync(join(site, engine));
  console.log(`${app}: ${name}${sizes} (dart2js ${engine}: ${kb(dart.length)}, gz ${kb(gzipSync(dart, { level: 9 }).length)}) → ${resolve(out)}`);
}

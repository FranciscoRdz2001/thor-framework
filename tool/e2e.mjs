// `tool/thor e2e`: the browser checks as a graph of tasks on a bounded pool
// (tool/pool.mjs). Each app is built once per engine and every check that
// serves it waits for that build; independent checks run side by side.
//
//   node tool/e2e.mjs [--jobs N] [--no-build] [--bail] [--verbose] [--list] [--no-harness] -- <entry>...
//
// An entry is `name:app[+app...]:script[:needs]` (E2E_CHECKS in tool/thor;
// needs: dart = the dart2js oracle engine (THOR_INTERNAL_ENGINE=dart, the
// internal comparison engine, never shipped), lite = the conformance's dart2js
// builds plus their lite copies, export = a static export, flutter). An app
// with `bin/export.dart` and no `bin/server.dart` (test/fixtures/apps/lab, many
// pages in one app) is always exported, with the engine its suite asks for.
//
// One app has one `build/` directory, so its two engines cannot be on disk
// at once: the build of the lite engine waits for every check that serves
// the dart2js one (and the conformance's lite copies), dart2js first.
// Ports are the checks' own (each one asks the OS for a free one).
import { existsSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { appDir } from './app_dir.mjs';
import { defaultJobs, repo, runPool } from './pool.mjs';

const argv = process.argv.slice(2);
const cut = argv.indexOf('--');
const args = cut < 0 ? argv : argv.slice(0, cut);
const entries = cut < 0 ? [] : argv.slice(cut + 1);
const flag = (n) => args.includes(n);
const jobsAt = args.indexOf('--jobs');
const jobs = jobsAt < 0 ? defaultJobs() : Number(args[jobsAt + 1]);
const build = !flag('--no-build');

// Estimated seconds of the slow ones, for the order (the pool starts the
// longest chains first): refreshed from the times table of a run.
const SUITE_WEIGHT = {
  lite: 135,
  'dev-overlay': 60,
  'animations-burst': 100,
  'early-keys-break': 30,
  'early-keys-break-dart': 30,
  forms: 25,
  hybrid: 100,
  'hybrid-dart': 100,
  navigation: 60,
  'navigation-dart': 60,
  transitions: 80,
  acts: 60,
  'lite-widgets-adversarial': 40,
  'lite-lifecycle-adversarial': 40,
  'controllers-break': 40,
  'engine-preload': 40,
};
const BUILD_WEIGHT = { realworld: 120, grid: 120, server_query: 120, intl_store: 120, docs: 90, lab: 60 };

// An app that is only ever exported: `thor export` writes its pages (bin/export.dart), it has no server.
const exportOnly = (app) => existsSync(join(repo, appDir(app), 'bin/export.dart')) && !existsSync(join(repo, appDir(app), 'bin/server.dart'));

let stage;
process.on('exit', () => stage && rmSync(stage, { recursive: true, force: true }));
const tasks = [];
const byName = new Map();
const add = (t) => {
  if (byName.has(t.name)) return byName.get(t.name);
  byName.set(t.name, t);
  tasks.push(t);
  return t;
};

// (The harness's own tests run once: not again for each browser of `--browsers`.)
if (!flag('--no-harness')) add({
  name: 'harness',
  // --test-timeout: a hung test (seen once under load, a stuck chromium launch) fails instead of blocking the run forever.
  cmd: 'node --test --test-timeout=240000 tool/pool_test.mjs test/e2e/checks/lib/e2e_test.mjs',
  weight: 40,
  tail: 2,
});

// Suites, with the (app, engine) each one serves.
const suites = [];
for (const entry of entries) {
  const [name, app, script, needs = ''] = entry.split(':');
  const flags = needs.split(',');
  const apps = app ? app.split('+') : [];
  const engine = flags.includes('dart') || flags.includes('lite') ? 'dart' : 'lite';
  suites.push({ name, apps, script, flags, engine });
}

// A build task per (engine, app); a static export of a server app is its own.
const buildOf = (kind, engine, app) => {
  const name = kind === 'export' ? (engine === 'lite' ? `export ${app}` : `export ${engine} ${app}`) : `build ${engine} ${app}`;
  return add({
    name,
    cmd: `THOR_INTERNAL_ENGINE=${engine} dart run thor_cli:thor ${kind === 'export' ? 'export' : 'build'} ${appDir(app)}`,
    weight: BUILD_WEIGHT[app] ?? 45,
    tail: 2,
    needs: [],
    consumers: [],
    kind,
    engine,
    app,
  });
};

for (const s of suites) {
  const needs = [];
  const consumes = [];
  if (build) {
    for (const app of s.apps) {
      const b = s.flags.includes('export') || exportOnly(app) ? buildOf('export', s.engine, app) : buildOf('build', s.engine, app);
      needs.push(b.name);
      consumes.push(b);
    }
    // transitions serves the docs export too (the script exports it when missing).
    if (s.name === 'transitions') {
      const b = buildOf('export', 'lite', 'docs');
      needs.push(b.name);
      consumes.push(b);
    }
  }
  let env;
  if (s.flags.includes('lite')) {
    // The conformance: lite copies of each dart2js build, one task per app.
    // A static app's dart2js and lite sites are also copied to `stage`, which
    // the conformance reads: the lite engine's build of the app need not wait
    // for it. A server app (bin/server.dart) is served from its own folder.
    stage ??= mkdtempSync(join(tmpdir(), 'thor-e2e-stage-'));
    env = { E2E_STAGE: stage };
    for (const app of s.apps) {
      const server = existsSync(join(repo, appDir(app), 'bin/server.dart'));
      const dartBuild = consumes.find((c) => c.app === app);
      const copy = add({
        name: `lite copy ${app}`,
        cmd:
          `node tool/thor_lite.mjs ${app}` +
          (server ? '' : ` && mkdir -p ${stage}/${app} && cp -R ${appDir(app)}/build/site ${appDir(app)}/build/site-lite ${stage}/${app}/`),
        weight: 40,
        tail: 2,
        needs: build ? [dartBuild.name] : [],
        consumers: [],
        app,
        staged: !server,
      });
      if (build) {
        dartBuild.consumers.push(copy);
      }
      needs.push(copy.name);
    }
  }
  const task = add({
    name: s.name,
    cmd: `node test/e2e/checks/${s.script}`,
    env,
    needs,
    weight: SUITE_WEIGHT[s.name] ?? 25,
    tail: 3,
  });
  for (const b of consumes) {
    // The conformance reads the staged copy of a static app: it does not hold the build.
    const staged = env && byName.get(`lite copy ${b.app}`)?.staged;
    if (!staged) b.consumers.push(task);
  }
}

// One directory per app: a lite build waits for the dart2js build's consumers.
if (build) {
  const builds = tasks.filter((t) => t.kind);
  for (const lite of builds.filter((t) => t.engine === 'lite')) {
    const dart = builds.find((t) => t.engine === 'dart' && t.app === lite.app);
    if (dart) lite.needs.push(...dart.consumers.map((c) => c.name));
  }
}

if (flag('--list')) {
  for (const t of tasks) console.log(`${t.name}${t.needs?.length ? `  <- ${t.needs.join(', ')}` : ''}`);
  process.exit(0);
}
const { ok } = await runPool(tasks, { jobs, verbose: flag('--verbose'), bail: flag('--bail'), title: 'e2e' });
if (ok) console.log('\n▸ All E2E checks passed');
process.exit(ok ? 0 : 1);

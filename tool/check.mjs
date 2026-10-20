// `tool/thor check` and `tool/thor test`: the gates and the test suites of
// the workspace as tasks of a bounded pool (tool/pool.mjs).
//
//   node tool/check.mjs check [options]     format, analyze, API, dart2js, every test
//   node tool/check.mjs test  [options]     every test (--browser adds the Chrome ones)
//
//   --jobs N          tasks at once (default: half the cores)
//   --changed [base]  only the packages and apps that changed against `base`
//                     (default origin/master, from the merge base; the working
//                     tree and untracked files count) and whatever depends on
//                     them; format and analyze always cover everything
//   --serial          --jobs 1: the times of each phase, one after another
//   --bail            stop at the first failure
//   --list            print the tasks and stop
//   --verbose         show the whole output of the passing tasks too
//
// The lists come from tool/thor (THOR_PACKAGES); the Chrome tests are found by their @TestOn('browser').
import { execFileSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { allAppDirs } from './app_dir.mjs';
import { defaultJobs, repo, runPool } from './pool.mjs';

const [mode = 'check', ...args] = process.argv.slice(2);
const flag = (name) => args.includes(name);
const opt = (name) => {
  const i = args.indexOf(name);
  return i < 0 ? undefined : args[i + 1];
};
const jobs = flag('--serial') ? 1 : Number(opt('--jobs') ?? defaultJobs());
const browser = mode === 'check' || flag('--browser');

const packages = (process.env.THOR_PACKAGES ?? '').split(/\s+/).filter(Boolean);
/** Every test file of the package that is annotated `@TestOn('browser')` before its first import. */
function browserTestsOf(pkg) {
  const found = [];
  const walk = (rel) => {
    for (const entry of readdirSync(join(repo, pkg, rel), { withFileTypes: true })) {
      const path = join(rel, entry.name);
      if (entry.isDirectory()) walk(path);
      else if (entry.name.endsWith('_test.dart')) {
        const head = readFileSync(join(repo, pkg, path), 'utf8').split('\n');
        const firstImport = head.findIndex((l) => /^(import|export|part) /.test(l));
        const annotated = head.slice(0, firstImport < 0 ? head.length : firstImport);
        if (annotated.some((l) => /^@TestOn\(['"]browser['"]\)/.test(l))) found.push({ pkg, file: path });
      }
    }
  };
  if (existsSync(join(repo, pkg, 'test'))) walk('test');
  return found;
}
// Scanned, not listed by hand: a new Chrome test runs in the gate without anyone remembering to add it.
const browserTests = packages.flatMap(browserTestsOf).sort((a, b) => (a.pkg + a.file).localeCompare(b.pkg + b.file));
const appsWithTests = allAppDirs().filter((d) => existsSync(join(repo, d, 'test')));

// --- the workspace graph -----------------------------------------------------
/** name → {dir, deps} of every package and app. */
function workspace() {
  const members = new Map();
  const dirs = [...packages, ...allAppDirs()];
  for (const dir of dirs) {
    const file = join(repo, dir, 'pubspec.yaml');
    if (!existsSync(file)) continue;
    const text = readFileSync(file, 'utf8');
    const name = text.match(/^name:\s*(\S+)/m)?.[1];
    const deps = new Set();
    let section = null;
    for (const line of text.split('\n')) {
      const top = line.match(/^([a-z_]+):/);
      if (top) section = ['dependencies', 'dev_dependencies', 'dependency_overrides'].includes(top[1]) ? top[1] : null;
      else if (section) {
        const dep = line.match(/^  ([a-z_0-9]+):/);
        if (dep) deps.add(dep[1]);
      }
    }
    members.set(name, { dir, deps });
  }
  return members;
}

/** The dirs (packages and apps) touched by the changes against [base] and their dependents. */
function affected(base) {
  const git = (...a) => execFileSync('git', a, { cwd: repo, encoding: 'utf8' }).trim();
  let ref = base;
  try {
    git('rev-parse', '--verify', '--quiet', `${ref}^{commit}`);
  } catch {
    ref = ['origin/master', 'master'].find((r) => {
      try {
        return git('rev-parse', '--verify', '--quiet', `${r}^{commit}`) !== '';
      } catch {
        return false;
      }
    });
    if (!ref) throw new Error(`no base to compare with: ${base}`);
  }
  const from = git('merge-base', 'HEAD', ref);
  const files = new Set([
    ...git('diff', '--name-only', from).split('\n'),
    ...git('ls-files', '--others', '--exclude-standard').split('\n'),
  ]);
  files.delete('');
  const members = workspace();
  const dirs = new Set();
  let everything = false;
  let tools = false;
  const why = [];
  for (const f of files) {
    if (['pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml'].includes(f)) everything = true;
    else if (f.startsWith('tool/') && !/^tool\/(pool|check|e2e)\.mjs$|^tool\/thor$|^tool\/golden\.sh$|deploy_docs/.test(f)) tools = true;
    else {
      const dir = [...members.values()].map((m) => m.dir).find((d) => f.startsWith(`${d}/`));
      if (dir) dirs.add(dir);
    }
  }
  if (everything) {
    why.push('a root pubspec or analysis_options changed: everything');
    return { everything: true, dirs: null, tools: true, files, why, ref: from };
  }
  // Dependents, transitively: a dependency's change reaches who imports it.
  const names = new Map([...members].map(([n, m]) => [m.dir, n]));
  const seen = new Set([...dirs].map((d) => names.get(d)));
  let grew = true;
  while (grew) {
    grew = false;
    for (const [n, m] of members) {
      if (!seen.has(n) && [...m.deps].some((d) => seen.has(d))) {
        seen.add(n);
        grew = true;
      }
    }
  }
  const out = new Set([...seen].map((n) => members.get(n).dir));
  for (const d of out) if (!dirs.has(d)) why.push(`${d} (depends on a changed package)`);
  for (const d of dirs) why.unshift(`${d} (changed)`);
  return { everything: false, dirs: out, tools, files, why, ref: from };
}

// --- the tasks -----------------------------------------------------------------
const tasks = [];
const add = (t) => tasks.push(t);
let scope = null;
if (flag('--changed')) {
  const next = args[args.indexOf('--changed') + 1];
  scope = affected(next && !next.startsWith('-') ? next : 'origin/master');
  console.log(`▸ Changed against ${scope.ref.slice(0, 8)}: ${scope.files.size} files`);
  if (scope.everything) console.log('  everything runs');
  else if (scope.dirs.size === 0 && !scope.tools) console.log('  no package or app changed: no tests to run');
  else for (const w of scope.why) console.log(`  ${w}`);
}
const wants = (dir) => scope === null || scope.everything || scope.dirs.has(dir);

if (mode === 'check') {
  add({ name: 'format', cmd: 'tool/thor format-check', weight: 10 });
  add({ name: 'analyze', cmd: 'tool/thor analyze', weight: 90 });
  add({ name: 'api', cmd: 'tool/thor api', weight: 20 });
  // The CSS escape hatches (`ignore: thor_lints/…`, `raw:`) never go up.
  add({ name: 'ratchet', cmd: 'tool/thor ratchet', weight: 5 });
  // The ```dart blocks of the guide compile against the packages as they are now.
  add({ name: 'docs-check', cmd: 'tool/thor docs-check', weight: 40 });
  // The counter app on the dart2js oracle engine: when it, the oracle or what it is made of changed.
  if (wants('test/fixtures/apps/counter') || wants('packages/thor_engine_oracle')) add({ name: 'dart2js', cmd: 'tool/thor dart2js', weight: 60 });
}
if (scope === null || scope.everything || scope.tools) {
  add({ name: 'test tool', cmd: 'dart test tool/test', weight: 20 });
}
// The packages whose VM tests are so many that one `dart test` would be the
// longest task of the run (thor_builder analyzes real sources in every test):
// their tests go in N shards (`dart test --total-shards`), each in its own process.
const SHARDS = { 'packages/thor_builder': 4, 'packages/thor_cli': 2 };
for (const dir of packages) {
  if (!wants(dir)) continue;
  const shards = jobs > 1 ? (SHARDS[dir] ?? 1) : 1;
  if (shards === 1) {
    add({ name: `test ${dir}`, cmd: 'dart test', cwd: dir, weight: 120 });
    continue;
  }
  for (let i = 0; i < shards; i++) {
    add({
      name: `test ${dir} [${i + 1}/${shards}]`,
      cmd: `dart test -j 2 --total-shards ${shards} --shard-index ${i}`,
      cwd: dir,
      weight: 150 / shards,
    });
  }
}
for (const dir of appsWithTests) {
  if (!wants(dir)) continue;
  // thor test: code generation, then dart test with the states registered.
  add({ name: `test ${dir}`, cmd: `dart run thor_cli:thor test --app ${dir}`, weight: 60 });
}
if (browser) {
  for (const { pkg, file } of browserTests) {
    if (!wants(pkg)) continue;
    add({ name: `chrome ${pkg}/${file}`, cmd: `dart test -p chrome ${file}`, cwd: pkg, weight: 60 });
  }
}
if (tasks.length === 0) {
  console.log('▸ Nothing to run');
  process.exit(0);
}
if (flag('--list')) {
  for (const t of tasks) console.log(t.name);
  process.exit(0);
}
const title = mode === 'check' ? 'check' : 'test';
const { ok } = await runPool(tasks, { jobs, verbose: flag('--verbose'), bail: flag('--bail'), title });
if (ok) console.log(`\n▸ All ${scope ? `${title} (changed only)` : 'checks'} passed`);
process.exit(ok ? 0 : 1);

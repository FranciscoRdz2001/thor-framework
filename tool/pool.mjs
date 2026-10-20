// A bounded worker pool for the repository's verification commands
// (tool/check.mjs, tool/e2e.mjs, tool/golden.sh).
//
// A task is a command with optional `needs` (names of tasks that must pass
// first: a build before the checks that serve it). At most `jobs` tasks run
// at once, the most expensive chains first. Each task's output is buffered
// and printed as one block when it ends (a passing task shows its last
// lines, a failing one everything), the whole output goes to
// `<logDir>/<task>.log`, and a summary with the time of each task and the
// failures comes last. Exit code 1 when any task failed.
//
//   node tool/pool.mjs [--jobs N] [--verbose] [--bail] [--title T] < tasks.tsv
//
// Each line of the TSV: name <TAB> needs (comma list, may be empty) <TAB>
// cwd (relative to the repo, may be empty) <TAB> shell command.
import { spawn } from 'node:child_process';
import { cpus } from 'node:os';
import { createWriteStream, mkdirSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const repo = fileURLToPath(new URL('..', import.meta.url));

/** Half the cores (at least 2): the builds and the browsers are heavy. */
export function defaultJobs() {
  return Math.max(2, Math.floor(cpus().length / 2));
}

const paint = (code, s) => (process.stdout.isTTY || process.env.FORCE_COLOR ? `\x1b[${code}m${s}\x1b[0m` : s);
const secs = (ms) => `${(ms / 1000).toFixed(1)}s`;
const safe = (name) => name.replace(/[^A-Za-z0-9._+-]+/g, '_');

/**
 * Runs `tasks` ({name, cmd (shell string or argv array), cwd, env, needs,
 * weight (estimated seconds, for the order), tail (lines a passing task
 * shows), timeout (ms)}) with up to `jobs` at a time. Returns
 * `{ok, results, wall}`.
 */
export async function runPool(
  tasks,
  { jobs = defaultJobs(), verbose = false, bail = false, title = 'tasks', logDir = join(repo, '.dart_tool/thor/logs') } = {},
) {
  mkdirSync(logDir, { recursive: true });
  const byName = new Map();
  for (const t of tasks) {
    if (byName.has(t.name)) throw new Error(`duplicate task: ${t.name}`);
    byName.set(t.name, { needs: [], weight: 30, tail: 3, ...t, state: 'pending', out: [] });
  }
  for (const t of byName.values()) {
    for (const n of t.needs) if (!byName.has(n)) throw new Error(`${t.name} needs unknown task ${n}`);
  }
  // Priority: the longest chain below a task first.
  const rankOf = new Map();
  const rank = (t) => {
    if (!rankOf.has(t.name)) {
      const below = [...byName.values()].filter((d) => d.needs.includes(t.name));
      rankOf.set(t.name, t.weight + Math.max(0, ...below.map(rank)));
    }
    return rankOf.get(t.name);
  };
  const order = [...byName.values()];
  order.forEach((t, i) => ((t.index = i), (t.rank = rank(t))));
  order.sort((a, b) => b.rank - a.rank || a.index - b.index);

  const started = Date.now();
  let running = 0;
  let stopping = false;
  const children = new Set();
  const results = [];
  let signalled = 0;

  const killAll = (sig) => {
    for (const c of children) {
      try {
        process.kill(-c.pid, sig); // the whole process group: browsers, servers
      } catch {}
    }
  };
  const onSignal = (sig) => {
    stopping = true;
    signalled = sig === 'SIGINT' ? 130 : 143;
    killAll('SIGTERM');
  };
  process.on('SIGINT', onSignal);
  process.on('SIGTERM', onSignal);

  const report = (t) => {
    const mark = t.state === 'ok' ? paint('1;32', '✓') : t.state === 'skipped' ? paint('1;33', '–') : paint('1;31', '✗');
    console.log(`\n${paint('1;36', '▸')} ${t.name}  ${mark} ${secs(t.ms ?? 0)}${t.note ? `  ${t.note}` : ''}`);
    const lines = t.out.join('').replace(/\r/g, '\n').split('\n');
    while (lines.length && lines[lines.length - 1] === '') lines.pop();
    const shown = verbose || t.state !== 'ok' ? lines : lines.slice(-t.tail);
    if (shown.length < lines.length) console.log(`  … ${lines.length - shown.length} lines (${join(logDir, `${safe(t.name)}.log`)})`);
    for (const l of shown) console.log(l);
  };

  await new Promise((done) => {
    const settle = () => {
      if (running === 0 && (stopping || [...byName.values()].every((t) => t.state !== 'pending'))) done();
    };
    const pump = () => {
      // Tasks whose needs failed are skipped, and so on down the chain.
      let changed = true;
      while (changed) {
        changed = false;
        for (const t of byName.values()) {
          if (t.state !== 'pending') continue;
          const bad = t.needs.find((n) => ['failed', 'skipped'].includes(byName.get(n).state));
          if (bad) {
            t.state = 'skipped';
            t.note = `needs ${bad}`;
            t.ms = 0;
            results.push(t);
            report(t);
            changed = true;
          }
        }
      }
      for (const t of order) {
        if (stopping || running >= jobs) break;
        if (t.state !== 'pending' || !t.needs.every((n) => byName.get(n).state === 'ok')) continue;
        launch(t);
      }
      settle();
    };
    const launch = (t) => {
      t.state = 'running';
      running++;
      const t0 = Date.now();
      const log = createWriteStream(join(logDir, `${safe(t.name)}.log`));
      const child = Array.isArray(t.cmd)
        ? spawn(t.cmd[0], t.cmd.slice(1), { cwd: resolve(repo, t.cwd ?? ''), env: { ...process.env, ...t.env }, detached: true })
        : spawn('bash', ['-c', t.cmd], { cwd: resolve(repo, t.cwd ?? ''), env: { ...process.env, ...t.env }, detached: true });
      children.add(child);
      const take = (b) => {
        const s = b.toString();
        t.out.push(s);
        log.write(s);
      };
      child.stdout.on('data', take);
      child.stderr.on('data', take);
      let timer;
      if (t.timeout) {
        timer = setTimeout(() => {
          t.note = `timed out after ${secs(t.timeout)}`;
          try {
            process.kill(-child.pid, 'SIGKILL');
          } catch {}
        }, t.timeout);
      }
      let over = false;
      const end = (code, err) => {
        if (over) return;
        over = true;
        clearTimeout(timer);
        children.delete(child);
        log.end();
        t.ms = Date.now() - t0;
        if (err) t.out.push(`${err}\n`);
        t.state = code === 0 && !t.note ? 'ok' : 'failed';
        if (t.state === 'failed' && !t.note) t.note = `exit ${code}`;
        running--;
        results.push(t);
        report(t);
        if (t.state === 'failed' && bail) {
          stopping = true;
          killAll('SIGTERM');
        }
        pump();
      };
      child.on('error', (e) => end(127, e.message));
      child.on('close', (code, sig) => end(code ?? (sig ? 128 : 1)));
    };
    pump();
  });
  process.off('SIGINT', onSignal);
  process.off('SIGTERM', onSignal);

  const wall = Date.now() - started;
  const ran = results.filter((t) => t.state !== 'skipped');
  const failed = [...byName.values()].filter((t) => t.state === 'failed' || t.state === 'skipped');
  const notRun = [...byName.values()].filter((t) => t.state === 'pending');
  console.log(`\n${paint('1;36', '▸')} ${title}: times (jobs ${jobs})`);
  for (const t of [...ran].sort((a, b) => b.ms - a.ms)) {
    console.log(`  ${secs(t.ms).padStart(8)}  ${t.state === 'ok' ? ' ' : '✗'} ${t.name}`);
  }
  const sum = ran.reduce((s, t) => s + t.ms, 0);
  console.log(`  wall ${secs(wall)}, sum of the tasks ${secs(sum)} (x${(sum / Math.max(wall, 1)).toFixed(1)})`);
  if (failed.length || notRun.length) {
    console.log(paint('1;31', `\n✗ ${title}: ${failed.length} failed, ${notRun.length} not run`));
    for (const t of failed) console.log(`  ✗ ${t.name}${t.note ? ` (${t.note})` : ''}  → ${join(logDir, `${safe(t.name)}.log`)}`);
    for (const t of notRun) console.log(`  – ${t.name} (not run)`);
  }
  if (signalled) process.exit(signalled);
  return { ok: failed.length === 0 && notRun.length === 0, results, wall };
}

// CLI: tasks from a TSV on stdin.
if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  const args = process.argv.slice(2);
  const opt = (name, fallback) => {
    const i = args.indexOf(name);
    return i < 0 ? fallback : args[i + 1];
  };
  const tasks = readFileSync(0, 'utf8')
    .split('\n')
    .filter((l) => l.trim() !== '' && !l.startsWith('#'))
    .map((l) => {
      const [name, needs, cwd, cmd] = l.split('\t');
      return { name, needs: needs ? needs.split(',') : [], cwd, cmd };
    });
  const { ok } = await runPool(tasks, {
    jobs: Number(opt('--jobs', defaultJobs())),
    verbose: args.includes('--verbose'),
    bail: args.includes('--bail'),
    title: opt('--title', 'tasks'),
  });
  process.exit(ok ? 0 : 1);
}

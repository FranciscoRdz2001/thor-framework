// Tests of the pool (tool/pool.mjs) and of the change scope of tool/check.mjs.
//   node --test tool/pool_test.mjs
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { runPool } from './pool.mjs';

const logDir = mkdtempSync(join(tmpdir(), 'thor-pool-test-'));
const quietly = async (fn) => {
  const log = console.log;
  console.log = () => {};
  try {
    return await fn();
  } finally {
    console.log = log;
  }
};
const run = (tasks, options = {}) => quietly(() => runPool(tasks, { logDir, ...options }));

test('a task waits for what it needs; failures skip the dependents, not the rest', async () => {
  const { ok, results } = await run([
    { name: 'build', cmd: 'exit 3' },
    { name: 'check', cmd: 'true', needs: ['build'] },
    { name: 'other', cmd: 'true' },
  ]);
  assert.equal(ok, false);
  const state = Object.fromEntries(results.map((t) => [t.name, t.state]));
  assert.deepEqual(state, { build: 'failed', check: 'skipped', other: 'ok' });
});

test('no more than `jobs` tasks run at once', async () => {
  const marks = join(logDir, 'marks');
  mkdirSync(marks, { recursive: true });
  const tasks = Array.from({ length: 6 }, (_, i) => ({
    name: `t${i}`,
    cmd: `touch ${marks}/run.$$; ls ${marks} | grep -c '^run\\.' >> ${marks}/counts; sleep 0.3; rm ${marks}/run.$$`,
  }));
  const { ok } = await run(tasks, { jobs: 2 });
  assert.equal(ok, true);
  const counts = readFileSync(join(marks, 'counts'), 'utf8').split('\n').filter(Boolean).map(Number);
  assert.equal(counts.length, 6);
  assert.ok(Math.max(...counts) <= 2, `at once: ${counts}`);
});

test('the output of a failing task is kept whole in its log', async () => {
  const { results } = await run([{ name: 'noisy', cmd: 'for i in 1 2 3 4 5 6 7 8; do echo line$i; done; exit 1' }]);
  assert.equal(results[0].state, 'failed');
  assert.equal(results[0].out.join('').split('\n').filter(Boolean).length, 8);
});

test('a timeout fails the task', async () => {
  const { results } = await run([{ name: 'slow', cmd: 'sleep 5', timeout: 200 }]);
  assert.equal(results[0].state, 'failed');
  assert.match(results[0].note, /timed out/);
});

test('an unknown need is refused', async () => {
  await assert.rejects(run([{ name: 'a', cmd: 'true', needs: ['b'] }]), /unknown task/);
});

// A cached page whose content-hashed engine was removed by a newer deploy:
// the loader reloads once, gets the new page and hydrates; if the page stays
// stale it reloads only once (no loop). Needs JavaScript by nature.
//
//   tool/thor e2e engine-redeploy               (builds test/fixtures/apps/counter, runs)
//   node test/e2e/checks/engine_redeploy_check.mjs
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { e2e, hydrated, repo, settle, trackHydration } from './lib/e2e.mjs';

// E2E_SITE=test/fixtures/apps/counter/build/site-lite runs it against thor-lite (tool/thor_lite.mjs).
const site = process.env.E2E_SITE ?? 'test/fixtures/apps/counter/build/site';
let fresh = '', stale = '';
let staleServes = 0, pageLoads = 0, engineMisses = 0;
if (existsSync(join(repo, site, 'index.html'))) {
  fresh = readFileSync(join(repo, site, 'index.html'), 'utf8');
  // The previous deploy's page: same markup, an engine file that no longer
  // exists (in the preload and in the loader: every mention, or the loader
  // would still find the engine).
  stale = fresh.replace(/engine\.(dart|lite)\.[0-9a-f]{8}\.js/g, 'engine.$1.deadbeef.js');
}

// The page itself comes from here: stale for the first `staleServes` loads.
function handle(req, res) {
  const path = new URL(req.url, 'http://x').pathname;
  if (path === '/' || path === '/index.html') {
    pageLoads++;
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
    res.end(staleServes-- > 0 ? stale : fresh);
    return true;
  }
  if (path.includes('deadbeef')) engineMisses++;
  return false;
}

await e2e('engine-redeploy', { site, handle }, async (t) => {
  if (stale === fresh) throw new Error(`no content-hashed engine in ${site}/index.html`);

  // Visits `/` with the first `staleCount` pages stale; returns what happened.
  async function visit(staleCount, { expectHydration }) {
    staleServes = staleCount;
    pageLoads = 0;
    engineMisses = 0;
    const p = await t.page();
    await trackHydration(p);
    await p.goto(t.url);
    let counted = false;
    if (expectHydration) {
      const ok = await hydrated(p).then(() => true, () => false);
      if (ok) {
        // Tap + and see the engine answer.
        await p.locator('button', { hasText: '+' }).click();
        counted = (await settle(p, () => /\b1\b/.test(document.body.innerText))) === true;
      }
    } else {
      // Never hydrates: wait for the second document's engine to fail, then
      // for the network to go quiet — a reload loop would load the page again.
      const deadline = Date.now() + 10_000;
      while (engineMisses < 2 && Date.now() < deadline) await new Promise((next) => setTimeout(next, 16));
      await settle(p, () => window.__thorEngineFailed === true);
      await p.waitForLoadState('networkidle');
    }
    const mark = await p.evaluate(
      () => Object.keys(sessionStorage).filter((k) => k.startsWith('thor-reload')).length,
    );
    const problems = p.problems.filter((m) => !m.includes('404'));
    await p.context().close();
    return { loads: pageLoads, misses: engineMisses, counted, mark, problems };
  }

  let r = await visit(1, { expectHydration: true });
  t.check('stale page, then the new one: reloaded once', r.loads === 2, `${r.loads} loads`);
  t.check('the new page hydrated: + counts', r.counted);
  t.check('reload mark cleared after hydration', r.mark === 0, `${r.mark} marks`);
  t.check('stale visit: no other errors', r.problems.length === 0, r.problems.join(' | '));

  r = await visit(99, { expectHydration: false });
  t.check('always stale: exactly one reload, no loop', r.loads === 2 && r.misses === 2, `${r.loads} loads, ${r.misses} engine misses`);
  t.check('always stale: the mark stays (no second reload)', r.mark === 1, `${r.mark} marks`);

  r = await visit(0, { expectHydration: true });
  t.check('normal visit: no reload', r.loads === 1, `${r.loads} loads`);
  t.check('normal visit: + counts', r.counted);
  t.check('normal visit: no errors', r.problems.length === 0, r.problems.join(' | '));
});

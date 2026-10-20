// `Expanded` in a real browser: in a Column whose height is not definite (a
// phone, a `FlexLayout` that is a row only from `lg`) it keeps its content
// instead of collapsing to 0; in a definite one it still fills the rest
// exactly and shares it by flex factor; a scroll area inside it still
// shrinks to its share; rows are unchanged. The page is rendered by the
// real widgets (packages/thor_ui/tool/expanded_page.dart).
//
//   tool/thor e2e expanded                   (renders, serves, runs)
//   node test/e2e/checks/expanded_check.mjs
//   E2E_BROWSER=firefox|webkit tool/thor e2e expanded   (same page, other engine)
//
// Known limit (not asserted): an Expanded whose own child has a `height`
// is 0 high in a Column without a definite height; see `Flexible.wrapData`.
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { closeServer, e2e, repo, serveStatic } from './lib/e2e.mjs';

const dir = mkdtempSync(join(tmpdir(), 'expanded-'));
let server;
try {
  execFileSync('dart', ['run', 'tool/expanded_page.dart', join(dir, 'index.html')], {
    cwd: join(repo, 'packages/thor_ui'),
    stdio: 'inherit',
  });
  server = await serveStatic(dir);
  const base = `http://127.0.0.1:${server.address().port}/`;

  await e2e('expanded', { site: null }, async (t) => {
    const near = (a, b) => Math.abs(a - b) < 0.6;
    const size = (page, id) =>
      page.evaluate((id) => {
        const r = document.getElementById(id).getBoundingClientRect();
        return { w: r.width, h: r.height, x: r.x, y: r.y };
      }, id);

    // A phone: the columns that grow with their content.
    const phone = await t.page({ viewport: { width: 390, height: 800 } });
    await phone.goto(base);
    let body = await size(phone, 'auto-body');
    t.check('auto-height column: the Expanded keeps its 120 px', near(body.h, 120), `${body.h}`);
    const col = await size(phone, 'auto-col');
    t.check('auto-height column: it is as tall as its content', near(col.h, 160), `${col.h}`);
    body = await size(phone, 'layout-body');
    t.check('FlexLayout column on a phone: the Expanded keeps its 120 px', near(body.h, 120), `${body.h}`);

    // Desktop: the same layout is a row, the Expanded takes the rest of the width.
    const desk = await t.page({ viewport: { width: 1280, height: 800 } });
    await desk.goto(base);
    const side = await size(desk, 'layout-side');
    body = await size(desk, 'layout-body');
    t.check('FlexLayout row on desktop: side by side', near(body.x, side.x + side.w), `${side.x + side.w} / ${body.x}`);
    t.check('FlexLayout row on desktop: the Expanded is as tall as the row', body.h >= 120, `${body.h}`);

    // A definite height: the same exact shares as before.
    const a = await size(phone, 'fixed-a');
    const b = await size(phone, 'fixed-b');
    t.check('fixed column: Expanded flex 1 is 80 px', near(a.h, 80), `${a.h}`);
    t.check('fixed column: Expanded flex 2 is 160 px (its 500 px content shrinks)', near(b.h, 160), `${b.h}`);
    const head = await size(phone, 'fixed-head');
    const foot = await size(phone, 'fixed-foot');
    t.check(
      'fixed column: the whole 300 px is used',
      near(foot.y + foot.h - head.y, 300),
      `${foot.y + foot.h - head.y}`,
    );

    // A scroll area inside an Expanded scrolls instead of growing.
    const scroll = await phone.evaluate(() => {
      const e = document.getElementById('scroll-area');
      return { h: e.getBoundingClientRect().height, scrolls: e.scrollHeight > e.clientHeight + 100 };
    });
    t.check('Expanded scroll area: 180 px and it scrolls', near(scroll.h, 180) && scroll.scrolls, JSON.stringify(scroll));

    // Rows: definite width, shares by flex factor.
    const ra = await size(phone, 'row-a');
    const rb = await size(phone, 'row-b');
    t.check('row: Expanded flex 1 is a third of the 200 px left', near(ra.w, 200 / 3), `${ra.w}`);
    t.check('row: Expanded flex 2 is two thirds', near(rb.w, 400 / 3), `${rb.w}`);

    // Siblings and nesting in a Column that grows with its content.
    const mixCol = await size(phone, 'mix-col');
    const mixA = await size(phone, 'mix-a');
    const inner = await size(phone, 'mix-inner');
    t.check('auto column, nested: each Expanded keeps its content', near(mixA.h, 50) && near(inner.h, 70), `${mixA.h} / ${inner.h}`);
    t.check('auto column, nested: no space invented', near(mixCol.h, 30 + 50 + 10 + 20 + 70), `${mixCol.h}`);

    // Flexible(loose) never grows past its content.
    const lf = await size(phone, 'loose-fixed');
    const la = await size(phone, 'loose-auto');
    t.check('Flexible loose: its content in a fixed column and in an auto one', near(lf.h, 60) && near(la.h, 60), `${lf.h} / ${la.h}`);

    // A Row with intrinsic-width children.
    const ri = await size(phone, 'row-intrinsic');
    t.check('row: Expanded takes what the intrinsic children leave (300 - 80 - 60)', near(ri.w, 160), `${ri.w}`);

    t.check('no console errors', phone.problems.length === 0 && desk.problems.length === 0);
  });
} finally {
  await closeServer(server);
  rmSync(dir, { recursive: true, force: true });
}

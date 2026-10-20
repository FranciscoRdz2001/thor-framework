// Where the upload progress script (lib/lite/form_upload.js) posts: the form's
// `action`, or the submitter's own `formaction`. A submit button without
// `formaction` has `formAction` = the page address, which is not its action.
// A page made in memory, real Chromium.
//
//   node test/e2e/checks/lite_form_upload_action_check.mjs
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { chromium } from '../runner/node_modules/playwright/index.mjs';
import { repo } from './lib/e2e.mjs';

const script = readFileSync(join(repo, 'packages/thor_engine/lib/lite/form_upload.js'), 'utf8');
const PAGE =
  `<!DOCTYPE html><html><body><form method="post" enctype="multipart/form-data" action="/page?/onValid">` +
  `<input type="file" name="f"><progress data-t-upload hidden></progress>` +
  `<button id="plain" name="a" value="1">Send</button>` +
  `<button id="own" formaction="/page?/other">Other</button></form>` +
  `<script>${script}</script></body></html>`;

const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail !== '' ? ` (${detail})` : ''}`);
};

const browser = await chromium.launch();
try {
  for (const [id, want] of [
    ['plain', '/page?/onValid'],
    ['own', '/page?/other'],
  ]) {
    const ctx = await browser.newContext();
    const p = await ctx.newPage();
    const posted = [];
    await ctx.route('http://lite.test/**', (r) => {
      const req = r.request();
      if (req.method() === 'POST') {
        const u = new URL(req.url());
        posted.push(u.pathname + u.search);
        return r.fulfill({ status: 204 });
      }
      return r.fulfill({ contentType: 'text/html', body: PAGE });
    });
    await p.goto('http://lite.test/page');
    await p.setInputFiles('input[type=file]', { name: 'a.txt', mimeType: 'text/plain', buffer: Buffer.from('hello') });
    await p.click(`#${id}`);
    await p.waitForTimeout(500);
    check(`${id}: the upload goes to ${want}`, posted.length === 1 && posted[0] === want, posted.join(','));
    await ctx.close();
  }
} finally {
  await browser.close();
}
process.exit(results.every(Boolean) ? 0 : 1);

// An Open Graph card per page of the exported docs site: the page's title and
// its section over the default card's look, as `og/<page>.jpg` (1200x630, JPEG: a gradient as PNG weighs
// 260 KB, ~30 KB this way, and Open Graph takes both),
// and the page's `og:image` pointed at it.
//
//   tool/og_cards.mjs [site-dir]      (default apps/docs/build/site)
//
// Optional: a site without the cards keeps `/og.png` on every page. Runs
// after the export (and before the search index), never in the app: the
// cards are a build product, not a render. One headless Chrome, driven over
// the DevTools protocol with node's own WebSocket (nothing to install); a
// card is ~60 ms, so the ~360 pages take about half a minute. Needs Chrome
// (CHROME=… to choose it).
import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const site = resolve(process.argv[2] ?? join(root, 'apps/docs/build/site'));
if (!existsSync(site)) throw new Error(`no such site: ${site} (tool/thor export docs)`);

const sections = { guia: 'Guía', api: 'API', errores: 'Errores', cambios: 'Cambios' };
const unescape = (s) =>
  s.replace(/&(#x[0-9a-f]+|#\d+|amp|lt|gt|quot|apos);/gi, (_, e) =>
    ({ amp: '&', lt: '<', gt: '>', quot: '"', apos: "'" })[e.toLowerCase()] ??
    String.fromCodePoint(e[1] === 'x' ? parseInt(e.slice(2), 16) : Number(e.slice(1))));
const escape = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

// The pages with an og:image: every .html but the error page, the search
// page (a card per query makes no sense) and the search index fragments.
function pages(dir, prefix = '') {
  const found = [];
  for (const name of readdirSync(dir).sort()) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) {
      if (!['pagefind', '_thor', 'fonts', 'og'].includes(name)) found.push(...pages(path, `${prefix}/${name}`));
    } else if (name.endsWith('.html') && !['404.html', 'buscar.html'].includes(name)) {
      found.push({ file: path, url: name === 'index.html' ? prefix || '/' : `${prefix}/${name.slice(0, -5)}` });
    }
  }
  return found;
}

const font = `data:font/woff2;base64,${readFileSync(join(site, 'fonts', readdirSync(join(site, 'fonts')).find((f) => /^figtree-latin-wght-normal.*\.woff2$/.test(f)))).toString('base64')}`;
const card = (title, section) => `<!doctype html><meta charset="utf-8"><style>
@font-face{font-family:F;src:url("${font}");font-weight:100 900}
html,body{margin:0}
body{width:1200px;height:630px;box-sizing:border-box;padding:92px 92px 0;font-family:F,system-ui,sans-serif;
background:linear-gradient(135deg,#14151f 0%,#2a2a6c 100%);color:#fff;overflow:hidden}
.k{font-size:26px;font-weight:700;letter-spacing:.28em;text-transform:uppercase;color:#9d9dff;margin:0 0 22px}
h1{font-size:${title.length > 60 ? 56 : title.length > 28 ? 72 : 104}px;line-height:1.08;font-weight:800;margin:0;
overflow-wrap:anywhere;display:-webkit-box;-webkit-line-clamp:4;-webkit-box-orient:vertical;overflow:hidden}
.s{position:absolute;left:92px;bottom:64px;font-size:34px;font-weight:600;color:#d6d6ff}
</style><p class="k">${escape(section)}</p><h1>${escape(title)}</h1><p class="s">Thor · docs</p>`;

// One Chrome, one tab, over the DevTools protocol.
const chromePath =
  process.env.CHROME ??
  ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/usr/bin/google-chrome', '/usr/bin/chromium'].find(existsSync);
if (!chromePath) throw new Error('Chrome not found (CHROME=…)');
const profile = mkdtempSync(join(tmpdir(), 'og-cards-'));
const chrome = spawn(chromePath, ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`, '--no-first-run', '--disable-gpu', '--hide-scrollbars', 'about:blank'], { stdio: ['ignore', 'ignore', 'pipe'] });
const cleanup = () => {
  chrome.kill();
  try {
    rmSync(profile, { recursive: true, force: true, maxRetries: 5 });
  } catch {} // Chrome still writing: the temp folder goes with the OS's cleanup
};
process.on('exit', cleanup);
process.on('SIGINT', () => process.exit(130));
process.on('SIGTERM', () => process.exit(143));
const wsUrl = await new Promise((resolve, reject) => {
  let log = '';
  chrome.stderr.on('data', (d) => {
    log += d;
    const m = /DevTools listening on (ws:\/\/\S+)/.exec(log);
    if (m) resolve(m[1]);
  });
  chrome.on('exit', () => reject(new Error(`Chrome did not start:\n${log}`)));
  setTimeout(() => reject(new Error('Chrome did not start in 20 s')), 20000);
});
const ws = new WebSocket(wsUrl);
await new Promise((r) => (ws.onopen = r));
let id = 0;
const waiting = new Map();
ws.onmessage = ({ data }) => {
  const m = JSON.parse(data);
  waiting.get(m.id)?.(m);
  waiting.delete(m.id);
};
const send = (method, params = {}, sessionId) =>
  new Promise((done, fail) => {
    const mine = ++id;
    waiting.set(mine, (m) => (m.error ? fail(new Error(`${method}: ${m.error.message}`)) : done(m.result)));
    ws.send(JSON.stringify({ id: mine, method, params, sessionId }));
  });
const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
await send('Emulation.setDeviceMetricsOverride', { width: 1200, height: 630, deviceScaleFactor: 1, mobile: false }, sessionId);
const { frameTree } = await send('Page.getFrameTree', {}, sessionId);
mkdirSync(join(site, 'og'), { recursive: true });

const started = Date.now();
let made = 0;
for (const { file, url } of pages(site)) {
  const html = readFileSync(file, 'utf8');
  const og = /<meta property="og:image" content="([^"]*)"/.exec(html);
  const title = /<meta property="og:title" content="([^"]*)"/.exec(html)?.[1];
  if (!og || !title) continue;
  const name = url === '/' ? 'home' : url.slice(1).replace(/\//g, '-');
  // "Widget · Thor docs", "Layout · API · Thor docs": the kind of page is the card's label.
  let heading = unescape(title).replace(/ · Thor docs$/, '');
  let section = url === '/' ? 'Documentación' : (sections[url.split('/')[1]] ?? 'Documentación');
  const kind = /^(.*) · (Widget|API)$/.exec(heading);
  if (kind) [, heading] = kind;
  if (kind && !section.includes(kind[2])) section += ` · ${kind[2]}`;
  await send('Page.setDocumentContent', { frameId: frameTree.frame.id, html: card(heading, section) }, sessionId);
  // The font in (it is inline): a card with the fallback font is a bug.
  await send('Runtime.evaluate', { expression: 'document.fonts.ready.then(() => document.fonts.check("700 20px F"))', awaitPromise: true }, sessionId);
  const { data } = await send('Page.captureScreenshot', { format: 'jpeg', quality: 82 }, sessionId);
  writeFileSync(join(site, `og/${name}.jpg`), Buffer.from(data, 'base64'));
  // The same origin and prefix as the default card.
  const image = og[1].replace(/\/og\.png$/, `/og/${name}.jpg`);
  writeFileSync(file, html.replace(og[0], `<meta property="og:image" content="${image}"`));
  made++;
}
console.log(`${made} cards → ${join(site, 'og')} (${((Date.now() - started) / 1000).toFixed(1)} s)`);
// The socket and Chrome would keep node alive.
process.exit(0);

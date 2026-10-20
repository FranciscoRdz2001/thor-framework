// Every live example of the exported docs site, audited in headless Chrome:
// how it renders (size, overflow, clipping, contrast, broken images), how it
// sits in the page, the console and network of its page, and, for a bench,
// whether each control really changes the stage and the live code.
//
//   tool/thor export docs && node tool/docs_examples_audit.mjs [options]
//   tool/thor examples-audit [options]
//
//   --site DIR        the export (default apps/docs/build/site); also the page list
//   --url URL         audit a running server instead (thor preview / thor dev)
//   --pages LIST      comma list of prefixes or globs (`es/ui/*`, `es/catalogo`)
//   --out DIR         the results (default build/examples_audit)
//   --jobs N          tabs at once (default 4)
//   --themes LIST     default light,dark
//   --viewports LIST  name=WxH[xDPR], default desktop=1280x900,phone=390x844x3
//   --no-interact     skip the controls of the benches
//
// Writes report.json (every finding), report.md (by page and severity:
// broken / visual / minor), crops/<page>/<example>.<theme>-<viewport>.png
// (the example as it sits in the page), sheets/<page>-<n>.png (contact
// sheets: every crop of a page with its findings, to review by eye) and
// index.html (the same, all pages, browsable).
//
// An example is an element with `data-docs-example="<id>"` (ExampleView) or
// any StudioBench (its `<id>-view` radio group). The stage of a bench is the
// pane its Demo / Code toggle hides; the controls are its panel's ranges and
// radio groups. The interaction pass runs in the first theme, every
// viewport. Chrome and the server die with the process (also on Ctrl-C).
// Needs node ≥ 22 and Chrome (CHROME=… to choose it).
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { createReadStream, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, extname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { inflateSync } from 'node:zlib';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const opt = (name, fallback) => {
  const i = args.indexOf(name);
  return i < 0 ? fallback : args[i + 1];
};
const site = resolve(opt('--site', join(root, 'apps/docs/build/site')));
const remote = opt('--url', null)?.replace(/\/$/, '');
const out = resolve(opt('--out', join(root, 'build/examples_audit')));
const jobs = Number(opt('--jobs', 4));
const themes = opt('--themes', 'light,dark').split(',');
const viewports = opt('--viewports', 'desktop=1280x900,phone=390x844x3')
  .split(',')
  .map((v) => {
    const [name, size] = v.split('=');
    const [width, height, dpr = 1] = size.split('x').map(Number);
    return { name, width, height, dpr, mobile: width < 600 };
  });
const interact = !args.includes('--no-interact');
const filters = (opt('--pages', '') || '')
  .split(',')
  .filter(Boolean)
  .map((f) => {
    const g = f.replace(/^\//, '');
    if (!/[*?]/.test(g)) return (p) => p.startsWith(g);
    const re = new RegExp(`^${g.replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*\*/g, '\0').replace(/\*/g, '[^/]*').replace(/\?/g, '.').replace(/\0/g, '.*')}$`);
    return (p) => re.test(p);
  });
if (!existsSync(site)) throw new Error(`no such site: ${site} (tool/thor export docs)`);

// ---------------------------------------------------------------------------
// The pages: every exported page with an example (a marked root or a bench).
function pages(dir, prefix = '') {
  const found = [];
  for (const name of readdirSync(dir).sort()) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) {
      if (!['pagefind', '_thor', 'fonts', 'og'].includes(name)) found.push(...pages(path, `${prefix}/${name}`));
    } else if (name.endsWith('.html') && name !== '404.html') {
      const html = readFileSync(path, 'utf8');
      if (/data-docs-example=|name="[A-Za-z][\w-]*-view"/.test(html)) {
        found.push(name === 'index.html' ? prefix || '/' : `${prefix}/${name.slice(0, -5)}`);
      }
    }
  }
  return found;
}
const paths = pages(site).filter((p) => !filters.length || filters.some((f) => f(p.slice(1))));
if (!paths.length) throw new Error(`no pages with examples in ${site}`);
const slug = (p) => p.replace(/^\//, '').replace(/\//g, '_') || 'index';

// ---------------------------------------------------------------------------
// One server: the export (unless --url) and the audit's own output under
// /__audit/ (the contact sheets are pages Chrome screenshots).
const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.woff2': 'font/woff2', '.json': 'application/json', '.txt': 'text/plain', '.md': 'text/plain; charset=utf-8' };
const server = createServer((req, res) => {
  const path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  const [base, dir] = path.startsWith('/__audit/') ? [join(out, path.slice(9)), out] : [join(site, path), site];
  const file = [base, `${base}.html`, join(base, 'index.html')].find((f) => f.startsWith(dir) && existsSync(f) && statSync(f).isFile());
  if (!file) {
    res.writeHead(404, { 'content-type': types['.html'] });
    return res.end('not found');
  }
  res.writeHead(200, { 'content-type': types[extname(file)] ?? 'application/octet-stream', 'cache-control': 'no-store' });
  createReadStream(file)
    .on('error', () => res.destroy())
    .pipe(res);
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const local = `http://127.0.0.1:${server.address().port}`;
const origin = remote ?? local;

// ---------------------------------------------------------------------------
// Chrome, over the DevTools protocol with node's own WebSocket.
const chromePath =
  process.env.CHROME ??
  ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/usr/bin/google-chrome', '/usr/bin/chromium'].find(existsSync);
if (!chromePath) throw new Error('Chrome not found (CHROME=…)');
const profile = mkdtempSync(join(tmpdir(), 'examples-audit-'));
const chrome = spawn(chromePath, ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`, '--no-first-run', '--disable-gpu', '--hide-scrollbars', '--mute-audio', '--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows', 'about:blank'], {
  stdio: ['ignore', 'ignore', 'pipe'],
});
let cleaned = false;
const cleanup = () => {
  if (cleaned) return;
  cleaned = true;
  try {
    chrome.kill('SIGKILL');
  } catch {}
  server.close();
  try {
    rmSync(profile, { recursive: true, force: true, maxRetries: 5 });
  } catch {} // Chrome still writing: the OS cleans the temp folder
};
process.on('exit', cleanup);
process.on('SIGINT', () => process.exit(130));
process.on('SIGTERM', () => process.exit(143));
process.on('uncaughtException', (e) => {
  console.error(e);
  process.exit(1);
});
const wsUrl = await new Promise((done, fail) => {
  let log = '';
  chrome.stderr.on('data', (d) => {
    log += d;
    const m = /DevTools listening on (ws:\/\/\S+)/.exec(log);
    if (m) done(m[1]);
  });
  chrome.on('exit', () => fail(new Error(`Chrome did not start:\n${log}`)));
  setTimeout(() => fail(new Error('Chrome did not start in 20 s')), 20000);
});
const ws = new WebSocket(wsUrl);
await new Promise((r) => (ws.onopen = r));
let nextId = 0;
const waiting = new Map();
const listeners = new Map(); // sessionId → (method, params) => void
ws.onmessage = ({ data }) => {
  const m = JSON.parse(data);
  if (m.id != null) {
    waiting.get(m.id)?.(m);
    waiting.delete(m.id);
  } else if (m.sessionId) listeners.get(m.sessionId)?.(m.method, m.params);
};
const send = (method, params = {}, sessionId) =>
  new Promise((done, fail) => {
    const mine = ++nextId;
    const timer = setTimeout(() => {
      waiting.delete(mine);
      fail(new Error(`${method}: timeout`));
    }, 60000);
    waiting.set(mine, (m) => {
      clearTimeout(timer);
      m.error ? fail(new Error(`${method}: ${m.error.message}`)) : done(m.result);
    });
    ws.send(JSON.stringify({ id: mine, method, params, sessionId }));
  });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------------------------------------------------------------------------
// PNG decoding (8-bit RGB/RGBA, what Chrome writes) and a pixel diff.
function decodePng(buf) {
  let p = 8;
  let width, height, colorType;
  const idat = [];
  while (p < buf.length) {
    const len = buf.readUInt32BE(p);
    const type = buf.toString('ascii', p + 4, p + 8);
    const data = buf.subarray(p + 8, p + 8 + len);
    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      colorType = data[9];
      if (data[8] !== 8 || data[12] !== 0) throw new Error('unsupported PNG');
    } else if (type === 'IDAT') idat.push(data);
    p += 12 + len;
  }
  const bpp = colorType === 6 ? 4 : colorType === 2 ? 3 : colorType === 0 ? 1 : 2;
  const raw = inflateSync(Buffer.concat(idat));
  const stride = width * bpp;
  const px = Buffer.alloc(width * height * 4);
  const prev = Buffer.alloc(stride);
  const line = Buffer.alloc(stride);
  for (let y = 0; y < height; y++) {
    const f = raw[y * (stride + 1)];
    const src = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? line[x - bpp] : 0;
      const b = prev[x];
      const c = x >= bpp ? prev[x - bpp] : 0;
      let v = src[x];
      if (f === 1) v += a;
      else if (f === 2) v += b;
      else if (f === 3) v += (a + b) >> 1;
      else if (f === 4) {
        const pp = a + b - c;
        const pa = Math.abs(pp - a), pb = Math.abs(pp - b), pc = Math.abs(pp - c);
        v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
      }
      line[x] = v & 255;
    }
    for (let x = 0; x < width; x++) {
      const o = (y * width + x) * 4;
      if (bpp >= 3) {
        px[o] = line[x * bpp];
        px[o + 1] = line[x * bpp + 1];
        px[o + 2] = line[x * bpp + 2];
      } else px[o] = px[o + 1] = px[o + 2] = line[x * bpp];
      px[o + 3] = 255;
    }
    line.copy(prev);
  }
  return { width, height, px };
}
/** The share of pixels that differ (any channel by more than 24). */
function diff(a, b) {
  if (!a || !b) return 1;
  if (a.width !== b.width || a.height !== b.height) return 1;
  let n = 0;
  for (let i = 0; i < a.px.length; i += 4) {
    if (Math.abs(a.px[i] - b.px[i]) > 24 || Math.abs(a.px[i + 1] - b.px[i + 1]) > 24 || Math.abs(a.px[i + 2] - b.px[i + 2]) > 24) n++;
  }
  return n / (a.width * a.height);
}
/** The share of pixels that are not the dominant color (an empty stage ≈ 0). */
function inked(img) {
  const counts = new Map();
  for (let i = 0; i < img.px.length; i += 16) {
    const k = (img.px[i] >> 3) | ((img.px[i + 1] >> 3) << 5) | ((img.px[i + 2] >> 3) << 10);
    counts.set(k, (counts.get(k) ?? 0) + 1);
  }
  const top = Math.max(...counts.values());
  return 1 - top / (img.px.length / 16);
}

// ---------------------------------------------------------------------------
// What runs in the page. `window.__audit` finds the examples and measures them.
const pageScript = String.raw`(() => {
  const rectOf = (el) => { const r = el.getBoundingClientRect(); return { x: r.left + scrollX, y: r.top + scrollY, w: r.width, h: r.height }; };
  const visible = (el) => { const s = getComputedStyle(el); return s.display !== 'none' && s.visibility !== 'hidden' && el.getClientRects().length > 0; };
  const parse = (c) => { const m = c.match(/rgba?\(([^)]+)\)/); if (!m) return null; const p = m[1].split(/[ ,/]+/).filter(Boolean).map(Number); return [p[0], p[1], p[2], p.length > 3 ? p[3] : 1]; };
  const lum = ([r, g, b]) => { const f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; }; return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b); };
  const blend = (top, under) => { const a = top[3]; return [top[0] * a + under[0] * (1 - a), top[1] * a + under[1] * (1 - a), top[2] * a + under[2] * (1 - a), 1]; };
  // The opaque color behind el, or null under an image or gradient.
  const background = (el) => {
    const layers = [];
    for (let e = el; e; e = e.parentElement) {
      const s = getComputedStyle(e);
      if (s.backgroundImage && s.backgroundImage !== 'none') return null;
      const c = parse(s.backgroundColor);
      if (c && c[3] > 0) { layers.push(c); if (c[3] >= 1) break; }
    }
    let base = [255, 255, 255, 1];
    const html = parse(getComputedStyle(document.documentElement).backgroundColor);
    if (html && html[3] > 0) base = html;
    for (let i = layers.length - 1; i >= 0; i--) base = blend(layers[i], base);
    return base;
  };
  const opacityChain = (el, stop) => { let o = 1; for (let e = el; e && e !== stop.parentElement; e = e.parentElement) o *= Number(getComputedStyle(e).opacity); return o; };

  function find() {
    const roots = [...document.querySelectorAll('[data-docs-example]')].map((el) => ({ el, id: el.dataset.docsExample }));
    // Benches with no mark (the home's).
    for (const input of document.querySelectorAll('input[type=radio][value=demo]')) {
      if (!/-view$/.test(input.name) || input.closest('[data-docs-example]')) continue;
      const el = input.closest('[role=group]');
      if (el) roots.push({ el, id: input.name.replace(/-view$/, '') });
    }
    return roots.map(({ el, id }, index) => {
      const view = [...el.querySelectorAll('input[type=radio][value=demo]')].find((i) => /-view$/.test(i.name));
      const ex = { index, id, el, view: view?.name ?? null };
      if (view) {
        let p = view;
        while (p && p !== el) {
          const parent = p.parentElement;
          const kids = parent ? [...parent.children] : [];
          if (kids.length >= 3 && kids.indexOf(p) >= 2) {
            ex.card = parent; ex.stage = kids[0]; ex.code = kids[1]; ex.toolbar = p; break;
          }
          p = parent;
        }
        // The panel is the sibling, at some level, of the branch that holds the
        // card (the example wraps the bench, so it is not always the root's child).
        for (let c = ex.card; ex.card && c && c !== el; c = c.parentElement) {
          const sibling = [...(c.parentElement?.children ?? [])].find((s) => s !== c && !s.contains(ex.card));
          if (sibling && el.contains(sibling)) { ex.panel = sibling; break; }
        }
      }
      if (!ex.stage) ex.stage = el;
      return ex;
    });
  }
  let examples = [];

  function controls(ex) {
    if (!ex.panel) return [];
    const out = [];
    const labelOf = (input) => {
      if (input.getAttribute('aria-label')) return input.getAttribute('aria-label');
      const by = input.getAttribute('aria-labelledby');
      if (by) return by.split(/\s+/).map((i) => document.getElementById(i)?.textContent ?? '').join(' ').trim();
      if (input.labels?.length) return [...input.labels].map((l) => l.textContent).join(' ').trim();
      return '';
    };
    for (const r of ex.panel.querySelectorAll('input[type=range]')) {
      out.push({ kind: 'level', name: r.name || null, label: labelOf(r), min: Number(r.min || 0), max: Number(r.max || 100), value: r.value, key: 'r' + out.length });
    }
    const groups = new Map();
    for (const r of ex.panel.querySelectorAll('input[type=radio]')) {
      if (!groups.has(r.name)) groups.set(r.name, []);
      groups.get(r.name).push(r);
    }
    for (const [name, radios] of groups) {
      const group = radios[0].closest('[role=radiogroup], fieldset, [role=group]');
      const gl = group ? (group.getAttribute('aria-label') || group.querySelector('legend')?.textContent || '') : '';
      out.push({ kind: 'switch', name, label: gl.trim(), segments: radios.map((r) => ({ value: r.value, label: labelOf(r) || r.closest('label')?.textContent?.trim() || '' })), value: radios.find((r) => r.checked)?.value ?? null, key: 'g' + out.length });
    }
    return out;
  }

  function measure(ex) {
    const f = [];
    const add = (severity, kind, detail) => f.push({ severity, kind, detail });
    const stage = ex.stage;
    const r = rectOf(ex.el);
    const s = rectOf(stage);
    if (!visible(ex.el) || r.w < 4 || r.h < 4) add('broken', 'zero-size', 'example root ' + Math.round(r.w) + '×' + Math.round(r.h));
    else if (!visible(stage) || s.w < 4 || s.h < 4) add('broken', 'zero-size', 'stage ' + Math.round(s.w) + '×' + Math.round(s.h));
    // What the stage shows: its visible boxes.
    const stageBox = stage.getBoundingClientRect();
    const top = ex.toolbar ? ex.toolbar.getBoundingClientRect().bottom : stageBox.top;
    let shown = 0, union = null;
    const escaped = [];
    const all = stage.querySelectorAll('*');
    for (let i = 0; i < all.length && i < 3000; i++) {
      const e = all[i];
      if (ex.toolbar && ex.toolbar.contains(e)) continue;
      const b = e.getBoundingClientRect();
      if (b.width < 1 || b.height < 1) continue;
      const cs = getComputedStyle(e);
      if (cs.visibility === 'hidden' || cs.position === 'fixed') continue;
      if (e.closest('dialog:not([open]), [popover]:not(:popover-open)')) continue;
      if (opacityChain(e, stage) < 0.05) continue;
      if (e.children.length === 0 || (e.childNodes.length && [...e.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim())) || /^(IMG|SVG|svg|CANVAS|VIDEO|INPUT|IFRAME|PROGRESS|METER|SELECT|TEXTAREA)$/.test(e.tagName)) {
        shown++;
        union = union ? { l: Math.min(union.l, b.left), t: Math.min(union.t, b.top), r: Math.max(union.r, b.right), b: Math.max(union.b, b.bottom) } : { l: b.left, t: b.top, r: b.right, b: b.bottom };
      }
      // Escaping the stage: no clipping ancestor between it and the stage.
      const ss = getComputedStyle(stage);
      const scrollsX = /auto|scroll/.test(ss.overflowX), scrollsY = /auto|scroll/.test(ss.overflowY);
      if ((b.right > stageBox.right + 2 && !scrollsX) || b.left < stageBox.left - 2 || (b.bottom > stageBox.bottom + 2 && !scrollsY) || b.top < stageBox.top - 2) {
        let clipped = false;
        for (let a = e.parentElement; a && a !== stage; a = a.parentElement) {
          const as = getComputedStyle(a);
          if (as.overflowX !== 'visible' || as.overflowY !== 'visible' || as.clipPath !== 'none' || as.contain.includes('paint')) { clipped = true; break; }
        }
        if (!clipped && !escaped.some((x) => x.contains(e))) escaped.push(e);
      }
      if (e.tagName === 'IMG' && e.complete && e.naturalWidth === 0) add('broken', 'broken-image', e.getAttribute('src'));
    }
    if (!f.some((x) => x.kind === 'zero-size') && shown === 0) add('broken', 'empty-stage', 'no visible content on the stage');
    const contentArea = Math.max(1, stageBox.width * (stageBox.bottom - top));
    const fill = union ? ((union.r - union.l) * (union.b - Math.max(union.t, top))) / contentArea : 0;
    for (const e of escaped.slice(0, 5)) {
      const b = e.getBoundingClientRect();
      const how = [b.right > stageBox.right + 2 && 'right +' + Math.round(b.right - stageBox.right), b.left < stageBox.left - 2 && 'left ' + Math.round(b.left - stageBox.left), b.bottom > stageBox.bottom + 2 && 'bottom +' + Math.round(b.bottom - stageBox.bottom), b.top < stageBox.top - 2 && 'top ' + Math.round(b.top - stageBox.top)].filter(Boolean).join(', ');
      add('visual', 'clipped', '<' + e.tagName.toLowerCase() + '> "' + (e.textContent || '').trim().slice(0, 40) + '" leaves the stage (' + how + ')');
    }
    if (escaped.length > 5) add('visual', 'clipped', (escaped.length - 5) + ' more elements leave the stage');
    // Overflow: the stage, the bench, the page column, the page.
    if (stage.scrollWidth > stage.clientWidth + 1) add('visual', 'overflow-x', 'stage scrolls sideways: content ' + stage.scrollWidth + 'px in ' + stage.clientWidth + 'px');
    if (ex.stage !== ex.el && stage.scrollHeight > stage.clientHeight + 1 && getComputedStyle(stage).overflowY !== 'visible') add('visual', 'overflow-y', 'stage scrolls vertically: content ' + stage.scrollHeight + 'px in ' + stage.clientHeight + 'px');
    if (ex.el !== stage && ex.el.scrollWidth > ex.el.clientWidth + 1) add('visual', 'overflow-x', 'bench wider than its box: ' + ex.el.scrollWidth + 'px in ' + ex.el.clientWidth + 'px');
    const column = ex.el.parentElement;
    const cb = column?.getBoundingClientRect();
    const eb = ex.el.getBoundingClientRect();
    if (cb && (eb.right > cb.right + 1 || eb.left < cb.left - 1)) add('visual', 'column-overflow', 'example ' + Math.round(eb.width) + 'px sticks out of its column (' + Math.round(cb.left) + '–' + Math.round(cb.right) + ')');
    if (eb.right > document.documentElement.clientWidth + 1) add('visual', 'page-overflow', 'example ends at ' + Math.round(eb.right) + 'px, viewport ' + document.documentElement.clientWidth + 'px');
    // Contrast of the stage's text.
    let checked = 0;
    const low = [];
    const walker = document.createTreeWalker(stage, NodeFilter.SHOW_TEXT);
    for (let n = walker.nextNode(); n && checked < 300; n = walker.nextNode()) {
      const t = n.textContent.trim();
      if (!t) continue;
      const e = n.parentElement;
      if (!e || (ex.toolbar && ex.toolbar.contains(e))) continue;
      if (e.closest('[disabled], [aria-disabled=true], [aria-hidden=true], svg')) continue;
      const b = e.getBoundingClientRect();
      if (b.width <= 1 || b.height <= 1 || !visible(e)) continue;
      const cs = getComputedStyle(e);
      if (cs.clip === 'rect(0px, 0px, 0px, 0px)' || cs.clipPath.startsWith('inset(50%')) continue;
      const o = opacityChain(e, stage);
      if (o < 0.1) continue;
      checked++;
      const color = parse(cs.color);
      const bg = background(e);
      if (!color || !bg) continue;
      const fg = blend([color[0], color[1], color[2], color[3] * o], bg);
      const l1 = lum(fg), l2 = lum(bg);
      const ratio = (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
      const size = parseFloat(cs.fontSize);
      const large = size >= 24 || (size >= 18.66 && Number(cs.fontWeight) >= 700);
      const need = large ? 3 : 4.5;
      if (ratio < need) low.push({ text: t.slice(0, 40), ratio: Math.round(ratio * 100) / 100, need, color: cs.color, bg: 'rgb(' + bg.slice(0, 3).map(Math.round).join(',') + ')' });
    }
    const seen = new Set();
    for (const l of low) {
      const k = l.color + l.bg;
      if (seen.has(k)) continue;
      seen.add(k);
      add('visual', 'contrast', '"' + l.text + '" ' + l.ratio + ':1 (needs ' + l.need + ') ' + l.color + ' on ' + l.bg);
    }
    // Controls with no name.
    for (const c of controls(ex)) {
      if (!c.label) add('minor', 'unlabelled-control', c.kind + ' ' + (c.name ?? c.key) + ' has no accessible name');
      if (c.kind === 'switch') for (const sg of c.segments) if (!sg.label) add('minor', 'unlabelled-control', 'segment ' + sg.value + ' of ' + (c.label || c.name) + ' has no text');
    }
    // A segment whose label is cut (ellipsis, or text wider than its cell).
    for (const g of ex.el.querySelectorAll('[role=radiogroup]')) {
      if (!visible(g)) continue;
      const cut = new Set();
      for (const e of g.querySelectorAll('*')) {
        if (e.tagName === 'INPUT' || !e.textContent.trim() || e.children.length > 1) continue;
        if (e.scrollWidth > e.clientWidth + 1 && e.clientWidth > 0 && getComputedStyle(e).overflowX !== 'visible') cut.add(e.textContent.trim().slice(0, 30));
      }
      if (cut.size) add('visual', 'clipped-segment', 'segment label cut off in "' + (g.getAttribute('aria-label') || '') + '": ' + [...cut].join(' | '));
    }
    if (ex.code) {
      const text = ex.code.textContent.trim();
      if (!text) add('broken', 'empty-code', 'the Code view has no text');
    }
    const panelRect = ex.panel ? ex.panel.getBoundingClientRect() : null;
    return {
      id: ex.id,
      index: ex.index,
      kind: ex.panel ? 'bench' : ex.code ? 'example' : 'bare',
      rect: r,
      stage: s,
      column: cb ? Math.round(cb.width) : null,
      widthShare: cb ? Math.round((eb.width / cb.width) * 100) / 100 : null,
      stageShare: ex.panel && panelRect ? Math.round((stageBox.width / eb.width) * 100) / 100 : null,
      fill: Math.round(fill * 100) / 100,
      shown,
      controls: controls(ex),
      findings: f,
    };
  }

  window.__audit = {
    find() { examples = find(); return examples.map((e) => e.id); },
    measure(i) { return measure(examples[i]); },
    measureAll() { return examples.map(measure); },
    // Crops in document coordinates.
    rect(i, part) {
      const ex = examples[i];
      const el = part === 'stage' ? ex.stage : part === 'code' ? ex.code : ex.el;
      if (!el) return null;
      el.scrollIntoView({ block: 'center', inline: 'nearest' });
      const r = rectOf(el);
      if (part === 'stage' && ex.toolbar) {
        const t = ex.toolbar.getBoundingClientRect().bottom + scrollY;
        const cut = Math.max(0, t - r.y);
        r.y += cut; r.h -= cut;
      }
      return r;
    },
    view(i, which) {
      const ex = examples[i];
      const input = ex.el.querySelector('input[name="' + ex.view + '"][value="' + which + '"]');
      if (input) input.click();
      return !!input;
    },
    codeState(i) {
      const ex = examples[i];
      if (!ex.code) return null;
      const s = getComputedStyle(ex.stage).display;
      const b = ex.code.getBoundingClientRect();
      return { stageHidden: s === 'none', codeShown: b.width > 4 && b.height > 4 && getComputedStyle(ex.code).display !== 'none', text: ex.code.innerText.trim().slice(0, 4000) };
    },
    codeText(i) { const ex = examples[i]; return ex.code ? ex.code.textContent : ''; },
    set(i, c, value) {
      const ex = examples[i];
      if (c.kind === 'level') {
        const r = ex.panel.querySelectorAll('input[type=range]')[Number(c.key.slice(1))];
        const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
        setter.call(r, String(value));
        r.dispatchEvent(new Event('input', { bubbles: true }));
        r.dispatchEvent(new Event('change', { bubbles: true }));
        return r.value;
      }
      const radio = [...ex.panel.querySelectorAll('input[type=radio]')].find((x) => x.name === c.name && x.value === value);
      if (radio) radio.click();
      return radio?.checked ?? false;
    },
    // The site's sticky bars would cover crops: hidden while the audit runs.
    hideChrome() {
      for (const e of document.querySelectorAll('body *')) {
        const p = getComputedStyle(e).position;
        if ((p === 'fixed' || p === 'sticky') && !e.closest('[data-docs-example], [role=group]')) e.style.setProperty('visibility', 'hidden', 'important');
      }
    },
  };
})()`;

// ---------------------------------------------------------------------------
// A tab.
async function openTab() {
  const { targetId } = await send('Target.createTarget', { url: 'about:blank', newWindow: true });
  const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
  const tab = { targetId, sessionId, events: [], onLoad: null };
  listeners.set(sessionId, (method, params) => {
    if (method === 'Page.loadEventFired') tab.onLoad?.();
    else tab.events.push({ method, params });
  });
  const s = (m, p) => send(m, p, sessionId);
  await s('Page.enable');
  // Parallel tabs: each acts focused, or Chrome pauses its frames.
  await s('Emulation.setFocusEmulationEnabled', { enabled: true });
  await s('Runtime.enable');
  await s('Log.enable');
  await s('Network.enable');
  await s('Page.addScriptToEvaluateOnNewDocument', { source: `addEventListener('DOMContentLoaded', () => { ${pageScript} })` });
  tab.send = s;
  tab.eval = async (expression) => {
    const r = await s('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (r.exceptionDetails) throw new Error(`${expression.slice(0, 60)}: ${r.exceptionDetails.exception?.description ?? r.exceptionDetails.text}`);
    return r.result.value;
  };
  return tab;
}

async function load(tab, url, theme, vp) {
  await tab.send('Emulation.setDeviceMetricsOverride', { width: vp.width, height: vp.height, deviceScaleFactor: vp.dpr, mobile: vp.mobile });
  await tab.send('Emulation.setTouchEmulationEnabled', { enabled: vp.mobile });
  await tab.send('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-color-scheme', value: theme }, { name: 'prefers-reduced-motion', value: 'no-preference' }] });
  tab.events = [];
  const loaded = new Promise((r) => (tab.onLoad = r));
  await tab.send('Page.navigate', { url });
  await Promise.race([loaded, sleep(20000)]);
  await tab.eval('document.fonts.ready.then(() => new Promise((r) => setTimeout(r, 400)))');
  // Entrances and transitions run fast so the crops show the settled state.
  await tab.send('Animation.enable').catch(() => {});
  await tab.send('Animation.setPlaybackRate', { playbackRate: 20 }).catch(() => {});
  if (!(await tab.eval('!!window.__audit'))) await tab.eval(pageScript);
  await tab.eval('__audit.hideChrome()');
}

async function shot(tab, rect, vp) {
  if (!rect || rect.w < 1 || rect.h < 1) return null;
  const tall = rect.h > vp.height - 20;
  const { data } = await tab.send('Page.captureScreenshot', {
    format: 'png',
    clip: { x: Math.max(0, rect.x), y: Math.max(0, rect.y), width: Math.ceil(rect.w), height: Math.min(Math.ceil(rect.h), 6000), scale: 1 },
    captureBeyondViewport: tall,
  });
  return Buffer.from(data, 'base64');
}
const pad = (r, m) => r && { x: r.x - m, y: r.y - m, w: r.w + 2 * m, h: r.h + 2 * m };

// The console and the network of a load, as page findings.
function pageEvents(tab, origin) {
  const f = [];
  for (const { method, params } of tab.events) {
    if (method === 'Runtime.exceptionThrown') {
      f.push({ severity: 'broken', kind: 'js-error', detail: (params.exceptionDetails.exception?.description ?? params.exceptionDetails.text).split('\n')[0] });
    } else if (method === 'Runtime.consoleAPICalled' && ['error', 'warning', 'assert'].includes(params.type)) {
      const text = params.args.map((a) => a.value ?? a.description ?? '').join(' ');
      const thor = /THOR-[A-Z]+\d+/.exec(text);
      f.push({ severity: params.type === 'error' ? 'visual' : 'minor', kind: thor ? 'thor-warning' : `console-${params.type}`, detail: text.slice(0, 300) });
    } else if (method === 'Log.entryAdded' && ['error', 'warning'].includes(params.entry.level) && params.entry.source !== 'network') {
      f.push({ severity: params.entry.level === 'error' ? 'visual' : 'minor', kind: `log-${params.entry.level}`, detail: params.entry.text.slice(0, 300) });
    } else if (method === 'Network.loadingFailed' && !params.canceled) {
      f.push({ severity: 'visual', kind: 'request-failed', detail: `${params.type ?? ''} ${params.errorText} (${tab.urls?.get(params.requestId) ?? params.requestId})` });
    } else if (method === 'Network.requestWillBeSent') {
      (tab.urls ??= new Map()).set(params.requestId, params.request.url.replace(origin, ''));
    } else if (method === 'Network.responseReceived' && params.response.status >= 400) {
      f.push({ severity: params.type === 'Image' || params.type === 'Script' ? 'broken' : 'visual', kind: 'http-error', detail: `${params.response.status} ${params.response.url.replace(origin, '')}` });
    }
  }
  return f;
}

// ---------------------------------------------------------------------------
// The interaction pass of one bench: every Level at min and max, every
// segment of every Switch, Demo / Code.
async function exercise(tab, i, info, vp, crop) {
  const f = [];
  const states = [];
  const mark = tab.events.length;
  const stage = async () => {
    const r = await tab.eval(`__audit.rect(${i}, 'stage')`);
    const png = await shot(tab, r, vp);
    return png && { png, img: decodePng(png) };
  };
  const settle = () => tab.eval('new Promise((r) => setTimeout(r, 150))');
  const base = await stage();
  const norm = (x) => `${x.kind}|${x.detail.replace(/[\d.+-]+/g, 'N')}`;
  const before = new Set((await tab.eval(`__audit.measure(${i})`)).findings.map(norm));
  const after = new Map(); // control|kind → {values, detail}
  if (base && info.kind !== 'bare' && inked(base.img) < 0.002) f.push({ severity: 'broken', kind: 'blank-stage', detail: 'the stage crop is a single flat color' });
  for (const c of info.controls) {
    const values = c.kind === 'level' ? [c.min, c.max] : c.segments.map((s) => s.value);
    const shots = [];
    const codes = [];
    for (const v of values) {
      await tab.eval(`__audit.set(${i}, ${JSON.stringify(c)}, ${JSON.stringify(v)})`);
      await settle();
      const s = await stage();
      shots.push({ v, s });
      codes.push(await tab.eval(`__audit.codeText(${i})`));
      const m = await tab.eval(`__audit.measure(${i})`);
      for (const x of m.findings) {
        if (!['zero-size', 'empty-stage', 'overflow-x', 'overflow-y', 'clipped', 'clipped-segment', 'column-overflow', 'page-overflow'].includes(x.kind) || before.has(norm(x))) continue;
        const k = `${c.label || c.name}|${x.kind}`;
        const prev = after.get(k);
        if (prev) {
          if (!prev.values.includes(v)) prev.values.push(v);
        } else after.set(k, { control: c.label || c.name, kind: x.kind, severity: x.severity === 'broken' ? 'broken' : 'visual', detail: x.detail, values: [v] });
      }
    }
    // Back to how the page drew it.
    await tab.eval(`__audit.set(${i}, ${JSON.stringify(c)}, ${JSON.stringify(c.value)})`);
    await settle();
    let changed = 0;
    for (let a = 1; a < shots.length; a++) changed = Math.max(changed, diff(shots[0].s?.img, shots[a].s?.img));
    const codeChanged = new Set(codes).size > 1;
    const label = c.label || c.name || c.key;
    states.push({ control: label, kind: c.kind, values, pixelsChanged: Math.round(changed * 10000) / 10000, codeChanged });
    const timing = c.kind === 'level' && /durac|duration|delay|retraso|espera|velocidad|speed|tiempo|time|ms\b/i.test(label);
    if (changed < 0.0005 && timing) {
      f.push({ severity: 'minor', kind: 'timing-control', detail: `level "${label}" only changes timing: no settled difference on the stage${codeChanged ? '' : ', nor in the code'}` });
    } else if (changed < 0.0005) {
      // Nothing anywhere is a dead control; a code line that moves with a
      // stage that does not is an effect the demo never shows.
      f.push(
        codeChanged
          ? { severity: 'visual', kind: 'invisible-effect', detail: `${c.kind} "${label}" (${values.join(' / ')}) changes the code but nothing visible on the stage` }
          : { severity: 'broken', kind: 'dead-control', detail: `${c.kind} "${label}" (${values.join(' / ')}) changes nothing, neither the stage nor the code` },
      );
      mkdirSync(join(crop.dir, 'dead'), { recursive: true });
      shots.forEach((x, k) => x.s && writeFileSync(join(crop.dir, 'dead', `${crop.name}.${c.key}.${k}.png`), x.s.png));
    } else if (!codeChanged && info.kind === 'bench') {
      f.push({ severity: 'minor', kind: 'static-code', detail: `${c.kind} "${label}" changes the stage but no line of the Code view` });
    }
  }
  for (const a of after.values()) {
    f.push({ severity: a.severity, kind: 'after-control', detail: `"${a.control}" = ${a.values.join(' / ')}: ${a.kind} — ${a.detail}` });
  }
  // Demo / Code.
  if (info.kind !== 'bare') {
    await tab.eval(`__audit.view(${i}, 'code')`);
    await settle();
    const cs = await tab.eval(`__audit.codeState(${i})`);
    if (cs) {
      if (!cs.stageHidden) f.push({ severity: 'broken', kind: 'toggle', detail: 'Code view chosen but the demo still shows' });
      if (!cs.codeShown) f.push({ severity: 'broken', kind: 'toggle', detail: 'Code view chosen but the code pane is not shown' });
      else if (!cs.text) f.push({ severity: 'broken', kind: 'empty-code', detail: 'the Code view shows no text' });
      if (crop.codeShot) {
        const png = await shot(tab, await tab.eval(`__audit.rect(${i}, 'code')`), vp);
        if (png) writeFileSync(join(crop.dir, `${crop.name}.code.png`), png);
      }
      const m = await tab.eval(`__audit.measure(${i})`);
      void m;
    }
    await tab.eval(`__audit.view(${i}, 'demo')`);
    await settle();
  }
  // What broke while its controls were used is this example's.
  for (const { method, params } of tab.events.slice(mark)) {
    if (method === 'Runtime.exceptionThrown') {
      f.push({ severity: 'broken', kind: 'js-error', detail: `while using its controls: ${(params.exceptionDetails.exception?.description ?? params.exceptionDetails.text).split('\n')[0]}` });
    }
  }
  tab.events = [...tab.events.slice(0, mark), ...tab.events.slice(mark).filter((e) => e.method !== 'Runtime.exceptionThrown')];
  return { findings: f, states };
}

// ---------------------------------------------------------------------------
// The run.
rmSync(out, { recursive: true, force: true });
mkdirSync(join(out, 'crops'), { recursive: true });
const results = []; // {path, examples: [...], page: [...]}
const queue = [...paths];
let done = 0;
const started = Date.now();

async function worker() {
  const tab = await openTab();
  for (let path = queue.shift(); path; path = queue.shift()) {
    const page = { path, examples: new Map(), findings: [] };
    const dir = join(out, 'crops', slug(path));
    mkdirSync(dir, { recursive: true });
    try {
      for (const [ti, theme] of themes.entries()) {
        for (const vp of viewports) {
          const combo = `${theme}-${vp.name}`;
          await load(tab, `${origin}${path}`, theme, vp);
          const ids = await tab.eval('__audit.find()');
          const measured = await tab.eval('__audit.measureAll()');
          for (const [i, m] of measured.entries()) {
            const key = `${i}:${ids[i]}`;
            const ex = page.examples.get(key) ?? { id: ids[i], index: i, kind: m.kind, combos: {}, findings: [], controls: m.controls, interaction: {} };
            page.examples.set(key, ex);
            const name = `${String(i).padStart(2, '0')}-${ids[i]}`;
            const png = await shot(tab, pad(await tab.eval(`__audit.rect(${i}, 'root')`), 12), vp);
            if (png) writeFileSync(join(dir, `${name}.${combo}.png`), png);
            ex.combos[combo] = { rect: m.rect, stage: m.stage, widthShare: m.widthShare, stageShare: m.stageShare, fill: m.fill, column: m.column, crop: png ? relative(out, join(dir, `${name}.${combo}.png`)) : null };
            for (const x of m.findings) ex.findings.push({ ...x, combo });
            if (interact && ti === 0 && m.kind !== 'bare') {
              const r = await exercise(tab, i, m, vp, { dir, name: `${name}.${combo}`, codeShot: vp === viewports[0] });
              for (const x of r.findings) ex.findings.push({ ...x, combo });
              ex.interaction[combo] = r.states;
            }
          }
          for (const x of pageEvents(tab, origin)) page.findings.push({ ...x, combo });
        }
      }
    } catch (e) {
      page.findings.push({ severity: 'broken', kind: 'audit-error', detail: String(e.message ?? e).slice(0, 300) });
    }
    results.push({ path, findings: dedupe(page.findings), examples: [...page.examples.values()].map((e) => ({ ...e, findings: dedupe(e.findings) })) });
    done++;
    const n = [...page.examples.values()].length;
    console.log(`${String(done).padStart(3)}/${paths.length} ${path}  ${n} example${n === 1 ? '' : 's'}`);
  }
  await send('Target.closeTarget', { targetId: tab.targetId }).catch(() => {});
}
// The same finding in several themes/viewports is one finding with its combos.
function dedupe(list) {
  const by = new Map();
  for (const x of list) {
    const k = `${x.severity}|${x.kind}|${x.detail.replace(/\d+(\.\d+)?px/g, 'Npx')}`;
    const prev = by.get(k);
    if (prev) {
      if (!prev.combos.includes(x.combo)) prev.combos.push(x.combo);
    } else by.set(k, { severity: x.severity, kind: x.kind, detail: x.detail, combos: [x.combo] });
  }
  return [...by.values()];
}
await Promise.all(Array.from({ length: Math.min(jobs, paths.length) }, worker));
results.sort((a, b) => a.path.localeCompare(b.path));

// ---------------------------------------------------------------------------
// Reports.
const sev = ['broken', 'visual', 'minor'];
const count = { broken: 0, visual: 0, minor: 0 };
let exampleCount = 0;
for (const p of results) {
  for (const x of p.findings) count[x.severity]++;
  for (const e of p.examples) {
    exampleCount++;
    for (const x of e.findings) count[x.severity]++;
  }
}
writeFileSync(join(out, 'report.json'), JSON.stringify({ origin, themes, viewports, pages: results.length, examples: exampleCount, counts: count, results }, null, 2));

const md = [`# Docs examples audit`, '', `${results.length} pages, ${exampleCount} examples · ${themes.join('/')} × ${viewports.map((v) => v.name).join('/')} · broken ${count.broken}, visual ${count.visual}, minor ${count.minor}`, ''];
const line = (x) => `  - **${x.severity}** \`${x.kind}\` ${x.detail} _(${x.combos.join(', ')})_`;
for (const p of results) {
  const flagged = p.examples.filter((e) => e.findings.length);
  if (!p.findings.length && !flagged.length) continue;
  md.push(`## ${p.path}`, '');
  for (const x of [...p.findings].sort((a, b) => sev.indexOf(a.severity) - sev.indexOf(b.severity))) md.push(line(x).replace(/^  /, ''));
  for (const e of flagged) {
    md.push(`- \`${e.id}\` (${e.kind})`);
    for (const x of [...e.findings].sort((a, b) => sev.indexOf(a.severity) - sev.indexOf(b.severity))) md.push(line(x));
  }
  md.push('');
}
writeFileSync(join(out, 'report.md'), md.join('\n'));

// The contact sheets: one HTML page per site page (chunks of 6 examples),
// screenshotted to sheets/, and index.html linking them all.
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const comboOrder = themes.flatMap((t) => viewports.map((v) => `${t}-${v.name}`));
const sheetCss = `body{margin:0;padding:16px;font:13px/1.4 -apple-system,system-ui,sans-serif;background:#e9e9ee;color:#111;width:1568px}
h1{font-size:18px;margin:0 0 12px}h2{font-size:15px;margin:0 0 6px}
.ex{background:#fff;border-radius:8px;padding:12px;margin:0 0 14px}
.row{display:flex;gap:10px;align-items:flex-start}.row figure{margin:0}.row figcaption{font-size:11px;color:#666}
.row img{display:block;border:1px solid #ccc;background:repeating-conic-gradient(#f4f4f4 0 25%,#fff 0 50%) 0/16px 16px}
.d img{width:440px}.p img{width:210px}
ul{margin:6px 0 0;padding-left:18px}.broken{color:#b00020;font-weight:600}.visual{color:#a35a00}.minor{color:#555}
.meta{color:#666;font-size:12px}`;
const exampleHtml = (p, e) => {
  const figs = comboOrder
    .map((c) => {
      const info = e.combos[c];
      if (!info?.crop) return '';
      const phone = !c.endsWith(viewports[0].name);
      return `<figure class="${phone ? 'p' : 'd'}"><img src="/__audit/${info.crop}"><figcaption>${c}</figcaption></figure>`;
    })
    .join('');
  const d = e.combos[comboOrder[0]] ?? {};
  const meta = `${e.kind} · width ${d.widthShare ?? '?'} of column ${d.column ?? '?'}px${d.stageShare != null ? ` · stage ${d.stageShare} of bench` : ''} · fill ${d.fill ?? '?'}`;
  const items = e.findings.map((x) => `<li class="${x.severity}">${x.severity} · ${esc(x.kind)} · ${esc(x.detail)} <span class="meta">(${x.combos.join(', ')})</span></li>`).join('');
  return `<div class="ex"><h2>${esc(e.id)} <span class="meta">${esc(p.path)}</span></h2><div class="meta">${esc(meta)}</div><div class="row">${figs}</div>${items ? `<ul>${items}</ul>` : ''}</div>`;
};
mkdirSync(join(out, 'sheets'), { recursive: true });
const sheets = [];
for (const p of results) {
  for (let k = 0; k < p.examples.length; k += 6) {
    const name = `${slug(p.path)}-${k / 6 + 1}`;
    const pageList = p.findings.map((x) => `<li class="${x.severity}">${x.severity} · ${esc(x.kind)} · ${esc(x.detail)}</li>`).join('');
    const html = `<!doctype html><meta charset="utf-8"><style>${sheetCss}</style><h1>${esc(p.path)} (${k + 1}–${Math.min(k + 6, p.examples.length)} of ${p.examples.length})</h1>${k === 0 && pageList ? `<ul>${pageList}</ul>` : ''}${p.examples.slice(k, k + 6).map((e) => exampleHtml(p, e)).join('')}`;
    writeFileSync(join(out, 'sheets', `${name}.html`), html);
    sheets.push({ name, path: p.path });
  }
}
{
  const tab = await openTab();
  await tab.send('Emulation.setDeviceMetricsOverride', { width: 1600, height: 1000, deviceScaleFactor: 1, mobile: false });
  for (const s of sheets) {
    const loaded = new Promise((r) => (tab.onLoad = r));
    await tab.send('Page.navigate', { url: `${local}/__audit/sheets/${s.name}.html` });
    await Promise.race([loaded, sleep(15000)]);
    const h = await tab.eval('document.documentElement.scrollHeight');
    const { data } = await tab.send('Page.captureScreenshot', { format: 'png', clip: { x: 0, y: 0, width: 1600, height: Math.min(h, 16000), scale: 1 }, captureBeyondViewport: true });
    writeFileSync(join(out, 'sheets', `${s.name}.png`), Buffer.from(data, 'base64'));
  }
}
const nav = results.map((p) => `<li><a href="#${slug(p.path)}">${esc(p.path)}</a> ${p.examples.length}${p.examples.some((e) => e.findings.some((x) => x.severity === 'broken')) ? ' <b class="broken">broken</b>' : ''}</li>`).join('');
const body = results.map((p) => `<section id="${slug(p.path)}"><h1>${esc(p.path)}</h1>${p.findings.length ? `<ul>${p.findings.map((x) => `<li class="${x.severity}">${x.severity} · ${esc(x.kind)} · ${esc(x.detail)}</li>`).join('')}</ul>` : ''}${p.examples.map((e) => exampleHtml(p, e)).join('')}</section>`).join('');
writeFileSync(
  join(out, 'index.html'),
  `<!doctype html><meta charset="utf-8"><title>Docs examples audit</title><style>${sheetCss.replace('width:1568px', '')}.row{flex-wrap:wrap}</style><h1>Docs examples audit — ${results.length} pages, ${exampleCount} examples · broken ${count.broken}, visual ${count.visual}, minor ${count.minor}</h1><ul>${nav}</ul>${body}`.replaceAll('/__audit/', ''),
);

console.log(`\n${results.length} pages, ${exampleCount} examples in ${((Date.now() - started) / 1000).toFixed(0)} s → ${out}`);
console.log(`broken ${count.broken} · visual ${count.visual} · minor ${count.minor}`);
console.log(`report.md, report.json, index.html, sheets/ (${sheets.length})`);
process.exit(0);

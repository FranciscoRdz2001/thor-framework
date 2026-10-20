// Upload progress of a `Form` with a file, in a real browser: a
// form that holds a `LinearProgressIndicator.upload()` (`<progress
// data-t-upload hidden>`) sends its files with an XMLHttpRequest (fetch has
// no upload progress), fills the bar as the bytes leave, and then the
// NAVIGATION IS THE BROWSER'S OWN. Pages made in memory around the real
// scripts (form_script.dart + upload_script.dart) and a server that speaks
// the protocol (`x-thor-upload` in, a redirect out as a `200` with
// `x-thor-location`) and reads the body slowly.
//
//   tool/thor e2e forms-upload     (no app to build)
//   node test/e2e/checks/forms_upload_check.mjs
//
// - the bar shows while it sends, rises (never back), the server gets every
//   byte, field and the pressed button's name/value; the form script is not
//   the one that sends (a page with a Form and no bar never loads it);
// - a redirect: ONE hidden post and ONE real GET of the target (a flash is
//   used up once), its Set-Cookie applied, a new history entry, back works
//   and the form is free again (bfcache), a redirect to another origin, a
//   `javascript:` target refused, the scroll and pressed button kept over a
//   same-path answer (and `data-t-reset` starting at the top);
// - a 422 or a 200 page: kept by the server, the browser navigates to it (one
//   post, the 422 status in the navigation, shown at the action's URL, its
//   scripts running, no document.write; a spent address lands on the form);
// - a page from a server that is not thor's: written over this one;
// - a download is saved, a 204 / a dropped connection frees the form;
// - no JS, no bar, no file, a GET form, urlencoded: the plain post.
import { readFileSync, mkdtempSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { e2e, repo } from './lib/e2e.mjs';

const literal = (file) => /r"""([\s\S]*?)"""/.exec(readFileSync(join(repo, file), 'utf8'))[1];
const formScript = literal('packages/thor_ui/lib/src/engine/form_script.dart');
const uploadScript = literal('packages/thor_ui/lib/src/engine/upload_script.dart');

const doc = (body, { title = 't', upload = true, extra = '' } = {}) =>
  `<!doctype html><html><head><meta charset="utf-8"><title>${title}</title></head><body>${body}${upload ? `<script>${uploadScript}</script>` : ''}<script>${formScript}</script>${extra}</body></html>`;
const form = (id, action, { bar = true, method = 'post', enctype = 'multipart/form-data', reset = false } = {}) =>
  `<form id="${id}" method="${method}" action="${action}" enctype="${enctype}"${reset ? ' data-t-reset' : ''}><input id="${id}-name" name="title" value="hola"><input id="${id}-file" type="file" name="file">${bar ? `<progress id="${id}-bar" data-t-upload max="1" hidden></progress>` : ''}<button id="${id}-go" type="submit" name="intent" value="save">Subir</button></form>`;
const tall = (inner) => `<div style="height:3000px">arriba</div>${inner}<div style="height:1500px">abajo</div>`;

const pages = {
  '/upload': doc(form('f', '/up')),
  '/invalid': doc(form('f', '/invalid')),
  '/drop': doc(form('f', '/drop')),
  '/nocontent': doc(form('f', '/nocontent')),
  '/download': doc(form('f', '/download')),
  '/page200': doc(form('f', '/page200')),
  '/foreign': doc(form('f', '/foreign')),
  '/cross': doc(form('f', '/cross')),
  '/tofile': doc(form('f', '/tofile')),
  '/evil': doc(form('f', '/evil')),
  '/nobar': doc(form('f', '/up', { bar: false })),
  '/get': doc(form('f', '/search', { method: 'get' })),
  '/urlenc': doc(form('f', '/up', { enctype: 'application/x-www-form-urlencoded' })),
  '/nojs': `<!doctype html><title>t</title>${form('f', '/up')}`,
  '/keep': doc(tall(form('f', '/keep'))),
  '/keep422': doc(tall(form('f', '/keep422'))),
  '/keep200': doc(tall(form('f', '/keep200'))),
  '/keep422-reset': doc(tall(form('f', '/keep422-reset', { reset: true }))),
  '/keep422-err': doc(tall(form('f', '/keep422-err'))),
  '/keep-reset': doc(tall(form('f', '/keep-reset', { reset: true }))),
  '/done': null, // below: it reads the flash cookie
};

const posts = [];
const results = new Map();
let lastToken;
const gets = [];
let other; // a second origin
const handle = (req, res) => {
  const url = new URL(req.url, 'http://x');
  const protocol = req.headers['x-thor-upload'] !== undefined;
  if (req.method === 'POST') {
    const info = { path: url.pathname, dest: req.headers['sec-fetch-dest'], bytes: 0, head: '', tail: '', protocol };
    posts.push(info);
    if (url.pathname === '/drop') {
      req.once('data', () => req.destroy());
      return true;
    }
    // Slow: a pause after each chunk, so the browser's send is held back.
    req.on('data', (c) => {
      if (info.bytes < 600) info.head = c.toString('latin1', 0, 150);
      info.tail = c.toString('latin1', Math.max(0, c.length - 120));
      info.bytes += c.length;
      req.pause();
      setTimeout(() => req.resume(), 15);
    });
    req.on('end', () => {
      // What thor_server does with `x-thor-upload`: a redirect is not followed
      // by the request, its target comes in a header, cookies kept.
      const redirect = (to, cookie) => {
        const cookies = cookie ? { 'set-cookie': cookie } : {};
        if (protocol) res.writeHead(200, { 'x-thor-upload': '1', 'x-thor-location': to, 'cache-control': 'no-store', ...cookies }).end();
        else res.writeHead(303, { location: to, ...cookies }).end();
      };
      // What thor_server does with a page: kept once under a token, the
      // answer is its address (and a cookie of the visitor).
      const page = (status, body) => {
        if (!protocol || url.pathname === '/foreign') return res.writeHead(status, { 'content-type': 'text/html; charset=utf-8' }).end(body);
        const token = `tok${results.size}${Date.now()}`;
        lastToken = token;
        results.set(token, { status, body });
        res.writeHead(200, { 'x-thor-upload': '1', 'x-thor-location': `/_thor/upload-result/${token}`, 'cache-control': 'no-store', 'set-cookie': `thor-upload=${token}; Path=/_thor/upload-result; HttpOnly` }).end();
      };
      switch (url.pathname) {
        case '/invalid':
          page(422, doc(`<p id="bad">demasiado grande</p>${form('f', '/invalid')}`, { title: 'invalido', extra: '<script>document.title+=" (js)"</script>' }));
          break;
        case '/nocontent':
          res.writeHead(204, protocol ? { 'x-thor-upload': '1' } : {}).end();
          break;
        case '/download':
          res.writeHead(200, { 'content-type': 'text/plain', 'content-disposition': 'attachment; filename="r.txt"', ...(protocol ? { 'x-thor-upload': '1' } : {}) }).end('descarga');
          break;
        case '/page200':
        case '/foreign':
          page(200, doc(`<p id="ok200">la pagina misma</p>${form('f', url.pathname)}`, { title: 'dos cientos', extra: '<script>document.body.dataset.ran="1"</script>' }));
          break;
        case '/cross':
          redirect(`http://127.0.0.1:${other.address().port}/ext`);
          break;
        case '/tofile':
          redirect('/file.txt');
          break;
        case '/evil':
          redirect('javascript:document.title="pwned"');
          break;
        case '/keep422':
          page(422, doc(tall(form('f', '/keep422')), { title: 'kept' }));
          break;
        case '/keep200':
          page(200, doc(tall(form('f', '/keep200')), { title: 'kept' }));
          break;
        case '/keep422-reset':
          page(422, doc(tall(form('f', '/keep422-reset', { reset: true }))));
          break;
        case '/keep422-err':
          page(422, doc(tall(`<input id="bad-input" name="x" autofocus aria-invalid="true">${form('f', '/keep422-err')}`)));
          break;
        case '/keep':
          redirect('/keep?ok=1');
          break;
        case '/keep-reset':
          redirect('/keep-reset');
          break;
        default:
          redirect('/done', 'flash=hola; Path=/');
      }
    });
    return true;
  }
  if (url.pathname.startsWith('/_thor/upload-result/')) {
    const token = url.pathname.split('/').pop();
    const mine = new RegExp(`(?:^|; )thor-upload=${token}(?:;|$)`).test(req.headers.cookie ?? '');
    const kept = mine && results.get(token);
    results.delete(token);
    if (!kept) return res.writeHead(303, { location: '/upload', 'cache-control': 'no-store' }).end(), true;
    res.writeHead(kept.status, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' }).end(kept.body);
    return true;
  }
  if (url.pathname === '/file.txt') {
    res.writeHead(200, { 'content-type': 'text/plain', 'content-disposition': 'attachment; filename="g.txt"' }).end('archivo');
    return true;
  }
  if (url.pathname === '/done') {
    gets.push({ path: url.pathname, dest: req.headers['sec-fetch-dest'], cookie: req.headers.cookie ?? '' });
    const flash = /flash=([^;]*)/.exec(req.headers.cookie ?? '')?.[1] ?? '';
    // A flash is read once: the answer clears it.
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store', 'set-cookie': 'flash=; Path=/; Max-Age=0' }).end(doc(`<p id="done">listo</p><p id="flash">${flash}</p>`, { title: 'done' }));
    return true;
  }
  const page = pages[url.pathname.replace(/\?.*/, '')];
  if (!page) return false;
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' }).end(page);
  return true;
};

const tmp = mkdtempSync(join(tmpdir(), 'thor-forms-upload-'));
writeFileSync(join(tmp, 'index.html'), '<!doctype html><title>placeholder</title>');
const file = (n, v = 7) => ({ name: 'big.bin', mimeType: 'application/octet-stream', buffer: Buffer.alloc(n, v) });
const big = file(6 * 1024 * 1024);

await e2e('forms-upload', { site: tmp, handle, timeout: 180_000 }, async (t) => {
  other = createServer((req, res) => res.writeHead(200, { 'content-type': 'text/html' }).end('<title>ext</title><p id="ext">otro origen</p>'));
  await new Promise((r) => other.listen(0, '127.0.0.1', r));
  const open = async (path, options = {}) => {
    const page = await t.page(options);
    await page.goto(t.url + path.slice(1), { waitUntil: 'domcontentloaded' });
    return page;
  };
  const submit = async (p, f = file(300_000, 1)) => {
    await p.setInputFiles('#f-file', f);
    await p.click('#f-go', { noWaitAfter: true });
  };
  const idle = (p) => p.evaluate(() => !document.getElementById('f').hasAttribute('data-pending') && !document.getElementById('f').hasAttribute('aria-busy') && document.getElementById('f-bar').hidden && !document.getElementById('f-go').disabled);
  // The bar's values, sampled in the page while it sends (the page stays
  // until the answer: an XMLHttpRequest, not a navigation) and reported out.
  const sample = async (page) => {
    const seen = [];
    await page.exposeFunction('__bar', (v) => seen.push(v));
    await page.evaluate(() => {
      const bar = document.getElementById('f-bar');
      setInterval(() => !bar.hidden && window.__bar(bar.hasAttribute('value') ? bar.value : null), 10);
    });
    return seen;
  };

  // A redirect: progress, then the browser's own navigation.
  {
    posts.length = 0;
    gets.length = 0;
    const p = await open('/upload');
    t.check('the bar starts hidden', await p.locator('#f-bar').evaluate((b) => b.hidden));
    const lengthBefore = await p.evaluate(() => history.length);
    await p.setInputFiles('#f-file', big);
    const values = await sample(p);
    await p.click('#f-go', { noWaitAfter: true });
    await p.waitForURL('**/done');
    const numeric = values.filter((v) => v !== null);
    t.check('the bar showed while it sent', values.length > 3, `${values.length}`);
    t.check('it rose through values between 0 and 1', numeric.filter((v) => v > 0 && v < 1).length >= 2, JSON.stringify([...new Set(numeric)].slice(0, 20)));
    t.check('it never went back', numeric.every((v, i) => i === 0 || v >= numeric[i - 1]));
    t.check('the target is shown (URL, content)', (await p.textContent('#done')) === 'listo' && (await p.title()) === 'done', p.url());
    t.check('one post, by XMLHttpRequest, with every byte', posts.length === 1 && posts[0].dest === 'empty' && posts[0].protocol && posts[0].bytes > big.buffer.length, JSON.stringify({ ...posts[0], head: '', tail: '' }));
    t.check('the fields and the pressed button went along', /hola/.test(posts[0]?.head ?? '') && /name="intent"\s+save/.test(posts[0]?.tail ?? ''), JSON.stringify(posts[0]));
    t.check('the target was fetched ONCE, as a document (a flash is used once)', gets.length === 1 && gets[0].dest === 'document', JSON.stringify(gets));
    t.check('the Set-Cookie of the post was applied (the flash came through)', (await p.textContent('#flash')) === 'hola', await p.textContent('#flash'));
    t.check('one history entry more', (await p.evaluate(() => history.length)) === lengthBefore + 1);
    await p.goBack();
    await p.waitForURL('**/upload');
    t.check('back: the form is free again (bfcache or reload) and the bar hidden', await p.waitForFunction(() => !document.getElementById('f').hasAttribute('data-pending') && document.getElementById('f-bar').hidden && !document.getElementById('f-go').disabled, null, { timeout: 5000 }).then(() => true, () => false));
    await p.goForward();
    await p.waitForURL('**/done');
    t.check('forward shows the target again', (await p.textContent('#done')) === 'listo');
    await p.close();
  }

  // A double click sends once.
  {
    posts.length = 0;
    const p = await open('/upload');
    await p.setInputFiles('#f-file', big);
    await p.evaluate(() => {
      const b = document.getElementById('f-go');
      b.click();
      b.click();
      document.getElementById('f').requestSubmit();
    });
    await p.waitForURL('**/done');
    t.check('submitting again while it sends does nothing (one post)', posts.length === 1, `${posts.length}`);
    await p.close();
  }

  // A page (a 422, a 200): the server keeps it, the browser navigates to it.
  const spy = (p) => p.addInitScript(() => {
    const write = Document.prototype.write;
    Document.prototype.write = function (...a) {
      try { sessionStorage.writes = +(sessionStorage.writes ?? 0) + 1; } catch {}
      return write.apply(this, a);
    };
  });
  {
    posts.length = 0;
    const p = await t.page();
    await spy(p);
    const statuses = [];
    p.on('response', (r) => r.url().includes('/_thor/upload-result/') && statuses.push([r.status(), r.request().resourceType()]));
    await p.goto(t.url + 'invalid', { waitUntil: 'domcontentloaded' });
    await submit(p);
    await p.waitForSelector('#bad');
    t.check('a 422 is ONE post (no second upload)', posts.length === 1 && posts[0].dest === 'empty' && posts[0].protocol, JSON.stringify(posts.map((x) => [x.path, x.dest])));
    t.check('the navigation got the 422 status', statuses.length === 1 && statuses[0][0] === 422 && statuses[0][1] === 'document', JSON.stringify(statuses));
    t.check('shown at the action URL, its scripts ran, its title', new URL(p.url()).pathname === '/invalid' && (await p.title()) === 'invalido (js)', `${p.url()} ${await p.title()}`);
    t.check('document.write was never used', (await p.evaluate(() => sessionStorage.writes ?? 0)) === 0);
    t.check('its form is idle and works again', await idle(p));
    const hist = await p.evaluate(() => history.length);
    posts.length = 0;
    await submit(p);
    await p.waitForFunction(() => document.title === 'invalido (js)' && document.querySelector('#bad'));
    t.check('and its form sends with progress again (the new document\'s scripts)', posts.length === 1 && posts[0].dest === 'empty', JSON.stringify(posts.map((x) => x.dest)));
    // The result is single use: its address, visited again, goes back to the form.
    const spent = lastToken;
    const q = await t.page();
    await q.goto(t.url + `_thor/upload-result/${spent}`);
    t.check('a spent or foreign result address lands on the form page, no error', new URL(q.url()).pathname === '/upload', q.url());
    await q.close();
    await p.goBack();
    await p.goForward();
    t.check('back and forward over a result are sane (the entry is the action URL)', new URL(p.url()).pathname === '/invalid' && hist >= 2, p.url());
    await p.close();
  }
  {
    posts.length = 0;
    const p = await t.page();
    await spy(p);
    await p.goto(t.url + 'page200', { waitUntil: 'domcontentloaded' });
    await submit(p);
    await p.waitForSelector('#ok200');
    t.check('a 200 page: one post, title, inline scripts, action URL, no document.write', posts.length === 1 && (await p.title()) === 'dos cientos' && (await p.evaluate(() => document.body.dataset.ran)) === '1' && new URL(p.url()).pathname === '/page200' && (await p.evaluate(() => sessionStorage.writes ?? 0)) === 0, await p.title());
    await p.close();
  }
  // A server that is not thor's: no protocol back, the page is written over this one.
  {
    posts.length = 0;
    const p = await open('/foreign');
    await submit(p);
    await p.waitForSelector('#ok200');
    t.check('a foreign server\'s page is written over this one (title, scripts, URL), one post', posts.length === 1 && (await p.title()) === 'dos cientos' && (await p.evaluate(() => document.body.dataset.ran)) === '1' && new URL(p.url()).pathname === '/foreign', await p.title());
    await p.close();
  }

  // A redirect to another origin, and one that is not a web address.
  {
    const p = await open('/cross');
    await submit(p);
    await p.waitForURL(/\/ext$/);
    t.check('a redirect to another origin is followed by the browser', (await p.textContent('#ext')) === 'otro origen', p.url());
    await p.close();
  }
  {
    const p = await open('/evil');
    await submit(p);
    await p.waitForFunction(() => !document.getElementById('f').hasAttribute('data-pending'), null, { timeout: 15_000 });
    t.check('a javascript: target is refused: nothing ran, the form is free', (await p.title()) === 't' && (await idle(p)), await p.title());
    await p.close();
  }

  // A download is saved; a 204 or a dropped connection leaves the page.
  {
    const p = await open('/download');
    await p.setInputFiles('#f-file', file(300_000, 1));
    const [dl] = await Promise.all([p.waitForEvent('download', { timeout: 15_000 }).catch(() => null), p.click('#f-go', { noWaitAfter: true })]);
    t.check('a Content-Disposition answer is downloaded', dl?.suggestedFilename() === 'r.txt', dl?.suggestedFilename());
    await p.waitForFunction(() => !document.getElementById('f').hasAttribute('data-pending'), null, { timeout: 15_000 });
    t.check('the form is free after the download, still this page', (await idle(p)) && new URL(p.url()).pathname === '/download');
    await p.close();
  }
  for (const [name, path] of [['a 204', '/nocontent'], ['a dropped connection', '/drop']]) {
    const p = await open(path);
    await p.evaluate(() => addEventListener('thor:upload-error', (e) => (window.uploadError = e.detail)));
    await submit(p);
    await p.waitForFunction(() => !document.getElementById('f').hasAttribute('data-pending'), null, { timeout: 15_000 });
    t.check(`${name} tells the page (thor:upload-error)`, (await p.evaluate(() => window.uploadError)) !== undefined, `${await p.evaluate(() => window.uploadError)}`);
    t.check(`${name} frees the form and hides the bar, on the same page`, (await idle(p)) && new URL(p.url()).pathname === path);
    await p.close();
  }

  // A redirect to a download: the page stays, the form is not locked forever.
  {
    const p = await open('/tofile');
    const [dl] = await Promise.all([p.waitForEvent('download', { timeout: 15_000 }).catch(() => null), submit(p)]);
    t.check('a redirect to a download is downloaded by the browser', dl?.suggestedFilename() === 'g.txt', dl?.suggestedFilename());
    await p.waitForFunction(() => !document.getElementById('f').hasAttribute('data-pending'), null, { timeout: 25_000 });
    t.check('and the form is free again (15 s), still this page', (await idle(p)) && new URL(p.url()).pathname === '/tofile');
    await p.close();
  }

  // The place over a kept page (a 422, a 200): as over a same-path answer.
  for (const [name, path] of [['a kept 422', '/keep422'], ['a kept 200', '/keep200']]) {
    const p = await open(path);
    await p.evaluate(() => scrollTo(0, 2500));
    await submit(p);
    await p.waitForFunction(() => document.title === 'kept', null, { timeout: 15_000 });
    await p.waitForTimeout(400);
    const y = await p.evaluate(() => scrollY);
    t.check(`${name} keeps the scroll`, y > 2000 && new URL(p.url()).pathname === path, `${y} ${p.url()}`);
    t.check(`${name}: the pressed button has the focus`, await p.evaluate(() => document.activeElement?.id === 'f-go'));
    await p.close();
  }
  {
    const p = await open('/keep422-reset');
    await p.evaluate(() => scrollTo(0, 2500));
    await submit(p);
    await p.waitForFunction(() => location.pathname === '/keep422-reset' && performance.getEntriesByType('navigation')[0]?.type === 'navigate', null, { timeout: 15_000 });
    await p.waitForTimeout(400);
    t.check('a kept 422 of a data-t-reset form starts at the top', (await p.evaluate(() => scrollY)) < 100);
    await p.close();
  }
  {
    const p = await open('/keep422-err');
    await p.evaluate(() => scrollTo(0, 2500));
    await submit(p);
    await p.waitForFunction(() => location.pathname === '/keep422-err' && performance.getEntriesByType('navigation')[0]?.type === 'navigate', null, { timeout: 15_000 });
    await p.waitForTimeout(400);
    t.check('a kept 422 with an error field focuses it, as a normal 422', await p.evaluate(() => document.activeElement?.id === 'bad-input'));
    await p.close();
  }

  // The visitor's place (form_submit.js's rules) over a same-path answer.
  {
    const p = await open('/keep');
    await p.evaluate(() => scrollTo(0, 2500));
    await submit(p);
    await p.waitForURL('**/keep?ok=1');
    await p.waitForTimeout(400);
    const y = await p.evaluate(() => scrollY);
    t.check('a same-path answer keeps the scroll', y > 2000, `${y}`);
    t.check('and the pressed button has the focus', await p.evaluate(() => document.activeElement?.id === 'f-go'));
    await p.close();
  }
  {
    const p = await open('/keep-reset');
    await p.evaluate(() => scrollTo(0, 2500));
    await submit(p);
    await p.waitForFunction(() => location.pathname === '/keep-reset' && !document.getElementById('f-go')?.disabled && performance.getEntriesByType('navigation')[0]?.type === 'navigate', null, { timeout: 15_000 });
    await p.waitForTimeout(400);
    const y = await p.evaluate(() => scrollY);
    t.check('data-t-reset starts at the top', y < 100, `${y}`);
    await p.close();
  }

  // The plain post: no bar in the form, no file chosen, a GET form, urlencoded.
  for (const [name, path, prepare, wanted] of [
    ['no bar in the form', '/nobar', async (p) => p.setInputFiles('#f-file', file(50_000)), '/done'],
    ['no file chosen', '/upload', async () => {}, '/done'],
    ['an urlencoded form', '/urlenc', async (p) => p.setInputFiles('#f-file', file(50_000)), '/done'],
  ]) {
    posts.length = 0;
    const p = await open(path);
    await prepare(p);
    await p.click('#f-go', { noWaitAfter: true });
    await p.waitForURL(`**${wanted}`);
    t.check(`${name}: the browser's own navigation posts`, posts.length === 1 && posts[0].dest === 'document' && !posts[0].protocol, JSON.stringify(posts.map((x) => [x.path, x.dest])));
    await p.close();
  }

  // Without JS the form is a plain post and the bar stays hidden.
  {
    posts.length = 0;
    const p = await open('/nojs', { javaScriptEnabled: false });
    t.check('no JS: the bar is hidden', await p.locator('#f-bar').evaluate((b) => b.hidden));
    await p.setInputFiles('#f-file', file(50_000));
    await p.click('#f-go', { noWaitAfter: true });
    await p.waitForURL('**/done');
    t.check('no JS: a plain post', posts.length === 1 && posts[0].dest === 'document', JSON.stringify(posts.map((x) => [x.path, x.dest])));
    await p.close();
  }
  other.close();
});

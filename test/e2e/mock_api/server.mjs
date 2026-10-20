// Deterministic backend for the server fixtures and their checks (no dependencies).
//
//   /api/*   RealWorld (Conduit) API in memory, seeded (johndoe & co.);
//            passes the official RealWorld Hurl API suite.
//   POST /__reset  back to the seed (between runs).
//
// The realworld fixture, its checks and the goldens read the same data with
// the same latency, so pages and timings are reproducible.
//
//   node test/e2e/mock_api/server.mjs [--port 3001] [--latency 20]
import { createServer } from 'node:http';
import { randomBytes } from 'node:crypto';
import { avatar, seed } from './seed.mjs';

const arg = (name, fallback) => {
  const i = process.argv.indexOf(`--${name}`);
  return i > 0 ? process.argv[i + 1] : process.env[`MOCK_${name.toUpperCase()}`] ?? fallback;
};
const port = +arg('port', 3001);
const latency = +arg('latency', 0);

// ---------------------------------------------------------------- RealWorld

let db;
function reset() {
  db = seed();
  db.tokens = new Map(db.users.map((u) => [u.token, u.id]));
}
reset();

class HttpError extends Error {
  constructor(status, errors) {
    super(`${status}`);
    this.status = status;
    this.errors = errors;
  }
}
const fail = (status, field, msg) => {
  throw new HttpError(status, { [field]: [msg] });
};
const blank = (v) => v === undefined || v === null || (typeof v === 'string' && v.trim() === '');
const orNull = (v) => (blank(v) ? null : v);

function currentUser(req, required) {
  const header = req.headers.authorization ?? '';
  const token = header.replace(/^(Token|Bearer)\s+/i, '');
  if (!token) {
    if (required) fail(401, 'token', 'is missing');
    return null;
  }
  const id = db.tokens.get(token);
  if (id === undefined) fail(401, 'token', 'is invalid');
  return db.users.find((u) => u.id === id);
}

const userJson = (u) => ({
  user: { email: u.email, token: u.token, username: u.username, bio: u.bio, image: u.image },
});
const profileJson = (u, viewer) => ({
  username: u.username,
  bio: u.bio,
  image: u.image,
  following: viewer ? db.follows.has(`${viewer.id}>${u.id}`) : false,
});
function articleJson(a, viewer, withBody = true) {
  const out = {
    slug: a.slug,
    title: a.title,
    description: a.description,
    ...(withBody ? { body: a.body } : {}),
    tagList: a.tagList,
    createdAt: a.createdAt,
    updatedAt: a.updatedAt,
    favorited: viewer ? a.favoritedBy.has(viewer.id) : false,
    favoritesCount: a.favoritedBy.size,
    author: profileJson(db.users.find((u) => u.id === a.authorId), viewer),
  };
  return out;
}
const commentJson = (c, viewer) => ({
  id: c.id,
  createdAt: c.createdAt,
  updatedAt: c.updatedAt,
  body: c.body,
  author: profileJson(db.users.find((u) => u.id === c.authorId), viewer),
});

const findArticle = (slug) => db.articles.find((a) => a.slug === slug) ?? fail(404, 'article', 'not found');
const findProfile = (name) => db.users.find((u) => u.username === name) ?? fail(404, 'profile', 'not found');

let clock = 0;
/** ISO time, strictly increasing (an update always changes updatedAt). */
function now() {
  clock = Math.max(Date.now(), clock + 1);
  return new Date(clock).toISOString();
}

function slugify(title) {
  const base = title
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[^\w\s-]/g, '')
    .trim()
    .replace(/[\s_-]+/g, '-')
    .slice(0, 80) || 'article';
  let slug = base;
  for (let n = 2; db.articles.some((a) => a.slug === slug); n++) slug = `${base}-${n}`;
  return slug;
}

function list(req, query, feed) {
  const viewer = currentUser(req, feed);
  let rows = db.articles;
  if (feed) rows = rows.filter((a) => db.follows.has(`${viewer.id}>${a.authorId}`));
  const tag = query.get('tag');
  const author = query.get('author');
  const favorited = query.get('favorited');
  if (tag) rows = rows.filter((a) => a.tagList.includes(tag));
  if (author) rows = rows.filter((a) => db.users.find((u) => u.id === a.authorId)?.username === author);
  if (favorited) {
    const fan = db.users.find((u) => u.username === favorited);
    rows = fan ? rows.filter((a) => a.favoritedBy.has(fan.id)) : [];
  }
  rows = [...rows].sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  const limit = Math.max(0, +(query.get('limit') ?? 20) || 20);
  const offset = Math.max(0, +(query.get('offset') ?? 0) || 0);
  return {
    articles: rows.slice(offset, offset + limit).map((a) => articleJson(a, viewer, false)),
    articlesCount: rows.length,
  };
}

function validPassword(p, { min }) {
  if (blank(p) || typeof p !== 'string') fail(422, 'password', "can't be blank");
  if (p.length < min) fail(422, 'password', `is too short (minimum is ${min} characters)`);
}

async function realworld(req, path, query, body) {
  const m = req.method;
  let r;
  // users
  if (m === 'POST' && path === '/users') {
    const { username, email, password } = body.user ?? {};
    if (blank(username)) fail(422, 'username', "can't be blank");
    if (blank(email)) fail(422, 'email', "can't be blank");
    validPassword(password, { min: 1 });
    if (db.users.some((u) => u.username === username)) fail(409, 'username', 'has already been taken');
    if (db.users.some((u) => u.email === email)) fail(409, 'email', 'has already been taken');
    const u = { id: ++db.ids.user, username, email, password, bio: null, image: null, token: randomBytes(18).toString('base64url') };
    db.users.push(u);
    db.tokens.set(u.token, u.id);
    return [201, userJson(u)];
  }
  if (m === 'POST' && path === '/users/login') {
    const { email, password } = body.user ?? {};
    if (blank(email)) fail(422, 'email', "can't be blank");
    if (blank(password)) fail(422, 'password', "can't be blank");
    const u = db.users.find((x) => x.email === email && x.password === password);
    if (!u) fail(401, 'credentials', 'invalid');
    return [200, userJson(u)];
  }
  if (path === '/user') {
    const u = currentUser(req, true);
    if (m === 'GET') return [200, userJson(u)];
    if (m === 'PUT') {
      const patch = body.user ?? {};
      if ('username' in patch) {
        if (blank(patch.username)) fail(422, 'username', "can't be blank");
        if (db.users.some((x) => x !== u && x.username === patch.username)) fail(409, 'username', 'has already been taken');
      }
      if ('email' in patch) {
        if (blank(patch.email)) fail(422, 'email', "can't be blank");
        if (db.users.some((x) => x !== u && x.email === patch.email)) fail(409, 'email', 'has already been taken');
      }
      if ('password' in patch) validPassword(patch.password, { min: 8 });
      if ('username' in patch) u.username = patch.username;
      if ('email' in patch) u.email = patch.email;
      if ('password' in patch) u.password = patch.password;
      if ('bio' in patch) u.bio = orNull(patch.bio);
      if ('image' in patch) u.image = orNull(patch.image);
      return [200, userJson(u)];
    }
  }
  // profiles
  if ((r = path.match(/^\/profiles\/([^/]+)(\/follow)?$/))) {
    const name = decodeURIComponent(r[1]);
    if (!r[2] && m === 'GET') {
      const viewer = currentUser(req, false);
      return [200, { profile: profileJson(findProfile(name), viewer) }];
    }
    if (r[2] && (m === 'POST' || m === 'DELETE')) {
      const viewer = currentUser(req, true);
      const target = findProfile(name);
      const key = `${viewer.id}>${target.id}`;
      if (m === 'POST') db.follows.add(key);
      else db.follows.delete(key);
      return [200, { profile: profileJson(target, viewer) }];
    }
  }
  // tags
  if (m === 'GET' && path === '/tags') {
    const count = new Map();
    for (const a of db.articles) for (const t of a.tagList) count.set(t, (count.get(t) ?? 0) + 1);
    const tags = [...count].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])).map(([t]) => t);
    return [200, { tags }];
  }
  // articles
  if (path === '/articles' && m === 'GET') return [200, list(req, query, false)];
  if (path === '/articles/feed' && m === 'GET') return [200, list(req, query, true)];
  if (path === '/articles' && m === 'POST') {
    const viewer = currentUser(req, true);
    const { title, description, body: text, tagList = [] } = body.article ?? {};
    if (blank(title)) fail(422, 'title', "can't be blank");
    if (blank(description)) fail(422, 'description', "can't be blank");
    if (blank(text)) fail(422, 'body', "can't be blank");
    if (!Array.isArray(tagList)) fail(422, 'tagList', 'must be an array');
    const at = now();
    const a = {
      id: ++db.ids.article, slug: slugify(title), title, description, body: text,
      tagList: [...new Set(tagList.filter((t) => typeof t === 'string' && t.trim()).map((t) => t.trim()))],
      createdAt: at, updatedAt: at, authorId: viewer.id, favoritedBy: new Set(),
    };
    db.articles.push(a);
    return [201, { article: articleJson(a, viewer) }];
  }
  if ((r = path.match(/^\/articles\/([^/]+)$/))) {
    const slug = decodeURIComponent(r[1]);
    if (m === 'GET') {
      const viewer = currentUser(req, false);
      return [200, { article: articleJson(findArticle(slug), viewer) }];
    }
    if (m === 'PUT' || m === 'DELETE') {
      const viewer = currentUser(req, true);
      const a = findArticle(slug);
      if (a.authorId !== viewer.id) fail(403, 'article', 'forbidden');
      if (m === 'DELETE') {
        db.articles = db.articles.filter((x) => x !== a);
        db.comments = db.comments.filter((c) => c.articleId !== a.id);
        return [204, null];
      }
      const patch = body.article ?? {};
      for (const f of ['title', 'description', 'body']) {
        if (f in patch && blank(patch[f])) fail(422, f, "can't be blank");
      }
      if ('tagList' in patch && !Array.isArray(patch.tagList)) fail(422, 'tagList', 'must be an array');
      for (const f of ['title', 'description', 'body']) if (f in patch) a[f] = patch[f];
      if ('tagList' in patch) a.tagList = [...new Set(patch.tagList)];
      a.updatedAt = now();
      return [200, { article: articleJson(a, viewer) }];
    }
  }
  if ((r = path.match(/^\/articles\/([^/]+)\/favorite$/)) && (m === 'POST' || m === 'DELETE')) {
    const viewer = currentUser(req, true);
    const a = findArticle(decodeURIComponent(r[1]));
    if (m === 'POST') a.favoritedBy.add(viewer.id);
    else a.favoritedBy.delete(viewer.id);
    return [200, { article: articleJson(a, viewer) }];
  }
  if ((r = path.match(/^\/articles\/([^/]+)\/comments(?:\/([^/]+))?$/))) {
    const slug = decodeURIComponent(r[1]);
    if (!r[2] && m === 'GET') {
      const viewer = currentUser(req, false);
      const a = findArticle(slug);
      const rows = db.comments
        .filter((c) => c.articleId === a.id)
        .sort((x, y) => y.createdAt.localeCompare(x.createdAt) || y.id - x.id);
      return [200, { comments: rows.map((c) => commentJson(c, viewer)) }];
    }
    if (!r[2] && m === 'POST') {
      const viewer = currentUser(req, true);
      const a = findArticle(slug);
      const text = body.comment?.body;
      if (blank(text)) fail(422, 'body', "can't be blank");
      const at = now();
      const c = { id: ++db.ids.comment, articleId: a.id, authorId: viewer.id, body: text, createdAt: at, updatedAt: at };
      db.comments.push(c);
      return [201, { comment: commentJson(c, viewer) }];
    }
    if (r[2] && m === 'DELETE') {
      const viewer = currentUser(req, true);
      const a = findArticle(slug);
      const c = db.comments.find((x) => x.articleId === a.id && String(x.id) === r[2]) ?? fail(404, 'comment', 'not found');
      if (c.authorId !== viewer.id) fail(403, 'comment', 'forbidden');
      db.comments = db.comments.filter((x) => x !== c);
      return [204, null];
    }
  }
  fail(404, 'route', 'not found');
}

// -------------------------------------------------------------------- server

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  if (req.method === 'OPTIONS') return res.writeHead(204).end();

  const img = url.pathname.match(/^\/img\/([\w-]+)\.svg$/);
  if (img) {
    res.writeHead(200, { 'Content-Type': 'image/svg+xml', 'Cache-Control': 'public, max-age=31536000' });
    return res.end(avatar(img[1]));
  }

  let text = '';
  for await (const chunk of req) text += chunk;
  let status;
  let payload;
  try {
    if (req.method === 'POST' && url.pathname === '/__reset') {
      reset();
      [status, payload] = [200, { ok: true }];
    } else if (url.pathname.startsWith('/api/')) {
      let body = {};
      if (text) {
        try {
          body = JSON.parse(text) ?? {};
        } catch {
          fail(422, 'body', 'is not valid JSON');
        }
      }
      [status, payload] = await realworld(req, url.pathname.slice(4), url.searchParams, body);
    } else {
      [status, payload] = [404, { error: 'not found' }];
    }
  } catch (e) {
    if (!(e instanceof HttpError)) console.error(e);
    [status, payload] = e instanceof HttpError ? [e.status, { errors: e.errors }] : [500, { errors: { server: ['error'] } }];
  }
  if (latency) await sleep(latency);
  if (payload === null && status === 204) return res.writeHead(204).end();
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(payload));
}).listen(port, () => console.log(`mock api on http://localhost:${port} (latency ${latency} ms)`));

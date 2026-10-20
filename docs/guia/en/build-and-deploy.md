# Build and deploy

Deploy your app as a static site, with the HTML already rendered, or as a Dart server that renders each request.

:::flutter Flutter: `flutter build web` · Thor: `thor export` or `thor build`

## Choose

Routes, widgets and styles are the same in both modes; what changes is when `load` runs.

```bash
thor export --base-url https://my-site.com   # static site → build/site
thor build                                   # server      → build/server
```

| Criterion | Static site | Server |
|---|---|---|
| For | documentation, landing pages, blogs and portfolios | apps with sessions, data that changes often and forms that save data |
| When `load` runs | once, at export time | on every request (or according to `cache`) |
| Form actions | no | yes |
| Where it's deployed | any file hosting | anywhere that runs a binary or a container |

Start with a [route table](navigation.md): it works for both modes, and moving from static to server doesn't force you to rewrite pages.

## Static site

`thor export` requests each route from the same handler the server would use and writes the result to `build/site`. The `bin/export.dart` file declares which routes exist:

```dart no-check
// bin/export.dart
import 'dart:io';

import 'package:my_site/handler.dart';
import 'package:thor_server/thor_server.dart';

Future<void> main(List<String> args) async {
  final report = await exportSite(
    siteHandler(), // the server's same RouteHandler
    paths: ['/', '/pricing', for (final p in posts) '/blog/${p.slug}'],
    outDir: 'build/site',
    baseUrl: args.length > 1 ? args[1] : null, // https://my-site.com
    notFoundPath: '/__missing__',
    staticDir: 'web',
  );
  exit(report.ok ? 0 : 1);
}
```

```bash
thor export --base-url https://my-site.com
thor preview   # serves build/site like a hosting would
```

When exporting:

- each route is a file (`/` → `index.html`, `/pricing` → `pricing.html`) and `notFoundPath` produces the `404.html` that hosts show for anything that doesn't exist;
- with `--base-url`, you also get `sitemap.xml` and `robots.txt`;
- the export fails, listing every problem, if a page doesn't respond `200` or if an internal link doesn't lead to an exported page, a file in `web/` or an existing `#anchor`.

An exported site keeps everything native (dialogs, menus, accordions, dark theme) and the ViewModels of its pages. Upload `build/site` to any static host: Netlify, Cloudflare Pages, GitHub Pages, Firebase Hosting, Vercel, S3 or nginx.

> **Important:** `load` runs only once, at export time: data that changes afterwards doesn't show up until you export and deploy again.

### A single page

An app without routes is a single page and doesn't need `bin/export.dart`:

```dart
// lib/main.server.dart
void main() {
  initializeThor(styles: const []);
  runApp(const Document(title: 'Counter', body: ThorApp(child: Counter())));
}
```

`thor build` renders it into `build/site` and shows its size (`7.5 KB html, 0.0 KB js (gzip)`).

## Server

For an app with `bin/server.dart`, `thor build` compiles a native executable: production doesn't need the Dart SDK.

```bash
thor build               # → build/server, build/public and build/run.sh
thor preview             # runs it at http://localhost:4400
PORT=8080 build/server   # in production
```

What you deploy is `build/server` together with `build/public` and `build/images.json`, plus `build/resources` when a pubspec declares `thor: resources:` or `thor: sdk:` ([CLI](cli.md#thor-build); the `Dockerfile` of `thor deploy init` copies it). The variables declared in `lib/env.dart` are configured on the host; if one is missing, the server doesn't start and names it ([Session and security](session-and-security.md#environment-and-secrets)).

| Variable | What it does |
|---|---|
| `PORT` | the port; the `thor create` template reads it from there, as Fly, Railway and Render expect |
| `SECURE_COOKIES` | `true` forces `Secure` on cookies and `false` removes it; when unset, it follows the request (HTTPS or `X-Forwarded-Proto`) |
| `ISOLATES` | how many isolates; by default one per core, up to 4 |
| `DART_VM_OPTIONS` | VM options; `build/run.sh` and the `Dockerfile` include the ones needed with more than 4 isolates |

- **Health:** `GET /_thor/health` responds `200 {"status":"ok"}` while the server is serving and `503` while shutting down. `ThorServer(healthPath: null)` disables it.
- **Graceful shutdown:** on `SIGTERM` or Ctrl-C, the server stops accepting connections, finishes in-flight requests (up to `shutdownTimeout`, 8 s) and exits.
- **Compression:** the server gzips HTML and text files. For Brotli, put a CDN or a proxy in front that does it (Caddy, nginx, Cloudflare).
- **Page cache:** a page with `cache:` shares its HTML across requests without a session ([Server and actions](server-and-actions.md#caching-and-metadata)).
- **Behind a CDN:** a `LazyPiece` requests its part on the same route with `?thor-piece=<id>`. Configure the CDN to include `thor-piece` in its cache key.

## `thor deploy init`

`thor deploy init` writes into your project the configuration each host requires and deploys nothing: you review the files, push them with your repository and deploy with the host's tool. It doesn't replace an existing file (`--force` does) and prints the next commands along with the `lib/env.dart` variables you need to configure.

```bash
thor deploy init fly          # in the app's folder
thor deploy init docker shop  # or naming the app
```

An app with a server is deployed as a container: `docker`, `fly`, `railway` and `render` use the same image. The `Dockerfile` has two stages: the first compiles with `thor build` on Linux and the final one contains only the executable, `build/public`, the image manifest and `deploy/healthcheck.dart`, running as an unprivileged user.

:::tabs
@tab Docker
```bash
thor deploy init docker
docker build -f Dockerfile -t shop .   # in a monorepo: -f services/shop/Dockerfile, from the root
docker run -p 8080:8080 -e API_URL=https://… shop
```
Docker marks the container as `healthy` when `/_thor/health` responds, and `docker stop` waits for in-flight requests to finish.
@tab Fly.io
```bash
thor deploy init fly
fly secrets set SESSION_SECRET=…   # the secrets of your lib/env.dart
fly deploy
```
`fly.toml` exposes port 8080 with forced HTTPS, checks `/_thor/health`, stops machines with no traffic and allows 10 s for graceful shutdown.
@tab Railway
```bash
thor deploy init railway
```
Create a service from the repository. `railway.json` points to the `Dockerfile` and the health check; Railway sets `PORT`. In a monorepo, set the path to `railway.json` in the service settings.
@tab Render
```bash
thor deploy init render
```
`render.yaml` is a Blueprint (New → Blueprint in Render): a Docker web service, the health check and your variables listed. Render reads it from the repository root.
:::

A static site is deployed as files: `cloudflare-pages`, `vercel` and `netlify` deploy `build/site`. All three get `deploy/build.sh` (it runs `thor build`, or `thor export` if there is a `bin/export.dart`, and asks for `SITE_URL` for the sitemap) and that host's cache rules. Their build environments don't include Dart: build on your machine or in CI and upload the folder.

:::tabs
@tab Cloudflare Pages
```bash
thor deploy init cloudflare-pages
sh deploy/build.sh
npx wrangler pages deploy
```
@tab Vercel
```bash
thor deploy init vercel
sh deploy/build.sh   # copies deploy/vercel.json to build/site
vercel deploy build/site --prod
```
@tab Netlify
```bash
thor deploy init netlify
sh deploy/build.sh
netlify deploy --prod --dir build/site
```
:::

JavaScript function hosts (Cloudflare Workers, Vercel Functions, Netlify Functions, AWS Lambda) don't run a Dart server: `thor deploy init` says so ([THOR-B017](../../errores/en/THOR-B017.md)) and suggests a container or a static site.

## Browser cache

`thor build` and `thor export` rename every file a page requests (the ViewModels script, images, fonts) with a hash of its content. That way a page always loads the files it was built with, and an open page whose files no longer exist reloads itself once. Files that others request by name are not renamed: `favicon*`, `apple-touch-icon*`, `og*`, `robots.txt`, `manifest` and `sitemap`.

For a deploy to show up immediately, the host must revalidate the HTML and cache hashed files forever:

:::tabs
@tab Netlify / Cloudflare
The build writes `build/site/_headers` with these rules, `/_thor/*` included, and keeps yours.
@tab Firebase
```jsonc
// firebase.json
"headers": [
  { "source": "**/*.html", "headers": [{ "key": "Cache-Control", "value": "no-cache" }] },
  { "source": "/_thor/**", "headers": [{ "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }] },
  { "regex": ".*\\.[0-9a-f]{8}\\.[a-z0-9]+$",
    "headers": [{ "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }] }
]
```
@tab Vercel
```jsonc
// vercel.json
{ "headers": [
  { "source": "/(.*).html", "headers": [{ "key": "Cache-Control", "value": "no-cache" }] },
  { "source": "/_thor/(.*)", "headers": [{ "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }] },
  { "source": "/(.*)\\.([0-9a-f]{8})\\.(js|png|jpg|webp|avif|woff2|svg|css)",
    "headers": [{ "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }] } ] }
```
@tab nginx
```nginx
location ~* \.[0-9a-f]{8}\.[a-z0-9]+$ { add_header Cache-Control "public, max-age=31536000, immutable"; }
location /_thor/                        { add_header Cache-Control "public, max-age=31536000, immutable"; }
location ~* \.html$                     { add_header Cache-Control "no-cache"; }
```
@tab S3 + CloudFront
Upload hashed files with `--cache-control "public, max-age=31536000, immutable"` and `.html` files with `--cache-control "no-cache"`.
:::

The Thor server already responds this way for files in `web/`: `immutable` for hashed names and `ETag` for the rest.

## Shared styles

By default, each page carries its styles inline. On a site where users visit many pages, `share_styles` moves the styles they share into a stylesheet the browser caches ([Advanced styles](advanced-styles.md#stylesheets-by-level)). The first visit pays for one extra request before showing the page, which is why it's off by default.

```yaml
# pubspec.yaml
thor:
  share_styles: true
```

## Before deploying

- [ ] `thor doctor` reports no problems and `thor test` passes ([Testing](testing.md)).
- [ ] `thor preview` shows the site or the server as in production.
- [ ] Every page has its own title and description ([SEO](seo.md)).
- [ ] Pages work with JavaScript disabled.
- [ ] The host's cache rules are configured.
- [ ] With a server: `/_thor/health` responds `200` and the `lib/env.dart` variables are set on the host.

## Next steps

:::cards
- [SEO](seo.md) — title, preview and sitemap for each page
- [Session and security](session-and-security.md) — environment, secrets and Content-Security-Policy
- [The thor command](cli.md#thor-export) — `thor export` and `thor build` with their options
:::

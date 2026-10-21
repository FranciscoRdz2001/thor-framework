# Session and security

Protect your app: a signed session cookie, form origin checks, secrets in the environment, rate limiting and security headers.

Thor covers part of it by default; you declare the rest:

| Topic | What Thor does | What you write |
|---|---|---|
| CSRF | accepts a `POST` only if its `Origin` is the site's own | `trustedOrigins` if another site of yours submits forms |
| HTML | all text is text, never interpreted as HTML | do not insert HTML from a user ([Pub packages](pub-packages.md#markdown)) |
| Actions, queries and commands | run after the page's middleware and guards | authorize what they read or write |
| Browser arguments | arrive with their type or respond `400` | check that the user may modify that `id` |
| Secrets | a `Secret` is never printed or serialized | do not put them in a page or a ViewModel |
| Static files | does not serve hidden files or `.map` files in production | do not put secrets in `web/` |

## Security headers

`securityHeaders` adds `X-Content-Type-Options`, `Referrer-Policy`, `X-Frame-Options`, `Cross-Origin-Opener-Policy` and a `Permissions-Policy` that disables camera, microphone and geolocation to every response in the group. With `hsts`, the browser uses only HTTPS for that long.

```dart
Group(
  middleware: [securityHeaders(hsts: const Duration(days: 365))],
  children: [homeRoute, accountRoute],
)
```

For them to also reach static files, the health check and global errors, pass them to the server:

```dart
ThorServer(
  handler: handler,
  publicDir: ThorServer.appPublicDir(),
  securityHeaders: const SecurityHeaders(hsts: Duration(days: 365)),
)
```

A header the response already carries is not replaced.

## Content-Security-Policy

`contentSecurityPolicy` sets a typed policy and a fresh nonce on every request. Every `<script>` and `<style>` that Thor emits (including yours via `html.script` and those of the parts that arrive later) carries that nonce, so the policy does not need `'unsafe-inline'`.

```dart
Group(
  middleware: [
    contentSecurityPolicy(
      ContentSecurityPolicy(
        imgSrc: [CspSource.self, CspSource.data, CspSource.host('https://cdn.example.com')],
        reportOnly: true, // reports without blocking; remove it when there are no reports
        reportUri: Uri.parse('/csp-report'),
      ),
    ),
  ],
  children: [homeRoute],
)
```

- A `<script>` that arrives as text (a `RawText`, a markdown renderer) gets no nonce, and the policy blocks it.
- The `style` attributes Thor writes are allowed by `style-src-attr 'unsafe-inline'`, which never allows `<style>` elements.
- Event attributes (`oninput`, `onclick`…) do not support a nonce. To keep them: `scriptSrcAttr: [CspSource.unsafeHashes, ...CspSource.thorHandlers]`.
- In a hand-written response, `request.cspNonce` is the nonce.
- A page with a nonce goes out without an `ETag` and with `Cache-Control: private`: do not put it behind a shared cache. For a public page (`cacheControl:`), use hashes instead of the nonce:

```dart no-check
contentSecurityPolicy(const ContentSecurityPolicy(nonce: false, hashes: true))
```

  With `hashes: true` the header lists the SHA-256 of each inline `<script>` and `<style>` of the finished page, so the body is the same for everyone: it keeps its `ETag` and its `public` cache. The price: the middleware reads the whole body (a page that streams its deferred values goes out whole), and a `<style>` or `<script>` that arrives later in the fragment of a lazy piece is not in the header. A page that changes on every request is not for this mode.
- The policy covers the group's pages, not static files or global errors.

A static site has no server to set a nonce. Each piece of Thor's inline code is constant and is allowed by its hash in `script-src`; event attributes also require `'unsafe-hashes'`. Without its hash, each one degrades without breaking the page:

| Feature | What it does | Without it |
|---|---|---|
| `TextField(maxLength:)` | `oninput`: updates the counter | the counter stays at the initial count |
| `Image(errorBuilder:)` | `onerror`: shows the fallback | the fallback does not appear |
| `Image(loadingBuilder:)` | `onload`: removes the loading placeholder | the loading placeholder stays |
| `Popover`, `MenuAnchor` with `closeOnNavigate` | `onclick`: closes on navigation | they do not close on navigation |
| `Drawer` with `closeOnNavigate` | `onclick`: closes on navigation | it does not close on navigation |
| `FutureBuilder` with `defer` | places the data that arrives later | the data arrives, but the skeletons remain |
| `LazyPiece`, `Region`, `LoadMore`, `Form(live:)`, `Link(fetch:)` | requests the part on demand and puts it in place | the part is not requested; the links and the form work as plain HTML |
| `ExpansionTile(permanentFrom:)` | removes the header from the Tab order from the breakpoint | the header still receives focus with Tab |
| `Form` | submit state, focus on the first error, preserved position | the form submits without those three things |
| `LinearProgressIndicator.upload()` | shows the upload progress | there is no bar; the form still submits |
| `Form(stay: true)`, `FileField(submitOnChange: true)` | submits the form without leaving the page, or when files are chosen | the form submits the normal way and the next page shows the message |
| `darkTheme` | remembers the chosen light or dark theme | the choice is not remembered across pages |
| Link prefetching in Firefox and Safari | loads the fallback prefetch | those browsers do not prefetch |
| `PageTransition.slide` | reverses the direction when going back | the transition always moves forward |

The hashes, in the same order as the table, for the hosting's `Content-Security-Policy` header:

```text
script-src 'self' 'unsafe-hashes'
  'sha256-d1k8y4HZiUcsRf7/fSwzLY3eloLLZikspOpQ2YrXhHs='
  'sha256-yMxl8xCTUafbfCLCfCzjwjSLtzTIs2YxOZEF/a/1y/M='
  'sha256-8bvL4iOwjjseCopvPb3HpKMRh3VhhhOLSaXO6KWVG7c='
  'sha256-L/gjp/lXf1b++Z++rgw+P1gwp3nzVwoiQxErAc/1Brc='
  'sha256-RyS7b/uVe1C+1Gd8n4HR1kH+n+01SmpZRn+mOR9CJUk='
  'sha256-Mxg6UhxGzKjB5ugabTWXccqT/DAbMskkZQEV7uRLGC0='
  'sha256-aZxydF34Vcd1+QjPpaARaxSaXzfpcIPoFZjbxvGjBos='
  'sha256-tiaf4Ty5SJfKEBWPKh/B6ZKlL80Xn7N9K+Q1zZFqvy4='
  'sha256-zlm6MXXoeDrl6SMrFRQc7NRm+ZLmsHjlpTuOW4kCA9g='
  'sha256-Asckod0Qy5jICUwq+JiuJxRdh6mNnBMYtL2+X0M9imE='
  'sha256-iXlGGEvhMoI+078S7Itq+JPK7xMdbE8uvolspVmGsuc='
  'sha256-aDxpB7mloHYVrqMV+HWFEAdeclRvWIRgIUucid0L9GI='
  'sha256-+vjJOlGdlPgTbJrnHZFLodugWUckeEMjYbDKn3UzboI='
  'sha256-B07+DJJ+zTmWcS+ikeNI2qf05ksFMdwClL0hweHfXo8='
```

`ThorApp(engineLoading: EngineLoading.eager)` loads the ViewModels script without inline code. Link prefetching (`PageNavigation`) puts a `<script type="speculationrules">` on every page; with a server, `PageNavigation(delivery: SpeculationDelivery.header)` sends the rules in a header, and `ThorPage(prefetch: false)` excludes a page whose `GET` is expensive.

### Analytics and tag manager snippets

A snippet that has to run in the `<head>` (Google Tag Manager, Clarity, a gtag config) goes in `WidgetRenderer(head:)` as `html.script`. Both the loader (`src:`) and the inline code (`content:`) get the request's nonce, and the policy only needs the hosts the snippet loads from or reports to.

```dart no-check
WidgetRenderer(
  head: [
    html.script(src: 'https://www.googletagmanager.com/gtag/js?id=G-XXXX', async: true),
    html.script(content: "window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments)}gtag('js',new Date());gtag('config','G-XXXX');"),
  ],
  ...
)

contentSecurityPolicy(
  ContentSecurityPolicy(
    scriptSrc: [CspSource.host('https://www.googletagmanager.com')],
    connectSrc: [CspSource.host('https://www.google-analytics.com')],
  ),
)
```

A snippet that injects more scripts from the first one (Tag Manager does) needs `CspSource.strictDynamic` in `scriptSrc`.

## Host and public origin

In production, declare which domains the server responds to. Any other `Host` responds `400` before reaching a page, so a forged `Host` never ends up in links, the cache or emails.

```dart
ThorServer(
  handler: handler,
  allowedHosts: ['example.com', '*.example.com'], // `*.` = subdomains
  publicOrigin: Uri.parse('https://example.com'),
)
```

With `publicOrigin`, the app always sees that origin: `og:url`, canonicals, the sitemap, redirects, the forms' `Origin` check and cache keys use it, and cookies go out with `Secure`. It implies a single public origin: in an app with several subdomains, use only `allowedHosts`.

Behind a proxy only `Host` is checked; `X-Forwarded-Host` is ignored. If your proxy rewrites `Host` to an internal name, configure it to keep the public one (nginx: `proxy_set_header Host $host;`) or declare `publicOrigin`. `thor dev` ignores both settings, and the health check responds to any host.

## Signed cookie

`SignedCookies` signs a value with HMAC-SHA256: the browser can read it but cannot change it. The signature includes the time, and the server checks `maxAge`: a stolen cookie stops working when it expires, even if the browser keeps it.

```dart
final session = SignedCookies(
  env.secret, // 32 bytes or more, outside the repo
  purpose: 'session',
  maxAge: const Duration(days: 30),
);

request.response.setCookie('session', session.sign(jsonEncode(account)),
    maxAge: const Duration(days: 30));
final user = session.verify(request.cookies['session']); // null if it expired
```

| Parameter | What it does |
|---|---|
| `purpose` | what the value is for; a cookie signed for another purpose does not verify |
| `maxAge` | maximum age of the value; `null` never expires (do not use it for sessions) |
| `previousSecrets` | keys from before a rotation: they only verify, never sign |
| `clock` | the clock for tests |

If one secret signs more than one cookie, give each its own `purpose`: without it, a value signed for a notice would be accepted as a session. With `purpose: 'session'` and no `maxAge`, `thor dev` warns ([THOR-P033](../../errores/en/THOR-P033.md)).

### Rotating the key

Sign with the new key and verify with all of them: nobody loses their session on rotation, and each cookie keeps its expiry.

```dart
final session = SignedCookies(
  newSecret,
  previousSecrets: [oldSecret], // remove it when its cookies expire
  maxAge: const Duration(days: 30),
);
```

## Sign-in

After signing in, the app sends the user back to the page they requested. That address comes from the browser and must be validated.

### Returning to where they were going

`safeNext` returns the destination only if it is a route on this site; otherwise, `fallback`. An unvalidated `?next=https://other.site` is an open redirect: always use it before redirecting to an address the browser sent.

```dart
Future<ActionResult?> signIn(PageRequest request) async {
  final form = await request.form();
  // ... check the password ...
  return Redirect(safeNext(request, form['next'], fallback: const RouteUrl('/account')));
}
```

| Input | Result |
|---|---|
| `/cart?a=1#top` | as is |
| `https://your.site/cart` (same origin) | `/cart` |
| `https://other.site/x`, `//other.site`, `/\other.site`, `javascript:…` | `fallback` |
| `/%2F/other.site`, double encoding, line breaks | `fallback` |

### Redirecting to sign-in

A Repository throws `HttpError(401)` when the backend does not recognize the session ([Data layer](data-layer.md#backend-errors-to-the-page)). `signInOn401` in the group's middleware turns that 401 into a redirect to sign-in, with the requested page in `?next=`.

```dart
Group(
  middleware: [session, signInOn401('/login')],
  children: [ordersRoute],
)
// A load that throws HttpError(StatusCode.unauthorized) ends at /login?next=%2Forders
```

A query or a command that receives the 401 responds with JSON containing `redirect`. Other statuses (403, 404…) do not change.

## Rate limiting

`RateLimit` counts attempts per key within a fixed window. As a group's middleware, once the limit is exceeded it responds `429` with `Retry-After`: an error page, or JSON (`{error, retryAfter}`) for a query or a command.

```dart
final loginLimit = RateLimit(max: 10, window: const Duration(minutes: 15));

Group(middleware: loginLimit.middleware(), children: [loginRoute]);
```

Inside an action, to show the form with a message and also limit per account:

```dart
final limited = await loginLimit.limit(
  request,
  key: 'login:${email.toLowerCase()}',
  data: {'error': 'Too many attempts. Try again in a few minutes.'},
);
if (limited != null) return limited; // 429 + Retry-After
```

| Parameter | What it does |
|---|---|
| `max`, `window` | attempts per key and window length |
| `key` | a request's key (`RateLimit.clientIp` by default); `null` does not limit |
| `trustedProxies` | how many proxies in front of the server append to `X-Forwarded-For` (0 by default) |
| `store` | where the counters live (`RateLimitStore`) |
| `reset(key)` | forgets a key after a successful sign-in; use it with the account key, never with the IP key |

`X-Forwarded-For` is written by the client: by default it is ignored and the key is the connection's address. Behind a proxy, state how many there are with `trustedProxies: 1`; without a proxy that rewrites the header, do not enable it.

> **Important:** The default store lives in each isolate's memory. With several isolates or several instances, each one counts separately. For a strict limit, implement `RateLimitStore` on a shared store (Redis `INCR` and `EXPIRE`) with an atomic `increment`.

## Environment and secrets

The app's environment variables (the API URL, the session secret, the port) are declared once, with their type, in `lib/env.dart`. The server checks them at startup and, if any is missing, does not start and lists them all ([THOR-P011](../../errores/en/THOR-P011.md)).

```dart
// lib/env.dart
import 'package:thor_server/thor_server.dart';

abstract final class AppEnv {
  static const api = EnvUrl('API_URL', fallback: 'https://api.example.com');
  static const port = EnvInt('PORT', fallback: 4300);
  static const title = EnvString('SITE_TITLE', public: true);
  static const session = EnvSecret('SESSION_SECRET', minLength: 32);
  static const isolates = EnvOptional(EnvInt('ISOLATES'));
  static const schema = EnvSchema([api, port, title, session, isolates]);
}
```

```dart
// bin/server.dart: first of all
final env = AppEnv.schema.load();
final api = env.of(AppEnv.api); // a Uri
```

`thor create` generates `lib/env.dart` and adds `.env` to `.gitignore`. `load()` only reads what is in `EnvSchema([...])`; the editor flags a declared variable missing from the list (`env_var_not_in_schema`).

| Type | Reads | Example |
|---|---|---|
| `EnvString` | a text | `SITE_TITLE=My shop` |
| `EnvInt` | an integer | `PORT=4300` |
| `EnvBool` | `true`/`false`, `1`/`0`, `yes`/`no` | `SECURE_COOKIES=true` |
| `EnvUrl` | an `http` or `https` URL with a host, as a `Uri` | `API_URL=https://api.example.com` |
| `EnvSecret` | a secret, with no default value and a minimum length | `SESSION_SECRET=…` |
| `EnvOptional(x)` | the same as `x`, or `null` if it is not set | `ISOLATES=4` |

An empty value counts as missing. Only what you mark with `public: true` is public: `env.public` gives those variables, the only ones you can put in a page or pass to a ViewModel. A secret is never public.

:::compare
```dart
// WRONG (THOR-P012): the secret in the page
Text('key: ${env.of(AppEnv.session).reveal()}')
```
```dart
// RIGHT: only the public part reaches the page
Text(env.public['SITE_TITLE'] ?? '')
```
:::

A `Secret` is read with `reveal()`; printing it shows `***`, and `jsonEncode` fails. With `thor dev`, a response containing a secret's value is a `500` ([THOR-P012](../../errores/en/THOR-P012.md)), and `thor export` stops if an exported page contains it.

`thor dev` and `thor preview` start the server with the variables from the app's `.env` file; a variable from the real environment takes precedence. In production, configure them in the hosting ([Build and deploy](build-and-deploy.md#server)).

## Next steps

:::cards
- [Build and deploy](build-and-deploy.md) — environment variables in the hosting
- [Server and actions](server-and-actions.md) — actions and arguments
- [Forms](forms.md) — validation in the browser and on the server
:::

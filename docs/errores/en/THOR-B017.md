# THOR-B017 · A deploy target that does not apply to this app

**Where:** `thor_cli` · `thor deploy init <target>`.

## What happened

The target cannot serve this app, or its image cannot be built:

- a server target (`docker`, `fly`, `railway`, `render`) for a static site (without `bin/server.dart`);
- a file host (`cloudflare-pages`, `vercel`, `netlify`) for an app with a server that is not exported (without `bin/export.dart`);
- a JavaScript functions host (`cloudflare-workers`, `vercel-functions`, `netlify-functions`, `lambda`): they do not run a Dart server;
- `thor_ui` comes from a folder (`path:`) outside what the Docker image sees.

## Why

A Thor app with a server is a native executable that listens on a port: it needs a container. A static site is files: it needs a file host with the right caches. The Docker image is built with what is inside the build context: a dependency outside it does not exist there.

## How to fix it

```bash
# WRONG: a Dart server on JavaScript functions
thor deploy init cloudflare-workers
```

```bash
# RIGHT: the server in a container…
thor deploy init fly
# …or the exported site on a static file host (with bin/export.dart)
thor deploy init cloudflare-pages
```

If `thor_ui` comes from a folder outside the project, take Thor from git (`thor create --git <url>`) or build from a folder that contains both.

[All codes](README.md)

// Where an app lives, by name: the site (apps/) or the fixtures of the
// framework checks (test/fixtures/apps/). Paths are relative to the repository root.
import { existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

export const APP_ROOTS = ['apps', 'test/fixtures/apps'];
const repo = fileURLToPath(new URL('..', import.meta.url));

export function appDir(name, root = repo) {
  for (const r of APP_ROOTS) if (existsSync(join(root, r, name, 'pubspec.yaml'))) return `${r}/${name}`;
  throw new Error(`no such app: ${name} (looked in ${APP_ROOTS.join(', ')})`);
}

/** Every app directory (relative to the repository root), in all the roots. */
export function allAppDirs() {
  return APP_ROOTS.flatMap((r) => (existsSync(join(repo, r)) ? readdirSync(join(repo, r)).map((a) => `${r}/${a}`) : []));
}

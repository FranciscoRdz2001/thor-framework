// Checks that every snippet of snippets/dart.json compiles against the
// current thor: creates an app with the local CLI (`thor create`), expands
// each snippet with its default placeholders (every option of a choice)
// into a file of that app and runs `dart analyze --fatal-infos` on it.
//
//   node tools/vscode-thor/test/validate_snippets.mjs [--keep]
//
// Offline: `dart pub get --offline` resolves from the local pub cache.
import { execFileSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..', '..');
const snippets = JSON.parse(readFileSync(join(here, '..', 'snippets', 'dart.json'), 'utf8'));
const keep = process.argv.includes('--keep');

const ui = "import 'package:thor_ui/thor_ui.dart';";
const router = "import 'package:thor_ui/router.dart';";

const counterState = `
class CounterViewModel extends ThorState {
  final count = state(0);

  String label() => '\${count.value}';
}

final counter = CounterViewModel();
`;

const aboutPage = `
class AboutPage extends ThorPage<void> {
  const AboutPage();

  @override
  Widget build(BuildContext context, PageState<void> state) => const Text('');
}
`;

// Where each snippet goes: its imports and the code around it (`%` is the
// snippet). A snippet without an entry fails the check: add one.
const contexts = {
  tstless: { imports: [ui], code: '%' },
  tpage: { imports: [router, ui], code: '%' },
  tpaged: { imports: [router, ui], code: '%' },
  tlayout: { imports: [router, ui], code: '%' },
  terror: { imports: [router, ui], code: '%' },
  tstate: { imports: [ui], code: '%' },
  twatch: { imports: [ui], code: `${counterState}\nWidget part() => %;` },
  twatchb: { imports: [ui], code: `${counterState}\nWidget part() => %;` },
  troute: { imports: [router, ui], code: `${aboutPage}\n%` },
  tgroup: { imports: [router], code: '%' },
  tform: { imports: [router], code: '%' },
  tfield: { imports: [router], code: 'abstract final class Fields {\n%\n}', indent: '  ' },
  tmw: { imports: [router], code: '%' },
};

// --- Snippet syntax (the part VS Code snippets use): $1, ${1}, ${1:default},
// ${1|a,b|}, ${1/regex/format/flags} and \$ \} \\ escapes.

/** Parses [text] into nodes until one of [stops] (unescaped). */
function parse(text, i = 0, stops = '') {
  const nodes = [];
  let literal = '';
  const flush = () => {
    if (literal) nodes.push({ kind: 'text', text: literal });
    literal = '';
  };
  while (i < text.length) {
    const c = text[i];
    if (c === '\\' && i + 1 < text.length && '$}\\,|'.includes(text[i + 1])) {
      literal += text[i + 1];
      i += 2;
      continue;
    }
    if (stops.includes(c)) break;
    if (c === '$') {
      const simple = /^\$(\d+)/.exec(text.slice(i));
      if (simple) {
        flush();
        nodes.push({ kind: 'tab', n: +simple[1], children: null });
        i += simple[0].length;
        continue;
      }
      const open = /^\$\{(\d+)/.exec(text.slice(i));
      if (open) {
        flush();
        const n = +open[1];
        i += open[0].length;
        if (text[i] === '}') {
          nodes.push({ kind: 'tab', n, children: null });
          i++;
        } else if (text[i] === ':') {
          const [children, j] = parse(text, i + 1, '}');
          nodes.push({ kind: 'tab', n, children });
          i = j + 1;
        } else if (text[i] === '|') {
          const end = text.indexOf('|}', i + 1);
          const options = text.slice(i + 1, end).split(',');
          nodes.push({ kind: 'choice', n, options });
          i = end + 2;
        } else if (text[i] === '/') {
          const parts = [];
          let part = '';
          let depth = 0; // `${1:/downcase}` inside the format
          i++;
          while (parts.length < 3) {
            if (text[i] === '\\') {
              part += text[i] + text[i + 1];
              i += 2;
            } else if (text[i] === '$' && text[i + 1] === '{') {
              depth++;
              part += '${';
              i += 2;
            } else if (text[i] === '}' && depth > 0) {
              depth--;
              part += text[i++];
            } else if (text[i] === '/' && parts.length < 2 && depth === 0) {
              parts.push(part);
              part = '';
              i++;
            } else if (text[i] === '}' && parts.length === 2) {
              parts.push(part);
              i++;
            } else {
              part += text[i++];
            }
          }
          nodes.push({ kind: 'transform', n, regex: parts[0], format: parts[1], flags: parts[2] });
        } else {
          throw new Error(`bad placeholder at ${i}: ${text.slice(i - 5, i + 10)}`);
        }
        continue;
      }
    }
    literal += c;
    i++;
  }
  flush();
  return [nodes, i];
}

/** The choice placeholders of [nodes], deep. */
function choices(nodes, found = new Map()) {
  for (const node of nodes) {
    if (node.kind === 'choice' && !found.has(node.n)) found.set(node.n, node.options);
    if (node.children) choices(node.children, found);
  }
  return found;
}

/** The text of [nodes] with each placeholder at its default ([picked] for
 * choices), mirrors and transforms applied. */
function expand(nodes, picked) {
  // The first placeholder with a default defines it; the others mirror it.
  const values = new Map(picked);
  const defaults = new Map();
  const collect = (list) => {
    for (const node of list) {
      if (node.kind === 'tab' && node.children && !defaults.has(node.n)) {
        defaults.set(node.n, node.children);
      }
      if (node.children) collect(node.children);
    }
  };
  collect(nodes);
  const valueOf = (n) => {
    if (values.get(n) != null) return values.get(n);
    const d = defaults.get(n);
    const v = d ? render(d) : '';
    values.set(n, v);
    return v;
  };
  const render = (list) =>
    list
      .map((node) => {
        switch (node.kind) {
          case 'text':
            return node.text;
          case 'tab':
          case 'choice':
            return valueOf(node.n);
          case 'transform': {
            const re = new RegExp(node.regex, node.flags);
            return valueOf(node.n).replace(re, (...m) =>
              node.format.replace(/\$\{(\d+):\/(downcase|upcase|capitalize)\}|\$(\d+)/g, (_, g, op, plain) => {
                const s = m[+(g ?? plain)] ?? '';
                if (op === 'downcase') return s.toLowerCase();
                if (op === 'upcase') return s.toUpperCase();
                if (op === 'capitalize') return s.charAt(0).toUpperCase() + s.slice(1);
                return s;
              }),
            );
          }
        }
        throw new Error(node.kind);
      })
      .join('');
  return render(nodes);
}

/** Every combination of the choices' options. */
function combinations(found) {
  let all = [new Map()];
  for (const [n, options] of found) {
    all = all.flatMap((m) => options.map((o) => new Map([...m, [n, o]])));
  }
  return all;
}

// --- The app.

function run(cmd, args, cwd) {
  return execFileSync(cmd, args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
}

const work = mkdtempSync(join(tmpdir(), 'thor-snippets-'));
let failed = false;
try {
  run('dart', ['run', join(root, 'packages', 'thor_cli', 'bin', 'thor.dart'), 'create', 'snippets_app', '--no-pub'], work);
  const app = join(work, 'snippets_app');
  run('dart', ['pub', 'get', '--offline'], app);
  const out = join(app, 'lib', 'snippets');
  mkdirSync(out);

  const files = [];
  for (const [name, snippet] of Object.entries(snippets)) {
    const prefix = snippet.prefix;
    const context = contexts[prefix];
    if (!context) {
      console.error(`✗ ${prefix} (${name}): no context in validate_snippets.mjs`);
      failed = true;
      continue;
    }
    const body = Array.isArray(snippet.body) ? snippet.body.join('\n') : snippet.body;
    const [nodes] = parse(body);
    combinations(choices(nodes)).forEach((picked, k) => {
      let code = expand(nodes, picked);
      if (context.indent) code = code.replace(/^(?=.)/gm, context.indent);
      const file = `${prefix}_${k}.dart`;
      const source = `${context.imports.join('\n')}\n\n${context.code.replace('%', () => code)}\n`;
      writeFileSync(join(out, file), source);
      files.push(file);
    });
  }

  try {
    // From the app's root: the thor_lints plugin only runs there.
    run('dart', ['analyze', '--fatal-infos'], app);
    console.log(`✓ ${files.length} expansions of ${Object.keys(snippets).length} snippets analyze clean`);
  } catch (e) {
    failed = true;
    console.error(e.stdout || e.message);
  }
  if (keep || failed) console.log(`App kept at ${app}`);
} finally {
  if (!keep && !failed) rmSync(work, { recursive: true, force: true });
}
process.exit(failed ? 1 : 0);

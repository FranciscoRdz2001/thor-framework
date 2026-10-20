/// The browser part of `thor render`: Playwright's Chromium loads the page
/// at each width, takes a screenshot, and reads the accessibility tree,
/// the debug inspector's warnings and the console. Optional: without Node
/// or Playwright the report says why and keeps the rest.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../workspace.dart';
import 'report.dart';

/// Where Playwright is: `THOR_PLAYWRIGHT` (a folder with
/// `node_modules/playwright`), the thor checkout's `test/e2e/runner`
/// (`tool/thor setup` installs it there), or a `node_modules` above
/// [appDir]. Null when none has it.
Future<String?> findPlaywright(String appDir) async {
  final candidates = <String>[
    ?Platform.environment['THOR_PLAYWRIGHT'],
    if (await ThorHome.locate() case final home?)
      p.join(home.root, 'test', 'e2e', 'runner'),
  ];
  for (var dir = p.absolute(appDir); ; dir = p.dirname(dir)) {
    candidates.add(dir);
    if (p.dirname(dir) == dir) break;
  }
  for (final dir in candidates) {
    final module = p.join(dir, 'node_modules', 'playwright');
    if (File(p.join(module, 'package.json')).existsSync()) return module;
  }
  return null;
}

/// Loads [url] in Chromium at [widths] with [cookies], writes a PNG per
/// width into [outDir] and returns what it saw. Throws a [BrowserMissing]
/// when it can't run, with the reason.
Future<BrowserResult> runBrowser({
  required String url,
  required String appDir,
  required String outDir,
  List<int> widths = const [390, 800, 1440],
  Map<String, String> cookies = const {},
  bool fullPage = true,
  Duration timeout = const Duration(seconds: 60),
}) async {
  final playwright = await findPlaywright(appDir);
  if (playwright == null) {
    throw const BrowserMissing(
      'Playwright not found: run `npm install playwright` in the app (or a '
      'folder above it), or set THOR_PLAYWRIGHT to a folder with '
      'node_modules/playwright',
    );
  }
  Directory(outDir).createSync(recursive: true);
  final script = File(p.join(outDir, 'render.cjs'))
    ..writeAsStringSync(browserScript);
  final args = jsonEncode({
    'url': url,
    'widths': widths,
    'cookies': [
      for (final e in cookies.entries) {'name': e.key, 'value': e.value},
    ],
    'outDir': p.absolute(outDir),
    'fullPage': fullPage,
  });
  final Process node;
  try {
    node = await Process.start('node', [script.path, playwright, args]);
  } on ProcessException catch (e) {
    throw BrowserMissing('node not found (${e.message})');
  }
  final out = StringBuffer();
  final err = StringBuffer();
  final done = Future.wait([
    node.stdout.transform(utf8.decoder).forEach(out.write),
    node.stderr.transform(utf8.decoder).forEach(err.write),
  ]);
  final code = await node.exitCode.timeout(
    timeout,
    onTimeout: () {
      node.kill(ProcessSignal.sigkill);
      return -1;
    },
  );
  await done;
  script.deleteSync();
  if (code != 0) {
    throw BrowserMissing(
      code == -1
          ? 'the browser took more than ${timeout.inSeconds} s'
          : 'the browser failed: ${_lastLines(err.toString())}',
    );
  }
  return BrowserResult.fromJson(
    (jsonDecode(out.toString()) as Map).cast<String, Object?>(),
  );
}

/// Why the browser part didn't run.
class BrowserMissing implements Exception {
  /// With its [reason].
  const BrowserMissing(this.reason);

  /// What is missing or what failed.
  final String reason;

  @override
  String toString() => reason;
}

String _lastLines(String text) {
  final lines = const LineSplitter().convert(text.trim());
  return lines.skip(lines.length > 6 ? lines.length - 6 : 0).join('\n');
}

/// The Node script (CommonJS: Playwright is required by its absolute path,
/// argv[2]). It loads the widths in parallel (a context each), always
/// closes the browser, and prints one JSON object.
const browserScript = r'''
const { chromium } = require(process.argv[2]);
const o = JSON.parse(process.argv[3]);
const path = require('path');
(async () => {
  const browser = await chromium.launch();
  const res = { aria: null, warnings: [], console: [], screenshots: [] };
  try {
    // The widths at once: each waits ~0.65 s for the network to settle
    // and the inspector to mark, so one after the other took ~3 s.
    await Promise.all(o.widths.map(async (width, i) => {
      const context = await browser.newContext({
        viewport: { width, height: 900 },
        deviceScaleFactor: 1,
      });
      if (o.cookies.length) {
        const u = new URL(o.url);
        await context.addCookies(o.cookies.map(c => ({ ...c, domain: u.hostname, path: '/' })));
      }
      const page = await context.newPage();
      if (i === 0) {
        page.on('console', m => {
          if (m.type() === 'error' || m.type() === 'warning') res.console.push(`${m.type()}: ${m.text()}`);
        });
        page.on('pageerror', e => res.console.push(`exception: ${e.message}`));
      }
      await page.goto(o.url, { waitUntil: 'load' });
      await page.waitForLoadState('networkidle', { timeout: 3000 }).catch(() => {});
      // The debug inspector marks elements after load.
      await page.waitForTimeout(150);
      const file = path.join(o.outDir, `${width}.png`);
      await page.screenshot({ path: file, fullPage: o.fullPage });
      const overflowX = await page.evaluate(() =>
        document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
      res.screenshots[i] = { width, path: file, overflowX };
      if (i === 0) {
        res.aria = await page.locator('body').ariaSnapshot().catch(() => null);
        res.warnings = await page.evaluate(() =>
          [...document.querySelectorAll('[data-thor-warning]')].map(e => ({
            widget: e.getAttribute('data-thor') || e.tagName.toLowerCase(),
            message: e.getAttribute('data-thor-warning'),
            source: e.closest('[data-thor-src]')?.getAttribute('data-thor-src') || null,
          })));
      }
      await context.close();
    }));
  } finally {
    await browser.close();
  }
  process.stdout.write(JSON.stringify(res));
})().catch(e => { console.error(e && e.stack || String(e)); process.exit(1); });
''';

@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/server.dart' show Document;
import 'package:thor_ui/src/core/render.dart' as core;
import 'package:thor_ui/src/engine/theme_script.dart' show themeScript;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// The visitor's light/dark choice survives reloads: a tiny inline script in
// the `<head>`, only on pages that have the theme switch.

String head(String html) => html.substring(0, html.indexOf('</head>'));

void main() {
  setUpAll(initializeThorTests);

  final dark = ThemeData.dark();

  test(
    'a page with a dark theme carries the theme script in its head',
    () async {
      final html = await renderDocument(
        ThorApp(darkTheme: dark, child: const Text('x')),
      );
      expect(head(html), contains(themeScript));
      // First in the head: before the stylesheet is parsed.
      expect(
        head(html).indexOf(themeScript),
        lessThan(head(html).indexOf('<style')),
      );
    },
  );

  test('the script comes before the app\'s own head links: after an external '
      'stylesheet it would hold the parser until that loads', () async {
    final html = utf8.decode(
      (await core.renderPage(
        Document(
          head: const [
            Widget.element(
              tag: 'link',
              attributes: {'rel': 'stylesheet', 'href': 'https://fonts/x.css'},
            ),
          ],
          body: ThorApp(darkTheme: dark, child: const Text('x')),
        ),
      )).body,
    );
    expect(
      head(html).indexOf(themeScript),
      lessThan(head(html).indexOf('https://fonts/x.css')),
    );
    expect(
      head(html).indexOf('<meta charset'),
      lessThan(head(html).indexOf(themeScript)),
    );
  });

  test('a page with no dark theme has no script and no switch', () async {
    final html = await renderDocument(const ThorApp(child: Text('x')));
    expect(html, isNot(contains('thor:theme')));
  });

  test('a fixed themeMode has no switch, so no script', () async {
    final html = await renderDocument(
      ThorApp(
        darkTheme: dark,
        themeMode: ThemeMode.dark,
        child: const Text('x'),
      ),
    );
    expect(html, isNot(contains('thor:theme')));
  });

  test('the script reads and writes storage inside try/catch only', () {
    // Blocked storage (private modes, cookies off) throws on access.
    expect(themeScript, contains('try{'));
    expect(themeScript, contains("K='thor:theme'"));
    expect(themeScript, contains('localStorage.getItem(K)'));
    expect(themeScript, contains('localStorage.setItem(K,'));
    expect(themeScript, contains('prefers-color-scheme'));
    expect(themeScript, isNot(contains('<')), reason: 'cannot close <script>');
    expect(themeScript.length, lessThan(900));
  });

  test(
    'the emitted script is exactly the constant (its CSP hash holds)',
    () async {
      final html = await renderDocument(
        ThorApp(darkTheme: dark, child: const Text('x')),
      );
      final tags = RegExp(
        r'<script>([\s\S]*?)</script>',
      ).allMatches(head(html));
      expect(
        tags.map((m) => m[1]),
        contains(themeScript),
        reason: 'no escaping, no whitespace added around it',
      );
      expect(html, contains('<script>$themeScript</script>'));
    },
  );

  test('the script follows storage events and the system, not just load', () {
    expect(themeScript, contains("addEventListener('storage'"));
    expect(themeScript, contains("m.addEventListener('change'"));
  });
}

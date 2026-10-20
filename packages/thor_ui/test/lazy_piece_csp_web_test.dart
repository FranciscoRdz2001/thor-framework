@TestOn('browser')
library;

// The loader of a `LazyPiece` (`lazyScript`) under a Content-Security-Policy
// with a nonce, in a real browser. The fragment is its own response, so the
// `<style>` Thor wrote in it carries the fragment's nonce, which the response
// names in `x-thor-piece-nonce`; the loader gives those styles the page's
// nonce (its own `document.currentScript.nonce`) so the policy lets them
// apply. A `<style>` that came in as text has no nonce and stays blocked.
//
// `csp_render_test.dart` checks the server side; this one runs the loader.
import 'dart:async';

import 'package:test/test.dart';
import 'package:thor_ui/src/engine/lazy_script.dart' show lazyScript;
import 'package:web/web.dart' as web;

const _pageNonce = 'pagenonce123';
const _fragmentNonce = 'fragmentnonce456';

void main() {
  /// A live `<script>` (one made by the parser does not run).
  web.HTMLScriptElement script(String code, {String? nonce}) {
    final s = web.document.createElement('script') as web.HTMLScriptElement;
    if (nonce != null) s.setAttribute('nonce', nonce);
    s.textContent = code;
    return s;
  }

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  test('the loader re-applies the page nonce to the fragment\'s styles, and '
      'only to those', () async {
    // The fragment, as the server answers `?thor-piece=…`: Thor's `<style>`
    // has the fragment's nonce, the one that came in as text has none.
    const fragment =
        '<style nonce="$_fragmentNonce">.lazy-trusted{color:rgb(1, 2, 3)}'
        '</style>'
        '<style>.lazy-untrusted{color:rgb(4, 5, 6)}</style>'
        '<p class="lazy-trusted">trusted</p>'
        '<p class="lazy-untrusted">untrusted</p>';
    web.document.head!.append(
      script(
        'window.__realFetch = window.fetch;'
        'window.fetch = function(){ return Promise.resolve(new Response('
        '${_jsString(fragment)}, {headers: {"x-thor-piece-nonce": '
        '"$_fragmentNonce"}})) };',
      ),
    );
    addTearDown(() {
      web.document.head!.append(script('window.fetch = window.__realFetch'));
    });

    // The page's policy, from now on: styles need the page's nonce. (A meta
    // policy cannot be taken back, which is fine: one page per test file.)
    web.document.head!.append(
      web.document.createElement('meta')
        ..setAttribute('http-equiv', 'Content-Security-Policy')
        ..setAttribute('content', "style-src 'nonce-$_pageNonce'"),
    );

    final piece = web.document.createElement('div')
      ..setAttribute('data-thor-lazy', '/page?thor-piece=one')
      ..setAttribute('data-thor-lazy-on', 'idle')
      ..textContent = 'fallback';
    web.document.body!.append(piece);
    // ignore: unnecessary_lambdas
    addTearDown(() => piece.remove());

    web.document.body!.append(script(lazyScript, nonce: _pageNonce));
    await until(() => piece.getAttribute('data-thor-lazy-state') != 'loading');
    expect(piece.getAttribute('data-thor-lazy-state'), 'done');

    final styles = piece.querySelectorAll('style');
    expect(styles.length, 2);
    final trusted = styles.item(0)! as web.HTMLStyleElement;
    final untrusted = styles.item(1)! as web.HTMLStyleElement;
    // The loader moved the nonce of the page onto Thor's style…
    expect(trusted.nonce, _pageNonce);
    // …and left the style that came in as text without one.
    expect(untrusted.getAttribute('nonce'), isNull);

    // The policy agrees: the first applies, the second is blocked.
    String colorOf(String cls) => web.window
        .getComputedStyle(piece.querySelector('.$cls')!)
        .getPropertyValue('color');
    expect(colorOf('lazy-trusted'), 'rgb(1, 2, 3)');
    expect(colorOf('lazy-untrusted'), isNot('rgb(4, 5, 6)'));
  });
}

/// [value] as a JavaScript string literal.
String _jsString(String value) =>
    "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll('\n', r'\n')}'";

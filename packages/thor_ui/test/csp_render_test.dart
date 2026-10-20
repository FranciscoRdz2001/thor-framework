@TestOn('vm')
library;

// `contentSecurityPolicy` with the real renderer: only the scripts and styles
// Thor emits carry the request's nonce, never markup that arrives as text, and
// a `LazyPiece` loader hands its nonce to the styles it inserts.
import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  initializeThorTests();

  final gate = Completer<String>();

  RouteHandler<Widget> handler() => RouteHandler<Widget>(
    renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
    routes: [
      LayoutRoute<Widget, void>(
        build: (s, child) => child,
        error: (e) => const Text('error'),
        middleware: contentSecurityPolicy(),
        children: [
          PageRoute<Widget, void>(
            path: 'inject',
            load: (r) {},
            build: (s) => const Column(
              children: [
                html.RawText(
                  '<script>alert(1)</script><script src=//evil></script>',
                ),
                html.RawText('<style>body{display:none}</style>'),
              ],
            ),
          ),
          PageRoute<Widget, void>(
            path: 'stream',
            load: (r) {},
            build: (s) => FutureBuilder<String>(
              future: gate.future,
              builder: (context, snap) => snap.hasData
                  ? Container(
                      color: const Color(0xFF8A1234),
                      child: Text('late ${snap.data}'),
                    )
                  : const Text('wait'),
            ),
          ),
          PageRoute<Widget, void>(
            path: 'lazy',
            load: (r) {},
            build: (s) => LazyPiece<void>(
              id: 'one',
              load: (request) async {},
              builder: (context, _) => const Column(
                children: [
                  Container(color: Color(0xFF123ABC), child: Text('piece')),
                  html.RawText('<style>p{display:none}</style>'),
                ],
              ),
              fallback: const Text('wait'),
            ),
          ),
          // Middleware below the policy that fails: the error page is
          // rendered above it.
          LayoutRoute<Widget, void>(
            path: 'forbidden',
            build: (s, child) => child,
            middleware: (request, next) async => throw const HttpError(403),
            children: [
              PageRoute<Widget, void>(
                load: (r) {},
                build: (s) => const Text('secret'),
              ),
            ],
          ),
          LayoutRoute<Widget, void>(
            path: 'broken',
            build: (s, child) => child,
            middleware: (request, next) async => throw StateError('bug'),
            children: [
              PageRoute<Widget, void>(
                load: (r) {},
                build: (s) => const Text('secret'),
              ),
            ],
          ),
          // The app sets its own policy below this one.
          LayoutRoute<Widget, void>(
            path: 'own',
            build: (s, child) => child,
            middleware: (request, next) async => (await next()).withHeaders(
              const {HttpHeader.contentSecurityPolicy: "default-src 'self'"},
            ),
            children: [
              PageRoute<Widget, void>(
                load: (r) {},
                build: (s) => const Text('own'),
              ),
            ],
          ),
        ],
      ),
      PageRoute<Widget, void>(
        path: 'open',
        load: (r) {},
        build: (s) => const Text('no policy'),
      ),
    ],
  );

  PageRequest get(String path, {Map<HttpHeader, String> headers = const {}}) =>
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://site.test$path'),
        headers: {HttpHeader.host: 'site.test', ...headers},
      );

  String policyOf(ThorResponse r) => r.headers.entries
      .firstWhere((e) => e.key.toLowerCase() == 'content-security-policy')
      .value;

  String nonceOf(ThorResponse r) =>
      RegExp(r"'nonce-([^']+)'").firstMatch(policyOf(r))![1]!;

  test(
    'Thor\'s own scripts and styles get the nonce, no token is left',
    () async {
      final r = await handler().handle(get('/inject'));
      final nonce = nonceOf(r);
      final html = r.text;
      expect(html, contains('nonce="$nonce"'));
      expect(html, isNot(contains('thor-nonce-')));
      // Every script and style element of the page has it, except the markup
      // that came in as text (it is not an element Thor emitted).
      final tags = RegExp(r'<(script|style)\b[^>]*>').allMatches(html);
      final unstamped = [
        for (final m in tags)
          if (!m[0]!.contains('nonce="$nonce"')) m[0],
      ];
      expect(unstamped, [
        '<script>',
        '<script src=//evil>',
        '<style>',
      ], reason: html);
    },
  );

  test('a page outside the policy has no nonce at all', () async {
    final r = await handler().handle(get('/open'));
    expect(r.text, isNot(contains('nonce=')));
    expect(r.text, isNot(contains('thor-nonce-')));
  });

  for (final path in ['/forbidden', '/broken']) {
    test('an error page from middleware below the policy ($path) never '
        'carries the placeholder', () async {
      final r = await handler().handle(get(path));
      expect(r.status, path == '/forbidden' ? 403 : 500);
      expect(r.text, isNot(contains('thor-nonce-')));
    });
  }

  test('a page with its own policy still gets no placeholder', () async {
    final r = await handler().handle(get('/own'));
    expect(policyOf(r), "default-src 'self'");
    expect(r.text, contains('own'));
    expect(r.text, isNot(contains('thor-nonce-')));
  });

  test('no ETag, so a revalidation cannot reuse an old body', () async {
    final first = await handler().handle(get('/lazy'));
    final etag = first.headers.entries
        .where((e) => e.key.toLowerCase() == 'etag')
        .firstOrNull;
    expect(etag, isNull);
    final second = await handler().handle(
      get('/lazy', headers: {HttpHeader.ifNoneMatch: '*'}),
    );
    expect(second.status, 200);
    expect(second.text, contains('nonce="${nonceOf(second)}"'));
  });

  test('a LazyPiece page carries the loader that copies the nonce', () async {
    final r = await handler().handle(get('/lazy'));
    final nonce = nonceOf(r);
    final loader = RegExp(
      r'<script nonce="([^"]+)">(\(function\(\)\{var D=document,W,N=.*?)</script>',
    ).firstMatch(r.text);
    expect(loader, isNotNull, reason: r.text);
    expect(loader![1], nonce);
    expect(loader[2], contains('D.currentScript.nonce'));
    expect(loader[2], contains("querySelectorAll('style')"));
    expect(loader[2], contains("getAttribute('nonce')==W"));
    expect(loader[2], contains('x-thor-piece-nonce'));
    // The fragment is its own response: its `<style>` has no nonce of its
    // own, the loader adds the page's.
    final f = await handler().handle(
      get(
        '/lazy?thor-piece=one',
        headers: {const HttpHeader('x-thor-piece'): '1'},
      ),
    );
    expect(f.status, 200);
    expect(f.text, isNot(contains('thor-nonce-')));
    // Thor's style carries the fragment's own nonce, which the response
    // names; the style that came in as text carries nothing.
    final fragmentNonce = nonceOf(f);
    expect(f.headers['x-thor-piece-nonce'], fragmentNonce);
    expect(f.text, contains('<style nonce="$fragmentNonce">'));
    expect(f.text, contains('<style>p{display:none}</style>'));
    // A page request does not get the header.
    expect(r.headers.containsKey('x-thor-piece-nonce'), isFalse);
  });

  test(
    'streamed late pieces carry the nonce on their script and style',
    () async {
      final r = await handler().handle(get('/stream'), stream: true);
      final nonce = nonceOf(r);
      final chunks = <String>[];
      final done = Completer<void>();
      r.stream!.listen(
        (c) => chunks.add(utf8.decode(c)),
        onDone: done.complete,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gate.complete('now');
      await done.future;
      final all = chunks.join();
      expect(chunks.length, greaterThan(2), reason: 'it streamed');
      expect(all, isNot(contains('thor-nonce-')));
      // The defer script and the piece's style carry the request's nonce.
      expect(
        all,
        contains('<script nonce="$nonce">(function(){function \$thor'),
      );
      expect(all, contains('<noscript><style nonce="$nonce">'));
      final late = chunks.skip(1).join();
      expect(late, contains('late now'));
      expect(late, contains('<style nonce="$nonce">'));
      final bare = RegExp(r'<(script|style)>').allMatches(late);
      expect(bare, isEmpty, reason: late);
    },
  );
}

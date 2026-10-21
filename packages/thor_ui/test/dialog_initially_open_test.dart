@TestOn('vm')
library;

// `Dialog(initiallyOpen:)` and `AlertDialog(initiallyOpen:)`: a modal dialog
// the server draws open (a product link that reloads the page with the
// product's dialog showing). Without JavaScript it is an open, non-modal
// `<dialog>` centered in the window; the page's loader upgrades it to a modal
// one (focus trap, backdrop, Esc) as soon as it runs.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/src/engine/lazy_script.dart' show lazyScript;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget w) => renderDocument(ThorApp(child: w));

String _body(String html) => html.substring(html.indexOf('<body'));

String _head(String html) => html.substring(0, html.indexOf('</head>'));

final hasNode = () {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();

void main() {
  setUpAll(initializeThorTests);

  group('modal dialog drawn open', () {
    test('Dialog: open, marked for the upgrade, still dismissible', () async {
      final html = await _page(
        const Dialog(initiallyOpen: true, child: Text('Mug')),
      );
      final dialog = RegExp(r'<dialog[^>]*>').firstMatch(_body(html))![0]!;
      expect(dialog, contains(' open'));
      expect(dialog, contains('data-thor-open'));
      expect(dialog, contains('closedby="any"'));
      expect(html, contains(lazyScript), reason: 'the loader upgrades it');
      // The look it has until then: fixed and centered, no backdrop yet.
      expect(_head(html), contains(':not(:modal)'));
      expect(_head(html), contains('::backdrop'));
    });

    test('AlertDialog does the same', () async {
      final html = await _page(
        const AlertDialog(initiallyOpen: true, content: Text('Sure?')),
      );
      final dialog = RegExp(r'<dialog[^>]*>').firstMatch(_body(html))![0]!;
      expect(dialog, contains(' open'));
      expect(dialog, contains('data-thor-open'));
      expect(dialog, contains('closedby="any"'));
      expect(html, contains(lazyScript));
    });

    test('by default it is closed and ships no loader', () async {
      for (final w in const [
        Dialog(child: Text('x')),
        AlertDialog(content: Text('x')),
      ]) {
        final html = await _page(w);
        final dialog = RegExp(r'<dialog[^>]*>').firstMatch(_body(html))![0]!;
        expect(dialog, isNot(contains(' open')));
        expect(dialog, isNot(contains('data-thor-open')));
        expect(html, isNot(contains(lazyScript)));
        expect(_head(html), isNot(contains(':not(:modal)')));
      }
    });

    test('a non-modal dialog is open already: nothing to upgrade', () async {
      final html = await _page(
        const Dialog(modal: false, initiallyOpen: true, child: Text('x')),
      );
      final dialog = RegExp(r'<dialog[^>]*>').firstMatch(_body(html))![0]!;
      expect(dialog, contains(' open'));
      expect(dialog, isNot(contains('data-thor-open')));
      expect(html, isNot(contains(lazyScript)));
    });

    test('the page decides from its query', () async {
      final h = RouteHandler<Widget>(
        renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
        onError: (request, error, stack) {},
        routes: [
          PageRoute<Widget, bool>(
            path: 'shop',
            load: (r) => r.uri.queryParameters.containsKey('product'),
            build: (s) => Dialog(
              id: 'product',
              initiallyOpen: s.data,
              child: const Text('Mug'),
            ),
          ),
        ],
      );
      PageRequest get(String path) => PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://site.test$path'),
        headers: {HttpHeader.host: 'site.test'},
      );
      final open = (await h.handle(get('/shop?product=mug'))).text;
      final closed = (await h.handle(get('/shop'))).text;
      expect(
        RegExp(r'<dialog[^>]*>').firstMatch(open)![0],
        contains('data-thor-open'),
      );
      expect(
        RegExp(r'<dialog[^>]*>').firstMatch(closed)![0],
        isNot(contains(' open')),
      );
    });
  });

  group(
    'the loader upgrades it, in node',
    () {
      Map<String, Object?> run(String body, String steps) {
        final program =
            '''
eval(require('fs').readFileSync('test/support/mini_dom.js', 'utf8'));
const input = JSON.parse(process.argv[1]);
const D = document, calls = [];
globalThis.MutationObserver = class { observe() {} };
globalThis.navigator = {};
globalThis.addEventListener = () => {};
globalThis.location = { href: 'http://site.test/shop' };
// A dialog that knows showModal() refuses an `open` one, like a browser.
Object.getPrototypeOf(D.createElement('dialog')).showModal = function () {
  if (this.hasAttribute('open')) throw new Error('InvalidStateError');
  this.open = true;
  calls.push(['showModal', this.id]);
};
const root = miniDom.parseHtml(input.page);
D.body.append(...root.childNodes);
const out = {};
eval(input.script);
(async () => { $steps; console.log(JSON.stringify(out)); })();
''';
        final r = Process.runSync('node', [
          '-e',
          program,
          jsonEncode({'page': body, 'script': lazyScript}),
        ]);
        expect(r.exitCode, 0, reason: '${r.stderr}');
        return jsonDecode((r.stdout as String).trim().split('\n').last)
            as Map<String, Object?>;
      }

      test('open and marked: showModal, mark gone; the rest untouched', () {
        final out = run(
          '<dialog id="a" open data-thor-open>one</dialog>'
              '<dialog id="b">two</dialog>',
          r'''
        const a = D.getElementById('a'), b = D.getElementById('b');
        out.calls = calls;
        out.aOpen = a.hasAttribute('open');
        out.aMark = a.hasAttribute('data-thor-open');
        out.bOpen = b.hasAttribute('open');
      ''',
        );
        expect(out['calls'], [
          ['showModal', 'a'],
        ]);
        expect(
          out['aOpen'],
          isFalse,
          reason: 'the attribute moved to the modal',
        );
        expect(out['aMark'], isFalse);
        expect(out['bOpen'], isFalse);
      });
    },
    skip: hasNode ? false : 'node is not installed',
  );
}

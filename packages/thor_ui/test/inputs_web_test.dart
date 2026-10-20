// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
// Image builders and inputs in a real browser: what the VM tests only read as
// markup. The page is rendered by thor (the same render the server runs) and
// put in a browser document: an image that 404s shows its fallback; one that
// loads drops its placeholder; the counter of a `maxLength` follows the typing
// with grapheme clusters.
@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_ui/server.dart' show Document;
import 'package:thor_ui/src/core/render.dart' as render;
import 'package:thor_ui/thor_ui.dart';
import 'package:web/web.dart' as web;

/// 1x1 transparent GIF: an image that loads.
const _pixel =
    'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

/// Renders [body] like a page and puts its markup and styles in the
/// document; returns the host element (removed by [addTearDown]).
Future<web.Element> mount(Widget body) async {
  // Release output: classes and a stylesheet, as a deployed page has.
  render.compactHtml = true;
  final result = await render.renderPage(Document(body: body));
  final page = utf8.decode(result.body);
  final style = RegExp(
    r'<style[^>]*>([\s\S]*?)</style>',
  ).allMatches(page).map((m) => m[1]).join('\n');
  final markup = page.substring(page.indexOf('<body') + 6);
  final sheet = web.document.createElement('style')..textContent = style;
  final host = web.document.createElement('div')
    ..innerHTML = markup.substring(0, markup.indexOf('</body>')).toJS;
  web.document.head!.append(sheet);
  web.document.body!.append(host);
  addTearDown(() {
    sheet.remove();
    host.remove();
  });
  return host;
}

bool shown(web.Element e) =>
    web.window.getComputedStyle(e).display != 'none' &&
    e.getBoundingClientRect().width > 0;

/// Waits until [test] holds (the browser reports a load or an error some
/// frames later).
Future<void> until(bool Function() test, String what) async {
  for (var i = 0; i < 100 && !test(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  expect(test(), isTrue, reason: what);
}

Widget _fallback(BuildContext c, Object e, StackTrace? s) =>
    const SizedBox(width: 120, height: 80, child: Text('No photo'));

Widget _spinner(BuildContext c, Widget child, ImageChunkEvent? p) =>
    const SizedBox(width: 60, height: 40, child: Text('Loading'));

void main() {
  test(
    'an image that 404s shows its fallback and hides the broken image',
    () async {
      final host = await mount(
        const Image.network(
          '/no-such-image.png',
          width: 120,
          height: 80,
          errorBuilder: _fallback,
        ),
      );
      final fallback = host.querySelector('[data-fb]')!;
      final img = host.querySelector('img')!;
      // Loading: the fallback is not shown yet.
      expect(shown(fallback) && !shown(img), isFalse);
      await until(
        () => host.querySelector('[data-ib]')!.hasAttribute('data-broken'),
        'the frame is told the image failed',
      );
      expect(shown(fallback), isTrue, reason: 'the fallback shows');
      expect(fallback.textContent, contains('No photo'));
      expect(shown(img), isFalse, reason: 'the broken image is hidden');
    },
  );

  test(
    'an image that loads keeps the image and never shows the fallback',
    () async {
      final host = await mount(
        const Image.network(
          _pixel,
          width: 40,
          height: 40,
          errorBuilder: _fallback,
          loadingBuilder: _spinner,
        ),
      );
      await until(
        () => host.querySelector('[data-ib]')!.hasAttribute('data-loaded'),
        'the frame is told the image loaded',
      );
      expect(
        host.querySelector('[data-ib]')!.hasAttribute('data-broken'),
        isFalse,
      );
      expect(shown(host.querySelector('[data-fb]')!), isFalse);
      expect(
        shown(host.querySelector('[data-ph]')!),
        isFalse,
        reason: 'the placeholder goes once loaded',
      );
      expect(shown(host.querySelector('img')!), isTrue);
    },
  );

  test('the placeholder shows while the image is still coming', () async {
    final host = await mount(
      const Image.network(
        // Never answers quickly enough to matter: the check is synchronous.
        '/slow-image.png',
        width: 60,
        height: 40,
        loadingBuilder: _spinner,
      ),
    );
    expect(shown(host.querySelector('[data-ph]')!), isTrue);
  });

  test('a failed image with both builders shows only the fallback', () async {
    final host = await mount(
      const Image.network(
        '/no-such-image.png',
        width: 120,
        height: 80,
        errorBuilder: _fallback,
        loadingBuilder: _spinner,
      ),
    );
    await until(
      () => host.querySelector('[data-ib]')!.hasAttribute('data-broken'),
      'the frame is told the image failed',
    );
    expect(shown(host.querySelector('[data-fb]')!), isTrue);
    expect(shown(host.querySelector('[data-ph]')!), isFalse);
    expect(shown(host.querySelector('img')!), isFalse);
  });

  test(
    'a failed image with only a loadingBuilder drops its placeholder',
    () async {
      final host = await mount(
        const Image.network(
          '/no-such-image.png',
          width: 60,
          height: 40,
          loadingBuilder: _spinner,
        ),
      );
      await until(
        () => !shown(host.querySelector('[data-ph]')!),
        'the placeholder goes when the image fails: it is not loading any more',
      );
    },
  );

  test('a fallback keeps its own styles when the image fails', () async {
    final host = await mount(
      Image.network(
        '/no-such-image.png',
        width: 120,
        height: 80,
        errorBuilder: (c, e, s) => const Styled(
          // A raw declaration on purpose: the test is about the cascade.
          // ignore: thor_lints/avoid_raw_css
          style: StyleProps(raw: {'display': 'flex'}),
          child: SizedBox(width: 120, height: 80, child: Text('No photo')),
        ),
      ),
    );
    final fallback = host.querySelector('[data-fb]')!;
    expect(shown(fallback), isFalse, reason: 'hidden while the image loads');
    await until(() => shown(fallback), 'the fallback shows once it fails');
    expect(web.window.getComputedStyle(fallback).display, 'flex');
  });

  test('the maxLength counter counts grapheme clusters as you type', () async {
    final host = await mount(const TextField(name: 'bio', maxLength: 20));
    final input = host.querySelector('input')! as web.HTMLInputElement;
    final counter = host.querySelector('#f-bio-cnt')!;
    expect(counter.textContent, '0/20');
    // A family emoji: 8 UTF-16 units, one character.
    input.value = '\u{1F468}‍\u{1F469}‍\u{1F467}';
    input.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    expect(counter.textContent, '1/20');
    input.value = 'éabc';
    input.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    expect(counter.textContent, '4/20');
    // The native stop is on the control.
    expect(input.maxLength, 20);
  });

  test('the counter without a limit shows the bare count', () async {
    final host = await mount(
      const TextField(name: 'n', maxLength: TextField.noMaxLength),
    );
    final input = host.querySelector('input')! as web.HTMLInputElement;
    input.value = 'ab';
    input.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    expect(host.querySelector('#f-n-cnt')!.textContent, '2');
  });

  test('an InkWell around text is a native button that takes Enter', () async {
    final host = await mount(const InkWell(onTap: _noop, child: Text('Open')));
    final button = host.querySelector('button')!;
    expect(button.getAttribute('type'), 'button');
    (button as web.HTMLElement).focus();
    expect(web.document.activeElement, same(button));
  });
}

void _noop() {}

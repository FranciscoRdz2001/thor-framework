// Flutter's RichText and SelectableText over Text.rich.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _html(Widget w) async =>
    (await renderHtml(w)).replaceAll(RegExp(r'<style>[\s\S]*?</style>'), '');

Future<String> _css(Widget w) async => RegExp(r'<style[^>]*>([\s\S]*?)</style>')
    .allMatches(await renderDocument(ThorApp(child: w)))
    .map((m) => m[1])
    .join()
    .replaceAll(' ', '');

const _span = TextSpan(
  text: 'Hello ',
  children: [
    TextSpan(
      text: 'bold',
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    TextSpan(text: ' and a link', href: '/x'),
  ],
);

void main() {
  setUpAll(initializeThorTests);

  group('RichText', () {
    test('is Text.rich: the same markup', () async {
      final rich = await _html(const RichText(text: _span));
      final text = await _html(const Text.rich(_span));
      expect(rich, text);
      expect(rich, contains('href="/x"'));
    });

    test('textAlign, maxLines, overflow and softWrap go through', () async {
      final css = await _css(
        const RichText(
          text: _span,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
      expect(css, contains('text-align:center'));
      expect(css, contains('text-overflow:ellipsis'));
      final nowrap = await _css(const RichText(text: _span, softWrap: false));
      expect(nowrap, contains('white-space:pre'));
    });

    test('a wrapper fuses into its element, like Text', () async {
      final html = await _html(
        const Padding(
          padding: EdgeInsets.all(8),
          child: RichText(text: _span),
        ),
      );
      final text = await _html(
        const Padding(padding: EdgeInsets.all(8), child: Text.rich(_span)),
      );
      expect(html, text);
    });

    test('a plain span is its text', () async {
      final html = await _html(const RichText(text: TextSpan(text: 'only')));
      expect(html, contains('>only<'));
    });
  });

  group('SelectableText', () {
    test('is a Text the person can select', () async {
      final css = await _css(const SelectableText('copy me'));
      expect(css, contains('user-select:text'));
      expect(css, contains('cursor:text'));
      expect(
        await _html(const SelectableText('copy me')),
        contains('>copy me<'),
      );
    });

    test('takes the style, alignment and lines of Text', () async {
      final css = await _css(
        const SelectableText(
          'x',
          style: TextStyle(fontSize: 20),
          textAlign: TextAlign.end,
          maxLines: 2,
        ),
      );
      expect(css, contains('font-size:20px'));
      expect(css, contains('text-align:end'));
      // Flutter's SelectableText has no overflow: it clips.
      expect(css, contains('max-height:calc(2*1lh)'));
    });

    test('.rich takes a span', () async {
      final html = await _html(const SelectableText.rich(_span));
      expect(html, contains('href="/x"'));
      expect(
        await _css(const SelectableText.rich(_span)),
        contains('user-select:text'),
      );
    });

    test('a plain Text does not force selection', () async {
      expect(await _css(const Text('x')), isNot(contains('user-select')));
    });
  });
}

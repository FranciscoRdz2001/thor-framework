// Text.overflow with maxLines: clip, fade and visible are not an ellipsis.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _css(Widget w) async => RegExp(r'<style[^>]*>([\s\S]*?)</style>')
    .allMatches(await renderDocument(ThorApp(child: w)))
    .map((m) => m[1])
    .join()
    .replaceAll(' ', '');

void main() {
  setUpAll(initializeThorTests);

  test('ellipsis keeps the ellipsis and the line clamp', () async {
    final one = await _css(
      const Text('long', maxLines: 1, overflow: TextOverflow.ellipsis),
    );
    expect(one, contains('text-overflow:ellipsis'));
    final many = await _css(
      const Text('long', maxLines: 3, overflow: TextOverflow.ellipsis),
    );
    expect(many, contains('-webkit-line-clamp:3'));
  });

  test('clip with maxLines cuts without an ellipsis', () async {
    final one = await _css(
      const Text('long', maxLines: 1, overflow: TextOverflow.clip),
    );
    expect(one, contains('overflow:hidden'));
    expect(one, contains('white-space:nowrap'));
    expect(one, isNot(contains('text-overflow')));
    final many = await _css(
      const Text('long', maxLines: 3, overflow: TextOverflow.clip),
    );
    expect(many, contains('overflow:hidden'));
    expect(many, contains('max-height:calc(3*1lh)'));
    expect(many, isNot(contains('line-clamp')));
  });

  test('fade clips and masks the end', () async {
    final one = await _css(
      const Text('long', maxLines: 1, overflow: TextOverflow.fade),
    );
    expect(one, contains('mask-image:linear-gradient(toright'));
    expect(one, isNot(contains('text-overflow')));
    final many = await _css(
      const Text('long', maxLines: 2, overflow: TextOverflow.fade),
    );
    expect(many, contains('mask-image'));
    expect(many, isNot(contains('line-clamp')));
  });

  test('visible does not clip', () async {
    final css = await _css(
      const Text('long', maxLines: 2, overflow: TextOverflow.visible),
    );
    expect(css, isNot(contains('overflow:hidden')));
    expect(css, isNot(contains('line-clamp')));
    expect(css, isNot(contains('text-overflow')));
  });

  test('maxLines without overflow clips, like Flutter', () async {
    final css = await _css(const Text('long', maxLines: 2));
    expect(css, contains('max-height:calc(2*1lh)'));
    expect(css, isNot(contains('line-clamp')));
    final one = await _css(const Text('long', maxLines: 1));
    expect(one, isNot(contains('text-overflow')));
  });

  test('DefaultTextStyle maxLines/overflow/softWrap reach Text', () async {
    final css = await _css(
      const DefaultTextStyle(
        style: TextStyle(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        child: Text('long'),
      ),
    );
    expect(css, contains('-webkit-line-clamp:2'));
    final own = await _css(
      const DefaultTextStyle(
        style: TextStyle(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        child: Text('long', maxLines: 1),
      ),
    );
    expect(own, contains('text-overflow:ellipsis'));
    expect(own, isNot(contains('line-clamp')));
    final merged = await _css(
      const DefaultTextStyle(
        style: TextStyle(),
        overflow: TextOverflow.ellipsis,
        child: DefaultTextStyle.merge(maxLines: 3, child: Text('long')),
      ),
    );
    expect(merged, contains('-webkit-line-clamp:3'));
    final wrap = await _css(
      const DefaultTextStyle(
        style: TextStyle(),
        softWrap: false,
        child: Text('long'),
      ),
    );
    expect(wrap, contains('white-space:pre'));
  });

  test('a page without those defaults renders as before', () async {
    final plain = await renderDocument(
      const ThorApp(
        child: DefaultTextStyle(style: TextStyle(), child: Text('x')),
      ),
    );
    expect(plain, isNot(contains('line-clamp')));
  });

  test('a box does not swallow a Text the defaults limit', () async {
    const limited = DefaultTextStyle(
      style: TextStyle(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      child: Container(padding: EdgeInsets.all(4), child: Text('long')),
    );
    expect(await _css(limited), contains('text-overflow:ellipsis'));
    final html = await renderDocument(const ThorApp(child: limited));
    expect(html, contains('<span'));
    // Without limits the box renders the text itself, as before.
    final plain = await renderDocument(
      const ThorApp(
        child: DefaultTextStyle(
          style: TextStyle(),
          child: Container(padding: EdgeInsets.all(4), child: Text('long')),
        ),
      ),
    );
    expect(bodyOfPage(plain), isNot(contains('<span')));
  });

  test('RichText and SelectableText read no line limits from above', () async {
    for (final child in [
      const RichText(text: TextSpan(text: 'long')),
      const SelectableText('long'),
    ]) {
      final css = await _css(
        DefaultTextStyle(
          style: const TextStyle(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          child: child,
        ),
      );
      expect(css, isNot(contains('line-clamp')), reason: '$child');
    }
  });

  test(
    'a wrapper above a limiting DefaultTextStyle lands on the Text',
    () async {
      final html = bodyOfPage(
        await renderDocument(
          const ThorApp(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: DefaultTextStyle(
                style: TextStyle(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                child: Text('long'),
              ),
            ),
          ),
        ),
      );
      // One element: the padding and the clamp share the Text's span.
      expect(RegExp('<span').allMatches(html), hasLength(1));
      final css = await _css(
        const Padding(
          padding: EdgeInsets.all(12),
          child: DefaultTextStyle(
            style: TextStyle(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            child: Text('long'),
          ),
        ),
      );
      expect(css, contains('padding:12px'));
      expect(css, contains('-webkit-line-clamp:2'));
    },
  );
}

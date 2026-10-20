@TestOn('vm')
library;

// The raw escape hatch (`StyleProps(raw:)`), `MouseRegion(cursor:)` and the
// `css` builder in html.dart / web.dart.
// Raw declarations on purpose: the test is about the raw escape hatch.
// ignore_for_file: thor_lints/avoid_raw_css
import 'package:test/test.dart';
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';
import 'package:thor_ui/web.dart' as web;

Future<String> _page(Widget w) async {
  final out = await renderDocument(ThorApp(child: w));
  return out;
}

String _rules(String page) => RegExp(
  r'<style[^>]*>([\s\S]*?)</style>',
).allMatches(page).map((m) => m[1]).join().replaceAll(' ', '');

void main() {
  setUpAll(initializeThorTests);

  test('StyleProps(raw:) writes the declaration', () async {
    final typed = await _page(
      const Styled(
        style: StyleProps(raw: {'filter': 'saturate(0)'}),
        child: Text('x'),
      ),
    );
    expect(_rules(typed), contains('filter:saturate(0)'));
  });

  test('MouseRegion(cursor:) writes the cursor', () async {
    final region = await _page(
      const MouseRegion(cursor: SystemMouseCursors.click, child: Text('x')),
    );
    expect(_rules(region), contains('cursor:pointer'));
  });

  test('the css builder of html.dart is the one of web.dart', () {
    expect(identical(web.css, html.css), isTrue);
    expect(html.css('.a'), isA<html.NestedStyleRule>());
  });

  test('html.dart and web.dart export the builder and its types', () {
    final rule = web.css('.card', [html.css('&:hover')]);
    expect(rule, isA<html.StyleRule>());
    const html.Css builder = html.css;
    expect(builder, isNotNull);
  });
}

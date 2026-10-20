@TestOn('vm')
library;

// The table tags of `html.dart`, an `<a>` without `href`, and `classes:` on
// the web layer's elements (a `class` attribute is merged, never dropped).
import 'package:test/test.dart';
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/web.dart';

void main() {
  initializeThorTests();

  test('a table, its sections, rows and cells', () async {
    final out = await renderHtml(
      const html.table([
        html.caption([Widget.text('People')]),
        html.colgroup([html.col(span: 2)]),
        html.thead([
          html.tr([
            html.th([Widget.text('Name')], scope: 'col'),
            html.th([Widget.text('Age')], scope: 'col'),
          ]),
        ]),
        html.tbody([
          html.tr([
            html.td([Widget.text('Ana')], classes: 'c'),
            html.td([Widget.text('30')], colSpan: 2, rowSpan: 3),
          ], id: 'r1'),
        ]),
        html.tfoot([
          html.tr([
            html.td([Widget.text('x')]),
          ]),
        ]),
      ], classes: 'table table-hover'),
    );
    expect(
      out,
      allOf(
        contains('<table class="table table-hover">'),
        contains('<caption>People</caption>'),
        contains('<colgroup><col span="2"/></colgroup>'),
        contains('<thead><tr><th scope="col">Name</th>'),
        contains('<tr id="r1"><td class="c">Ana</td>'),
        contains('<td colspan="2" rowspan="3">30</td>'),
        contains('<tfoot><tr><td>x</td></tr></tfoot>'),
      ),
    );
  });

  test('an <a> without href is a placeholder link', () async {
    final out = await renderHtml(const html.a([Widget.text('pick')]));
    expect(out, '<a>pick</a>');
    final withHref = await renderHtml(
      const html.a([Widget.text('go')], href: '/x'),
    );
    expect(withHref, contains('href="/x"'));
  });

  group('classes on a web element', () {
    test('classes: next to the generated class', () async {
      final out = await renderHtml(
        const ThorApp(
          child: Box(
            classes: 'btn btn-primary',
            style: Style(display: Display.flex),
          ),
        ),
      );
      expect(out, matches(RegExp(r'<div class="btn btn-primary [^"]+"')));
    });

    test('a class attribute is merged, not dropped', () async {
      final out = await renderHtml(
        const ThorApp(
          child: Span(
            classes: 'a b',
            attributes: {'class': 'b c', 'data-x': '1'},
            style: Style(display: Display.flex),
          ),
        ),
      );
      expect(out, matches(RegExp(r'<span class="a b c [^"]+"')));
      expect(out, contains('data-x="1"'));
    });

    test('without a ThorApp the class attribute still survives', () async {
      final out = await renderHtml(
        const Td(
          attributes: {'class': 'cell'},
          style: Style(display: Display.flex),
          text: 'x',
        ),
      );
      expect(out, contains('class="cell"'));
      expect(out, contains('>x</td>'));
    });
  });
}

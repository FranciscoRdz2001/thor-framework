@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  group('HtmlAttributes', () {
    test('writes aria, data, globals and flags as attributes', () {
      final attributes = HtmlAttributes(
        aria: {AriaAttribute.label: 'Search', AriaAttribute.busy: true},
        data: {'k': 'u0', 'row-id': '7'},
        id: 'q',
        title: 'Find',
        tabIndex: 2,
        flags: {BooleanAttribute.autofocus, BooleanAttribute.required},
        custom: {'type': 'search'},
      );
      expect(attributes, {
        'aria-label': 'Search',
        'aria-busy': 'true',
        'data-k': 'u0',
        'data-row-id': '7',
        'id': 'q',
        'title': 'Find',
        'tabindex': '2',
        'autofocus': '',
        'required': '',
        'type': 'search',
      });
    });

    test('it is unmodifiable', () {
      final attributes = HtmlAttributes.custom({'type': 'date'});
      expect(() => attributes['x'] = 'y', throwsUnsupportedError);
    });

    test('a data key is lowercase letters, digits and dashes', () {
      for (final bad in ['K', 'a b', '1a', 'a"b', '']) {
        expect(
          () => HtmlAttributes(data: {bad: 'x'}),
          throwsArgumentError,
          reason: bad,
        );
      }
    });

    test('custom refuses a bad name and an event handler', () {
      // The last three pass a looser check but the page writer refuses them.
      for (final bad in [
        'a b',
        'a"b',
        '',
        '1a',
        'onclick',
        'OnLoad',
        'data-foo-',
        '_x',
        'Foo',
      ]) {
        expect(
          () => HtmlAttributes.custom({bad: 'x'}),
          throwsArgumentError,
          reason: bad,
        );
      }
      expect(HtmlAttributes.custom({'aria-x.y:z_w': '1'}), isNotEmpty);
    });

    test('merge: the second wins on a name both have', () {
      final merged = HtmlAttributes.custom({
        'a': '1',
        'b': '1',
      }).merge(HtmlAttributes.custom({'b': '2'}));
      expect(merged, {'a': '1', 'b': '2'});
      expect(HtmlAttributes.empty.merge(null), isEmpty);
    });

    test('a TextField writes its inputAttributes on the <input>', () async {
      final out = await renderHtml(
        TextField(
          name: 'q',
          inputAttributes: HtmlAttributes(
            aria: {AriaAttribute.label: 'Search'},
            data: {'k': 'x'},
          ),
        ),
      );
      expect(out, contains('aria-label="Search"'));
      expect(out, contains('data-k="x"'));
    });

    test('the raw layer takes it where it takes a map', () async {
      final out = await renderHtml(
        html.div(
          const [],
          attributes: HtmlAttributes(aria: {AriaAttribute.hidden: true}),
        ),
      );
      expect(out, contains('aria-hidden="true"'));
    });
  });

  group('AttributeName', () {
    test('constants, aria and data names', () {
      expect(AttributeName.href, 'href');
      expect(AttributeName.tabIndex, 'tabindex');
      expect(AttributeName.ariaOf(AriaAttribute.rowcount), 'aria-rowcount');
      expect(AttributeName.data('stack-index'), 'data-stack-index');
      expect(() => AttributeName.data('Bad'), throwsArgumentError);
    });

    test('WatchAttributes still refuses a name a binding may not write', () {
      expect(
        () => WatchAttributes({
          const AttributeName('onclick'): () => 1,
        }, child: const SizedBox()).wrapData,
        throwsArgumentError,
      );
    });
  });
}

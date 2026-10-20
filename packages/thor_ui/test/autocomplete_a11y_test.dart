// ignore_for_file: thor_lints/text_field_without_label
// Autocomplete a11y: a polite live region for the result count with
// translatable texts, a panel that can flip above the field (the markup the
// engine toggles), and panel ids that stay unique in a `Watch.list` row.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class Fruit {
  const Fruit(this.id, this.name);
  final int id;
  final String name;
}

abstract class _FruitsMembers extends ThorState {
  @override
  String get $type => 'Fruits';

  @override
  List<ThorMember> get $members {
    final s = this as _Fruits;
    return [
      ThorMember.state('rows', s.rows),
      ThorMember(
        'idOf',
        s.idOf,
        arity: 1,
        callWithItem: (i) => s.idOf(i as Fruit),
      ),
      ThorMember(
        'nameOf',
        s.nameOf,
        arity: 1,
        callWithItem: (i) => s.nameOf(i as Fruit),
      ),
    ];
  }
}

class _Fruits extends _FruitsMembers {
  final rows = state<List<Fruit>>(const [Fruit(1, 'apple'), Fruit(2, 'pear')]);
  int idOf(Fruit f) => f.id;
  String nameOf(Fruit f) => f.name;
}

final _fruits = _Fruits();

Iterable<String> _all(TextEditingValue v) => const ['apple', 'banana'];

Future<String> _body(Widget w) async =>
    bodyOfPage(await renderDocument(ThorApp(child: w)));

Future<String> _css(Widget w) async => RegExp(r'<style[^>]*>([\s\S]*?)</style>')
    .allMatches(await renderDocument(ThorApp(child: w)))
    .map((m) => m[1])
    .join()
    .replaceAll(' ', '');

String _tagOf(String html, String needle) =>
    RegExp('<[^>]*$needle[^>]*>').firstMatch(html)![0]!;

void main() {
  setUpAll(initializeThorTests);

  group('live region', () {
    test('a polite status with the English texts by default', () async {
      final html = await _body(
        const Autocomplete<String>(optionsBuilder: _all),
      );
      final tag = _tagOf(html, 'data-t-ac-status');
      expect(tag, contains('role="status"'));
      expect(tag, contains('aria-live="polite"'));
      expect(tag, contains('aria-atomic="true"'));
      expect(tag, contains('data-t-ac-status="{count} results"'));
      expect(tag, contains('data-t-ac-one="1 result"'));
      expect(tag, contains('data-t-ac-none="No results"'));
      // Before the panel, never inside it (the panel is hidden when closed).
      expect(
        html.indexOf('data-t-ac-status'),
        lessThan(html.indexOf('popover=')),
      );
    });

    test('translatable: the three texts are parameters', () async {
      final html = await _body(
        const Autocomplete<String>(
          optionsBuilder: _all,
          resultsLabel: '{count} resultados',
          oneResultLabel: '1 resultado',
          noResultsLabel: 'Sin resultados',
        ),
      );
      final tag = _tagOf(html, 'data-t-ac-status');
      expect(tag, contains('data-t-ac-status="{count} resultados"'));
      expect(tag, contains('data-t-ac-one="1 resultado"'));
      expect(tag, contains('data-t-ac-none="Sin resultados"'));
    });

    test('RawAutocomplete has it too', () async {
      final html = await _body(
        RawAutocomplete<String>(
          optionsBuilder: (v) => const <String>[],
          resultsLabel: '{count} hallazgos',
          fieldViewBuilder: (context, controller, focus, submit) =>
              TextField(controller: controller, focusNode: focus),
          optionsViewBuilder: (context, onSelected, options) => const Text('x'),
        ),
      );
      expect(
        _tagOf(html, 'data-t-ac-status'),
        contains('data-t-ac-status="{count} hallazgos"'),
      );
    });

    test(
      'visually hidden but not display:none (a screen reader reads it)',
      () async {
        final css = await _css(
          const Autocomplete<String>(optionsBuilder: _all),
        );
        expect(css, contains('clip-path:inset(50%)'));
        expect(css, contains('width:1px'));
      },
    );
  });

  group('flip above', () {
    test('the panel has an up variant the engine switches on', () async {
      final css = await _css(const Autocomplete<String>(optionsBuilder: _all));
      expect(css, contains('[data-t-up]'));
      expect(css, contains('position-area:block-startspan-inline-end'));
      // The room the engine measured (visualViewport) caps the height.
      expect(css, contains('var(--t-ac-room'));
    });
  });

  group('ids in a Watch.list row', () {
    test('a ValueKey(row.key) keeps the token in the panel id', () async {
      final html = await renderHtml(
        Watch.list(
          _fruits.rows.call,
          itemKey: _fruits.idOf,
          each: (row) => Autocomplete<String>(
            key: ValueKey(row.key),
            optionsBuilder: _all,
          ),
        ),
      );
      final rows = html.substring(0, html.indexOf('<template'));
      final template = html.substring(html.indexOf('<template'));
      expect(rows, contains('id="ac-1-list"'));
      expect(rows, contains('id="ac-2-list"'));
      expect(template, contains('id="ac-{{key}}-list"'));
    });

    test('without a key, two on a page still get their own', () async {
      final html = await _body(
        const Column(
          children: [
            Autocomplete<String>(optionsBuilder: _all),
            Autocomplete<String>(optionsBuilder: _all),
          ],
        ),
      );
      final ids = RegExp(
        r'<div id="([^"]+)"[^>]*popover=',
      ).allMatches(html).map((m) => m[1]).toList();
      expect(ids.toSet(), hasLength(2));
    });

    test('the same key twice still gets two ids', () async {
      final html = await _body(
        const Column(
          children: [
            Autocomplete<String>(key: ValueKey(7), optionsBuilder: _all),
            Autocomplete<String>(key: ValueKey(7), optionsBuilder: _all),
          ],
        ),
      );
      final ids = RegExp(
        r'<div id="([^"]+)"[^>]*popover=',
      ).allMatches(html).map((m) => m[1]).toList();
      expect(ids, ['ac-7-list', 'ac-7-2-list']);
    });
  });

  group('labels', () {
    test('are escaped in the markup, whatever the translation holds', () async {
      final html = await _body(
        const Autocomplete<String>(
          optionsBuilder: _all,
          resultsLabel: '{count} "résultats" <b>&',
          oneResultLabel: "l'un",
          noResultsLabel: '<script>x</script>',
        ),
      );
      expect(html, isNot(contains('<script>x')));
      expect(html, isNot(contains('<b>&')));
      expect(html, contains('{count} &quot;résultats&quot;'));
    });
  });
}

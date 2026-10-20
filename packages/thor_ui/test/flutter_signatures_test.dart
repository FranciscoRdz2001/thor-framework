// Fixture: fields without a label on purpose.
// ignore_for_file: thor_lints/text_field_without_label
// Flutter signatures thor matches: nullable `maxLines`,
// `keyboardType` and `enabled`, an optional `Scaffold.body`, `SafeArea.minimum`,
// `IndexedWidgetBuilder`, a `ListView.builder` with no `itemCount`,
// `Row.verticalDirection`, `Column.textDirection`, `Text.softWrap: null`,
// `SnackBar.behavior` and a typed `ButtonType`.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _html(Widget w) => renderDocument(ThorApp(child: w));

// The opening tag of the first `<tag …>` in [html].
String _open(String html, String tag) =>
    RegExp('<$tag[ >][^>]*>').firstMatch(html)![0]!;

String _css(String html) => RegExp(
  r'<style[^>]*>([\s\S]*?)</style>',
).allMatches(html).map((m) => m[1]).join().replaceAll(' ', '');

void main() {
  setUpAll(initializeThorTests);

  group('TextField', () {
    test(
      'maxLines null grows without limit: a textarea, field-sizing',
      () async {
        final html = await _html(const TextField(maxLines: null));
        expect(html, contains('<textarea'));
        final css = _css(html);
        expect(css, contains('field-sizing:content'));
        expect(css, isNot(contains('max-height:calc')));
        expect(css, contains('min-height:calc(1lh'));
      },
    );

    test('maxLines null with minLines starts at minLines', () async {
      final html = await _html(const TextField(maxLines: null, minLines: 3));
      expect(html, contains('rows="3"'));
      expect(_css(html), contains('min-height:calc(3lh'));
    });

    test('a number keeps its limit', () async {
      final css = _css(await _html(const TextField(maxLines: 6, minLines: 2)));
      expect(css, contains('max-height:calc(6lh'));
    });

    test('keyboardType and enabled left null are text and enabled', () async {
      final html = await _html(const TextField());
      expect(html, contains('type="text"'));
      expect(_open(html, 'input'), isNot(contains('disabled')));
      const field = TextField(keyboardType: null, enabled: null);
      expect(field.keyboardType, isNull);
      expect(field.enabled, isNull);
    });

    test('enabled: false still disables', () async {
      expect(
        await _html(const TextField(enabled: false)),
        contains('disabled'),
      );
    });

    test('TextFormField takes the same nullable values', () async {
      final html = await _html(
        const TextFormField(
          name: 'bio',
          maxLines: null,
          keyboardType: null,
          enabled: null,
        ),
      );
      expect(html, contains('<textarea'));
      expect(_open(html, 'textarea'), isNot(contains('disabled')));
    });
  });

  group('Scaffold', () {
    test('body is optional: an empty <main>', () async {
      final html = await _html(const Scaffold(appBar: AppBar()));
      expect(
        RegExp(r'<main[^>]*></main>').hasMatch(html),
        isTrue,
        reason: html,
      );
    });

    test('a bottom bar and a button publish where a snack bar sits', () async {
      final html = await _html(
        Scaffold(
          bottomNavigationBar: NavigationBar(
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
            ],
          ),
          floatingActionButton: const SizedBox(),
        ),
      );
      expect(
        _css(html),
        contains(
          '--t-snack-offset:calc(152px+env(safe-area-inset-bottom,0px))',
        ),
      );
    });

    test('no bar or button, no offset', () async {
      expect(_css(await _html(const Scaffold())), isNot(contains('--t-snack')));
    });
  });

  group('SafeArea.minimum', () {
    test('a side takes the larger of the inset and the minimum', () async {
      final css = _css(
        await _html(
          const SafeArea(
            minimum: EdgeInsets.only(bottom: 16, left: 8),
            child: Text('x'),
          ),
        ),
      );
      expect(css, contains('max(env(safe-area-inset-bottom),16px)'));
      expect(css, contains('max(env(safe-area-inset-left),8px)'));
      expect(css, contains('env(safe-area-inset-top)'));
    });

    test('a side that is not avoided still takes its minimum', () async {
      final css = _css(
        await _html(
          const SafeArea(
            top: false,
            minimum: EdgeInsets.only(top: 12),
            child: Text('x'),
          ),
        ),
      );
      expect(css, contains('12px'));
      expect(css, isNot(contains('safe-area-inset-top')));
    });

    test('it adds the child padding to the larger one', () async {
      final css = _css(
        await _html(
          const SafeArea(
            minimum: EdgeInsets.only(top: 10),
            child: Padding(padding: EdgeInsets.only(top: 4), child: Text('x')),
          ),
        ),
      );
      expect(css, contains('calc(max(env(safe-area-inset-top),10px)+4px)'));
    });

    test('the default minimum changes nothing', () async {
      final css = _css(await _html(const SafeArea(child: Text('x'))));
      expect(css, isNot(contains('max(env(safe-area-inset')));
    });
  });

  group('builders', () {
    test('IndexedWidgetBuilder is the builder of a ListView', () async {
      Widget builder(BuildContext context, int i) => Text('item $i');
      final html = await _html(
        ListView.builder(itemCount: 3, itemBuilder: builder),
      );
      expect(RegExp(r'>item \d<').allMatches(html).length, 3);
      final IndexedWidgetBuilder typed = builder;
      expect(typed, builder);
    });

    test(
      'with no itemCount the list ends where the builder returns null',
      () async {
        final html = await _html(
          ListView.builder(
            itemBuilder: (context, i) => i < 4 ? Text('row $i') : null,
          ),
        );
        expect(RegExp(r'>row \d<').allMatches(html).length, 4);
      },
    );

    test('separated builds the separators between the items only', () async {
      final html = await _html(
        ListView.separated(
          itemBuilder: (context, i) => i < 3 ? Text('row $i') : null,
          separatorBuilder: (context, i) => Text('sep $i'),
        ),
      );
      expect(RegExp(r'>row \d<').allMatches(html).length, 3);
      expect(RegExp(r'>sep \d<').allMatches(html).length, 2);
      expect(html.indexOf('row 0') < html.indexOf('sep 0'), isTrue);
      expect(html.indexOf('sep 1') < html.indexOf('row 2'), isTrue);
    });

    test('a builder that never ends is an error, not a hang', () async {
      await expectLater(
        _html(ListView.builder(itemBuilder: (context, i) => const Text('x'))),
        throwsA(
          anyOf(
            isA<StateError>(),
            predicate((Object e) => e.toString().contains('itemCount')),
          ),
        ),
      );
    });
  });

  group('Flex directions', () {
    test('Row.verticalDirection: up swaps the cross start and end', () async {
      final css = _css(
        await _html(
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            verticalDirection: VerticalDirection.up,
            children: [Text('a')],
          ),
        ),
      );
      expect(css, contains('align-items:flex-end'));
      expect(css, isNot(contains('column-reverse')));
    });

    test('Row.verticalDirection leaves center alone', () async {
      final css = _css(
        await _html(
          const Row(
            verticalDirection: VerticalDirection.up,
            children: [Text('a')],
          ),
        ),
      );
      expect(css, contains('align-items:center'));
    });

    test('Column.textDirection: rtl swaps the cross start and end', () async {
      final css = _css(
        await _html(
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            textDirection: TextDirection.rtl,
            children: [Text('a')],
          ),
        ),
      );
      expect(css, contains('align-items:flex-start'));
      expect(css, isNot(contains('row-reverse')));
    });

    test('the other directions still reverse the main axis', () async {
      final css = _css(
        await _html(
          const Column(
            verticalDirection: VerticalDirection.up,
            textDirection: TextDirection.rtl,
            children: [Text('a')],
          ),
        ),
      );
      expect(css, contains('column-reverse'));
      final row = _css(
        await _html(
          const Row(textDirection: TextDirection.rtl, children: [Text('a')]),
        ),
      );
      expect(row, contains('row-reverse'));
    });
  });

  group('Text.softWrap', () {
    test('null is true, false is pre', () async {
      expect(const Text('a', softWrap: null).softWrap, isNull);
      expect(
        _css(await _html(const Text('a', softWrap: null))),
        isNot(contains('white-space:pre')),
      );
      expect(
        _css(await _html(const Text('a', softWrap: false))),
        contains('white-space:pre'),
      );
    });
  });

  group('SnackBar.behavior', () {
    test('fixed (the default) is full width at the bottom', () async {
      for (final bar in [
        const SnackBar(content: Text('Saved')),
        const SnackBar(
          content: Text('Saved'),
          behavior: SnackBarBehavior.fixed,
        ),
      ]) {
        final css = _css(await _html(bar));
        expect(css, contains('left:0'));
        expect(css, contains('right:0'));
        expect(css, contains('bottom:var(--t-snack-offset,0px)'));
        expect(css, contains('thor-snack-out-fixed'));
        expect(css, isNot(contains('border-radius:4px')));
        // The popover box is `width: fit-content`: the bar overrides it.
        expect(css, contains('width:auto'));
        expect(css, contains('max-width:none'));
        expect(css, contains('border-radius:0'));
      }
    });

    test('floating is the rounded centered bar, above the offset', () async {
      final css = _css(
        await _html(
          const SnackBar(
            content: Text('Saved'),
            behavior: SnackBarBehavior.floating,
          ),
        ),
      );
      expect(css, contains('left:50%'));
      expect(css, contains('border-radius:4px'));
      expect(css, contains('+var(--t-snack-offset,0px)'));
      expect(css, contains('translate:-50%0'));
    });
  });

  group('ButtonType', () {
    test('submit makes a submit button, enabled inside a Form', () async {
      final html = await _html(
        const Form(
          child: FilledButton(
            buttonType: ButtonType.submit,
            child: Text('Send'),
          ),
        ),
      );
      expect(_open(html, 'button'), contains('type="submit"'));
      expect(_open(html, 'button'), isNot(contains('disabled')));
    });

    test('button is the default and does not submit', () async {
      final html = await _html(
        const FilledButton(onPressed: _noop, child: Text('Go')),
      );
      expect(_open(html, 'button'), contains('type="button"'));
    });

    test('IconButton takes it too', () async {
      final html = await _html(
        const Form(
          child: IconButton(
            tooltip: 'Sign out',
            icon: Icon(Icons.logout),
            buttonType: ButtonType.submit,
          ),
        ),
      );
      expect(_open(html, 'button'), contains('type="submit"'));
      expect(_open(html, 'button'), isNot(contains('disabled')));
    });
  });
}

void _noop() {}

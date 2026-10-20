// ignore_for_file: thor_lints/text_field_without_label
// Autocomplete / RawAutocomplete (Flutter's): a field and
// an options panel on a native popover anchored to it. Nothing here needs a
// browser: the markup is the contract the engine's AutocompleteFeature binds.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

abstract class _SearchMembers extends ThorState {
  @override
  String get $type => 'Search';

  @override
  List<ThorMember> get $members {
    final s = this as _Search;
    return [
      ThorMember.controller('box', s.box),
      ThorMember.controller('focus', s.focus),
      ThorMember('pick', s.pick, arity: 1, call: (a) => s.pick(a!)),
    ];
  }
}

class _Search extends _SearchMembers {
  final box = TextEditingController();
  final focus = FocusNode();
  final picked = state('');
  void pick(String name) => picked.value = name;
}

final _search = _Search();

const _fruits = ['apple', 'banana', 'cherry'];

Iterable<String> _all(TextEditingValue v) =>
    _fruits.where((o) => o.contains(v.text.toLowerCase()));

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

  group('Autocomplete', () {
    test('a field and a manual popover listbox with the options', () async {
      final html = await _body(
        const Autocomplete<String>(optionsBuilder: _all),
      );
      // One text input (the field) and the panel; no second input.
      expect('<input'.allMatches(html), hasLength(1));
      final panel = _tagOf(html, 'popover=');
      expect(panel, contains('popover="manual"'));
      expect(panel, contains('role="listbox"'));
      final options = RegExp(
        r'<div[^>]*role="option"[^>]*>([^<]*)</div>',
      ).allMatches(html).map((m) => m[1]).toList();
      expect(options, _fruits);
      expect(html, contains('data-t-ac='));
      // The anchor and the panel's anchoring (the same classes per instance).
      final css = await _css(const Autocomplete<String>(optionsBuilder: _all));
      expect(css, contains('anchor-name:--t-ac'));
      expect(css, contains('anchor-scope:--t-ac'));
      expect(css, contains('position-anchor:--t-ac'));
      expect(
        css,
        contains('position-area:block-end span-inline-end'.replaceAll(' ', '')),
      );
    });

    test('the panel is the listbox the field points at', () async {
      final html = await _body(
        const Autocomplete<String>(optionsBuilder: _all),
      );
      final id = RegExp(r'<div id="([^"]+)"[^>]*popover=').firstMatch(html)![1];
      expect(id, isNotEmpty);
      // The engine reads it from the panel (`aria-controls` of the field).
      expect(_tagOf(html, 'popover='), contains('role="listbox"'));
    });

    test('displayStringForOption names the rows', () async {
      final html = await _body(
        Autocomplete<int>(
          optionsBuilder: (v) => const [1, 2],
          displayStringForOption: (n) => 'Item $n',
        ),
      );
      expect(html, contains('>Item 1<'));
      expect(html, contains('>Item 2<'));
    });

    test(
      'onSelected is a ThorState method: each row carries its option',
      () async {
        final html = await _body(
          Autocomplete<String>(optionsBuilder: _all, onSelected: _search.pick),
        );
        final rows = RegExp(
          r'<div[^>]*role="option"[^>]*>',
        ).allMatches(html).map((m) => m[0]!).toList();
        expect(rows, hasLength(3));
        for (final (i, row) in rows.indexed) {
          expect(row, contains('data-t-on="click:Search.pick"'));
          expect(row, contains('data-tx="${_fruits[i]}"'));
          expect(row, contains('aria-selected="false"'));
        }
      },
    );

    test('a controller of a state binds the field', () async {
      final html = await _body(
        Autocomplete<String>(
          optionsBuilder: _all,
          textEditingController: _search.box,
          focusNode: _search.focus,
          fieldViewBuilder: (context, controller, focus, submit) {
            expect(identical(controller, _search.box), isTrue);
            return TextField(controller: controller, focusNode: focus);
          },
        ),
      );
      expect(html, contains('data-ttc="Search.box"'));
    });

    test('initialValue fills the field and the options see it', () async {
      String? seen;
      final html = await _body(
        Autocomplete<String>(
          initialValue: const TextEditingValue(text: 'ban'),
          optionsBuilder: (v) {
            seen = v.text;
            return _all(v);
          },
        ),
      );
      expect(seen, 'ban');
      expect(html, contains('value="ban"'));
    });

    test(
      'an async optionsBuilder is an error that names the way out',
      () async {
        await expectLater(
          _body(Autocomplete<String>(optionsBuilder: (v) async => _fruits)),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(contains('THOR-R032'), contains('optionsViewBuilder')),
            ),
          ),
        );
      },
    );

    test('no options: the panel is still there for the page to fill', () async {
      final html = await _body(
        const Autocomplete<String>(optionsBuilder: _none),
      );
      expect(html, contains('popover="manual"'));
      expect('role="option"'.allMatches(html), isEmpty);
    });

    test(
      'the open direction anchors the panel up, down or where room is',
      () async {
        Future<String> panelCss(OptionsViewOpenDirection d) => _css(
          Autocomplete<String>(
            optionsBuilder: _all,
            optionsViewOpenDirection: d,
          ),
        );
        expect(
          await panelCss(OptionsViewOpenDirection.up),
          contains('position-area:block-startspan-inline-end'),
        );
        final down = await panelCss(OptionsViewOpenDirection.down);
        expect(down, contains('position-area:block-endspan-inline-end'));
        expect(down, contains('position-try-fallbacks:flip-block'));
        final most = await panelCss(OptionsViewOpenDirection.mostSpace);
        expect(most, contains('position-try:most-heightflip-block'));
      },
    );

    test('optionsMaxHeight caps the default panel', () async {
      final css = await _css(
        const Autocomplete<String>(optionsBuilder: _all, optionsMaxHeight: 120),
      );
      expect(
        css,
        contains(
          'max-height:min(120px,calc(100dvh-16px),var(--t-ac-room,100dvh))',
        ),
      );
    });

    test('two on one page: own ids, same classes', () async {
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
      expect(ids, hasLength(2));
      expect(ids.toSet(), hasLength(2));
      final roots = RegExp(
        r'<div class="([^"]+)"[^>]*data-t-ac=',
      ).allMatches(html).map((m) => m[1]).toList();
      expect(roots, hasLength(2));
      expect(roots.toSet(), hasLength(1));
    });
  });

  group('RawAutocomplete', () {
    test('its views, the state\'s list in the panel', () async {
      final html = await _body(
        RawAutocomplete<String>(
          optionsBuilder: (v) => const <String>[],
          textEditingController: _search.box,
          focusNode: _search.focus,
          fieldViewBuilder: (context, controller, focus, submit) =>
              TextField(controller: controller, focusNode: focus),
          optionsViewBuilder: (context, onSelected, options) => const Column(
            children: [
              Semantics(role: SemanticsRole.option, child: Text('Café')),
              Semantics(role: SemanticsRole.option, child: Text('Té')),
            ],
          ),
        ),
      );
      expect('role="option"'.allMatches(html), hasLength(2));
      // The panel draws nothing of its own around a view the app draws.
      final panel = _tagOf(html, 'popover=');
      expect(panel, contains('popover="manual"'));
      final css = await _css(
        RawAutocomplete<String>(
          optionsBuilder: (v) => const <String>[],
          fieldViewBuilder: (context, controller, focus, submit) =>
              TextField(controller: controller, focusNode: focus),
          optionsViewBuilder: (context, onSelected, options) => const Text('x'),
        ),
      );
      expect(css, contains('overflow:visible'));
      expect(css, isNot(contains('rgba(0,0,0,0.3)')), reason: 'no panel look');
    });

    test(
      'options are what optionsBuilder gives for the field\'s text',
      () async {
        Iterable<String>? given;
        await _body(
          RawAutocomplete<String>(
            optionsBuilder: _all,
            fieldViewBuilder: (context, controller, focus, submit) =>
                TextField(controller: controller, focusNode: focus),
            optionsViewBuilder: (context, onSelected, options) {
              given = options;
              return const SizedBox();
            },
          ),
        );
        expect(given, _fruits);
      },
    );
  });

  test('a RawAutocomplete without a fieldViewBuilder is refused', () {
    expect(
      () => RawAutocomplete<String>(
        optionsBuilder: _all,
        optionsViewBuilder: (context, onSelected, options) => const SizedBox(),
        focusNode: FocusNode(),
        textEditingController: TextEditingController(),
      ),
      throwsA(
        isA<AssertionError>().having(
          (e) => e.message,
          'message',
          contains('fieldViewBuilder'),
        ),
      ),
    );
  });

  test('SemanticsRole.option is an ARIA option', () async {
    final html = await _body(
      const Semantics(role: SemanticsRole.option, child: Text('x')),
    );
    expect(html, contains('role="option"'));
  });

  test('SemanticsRole.toolbar is an ARIA toolbar with its label', () async {
    final html = await _body(
      const Semantics(
        role: SemanticsRole.toolbar,
        label: 'Actions',
        child: Text('x'),
      ),
    );
    expect(html, contains('role="toolbar"'));
    expect(html, contains('aria-label="Actions"'));
  });
}

Iterable<String> _none(TextEditingValue v) => const [];

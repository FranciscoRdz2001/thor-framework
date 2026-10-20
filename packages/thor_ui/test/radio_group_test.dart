@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/server.dart' show Document;
import 'package:thor_ui/src/core/render.dart' as render;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

enum Plan { free, pro }

// The member list thor generates for [_Picker], by hand.
abstract class _PickerMembers extends ThorState {
  @override
  String get $type => 'Picker';

  @override
  List<ThorMember> get $members {
    final s = this as _Picker;
    return [ThorMember('pick', s.pick, arity: 1, call: s.pick)];
  }
}

class _Picker extends _PickerMembers {
  void pick(String? v) {}
}

final _picker = _Picker();

Future<String> _body(Widget w) async =>
    bodyOfPage(await renderDocument(ThorApp(child: w)));

List<String> _radios(String html) => [
  for (final m in RegExp(r'<input[^>]*type="radio"[^>]*>').allMatches(html))
    m[0]!,
];

void _noop(Object? _) {}

void main() {
  setUpAll(initializeThorTests);

  group('RadioGroup', () {
    test('gives its radios one name and the checked state', () async {
      final radios = _radios(
        await _body(
          const RadioGroup<String>(
            groupValue: 'b',
            onChanged: _noop,
            child: Column(
              children: [
                Radio<String>(value: 'a'),
                Radio<String>(value: 'b'),
              ],
            ),
          ),
        ),
      );
      expect(radios, hasLength(2));
      final names = [
        for (final r in radios) RegExp(r'name="([^"]+)"').firstMatch(r)![1],
      ];
      expect(names[0], isNotNull);
      expect(names[0], names[1]);
      expect(radios[0], isNot(contains('checked')));
      expect(radios[1], contains('checked'));
      expect(radios[0], isNot(contains('disabled')));
    });

    test('name: is the name the form submits; works without JS', () async {
      final html = await _body(
        const Form(
          child: RadioGroup<String>(
            name: 'plan',
            groupValue: 'pro',
            onChanged: _noop,
            child: Column(
              children: [
                Radio<String>(value: 'free'),
                Radio<String>(value: 'pro'),
              ],
            ),
          ),
        ),
      );
      final radios = _radios(html);
      expect(radios[0], contains('name="plan"'));
      expect(radios[0], contains('value="free"'));
      expect(radios[1], contains('checked'));
      // The page loads no script for a group in a form.
      expect(html, isNot(contains('<script src')));
    });

    test('a failed form decides which radio is on', () async {
      final radios = _radios(
        await _body(
          Form(
            failed: FormInvalid(values: const {'plan': 'free'}),
            child: const RadioGroup<String>(
              name: 'plan',
              groupValue: 'pro',
              onChanged: _noop,
              child: Column(
                children: [
                  Radio<String>(value: 'free'),
                  Radio<String>(value: 'pro'),
                ],
              ),
            ),
          ),
        ),
      );
      expect(radios[0], contains('checked'));
      expect(radios[1], isNot(contains('checked')));
    });

    test('enum values submit their name and select by identity', () async {
      final radios = _radios(
        await _body(
          const RadioGroup<Plan>(
            name: 'plan',
            groupValue: Plan.pro,
            onChanged: _noop,
            child: Column(
              children: [
                Radio<Plan>(value: Plan.free),
                Radio<Plan>(value: Plan.pro),
              ],
            ),
          ),
        ),
      );
      expect(radios[0], contains('value="free"'));
      expect(radios[1], contains('value="pro"'));
      expect(radios[1], contains('checked'));
      expect(radios[0], isNot(contains('checked')));
    });

    test('no groupValue: nothing is checked', () async {
      final radios = _radios(
        await _body(
          const RadioGroup<String>(
            onChanged: _noop,
            child: Radio<String>(value: 'a'),
          ),
        ),
      );
      expect(radios.single, isNot(contains('checked')));
    });

    test(
      'nested groups: each radio belongs to the nearest of its type',
      () async {
        final radios = _radios(
          await _body(
            const RadioGroup<String>(
              name: 'outer',
              groupValue: 'a',
              onChanged: _noop,
              child: Column(
                children: [
                  Radio<String>(value: 'a'),
                  RadioGroup<String>(
                    name: 'inner',
                    groupValue: 'x',
                    onChanged: _noop,
                    child: Radio<String>(value: 'x'),
                  ),
                  Radio<String>(value: 'b'),
                ],
              ),
            ),
          ),
        );
        expect(radios[0], contains('name="outer"'));
        expect(radios[0], contains('checked'));
        expect(radios[1], contains('name="inner"'));
        expect(radios[1], contains('checked'));
        expect(radios[2], contains('name="outer"'));
        expect(radios[2], isNot(contains('checked')));
      },
    );

    test('two groups without a name do not share one', () async {
      final radios = _radios(
        await _body(
          const Column(
            children: [
              RadioGroup<String>(
                onChanged: _noop,
                child: Radio<String>(value: 'a'),
              ),
              RadioGroup<String>(
                onChanged: _noop,
                child: Radio<String>(value: 'a'),
              ),
            ],
          ),
        ),
      );
      String name(String r) => RegExp(r'name="([^"]+)"').firstMatch(r)![1]!;
      expect(name(radios[0]), isNot(name(radios[1])));
    });

    test('a group without onChanged disables its radios', () async {
      final radios = _radios(
        await _body(
          const RadioGroup<String>(
            groupValue: 'a',
            onChanged: null,
            child: Radio<String>(value: 'a'),
          ),
        ),
      );
      expect(radios.single, contains('disabled'));
    });

    test('a ThorState method as onChanged reaches the browser', () async {
      final radios = _radios(
        await _body(
          RadioGroup<String>(
            groupValue: 'a',
            onChanged: _picker.pick,
            child: const Radio<String>(value: 'a'),
          ),
        ),
      );
      expect(radios.single, contains('data-t'));
      expect(radios.single, contains('Picker'));
    });

    test('RadioListTile takes its group from a RadioGroup', () async {
      final radios = _radios(
        await _body(
          const RadioGroup<String>(
            name: 'g',
            groupValue: 'b',
            onChanged: _noop,
            child: Column(
              children: [
                RadioListTile<String>(value: 'a', title: Text('A')),
                RadioListTile<String>(value: 'b', title: Text('B')),
              ],
            ),
          ),
        ),
      );
      expect(radios[0], contains('name="g"'));
      expect(radios[1], contains('checked'));
    });

    test('Radio(groupValue:, onChanged:) keeps working', () async {
      final radios = _radios(
        await _body(
          // ignore: deprecated_member_use
          const Radio<String>(value: 'a', groupValue: 'a', onChanged: _noop),
        ),
      );
      expect(radios.single, contains('checked'));
    });
  });

  group('RadioGroup adversarial', () {
    test(
      'groups of a loose page (no ThorApp) still get names of their own',
      () async {
        final page = await render.renderPage(
          const Document(
            body: Column(
              children: [
                RadioGroup<String>(
                  onChanged: _noop,
                  child: Radio<String>(value: 'a'),
                ),
                RadioGroup<String>(
                  onChanged: _noop,
                  child: Radio<String>(value: 'a'),
                ),
              ],
            ),
          ),
        );
        final radios = _radios(String.fromCharCodes(page.body));
        String name(String r) => RegExp(r'name="([^"]+)"').firstMatch(r)![1]!;
        expect(radios, hasLength(2));
        expect(name(radios[0]), isNot(name(radios[1])));
      },
    );

    test(
      'rows of a list and a radio in a dialog get a name per group',
      () async {
        final radios = _radios(
          await _body(
            Column(
              children: [
                for (var i = 0; i < 2; i++)
                  RadioGroup<int>(
                    key: ValueKey(i),
                    onChanged: _noop,
                    groupValue: 1,
                    child: const Row(
                      children: [Radio<int>(value: 1), Radio<int>(value: 2)],
                    ),
                  ),
                const Dialog(
                  id: 'd',
                  child: RadioGroup<int>(
                    onChanged: _noop,
                    groupValue: 2,
                    child: Radio<int>(value: 2),
                  ),
                ),
              ],
            ),
          ),
        );
        String name(String r) => RegExp(r'name="([^"]+)"').firstMatch(r)![1]!;
        expect(name(radios[0]), name(radios[1]));
        expect(name(radios[2]), name(radios[3]));
        expect({
          name(radios[0]),
          name(radios[2]),
          name(radios[4]),
        }, hasLength(3));
        expect(radios[4], contains('checked'));
      },
    );
  });
}

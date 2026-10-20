@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) async {
  return renderDocument(ThorApp(child: body));
}

String bodyOf(String html) => html.substring(html.indexOf('<body'));

void _noop(Object? _) {}

void main() {
  setUpAll(initializeThorTests);

  test(
    'Checkbox is a native input; checked state does not change its class',
    () async {
      final on = bodyOf(
        await page(const Checkbox(value: true, onChanged: _noop)),
      );
      final off = bodyOf(
        await page(const Checkbox(value: false, onChanged: _noop)),
      );
      final cls = RegExp(r'<input class="(t\w+)"');
      expect(on, contains('type="checkbox" checked'));
      expect(off, isNot(contains('checked')));
      expect(cls.firstMatch(on)![1], cls.firstMatch(off)![1]);
    },
  );

  test('a control without onChanged is disabled (like Flutter)', () async {
    for (final c in [
      const Checkbox(value: false, onChanged: null),
      const Switch(value: false, onChanged: null),
      const Radio<int>(value: 1, groupValue: 1, onChanged: null),
      const Slider(value: 0.5, onChanged: null),
      const DropdownButton<int>(items: [], value: null, onChanged: null),
    ]) {
      expect(bodyOf(await page(c)), contains('disabled'));
    }
  });

  test(
    'checked look lives in a :checked condition of the same class',
    () async {
      final html = await page(const Switch(value: false, onChanged: _noop));
      expect(html, matches(RegExp(r'\.t\w+:checked\{')));
      expect(html, contains('role="switch"'));
      expect(
        html,
        matches(RegExp(r'\.t\w+:focus-visible\{outline: 2px solid')),
      );
    },
  );

  test('Slider(divisions:) writes the step at full precision', () async {
    final third = await page(
      Slider(value: 1, min: 0, max: 1, divisions: 3, onChanged: (_) {}),
    );
    expect(third, contains('step="0.3333333333333333"'));
    final whole = await page(
      Slider(value: 0, min: 0, max: 100, divisions: 4, onChanged: (_) {}),
    );
    expect(whole, contains('step="25"'));
  });

  test('tristate Checkbox renders mixed', () async {
    final html = await page(
      const Checkbox(value: null, tristate: true, onChanged: _noop),
    );
    expect(html, contains('aria-checked="mixed"'));
    // The dash is only for an unchecked box: once the visitor checks it
    // (no rebuild), the attribute left behind must not draw it again.
    expect(html, contains(r'[aria-checked="mixed"]:not(:checked){'));
  });

  test(
    'Radio is checked when value == groupValue and submits its value',
    () async {
      final html = bodyOf(
        await page(
          const Row(
            children: [
              Radio<String>(
                value: 'a',
                groupValue: 'b',
                onChanged: _noop,
                name: 'g',
              ),
              Radio<String>(
                value: 'b',
                groupValue: 'b',
                onChanged: _noop,
                name: 'g',
              ),
            ],
          ),
        ),
      );
      expect(html, contains('type="radio" name="g" value="a"'));
      expect(html, contains('type="radio" checked name="g" value="b"'));
    },
  );

  test('Slider maps divisions to step and value to the native range', () async {
    final html = bodyOf(
      await page(
        const Slider(
          value: 20,
          min: 0,
          max: 100,
          divisions: 10,
          onChanged: _noop,
        ),
      ),
    );
    expect(
      html,
      contains('type="range" min="0" max="100" step="10" value="20"'),
    );
  });

  test(
    'DropdownButton is a <select> with a placeholder when value is null',
    () async {
      final html = bodyOf(
        await page(
          const DropdownButton<String>(
            hint: 'Method',
            value: null,
            onChanged: _noop,
            items: [
              DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
              DropdownMenuItem(value: 'card', child: Text('Tarjeta')),
            ],
          ),
        ),
      );
      expect(html, contains('<select'));
      expect(html, contains('<option value disabled selected>Method</option>'));
      // The option's value is the item's value (the form submits it).
      expect(html, contains('<option value="card">Tarjeta</option>'));
    },
  );

  test(
    'DropdownButton takes an id, so a <label for> names the select',
    () async {
      // A <select> without a <label for> is unnamed (axe select-name,
      // critical).
      final html = bodyOf(
        await page(
          const DropdownButton<String>(
            id: 'subject',
            name: 'subject',
            value: 'a',
            onChanged: _noop,
            items: [DropdownMenuItem(value: 'a', child: Text('A'))],
          ),
        ),
      );
      expect(html, contains('id="subject"'));
      final plain = bodyOf(
        await page(
          const DropdownButton<String>(
            value: 'a',
            onChanged: _noop,
            items: [DropdownMenuItem(value: 'a', child: Text('A'))],
          ),
        ),
      );
      expect(plain, isNot(contains(' id=')));
    },
  );

  test(
    'ListTile controls wrap the input in a <label> (whole row toggles)',
    () async {
      final html = bodyOf(
        await page(
          const SwitchListTile(
            value: true,
            onChanged: _noop,
            title: Text('Notifications'),
          ),
        ),
      );
      expect(html, startsWith('<body><label'));
      expect(
        RegExp(r'<label[^>]*>.*<input[^>]*role="switch"').hasMatch(html),
        isTrue,
      );
    },
  );
}

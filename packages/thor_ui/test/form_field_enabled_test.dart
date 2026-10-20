@TestOn('vm')
library;

// A control with a `name` inside a `Form` is a form field: enabled when
// `onChanged` is left out (a form without JS has nothing to call). An
// `onChanged: null` written on purpose disables it like Flutter does, and so
// does leaving it out without a name or outside a form.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _html(Widget body) async {
  final html = await renderDocument(ThorApp(child: body));
  return html.substring(html.indexOf('<body'));
}

Widget _inForm(Widget child) => Form(action: '/x', child: child);

// A control's own `disabled` attribute (the CSS and the form script name it too).
final _disabled = matches(RegExp(r'<(input|select)\b[^>]*\sdisabled[\s/>]'));

enum _Plan { free, pro }

void main() {
  group('named + inside a Form: enabled without onChanged', () {
    test('Checkbox', () async {
      final html = await _html(
        _inForm(const Checkbox(name: 'agree', value: false)),
      );
      expect(html, contains('name="agree"'));
      expect(html, isNot(_disabled));
    });

    test('Switch', () async {
      final html = await _html(
        _inForm(const Switch(name: 'news', value: true)),
      );
      expect(html, isNot(_disabled));
    });

    test('Slider', () async {
      final html = await _html(_inForm(const Slider(name: 'vol', value: 0.5)));
      expect(html, isNot(_disabled));
    });

    test('DropdownButton', () async {
      final html = await _html(
        _inForm(
          const DropdownButton<String>(
            name: 'size',
            value: 'm',
            items: [
              DropdownMenuItem(value: 'm', child: Text('M')),
              DropdownMenuItem(value: 'l', child: Text('L')),
            ],
          ),
        ),
      );
      expect(html, contains('<select'));
      expect(html, isNot(_disabled));
    });

    test('a named RadioGroup: its radios', () async {
      final html = await _html(
        _inForm(
          const RadioGroup<_Plan>(
            name: 'plan',
            groupValue: _Plan.free,
            child: Column(
              children: [
                Radio<_Plan>(value: _Plan.free),
                Radio<_Plan>(value: _Plan.pro),
              ],
            ),
          ),
        ),
      );
      expect(html, contains('name="plan"'));
      expect(html, isNot(_disabled));
    });

    test('the list tiles follow their control', () async {
      final html = await _html(
        _inForm(
          const Column(
            children: [
              CheckboxListTile(name: 'a', value: false),
              SwitchListTile(name: 'b', value: false),
            ],
          ),
        ),
      );
      expect(html, isNot(_disabled));
      expect(html, isNot(contains('aria-disabled')));
    });
  });

  group('Flutter\'s rule everywhere else', () {
    test('no name inside a Form: disabled', () async {
      for (final w in <Widget>[
        const Checkbox(value: false, onChanged: null),
        const Checkbox(value: false),
      ]) {
        expect(await _html(_inForm(w)), _disabled, reason: '$w');
      }
    });

    test('a name outside a Form: disabled', () async {
      for (final w in <Widget>[
        const Checkbox(name: 'a', value: false, onChanged: null),
        const Switch(name: 'a', value: false, onChanged: null),
        const Slider(name: 'a', value: 0.5, onChanged: null),
        const Checkbox(name: 'a', value: false),
      ]) {
        expect(await _html(w), _disabled, reason: '$w');
      }
    });

    test(
      'a RadioGroup without a name (a generated one) stays disabled',
      () async {
        for (final group in <Widget>[
          const RadioGroup<_Plan>(
            groupValue: _Plan.free,
            onChanged: null,
            child: Radio<_Plan>(value: _Plan.free),
          ),
          const RadioGroup<_Plan>(
            groupValue: _Plan.free,
            child: Radio<_Plan>(value: _Plan.free),
          ),
        ]) {
          expect(await _html(_inForm(group)), _disabled);
        }
      },
    );

    test(
      'named + inside a Form, onChanged: null on purpose: disabled',
      () async {
        for (final w in <Widget>[
          const Checkbox(name: 'a', value: false, onChanged: null),
          const Switch(name: 'a', value: false, onChanged: null),
          const Slider(name: 'a', value: 0.5, onChanged: null),
          const CheckboxListTile(name: 'a', value: false, onChanged: null),
          const SwitchListTile(name: 'a', value: false, onChanged: null),
          const DropdownButton<String>(
            name: 'a',
            value: 'm',
            onChanged: null,
            items: [DropdownMenuItem(value: 'm', child: Text('M'))],
          ),
        ]) {
          expect(await _html(_inForm(w)), _disabled, reason: '$w');
        }
      },
    );

    test('`locked ? null : handler` disables the field when locked', () async {
      Widget box(bool locked) => _inForm(
        Checkbox(
          name: 'terms',
          value: false,
          onChanged: locked ? null : (_) {},
        ),
      );
      expect(await _html(box(true)), _disabled);
      expect(await _html(box(false)), isNot(_disabled));
    });

    test(
      'a named RadioGroup with onChanged: null on purpose: disabled',
      () async {
        final html = await _html(
          _inForm(
            const RadioGroup<_Plan>(
              name: 'plan',
              groupValue: _Plan.free,
              onChanged: null,
              child: Radio<_Plan>(value: _Plan.free),
            ),
          ),
        );
        expect(html, _disabled);
      },
    );

    test('an onChanged keeps it enabled, named or not', () async {
      final html = await _html(
        _inForm(Checkbox(value: false, onChanged: (_) {})),
      );
      expect(html, isNot(_disabled));
    });
  });
}

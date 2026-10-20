@TestOn('vm')
library;

// The lite "attributes" part (`writeAttr`) under node with a tiny element:
// what a bound custom property takes (pixels, or a color for a row's
// `row.color`), and a bound `value` on a `<textarea>`. The color check is the
// same as the server's `safeCssColor`.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

final _hasNode = Process.runSync('node', ['--version']).exitCode == 0;

const _samples = <String>[
  '#fff',
  '#FFFF',
  '#4361ee',
  '#4361EE80',
  '#12',
  '#12345',
  '#ggg',
  'red',
  'transparent',
  'currentcolor',
  'rd',
  'a-b',
  'rgb(1, 2, 3)',
  'rgba(0 0 0 / 50%)',
  'hsl(120deg 50% 50%)',
  'oklch(0.7 0.1 200)',
  'rgb(var(--x))',
  'rgb(1,2,3);color:red',
  'url(http://x)',
  'calc(1px + 2px)',
  'rgb(1, 2, 3) !important',
  'expression(1)',
  '',
  '   ',
  '  #fff  ',
];

void main() {
  final source = File('lib/lite/parts/attributes.js').readAsStringSync();
  final script =
      '''
const src = ${jsonEncode(source)};
const { writeAttr, cssColor } = new Function(src + '; return { writeAttr, cssColor };')();
const make = (tagName = 'DIV') => {
  const props = new Map(), attrs = new Map();
  const el = {
    tagName, value: '', props, attrs,
    style: {
      getPropertyValue: (n) => props.get(n) ?? '',
      setProperty: (n, v) => props.set(n, v),
      removeProperty: (n) => props.delete(n),
    },
    hasAttribute: (n) => attrs.has(n),
    getAttribute: (n) => attrs.get(n) ?? null,
    setAttribute: (n, v) => attrs.set(n, v),
    removeAttribute: (n) => attrs.delete(n),
  };
  return el;
};
const out = {};
out.parity = ${jsonEncode(_samples)}.map((s) => cssColor(s));
const div = make();
writeAttr(div, '--tr-color-S-hex', '#4361ee');
out.color = div.props.get('--tr-color-S-hex');
writeAttr(div, '--tr-color-S-hex', 'rgb(1,2,3);x');
out.bad = div.props.has('--tr-color-S-hex');
writeAttr(div, '--tr-S-len', '12');
out.px = div.props.get('--tr-S-len');
const area = make('TEXTAREA');
writeAttr(area, 'value', 'a < b');
out.areaValue = area.value;
out.areaAttr = area.attrs.has('value');
const input = make('INPUT');
writeAttr(input, 'value', 'x');
out.inputAttr = input.attrs.get('value');
const select = make('SELECT');
writeAttr(select, 'value', 'tablet');
out.selectValue = select.value;
out.selectAttr = select.attrs.has('value');
// A group of radios (a SegmentedButton) checks the one with the value.
const radios = ['phone', 'tablet'].map((value) => ({ value, checked: value === 'phone' }));
const group = make();
group.attrs.set('role', 'radiogroup');
group.querySelectorAll = () => radios;
writeAttr(group, 'value', 'tablet');
out.radios = radios.map((r) => r.checked);
out.groupAttr = group.attrs.has('value');
const details = make('DETAILS');
writeAttr(details, 'open', 'true');
out.openOn = details.attrs.get('open');
writeAttr(details, 'open', 'false');
out.openOff = details.attrs.has('open');
out.openParity = ['true', 'false', '', 'x'].map((v) => { writeAttr(details, 'open', v); return details.attrs.get('open') ?? null; });
console.log(JSON.stringify(out));
''';

  group('lite attributes part', skip: _hasNode ? false : 'needs node', () {
    late Map<String, Object?> out;
    setUpAll(() {
      final r = Process.runSync('node', ['-e', script]);
      if (r.exitCode != 0) fail('node failed:\n${r.stderr}');
      out = jsonDecode((r.stdout as String).trim()) as Map<String, Object?>;
    });

    test('a row color is written as a color; a non-color unsets it', () {
      expect(out['color'], '#4361ee');
      expect(out['bad'], isFalse);
      expect(out['px'], '12px');
    });

    test('a bound value on a textarea is the control value only', () {
      expect(out['areaValue'], 'a < b');
      expect(out['areaAttr'], isFalse);
      expect(out['inputAttr'], 'x');
    });

    test('a select and a radio group follow a bound value', () {
      expect(out['selectValue'], 'tablet');
      expect(out['radios'], [false, true]);
      // `value` is not an attribute of a <select> or a radio group.
      expect(out['selectAttr'], isFalse);
      expect(out['groupAttr'], isFalse);
    });

    test('a bound open turns a <details> on and off, as the server does', () {
      expect(out['openOn'], '');
      expect(out['openOff'], isFalse);
      expect(out['openParity'], [
        for (final v in ['true', 'false', '', 'x'])
          safeAttributeValue('open', v),
      ]);
    });

    test('the browser and the server accept the same colors', () {
      final js = (out['parity'] as List).cast<String?>();
      for (var i = 0; i < _samples.length; i++) {
        expect(js[i], safeCssColor(_samples[i]), reason: '"${_samples[i]}"');
      }
    });
  });

  group('safeCssColor', () {
    test('hex, plain functions and keywords', () {
      expect(safeCssColor('#4361ee'), '#4361ee');
      expect(safeCssColor(' #fff '), '#fff');
      expect(safeCssColor('rgba(0 0 0 / 50%)'), 'rgba(0 0 0 / 50%)');
      expect(safeCssColor('red'), 'red');
    });

    test('nothing that can carry more than a color', () {
      for (final bad in [
        '#12345',
        'rgb(1,2,3);color:red',
        'url(http://x)',
        'rgb(var(--x))',
        'calc(1px + 2px)',
        'a;b',
        '',
      ]) {
        expect(safeCssColor(bad), isNull, reason: bad);
      }
    });
  });
}

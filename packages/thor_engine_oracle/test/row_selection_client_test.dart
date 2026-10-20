// `row.selected` (only the rows that were and are now selected change state),
// per-row custom properties and boolean attributes (`row.length`,
// `row.attribute('hidden', …)`) and the property of a control a bound value
// writes (`value`, `checked`) in the dart2js engine.
@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';
import 'package:thor_engine_oracle/src/controllers_client.dart'
    show writeBoundAttribute;
import 'package:web/web.dart' as web;

web.HTMLElement mount(String html) {
  final root = web.document.createElement('div') as web.HTMLElement;
  root.innerHTML = html.toJS;
  web.document.body!.append(root);
  // ignore: unnecessary_lambdas
  addTearDown(() => root.remove());
  return root;
}

class _Pick extends ThorState {
  final items = state(const ['a', 'b', 'c']);
  final picked = state('b');

  /// How many times a row's text was asked: a selection must not ask any.
  var nameCalls = 0;

  @override
  String get $type => 'Pick';

  @override
  List<ThorMember> get $members => [
    ThorMember.state('items', items),
    ThorMember.state('picked', picked),
    ThorMember(
      'itemKey',
      itemKey,
      arity: 1,
      callWithItem: (i) => itemKey(i! as String),
    ),
    ThorMember(
      'nameOf',
      nameOf,
      arity: 1,
      callWithItem: (i) => nameOf(i! as String),
    ),
    ThorMember('left', left, arity: 1, callWithItem: (i) => left(i! as String)),
    ThorMember(
      'isOff',
      isOff,
      arity: 1,
      callWithItem: (i) => isOff(i! as String),
    ),
  ];

  String itemKey(String i) => i;
  String nameOf(String i) {
    nameCalls++;
    return i.toUpperCase();
  }

  double left(String i) => i.codeUnitAt(0) - 96.5;
  bool isOff(String i) => i == 'c';
}

List<web.Element> _rows(web.Element root) => [
  for (final r in root.querySelectorAll('li[data-tk]').toList) r,
];

extension on web.NodeList {
  List<web.Element> get toList => [
    for (var i = 0; i < length; i++) item(i)! as web.Element,
  ];
}

const _list =
    '<ul data-tl="Pick.items" data-tlk="Pick.itemKey">'
    '<li data-tk="a" data-tfa="--tr-Pick-left:Pick.left;hidden:Pick.isOff" style="--tr-Pick-left:0px">'
    '<b data-tf="Pick.nameOf">A</b>'
    '<i data-tvf="Pick.picked" data-tvi="0" data-tvs>off</i></li>'
    '<li data-tk="b" data-tfa="--tr-Pick-left:Pick.left;hidden:Pick.isOff" style="--tr-Pick-left:0px">'
    '<b data-tf="Pick.nameOf">B</b>'
    '<i data-tvf="Pick.picked" data-tvi="1" data-tvs>on</i></li>'
    '<li data-tk="c" data-tfa="--tr-Pick-left:Pick.left;hidden:Pick.isOff" style="--tr-Pick-left:0px">'
    '<b data-tf="Pick.nameOf">C</b>'
    '<i data-tvf="Pick.picked" data-tvi="0" data-tvs>off</i></li>'
    '<template data-tlt="Pick.items">'
    '<li data-tfa="--tr-Pick-left:Pick.left;hidden:Pick.isOff" style="--tr-Pick-left:0px">'
    '<b data-tf="Pick.nameOf"></b>'
    '<i data-tvf="Pick.picked" data-tvi="0" data-tvs data-tp-1="|#|=on">off</i>'
    '</li></template></ul>';

const _features = [ListsFeature(rowAttributes: RowAttributes())];

String _state(web.Element row) => row.querySelector('i')!.textContent!;

void main() {
  test('row.selected: the selection moves two rows and asks none', () {
    final pick = _Pick();
    final root = mount(_list);
    addTearDown(startThor([pick], root: root, features: _features));
    // Starts from the field's value, whatever the server drew.
    expect([for (final r in _rows(root)) _state(r)], ['off', 'on', 'off']);
    final asked = pick.nameCalls;
    pick.picked.value = 'c';
    expect([for (final r in _rows(root)) _state(r)], ['off', 'off', 'on']);
    expect(
      [
        for (final r in _rows(root))
          r.querySelector('i')!.getAttribute('data-tvi'),
      ],
      ['0', '0', '1'],
    );
    expect(pick.nameCalls, asked, reason: 'no row was rendered again');
    pick.picked.value = 'nobody';
    expect([for (final r in _rows(root)) _state(r)], ['off', 'off', 'off']);
  });

  test('row.selected: rows the browser adds start in the right state', () {
    final pick = _Pick();
    final root = mount(_list);
    addTearDown(startThor([pick], root: root, features: _features));
    pick.items.value = ['a', 'b', 'c', 'd'];
    pick.picked.value = 'd';
    final rows = _rows(root);
    expect(rows.length, 4);
    expect([for (final r in rows) _state(r)], ['off', 'off', 'off', 'on']);
    // A new row for the key that is already selected.
    pick.items.value = ['a', 'b', 'c', 'd', 'e'];
    pick.picked.value = 'e';
    expect([for (final r in _rows(root)) _state(r)].last, 'on');
    expect([for (final r in _rows(root)) _state(r)].where((s) => s == 'on'), [
      'on',
    ]);
  });

  test('row.length and a bound boolean follow each row', () {
    final pick = _Pick();
    final root = mount(_list);
    addTearDown(startThor([pick], root: root, features: _features));
    final rows = _rows(root);
    expect(
      [
        for (final r in rows)
          (r as web.HTMLElement).style.getPropertyValue('--tr-Pick-left'),
      ],
      ['0.5px', '1.5px', '2.5px'],
    );
    expect(
      [for (final r in rows) r.hasAttribute('hidden')],
      [false, false, true],
    );
    // A cloned row from the template, with its own values.
    pick.items.value = ['a', 'b', 'c', 'd'];
    final added = _rows(root).last as web.HTMLElement;
    expect(added.style.getPropertyValue('--tr-Pick-left'), '3.5px');
    expect(added.hasAttribute('hidden'), isFalse);
  });

  test('a bound value moves a control the user already edited', () {
    final root = mount('<input value="1"><input type="checkbox">');
    final input = root.querySelector('input')! as web.HTMLInputElement;
    final check =
        root.querySelectorAll('input').item(1)! as web.HTMLInputElement;
    // The user types: the property leaves the attribute behind.
    input.value = '60';
    writeBoundAttribute(input, 'value', '30');
    expect(input.getAttribute('value'), '30');
    expect(input.value, '30', reason: 'the property follows the binding');
    check.checked = true;
    writeBoundAttribute(check, 'checked', 'false');
    expect(check.checked, isFalse);
    expect(check.hasAttribute('checked'), isFalse);
    writeBoundAttribute(check, 'checked', 'true');
    expect(check.checked, isTrue);
    // disabled / readonly / hidden: present for true, gone otherwise.
    writeBoundAttribute(input, 'disabled', 'true');
    expect(input.disabled, isTrue);
    writeBoundAttribute(input, 'disabled', 'false');
    expect(input.disabled, isFalse);
    writeBoundAttribute(input, 'readonly', 'true');
    expect(input.readOnly, isTrue);
    writeBoundAttribute(input, 'hidden', 'true');
    expect(input.hidden, isTrue);
  });
}

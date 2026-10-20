@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';
import 'package:web/web.dart' as web;

// The member list thor generates for [_Order], by hand.
abstract class _OrderMembers extends ThorState {
  @override
  String get $type => 'Order';

  @override
  List<ThorMember> get $members {
    final s = this as _Order;
    return [
      ThorMember.state('picks', s.picks),
      ThorMember('setFruit', s.setFruit, arity: 1, call: s.setFruit),
    ];
  }
}

class _Order extends _OrderMembers {
  final picks = state(const <String>[]);
  void setFruit(String? v) => picks.value = [...picks.value, '$v'];
}

/// A `DropdownMenu` as thor_ui renders it (entries: Apple, Apricot,
/// Banana, Blueberry, Cherry disabled; Banana picked), with or without the
/// filter field.
web.HTMLElement mount({bool filter = false, String flags = 's'}) {
  const entries = [
    ('apple', 'Apple'),
    ('apricot', 'Apricot'),
    ('banana', 'Banana'),
    ('blueberry', 'Blueberry'),
    ('cherry', 'Cherry'),
  ];
  String option((String, String) e) =>
      '<div role="option" aria-selected="${e.$1 == 'banana'}"'
      '${e.$1 == 'cherry' ? ' aria-disabled="true"' : ''}>${e.$2}</div>';
  final options = entries.map(option).join();
  final list = filter ? 'm-list' : 'm-menu';
  final root = web.document.createElement('div') as web.HTMLElement;
  root.innerHTML =
      '<div data-t-dd="$flags">'
              '<button type="button" role="combobox" aria-haspopup="listbox" '
              'aria-expanded="false" aria-controls="$list" '
              'popovertarget="m-menu"><span data-tdl>Banana</span></button>'
              '<select name="fruit" data-t-on="change:Order.setFruit">'
              '${entries.map((e) => '<option value="${e.$1}"${e.$1 == 'banana' ? ' selected' : ''}>${e.$2}</option>').join()}'
              '</select>'
              '<div id="m-menu" popover="auto"'
              '${filter ? '><label><input role="combobox" aria-controls="m-list"></label><div id="m-list" role="listbox">$options</div>' : ' role="listbox">$options'}'
              '</div></div>'
          .toJS;
  web.document.body!.append(root);
  // A lambda: tear-offs of interop members are not allowed.
  // ignore: unnecessary_lambdas
  addTearDown(() => root.remove());
  return root;
}

void key(web.Element el, String key) => el.dispatchEvent(
  web.KeyboardEvent(
    'keydown',
    web.KeyboardEventInit(key: key, bubbles: true, cancelable: true),
  ),
);

/// `toggle` events are queued: waits until [ready] (what the event sets),
/// with a deadline, not for a fixed time a loaded machine can stretch.
Future<void> settle(bool Function() ready) async {
  final end = DateTime.now().add(const Duration(seconds: 20));
  while (!ready() && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

class _Parts {
  _Parts(this.root);
  final web.Element root;
  web.HTMLElement get button =>
      root.querySelector('button')! as web.HTMLElement;
  web.HTMLElement get panel =>
      root.querySelector('[popover]')! as web.HTMLElement;
  web.HTMLSelectElement get select =>
      root.querySelector('select')! as web.HTMLSelectElement;
  web.HTMLInputElement get field =>
      root.querySelector('input')! as web.HTMLInputElement;
  bool get open => panel.matches(':popover-open');
  String get expanded => button.getAttribute('aria-expanded')!;
  String get label => root.querySelector('[data-tdl]')!.textContent!;
  String? get active {
    final id = button.getAttribute('aria-activedescendant');
    return id == null ? null : web.document.getElementById(id)?.textContent;
  }

  List<String> get selected {
    final list = root.querySelectorAll('[aria-selected="true"]');
    return [for (var i = 0; i < list.length; i++) list.item(i)!.textContent!];
  }

  List<String> get visible {
    final list = root.querySelectorAll('[role="option"]:not([hidden])');
    return [for (var i = 0; i < list.length; i++) list.item(i)!.textContent!];
  }

  web.Element option(String text) {
    final list = root.querySelectorAll('[role="option"]');
    for (var i = 0; i < list.length; i++) {
      if (list.item(i)!.textContent == text) {
        return list.item(i)! as web.Element;
      }
    }
    throw StateError(text);
  }
}

void main() {
  test('click opens on the picked entry; arrows skip disabled entries; '
      'Enter picks, updates the button and the select, reaches the state '
      'and closes', () async {
    final order = _Order();
    final m = _Parts(mount());
    addTearDown(
      startThor([order], root: m.root, features: const [DropdownMenuFeature()]),
    );
    m.button.click();
    await settle(() => m.expanded == 'true' && m.active == 'Banana');
    expect(m.open, isTrue);
    expect(m.expanded, 'true');
    expect(m.active, 'Banana', reason: 'opens on the picked entry');
    key(m.button, 'ArrowDown');
    expect(m.active, 'Blueberry');
    key(m.button, 'ArrowDown');
    expect(m.active, 'Blueberry', reason: 'Cherry is disabled; no wrap');
    key(m.button, 'Home');
    expect(m.active, 'Apple');
    key(m.button, 'End');
    expect(m.active, 'Blueberry');
    key(m.button, 'Enter');
    expect(m.open, isFalse);
    expect(m.expanded, 'false');
    expect(m.label, 'Blueberry');
    expect(m.select.value, 'blueberry', reason: 'what a form posts');
    expect(m.selected, ['Blueberry']);
    expect(order.picks.value, ['blueberry']);
    expect(m.button.hasAttribute('aria-activedescendant'), isFalse);
  });

  test('type-ahead on the closed button opens and finds; the same letter '
      'cycles; Space picks once typing pauses', () async {
    final order = _Order();
    final m = _Parts(mount());
    addTearDown(
      startThor([order], root: m.root, features: const [DropdownMenuFeature()]),
    );
    key(m.button, 'a');
    expect(m.open, isTrue);
    expect(m.active, 'Apple', reason: 'the next "a…" after Banana, wrapping');
    key(m.button, 'p');
    key(m.button, 'r');
    expect(m.active, 'Apricot', reason: '"apr"');
    key(m.button, 'b');
    await Future<void>.delayed(const Duration(milliseconds: 750));
    key(m.button, 'b');
    expect(m.active, 'Banana', reason: 'a new search after a pause');
    key(m.button, 'b');
    expect(m.active, 'Blueberry');
    await Future<void>.delayed(const Duration(milliseconds: 750));
    key(m.button, ' ');
    expect(m.label, 'Blueberry');
    expect(order.picks.value, ['blueberry']);
  });

  test('without the search flag, letters do nothing', () async {
    final m = _Parts(mount(flags: ''));
    addTearDown(
      startThor([], root: m.root, features: const [DropdownMenuFeature()]),
    );
    key(m.button, 'a');
    expect(m.open, isFalse);
  });

  test('the filter field: focused on open, typing hides the rest and '
      'highlights the first match, Enter picks, reopening clears', () async {
    final order = _Order();
    final m = _Parts(mount(filter: true, flags: 'sf'));
    addTearDown(
      startThor([order], root: m.root, features: const [DropdownMenuFeature()]),
    );
    m.button.click();
    await settle(() => web.document.activeElement == m.field);
    expect(web.document.activeElement, m.field);
    m.field.value = 'ap';
    m.field.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    expect(m.visible, ['Apple', 'Apricot']);
    expect(m.active, 'Apple');
    expect(
      m.field.getAttribute('aria-activedescendant'),
      m.button.getAttribute('aria-activedescendant'),
    );
    key(m.field, 'ArrowDown');
    expect(m.active, 'Apricot');
    m.field.value = 'zzz';
    m.field.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    expect(m.visible, isEmpty);
    expect(m.active, isNull);
    key(m.field, 'Enter');
    expect(m.open, isTrue, reason: 'nothing to pick');
    m.field.value = 'rry';
    m.field.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    expect(m.visible, ['Blueberry', 'Cherry']);
    expect(m.active, 'Blueberry', reason: 'Cherry is disabled');
    key(m.field, 'Enter');
    expect(m.open, isFalse);
    expect(m.label, 'Blueberry');
    expect(web.document.activeElement, m.button);
    await settle(() => m.expanded == 'false'); // the close is through
    m.button.click();
    await settle(
      () => m.field.value == '' && m.visible.length == 5 && m.active != null,
    );
    expect(m.field.value, '');
    expect(m.visible, hasLength(5));
    expect(m.active, 'Blueberry');
  });

  test('requestFocusOnTap: false keeps focus on the button', () async {
    final m = _Parts(mount(filter: true, flags: 'n'));
    addTearDown(
      startThor([], root: m.root, features: const [DropdownMenuFeature()]),
    );
    m.button
      ..focus()
      ..click();
    await settle(() => m.expanded == 'true');
    expect(m.open, isTrue);
    expect(web.document.activeElement, m.button);
  });

  test(
    'the pointer highlights and a click picks (not a disabled entry)',
    () async {
      final order = _Order();
      final m = _Parts(mount());
      addTearDown(
        startThor(
          [order],
          root: m.root,
          features: const [DropdownMenuFeature()],
        ),
      );
      m.button.click();
      await settle(() => m.active == 'Banana');
      m.option('Cherry')
        ..dispatchEvent(
          web.PointerEvent('pointerover', web.PointerEventInit(bubbles: true)),
        )
        ..dispatchEvent(
          web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
        );
      expect(m.active, 'Banana', reason: 'a disabled entry is inert');
      expect(m.open, isTrue);
      m
          .option('Apple')
          .dispatchEvent(
            web.PointerEvent(
              'pointerover',
              web.PointerEventInit(bubbles: true),
            ),
          );
      expect(m.active, 'Apple');
      m
          .option('Apple')
          .dispatchEvent(
            web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
          );
      expect(m.label, 'Apple');
      expect(m.open, isFalse);
      // The same entry again: Flutter's onSelected runs on every pick.
      await settle(() => m.expanded == 'false'); // the close is through
      m.button.click();
      await settle(() => m.expanded == 'true' && m.active != null);
      m
          .option('Apple')
          .dispatchEvent(
            web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
          );
      expect(order.picks.value, ['apple', 'apple']);
    },
  );

  test('closing natively (Esc, light dismiss) resets the button', () async {
    final m = _Parts(mount());
    addTearDown(
      startThor([], root: m.root, features: const [DropdownMenuFeature()]),
    );
    m.button.click();
    await settle(() => m.active == 'Banana');
    expect(m.active, 'Banana');
    m.panel.hidePopover();
    await settle(() => m.expanded == 'false' && m.active == null);
    expect(m.expanded, 'false');
    expect(m.active, isNull);
    expect(m.root.querySelector('[data-active]'), isNull);
    expect(m.label, 'Banana', reason: 'closing picks nothing');
  });

  test('a missing DropdownMenuFeature is reported in debug', () {
    final m = _Parts(mount());
    expect(
      missingFeatures(m.root, const []).join(),
      contains('DropdownMenuFeature'),
    );
  });
}

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
      ThorMember('pick', s.pick, arity: 1, call: (a) => s.pick(a!)),
    ];
  }
}

class _Order extends _OrderMembers {
  final picks = state(const <String>[]);
  void pick(String v) => picks.value = [...picks.value, v];
}

/// An `Autocomplete` as thor_ui renders it: a field and a manual popover
/// listbox of options (apple, apricot, banana, cherry disabled).
web.HTMLElement mount({
  String flags = 'f',
  bool state = false,
  bool status = false,
  bool inline = false,
  List<String> fruits = const ['apple', 'apricot', 'banana', 'cherry'],
}) {
  String option(String f) =>
      '<div role="option" aria-selected="false"'
      '${f == 'cherry' ? ' aria-disabled="true"' : ''}'
      '${state ? ' data-t-on="click:Order.pick" data-tx="$f"' : ''}>$f</div>';
  final root = web.document.createElement('div') as web.HTMLElement;
  root.innerHTML =
      '<form><div data-t-ac="$flags" style="anchor-name:--a;anchor-scope:--a">'
              '<input type="text" name="q">'
              '${status ? '<div role="status" aria-live="polite" data-t-ac-status="{count} results" data-t-ac-one="1 result" data-t-ac-none="No results"></div>' : ''}'
              '${inline ? '<div id="ac-list" data-t-inl hidden role="listbox">' : '<div id="ac-list" popover="manual" role="listbox">'}'
              '${fruits.map(option).join()}</div></div>'
              '<button type="submit">go</button></form>'
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

void type(web.HTMLInputElement field, String text) {
  field.value = text;
  field.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
}

class _Parts {
  _Parts(this.root);
  final web.Element root;
  web.HTMLElement get panel =>
      root.querySelector('[popover],[data-t-inl]')! as web.HTMLElement;
  web.HTMLInputElement get field =>
      root.querySelector('input')! as web.HTMLInputElement;
  bool get open => panel.hasAttribute('popover')
      ? panel.matches(':popover-open')
      : !panel.hasAttribute('hidden');
  String get expanded => field.getAttribute('aria-expanded')!;
  String? get active {
    final id = field.getAttribute('aria-activedescendant');
    return id == null ? null : web.document.getElementById(id)?.textContent;
  }

  List<String> get visible {
    final list = root.querySelectorAll('[role="option"]:not([hidden])');
    return [for (var i = 0; i < list.length; i++) list.item(i)!.textContent!];
  }

  web.HTMLElement option(String text) {
    final list = root.querySelectorAll('[role="option"]');
    for (var i = 0; i < list.length; i++) {
      if (list.item(i)!.textContent == text) {
        return list.item(i)! as web.HTMLElement;
      }
    }
    throw StateError(text);
  }
}

web.FocusEvent focus(String type, [web.EventTarget? related]) => web.FocusEvent(
  type,
  web.FocusEventInit(bubbles: true, relatedTarget: related),
);

void main() {
  void start(web.Element root, [List<ThorState> states = const []]) =>
      addTearDown(
        startThor(states, root: root, features: const [AutocompleteFeature()]),
      );

  test('the field becomes a combobox on focus and opens the panel with the '
      'options', () async {
    final m = _Parts(mount());
    start(m.root);
    expect(
      m.field.hasAttribute('role'),
      isFalse,
      reason: 'plain without focus',
    );
    m.field.focus();
    expect(m.field.getAttribute('role'), 'combobox');
    expect(m.field.getAttribute('aria-controls'), 'ac-list');
    expect(m.field.getAttribute('aria-autocomplete'), 'list');
    expect(m.open, isTrue);
    expect(m.expanded, 'true');
  });

  test('typing hides the options the text does not match; no match closes; '
      'clearing shows them again', () async {
    final m = _Parts(mount());
    start(m.root);
    m.field.focus();
    type(m.field, 'ap');
    expect(m.visible, ['apple', 'apricot']);
    expect(m.open, isTrue);
    type(m.field, 'APR');
    expect(m.visible, ['apricot'], reason: 'any case');
    type(m.field, 'zzz');
    expect(m.visible, isEmpty);
    expect(m.open, isFalse, reason: 'nothing to show');
    type(m.field, '');
    expect(m.visible, hasLength(4));
    expect(m.open, isTrue);
  });

  test(
    'without the filter flag every option stays (the page\'s own list)',
    () async {
      final m = _Parts(mount(flags: ''));
      start(m.root);
      m.field.focus();
      type(m.field, 'zzz');
      expect(m.visible, hasLength(4));
      expect(m.open, isTrue);
    },
  );

  test('arrows move the highlight (skipping disabled, wrapping as the APG '
      'does); nothing is highlighted before', () async {
    final m = _Parts(mount());
    start(m.root);
    m.field.focus();
    expect(m.active, isNull);
    key(m.field, 'ArrowDown');
    expect(m.active, 'apple');
    key(m.field, 'ArrowDown');
    key(m.field, 'ArrowDown');
    expect(m.active, 'banana');
    key(m.field, 'ArrowDown');
    expect(m.active, 'apple', reason: 'cherry is disabled; past the end wraps');
    key(m.field, 'ArrowUp');
    expect(m.active, 'banana', reason: 'before the first wraps to the last');
    key(m.field, 'ArrowUp');
    expect(m.active, 'apricot');
  });

  test('ArrowUp with nothing highlighted goes to the last option', () async {
    final m = _Parts(mount());
    start(m.root);
    m.field.focus();
    key(m.field, 'ArrowUp');
    expect(m.active, 'banana');
  });

  test('Home and End give the highlight back to the field and are left to '
      'it (the caret)', () async {
    final m = _Parts(mount());
    start(m.root);
    m.field.focus();
    for (final k in ['Home', 'End']) {
      key(m.field, 'ArrowDown');
      expect(m.active, isNotNull);
      final e = web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: k, bubbles: true, cancelable: true),
      );
      m.field.dispatchEvent(e);
      expect(m.active, isNull, reason: '$k returns to the field');
      expect(e.defaultPrevented, isFalse, reason: '$k moves the caret');
      expect(m.open, isTrue);
    }
  });

  // The region waits for the typing to pause (a screen reader would read
  // every step of "apple" otherwise); closing empties it at once.
  Future<void> pause() =>
      Future<void>.delayed(const Duration(milliseconds: 400));

  test('a polite live region says how many options there are', () async {
    final m = _Parts(mount(status: true));
    start(m.root);
    final status = m.root.querySelector('[data-t-ac-status]')!;
    expect(status.textContent, '', reason: 'nothing before the focus');
    m.field.focus();
    await pause();
    expect(status.textContent, '3 results', reason: 'cherry is disabled');
    type(m.field, 'ap');
    await pause();
    expect(status.textContent, '2 results');
    type(m.field, 'apple');
    await pause();
    expect(status.textContent, '1 result');
    type(m.field, 'zzz');
    await pause();
    expect(status.textContent, 'No results');
    type(m.field, '');
    await pause();
    expect(status.textContent, '3 results');
    key(m.field, 'Escape');
    expect(status.textContent, '', reason: 'closed: no stale count, at once');
    m.field.dispatchEvent(focus('focusout'));
    expect(status.textContent, '');
  });

  test('fast typing says only where it stopped; closing cancels a pending '
      'announcement', () async {
    final m = _Parts(mount(status: true));
    start(m.root);
    final status = m.root.querySelector('[data-t-ac-status]')!;
    var writes = 0;
    web.MutationObserver(
      ((JSArray<web.MutationRecord> r, web.MutationObserver _) =>
              writes += r.length)
          .toJS,
    ).observe(status, web.MutationObserverInit(childList: true));
    m.field.focus();
    await pause();
    writes = 0;
    for (final t in ['a', 'ap', 'app', 'appl', 'apple']) {
      type(m.field, t);
    }
    await pause();
    expect(status.textContent, '1 result');
    expect(writes, lessThanOrEqualTo(2), reason: 'not one per key');
    // A change, then Escape before the pause: nothing stale arrives.
    type(m.field, 'ap');
    key(m.field, 'Escape');
    await pause();
    expect(status.textContent, '');
  });

  test('{count} may appear more than once in the text', () async {
    final m = _Parts(mount(status: true));
    m.root
        .querySelector('[data-t-ac-status]')!
        .setAttribute('data-t-ac-status', '{count} of {count}');
    start(m.root);
    m.field.focus();
    await pause();
    expect(m.root.querySelector('[data-t-ac-status]')!.textContent, '3 of 3');
  });

  test('an empty field with no options announces nothing', () async {
    final m = _Parts(mount(status: true, flags: ''));
    m.panel.innerHTML = ''.toJS;
    start(m.root);
    m.field.focus();
    expect(m.root.querySelector('[data-t-ac-status]')!.textContent, '');
  });

  test('Enter picks the highlighted option: the field takes its text, the '
      'panel closes, the handler runs; with none highlighted it is the '
      'form\'s', () async {
    final order = _Order();
    final m = _Parts(mount(state: true));
    start(m.root, [order]);
    var inputs = 0;
    m.field.addEventListener('input', ((web.Event _) => inputs++).toJS);
    m.field.focus();
    key(m.field, 'Enter');
    expect(m.open, isTrue, reason: 'nothing highlighted: not handled');
    expect(order.picks.value, isEmpty);
    key(m.field, 'ArrowDown');
    key(m.field, 'ArrowDown');
    final enter = web.KeyboardEvent(
      'keydown',
      web.KeyboardEventInit(key: 'Enter', bubbles: true, cancelable: true),
    );
    m.field.dispatchEvent(enter);
    expect(enter.defaultPrevented, isTrue, reason: 'the form must not submit');
    expect(m.field.value, 'apricot');
    expect(inputs, 1, reason: 'the controller hears it once');
    expect(m.open, isFalse);
    expect(m.expanded, 'false');
    expect(order.picks.value, ['apricot']);
    expect(m.option('apricot').getAttribute('aria-selected'), 'true');
    expect(web.document.activeElement, m.field);
  });

  test(
    'a click picks; the pointer highlights; mousedown keeps the focus',
    () async {
      final order = _Parts(mount(state: true));
      start(order.root);
      order.field.focus();
      final down = web.MouseEvent(
        'mousedown',
        web.MouseEventInit(bubbles: true, cancelable: true),
      );
      order.option('banana').dispatchEvent(down);
      expect(down.defaultPrevented, isTrue);
      order
          .option('banana')
          .dispatchEvent(
            web.PointerEvent(
              'pointerover',
              web.PointerEventInit(bubbles: true),
            ),
          );
      expect(order.active, 'banana');
      order.option('banana').click();
      expect(order.field.value, 'banana');
      expect(order.open, isFalse);
    },
  );

  test(
    'Esc closes and keeps the text; typing opens again; Tab closes',
    () async {
      final m = _Parts(mount());
      start(m.root);
      m.field.focus();
      type(m.field, 'a');
      expect(m.open, isTrue);
      key(m.field, 'Escape');
      expect(m.open, isFalse);
      expect(m.field.value, 'a');
      type(m.field, 'ap');
      expect(m.open, isTrue);
      key(m.field, 'Tab');
      expect(m.open, isFalse);
    },
  );

  test(
    'the focus leaving closes the panel; focusing it again reopens',
    () async {
      final m = _Parts(mount());
      start(m.root);
      m.field.focus();
      expect(m.open, isTrue);
      m.field.dispatchEvent(focus('focusout'));
      expect(m.open, isFalse);
      expect(m.expanded, 'false');
      m.field.dispatchEvent(focus('focusin'));
      expect(m.open, isTrue);
    },
  );

  test(
    'options a state adds while the field has focus open the panel',
    () async {
      final m = _Parts(mount(flags: ''));
      // No options at first.
      final list = m.panel;
      final firstOptions = list.innerHTML;
      list.innerHTML = ''.toJS;
      start(m.root);
      m.field.focus();
      expect(m.open, isFalse);
      list.innerHTML = firstOptions;
      // The observer is queued: wait for it.
      final end = DateTime.now().add(const Duration(seconds: 10));
      while (!m.open && DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(m.open, isTrue);
      list.innerHTML = ''.toJS;
      final gone = DateTime.now().add(const Duration(seconds: 10));
      while (m.open && DateTime.now().isBefore(gone)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(m.open, isFalse, reason: 'no options: closed');
    },
  );

  test('w: every typed word matches, any order, accents ignored', () {
    final m = _Parts(
      mount(flags: 'fw', fruits: ['New York', 'York, New', 'Café con leche']),
    );
    start(m.root);
    m.field.focus();
    type(m.field, 'york new');
    expect(m.visible, ['New York', 'York, New']);
    type(m.field, 'CAFE leche');
    expect(m.visible, ['Café con leche']);
  });

  test('without w the whole phrase is matched', () {
    final m = _Parts(mount(fruits: ['New York', 'York, New']));
    start(m.root);
    m.field.focus();
    type(m.field, 'york new');
    expect(m.visible, isEmpty);
  });

  test('inline: the panel is shown while there is an option, Esc is left to '
      'the page', () {
    final m = _Parts(mount(flags: 'fi', inline: true));
    start(m.root);
    m.field.focus();
    expect(m.open, isTrue);
    expect(m.expanded, 'true');
    key(m.field, 'Escape');
    expect(m.open, isTrue, reason: 'Esc is the page\'s');
    type(m.field, 'zzz');
    expect(m.open, isFalse);
  });

  test('h: the first usable option is active, and Home keeps it', () {
    final m = _Parts(mount(flags: 'fh'));
    start(m.root);
    m.field.focus();
    expect(m.active, 'apple');
    type(m.field, 'ban');
    expect(m.active, 'banana');
    key(m.field, 'Home');
    expect(m.active, 'banana');
  });

  test('a row that stops being an option loses its highlight mark', () async {
    final m = _Parts(mount());
    start(m.root);
    m.field.focus();
    key(m.field, 'ArrowDown');
    final first = m.option('apple');
    expect(first.hasAttribute('data-active'), isTrue);
    first.setAttribute('role', 'presentation');
    final end = DateTime.now().add(const Duration(seconds: 10));
    while (first.hasAttribute('data-active') && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(first.hasAttribute('data-active'), isFalse);
    expect(m.field.hasAttribute('aria-activedescendant'), isFalse);
  });
}

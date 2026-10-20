@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';
import 'package:web/web.dart' as web;

web.HTMLElement mount(String html) {
  final root = web.document.createElement('div') as web.HTMLElement;
  root.innerHTML = html.toJS;
  web.document.body!.append(root);
  // A lambda: tear-offs of interop members are not allowed.
  // ignore: unnecessary_lambdas
  addTearDown(() => root.remove());
  return root;
}

void key(
  web.Element el,
  String key, {
  bool shift = false,
  bool meta = false,
  bool control = false,
  String code = '',
}) => el.dispatchEvent(
  web.KeyboardEvent(
    'keydown',
    web.KeyboardEventInit(
      key: key,
      code: code,
      shiftKey: shift,
      metaKey: meta,
      ctrlKey: control,
      bubbles: true,
      cancelable: true,
    ),
  ),
);

void click(web.Element el) => el.dispatchEvent(
  web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
);

// The member list thor generates for [_Grid], by hand.
abstract class _GridMembers extends ThorState {
  @override
  String get $type => 'Grid';

  @override
  List<ThorMember> get $members {
    final s = this as _Grid;
    return [
      ThorMember.state('row', s.row),
      ThorMember.state('items', s.items),
      ThorMember.state('mode', s.mode),
      ThorMember.controller('scroll', s.scroll),
      ThorMember.controller('draft', s.draft),
      ThorMember.controller('focus', s.focus),
      ThorMember.controller('details', s.details),
      ThorMember('copy', s.copy, call: (_) => s.copy()),
      ThorMember('paste', s.paste, call: (_) => s.paste()),
      ThorMember('down', s.down, call: (_) => s.down()),
      ThorMember('undo', s.undo, call: (_) => s.undo()),
      ThorMember('go', s.go, arity: 1, call: (a) => s.go(int.parse(a!))),
      ThorMember('top', s.top, call: (_) => s.top()),
      ThorMember(
        'width',
        s.width,
        arity: 1,
        call: (a) => s.width(int.parse(a!)),
      ),
      ThorMember('shift', s.shift, call: (_) => s.shift()),
      ThorMember('type', s.type, arity: 1, call: (a) => s.type(a!)),
      ThorMember(
        'modeIndex',
        s.modeIndex,
        call: (_) => s.modeIndex(),
        variants: const [0, 1],
      ),
      ThorMember('op', s.op, call: (_) => s.op(), variants: const [0, 1]),
      ThorMember(
        'key',
        s.key_,
        arity: 1,
        callWithItem: (i) => s.key_(i! as String),
      ),
      ThorMember(
        'look',
        s.look,
        arity: 1,
        callWithItem: (i) => s.look(i! as String),
        variants: const [false, true],
      ),
      ThorMember(
        'big',
        s.big,
        arity: 1,
        callWithItem: (i) => s.big(i! as String),
        variants: const [false, true],
      ),
      ThorMember(
        'label',
        s.label,
        arity: 1,
        callWithItem: (i) => s.label(i! as String),
      ),
    ];
  }
}

class _Grid extends _GridMembers {
  final row = state(0);
  final items = state(const ['a', 'b']);
  final mode = state(0);
  final scroll = ScrollController();
  final draft = TextEditingController();
  final focus = FocusNode();
  final details = DialogController();
  var undos = 0;
  String? pasted;
  void copy() => Clipboard.setData(const ClipboardData(text: 'a\tb\n1\t2'));
  Future<void> paste() async {
    pasted = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
  }

  var shifted = false;

  void down() => row.value++;
  void undo() => undos++;
  void go(int r) => row.value = r;
  double top() => row.value * 32.0;
  double width(int c) => 100.0 + c;
  void shift() => shifted = HardwareKeyboard.instance.isShiftPressed;
  var typed = '';
  void type(String c) => typed += c;
  int modeIndex() => mode.value;
  int op() => row.value.isOdd ? 1 : 0;
  String key_(String i) => 'k$i';
  bool look(String i) => i.startsWith('x');
  bool big(String i) => i.length > 1;
  String label(String i) => 'label $i';
}

// A list of checkboxes: items are `key:0|1`.
abstract class _ChecksMembers extends ThorState {
  @override
  String get $type => 'Checks';

  @override
  List<ThorMember> get $members {
    final s = this as _Checks;
    return [
      ThorMember.state('items', s.items),
      ThorMember(
        'key',
        s.key_,
        arity: 1,
        callWithItem: (i) => s.key_(i! as String),
      ),
      ThorMember(
        'on',
        s.on,
        arity: 1,
        callWithItem: (i) => s.on(i! as String),
        variants: const [false, true],
      ),
      ThorMember(
        'set',
        s.set,
        arity: 2,
        call: (a) {
          final x = splitArgs(a, 2);
          return s.set(x[0], x[1] == 'true');
        },
      ),
    ];
  }
}

class _Checks extends _ChecksMembers {
  final items = state(const ['a:0', 'b:0']);
  var locked = false;

  String key_(String i) => i.split(':').first;
  bool on(String i) => i.endsWith(':1');
  void set(String key, bool value) {
    if (locked) return;
    items.value = [
      for (final i in items.value) key_(i) == key ? '$key:${value ? 1 : 0}' : i,
    ];
  }
}

// A list whose row state reads a set outside the item: items are keys.
abstract class _StarsMembers extends ThorState {
  @override
  String get $type => 'Stars';

  @override
  List<ThorMember> get $members {
    final s = this as _Stars;
    return [
      ThorMember.state('items', s.items),
      ThorMember.state('starred', s.starred),
      ThorMember(
        'key',
        s.key_,
        arity: 1,
        callWithItem: (i) => s.key_(i! as String),
      ),
      ThorMember(
        'on',
        s.on,
        arity: 1,
        callWithItem: (i) => s.on(i! as String),
        variants: const [false, true],
      ),
      ThorMember(
        'label',
        s.label,
        arity: 1,
        callWithItem: (i) => s.label(i! as String),
      ),
    ];
  }
}

class _Stars extends _StarsMembers {
  final items = state(const ['a', 'b']);
  final starred = state<Set<String>>(const {});

  String key_(String i) => i;
  bool on(String i) => starred.value.contains(i);
  String label(String i) => 'label $i';
}

/// Waits for [ready] (something the browser does in a queued task) with a
/// deadline, not for a fixed time a loaded machine can stretch.
Future<void> _until(bool Function() ready) async {
  final end = DateTime.now().add(const Duration(seconds: 20));
  while (!ready() && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

Future<void> _microtasks() => Future<void>.delayed(Duration.zero);

void main() {
  group('CallbackShortcuts', () {
    test('the innermost match runs, with its argument, and stops the key', () {
      final g = _Grid();
      final root = mount(
        '<div data-tks="+arrowdown>Grid.down;m+z>Grid.undo">'
        '<p data-tks="+arrowdown>Grid.go~7" tabindex="0">inner</p>'
        '<span tabindex="0">outer</span></div>',
      );
      addTearDown(startThor([g], root: root, features: allEngineFeatures));
      key(root.querySelector('p')!, 'ArrowDown');
      expect(g.row.value, 7, reason: 'innermost binding, withArg');
      key(root.querySelector('span')!, 'ArrowDown');
      expect(g.row.value, 8);
      key(root.querySelector('p')!, 'z', meta: true);
      expect(g.undos, 1, reason: 'falls through to the outer shortcuts');
      key(root.querySelector('p')!, 'z');
      expect(g.undos, 1, reason: 'modifiers must match exactly');
      // A letter from Flutter's full set: ⌘K.
      root.firstElementChild!.setAttribute(
        'data-tks',
        encodeShortcuts({
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true).spec:
              'Grid.undo',
        }),
      );
      key(root.querySelector('span')!, 'k', meta: true);
      expect(g.undos, 2, reason: 'meta+k matches a keydown of k with Meta');
    });

    test('a non-Latin layout falls back to the physical key; a Latin one '
        'keeps its letters', () {
      final g = _Grid();
      final root = mount(
        '<div data-tks="m+s>Grid.undo; c+1>Grid.go~1; m+c>Grid.go~9">'
        '<span tabindex="0">page</span><input type="text"></div>',
      );
      addTearDown(startThor([g], root: root, features: allEngineFeatures));
      final span = root.querySelector('span')!;
      key(span, 'ы', code: 'KeyS', meta: true);
      expect(g.undos, 1, reason: 'Cyrillic ы on KeyS is ⌘S');
      key(span, 'σ', code: 'KeyS', meta: true);
      expect(g.undos, 2, reason: 'Greek σ on KeyS is ⌘S');
      key(span, 'ש', code: 'Digit1', control: true);
      expect(g.row.value, 1, reason: 'a digit by its physical key');
      key(span, 'o', code: 'KeyS', meta: true);
      expect(g.undos, 2, reason: "Dvorak's o on KeyS is an o, not ⌘S");
      key(span, 'ф', code: 'KeyA', meta: true);
      expect(g.undos, 2, reason: 'another physical key');
      key(root.querySelector('input')!, 'с', code: 'KeyC', meta: true);
      key(root.querySelector('input')!, 'ы', code: 'KeyS', meta: true);
      expect(g.row.value, 1, reason: 'a field keeps ⌘C on any layout');
      expect(g.undos, 3, reason: '⌘S is not an editing key');
    });

    test('a text field keeps its editing keys; Enter/Escape still reach', () {
      final g = _Grid();
      final root = mount(
        '<div data-tks="+arrowdown>Grid.down;+enter>Grid.go~3">'
        '<input type="text"><button type="button">b</button></div>',
      );
      addTearDown(startThor([g], root: root, features: allEngineFeatures));
      final input = root.querySelector('input')!;
      key(input, 'ArrowDown');
      expect(g.row.value, 0, reason: 'the caret moves, not the grid');
      key(input, 'Enter');
      expect(g.row.value, 3);
      key(root.querySelector('button')!, 'Enter');
      expect(g.row.value, 3, reason: 'a button presses on Enter');
    });

    test('onCharacter gets printable characters its bindings leave; '
        'CharacterActivator matches the character', () {
      final g = _Grid();
      final root = mount(
        '<div data-tks="+ >Grid.down;=63>Grid.undo;*>Grid.type" tabindex="0">'
        '<input type="text"></div>',
      );
      addTearDown(startThor([g], root: root, features: allEngineFeatures));
      final grid = root.firstElementChild!;
      key(grid, 'a');
      key(grid, 'Ñ', shift: true);
      key(grid, ' ');
      key(grid, '?', shift: true);
      key(grid, 'c', meta: true);
      key(grid, 'ArrowDown');
      expect(g.typed, 'aÑ');
      expect(g.row.value, 1, reason: 'Space has its own binding');
      expect(g.undos, 1, reason: 'CharacterActivator("?")');
      key(root.querySelector('input')!, 'x');
      expect(g.typed, 'aÑ', reason: 'a text field keeps its characters');
    });

    test('with nothing focused (key on <body>) the outermost shortcuts '
        'on view answer, like Flutter\'s root focus', () {
      final g = _Grid();
      final root = mount(
        '<div data-tks="m+k>Grid.undo">'
        '<div data-tks="+arrowdown>Grid.down"><span>page</span></div></div>'
        '<dialog><div data-tks="m+k>Grid.go~5"></div></dialog>'
        '<button type="button">outside</button>',
      );
      addTearDown(startThor([g], root: root, features: allEngineFeatures));
      final body = web.document.body!;
      key(body, 'k', meta: true);
      expect(g.undos, 1, reason: 'the layout\'s ⌘K with the page just loaded');
      expect(g.row.value, 0, reason: 'a closed dialog\'s shortcuts sleep');
      key(body, 'ArrowDown');
      expect(g.row.value, 0, reason: 'inner shortcuts need focus inside');
      key(root.querySelector('button')!, 'k', meta: true);
      expect(g.undos, 1, reason: 'focus elsewhere: not the root focus');
    });

    test('HardwareKeyboard follows the modifiers of pointer events', () {
      final g = _Grid();
      final root = mount('<button data-t-on="click:Grid.shift">x</button>');
      addTearDown(startThor([g], root: root, features: allEngineFeatures));
      final b = root.querySelector('button')!;
      b.dispatchEvent(
        web.PointerEvent(
          'pointerdown',
          web.PointerEventInit(bubbles: true, shiftKey: true),
        ),
      );
      click(b);
      expect(g.shifted, isTrue);
      b.dispatchEvent(
        web.PointerEvent('pointerdown', web.PointerEventInit(bubbles: true)),
      );
      click(b);
      expect(g.shifted, isFalse);
    });
  });

  group('controllers', () {
    test('a text controller starts from the field and follows both ways', () {
      final g = _Grid();
      final root = mount(
        '<input data-ttc="Grid.draft" value="server"><textarea data-ttc="Grid.draft"></textarea>',
      );
      addTearDown(startThor([g], root: root, features: allEngineFeatures));
      final input = root.querySelector('input')! as web.HTMLInputElement;
      final area = root.querySelector('textarea')! as web.HTMLTextAreaElement;
      expect(g.draft.text, 'server');
      expect(area.value, 'server');
      g.draft.text = 'from state';
      expect(input.value, 'from state');
      input.value = 'typed';
      input.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
      expect(g.draft.text, 'typed');
      expect(area.value, 'typed');
    });

    test(
      'a focus node focuses its element after the current updates',
      () async {
        final g = _Grid();
        final root = mount('<p data-tfn="Grid.focus" tabindex="-1">x</p>');
        addTearDown(startThor([g], root: root, features: allEngineFeatures));
        g.focus.requestFocus();
        expect(web.document.activeElement, isNot(root.querySelector('p')));
        await _microtasks();
        expect(web.document.activeElement, root.querySelector('p'));
        expect(g.focus.hasFocus, isTrue);
        g.focus.unfocus();
        expect(g.focus.hasFocus, isFalse);
      },
    );

    test('a scroll controller follows its element and moves it', () async {
      final g = _Grid();
      final root = mount(
        '<div data-tsc="Grid.scroll" style="height:100px;overflow:auto">'
        '<div style="height:1000px"></div></div>',
      );
      addTearDown(startThor([g], root: root, features: allEngineFeatures));
      expect(g.scroll.position.viewportDimension, 100);
      expect(g.scroll.position.maxScrollExtent, 900);
      g.scroll.jumpTo(250);
      final el = root.firstElementChild!;
      expect(el.scrollTop, 250);
      el.scrollTop = 400;
      el.dispatchEvent(web.Event('scroll'));
      expect(g.scroll.offset, 400);
    });

    test(
      'a dialog controller opens and closes its dialog, and follows Esc',
      () async {
        final g = _Grid();
        final root = mount(
          '<dialog data-tdc="Grid.details" closedby="any"><input></dialog>',
        );
        addTearDown(startThor([g], root: root, features: allEngineFeatures));
        final d = root.querySelector('dialog')! as web.HTMLDialogElement;
        g.details.open();
        expect(g.details.isOpen, isTrue);
        await _microtasks();
        expect(d.open, isTrue);
        expect(d.matches(':modal'), isTrue, reason: 'showModal, not show');
        g.details.close();
        expect(d.open, isFalse);
        expect(g.details.isOpen, isFalse);
        d.showModal(); // a DialogTrigger
        await _microtasks();
        expect(g.details.isOpen, isTrue);
        d.close(); // Esc, the backdrop
        await _until(() => !g.details.isOpen);
        expect(g.details.isOpen, isFalse);
      },
    );

    test('Clipboard: a shortcut answers in its own copy/paste event and lets '
        'the key through', () async {
      final g = _Grid();
      final root = mount(
        '<div tabindex="0" data-tks="m+c>Grid.copy;m+v>Grid.paste">grid</div>',
      );
      addTearDown(startThor([g], root: root, features: allEngineFeatures));
      final grid = root.firstElementChild!;
      final down = web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(
          key: 'c',
          metaKey: true,
          bubbles: true,
          cancelable: true,
        ),
      );
      grid.dispatchEvent(down);
      expect(down.defaultPrevented, isFalse, reason: 'the copy must follow');
      final copied = web.DataTransfer();
      final copy = web.ClipboardEvent(
        'copy',
        web.ClipboardEventInit(
          clipboardData: copied,
          bubbles: true,
          cancelable: true,
        ),
      );
      grid.dispatchEvent(copy);
      expect(copy.defaultPrevented, isTrue);
      expect(copied.getData('text/plain'), 'a\tb\n1\t2');

      key(grid, 'v', meta: true);
      final data = web.DataTransfer()..setData('text/plain', 'x\ty');
      grid.dispatchEvent(
        web.ClipboardEvent(
          'paste',
          web.ClipboardEventInit(
            clipboardData: data,
            bubbles: true,
            cancelable: true,
          ),
        ),
      );
      await _microtasks();
      expect(g.pasted, 'x\ty');

      // Nothing pending: other shortcuts still stop their key, and a copy
      // event without a pending write is the browser's.
      final other = web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(
          key: 'z',
          metaKey: true,
          bubbles: true,
          cancelable: true,
        ),
      );
      root.firstElementChild!.setAttribute('data-tks', 'm+z>Grid.undo');
      grid.dispatchEvent(other);
      expect(other.defaultPrevented, isTrue);
      final plain = web.ClipboardEvent(
        'copy',
        web.ClipboardEventInit(
          clipboardData: web.DataTransfer(),
          cancelable: true,
        ),
      );
      grid.dispatchEvent(plain);
      expect(plain.defaultPrevented, isFalse);
    });

    test('SystemNavigator writes the address without navigating', () {
      final g = _Grid();
      final root = mount('<p></p>');
      final before = web.window.location.href;
      addTearDown(() => web.window.history.replaceState(null, '', before));
      addTearDown(startThor([g], root: root, features: allEngineFeatures));
      SystemNavigator.routeInformationUpdated(
        uri: Uri.parse('${web.window.location.pathname}?view=x'),
        replace: true,
      );
      expect(web.window.location.search, '?view=x');
    });
  });

  test('WatchVariables keep custom properties in pixels', () {
    final g = _Grid();
    final root = mount(
      '<div data-tcv="--top:Grid.top;--w2:Grid.width~2;bad:Grid.top" '
      'style="--top:0px;--w2:102px"></div>',
    );
    addTearDown(startThor([g], root: root, features: allEngineFeatures));
    final el = root.firstElementChild! as web.HTMLElement;
    g.row.value = 3;
    expect(el.style.getPropertyValue('--top'), '96px');
    expect(el.style.getPropertyValue('--w2'), '102px');
    expect(el.style.getPropertyValue('bad'), '');
  });

  test(
    'a bound length (`state.field.px`) names a field and keeps its pixels',
    () {
      final g = _Grid();
      final root = mount(
        '<div data-tcv="--tb-Grid-row:Grid.row;--tb-Grid-top:Grid.top" '
        'style="--tb-Grid-row:0px;--tb-Grid-top:0px"></div>',
      );
      addTearDown(startThor([g], root: root, features: allEngineFeatures));
      final el = root.firstElementChild! as web.HTMLElement;
      g.row.value = 3;
      expect(
        el.style.getPropertyValue('--tb-Grid-row'),
        '3px',
        reason: 'field',
      );
      expect(
        el.style.getPropertyValue('--tb-Grid-top'),
        '96px',
        reason: 'method',
      );
    },
  );

  group('states', () {
    test('a native checkbox in a row follows its state, also after the user '
        'touched it, and stays controlled', () {
      final c = _Checks();
      String box(String key, {bool checked = false}) =>
          '<input type="checkbox"${checked ? ' checked' : ''} '
          'data-tvf="Checks.on" data-tvi="${checked ? 1 : 0}" '
          'data-t-on="change:Checks.set" data-tx="$key" data-txv="">';
      final root = mount(
        '<ul data-tl="Checks.items" data-tlk="Checks.key">'
        '<li data-tk="a">${box('a')}</li><li data-tk="b">${box('b')}</li>'
        '<template data-tlt="Checks.items"><li>${box('{{key}}')}'
        '<template data-tvft="Checks.on" data-i="1">'
        '${box('{{key}}', checked: true)}</template></li></template></ul>',
      );
      addTearDown(startThor([c], root: root, features: allEngineFeatures));
      web.HTMLInputElement input(String key) =>
          root.querySelector('[data-tk="$key"] input')! as web.HTMLInputElement;
      input('a').click();
      expect(c.items.value, ['a:1', 'b:0']);
      expect(input('a').checked, isTrue);
      c.items.value = ['a:0', 'b:1'];
      expect(input('a').checked, isFalse, reason: 'touched, then the state');
      expect(input('b').checked, isTrue, reason: 'untouched');
      c.locked = true;
      input('a').click();
      expect(c.items.value, ['a:0', 'b:1']);
      expect(
        input('a').checked,
        isFalse,
        reason: 'like Flutter: the box shows `value`, not the click',
      );
    });

    test('a row state that reads another state\'s field follows it, also '
        'when its variants have another structure, kept rows included', () {
      final g = _Stars();
      const plain = '<b data-tf="Stars.label">%s</b><button>Agregar</button>';
      const fav =
          '<b data-tf="Stars.label">%s</b><i>★</i><button>Quitar</button>';
      String li(String key) =>
          '<li data-tk="$key"><span data-tvf="Stars.on" data-tvi="0">'
          '${plain.replaceFirst('%s', 'label $key')}</span></li>';
      final root = mount(
        '<ul data-tl="Stars.items" data-tlk="Stars.key">${li('a')}${li('b')}'
        '<template data-tlt="Stars.items"><li><span data-tvf="Stars.on" '
        'data-tvi="0">${plain.replaceFirst('%s', '')}'
        '<template data-tvft="Stars.on" data-i="1">'
        '<span>${fav.replaceFirst('%s', '')}</span></template></span></li>'
        '</template></ul>',
      );
      addTearDown(startThor([g], root: root, features: allEngineFeatures));
      String row(String key) =>
          root.querySelector('[data-tk="$key"]')!.textContent!;
      web.Element span(String key) =>
          root.querySelector('[data-tk="$key"] span')!;
      for (var round = 0; round < 2; round++) {
        g.starred.value = {'a'};
        expect(row('a'), 'label a★Quitar', reason: 'kept row, round $round');
        expect(span('a').getAttribute('data-tvi'), '1');
        expect(row('b'), 'label bAgregar');
        g.starred.value = {};
        expect(row('a'), 'label aAgregar', reason: 'back, round $round');
        expect(span('a').getAttribute('data-tvi'), '0');
      }
      g.items.value = ['a', 'b', 'c'];
      g.starred.value = {'a', 'c'};
      expect(row('c'), 'label c★Quitar', reason: 'a row the browser made');
      expect(row('a'), 'label a★Quitar');
      expect(row('b'), 'label bAgregar');
    });

    test('a state on the row element itself (row.watch as the row)', () {
      final g = _Grid();
      final root = mount(
        '<ul data-tl="Grid.items" data-tlk="Grid.key">'
        '<li data-tk="ka" class="plain" data-tvf="Grid.look" data-tvi="0">'
        '<i class="small" data-tvf="Grid.big" data-tvi="0">a</i></li>'
        '<template data-tlt="Grid.items">'
        '<li class="plain" data-tvf="Grid.look" data-tvi="0">'
        '<i class="small" data-tvf="Grid.big" data-tvi="0">a</i>'
        '<template data-tvft="Grid.big" data-i="1"><i class="large">a</i></template>'
        '</li>'
        '<template data-tvft="Grid.look" data-i="1"><li class="marked">'
        '<i class="small" data-tvf="Grid.big" data-tvi="0">a</i>'
        '<template data-tvft="Grid.big" data-i="1"><i class="large">a</i></template>'
        '</li></template>'
        '</template></ul>',
      );
      addTearDown(startThor([g], root: root, features: allEngineFeatures));
      g.items.value = ['a', 'xx'];
      final rows = root.querySelectorAll('li[data-tk]');
      final x = rows.item(1)! as web.Element;
      expect(x.className, 'marked', reason: 'the row\'s own state');
      expect(
        x.querySelector('i')!.className,
        'large',
        reason: 'a nested state keeps its own value',
      );
      expect(x.querySelector('template'), isNull);
    });

    test('a bound text in a row state takes the look of the state, keeping '
        'its text (row.text(style:) inside row.watch)', () {
      final g = _Grid();
      const row =
          '<li%s data-tvf="Grid.look" data-tvi="%s" '
          'data-tp-1="|class|=marked;0|class|=strike">'
          '<b class="%s" data-tf="Grid.label">%s</b></li>';
      String li(String key, String state, String cls, String text) => row
          .replaceFirst('%s', key.isEmpty ? '' : ' data-tk="$key"')
          .replaceFirst('%s', state)
          .replaceFirst('%s', cls)
          .replaceFirst('%s', text);
      final root = mount(
        '<ul data-tl="Grid.items" data-tlk="Grid.key">'
        '${li('ka', '0', 'plain', 'label a')}'
        '<template data-tlt="Grid.items">${li('', '0', 'plain', '')}</template>'
        '</ul>',
      );
      addTearDown(startThor([g], root: root, features: allEngineFeatures));
      g.items.value = ['a', 'xb', 'c', 'xd'];
      String cls(int i) =>
          (root.querySelectorAll('li[data-tk] b').item(i)! as web.Element)
              .className;
      String text(int i) =>
          root.querySelectorAll('li[data-tk] b').item(i)!.textContent!;
      expect(
        [cls(0), cls(1), cls(2), cls(3)],
        ['plain', 'strike', 'plain', 'strike'],
      );
      expect([text(1), text(3)], ['label xb', 'label xd']);
      g.items.value = ['xa', 'b', 'xc', 'd'];
      expect(
        [cls(0), cls(1), cls(2), cls(3)],
        ['strike', 'plain', 'strike', 'plain'],
        reason: 'every row follows its state, added or not',
      );
    });

    test('row.bind attributes (data-tfa) are filled in rows the browser adds '
        'and follow a changed item, hostile values included', () {
      final g = _Grid();
      const tpl =
          '<li%s data-tfa="aria-label:Grid.label;title:Grid.label" '
          'aria-label="%s" title="%s"><b>x</b></li>';
      String li(String key, String label) => tpl
          .replaceFirst('%s', key.isEmpty ? '' : ' data-tk="$key"')
          .replaceFirst('%s', label)
          .replaceFirst('%s', label);
      final root = mount(
        '<ul data-tl="Grid.items" data-tlk="Grid.key">'
        '${li('ka', 'label a')}'
        '<template data-tlt="Grid.items">${li('', '')}</template>'
        '</ul>',
      );
      addTearDown(startThor([g], root: root, features: allEngineFeatures));
      const hostile = 'q"<b>&;:';
      g.items.value = ['a', hostile, 'c'];
      final rows = root.querySelectorAll('li[data-tk]');
      String attr(int i, String name) =>
          (rows.item(i)! as web.Element).getAttribute(name)!;
      expect(attr(0, 'aria-label'), 'label a');
      expect(attr(1, 'aria-label'), 'label $hostile');
      expect(attr(1, 'title'), 'label $hostile');
      expect(attr(2, 'aria-label'), 'label c');
      expect(root.querySelectorAll('b').length, 3, reason: 'no markup made');
    });

    test('states inside a replaced state move to the copy, with its '
        'templates', () {
      final g = _Grid();
      final root = mount(
        '<div data-tv="Grid.modeIndex"><b data-tv="Grid.op">m0 op0</b>'
        '<template data-tvt="Grid.op" data-i="1"><b>m0 op1</b></template></div>'
        '<template data-tvt="Grid.modeIndex" data-i="1"><div><span>'
        '<b data-tv="Grid.op">m1 op0</b>'
        '<template data-tvt="Grid.op" data-i="1"><b>m1 op1</b></template>'
        '</span></div></template>',
      );
      addTearDown(startThor([g], root: root, features: allEngineFeatures));
      g.mode.value = 1;
      expect(root.querySelector('[data-tv="Grid.op"]')!.textContent, 'm1 op0');
      g.row.value = 1;
      expect(
        root.querySelector('[data-tv="Grid.op"]')!.textContent,
        'm1 op1',
        reason: 'the inner state reacts in the new subtree',
      );
      g.mode.value = 0;
      expect(root.querySelector('[data-tv="Grid.op"]')!.textContent, 'm0 op1');
    });

    test('a state switch moves its argument and checked state', () {
      final g = _Grid();
      final root = mount(
        '<label data-tv="Grid.modeIndex">'
        '<input type="checkbox" data-t-on="click:Grid.go" data-tx="1"></label>'
        '<template data-tvt="Grid.modeIndex" data-i="1"><label>'
        '<input type="checkbox" checked data-t-on="click:Grid.go" data-tx="5">'
        '</label></template>',
      );
      addTearDown(startThor([g], root: root, features: allEngineFeatures));
      final box = root.querySelector('input')! as web.HTMLInputElement;
      g.mode.value = 1;
      expect(box.checked, isTrue);
      click(box);
      expect(g.row.value, 5, reason: 'the argument of the new state');
    });
  });
}

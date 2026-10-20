@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

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

void click(web.Element el) => el.dispatchEvent(
  web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
);

// A state with a persisted field (what thor_builder generates, by hand).
class _Prefs extends ThorState {
  final big = state(false, cookie: 'big-test');

  @override
  String get $type => 'Prefs';

  @override
  List<ThorMember> get $members => [
    ThorMember.state('big', big),
    ThorMember('label', label, call: (_) => label()),
  ];

  String label() => big.value ? 'grande' : 'chico';
}

// A state with a field kept in localStorage (by hand, like [_Prefs]).
class _Draft extends ThorState {
  final text = state('', local: 'draft-test');

  @override
  String get $type => 'Draft';

  @override
  List<ThorMember> get $members => [
    ThorMember.state('text', text),
    ThorMember('label', label, call: (_) => label()),
  ];

  String label() => text.value;
}

// The member list thor generates for [_Shop], by hand.
abstract class _ShopMembers extends ThorState {
  @override
  String get $type => 'Shop';

  @override
  List<ThorMember> get $members {
    final s = this as _Shop;
    return [
      ThorMember.state('count', s.count),
      ThorMember.state('items', s.items),
      ThorMember('label', s.label, call: (_) => s.label()),
      ThorMember(
        'isZero',
        s.isZero,
        call: (_) => s.isZero(),
        variants: const [false, true],
      ),
      ThorMember('inc', s.inc, call: (_) => s.inc()),
      ThorMember('add', s.add, arity: 1, call: (a) => s.add(int.parse(a!))),
      ThorMember(
        'setFlag',
        s.setFlag,
        arity: 2,
        call: (a) {
          final x = splitArgs(a, 2);
          return s.setFlag(int.parse(x[0]), x[1] == 'true');
        },
      ),
      ThorMember(
        'itemKey',
        s.itemKey,
        arity: 1,
        callWithItem: (i) => s.itemKey(i! as String),
      ),
      ThorMember(
        'itemName',
        s.itemName,
        arity: 1,
        callWithItem: (i) => s.itemName(i! as String),
      ),
      ThorMember(
        'isBig',
        s.isBig,
        arity: 1,
        callWithItem: (i) => s.isBig(i! as String),
        variants: const [false, true],
      ),
      ThorMember(
        'itemUrl',
        s.itemUrl,
        arity: 1,
        callWithItem: (i) => s.itemUrl(i! as String),
      ),
      ThorMember(
        'cellOn',
        s.cellOn,
        arity: 2,
        callWithArgAndItem: (String? a, i) =>
            s.cellOn(int.parse(a!), i! as String),
        variants: const [false, true],
      ),
      ThorMember('itemCount', s.itemCount, call: (_) => s.itemCount()),
      ThorMember('itemsOf', s.itemsOf, arity: 1, call: (a) => s.itemsOf(a!)),
      ThorMember('link', s.link, call: (_) => s.link()),
    ];
  }
}

class _Shop extends _ShopMembers {
  final count = state(0);
  final items = state(const ['a', 'b']);
  final flags = <int, bool>{};

  String label() => 'n=${count.value}';
  bool isZero() => count.value == 0;
  void inc() => count.value++;
  void add(int n) => count.value += n;
  void setFlag(int i, bool on) => flags[i] = on;
  // `!` marks a changed item under the same key (a recycled row).
  String itemKey(String i) => 'k${i.replaceAll('!', '')}';
  String itemName(String i) => i.toUpperCase();
  bool isBig(String i) => i.startsWith('b');
  // An item starting with `x` carries a hostile URL.
  String itemUrl(String i) =>
      i.startsWith('x') ? ' JavaScript:alert(1)' : 'https://e.x/$i';
  bool cellOn(int column, String i) => i.length == column;
  String itemCount() => '${items.value.length}';
  // A list per instance: `Watch.list(shop.itemsOf.withArg(prefix))`.
  List<String> itemsOf(String prefix) => [
    for (final i in items.value)
      if (i.startsWith(prefix)) i,
  ];
  String link() => items.value.isEmpty ? 'data:text/html,x' : '/p';
}

void main() {
  // The builder picks features from source text; a marker whose feature is
  // left out is named (debug builds print it) instead of failing silently.
  test('missingFeatures names the features the markup needs', () {
    final root = mount('''
<ul data-tl="shop.lines"></ul>
<form data-t-validate></form>
<div role="button" data-t-on="click:shop.add"></div>
<div data-tg="dtap:shop.add"></div>
<span data-t-on="transitionend:shop.add"></span>
<div data-t-ev="enter:shop.add"></div>
<div data-tsz="200|linear|200"><i></i></div>
''');
    final missing = missingFeatures(root, const [ListsFeature()]);
    String named(String feature) =>
        missing.firstWhere((m) => m.contains(feature), orElse: () => '');
    expect(named('ListsFeature'), isEmpty, reason: 'it is included');
    expect(named('VariantsFeature'), isEmpty, reason: 'no variant markup');
    expect(named('FormsFeature'), contains('[data-t-validate]'));
    expect(named('KeyboardFeature'), isNotEmpty);
    expect(named('GesturesFeature'), isNotEmpty);
    expect(named('TransitionsFeature'), isNotEmpty);
    expect(named('ElementEventsFeature'), contains('[data-t-ev]'));
    expect(named('SizeAnimationsFeature'), contains('[data-tsz]'));
    expect(missing.first, contains('all_features: true'));
    expect(missingFeatures(root, allEngineFeatures), isEmpty);
    expect(
      missingFeatures(mount('<p data-tt="shop.label"></p>'), const []),
      isEmpty,
    );
  });

  test('text bindings update the marked nodes only', () {
    final count = Signal(3);
    final label = TextBinding('label', () => 'Total ${count.value}');
    final add = Action('add', (arg) => count.value += int.parse(arg!));
    final root = mount(
      '<p>static</p>'
      '<span data-tt="label">Total 3</span>'
      '<button data-t-on="click:add" data-tx="2"><i>+2</i></button>',
    );
    hydrate([label, add], root: root, features: allEngineFeatures);
    // Click on a child bubbles to the element with the handler.
    click(root.querySelector('i')!);
    expect(root.querySelector('[data-tt]')!.textContent, 'Total 5');
    expect(root.querySelector('p')!.textContent, 'static');
  });

  test('variants patch classes and state from the precompiled template', () {
    final selected = Signal(false);
    final chip = VariantBinding(
      'chip',
      count: 2,
      index: () => selected.value ? 1 : 0,
    );
    final toggle = Action('toggle', (_) => selected.value = !selected.value);
    final root = mount(
      '<div class="pad" data-tv="chip"><button class="off" data-t-on="click:toggle"><span class="t-off">Café</span></button></div>'
      '<template data-tvt="chip" data-i="1"><div class="pad"><button class="on" aria-pressed="true" data-t-on="click:toggle"><span class="t-on">Café</span></button></div></template>',
    );
    hydrate([chip, toggle], root: root, features: allEngineFeatures);
    final button = root.querySelector('button')!;
    click(button);
    expect(button.className, 'on');
    expect(button.getAttribute('aria-pressed'), 'true');
    expect(root.querySelector('span')!.className, 't-on');
    // Back to the server's variant (snapshot taken before the first patch).
    click(button);
    expect(button.className, 'off');
    expect(button.hasAttribute('aria-pressed'), isFalse);
    expect(
      identical(root.querySelector('button'), button),
      isTrue,
      reason: 'same node, patched in place',
    );
  });

  test('non-click events fire only for the element itself', () {
    var ends = 0;
    final end = Action('end', (_) => ends++);
    final root = mount('<div data-t-on="transitionend:end"><b>x</b></div>');
    hydrate([end], root: root, features: allEngineFeatures);
    root
        .querySelector('b')!
        .dispatchEvent(
          web.Event('transitionend', web.EventInit(bubbles: true)),
        );
    expect(ends, 0, reason: "a child's transition is not ours");
    root
        .querySelector('div')!
        .dispatchEvent(
          web.Event('transitionend', web.EventInit(bubbles: true)),
        );
    expect(ends, 1);
  });

  test('a custom event passes its string detail (FlutterView messages)', () {
    final got = <String?>[];
    final msg = Action('msg', got.add);
    final root = mount('<div data-t-on="thor-flutter-message:msg"></div>');
    hydrate([msg], root: root, features: allEngineFeatures);
    final host = root.querySelector('div')!;
    void send(JSAny? detail) => host.dispatchEvent(
      web.CustomEvent(
        'thor-flutter-message',
        web.CustomEventInit(detail: detail, bubbles: true),
      ),
    );
    send('{"bar":"abr"}'.toJS);
    // Not a string (or none): the action runs without a value.
    send(42.toJS);
    send(null);
    // A plain Event of the same type carries no detail either.
    host.dispatchEvent(
      web.Event('thor-flutter-message', web.EventInit(bubbles: true)),
    );
    expect(got, ['{"bar":"abr"}', null, null, null]);
  });

  test('a nested text binding survives a variant switch', () {
    final n = Signal(1);
    final bumped = Signal(false);
    final text = TextBinding('n', () => 'n=${n.value}');
    final v = VariantBinding('v', count: 2, index: () => bumped.value ? 1 : 0);
    final root = mount(
      '<button class="a" data-tv="v"><span data-tt="n">n=1</span></button>'
      '<template data-tvt="v" data-i="1"><button class="b"><span data-tt="n">n=1</span></button></template>',
    );
    hydrate([text, v], root: root, features: allEngineFeatures);
    batch(() {
      n.value = 7;
      bumped.value = true;
    });
    expect(root.querySelector('button')!.className, 'b');
    expect(root.querySelector('[data-tt]')!.textContent, 'n=7');
  });

  test('dispose removes listeners and effects', () {
    final count = Signal(0);
    final add = Action('add', (_) => count.value++);
    final root = mount('<button data-t-on="click:add">+</button>');
    final dispose = hydrate([add], root: root, features: allEngineFeatures);
    click(root.querySelector('button')!);
    dispose();
    click(root.querySelector('button')!);
    expect(count.peek(), 1);
  });

  test(
    'a change inside a labelled row reaches the row with the control value',
    () {
      final on = Signal<String?>(null);
      final set = Action('set', (v) => on.value = v);
      final root = mount(
        '<label data-t-on="change:set"><input type="checkbox"> Sonido</label>',
      );
      hydrate([set], root: root, features: allEngineFeatures);
      final input = root.querySelector('input')! as web.HTMLInputElement;
      input.click();
      expect(on.peek(), 'true');
      input.click();
      expect(on.peek(), 'false');
    },
  );

  test('compact patches switch between three variants and back', () {
    final state = Signal(0);
    final v = VariantBinding('todos', count: 3, index: () => state.value);
    final root = mount(
      '<label class="row" data-tv="todos" data-tp-1="0|aria-checked|-;0|class|=c on" data-tp-2="0|aria-checked|-;1|#|=Ninguno">'
      '<input class="c" aria-checked="mixed"><span>Todos</span></label>',
    );
    hydrate([v], root: root, features: allEngineFeatures);
    final input = root.querySelector('input')!;
    final span = root.querySelector('span')!;
    state.value = 1;
    expect(input.hasAttribute('aria-checked'), isFalse);
    expect(input.className, 'c on');
    state.value = 2;
    expect(input.className, 'c', reason: 'restored before applying 2');
    expect(span.textContent, 'Ninguno');
    state.value = 0;
    expect(input.getAttribute('aria-checked'), 'mixed');
    expect(span.textContent, 'Todos');
  });

  test('a handler that only a patch brings still gets its event', () {
    final state = Signal(0);
    var runs = 0;
    final v = VariantBinding('t', count: 2, index: () => state.value);
    final go = Action('go', (_) => runs++);
    // The live button is disabled (no handler); state 1 enables it.
    final root = mount(
      '<button data-tv="t" disabled data-tp-1="|disabled|-;|data-t-on|=dblclick:go">x</button>',
    );
    hydrate([v, go], root: root, features: allEngineFeatures);
    state.value = 1;
    root
        .querySelector('button')!
        .dispatchEvent(
          web.MouseEvent('dblclick', web.MouseEventInit(bubbles: true)),
        );
    expect(runs, 1);
  });

  test('aria-checked=mixed becomes the indeterminate property', () {
    final state = Signal(0);
    final v = VariantBinding('t', count: 2, index: () => state.value);
    final root = mount(
      '<label data-tv="t" data-tp-1="0|aria-checked|-;0|checked|="><input type="checkbox" aria-checked="mixed"></label>',
    );
    hydrate([v], root: root, features: allEngineFeatures);
    final input = root.querySelector('input')! as web.HTMLInputElement;
    expect(input.indeterminate, isTrue);
    state.value = 1;
    expect(input.indeterminate, isFalse);
    state.value = 0;
    expect(input.indeterminate, isTrue);
  });

  group('keyed lists', () {
    web.HTMLElement listPage() => mount(
      '<ul data-tl="cart">'
      '<li data-tk="a"><span data-tf="name">Americano</span> <b data-tf="qty">1</b>'
      '<button data-t-on="click:remove" data-tx="a">x</button></li>'
      '<template data-tlt="cart"><li><span data-tf="name"></span> <b data-tf="qty"></b>'
      '<button data-t-on="click:remove" data-tx="{{key}}">x</button></li></template>'
      '</ul>',
    );

    test('adds, updates, reorders (same nodes) and removes rows', () {
      final items = Signal([('a', 'Americano', 1)]);
      final list = ListBinding<(String, String, int)>(
        'cart',
        items: () => items.value,
        key: (i) => i.$1,
        fields: {'name': (i) => i.$2, 'qty': (i) => '${i.$3}'},
      );
      final root = listPage();
      hydrate([list], root: root, features: allEngineFeatures);
      final a = root.querySelector('[data-tk=a]')!;
      String rows() => [
        for (final li in _rows(root))
          '${li.getAttribute('data-tk')}:${li.textContent}',
      ].join(',');

      items.value = [('a', 'Americano', 2), ('b', 'Chai', 1)];
      expect(rows(), 'a:Americano 2x,b:Chai 1x');
      expect(identical(root.querySelector('[data-tk=a]'), a), isTrue);

      items.value = [('b', 'Chai', 1), ('a', 'Americano', 2)];
      expect(rows(), 'b:Chai 1x,a:Americano 2x');
      expect(
        identical(root.querySelector('[data-tk=a]'), a),
        isTrue,
        reason: 'moved, not recreated',
      );

      items.value = [('b', 'Chai', 3)];
      expect(rows(), 'b:Chai 3x');
      expect(
        root.querySelector('template[data-tlt]'),
        isNotNull,
        reason: 'template stays',
      );
    });

    test(
      'a swap moves at most two nodes; removing one row moves none',
      () async {
        final items = Signal([
          for (var i = 0; i < 10; i++) ('k$i', 'row $i', 1),
        ]);
        final list = ListBinding<(String, String, int)>(
          'cart',
          items: () => items.value,
          key: (i) => i.$1,
          fields: {'name': (i) => i.$2, 'qty': (i) => '${i.$3}'},
        );
        final root = listPage();
        hydrate([list], root: root, features: allEngineFeatures);
        final ul = root.querySelector('ul')!;
        var added = 0;
        final observer = web.MutationObserver(
          ((JSArray<web.MutationRecord> records, web.MutationObserver _) {
            for (final r in records.toDart) {
              added += r.addedNodes.length;
            }
          }).toJS,
        );
        observer.observe(ul, web.MutationObserverInit(childList: true));
        final r = [...items.value];
        final t = r[1];
        r[1] = r[8];
        r[8] = t;
        items.value = r;
        await Future<void>.delayed(Duration.zero);
        expect(added, lessThanOrEqualTo(2));
        expect(_rows(root)[1].getAttribute('data-tk'), 'k8');
        expect(_rows(root)[8].getAttribute('data-tk'), 'k1');
        added = 0;
        items.value = [...items.value]..removeAt(4);
        await Future<void>.delayed(Duration.zero);
        expect(added, 0);
        expect(_rows(root), hasLength(9));
        observer.disconnect();
      },
    );

    test('actions of cloned rows get the row key', () {
      final items = Signal([('a', 'Americano', 1)]);
      final removed = <String?>[];
      final list = ListBinding<(String, String, int)>(
        'cart',
        items: () => items.value,
        key: (i) => i.$1,
        fields: {'name': (i) => i.$2, 'qty': (i) => '${i.$3}'},
      );
      final remove = Action('remove', (k) {
        removed.add(k);
        items.value = [
          for (final i in items.value)
            if (i.$1 != k) i,
        ];
        return null;
      });
      final root = listPage();
      hydrate([list, remove], root: root, features: allEngineFeatures);
      items.value = [...items.value, ('z', 'Pan', 1)];
      click(root.querySelector('[data-tk=z] button')!);
      expect(removed, ['z']);
      expect(root.querySelector('[data-tk=z]'), isNull);
      click(root.querySelector('[data-tk=a] button')!);
      expect(removed, ['z', 'a']);
      expect(_rows(root), isEmpty);
    });
  });

  test(
    'Enter in a field runs its action, not the form submit; hidden row fields get values',
    () {
      final tags = Signal(<String>['a']);
      final added = <String?>[];
      final add = Action('add', (v) {
        added.add(v);
        tags.value = [...tags.value, v!];
        return null;
      });
      final list = ListBinding<String>(
        'tags',
        items: () => tags.value,
        key: (t) => t,
        fields: {'name': (t) => t},
      );
      final root = mount(
        '<form><input data-t-on="enter:add" data-t-clear>'
        '<div data-tl="tags"><span data-tk="a"><b data-tf="name">a</b><input type="hidden" name="tag" value="a" data-tf="name"></span>'
        '<template data-tlt="tags"><span><b data-tf="name"></b><input type="hidden" name="tag" value="" data-tf="name"></span></template></div>'
        '</form>',
      );
      var submitted = false;
      root
          .querySelector('form')!
          .addEventListener(
            'submit',
            ((web.Event e) {
              submitted = true;
              e.preventDefault();
            }).toJS,
          );
      hydrate([add, list], root: root, features: allEngineFeatures);
      final input =
          root.querySelector('input[data-t-on]')! as web.HTMLInputElement;
      input.value = 'css';
      final enter = web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: 'Enter', bubbles: true, cancelable: true),
      );
      input.dispatchEvent(enter);
      expect(added, ['css']);
      expect(enter.defaultPrevented, isTrue, reason: 'Enter must not submit');
      expect(submitted, isFalse);
      expect(input.value, '', reason: 'data-t-clear empties the field');
      final hidden = _all(
        root,
        'input[name=tag]',
      ).map((e) => (e as web.HTMLInputElement).value);
      expect(hidden, ['a', 'css']);
      // The same field shown as text too.
      expect(_all(root, 'b').map((e) => e.textContent), ['a', 'css']);
      // Other keys do nothing.
      input.value = 'x';
      input.dispatchEvent(
        web.KeyboardEvent(
          'keydown',
          web.KeyboardEventInit(key: 'a', bubbles: true),
        ),
      );
      expect(added, ['css']);
      expect(input.value, 'x');
    },
  );

  test('a handled click on a submit button does not post the form', () {
    var ran = 0;
    final root = mount(
      '<form><button type="submit" formaction="?/remove" data-t-on="click:remove">x</button></form>',
    );
    var submitted = false;
    root
        .querySelector('form')!
        .addEventListener(
          'submit',
          ((web.Event e) {
            submitted = true;
            e.preventDefault();
          }).toJS,
        );
    hydrate(
      [Action('remove', (_) => ran++)],
      root: root,
      features: allEngineFeatures,
    );
    // A real click is cancelable (the synthetic helper's is not).
    root
        .querySelector('button')!
        .dispatchEvent(
          web.MouseEvent(
            'click',
            web.MouseEventInit(bubbles: true, cancelable: true),
          ),
        );
    expect(ran, 1);
    expect(submitted, isFalse);
  });

  test('state from the server wins over the defaults in the code', () {
    final n = Signal(1);
    final items = Signal<List<String>>(const []);
    final text = TextBinding(
      'n',
      () => 'n=${n.value} (${items.value.join(',')})',
    );
    final bindings = [
      StateBinding<int>(
        'n',
        n,
        encode: (v) => v,
        decode: (j) => (j! as num).toInt(),
      ),
      StateBinding<List<String>>(
        'items',
        items,
        encode: (v) => v,
        decode: (j) => [for (final x in j! as List) x as String],
      ),
      text,
    ];
    final root = mount(
      '<script type="application/json" id="thor-state">{"n":7,"items":["a","b"]}</script>'
      '<span data-tt="n">n=7 (a,b)</span>',
    );
    hydrate(bindings, root: root, features: allEngineFeatures);
    expect(n.peek(), 7);
    expect(items.peek(), ['a', 'b']);
    expect(root.querySelector('span')!.textContent, 'n=7 (a,b)');
    n.value = 8;
    expect(root.querySelector('span')!.textContent, 'n=8 (a,b)');
  });

  test('forms: native rules, own messages, submit action only when valid', () async {
    var submitted = 0;
    final submit = Action('login', (_) => submitted++);
    final root = mount(
      '<form data-t-on="submit:login" method="post" action="/nowhere">'
      '<input id="f-email" name="email" type="email" required data-t-validate '
      'data-msg-valuemissing="Escribe tu correo" data-msg-typemismatch="Correo inválido" '
      'aria-describedby="f-email-msg">'
      '<span id="f-email-msg" data-helper="Usamos tu correo de trabajo">Usamos tu correo de trabajo</span>'
      '<button type="submit">Entrar</button></form>',
    );
    hydrate([submit], root: root, features: allEngineFeatures);
    final form = root.querySelector('form')! as web.HTMLFormElement;
    final input = root.querySelector('input')! as web.HTMLInputElement;
    final msg = root.querySelector('#f-email-msg')!;

    form.requestSubmit();
    await Future<void>.delayed(Duration.zero);
    expect(submitted, 0);
    expect(msg.textContent, 'Escribe tu correo');
    expect(msg.hasAttribute('data-invalid'), isTrue);
    expect(input.getAttribute('aria-invalid'), 'true');

    input.value = 'ana';
    input.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    expect(msg.textContent, 'Correo inválido');

    input.value = 'ana@example.com';
    input.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    expect(msg.textContent, 'Usamos tu correo de trabajo');
    expect(input.getAttribute('aria-invalid'), 'false');

    form.requestSubmit();
    await Future<void>.delayed(Duration.zero);
    expect(submitted, 1, reason: 'valid: the action runs, no navigation');
  });

  test('startThor wires a ThorState page from its markers', () {
    final shop = _Shop();
    final root = mount(
      '<script type="application/json" id="thor-state">{"Shop.count":2}</script>'
      '<span data-tt="Shop.label">n=0</span>'
      '<button id="inc" data-t-on="click:Shop.inc">+</button>'
      '<button id="add" data-t-on="click:Shop.add" data-tx="5">+5</button>'
      '<input id="flag" type="checkbox" data-t-on="change:Shop.setFlag" data-tx="3" data-txv>'
      '<p class="off" data-tv="Shop.isZero" data-tp-1="|class|=on">x</p>'
      '<ul data-tl="Shop.items" data-tlk="Shop.itemKey">'
      '<li data-tk="ka"><b data-tf="Shop.itemName">A</b></li>'
      '<li data-tk="kb"><b data-tf="Shop.itemName">B</b></li>'
      '<template data-tlt="Shop.items"><li><b data-tf="Shop.itemName"></b></li></template>'
      '</ul>',
    );
    final dispose = startThor([shop], root: root, features: allEngineFeatures);
    addTearDown(dispose);
    // State restored from the page before anything renders.
    expect(shop.count.value, 2);
    expect(root.querySelector('[data-tt]')!.textContent, 'n=2');
    click(root.querySelector('#inc')!);
    click(root.querySelector('#add')!);
    expect(root.querySelector('[data-tt]')!.textContent, 'n=8');
    // Two-parameter action: fixed argument + the checkbox's value.
    (root.querySelector('#flag')! as web.HTMLElement).click();
    expect(shop.flags, {3: true});
    // Variant follows the bool source.
    shop.count.value = 0;
    expect(root.querySelector('p')!.className, 'on');
    // Keyed list from the state's field and item methods.
    shop.items.value = ['b', 'c'];
    final names = root.querySelectorAll('li [data-tf]');
    expect(
      [for (var i = 0; i < names.length; i++) names.item(i)!.textContent],
      ['B', 'C'],
    );
  });

  test('a list over a method with an argument is one list per instance', () {
    final shop = _Shop();
    final root = mount(
      '<ul id="a" data-tl="Shop.itemsOf~a" data-tlk="Shop.itemKey">'
      '<li data-tk="ka"><b data-tf="Shop.itemName">A</b></li>'
      '<template data-tlt="Shop.itemsOf~a"><li><b data-tf="Shop.itemName"></b></li></template>'
      '</ul>'
      '<ul id="b" data-tl="Shop.itemsOf~b" data-tlk="Shop.itemKey">'
      '<template data-tlt="Shop.itemsOf~b"><li><b data-tf="Shop.itemName"></b></li></template>'
      '</ul>',
    );
    final dispose = startThor([shop], root: root, features: allEngineFeatures);
    addTearDown(dispose);
    List<String?> names(String id) {
      final found = root.querySelectorAll('#$id li b');
      return [
        for (var i = 0; i < found.length; i++) found.item(i)!.textContent,
      ];
    }

    expect(names('a'), ['A']);
    expect(names('b'), ['B']);
    shop.items.value = ['a', 'a2', 'b', 'b2', 'b3'];
    expect(names('a'), ['A', 'A2']);
    expect(names('b'), ['B', 'B2', 'B3']);
  });

  // On dart2js: a broken #thor-state used to throw "Unexpected end of JSON
  // input" out of startThor and leave the page dead.
  // Only a payload that is not JSON at all is reported (once); valid JSON
  // that is not an object is just ignored.
  for (final (broken, reports) in [
    ('{"Shop.count":', 1),
    ('[1,2', 1),
    ('{"Shop.count": NaN}', 1),
    ('"x"', 0),
  ]) {
    test('a broken #thor-state ($broken) keeps the page interactive', () {
      final console = globalContext['console']! as JSObject;
      final original = console['error'];
      final reported = <String>[];
      console['error'] = ((JSAny? m) => reported.add(m.toString())).toJS;
      addTearDown(() => console['error'] = original);

      final shop = _Shop();
      final root = mount(
        '<script type="application/json" id="thor-state">$broken</script>'
        '<span data-tt="Shop.label">n=0</span>'
        '<button id="inc" data-t-on="click:Shop.inc">+</button>',
      );
      late void Function() dispose;
      expect(
        () => dispose = startThor(
          [shop],
          root: root,
          features: allEngineFeatures,
        ),
        returnsNormally,
      );
      addTearDown(dispose);
      // The code's values, and the page still reacts.
      expect(shop.count.value, 0);
      click(root.querySelector('#inc')!);
      expect(root.querySelector('[data-tt]')!.textContent, 'n=1');
      expect(reported.length, reports, reason: reported.join('|'));
    });
  }

  // A value of the wrong type for one field (a page cached from a deploy that
  // changed it, a hand-edited payload) is that field's problem: the others are
  // restored and the page is interactive. It used to throw out of startThor.
  for (final bad in ['"x"', '[1,2]', '{"a":1}', 'null', '1.5', 'true']) {
    test('a #thor-state value that does not fit its field ($bad)', () {
      final console = globalContext['console']! as JSObject;
      final original = console['error'];
      final reported = <String>[];
      console['error'] = ((JSAny? m) => reported.add(m.toString())).toJS;
      addTearDown(() => console['error'] = original);

      final shop = _Shop();
      final root = mount(
        '<script type="application/json" id="thor-state">'
        '{"Shop.count": $bad, "Shop.items": ["z"]}</script>'
        '<span data-tt="Shop.label">n=0</span>'
        '<button id="inc" data-t-on="click:Shop.inc">+</button>',
      );
      late void Function() dispose;
      expect(
        () => dispose = startThor(
          [shop],
          root: root,
          features: allEngineFeatures,
        ),
        returnsNormally,
      );
      addTearDown(dispose);
      expect(shop.count.value, 0, reason: 'its own value');
      expect(shop.items.value, ['z'], reason: 'the next field is restored');
      click(root.querySelector('#inc')!);
      expect(root.querySelector('[data-tt]')!.textContent, 'n=1');
      expect(reported.length, 1, reason: reported.join('|'));
      expect(reported.single, contains('Shop.count'));
    });
  }

  test('hydrate with a truncated #thor-state starts from the code values', () {
    final n = Signal(1);
    final root = mount(
      '<script type="application/json" id="thor-state">{"n":</script>'
      '<span data-tt="n">n=1</span>',
    );
    final console = globalContext['console']! as JSObject;
    final original = console['error'];
    console['error'] = ((JSAny? m) {}).toJS;
    addTearDown(() => console['error'] = original);
    late void Function() dispose;
    expect(
      () => dispose = hydrate(
        [
          StateBinding<int>(
            'n',
            n,
            encode: (v) => v,
            decode: (j) => (j! as num).toInt(),
          ),
          TextBinding('n', () => 'n=${n.value}'),
        ],
        root: root,
        features: allEngineFeatures,
      ),
      returnsNormally,
    );
    addTearDown(dispose);
    n.value = 2;
    expect(root.querySelector('span')!.textContent, 'n=2');
  });

  test('a state with another structure replaces the subtree (both ways)', () {
    final shop = _Shop();
    final root = mount(
      '<span data-tv="Shop.isZero">vacío</span>'
      '<template data-tvt="Shop.isZero" data-i="0">'
      '<section><b data-tt="Shop.label">n=?</b></section></template>',
    );
    addTearDown(startThor([shop], root: root, features: allEngineFeatures));
    shop.inc();
    expect(root.querySelector('section b')!.textContent, 'n=1');
    // The text inside the new subtree keeps following its binding.
    shop.inc();
    expect(root.querySelector('section b')!.textContent, 'n=2');
    shop.count.value = 0;
    expect(root.querySelector('section'), isNull);
    expect(root.querySelector('span')!.textContent, 'vacío');
    shop.inc();
    expect(root.querySelector('section b')!.textContent, 'n=1');
  });

  test(
    'a persisted field starts from its cookie and writes it on change',
    () async {
      void setCookie(String v) =>
          web.document.cookie = 'thor-s.big-test=$v; path=/';
      String? cookie() => {
        for (final p in web.document.cookie.split(';'))
          if (p.trim().split('=') case [final k, final v]) k: v,
      }['thor-s.big-test'];
      addTearDown(() => setCookie('; max-age=0'));

      setCookie('true');
      final prefs = _Prefs();
      final root = mount('<p data-tt="Prefs.label">chico</p>');
      const persist = [PersistedStatesFeature()];
      final stop = startThor([prefs], root: root, features: persist);
      // A static page: the engine applies it before painting.
      expect(root.textContent, 'grande');
      expect(cookie(), 'true'); // starting doesn't rewrite it
      prefs.big.value = false;
      expect(root.textContent, 'chico');
      // The write is coalesced: it lands with the next frame, not at once.
      expect(cookie(), 'true');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(cookie(), 'false');
      stop();

      // A value that isn't the field's is ignored.
      setCookie('%22si%22');
      final other = _Prefs();
      final again = mount('<p data-tt="Prefs.label">chico</p>');
      addTearDown(startThor([other], root: again, features: persist));
      expect(again.textContent, 'chico');
    },
  );

  test(
    'a burst of changes is one cookie write, and a hide flushes it',
    () async {
      const name = 'thor-s.big-test';
      addTearDown(() => web.document.cookie = '$name=; path=/; max-age=0');
      web.document.cookie = '$name=false; path=/';
      final prefs = _Prefs();
      final root = mount('<p data-tt="Prefs.label">chico</p>');
      final stop = startThor(
        [prefs],
        root: root,
        features: const [PersistedStatesFeature()],
      );
      addTearDown(stop);
      String? cookie() => {
        for (final p in web.document.cookie.split(';'))
          if (p.trim().split('=') case [final k, final v]) k: v,
      }[name];

      // Every write goes through a counting accessor over document.cookie.
      var writes = 0;
      final proto = web.document as JSObject;
      final desc =
          (globalContext['Object']! as JSObject).callMethod<JSAny?>(
                'getOwnPropertyDescriptor'.toJS,
                (globalContext['Document']! as JSObject)['prototype'],
                'cookie'.toJS,
              )!
              as JSObject;
      final get = desc['get']! as JSFunction;
      final set = desc['set']! as JSFunction;
      (globalContext['Object']! as JSObject).callMethod<JSAny?>(
        'defineProperty'.toJS,
        proto,
        'cookie'.toJS,
        {
          'configurable': true,
          'get': (() => get.callAsFunction(proto)).toJS,
          'set': ((JSString v) {
            writes++;
            set.callAsFunction(proto, v);
          }).toJS,
        }.jsify(),
      );
      addTearDown(
        () => (globalContext['Object']! as JSObject).callMethod<JSAny?>(
          'defineProperty'.toJS,
          proto,
          'cookie'.toJS,
          desc,
        ),
      );

      for (var i = 0; i < 50; i++) {
        prefs.big.value = !prefs.big.value;
      }
      prefs.big.value = true;
      expect(writes, 0, reason: 'nothing is written inside the burst');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(writes, 1);
      expect(cookie(), 'true');

      // Not waiting for the frame: leaving the page flushes the last value.
      prefs.big.value = false;
      expect(cookie(), 'true');
      web.window.dispatchEvent(
        web.PageTransitionEvent('pagehide', web.PageTransitionEventInit()),
      );
      expect(cookie(), 'false');
      expect(writes, 2);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(writes, 2, reason: 'the frame has nothing left to write');
    },
  );

  group('a local field (localStorage)', () {
    const key = 'thor-s.draft-test';
    final storage = web.window.localStorage;
    setUp(() => storage.removeItem(key));
    tearDown(() => storage.removeItem(key));
    const persist = [PersistedStatesFeature()];

    test('starts from its stored value and writes it once per frame', () async {
      storage.setItem(key, '"hola"');
      final draft = _Draft();
      final root = mount('<p data-tt="Draft.label"></p>');
      final stop = startThor([draft], root: root, features: persist);
      expect(root.textContent, 'hola');
      expect(storage.getItem(key), '"hola"'); // starting doesn't rewrite it
      for (var i = 0; i < 20; i++) {
        draft.text.value = 'v$i';
      }
      expect(storage.getItem(key), '"hola"', reason: 'not inside the burst');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(storage.getItem(key), '"v19"');
      stop();

      // A value that isn't the field's is ignored.
      storage.setItem(key, '42');
      final other = _Draft();
      final again = mount('<p data-tt="Draft.label"></p>');
      addTearDown(startThor([other], root: again, features: persist));
      expect(again.textContent, '');
    });

    test('takes what another tab stores, without writing it back', () async {
      final draft = _Draft();
      final root = mount('<p data-tt="Draft.label"></p>');
      addTearDown(startThor([draft], root: root, features: persist));
      // Another tab: the shared storage changes, then the event arrives.
      void fromTab(String? value, {web.Storage? area}) {
        if (area == null) {
          value == null ? storage.removeItem(key) : storage.setItem(key, value);
        }
        web.window.dispatchEvent(
          web.StorageEvent(
            'storage',
            web.StorageEventInit(
              key: key,
              newValue: value,
              storageArea: area ?? storage,
            ),
          ),
        );
      }

      fromTab('"otra"');
      expect(root.textContent, 'otra');
      fromTab('7'); // not a String: ignored
      expect(root.textContent, 'otra');
      fromTab(null); // removed: the page keeps its value
      expect(root.textContent, 'otra');
      web.window.sessionStorage.setItem(key, '"s"');
      addTearDown(() => web.window.sessionStorage.removeItem(key));
      fromTab(null, area: web.window.sessionStorage);
      expect(root.textContent, 'otra');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(storage.getItem(key), isNull, reason: 'no echo of the removal');
    });

    test('blocked storage: the value lives in memory, no error', () async {
      final objectJs = globalContext['Object']! as JSObject;
      final w = web.window as JSObject;
      objectJs.callMethod<JSAny?>(
        'defineProperty'.toJS,
        w,
        'localStorage'.toJS,
        {
          'configurable': true,
          // What a browser that blocks storage does on the read.
          'get': (globalContext['Function']! as JSFunction)
              .callAsConstructor<JSFunction>(
                "throw new DOMException('blocked', 'SecurityError')".toJS,
              ),
        }.jsify(),
      );
      addTearDown(() => w.delete('localStorage'.toJS));
      final draft = _Draft();
      final root = mount('<p data-tt="Draft.label"></p>');
      final stop = startThor([draft], root: root, features: persist);
      expect(root.textContent, '');
      draft.text.value = 'hola';
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(root.textContent, 'hola');
      stop();
      // A state started again in the page reads it back from memory.
      final again = _Draft();
      final root2 = mount('<p data-tt="Draft.label"></p>');
      addTearDown(startThor([again], root: root2, features: persist));
      expect(root2.textContent, 'hola');
    });
  });

  test(
    'ControllersFeature points PageNavigator at the document, and lets go',
    () {
      final shop = _Shop();
      final root = mount('<p data-tt="Shop.label">0</p>');
      final stop = startThor(
        [shop],
        root: root,
        features: const [ControllersFeature()],
      );
      expect(PageNavigator.handler, isNotNull);
      expect(PageNavigator.popHandler, isNotNull);
      expect(PageNavigator.reloadHandler, isNotNull);
      // A test page has no history of its own to go back to.
      expect(PageNavigator.canPop(), isA<bool>());
      stop();
      expect(PageNavigator.handler, isNull);
      expect(PageNavigator.popHandler, isNull);
      expect(PageNavigator.canPopHandler, isNull);
      expect(PageNavigator.reloadHandler, isNull);
    },
  );

  test(
    'PageNavigator.canPop / pop without the Navigation API (adversarial)',
    () {
      final w = web.window as JSObject;
      final d = web.document as JSObject;
      final objectJs = globalContext['Object']! as JSObject;
      void define(JSObject o, String k, JSAny? v) => objectJs.callMethod(
        'defineProperty'.toJS,
        o,
        k.toJS,
        {'value': v, 'configurable': true}.jsify(),
      );
      addTearDown(() {
        d.delete('referrer'.toJS);
      });
      // A browser without the API: `window.navigation` reads undefined.
      final saved = objectJs.callMethod(
        'getOwnPropertyDescriptor'.toJS,
        w,
        'navigation'.toJS,
      );
      expect(w.delete('navigation'.toJS).toDart, isTrue);
      addTearDown(() {
        if (!saved.isUndefinedOrNull) {
          objectJs.callMethod(
            'defineProperty'.toJS,
            w,
            'navigation'.toJS,
            saved,
          );
        }
      });
      final origin = web.window.location.origin;
      define(d, 'referrer', '$origin/list'.toJS);
      final shop = _Shop();
      final root = mount('<p data-tt="Shop.label">0</p>');
      final stop = startThor(
        [shop],
        root: root,
        features: const [ControllersFeature()],
      );
      addTearDown(stop);
      // Same-origin referrer: only with an entry before this one.
      expect(
        PageNavigator.canPop(),
        web.window.history.length > 1,
        reason: 'a referrer alone (a new tab from a link) is not an entry',
      );
      // A hash entry counts, whatever the referrer says.
      define(d, 'referrer', ''.toJS);
      expect(PageNavigator.canPop(), isFalse);
      web.window.history.pushState(null, '', '#a');
      web.window.dispatchEvent(web.Event('hashchange'));
      expect(PageNavigator.canPop(), isTrue);
      web.window.history.back();
    },
  );

  test('row states follow each item (existing and cloned rows)', () {
    final shop = _Shop();
    final root = mount(
      '<ul data-tl="Shop.items" data-tlk="Shop.itemKey">'
      '<li data-tk="ka"><b data-tf="Shop.itemName">A</b>'
      '<i class="no" data-tvf="Shop.isBig" data-tvi="0">x</i></li>'
      '<li data-tk="kb"><b data-tf="Shop.itemName">B</b>'
      '<i class="yes" data-tvf="Shop.isBig" data-tvi="1">x</i></li>'
      '<template data-tlt="Shop.items"><li><b data-tf="Shop.itemName"></b>'
      '<i class="no" data-tvf="Shop.isBig" data-tvi="0">x</i>'
      '<template data-tvft="Shop.isBig" data-i="1"><i class="yes">x</i></template>'
      '</li></template></ul>',
    );
    addTearDown(startThor([shop], root: root, features: allEngineFeatures));
    shop.items.value = ['b', 'c', 'bb'];
    final rows = _rows(root);
    expect(
      [for (final r in rows) r.getAttribute('data-tk')],
      ['kb', 'kc', 'kbb'],
    );
    expect(
      [for (final r in rows) r.querySelector('i')!.className],
      ['yes', 'no', 'yes'],
    );
    expect(
      [for (final r in rows) r.querySelector('b')!.textContent],
      ['B', 'C', 'BB'],
    );
    // Cloned rows don't carry the state templates.
    expect(rows[2].querySelector('template'), isNull);
  });

  // `AnimatedList`: a row that leaves stays (marked, inert) for the time the
  // container says; the rows the browser adds come with `data-tli` until they
  // have appeared.
  test('animated rows: a removed row leaves after its time, a new one '
      'enters', () async {
    final shop = _Shop();
    final root = mount(
      '<ul data-tl="Shop.items" data-tlk="Shop.itemKey" data-tlx="80">'
      '<li data-tk="ka"><b data-tf="Shop.itemName">A</b></li>'
      '<li data-tk="kb"><b data-tf="Shop.itemName">B</b></li>'
      '<template data-tlt="Shop.items"><li data-tli>'
      '<b data-tf="Shop.itemName"></b></li></template></ul>',
    );
    addTearDown(
      startThor(
        [shop],
        root: root,
        features: const [ListsFeature(animatedRows: true)],
      ),
    );
    shop.items.value = ['b', 'c'];
    List<String> keys() => [
      for (final r in _rows(root))
        [
          r.getAttribute('data-tk'),
          if (r.hasAttribute('data-tlo')) 'leaving',
          if (r.hasAttribute('data-tli')) 'new',
        ].join('-'),
    ];
    expect(keys(), ['ka-leaving', 'kb', 'kc-new']);
    expect(_rows(root).first.hasAttribute('inert'), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 160));
    expect(keys(), ['kb', 'kc'], reason: 'gone after its time, entered');
  });

  group('virtual lists', () {
    // 200 rows of 20 px, as the server draws them (all of them).
    String rows() => [
      for (var i = 0; i < 200; i++)
        '<li data-tk="ki$i" style="height:20px"><b data-tf="Shop.itemName">I$i</b></li>',
    ].join();
    const tpl =
        '<template data-tlt="Shop.items"><li style="height:20px">'
        '<b data-tf="Shop.itemName"></b></li></template>';
    List<String> all() => [for (var i = 0; i < 200; i++) 'i$i'];
    int count(web.Element root) => root.querySelectorAll('[data-tk]').length;

    test('a list that scrolls itself is windowed by its own scroll', () async {
      final shop = _Shop()..items.value = all();
      final root = mount(
        '<ul data-tl="Shop.items" data-tlk="Shop.itemKey" data-tlv="20" '
        'style="height:200px;overflow:auto;margin:0;padding:0">${rows()}$tpl</ul>',
      );
      addTearDown(startThor([shop], root: root, features: allEngineFeatures));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final ul = root.querySelector('ul')! as web.HTMLElement;
      expect(count(ul), lessThan(60), reason: 'only the rows near the top');
      ul.scrollTop = 3000;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final first = int.parse(
        ul.querySelector('[data-tk]')!.getAttribute('data-tk')!.substring(2),
      );
      expect(first, greaterThan(100), reason: 'the window followed the scroll');
      expect(count(ul), lessThan(60));
    });

    test('a container that wraps the list keeps the window mark with it', () {
      final shop = _Shop()..items.value = all();
      final root = mount(
        '<div data-tl="Shop.items" data-tlk="Shop.itemKey" data-tlv="20">'
        '<ul style="margin:0;padding:0">${rows()}$tpl</ul></div>',
      );
      addTearDown(startThor([shop], root: root, features: allEngineFeatures));
      expect(count(root), lessThan(60));
    });
  });

  test('row states shipped as patches of the template row (existing and '
      'cloned rows)', () {
    final shop = _Shop();
    final root = mount(
      '<ul data-tl="Shop.items" data-tlk="Shop.itemKey">'
      '<li data-tk="ka"><b data-tf="Shop.itemName">A</b>'
      '<i class="no" data-tvf="Shop.isBig" data-tvi="0">x</i></li>'
      '<li data-tk="kb"><b data-tf="Shop.itemName">B</b>'
      '<i class="yes" title="big" data-tvf="Shop.isBig" data-tvi="1">y</i></li>'
      '<template data-tlt="Shop.items"><li><b data-tf="Shop.itemName"></b>'
      '<i class="no" data-tvf="Shop.isBig" data-tvi="0" '
      'data-tp-1="|class|=yes;|title|=big;|#|=y">x</i>'
      '</li></template></ul>',
    );
    addTearDown(startThor([shop], root: root, features: allEngineFeatures));
    shop.items.value = ['b', 'c', 'bb'];
    final rows = _rows(root);
    expect(
      [for (final r in rows) r.getAttribute('data-tk')],
      ['kb', 'kc', 'kbb'],
    );
    expect(
      [for (final r in rows) r.querySelector('i')!.className],
      ['yes', 'no', 'yes'],
    );
    expect(
      [for (final r in rows) r.querySelector('i')!.getAttribute('title')],
      ['big', null, 'big'],
    );
    expect(
      [for (final r in rows) r.querySelector('i')!.textContent],
      ['y', 'x', 'y'],
    );
    // Live rows never carry the patches.
    expect(root.querySelectorAll('li [data-tp-1]').length, 0);
  });

  test('row attributes follow each item, sanitized (existing, cloned, '
      'reused rows)', () {
    final shop = _Shop();
    final root = mount(
      '<ul data-tl="Shop.items" data-tlk="Shop.itemKey">'
      '<li data-tk="ka" class="no" data-tvf="Shop.isBig" data-tvi="0">'
      '<a data-tfa="href:Shop.itemUrl;title:Shop.itemName" '
      'href="https://e.x/a" title="A">a</a>'
      '<i data-tfa="aria-selected:Shop.cellOn~1" aria-selected="true">'
      '<b data-tf="Shop.itemName">A</b></i></li>'
      '<template data-tlt="Shop.items">'
      '<li class="no" data-tvf="Shop.isBig" data-tvi="0">'
      '<a data-tfa="href:Shop.itemUrl;title:Shop.itemName" title>a</a>'
      '<i data-tfa="aria-selected:Shop.cellOn~1" aria-selected>'
      '<b data-tf="Shop.itemName"></b></i></li>'
      '<template data-tvft="Shop.isBig" data-i="1">'
      '<li class="yes" title="state"><a title="state">a</a>'
      '<i aria-selected="false"><b></b></i></li></template>'
      '</template></ul>',
    );
    addTearDown(startThor([shop], root: root, features: allEngineFeatures));
    String attrs() => [
      for (final r in _rows(root))
        [
          r.getAttribute('data-tk'),
          r.querySelector('a')!.getAttribute('href'),
          r.querySelector('a')!.getAttribute('title'),
          r.querySelector('i')!.getAttribute('aria-selected'),
        ].join('|').replaceFirst('|', ':'),
    ].join(',');

    shop.items.value = ['a', 'bb', 'xa'];
    expect(
      attrs(),
      'ka:https://e.x/a|A|true,kbb:https://e.x/bb|BB|false,'
      'kxa:null|XA|false',
      reason: 'a javascript: URL is removed, not written',
    );
    // A row state switch (bb is big) doesn't overwrite bound attributes.
    expect(_rows(root)[1].className, 'yes');
    // The same key with another item (a virtualized row reused for new
    // data): its attributes follow.
    final a = _rows(root).first;
    shop.items.value = ['x', 'bb', 'xa'];
    expect(root.querySelector('[data-tk=kx]'), isNotNull);
    shop.items.value = ['a', 'bb', 'xa'];
    expect(identical(_rows(root).first, a), isFalse);
    expect(attrs().split(',').first, 'ka:https://e.x/a|A|true');
    // The same row element given a new item (same key): rewritten in place.
    final kept = _rows(root).first;
    shop.items.value = ['a!', 'bb', 'xa'];
    expect(identical(_rows(root).first, kept), isTrue);
    expect(attrs().split(',').first, 'ka:https://e.x/a!|A!|false');
  });

  // The same state watched more than once: each element keeps its own
  // states (its templates, its patches).
  group('several elements per state', () {
    // What an element with states shows: tag, class and text.
    String look(web.Element? el) => el == null
        ? '-'
        : '${el.tagName.toLowerCase()}.${el.className}:${el.textContent}';

    test('two Watches of one state with different structures', () {
      final open = Signal(false);
      final v = VariantBinding(
        'open',
        count: 2,
        index: () => open.value ? 1 : 0,
      );
      // A chevron (a patch) in the header, the items (a template) below.
      final root = mount(
        '<button id="head"><i class="right" data-tv="open" data-tp-1="|class|=down"></i></button>'
        '<div id="body"><span data-tv="open"></span>'
        '<template data-tvt="open" data-i="1"><ul><li>uno</li><li>dos</li></ul></template></div>',
      );
      hydrate([v], root: root, features: allEngineFeatures);
      final head = root.querySelector('#head')!;
      final body = root.querySelector('#body')!;
      for (var round = 0; round < 2; round++) {
        open.value = true;
        expect(head.children.length, 1, reason: 'no items in the header');
        expect(look(head.firstElementChild), 'i.down:');
        expect(look(body.firstElementChild), 'ul.:unodos');
        open.value = false;
        expect(look(head.firstElementChild), 'i.right:');
        expect(look(body.firstElementChild), 'span.:');
        expect(body.querySelector('ul'), isNull);
      }
    });

    test('the same Watch rendered twice switches both, back and forth', () {
      final open = Signal(false);
      final v = VariantBinding(
        'open',
        count: 2,
        index: () => open.value ? 1 : 0,
      );
      const copy =
          '<p class="c" data-tv="open">cerrado</p>'
          '<template data-tvt="open" data-i="1"><ul><li>a</li></ul></template>';
      final root = mount('<nav id="a">$copy</nav><nav id="b">$copy</nav>');
      hydrate([v], root: root, features: allEngineFeatures);
      String both() => [
        for (final id in ['a', 'b'])
          look(root.querySelector('#$id')!.firstElementChild),
      ].join(' ');
      for (var round = 0; round < 3; round++) {
        open.value = true;
        expect(both(), 'ul.:a ul.:a');
        open.value = false;
        expect(both(), 'p.c:cerrado p.c:cerrado');
      }
    });

    test('a state inside one of two copies gets its own element', () {
      final open = Signal(false);
      final sel = Signal(false);
      final outer = VariantBinding(
        'open',
        count: 2,
        index: () => open.value ? 1 : 0,
      );
      final inner = VariantBinding(
        'sel',
        count: 2,
        index: () => sel.value ? 1 : 0,
      );
      final root = mount(
        '<nav id="a"><p data-tv="open">cerrado</p>'
        '<template data-tvt="open" data-i="1"><ul><li>plano</li></ul></template></nav>'
        '<nav id="b"><p data-tv="open">cerrado</p>'
        '<template data-tvt="open" data-i="1"><ul>'
        '<li class="off" data-tv="sel" data-tp-1="|class|=on">x</li></ul></template></nav>'
        '<b id="s" class="off" data-tv="sel" data-tp-1="|class|=on">s</b>',
      );
      hydrate([outer, inner], root: root, features: allEngineFeatures);
      final s = root.querySelector('#s')!;
      web.Element? nested() => root.querySelector('#b li');
      sel.value = true;
      open.value = true;
      expect(look(root.querySelector('#a li')), 'li.:plano');
      expect(look(nested()), 'li.on:x', reason: 'caught up on arrival');
      sel.value = false;
      expect(look(nested()), 'li.off:x');
      expect(look(s), 'b.off:s', reason: 'the page one still follows');
      open.value = false;
      expect(nested(), isNull);
      sel.value = true;
      expect(look(s), 'b.on:s');
      open.value = true;
      expect(look(nested()), 'li.on:x');
      expect(root.querySelectorAll('[data-tv=sel]').length, 2);
    });

    test('a Watch twice inside a replaced subtree: each copy moves', () {
      final open = Signal(false);
      final sel = Signal(false);
      final outer = VariantBinding(
        'open',
        count: 2,
        index: () => open.value ? 1 : 0,
      );
      final inner = VariantBinding(
        'sel',
        count: 2,
        index: () => sel.value ? 1 : 0,
      );
      // One copy patches, the other has a template.
      const both =
          '<i class="off" data-tv="sel" data-tp-1="|class|=on"></i>'
          '<u data-tv="sel">no</u>'
          '<template data-tvt="sel" data-i="1"><em>sí</em></template>';
      final root = mount(
        '<section data-tv="open">$both</section>'
        '<template data-tvt="open" data-i="1"><article>$both<b>más</b></article></template>',
      );
      hydrate([outer, inner], root: root, features: allEngineFeatures);
      String shown() {
        final box = root.firstElementChild!;
        return '${box.tagName.toLowerCase()} '
            '${look(box.querySelector('i'))} '
            '${look(box.querySelector('i')!.nextElementSibling)}';
      }

      sel.value = true;
      expect(shown(), 'section i.on: em.:sí');
      open.value = true;
      expect(shown(), 'article i.on: em.:sí');
      sel.value = false;
      expect(shown(), 'article i.off: u.:no');
      // Back to the server's markup, taken before the states inside moved.
      open.value = false;
      expect(shown(), 'section i.off: u.:no');
      sel.value = true;
      expect(shown(), 'section i.on: em.:sí');
      open.value = true;
      sel.value = false;
      expect(shown(), 'article i.off: u.:no');
      open.value = false;
      expect(shown(), 'section i.off: u.:no');
    });

    test('the same list in two containers renders in both', () {
      final items = Signal(['a']);
      final list = ListBinding<String>(
        'l',
        items: () => items.value,
        key: (i) => i,
        fields: {'n': (i) => i.toUpperCase()},
      );
      const copy =
          '<ul data-tl="l"><li data-tk="a"><b data-tf="n">A</b></li>'
          '<template data-tlt="l"><li><b data-tf="n"></b></li></template></ul>';
      final root = mount('<nav>$copy</nav><aside>$copy</aside>');
      hydrate([list], root: root, features: allEngineFeatures);
      items.value = ['b', 'a', 'c'];
      for (final box in ['nav', 'aside']) {
        expect(
          [for (final b in _all(root, '$box b')) b.textContent],
          ['B', 'A', 'C'],
          reason: box,
        );
      }
    });
  });

  test('a list per instance keeps arguments that look like the markup', () {
    final shop = _Shop()
      ..items.value = [
        'a~b1',
        'a~b2',
        'x/y1',
        'é☃😀1',
        'q"1',
        '<b>1',
        '1',
        'a',
      ];
    // `itemsOf` keeps the items that start with the argument.
    const args = ['a~b', 'x/y', 'é☃😀', 'q"', '<b>', ''];
    String esc(String v) => v
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll('<', '&lt;');
    String list(int i) =>
        '<ul id="o$i" data-tl="Shop.itemsOf~${esc(args[i])}" '
        'data-tlk="Shop.itemKey">'
        '<template data-tlt="Shop.itemsOf~${esc(args[i])}">'
        '<li><b data-tf="Shop.itemName"></b></li></template></ul>';
    final root = mount([for (var i = 0; i < args.length; i++) list(i)].join());
    final dispose = startThor([shop], root: root, features: allEngineFeatures);
    addTearDown(dispose);
    List<String?> names(int i) {
      final found = root.querySelectorAll('#o$i li b');
      return [
        for (var n = 0; n < found.length; n++) found.item(n)!.textContent,
      ];
    }

    expect(names(0), ['A~B1', 'A~B2']);
    expect(names(1), ['X/Y1']);
    expect(names(2), ['É☃😀1']);
    expect(names(3), ['Q"1']);
    expect(names(4), ['<B>1']);
    // The empty argument keeps every item (all of them start with '').
    expect(names(5), hasLength(8));
    shop.items.value = ['a~b3'];
    expect(names(0), ['A~B3']);
    expect(names(1), isEmpty);
    expect(names(5), ['A~B3']);
  });

  // A part of the page that arrives after hydration (`LazyPiece`, a
  // `FutureBuilder`): the loader fires `thor:stream` on <html> with the nodes
  // it put in place, and the engine binds them like the page.
  test('a part that arrives after hydration is bound (thor:stream)', () {
    final shop = _Shop();
    final state = web.document.createElement('script') as web.HTMLElement
      ..id = 'thor-state'
      ..textContent = '{"Shop.count":1}';
    web.document.body!.append(state);
    // ignore: unnecessary_lambdas
    addTearDown(() => state.remove());
    final root = mount(
      '<button id="page" data-t-on="click:Shop.inc">page</button>'
      '<span id="pageText" data-tt="Shop.label">n=1</span>'
      '<div id="host"></div>',
    );
    addTearDown(startThor([shop], root: root, features: allEngineFeatures));
    expect(shop.count.value, 1);

    // What the loader does: values to #thor-state, nodes in, the event.
    state.textContent = '{"Shop.count":1,"Shop.items":["a","b"]}';
    final host = root.querySelector('#host')!;
    const late =
        '<span id="lateText" data-tt="Shop.label">n=0</span>'
        '<button id="late" data-t-on="click:Shop.inc">late</button>'
        '<ul id="lateList" data-tl="Shop.itemsOf~a" data-tlk="Shop.itemKey">'
        '<template data-tlt="Shop.itemsOf~a"><li><b data-tf="Shop.itemName">'
        '</b></li></template></ul>';
    host.innerHTML = late.toJS;
    final nodes = [
      for (var i = 0; i < host.children.length; i++) host.children.item(i)!,
    ];
    final detail = JSObject()
      ..['nodes'] = nodes.map((n) => n as JSAny).toList().toJS;
    web.document.documentElement!.dispatchEvent(
      web.CustomEvent('thor:stream', web.CustomEventInit(detail: detail)),
    );
    // The late text follows the state, like the page's.
    expect(host.querySelector('#lateText')!.textContent, 'n=1');
    shop.count.value = 2;
    expect(host.querySelector('#lateText')!.textContent, 'n=2');
    expect(root.querySelector('#pageText')!.textContent, 'n=2');
    // The late button runs the action once (the page's listener and the
    // late part's are not both on it).
    click(host.querySelector('#late')!);
    expect(shop.count.value, 3);
    click(root.querySelector('#page')!);
    expect(shop.count.value, 4);
    // The late list shows its rows; the page's other bindings are untouched.
    expect(_rows(host).map((r) => r.textContent), ['A']);
  });

  test('WatchAttributes keeps an attribute current, sanitized', () {
    final shop = _Shop();
    final root = mount(
      '<div data-tca="aria-rowcount:Shop.itemCount;href:Shop.link" '
      'aria-rowcount="2" href="/p"></div>',
    );
    addTearDown(startThor([shop], root: root, features: allEngineFeatures));
    final el = root.querySelector('div')!;
    shop.items.value = ['a', 'b', 'c'];
    expect(el.getAttribute('aria-rowcount'), '3');
    expect(el.getAttribute('href'), '/p');
    shop.items.value = [];
    expect(el.getAttribute('aria-rowcount'), '0');
    expect(el.hasAttribute('href'), isFalse, reason: 'data: URL removed');
    shop.items.value = ['a'];
    expect(el.getAttribute('href'), '/p');
  });
}

List<web.Element> _rows(web.Element root) {
  final l = root.querySelectorAll('[data-tk]');
  return [for (var i = 0; i < l.length; i++) l.item(i)! as web.Element];
}

List<web.Element> _all(web.Element root, String selector) {
  final list = root.querySelectorAll(selector);
  return [for (var i = 0; i < list.length; i++) list.item(i)! as web.Element];
}

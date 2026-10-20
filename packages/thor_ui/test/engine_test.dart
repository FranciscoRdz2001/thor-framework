// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
// These tests are about the button's wiring, not its name.
// ignore_for_file: thor_lints/icon_button_without_name
@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart'
    show
        PatchOp,
        decodePatch,
        isBindableAttribute,
        isSafeUrl,
        safeAttributeValue;
import 'package:thor_ui/html.dart' as raw;
import 'package:thor_ui/src/foundation/row_bind.dart'
    show bindRowMarkers, isRowBindMarker, rowBindMarker;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class Line {
  const Line(this.id, this.name, [this.url = '']);
  final int id;
  final String name;
  final String url;
}

enum Tab { home, cart }

// The member list thor generates for [ShopState], by hand (tests don't run the build).
abstract class _ShopStateMembers extends ThorState {
  @override
  String get $type => 'ShopState';

  @override
  List<ThorMember> get $members {
    final s = this as ShopState;
    return [
      ThorMember.state('count', s.count),
      ThorMember.state('lines', s.lines),
      ThorMember.state('note', s.note),
      ThorMember('label', s.label, call: (_) => s.label()),
      ThorMember(
        'isEmpty',
        s.isEmpty,
        call: (_) => s.isEmpty(),
        variants: const [false, true],
      ),
      ThorMember('tab', s.tab, call: (_) => s.tab(), variants: Tab.values),
      ThorMember(
        'isLine',
        s.isLine,
        arity: 1,
        call: (a) => s.isLine(int.parse(a!)),
        variants: const [false, true],
      ),
      ThorMember('inc', s.inc, call: (_) => s.inc()),
      ThorMember('setOn', s.setOn, arity: 1, call: (a) => s.setOn(a == 'true')),
      ThorMember('add', s.add, arity: 1, call: (a) => s.add(int.parse(a!))),
      ThorMember('addTag', s.addTag, arity: 1, call: (a) => s.addTag(a!)),
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
        'lineKey',
        s.lineKey,
        arity: 1,
        callWithItem: (i) => s.lineKey(i as Line),
      ),
      ThorMember(
        'lineName',
        s.lineName,
        arity: 1,
        callWithItem: (i) => s.lineName(i as Line),
      ),
      ThorMember(
        'isFirst',
        s.isFirst,
        arity: 1,
        callWithItem: (i) => s.isFirst(i as Line),
        variants: const [false, true],
      ),
      ThorMember(
        'lineUrl',
        s.lineUrl,
        arity: 1,
        callWithItem: (i) => s.lineUrl(i as Line),
      ),
      ThorMember(
        'cellLabel',
        s.cellLabel,
        arity: 2,
        callWithArgAndItem: (String? a, i) =>
            s.cellLabel(int.parse(a!), i as Line),
      ),
      ThorMember(
        'cellOn',
        s.cellOn,
        arity: 2,
        callWithArgAndItem: (String? a, i) =>
            s.cellOn(int.parse(a!), i as Line),
        variants: const [false, true],
      ),
      ThorMember('rowCount', s.rowCount, call: (_) => s.rowCount()),
      ThorMember('pageUrl', s.pageUrl, call: (_) => s.pageUrl()),
    ];
  }
}

class ShopState extends _ShopStateMembers {
  final count = state(2);
  final lines = state(const [
    Line(1, 'Café', 'https://cafe.example/menu?a=1&b=2'),
    Line(2, 'Pan', 'javascript:alert(1)'),
  ]);
  final note = state('</script><b>');

  String label() => 'Total ${count.value}';
  bool isEmpty() => count.value == 0;
  Tab tab() => Tab.cart;
  bool isLine(int id) => lines.value.any((l) => l.id == id);
  void inc() => count.value++;
  void setOn(bool? on) {}
  void add(int n) => count.value += n;
  void addTag(String tag) {}
  void setFlag(int i, bool on) {}
  String lineKey(Line l) => 'l${l.id}';
  String lineName(Line l) => l.name;
  bool isFirst(Line l) => l.id == 1;
  String lineUrl(Line l) => l.url;
  String cellLabel(int column, Line l) => '${l.name} · $column';
  bool cellOn(int column, Line l) => column == l.id;
  int rowCount() => lines.value.length + 1;
  String pageUrl() => 'data:text/html,<script>alert(1)</script>';
}

final shop = ShopState();

/// The ops of state [index] on the page's first live state element.
List<PatchOp> patchesOf(String html, int index) => decodePatch(
  RegExp('data-tp-$index="([^"]*)"')
      .firstMatch(html)![1]!
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&'),
);

void main() {
  initializeThorTests();

  group('a folded margin on states inside states', () {
    // The box of the outer states (`display: contents`) takes no part in
    // the layout: a margin on it would do nothing.
    String box(String html) => RegExp(
      r'<div style="[^"]*display: contents[^"]*"[^>]*>',
    ).firstMatch(html)![0]!;

    test('the margin goes to the element inside, not the box', () async {
      final html = await renderHtml(
        Column(
          children: [
            const Text('a'),
            const SizedBox(height: 12),
            Watch(
              shop.isEmpty,
              builder: (_) => Watch(shop.tab, builder: (t) => Text(t.name)),
            ),
          ],
        ),
      );
      expect(box(html), isNot(contains('margin-top')));
      expect(box(html), contains('data-tv="ShopState.isEmpty"'));
      // The inner live element: the margin and the column's rules.
      expect(
        html,
        contains('flex: 0 0 auto; margin-top: 12px" data-tv="ShopState.tab"'),
      );
    });

    test('a state shipped as a template keeps the margin too', () async {
      final html = await renderHtml(
        Column(
          children: [
            const Text('a'),
            const SizedBox(height: 12),
            Watch(
              shop.isEmpty,
              builder: (empty) => Watch(
                shop.tab,
                builder: (t) =>
                    empty ? Row(children: [Text(t.name)]) : Text(t.name),
              ),
            ),
          ],
        ),
      );
      final template = html.substring(html.indexOf('<template'));
      expect(template, contains('margin-top: 12px'));
      expect(box(template), isNot(contains('margin-top')));
    });
  });

  test('Watch of a text method renders the value with its id', () async {
    final html = await renderHtml(Watch(shop.label));
    expect(html, contains('data-tt="ShopState.label"'));
    expect(html, contains('Total 2'));
  });

  test('TextField onSubmitted binds Enter (and can clear the field)', () async {
    final html = await renderHtml(
      TextField(onSubmitted: shop.addTag, clearOnSubmitted: true),
    );
    expect(html, contains('data-t-on="enter:ShopState.addTag"'));
    expect(html, contains('data-t-clear'));
  });

  test('row.field posts each item as a hidden input', () async {
    final html = await renderHtml(
      Watch.list(
        shop.lines,
        itemKey: shop.lineKey,
        each: (row) => row.field('tag', shop.lineName),
      ),
    );
    expect(
      html,
      contains(
        'type="hidden" name="tag" value="Café" data-tf="ShopState.lineName"',
      ),
    );
    // The row template has an empty value, filled by the browser.
    expect(
      html,
      contains(
        '<template data-tlt="ShopState.lines"><input type="hidden" name="tag" value data-tf',
      ),
    );
  });

  test('Watch of a field renders its value', () async {
    final html = await renderHtml(Watch(shop.count));
    expect(html, contains('data-tt="ShopState.count"'));
    expect(html, contains('>2<'));
  });

  test('Watch with a builder precompiles every state (bool, enum)', () async {
    final html = await renderHtml(
      Watch(shop.isEmpty, builder: (empty) => Text(empty ? 'empty' : 'full')),
    );
    expect(html, contains('data-tv="ShopState.isEmpty"'));
    expect(html, contains('full'));
    // Same structure: the other state is a patch of the live element, not
    // a copy of its markup.
    expect(html, isNot(contains('<template')));
    expect(patchesOf(html, 1), [const PatchOp([], '#', 'empty')]);

    final tabs = await renderHtml(
      Watch(shop.tab, builder: (t) => Text(t.name)),
    );
    expect(tabs, isNot(contains('<template')));
    expect(patchesOf(tabs, 0), [const PatchOp([], '#', 'home')]);
  });

  // The engine gives every element of a state its own states: the
  // templates right after it and the patches on it.
  test('a state watched twice: each element carries its own states', () async {
    final html = await renderHtml(
      Column(
        children: [
          Watch(shop.isEmpty, builder: (empty) => Text(empty ? 'v' : '>')),
          Row(
            children: [
              Expanded(
                child: Watch(
                  shop.isEmpty,
                  builder: (empty) => empty
                      ? const Column(children: [Text('a'), Text('b')])
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    // The chevron patches; the other element's template follows it.
    expect(
      html,
      contains('data-tv="ShopState.isEmpty" data-tp-1="|#|=v">&gt;</span>'),
    );
    expect(
      html,
      contains(
        'data-tv="ShopState.isEmpty"></div>'
        '<template data-tvt="ShopState.isEmpty" data-i="1">',
      ),
    );
    expect('data-tvt='.allMatches(html), hasLength(1));
  });

  group('states as patches', () {
    test('a button enabled in one state: handler and disabled', () async {
      final html = await renderHtml(
        Watch(
          shop.isEmpty,
          builder: (empty) => TextButton(
            onPressed: empty ? null : shop.inc,
            child: const Text('+'),
          ),
        ),
      );
      expect(html, isNot(contains('<template')));
      final ops = patchesOf(html, 1);
      expect(ops, contains(const PatchOp([], 'data-t-on', null)));
      expect(ops, contains(const PatchOp([], 'disabled', '')));
    });

    test('a nested state the same in both is left alone', () async {
      final html = await renderHtml(
        Watch(
          shop.isEmpty,
          builder: (empty) => Column(
            children: [
              Text(empty ? 'empty' : 'full'),
              Watch(shop.tab, builder: (t) => Text(t.name)),
            ],
          ),
        ),
      );
      expect(html, isNot(contains('<template')));
      // Only the first child changes: nothing goes into the nested state.
      expect(patchesOf(html, 1), [
        const PatchOp([0], '#', 'empty'),
      ]);
    });

    test('a nested state that differs keeps the template', () async {
      final html = await renderHtml(
        Watch(
          shop.isEmpty,
          builder: (empty) => Column(
            children: [
              Watch(
                shop.tab,
                builder: (t) => Text(empty ? 'x${t.name}' : t.name),
              ),
            ],
          ),
        ),
      );
      expect(
        html,
        contains('<template data-tvt="ShopState.isEmpty" data-i="1">'),
      );
    });

    test('a binding only one state has keeps the template', () async {
      final html = await renderHtml(
        Watch(
          shop.isEmpty,
          builder: (empty) => Column(
            children: [empty ? const Text('nothing') : Watch(shop.label)],
          ),
        ),
      );
      expect(
        html,
        contains('<template data-tvt="ShopState.isEmpty" data-i="1">'),
      );
      expect(html, isNot(contains('data-tp-')));
    });

    test('raw markup that differs keeps the template', () async {
      final html = await renderHtml(
        Watch(
          shop.isEmpty,
          builder: (empty) =>
              Column(children: [raw.RawText(empty ? '<i>a</i>' : '<b>b</b>')]),
        ),
      );
      expect(
        html,
        contains('<template data-tvt="ShopState.isEmpty" data-i="1">'),
      );
    });
  });

  test('withArg puts the argument in the id', () async {
    final html = await renderHtml(
      Watch(shop.isLine.withArg(2), builder: (on) => Text('$on')),
    );
    expect(html, contains('data-tv="ShopState.isLine~2"'));
    expect(html, contains('true'));
  });

  test('callbacks that are state methods become engine markers', () async {
    final html = await renderHtml(
      Column(
        children: [
          FilledButton(onPressed: shop.inc, child: const Text('+')),
          IconButton(
            icon: const Icon(IconData.svg('x', '<path d="M0 0"/>')),
            onPressed: shop.add.withArg(3),
          ),
          Switch(value: false, onChanged: shop.setFlag.withArg(4)),
          FilterChip(
            label: const Text('A'),
            selected: false,
            onSelected: shop.setFlag.withArg(5),
          ),
          FilledButton(onPressed: () {}, child: const Text('closure')),
        ],
      ),
    );
    expect(html, contains('data-t-on="click:ShopState.inc"'));
    expect(html, contains('data-t-on="click:ShopState.add" data-tx="3"'));
    // A two-parameter method: fixed argument + the control's value.
    expect(
      html,
      contains('data-t-on="change:ShopState.setFlag" data-tx="4" data-txv'),
    );
    // A chip gives its next state itself.
    expect(
      html,
      contains('data-t-on="click:ShopState.setFlag" data-tx="5~true"'),
    );
    // A closure is not an engine action (and still enables the button).
    expect(RegExp('data-t-on').allMatches(html), hasLength(4));
    expect(RegExp('disabled=""').allMatches(html), isEmpty);
  });

  test('a list renders keyed rows plus a row template', () async {
    final html = await renderHtml(
      Watch.list(
        shop.lines,
        itemKey: shop.lineKey,
        container: (rows) => Semantics(
          role: SemanticsRole.list,
          child: Column(children: rows),
        ),
        each: (row) => Semantics(
          role: SemanticsRole.listItem,
          child: Row(
            children: [
              row.text(shop.lineName),
              IconButton(
                icon: const Icon(IconData.svg('x', '<path d="M0 0"/>')),
                onPressed: shop.add.withArg(1),
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      html,
      contains('data-tl="ShopState.lines" data-tlk="ShopState.lineKey"'),
    );
    expect(html, contains('data-tk="l1"'));
    expect(html, contains('data-tk="l2"'));
    expect(html, contains('data-tf="ShopState.lineName"'));
    expect(html, contains('Café'));
    expect(html, contains('<template data-tlt="ShopState.lines">'));
  });

  test('row.watch: current state per row, other states as patches of the '
      'template row', () async {
    final html = await renderHtml(
      Watch.list(
        shop.lines,
        itemKey: shop.lineKey,
        each: (row) => row.watch(
          shop.isFirst,
          builder: (first) => Text(first ? 'first' : 'other'),
        ),
      ),
    );
    expect(html, contains('data-tvf="ShopState.isFirst" data-tvi="1">first'));
    expect(html, contains('data-tvf="ShopState.isFirst" data-tvi="0">other'));
    // Same structure: a patch of the template row's element, no copy.
    final template = html.substring(html.indexOf('<template data-tlt='));
    expect(template, isNot(contains('data-tvft')));
    expect(
      template,
      contains(
        'data-tvf="ShopState.isFirst" data-tvi="0" '
        'data-tp-1="|#|=first">other',
      ),
    );
  });

  test(
    'row.watch: a state with another structure stays a <template>',
    () async {
      final html = await renderHtml(
        Watch.list(
          shop.lines,
          itemKey: shop.lineKey,
          each: (row) => row.watch(
            shop.isFirst,
            builder: (first) => first
                ? const Column(children: [Text('a'), Text('b')])
                : const Text('other'),
          ),
        ),
      );
      final template = html.substring(html.indexOf('<template data-tlt='));
      expect(
        template,
        contains('<template data-tvft="ShopState.isFirst" data-i="1">'),
      );
      expect(template, isNot(contains('data-tp-')));
    },
  );

  test('row.watch: a wrapper around it decorates every state, never the '
      '<template> that carries one', () async {
    final html = await renderHtml(
      Watch.list(
        shop.lines,
        itemKey: shop.lineKey,
        container: (rows) => Semantics(
          role: SemanticsRole.list,
          child: Column(children: rows),
        ),
        each: (row) => Semantics(
          role: SemanticsRole.listItem,
          child: row.attribute(
            AttributeName.ariaOf(AriaAttribute.label),
            shop.lineName,
            child: row.watch(
              shop.isFirst,
              builder: (first) => Text(first ? 'first' : 'other'),
            ),
          ),
        ),
      ),
    );
    final template = html.substring(html.indexOf('<template data-tlt='));
    // The live state of the row template is the <li> with the binding and
    // the bound attribute; the other state patches only its text, so the
    // row keeps its <li>, its key and its bound attribute.
    final li = RegExp(r'<li[^>]*>').firstMatch(template)![0]!;
    expect(li, contains('data-tfa="aria-label:ShopState.lineName"'));
    expect(li, contains('data-tvf="ShopState.isFirst"'));
    expect(li, contains('data-tp-1="|#|=first"'));
    expect(template, isNot(contains('data-tvft')));
    // Server rows: an <li> each, keyed.
    expect(RegExp('<li[^>]*data-tk=').allMatches(html).length, 2);
  });

  group('row.attribute', () {
    Future<String> rows(Widget Function(WatchRow<Line, String> row) each) =>
        renderHtml(Watch.list(shop.lines, itemKey: shop.lineKey, each: each));

    test('renders each row value, sanitized, and marks the binding', () async {
      final html = await rows(
        (row) => Link(
          href: const RouteUrl('#placeholder'),
          newTab: true,
          child: row.attribute(
            AttributeName.href,
            shop.lineUrl,
            child: row.attribute(
              AttributeName.ariaOf(AriaAttribute.label),
              shop.lineName,
              child: row.text(shop.lineName),
            ),
          ),
        ),
      );
      // A safe URL wins over the Link's placeholder (escaped as usual).
      expect(html, contains('href="https://cafe.example/menu?a=1&amp;b=2"'));
      expect(html, contains('target="_blank" rel="noopener noreferrer"'));
      expect(html, contains('aria-label="Café"'));
      expect(html, contains('aria-label="Pan"'));
      // Both bindings on one element (nested wrappers keep both).
      expect(
        html,
        contains(
          'data-tfa="aria-label:ShopState.lineName;href:ShopState.lineUrl"',
        ),
      );
      // javascript: never reaches the page, and the placeholder is gone too.
      expect(html, isNot(contains('javascript')));
      expect(RegExp('href="#placeholder"').allMatches(html), isEmpty);
      // The row template carries the binding and no URL (the engine fills
      // it per row); its other attributes are empty.
      final template = html.substring(html.indexOf('<template'));
      expect(template, contains('data-tfa='));
      expect(template, isNot(contains('href=')));
      expect(template, contains(' aria-label '));
    });

    test('src through Link > ClipRRect > Image reaches the <img>, not the '
        '<a> (#20)', () async {
      final html = await rows(
        (row) => Link(
          href: const RouteUrl('/p'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: row.attribute(
              AttributeName.src,
              shop.lineUrl,
              child: row.attribute(
                AttributeName.alt,
                shop.lineName,
                child: const Image.network(''),
              ),
            ),
          ),
        ),
      );
      final a = RegExp(r'<a[^>]*>').firstMatch(html)![0]!;
      final img = RegExp(r'<img[^>]*>').firstMatch(html)![0]!;
      expect(a, isNot(contains('src=')));
      expect(a, isNot(contains('alt=')));
      expect(a, isNot(contains('data-tfa')));
      expect(a, contains('href="/p"'));
      expect(img, contains('src="https://cafe.example/menu?a=1&amp;b=2"'));
      expect(img, contains('alt="Café"'));
      expect(
        img,
        contains('data-tfa="alt:ShopState.lineName;src:ShopState.lineUrl"'),
      );
    });

    test('an href binding still goes to the <a> around an <img>', () async {
      final html = await rows(
        (row) => Link(
          href: const RouteUrl('#placeholder'),
          child: row.attribute(
            AttributeName.href,
            shop.lineUrl,
            child: row.attribute(
              AttributeName.src,
              shop.lineUrl,
              child: const Image.network(''),
            ),
          ),
        ),
      );
      final a = RegExp(r'<a[^>]*>').firstMatch(html)![0]!;
      final img = RegExp(r'<img[^>]*>').firstMatch(html)![0]!;
      expect(a, contains('href="https://cafe.example/menu?a=1&amp;b=2"'));
      expect(a, contains('data-tfa="href:ShopState.lineUrl"'));
      expect(img, isNot(contains('href=')));
      expect(img, contains('data-tfa="src:ShopState.lineUrl"'));
    });

    test(
      'on a TextField, the control\'s attributes go to its <input>',
      () async {
        for (final field in [
          const TextField(name: 'env_key'),
          const TextField(
            name: 'env_key',
            decoration: InputDecoration(labelText: 'Clave'),
          ),
        ]) {
          final html = await rows(
            (row) => row.attribute(
              AttributeName.value,
              shop.lineName,
              child: row.attribute(
                AttributeName.ariaOf(AriaAttribute.label),
                shop.lineName,
                child: row.attribute(
                  AttributeName.title,
                  shop.lineName,
                  child: field,
                ),
              ),
            ),
          );
          final input = RegExp(r'<input[^>]*>').firstMatch(html)![0]!;
          expect(input, contains('value="Café"'));
          expect(input, contains('aria-label="Café"'));
          expect(
            input,
            contains(
              'data-tfa="aria-label:ShopState.lineName;'
              'value:ShopState.lineName"',
            ),
          );
          // The rest stays on the field's outer element.
          expect(RegExp(r'<label[^>]*value=').hasMatch(html), isFalse);
          expect(html, contains('data-tfa="title:ShopState.lineName"'));
          expect(RegExp(r'<input[^>]*title=').hasMatch(html), isFalse);
          // The row template's input carries the binding too.
          final template = html.substring(html.indexOf('<template'));
          expect(template, contains('value:ShopState.lineName'));
          expect(RegExp(r'<input[^>]*data-tfa=').hasMatch(template), isTrue);
        }
      },
    );

    test('a method with a fixed argument works per row (withArg)', () async {
      final html = await rows(
        (row) => Row(
          children: [
            for (final c in [1, 2])
              row.attribute(
                AttributeName.ariaOf(AriaAttribute.selected),
                shop.cellOn.withArg(c),
                child: row.text(shop.cellLabel.withArg(c)),
              ),
          ],
        ),
      );
      expect(html, contains('data-tf="ShopState.cellLabel~2"'));
      expect(html, contains('Café · 1'));
      expect(html, contains('Pan · 2'));
      expect(
        html,
        contains(
          'data-tfa="aria-selected:ShopState.cellOn~1" aria-selected="true"',
        ),
      );
      expect(RegExp('aria-selected="true"').allMatches(html), hasLength(2));
    });

    test('rejects handlers, style, class and engine markers', () async {
      for (final name in [
        'onclick',
        'onmouseover',
        'style',
        'class',
        'srcdoc',
        'data-tk',
        'Href',
        'xlink:href',
      ]) {
        await expectLater(
          rows(
            (row) => row.attribute(
              AttributeName(name),
              shop.lineName,
              child: const Text('x'),
            ),
          ),
          throwsArgumentError,
          reason: name,
        );
      }
      // A method that doesn't take the item is not a `Watch.list` row's
      // (the compiler refuses `row.attribute(AttributeName.title, shop.label, …)`).
    });
  });

  group('row.bind', () {
    Future<String> rows(Widget Function(WatchRow<Line, String> row) each) =>
        renderHtml(Watch.list(shop.lines, itemKey: shop.lineKey, each: each));

    // What a row holds: the row template is the last `<template>`.
    String template(String html) => html.substring(html.indexOf('<template'));
    String tag(String html, String name, {int from = 0}) =>
        RegExp('<$name[^>]*>').allMatches(html.substring(from)).first[0]!;

    test('Checkbox(semanticLabel:) names each row, also the ones the '
        'browser adds', () async {
      final html = await rows(
        (row) => Checkbox(
          value: false,
          semanticLabel: row.bind(shop.lineName),
          onChanged: shop.setOn,
        ),
      );
      // Server rows: the row's own name, on the <input>.
      expect(html, contains('aria-label="Café"'));
      expect(html, contains('aria-label="Pan"'));
      // The same binding `row.attribute` makes.
      final input = tag(html, 'input');
      expect(input, contains('data-tfa="aria-label:ShopState.lineName"'));
      // The row template has the binding and no name: the browser fills it.
      final t = tag(template(html), 'input');
      expect(t, contains('data-tfa="aria-label:ShopState.lineName"'));
      expect(t, isNot(contains('Café')));
      expect(t, contains(' aria-label '));
      // The marker never reaches the page.
      expect(html, isNot(contains('')));
      expect(html, isNot(contains('')));
    });

    test('an IconButton tooltip binds both the name and the hint', () async {
      final html = await rows(
        (row) => IconButton(
          icon: const Icon(Icons.delete),
          tooltip: row.bind(shop.lineName),
          onPressed: shop.inc,
        ),
      );
      final button = tag(html, 'button');
      expect(button, contains('aria-label="Café"'));
      expect(button, contains('title="Café"'));
      expect(
        button,
        contains(
          'data-tfa="aria-label:ShopState.lineName;title:ShopState.lineName"',
        ),
      );
      expect(html, isNot(contains('')));
    });

    test('Semantics(label:) binds too', () async {
      final html = await rows(
        (row) => Semantics(
          label: row.bind(shop.lineName),
          child: Checkbox(value: true, onChanged: shop.setOn),
        ),
      );
      final input = tag(html, 'input');
      expect(input, contains('aria-label="Café"'));
      expect(input, contains('data-tfa="aria-label:ShopState.lineName"'));
      expect(html, isNot(contains('\uE000')));
    });

    test('a method with a fixed argument (withArg) binds per row', () async {
      final html = await rows(
        (row) => Checkbox(
          value: false,
          semanticLabel: row.bind(shop.cellLabel.withArg(2)),
          onChanged: shop.setOn,
        ),
      );
      expect(html, contains('aria-label="Café · 2"'));
      expect(html, contains('data-tfa="aria-label:ShopState.cellLabel~2"'));
    });

    test('shares the element with row.attribute: both bindings stay', () async {
      final html = await rows(
        (row) => row.attribute(
          AttributeName.data('note'),
          shop.lineUrl,
          child: Checkbox(
            value: false,
            semanticLabel: row.bind(shop.lineName),
            onChanged: shop.setOn,
          ),
        ),
      );
      final input = tag(html, 'input');
      expect(input, contains('aria-label:ShopState.lineName'));
      expect(input, contains('data-note:ShopState.lineUrl'));
      expect(input, contains('aria-label="Café"'));
    });

    test(
      'quotes, markup, ; and : in the value are data, escaped once',
      () async {
        const hostile = 'Té "q" <b>x</b> & a;b:c';
        final before = shop.lines.value;
        shop.lines.value = const [Line(7, hostile)];
        addTearDown(() => shop.lines.value = before);
        final html = await rows(
          (row) => Checkbox(
            value: false,
            semanticLabel: row.bind(shop.lineName),
            onChanged: shop.setOn,
          ),
        );
        final input = tag(html, 'input');
        expect(
          input,
          contains(
            'aria-label="Té &quot;q&quot; &lt;b&gt;x&lt;/b&gt; &amp; a;b:c"',
          ),
        );
        // The binding names the field, never the value.
        expect(input, contains('data-tfa="aria-label:ShopState.lineName"'));
        expect(html, isNot(contains('<b>x')));
      },
    );

    test('an unsafe URL is left out, like row.attribute', () async {
      final html = await rows(
        (row) => Link(
          href: RouteUrl(row.bind(shop.lineUrl)),
          child: const Text('go'),
        ),
      );
      expect(html, contains('href="https://cafe.example/menu?a=1&amp;b=2"'));
      expect(html, isNot(contains('javascript')));
      expect(html, contains('data-tfa="href:ShopState.lineUrl"'));
    });

    test('an empty value is an empty attribute, never the word null', () async {
      final before = shop.lines.value;
      shop.lines.value = const [Line(8, '')];
      addTearDown(() => shop.lines.value = before);
      final html = await rows(
        (row) => Checkbox(
          value: false,
          semanticLabel: row.bind(shop.lineName),
          onChanged: shop.setOn,
        ),
      );
      expect(html, isNot(contains('null')));
      expect(tag(html, 'input'), contains('data-tfa="aria-label:'));
    });

    test('a TextField hint goes to the <input> with its binding', () async {
      final html = await rows(
        (row) => TextField(
          name: 'n',
          decoration: InputDecoration(hintText: row.bind(shop.lineName)),
        ),
      );
      final input = tag(html, 'input');
      expect(input, contains('placeholder="Café"'));
      expect(input, contains('placeholder:ShopState.lineName'));
      expect(html, isNot(contains('')));
    });

    test('a marker on an attribute a binding may not write is THOR-S035', () {
      final marker = rowBindMarker('ShopState.lineName', 'x');
      for (final name in ['onclick', 'style', 'class', 'data-tk']) {
        expect(
          () => bindRowMarkers({name: marker}),
          throwsA(
            isA<ArgumentError>().having(
              (e) => '$e',
              'message',
              contains('THOR-S035'),
            ),
          ),
          reason: name,
        );
      }
    });

    group('the marker never reaches the page (THOR-S036)', () {
      final cases = <String, Widget Function(WatchRow<Line, String>)>{
        'Text(row.bind)': (r) => Text(r.bind(shop.lineName)),
        'interpolated': (r) => Checkbox(
          value: false,
          semanticLabel: 'Task ${r.bind(shop.lineName)}',
          onChanged: shop.setOn,
        ),
        'suffixed': (r) => Checkbox(
          value: false,
          semanticLabel: '${r.bind(shop.lineName)}!',
          onChanged: shop.setOn,
        ),
        'toUpperCase': (r) => Checkbox(
          value: false,
          semanticLabel: r.bind(shop.lineName).toUpperCase(),
          onChanged: shop.setOn,
        ),
        'tooltip concatenated': (r) => IconButton(
          icon: const Icon(Icons.delete),
          tooltip: 'x${r.bind(shop.lineName)}',
          onPressed: shop.inc,
        ),
        'InputDecoration.labelText': (r) => TextField(
          name: 'n',
          decoration: InputDecoration(labelText: r.bind(shop.lineName)),
        ),
        'Tooltip.message': (r) =>
            Tooltip(message: r.bind(shop.lineName), child: const Text('a')),
        'Chip.label': (r) => Chip(label: Text(r.bind(shop.lineName))),
      };
      for (final MapEntry(:key, :value) in cases.entries) {
        test('$key fails loudly', () {
          expect(
            rows(value),
            throwsA(
              isA<StateError>().having(
                (e) => '$e',
                'message',
                allOf(contains('THOR-S036'), contains('row.bind')),
              ),
            ),
          );
        });
      }

      test('what works leaves no marker: trim, Image, Icon, Tooltip', () async {
        for (final each in <Widget Function(WatchRow<Line, String>)>[
          (r) => Checkbox(
            value: false,
            semanticLabel: r.bind(shop.lineName).trim(),
            onChanged: shop.setOn,
          ),
          (r) => Image.network('/a.png', semanticLabel: r.bind(shop.lineName)),
          (r) => Icon(Icons.delete, semanticLabel: r.bind(shop.lineName)),
        ]) {
          final html = await rows(each);
          expect(html, isNot(matches('[\uE000-\uE002]')));
          expect(html, contains('data-tfa="'));
        }
      });
    });

    test('text from a user with the private characters is data, never a '
        'binding', () async {
      const spoof = '\uE000onclick\uE001alert(1)\uE002';
      const spoofId = '\uE000ShopState.lineName\uE001x\uE002';
      final html = await rows(
        (row) => Column(
          children: [
            Checkbox(value: false, semanticLabel: spoof, onChanged: shop.setOn),
            Checkbox(
              value: false,
              semanticLabel: spoofId,
              onChanged: shop.setOn,
            ),
            const Text(spoofId),
          ],
        ),
      );
      expect(html, isNot(contains('data-tfa')));
      expect(html, isNot(contains(' onclick=')));
      expect(html, contains('aria-label="$spoofId"'));
    });

    test('a row value with the marker characters stays the value', () async {
      const hostile = 'a\uE001b\uE002c\uE000d';
      final before = shop.lines.value;
      shop.lines.value = const [Line(9, hostile)];
      addTearDown(() => shop.lines.value = before);
      final html = await rows(
        (row) => Checkbox(
          value: false,
          semanticLabel: row.bind(shop.lineName),
          onChanged: shop.setOn,
        ),
      );
      expect(html, contains('aria-label="$hostile"'));
      expect(html, contains('data-tfa="aria-label:ShopState.lineName"'));
    });

    test('only a real marker is touched', () {
      final plain = {'aria-label': 'Café', 'title': ' lone'};
      expect(identical(bindRowMarkers(plain), plain), isTrue);
      expect(isRowBindMarker(' no separator'), isFalse);
      expect(isRowBindMarker(''), isFalse);
    });
  });

  test('WatchAttributes binds attributes outside a list, sanitized', () async {
    final html = await renderHtml(
      WatchAttributes({
        AttributeName.ariaOf(AriaAttribute.rowcount): shop.rowCount,
        AttributeName.href: shop.pageUrl,
      }, child: const Link(href: RouteUrl('#x'), child: Text('grid'))),
    );
    expect(html, contains('aria-rowcount="3"'));
    expect(
      html,
      contains(
        'data-tca="aria-rowcount:ShopState.rowCount;href:ShopState.pageUrl"',
      ),
    );
    expect(html, isNot(contains('href=')), reason: 'data: URL left out');
    expect(
      () => WatchAttributes({
        const AttributeName('onclick'): shop.label,
      }, child: const Text('x')).wrapData,
      throwsArgumentError,
    );
  });

  test(
    'WatchAttributes clientOnly leaves the first value to the engine',
    () async {
      // count is 2, so isEmpty is false; make it true to see the difference.
      final before = shop.count.value;
      shop.count.value = 0;
      addTearDown(() => shop.count.value = before);
      final server = await renderHtml(
        WatchAttributes(
          {AttributeName.disabled: shop.isEmpty},
          child: const FilledButton(
            buttonType: ButtonType.submit,
            child: Text('Go'),
          ),
        ),
      );
      expect(server, contains('data-tca="disabled:ShopState.isEmpty"'));
      expect(server, matches(RegExp(r'<button[^>]* disabled[ >]')));
      expect(server, isNot(contains('data-tcs')));
      final client = await renderHtml(
        WatchAttributes(
          {AttributeName.disabled: shop.isEmpty},
          clientOnly: {AttributeName.disabled},
          child: const FilledButton(
            buttonType: ButtonType.submit,
            child: Text('Go'),
          ),
        ),
      );
      expect(client, contains('data-tca="disabled:ShopState.isEmpty"'));
      expect(client, isNot(matches(RegExp(r'<button[^>]* disabled[ >]'))));
      // The marker that makes the lazy engine start the state at load.
      expect(client, contains('data-tcs'));
    },
  );

  test('AttributeName.open binds a details and an ExpansionTile', () async {
    final before = shop.count.value;
    shop.count.value = 0;
    addTearDown(() => shop.count.value = before);
    final tile = await renderHtml(
      ExpansionTile(
        expandedWatch: shop.isEmpty,
        title: const Text('T'),
        children: const [Text('x')],
      ),
    );
    expect(tile, matches(RegExp(r'<details[^>]* open[ >=]')));
    expect(tile, contains('data-tca="open:ShopState.isEmpty"'));
    shop.count.value = 2;
    final closed = await renderHtml(
      ExpansionTile(expandedWatch: shop.isEmpty, title: const Text('T')),
    );
    expect(closed, isNot(matches(RegExp(r'<details[^>]* open[ >=]'))));
    expect(closed, contains('data-tca="open:ShopState.isEmpty"'));
    final plain = await renderHtml(
      WatchAttributes({
        AttributeName.open: shop.isEmpty,
      }, child: const ExpansionTile(title: Text('T'))),
    );
    expect(plain, contains('data-tca="open:ShopState.isEmpty"'));
    expect(safeAttributeValue('open', 'true'), '');
    expect(safeAttributeValue('open', 'false'), isNull);
    expect(
      () => ExpansionTile(
        initiallyExpanded: true,
        expandedWatch: shop.isEmpty,
        title: const Text('T'),
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('ExpansionPanelList keeps each tile\'s expandedWatch', () async {
    final before = shop.count.value;
    shop.count.value = 0;
    addTearDown(() => shop.count.value = before);
    final html = await renderHtml(
      ExpansionPanelList(
        name: 'g',
        children: [
          ExpansionTile(
            expandedWatch: shop.isEmpty,
            hoverColor: const Color(0xFF00FF00),
            title: const Text('T'),
            children: const [Text('x')],
          ),
        ],
      ),
    );
    expect(html, matches(RegExp(r'<details[^>]* open[ >=]')));
    expect(html, contains('data-tca="open:ShopState.isEmpty"'));
    expect(html, contains('name="g"'));
  });

  test('isSafeUrl and safeAttributeValue', () {
    for (final ok in [
      'https://a.b/c',
      'http://x',
      '/path',
      'rel/x?y#z',
      '#id',
      '?q=1',
      '//cdn.example/x.png',
      'mailto:a@b.c',
      'tel:+52',
      'HTTPS://X',
      'a/b:c',
      'x?y=javascript:1',
      '1x:y',
    ]) {
      expect(isSafeUrl(ok), isTrue, reason: ok);
    }
    for (final bad in [
      'javascript:alert(1)',
      'JavaScript:x',
      ' javascript:x',
      'java\tscript:x',
      'java\nscript:x',
      '\u0001javascript:x',
      'data:text/html,x',
      'data:image/png;base64,AAAA',
      'vbscript:x',
      'file:///etc/passwd',
      'JAVASCRIPT:x',
      'java\u007fscript:x',
      'web+app:x',
    ]) {
      expect(isSafeUrl(bad), isFalse, reason: bad);
    }
    expect(safeAttributeValue('href', ''), isNull);
    expect(safeAttributeValue('href', 'javascript:x'), isNull);
    expect(safeAttributeValue('src', 'data:image/svg+xml,<svg>'), isNull);
    expect(safeAttributeValue('title', 'javascript:x'), 'javascript:x');
    expect(safeAttributeValue('alt', ''), '');
    expect(safeAttributeValue('onclick', 'x'), isNull);
    expect(isBindableAttribute('aria-rowindex'), isTrue);
    expect(isBindableAttribute('data-row'), isTrue);
    expect(isBindableAttribute('aria-'), isFalse);
    for (final bad in [
      '',
      'Href',
      '1a',
      'aria_x',
      'on-x',
      'onclick',
      'style',
    ]) {
      expect(isBindableAttribute(bad), isFalse, reason: bad);
    }
  });

  test('a conditional part: states with different structure', () async {
    final html = await renderHtml(
      Watch(
        shop.isEmpty,
        builder: (empty) => empty
            ? const SizedBox.shrink()
            : Column(children: [Watch(shop.label)]),
      ),
    );
    // Not empty now: the panel (with its nested text) is live, the empty
    // state waits in a template.
    expect(html, contains('data-tv="ShopState.isEmpty"'));
    expect(html, contains('data-tt="ShopState.label"'));
    expect(
      html,
      contains('<template data-tvt="ShopState.isEmpty" data-i="1">'),
    );
  });

  test('a closure as a Watch source is a clear build error', () async {
    // A build error fails the page (the route shows its error page): no
    // partial page, no message in the HTML.
    await expectLater(
      renderHtml(Watch(() => 'x')),
      throwsA(
        isA<ArgumentError>().having(
          (e) => '${e.message}',
          'message',
          contains('not a closure'),
        ),
      ),
    );
  });

  test('ThorApp ships the engine script and changed state, escaped', () async {
    shop.note.value = '</script><b>'; // same as the code: not shipped
    shop.count.value = 5;
    addTearDown(() => shop.count.value = 2);
    final page = await renderDocument(ThorApp(child: Watch(shop.label)));
    expect(headOfPage(page), contains('requestIdleCallback'));
    final json = RegExp(
      r'<script id="thor-state" type="application/json">(.*?)</script>',
    ).firstMatch(page)!.group(1)!;
    expect(json, isNot(contains('<')));
    expect(jsonDecode(json), {'ShopState.count': 5});
  });

  test('a page without ThorState ships no engine', () async {
    final page = await renderDocument(const ThorApp(child: Text('static')));
    expect(page, isNot(contains('requestIdleCallback')));
    expect(page, isNot(contains('thor-state')));
  });
}

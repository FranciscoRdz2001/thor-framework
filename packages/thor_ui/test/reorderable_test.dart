@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// The member list thor generates for [_Todo], by hand.
abstract class _TodoMembers extends ThorState {
  @override
  String get $type => 'Todo';

  @override
  List<ThorMember> get $members {
    final s = this as _Todo;
    return [
      ThorMember.state('items', s.items),
      ThorMember(
        'idOf',
        s.idOf,
        arity: 1,
        callWithItem: (i) => s.idOf(i as int),
      ),
      ThorMember(
        'reorder',
        s.reorder,
        arity: 3,
        call: (a) {
          final x = splitArgs(a, 3);
          return s.reorder(x[0], int.parse(x[1]), int.parse(x[2]));
        },
      ),
      ThorMember(
        'plain',
        s.plain,
        arity: 2,
        call: (a) {
          final x = splitArgs(a, 2);
          return s.plain(int.parse(x[0]), int.parse(x[1]));
        },
      ),
      ThorMember(
        'started',
        s.started,
        arity: 1,
        call: (a) => s.started(int.parse(a!)),
      ),
      ThorMember(
        'ended',
        s.ended,
        arity: 1,
        call: (a) => s.ended(int.parse(a!)),
      ),
    ];
  }
}

class _Todo extends _TodoMembers {
  final items = state<List<int>>(const [1, 2, 3]);
  int idOf(int n) => n;
  void reorder(String list, int oldIndex, int newIndex) {}
  void plain(int oldIndex, int newIndex) {}
  void started(int index) {}
  void ended(int index) {}
}

final _todo = _Todo();

Future<String> _page(Widget body) =>
    renderDocument(ThorApp(child: body)).then(headOfPage);

String _sheet(String page) =>
    RegExp(
      r'<style id="thor-styles">(.*?)</style>',
      dotAll: true,
    ).firstMatch(page)?[1] ??
    '';

Widget _tile(String text) => Container(key: ValueKey(text), child: Text(text));

void main() {
  initializeThorTests();

  test(
    'a list of items: each is a listitem with a handle, one root each',
    () async {
      final html = await renderHtml(
        ReorderableListView(
          onReorder: _todo.plain,
          children: [_tile('a'), _tile('b'), _tile('c')],
        ),
      );
      expect(html, contains('data-t-ro="reorder:Todo.plain"'));
      expect(html, contains('data-t-ro-cfg="v|1"'));
      expect(html, contains('role="list"'));
      expect(RegExp('data-t-ro-item').allMatches(html), hasLength(3));
      expect(RegExp('role="listitem"').allMatches(html), hasLength(3));
      // One default handle per item: a real button with a name.
      expect(RegExp('data-t-ro-h').allMatches(html), hasLength(3));
      expect(RegExp(r'<button[^>]*data-t-ro-h').allMatches(html), hasLength(3));
      expect(html, contains('aria-label="Reorder"'));
      expect(html, contains('aria-roledescription="drag handle"'));
      expect(html, contains('<svg'));
    },
  );

  test('onReorder, onReorderStart and onReorderEnd are state methods with '
      'the row\'s argument', () async {
    final html = await renderHtml(
      ReorderableListView(
        onReorder: _todo.reorder.withArg('today'),
        onReorderStart: _todo.started,
        onReorderEnd: _todo.ended,
        children: [_tile('a')],
      ),
    );
    expect(
      html,
      contains(
        'data-t-ro="reorder:Todo.reorder;start:Todo.started;end:Todo.ended"',
      ),
    );
    expect(html, contains('data-tx="today"'));
  });

  test(
    'without default handles there are none (a listener makes one)',
    () async {
      final html = await renderHtml(
        ReorderableListView(
          onReorder: _todo.plain,
          buildDefaultDragHandles: false,
          children: [
            const Row(
              key: ValueKey('r'),
              children: [
                Text('a'),
                ReorderableDragStartListener(
                  index: 0,
                  child: Icon(Icons.drag_handle),
                ),
                ReorderableDelayedDragStartListener(
                  index: 0,
                  child: Text('hold'),
                ),
              ],
            ),
          ],
        ),
      );
      expect(html, contains('data-t-ro-cfg="v|0"'));
      // The two listeners are the handles: one immediate, one that waits.
      expect(RegExp(r'data-t-ro-h(?!\w|-)').allMatches(html), hasLength(2));
      expect(html, contains('data-t-ro-h="delayed"'));
      expect(html, contains('tabindex="0"'));
      expect(html, contains('touch-action: none'));
      expect(html, contains('touch-action: manipulation'));
      expect(html, isNot(contains('<button')));
    },
  );

  test('header and footer are not items; the builder constructor builds '
      'itemCount items', () async {
    final html = await renderHtml(
      ReorderableListView.builder(
        onReorder: _todo.plain,
        itemCount: 4,
        header: const Text('top'),
        footer: const Text('bottom'),
        itemBuilder: (context, i) => _tile('item $i'),
      ),
    );
    expect(RegExp('data-t-ro-item').allMatches(html), hasLength(4));
    expect(html, contains('top'));
    expect(html, contains('bottom'));
    expect(html.indexOf('top'), lessThan(html.indexOf('item 0')));
    expect(html.indexOf('bottom'), greaterThan(html.indexOf('item 3')));
    // Outside the role="list" element, as its siblings.
    final open = html.indexOf('role="list"');
    expect(open, greaterThan(html.indexOf('top')));
    final listEnd = html.lastIndexOf('item 3');
    expect(html.indexOf('bottom'), greaterThan(listEnd));
    final list = RegExp(
      r'<div[^>]*role="list"[^>]*>([\s\S]*)</div>\s*<[^>]*>bottom',
    ).firstMatch(html);
    expect(list, isNotNull);
    expect(list![1], isNot(contains('>top<')));
    expect(list[1], isNot(contains('>bottom<')));
  });

  test('with a header the box around it scrolls and holds the padding, so '
      'the header scrolls with the items as in Flutter', () async {
    final html = await renderHtml(
      ReorderableListView(
        onReorder: _todo.plain,
        header: const Text('top'),
        padding: const EdgeInsets.all(8),
        children: [_tile('a')],
      ),
    );
    final outer = RegExp(r'^<div style="([^"]*)"').firstMatch(html)![1]!;
    expect(outer, contains('overflow: auto'));
    expect(outer, contains('padding: 8px'));
    final list = RegExp(
      r'<div style="([^"]*)" role="list"',
    ).firstMatch(html)![1]!;
    expect(list, isNot(contains('overflow')));
    expect(list, isNot(contains('padding')));
    expect(list, contains('flex: 0 0 auto'));
  });

  test('without header or footer the list is the only element', () async {
    final html = await renderHtml(
      ReorderableListView(onReorder: _todo.plain, children: [_tile('a')]),
    );
    expect(html, startsWith('<div'));
    expect(html, contains('role="list"'));
    expect(RegExp('role="list"').allMatches(html), hasLength(1));
    expect(
      html.indexOf('<div'),
      html.lastIndexOf('<div', html.indexOf('role="list"')),
    );
  });

  test('a horizontal list reorders along x', () async {
    final page = await _page(
      ReorderableListView(
        onReorder: _todo.plain,
        scrollDirection: Axis.horizontal,
        children: [_tile('a'), _tile('b')],
      ),
    );
    final css = _sheet(page);
    expect(css, contains('flex-direction: row'));
    final html = await renderHtml(
      ReorderableListView(
        onReorder: _todo.plain,
        scrollDirection: Axis.horizontal,
        children: [_tile('a')],
      ),
    );
    expect(html, contains('data-t-ro-cfg="h|1"'));
  });

  test('the CSS: variables, transitions of the items that give way, the '
      'dragged one lifted, reduced motion', () async {
    final page = await _page(
      ReorderableListView(
        onReorder: _todo.plain,
        children: [_tile('a'), _tile('b')],
      ),
    );
    final css = _sheet(page);
    expect(css, contains('translate: var(--t-ro-x, 0px) var(--t-ro-y, 0px)'));
    expect(css, contains('[data-t-ro-shift]'));
    expect(css, contains('[data-t-ro-settle]'));
    expect(css, contains('[data-t-ro-drag]'));
    expect(css, contains('box-shadow'));
    expect(css, contains('position: relative'));
    expect(
      page,
      contains(
        "@property --t-ro-x{syntax:'<length>';inherits:false;initial-value:0px}",
      ),
    );
    expect(page, contains('@property --t-ro-y{'));
    expect(
      RegExp(
        r'@media \(prefers-reduced-motion: ?reduce\)\{[^}]*transition-duration: ?1ms',
      ).hasMatch(css),
      isTrue,
      reason: css,
    );
    // The handle: the grab cursor, no scrolling under a finger on it.
    expect(css, contains('cursor: grab'));
    expect(css, contains('touch-action: none'));
    // A page without one has none of it.
    expect(await _page(const Text('x')), isNot(contains('--t-ro-x')));
  });

  test('draggingStyle takes the dragged item\'s look; proxyDecorator has no '
      'equivalent', () async {
    final css = _sheet(
      await _page(
        ReorderableListView(
          onReorder: _todo.plain,
          draggingStyle: const StyleProps(opacity: 0.8),
          children: [_tile('a')],
        ),
      ),
    );
    expect(css, contains('opacity: 0.8'));
    expect(
      () => renderHtml(
        ReorderableListView(
          onReorder: _todo.plain,
          proxyDecorator: (child, index, animation) => child,
          children: [_tile('a')],
        ),
      ),
      throwsA(predicate((e) => '$e'.contains('THOR-R040'))),
    );
  });

  test(
    'the labels are on the container only when they are not the defaults',
    () async {
      final plain = await renderHtml(
        ReorderableListView(onReorder: _todo.plain, children: [_tile('a')]),
      );
      expect(plain, isNot(contains('data-t-ro-say')));
      final es = await renderHtml(
        ReorderableListView(
          onReorder: _todo.plain,
          labels: const ReorderLabels(
            handle: 'Reordenar',
            pickedUp: 'Levantaste {item}, posición {position} de {count}',
          ),
          children: [_tile('a')],
        ),
      );
      expect(es, contains('data-t-ro-say="'));
      expect(es, contains('posición {position} de {count}'));
      expect(es, contains('aria-label="Reordenar"'));
    },
  );

  test('over a Watch.list: the row is the item (one root, its key kept), '
      'the template holds the same item and is not one', () async {
    _todo.items.value = [1, 2];
    final html = await renderHtml(
      ThorApp(
        child: Watch.list(
          _todo.items,
          itemKey: _todo.idOf,
          container: (rows) => ReorderableListView(
            onReorder: _todo.reorder.withArg('x'),
            children: rows,
          ),
          each: (row) =>
              Container(key: ValueKey(row.key), child: const Text('row')),
        ),
      ),
    );
    final body = html.substring(html.indexOf('<body'));
    // Two live rows, each with its key on the item, plus the template's item.
    expect(
      RegExp(
        r'<div[^>]*data-t-ro-item[^>]*data-tk="[12]"|<div[^>]*data-tk="[12]"[^>]*data-t-ro-item',
      ).allMatches(body),
      hasLength(2),
      reason: body,
    );
    expect(RegExp('data-t-ro-item').allMatches(body), hasLength(3));
    final template = RegExp(
      r'<template[^>]*data-tlt[^>]*>(.*?)</template>',
      dotAll: true,
    ).firstMatch(body)![1]!;
    expect(template, contains('data-t-ro-item'));
    expect(template, contains('data-t-ro-h'));
    expect(
      RegExp('<template').allMatches(body).length,
      greaterThanOrEqualTo(1),
    );
    // The list marker stays on the container the engine reconciles.
    expect(body, contains('data-tl="Todo.items"'));
    expect(body, contains('data-t-ro="reorder:Todo.reorder"'));
  });

  test('over a Watch.list with a header and a footer: the list marker is on '
      'the role="list" element, the rest of the wrappers on the box', () async {
    _todo.items.value = [1, 2];
    final html = await renderHtml(
      ThorApp(
        child: Watch.list(
          _todo.items,
          itemKey: _todo.idOf,
          container: (rows) => Semantics(
            identifier: 'todos',
            child: ReorderableListView(
              onReorder: _todo.reorder.withArg('x'),
              header: const Text('top'),
              footer: const Text('bottom'),
              children: rows,
            ),
          ),
          each: (row) =>
              Container(key: ValueKey(row.key), child: const Text('row')),
        ),
      ),
    );
    final body = html.substring(html.indexOf('<body'));
    final list = RegExp(r'<div[^>]*role="list"[^>]*>').firstMatch(body)![0]!;
    expect(list, contains('data-tl="Todo.items"'));
    expect(list, contains('data-tlk="Todo.idOf"'));
    expect(list, contains('data-t-ro='));
    expect(RegExp('data-tl=').allMatches(body), hasLength(1));
    // The box around the header, the list and the footer keeps the rest.
    final box = RegExp(r'<div[^>]*id="todos"[^>]*>').firstMatch(body)![0]!;
    expect(box, isNot(contains('role="list"')));
    expect(body.indexOf('id="todos"'), lessThan(body.indexOf('>top<')));
    expect(body.indexOf('>top<'), lessThan(body.indexOf('role="list"')));
  });

  test('keyboard shortcuts are named on the handle', () async {
    final html = await renderHtml(
      ReorderableListView(onReorder: _todo.plain, children: [_tile('a')]),
    );
    expect(
      html,
      contains('aria-keyshortcuts="Space Alt+ArrowUp Alt+ArrowDown"'),
    );
    final h = await renderHtml(
      ReorderableListView(
        onReorder: _todo.plain,
        scrollDirection: Axis.horizontal,
        children: [_tile('a')],
      ),
    );
    expect(
      h,
      contains('aria-keyshortcuts="Space Alt+ArrowLeft Alt+ArrowRight"'),
    );
  });
}

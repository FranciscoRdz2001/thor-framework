// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// The member list thor generates for [GridState], by hand (tests don't run the build).
abstract class _GridStateMembers extends ThorState {
  @override
  String get $type => 'GridState';

  @override
  List<ThorMember> get $members {
    final s = this as GridState;
    return [
      ThorMember.state('rows', s.rows),
      ThorMember.controller('scroll', s.scroll),
      ThorMember.controller('draft', s.draft),
      ThorMember.controller('focus', s.focus),
      ThorMember.controller('details', s.details),
      ThorMember('type', s.type, arity: 1, call: (a) => s.type(a!)),
      ThorMember('down', s.down, call: (_) => s.down()),
      ThorMember('go', s.go, arity: 1, call: (a) => s.go(int.parse(a!))),
      ThorMember('top', s.top, call: (_) => s.top()),
      ThorMember(
        'save',
        s.save,
        arity: 1,
        call: (_) => s.save(const SaveIntent()),
      ),
      ThorMember(
        'onKey',
        s.onKey,
        call: (a) => s.onKey(FocusNode(), KeyEvent.decode(a!)),
      ),
      ThorMember(
        'width',
        s.width,
        arity: 1,
        call: (a) => s.width(int.parse(a!)),
      ),
      ThorMember('mode', s.mode, call: (_) => s.mode(), variants: const [0, 1]),
      ThorMember('op', s.op, call: (_) => s.op(), variants: const [0, 1]),
      ThorMember(
        'rowKey',
        s.rowKey,
        arity: 1,
        callWithItem: (i) => s.rowKey(i! as int),
      ),
      ThorMember(
        'stars',
        s.stars,
        arity: 1,
        callWithItem: (i) => s.stars(i! as int),
      ),
    ];
  }
}

class GridState extends _GridStateMembers {
  final rows = state(const [1, 4]);
  final scroll = ScrollController();
  final draft = TextEditingController(text: 'hello');
  final focus = FocusNode();
  final details = DialogController();

  void type(String character) {}
  void down() {}
  void go(int row) {}
  double top() => 12.5;
  double width(int column) => 100.0 + column;
  int mode() => 0;
  int op() => 1;
  String rowKey(int r) => 'r$r';
  int stars(int r) => r;
  void save(SaveIntent intent) {}
  KeyEventResult onKey(FocusNode node, KeyEvent event) =>
      KeyEventResult.ignored;
}

class SaveIntent extends Intent {
  const SaveIntent();
}

class MoveIntent<T> extends Intent {
  const MoveIntent();
}

class _MyAction extends Action<SaveIntent> {}

final grid = GridState();

void main() {
  initializeThorTests();

  test('CallbackShortcuts marks the element with each activator', () async {
    final html = await renderHtml(
      CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): grid.down,
          const SingleActivator(
            LogicalKeyboardKey.keyZ,
            meta: true,
            shift: true,
          ): grid.go.withArg(
            3,
          ),
          const SingleActivator(LogicalKeyboardKey.enter): () {},
        },
        child: const Focus(child: SizedBox(width: 10)),
      ),
    );
    expect(
      html,
      contains(
        'data-tks="+arrowdown&gt;GridState.down;sm+z&gt;GridState.go~3"',
      ),
    );
    expect(html, contains('tabindex="0"'));
    expect(RegExp('<div').allMatches(html), hasLength(1), reason: 'no node');
  });

  test('CharacterActivator and onCharacter (last: bindings win)', () async {
    final html = await renderHtml(
      CallbackShortcuts(
        bindings: {const CharacterActivator('?'): grid.down},
        onCharacter: grid.type,
        child: const SizedBox(width: 10),
      ),
    );
    expect(
      html,
      contains('data-tks="=63&gt;GridState.down;*&gt;GridState.type"'),
    );
  });

  test('Shortcuts marks the element with each activator and intent', () async {
    final html = await renderHtml(
      const Shortcuts(
        shortcuts: {
          SingleActivator(LogicalKeyboardKey.keyS, meta: true): SaveIntent(),
          CharacterActivator('?'): MoveIntent<int>(),
        },
        child: Focus(child: SizedBox(width: 10)),
      ),
    );
    expect(
      html,
      contains('data-tsi="m+s&gt;SaveIntent;=63&gt;MoveIntent_int_"'),
    );
    expect(RegExp('<div').allMatches(html), hasLength(1), reason: 'no node');
  });

  test('Actions: a state method by intent type, DoNothingAction, and '
      'nested ones keep both sets (inner first)', () async {
    final html = await renderHtml(
      Actions(
        actions: {
          SaveIntent: const DoNothingAction(consumesKey: false),
          MoveIntent<int>: const DoNothingAction(),
        },
        child: Actions(
          actions: {
            SaveIntent: CallbackAction<SaveIntent>(onInvoke: grid.save),
            // A closure only exists on the server: nothing in the page.
            MoveIntent<int>: CallbackAction<MoveIntent<int>>(
              onInvoke: (_) => null,
            ),
          },
          child: const SizedBox(width: 10),
        ),
      ),
    );
    expect(
      html,
      contains(
        'data-tai="SaveIntent&gt;GridState.save;'
        'SaveIntent&gt;!;MoveIntent_int_&gt;"',
      ),
    );
  });

  test('Actions refuses an Action the page can not run', () async {
    expect(
      () => renderHtml(
        Actions(actions: {SaveIntent: _MyAction()}, child: const SizedBox()),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('Focus(onKeyEvent:) names the state method', () async {
    final html = await renderHtml(
      Focus(onKeyEvent: grid.onKey, child: const SizedBox(width: 10)),
    );
    expect(html, contains('data-tke="GridState.onKey"'));
    expect(html, contains('tabindex="0"'));
    expect(
      await renderHtml(
        Focus(
          onKeyEvent: (_, _) => KeyEventResult.handled,
          child: const SizedBox(),
        ),
      ),
      isNot(contains('data-tke')),
    );
  });

  test('a DialogController marks its dialog', () async {
    for (final w in [
      Drawer(id: 'd', controller: grid.details, child: const SizedBox()),
      AlertDialog(id: 'a', controller: grid.details),
      ModalBottomSheet(
        id: 'm',
        controller: grid.details,
        child: const SizedBox(),
      ),
    ]) {
      final html = await renderHtml(w);
      expect(html, contains('data-tdc="GridState.details"'));
      expect(html, contains('<dialog'));
    }
    expect(
      await renderHtml(const Drawer(id: 'd', child: SizedBox())),
      isNot(contains('data-tdc')),
    );
  });

  test('nested shortcuts keep both sets (inner first)', () async {
    final html = await renderHtml(
      CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): grid.down},
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.enter): grid.go.withArg(1),
          },
          child: const SizedBox(width: 10),
        ),
      ),
    );
    expect(
      html,
      contains('data-tks="+enter&gt;GridState.go~1;+escape&gt;GridState.down"'),
    );
  });

  test('Focus: node, traversal and autofocus', () async {
    final html = await renderHtml(
      Focus(
        focusNode: grid.focus,
        skipTraversal: true,
        autofocus: true,
        child: const SizedBox(width: 10),
      ),
    );
    expect(html, contains('tabindex="-1"'));
    expect(html, contains('autofocus'));
    expect(html, contains('data-tfn="GridState.focus"'));
    // A node that no state holds only exists on the server.
    expect(
      await renderHtml(Focus(focusNode: FocusNode(), child: const SizedBox())),
      isNot(contains('data-tfn')),
    );
  });

  test('controllers mark their scroll view and fields', () async {
    final html = await renderHtml(
      Column(
        children: [
          SingleChildScrollView(
            controller: grid.scroll,
            child: const SizedBox(height: 10),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: grid.scroll,
            child: const SizedBox(width: 10),
          ),
          TextField(controller: grid.draft, focusNode: grid.focus),
          TextField(controller: grid.draft, maxLines: 3),
        ],
      ),
    );
    expect(
      RegExp('data-tsc="GridState.scroll"').allMatches(html),
      hasLength(2),
    );
    expect(RegExp('data-tsc-h').allMatches(html), hasLength(1));
    expect(html, contains('value="hello"'), reason: 'the controller text');
    expect(html, contains('>hello</textarea>'));
    expect(RegExp('data-ttc="GridState.draft"').allMatches(html), hasLength(2));
    expect(html, contains('data-tfn="GridState.focus"'));
  });

  test(
    'WatchVariables: first values in style, bindings in the marker',
    () async {
      final html = await renderHtml(
        WatchVariables({
          const CssVariable('--top'): grid.top,
          const CssVariable('--w2'): grid.width.withArg(2),
        }, child: const SizedBox(width: 10)),
      );
      expect(
        html,
        contains('data-tcv="--top:GridState.top;--w2:GridState.width~2"'),
      );
      expect(html, contains('--top: 12.5px; --w2: 102px'));
      expect(
        () => renderHtml(
          WatchVariables({
            const CssVariable('color'): grid.top,
          }, child: const SizedBox()),
        ),
        throwsArgumentError,
      );
      expect(
        () => renderHtml(
          WatchVariables({
            const CssVariable('--x'): () => 1,
          }, child: const SizedBox()),
        ),
        throwsArgumentError,
        reason: 'a closure has no id in the page',
      );
    },
  );

  test('row.watch with an int state and count', () async {
    final html = await renderHtml(
      Watch.list(
        grid.rows,
        itemKey: grid.rowKey,
        each: (row) => row.watch(
          grid.stars,
          count: 6,
          builder: (int n) => Text('$n stars'),
        ),
      ),
    );
    expect(html, contains('data-tvi="4"'));
    expect(html, contains('4 stars'));
    // The row template carries the other five states, as patches of its
    // element (same structure: only the text differs).
    final template = html.substring(html.indexOf('<template data-tlt='));
    expect(RegExp(r'data-tp-\d="').allMatches(template), hasLength(5));
    expect(template, contains('data-tp-5="|#|=5 stars"'));
    expect(template, isNot(contains('data-tvft')));
  });

  test('a Watch built by a Watch gets its own element', () async {
    final html = await renderHtml(
      Watch(
        grid.mode,
        count: 2,
        builder: (int m) =>
            Watch(grid.op, count: 2, builder: (int o) => Text('m$m o$o')),
      ),
    );
    final outer = RegExp(
      r'<div style="display: contents" data-tv="GridState.mode">',
    );
    expect(outer.hasMatch(html), isTrue);
    expect(html, contains('data-tv="GridState.op"'));
  });

  test('a state of several elements (a menu: trigger and popover) is '
      'swapped as one box', () async {
    final html = await renderHtml(
      Watch(
        grid.mode,
        count: 2,
        builder: (int m) => PopupMenuButton(
          id: 'menu',
          onSelected: grid.type,
          items: const [PopupMenuItem(value: 'a', child: Text('A'))],
          child: Text('m$m'),
        ),
      ),
    );
    // The box carries the states; the trigger and the popover follow it.
    final box = html.indexOf(
      '<div style="display: contents" data-tv="GridState.mode"',
    );
    expect(box, isNonNegative);
    final trigger = html.indexOf('popovertarget="menu"');
    final menu = html.indexOf('id="menu"');
    expect(trigger, greaterThan(box));
    expect(menu, greaterThan(trigger));
  });
}

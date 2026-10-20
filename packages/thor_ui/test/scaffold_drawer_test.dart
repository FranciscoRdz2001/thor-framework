@TestOn('vm')
library;

// Scaffold(drawer:, endDrawer:) with the AppBar's implicit DrawerButton,
// optional ids of the native dialogs and popovers, and DialogClose()
// without an id: all plain markup, nothing for the client to make.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// The member list thor generates for [SheetState], by hand.
abstract class _SheetMembers extends ThorState {
  @override
  String get $type => 'SheetState';

  @override
  List<ThorMember> get $members {
    final s = this as SheetState;
    return [
      ThorMember.controller('confirm', s.confirm),
      ThorMember.controller('other', s.other),
    ];
  }
}

class SheetState extends _SheetMembers {
  final confirm = DialogController();
  final other = DialogController();
}

final sheet = SheetState();

Future<String> _html(Widget w) => renderHtml(ThorApp(child: w));

/// The value of [attr] in every tag that has it.
List<String> _attr(String html, String attr) => [
  for (final m in RegExp('$attr="([^"]*)"').allMatches(html)) m[1]!,
];

/// The `<dialog …>` opening tags of the page.
List<String> _dialogs(String html) => [
  for (final m in RegExp('<dialog[^>]*>').allMatches(html)) m[0]!,
];

String _idOf(String tag) => RegExp(' id="([^"]*)"').firstMatch(tag)![1]!;

/// The `<button …>` tags whose `commandfor` is [id].
List<String> _buttonsFor(String html, String id) => [
  for (final m in RegExp('<button[^>]*>').allMatches(html))
    if (m[0]!.contains('commandfor="$id"')) m[0]!,
];

Widget _scaffold({
  Widget? drawer,
  Widget? endDrawer,
  AppBar? appBar,
  Widget? body,
}) => Scaffold(
  appBar: appBar ?? const AppBar(title: Text('Home')),
  drawer: drawer,
  endDrawer: endDrawer,
  body: body ?? const Text('body'),
);

void main() {
  setUpAll(initializeThorTests);

  group('Scaffold drawer', () {
    test('the AppBar gets a DrawerButton that opens the drawer', () async {
      final html = await _html(
        _scaffold(drawer: const Drawer(child: Text('menu'))),
      );
      final dialogs = _dialogs(html);
      expect(dialogs, hasLength(1));
      final id = _idOf(dialogs.single);
      final buttons = _buttonsFor(html, id);
      expect(buttons, hasLength(1));
      expect(buttons.single, contains('command="show-modal"'));
      expect(buttons.single, contains('aria-label="Open navigation menu"'));
      // It sits in the header, before the title.
      final header = html.substring(
        html.indexOf('<header'),
        html.indexOf('</header>'),
      );
      expect(header, contains('commandfor="$id"'));
      expect(header.indexOf('commandfor'), lessThan(header.indexOf('Home')));
    });

    test('an explicit Drawer id is the one the button points at', () async {
      final html = await _html(
        _scaffold(
          drawer: const Drawer(id: 'menu', child: Text('m')),
        ),
      );
      expect(_buttonsFor(html, 'menu'), hasLength(1));
      expect(_dialogs(html).single, contains('id="menu"'));
    });

    test('through an app component that builds the Drawer', () async {
      final html = await _html(_scaffold(drawer: const _AppDrawer()));
      final id = _idOf(_dialogs(html).single);
      expect(id, isNotEmpty);
      expect(_buttonsFor(html, id), hasLength(1));
    });

    test('drawer and endDrawer: two ids, two buttons, each side', () async {
      final html = await _html(
        _scaffold(
          drawer: const Drawer(child: Text('a')),
          endDrawer: const Drawer(child: Text('b')),
        ),
      );
      final ids = _dialogs(html).map(_idOf).toList();
      expect(ids, hasLength(2));
      expect(ids.toSet(), hasLength(2));
      for (final id in ids) {
        expect(_buttonsFor(html, id), hasLength(1), reason: id);
      }
      // The start button leads the bar, the end one closes it.
      final header = html.substring(
        html.indexOf('<header'),
        html.indexOf('</header>'),
      );
      expect(
        header.indexOf('commandfor="${ids[0]}"'),
        lessThan(header.indexOf('Home')),
      );
      expect(
        header.indexOf('commandfor="${ids[1]}"'),
        greaterThan(header.indexOf('Home')),
      );
      // The end drawer slides from the end (a class rule of its own).
      final doc = await renderDocument(
        ThorApp(
          child: _scaffold(endDrawer: const Drawer(child: Text('b'))),
        ),
      );
      expect(doc, contains('margin-inline: auto 0'));
    });

    test('only an endDrawer: the button goes in the actions', () async {
      final html = await _html(
        _scaffold(endDrawer: const Drawer(child: Text('b'))),
      );
      final id = _idOf(_dialogs(html).single);
      final header = html.substring(
        html.indexOf('<header'),
        html.indexOf('</header>'),
      );
      expect(
        header.indexOf('commandfor="$id"'),
        greaterThan(header.indexOf('Home')),
      );
      expect(_attr(header, 'aria-label'), ['Open secondary menu']);
    });

    test('automaticallyImplyLeading: false, or a leading, adds none', () async {
      const drawer = Drawer(id: 'menu', child: Text('m'));
      var html = await _html(
        _scaffold(
          drawer: drawer,
          appBar: const AppBar(
            automaticallyImplyLeading: false,
            title: Text('Home'),
          ),
        ),
      );
      expect(_buttonsFor(html, 'menu'), isEmpty);
      html = await _html(
        _scaffold(
          drawer: drawer,
          appBar: const AppBar(leading: Text('mine'), title: Text('Home')),
        ),
      );
      expect(_buttonsFor(html, 'menu'), isEmpty);
      expect(html, contains('mine'));
    });

    test(
      'automaticallyImplyActions: false leaves the end button out',
      () async {
        final html = await _html(
          _scaffold(
            endDrawer: const Drawer(id: 'end', child: Text('b')),
            appBar: const AppBar(
              automaticallyImplyActions: false,
              title: Text('Home'),
            ),
          ),
        );
        expect(_buttonsFor(html, 'end'), isEmpty);
      },
    );

    test('actions given: the end button is not added (like Flutter)', () async {
      final html = await _html(
        _scaffold(
          endDrawer: const Drawer(id: 'end', child: Text('b')),
          appBar: AppBar(
            title: const Text('Home'),
            actions: [IconButton(icon: const Text('x'), onPressed: () {})],
          ),
        ),
      );
      expect(_buttonsFor(html, 'end'), isEmpty);
    });

    test('no drawer, no button; an AppBar outside a Scaffold, none', () async {
      var html = await _html(_scaffold());
      expect(html, isNot(contains('commandfor')));
      html = await _html(const AppBar(title: Text('Home')));
      expect(html, isNot(contains('commandfor')));
    });

    test('two scaffolds on a page keep their own drawers apart', () async {
      final html = await _html(
        Column(
          children: [
            _scaffold(drawer: const Drawer(child: Text('one'))),
            _scaffold(drawer: const Drawer(child: Text('two'))),
          ],
        ),
      );
      final ids = _dialogs(html).map(_idOf).toList();
      expect(ids.toSet(), hasLength(2));
      for (final id in ids) {
        expect(_buttonsFor(html, id), hasLength(1), reason: id);
      }
    });

    test('a Drawer outside a Scaffold still needs no id', () async {
      final html = await _html(const Drawer(child: Text('x')));
      expect(_idOf(_dialogs(html).single), isNotEmpty);
    });

    test('a Drawer inside the drawer of a Scaffold gets its own id', () async {
      final html = await _html(
        _scaffold(
          drawer: const Drawer(child: Drawer(child: Text('inner'))),
        ),
      );
      final ids = _dialogs(html).map(_idOf).toList();
      expect(ids.toSet(), hasLength(2));
    });

    test('ids are the same on every render of the page', () async {
      Widget page() => _scaffold(
        drawer: const Drawer(child: Text('a')),
        endDrawer: const Drawer(child: Text('b')),
      );
      expect(await _html(page()), await _html(page()));
    });

    test('the DrawerButton is public: any place inside the Scaffold', () async {
      final html = await _html(
        const Scaffold(
          drawer: Drawer(id: 'menu', child: Text('m')),
          body: Center(child: DrawerButton()),
        ),
      );
      expect(_buttonsFor(html, 'menu'), hasLength(1));
    });

    test('a DrawerButton outside a Scaffold says what is missing', () async {
      await expectLater(
        _html(const DrawerButton()),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('DrawerButton'), contains('Scaffold(drawer:')),
          ),
        ),
      );
    });

    test('a Scaffold whose drawer is not a Drawer says so', () async {
      await expectLater(
        _html(_scaffold(drawer: const Text('not a drawer'))),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Drawer'),
          ),
        ),
      );
    });
  });

  group('optional ids', () {
    test(
      'each native panel gets an id of its own when none is given',
      () async {
        final widgets = <Widget>[
          const AlertDialog(title: Text('t')),
          const Dialog(child: Text('d')),
          const Drawer(child: Text('r')),
          const ModalBottomSheet(child: Text('s')),
        ];
        for (final w in widgets) {
          final id = _idOf(_dialogs(await _html(w)).single);
          expect(id, matches(RegExp(r'^[A-Za-z][\w-]*$')), reason: id);
        }
      },
    );

    test('an AlertDialog names its title from its own id', () async {
      final html = await _html(const AlertDialog(title: Text('Sure?')));
      final id = _idOf(_dialogs(html).single);
      expect(html, contains('aria-labelledby="$id-title"'));
      expect(html, contains('id="$id-title"'));
    });

    test('many dialogs on a page never share an id', () async {
      final html = await _html(
        Column(
          children: [
            for (var i = 0; i < 60; i++) AlertDialog(title: Text('n$i')),
            for (var i = 0; i < 20; i++) Dialog(child: Text('d$i')),
            for (var i = 0; i < 20; i++) const Drawer(child: Text('x')),
          ],
        ),
      );
      final ids = _attr(html, ' id');
      final all = _dialogs(html).map(_idOf).toList();
      expect(all, hasLength(100));
      expect(all.toSet(), hasLength(100));
      expect(ids.toSet().length, ids.length, reason: 'no DOM id repeats');
    });

    test('a render twice gives the same ids', () async {
      Widget page() => const Column(
        children: [
          AlertDialog(title: Text('a')),
          Popover(trigger: Text('p'), child: Text('c')),
          PopupMenuButton(
            items: [PopupMenuItem(value: 'a', child: Text('A'))],
            child: Text('m'),
          ),
        ],
      );
      expect(await _html(page()), await _html(page()));
    });

    test('an explicit id still wins, and is used as given', () async {
      final html = await _html(
        const AlertDialog(id: 'confirm', title: Text('t')),
      );
      expect(_idOf(_dialogs(html).single), 'confirm');
      expect(html, contains('aria-labelledby="confirm-title"'));
    });

    test('a ValueKey names the dialog: inside a list, per item', () async {
      Widget list(List<int> ids) => Column(
        children: [
          for (final id in ids)
            AlertDialog(key: ValueKey(id), title: Text('order $id')),
        ],
      );
      final a = _dialogs(await _html(list([1, 2, 3]))).map(_idOf).toList();
      final b = _dialogs(await _html(list([3, 1]))).map(_idOf).toList();
      expect(a.toSet(), hasLength(3));
      // Order 3 and order 1 keep their ids when the list changes.
      expect(b, [a[2], a[0]]);
    });

    test('the same key twice on a page still gives two ids', () async {
      final html = await _html(
        const Column(
          children: [
            AlertDialog(key: ValueKey('a'), title: Text('1')),
            AlertDialog(key: ValueKey('a'), title: Text('2')),
          ],
        ),
      );
      final ids = _dialogs(html).map(_idOf).toList();
      expect(ids.toSet(), hasLength(2));
    });

    test('a key with odd characters gives a plain identifier', () async {
      final html = await _html(
        const AlertDialog(key: ValueKey('a b/c"<x>'), title: Text('t')),
      );
      expect(_idOf(_dialogs(html).single), matches(RegExp(r'^[\w-]+$')));
    });

    test('a controller names the dialog and the trigger finds it', () async {
      final html = await _html(
        Column(
          children: [
            DialogTrigger(
              controller: sheet.confirm,
              child: FilledButton(onPressed: () {}, child: const Text('Open')),
            ),
            AlertDialog(controller: sheet.confirm, title: const Text('t')),
            AlertDialog(controller: sheet.other, title: const Text('u')),
          ],
        ),
      );
      final ids = _dialogs(html).map(_idOf).toList();
      expect(ids.toSet(), hasLength(2));
      expect(_buttonsFor(html, ids[0]), hasLength(1));
      expect(_buttonsFor(html, ids[1]), isEmpty);
      expect(html, contains('data-tdc="SheetState.confirm"'));
    });

    test('a DialogTrigger needs an id or a controller', () {
      expect(
        () => DialogTrigger(child: const Text('x')),
        throwsA(isA<AssertionError>()),
      );
    });

    test(
      'Popover and PopupMenuButton link trigger and panel by themselves',
      () async {
        final html = await _html(
          const Column(
            children: [
              Popover(trigger: Text('p'), child: Text('c')),
              PopupMenuButton(
                items: [PopupMenuItem(value: 'a', child: Text('A'))],
                child: Text('m'),
              ),
              Popover(trigger: Text('q'), child: Text('d')),
            ],
          ),
        );
        // The menu's items point at it too (`popovertargetaction="hide"`).
        final targets = _attr(html, 'popovertarget').toSet();
        expect(targets, hasLength(3));
        for (final t in targets) {
          expect(html, contains('id="$t"'), reason: t);
        }
      },
    );

    test('DefaultTabController without id: radios and panels agree', () async {
      final html = await _html(
        const DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  Tab(text: 'A'),
                  Tab(text: 'B'),
                ],
              ),
              TabBarView(children: [Text('a'), Text('b')]),
            ],
          ),
        ),
      );
      final names = _attr(html, 'name').toSet();
      expect(names, hasLength(1));
      final name = names.single;
      expect(html, contains('id="$name-panel-0"'));
      expect(html, contains('aria-controls="$name-panel-1"'));
    });

    test('two DefaultTabControllers on a page do not share a group', () async {
      Widget tabs() => const DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              tabs: [
                Tab(text: 'A'),
                Tab(text: 'B'),
              ],
            ),
            TabBarView(children: [Text('a'), Text('b')]),
          ],
        ),
      );
      final html = await _html(Column(children: [tabs(), tabs()]));
      expect(_attr(html, 'name').toSet(), hasLength(2));
    });

    test('DatePickerDialog and TimePickerDialog take no id either', () async {
      final html = await _html(
        Column(
          children: [
            DatePickerDialog(
              firstDate: DateTime(2026),
              lastDate: DateTime(2027),
            ),
            const TimePickerDialog(initialTime: TimeOfDay(hour: 9, minute: 0)),
          ],
        ),
      );
      final ids = _dialogs(html).map(_idOf).toList();
      expect(ids, hasLength(2));
      expect(ids.toSet(), hasLength(2));
    });
  });

  group('DialogClose()', () {
    test('closes the nearest dialog above it, by its id', () async {
      final html = await _html(
        Column(
          children: [
            AlertDialog(
              title: const Text('one'),
              actions: [
                DialogClose(
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Cancel one'),
                  ),
                ),
              ],
            ),
            AlertDialog(
              title: const Text('two'),
              actions: [
                DialogClose(
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Cancel two'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      final ids = _dialogs(html).map(_idOf).toList();
      for (final (i, id) in ids.indexed) {
        final buttons = _buttonsFor(html, id);
        expect(buttons, hasLength(1), reason: id);
        expect(buttons.single, contains('command="close"'));
        // The button lives inside its own dialog.
        final from = html.indexOf('id="$id"');
        final to = html.indexOf('</dialog>', from);
        expect(
          html.substring(from, to),
          contains(buttons.single),
          reason: '$i',
        );
      }
    });

    test('works in a Drawer, a sheet and a Dialog', () async {
      for (final w in <Widget>[
        Drawer(
          child: DialogClose(
            child: TextButton(onPressed: () {}, child: const Text('x')),
          ),
        ),
        ModalBottomSheet(
          child: DialogClose(
            child: TextButton(onPressed: () {}, child: const Text('x')),
          ),
        ),
        Dialog(
          child: DialogClose(
            child: TextButton(onPressed: () {}, child: const Text('x')),
          ),
        ),
      ]) {
        final html = await _html(w);
        final id = _idOf(_dialogs(html).single);
        expect(_buttonsFor(html, id), hasLength(1), reason: '$w');
      }
    });

    test('the nearest wins when dialogs nest', () async {
      final html = await _html(
        Dialog(
          id: 'outer',
          child: Dialog(
            id: 'inner',
            child: DialogClose(
              child: TextButton(onPressed: () {}, child: const Text('x')),
            ),
          ),
        ),
      );
      expect(_buttonsFor(html, 'inner'), hasLength(1));
      expect(_buttonsFor(html, 'outer'), isEmpty);
    });

    test('an explicit id still closes that dialog', () async {
      final html = await _html(
        Dialog(
          id: 'a',
          child: DialogClose(
            id: 'elsewhere',
            child: TextButton(onPressed: () {}, child: const Text('x')),
          ),
        ),
      );
      expect(_buttonsFor(html, 'elsewhere'), hasLength(1));
    });

    test('outside a dialog it says so instead of doing nothing', () async {
      await expectLater(
        _html(
          DialogClose(
            child: TextButton(onPressed: () {}, child: const Text('x')),
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('DialogClose'), contains('Pass id:')),
          ),
        ),
      );
    });
  });
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) => const Drawer(child: Text('app'));
}

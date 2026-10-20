import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_builder/src/app_entries.dart';

import 'support.dart';

const _shop = r'''
import 'package:thor_ui/thor_ui.dart';

enum Tab { home, cart }

class Line {
  const Line(this.id);
  final int id;
}

class _Row {
  const _Row(this.id);
  final int id;
}

class SaveIntent extends Intent {
  const SaveIntent();
}

class MoveIntent extends Intent {
  const MoveIntent(this.by);
  final int by;
}

class ShopState extends ThorState {
  ShopState({super.key});

  final count = state(0);
  final lines = state(const <Line>[]);
  final scroll = ScrollController();
  int plain = 0;
  final _secret = state(1);
  final open = state(false);
  final tab2 = state(Tab.home);
  final label2 = state('');
  final orNull = state<bool?>(null);
  final orNullTab = state<Tab?>(null);

  String label() => '${count.value}';
  bool isZero() => count.value == 0;
  Tab tab() => Tab.home;
  bool isLine(int id) => true;
  void inc() => count.value++;
  void add(int n) => count.value += n;
  void pick(Tab t) {}
  void picks(Set<Tab> t) {}
  void tapped(TapDownDetails d) {}
  void at(DateTime day) {}
  void clock(TimeOfDay t) {}
  void maybe(int? n) {}
  String lineName(Line l) => '${l.id}';
  String rowName(_Row r) => '${r.id}';
  String cell(int column, Line line) => '$column${line.id}';
  void move(int id, double dx, double dy) {}
  void save(SaveIntent intent) {}
  void moveBy(MoveIntent intent) {}
  KeyEventResult onKey(FocusNode node, KeyEvent event) =>
      KeyEventResult.ignored;
  void _hidden() {}
  @override
  void onHydrated() {}
  @override
  void dispose() {}
  void tooMany(int a, int b, int c, int d) {}
  void named({int n = 0}) {}
}

// Two states in one file.
class OtherState extends ThorState {
  final on = state(false);
  void flip() => on.value = !on.value;
}

final shop = ShopState();
final other = OtherState();
''';

/// The state classes of [sources]' `lib/shop.dart`, with the registry
/// thor writes for them.
Future<(String, List<String>, List<EntryProblem>)> _registry(
  Map<String, String> sources,
) => resolveSources(
  sources,
  (resolver) async {
    final lib = await resolver.libraryFor(AssetId.parse('app|lib/shop.dart'));
    final warnings = <String>[];
    final problems = <EntryProblem>[];
    final code = statesLibrary(
      [
        for (final c in lib.classes)
          if (isRegisteredState(c)) (c, 'lib/shop.dart'),
      ],
      warn: warnings.add,
      problems: problems,
    );
    return (code, warnings, problems);
  },
  rootPackage: 'app',
  readAllSourcesFromFilesystem: true,
);

/// A Flutter-style counter with `setState` in the button.
const _flutterStyle = r'''
import 'package:thor_ui/thor_ui.dart';

class Clicks extends StatefulWidget {
  const Clicks({super.key});

  @override
  State<Clicks> createState() => _ClicksState();
}

class _ClicksState extends State<Clicks> {
  int n = 0;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: () => setState(() => n++),
    child: Text('$n'),
  );
}

class Fade extends StatelessWidget {
  const Fade({super.key});

  @override
  Widget build(BuildContext context) => const AnimatedSwitcher(
    duration: Duration(milliseconds: 200),
    child: Text('hola'),
  );
}
''';

/// A state read while the server draws the page.
const _frozen = r'''
import 'package:thor_ui/thor_ui.dart';

class CounterState extends ThorState {
  final count = state(0);
  String label() => '${count.value}';
}

final counter = CounterState();

class Card extends StatelessWidget {
  const Card({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('${counter.count.value}'),
      Watch(counter.label),
    ],
  );
}
''';

/// A state method called with the row key in a list row's builder.
const _rowKey = r'''
import 'package:thor_ui/thor_ui.dart';

class Todo {
  const Todo(this.id, this.title);
  final String id;
  final String title;
}

class TodoState extends ThorState {
  final todos = state(const <Todo>[]);
  String idOf(Todo t) => t.id;
  String titleOf(Todo t) => t.title;
  String titleById(String id) => id;
  void setDone(String id, bool? on) {}
}

final todo = TodoState();

class Rows extends StatelessWidget {
  const Rows({super.key});

  @override
  Widget build(BuildContext context) => Watch.list(
    todo.todos.call,
    itemKey: todo.idOf,
    each: (row) => Checkbox(
      value: false,
      semanticLabel: todo.titleById(row.key),
      onChanged: todo.setDone.withArg(row.key),
    ),
  );
}
''';

/// What the entries step warns about for [source] as `lib/counter.dart`.
Future<List<String>> _warnings(String source) => resolveSources(
  {'app|lib/counter.dart': source},
  (resolver) async {
    final lib = await resolver.libraryFor(
      AssetId.parse('app|lib/counter.dart'),
    );
    final result =
        await lib.session.getResolvedUnit(lib.firstFragment.source.fullName)
            as ResolvedUnitResult;
    return stateWarnings(result.unit, 'lib/counter.dart');
  },
  rootPackage: 'app',
  readAllSourcesFromFilesystem: true,
);

/// A state member called with a multi-line string while the server draws.
const _multiline = r'''
import 'package:thor_ui/thor_ui.dart';

class CounterState extends ThorState {
  final count = state(0);
  String tag(String s) => '$s${count.value}';
}

final counter = CounterState();

class Card extends StatelessWidget {
  const Card({super.key});

  @override
  Widget build(BuildContext context) => Text(counter.tag("""a
b"""));
}
''';

void main() {
  _modelTests();
  _feedbackTests();
  _disposesTests();
  group('silent failures', () {
    test('a warning is one line even when its code spans several', () async {
      final found = await _warnings(_multiline);
      expect(found, hasLength(1), reason: found.join('\n'));
      expect(found.single, isNot(contains('\n')));
      expect(found.single, contains('THOR-S015'));
    });

    test('a state method called with the row key is a warning (THOR-S034), '
        'and binding it is not', () async {
      expect(await _misuses(_rowKey), isEmpty);
      final found = await _warnings(_rowKey);
      expect(found, hasLength(1), reason: found.join('\n'));
      expect(
        found.single,
        allOf(
          matches(RegExp(r'^lib/counter.dart:\d+:\d+: Warning: ')),
          contains('todo.titleById(row.key)'),
          contains('THOR-S034'),
          contains('row.bind(state.titleOf)'),
        ),
      );
      final fixed = _rowKey.replaceFirst(
        'todo.titleById(row.key)',
        'row.bind(todo.titleOf)',
      );
      expect(await _warnings(fixed), isEmpty);
    });

    test('a frozen read is a warning, not an error', () async {
      expect(await _misuses(_frozen), isEmpty);
      final found = await _warnings(_frozen);
      expect(found, hasLength(1), reason: found.join('\n'));
      expect(
        found.single,
        allOf(
          matches(RegExp(r'^lib/counter.dart:\d+:\d+: Warning: ')),
          contains('counter.count.value'),
          contains('THOR-S015'),
          contains('Watch'),
        ),
      );
      final fixed = _frozen.replaceFirst(
        "Text('\${counter.count.value}'),",
        'Watch(counter.label),',
      );
      expect(await _warnings(fixed), isEmpty);
    });

    test('setState fails, with its file, line, code and fix', () async {
      final found = await _misuses(_flutterStyle);
      expect(found, hasLength(2), reason: found.join('\n'));
      expect(found.last, allOf(contains('THOR-S016'), contains('Watch')));
      expect(
        found.first,
        allOf(
          matches(RegExp(r'^lib/counter.dart:\d+:\d+: Error: ')),
          contains('THOR-S014'),
          contains('ThorState'),
        ),
      );
    });

    test('the fixed code has none', () async {
      final fixed = _flutterStyle
          .replaceFirst('() => setState(() => n++)', 'null')
          .replaceFirst('const AnimatedSwitcher(', 'const Padding(')
          .replaceFirst('    duration: Duration(milliseconds: 200),\n', '');
      expect(await _misuses(fixed), isEmpty);
    });

    test('a file that only mentions setState is resolved', () {
      expect(mayFailSilently('onPressed: () => setState(() {})'), isTrue);
      expect(mayFailSilently('const AnimatedSwitcher('), isTrue);
      expect(mayFailSilently('Text(label)'), isFalse);
    });
  });

  group('state misuses', () {
    test('lists each with its file, line and fix', () async {
      final found = await _misuses(_counter);
      expect(found, hasLength(4), reason: found.join('\n'));
      expect(found[0], startsWith('lib/counter.dart:15:24: Error: '));
      expect(found[0], contains('THOR-S012'));
      expect(found[1], startsWith('lib/counter.dart:20:13: Error: '));
      expect(found[1], contains('THOR-S001'));
      expect(found[2], contains('THOR-S011'));
      expect(found[2], contains('Pass `counter.increment`.'));
      expect(found[3], contains('Pass `counter.add.withArg(5)`.'));
    });

    test('a correct app has none', () async {
      final fixed = _counter
          .replaceFirst('  final counterState = CounterState();\n', '')
          .replaceFirst('() => counter.count.value', 'counter.label')
          .replaceFirst(
            RegExp(r'\(\) \{\s*counter\.increment\(\);\s*\}'),
            'counter.increment',
          )
          .replaceFirst('() => counter.add(5)', 'counter.add.withArg(5)');
      expect(await _misuses(fixed), isEmpty);
    });

    test('a file that names no state is not resolved', () {
      expect(mayUseStates('Text(label)', {'CounterState', 'counter'}), false);
      expect(mayUseStates('counter.increment', {'counter'}), isTrue);
      expect(mayUseStates('encounter.x', {'counter'}), isFalse);
    });
  });

  test('a state registers the fields and methods of its mixins', () async {
    final (code, _, problems) = await _registry({
      'app|lib/shop.dart': r'''
import 'package:thor_ui/thor_ui.dart';

mixin Counting on ThorState {
  final count = state(0);
  void inc() => count.value++;
  String label() => '${count.value}';
}

class MixedState extends ThorState with Counting {
  final own = state(false);
  void flip() => own.value = !own.value;
}
''',
    });
    expect(problems, isEmpty);
    expect(code, contains("ThorMember.state('count', s.count)"));
    expect(code, contains("ThorMember.state('own', s.own"));
    expect(code, contains("ThorMember('inc', s.inc"));
    expect(code, contains("ThorMember('label', s.label"));
    expect(code, contains("ThorMember('flip', s.flip"));
  });

  test('a dollar sign in a member or row property name is escaped in the '
      'quoted literals', () async {
    final (code, _, problems) = await _registry({
      'app|lib/shop.dart': r'''
import 'package:thor_ui/thor_ui.dart';

class Item {
  const Item(this.price$eur, this.qty$n, this.ratio$r);
  final String price$eur;
  final int qty$n;
  final double ratio$r;
}

class ShopState extends ThorState {
  final a$b = state(0);
  final c$d = derived(() => 1);
  void go$x() {}
  String label$y(Item i) => i.price$eur;
}
''',
    });
    expect(problems, isEmpty);
    expect(code, contains(r"ThorMember.state('a\$b'"));
    expect(code, contains(r"ThorMember('c\$d'"));
    expect(code, contains(r"ThorMember('go\$x'"));
    expect(code, contains(r"ThorMember('label\$y'"));
  });

  test('a dollar sign in a used state name is escaped', () async {
    final code = await resolveSources(
      {
        'app|lib/shop.dart': r'''
import 'package:thor_ui/thor_ui.dart';

class Cart$State extends ThorState {
  final n = state(0);
}
''',
      },
      (resolver) async {
        final lib = await resolver.libraryFor(
          AssetId.parse('app|lib/shop.dart'),
        );
        final c = lib.classes.single;
        return statesLibrary(
          [(c, 'lib/shop.dart')],
          warn: (_) {},
          problems: [],
          uses: {
            c: {r'Price$State'},
          },
        );
      },
      rootPackage: 'app',
      readAllSourcesFromFilesystem: true,
    );
    expect(code, contains(r"ThorStateType('Cart\$State'"));
    expect(code, contains(r"uses: const {'Price\$State'}"));
  });

  test('a row probe escapes a dollar sign in the property names', () async {
    final code = await resolveSources(
      {
        'app|lib/shop.dart': r'''
class Item {
  const Item(this.price$eur, this.qty$n, this.ratio$r);
  final String price$eur;
  final int qty$n;
  final double ratio$r;
}
''',
      },
      (resolver) async {
        final lib = await resolver.libraryFor(
          AssetId.parse('app|lib/shop.dart'),
        );
        return statesLibrary(
          const [],
          warn: (_) {},
          problems: [],
          rowItems: {lib.classes.single},
        );
      },
      rootPackage: 'app',
      readAllSourcesFromFilesystem: true,
    );
    expect(code, contains(r"log.read('price\$eur')"));
    expect(code, contains(r"RowProbeLog.marker('price\$eur')"));
    expect(code, contains(r"log.integer('qty\$n')"));
    expect(code, contains(r"log.decimal('ratio\$r')"));
  });

  test(
    'a plain ValueNotifier field warns that nothing listens to it',
    () async {
      final (_, warnings, problems) = await _registry({
        'app|lib/shop.dart': r'''
import 'package:thor_ui/thor_ui.dart';

class PanelState extends ThorState {
  final open = state(false);
  final loose = ValueNotifier<int>(0);
  final _private = ValueNotifier<int>(0);
  void inc() => loose.value++;
}
''',
      });
      expect(problems, isEmpty);
      final text = warnings.join('\n');
      expect(text, contains('THOR-B033'));
      expect(text, contains('PanelState.loose'));
      expect(text, isNot(contains('_private')));
      expect(text, isNot(contains('PanelState.open')));
    },
  );

  group('the states registry', () {
    late String code;
    late List<String> warnings;

    setUpAll(() async {
      final List<EntryProblem> problems;
      (code, warnings, problems) = await _registry({
        'app|lib/shop.dart': _shop,
      });
      expect(problems, isEmpty);
    });

    test('the state\'s life is not a member; bool and enum fields carry their '
        'values', () {
      expect(code, isNot(contains("'onHydrated'")));
      expect(code, isNot(contains("'dispose'")));
      expect(
        code,
        contains(
          "ThorMember.state('open', s.open, variants: const [false, true])",
        ),
      );
      expect(code, contains("ThorMember.state('tab2', s.tab2, variants: "));
      expect(code, contains("ThorMember.state('label2', s.label2)"));
    });

    test('a nullable bool or enum field has no variants: null has no copy '
        'to show, so it is unbounded (THOR-S013 says so)', () {
      expect(code, contains("ThorMember.state('orNull', s.orNull)"));
      expect(code, contains("ThorMember.state('orNullTab', s.orNullTab)"));
    });

    test('lists both states of the file with their public members', () {
      expect(code, contains("ThorStateType('ShopState',"));
      expect(code, contains("ThorStateType('OtherState',"));
      expect(code, contains("ThorMember.state('count', s.count)"));
      expect(code, contains("ThorMember.controller('scroll', s.scroll)"));
      expect(code, isNot(contains('plain')));
      expect(code, isNot(contains('_secret')));
      expect(code, isNot(contains('_hidden')));
      expect(code, contains('variants: const [false, true]'));
      expect(code, contains('t0.Tab.values'));
    });

    test('parses page arguments to the parameter types', () {
      expect(code, contains('s.add(int.parse(a!))'));
      expect(code, contains('s.pick(t0.Tab.values.byName(a!))'));
      expect(
        code,
        contains(
          's.picks((a == null || a.isEmpty ? <t0.Tab>{} : '
          "{for (final String? \$v in a.split('\\u001f')) "
          't0.Tab.values.byName(\$v!)}))',
        ),
      );
      expect(code, contains('s.at(DateTime.parse(a!))'));
      expect(code, contains('s.tapped(t1.TapDownDetails.fromArg(a))'));
      expect(code, contains('(hour: int.parse(a!.substring(0, 2))'));
      expect(code, contains('s.maybe((a == null || a.isEmpty ? null'));
      expect(code, contains('splitArgs(a, 3)'));
    });

    test('a CallbackAction method gets its intent made again; onKeyEvent the '
        'page\'s KeyEvent and a fresh FocusNode', () {
      expect(code, contains('s.save(t0.SaveIntent())'));
      expect(code, contains('KeyEvent.decode(a!)'));
      expect(code, contains('FocusNode(), '));
      expect(warnings.join('\n'), contains('ShopState.moveBy is skipped'));
    });

    test('passes list items unchecked, so a private item class works', () {
      expect(code, contains('s.lineName(i as dynamic)'));
      expect(code, contains('s.rowName(i as dynamic)'));
      expect(code, contains('s.cell(int.parse(a!), i as dynamic)'));
    });

    test('warns about methods the page cannot call', () {
      expect(warnings.join('\n'), contains('ShopState.tooMany is skipped'));
      expect(warnings.join('\n'), contains('ShopState.named is skipped'));
      expect(warnings.join('\n'), contains('THOR-B002'));
    });

    test('compiles next to the app, with no part in the app', () async {
      final errors = await compileErrors({
        'app|lib/shop.dart': _shop,
        'app|lib/states.g.dart': code,
      }, 'app|lib/states.g.dart');
      expect(errors, isEmpty);
    });
  });

  test('a state class the registry cannot name is THOR-B018', () async {
    const source = '''
import 'package:thor_ui/thor_ui.dart';

class _Hidden extends ThorState {}
class Box<T> extends ThorState {}
abstract class Base extends ThorState {}
enum _Mode { a, b }
class Mode extends ThorState {
  _Mode mode() => _Mode.a;
}
''';
    final (_, _, problems) = await _registry({'app|lib/shop.dart': source});
    final text = problems.join('\n');
    expect(text, contains('_Hidden must be public'));
    expect(text, contains('Box must be public, concrete and without type'));
    expect(text, contains('Base must be public, concrete'));
    expect(text, contains('Mode.mode returns a private enum'));
    expect(problems.every((p) => p.message.contains('THOR-B018')), isTrue);
  });

  test('two states with one class name are THOR-B036', () async {
    const a = """
import 'package:thor_ui/thor_ui.dart';

class PanelState extends ThorState {
  final on = state(false);
}
""";
    final problems = await resolveSources(
      {'app|lib/shop.dart': a, 'app|lib/other.dart': a},
      (resolver) async {
        final first = await resolver.libraryFor(
          AssetId.parse('app|lib/shop.dart'),
        );
        final second = await resolver.libraryFor(
          AssetId.parse('app|lib/other.dart'),
        );
        final problems = <EntryProblem>[];
        statesLibrary(
          [
            for (final c in first.classes) (c, 'lib/shop.dart'),
            for (final c in second.classes) (c, 'lib/other.dart'),
          ],
          warn: (_) {},
          problems: problems,
        );
        return problems;
      },
      rootPackage: 'app',
      readAllSourcesFromFilesystem: true,
    );
    expect(problems, hasLength(1));
    expect(problems.single.message, contains('THOR-B036'));
    expect(problems.single.message, contains('PanelState'));
    expect(problems.single.message, contains('lib/shop.dart'));
    expect(problems.single.message, contains('legal'));
    expect(problems.single.message, contains('OtherPanelState'));
  });

  test('the server entry registers, then runs the app with its args', () {
    final code = serverEntry('../../bin/server.dart');
    expect(code, contains("import '../../bin/server.dart' as app;"));
    final register = code.indexOf(
      'ThorServer.setUpIsolates(registerThorStates);',
    );
    expect(register, greaterThan(0));
    expect(code.indexOf('run(args)'), greaterThan(register));
  });

  test('the engine entry registers before it starts, with the features', () {
    final code = engineEntry(
      [('package:app/shop.dart', 'shop')],
      features: {'VariantsFeature', 'ListsFeature'},
      rowAttributes: true,
    );
    expect(code, contains("import 'package:app/shop.dart' as s0;"));
    expect(
      code.indexOf('registerThorStates();'),
      lessThan(code.indexOf('startThor(')),
    );
    expect(code, contains('s0.shop,'));
    expect(
      code,
      contains(
        'VariantsFeature(), ListsFeature(rowAttributes: RowAttributes())',
      ),
    );
    expect(
      engineEntry(const [], features: const {}, allFeatures: true),
      isNot(contains('features:')),
    );
  });

  test('the engine entry reads the properties the row lambdas read', () {
    final code = engineEntry(
      [('package:app/shop.dart', 'shop')],
      features: {'ListsFeature'},
      rowProperties: ['customer', 'city', 'customer'],
    );
    expect(code, contains('RowReaders({'));
    expect(code, contains("'city': (it) => (it as dynamic).city,"));
    expect(code, contains("'customer': (it) => (it as dynamic).customer,"));
    expect(RegExp("'customer'").allMatches(code), hasLength(1));
    expect(code.indexOf('s0.shop,'), lessThan(code.indexOf('RowReaders')));
    expect(
      engineEntry(const [], features: const {}, allFeatures: true),
      isNot(contains('RowReaders')),
    );
  });

  test('the engine entry counts the states of the bool and enum readers', () {
    final code = engineEntry(
      [('package:app/shop.dart', 'shop')],
      features: {'ListsFeature'},
      rowProperties: ['customer', 'tier', 'vip'],
      rowStates: {'vip': 2, 'tier': 3},
    );
    expect(code, contains("'vip': (it) => (it as dynamic).vip,"));
    expect(code, contains("'tier': (it) => (it as dynamic).tier,"));
    expect(code, contains("states: {'tier': 3, 'vip': 2}"));
    expect(
      engineEntry(
        [('package:app/shop.dart', 'shop')],
        features: {'ListsFeature'},
        rowProperties: ['customer'],
      ),
      isNot(contains('states:')),
    );
  });

  test('a row property with a dollar sign is quoted in the engine entry', () {
    final code = engineEntry(
      [('package:app/shop.dart', 'shop')],
      features: {'ListsFeature'},
      rowProperties: [r'price$eur'],
    );
    expect(code, contains(r"'price\$eur': (it) => (it as dynamic).price$eur,"));
  });

  test('AnimatedList brings the lists feature that keeps leaving rows', () {
    const source =
        'AnimatedList<Note, int>(notes.items.call, itemKey: notes.idOf, '
        'itemBuilder: (c, row, a) => FadeTransition(opacity: a, child: x))';
    final (used, _) = featuresOf([source]);
    expect(used, contains('ListsFeature'));
    expect(animatedRowsIn([source]), isTrue);
    expect(animatedRowsIn(['Watch.list(a, itemKey: k, each: e)']), isFalse);
    final code = engineEntry(
      [('package:app/s.dart', 's')],
      features: {'ListsFeature'},
      animatedRows: true,
    );
    expect(code, contains('ListsFeature(animatedRows: true)'));
    expect(
      engineEntry(
        [('package:app/s.dart', 's')],
        features: {'ListsFeature'},
        rowAttributes: true,
        animatedRows: true,
      ),
      contains(
        'ListsFeature(rowAttributes: RowAttributes(), animatedRows: true)',
      ),
    );
    expect(
      engineEntry([('package:app/s.dart', 's')], features: {'ListsFeature'}),
      contains('ListsFeature()'),
    );
  });

  test('features come from the sources, by text', () {
    final (used, rows) = featuresOf([
      "Watch(s.tab, builder: (t) => Text('x'))",
      "list.each(row.attribute('x'))  each: rows",
      'class A extends ThorState { final c = AnimationController(); }',
      'DropdownMenuEntry(value: 1)',
    ]);
    expect(
      used,
      containsAll(['VariantsFeature', 'ListsFeature', 'AnimationsFeature']),
    );
    expect(used, isNot(contains('DropdownMenuFeature')));
    expect(rows, isTrue);
  });

  test('tabs and menus bring their keyboard parts to an app with states', () {
    expect(
      featuresOf(['const TabBar(tabs: [Tab(text: "a")])']).$1,
      contains('TabsFeature'),
    );
    expect(
      featuresOf(['PopupMenuButton(items: [], child: Text("x"))']).$1,
      contains('MenuFeature'),
    );
    expect(
      featuresOf(['MenuAnchor(menuChildren: [])']).$1,
      contains('MenuFeature'),
    );
    expect(
      featuresOf(['SubmenuButton(menuChildren: [])']).$1,
      contains('MenuFeature'),
    );
    // A name that only ends like them is not them.
    expect(
      featuresOf(['MyTabBar(), final x = SideTabBar();']).$1,
      isNot(contains('TabsFeature')),
    );
    // They improve a page that has the engine anyway; they don't ask for it.
    expect(standaloneFeatures, isNot(contains('TabsFeature')));
    expect(standaloneFeatures, isNot(contains('MenuFeature')));
  });

  test('a windowed list brings VirtualLists into the engine entry', () {
    expect(usesVirtualLists(['Watch.list(r, virtual: true, each: x)']), isTrue);
    expect(usesVirtualLists(['Watch.list(r, each: x)']), isFalse);
    expect(usesVirtualLists(['final virtualized = 1;']), isFalse);
    final code = engineEntry(
      [('package:app/shop.dart', 'shop')],
      features: {'ListsFeature'},
      rowAttributes: true,
      virtualLists: true,
    );
    expect(
      code,
      contains(
        'ListsFeature(rowAttributes: RowAttributes(), '
        'virtualLists: VirtualLists())',
      ),
    );
    expect(
      engineEntry(
        [('package:app/shop.dart', 'shop')],
        features: {'ListsFeature'},
      ),
      isNot(contains('VirtualLists')),
    );
  });

  test('LifecycleFeature only for a state that overrides dispose', () {
    const state = '''
class TickState extends ThorState {
  Timer? _t;
  @override
  void dispose() => _t?.cancel();
}''';
    expect(featuresOf([state]).$1, contains('LifecycleFeature'));
    expect(
      featuresOf([state.replaceAll('dispose', 'onHydrated')]).$1,
      isNot(contains('LifecycleFeature')),
    );
    expect(
      featuresOf(['class W { void dispose() {} }']).$1,
      isNot(contains('LifecycleFeature')),
    );
  });

  test('row.bind brings the per-row attributes part like row.attribute', () {
    const source =
        'Watch.list(s.todos, itemKey: s.idOf, each: (row) => Checkbox('
        'value: false, semanticLabel: row.bind(s.titleOf)))';
    final (used, rows) = featuresOf([source]);
    expect(used, contains('ListsFeature'));
    expect(rows, isTrue);
    expect(featuresOf(['Text("x")']).$2, isFalse);
  });

  test('AnimationsFeature only for a controller in a state', () {
    const state = '''
class CardState extends ThorState {
  final reveal = AnimationController(duration: const Duration(seconds: 1));
}''';
    expect(featuresOf([state]).$1, contains('AnimationsFeature'));
    // An inline controller (a CSS entrance) in a widget file needs none.
    const hero = '''
Widget hero() => FadeTransition(
  opacity: AnimationController(duration: const Duration(seconds: 1))..forward(),
  child: const SizedBox(),
);''';
    expect(featuresOf([hero]).$1, isNot(contains('AnimationsFeature')));
  });

  test(
    'a bound length brings the variables feature, a number\'s .px does not',
    () {
      Set<String> used(String source) => featuresOf([source]).$1;
      expect(
        used(
          'Widget w() => Padding(padding: EdgeInsetsGeometry.allLength(card.gap.px), child: x);',
        ),
        contains('VariablesFeature'),
      );
      expect(
        used(
          'final r = BorderRadius.circularLength(BoundLength(card.radius));',
        ),
        contains('VariablesFeature'),
      );
      expect(
        used(
          'final p = EdgeInsets.all(16.px.toString().length);'
          'final l = Length.px(8); final w = 100.dvh - 48.px;',
        ),
        isNot(contains('VariablesFeature')),
      );
    },
  );

  test('Shortcuts, Actions and onKeyEvent share the shortcuts feature', () {
    for (final source in [
      'Widget page() => Shortcuts(shortcuts: {}, child: x);',
      'Widget page() => Actions(actions: {}, child: x);',
      'Widget page() => Focus(onKeyEvent: grid.onKey, child: x);',
    ]) {
      expect(
        featuresOf([source]).$1,
        contains('ShortcutsFeature'),
        reason: source,
      );
    }
    expect(
      featuresOf(['final a = myActions(x);']).$1,
      isNot(contains('ShortcutsFeature')),
    );
  });

  test('shortcuts, controllers, variables, clipboard and gestures', () {
    final (used, _) = featuresOf([
      '''
final scroll = ScrollController();
void copy() => Clipboard.setData(const ClipboardData(text: 'x'));
Widget page() => CallbackShortcuts(
  bindings: {},
  child: WatchVariables({}, child: Gesture(onDragUpdate: move, child: x)),
);''',
    ]);
    expect(
      used,
      containsAll([
        'ShortcutsFeature',
        'ControllersFeature',
        'VariablesFeature',
        'ClipboardFeature',
        'GesturesFeature',
      ]),
    );
  });

  test(
    'GestureDetector, InkWell and InkResponse ship the features Gesture does',
    () {
      final (detector, _) = featuresOf([
        'Widget w() => GestureDetector(onPanUpdate: move, child: x);',
      ]);
      expect(detector, containsAll(['GesturesFeature', 'KeyboardFeature']));
      final (swipe, _) = featuresOf([
        'Widget w() => GestureDetector(onHorizontalDragEnd: swiped, child: x);',
      ]);
      expect(swipe, contains('GesturesFeature'));
      // A tap alone needs the delegated click, and the keyboard for a
      // role=button target.
      final (ink, _) = featuresOf([
        'Widget w() => InkWell(onTap: open, child: x);',
      ]);
      expect(ink, contains('KeyboardFeature'));
      expect(ink, isNot(contains('GesturesFeature')));
      final (long, _) = featuresOf([
        'Widget w() => InkResponse(onLongPress: menu, child: x);',
      ]);
      expect(long, contains('GesturesFeature'));
      // A field or a name that only ends like them is not one.
      final (other, _) = featuresOf(['final MyGestureDetector = 1;']);
      expect(other, isNot(contains('GesturesFeature')));
    },
  );

  test('confirm and toast in a state need the feedback feature', () {
    const state = 'class A extends ThorState { void go() => toast(\'x\'); }';
    expect(featuresOf([state]).$1, contains('FeedbackFeature'));
    expect(
      featuresOf([
        'class A extends ThorState { Future<void> r() async { if (!await confirm(\'?\')) return; } }',
      ]).$1,
      contains('FeedbackFeature'),
    );
    // A member of the same name, `window.confirm`, or a page without a state.
    expect(
      featuresOf([
        'class A extends ThorState { void go() => dialog.confirm(); }',
      ]).$1,
      isNot(contains('FeedbackFeature')),
    );
    expect(
      featuresOf(['Text(toast(1))']).$1,
      isNot(contains('FeedbackFeature')),
    );
  });

  test('hideToast and clearToasts need the feedback feature too', () {
    for (final call in ['hideToast()', 'clearToasts()']) {
      expect(
        featuresOf(['class A extends ThorState { void go() => $call; }']).$1,
        contains('FeedbackFeature'),
        reason: call,
      );
    }
    expect(
      featuresOf([
        'class A extends ThorState { void go() => dialog.hideToast(); }',
      ]).$1,
      isNot(contains('FeedbackFeature')),
    );
  });

  test('a PageController needs the controllers; onPageChanged the element '
      'events', () {
    expect(
      featuresOf(['final pages = PageController(initialPage: 1);']).$1,
      contains('ControllersFeature'),
    );
    expect(
      featuresOf(['PageView(onPageChanged: deck.changed, children: [])']).$1,
      contains('ElementEventsFeature'),
    );
  });

  test('hover, focus and expansion callbacks need the element events', () {
    for (final page in [
      'MouseRegion(onEnter: card.hover, child: x)',
      'MouseRegion(onExit: card.unhover, child: x)',
      'Focus(onFocusChange: field.focused, child: x)',
      'ExpansionTile(onExpansionChanged: faq.toggled, title: t)',
    ]) {
      final (used, _) = featuresOf([page]);
      expect(used, contains('ElementEventsFeature'), reason: page);
    }
    // A cursor alone, or a word that only starts the same, is not one.
    final (plain, _) = featuresOf([
      'MouseRegion(cursor: SystemMouseCursors.click, child: x); final onEnterKey = 1;',
    ]);
    expect(plain, isNot(contains('ElementEventsFeature')));
  });

  test('AnimatedSize and AnimatedCrossFade need the size animations', () {
    for (final page in [
      'AnimatedSize(duration: d, child: x)',
      'AnimatedCrossFade(firstChild: a, secondChild: b)',
    ]) {
      final (used, _) = featuresOf([page]);
      expect(used, contains('SizeAnimationsFeature'), reason: page);
    }
    final (plain, _) = featuresOf(['final t = AnimatedSizeBox(1);']);
    expect(plain, isNot(contains('SizeAnimationsFeature')));
  });

  test('a CarouselView needs the carousel feature (controls, autoplay)', () {
    final (used, _) = featuresOf(['CarouselView(children: x)']);
    expect(used, contains('CarouselFeature'));
    final (plain, _) = featuresOf(['final c = MyCarouselViewer(1);']);
    expect(plain, isNot(contains('CarouselFeature')));
  });

  test('a Dismissible needs its feature, not the gestures one', () {
    final (used, _) = featuresOf([
      'Widget w() => Dismissible(key: k, onDismissed: s.gone, child: x);',
    ]);
    expect(used, contains('DismissibleFeature'));
    expect(used, isNot(contains('GesturesFeature')));
    final (plain, _) = featuresOf(['final d = MyDismissible(1);']);
    expect(plain, isNot(contains('DismissibleFeature')));
    final (field, _) = featuresOf(['final d = x.Dismissible(1);']);
    expect(field, isNot(contains('DismissibleFeature')));
  });

  test(
    'Draggable, LongPressDraggable and DragTarget need the drag feature',
    () {
      for (final source in [
        'Widget w() => Draggable<String>(data: id, feedback: f, child: x);',
        'Widget w() => LongPressDraggable(feedback: f, child: x);',
        'Widget w() => DragTarget<int>(builder: b);',
        'Widget w() => DragTarget<Map<String, int>>(builder: b);',
        'Widget w() => NativeDraggable<String>(data: id, child: x);',
        'Widget w() => NativeDragTarget<int>(builder: b);',
      ]) {
        expect(
          featuresOf([source]).$1,
          contains('DragDropFeature'),
          reason: source,
        );
      }
      for (final other in [
        'final d = MyDraggable(1);',
        'final t = x.DragTarget(1);',
      ]) {
        expect(featuresOf([other]).$1, isNot(contains('DragDropFeature')));
      }
    },
  );

  test('a SplitPane needs its feature and the element events', () {
    const source = 'Widget w() => SplitPane(first: a, second: b);';
    final features = featuresOf([source]).$1;
    expect(features, containsAll(['SplitPaneFeature', 'ElementEventsFeature']));
    expect(
      featuresOf(['final r = MySplitPane(1);']).$1,
      isNot(contains('SplitPaneFeature')),
    );
  });

  test('a ReorderableListView needs the reorderable feature', () {
    for (final source in [
      'Widget w() => ReorderableListView(onReorder: r, children: c);',
      'Widget w() => ReorderableListView.builder(itemBuilder: b, itemCount: 3, onReorder: r);',
    ]) {
      expect(
        featuresOf([source]).$1,
        contains('ReorderableFeature'),
        reason: source,
      );
    }
    expect(
      featuresOf(['final r = MyReorderableListView(1);']).$1,
      isNot(contains('ReorderableFeature')),
    );
    // The drag feature is not brought by it.
    expect(
      featuresOf([
        'Widget w() => ReorderableListView(onReorder: r, children: c);',
      ]).$1,
      isNot(contains('DragDropFeature')),
    );
  });

  test('a picker or a DropdownMenu alone still needs the engine', () {
    for (final page in [
      'DatePickerFormField(id: "d", name: "d")',
      'DropdownMenu<String>(dropdownMenuEntries: const [])',
      'DropdownMenu<List<int>>(x)',
    ]) {
      final (used, _) = featuresOf([page]);
      expect(used.any(standaloneFeatures.contains), isTrue, reason: page);
    }
    // An entry, or a word that starts the same, isn't one.
    expect(
      featuresOf([
        "const e = DropdownMenuEntry(value: 1, label: 'a'); "
                'final f = DropdownMenuFeature();'
            .toString(),
      ]).$1,
      isEmpty,
    );
    expect(featuresOf(["const x = 'plain';"]).$1, isEmpty);
  });

  test('Autocomplete and RawAutocomplete bring their feature alone', () {
    for (final page in [
      'Autocomplete<String>(optionsBuilder: (v) => const [])',
      'const Autocomplete(optionsBuilder: _all)',
      'RawAutocomplete<String>(optionsBuilder: _none)',
    ]) {
      final (used, _) = featuresOf([page]);
      expect(used, contains('AutocompleteFeature'), reason: page);
      expect(used.any(standaloneFeatures.contains), isTrue, reason: page);
    }
    // Its types and a word that starts the same are not one.
    final (plain, _) = featuresOf([
      'AutocompleteOptionsBuilder<String> f = g; AutocompleteFoo(1);',
    ]);
    expect(plain, isNot(contains('AutocompleteFeature')));
  });
}

const _counter = r'''
import 'package:thor_ui/thor_ui.dart';

class CounterState extends ThorState {
  final count = state(0);
  String label() => '${count.value}';
  void increment() => count.value++;
  void add(int n) => count.value += n;
}

final counter = CounterState();

class CounterWidget extends StatelessWidget {
  CounterWidget({super.key});

  final counterState = CounterState();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Watch(() => counter.count.value, builder: (v) => Text('$v')),
      OutlinedButton(
        onPressed: () {
          counter.increment();
        },
        child: const Text('+'),
      ),
      OutlinedButton(onPressed: () => counter.add(5), child: const Text('+5')),
      OutlinedButton(onPressed: counter.increment, child: const Text('ok')),
      OutlinedButton(onPressed: () {}, child: const Text('native')),
    ],
  );
}
''';

/// What the entries step reports for [source] as the app's
/// `lib/counter.dart`.
Future<List<String>> _misuses(String source) => resolveSources(
  {'app|lib/counter.dart': source},
  (resolver) async {
    final lib = await resolver.libraryFor(
      AssetId.parse('app|lib/counter.dart'),
    );
    final result =
        await lib.session.getResolvedUnit(lib.firstFragment.source.fullName)
            as ResolvedUnitResult;
    return stateMisuses(result.unit, 'lib/counter.dart');
  },
  rootPackage: 'app',
  readAllSourcesFromFilesystem: true,
);

// Which states need the page's shared dialog or snack bar.
const _feedback = r'''
import 'package:thor_ui/thor_ui.dart';

class AsksState extends ThorState {
  final orders = state(<int>[1]);

  Future<void> remove(int id) async {
    if (!await confirm('Delete?')) return;
    orders.value = [];
  }
}

class TellsState extends ThorState {
  void save() => toast('Saved', kind: ToastKind.success);
}
''';

/// The resolved unit of [lib].
Future<CompilationUnit> _unitOf(LibraryElement lib) async {
  final result =
      await lib.session.getResolvedLibraryByElement(lib)
          as ResolvedLibraryResult;
  return result.units.first.unit;
}

const _lifeSource = '''
import 'package:thor_ui/thor_ui.dart';

class TickState extends ThorState {
  void dispose() {}
}

mixin _Stops on ThorState {
  @override
  void dispose() {}
}

class MixedState extends ThorState with _Stops {}

class PlainState extends ThorState {
  @override
  void onHydrated() {}
}
''';

void _disposesTests() {
  test('the registry says which classes override dispose', () async {
    final code = await resolveSources(
      {'app|lib/life.dart': _lifeSource},
      (resolver) async {
        final lib = await resolver.libraryFor(
          AssetId.parse('app|lib/life.dart'),
        );
        return statesLibrary(
          [
            for (final c in lib.classes)
              if (isRegisteredState(c)) (c, 'lib/life.dart'),
          ],
          warn: (_) {},
          problems: [],
        );
      },
      rootPackage: 'app',
      readAllSourcesFromFilesystem: true,
    );
    String entry(String name) {
      final start = code.indexOf("ThorStateType('$name',");
      return code.substring(start, code.indexOf('),\n', start));
    }

    expect(entry('TickState'), contains('disposes: true'));
    expect(entry('MixedState'), contains('disposes: true'));
    expect(entry('PlainState'), isNot(contains('disposes')));
  });
}

void _feedbackTests() {
  test('a state names the shared features its file calls', () async {
    final code = await resolveSources(
      {'app|lib/shop.dart': _feedback},
      (resolver) async {
        final lib = await resolver.libraryFor(
          AssetId.parse('app|lib/shop.dart'),
        );
        final unit = await _unitOf(lib);
        final classes = [
          for (final c in lib.classes)
            if (isRegisteredState(c)) (c, 'lib/shop.dart'),
        ];
        final uses = featuresCalledIn([unit]);
        return statesLibrary(
          classes,
          warn: (_) {},
          problems: [],
          uses: {for (final (c, _) in classes) c: uses},
        );
      },
      rootPackage: 'app',
      readAllSourcesFromFilesystem: true,
    );
    // One file: every state in it carries what the file calls.
    expect(code, contains("uses: const {'confirm', 'toast'}"));
  });

  group('confirm and toast reached through helpers of other files', () {
    // The state's file never says `confirm`: a helper in another file does.
    Future<Set<String>> reached(
      Map<String, String> sources, {
      String from = 'lib/shop.dart',
    }) => resolveSources(
      {for (final e in sources.entries) 'app|${e.key}': e.value},
      (resolver) async {
        final lib = await resolver.libraryFor(AssetId.parse('app|$from'));
        return featuresReachedFrom(
          [await _unitOf(lib)],
          lib.session,
          inApp: (uri) =>
              uri.scheme == 'package' && uri.pathSegments.first == 'app',
        );
      },
      rootPackage: 'app',
      readAllSourcesFromFilesystem: true,
    );

    const state = r"""
import 'package:thor_ui/thor_ui.dart';
import 'helpers.dart';

class ShopState extends ThorState {
  final n = state(0);
  Future<void> remove() async {
    if (!await askDelete()) return;
    n.value++;
  }
}
""";

    test('a top-level helper of another file', () async {
      expect(
        await reached({
          'lib/shop.dart': state,
          'lib/helpers.dart': r"""
import 'package:thor_ui/thor_ui.dart';
Future<bool> askDelete() => confirm('Sure?');
""",
        }),
        {'confirm'},
      );
    });

    test('a chain over three files, a static method and a loop', () async {
      expect(
        await reached({
          'lib/shop.dart': state,
          'lib/helpers.dart': r"""
import 'a.dart';
Future<bool> askDelete() => Dialogs.sure();
""",
          'lib/a.dart': r"""
import 'b.dart';
class Dialogs {
  static Future<bool> sure() { loopA(); return Messages().ask(); }
  static void loopA() => loopB();
  static void loopB() => loopA();
}
""",
          'lib/b.dart': r"""
import 'package:thor_ui/thor_ui.dart';
class Messages {
  Future<bool> ask() { toast('hi'); return confirm('Sure?'); }
}
""",
        }),
        {'confirm', 'toast'},
      );
    });

    test('a tear-off passed as a callback counts too', () async {
      expect(
        await reached({
          'lib/shop.dart': r"""
import 'package:thor_ui/thor_ui.dart';
import 'helpers.dart';

class ShopState extends ThorState {
  final done = state(false);
  void go() => run(askDelete);
}
void run(Function f) {}
""",
          'lib/helpers.dart': r"""
import 'package:thor_ui/thor_ui.dart';
Future<bool> askDelete() => confirm('Sure?');
""",
        }),
        {'confirm'},
      );
    });

    test(
      'a helper that only has its own confirm or toast adds nothing',
      () async {
        expect(
          await reached({
            'lib/shop.dart': state,
            'lib/helpers.dart': r"""
Future<bool> askDelete() async => confirm('Sure?');
Future<bool> confirm(String m) async => true;
""",
          }),
          isEmpty,
        );
      },
    );

    test('a package function is not followed', () async {
      expect(
        await reached({
          'lib/shop.dart': r"""
import 'package:thor_ui/thor_ui.dart';
class ShopState extends ThorState {
  final n = state(0);
  void go() => n.value = [1, 2].length;
}
""",
        }),
        isEmpty,
      );
    });
  });

  test('a member named confirm is not the framework function', () async {
    final uses = await resolveSources(
      {
        'app|lib/shop.dart': r'''
import 'package:thor_ui/thor_ui.dart';

class ShadowState extends ThorState {
  final confirm = DialogController();
  void go() => confirm.open();
  String toast() => 'x';
  void again() => toast();
}
''',
      },
      (resolver) async => featuresCalledIn([
        await _unitOf(
          await resolver.libraryFor(AssetId.parse('app|lib/shop.dart')),
        ),
      ]),
      rootPackage: 'app',
      readAllSourcesFromFilesystem: true,
    );
    expect(uses, isEmpty);
  });

  test('hideToast and clearToasts ship the snack bar (uses toast)', () async {
    final uses = await resolveSources(
      {
        'app|lib/shop.dart': r'''
import 'package:thor_ui/thor_ui.dart';

class QuietState extends ThorState {
  void go() => hideToast();
  void all() => clearToasts();
}
''',
      },
      (resolver) async => featuresCalledIn([
        await _unitOf(
          await resolver.libraryFor(AssetId.parse('app|lib/shop.dart')),
        ),
      ]),
      rootPackage: 'app',
      readAllSourcesFromFilesystem: true,
    );
    expect(uses, {'toast'});
  });

  test('a file that calls neither adds nothing to its states', () async {
    final (code, _, _) = await _registry({'app|lib/shop.dart': _shop});
    expect(code, isNot(contains('uses:')));
  });
}

const _models = r'''
import 'package:thor_ui/thor_ui.dart';

class Order {
  const Order(this.id);
  factory Order.fromJson(Map<String, Object?> json) => Order(json['id']! as int);
  final int id;
  Map<String, Object?> toJson() => {'id': id};
}

class Draft {
  const Draft(this.text);
  final String text;
}

class OrdersViewModel extends ThorState {
  final orders = state<List<Order>>(const []);
  final byId = state<Map<String, Order>>(const {});
  final current = state<Order?>(null);
  final drafts = state<List<Draft>>(const []);
  final count = state(0);
}
''';

// A state field that holds the app's own class registers it with the engine
// (its `toJson`/`fromJson`), so it needs no `encode:`/`decode:`.
void _modelTests() {
  test('a class with toJson/fromJson in a state(...) is registered', () async {
    final (code, _, problems) = await _registry({'app|lib/shop.dart': _models});
    expect(problems, isEmpty);
    expect(
      code,
      contains(
        'registerJsonModel<t0.Order>(t0.Order.fromJson, (m) => m.toJson());',
      ),
    );
    // Once, however many fields hold it; a class without them is not.
    expect('registerJsonModel<'.allMatches(code), hasLength(1));
    expect(code, isNot(contains('t0.Draft')));
  });

  test('no registration without such a class', () async {
    final (code, _, _) = await _registry({'app|lib/shop.dart': _shop});
    expect(code, isNot(contains('registerJsonModel')));
  });
}

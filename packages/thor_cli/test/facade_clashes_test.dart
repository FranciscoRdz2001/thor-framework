import 'package:test/test.dart';
import 'package:thor_cli/src/dev/facade_clashes.dart';

void main() {
  const snapshot = '''
thor_ui\tSkeleton\tclass
thor_ui\tSkeleton.new\tSkeleton()
thor_ui\tText\tclass
thor_ui\tgap\tdouble gap
html\tInputType\tenum
''';

  test('facadeNames: top-level names by import, members dropped', () {
    expect(facadeNames(snapshot), {
      'thor_ui': {'Skeleton', 'Text', 'gap'},
      'html': {'InputType'},
    });
  });

  test('topLevelNames: types, typedefs, functions and variables', () {
    final names = topLevelNames('''
import 'x.dart';
abstract class Skeleton extends StatelessWidget {
  final Widget gap = x;
}
typedef Row2 = (int, int);
sealed class Shape {}
extension type Id(int v) {}
mixin Mx {}
enum Plan { a }
const limit = 10;
final List<int> items = [
  1,
];
Widget build(int x) => x;
Future<void> main() async {}
''');
    expect(
      names,
      containsAll([
        'Skeleton',
        'Row2',
        'Shape',
        'Id',
        'Mx',
        'Plan',
        'limit',
        'items',
        'build',
        'main',
      ]),
    );
    expect(names, isNot(contains('gap')));
  });

  group('importsFacade', () {
    test('plain import clashes; hide of that name, show, prefix do not', () {
      const uri = 'package:thor_ui/thor_ui.dart';
      expect(importsFacade("import '$uri';", uri, 'Skeleton'), isTrue);
      expect(
        importsFacade("import '$uri' hide Skeleton, Text;", uri, 'Skeleton'),
        isFalse,
      );
      expect(
        importsFacade("import '$uri' hide Text;", uri, 'Skeleton'),
        isTrue,
      );
      expect(
        importsFacade("import '$uri' show Text;", uri, 'Skeleton'),
        isFalse,
      );
      expect(importsFacade("import '$uri' as t;", uri, 'Skeleton'), isFalse);
      expect(
        importsFacade("import '$uri'\n    hide\n  Skeleton;", uri, 'Skeleton'),
        isFalse,
      );
      expect(importsFacade('', uri, 'Skeleton'), isFalse);
    });
  });

  test('findClashes: needs a file importing both, not the declarer itself', () {
    const uri = 'package:thor_ui/thor_ui.dart';
    final files = {
      'lib/ui/skeleton.dart': "import '$uri';\nclass Skeleton {}\n",
      'lib/pages/home.dart':
          "import '$uri';\nimport 'package:app/ui/skeleton.dart';\n",
      'lib/pages/other.dart':
          "import '$uri' hide Skeleton;\n"
          "import '../ui/skeleton.dart';\n",
      'lib/pages/unrelated.dart': "import '$uri';\n",
    };
    final clashes = findClashes(
      files,
      package: 'app',
      facade: facadeNames(snapshot),
    );
    expect(clashes, hasLength(1));
    expect(clashes.single.name, 'Skeleton');
    expect(clashes.single.declaredIn, 'lib/ui/skeleton.dart');
    expect(clashes.single.import, 'package:thor_ui/thor_ui.dart');
    expect(clashes.single.files, ['lib/pages/home.dart']);
    expect(
      clashes.single.fix,
      "import 'package:thor_ui/thor_ui.dart' hide Skeleton;",
    );
  });

  group('topLevelNames: what a light scan used to miss', () {
    test('annotations on the same line, getters, setters, extensions', () {
      final names = topLevelNames('''
@immutable class OneLine {}
@Deprecated('x') final tagged = 1;
@Deprecated(
  'x',
)
class Annotated {}
/// Doc.
int get gap => 1;
set level(int v) {}
extension Plain on String {}
extension Generic<T> on List<T> {}
extension on int {}
mixin class Both {}
base mixin Base {}
typedef Old = int Function();
final a = 1, second = 2;
''');
      expect(
        names,
        containsAll([
          'OneLine',
          'tagged',
          'Annotated',
          'gap',
          'level',
          'Plain',
          'Generic',
          'Both',
          'Base',
          'Old',
        ]),
      );
      expect(names, isNot(contains('on')));
    });

    test('comments and strings are not declarations; private names are '
        'never reported', () {
      final names = topLevelNames("""
/*
class InComment {}
*/
const text = '''
class InString {}
''';
class _Private {}
final _hidden = 1;
""");
      expect(names, contains('text'));
      expect(names, isNot(contains('InComment')));
      expect(names, isNot(contains('InString')));
      expect(names.where((n) => n.startsWith('_')), isEmpty);
    });
  });

  group('findClashes: what a file brings through other files', () {
    const uri = 'package:thor_ui/thor_ui.dart';
    final facade = facadeNames(snapshot);

    test('a name exported by a barrel clashes in who imports the barrel', () {
      final clashes = findClashes(
        {
          'lib/ui/skeleton.dart': 'class Skeleton {}',
          'lib/ui/ui.dart': "export 'skeleton.dart';",
          'lib/ui/hidden.dart': "export 'skeleton.dart' hide Skeleton;",
          'lib/pages/home.dart':
              "import '$uri';\nimport 'package:app/ui/ui.dart';\n",
          'lib/pages/other.dart':
              "import '$uri';\nimport 'package:app/ui/hidden.dart';\n",
        },
        package: 'app',
        facade: facade,
      );
      expect(clashes, hasLength(1));
      expect(clashes.single.files, ['lib/pages/home.dart']);
    });

    test('a name declared in a part file belongs to its library', () {
      final clashes = findClashes(
        {
          'lib/ui/ui.dart': "part 'skeleton.dart';",
          'lib/ui/skeleton.dart': "part of 'ui.dart';\nclass Skeleton {}\n",
          'lib/pages/home.dart':
              "import '$uri';\nimport 'package:app/ui/ui.dart';\n",
        },
        package: 'app',
        facade: facade,
      );
      expect(clashes, hasLength(1));
      expect(clashes.single.files, ['lib/pages/home.dart']);
    });

    test('a file that imports the facade twice or by another path', () {
      final clashes = findClashes(
        {
          'lib/ui/skeleton.dart': 'class Skeleton {}',
          'lib/pages/home.dart':
              "import 'package:thor_ui/thor_ui.dart';\nimport '../ui/skeleton.dart';\n",
          'lib/pages/shown.dart':
              "import '$uri' show Text;\nimport '../ui/skeleton.dart';\n",
        },
        package: 'app',
        facade: facade,
      );
      expect(clashes.single.files, ['lib/pages/home.dart']);
    });
  });
}

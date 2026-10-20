// ScrollController.animateTo and TextEditingController.selection in a
// lite state.
import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_lints/lite.dart';

const _state = r'''
import 'package:thor_ui/thor_ui.dart';

class FormState extends ThorState {
  final list = ScrollController(initialScrollOffset: 40);
  final name = TextEditingController(text: 'Ana');

  void top() => list.animateTo(
    0,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
  );
  Future<void> bottom() async {
    await list.animateTo(
      list.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.linear,
    );
    name.text = 'listo';
  }

  void toEnd() => name.selection = TextSelection.collapsed(offset: name.text.length);
  void pick() => name.selection = const TextSelection(baseOffset: 0, extentOffset: 2);
  int caret() => name.selection.baseOffset;
  bool isRange() => !name.selection.isCollapsed;
  int width() => name.selection.end - name.selection.start;
  bool ready() => list.hasClients;
  void fill() => name.value = const TextEditingValue(
    text: 'Maria',
    selection: TextSelection(baseOffset: 1, extentOffset: 3),
  );
  void upper() =>
      name.value = name.value.copyWith(text: name.value.text.toUpperCase());
  void wipe() => name.value = TextEditingValue.empty;
  String typed() => name.value.text;
  bool atStart() => name.value.selection.start == 0;
  bool sameValue() => name.value == const TextEditingValue(text: 'Ana');
  bool same() => name.selection == const TextSelection.collapsed(offset: 0);
}

final form = FormState();
''';

Future<String> _lite(String source) => resolveSources(
  {'app|lib/shop.dart': source},
  (resolver) async {
    final lib = await resolver.libraryFor(AssetId.parse('app|lib/shop.dart'));
    final res =
        await lib.session.getResolvedLibraryByElement(lib)
            as ResolvedLibraryResult;
    return translateLiteStates([
      for (final u in res.units) LiteUnit('lib/shop.dart', u.unit),
    ]);
  },
  rootPackage: 'app',
  readAllSourcesFromFilesystem: true,
);

void main() {
  late String js;
  setUpAll(() async => js = await _lite(_state));

  test('animateTo keeps the offset, the duration and the curve as CSS', () {
    expect(
      js,
      contains(r"list.animateTo(0, $c0, 'cubic-bezier(0, 0, 0.58, 1)')"),
    );
    expect(
      js,
      contains(r'await list.animateTo(list.position.maxScrollExtent, $c0'),
    );
    expect(js, contains(", 'linear')"));
    expect(js, isNot(contains('Curves')));
    expect(js, contains(r'$Dur.of('));
  });

  test('a TextSelection is made and read by its names', () {
    expect(js, contains('name.selection = '));
    expect(js, contains('.sel(name.text.length)'));
    expect(js, contains('.sel(0, 2)'));
    expect(js, contains('name.selection.baseOffset'));
    expect(js, contains('!name.selection.isCollapsed'));
    expect(js, contains('name.selection.end - name.selection.start'));
  });

  test('== on selections compares values', () {
    expect(js, contains(r'$deq(name.selection, '));
  });

  test('a selection in a string is interpolated (the part prints it as '
      'Dart does)', () async {
    final out = await _lite(
      _state.replaceFirst(
        'bool same()',
        r"String shown() => 'en ${name.selection}';"
            '\n  bool same()',
      ),
    );
    expect(out, contains(r'`en ${name.selection}`'));
    expect(out, contains('text_controller'));
  });

  test(
    'what a lite TextSelection does not have is an error that names it',
    () async {
      for (final member in [
        'hashCode',
        'isNormalized',
        'copyWith(baseOffset: 0)',
      ]) {
        await expectLater(
          _lite(
            _state.replaceFirst(
              'bool same()',
              'Object other() => name.selection.$member;\n  bool same()',
            ),
          ),
          throwsA(
            isA<LiteTranslationException>().having(
              (e) => e.toString(),
              'message',
              contains(member.split('(').first),
            ),
          ),
          reason: member,
        );
      }
    },
  );

  test('TextEditingController.value is read and written by its names', () {
    expect(js, contains('name.value = '));
    expect(js, contains('.val(`Maria`, '.replaceAll('`', "'")));
    expect(js, contains('name.value.copyWith(name.value.text.toUpperCase())'));
    expect(js, contains('name.value.text'));
    expect(js, contains('name.value.selection.start'));
  });

  test('TextEditingValue.empty and == by value', () {
    expect(js, contains(r'.val()'));
    expect(js, contains(r'$deq(name.value, '));
  });

  test('a copyWith of the selection too', () async {
    final out = await _lite(
      _state.replaceFirst(
        'bool atStart()',
        'void keep() => name.value = name.value.copyWith('
            'selection: const TextSelection.collapsed(offset: 0));\n'
            '  bool atStart()',
      ),
    );
    expect(out, contains('name.value.copyWith(undefined, '));
  });

  test('what a lite TextEditingValue does not have is an error that names '
      'it', () async {
    for (final member in ['composing', 'isComposingRangeValid']) {
      await expectLater(
        _lite(
          _state.replaceFirst(
            'bool atStart()',
            'Object other() => name.value.$member;\n  bool atStart()',
          ),
        ),
        throwsA(
          isA<LiteTranslationException>().having(
            (e) => e.toString(),
            'message',
            contains(member),
          ),
        ),
        reason: member,
      );
    }
  });

  test('hasClients is read by its name', () {
    expect(js, contains('list.hasClients'));
  });

  test('the parts are loaded', () {
    expect(js, contains('scroll_controller'));
    expect(js, contains('text_controller'));
  });
}

// The controller APIs pushed further in the translator: each one inside a state mixin and
// in a helper function, and the variants that are not in the subset giving
// errors that name what to do.
import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_lints/lite.dart';

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

Matcher _fails(String about) => throwsA(
  isA<LiteTranslationException>().having(
    (e) => e.toString(),
    'message',
    contains(about),
  ),
);

const _head = "import 'package:thor_ui/thor_ui.dart';\n";

void main() {
  group('inside a state mixin', () {
    const mixin =
        '''
${_head}mixin Controls on ThorState {
  final draft = TextEditingController();
  final field = FocusNode();
  final pages = PageController(initialPage: 1);
  final fade = AnimationController(duration: const Duration(milliseconds: 200));
  final heard = state(0);

  void note() => heard.value += field.hasFocus ? 1 : 0;
  @override
  void onHydrated() => field.addListener(note);
  @override
  void dispose() {
    field.removeListener(note);
    field.dispose();
  }

  void reset() {
    draft.value = const TextEditingValue(
      text: 'x',
      selection: TextSelection.collapsed(offset: 1),
    );
    draft.value = draft.value.copyWith(text: 'xy');
    clearToasts();
    hideToast();
  }

  bool same() => draft.value == TextEditingValue.empty;
  int where() => draft.value.selection.baseOffset;
  bool mounted() => pages.hasClients;
  Future<void> go() => pages.animateToPage(
    2,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeInOut,
  );
  Future<void> spring() => fade.fling(velocity: 2);
}

class PanelState extends ThorState with Controls {}

final panel = PanelState();
''';

    test('they translate with the controller fields of the mixin', () async {
      final js = await _lite(mixin);
      expect(js, contains('field.addListener(note)'));
      expect(js, contains('field.removeListener(note)'));
      expect(js, contains('field.dispose()'));
      expect(js, contains('draft.value = '));
      expect(js, contains('draft.value.copyWith('));
      expect(js, contains('toastHide'));
      expect(js, contains('pages.hasClients'));
      expect(js, contains('pages.animateToPage(2, '));
      expect(js, contains("'cubic-bezier(0.42, 0, 0.58, 1)'"));
      expect(js, contains('fade.fling(2)'));
      expect(js, contains('page_controller'));
      expect(js, contains('text_controller'));
    });

    test('== of two TextEditingValues compares by value', () async {
      final js = await _lite(mixin);
      expect(js, isNot(contains('draft.value === ')));
      expect(js, contains(r'$deq(draft.value'));
    });
  });

  group('inside a helper function', () {
    test('a controller passed to a function: value, listeners, pages, '
        'curves', () async {
      final js = await _lite('''
${_head}void reveal(TextEditingController c) =>
    c.value = c.value.copyWith(text: 'shown');
void watch(FocusNode n, void Function() f) => n.addListener(f);
Future<void> open(PageController p, int i) => p.animateToPage(
  i,
  duration: const Duration(milliseconds: 400),
  curve: Curves.fastOutSlowIn,
);
Future<void> slide(AnimationController a) => a.animateBack(
  0.2,
  duration: const Duration(milliseconds: 90),
  curve: Curves.easeOutBack,
);
void quiet() {
  hideToast();
  clearToasts();
}

class FormState extends ThorState {
  final name = TextEditingController();
  final focus = FocusNode();
  final pages = PageController();
  final fade = AnimationController(duration: const Duration(milliseconds: 200));
  void run() {
    reveal(name);
    watch(focus, quiet);
    open(pages, 1);
    slide(fade);
  }
}

final form = FormState();
''');
      expect(js, contains('c.value = c.value.copyWith('));
      expect(js, contains('n.addListener(f)'));
      expect(js, contains('p.animateToPage(i, '));
      expect(js, contains("'cubic-bezier(0.4, 0, 0.2, 1)'"));
      expect(js, contains("'cubic-bezier(0.175, 0.885, 0.32, 1.275)'"));
      expect(js, contains('toastHide'));
    });
  });

  group('a curve held in a constant', () {
    const css = "'cubic-bezier(0.2, 0, 0, 1)'";

    Future<String> withHolder(String holder, String use) => _lite('''
$_head$holder

class FadeState extends ThorState {
  final fade = AnimationController(duration: const Duration(milliseconds: 200));
  Future<void> back() => fade.animateBack(0, curve: $use);
}

final fader = FadeState();
''');

    test('a top-level const or final, with a const curve expression', () async {
      for (final (holder, use) in [
        ('const _snap = Cubic(0.2, 0, 0, 1);', '_snap'),
        ('const _snap = Curves.easeOut;', '_snap'),
        ('final _snap = const Cubic(0.2, 0, 0, 1);', '_snap'),
        ('final _snap = Cubic(0.2, 0, 0, 1);', '_snap'),
        ('const _a = Cubic(0.2, 0, 0, 1);\nconst _snap = _a;', '_snap'),
        ('final _snap = FlippedCurve(Cubic(1 - 0, 1, 1, 0.8));', '_snap'),
      ]) {
        final js = await withHolder(holder, use);
        expect(js, contains('fade.animateBack(0, null, '), reason: holder);
        expect(js, contains("'cubic-bezier("), reason: holder);
        expect(js, isNot(contains('_snap')), reason: 'not written: $holder');
      }
      final js = await withHolder(
        'const _snap = Cubic(0.2, 0, 0, 1);',
        '_snap',
      );
      expect(js, contains(css));
    });

    test('a static const of a class, and of the state itself', () async {
      var js = await withHolder(
        'class Motion {\n  static const curve = Cubic(0.2, 0, 0, 1);\n}',
        'Motion.curve',
      );
      expect(js, contains(css));
      expect(js, isNot(contains('curve')));
      js = await _lite('''
${_head}class FadeState extends ThorState {
  static const ease = Cubic(0.2, 0, 0, 1);
  final fade = AnimationController(duration: const Duration(milliseconds: 200));
  Future<void> back() => fade.animateBack(0, curve: ease);
}
final fader = FadeState();
''');
      expect(js, contains(css));
    });

    test('a final field of a state initialized with a const curve', () async {
      final js = await _lite('''
${_head}class FadeState extends ThorState {
  final ease = Curves.easeOut;
  final fade = AnimationController(duration: const Duration(milliseconds: 200));
  Future<void> back() => fade.animateBack(0, curve: ease);
  Future<void> again() => fade.animateTo(1, curve: this.ease);
}
final fader = FadeState();
''');
      expect(js, contains("'cubic-bezier(0, 0, 0.58, 1)'"));
      expect(js, isNot(contains('const ease')));
    });

    test('a value that is not constant keeps the precise error', () async {
      for (final holder in [
        'Curve _pick() => Curves.easeIn;\nfinal _snap = _pick();',
        'var _snap = Curves.easeIn;',
        'final _snap = DateTime.now().second > 3 ? Curves.easeIn : Curves.easeOut;',
      ]) {
        await expectLater(
          withHolder(holder, '_snap'),
          _fails('must be a constant'),
          reason: holder,
        );
      }
    });

    test('a curve used as a value anywhere else says it is only the '
        'curve argument', () async {
      await expectLater(
        _lite('''
${_head}const _snap = Cubic(0.2, 0, 0, 1);
class FadeState extends ThorState {
  final fade = AnimationController(duration: const Duration(milliseconds: 200));
  Object keep() => _snap;
}
final fader = FadeState();
'''),
        _fails('only the `curve:` argument'),
      );
    });
  });

  group('what is not in the subset names what to do', () {
    const base =
        '''
${_head}class FormState extends ThorState {
  final name = TextEditingController();
  final pages = PageController();
  final fade = AnimationController(duration: const Duration(milliseconds: 200));
  final scroll = ScrollController();
  void run() => BODY;
}

final form = FormState();
''';

    test('the parts of a TextEditingValue that do not exist', () async {
      for (final body in [
        'name.value.composing',
        'name.value.isComposingRangeValid',
        'name.value.replaced(const TextRange(start: 0, end: 1), "x")',
      ]) {
        final e = await _lite(
          base.replaceFirst('BODY', body),
        ).then<Object?>((_) => null, onError: (Object e) => e);
        expect(e, isA<LiteTranslationException>(), reason: body);
      }
    });

    test('animateTo with a curve that is a parameter says it must be '
        'constant', () async {
      await expectLater(
        _lite('''
${_head}class FormState extends ThorState {
  final fade = AnimationController(duration: const Duration(milliseconds: 200));
  Future<void> go(Curve c) => fade.animateTo(1, curve: c);
}
final form = FormState();
'''),
        _fails('must be a constant'),
      );
    });

    test(
      'a viewportFraction of a PageController in a mixin is refused too',
      () async {
        await expectLater(
          _lite('''
${_head}mixin Deck on ThorState {
  final pages = PageController(viewportFraction: 0.8);
}
class DeckState extends ThorState with Deck {}
final d = DeckState();
'''),
          _fails('viewportFraction'),
        );
      },
    );

    test('a PageController the page does not know cannot be used for '
        'positions', () async {
      await expectLater(
        _lite(base.replaceFirst('BODY', 'pages.position.pixels')),
        completes,
      );
    });
  });
}

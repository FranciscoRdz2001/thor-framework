// FocusNode listeners, AnimationController.animateTo/animateBack/fling,
// PageController, and ScaffoldMessenger.hideCurrentSnackBar/clearSnackBars
// in a lite state.
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
  group('FocusNode listeners', () {
    const state =
        '''
${_head}class FieldState extends ThorState {
  final field = FocusNode();
  final log = state('');
  void changed() => log.value += field.hasFocus ? 'in;' : 'out;';

  @override
  void onHydrated() => field.addListener(changed);

  @override
  void dispose() => field.removeListener(changed);
}

final form = FieldState();
''';

    test('addListener and removeListener take the state method', () async {
      final js = await _lite(state);
      expect(js, contains('field.addListener(changed)'));
      expect(js, contains('field.removeListener(changed)'));
      expect(js, contains('focus_node'));
    });

    test('a closure listener is fine too', () async {
      final js = await _lite(
        state.replaceFirst(
          'field.addListener(changed)',
          "field.addListener(() => log.value = 'x')",
        ),
      );
      expect(js, contains('field.addListener('));
    });

    test(
      'what a lite FocusNode does not have is an error that names it',
      () async {
        for (final member in [
          'canRequestFocus',
          'hasPrimaryFocus',
          'context',
        ]) {
          await expectLater(
            _lite(
              state.replaceFirst(
                'void changed()',
                'Object other() => field.$member;\n  void changed()',
              ),
            ),
            _fails(member),
            reason: member,
          );
        }
      },
    );
  });

  group('hideToast and clearToasts', () {
    const state =
        '''
${_head}class Notes extends ThorState {
  void save() => toast('Saved');
  void undo() => hideToast();
  void reset() => clearToasts();
}

final notes = Notes();
''';

    test('map to the page handle', () async {
      final js = await _lite(state);
      expect(js, contains(r'$toastHide(false)'));
      expect(js, contains(r'$toastHide(true)'));
      expect(js, contains('document.thorToastHide'));
    });

    test('an argument is an error that names the call', () async {
      await expectLater(
        _lite(state.replaceFirst('hideToast()', 'hideToast(1)')),
        _fails('hideToast'),
      );
    });
  });

  group('AnimationController.animateTo, animateBack and fling', () {
    const state =
        '''
${_head}class FadeState extends ThorState {
  final fade = AnimationController(duration: const Duration(milliseconds: 300));

  void half() => fade.animateTo(0.5);
  Future<void> slow() => fade.animateTo(
    1,
    duration: const Duration(seconds: 1),
    curve: Curves.easeOut,
  );
  Future<void> back() => fade.animateBack(0, curve: Curves.linear);
  void backFor() =>
      fade.animateBack(0.25, duration: const Duration(milliseconds: 80));
  Future<void> kick() => fade.fling(velocity: -2);
  void push() => fade.fling();
  Future<void> chain() async {
    await fade.animateTo(0.5);
    await fade.animateBack(0);
    fade.forward();
  }
}

final fader = FadeState();
''';

    test(
      'the target, the duration and the curve (as its CSS) are translated',
      () async {
        final js = await _lite(state);
        expect(js, contains('fade.animateTo(0.5);'));
        expect(js, contains(r'$Dur.of(undefined, undefined, undefined, 1)'));
        expect(
          js,
          contains(r"fade.animateTo(1, $c1, 'cubic-bezier(0, 0, 0.58, 1)')"),
        );
        expect(js, contains("fade.animateBack(0, null, 'linear');"));
        expect(js, contains('fade.animateBack(0.25, '));
        expect(js, isNot(contains('Curves')));
        expect(js, contains('animation_controller'));
      },
    );

    test('a curve is the CSS its class compiles to: Cubic, Interval, '
        'FlippedCurve, a sampled one; the constants of Curves', () async {
      for (final (curve, css) in [
        ('Curves.fastOutSlowIn', "'cubic-bezier(0.4, 0, 0.2, 1)'"),
        ('Cubic(1 / 3, 0.5, -0.5, 1)', "'cubic-bezier(0.3333, 0.5, -0.5, 1)'"),
        ('const Cubic(0.1, 0.2, 0.3, 1)', "'cubic-bezier(0.1, 0.2, 0.3, 1)'"),
        ('Curves.easeInOutCubicEmphasized', "'linear(0, "),
        ('Curves.bounceOut', "'linear(0, 0.005, "),
        ('const Interval(0.25, 0.75, curve: Curves.easeIn)', "'linear(0, 0, "),
        ('FlippedCurve(Curves.easeIn)', "'cubic-bezier(0, 0, 0.58, 1)'"),
        ('const Threshold(0.5)', "'linear(0, 0 50%, 1 50%, 1)'"),
        ('const ElasticOutCurve(0.5)', "'linear(0, "),
      ]) {
        final js = await _lite(
          state.replaceFirst('curve: Curves.linear', 'curve: $curve'),
        );
        expect(js, contains('fade.animateBack(0, null, $css'), reason: curve);
      }
    });

    test('inside a mixin and a helper the curve is compiled too', () async {
      final js = await _lite('''
${_head}mixin Fades on ThorState {
  final fade = AnimationController(duration: const Duration(milliseconds: 300));
  Future<void> hide() => fade.animateBack(0, curve: Curves.easeIn);
}

Future<void> softly(AnimationController c) =>
    c.animateTo(1, duration: const Duration(seconds: 2), curve: Curves.easeOut);

class CardState extends ThorState with Fades {
  Future<void> show() => softly(fade);
}

final card = CardState();
''');
      expect(
        js,
        contains("fade.animateBack(0, null, 'cubic-bezier(0.42, 0, 1, 1)')"),
      );
      expect(js, contains('c.animateTo(1, '));
      expect(js, contains("'cubic-bezier(0, 0, 0.58, 1)'"));
    });

    test('a curve that is not a constant is an error that says what '
        'works', () async {
      for (final curve in [
        'someCurve()',
        'Curves.easeIn.flipped',
        'Curve(0.1)',
        'MyCurve()',
        'const Cubic(speed, 0, 0, 1)',
        'curveField',
      ]) {
        await expectLater(
          _lite('''
${_head}class MyCurve extends Curve {
  const MyCurve();
  @override
  double transformInternal(double t) => t;
}

Curve someCurve() => Curves.easeIn;
double speed = 0.3;

class FadeState extends ThorState {
  final fade = AnimationController(duration: const Duration(milliseconds: 300));
  Curve curveField = Curves.easeIn;
  Future<void> back() => fade.animateBack(0, curve: $curve);
}

final fader = FadeState();
'''),
          _fails('must be a constant'),
          reason: curve,
        );
      }
    });

    test(
      'the animateTo of a scroll view takes its duration and curve too',
      () async {
        await expectLater(
          _lite('''
${_head}class ListState extends ThorState {
  final list = ScrollController();
  void top() => list.animateTo(0, duration: const Duration(seconds: 1), curve: Curves.easeIn);
}
final l = ListState();
'''),
          completes,
        );
      },
    );

    test('fling takes its velocity', () async {
      final js = await _lite(state);
      expect(js, contains('fade.fling(-2)'));
      expect(js, contains('fade.fling()'));
    });

    test('they can be awaited', () async {
      final js = await _lite(state);
      expect(js, contains('(await fade.animateTo(0.5));'));
      expect(js, contains('(await fade.animateBack(0));'));
    });

    test('an Interval is sampled into a linear() the same way', () async {
      final js = await _lite(
        state.replaceFirst(
          'curve: Curves.linear',
          'curve: const Interval(0, 0.5)',
        ),
      );
      expect(js, contains("fade.animateBack(0, null, 'linear("));
    });
  });

  group('PageController', () {
    const state =
        '''
${_head}class DeckState extends ThorState {
  final pages = PageController(initialPage: 2);
  final seen = state(0);

  void changed(int page) => seen.value = page;
  int current() => pages.page!.round();
  double offset() => pages.offset;
  bool ready() => pages.hasClients;
  void first() => pages.jumpToPage(0);
  void next() => pages.jumpToPage(current() + 1);
  Future<void> slide() => pages.animateToPage(
    current() + 1,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
  );
  Future<void> top() => pages.animateTo(
    0,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
  );
  void px() => pages.jumpTo(100);
  int start() => pages.initialPage;
}

final deck = DeckState();
''';

    test('the field is made by the page part, and starts at load', () async {
      final js = await _lite(state);
      expect(js, contains(r'$C.page(`${$p}.pages`, 2)'));
      expect(js, contains('page_controller'));
      expect(js, contains('scroll_controller'));
      expect(js, contains('eager: true'));
    });

    test('page, jumpToPage and animateToPage keep their names; duration and '
        'curve are translated', () async {
      final js = await _lite(state);
      expect(js, contains('pages.page'));
      expect(js, contains('pages.jumpToPage(0)'));
      expect(js, contains('pages.jumpToPage(current() + 1)'));
      expect(
        js,
        contains(
          r"pages.animateToPage(current() + 1, $c0, 'cubic-bezier(0, 0, 0.58, 1)')",
        ),
      );
      expect(
        js,
        contains(r"pages.animateTo(0, $c0, 'cubic-bezier(0, 0, 0.58, 1)')"),
      );
      expect(js, isNot(contains('easeOut')));
      expect(js, contains('pages.offset'));
      expect(js, contains('pages.hasClients'));
      expect(js, contains('pages.initialPage'));
    });

    test('a ScrollController alone does not bring the page part', () async {
      final js = await _lite('''
${_head}class ListState extends ThorState {
  final list = ScrollController();
  void top() => list.jumpTo(0);
}

final l = ListState();
''');
      expect(js, isNot(contains('page_controller')));
    });

    test('viewportFraction is refused with the reason', () async {
      await expectLater(
        _lite(
          state.replaceFirst(
            'PageController(initialPage: 2)',
            'PageController(viewportFraction: 0.8)',
          ),
        ),
        _fails('viewportFraction'),
      );
    });

    test('keepPage is accepted', () async {
      final js = await _lite(
        state.replaceFirst(
          'PageController(initialPage: 2)',
          'PageController(initialPage: 1, keepPage: false)',
        ),
      );
      expect(js, contains(r'$C.page(`${$p}.pages`, 1'));
    });

    test('what a lite PageController does not have is an error that names '
        'it', () async {
      for (final member in ['positions', 'viewportFraction', 'keepPage']) {
        await expectLater(
          _lite(
            state.replaceFirst(
              'int start()',
              'Object other() => pages.$member;\n  int start()',
            ),
          ),
          _fails(member),
          reason: member,
        );
      }
    });
  });
}

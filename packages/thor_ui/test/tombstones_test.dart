@TestOn('vm')
library;

// ignore_for_file: deprecated_member_use

// Flutter names with no equivalent in thor: each is a @Deprecated
// tombstone that says the fix in the editor and, if it is run anyway,
// throws the same message with a link, instead of rendering nothing.
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

const _docs = 'https://thor-docs.vercel.app/en/get-started/from-flutter#';

/// Runs [body] and returns the message of the [UnsupportedError] it throws.
String _says(void Function() body) {
  try {
    body();
  } on UnsupportedError catch (e) {
    return '${e.message}';
  }
  fail('nothing was thrown');
}

Matcher _guides(String name, List<String> fixes) =>
    allOf([contains(name), contains(_docs), ...fixes.map(contains)]);

Future<void> _render(Widget w) => renderHtml(ThorApp(child: w));

void main() {
  setUpAll(initializeThorTests);

  group('the widgets throw when they are built, with the fix', () {
    test('LayoutBuilder', () {
      expect(
        _says(
          () =>
              LayoutBuilder(builder: (context, constraints) => const Text('x')),
        ),
        _guides('LayoutBuilder', ['LayoutScope', '.when(']),
      );
    });

    test('OrientationBuilder', () {
      expect(
        _says(
          () => OrientationBuilder(
            builder: (context, orientation) => const Text('x'),
          ),
        ),
        _guides('OrientationBuilder', ['.when(']),
      );
    });

    test('StreamBuilder', () {
      expect(
        _says(
          () => StreamBuilder<int>(
            stream: const Stream<int>.empty(),
            builder: (context, snapshot) => const Text('x'),
          ),
        ),
        _guides('StreamBuilder', ['ThorState']),
      );
    });

    test('BottomNavigationBar points at NavigationBar', () {
      expect(
        _says(
          () => BottomNavigationBar(
            items: const [
              BottomNavigationBarItem(icon: Text('i'), label: 'Home'),
            ],
          ),
        ),
        _guides('BottomNavigationBar', ['NavigationBar']),
      );
    });

    test('Navigator and MediaQuery as widgets', () {
      expect(
        _says(() => Navigator(onGenerateRoute: (settings) => null)),
        _guides('Navigator', ['Link']),
      );
      expect(
        _says(
          () =>
              MediaQuery(data: const MediaQueryData(), child: const Text('x')),
        ),
        _guides('MediaQuery', ['.when(']),
      );
    });

    test('the error is thrown where the widget is written, not rendered', () {
      // Never a page that renders empty: constructing it already fails.
      expect(
        () => _render(
          Column(
            children: [LayoutBuilder(builder: (context, c) => const Text('x'))],
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('the static entry points throw too', () {
    test('MediaQuery.of and friends', () {
      final context = _Ctx();
      for (final call in <void Function()>[
        () => MediaQuery.of(context),
        () => MediaQuery.maybeOf(context),
        () => MediaQuery.sizeOf(context),
        () => MediaQuery.orientationOf(context),
        () => MediaQuery.paddingOf(context),
      ]) {
        expect(_says(call), _guides('MediaQuery', ['.when(', 'LayoutScope']));
      }
    });

    test('Navigator.pop closes drawers and dialogs: the message says how', () {
      final context = _Ctx();
      for (final call in <void Function()>[
        () => Navigator.pop(context),
        () => Navigator.of(context).pop(),
        () => Navigator.maybePop(context),
        () => Navigator.of(context).maybePop(),
      ]) {
        expect(
          _says(call),
          _guides('Navigator', [
            'DialogClose(child: ListTile(onTap:',
            'DialogController',
            'PageNavigator',
          ]),
        );
      }
    });

    test('Navigator.of(context).pop() and the static forms', () {
      final context = _Ctx();
      for (final call in <void Function()>[
        () => Navigator.of(context),
        () => Navigator.maybeOf(context),
        () => Navigator.pop(context),
        () => Navigator.maybePop(context),
        () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (c) => const Text('x')),
        ),
        () => Navigator.pushNamed(context, '/x'),
        () => Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(builder: (c) => const Text('x')),
        ),
        () => Navigator.popUntil(context, (route) => true),
      ]) {
        expect(_says(call), _guides('Navigator', ['Link', 'PageNavigator']));
      }
    });

    test('MaterialPageRoute', () {
      expect(
        _says(() => MaterialPageRoute<void>(builder: (c) => const Text('x'))),
        _guides('MaterialPageRoute', ['Link']),
      );
    });

    test('showDialog', () {
      expect(
        _says(
          () => showDialog<bool>(
            context: _Ctx(),
            builder: (context) => const AlertDialog(),
          ),
        ),
        _guides('showDialog', ['AlertDialog', 'DialogController', 'confirm(']),
      );
    });

    test('showModalBottomSheet, showDatePicker and showTimePicker', () {
      final context = _Ctx();
      expect(
        _says(
          () => showModalBottomSheet<void>(
            context: context,
            builder: (c) => const Text('x'),
            isScrollControlled: true,
            showDragHandle: true,
          ),
        ),
        _guides('showModalBottomSheet', ['ModalBottomSheet', 'DialogTrigger']),
      );
      expect(
        _says(
          () => showDatePicker(
            context: context,
            initialDate: DateTime(2026),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            helpText: 'x',
          ),
        ),
        _guides('showDatePicker', ['DatePickerFormField', 'DatePickerDialog']),
      );
      expect(
        _says(
          () => showTimePicker(
            context: context,
            initialTime: Object(),
            helpText: 'x',
          ),
        ),
        _guides('showTimePicker', ['TimePickerDialog']),
      );
    });

    test('pasted Flutter code compiles: every showDialog parameter', () {
      // A missing named parameter would be a compile error instead of the
      // guide: this file not compiling is the failure.
      final context = _Ctx();
      expect(
        _says(
          () => showDialog<void>(
            context: context,
            builder: (c) => const AlertDialog(),
            barrierDismissible: false,
            barrierColor: null,
            barrierLabel: 'x',
            useSafeArea: false,
            useRootNavigator: false,
            routeSettings: null,
            anchorPoint: null,
            traversalEdgeBehavior: null,
            fullscreenDialog: true,
            requestFocus: true,
          ),
        ),
        _guides('showDialog', ['AlertDialog']),
      );
      for (final call in <void Function()>[
        () => Navigator.of(context).pushReplacementNamed('/x'),
        () => Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false),
        () => Navigator.of(context).popUntil((r) => true),
        () => Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (c) => const Text('x')),
          (r) => false,
        ),
      ]) {
        expect(_says(call), _guides('Navigator', ['Link', 'PageNavigator']));
      }
    });

    test('ScaffoldMessenger.of(context).showSnackBar', () {
      final context = _Ctx();
      for (final call in <void Function()>[
        () => ScaffoldMessenger.of(context),
        () => ScaffoldMessenger.maybeOf(context),
      ]) {
        expect(_says(call), _guides('ScaffoldMessenger', ['toast(', 'flash']));
      }
      expect(
        _says(
          () => const ScaffoldMessengerState().showSnackBar(const Text('x')),
        ),
        _guides('ScaffoldMessenger', ['toast(']),
      );
      expect(
        _says(() => const ScaffoldMessengerState().hideCurrentSnackBar()),
        _guides('ScaffoldMessenger', ['hideToast()']),
      );
      expect(
        _says(() => const ScaffoldMessengerState().clearSnackBars()),
        _guides('ScaffoldMessenger', ['clearToasts()']),
      );
    });
  });

  group('they are tombstones, not API', () {
    test('every one is @Deprecated, with the fix in the message', () {
      final source = File('lib/src/widgets/tombstones.dart').readAsStringSync();
      final names = RegExp(
        r'@Tombstone\(\)\s+@Deprecated\(',
      ).allMatches(source).length;
      // The widgets, the statics' classes, the function and the helpers.
      expect(names, greaterThanOrEqualTo(12));
      expect(
        RegExp(
          r'^(abstract |final )?(class|enum|Future|typedef)\b',
          multiLine: true,
        ).allMatches(source).length,
        greaterThanOrEqualTo(12),
      );
    });

    test('the link points at a section of the English guide', () {
      final guide = File(
        '../../docs/guia/en/from-flutter.md',
      ).readAsStringSync();
      // The anchor of `## Flutter names that don't exist`.
      expect(guide, contains("## Flutter names that don't exist"));
      expect(
        File('lib/src/widgets/tombstones.dart').readAsStringSync(),
        contains("'#flutter-names-that-dont-exist'"),
      );
      // The built page (the docs golden) serves that path with that anchor.
      final built = File(
        '../../test/golden/docs/en/get-started/from-flutter.html',
      ).readAsStringSync();
      expect(built, contains('id="flutter-names-that-dont-exist"'));
    });

    test('the guide lists each one', () {
      final guide = File(
        '../../docs/guia/es/desde-flutter.md',
      ).readAsStringSync();
      for (final name in [
        'MediaQuery',
        'LayoutBuilder',
        'OrientationBuilder',
        'showDialog',
        'showModalBottomSheet',
        'showDatePicker',
        'showTimePicker',
        'Navigator',
        'ScaffoldMessenger',
        'StreamBuilder',
        'BottomNavigationBar',
      ]) {
        expect(guide, contains('`$name'), reason: name);
      }
      expect(guide, contains('## Nombres de Flutter que no existen'));
    });
  });
}

/// A context for the calls that only need one to throw.
class _Ctx implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

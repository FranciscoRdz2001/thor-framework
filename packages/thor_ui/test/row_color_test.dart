@TestOn('vm')
library;

// `row.color(...)`: a row's color from its item (a lambda over a `String`
// property, or a method of the state) as a CSS variable the class reads. The
// element that reads it gets the binding and the first value; the class is the
// same in every row.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class Swatch {
  const Swatch(this.id, this.hex);
  final int id;
  final String hex;
}

/// What thor generates for `Swatch` (by hand: tests don't run the build).
class _SwatchProbe implements Swatch {
  _SwatchProbe(this.log);
  final RowProbeLog log;

  @override
  int get id => log.integer('id');

  @override
  String get hex {
    log.read('hex');
    return RowProbeLog.marker('hex');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    log.read('');
    return super.noSuchMethod(invocation);
  }
}

abstract class _Members extends ThorState {
  @override
  String get $type => 'SwatchesState';

  @override
  List<ThorMember> get $members {
    final s = this as SwatchesState;
    return [
      ThorMember.state('swatches', s.swatches),
      ThorMember(
        'idOf',
        s.idOf,
        arity: 1,
        callWithItem: (i) => s.idOf(i as Swatch),
      ),
      ThorMember(
        'hexOf',
        s.hexOf,
        arity: 1,
        callWithItem: (i) => s.hexOf(i as Swatch),
      ),
    ];
  }
}

class SwatchesState extends _Members {
  final swatches = state<List<Swatch>>(const [
    Swatch(1, '#4361ee'),
    Swatch(2, 'rgb(1, 2, 3);background:url(x)'),
    Swatch(3, ''),
  ]);

  int idOf(Swatch s) => s.id;
  String hexOf(Swatch s) => s.hex;
}

final swatches = SwatchesState();

void main() {
  initializeThorTests();
  setUpAll(() => registerRowProbes({Swatch: _SwatchProbe.new}));

  Future<String> rows(Widget Function(WatchRow<Swatch, int> row) each) =>
      renderHtml(
        Watch.list(swatches.swatches.call, itemKey: swatches.idOf, each: each),
      );

  Widget chip(Color color) => Container(width: 28, height: 28, color: color);

  test('a lambda over a property: first value, binding, one class', () async {
    final out = await rows((row) => chip(row.color((s) => s.hex)));
    final name = RegExp(r'--tr-color-[A-Za-z0-9_-]+').firstMatch(out)![0]!;
    expect(out, contains('$name: #4361ee'));
    expect(out, contains('data-tfa="$name:\$Rows.hex"'));
    // One class for every row: the color is a variable, not a declaration.
    expect(out, contains('background-color: var($name)'));
    expect(RegExp('#4361ee').allMatches(out), hasLength(1));
  });

  test('a value that is not a color is left unset', () async {
    final out = await rows((row) => chip(row.color((s) => s.hex)));
    expect(out, isNot(contains('url(x)')));
    // Rows 2 (not a color) and 3 (empty) carry the binding but no value;
    // the template carries neither a value.
    expect(
      RegExp(r'--tr-color-[A-Za-z0-9_-]+: ').allMatches(out),
      hasLength(1),
    );
    expect(RegExp(r'data-tfa="--tr-color').allMatches(out), hasLength(4));
  });

  test('a method of the state works too', () async {
    final out = await rows((row) => chip(row.color(swatches.hexOf)));
    expect(out, contains('--tr-color-SwatchesState-hexOf: #4361ee'));
    expect(
      out,
      contains('data-tfa="--tr-color-SwatchesState-hexOf:SwatchesState.hexOf"'),
    );
  });

  test('read outside its row it fails with THOR-S042', () async {
    late RowColor leaked;
    await rows((row) => chip(leaked = row.color((s) => s.hex)));
    await expectLater(
      renderHtml(chip(leaked)),
      throwsA(
        predicate(
          (e) => '$e'.contains('THOR-S042') && '$e'.contains('row.color'),
        ),
      ),
    );
  });
}

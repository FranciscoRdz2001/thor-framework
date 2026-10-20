import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

void main() {
  test('an outer and an inner transform compose, outer first', () {
    final out = composeTransforms(
      {'transform': 'rotate(0.5rad)'},
      {'transform': 'scale(2)'},
    );
    // Same (default) origin: one list, the outer one applied last.
    expect(out, {'transform': 'rotate(0.5rad) scale(2)'});
  });

  test('different origins are baked into the list', () {
    final out = composeTransforms(
      {'transform': 'rotate(0.5rad)'},
      {'transform': 'matrix(1, 0, 0, 1, 8, 0)', 'transform-origin': '0 0'},
    );
    expect(out, {
      'transform':
          'translate(50%, 50%) rotate(0.5rad) translate(-50%, -50%) '
          'matrix(1, 0, 0, 1, 8, 0)',
      'transform-origin': '0 0',
    });
  });

  test('only one side: nothing to compose', () {
    expect(composeTransforms({'transform': 'a'}, {'x': 'y'}), isNull);
    expect(composeTransforms({'x': 'y'}, {'transform': 'a'}), isNull);
  });

  test('an unparseable origin keeps the inner transform alone', () {
    expect(
      composeTransforms(
        {'transform': 'a', 'transform-origin': 'left top'},
        {'transform': 'b'},
      ),
      isNull,
    );
  });
}

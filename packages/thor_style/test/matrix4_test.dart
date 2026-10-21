import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

void main() {
  test('identity is no transform', () {
    expect(Matrix4.identity().css, 'none');
  });

  test('2D matrices compile to matrix()', () {
    expect(
      Matrix4.translationValues(10, 20, 0).css,
      'matrix(1, 0, 0, 1, 10, 20)',
    );
    expect(Matrix4.diagonal3Values(2, 3, 1).css, 'matrix(2, 0, 0, 3, 0, 0)');
    // rotationZ(0) is the identity, rotationZ(pi / 2) is a quarter turn.
    expect(Matrix4.rotationZ(0).css, 'none');
    final q = Matrix4.rotationZ(1.5707963267948966).css;
    expect(q, 'matrix(0, 1, -1, 0, 0, 0)');
  });

  test('3D matrices compile to matrix3d()', () {
    expect(
      Matrix4.rotationX(1.5707963267948966).css,
      'matrix3d(1, 0, 0, 0, 0, 0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1)',
    );
    expect(Matrix4.translationValues(0, 0, 5).css, startsWith('matrix3d('));
  });

  test('multiplication applies the right operand first, like Flutter', () {
    // translate(10, 0) * scale(2): a point is scaled, then moved.
    final m =
        Matrix4.translationValues(10, 0, 0) * Matrix4.diagonal3Values(2, 2, 1);
    expect(m.css, 'matrix(2, 0, 0, 2, 10, 0)');
    final n =
        Matrix4.diagonal3Values(2, 2, 1) * Matrix4.translationValues(10, 0, 0);
    expect(n.css, 'matrix(2, 0, 0, 2, 20, 0)');
  });

  test('value equality and no NaN in the output', () {
    expect(
      Matrix4.translationValues(1, 2, 0),
      Matrix4.translationValues(1, 2, 0),
    );
    expect(Matrix4.rotationZ(0.3).css, isNot(contains('NaN')));
    // -0 does not leak as "-0".
    expect(Matrix4.rotationZ(3.141592653589793).css, isNot(contains('-0,')));
  });

  test('a matrix changes per state and breakpoint with .when()', () {
    final m = Matrix4.identity().when(
      hover: Matrix4.translationValues(0, -2, 0),
      medium: Matrix4.diagonal3Values(2, 2, 1),
    );
    final css = m.css;
    expect(isAdaptive(css), isTrue);
    expect(css, contains('matrix(1, 0, 0, 1, 0, -2)'));
    expect(css, contains('matrix(2, 0, 0, 2, 0, 0)'));
    expect(m.toString(), startsWith('Matrix4('));
  });

  test('multiplying keeps the variants', () {
    final m = Matrix4.translationValues(
      1,
      0,
      0,
    ).when(hover: Matrix4.translationValues(5, 0, 0));
    final moved = m * Matrix4.translationValues(0, 3, 0);
    expect(moved.css, contains('matrix(1, 0, 0, 1, 1, 3)'));
    expect(moved.css, contains('matrix(1, 0, 0, 1, 5, 3)'));
    final left = Matrix4.translationValues(0, 3, 0) * m;
    expect(left.css, contains('matrix(1, 0, 0, 1, 5, 3)'));
  });

  test('a variant transform is not joined to another one', () {
    final m = Matrix4.identity().when(
      hover: Matrix4.translationValues(0, -2, 0),
    );
    expect(
      composeTransforms({'transform': m.css}, {'transform': 'scale(2)'}),
      isNull,
    );
  });
}

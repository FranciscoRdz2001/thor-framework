import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

void main() {
  group('Color', () {
    test('opaque → hex, translucent → rgba', () {
      expect(const Color(0xFF4361EE).css, '#4361ee');
      expect(Color.fromRGBO(0, 0, 0, 0.5).css, 'rgba(0, 0, 0, 0.502)');
      expect(Colors.transparent.css, 'transparent');
    });

    test('variables are const and keep the fallback', () {
      const c = Color.variable(
        CssVariable('--t-primary'),
        fallback: Color(0xFF6750A4),
      );
      expect(c.css, 'var(--t-primary, #6750a4)');
    });
  });

  group('EdgeInsets', () {
    test('emits the shortest shorthand', () {
      expect(const EdgeInsets.all(8).css, '8px');
      expect(
        const EdgeInsets.symmetric(vertical: 4, horizontal: 12).css,
        '4px 12px',
      );
      expect(const EdgeInsets.fromLTRB(1, 2, 3, 4).css, '2px 3px 4px 1px');
    });
  });

  test('double.infinity maps to 100%', () {
    expect(cssPx(double.infinity), '100%');
    expect(cssPx(16), '16px');
    expect(cssPx(0.5), '0.5px');
  });

  test('BoxDecoration compiles background, border, radius and shadow', () {
    final css = BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.black12),
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(offset: Offset(0, 2), blurRadius: 8, color: Colors.black12),
      ],
    ).toCss();
    expect(css, {
      'background-color': '#ffffff',
      'border': '1px solid rgba(0, 0, 0, 0.122)',
      'border-radius': '12px',
      'box-shadow': '0px 2px 8px 0px rgba(0, 0, 0, 0.122)',
    });
  });

  test('LinearGradient converts Alignment begin/end to an angle', () {
    expect(
      const LinearGradient(colors: [Colors.black, Colors.white]).css,
      'linear-gradient(90deg, #000000, #ffffff)',
    );
    expect(
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black, Colors.white],
        stops: [0, 0.4],
      ).css,
      'linear-gradient(180deg, #000000 0%, #ffffff 40%)',
    );
  });

  test('LinearGradient over part of the box maps the stops onto that part', () {
    expect(
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [Colors.black, Colors.white],
      ).css,
      'linear-gradient(180deg, #000000 0%, #ffffff 50%)',
    );
    expect(
      const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.center,
        colors: [Colors.black, Colors.white],
      ).css,
      'linear-gradient(0deg, #000000 0%, #ffffff 50%)',
    );
    expect(
      const LinearGradient(
        begin: Alignment(0, -0.5),
        end: Alignment(0, 0.5),
        colors: [Colors.black, Colors.white],
        stops: [0, 0.5],
      ).css,
      'linear-gradient(180deg, #000000 25%, #ffffff 50%)',
    );
  });

  test('TextStyle uses unitless line-height and merges like Flutter', () {
    const base = TextStyle(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w500,
    );
    final merged = base.merge(const TextStyle(color: Colors.red, fontSize: 20));
    expect(merged.toCss(), {
      'color': '#f44336',
      'font-size': '20px',
      'font-weight': '500',
      'line-height': '1.5',
    });
  });

  test('Alignment keywords vs fractional', () {
    expect(Alignment.bottomRight.placeItems, 'end right');
    // Physical: Alignment does not flip in RTL (AlignmentDirectional does).
    expect(Alignment.centerLeft.placeItems, 'center left');
    expect(const Alignment(0.5, -0.5).isKeyword, isFalse);
    expect(const Alignment(0.5, -0.5).fractionalChildCss()['left'], '75%');
  });
}

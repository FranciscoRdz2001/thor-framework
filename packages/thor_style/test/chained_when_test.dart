import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

void main() {
  group('chained .when() is one .when()', () {
    test('EdgeInsets: each call adds its own breakpoint', () {
      final p = const EdgeInsets.symmetric(horizontal: 16)
          .when(medium: const EdgeInsets.symmetric(horizontal: 24))
          .when(large: const EdgeInsets.symmetric(horizontal: 32));
      final split = splitAdaptive({'padding': p.css});
      expect(split.base, {'padding': '0px 16px'});
      expect(split.byBreakpoint, {
        'medium': {'padding': '0px 24px'},
        'large': {'padding': '0px 32px'},
      });
      expect(
        p.css,
        const EdgeInsets.symmetric(horizontal: 16)
            .when(
              medium: const EdgeInsets.symmetric(horizontal: 24),
              large: const EdgeInsets.symmetric(horizontal: 32),
            )
            .css,
      );
    });

    test('the same key: the later call wins', () {
      final p = const EdgeInsets.all(8)
          .when(medium: const EdgeInsets.all(16))
          .when(medium: const EdgeInsets.all(24));
      final split = splitAdaptive({'padding': p.css});
      expect(split.byBreakpoint, {
        'medium': {'padding': '24px'},
      });
    });

    test('EdgeInsetsGeometry', () {
      const EdgeInsetsGeometry g = EdgeInsetsDirectional.only(start: 1);
      final p = g
          .when(medium: const EdgeInsetsDirectional.only(start: 2))
          .when(large: const EdgeInsetsDirectional.only(start: 3));
      final decl = p.toCss('padding');
      final split = splitAdaptive(decl);
      expect(
        decl.values.any((v) => v.contains('␟large␞') && v.contains('␟medium␞')),
        isTrue,
      );
      expect(split.byBreakpoint.keys, containsAll(['medium', 'large']));
    });

    test('Color and Length', () {
      final c = const Color(0xFF000000)
          .when(medium: const Color(0xFFFF0000))
          .when(large: const Color(0xFF00FF00));
      final s = splitAdaptive({'color': c.css});
      expect(s.base['color'], '#000000');
      expect(s.byBreakpoint['medium'], {'color': '#ff0000'});
      expect(s.byBreakpoint['large'], {'color': '#00ff00'});

      final l = 40.px.when(medium: 48.px).when(large: 56.px);
      final ls = splitAdaptive({'height': l.css});
      expect(ls.base['height'], '40px');
      expect(ls.byBreakpoint['medium'], {'height': '48px'});
      expect(ls.byBreakpoint['large'], {'height': '56px'});
    });

    test('BoxConstraints and BorderRadius', () {
      final k = const BoxConstraints(maxWidth: 100)
          .when(medium: const BoxConstraints(maxWidth: 200))
          .when(large: const BoxConstraints(maxWidth: 300));
      final ks = splitAdaptive(k.toCss());
      expect(ks.base['max-width'], '100px');
      expect(ks.byBreakpoint['medium'], {'max-width': '200px'});
      expect(ks.byBreakpoint['large'], {'max-width': '300px'});

      final r = BorderRadius.circular(4)
          .when(medium: BorderRadius.circular(8))
          .when(large: BorderRadius.circular(12));
      final rs = splitAdaptive({'border-radius': r.css});
      expect(rs.base['border-radius'], '4px');
      expect(rs.byBreakpoint['medium'], {'border-radius': '8px'});
      expect(rs.byBreakpoint['large'], {'border-radius': '12px'});
    });

    test('TextStyle', () {
      final t = const TextStyle(fontSize: 10)
          .when(medium: const TextStyle(fontSize: 20))
          .when(large: const TextStyle(fontSize: 30));
      final s = splitAdaptive(t.toCss());
      expect(s.base['font-size'], '10px');
      expect(s.byBreakpoint['medium'], {'font-size': '20px'});
      expect(s.byBreakpoint['large'], {'font-size': '30px'});
    });
  });
}

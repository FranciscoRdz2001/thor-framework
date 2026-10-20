// ignore_for_file: prefer_const_constructors
// Widgets that compute with the numeric sides of an inset must not drop a
// Length inset silently: an `EdgeInsetsGeometry.allLength` is not an
// `EdgeInsets` (so they cannot be given one), and the widgets that only write
// CSS take the geometry.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  setUpAll(initializeThorTests);

  const geometry = EdgeInsetsGeometry.allLength(
    Length.variable(CssVariable('--gap')),
  );

  test('SafeArea adds a Length padding to the safe area', () async {
    final html = await renderHtml(
      SafeArea(
        child: Padding(padding: geometry, child: const Text('x')),
      ),
    );
    expect(html, contains('calc(env(safe-area-inset-top) + var(--gap))'));
    expect(html, contains('calc(env(safe-area-inset-left) + var(--gap))'));
  });

  test('SafeArea with a numeric padding is unchanged', () async {
    final html = await renderHtml(
      const SafeArea(
        child: Padding(padding: EdgeInsets.all(8), child: Text('x')),
      ),
    );
    expect(html, contains('calc(env(safe-area-inset-top) + 8px)'));
  });
}

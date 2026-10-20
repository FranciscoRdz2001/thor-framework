import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  setUpAll(initializeThorTests);

  test('a role with a fluid size and em tracking publishes them', () async {
    final theme = ThemeData(
      textTheme: TextTheme(
        displayLarge: const TextStyle(
          fontSize: 40,
          fontSizeLength: Length.clamp(
            Length.px(40),
            Length.vw(5),
            Length.px(72),
          ),
          letterSpacingLength: Length.em(-0.02),
        ),
      ),
    );
    final head = headOfPage(
      await renderDocument(
        ThorApp(
          theme: theme,
          child: const Text('Hello', style: ThemeText.displayLarge),
        ),
      ),
    );
    expect(head, contains('--t-display-large-size:clamp(40px, 5vw, 72px)'));
    expect(head, contains('--t-display-large-tracking:-0.02em'));
  });
}

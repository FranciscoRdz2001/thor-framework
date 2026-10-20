@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  setUpAll(initializeThorTests);

  test('what a widget sets is rejected, naming the widget', () {
    expect(const StyleProps(padding: EdgeInsets.all(8)).widgetProps(), [
      'padding → Padding(padding:)',
    ]);
    expect(const StyleProps(opacity: 0.5).widgetProps(), ['opacity → Opacity']);
  });

  test('web-only values are Styled\'s job', () {
    expect(
      const StyleProps(
        position: BoxPosition.sticky(top: Length.zero),
        overflowY: Overflow.auto,
        zIndex: 2,
      ).widgetProps(),
      isEmpty,
    );
  });

  test('numbers that vary with .when() are allowed', () {
    expect(
      const StyleProps(
        scale: 1,
      ).when(hover: const StyleProps(scale: 1.05)).widgetProps(),
      isEmpty,
    );
    expect(
      const StyleProps(padding: EdgeInsets.all(8))
          .when(medium: const StyleProps(padding: EdgeInsets.all(16)))
          .widgetProps(),
      ['padding → Padding(padding:)'],
      reason: 'EdgeInsets varies itself: Padding(padding: …when())',
    );
  });
}

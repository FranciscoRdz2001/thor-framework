@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void _noop(Object? _) {}

Future<String> page(Widget body, {SliderThemeData? slider}) => renderDocument(
  ThorApp(
    theme: ThemeData(sliderTheme: slider),
    child: body,
  ),
);

enum Billing { monthly, yearly }

void main() {
  setUpAll(initializeThorTests);

  group('Slider value indicator', () {
    test('no theme: no bubble, the label stays the tooltip', () async {
      final html = await page(
        const Slider(value: 5, max: 10, label: '5', onChanged: _noop),
      );
      expect(html, isNot(contains('data-t-f')));
      expect(html, contains('title="5"'));
    });

    test('alwaysVisible draws a bubble that follows the thumb', () async {
      final html = await page(
        const Slider(value: 25, max: 100, label: '{}k', onChanged: _noop),
        slider: const SliderThemeData(
          showValueIndicator: ShowValueIndicator.alwaysVisible,
        ),
      );
      expect(html, contains('<span class="'));
      expect(html, contains('data-t-f="{}k"'));
      expect(html, contains('>25k</span>'));
      expect(html, contains('--f: 0.25'));
      expect(html, contains('left: calc(10px + (100% - 20px) * var(--f))'));
      expect(html, contains('opacity: 1'));
      expect(html, contains('oninput="'));
      expect(html, contains('aria-hidden="true"'));
      expect(html, isNot(contains('title=')));
    });

    test('onDrag shows it with :active or the keyboard focus', () async {
      final html = await page(
        const Slider(value: 1, max: 4, onChanged: _noop),
        slider: const SliderThemeData(
          showValueIndicator: ShowValueIndicator.onDrag,
          valueIndicatorColor: Color(0xFF112233),
        ),
      );
      expect(html, contains(':has(input:active, input:focus-visible)'));
      expect(html, contains('background-color: #112233'));
      expect(html, contains('>1</span>'));
    });

    test(
      'onlyForDiscrete follows divisions; never and disabled hide it',
      () async {
        const discrete = SliderThemeData(
          showValueIndicator: ShowValueIndicator.onlyForDiscrete,
        );
        expect(
          await page(
            const Slider(value: 0, divisions: 4, onChanged: _noop),
            slider: discrete,
          ),
          contains('data-t-f'),
        );
        expect(
          await page(
            const Slider(value: 0, onChanged: _noop),
            slider: discrete,
          ),
          isNot(contains('data-t-f')),
        );
        expect(
          await page(
            const Slider(value: 0, onChanged: _noop),
            slider: const SliderThemeData(
              showValueIndicator: ShowValueIndicator.never,
            ),
          ),
          isNot(contains('data-t-f')),
        );
        expect(
          await page(
            const Slider(value: 0, onChanged: null),
            slider: const SliderThemeData(
              showValueIndicator: ShowValueIndicator.alwaysVisible,
            ),
          ),
          isNot(contains('data-t-f')),
        );
      },
    );
  });

  test('SegmentedButton makes a pill toggle with StadiumBorder', () async {
    final html = await page(
      const SegmentedButton<Billing>(
        segments: [
          ButtonSegment(value: Billing.monthly, label: Text('Monthly')),
          ButtonSegment(value: Billing.yearly, label: Text('Yearly')),
        ],
        selected: {Billing.monthly},
        showSelectedIcon: false,
        groupPadding: EdgeInsets.all(4),
        groupColor: Color(0xFFF3F4F6),
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(StadiumBorder()),
          side: WidgetStatePropertyAll(BorderSide.none),
        ),
        selectedStyle: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(Color(0xFF4F46E5)),
          foregroundColor: WidgetStatePropertyAll(Color(0xFFFFFFFF)),
          shape: WidgetStatePropertyAll(StadiumBorder()),
        ),
        onSelectionChanged: _noop,
      ),
    );
    expect(html, contains('border-radius: 9999px'));
    expect(
      html,
      contains(
        'background-color: #4f46e5; color: #ffffff; border-radius: 9999px',
      ),
    );
    expect(html, contains('background-color: #f3f4f6'));
  });
}

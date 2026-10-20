@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(CrossFadeState state) => renderDocument(
  ThorApp(
    child: AnimatedCrossFade(
      duration: const Duration(seconds: 1),
      reverseDuration: const Duration(milliseconds: 100),
      crossFadeState: state,
      firstChild: const Text('A'),
      secondChild: const Text('B'),
    ),
  ),
);

void main() {
  test('showing the first child fades with reverseDuration', () async {
    final html = await page(CrossFadeState.showFirst);
    expect(html, contains('transition: opacity 100ms linear'));
    expect(html, contains('visibility 0s linear 100ms'));
    expect(html, isNot(contains('1000ms')));
  });

  test('showing the second child fades with duration', () async {
    final html = await page(CrossFadeState.showSecond);
    expect(html, contains('transition: opacity 1000ms linear'));
    expect(html, contains('visibility 0s linear 1000ms'));
  });
}

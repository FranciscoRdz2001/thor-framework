@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  setUpAll(() => initializeThorTests(compactHtml: false));

  test('the frame scales against a stage that is its own element', () async {
    final html = await renderDocument(
      ThorApp(
        child: Styled(
          style: const StyleProps(containerType: ContainerType.size),
          child: SizedBox.expand(
            child: Styled(
              style: StyleProps(
                transformOrigin: Alignment.topLeft,
                scaleRatio: Ratio.min([
                  const Ratio.value(1),
                  Ratio.of(100.cqh, 844.px),
                ]),
              ),
              child: const SizedBox(
                width: 390,
                height: 844,
                child: Text('device'),
              ),
            ),
          ),
        ),
      ),
    );
    final head = html.substring(0, html.indexOf('</head>'));
    final body = html.substring(html.indexOf('<body'));
    expect(body, isNot(contains('style="')));
    String classOf(String declaration) {
      final rule = RegExp(r'\.(t\w+)\{[^}]*' + RegExp.escape(declaration));
      final match = rule.firstMatch(head);
      expect(match, isNotNull, reason: 'no rule writes $declaration');
      return match![1]!;
    }

    final stage = classOf('container-type: size');
    final frame = classOf('scale: min(1, tan(atan2(100cqh, 844px)))');
    // cq units measure an ancestor container, never the element itself.
    expect(stage, isNot(frame));
    final stageAt = body.indexOf('class="$stage"');
    final frameAt = body.indexOf('class="$frame"');
    expect(stageAt, isNonNegative);
    expect(frameAt, greaterThan(stageAt));
  });

  test('scaleRatio is web-only: Styled does not point it to Transform', () {
    final ratio = StyleProps(scaleRatio: Ratio.of(100.cqw, 390.px));
    expect(ratio.widgetProps(), isEmpty);
    expect(const StyleProps(scale: 2).widgetProps(), [
      'scale/offset/turns → Transform',
    ]);
  });

  test('scaleRatio writes a scale the browser computes', () {
    final css = StyleProps(
      containerType: ContainerType.size,
      scaleRatio: Ratio.min([
        const Ratio.value(1),
        Ratio.of(100.cqh, 844.px),
        Ratio.of(100.cqw, 390.px),
      ]),
    ).toCss();
    expect(
      css['scale'],
      'min(1, tan(atan2(100cqh, 844px)), tan(atan2(100cqw, 390px)))',
    );
    expect(css['container-type'], 'size');
  });

  test('scaleRatio wins over scale', () {
    final css = const StyleProps(
      scale: 2,
      scaleRatio: Ratio.value(0.5),
    ).toCss();
    expect(css['scale'], '0.5');
  });
}

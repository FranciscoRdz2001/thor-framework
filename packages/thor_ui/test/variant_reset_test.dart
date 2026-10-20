@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

/// The rules of the page's `<style>` as text.
Future<String> _css(Widget child) async {
  final html = await renderDocument(ThorApp(child: child));
  final start = html.indexOf('id="thor-styles">');
  final style = html.substring(start, html.indexOf('</style>', start));
  return style.replaceAll(RegExp(r'\s+'), ' ');
}

/// A `.when()` variant that changes the `position` drops the offsets the
/// base set (`left: 40px` under `sticky`): a variant only carries what it
/// names, but the position is one value, so the variant replaces it whole.
void main() {
  setUpAll(() => initializeThorTests(compactHtml: false));

  Future<String> box(StyleProps style) =>
      _css(Styled(style: style, child: const SizedBox(width: 10)));

  test('a variant with another position resets the base offsets', () async {
    final css = await box(
      StyleProps(
        position: BoxPosition.fixed(left: 40.px, top: 10.px),
      ).when(
        medium: StyleProps(position: BoxPosition.sticky(top: 0.px)),
      ),
    );
    expect(css, contains('position: fixed'));
    expect(css, contains('left: 40px'));
    final md = css.substring(css.indexOf('@media'));
    expect(md, contains('position: sticky'));
    expect(md, contains('top: 0'));
    expect(md, contains('left: auto'));
    expect(md, isNot(contains('right:')));
    expect(md, isNot(contains('bottom:')));
  });

  test('an offset the variant names is not reset', () async {
    final css = await box(
      StyleProps(position: BoxPosition.fixed(left: 40.px)).when(
        medium: StyleProps(position: BoxPosition.sticky(left: 8.px)),
      ),
    );
    final md = css.substring(css.indexOf('@media'));
    expect(md, contains('left: 8px'));
    expect(md, isNot(contains('left: auto')));
  });

  test('a variant that does not touch the position keeps the base', () async {
    final css = await box(
      StyleProps(
        position: BoxPosition.fixed(left: 40.px),
      ).when(medium: const StyleProps(zIndex: 5)),
    );
    final md = css.substring(css.indexOf('@media'));
    expect(md, contains('z-index: 5'));
    expect(md, isNot(contains('left:')));
    expect(md, isNot(contains('position:')));
  });

  test('a base without position has nothing to reset', () async {
    final css = await box(
      const StyleProps().when(
        medium: StyleProps(position: BoxPosition.sticky(top: 0.px)),
      ),
    );
    expect(css, isNot(contains('auto')));
    expect(css, contains('position: sticky'));
  });

  test('every offset of the base is reset, state variants too', () async {
    final css = await box(
      StyleProps(
        position: BoxPosition.fixed(
          top: 1.px,
          right: 2.px,
          bottom: 3.px,
          left: 4.px,
        ),
      ).when(hover: const StyleProps(position: BoxPosition.relative())),
    );
    final hover = css.substring(css.indexOf(':hover'));
    for (final side in ['top', 'right', 'bottom', 'left']) {
      expect(hover, contains('$side: auto'), reason: side);
    }
    expect(hover, contains('position: relative'));
  });

  test('offsets a smaller variant set are reset by a later one', () async {
    // base: no offsets; md: absolute(left); lg: relative(): the `left` of md
    // would carry into lg (mobile-first cascade) and shift the box.
    final css = await box(
      const StyleProps(position: BoxPosition.relative()).when(
        medium: StyleProps(position: BoxPosition.absolute(left: 5.px)),
        expanded: const StyleProps(position: BoxPosition.relative()),
      ),
    );
    final lg = css.substring(css.lastIndexOf('@media'));
    expect(lg, contains('position: relative'));
    expect(lg, contains('left: auto'));
  });

  test('a state variant resets what a breakpoint set', () async {
    final css = await box(
      const StyleProps(position: BoxPosition.relative()).when(
        medium: StyleProps(position: BoxPosition.absolute(top: 5.px)),
        hover: const StyleProps(position: BoxPosition.relative()),
      ),
    );
    final hover = css.substring(css.indexOf(':hover'));
    expect(hover, contains('top: auto'));
  });

  test('multiple breakpoints each with other offsets', () async {
    final css = await box(
      StyleProps(position: BoxPosition.fixed(left: 1.px)).when(
        medium: StyleProps(position: BoxPosition.fixed(top: 2.px)),
        expanded: StyleProps(position: BoxPosition.absolute(right: 3.px)),
        large: StyleProps(position: BoxPosition.sticky(bottom: 4.px)),
      ),
    );
    final lg = css.substring(css.lastIndexOf('@media'));
    // top and left were reset from `sm` up already: lg only resets `right`.
    expect(lg, contains('right: auto'));
    expect(lg, isNot(contains('bottom: auto')));
    expect(css, contains('top: auto'));
    expect(css, contains('left: auto'));
  });
}

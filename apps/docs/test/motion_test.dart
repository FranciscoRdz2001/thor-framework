// The frame's page-change rules (lib/core/theme/motion.dart): what the
// browser captures as the sidebar, and that its group never travels.
import 'package:docs/core/theme/motion.dart';
import 'package:test/test.dart';

final _css = motionStyles.map((r) => r.toCss()).join('\n');

/// [text] without its whitespace (the debug CSS is indented).
String _flat(String text) => text.replaceAll(RegExp(r'\s+'), '');

void main() {
  test('from the column width the sticky list is the sidebar group', () {
    // The column is as tall as the page: placed by its top, a scrolled
    // page's snapshot flew in from far above the window.
    final flat = _flat(_css);
    expect(
      flat,
      contains(
        '@mediascreenand(min-width:1024px){'
        ':where(#studio-sidebar){view-transition-name:none;}'
        ':where(#studio-sidebar[data-studio-sidebar-scroll]){'
        'view-transition-name:docs-nav;}',
      ),
    );
  });

  test('the drawer stays the sidebar group below the column width', () {
    expect(
      _flat(_css),
      contains(':where(#studio-sidebar){view-transition-name:docs-nav;}'),
    );
  });

  test('the sidebar group keeps the page timing and moves nothing', () {
    final flat = _flat(_css);
    expect(flat, contains('@keyframesdocs-still{}'));
    expect(
      flat,
      matches(
        RegExp(
          r'::view-transition-group\(docs-nav\)\{animation:docs-still150ms',
        ),
      ),
    );
  });
}

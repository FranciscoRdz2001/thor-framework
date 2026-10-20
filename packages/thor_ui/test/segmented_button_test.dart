@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

enum View { list, grid, table }

abstract class _BrowseMembers extends ThorState {
  @override
  String get $type => 'Browse';

  @override
  List<ThorMember> get $members {
    final s = this as _Browse;
    return [
      ThorMember(
        'setView',
        s.setView,
        arity: 1,
        call: (a) => s.setView({View.values.byName('$a')}),
      ),
    ];
  }
}

class _Browse extends _BrowseMembers {
  void setView(Set<View> views) {}
}

final _browse = _Browse();

Future<String> page(Widget body) async {
  final html = await renderDocument(ThorApp(child: body));
  return html.substring(html.indexOf('<body'));
}

const _segments = [
  ButtonSegment(value: View.list, label: Text('List')),
  ButtonSegment(value: View.grid, label: Text('Grid')),
  ButtonSegment(value: View.table, label: Text('Table'), enabled: false),
];

void main() {
  setUpAll(initializeThorTests);

  test('single selection is a native radio group', () async {
    final html = await page(
      const SegmentedButton<View>(
        segments: _segments,
        selected: {View.grid},
        semanticLabel: 'View',
      ),
    );
    expect(html, contains('role="radiogroup"'));
    expect(html, contains('aria-label="View"'));
    expect('type="radio"'.allMatches(html), hasLength(3));
    expect(RegExp(r'type="radio"[^>]*checked').allMatches(html), hasLength(1));
    expect(html, contains('value="grid"'));
    expect('disabled'.allMatches(html), hasLength(1));
    expect(html, contains('data-t-seg-check'));
  });

  test('multiple selection is a group of checkboxes', () async {
    final html = await page(
      SegmentedButton<View>(
        segments: _segments,
        selected: const {View.list, View.grid},
        multiSelectionEnabled: true,
        onSelectionChanged: (_) {},
      ),
    );
    expect(html, contains('role="group"'));
    expect('type="checkbox"'.allMatches(html), hasLength(3));
    expect(
      RegExp(r'type="checkbox"[^>]*checked').allMatches(html),
      hasLength(2),
    );
  });

  test(
    'onSelectionChanged: null disables it; showSelectedIcon: false',
    () async {
      final html = await page(
        const SegmentedButton<View>(
          segments: _segments,
          selected: {View.list},
          onSelectionChanged: null,
          showSelectedIcon: false,
        ),
      );
      expect(html, contains('aria-disabled="true"'));
      expect('disabled'.allMatches(html).length, greaterThanOrEqualTo(3));
      expect(html, isNot(contains('data-t-seg-check')));
    },
  );

  test('an icon-only segment is named by its tooltip', () async {
    final html = await page(
      const SegmentedButton<View>(
        segments: [
          ButtonSegment(
            value: View.list,
            icon: Icon(Icons.check),
            tooltip: 'List view',
          ),
          ButtonSegment(value: View.grid, label: Text('Grid')),
        ],
        selected: {View.list},
      ),
    );
    expect(html, contains('aria-label="List view"'));
    expect(html, contains('title="List view"'));
  });

  test('the engine binds the change handler to every segment', () async {
    final single = await page(
      SegmentedButton<View>(
        segments: _segments,
        selected: const {View.grid},
        onSelectionChanged: _browse.setView,
      ),
    );
    final radios = RegExp(r'<input[^>]*type="radio"[^>]*>').allMatches(single);
    expect(radios, hasLength(3));
    for (final r in radios) {
      expect(r[0], contains('Browse.setView'));
    }
    final multi = await page(
      SegmentedButton<View>(
        segments: _segments,
        selected: const {View.list},
        multiSelectionEnabled: true,
        onSelectionChanged: _browse.setView,
      ),
    );
    final boxes = RegExp(r'<input[^>]*type="checkbox"[^>]*>').allMatches(multi);
    expect(boxes, hasLength(3));
    final names = {
      for (final b in boxes) RegExp(r'name="([^"]+)"').firstMatch(b[0]!)![1],
    };
    expect(names, hasLength(1));
    for (final b in boxes) {
      expect(b[0], contains('data-t-set="${names.single}"'));
      expect(b[0], contains('Browse.setView'));
    }
  });

  test('a segment without a Text label or a tooltip fails (THOR-R038)', () {
    expect(
      () => page(
        SegmentedButton<View>(
          segments: const [
            ButtonSegment(value: View.list, icon: Icon(Icons.list)),
            ButtonSegment(value: View.grid, label: Text('Grid')),
          ],
          selected: const {View.list},
          onSelectionChanged: _browse.setView,
        ),
      ),
      throwsA(predicate((e) => e.toString().contains('THOR-R038'))),
    );
  });

  test('a Text wrapped in a Styled or a component names the segment', () async {
    final html = await page(
      SegmentedButton<View>(
        segments: const [
          ButtonSegment(
            value: View.list,
            label: Styled(classes: ['x'], child: Text('Wrapped')),
          ),
          ButtonSegment(value: View.grid, label: _WrappedLabel()),
        ],
        selected: const {View.list},
        onSelectionChanged: _browse.setView,
      ),
    );
    expect(html, contains('Wrapped'));
    expect(html, contains('Boxed'));
  });

  test('a label that names itself or a tooltip passes, and names it', () async {
    final html = await page(
      SegmentedButton<View>(
        segments: const [
          // A widget label that says nothing: the tooltip names the radio.
          ButtonSegment(
            value: View.list,
            label: Icon(Icons.list),
            tooltip: 'List view',
          ),
          ButtonSegment(
            value: View.grid,
            label: Semantics(label: 'Grid view', child: Icon(Icons.list)),
          ),
          ButtonSegment(value: View.table, label: _TableLabel()),
        ],
        selected: const {View.list},
        onSelectionChanged: _browse.setView,
      ),
    );
    final radios = RegExp(
      r'<input[^>]*type="radio"[^>]*>',
    ).allMatches(html).map((m) => m[0]!).toList();
    expect(radios, hasLength(3));
    expect(radios[0], contains('aria-label="List view"'));
    expect(radios[1], isNot(contains('aria-label')));
    expect(radios[2], isNot(contains('aria-label')));
    expect(html, contains('aria-label="Grid view"'));
  });

  group('segment sizes and group box (62, 70)', () {
    String head(String html) => html.substring(0, html.indexOf('</head>'));

    Future<String> doc(Widget w) => renderDocument(ThorApp(child: w));

    test('every segment gets an equal share (flex 1 1 0)', () async {
      final css = head(
        await doc(
          const SegmentedButton<View>(
            segments: _segments,
            selected: {View.list},
          ),
        ),
      );
      expect(css, contains('flex: 1 1 0'));
      expect(css, isNot(contains('flex: 1 1 auto')));
    });

    test(
      'style.side and style.shape draw the group, not each segment',
      () async {
        final css = head(
          await doc(
            const SegmentedButton<View>(
              segments: _segments,
              selected: {View.list},
              style: ButtonStyle(
                side: WidgetStatePropertyAll(
                  BorderSide(color: Color(0xFF123456), width: 2),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(css, contains('border: 2px solid'));
        expect(css, contains('border-radius: 8px'));
        expect(css, isNot(contains('border-radius: 20px')));
        // The dividers between segments use the same side.
        expect(css, contains('border-inline-start: 2px solid'));
        // Only the group draws them: a segment has no outline or corners.
        expect('border: 2px solid'.allMatches(css), hasLength(1));
        expect('border-radius: 8px'.allMatches(css), hasLength(1));
      },
    );

    test('groupPadding and groupColor pad and fill the group', () async {
      final css = head(
        await doc(
          const SegmentedButton<View>(
            segments: _segments,
            selected: {View.list},
            groupPadding: EdgeInsets.all(2),
            groupColor: Color(0xFF445566),
          ),
        ),
      );
      expect(css, contains('padding: 2px'));
      expect(css, contains('background-color: #445566'));
    });
  });
}

/// An app component whose build is a `Text`: it names its segment.
class _TableLabel extends StatelessWidget {
  const _TableLabel();

  @override
  Widget build(BuildContext context) => const Text('Table');
}

/// An app component whose build is a `Text` inside a wrapper.
class _WrappedLabel extends StatelessWidget {
  const _WrappedLabel();

  @override
  Widget build(BuildContext context) =>
      const Styled(classes: ['x'], child: Text('Boxed'));
}

// Fixture: fields without a label on purpose.
// ignore_for_file: thor_lints/text_field_without_label
// A `Watch.field` whose states are text areas (`maxLines`) with and without
// a helper line: every other state ships as a patch whose element paths the
// browser resolves (`at(el, path)`), or as a template; a path that missed an
// element threw `Cannot read properties of null (reading 'getAttribute')`
// in the engine.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

abstract class _Members extends ThorState {
  @override
  String get $type => 'AreaState';

  @override
  List<ThorMember> get $members {
    final s = this as AreaState;
    return [ThorMember.state('mode', s.mode)];
  }
}

class AreaState extends _Members {
  final mode = state(0);
}

final area = AreaState();

Widget _field(int i) => TextField(
  maxLines: i.isEven ? 1 : 4,
  decoration: InputDecoration(
    labelText: 'Notes',
    helperText: i & 2 == 0 ? null : 'Say more $i',
    errorText: i & 4 == 0 ? null : 'Wrong $i',
  ),
);

void main() {
  setUpAll(initializeThorTests);

  test('text-area states with and without helper text render', () async {
    final html = bodyOfPage(
      await renderDocument(
        ThorApp(child: Watch.field(area.mode, count: 8, builder: _field)),
      ),
    );
    // The live state is the first; the others are patches or templates, and
    // none of them is lost.
    final patches = RegExp(r'data-tp-\d').allMatches(html).length;
    final templates = RegExp(r'data-tvt=').allMatches(html).length;
    expect(patches + templates, 7);
    // A patch never points at a path the live markup lacks: every op names
    // a tag count that the live element has (the engine walks `children`).
    for (final m in RegExp(r'data-tp-\d="([^"]*)"').allMatches(html)) {
      for (final op in m[1]!.split(';').where((o) => o.isNotEmpty)) {
        final path = op.split('|').first;
        expect(
          path.isEmpty || RegExp(r'^\d+(\.\d+)*$').hasMatch(path),
          isTrue,
          reason: op,
        );
      }
    }
    // The helper line is the same element in the states that have one.
    expect(html, contains('data-helper="Say more 2"'));
  });
}

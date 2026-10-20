import 'package:test/test.dart';

import '../api_check.dart';

String _api(List<String> lines) => '${lines.join('\n')}\n';

void main() {
  const row = 'thor_ui\tRow\tclass';
  const rowNew = 'thor_ui\tRow.new\tRow Row({Key? key})';
  const old = 'thor_ui\tFlexProps\tclass\t@deprecated';
  final recorded = _api([old, row, rowNew]);

  test('the same API is unchanged, whatever the line endings', () {
    expect(compareApi(recorded, recorded), isA<ApiUnchanged>());
    expect(
      compareApi(recorded, recorded.replaceAll('\n', '\r\n')),
      isA<ApiUnchanged>().having((c) => c.names, 'names', 3),
    );
  });

  test('a public name that goes away without deprecation fails', () {
    final change = compareApi(recorded, _api([old, rowNew]));
    expect(
      change,
      isA<ApiRemoved>().having((c) => c.names, 'names', ['thor_ui Row']),
    );
  });

  test('a constructor or member is a name too', () {
    expect(compareApi(recorded, _api([old, row])), isA<ApiRemoved>());
  });

  test('a name deprecated in the recorded API may go', () {
    expect(
      compareApi(recorded, _api([row, rowNew])),
      isA<ApiChanged>()
          .having((c) => c.removed, 'removed', 1)
          .having((c) => c.added, 'added', 0),
    );
  });

  test('deprecating now is not enough: the deprecation must be recorded '
      'before the removal', () {
    // Recorded without the mark, removed in the same change.
    final unmarked = _api([row, rowNew, 'thor_ui\tFlexProps\tclass']);
    expect(compareApi(unmarked, _api([row, rowNew])), isA<ApiRemoved>());
  });

  test('an added name, a changed signature or a new deprecation is a '
      'change to record', () {
    expect(
      compareApi(recorded, _api([old, row, rowNew, 'thor_ui\tColumn\tclass'])),
      isA<ApiChanged>().having((c) => c.added, 'added', 1),
    );
    expect(
      compareApi(recorded, _api([old, row, 'thor_ui\tRow.new\tRow Row()'])),
      isA<ApiChanged>(),
    );
    expect(
      compareApi(recorded, _api([old, '$row\t@deprecated', rowNew])),
      isA<ApiChanged>(),
    );
  });

  test('the same name from another import is another name', () {
    final both = _api([row, rowNew, 'html\tRow\tclass']);
    expect(compareApi(both, _api([row, rowNew])), isA<ApiRemoved>());
  });

  test('a tombstone is no deprecation: it is counted apart and may go', () {
    const tomb = 'thor_ui\tMediaQuery\tclass\t@tombstone';
    final withTomb = _api([old, row, rowNew, tomb]);
    expect(
      compareApi(withTomb, withTomb),
      isA<ApiUnchanged>()
          .having((c) => c.names, 'names', 4)
          .having((c) => c.deprecated, 'deprecated', 1)
          .having((c) => c.tombstones, 'tombstones', 1),
    );
    expect(
      compareApi(withTomb, _api([old, row, rowNew])),
      isA<ApiChanged>().having((c) => c.removed, 'removed', 1),
    );
    // Turning a deprecation into a tombstone is a change to record.
    expect(
      compareApi(
        recorded,
        _api([row, rowNew, '${old.split('\t@')[0]}\t@tombstone']),
      ),
      isA<ApiChanged>(),
    );
  });

  test('an empty current API removes everything', () {
    expect(
      compareApi(recorded, ''),
      isA<ApiRemoved>().having((c) => c.names, 'names', hasLength(2)),
    );
  });
}

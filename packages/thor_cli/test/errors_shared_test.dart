// The CLI's error helper is thor_style's, not a copy that can drift.
import 'package:test/test.dart';
import 'package:thor_cli/src/errors.dart' as cli;
import 'package:thor_style/errors.dart' as style;

void main() {
  test('thorError and thorErrorsUrl are the shared ones', () {
    // The same function, not an equal copy: tear-offs of one top-level
    // function are identical, of two copies are not.
    expect(identical(cli.thorError, style.thorError), isTrue);
    expect(cli.thorErrorsUrl, style.thorErrorsUrl);
    expect(
      cli.thorError('THOR-B010', 'no cwebp'),
      style.thorError('THOR-B010', 'no cwebp'),
    );
  });
}

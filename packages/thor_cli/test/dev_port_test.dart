@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_cli/src/commands/dev.dart' show devPort;
import 'package:thor_cli/src/run.dart' show ThorException;

void main() {
  test('--port wins over THOR_DEV_PORT', () {
    expect(devPort('5000', {'THOR_DEV_PORT': '4700'}, {}), 5000);
  });

  test('the app .env sets the default port', () {
    expect(devPort(null, {'THOR_DEV_PORT': '4700'}, {}), 4700);
  });

  test('the real environment wins over the .env, like for any variable', () {
    expect(
      devPort(null, {'THOR_DEV_PORT': '4700'}, {'THOR_DEV_PORT': '4800'}),
      4800,
    );
  });

  test('without any of them: 4300', () {
    expect(devPort(null, {}, {}), 4300);
    expect(devPort(null, {'THOR_DEV_PORT': ' '}, {}), 4300);
  });

  test('a bad THOR_DEV_PORT names the variable', () {
    expect(
      () => devPort(null, {'THOR_DEV_PORT': 'abc'}, {}),
      throwsA(
        isA<ThorException>().having(
          (e) => e.message,
          'message',
          contains('THOR_DEV_PORT'),
        ),
      ),
    );
  });
}

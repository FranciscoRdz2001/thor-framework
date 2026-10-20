import 'package:test/test.dart';
import 'package:thor_cli/thor_cli.dart';

void main() {
  group('a bare --host means every interface', () {
    test('alone or last', () {
      expect(expandBareHost(['dev', '--host']), ['dev', '--host=0.0.0.0']);
    });

    test('before another option', () {
      expect(expandBareHost(['dev', '--host', '--port', '5000']), [
        'dev',
        '--host=0.0.0.0',
        '--port',
        '5000',
      ]);
    });

    test('with an address, in either form, it is left alone', () {
      expect(expandBareHost(['dev', '--host', '192.168.1.4']), [
        'dev',
        '--host',
        '192.168.1.4',
      ]);
      expect(expandBareHost(['dev', '--host=::']), ['dev', '--host=::']);
    });

    test('only for thor dev', () {
      expect(expandBareHost(['preview', '--host']), ['preview', '--host']);
    });
  });

  group('thor dev options', () {
    final dev = thorRunner().commands['dev']!;

    test('no --host: the loopback only', () {
      expect(dev.argParser.parse([])['host'], isNull);
      expect(dev.argParser.parse([])['allowed-host'], isEmpty);
    });

    test('--host and --allowed-host (repeatable)', () {
      final r = dev.argParser.parse([
        '--host=0.0.0.0',
        '--allowed-host',
        'a.test',
        '--allowed-host=.b.test',
      ]);
      expect(r['host'], '0.0.0.0');
      expect(r['allowed-host'], ['a.test', '.b.test']);
    });

    test('the runner parses a bare --host', () {
      final r = thorRunner().parse(['dev', '--host']);
      expect(r.command!['host'], '0.0.0.0');
    });
  });
}

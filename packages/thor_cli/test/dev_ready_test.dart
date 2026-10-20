// `thor dev` says ready only when the app runs.
import 'package:test/test.dart';
import 'package:thor_cli/src/commands/dev.dart' show devNotRunning;
import 'package:thor_cli/src/dev/overlay.dart';
import 'package:thor_cli/src/dev_proxy.dart';

void main() {
  group('devNotRunning', () {
    test('nothing wrong: ready', () {
      expect(devNotRunning(null), isNull);
    });

    test('an app that exited says so with its first line', () {
      expect(
        devNotRunning(
          'The app exited with code 254 before listening.\n'
          'lib/a.dart:3:1: Error: Expected a declaration.',
        ),
        'The app exited with code 254 before listening.',
      );
    });

    test('a failed build step is not ready either, and says which', () {
      expect(
        devNotRunning(null, error: 'Engine: Expected ;'),
        'Engine: Expected ;',
      );
      expect(devNotRunning(''), 'it did not start');
    });
  });

  group('DevProxy failure and hasErrors', () {
    late DevProxy proxy;
    setUp(() {
      proxy = DevProxy(
        upstream: 1,
        sources: SourceMap(appDir: '/app', packages: const {}),
      );
    });

    test('failed() and ready() move failure', () {
      expect(proxy.failure, isNull);
      proxy.failed('boom');
      expect(proxy.failure, 'boom');
      proxy.ready();
      expect(proxy.failure, isNull);
    });

    test('an error problem counts, a warning does not', () {
      expect(proxy.hasErrors, isFalse);
      proxy.problem('codegen', 'Code generation', 'lib/a.dart:1:1: Warning: w');
      expect(proxy.hasErrors, isFalse);
      proxy.problem('engine', 'Engine', 'lib/a.dart:1:1: Error: e');
      expect(proxy.hasErrors, isTrue);
      expect(proxy.firstError, startsWith('Engine'));
      proxy.clearProblem('engine');
      expect(proxy.hasErrors, isFalse);
      expect(proxy.firstError, isNull);
    });
  });
}

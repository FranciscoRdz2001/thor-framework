import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_cli/src/stop_signals.dart';

void main() {
  test('POSIX stops on Ctrl-C, kill and the terminal closing', () {
    expect(stopSignals(windows: false), [
      ProcessSignal.sigint,
      ProcessSignal.sigterm,
      ProcessSignal.sighup,
    ]);
  });

  test('Windows watches only what Dart delivers there (not verified on '
      'Windows)', () {
    expect(stopSignals(windows: true), [ProcessSignal.sigint]);
  });

  test('the platform default can be watched here', () async {
    for (final s in stopSignals()) {
      final sub = s.watch().listen((_) {});
      await sub.cancel();
    }
  });
}

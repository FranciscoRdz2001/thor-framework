/// `tool/thor ratchet [--update]`: fails when a package or app has more
/// `// ignore: thor_lints/…` comments or `raw:` arguments than the recorded
/// baseline (`tool/ratchet_baseline.txt`). See `tool/ratchet_count.dart`.
///
/// `--update` rewrites the baseline, and only to lower it: it refuses while
/// any count is above the recorded one.
library;

import 'dart:io';

import 'ratchet_count.dart';

const _baselineFile = 'tool/ratchet_baseline.txt';

Future<void> main(List<String> args) async {
  final update = args.contains('--update');
  final root = Directory.current;
  final baselineFile = File(_baselineFile);
  final baseline = baselineFile.existsSync()
      ? parseBaseline(baselineFile.readAsStringSync())
      : <String, Map<String, int>>{};
  final current = countRepo(root);
  final (:rose, :fell) = compareRatchet(baseline, current);

  if (rose.isNotEmpty && !(update && !baselineFile.existsSync())) {
    stderr.writeln(
      'More CSS escape hatches than the baseline '
      '(an `// ignore: thor_lints/…` or a `raw:`):',
    );
    for (final change in rose) {
      stderr.writeln('  $change');
    }
    stderr.writeln(
      'Use the typed value instead (StyleProps fields, Transition, '
      'CssAnimation, Length.maxContent…). The baseline never goes up.',
    );
    exit(1);
  }

  if (update) {
    // (A missing baseline is created from the current counts.)
    final created = !baselineFile.existsSync();
    baselineFile.writeAsStringSync(formatBaseline(current));
    stdout.writeln(
      created
          ? 'Baseline recorded.'
          : fell.isEmpty
          ? 'Baseline unchanged.'
          : 'Baseline lowered: ${fell.join('; ')}',
    );
    return;
  }
  if (fell.isNotEmpty) {
    stdout.writeln(
      'Lower the baseline with `tool/thor ratchet --update`: '
      '${fell.join('; ')}',
    );
  }
  final total = {
    for (final m in metrics)
      m: current.values.fold<int>(0, (sum, c) => sum + (c[m] ?? 0)),
  };
  stdout.writeln(
    'Escape hatches within the baseline '
    '(${total['ignores']} ignores, ${total['raw']} raw).',
  );
}

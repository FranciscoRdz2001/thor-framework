import 'package:thor_ui/thor_ui.dart';

import '../../../core/repositories/lab_repository.dart';

/// The lab page's state: every way a server call can end. `rows` and
/// `remove` show the queue (`remove.run.withArg('a')` on each row) and
/// `invalidates`; `slow` and `hang` their `timeout:`; the rest the kinds
/// and the messages of the errors.
class LabState extends ThorState {
  final rows = query(labRepository.rows);
  final slow = queryWith(
    labRepository.slow,
    arg: 0,
    timeout: const Duration(milliseconds: 600),
  );
  final denied = query(labRepository.denied);
  final broken = query(labRepository.broken);
  final plain = query(labRepository.plain);

  final remove = commandWith(
    labRepository.remove,
    invalidates: (LabState s) => [s.rows],
  );
  final reset = command(labRepository.reset);
  final hang = command(
    labRepository.hang,
    timeout: const Duration(milliseconds: 400),
  );
  final deny = command(labRepository.deny);
  final throttle = command(labRepository.throttle);

  String rowsText() =>
      'filas: ${(rows.data.value ?? const <String>[]).join(',')}';
  bool removing() => remove.pending.value;
  bool removingRow(String id) => remove.pendingFor(id);
  String removeError() => remove.error.value ?? '';

  String slowText() {
    final v = slow.data.value;
    return v == null ? 'valor -' : 'valor $v';
  }

  void slowFor(int ms) => slow.setArg(ms);
  bool slowBusy() => slow.loading.value;
  String slowError() => slow.error.value ?? '';
  String slowKind() => slow.errorKind.value?.name ?? '';

  String deniedError() => denied.error.value ?? '';
  String deniedKind() => denied.errorKind.value?.name ?? '';
  String brokenError() => broken.error.value ?? '';
  String brokenKind() => broken.errorKind.value?.name ?? '';
  String plainError() => plain.error.value ?? '';
  String plainKind() => plain.errorKind.value?.name ?? '';

  bool hanging() => hang.pending.value;
  String hangError() => hang.error.value ?? '';
  String hangKind() => hang.errorKind.value?.name ?? '';
  String denyError() => deny.error.value ?? '';
  String denyKind() => deny.errorKind.value?.name ?? '';
  String throttleError() => throttle.error.value ?? '';
  String throttleKind() => throttle.errorKind.value?.name ?? '';

  /// Removes rows `a` and `b` one after the other, the way a method would:
  /// waits for each answer.
  Future<void> removeAB() async {
    final done = await remove.run('a');
    if (done != null) await remove.run('b');
  }
}

/// The lab page's state.
final lab = LabState();

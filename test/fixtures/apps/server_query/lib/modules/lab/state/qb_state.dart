import 'package:thor_ui/thor_ui.dart';

import '../../../core/repositories/lab_repository.dart';

/// The `/qb` page's state: queries that answer nothing, fail while their
/// argument moves, and are drawn by several `QueryBuilder`s at once.
class QbState extends ThorState {
  final maybe = queryWith(labRepository.maybe, arg: 3);
  final flaky = queryWith(labRepository.flaky, arg: 0);
  final rows = query(labRepository.rows);

  void maybeFor(int n) => maybe.setArg(n);
  void flakyFor(int n) => flaky.setArg(n);

  String maybeText() =>
      'maybe=${maybe.data.value == null ? '-' : maybe.data.value.toString()}';
  String flakyText() =>
      'flaky=${flaky.data.value == null ? '-' : flaky.data.value.toString()}';
  List<String> rowList() => rows.data.value ?? const <String>[];
  String rowKey(String id) => id;
  String rowText(String id) => 'fila $id';
}

/// The `/qb` page's state.
final qb = QbState();

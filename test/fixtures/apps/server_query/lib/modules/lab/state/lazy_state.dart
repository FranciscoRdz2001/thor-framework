import 'package:thor_ui/thor_ui.dart';

import '../../../core/repositories/lab_repository.dart';

/// The `/lazy` page's state: queries the browser runs (`ssr: false`), so the
/// page never waits for them.
class LazyState extends ThorState {
  final rows = query(labRepository.lazyRows, ssr: false);
  final echo = queryWith(labRepository.lazyEcho, arg: 'a', ssr: false);
  final broken = query(labRepository.lazyBroken, ssr: false);

  List<String> rowList() => rows.data.value ?? const <String>[];
  String rowKey(String id) => id;
  String rowText(String id) => 'fila $id';
  String echoText() => echo.data.value ?? 'echo -';
  void echoFor(String q) => echo.setArg(q);
}

/// The `/lazy` page's state.
final lazy = LazyState();

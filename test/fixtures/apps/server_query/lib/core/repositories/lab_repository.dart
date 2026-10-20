import 'package:thor_ui/router.dart';

/// A public lab for the errors and the timing of server calls: what each
/// method does is what a test or the browser check needs. Nothing here
/// touches a database; the rows live in memory, per isolate.
class LabRepository {
  LabRepository();

  final _rows = <String>['a', 'b', 'c', 'd'];

  /// Every call the commands ran, in the order they reached the server.
  final log = <String>[];

  /// The rows still there.
  Future<List<String>> rows() async => [..._rows];

  /// Waits [ms] milliseconds (a slow backend: past the state's `timeout:`
  /// the browser gives up) and answers them.
  Future<int> slow(int ms) async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    return ms;
  }

  /// A query the visitor may not read (`403` with its own message).
  Future<int> denied() async =>
      throw const HttpError(StatusCode.forbidden, 'Solo para administradores.');

  /// A query that fails with an unexpected error: a generic message.
  Future<int> broken() async => throw StateError('lab table is locked');

  /// A query that fails with a status and no message (`429`).
  Future<int> plain() async =>
      throw const HttpError(StatusCode.tooManyRequests);

  /// A lookup that finds nothing for 0 (a null answer, not an error).
  Future<int?> maybe(int n) async => n == 0 ? null : n;

  /// A lookup that fails for 0 and answers [n] otherwise (an argument that
  /// moves while the query is failed).
  Future<int> flaky(int n) async => n == 0
      ? throw const HttpError(StatusCode.serviceUnavailable, 'Servicio caído.')
      : n;

  /// How many times each function of the `/lazy` page ran on the server.
  final lazyCalls = <String, int>{};

  /// Rows that take a while (a slow backend the page must not wait for):
  /// two the first time, three after.
  Future<List<String>> lazyRows() async {
    final n = lazyCalls['lazyRows'] = (lazyCalls['lazyRows'] ?? 0) + 1;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return n == 1 ? ['x', 'y'] : ['x', 'y', 'z'];
  }

  /// `echo <q>`, after a beat.
  Future<String> lazyEcho(String q) async {
    lazyCalls['lazyEcho'] = (lazyCalls['lazyEcho'] ?? 0) + 1;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return 'echo $q';
  }

  /// A lazy query that fails.
  Future<List<String>> lazyBroken() async {
    lazyCalls['lazyBroken'] = (lazyCalls['lazyBroken'] ?? 0) + 1;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    throw const HttpError(StatusCode.serviceUnavailable, 'Lazy no responde.');
  }

  /// Removes row [id] after a beat (the browser can start two at once).
  Future<String> remove(String id) async {
    log.add('start $id');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _rows.remove(id);
    log.add('end $id');
    return id;
  }

  /// Puts the rows back, after a beat (a slow command that refreshes every
  /// query: the browser can change an argument while it flies).
  Future<void> reset() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _rows
      ..clear()
      ..addAll(['a', 'b', 'c', 'd']);
    log.clear();
  }

  /// A change that takes longer than the state's `timeout:`.
  Future<void> hang() async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
  }

  /// A command the visitor may not run (`403`).
  Future<void> deny() async =>
      throw const HttpError(StatusCode.forbidden, 'No puedes hacer eso.');

  /// A command that fails with a status and no message.
  Future<void> throttle() async =>
      throw const HttpError(StatusCode.tooManyRequests);
}

/// The repository the state uses.
final labRepository = LabRepository();

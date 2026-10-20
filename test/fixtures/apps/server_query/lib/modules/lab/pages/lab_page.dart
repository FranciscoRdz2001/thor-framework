import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../state/lab_state.dart';

/// `/lab`: public, for the tests and the browser check of the timing and
/// the errors of server calls.
class LabPage extends ThorPage<void> {
  const LabPage();

  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'Laboratorio');

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 8,
    children: [
      Watch(lab.rowsText),
      Row(
        spacing: 8,
        children: [
          for (final id in const ['a', 'b', 'c', 'd'])
            OutlinedButton(
              onPressed: lab.remove.run.withArg(id),
              child: Text('Borrar $id'),
            ),
          OutlinedButton(
            onPressed: lab.removeAB,
            child: const Text('Borrar a y b'),
          ),
          OutlinedButton(
            onPressed: lab.reset.run,
            child: const Text('Reiniciar'),
          ),
        ],
      ),
      Watch(lab.removeError),
      Row(
        spacing: 8,
        children: [
          for (final ms in const [50, 1500])
            OutlinedButton(
              onPressed: lab.slowFor.withArg(ms),
              child: Text('Lenta $ms'),
            ),
          Watch(lab.slowText),
          Watch(lab.slowBusy, builder: (b) => Text(b ? 'Cargando' : 'Quieta')),
          Watch(lab.slowError),
          Watch(lab.slowKind),
        ],
      ),
      Row(
        spacing: 8,
        children: [
          Watch(lab.deniedError),
          Watch(lab.deniedKind),
          Watch(lab.brokenError),
          Watch(lab.brokenKind),
          Watch(lab.plainError),
          Watch(lab.plainKind),
        ],
      ),
      Row(
        spacing: 8,
        children: [
          OutlinedButton(onPressed: lab.hang.run, child: const Text('Colgar')),
          OutlinedButton(onPressed: lab.deny.run, child: const Text('Negar')),
          OutlinedButton(
            onPressed: lab.throttle.run,
            child: const Text('Limitar'),
          ),
          Watch(lab.hangError),
          Watch(lab.hangKind),
          Watch(lab.denyError),
          Watch(lab.denyKind),
          Watch(lab.throttleError),
          Watch(lab.throttleKind),
        ],
      ),
      // QueryBuilder over the slow query (waiting, done, failed with the
      // timeout) and over the denied one (a first paint that failed).
      QueryBuilder<int>(
        query: lab.slow,
        builder: (context, snap) => Text(_phase('lenta', snap)),
      ),
      QueryBuilder<int>(
        query: lab.denied,
        initialData: 0,
        builder: (context, snap) => snap.hasError
            ? Row(
                spacing: 8,
                children: [
                  Text(_phase('negada', snap)),
                  QueryError(lab.denied),
                  OutlinedButton(
                    onPressed: lab.denied.refresh,
                    child: const Text('Reintentar negada'),
                  ),
                ],
              )
            : Text(_phase('negada', snap)),
      ),
    ],
  );

  /// `name: waiting`, `name: done con dato`, `name: error`…: what the
  /// snapshot says, for the browser check.
  static String _phase(String name, AsyncSnapshot<Object?> snap) =>
      '$name: ${snap.hasError ? 'error' : snap.connectionState.name}'
      '${snap.hasData ? ' con dato' : ''}';
}

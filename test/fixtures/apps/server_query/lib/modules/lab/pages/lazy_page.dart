import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../state/lazy_state.dart';

/// `/lazy`: queries with `ssr: false` and `QueryBuilder`s with no
/// `initialData`, for their browser check: the page goes out waiting, the browser asks, and the states the
/// server never drew (a state with two roots, a list in a wrapped container,
/// a widget drawn twice) show up when the data arrives.
class LazyPage extends ThorPage<void> {
  const LazyPage();

  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'Lazy');

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 8,
    children: [
      Row(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: lazy.echoFor.withArg('b'),
            child: const Text('Echo b'),
          ),
          OutlinedButton(
            onPressed: lazy.rows.refresh,
            child: const Text('Reload rows'),
          ),
        ],
      ),
      // Nothing on the server, no initialData.
      QueryBuilder<List<String>>(
        query: lazy.rows,
        builder: (context, snap) => snap.hasError
            ? const Text('rows: error')
            : snap.hasData
            ? const Text('rows: listo')
            : const Text('rows: cargando'),
      ),
      // A state with two roots (mobile and desktop variants).
      QueryBuilder<List<String>>(
        query: lazy.rows,
        builder: (context, snap) => snap.hasData
            ? const ResponsiveLayout(
                mobile: Text('variante móvil'),
                desktop: Text('variante escritorio'),
              )
            : const Text('variante cargando'),
      ),
      // The rows live in the Row, inside a Column with other content.
      Watch.list(
        lazy.rowList,
        itemKey: lazy.rowKey,
        container: (rows) => Column(
          children: [
            const Text('Lista anidada'),
            Row(spacing: 6, children: rows),
          ],
        ),
        each: (row) => row.text(lazy.rowText),
      ),
      // A container with two roots (a list per breakpoint).
      Watch.list(
        lazy.rowList,
        itemKey: lazy.rowKey,
        container: (rows) => ResponsiveLayout(
          mobile: Column(children: rows),
          desktop: Row(spacing: 6, children: rows),
        ),
        each: (row) => row.text(lazy.rowText),
      ),
      // The same widget twice, one hidden by CSS.
      const ResponsiveVisibility(
        hiddenFrom: WindowSizeClass.expanded,
        child: _Echo(),
      ),
      const ResponsiveVisibility(
        visibleFrom: WindowSizeClass.expanded,
        child: _Echo(),
      ),
      // THOR-S037 on purpose: this builder reads `data!`, so the server can't
      // draw its done state and `thor dev` says so; the ones above only read
      // `hasData` and must not be reported.
      QueryBuilder<List<String>>(
        query: lazy.rows,
        builder: (context, snap) => snap.hasData
            // ignore: thor_lints/query_builder_reads_data
            ? Text('cuenta: ${snap.data!.length}')
            : const Text('cuenta: cargando'),
      ),
      QueryBuilder<List<String>>(
        query: lazy.broken,
        builder: (context, snap) => snap.hasError
            ? Row(
                spacing: 6,
                children: [const Text('broken:'), QueryError(lazy.broken)],
              )
            : snap.hasData
            ? const Text('broken: listo')
            : const Text('broken: cargando'),
      ),
    ],
  );
}

class _Echo extends StatelessWidget {
  const _Echo();

  @override
  Widget build(BuildContext context) => QueryBuilder<String>(
    query: lazy.echo,
    builder: (context, snap) => snap.hasData
        ? Row(spacing: 6, children: [const Text('eco:'), Watch(lazy.echoText)])
        : const Text('eco cargando'),
  );
}

import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../lab/lab_routes.dart';
import '../state/defer_state.dart';

/// What `/defer` loads: `title` is awaited, the rest arrives later.
class DeferData {
  const DeferData(
    this.title,
    this.slow,
    this.slower,
    this.broken, {
    this.early = false,
    this.product,
    this.responsive = false,
  });

  /// `?head=ok|slow|budget|missing|slowmissing`: a product the head waits for
  /// (`ok` comes in 100 ms, `slow` in 1.5 s, `budget` in 1.5 s with an
  /// opt-in 300 ms budget, `missing` is a `NotFound` at 100 ms and
  /// `slowmissing` one at 900 ms).
  final Future<String>? product;

  /// `?responsive=1`: one list shown in a mobile and a desktop variant.
  final bool responsive;

  /// `?early=1`: the state is also used by the part that goes out first.
  final bool early;

  final String title;
  final Future<String> slow;
  final Future<String> slower;
  final Future<String> broken;
}

/// `/defer?ms=700`: a page whose data is slow on purpose, for the browser
/// check of streaming SSR: the page goes out with skeletons, the
/// values replace them as they come (`ms` and twice `ms`), one fails, and a
/// state works inside the content that came late.
class DeferPage extends ThorPage<DeferData> {
  const DeferPage();

  @override
  Future<DeferData> load(PageRequest request) async {
    final ms = int.tryParse(request.queryParameters['ms'] ?? '') ?? 700;
    Future<String> after(int wait, String value) =>
        Future<String>.delayed(Duration(milliseconds: wait), () => value);
    final data = DeferData(
      'Deferred',
      defer(after(ms, 'slow value')),
      defer(after(ms * 2, 'slower value')),
      defer(
        Future<String>.delayed(
          Duration(milliseconds: ms),
          () => throw StateError('secret backend detail'),
        ),
      ),
      early: request.queryParameters['early'] == '1',
    );
    // `?sync=1`: what the page did before it could defer: nothing goes out
    // until every call is back (the baseline of the measurements).
    final head = request.queryParameters['head'];
    final withProduct = DeferData(
      data.title,
      data.slow,
      data.slower,
      data.broken,
      early: data.early,
      responsive: request.queryParameters['responsive'] == '1',
      product: switch (head) {
        'ok' => defer(after(100, 'Real product name'), head: true),
        // No budget: the head waits for it, 1.5 s, and the title is real.
        'slow' => defer(after(1500, 'Real product name'), head: true),
        // An opt-in budget (cosmetic head data): past it the page streams.
        'budget' => defer(
          after(1500, 'Real product name'),
          head: true,
          headBudget: defaultHeadBudget,
        ),
        // Missing, and slow (900 ms, past any head budget): still a 404.
        'slowmissing' => defer(
          Future<String>.delayed(
            const Duration(milliseconds: 900),
            () => throw const NotFound('No such product'),
          ),
          head: true,
        ),
        'missing' => defer(
          Future<String>.delayed(
            const Duration(milliseconds: 100),
            () => throw const NotFound('No such product'),
          ),
          head: true,
        ),
        _ => null,
      },
    );
    if (request.queryParameters['sync'] == '1') {
      await Future.wait([
        data.slow,
        data.slower,
        data.broken.catchError((Object _) => ''),
      ]);
    }
    return withProduct;
  }

  @override
  PageMeta meta(PageState<DeferData> state) => PageMeta(
    // The head waits (until it is done, or its opt-in budget) for `?head=`'s product.
    title: resolvedValue(state.data.product) ?? state.data.title,
  );

  @override
  Widget build(BuildContext context, PageState<DeferData> state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      const Text('Header (not deferred)'),
      Link(href: labRoute.link(), child: const Text('To the lab')),
      if (state.data.early) ...[
        FilledButton(
          onPressed: deferState.increment,
          child: const Text('Count early'),
        ),
        Watch(deferState.label),
      ],
      FutureBuilder<String>(
        future: state.data.slow,
        builder: (context, snapshot) => snapshot.hasData
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text('Loaded: ${snapshot.data}'),
                  FilledButton(
                    onPressed: deferState.increment,
                    child: const Text('Count'),
                  ),
                  Watch(deferState.label),
                ],
              )
            : const Skeleton(width: 240, height: 48),
      ),
      FutureBuilder<String>(
        future: state.data.slower,
        builder: (context, snapshot) => snapshot.hasData
            ? Text('Loaded: ${snapshot.data}')
            : const Skeleton(width: 240, height: 24),
      ),
      FutureBuilder<String>(
        future: state.data.broken,
        builder: (context, snapshot) => snapshot.hasError
            ? Text('Failed: ${snapshot.error}')
            : const Skeleton(width: 240, height: 24),
      ),
      if (state.data.product case final product?)
        FutureBuilder<String>(
          future: product,
          builder: (context, snapshot) => Text(
            snapshot.hasData
                ? 'Product: ${snapshot.data}'
                : snapshot.hasError
                ? 'Product failed: ${snapshot.error}'
                : 'Product loading',
          ),
        ),
      if (state.data.responsive) _ResponsiveList(state.data.slow),
      const Text('Footer (not deferred)'),
    ],
  );
}

/// Text that would break out of an attribute if it were not escaped.
const hostileLabel =
    '"><img src=x onerror=window.__pwned=1> \' onmouseover=window.__pwned=2 x=';

/// The same list in two variants (`ResponsiveLayout`): the late piece goes
/// once and fills both places.
class _ResponsiveList extends StatelessWidget {
  const _ResponsiveList(this.future);

  final Future<String> future;

  @override
  Widget build(BuildContext context) {
    final list = FutureBuilder<String>(
      future: future,
      builder: (context, snapshot) => snapshot.hasData
          // Hostile text in an attribute of the top element, which the two
          // places also receive in `data-thor-cls` (it must stay a value).
          ? Semantics(
              label: hostileLabel,
              child: Column(
                children: [
                  for (var i = 0; i < 3; i++)
                    Text('Item $i of ${snapshot.data}'),
                  FilledButton(
                    onPressed: deferState.increment,
                    child: const Text('Count shared'),
                  ),
                  Watch(deferState.label),
                ],
              ),
            )
          : const Skeleton(width: 240, height: 48),
    );
    return ResponsiveLayout(
      mobile: Column(children: [const Text('Mobile shell'), list]),
      // `Expanded` gives the top element another start tag than the mobile one.
      desktop: Row(
        children: [
          const Text('Desktop shell'),
          Expanded(child: list),
        ],
      ),
    );
  }
}

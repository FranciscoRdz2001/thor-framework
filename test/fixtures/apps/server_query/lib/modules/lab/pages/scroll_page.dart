import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

/// What `/scroll` loads.
class ScrollData {
  const ScrollData(this.late);

  final Future<String>? late;
}

/// `/scroll`: public, for the browser check that a form action answering the
/// same page keeps the visitor where they were (`test/e2e/checks/
/// scroll_check.mjs`): a long list with one button per row, and the three
/// ways an action can answer.
class ScrollPage extends ThorPage<ScrollData> {
  const ScrollPage();

  /// `?late=1`: the list arrives after the page went out (streaming), so
  /// the page is short when its script runs.
  @override
  Future<ScrollData> load(PageRequest request) async {
    // `?slow=1`: a landing that takes a while (a second tab acts meanwhile).
    if (request.queryParameters['slow'] == '1') {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }
    return _data(request);
  }

  ScrollData _data(PageRequest request) => ScrollData(
    request.queryParameters['late'] == '1'
        ? defer<String>(
            Future<String>.delayed(
              const Duration(milliseconds: 400),
              () => 'ok',
            ),
          )
        : null,
  );

  /// Back to this same page (query included) with a toast: the visitor stays.
  Future<ActionResult?> add(PageRequest request, int id) async =>
      Redirect.back(request).flash('Agregado $id');

  /// This page's path, the query dropped (what a hand-written
  /// `Redirect(request.uri.path)` does).
  Future<ActionResult?> drop(PageRequest request) async =>
      Redirect(RouteUrl(request.uri.path)).flash('Soltado');

  /// The quantity stepper: the same path with another query (`?qty=4`).
  Future<ActionResult?> step(PageRequest request, int qty) async =>
      Redirect(RouteUrl('/scroll?qty=$qty'));

  /// The cart's `+`/`-`: `withArgs` (sku, quantity), the page itself answers.
  Future<ActionResult?> setQuantity(
    PageRequest request,
    String sku,
    int qty,
  ) async => null;

  /// The same, answered with `Redirect.back`.
  Future<ActionResult?> setQuantityBack(
    PageRequest request,
    String sku,
    int qty,
  ) async => Redirect.back(request);

  /// The same path, but the visitor starts over (back to page 1).
  Future<ActionResult?> restart(PageRequest request) async =>
      const Redirect(RouteUrl('/scroll?page=1'), resetScroll: true);

  /// Starts over, onto a landing that is slow to arrive.
  Future<ActionResult?> restartSlow(PageRequest request) async =>
      const Redirect(RouteUrl('/scroll?page=1&slow=1'), resetScroll: true);

  /// The same page again, starting over, whatever its path and query
  /// (`Redirect.back`).
  Future<ActionResult?> restartHere(PageRequest request) async =>
      Redirect.back(request, resetScroll: true);

  /// Another page: the visitor starts at its top.
  Future<ActionResult?> leave(PageRequest request) async =>
      const Redirect(RouteUrl('/acts')).flash('Fuera');

  /// The page itself, answered by the POST (no redirect).
  Future<ActionResult?> answer(PageRequest request) async => null;

  /// A validation error: the same page again with a `422`.
  Future<ActionResult?> fail(PageRequest request) async =>
      const ActionResult.fail(422, 'no');

  @override
  PageMeta meta(PageState<ScrollData> state) => const PageMeta(title: 'Scroll');

  @override
  Widget build(BuildContext context, PageState<ScrollData> state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 8,
    children: [
      const Text('Scroll', style: TextStyle(fontSize: 20)),
      if (state.data.late case final late?)
        FutureBuilder<String>(
          future: late,
          builder: (context, snapshot) => snapshot.hasData
              ? _rows()
              : const Skeleton(width: 240, height: 48),
        )
      else
        _rows(),
      FilledButton(onPost: answer, child: const Text('Answer')),
      FilledButton(onPost: fail, child: const Text('Fail')),
      FilledButton(onPost: leave, child: const Text('Leave')),
      FilledButton(onPost: step.withArg(4), child: const Text('Qty 4')),
      FilledButton(
        onPost: setQuantity.withArgs('sku-1', 3),
        child: const Text('Cart plus'),
      ),
      FilledButton(
        onPost: setQuantityBack.withArgs('sku-1', 2),
        child: const Text('Cart back'),
      ),
      FilledButton(onPost: restart, child: const Text('Restart')),
      FilledButton(onPost: restartSlow, child: const Text('Restart slow')),
      FilledButton(onPost: restartHere, child: const Text('Restart here')),
      Form(
        onPost: answer,
        resetScroll: true,
        child: FilledButton(
          buttonType: ButtonType.submit,
          onPressed: () {},
          child: const Text('Reset form'),
        ),
      ),
      const Link(href: RouteUrl('/scroll?page=2'), child: Text('Page 2')),
      FilledButton(onPost: drop, child: const Text('Drop')),
      Form(
        onPost: answer,
        child: Row(
          spacing: 8,
          children: [
            const TextField(
              name: 'note',
              decoration: InputDecoration(labelText: 'Note'),
            ),
            FilledButton(
              buttonType: ButtonType.submit,
              onPressed: () {},
              child: const Text('Save note'),
            ),
          ],
        ),
      ),
      Form(
        formMethod: FormMethod.get,
        child: Row(
          spacing: 8,
          children: [
            const TextField(
              name: 'q',
              decoration: InputDecoration(labelText: 'Search'),
            ),
            FilledButton(
              buttonType: ButtonType.submit,
              onPressed: () {},
              child: const Text('Search'),
            ),
          ],
        ),
      ),
      const Link(href: RouteUrl('/acts'), child: Text('To acts')),
      const Link(href: RouteUrl('/scroll'), child: Text('To scroll')),
    ],
  );

  Widget _rows() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 8,
    children: [
      for (var i = 0; i < 60; i++)
        Row(
          spacing: 8,
          children: [
            SizedBox(width: 120, height: 40, child: Text('Item $i')),
            FilledButton(onPost: add.withArg(i), child: Text('Add $i')),
          ],
        ),
    ],
  );
}

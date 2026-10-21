/// Asking a `Region` of the page to draw again from a `ThorState` method: [PageRegion.refresh]. On the server it does nothing;
/// in the browser the engine hands the request to the page's fragment loader.
library;

/// Refreshes the parts of the page that the server draws alone (a `Region`):
/// the browser asks the page again for the region, from the page's current
/// URL, and swaps the answer in.
///
/// ```dart
/// class TrackingViewModel extends ThorState {
///   Timer? _poll;
///
///   // Poll: every 10 seconds the order's region is drawn again.
///   @override
///   void onHydrated() {
///     _poll = Timer.periodic(
///       const Duration(seconds: 10),
///       (t) => PageRegion.refresh('tracking'),
///     );
///   }
///
///   @override
///   void dispose() => _poll?.cancel();
///
///   void saved() => PageRegion.refresh('summary');
/// }
/// ```
///
/// A refresh while an earlier one for the same region is in flight cancels
/// the earlier one, so a slow answer never overwrites a newer one. A region
/// the page does not have, or a request that fails, changes nothing. The
/// region's content may use `Watch`, buttons and the states of the page; with
/// `Region(syncState: true)` the refresh also updates the values of the
/// states it reads.
///
/// `// web:` Flutter rebuilds a widget from a `setState`; here the
/// server draws the part (the page's `load` runs for the request, so keep it
/// light or cached), and the browser puts the HTML in place. There is no
/// polling widget: a `Timer.periodic` in the state is the clock. Static
/// sites have no server to ask: nothing happens.
abstract final class PageRegion {
  /// Engine only: asks the page's loader to refresh the region.
  static void Function(String id)? handler;

  /// Asks the browser to draw the region [id] (the `id` of a `Region` of
  /// the page, a top-level one) again and swap it in.
  static void refresh(String id) => handler?.call(id);
}

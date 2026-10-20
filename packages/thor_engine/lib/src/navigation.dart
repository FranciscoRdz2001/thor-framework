/// Leaving the page from a `ThorState` method: [PageNavigator.go]. On the
/// server it does nothing; in the browser the engine (both engines) points
/// it at the document's own navigation.
library;

import 'feedback.dart' show ToastKind;

/// Goes to another page from a state method, like following a link: the
/// browser loads [go]'s location as a new document (its server render,
/// its speculation rules, its history entry). There is no client router.
///
/// ```dart
/// // url from the route table on the server: articleRoute.link(…), via withArg
/// void openArticle(String url) => PageNavigator.go(url);
/// void onShortcut() => PageNavigator.go('/reports', replace: true);
/// ```
///
/// `// web:` Flutter's `Navigator.push` keeps the app alive and needs a
/// `BuildContext`; a thor page is a document, so the next page is the
/// server's render of the new URL. Only relative, `http:` and `https:`
/// locations: another scheme (`javascript:`, `data:`) is THOR-S008.
///
/// A `toast` shown right before `go` dies with the page; pass `flash:` to
/// have the next page show the message instead (the same one a server
/// `Redirect(...).flash(...)` leaves).
abstract final class PageNavigator {
  /// Engine only: loads the location (`location.assign`/`replace`).
  static void Function(String location, bool replace)? handler;

  /// Engine only: leaves `message` for the next page that draws (the
  /// `thor-flash` cookie of a server flash), before [handler] navigates.
  static void Function(String message, ToastKind kind)? flashHandler;

  /// Engine only: goes back one entry, or loads the fallback when there is
  /// none of this site to go back to.
  static void Function(String fallback)? popHandler;

  /// Engine only: whether there is an entry of this site to go back to.
  static bool Function()? canPopHandler;

  /// Engine only: reloads the current document.
  static void Function()? reloadHandler;

  /// Loads [location] (a path, `Routes.x(...)`, or an `http(s)` URL) as the
  /// next page; with [replace] it takes the current history entry's place
  /// (the back button skips this page). With [flash] the next page shows
  /// that message as a snack bar of [flashKind] (a blank one is ignored;
  /// 300 characters at most, the rest is cut).
  ///
  /// ```dart
  /// void saved() => PageNavigator.go('/orders',
  ///     flash: 'Order saved', flashKind: ToastKind.success);
  /// ```
  ///
  /// `// web:` the message rides a short-lived cookie to the next document
  /// (Rails' `redirect_to … notice:`), since the page that shows a
  /// `toast` is gone once the browser loads the next one.
  static void go(
    String location, {
    bool replace = false,
    String? flash,
    ToastKind flashKind = ToastKind.info,
  }) {
    if (!isNavigable(location)) {
      throw ArgumentError.value(
        location,
        'location',
        'Only a relative, http: or https: location can be navigated to '
            '(THOR-S008)',
      );
    }
    if (flash != null && flash.trim().isNotEmpty) {
      flashHandler?.call(flash, flashKind);
    }
    handler?.call(location, replace);
  }

  /// Goes back to the previous page of this site (the browser's back
  /// button); with none to go back to ([canPop] is false) it loads
  /// [fallback] instead of leaving the site.
  ///
  /// ```dart
  /// void close() => PageNavigator.pop(fallback: '/reports');
  /// ```
  ///
  /// `// web:` Flutter's `Navigator.pop` removes the top route and
  /// `canPop` says whether one is left; go_router's `context.pop()` and
  /// `canPop()` read the same way. A thor page is a document, so `pop` is
  /// the history's back, and `canPop` counts only entries of this site
  /// (`history.length` also counts other sites' and cannot tell whether
  /// there is a previous entry): the Navigation API's `canGoBack` where the
  /// browser has it, else a same-origin referrer or an entry the page
  /// pushed itself. Without it a "close" button would send the user to
  /// the site they came from, hence [fallback].
  static void pop({String fallback = '/'}) {
    if (!isNavigable(fallback)) {
      throw ArgumentError.value(
        fallback,
        'fallback',
        'Only a relative, http: or https: location can be navigated to '
            '(THOR-S008)',
      );
    }
    popHandler?.call(fallback);
  }

  /// Whether [pop] has an entry of this site to go back to (always false on
  /// the server).
  static bool canPop() => canPopHandler?.call() ?? false;

  /// Loads the current page again, from the server.
  ///
  /// `// web:` Flutter has no document to reload; this is
  /// `location.reload()`, the way to get the server's render again after a
  /// change the page cannot make itself.
  static void reload() => reloadHandler?.call();

  /// Whether [location] is relative or `http(s)` (what [go] accepts).
  static bool isNavigable(String location) {
    // Browsers drop control characters and surrounding spaces before
    // reading the scheme (`java\tscript:`): so does this check.
    // (No RegExp: it would weigh on the dart2js engine.)
    final scheme = StringBuffer();
    for (final unit in location.codeUnits) {
      if (unit <= 0x20) continue;
      // A path, query or fragment before any colon: relative.
      if (unit == 0x2F || unit == 0x3F || unit == 0x23) return true;
      if (unit == 0x3A) {
        final lower = scheme.toString().toLowerCase();
        return lower == 'http' || lower == 'https';
      }
      scheme.writeCharCode(unit);
    }
    return true;
  }
}

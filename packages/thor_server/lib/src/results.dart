/// Outcomes a `load`, an action or a guard can throw (or an action return)
/// to end the request differently from rendering the page.
library;

import 'flash.dart';
import 'list_query.dart' show queryWithoutAction, sitePath;
import 'request.dart' show PageRequest;
import 'route_url.dart';

/// Ends the request with a redirect to [location]. Thrown from a `load` or
/// returned (or thrown) from an action.
///
/// After a form `POST` the default is `303 See Other` (the browser follows
/// it with a `GET`: post/redirect/get).
///
/// It is an [ActionResult] too, so an action method typed
/// `Future<ActionResult?>` returns it: `return Redirect(route.link());`.
class Redirect extends ActionResult implements Exception {
  /// `303 See Other` to [location].
  ///
  /// [resetScroll]: the visitor starts at the top of [location] even when it
  /// is the page they were on. By default a redirect that lands on the same
  /// path (the query may change: `/p/shirt?qty=4`) keeps their scroll and the
  /// pressed button (`thor_ui`'s form script); turn it on when the action
  /// really starts the page over (clear the filters, back to page 1).
  /// `// web:` Remix's `preventScrollReset` defaults to resetting; here the
  /// default is to keep, and this is the way back. The form script leaves a
  /// mark of the posting tab in a `thor-tab` cookie; the redirect echoes it
  /// in a short-lived `thor-scroll` cookie, which that tab's script reads and
  /// removes on the next page (cookies are shared by tabs: another tab's
  /// landing is not reset). With cookies blocked the redirect cannot ask for
  /// it; `Form(resetScroll: true)` needs none.
  const Redirect(this.location, {int status = 303, this.resetScroll = false})
    : flashMessage = null,
      super._(status);

  /// The page [request] was posted from, its query kept and the action key
  /// (`?/save`) gone: the very URL the visitor was on, so the browser keeps
  /// their scroll and the pressed button (`thor_ui`'s form script). A
  /// hand-written `Redirect(request.uri.path)` drops the query (`/orders?
  /// status=paid` lands on `/orders`): that is another page and it starts at
  /// the top. Not the `Referer`: that header is the client's to send or not,
  /// and an action may also be posted from another page.
  ///
  /// ```dart
  /// Future<ActionResult?> archive(PageRequest request) async {
  ///   ...
  ///   return Redirect.back(request).flash('Archived');
  /// }
  /// ```
  ///
  /// `// web:` Rails' `redirect_back`, Remix's `redirect(request.url)`; an
  /// action that returns `null` already does this.
  factory Redirect.back(
    PageRequest request, {
    int status = 303,
    bool resetScroll = false,
  }) {
    final query = queryWithoutAction(request.uri.query);
    final path = sitePath(request.uri.path);
    return Redirect(
      RouteUrl(query.isEmpty ? path : '$path?$query'),
      status: status,
      resetScroll: resetScroll,
    );
  }

  /// `302 Found`: a temporary redirect (e.g. a protected page → `/login`).
  const Redirect.found(this.location)
    : flashMessage = null,
      resetScroll = false,
      super._(302);

  /// `307 Temporary Redirect`: keeps the method and body.
  const Redirect.temporary(this.location)
    : flashMessage = null,
      resetScroll = false,
      super._(307);

  /// `308 Permanent Redirect`.
  const Redirect.permanent(this.location)
    : flashMessage = null,
      resetScroll = false,
      super._(308);

  const Redirect._flashed(
    this.location,
    int status,
    this.flashMessage,
    this.resetScroll,
  ) : super._(status);

  /// Where to go (a path or a URL); [status] is the 3xx.
  final RouteUrl location;

  /// Whether the visitor starts at the top even on the same path (see the
  /// constructor).
  final bool resetScroll;

  /// The message the next page that draws shows, if any ([flash]).
  final FlashMessage? flashMessage;

  /// This redirect, and [message] on the next page that draws (as a snack
  /// bar): the page shows it once, with or without JavaScript, and it is
  /// gone on the next one. A blank message is nothing; a message longer than
  /// 300 characters is cut. Two flashes before a page draws: the last wins.
  ///
  /// ```dart
  /// return Redirect(ordersRoute.link()).flash('Order deleted', kind: FlashKind.success);
  /// ```
  ///
  /// `// web:` Rails' `redirect_to … , notice:`, Phoenix's `put_flash`, Remix's
  /// `session.flash`; here a short-lived cookie, since a thor server keeps no
  /// session of its own.
  Redirect flash(String message, {FlashKind kind = FlashKind.info}) {
    final flash = FlashMessage(message, kind);
    return flash.message.trim().isEmpty
        ? this
        : Redirect._flashed(location, status, flash, resetScroll);
  }

  @override
  String toString() => 'Redirect($status → $location)';
}

/// Ends the request with an error [status]: the error page of the nearest
/// group (`Group(error:)`) renders it. [message] is shown to the user; keep it free of internals.
class HttpError implements Exception {
  /// An error with [status].
  const HttpError(this.status, [this.message]);

  /// HTTP status (4xx or 5xx).
  final int status;

  /// Text for the error page.
  final String? message;

  @override
  String toString() =>
      'HttpError($status${message == null ? '' : ': $message'})';
}

/// `429 Too Many Requests`: the client must wait [retryAfter] (sent as
/// `Retry-After`). What `RateLimit.middleware` ends a request with.
class TooManyRequests extends HttpError {
  /// A 429 that asks to wait [retryAfter].
  const TooManyRequests(this.retryAfter, [String? message])
    : super(429, message ?? 'Too many requests. Try again later.');

  /// How long to wait.
  final Duration retryAfter;

  /// `Retry-After` in whole seconds, at least one.
  int get retryAfterSeconds =>
      retryAfter.inSeconds < 1 ? 1 : retryAfter.inSeconds;
}

/// `404 Not Found`.
class NotFound extends HttpError {
  /// A 404, optionally with a [message].
  const NotFound([String? message]) : super(404, message);
}

/// What an action returns: a [Redirect], or the page again
/// ([ActionResult.fail], [ActionResult.success]).
///
/// ```dart
/// if (form['email']!.isEmpty) return ActionResult.fail(422, {'errors': …});
/// ```
class ActionResult {
  /// The action failed: the page renders again with [status] and [data]
  /// as its `state.form` (the values to re-fill and the errors to show).
  const ActionResult.fail(this.status, [this.data]);

  /// The action worked and the page renders again (no redirect) with
  /// [data] as its `state.form`.
  const ActionResult.success([this.data]) : status = 200;

  const ActionResult._(this.status) : data = null;

  /// HTTP status of the re-rendered page.
  final int status;

  /// Data for the page (`state.form`).
  final Object? data;
}

/// A value an action can return that knows its own [ActionResult]: a
/// failed form (`FormInvalid` of `thor_ui/router.dart`) is a `422` with
/// itself as `state.form`, never a `200` that drops it.
abstract interface class ActionOutcome {
  /// What the page renders with.
  ActionResult get actionResult;
}

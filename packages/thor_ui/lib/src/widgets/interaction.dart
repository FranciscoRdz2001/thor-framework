import 'dart:convert' show jsonEncode;

import 'package:thor_engine/thor_engine.dart'
    show
        argAttr,
        geolocationAttr,
        geolocationOptionsAttr,
        shareAttr,
        shareDataAttr,
        visibilityAttr;

import '../engine/watch.dart' show elementEventAttributes, gestureAttributes;
import '../foundation/parent_data.dart';

/// Flutter's `MouseCursor`, mapped to CSS `cursor`.
class MouseCursor {
  const MouseCursor._(this.css);

  /// The CSS `cursor` value.
  final String css;
}

/// Flutter's `SystemMouseCursors`.
abstract final class SystemMouseCursors {
  /// `cursor: default`.
  static const basic = MouseCursor._('default');

  /// `cursor: pointer`.
  static const click = MouseCursor._('pointer');

  /// `cursor: text`.
  static const text = MouseCursor._('text');

  /// `cursor: not-allowed`.
  static const forbidden = MouseCursor._('not-allowed');

  /// `cursor: wait`.
  static const wait = MouseCursor._('wait');

  /// `cursor: progress`.
  static const progress = MouseCursor._('progress');

  /// `cursor: help`.
  static const help = MouseCursor._('help');

  /// `cursor: move`.
  static const move = MouseCursor._('move');

  /// `cursor: grab`.
  static const grab = MouseCursor._('grab');

  /// `cursor: grabbing`.
  static const grabbing = MouseCursor._('grabbing');

  /// `cursor: crosshair`.
  static const precise = MouseCursor._('crosshair');

  /// `cursor: none`.
  static const none = MouseCursor._('none');

  /// `cursor: col-resize`.
  static const resizeColumn = MouseCursor._('col-resize');

  /// `cursor: row-resize`.
  static const resizeRow = MouseCursor._('row-resize');

  /// `cursor: zoom-in`.
  static const zoomIn = MouseCursor._('zoom-in');

  /// `cursor: zoom-out`.
  static const zoomOut = MouseCursor._('zoom-out');
}

/// Flutter's `MouseRegion`.
///
/// ```dart
/// MouseRegion(
///   cursor: SystemMouseCursors.click,
///   onEnter: card.hover,     // void hover()
///   onExit: card.unhover,
///   child: card,
/// )
/// ```
///
/// `// web:` [onEnter] and [onExit] are methods of a `ThorState` and run
/// in the browser once the engine is loaded (the first click, key or focus
/// loads it; hovering alone does not, so a page nobody touches ships no
/// JS): a pointer already inside then counts as entered. Only a mouse or
/// pen counts, like Flutter (a finger never hovers, so a tap on a phone
/// enters nothing and leaves nothing). Nested regions and children inside
/// the region do not flicker: moving between two elements of the same
/// region is not an exit, and leaving the window is.
class MouseRegion extends ParentDataWrapper {
  /// Wraps `child`, applying [cursor] and pointer listeners.
  const MouseRegion({
    super.key,
    this.cursor,
    this.onEnter,
    this.onExit,
    required super.child,
  });

  /// The cursor shown while hovering `child`.
  final MouseCursor? cursor;

  /// Called when the pointer enters `child`.
  final void Function()? onEnter;

  /// Called when the pointer leaves `child`.
  final void Function()? onExit;

  @override
  WrapData get wrapData => WrapData(
    css: {if (cursor != null) 'cursor': cursor!.css},
    attributes: elementEventAttributes({'enter': onEnter, 'leave': onExit}),
  );
}

/// Reports when its child enters or leaves the viewport: an infinite list's
/// "load more" sentinel, a reveal-on-scroll, a view counter.
///
/// ```dart
/// // a ViewModel method: void seen(bool visible) { if (visible) loadMore(); }
/// VisibilityDetector(
///   onVisibilityChanged: feed.seen,
///   margin: 400, // starts 400 px before it shows
///   child: const SizedBox(height: 1),
/// )
/// ```
///
/// Without JavaScript nothing is reported, so the child is also the page's
/// way without it: a "Load more" link (`?cursor=`) the same list answers.
///
/// `// web:` Flutter has no such widget (the `visibility_detector` package
/// is the nearest, and reports a `VisibilityInfo`); here the browser's
/// `IntersectionObserver` calls a method of a `ThorState` with `true` or
/// `false`. It reports changes: an element that starts out of view says
/// nothing until it shows, and one that shows says `true` once (until it
/// leaves and comes back), so a sentinel that stays in view after its rows
/// loaded is not reported again; remove it (`if (hasMore)`) or let the next
/// rows push it away. The engine starts when the first change is reported.
class VisibilityDetector extends ParentDataWrapper {
  /// Wraps [child], reporting to [onVisibilityChanged].
  const VisibilityDetector({
    super.key,
    required this.onVisibilityChanged,
    this.threshold = 0,
    this.margin = 0,
    this.once = false,
    required super.child,
  }) : assert(threshold >= 0 && threshold <= 1, 'threshold is from 0 to 1');

  /// Called with `true` when [child] shows and `false` when it stops
  /// showing: a method of a `ThorState` that takes a `bool`.
  final void Function(bool visible) onVisibilityChanged;

  /// The share of [child] that must show to count (0: one pixel; 1: all).
  final double threshold;

  /// Logical pixels around the viewport that count as showing: `400` reports
  /// 400 px before the child scrolls into view.
  final double margin;

  /// Reports only the first appearance (`true` once) and stops watching.
  final bool once;

  @override
  WrapData get wrapData {
    final marks = elementEventAttributes({'visible': onVisibilityChanged});
    if (marks.isEmpty) return const WrapData();
    return WrapData(
      attributes: {
        ...marks,
        visibilityAttr: '${_num(threshold)}|${_num(margin)}|${once ? 1 : 0}',
      },
    );
  }

  static String _num(double v) => v == v.truncate() ? '${v.truncate()}' : '$v';
}

/// Asks the browser for the visitor's position when its child is tapped.
///
/// ```dart
/// // ViewModel: void found(double latitude, double longitude, double accuracy)
/// //            void failed(String reason)
/// GeolocationRequest(
///   onPosition: nearby.found,
///   onError: nearby.failed, // 'denied', 'unavailable', 'timeout' or 'unsupported'
///   child: OutlinedButton(onPressed: null, child: Text('Use my location')),
/// )
/// ```
///
/// `// web:` Flutter has no built-in location (the `geolocator` package
/// returns a `Future<Position>`); here the tap calls
/// `navigator.geolocation.getCurrentPosition`, which asks the visitor and
/// only works on a secure page. The answer reaches methods of a
/// `ThorState`: [onPosition] with the latitude, longitude and accuracy (in
/// metres) and [onError] with the reason. Only a tap asks (a page that asks
/// at load is refused by most browsers and by most visitors); the position
/// never travels to the server by itself, so a cached page stays the same
/// for everyone and the state decides what to do with it (a `query`
/// argument, a link to `?lat=&lng=`). A second tap while one is waiting is
/// ignored.
class GeolocationRequest extends ParentDataWrapper {
  /// Wraps [child]: tapping it asks for the position.
  const GeolocationRequest({
    super.key,
    this.onPosition,
    this.onError,
    this.highAccuracy = false,
    this.timeout,
    this.maximumAge,
    required super.child,
  });

  /// Called with the position: latitude and longitude in degrees, accuracy
  /// in metres.
  final void Function(double latitude, double longitude, double accuracy)?
  onPosition;

  /// Called with why there is none: `denied` (the visitor said no),
  /// `unavailable`, `timeout` or `unsupported` (no geolocation here).
  final void Function(String reason)? onError;

  /// Asks for the best position the device can give (GPS: slower, uses
  /// more battery).
  final bool highAccuracy;

  /// How long to wait for the answer, or null for the browser's default.
  final Duration? timeout;

  /// A position this old (or newer) is good enough, or null to always ask
  /// the device again.
  final Duration? maximumAge;

  @override
  WrapData get wrapData {
    final marks = gestureAttributes({
      'ok': onPosition,
      'err': onError,
    }, attribute: geolocationAttr);
    if (marks.attributes.isEmpty) return const WrapData();
    return WrapData(
      attributes: {
        ...marks.attributes,
        argAttr: ?marks.fixed,
        geolocationOptionsAttr:
            '${highAccuracy ? 1 : 0}|${timeout?.inMilliseconds ?? 0}|'
            '${maximumAge?.inMilliseconds ?? 0}',
      },
    );
  }
}

/// Opens the device's share sheet when its child is tapped.
///
/// ```dart
/// ShareRequest(
///   title: 'Tacos El Güero',
///   text: 'The best tacos in town',
///   url: '/places/tacos-el-guero',
///   onResult: place.shared, // void shared(String result)
///   child: const Link(href: 'https://wa.me/?text=...', child: Text('Share')),
/// )
/// ```
///
/// `// web:` Flutter's `share_plus` shares from Dart; here the tap calls the
/// browser's `navigator.share`, which needs a tap and a secure page, and
/// exists on phones and a few desktops. Where it does not, a child that is a
/// link keeps its own `href` (the page's fallback, also what it does without
/// JavaScript: a `wa.me` or `mailto:` link); a child with no link copies the
/// text and the link to the clipboard. [onResult] says what happened:
/// `shared`, `cancelled` (the visitor closed the sheet), `link` (the child's
/// link was followed), `copied` or `failed`, so a state can show "Link
/// copied". [url] may be a path; without it the current page is shared.
class ShareRequest extends ParentDataWrapper {
  /// Wraps [child]: tapping it shares.
  const ShareRequest({
    super.key,
    this.title,
    this.text,
    this.url,
    this.onResult,
    required super.child,
  });

  /// The subject of what is shared.
  final String? title;

  /// The message.
  final String? text;

  /// The link, absolute or a path of this site; the current page by default.
  final String? url;

  /// Called with how it went: `shared`, `cancelled`, `link`, `copied` or
  /// `failed`.
  final void Function(String result)? onResult;

  @override
  WrapData get wrapData {
    final marks = gestureAttributes({'result': onResult}, attribute: shareAttr);
    return WrapData(
      attributes: {
        ...marks.attributes,
        argAttr: ?marks.fixed,
        shareDataAttr: jsonEncode({
          'title': ?title,
          'text': ?text,
          'url': ?url,
        }),
      },
    );
  }
}

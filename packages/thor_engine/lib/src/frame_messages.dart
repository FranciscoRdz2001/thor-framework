/// `postMessage` between the page and the frames around it, for `ThorState`
/// methods: [FrameMessages.postToParent], [FrameMessages.postToFrame] and
/// [FrameMessages.listen]. On the server and in the VM they do nothing; in
/// the browser the lite engine (part `frame_messages`) connects them to
/// `window.postMessage` and the `message` event.
library;

/// A running [FrameMessages.listen]: [cancel] it from `dispose()`.
final class FrameSubscription {
  /// A subscription that runs [onCancel] once.
  FrameSubscription(void Function() onCancel) : _onCancel = onCancel;

  void Function()? _onCancel;

  /// Stops listening. Calling it again does nothing.
  void cancel() {
    final f = _onCancel;
    _onCancel = null;
    f?.call();
  }
}

/// What the engine does for [FrameMessages].
abstract interface class FrameMessagesDriver {
  /// Posts [message] to the parent window ([frameId] null) or to the
  /// `<iframe id="frameId">` of this document, only if its origin is
  /// [targetOrigin].
  void post(String? frameId, String message, String targetOrigin);

  /// Calls [onMessage] with each message from the parent or one of this
  /// page's frames whose origin is in [origins].
  FrameSubscription listen(
    List<String> origins,
    void Function(String origin, String message) onMessage,
  );
}

/// Talks to an `<iframe>` of the page (or to the page that holds this one)
/// from a state method, with `postMessage`:
///
/// ```dart
/// class CanvasViewModel extends ThorState {
///   final zoom = state(1.0);
///   FrameSubscription? _heard;
///
///   @override
///   void onHydrated() {
///     // a change of the field tells the frame, however it came about
///     zoom.addListener(_tellFrame);
///     _heard = FrameMessages.listen(
///       origins: ['https://preview.example.com'],
///       onMessage: _fromFrame,
///     );
///   }
///
///   @override
///   void dispose() => _heard?.cancel();
///
///   void _tellFrame() => FrameMessages.postToFrame('canvas',
///       jsonEncode({'type': 'zoom', 'zoom': zoom.value}),
///       targetOrigin: 'https://preview.example.com');
///
///   void _fromFrame(String origin, String message) {
///     final data = jsonDecode(message) as Map<String, Object?>;
///     if (data['type'] == 'hover') { … }
///   }
/// }
/// ```
///
/// `// web:` Flutter has no windows to talk to; this is the browser's
/// `window.postMessage`, made safe by construction:
///
/// * Every origin is explicit: `https://host[:port]` (or `http:`), nothing
///   else. `'*'`, `'null'`, a path, a wildcard or a blank one throws an
///   [ArgumentError] (THOR-S044), when sending and when listening. There is
///   no way to send to, or accept from, "any" origin.
/// * [listen] drops a message whose `origin` is not in its `origins`, one
///   that doesn't come from the parent window or an `<iframe>` of this
///   document, a non-string one and one over [maxMessageLength], and never
///   calls the method for it.
/// * A message is text (use `jsonEncode`/`jsonDecode`): no object crosses
///   the boundary, so nothing from the other side is trusted as a type.
/// * The browser delivers a posted message only if the target's origin is
///   `targetOrigin`.
///
/// Sending to a frame that isn't in the page (yet) or to the parent of a
/// top-level page does nothing. The message of a frame is data, never
/// something to run: check its `type` and its fields as you would a form.
abstract final class FrameMessages {
  /// The biggest message [listen] accepts, in UTF-16 code units.
  static const maxMessageLength = 1 << 20;

  /// Engine only: the page's windows.
  static FrameMessagesDriver? driver;

  /// Whether [origin] is a legal explicit origin: `http(s)://host[:port]`,
  /// as the browser writes it (lower case, no path, no wildcard, no default
  /// port).
  static bool isValidOrigin(String origin) {
    if (origin.contains('*') || origin.endsWith('/')) return false;
    final Uri uri;
    try {
      uri = Uri.parse(origin);
    } on FormatException {
      return false;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    if (uri.host.isEmpty || uri.userInfo.isNotEmpty) return false;
    if (uri.path.isNotEmpty || uri.hasQuery || uri.hasFragment) return false;
    // `https://a.com:443` is `https://a.com` to the browser: it would never
    // match an event's origin.
    if (origin.endsWith(uri.scheme == 'https' ? ':443' : ':80')) return false;
    return origin == origin.toLowerCase();
  }

  static String _origin(String origin, String what) {
    if (!isValidOrigin(origin)) {
      throw ArgumentError.value(
        origin,
        'origin',
        '$what needs an explicit origin like "https://host:port" (no "*", '
            '"null", path or default port) (THOR-S044)',
      );
    }
    return origin;
  }

  /// Posts [message] to the window that holds this page (when it is in an
  /// `<iframe>`); the browser delivers it only if that window's origin is
  /// [targetOrigin].
  static void postToParent(String message, {required String targetOrigin}) {
    _origin(targetOrigin, 'postToParent');
    driver?.post(null, message, targetOrigin);
  }

  /// Posts [message] to the `<iframe id="frameId">` of this page; delivered
  /// only if its current origin is [targetOrigin].
  static void postToFrame(
    String frameId,
    String message, {
    required String targetOrigin,
  }) {
    _origin(targetOrigin, 'postToFrame');
    driver?.post(frameId, message, targetOrigin);
  }

  /// Calls [onMessage] (origin, message) for each message that the parent
  /// window or a frame of this page posts from one of [origins] (not empty).
  /// Cancel the result in `dispose()`.
  static FrameSubscription listen({
    required List<String> origins,
    required void Function(String origin, String message) onMessage,
  }) {
    if (origins.isEmpty) {
      throw ArgumentError.value(
        origins,
        'origins',
        'listen needs at least one explicit origin (THOR-S044)',
      );
    }
    for (final o in origins) {
      _origin(o, 'listen');
    }
    return driver?.listen(origins, onMessage) ?? FrameSubscription(() {});
  }
}

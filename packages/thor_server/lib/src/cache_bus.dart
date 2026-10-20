import 'dart:async';
import 'dart:isolate';

/// Tells every isolate of a server that data changed, so each clears its
/// page cache (the way Phoenix.PubSub tells every node of a cluster).
///
/// Every isolate has a page cache of its own; without this, one that
/// didn't get the write keeps serving the old page up to twice the TTL.
/// `ThorServer.serve` wires the isolates it starts: each gives its
/// [inbox], gets the others' ([connect]), and a handler that cleared its
/// cache after a write calls [announce].
///
/// [announce] never waits and never queues without bound: the first
/// one in a while goes out at once, and the ones that follow within
/// [window] become a single message at the end of it (a burst of a thousand
/// writes is two messages per peer, the last one after the last write).
class CacheBus {
  CacheBus._();

  /// The most often a burst of writes sends: one message per peer each.
  /// Tests that put writes inside or outside of it widen it, so a loaded
  /// machine can't move a write across its edge ([reset] restores it).
  static Duration window = const Duration(milliseconds: 50);

  static final _listeners = <WeakReference<void Function()>>[];
  static final _tagListeners = <WeakReference<void Function(List<String>)>>[];
  static final _pendingTags = <String>{};
  static Timer? _tagTrailing;
  static final _tagClock = Stopwatch();
  static var _tagSent = false;
  static final _peers = <SendPort>[];
  static ReceivePort? _inbox;
  static Timer? _trailing;
  static final _clock = Stopwatch();
  static var _sent = false;

  /// Calls [onClear] whenever another isolate announces a write. Held
  /// weakly: keep a reference for as long as it should be called (the
  /// handler's own tear-off does).
  static void listen(void Function() onClear) {
    _listeners.removeWhere((w) => w.target == null);
    _listeners.add(WeakReference(onClear));
  }

  /// Calls [onTags] with the tags another isolate revalidated, and with the
  /// ones [revalidate] names here. Held weakly, like [listen].
  static void listenTags(void Function(List<String>) onTags) {
    _tagListeners.removeWhere((w) => w.target == null);
    _tagListeners.add(WeakReference(onTags));
  }

  static void _heardTags(List<String> tags) {
    for (final w in [..._tagListeners]) {
      w.target?.call(tags);
    }
  }

  /// A page cache entry tagged with any of [tags] is stale: this isolate's
  /// handlers drop theirs now, and the peers are told (coalesced like
  /// [announce]: the tags of a burst go in one message per peer).
  static void revalidate(Iterable<String> tags) {
    final list = tags.toSet().toList();
    if (list.isEmpty) return;
    _heardTags(list);
    if (_peers.isEmpty) return;
    _pendingTags.addAll(list);
    // A burst of distinct tags (one per user, per product) is not worth a
    // message that grows with it: past the cap the peers are told to drop
    // every tagged page (`*`), which is over-invalidating and bounded.
    if (_pendingTags.length > maxPendingTags) {
      _pendingTags
        ..clear()
        ..add(allTags);
    }
    if (_tagTrailing != null) return;
    final since = _tagSent ? _tagClock.elapsed : window;
    if (since >= window) {
      _sendTags();
    } else {
      _tagTrailing = Timer(window - since, () {
        _tagTrailing = null;
        _sendTags();
      });
    }
  }

  /// The tag that means "every tagged page" (a peer that hears it drops them
  /// all, also the ones that stay through writes).
  static const allTags = '*';

  /// Most distinct tags that wait to be sent before they become [allTags].
  static const maxPendingTags = 1024;

  static void _sendTags() {
    _tagSent = true;
    _tagClock
      ..reset()
      ..start();
    final tags = _pendingTags.toList();
    _pendingTags.clear();
    for (final peer in _peers) {
      peer.send(tags);
    }
  }

  /// The port this isolate receives announcements on (opened on first
  /// use). Give it to the other isolates.
  static SendPort get inbox =>
      (_inbox ??= ReceivePort()
            ..listen((message) {
              if (message is Map) {
                onShare?.call(message);
                return;
              }
              if (message is List) {
                _heardTags([for (final t in message) '$t']);
                return;
              }
              for (final w in [..._listeners]) {
                w.target?.call();
              }
            }))
          .sendPort;

  /// Called with a message another isolate [share]d (`UploadResults`).
  static void Function(Map<Object?, Object?>)? onShare;

  /// Sends [message] (a map of sendable values) to every peer, at once: unlike
  /// [announce] it is not coalesced, each one is its own data.
  static void share(Map<String, Object?> message) {
    for (final peer in _peers) {
      peer.send(message);
    }
  }

  /// Whether a message waits for the end of the [window] (tests).
  static bool get pending => _trailing != null || _tagTrailing != null;

  /// Sets the isolates to tell (not this one: it cleared its own cache).
  static void connect(Iterable<SendPort> peers) {
    _peers
      ..clear()
      ..addAll(peers);
  }

  /// Tells the peers that a write happened here. Cheap and never blocks
  /// the response.
  static void announce() {
    if (_peers.isEmpty || _trailing != null) return;
    final since = _sent ? _clock.elapsed : window;
    if (since >= window) {
      _send();
    } else {
      // Inside the window: one message at its end covers every write since.
      _trailing = Timer(window - since, () {
        _trailing = null;
        _send();
      });
    }
  }

  static void _send() {
    _sent = true;
    _clock
      ..reset()
      ..start();
    for (final peer in _peers) {
      peer.send(0);
    }
  }

  /// Forgets the peers and closes the inbox (tests).
  static void reset() {
    _trailing?.cancel();
    _trailing = null;
    _tagTrailing?.cancel();
    _tagTrailing = null;
    _pendingTags.clear();
    _tagListeners.clear();
    _tagSent = false;
    _tagClock
      ..stop()
      ..reset();
    _peers.clear();
    _listeners.clear();
    _inbox?.close();
    _inbox = null;
    _sent = false;
    window = const Duration(milliseconds: 50);
    _clock
      ..stop()
      ..reset();
  }
}

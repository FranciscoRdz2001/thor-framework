/// Server events for the dart2js engine: `events(url)`, the lite
/// engine's part `events`.
///
/// A [ServerEventStream] field is a query (the server's value drew the page) that
/// a native `EventSource` keeps up to date. The browser keeps one
/// `EventSource` per URL on the page (a hub the states that use it share);
/// it opens when an element of the page names a state with the field and
/// closes when none does, and while the page is hidden (`pagehide`, a hidden
/// tab, a page kept for the back button: it opens again when shown, and a state with an `initial`
/// function asks the server for the value, since a new connection has no
/// `Last-Event-ID`). After a drop the browser reconnects by itself, sending
/// `Last-Event-ID`; `connection` is `waiting` meanwhile, `active` when open
/// and `done` when the browser gave up (the server answered with an error)
/// or the hub closed.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:thor_engine/src/async_snapshot.dart' show ConnectionState;
import 'package:thor_engine/src/query.dart';
import 'package:thor_engine/src/reactive.dart' show batch;
import 'package:thor_engine/src/thor_state.dart';
import 'package:thor_engine_oracle/client.dart' show EngineFeature, StateLife;
import 'package:thor_engine_oracle/src/json_interop.dart';
import 'package:thor_engine_oracle/src/lifecycle_client.dart' show namedStates;
import 'package:web/web.dart' as web;

/// The `EventSource` of every `events(url)` field of the app's states. The
/// generated entry adds it when the app has one.
final class EventsFeature extends EngineFeature {
  /// The feature.
  const EventsFeature();

  @override
  void Function()? followStates(
    web.Element scope,
    Iterable<ThorState> states,
    StateLife life,
  ) {
    // The state's id prefix → its event streams.
    final byPrefix = <String, List<_Stream>>{};
    for (final s in states) {
      for (final m in s.members) {
        if (m.query case final ServerEventStream<Object?> e) {
          (byPrefix[s.idPrefix] ??= []).add(_Stream(e));
        }
      }
    }
    if (byPrefix.isEmpty) return null;
    void sync(Set<String> here) {
      for (final MapEntry(key: prefix, value: streams) in byPrefix.entries) {
        for (final s in streams) {
          here.contains(prefix) ? s.start() : s.stop();
        }
      }
    }

    sync(namedStates([scope]));
    final observer = web.MutationObserver(
      ((JSArray<web.MutationRecord> records, web.MutationObserver _) {
        // Only what leaves or arrives can change what the page names.
        var moved = false;
        for (final r in records.toDart) {
          moved = moved || r.removedNodes.length > 0 || r.addedNodes.length > 0;
        }
        if (moved) sync(namedStates([scope]));
      }).toJS,
    );
    observer.observe(
      scope,
      web.MutationObserverInit(childList: true, subtree: true),
    );
    return () {
      observer.disconnect();
      for (final streams in byPrefix.values) {
        for (final s in streams) {
          s.stop();
        }
      }
    };
  }
}

/// One `events(url)` field's use of its hub.
final class _Stream {
  _Stream(this.events) {
    events.attach(_reconnect);
  }

  final ServerEventStream<Object?> events;
  _Sub? _sub;

  void start() {
    if (_sub != null) return;
    _sub = _acquire(
      events.url,
      _Sub(
        event: events.event,
        onData: _receive,
        onState: (s) => events.connection.value = s,
        // `// web:` the lite engine asks the server for `initial` again here;
        // dart2js can't call the server (`refresh` does nothing), so the
        // value is whatever the new connection's first event brings: a
        // stream that can be restored should open with a `replace`.
        onResume: () {},
      ),
    );
  }

  void stop() {
    final sub = _sub;
    if (sub == null) return;
    _sub = null;
    sub.release();
    events.connection.value = ConnectionState.done;
  }

  void _reconnect() {
    if (_sub == null) {
      start();
    } else {
      _sub!.reopen();
    }
  }

  void _receive(String text) {
    try {
      final json = (globalContext['JSON']! as JSObject).callMethod<JSAny?>(
        'parse'.toJS,
        text.toJS,
      );
      batch(() => events.receive(jsonToDart(json)));
      // One event's failure (a text that is not JSON, a shape the field
      // doesn't have) is reported like the other failures, and the stream
      // goes on.
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      web.console.error('thor: an event of ${events.url} failed: $e'.toJS);
    }
  }
}

/// A listener of a hub: the event it wants and where its news go.
final class _Sub {
  _Sub({
    required this.event,
    required this.onData,
    required this.onState,
    required this.onResume,
  });

  final String event;
  final void Function(String data) onData;
  final void Function(ConnectionState state) onState;
  final void Function() onResume;
  late void Function() release;
  late void Function() reopen;
}

/// The page's streams, by absolute URL: one `EventSource` each.
final _hubs = <String, _Hub>{};

final class _Hub {
  _Hub(this.url);

  final String url;
  final subs = <_Sub>[];
  final events = <String>{};
  web.EventSource? source;
  ConnectionState state = ConnectionState.waiting;

  void tell(ConnectionState next) {
    state = next;
    for (final s in [...subs]) {
      s.onState(next);
    }
  }

  void listen(String event) {
    source!.addEventListener(
      event,
      ((web.Event e) {
        final data = (e as web.MessageEvent).data;
        if (data == null || !data.isA<JSString>()) return;
        final text = (data as JSString).toDart;
        for (final s in [...subs]) {
          if (s.event == event) s.onData(text);
        }
      }).toJS,
    );
  }

  void open() {
    // A page that loads hidden opens when it is shown.
    if (web.document.hidden) return tell(ConnectionState.done);
    final web.EventSource es;
    try {
      es = source = web.EventSource(url);
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      source = null;
      web.console.error('thor: events($url) did not open: $e'.toJS);
      return tell(ConnectionState.done);
    }
    es.onopen = ((web.Event _) => tell(ConnectionState.active)).toJS;
    // A closed source is final (the server refused it); one that is still
    // connecting is the browser's own reconnection.
    es.onerror = ((web.Event _) => tell(
      es.readyState == web.EventSource.CLOSED
          ? ConnectionState.done
          : ConnectionState.waiting,
    )).toJS;
    events.forEach(listen);
    tell(ConnectionState.waiting);
  }

  void close() {
    source?.close();
    source = null;
  }
}

bool _pageEvents = false;

// Every stream closes when the page is hidden (a background tab, or kept for
// the back button: a browser allows 6 connections per host over HTTP/1.1) and
// opens again, asking for the value, when the page is visible.
void _watchPage() {
  if (_pageEvents) return;
  _pageEvents = true;
  void off() {
    for (final h in _hubs.values.toList()) {
      h.close();
      h.tell(ConnectionState.done);
    }
  }

  void on() {
    for (final h in _hubs.values.toList()) {
      if (h.source != null) continue;
      h.open();
      for (final s in [...h.subs]) {
        s.onResume();
      }
    }
  }

  web.window.addEventListener('pagehide', ((web.Event _) => off()).toJS);
  web.window.addEventListener(
    'pageshow',
    ((web.Event e) {
      if ((e as web.PageTransitionEvent).persisted && !web.document.hidden) {
        on();
      }
    }).toJS,
  );
  web.document.addEventListener(
    'visibilitychange',
    ((web.Event _) => web.document.hidden ? off() : on()).toJS,
  );
}

/// Adds [sub] to the hub of [path] (made if it is the first), or fails
/// (`done`) when [path] is not of this page's origin.
_Sub _acquire(String path, _Sub sub) {
  _watchPage();
  String? key;
  try {
    // `Uri.origin` throws for a scheme that has none (`javascript:`).
    final url = Uri.parse(web.window.location.href).resolve(path);
    if (url.origin == web.window.location.origin) key = url.toString();
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {}
  if (key == null) {
    web.console.error(
      "thor: events('$path') is not a path of this page's origin".toJS,
    );
    sub.onState(ConnectionState.done);
    return sub
      ..release = () {}
      ..reopen = () {};
  }
  var hub = _hubs[key];
  if (hub == null) {
    hub = _hubs[key] = _Hub(key);
    hub.subs.add(sub);
    hub.events.add(sub.event);
    hub.open();
  } else {
    hub.subs.add(sub);
    if (hub.events.add(sub.event) && hub.source != null) {
      hub.listen(sub.event);
    }
    sub.onState(hub.state);
  }
  final h = hub;
  sub
    ..release = () {
      if (!h.subs.remove(sub) || h.subs.isNotEmpty) return;
      h.close();
      if (identical(_hubs[key], h)) _hubs.remove(key);
    }
    ..reopen = () {
      if (!h.subs.contains(sub)) return;
      if (h.source == null || h.source!.readyState == web.EventSource.CLOSED) {
        h.open();
      }
    };
  return sub;
}

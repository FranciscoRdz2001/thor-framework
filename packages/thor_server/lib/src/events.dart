import 'dart:async';
import 'dart:convert';

import 'flash.dart';

/// One server-sent event (`text/event-stream`): what an `EventSource` in the
/// browser receives as a `MessageEvent`.
///
/// ```dart
/// ThorResponse.events(Stream.periodic(
///   const Duration(seconds: 1),
///   (i) => ServerEvent(jsonEncode({'n': i}), event: 'tick'),
/// ));
/// ```
final class ServerEvent {
  /// An event with [data] (any text; a line break splits it into several
  /// `data:` lines, which the browser joins back with `\n`).
  const ServerEvent(this.data, {this.event, this.id, this.retry});

  /// A message for the page's snack bar (the browser's `toast`), sent from
  /// the server: `ServerEvent.toast('main.dart changed on disk')`.
  ///
  /// Any `events()` stream of the page shows it (the lite engine listens
  /// for [toastEventName] on every stream it opens), whatever the stream's
  /// own events are, so a stream that carries data can mix toasts in. [kind]
  /// is how it looks, [duration] how long it stays (the snack bar's own when
  /// null; at most a minute). The message is text the page escapes, cut to
  /// [flashMaxLength]. A page with no snack bar drops it (and says so in the
  /// console).
  ///
  /// ```dart
  /// yield ServerEvent.toast('Saved by another tab', kind: FlashKind.success);
  /// ```
  factory ServerEvent.toast(
    String message, {
    FlashKind kind = FlashKind.info,
    Duration? duration,
    String? id,
  }) => ServerEvent(
    jsonEncode({
      'message': FlashMessage(message).message,
      'kind': kind.name,
      if (duration != null && duration > Duration.zero)
        'duration': duration.inMilliseconds,
    }),
    event: toastEventName,
    id: id,
  );

  /// The event name [ServerEvent.toast] sends and the browser listens for.
  static const toastEventName = 'thor-toast';

  /// The payload (`MessageEvent.data`).
  final String data;

  /// The event name (`addEventListener('tick', …)`); null: `message`.
  final String? event;

  /// The id the browser sends back as `Last-Event-ID` when it reconnects.
  final String? id;

  /// How long the browser waits before it reconnects, if the connection
  /// drops.
  final Duration? retry;

  /// The wire format: fields, one per line, ended by a blank line. A line
  /// break in [event] or [id] is dropped (it would end the field and
  /// forge another one), `\r` and `\r\n` in [data] are line breaks too.
  List<int> encode() {
    final out = StringBuffer();
    if (id != null) out.write('id: ${_field(id!)}\n');
    if (event != null) out.write('event: ${_field(event!)}\n');
    if (retry != null) out.write('retry: ${retry!.inMilliseconds}\n');
    for (final line in data.split(_lineBreak)) {
      out.write('data: $line\n');
    }
    out.write('\n');
    return utf8.encode(out.toString());
  }

  static final _lineBreak = RegExp(r'\r\n|\r|\n');

  static String _field(String v) => v.replaceAll(RegExp(r'[\r\n\x00]'), '');
}

/// [events] as the bytes of an event stream: a first comment (so the
/// headers reach the browser at once), a `: heartbeat` comment whenever
/// [heartbeat] passes with nothing sent (proxies close idle connections),
/// and the source cancelled the moment the consumer cancels (the client
/// left).
Stream<List<int>> eventStreamBytes(
  Stream<ServerEvent> events,
  Duration heartbeat,
) {
  late StreamController<List<int>> out;
  StreamSubscription<ServerEvent>? sub;
  Timer? timer;
  void arm() {
    timer?.cancel();
    if (heartbeat <= Duration.zero) return;
    timer = Timer(heartbeat, () {
      out.add(_heartbeatBytes);
      arm();
    });
  }

  out = StreamController<List<int>>(
    onListen: () {
      out.add(_connectedBytes);
      sub = events.listen(
        (e) {
          out.add(e.encode());
          arm();
        },
        onError: out.addError,
        onDone: () {
          timer?.cancel();
          out.close();
        },
      );
      arm();
    },
    onPause: () => sub?.pause(),
    onResume: () => sub?.resume(),
    onCancel: () {
      timer?.cancel();
      return sub?.cancel();
    },
  );
  return out.stream;
}

final _connectedBytes = utf8.encode(': connected\n\n');
final _heartbeatBytes = utf8.encode(': heartbeat\n\n');

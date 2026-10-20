import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// Internal: `ThorHttpClient`'s HTTP/1.1 over a plain `Socket`. The
// `dart:io` `HttpClient` costs a server that calls its API on every page
// ~10 % of its time (a `StackTrace.current` per request, its header maps,
// streams per body); this is the same protocol with one buffer per
// response. It keeps `HttpClient`'s contract where `ThorHttpClient` relies
// on it: keep-alive pool per origin with an idle timeout and a connection
// limit, redirects (GET/HEAD; a POST only on 303), gzip bodies decoded,
// the same exceptions for a socket the backend closed.

/// One response, read whole.
final class WireResponse {
  /// [status], [headers] and [body] as read.
  WireResponse(this.status, this.headers, this.body);

  /// HTTP status.
  final int status;

  /// Lower-case names; repeated values joined with `, `.
  final Map<String, String> headers;

  /// The body (decoded when it came gzip-compressed).
  final Uint8List body;
}

/// The body grew past the limit (the caller turns it into its own error).
final class WireTooLarge implements Exception {
  /// The limit was passed.
  const WireTooLarge();
}

/// What a deadline aborts: the wait for a connection, the connect, or the
/// exchange.
final class WireCall {
  void Function()? _abort;
  bool _aborted = false;

  /// The response's status line and headers arrived.
  bool started = false;

  /// Stops the call where it is (its future fails or is ignored).
  void abort() {
    _aborted = true;
    final abort = _abort;
    _abort = null;
    abort?.call();
  }
}

/// Keep-alive connections by origin.
final class WirePool {
  /// A pool; [connectionTimeout] bounds each connect.
  WirePool({
    required this.idleTimeout,
    required this.maxConnectionsPerHost,
    required this.connectionTimeout,
  });

  /// How long an unused connection stays open.
  final Duration idleTimeout;

  /// Open connections per origin, at most (more calls wait).
  final int maxConnectionsPerHost;

  /// Longest a connect may take.
  final Duration connectionTimeout;

  final _hosts = <String, _Host>{};
  bool _closed = false;

  /// Sends one request on a pooled connection to [uri]'s origin and reads
  /// its whole response. [headers] have lower-case names. Follows
  /// redirects like `HttpClient` up to [maxRedirects].
  Future<WireResponse> send(
    WireCall call,
    String method,
    Uri uri,
    Map<String, String> headers,
    List<int>? payload, {
    required int maxRedirects,
    required int maxResponseBytes,
  }) async {
    var currentMethod = method;
    var currentUri = uri;
    var currentHeaders = headers;
    var currentPayload = payload;
    final visited = <Uri>[];
    while (true) {
      final response = await _exchange(
        call,
        currentMethod,
        currentUri,
        currentHeaders,
        currentPayload,
        maxResponseBytes,
      );
      if (!_isRedirect(currentMethod, response.status)) return response;
      if (visited.length >= maxRedirects) {
        throw const RedirectException('Redirect limit exceeded', []);
      }
      final location = response.headers['location'];
      if (location == null) {
        throw const RedirectException(
          'Server response has no Location header for redirect',
          [],
        );
      }
      final next = currentUri.resolveUri(Uri.parse(location));
      if (visited.contains(next)) {
        throw const RedirectException('Redirect loop detected', []);
      }
      visited.add(next);
      if (response.status == HttpStatus.seeOther && currentMethod == 'POST') {
        currentMethod = 'GET';
      }
      // As `HttpClient`: credentials stay on the same site.
      final sameSite = _isSubdomain(next, currentUri);
      currentHeaders = {
        for (final e in currentHeaders.entries)
          if (sameSite ||
              !const {
                'authorization',
                'www-authenticate',
                'cookie',
                'cookie2',
              }.contains(e.key))
            e.key: e.value,
      };
      currentPayload = null;
      currentUri = next;
      call.started = false;
    }
  }

  static bool _isRedirect(String method, int status) {
    if (method == 'GET' || method == 'HEAD') {
      return status == 301 ||
          status == 302 ||
          status == 303 ||
          status == 307 ||
          status == 308;
    }
    return method == 'POST' && status == 303;
  }

  static bool _isSubdomain(Uri sub, Uri domain) =>
      sub.isScheme(domain.scheme) &&
      sub.port == domain.port &&
      (sub.host == domain.host || sub.host.endsWith('.${domain.host}'));

  Future<WireResponse> _exchange(
    WireCall call,
    String method,
    Uri uri,
    Map<String, String> headers,
    List<int>? payload,
    int maxResponseBytes,
  ) async {
    if (_closed) throw StateError('Client is closed');
    final head = _requestHead(method, uri, headers, payload?.length);
    final Uint8List bytes;
    if (payload == null || payload.isEmpty) {
      bytes = head;
    } else {
      bytes = Uint8List(head.length + payload.length)
        ..setAll(0, head)
        ..setAll(head.length, payload);
    }
    final secure = uri.isScheme('https');
    final port = uri.hasPort ? uri.port : (secure ? 443 : 80);
    final host = _hosts.putIfAbsent(
      '${secure ? 's' : ''}:${uri.host}:$port',
      () => _Host(this, uri.host, port, secure: secure),
    );
    final connection = await host.acquire(call);
    final response = await connection.exchange(
      call,
      bytes,
      head: method == 'HEAD',
      maxBytes: maxResponseBytes,
    );
    final decoded =
        response.headers['content-encoding']?.toLowerCase() == 'gzip' &&
            response.body.isNotEmpty
        ? _gunzip(response.body, maxResponseBytes)
        : response.body;
    return WireResponse(response.status, response.headers, decoded);
  }

  static Uint8List _gunzip(Uint8List body, int max) {
    final out = gzip.decode(body);
    if (out.length > max) throw const WireTooLarge();
    return out is Uint8List ? out : Uint8List.fromList(out);
  }

  /// Closes the idle connections; with [force], the busy ones too.
  void close({bool force = false}) {
    _closed = true;
    for (final host in _hosts.values) {
      host.close(force: force);
    }
  }

  // The characters of an HTTP token (RFC 9110 §5.6.2), by code unit.
  static final _token = () {
    final table = List<bool>.filled(128, false);
    const chars =
        '!#\$%&\'*+-.^_`|~0123456789'
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (final unit in chars.codeUnits) {
      table[unit] = true;
    }
    return table;
  }();

  static Uint8List _requestHead(
    String method,
    Uri uri,
    Map<String, String> headers,
    int? contentLength,
  ) {
    final path = uri.path.isEmpty ? '/' : uri.path;
    final target = uri.hasQuery ? '$path?${uri.query}' : path;
    final secure = uri.isScheme('https');
    final defaultPort = secure ? 443 : 80;
    final hostName = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
    final hostValue = !uri.hasPort || uri.port == defaultPort
        ? hostName
        : '$hostName:${uri.port}';
    final out = StringBuffer('$method $target HTTP/1.1\r\n');
    final all = <String, String>{
      'user-agent': _userAgent,
      'accept-encoding': 'gzip',
      'host': hostValue,
      ...headers,
      if (contentLength != null) 'content-length': '$contentLength',
    };
    all.forEach((name, value) {
      for (final unit in name.codeUnits) {
        if (unit >= 128 || !_token[unit]) {
          throw FormatException('Invalid HTTP header field name', name);
        }
      }
      for (final unit in value.codeUnits) {
        if (unit > 255 || unit == 10 || unit == 13 || unit == 0) {
          throw FormatException('Invalid HTTP header field value', value);
        }
      }
      out
        ..write(name)
        ..write(': ')
        ..write(value)
        ..write('\r\n');
    });
    out.write('\r\n');
    return latin1.encode(out.toString());
  }

  static final _userAgent = () {
    final version = Platform.version.split(' ').first;
    return 'Dart/${version.split('.').take(2).join('.')} (dart:io)';
  }();
}

/// The connections to one origin.
final class _Host {
  _Host(this.pool, this.host, this.port, {required this.secure});

  final WirePool pool;
  final String host;
  final int port;
  final bool secure;

  /// Open connections (busy, idle or connecting): at most the pool's limit.
  int _open = 0;
  final _idle = <_WireConnection>[];
  final _busy = <_WireConnection>{};
  final _waiters = Queue<Completer<_WireConnection?>>();

  Future<_WireConnection> acquire(WireCall call) async {
    while (_idle.isNotEmpty) {
      final c = _idle.removeLast();
      c.idleTimer?.cancel();
      if (c.closed) continue;
      c.reused = true;
      _busy.add(c);
      return c;
    }
    if (_open < pool.maxConnectionsPerHost) {
      _open++;
      return _connect(call);
    }
    final waiter = Completer<_WireConnection?>();
    _waiters.add(waiter);
    call._abort = () {
      if (_waiters.remove(waiter)) {
        waiter.completeError(const SocketException('Connection aborted'));
      }
    };
    final handed = await waiter.future;
    call._abort = null;
    if (handed != null) {
      if (call._aborted) {
        release(handed, reusable: true);
        throw const SocketException('Connection aborted');
      }
      _busy.add(handed);
      return handed;
    }
    // A slot freed up and is this call's: connect.
    return _connect(call);
  }

  Future<_WireConnection> _connect(WireCall call) async {
    try {
      if (call._aborted) throw const SocketException('Connection aborted');
      final task = secure
          ? await SecureSocket.startConnect(host, port)
          : await Socket.startConnect(host, port);
      call._abort = task.cancel;
      final socket = await task.socket.timeout(
        pool.connectionTimeout,
        onTimeout: () {
          task.cancel();
          throw SocketException(
            'HTTP connection timed out after ${pool.connectionTimeout}',
          );
        },
      );
      call._abort = null;
      if (call._aborted) {
        socket.destroy();
        throw const SocketException('Connection aborted');
      }
      // As `HttpClient`: a request goes out in one segment, now.
      socket.setOption(SocketOption.tcpNoDelay, true);
      final c = _WireConnection(this, socket);
      _busy.add(c);
      return c;
    } catch (_) {
      _slotFreed();
      rethrow;
    }
  }

  /// [c] finished an exchange: back to the pool, or closed.
  void release(_WireConnection c, {required bool reusable}) {
    _busy.remove(c);
    if (!reusable || c.closed || pool._closed) {
      c.destroy();
      return;
    }
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete(c);
      return;
    }
    _idle.add(c);
    c.idleTimer = Timer(pool.idleTimeout, c.destroy);
  }

  /// [c] closed (by either side): its slot goes to a waiter or is freed.
  void closed(_WireConnection c) {
    _busy.remove(c);
    _idle.remove(c);
    c.idleTimer?.cancel();
    _slotFreed();
  }

  void _slotFreed() {
    if (_waiters.isNotEmpty) {
      // The slot passes to the waiter, which connects.
      _waiters.removeFirst().complete(null);
    } else {
      _open--;
    }
  }

  void close({required bool force}) {
    for (final c in [..._idle]) {
      c.destroy();
    }
    if (force) {
      for (final c in [..._busy]) {
        c.destroy();
      }
    }
  }
}

/// One socket, one exchange at a time.
final class _WireConnection {
  _WireConnection(this.host, this.socket) {
    socket.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: true,
    );
    // Write errors also land here: never unhandled.
    unawaited(socket.done.then((_) {}, onError: _onError));
  }

  final _Host host;
  final Socket socket;
  Timer? idleTimer;
  bool closed = false;
  bool reused = false;
  _Exchange? _current;

  Future<_Parsed> exchange(
    WireCall call,
    Uint8List request, {
    required bool head,
    required int maxBytes,
  }) {
    final ex = _current = _Exchange(call, head: head, maxBytes: maxBytes);
    call._abort = destroy;
    if (closed) {
      _current = null;
      ex.fail(
        const HttpException(
          'Connection closed before full header was received',
        ),
      );
    } else {
      socket.add(request);
    }
    return ex.done.future.then((parsed) {
      call._abort = null;
      host.release(this, reusable: parsed.reusable);
      return parsed;
    });
  }

  void _onData(Uint8List data) {
    final ex = _current;
    if (ex == null) {
      // Bytes nobody asked for: the connection can't be trusted.
      destroy();
      return;
    }
    try {
      ex.feed(data);
    } on Object catch (e, st) {
      _current = null;
      destroy();
      ex.fail(e, st);
      return;
    }
    if (ex.done.isCompleted) _current = null;
  }

  void _onError(Object error, [StackTrace? st]) {
    final ex = _current;
    _current = null;
    destroy();
    ex?.fail(error, st);
  }

  void _onDone() {
    final ex = _current;
    _current = null;
    if (ex != null) {
      try {
        ex.end();
      } on Object catch (e, st) {
        ex.fail(e, st);
      }
    }
    destroy();
  }

  /// Closes the socket; an exchange in flight fails.
  void destroy() {
    if (closed) return;
    closed = true;
    socket.destroy();
    final ex = _current;
    _current = null;
    ex?.fail(const SocketException('Connection aborted'));
    host.closed(this);
  }
}

/// A response as read.
typedef _Parsed = ({
  int status,
  Map<String, String> headers,
  Uint8List body,
  bool reusable,
});

/// Reads one response off the socket's chunks.
final class _Exchange {
  _Exchange(this.call, {required this.head, required this.maxBytes});

  final WireCall call;
  final bool head;
  final int maxBytes;
  final done = Completer<_Parsed>();

  static const _readingHead = 0,
      _readingLength = 1,
      _readingChunkSize = 2,
      _readingChunk = 3,
      _readingChunkEnd = 4,
      _readingTrailers = 5,
      _readingToClose = 6,
      _finished = 7;

  int _state = _readingHead;
  // Bytes of the head (or of a chunk-size / trailer line) so far.
  final _line = BytesBuilder(copy: true);
  final _body = BytesBuilder(copy: true);
  int _remaining = 0;
  int _status = 0;
  bool _reusable = true;
  Map<String, String> _headers = const {};

  void fail(Object error, [StackTrace? st]) {
    if (!done.isCompleted) done.completeError(error, st);
  }

  void feed(Uint8List data) {
    var i = 0;
    while (i < data.length && _state != _finished) {
      switch (_state) {
        case _readingHead:
          i = _feedHead(data, i);
        case _readingLength:
          final n = _min(_remaining, data.length - i);
          _body.add(Uint8List.sublistView(data, i, i + n));
          i += n;
          _remaining -= n;
          if (_remaining == 0) _finish();
        case _readingChunkSize:
        case _readingChunkEnd:
        case _readingTrailers:
          final end = _indexOfLf(data, i);
          if (end < 0) {
            _line.add(Uint8List.sublistView(data, i));
            if (_line.length > 8192) {
              throw const HttpException('Invalid chunked encoding');
            }
            i = data.length;
          } else {
            _line.add(Uint8List.sublistView(data, i, end));
            i = end + 1;
            _onLine(latin1.decode(_line.takeBytes()).trimRight());
          }
        case _readingChunk:
          final n = _min(_remaining, data.length - i);
          _addBody(Uint8List.sublistView(data, i, i + n));
          i += n;
          _remaining -= n;
          if (_remaining == 0) _state = _readingChunkEnd;
        case _readingToClose:
          _addBody(Uint8List.sublistView(data, i));
          i = data.length;
      }
    }
    if (_state == _finished && i < data.length) {
      // More than one response: nothing pipelines here.
      _reusable = false;
    }
  }

  /// The socket closed.
  void end() {
    if (_state == _readingToClose) {
      _reusable = false;
      _finish();
    } else if (_state == _readingHead) {
      throw const HttpException(
        'Connection closed before full header was received',
      );
    } else if (_state != _finished) {
      throw const HttpException('Connection closed while receiving data');
    }
  }

  void _addBody(Uint8List bytes) {
    _body.add(bytes);
    if (_body.length > maxBytes) throw const WireTooLarge();
  }

  int _feedHead(Uint8List data, int from) {
    // The head ends at the first empty line; it may have started in an
    // earlier chunk, and its last four bytes may straddle two.
    var end = -1;
    final before = _line.length;
    if (before > 0) {
      final earlier = _line.toBytes();
      final tail = <int>[
        ...Uint8List.sublistView(earlier, before >= 3 ? before - 3 : 0),
        ...Uint8List.sublistView(data, from, _min(from + 3, data.length)),
      ];
      final at = _terminator(tail, 0);
      final back = before >= 3 ? 3 : before;
      if (at >= 0 && at < back) end = from + at + 4 - back;
    }
    if (end < 0) {
      final at = _terminator(data, from);
      if (at >= 0) end = at + 4;
    }
    if (end < 0) {
      _line.add(Uint8List.sublistView(data, from));
      if (_line.length > 65536) throw const HttpException('Header too large');
      return data.length;
    }
    _line.add(Uint8List.sublistView(data, from, end));
    final head = _line.takeBytes();
    _parseHead(latin1.decode(Uint8List.sublistView(head, 0, head.length - 4)));
    return end;
  }

  // Where `\r\n\r\n` starts in [bytes] at or after [from], or -1.
  static int _terminator(List<int> bytes, int from) {
    for (var k = from; k + 3 < bytes.length; k++) {
      if (bytes[k] == 13 &&
          bytes[k + 1] == 10 &&
          bytes[k + 2] == 13 &&
          bytes[k + 3] == 10) {
        return k;
      }
    }
    return -1;
  }

  void _parseHead(String text) {
    final lines = text.split('\r\n');
    final status = lines.first;
    if (!status.startsWith('HTTP/1.') || status.length < 12) {
      throw HttpException('Invalid response line: $status');
    }
    final code = int.tryParse(status.substring(9, 12));
    if (code == null) throw HttpException('Invalid response line: $status');
    final headers = <String, String>{};
    for (var k = 1; k < lines.length; k++) {
      final line = lines[k];
      final colon = line.indexOf(':');
      if (colon <= 0) throw const HttpException('Invalid response header');
      final name = line.substring(0, colon).trim().toLowerCase();
      final value = line.substring(colon + 1).trim();
      final old = headers[name];
      headers[name] = old == null ? value : '$old, $value';
    }
    if (code >= 100 && code < 200) {
      if (code == 101) throw const HttpException('Unexpected 101');
      // An interim answer (100 Continue): the real one follows.
      return;
    }
    _status = code;
    _headers = headers;
    call.started = true;
    final connection = headers['connection']?.toLowerCase() ?? '';
    _reusable = status.startsWith('HTTP/1.1')
        ? !connection.contains('close')
        : connection.contains('keep-alive');
    if (head || code == 204 || code == 304) {
      _finish();
      return;
    }
    final transfer = headers['transfer-encoding']?.toLowerCase();
    if (transfer != null && transfer.contains('chunked')) {
      _state = _readingChunkSize;
      return;
    }
    final length = headers['content-length'];
    if (length != null) {
      final n = int.tryParse(length.split(',').first.trim());
      if (n == null || n < 0) throw const HttpException('Invalid length');
      if (n > maxBytes) throw const WireTooLarge();
      _remaining = n;
      if (n == 0) {
        _finish();
      } else {
        _state = _readingLength;
      }
      return;
    }
    _state = _readingToClose;
  }

  void _onLine(String line) {
    switch (_state) {
      case _readingChunkSize:
        final semi = line.indexOf(';');
        final size = int.tryParse(
          (semi < 0 ? line : line.substring(0, semi)).trim(),
          radix: 16,
        );
        if (size == null || size < 0) {
          throw const HttpException('Invalid chunked encoding');
        }
        if (size == 0) {
          _state = _readingTrailers;
        } else {
          _remaining = size;
          _state = _readingChunk;
        }
      case _readingChunkEnd:
        if (line.isNotEmpty) {
          throw const HttpException('Invalid chunked encoding');
        }
        _state = _readingChunkSize;
      case _readingTrailers:
        if (line.isEmpty) _finish();
    }
  }

  void _finish() {
    _state = _finished;
    if (!done.isCompleted) {
      done.complete((
        status: _status,
        headers: _headers,
        body: _body.takeBytes(),
        reusable: _reusable,
      ));
    }
  }

  static int _min(int a, int b) => a < b ? a : b;

  static int _indexOfLf(Uint8List data, int from) {
    for (var k = from; k < data.length; k++) {
      if (data[k] == 10) return k;
    }
    return -1;
  }
}

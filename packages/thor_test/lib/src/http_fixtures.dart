/// Fake backends for tests: the calls a page's `load` makes through a
/// `ThorHttpClient` are answered by fixtures, never by the network.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:thor_server/thor_server.dart';

/// A canned answer for [MockTransport] and [withHttpFixtures].
class ThorHttpFixture {
  /// An answer with [status], [headers] and a raw [body].
  const ThorHttpFixture(
    this.body, {
    this.status = 200,
    this.headers = const {},
  });

  /// A JSON answer (`content-type: application/json`).
  ThorHttpFixture.json(
    Object? value, {
    this.status = 200,
    Map<HttpHeader, String> headers = const {},
  }) : body = utf8.encode(jsonEncode(value)),
       headers = {HttpHeader.contentType: 'application/json', ...headers};

  /// A text answer.
  ThorHttpFixture.text(
    String value, {
    this.status = 200,
    Map<HttpHeader, String> headers = const {},
  }) : body = utf8.encode(value),
       headers = {
         HttpHeader.contentType: 'text/plain; charset=utf-8',
         ...headers,
       };

  /// The HTTP status.
  final int status;

  /// The headers (lower-case names).
  final Map<HttpHeader, String> headers;

  /// The body.
  final List<int> body;

  ThorHttpResponse _answer(ThorHttpRequest req) => ThorHttpResponse(
    uri: req.uri,
    method: req.method,
    statusCode: status,
    headers: headers,
    bytes: Uint8List.fromList(body),
  );
}

/// A call no fixture answered. An [Error], not an exception: the page's
/// `load` does not turn it into a `502`, and [withHttpFixtures] and
/// `ThorTestClient(httpOverrides:)` rethrow it even when the page caught
/// it, so a test never passes over an accidental network call.
class UnmockedHttpRequest extends Error {
  /// A call to [method] [uri] that nothing answered.
  UnmockedHttpRequest(this.method, this.uri, [this.hint = '']);

  /// The request's method.
  final HttpMethod method;

  /// The URL.
  final Uri uri;

  /// What to do about it.
  final String hint;

  @override
  String toString() =>
      'UnmockedHttpRequest: no fixture for $method $uri'
      '${hint.isEmpty ? '' : '\n$hint'}';
}

/// Answers `ThorHttpClient` calls from a test.
///
/// ```dart
/// final fake = MockTransport.fixtures({
///   'GET https://api.example.com/items/1': {'id': 1},
///   'https://api.example.com/search*': ThorHttpFixture.json([], status: 200),
///   'POST https://api.example.com/cart': (req) => {'got': req.json()},
/// });
/// final app = appHandler().client(httpOverrides: fake);
/// ```
class MockTransport {
  /// A transport that asks [answer]: a [ThorHttpFixture] (or
  /// [ThorHttpResponse], or any JSON value, sent as a `200`), or `null` when
  /// nothing matches the request.
  MockTransport(this.answer, {String hint = ''}) : _hint = hint;

  /// Matches `'METHOD url'` or `'url'` (any method) to an answer: a
  /// [ThorHttpFixture], a [ThorHttpResponse], a function of the
  /// [ThorHttpRequest] returning one of those, or any other value (JSON, a
  /// `200`). A key ending in `*` matches by prefix. The exact keys win over
  /// the prefixes.
  factory MockTransport.fixtures(Map<String, Object?> fixtures) {
    final exact = <String, Object?>{};
    final prefixes = <MapEntry<String, Object?>>[];
    for (final e in fixtures.entries) {
      if (e.key.endsWith('*')) {
        prefixes.add(e);
      } else {
        exact[e.key] = e.value;
      }
    }
    return MockTransport((req) {
      final url = req.uri.removeFragment().toString();
      final method = req.method;
      final keys = ['$method $url', url];
      for (final k in keys) {
        if (exact.containsKey(k)) return _resolve(exact[k], req);
      }
      for (final p in prefixes) {
        final key = p.key.substring(0, p.key.length - 1);
        if (_prefixMatches(key, '$method $url') || _prefixMatches(key, url)) {
          return _resolve(p.value, req);
        }
      }
      return null;
    });
  }

  /// Replays the responses saved in [directory] (`test/fixtures`), one JSON
  /// file per request. With [record] (default: `THOR_HTTP_RECORD=1` in the
  /// environment, what `thor test --record` sets) the call goes over the
  /// real network and its response is saved instead. The request's headers
  /// are not saved (no tokens in the repo).
  factory MockTransport.recorded(String directory, {bool? record}) {
    final recording = record ?? Platform.environment['THOR_HTTP_RECORD'] == '1';
    return MockTransport((req) async {
      final file = File('$directory/${_fileName(req)}');
      if (recording) {
        final real = await req.network();
        await file.parent.create(recursive: true);
        await file.writeAsString(_encodeRecording(real));
        return real;
      }
      if (!file.existsSync()) return null;
      return _decodeRecording(
        jsonDecode(await file.readAsString()) as Map<String, Object?>,
        req,
      );
    }, hint: 'no recording: run with THOR_HTTP_RECORD=1 (thor test --record)');
  }

  /// What answers; `null` means "no fixture for this".
  final FutureOr<Object?> Function(ThorHttpRequest request) answer;

  final String _hint;

  /// Every call seen, in order, answered or not (assert on `.json()` of the
  /// body, the headers…).
  final List<ThorHttpRequest> requests = [];

  /// The calls nothing answered.
  final List<UnmockedHttpRequest> unmatched = [];

  /// Throws the first [unmatched] call, if any.
  void verify() {
    if (unmatched.isNotEmpty) throw unmatched.first;
  }

  /// The transport to hand to `runWithThorHttpTransport`.
  Future<ThorHttpResponse> call(ThorHttpRequest req) async {
    requests.add(req);
    final out = await answer(req);
    if (out == null) {
      final error = UnmockedHttpRequest(req.method, req.uri, _hint);
      unmatched.add(error);
      throw error;
    }
    return _coerce(out, req);
  }

  /// [url] starts with [key]; a key that stops inside the authority
  /// (`https://a.com`) must stop at its end, so it never matches
  /// `https://a.com.evil.io` or `https://a.com@evil.io`.
  static bool _prefixMatches(String key, String url) {
    if (!url.startsWith(key)) return false;
    final scheme = key.indexOf('://');
    if (scheme < 0 || key.indexOf('/', scheme + 3) >= 0) return true;
    final rest = url.substring(key.length);
    return rest.isEmpty || '/?#:'.contains(rest[0]);
  }

  static Object? _resolve(Object? value, ThorHttpRequest req) =>
      value is Object? Function(ThorHttpRequest) ? value(req) : value;

  static FutureOr<ThorHttpResponse> _coerce(Object? out, ThorHttpRequest req) {
    if (out is Future<Object?>) return out.then((v) => _coerce(v, req));
    return switch (out) {
      final ThorHttpResponse r => r,
      final ThorHttpFixture f => f._answer(req),
      _ => ThorHttpFixture.json(out)._answer(req),
    };
  }

  static final _secretParam = RegExp(
    'token|key|secret|pass|pwd|auth|sig|credential|session|jwt|bearer|code',
    caseSensitive: false,
  );

  /// [uri] as it is saved: no fragment, no `user:pass@`, and the value of
  /// every query parameter that looks like a credential replaced, so a
  /// recording (and its file name) never holds a secret, and a rotated token
  /// still finds its recording.
  static String _redacted(Uri uri) {
    final clean = uri.removeFragment();
    final query = clean.hasQuery
        ? clean.query
              .split('&')
              .map((pair) {
                final eq = pair.indexOf('=');
                final name = eq < 0 ? pair : pair.substring(0, eq);
                return eq >= 0 &&
                        _secretParam.hasMatch(Uri.decodeQueryComponent(name))
                    ? '$name=REDACTED'
                    : pair;
              })
              .join('&')
        : null;
    return Uri(
      scheme: clean.scheme,
      host: clean.host,
      port: clean.hasPort ? clean.port : null,
      path: clean.path,
    ).replace(query: query).toString();
  }

  static String _fileName(ThorHttpRequest req) {
    final url = _redacted(req.uri);
    // FNV-1a: stable across runs and platforms (String.hashCode is not
    // promised to be). It covers the body too: two POSTs to one URL are two
    // recordings.
    var h = 0xcbf29ce484222325;
    for (final c in [
      ...utf8.encode('${req.method} $url'),
      if (req.bodyBytes.isNotEmpty) ...[0, ...req.bodyBytes],
    ]) {
      h = ((h ^ c) * 0x100000001b3) & 0x7fffffffffffffff;
    }
    final slug = url
        .replaceFirst(RegExp('^https?://'), '')
        .replaceAll(RegExp('[^A-Za-z0-9]+'), '_');
    final short = slug.length > 60 ? slug.substring(0, 60) : slug;
    return '${req.method}_${short}_${h.toRadixString(16)}.json';
  }

  static String _encodeRecording(ThorHttpResponse r) {
    Object? json;
    try {
      json = r.bytes.isEmpty ? null : r.json();
      // Saved as JSON only when it replays byte for byte (`1e2` or a big
      // integer would not).
      if (json != null && jsonEncode(json) != utf8.decode(r.bytes)) json = null;
    } on Object {
      json = null;
    }
    final contentType = r.headers['content-type'];
    return '${const JsonEncoder.withIndent('  ').convert({
      'method': r.method.token,
      'url': _redacted(r.uri),
      'status': r.statusCode,
      'headers': {'content-type': ?contentType},
      if (json != null) 'json': json else 'text': _tryText(r.bytes) ?? '',
      if (json == null && _tryText(r.bytes) == null) 'base64': base64.encode(r.bytes),
    })}\n';
  }

  static String? _tryText(Uint8List b) {
    try {
      return utf8.decode(b);
    } on FormatException {
      return null;
    }
  }

  static ThorHttpResponse _decodeRecording(
    Map<String, Object?> m,
    ThorHttpRequest req,
  ) => ThorHttpResponse(
    uri: req.uri,
    method: req.method,
    statusCode: m['status']! as int,
    headers: {
      for (final e in (m['headers']! as Map).entries)
        HttpHeader('${e.key}'): '${e.value}',
    },
    bytes: Uint8List.fromList(
      m.containsKey('json')
          ? utf8.encode(jsonEncode(m['json']))
          : m.containsKey('base64')
          ? base64.decode(m['base64']! as String)
          : utf8.encode((m['text'] as String?) ?? ''),
    ),
  );
}

/// Runs [body] with [fixtures] answering every `ThorHttpClient` call in it,
/// whatever client holds (a global one too). A call nothing matches throws
/// [UnmockedHttpRequest] naming the method and URL, and the run fails with
/// it even if the page swallowed the error.
///
/// ```dart
/// test('the search lists the results', () async {
///   await withHttpFixtures({
///     'GET https://api.example.com/search?q=shoes': {'items': [{'name': 'A'}]},
///   }, () async {
///     final res = await appHandler().client().get('/search?q=shoes');
///     expect(res.html.querySelectorAll('li'), hasLength(1));
///   });
/// });
/// ```
Future<T> withHttpFixtures<T>(
  Map<String, Object?> fixtures,
  FutureOr<T> Function() body,
) => withHttpMock(MockTransport.fixtures(fixtures), body);

/// [withHttpFixtures] with a ready [MockTransport] (to read its
/// [MockTransport.requests] afterwards).
Future<T> withHttpMock<T>(
  MockTransport mock,
  FutureOr<T> Function() body,
) async {
  final result = await runWithThorHttpTransport(mock.call, () async => body());
  mock.verify();
  return result;
}

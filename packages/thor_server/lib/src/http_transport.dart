import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'http_client.dart';
import 'http_types.dart';

/// What a [ThorHttpClient] call sends, as a [ThorHttpTransport] sees it.
class ThorHttpRequest {
  /// A request to [method] [uri]. [network] sends it for real.
  ThorHttpRequest(
    this.method,
    this.uri,
    this.headers,
    this.bodyBytes,
    this._network,
  );

  /// The method.
  final HttpMethod method;

  /// The URL.
  final Uri uri;

  /// The headers the call carries (the client's and the call's), lower-case
  /// names.
  final Map<HttpHeader, String> headers;

  /// The body (empty when there is none).
  final Uint8List bodyBytes;

  final Future<ThorHttpResponse> Function() _network;

  /// The body as UTF-8 text.
  String get text => utf8.decode(bodyBytes);

  /// The body as JSON (`null` when empty).
  Object? json() => bodyBytes.isEmpty ? null : jsonDecode(text);

  /// Sends the request over the real network, bypassing the fake (to record
  /// a response, or to let one URL through).
  Future<ThorHttpResponse> network() => _network();

  @override
  String toString() => '$method $uri';
}

/// Answers the calls of every [ThorHttpClient] instead of the network,
/// inside [runWithThorHttpTransport]. For tests.
typedef ThorHttpTransport =
    FutureOr<ThorHttpResponse> Function(ThorHttpRequest request);

/// The zone key [runWithThorHttpTransport] sets.
const Object thorHttpTransportKey = #thor.httpTransport;

/// Runs [body] with [transport] answering every [ThorHttpClient] call made
/// in its zone (futures, `defer`red values and streams started inside it
/// keep the zone). A client held in a global needs no change; the zone is
/// the whole switch, as with `HttpOverrides.runZoned` in `dart:io`. In
/// production nothing sets it: a call pays one zone lookup.
///
/// ```dart
/// await runWithThorHttpTransport(
///   (req) => ThorHttpResponse(
///     uri: req.uri, method: req.method, statusCode: 200,
///     bytes: Uint8List.fromList(utf8.encode('{"id":1}')),
///   ),
///   () => api.getJson('https://api.example.com/items/1'),
/// );
/// ```
R runWithThorHttpTransport<R>(ThorHttpTransport transport, R Function() body) =>
    runZoned(body, zoneValues: {thorHttpTransportKey: transport});

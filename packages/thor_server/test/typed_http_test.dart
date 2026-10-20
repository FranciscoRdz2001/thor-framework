import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

void main() {
  group('HttpMethod', () {
    test('parses the request line, case-sensitive', () {
      expect(HttpMethod.tryParse('GET'), HttpMethod.get);
      expect(HttpMethod.tryParse('PATCH'), HttpMethod.patch);
      expect(HttpMethod.tryParse('get'), isNull);
      expect(HttpMethod.tryParse('PROPFIND'), isNull);
    });

    test('isRead is GET and HEAD only', () {
      expect(
        [
          for (final m in HttpMethod.values)
            if (m.isRead) m,
        ],
        [HttpMethod.get, HttpMethod.head],
      );
    });

    test('prints its token', () {
      expect('${HttpMethod.post}', 'POST');
      expect(HttpMethod.options.token, 'OPTIONS');
    });
  });

  group('StatusCode', () {
    test('is an int, and says its class', () {
      const int status = StatusCode.notFound;
      expect(status, 404);
      expect(StatusCode.ok.isSuccess, isTrue);
      expect(StatusCode.found.isRedirect, isTrue);
      expect(StatusCode.forbidden.isClientError, isTrue);
      expect(StatusCode.badGateway.isServerError, isTrue);
      expect(const StatusCode(418).isClientError, isTrue);
    });

    test('HttpError and ThorResponse take it', () {
      expect(const HttpError(StatusCode.conflict).status, 409);
      expect(ThorResponse(StatusCode.noContent).status, 204);
    });
  });

  test('HttpHeader names are the lowercase spelling the maps use', () {
    final request = PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://site.test/'),
      headers: {const HttpHeader('Accept-Language'): 'es'},
    );
    expect(request.headers[HttpHeader.acceptLanguage], 'es');
  });

  group('cors', () {
    test('cors takes HttpMethod and writes the tokens', () async {
      final middleware = cors(
        origins: ['https://app.test'],
        methods: [HttpMethod.get, HttpMethod.put],
      );
      final response = await middleware(
        PageRequest(
          method: HttpMethod.options,
          uri: Uri.parse('http://site.test/api'),
          headers: {
            HttpHeader.origin: 'https://app.test',
            HttpHeader.accessControlRequestMethod: 'PUT',
          },
        ),
        () async => ThorResponse(StatusCode.ok),
      );
      expect(response.status, 204);
      expect(response.headers['access-control-allow-methods'], 'GET, PUT');
    });

    test("'*' with credentials throws", () {
      expect(
        () => cors(origins: ['*'], credentials: true),
        throwsArgumentError,
      );
      expect(
        () => cors(origins: ['https://a.test', '*'], credentials: true),
        throwsArgumentError,
      );
      expect(() => cors(origins: ['*']), returnsNormally);
      expect(
        () => cors(origins: ['https://a.test'], credentials: true),
        returnsNormally,
      );
    });

    test("'*' answers '*'; credentials echo the listed origin", () async {
      Future<ThorResponse> from(Middleware middleware) async => middleware(
        PageRequest(
          method: HttpMethod.get,
          uri: Uri.parse('http://site.test/api'),
          headers: {HttpHeader.origin: 'https://app.test'},
        ),
        () async => ThorResponse(StatusCode.ok),
      );
      final open = await from(cors(origins: ['*']));
      expect(open.headers['access-control-allow-origin'], '*');
      expect(
        open.headers.containsKey('access-control-allow-credentials'),
        isFalse,
      );
      final signed = await from(
        cors(origins: ['https://app.test'], credentials: true),
      );
      expect(signed.headers['access-control-allow-origin'], 'https://app.test');
      expect(signed.headers['access-control-allow-credentials'], 'true');
    });

    test('default methods are what routes serve', () async {
      final response = await cors(origins: ['https://app.test'])(
        PageRequest(
          method: HttpMethod.options,
          uri: Uri.parse('http://site.test/api'),
          headers: {
            HttpHeader.origin: 'https://app.test',
            HttpHeader.accessControlRequestMethod: 'GET',
          },
        ),
        () async => ThorResponse(StatusCode.ok),
      );
      expect(
        response.headers['access-control-allow-methods'],
        'GET, HEAD, POST',
      );
    });
  });
}

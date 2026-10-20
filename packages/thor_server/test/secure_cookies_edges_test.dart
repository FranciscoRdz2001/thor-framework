// Adversarial edges of `Secure` on cookies: header parsing, deletion,
// SameSite=None and the SECURE_COOKIES variable.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

RouteHandler<String> _handler([bool? secure]) => RouteHandler<String>(
  renderer: _Renderer(),
  secureCookies: secure,
  routes: [
    PageRoute<String, void>(
      load: (r) {
        r.response.setCookie('a', '1');
        r.response.setCookie('gone', '', maxAge: Duration.zero);
        r.response.setCookie('cross', '1', sameSite: 'None');
        r.response.setCookie('crossLower', '1', sameSite: 'none');
        r.response.setCookie('crossOff', '1', sameSite: 'None', secure: false);
        r.response.setCookie('strict', '1', sameSite: 'Strict');
      },
      build: (_) => 'x',
    ),
  ],
);

Future<Map<String, String>> _cookies(
  RouteHandler<String> h, {
  String scheme = 'http',
  Map<HttpHeader, String> headers = const {},
}) async {
  final r = await h.handle(
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('$scheme://site.test/'),
      headers: {HttpHeader.host: 'site.test', ...headers},
    ),
  );
  return {for (final c in r.cookies) c.split('=').first: c};
}

bool _isSecure(String header) => header.split('; ').contains('Secure');

void main() {
  group('the proxy header', () {
    test('Forwarded: any case, quoted, spaces around =', () async {
      for (final v in [
        'proto=https',
        'Proto=HTTPS',
        'PROTO="https"',
        'for=1.2.3.4; proto = https',
        'for="[2001:db8::1]:4711";by=x;proto=https',
        'proto=https, proto=http',
      ]) {
        final c = await _cookies(
          _handler(),
          headers: {const HttpHeader('forwarded'): v},
        );
        expect(_isSecure(c['a']!), isTrue, reason: v);
      }
    });

    test('Forwarded: not https in the first hop is not Secure', () async {
      for (final v in [
        'proto=http;for=1.2.3.4, proto=https',
        'for=1.2.3.4',
        'proto=',
        'proto=https=x',
        'protox=https',
        'by=proto=https',
        '',
      ]) {
        final c = await _cookies(
          _handler(),
          headers: {const HttpHeader('forwarded'): v},
        );
        expect(_isSecure(c['a']!), isFalse, reason: v);
      }
    });

    test('X-Forwarded-Proto wins over Forwarded when both come', () async {
      final c = await _cookies(
        _handler(),
        headers: {
          HttpHeader.xForwardedProto: 'http',
          const HttpHeader('forwarded'): 'proto=https',
        },
      );
      expect(_isSecure(c['a']!), isFalse);
    });

    test(
      'the deletion of a cookie carries the same Secure as its set',
      () async {
        final https = await _cookies(_handler(), scheme: 'https');
        expect(https['gone'], contains('Max-Age=0'));
        expect(_isSecure(https['gone']!), isTrue);
        final http = await _cookies(_handler());
        expect(_isSecure(http['gone']!), isFalse);
      },
    );
  });

  group('SameSite=None', () {
    test(
      'needs Secure even over http (a browser drops it otherwise)',
      () async {
        final c = await _cookies(_handler());
        expect(_isSecure(c['cross']!), isTrue);
        expect(_isSecure(c['crossLower']!), isTrue);
        expect(_isSecure(c['strict']!), isFalse);
      },
    );

    test('secureCookies false does not undo it', () async {
      final c = await _cookies(_handler(false));
      expect(_isSecure(c['cross']!), isTrue);
    });

    test('an explicit secure: false on the cookie is respected', () async {
      final c = await _cookies(_handler(), scheme: 'https');
      expect(_isSecure(c['crossOff']!), isFalse);
    });
  });

  group('SECURE_COOKIES', () {
    const secure = EnvOptional(EnvBool('SECURE_COOKIES'));
    const schema = EnvSchema([secure]);

    test('unset is null, true and false as written, in any case', () {
      expect(schema.load({}).of(secure), isNull);
      for (final t in ['true', 'TRUE', '1', 'yes', ' True ']) {
        expect(
          schema.load({'SECURE_COOKIES': t}).of(secure),
          isTrue,
          reason: t,
        );
      }
      for (final f in ['false', 'False', '0', 'no']) {
        expect(
          schema.load({'SECURE_COOKIES': f}).of(secure),
          isFalse,
          reason: f,
        );
      }
    });

    test('garbage stops the start instead of guessing', () {
      for (final junk in ['maybe', 'tru', 'on', '2']) {
        expect(
          () => schema.load({'SECURE_COOKIES': junk}),
          throwsA(anything),
          reason: junk,
        );
      }
    });
  });
}

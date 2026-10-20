import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

abstract final class _Env {
  static const api = EnvUrl('API_URL', fallback: 'https://api.example.com');
  static const port = EnvInt('PORT', fallback: 4300);
  static const secure = EnvBool('SECURE_COOKIES', fallback: false);
  static const title = EnvString('SITE_TITLE', public: true);
  static const session = EnvSecret('SESSION_SECRET', minLength: 20);
  static const schema = EnvSchema([api, port, secure, title, session]);
}

const _secret = 'a-very-secret-value-0123456789';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

RouteHandler<String> _handler(String Function() body) => RouteHandler<String>(
  renderer: _Renderer(),
  onError: (request, error, stack) {},
  routes: [PageRoute<String, void>(build: (s) => body())],
);

PageRequest _get(String path) => PageRequest(
  method: HttpMethod.get,
  uri: Uri.parse('http://site.test$path'),
  headers: const {HttpHeader.host: 'site.test'},
);

void main() {
  tearDown(() {
    Secret.forgetAll();
    ThorDev.enabled = false;
  });

  test('every value typed, with fallbacks for the unset ones', () {
    final env = _Env.schema.load({
      'SITE_TITLE': 'Acme',
      'SESSION_SECRET': _secret,
      'SECURE_COOKIES': 'YES',
    });
    expect(env.of(_Env.api), Uri.parse('https://api.example.com'));
    expect(env.of(_Env.port), 4300);
    expect(env.of(_Env.secure), isTrue);
    expect(env.of(_Env.title), 'Acme');
    expect(env.of(_Env.session).reveal(), _secret);
  });

  test('lists every problem at once (THOR-P011), not the first', () {
    expect(
      () => _Env.schema.load({
        'API_URL': 'ftp://nope',
        'PORT': '43a',
        'SECURE_COOKIES': 'maybe',
        'SESSION_SECRET': 'short',
      }),
      throwsA(
        isA<EnvError>()
            .having((e) => e.problems, 'problems', hasLength(5))
            .having(
              (e) => e.toString(),
              'message',
              allOf(
                contains('THOR-P011'),
                contains('API_URL: not an http(s) URL'),
                contains('PORT: not a whole number'),
                contains('SECURE_COOKIES: not true or false'),
                contains('SITE_TITLE: missing'),
                contains('SESSION_SECRET: shorter than 20'),
              ),
            ),
      ),
    );
  });

  test('an empty value counts as unset; a name twice is a problem', () {
    final env = _Env.schema.load({
      'PORT': '',
      'SITE_TITLE': 'x',
      'SESSION_SECRET': _secret,
    });
    expect(env.of(_Env.port), 4300);
    expect(
      () => const EnvSchema([
        EnvInt('PORT', fallback: 1),
        EnvString('PORT', fallback: 'a'),
      ]).load(const {}),
      throwsA(
        isA<EnvError>().having(
          (e) => e.problems.single,
          'problem',
          contains('declared twice'),
        ),
      ),
    );
  });

  test('EnvOptional: null when unset, checked like its variable when set', () {
    const isolates = EnvOptional(EnvInt('ISOLATES'));
    const key = EnvOptional(EnvSecret('KEY', minLength: 4));
    const schema = EnvSchema([isolates, key]);
    final unset = schema.load(const {});
    expect(unset.of(isolates), isNull);
    expect(unset.of(key), isNull);
    final set = schema.load(const {'ISOLATES': '2', 'KEY': 'abcd'});
    expect(set.of(isolates), 2);
    expect(set.of(key)!.reveal(), 'abcd');
    expect(
      () => schema.load(const {'ISOLATES': 'two', 'KEY': 'ab'}),
      throwsA(
        isA<EnvError>().having((e) => e.problems, 'problems', [
          'ISOLATES: not a whole number',
          'KEY: shorter than 4 characters',
        ]),
      ),
    );
  });

  test('a variable of another schema is an error', () {
    final env = _Env.schema.load({
      'SITE_TITLE': 'x',
      'SESSION_SECRET': _secret,
    });
    expect(
      () => env.of(const EnvString('OTHER', fallback: 'x')),
      throwsA(
        isA<ArgumentError>().having(
          (e) => '$e',
          'message',
          allOf(
            contains('OTHER is not in the EnvSchema'),
            contains('SITE_TITLE'),
            contains('Add it to the `EnvSchema([...])` list'),
            contains('THOR-P011'),
          ),
        ),
      ),
    );
  });

  test('a secret never prints, never becomes JSON, and is never public', () {
    final env = _Env.schema.load({
      'SITE_TITLE': 'Acme',
      'SESSION_SECRET': _secret,
    });
    final secret = env.of(_Env.session);
    expect('$secret', '***');
    expect(() => jsonEncode({'s': secret}), throwsA(anything));
    expect(env.public, {'SITE_TITLE': 'Acme'});
    expect(jsonEncode(env.public), isNot(contains(_secret)));
  });

  group('a secret that reaches a page (THOR-P012)', () {
    setUp(
      () => _Env.schema.load({'SITE_TITLE': 'x', 'SESSION_SECRET': _secret}),
    );

    test('is a 500 under thor dev, without the value', () async {
      ThorDev.enabled = true;
      final r = await _handler(() => 'token=$_secret').handle(_get('/'));
      expect(r.status, 500);
      expect(r.text, contains('THOR-P012'));
      expect(r.text, isNot(contains(_secret)));
    });

    test('a page without it is untouched', () async {
      ThorDev.enabled = true;
      final r = await _handler(() => 'hello').handle(_get('/'));
      expect(r.status, 200);
      expect(r.text, 'hello');
    });

    test('stops a static export in any mode', () async {
      final out = await Directory.systemTemp.createTemp('thor_env_');
      addTearDown(() => out.delete(recursive: true));
      await expectLater(
        exportSite(
          _handler(() => '<p>$_secret</p>'),
          paths: const ['/'],
          outDir: out.path,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('THOR-P012'), isNot(contains(_secret))),
          ),
        ),
      );
      expect(File('${out.path}/index.html').existsSync(), isFalse);
    });
  });
}

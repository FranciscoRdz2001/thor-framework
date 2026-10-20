// safeNext against the hostile inputs of Django's
// `url_has_allowed_host_and_scheme` (django/utils/http.py): backslash read as
// a slash, three slashes, a scheme without a host, a leading control
// character, a length cap (MAX_URL_LENGTH = 2048), plus percent-encoding and
// full-width characters.
import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

void main() {
  final request = PageRequest(
    method: HttpMethod.post,
    uri: Uri.parse('https://shop.example/login'),
  );
  String next(String v) => safeNext(request, v, fallback: const RouteUrl('FB'));

  const hostile = [
    r'/\evil.com',
    r'\/evil.com',
    r'/\/evil.com',
    '/%2F%2Fevil.com',
    '/%09/evil.com',
    '/%0d/evil.com',
    '/%5c/evil.com',
    '／／evil.com',
    'javascript:alert(1)',
    'https://evil.example\\@shop.example/x',
    'https:/evil.example',
    'https:evil.example',
    'https:///evil.example',
    'ht\ttps://evil.example',
    'https://shop.example/\t/evil.example',
    'https://shop.example/%2F%2Fevil.com',
    ' /cart',
    '\u0000/cart',
    'https://xn--shop.example/',
    'https://shop.example%2eevil.com/',
    'https://shop.example.:443/x',
  ];
  for (final bad in hostile) {
    test('refuses ${Uri.encodeFull(bad)}', () => expect(next(bad), 'FB'));
  }

  test('an absolute URL of this origin keeps path, query and fragment', () {
    expect(
      next('https://shop.example:443/x?a=//evil.com#//e'),
      startsWith('/x'),
    );
    expect(next('/a?next=//evil.com#frag'), '/a?next=//evil.com#frag');
  });

  test('full-width slashes after the first one are only characters', () {
    expect(next('/／evil.com'), '/%EF%BC%8Fevil.com');
  });

  test('an input over 2048 characters is refused (Django: MAX_URL_LENGTH)', () {
    expect(next('/${'a' * 2047}'), isNot('FB'));
    expect(next('/${'a' * 2048}'), 'FB');
    expect(next('/${'a' * 100000}'), 'FB');
  });

  test('whatever comes out is a path of this site', () {
    for (final input in hostile) {
      final out = next(input);
      expect(
        out == 'FB' ||
            (out.startsWith('/') &&
                !out.startsWith('//') &&
                !RegExp(r'[\\\x00-\x1f\x7f]').hasMatch(out)),
        isTrue,
        reason: input,
      );
    }
  });
}

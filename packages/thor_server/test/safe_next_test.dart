import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

void main() {
  final request = PageRequest(
    method: HttpMethod.post,
    uri: Uri.parse('https://shop.example/login'),
  );
  String next(String? v, {String fallback = '/'}) =>
      safeNext(request, v, fallback: RouteUrl(fallback));

  test('same-origin paths pass, with query and fragment', () {
    expect(next('/cart'), '/cart');
    expect(next('/orders?page=2#top'), '/orders?page=2#top');
    expect(next('/caf%C3%A9'), '/caf%C3%A9');
    expect(next('/'), '/');
  });

  test('a same-origin absolute URL becomes its path', () {
    expect(next('https://shop.example/cart?a=1'), '/cart?a=1');
  });

  test('nothing to go back to is the fallback', () {
    expect(next(null), '/');
    expect(next(''), '/');
    expect(next(null, fallback: '/home'), '/home');
  });

  for (final bad in [
    'https://evil.example/x',
    'http://shop.example/x', // another scheme is another origin
    'https://shop.example.evil.example/x',
    'https://shop.example@evil.example/x',
    '//evil.example/x',
    '///evil.example',
    '/\\evil.example',
    '\\\\evil.example',
    '\\/evil.example',
    'evil.example',
    'cart',
    'javascript:alert(1)',
    'JaVaScRiPt:alert(1)',
    ' javascript:alert(1)',
    'data:text/html,x',
    '/%2F/evil.example',
    '/%2f%2fevil.example',
    '/%5Cevil.example',
    '/%252F%252Fevil.example', // double encoded
    '/%0A/evil.example',
    '/\t/evil.example',
    '/\n/evil.example',
    '/x\r\nSet-Cookie: a=b',
    '/%E0%A4%A', // malformed escape
    '/∕evil.example', // division slash: not a slash for a browser, but
  ]) {
    test('refuses ${bad.replaceAll('\n', r'\n').replaceAll('\t', r'\t')}', () {
      final got = next(bad, fallback: '/safe');
      // `/∕…` is a path on this site: allowed, encoded.
      if (bad == '/∕evil.example') {
        expect(got, startsWith('/%E2%88%95'));
      } else {
        expect(got, '/safe');
      }
    });
  }
}

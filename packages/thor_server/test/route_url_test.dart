import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

void main() {
  test('it is a String, so a String API takes it', () {
    const String path = RouteUrl('/orders');
    expect(path, '/orders');
    expect(const RouteUrl('/orders').uri.path, '/orders');
  });

  test('external accepts http, https, mailto and tel only', () {
    expect(RouteUrl.external('https://example.com/x'), 'https://example.com/x');
    expect(RouteUrl.external('mailto:a@b.test'), 'mailto:a@b.test');
    expect(RouteUrl.external('tel:+34123'), 'tel:+34123');
    for (final bad in [
      'javascript:alert(1)',
      'data:text/html,x',
      '/relative',
      'ftp://x',
    ]) {
      expect(() => RouteUrl.external(bad), throwsArgumentError, reason: bad);
    }
  });

  test('isExternal: a scheme or a scheme-relative URL leaves the site', () {
    expect(const RouteUrl('/a').isExternal, isFalse);
    expect(const RouteUrl('#top').isExternal, isFalse);
    expect(const RouteUrl('?p=2').isExternal, isFalse);
    expect(const RouteUrl('https://example.com').isExternal, isTrue);
    expect(const RouteUrl('//example.com').isExternal, isTrue);
  });

  test('withQuery replaces the query and keeps the fragment', () {
    expect(
      const RouteUrl('/s?q=old#top').withQuery({
        'q': 'shoes',
        'f': ['red', 'size 9'],
        'none': <String>[],
      }),
      '/s?q=shoes&f=red&f=size+9#top',
    );
    expect(const RouteUrl('/s?q=1').withQuery({}), '/s');
    expect(() => const RouteUrl('/s').withQuery({'n': 1}), throwsArgumentError);
  });

  test('withFragment sets or clears the fragment', () {
    expect(const RouteUrl('/a#x').withFragment('y z'), '/a#y%20z');
    expect(const RouteUrl('/a#x').withFragment(''), '/a');
  });

  test('Redirect carries it', () {
    expect(const Redirect(RouteUrl('/x')).location, '/x');
    expect(const Redirect.permanent(RouteUrl('/y')).status, 308);
    expect(const Redirect.moved(RouteUrl('/y')).status, 301);
  });

  test('safeNext answers a RouteUrl', () {
    final request = PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('https://shop.example/login'),
    );
    expect(safeNext(request, '/orders?x=1'), isA<RouteUrl>());
    expect(safeNext(request, '//evil.example'), '/');
    expect(
      safeNext(request, 'https://evil.example', fallback: const RouteUrl('/a')),
      '/a',
    );
  });
}

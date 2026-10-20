import 'package:test/test.dart';
import 'package:thor_cli/src/templates.dart';

void main() {
  // `Link.href` is a `RouteUrl`: an app without `homeRoute` gets a literal
  // one, never a bare String (which does not compile).
  for (final (name, file) in [
    ('error', errorFile()),
    ('not found', notFoundFile()),
  ]) {
    test('the $name page without an app links home with a RouteUrl', () {
      expect(file, contains("Link(href: RouteUrl('/')"));
      expect(file, isNot(contains("href: '/'")));
    });
  }
}

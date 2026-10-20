import 'dart:io';

import 'package:test/test.dart';

import '../error_codes.dart';

void main() {
  test('every error code has its page, every page its use', () {
    // Run from the repository root (tool/thor check does).
    expect(checkErrorCodes(Directory.current.path), isEmpty);
  });

  group('the check', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('thor_codes_');
      Directory('${root.path}/docs/errores').createSync(recursive: true);
    });
    tearDown(() => root.deleteSync(recursive: true));

    void lib(String package, String file, String text) =>
        File('${root.path}/packages/$package/lib/$file')
          ..createSync(recursive: true)
          ..writeAsStringSync(text);
    void page(String code, {String title = 'Algo'}) => File(
      '${root.path}/docs/errores/$code.md',
    ).writeAsStringSync('# $code · $title\n\n');
    void index(List<String> codes) =>
        File('${root.path}/docs/errores/README.md').writeAsStringSync(
          [for (final c in codes) '| [$c]($c.md) | x |'].join('\n'),
        );
    const helper = "const u = '$errorsUrl';";

    test('a consistent repository passes', () {
      lib('thor_ui', 'errors.dart', helper);
      lib('thor_ui', 'a.dart', "thorError('THOR-R001', 'x')");
      lib('thor_engine', 'client.dart', "'no member (THOR-S005)'");
      page('THOR-R001');
      page('THOR-S005');
      index(['THOR-R001', 'THOR-S005']);
      expect(checkErrorCodes(root.path), isEmpty);
    });

    test('a code without a page, and a page nobody uses', () {
      lib('thor_ui', 'errors.dart', helper);
      lib('thor_ui', 'a.dart', "thorError('THOR-R002', 'x')");
      page('THOR-R003');
      index(['THOR-R003']);
      final problems = checkErrorCodes(root.path);
      expect(problems, hasLength(2));
      expect(
        problems,
        contains(startsWith('THOR-R002 (packages/thor_ui/lib/a.dart:1)')),
      );
      expect(problems, contains(contains('no package uses THOR-R003')));
    });

    test('a page without its row, or with a wrong heading', () {
      lib('thor_ui', 'errors.dart', helper);
      lib('thor_ui', 'a.dart', "'THOR-L001'");
      File('${root.path}/docs/errores/THOR-L001.md').writeAsStringSync('# x');
      index([]);
      final problems = checkErrorCodes(root.path);
      expect(problems, contains(contains('must start with')));
      expect(problems, contains(contains('no row for THOR-L001')));
    });

    test('a package may reuse thor_style\'s helper, and then holds no URL', () {
      lib('thor_style', 'errors.dart', helper);
      lib('thor_style', 'a.dart', "thorError('THOR-R001', 'x')");
      lib(
        'thor_server',
        'errors.dart',
        "export 'package:thor_style/errors.dart' show thorError;",
      );
      lib('thor_server', 'a.dart', "thorError('THOR-P001', 'x')");
      page('THOR-R001');
      page('THOR-P001');
      index(['THOR-R001', 'THOR-P001']);
      expect(checkErrorCodes(root.path), isEmpty);
      lib('thor_server', 'b.dart', helper);
      expect(
        checkErrorCodes(root.path),
        contains(startsWith('thor_server: reuses thor_style')),
      );
    });

    test('the URL has no language in it: the site redirects', () {
      expect(errorsUrl, isNot(contains('/es/')));
      expect(errorsUrl, endsWith('/errores/'));
    });

    test('a package without its URL helper; the engine without the URL', () {
      lib('thor_server', 'a.dart', "'THOR-P001'");
      lib('thor_engine', 'b.dart', "'THOR-S005 $errorsUrl'");
      page('THOR-P001');
      page('THOR-S005');
      index(['THOR-P001', 'THOR-S005']);
      final problems = checkErrorCodes(root.path);
      expect(problems, contains(startsWith('thor_server: uses error codes')));
      expect(
        problems,
        contains('thor_engine: a code-only package has the URL'),
      );
    });
  });
}

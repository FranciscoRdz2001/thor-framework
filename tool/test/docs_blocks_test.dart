import 'package:test/test.dart';

import '../docs_blocks.dart';

DocBlock block(String code, {List<String> info = const []}) =>
    DocBlock(file: 'p.md', line: 1, lang: 'dart', info: info, code: code);

void main() {
  group('extractBlocks', () {
    test('finds fenced blocks with their language, info and first line', () {
      const md = '''
# Title

```dart no-check
a();
```

text

```bash
thor dev
```
''';
      final blocks = extractBlocks(md, file: 'x.md');
      expect(blocks, hasLength(2));
      expect(blocks[0].lang, 'dart');
      expect(blocks[0].skip, isTrue);
      expect(blocks[0].line, 4);
      expect(blocks[0].code, 'a();');
      expect(blocks[1].lang, 'bash');
      expect(blocks[1].skip, isFalse);
      expect(blocks[1].toString(), 'x.md:10');
    });

    test('strips the indentation of a fence inside a list', () {
      final b = extractBlocks(
        '- item\n\n  ```dart\n  final a = 1;\n    b();\n  ```\n',
      ).single;
      expect(b.code, 'final a = 1;\n  b();');
    });

    test('a path comment names the file of the project', () {
      expect(block('// lib/catalog.dart\nclass A {}').path, 'lib/catalog.dart');
      expect(block('// in lib/catalog.dart\nclass A {}').path, isNull);
    });
  });

  group('wrapBlock', () {
    WrapKind kind(String code) => wrapBlock(block(code)).kind;

    test('declarations are a library', () {
      expect(kind('class A {}'), WrapKind.library);
      expect(kind('final a = 1;\nint f() => a;'), WrapKind.library);
    });

    test('statements and widgets one after another', () {
      expect(kind('a();\nb();'), WrapKind.statements);
      expect(kind('Text(a)\nText(b)'), WrapKind.sequence);
    });

    test('one expression, with its trailing comma', () {
      expect(kind('Text(a),'), WrapKind.expression);
    });

    test('the elements of a list and the arguments of a call', () {
      expect(
        kind('for (final i in xs)\n  Text(i),\nText(2),'),
        WrapKind.elements,
      );
      expect(kind('padding: x,\nchild: y,'), WrapKind.expression); // a record
    });

    test('members of a class, even with an @override', () {
      expect(kind('@override\nvoid f() {}'), WrapKind.members);
      expect(kind('int get a => 1;\nvoid f() {}'), WrapKind.library);
    });

    test('a class and the widget that uses it side by side', () {
      final w = wrapBlock(block('class A {}\n\nText(a)\nText(b)'));
      expect(w.kind, WrapKind.mixed);
      // The widgets are the third and fourth lines of the block.
      final lines = w.source.split('\n');
      final text = lines.indexWhere((l) => l.startsWith('Text(a)')) + 1;
      expect(w.blockLine(text), 3);
    });

    test('imports go on top of the statements', () {
      final w = wrapBlock(
        block("import 'dart:io';\n\nfinal a = 1;\nprint(a);"),
      );
      expect(w.source.trimLeft(), startsWith("import 'dart:io';"));
      expect(w.kind, isNot(WrapKind.unparseable));
    });

    test('a page placeholder (an ellipsis) is not Dart', () {
      final w = wrapBlock(block('Text(…)\nText(1)'));
      expect(w.kind, WrapKind.unparseable);
      expect(w.errors, isNotEmpty);
    });

    test('the prelude goes in front, only when the block imports nothing', () {
      const prelude = "import 'package:a/a.dart';\n";
      expect(
        wrapBlock(block('class A {}'), prelude: prelude).source,
        startsWith(prelude),
      );
      expect(
        wrapBlock(
          block("import 'dart:io';\nclass A {}"),
          prelude: prelude,
        ).source,
        isNot(contains('package:a')),
      );
    });

    test('line numbers map back to the block', () {
      const prelude = "import 'package:a/a.dart';\n";
      for (final code in [
        'class A {}\nclass B {}',
        'a();\nb();',
        'Text(a)\nText(b)',
      ]) {
        final w = wrapBlock(block(code), prelude: prelude);
        final lines = w.source.split('\n');
        final second =
            lines.indexWhere(
              (l) =>
                  l.contains('b()') ||
                  l.contains('Text(b)') ||
                  l.contains('class B'),
            ) +
            1;
        expect(w.blockLine(second), 2, reason: code);
      }
    });
  });

  group('separate', () {
    test('puts the mark between pieces that close what they open', () {
      expect(separate('Text(a)\nText(b)', ';'), 'Text(a);\nText(b);');
      expect(
        separate('Row(\n  children: [a],\n)\nText(b)', ','),
        'Row(\n  children: [a],\n),\nText(b),',
      );
    });

    test('leaves a continuation alone', () {
      expect(separate('a\n  .b()\n  .c()', ';'), 'a\n  .b()\n  .c();');
    });

    test('skips comments between pieces', () {
      expect(separate('a()\n// next\nb()', ';'), 'a();\n// next\nb();');
    });
  });

  group('sections', () {
    test('a block without markers is one section', () {
      final s = sections(block('a();'));
      expect(s, hasLength(1));
      expect(s.single.wrong, isFalse);
    });

    test(
      'cuts at WRONG and RIGHT, and only the WRONG ones are not checked',
      () {
        final s = sections(block('// WRONG: x\na();\n\n// RIGHT\nb();'));
        expect(s.map((e) => e.wrong), [true, false]);
        expect(s[1].block.line, 4);
        expect(s[1].block.code, '// RIGHT\nb();');
      },
    );
  });
}

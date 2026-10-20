import 'dart:io';

import 'package:docs/core/content/library.dart';
import 'package:docs/core/content/llms.dart';
import 'package:docs/core/i18n/docs_locale.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('docs_llms');
    Directory('${dir.path}/guia/es').createSync(recursive: true);
    File('${dir.path}/guia/es/estado.md').writeAsStringSync('''
# Estado

Lo que cambia vive en `ThorState`.

:::warning
Cuidado con **esto**: ver [Datos](datos.md#cache) y [Flutter](https://flutter.dev).
:::

:::note Con título
Una nota.
:::

:::example counter open
:::

:::tabs
@tab Uno
Texto uno.
@tab Dos
Texto dos.
:::

```dart
// [no](cambia.md)
final a = 1;
```
''');
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  String md(String name, String source) {
    File('${dir.path}/guia/es/$name.md').writeAsStringSync(source);
    return guideMarkdown(
      Guide('empezar', name, (t) => name),
      locale: 'es',
      baseUrl: 'https://docs.test',
      dir: dir.path,
    );
  }

  final guide = Guide('datos-y-estado', 'estado', (t) => t.pageState);

  test('a guide as Markdown: callouts as quotes, links absolute', () {
    final md = guideMarkdown(
      guide,
      locale: 'es',
      baseUrl: 'https://docs.test/',
      dir: dir.path,
    );
    expect(md, contains('> **Importante:** Cuidado con **esto**: ver '));
    // A guide's link is its Markdown; an outside one is kept.
    expect(
      md,
      contains(
        '](https://docs.test/es/datos-y-estado/red-y-servidor.md#cache)',
      ),
    );
    expect(md, contains('](https://flutter.dev)'));
    expect(md, contains('> **Con título:** Una nota.'));
    expect(md, contains('#### Uno\nTexto uno.\n#### Dos'));
    expect(md, isNot(contains(':::')));
    expect(md, isNot(contains('counter')));
    // Code is left as written.
    expect(md, contains('// [no](cambia.md)'));
  });

  test('without a base URL the links are paths', () {
    final md = guideMarkdown(guide, locale: 'es', dir: dir.path);
    expect(md, contains('](/es/datos-y-estado/red-y-servidor.md#cache)'));
  });

  group('attacks', () {
    test('a directive touching its text keeps the lines apart', () {
      final out = md(
        'pegado',
        '# T\n\nUn párrafo.\n:::note\nNota.\n:::\nOtro párrafo.\n',
      );
      expect(
        out,
        contains('Un párrafo.\n\n> **Nota:** Nota.\n\nOtro párrafo.'),
      );
      expect(out, isNot(contains('párrafo.> ')));
      expect(out, isNot(contains('Nota.Otro')));
    });

    test('a callout with a list and code stays one quote', () {
      final out = md('lista', '''
# T

:::warning
Antes de seguir:

- uno con [Datos](datos.md)
- dos

```dart
final a = 1;
```

Después.
:::

Fuera.
''');
      expect(
        out,
        contains(
          '> **Importante:** Antes de seguir:\n>\n> - uno con [Datos](https://docs.test/es/datos-y-estado/red-y-servidor.md)\n> - dos\n>\n> ```dart\n> final a = 1;\n> ```\n>\n> Después.\n\nFuera.',
        ),
      );
    });

    test('a labelled quote with a code block is kept, under its shown label', () {
      final out = md(
        'cita',
        '# T\n\n> **Ojo:** primera\n> segunda\n>\n> ```dart\n> a();\n> ```\n\nFin.\n',
      );
      expect(
        out,
        contains(
          '> **Importante:** primera\n> segunda\n>\n> ```dart\n> a();\n> ```\n\nFin.',
        ),
      );
    });

    test('a callout at the end of the file, closed or not', () {
      final closed = md('fin', '# T\n\n:::tip\nÚltima.\n:::');
      expect(closed, endsWith('> **Consejo:** Última.'));
      final open = md('fin2', '# T\n\n:::tip\nSin cerrar.');
      expect(open, endsWith('> **Consejo:** Sin cerrar.'));
      expect(open, isNot(contains(':::')));
    });

    test('a link inside inline code is not rewritten', () {
      final out = md(
        'codigo',
        '# T\n\nEscribe `[Título](datos.md)` y [va](datos.md).\n',
      );
      expect(out, contains('`[Título](datos.md)`'));
      expect(
        out,
        contains('[va](https://docs.test/es/datos-y-estado/red-y-servidor.md)'),
      );
    });
  });

  test('summary never ends on a half sentence', () {
    final long =
        'Cómo colocar los widgets en Thor. Casi todo se comporta igual; '
        '${'y así sigue una frase larga sin punto final ' * 6}';
    final cut = summary(long, max: 100);
    expect(cut, isNot(endsWith(';')));
    expect(cut, isNot(endsWith(':')));
    expect(cut.length, lessThanOrEqualTo(100));
  });

  test('summary cuts at a sentence', () {
    expect(summary('Corto.'), 'Corto.');
    final long = '${'Una frase de relleno. ' * 12}Y otra sin fin';
    final cut = summary(long, max: 100);
    expect(cut.length, lessThanOrEqualTo(100));
    expect(cut, endsWith('.'));
    expect(summary(null), '');
  });

  group('the real guide', () {
    late Directory out;
    setUpAll(() {
      out = Directory.systemTemp.createTempSync('docs_llms_out');
      writeMarkdownFiles(
        out.path,
        intro: 'llms-intro.md',
        baseUrl: 'https://docs.test',
      );
    });
    tearDownAll(() => out.deleteSync(recursive: true));

    test('every guide has its .md, with no directives left', () {
      for (final g in allGuides) {
        final file = File('${out.path}/es${g.path}.md');
        expect(file.existsSync(), isTrue, reason: g.path);
        final md = file.readAsStringSync();
        expect(md, startsWith('# '), reason: g.path);
        expect(md, isNot(contains('\n:::')), reason: g.path);
        expect(md, isNot(contains(RegExp(r'\]\([a-z-]+\.md'))), reason: g.path);
      }
    });

    test('llms.txt: the rules, every guide once, the API and the errors', () {
      final text = File('${out.path}/es/llms.txt').readAsStringSync();
      expect(text, startsWith('# thor'));
      for (final g in allGuides) {
        expect(text, contains('(https://docs.test/es${g.path}.md)'));
      }
      expect(text, contains('(https://docs.test/es/api/thor_ui)'));
      expect(text, contains('(https://docs.test/es/errores)'));
      expect('## Optional'.allMatches(text), hasLength(1));
      // The default language's is also at the root, its pages spelled in it.
      final en = File('${out.path}/llms.txt').readAsStringSync();
      expect(File('${out.path}/en/llms.txt').readAsStringSync(), en);
      for (final g in allGuides) {
        expect(en, contains('(https://docs.test/en${g.pathIn('en')}.md)'));
        expect(File('${out.path}/en${g.pathIn('en')}.md').existsSync(), isTrue);
      }
      expect(en, contains('(https://docs.test/en/errors)'));
      expect(en, contains('## Get started'));
    });

    test('llms-full.txt: every anchor is unique and every # link lands', () {
      for (final locale in docsLocales) {
        final text = File(
          '${out.path}/$locale/llms-full.txt',
        ).readAsStringSync();
        final ids = [
          for (final m in RegExp(r'<a id="([^"]+)"></a>').allMatches(text))
            m[1]!,
        ];
        expect(ids, isNotEmpty);
        expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate anchors');
        // Each page's anchors carry its slug.
        if (locale == 'es') expect(ids, contains('estado-listas'));
        final broken = <String>[];
        var fenced = false;
        for (final line in text.split('\n')) {
          if (line.trimLeft().startsWith('```')) fenced = !fenced;
          if (fenced) continue;
          for (final m in RegExp(r'\]\(#([^)\s]+)\)').allMatches(line)) {
            if (!ids.contains(m[1])) broken.add(m[1]!);
          }
        }
        expect(broken, isEmpty, reason: locale);
        // A link to another guide's section is an anchor of this file.
        expect([
          for (final l in text.split('\n'))
            if (l.contains('docs.test/$locale/') && l.contains('.md#')) l,
        ], isEmpty);
      }
    });

    test('anchors of the concatenated pages, on a small guide', () {
      final dir = Directory.systemTemp.createTempSync('docs_llms_full');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory('${dir.path}/guia/es').createSync(recursive: true);
      File('${dir.path}/guia/es/estado.md').writeAsStringSync(
        '# Estado\n\n## Uso\n\nVer [abajo](#uso-1) y [Datos](red-y-servidor.md#uso).\n\n'
        '## Uso\n\n```md\n## Uso\n[no](#uso)\n```\n',
      );
      File(
        '${dir.path}/guia/es/red-y-servidor.md',
      ).writeAsStringSync('# Datos\n\n## Uso\n');
      final text = llmsFullTxt(
        'intro',
        locale: 'es',
        baseUrl: 'https://docs.test',
        dir: dir.path,
        guides: [
          Guide('datos-y-estado', 'estado', (t) => t.pageState),
          Guide('datos-y-estado', 'red-y-servidor', (t) => t.pageState),
        ],
      );
      expect(text, contains('<a id="estado-uso"></a>\n\n## Uso'));
      expect(text, contains('<a id="estado-uso-1"></a>\n\n## Uso'));
      expect(text, contains('<a id="red-y-servidor-uso"></a>'));
      expect(
        text,
        contains('[abajo](#estado-uso-1) y [Datos](#red-y-servidor-uso)'),
      );
      // Code is left as written.
      expect(text, contains('```md\n## Uso\n[no](#uso)\n```'));
    });

    test('llms-full.txt holds every guide under its address', () {
      final text = File('${out.path}/es/llms-full.txt').readAsStringSync();
      for (final g in allGuides) {
        expect(text, contains('Fuente: https://docs.test/es${g.path}\n'));
      }
      expect(File('${out.path}/llms-full.txt').readAsStringSync(), isNot(text));
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:docs/app.dart';
import 'package:docs/core/content/library.dart';
import 'package:docs/core/content/redirects.dart';
import 'package:docs/core/i18n/docs_locale.dart';
import 'package:test/test.dart';

import '../bin/redirects.dart' show redirectsConfig;

void main() {
  test('every old guide address goes to a page of the site, or to a URL', () {
    final pages = {...sitePaths(), '/cambios'};
    for (final MapEntry(:key, :value) in legacyGuideTargets.entries) {
      if (value.startsWith('http')) continue;
      expect(
        pages,
        contains(value.split('#').first),
        reason: '/guia/$key → $value',
      );
    }
  });

  test('every old address has its redirect page in the export', () {
    final redirects = legacyRedirects(sitePaths());
    expect(redirects.keys, contains('/guia/tutorial'));
    expect(redirects['/guia/tutorial'], '/en/get-started/first-app');
    expect(redirects['/guia/capa-web'], '/en/fundamentals/widgets');
    // `/api` has no page: the export writes `api.html` that redirects.
    expect(redirects['/api'], '/en/api/thor_ui');
    expect(redirects['/api/thor_ui'], '/en/api/thor_ui');
    expect(redirects['/buscar'], '/en/search');
    expect(redirects['/errores/THOR-B012'], '/en/errors/THOR-B012');
    expect(
      redirects['/api/thor_ui/controles/FilledButton'],
      '/en/api/thor_ui/controls/FilledButton',
    );
    expect(redirects['/en/recetas/contador'], '/en/examples/counter');
    // A page that already has a language is an old address only when it
    // changed section.
    expect(redirects.keys.where((k) => k.startsWith('/es')).toSet(), {
      for (final key in legacySectionTargets.keys) '/es$key',
    });
    expect(redirects['/es/aprender/widgets'], '/es/fundamentos/widgets');
    // The examples were the recipes.
    expect(redirects['/es/recetas/recetas'], '/es/ejemplos/ejemplos');
    expect(redirects['/es/recetas/contador'], '/es/ejemplos/contador');
    expect(redirects['/es/cookbook/recetas'], '/es/ejemplos/ejemplos');
    expect(
      redirects['/es/ui/iconos'],
      '/es/componentes/componentes-contenido#icon',
    );
    final page = redirectPage('/es/empezar/primera-app');
    expect(page, contains('http-equiv="refresh" content="0; url=/es/'));
    expect(page, contains('rel="canonical" href="/es/empezar/primera-app"'));
    expect(page, contains('noindex'));
  });

  test('every page that changed section goes to a page of the site', () {
    final pages = sitePaths().toSet();
    for (final MapEntry(:key, :value) in legacySectionTargets.entries) {
      expect(pages, isNot(contains(key)), reason: '$key is still a page');
      expect(pages, contains(value.split('#').first), reason: '$key → $value');
    }
  });

  test('the guide has no slug twice and every slug is a section page', () {
    final slugs = [for (final g in allGuides) g.slug];
    expect(slugs.toSet(), hasLength(slugs.length));
    for (final g in allGuides) {
      expect(g.path, '/${g.section}/${g.slug}');
      final folder = g.section == examplesSection && g.slug != examplesSection
          ? 'ejemplos/'
          : '';
      expect(g.file(sourceLocale), 'guia/$sourceLocale/$folder${g.slug}.md');
      expect(
        g.file('en'),
        'guia/en/${folder.isEmpty ? '' : 'examples/'}${g.slugIn('en')}.md',
      );
    }
  });

  test('deploy/vercel.json is what redirects.dart writes', () {
    final file = File('deploy/vercel.json').readAsStringSync();
    final config = jsonDecode(file) as Map<String, Object?>;
    expect(
      file,
      redirectsConfig(config),
      reason: 'run `dart run bin/redirects.dart` in apps/docs',
    );
  });
}

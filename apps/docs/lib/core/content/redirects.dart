/// Where the old addresses of the site go.
///
/// The guide used to live at `/guia/<slug>` (and the API, the error codes,
/// the changes and the search at `/api`, `/errores`, `/cambios` and
/// `/buscar`, without a language). Every old URL still answers: with a
/// permanent redirect on the server, with a small page that refreshes to the
/// new one in the static export (`bin/export.dart`), and with a rule in
/// `deploy/vercel.json` (`dart run bin/redirects.dart` writes it from here).
library;

import 'dart:convert';

import '../i18n/docs_locale.dart';

/// Every slug the guide ever had at `/guia/<slug>` and where it is now: a
/// route's own path (`/empezar/primera-app`, the language goes in front), or
/// a URL. A page that left the site lands on the nearest page.
const legacyGuideTargets = {
  // Get started.
  'que-es-thor': '/empezar/que-es-thor',
  'instalacion': '/empezar/instalacion',
  'entorno': '/datos-y-estado/sesion-y-seguridad#entorno-y-secretos',
  'tutorial': '/empezar/primera-app',
  'desde-flutter': '/empezar/desde-flutter',
  // Fundamentals.
  'widgets-y-layout': '/fundamentos/layout',
  'layout': '/fundamentos/layout',
  'interactividad': '/fundamentos/interactividad',
  'rutas': '/fundamentos/navegacion',
  'rutas-y-datos': '/fundamentos/navegacion',
  // Architecture.
  'estructura': '/arquitectura/estructura',
  'arquitectura': '/arquitectura/como-funciona',
  // Interface.
  'estilos-y-tema': '/interfaz/tema-y-estilos',
  'animaciones': '/interfaz/animaciones',
  'transiciones': '/interfaz/animaciones',
  'gestos': '/interfaz/gestos',
  'dialogos-y-menus': '/interfaz/dialogos-y-menus',
  'i18n': '/interfaz/idiomas',
  'flutter-embebido': '/interfaz/flutter-embebido',
  // Data and state.
  'estado': '/datos-y-estado/estado',
  'datos': '/datos-y-estado/red-y-servidor',
  'formularios': '/datos-y-estado/formularios',
  'listas-largas': '/datos-y-estado/listas-largas',
  'sesiones-y-seguridad': '/datos-y-estado/sesion-y-seguridad',
  'paquetes': '/datos-y-estado/paquetes',
  // Test and deploy.
  'testing': '/publicar/pruebas',
  'cli': '/publicar/cli',
  'herramientas': '/publicar/cli',
  'estatico-o-servidor': '/publicar/publicar',
  'deploy': '/publicar/publicar',
  'seo': '/publicar/seo',
  // Components.
  'catalogo': '/componentes/componentes',
  'componentes': '/componentes/componentes',
  'componentes-botones': '/componentes/componentes-botones',
  'componentes-entradas': '/componentes/componentes-entradas',
  'componentes-seleccion': '/componentes/componentes-seleccion',
  'componentes-contenido': '/componentes/componentes-contenido',
  'componentes-navegacion': '/componentes/componentes-navegacion',
  'componentes-avisos': '/componentes/componentes-avisos',
  'iconos': '/componentes/componentes-contenido#icon',
  // Examples.
  '7guis': '/ejemplos/ejemplos',
  'paginas-de-contenido': '/ejemplos/pagina-de-contenido',
  // Gone from the site: what covers them, or the home page.
  'capa-web': '/fundamentos/widgets',
};

/// The anchors of [legacyGuideTargets] that are a heading's slug, in the
/// languages whose heading reads differently: [localizePath] translates the
/// path, not the fragment.
const legacyAnchors = {
  'en': {'entorno-y-secretos': 'environment-and-secrets'},
};

/// [target] with its fragment in [locale] ([legacyAnchors]).
String localizeAnchor(String locale, String target) {
  final hash = target.indexOf('#');
  if (hash < 0) return target;
  final anchor = target.substring(hash + 1);
  final translated = legacyAnchors[locale]?[anchor] ?? anchor;
  return '${target.substring(0, hash)}#$translated';
}

/// The pages that moved from one section to another (or left the site), by
/// their old path (`/<section>/<slug>`, without the language) and where they
/// are now. The old paths had a language in front: each one redirects in
/// every language (`/es/aprender/widgets` → `/es/fundamentos/widgets`).
final legacySectionTargets = {
  for (final slug in ['widgets', 'layout', 'interactividad', 'navegacion'])
    '/aprender/$slug': '/fundamentos/$slug',
  '/aprender/leer-datos': '/fundamentos/leer-datos',
  '/arquitectura/recomendaciones': '/arquitectura/arquitectura',
  for (final slug in [
    'tema-y-estilos',
    'animaciones',
    'gestos',
    'dialogos-y-menus',
    'accesibilidad',
    'idiomas',
  ])
    '/ui/$slug': '/interfaz/$slug',
  '/ui/listas-largas': '/datos-y-estado/listas-largas',
  '/ui/iconos': '/componentes/componentes-contenido#icon',
  '/pruebas-y-herramientas/pruebas': '/publicar/pruebas',
  '/pruebas-y-herramientas/cli': '/publicar/cli',
  '/desplegar/estatico-o-servidor': '/publicar/publicar',
  '/desplegar/desplegar': '/publicar/publicar',
  '/desplegar/seo': '/publicar/seo',
  // The examples were the cookbook (`/cookbook/…`), then the recipes
  // (`/recetas/…`, its index `/recetas/recetas`).
  for (final old in ['cookbook', 'recetas'])
    for (final slug in [
      'recetas',
      'contador',
      'temperatura',
      'vuelos',
      'temporizador',
      'crud',
      'circulos',
      'celdas',
      'pagina-de-contenido',
      'deslizar-confirmar',
      'copiar',
      'pestanas',
      'avisos',
    ])
      '/$old/$slug': '/ejemplos/${slug == 'recetas' ? 'ejemplos' : slug}',
  for (final slug in ['me-gusta', 'contador-animado', 'interruptor'])
    '/cookbook/$slug': '/ejemplos/ejemplos',
  for (final slug in [
    'componentes',
    'componentes-botones',
    'componentes-entradas',
    'componentes-seleccion',
    'componentes-contenido',
    'componentes-navegacion',
    'componentes-avisos',
  ])
    '/catalogo/$slug': '/componentes/$slug',
  '/como-funciona/como-funciona': '/arquitectura/como-funciona',
  '/como-funciona/flutter-embebido': '/interfaz/flutter-embebido',
};

/// Where the old page at [path] (`/<section>/<slug>`, without the language)
/// is now, or null.
String? legacySectionPath(String path) => legacySectionTargets[path];

/// The sections the guide had that it no longer has: their old pages answer
/// with a redirect (`legacySectionTargets`).
Set<String> get legacySections => {
  for (final path in legacySectionTargets.keys) path.split('/')[1],
};

/// The page that replaced the old guide [slug] (`/guia/<slug>`), or null.
String? legacyGuidePath(String slug) => legacyGuideTargets[slug];

/// The pages of the site that had an address without a language: the
/// first segment of each (`/api/thor_ui` → `api`).
const unprefixedRoots = ['api', 'errores', 'cambios', 'buscar'];

/// Addresses that are not a page of their own: the route's own path and the
/// page it sends to (`/es/api` → `/es/api/thor_ui`), in every language.
const indexRedirects = {'/api': '/api/thor_ui'};

/// [indexRedirects] in every language: `/es/api` → `/es/api/thor_ui`.
Map<String, String> localizedIndexRedirects() => {
  for (final locale in docsLocales)
    for (final MapEntry(:key, :value) in indexRedirects.entries)
      localizePath(locale, key): localizePath(locale, value),
};

/// The old address of each page and where it goes now, as paths of the
/// site (with the default language in front) or URLs: `/guia/<slug>` for
/// every [legacyGuideTargets], every path of [pages] (the site's own
/// routes, without a language) that had no language before, and every
/// [legacySectionTargets] in each language.
Map<String, String> legacyRedirects(Iterable<String> pages) {
  String inDefault(String target) => target.startsWith('http')
      ? target
      : localizeAnchor(defaultLocale, localizePath(defaultLocale, target));
  return {
    for (final MapEntry(:key, :value) in legacyGuideTargets.entries)
      '/guia/$key': inDefault(value),
    // `/api` is no page and has no language: it goes straight to the first
    // reference page, in one hop (not through `/es/api`).
    for (final MapEntry(:key, :value) in indexRedirects.entries)
      key: inDefault(value),
    for (final page in pages)
      if (page != '/' && unprefixedRoots.contains(page.split('/')[1]))
        page: inDefault(page),
    // A page that changed section: its old address in every language.
    for (final locale in docsLocales)
      for (final MapEntry(:key, :value) in legacySectionTargets.entries)
        localizePath(locale, key): localizePath(locale, value),
  };
}

/// A page that sends the reader to [target] (a path or a URL): a refresh, a
/// script and a link, for hosts with no redirect rules of their own. Not
/// indexed; its canonical is the target.
String redirectPage(String target, {String lang = defaultLocale}) {
  final href = const HtmlEscape(HtmlEscapeMode.attribute).convert(target);
  final script = jsonEncode(target).replaceAll('<', r'<');
  return '<!DOCTYPE html><html lang="$lang"><head><meta charset="utf-8">'
      '<title>$href</title><meta name="robots" content="noindex">'
      '<link rel="canonical" href="$href">'
      '<meta http-equiv="refresh" content="0; url=$href">'
      '<script>location.replace($script)</script>'
      '</head><body><a href="$href">$href</a></body></html>\n';
}

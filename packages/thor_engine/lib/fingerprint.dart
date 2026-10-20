/// Content-hash cache busting for a built site (a build step, never in the
/// browser).
///
/// Every local file a page references (the engine script, images, fonts…)
/// is renamed to `name.<hash>.ext` and the pages are rewritten to point at
/// it, so a page always loads exactly the files it was built with: after a
/// deploy, a new page can't pick up an old engine from the cache, or the
/// other way round. A `_headers` file (Netlify / Cloudflare Pages format)
/// marks the hashed files as immutable and the pages as always revalidated.
library;

import 'dart:convert';
import 'dart:io';

import 'src/markup.dart';

/// Result of [fingerprintSite].
class FingerprintReport {
  /// Wraps the results of a run.
  FingerprintReport(this.pages, this.renamed);

  /// Pages (`.html`) rewritten.
  final int pages;

  /// Site-relative original path → hashed path.
  final Map<String, String> renamed;
}

/// Files other sites or crawlers request by their name: never renamed.
final _stableName = RegExp(
  r'(^|/)(favicon[^/]*|apple-touch-icon[^/]*|og[^/]*|robots\.txt|'
  r'manifest[^/]*|site\.webmanifest|sitemap[^/]*)$',
);

/// A name that already carries a hash (`engine.dart.3f9a1c2e.js`).
final _hashed = RegExp(r'\.[0-9a-f]{8}\.[A-Za-z0-9]+$');

final _cssImport = RegExp(r'''@import\s+(['"])([^'"]+)\1''');

final _cssUrl = RegExp(r'''url\(\s*(['"]?)([^'")]+)\1\s*\)''');

/// Renames the local files the pages of [siteDir] reference to
/// content-hashed names, rewrites the references and writes `_headers`.
/// [exclude] lists more site-relative paths to keep as they are. Running it
/// twice changes nothing.
FingerprintReport fingerprintSite(
  String siteDir, {
  Set<String> exclude = const {},
}) {
  final root = Directory(siteDir).absolute;
  final pages = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.html'))
      .toList();
  final docs = {for (final p in pages) p: MarkupDoc(p.readAsStringSync())};

  // 1. Every local file referenced by any page → its hashed name. A
  // stylesheet is named by the hash of its *rewritten* content (its url()
  // and @import follow the renames of what it points at), so the files it
  // references are resolved first; a stylesheet whose name already carries
  // a hash is renamed too when that rewrite changes it.
  final renamed = <String, String>{};
  final sheetText = <String, String>{}; // rewritten stylesheets, by path
  final resolving = <String>{};
  late final String? Function(File page, String ref) hashedFor;

  String rewrite(File page, String ref) {
    final hashed = hashedFor(page, ref);
    if (hashed == null) return ref;
    // Keep the reference's own form (relative / root-absolute, query).
    final cut = ref.indexOf(RegExp('[?#]'));
    final path = cut < 0 ? ref : ref.substring(0, cut);
    final tail = cut < 0 ? '' : ref.substring(cut);
    final base = path.substring(0, path.lastIndexOf('/') + 1);
    // The name was decoded to find the file: it goes back encoded (a space
    // splits a `srcset`, a parenthesis ends an unquoted `url()`).
    final name = Uri.encodeComponent(
      hashed.substring(hashed.lastIndexOf('/') + 1),
    ).replaceAll('(', '%28').replaceAll(')', '%29').replaceAll("'", '%27');
    return '$base$name$tail';
  }

  /// [text] of the stylesheet [sheet] with its references rewritten.
  String rewriteSheet(File sheet, String text) => text
      .replaceAllMapped(
        _cssUrl,
        (m) => 'url(${m[1]}${rewrite(sheet, m[2]!)}${m[1]})',
      )
      .replaceAllMapped(
        _cssImport,
        (m) => '@import ${m[1]}${rewrite(sheet, m[2]!)}${m[1]}',
      );

  String? sheetFor(String rel) {
    if (renamed.containsKey(rel)) return renamed[rel];
    if (!resolving.add(rel)) return null; // an @import cycle: keep the name
    final file = File('${root.path}/$rel');
    final text = file.readAsStringSync();
    final next = rewriteSheet(file, text);
    resolving.remove(rel);
    if (next != text) sheetText[rel] = next;
    final hashedName = _hashed.hasMatch(rel);
    if (hashedName && next == text) return null;
    final plain = hashedName
        ? rel.replaceFirstMapped(
            RegExp(r'\.[0-9a-f]{8}(\.[A-Za-z0-9]+)$'),
            (m) => m[1]!,
          )
        : rel;
    final dot = plain.lastIndexOf('.');
    final named =
        '${plain.substring(0, dot)}.${contentHash(utf8.encode(next))}'
        '${plain.substring(dot)}';
    return named == rel ? null : renamed[rel] = named;
  }

  hashedFor = (File page, String ref) {
    final rel = _siteRelative(root, page, ref);
    if (rel == null || exclude.contains(rel) || _stableName.hasMatch(rel)) {
      return null;
    }
    final existing = renamed[rel];
    if (existing != null) return existing;
    if (!File('${root.path}/$rel').existsSync()) return null;
    if (rel.endsWith('.css')) return sheetFor(rel);
    if (_hashed.hasMatch(rel)) return null;
    final file = File('${root.path}/$rel');
    final dot = rel.lastIndexOf('.');
    final slash = rel.lastIndexOf('/');
    final hash = contentHash(file.readAsBytesSync());
    return renamed[rel] = dot > slash
        ? '${rel.substring(0, dot)}.$hash${rel.substring(dot)}'
        : '$rel.$hash';
  };

  // 2. Rewrite the references.
  for (final MapEntry(key: page, value: doc) in docs.entries) {
    String one(String v) => rewrite(page, v);
    String srcset(String v) => v
        .split(',')
        .map((c) {
          final parts = c.trim().split(RegExp(r'\s+'));
          return [one(parts.first), ...parts.skip(1)].join(' ');
        })
        .join(', ');
    String css(String v) =>
        v.replaceAllMapped(_cssUrl, (m) => 'url(${m[1]}${one(m[2]!)}${m[1]})');

    // Only what changes is written back; the rest of the page is left as it
    // was (see `src/markup.dart`).
    void set(MElement e, String name, String Function(String) f) {
      final v = e.attr(name);
      if (v == null) return;
      final next = f(v);
      if (next != v) doc.setAttr(e, name, next);
    }

    for (final e in doc.all) {
      set(e, 'src', one);
      set(e, 'data-thor-engine', one);
      set(e, 'srcset', srcset);
      if (e.name == 'video') set(e, 'poster', one);
      if (e.name == 'link') {
        final rel = (e.attr('rel') ?? '').toLowerCase();
        if (RegExp(r'\b(preload|modulepreload|stylesheet)\b').hasMatch(rel)) {
          set(e, 'href', one);
        }
      }
      if (e.name == 'style') {
        final text = e.text;
        final next = css(text);
        if (next != text) doc.setContent(e, next);
      }
      set(e, 'style', css);
    }
  }

  // 2b. Stylesheets no page links (an @import target is reached above): their
  // url() still follow the renames, in place.
  for (final f in root.listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.css')) continue;
    final rel = f.path.substring(root.path.length + 1);
    if (renamed.containsKey(rel) || sheetText.containsKey(rel)) continue;
    final text = f.readAsStringSync();
    final next = rewriteSheet(f, text);
    if (next != text) sheetText[rel] = next;
  }

  // 3. Write the pages, then rename the files (a file shared by several
  // pages is renamed once).
  for (final MapEntry(key: page, value: doc) in docs.entries) {
    page.writeAsStringSync(doc.render());
  }
  for (final MapEntry(key: rel, value: text) in sheetText.entries) {
    File('${root.path}/$rel').writeAsStringSync(text);
  }
  for (final e in renamed.entries) {
    File('${root.path}/${e.key}').renameSync('${root.path}/${e.value}');
  }

  _writeHeaders(root, {...renamed.values, ..._alreadyHashed(root)});
  return FingerprintReport(pages.length, renamed);
}

/// FNV-1a (64-bit) of [bytes], 8 hex digits: a cache key, not a signature.
String contentHash(List<int> bytes) {
  var h = 0xcbf29ce484222325;
  for (final b in bytes) {
    h ^= b;
    h *= 0x100000001b3; // wraps at 64 bits on the VM
  }
  // The high 32 bits, unsigned (ints are signed 64-bit on the VM).
  return ((h >> 32) & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
}

/// [ref] as a path relative to the site root, or null when it isn't a
/// local file (a URL, `data:`, a fragment…).
String? _siteRelative(Directory root, File page, String ref) {
  final r = ref.trim();
  if (r.isEmpty ||
      r.startsWith('#') ||
      r.startsWith('//') ||
      RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(r)) {
    return null;
  }
  final cut = r.indexOf(RegExp('[?#]'));
  final path = Uri.decodeFull(cut < 0 ? r : r.substring(0, cut));
  final pageDir = page.parent.path.substring(root.path.length);
  final joined = path.startsWith('/') ? path : '$pageDir/$path';
  final parts = <String>[];
  for (final seg in joined.split('/')) {
    if (seg.isEmpty || seg == '.') continue;
    if (seg == '..') {
      if (parts.isEmpty) return null;
      parts.removeLast();
    } else {
      parts.add(seg);
    }
  }
  return parts.isEmpty ? null : parts.join('/');
}

Iterable<String> _alreadyHashed(Directory root) => root
    .listSync(recursive: true)
    .whereType<File>()
    .map((f) => f.path.substring(root.path.length + 1))
    .where(_hashed.hasMatch);

const _headersStart = '# thor: cache headers (generated)';
const _headersEnd = '# thor: end';

/// `_headers` for Netlify and Cloudflare Pages: pages always revalidate
/// (so a deploy shows up at once), hashed files are cached for a year
/// without revalidation (their name changes when their content does).
/// Other hosts: see docs/guia/en/build-and-deploy.md, "Browser cache".
void _writeHeaders(Directory root, Iterable<String> hashed) {
  final file = File('${root.path}/_headers');
  final own = StringBuffer()
    ..writeln(_headersStart)
    ..writeln('/')
    ..writeln('  Cache-Control: no-cache')
    ..writeln('/*.html')
    ..writeln('  Cache-Control: no-cache')
    // thor's own folder: shared and module stylesheets named by a hash of
    // their content, short names that aren't hex.
    ..writeln('/_thor/*')
    ..writeln('  Cache-Control: public, max-age=31536000, immutable');
  for (final path in {...hashed}.toList()..sort()) {
    own
      ..writeln('/$path')
      ..writeln('  Cache-Control: public, max-age=31536000, immutable');
  }
  own.writeln(_headersEnd);
  // Keep the app's own rules; replace only the generated block.
  final existing = file.existsSync() ? file.readAsStringSync() : '';
  final start = existing.indexOf(_headersStart);
  final end = existing.indexOf(_headersEnd);
  final kept = start < 0
      ? existing
      : existing.substring(0, start) +
            (end < 0 ? '' : existing.substring(end + _headersEnd.length + 1));
  file.writeAsStringSync(
    '${kept.trimRight()}${kept.trim().isEmpty ? '' : '\n\n'}$own',
  );
}

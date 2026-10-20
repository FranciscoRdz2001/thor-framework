// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
// The inline event handlers thor emits must hash to the values that
// docs/guia/es/sesion-y-seguridad.md lists for a strict CSP (`'unsafe-hashes'`): a change
// to a handler's text without the guide would break those sites silently.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart' show CspSource;
import 'package:thor_ui/src/engine/form_script.dart' show formScript;
import 'package:thor_ui/src/engine/lazy_script.dart' show lazyScript;
import 'package:thor_ui/src/engine/permanent_script.dart' show permanentScript;
import 'package:thor_ui/src/engine/prefetch_script.dart'
    show prefetchLoaderScript;
import 'package:thor_ui/src/engine/theme_script.dart' show themeScript;
import 'package:thor_ui/src/engine/upload_script.dart' show uploadScript;
import 'package:thor_ui/src/router/late_pieces.dart' show deferScript;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Widget _fallback(BuildContext c, Object e, StackTrace? s) => const Text('x');
Widget _spinner(BuildContext c, Widget child, ImageChunkEvent? p) =>
    const Text('…');

String _hash(String source) =>
    "'sha256-${base64.encode(sha256.convert(utf8.encode(source)).bytes)}'";

String _unescape(String v) => v
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');

void main() {
  test('every inline handler hash is in the security guide', () async {
    initializeThorTests();
    final html = await renderHtml(
      const Column(
        children: [
          Image.network(
            '/a.png',
            errorBuilder: _fallback,
            loadingBuilder: _spinner,
          ),
          TextField(name: 'bio', maxLength: 140),
          Drawer(id: 'd', child: Text('x')),
          Popover(id: 'p', trigger: Text('p'), child: Text('x')),
          MenuAnchor(
            id: 'm',
            menuChildren: [MenuItemButton(href: '/a', child: Text('a'))],
            child: TextButton(onPressed: null, child: Text('m')),
          ),
        ],
      ),
    );
    final handlers = {
      for (final m in RegExp(
        r'''\s(oninput|onerror|onload|onclick)="([^"]*)"''',
      ).allMatches(html))
        _unescape(m[2]!),
    };
    // The counter, two image handlers, and the two closing handlers
    // (`hidePopover` for Popover and MenuAnchor, `close` for Drawer).
    expect(handlers, hasLength(5), reason: html);
    final guide = File(
      '../../docs/guia/es/sesion-y-seguridad.md',
    ).readAsStringSync();
    for (final h in handlers) {
      expect(guide, contains(_hash(h)), reason: 'handler: $h');
    }
    // The typed list the apps use (`CspSource.thorHandlers`).
    expect(CspSource.thorHandlers.map((c) => c.value).toSet(), {
      for (final h in handlers) _hash(h),
    });
  });

  test('the script that swaps late pieces is hashed in the security guide', () {
    final guide = File(
      '../../docs/guia/es/sesion-y-seguridad.md',
    ).readAsStringSync();
    expect(guide, contains(_hash(deferScript)), reason: _hash(deferScript));
  });

  test('the script that loads a LazyPiece is hashed in the security guide', () {
    final guide = File(
      '../../docs/guia/es/sesion-y-seguridad.md',
    ).readAsStringSync();
    expect(guide, contains(_hash(lazyScript)), reason: _hash(lazyScript));
  });

  test(
    'the script of ExpansionTile(permanentFrom:) is hashed in the guide',
    () {
      final guide = File(
        '../../docs/guia/es/sesion-y-seguridad.md',
      ).readAsStringSync();
      expect(
        guide,
        contains(_hash(permanentScript)),
        reason: _hash(permanentScript),
      );
    },
  );

  test('the upload progress script is hashed in the security guide', () {
    final guide = File(
      '../../docs/guia/es/sesion-y-seguridad.md',
    ).readAsStringSync();
    expect(guide, contains(_hash(uploadScript)), reason: _hash(uploadScript));
  });

  test(
    'the form script (sending state, kept place) is hashed in the guide',
    () {
      final guide = File(
        '../../docs/guia/es/sesion-y-seguridad.md',
      ).readAsStringSync();
      expect(guide, contains(_hash(formScript)), reason: _hash(formScript));
    },
  );

  test(
    'the theme script (the remembered light/dark) is hashed in the guide',
    () {
      final guide = File(
        '../../docs/guia/es/sesion-y-seguridad.md',
      ).readAsStringSync();
      expect(guide, contains(_hash(themeScript)), reason: _hash(themeScript));
    },
  );

  test('the prefetch fallback loader is hashed in the guide', () {
    final guide = File(
      '../../docs/guia/es/sesion-y-seguridad.md',
    ).readAsStringSync();
    expect(
      guide,
      contains(_hash(prefetchLoaderScript)),
      reason: _hash(prefetchLoaderScript),
    );
  });

  test(
    'the slide transition script (back direction) is hashed in the guide',
    () {
      final guide = File(
        '../../docs/guia/es/sesion-y-seguridad.md',
      ).readAsStringSync();
      final script = const PageTransition.slide().script!;
      expect(guide, contains(_hash(script)), reason: _hash(script));
    },
  );
}

@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

/// The page's sprite (`<svg id="thor-sprite" …>…</svg>`), '' without one.
String sprite(String html) =>
    RegExp(
      r'<svg id="thor-sprite".*?</svg>',
      dotAll: true,
    ).firstMatch(html)?.group(0) ??
    '';

void main() {
  test('Icons.search is an SVG icon in the page sprite, decorative', () async {
    final html = await page(const Icon(Icons.search));
    expect('<symbol id="material-search"'.allMatches(html), hasLength(1));
    expect(html, contains('<use href="#material-search">'));
    final svg = RegExp(r'<svg [^>]*>').firstMatch(html)![0]!;
    expect(svg, contains('aria-hidden="true"'));
    expect(svg, contains('viewBox="0 0 24 24"'));
    // Material icons are filled shapes: no stroke.
    expect(html, isNot(contains('stroke-width')));
    expect(html, contains('fill: currentColor'));
  });

  test('an icon nobody draws adds 0 bytes to the page', () async {
    final base = await page(const Icon(Icons.search));
    // Referenced, not drawn: the sprite only holds what the page renders.
    const unused = Icons.delete;
    final withUnused = await page(
      Column(
        children: [
          const Icon(Icons.search),
          if (unused.svgId == '') const Icon(unused),
        ],
      ),
    );
    expect(sprite(withUnused), sprite(base));
    expect(withUnused, isNot(contains('material-delete')));
    // Drawn, it does add its own symbol.
    final drawn = await page(
      const Column(children: [Icon(Icons.search), Icon(Icons.delete)]),
    );
    expect(drawn, contains('<symbol id="material-delete"'));
    expect(drawn.length, greaterThan(base.length));
  });

  test('the same icon twice is one symbol', () async {
    final html = await page(
      const Row(children: [Icon(Icons.add), Icon(Icons.add), Icon(Icons.add)]),
    );
    expect('<symbol id="material-add"'.allMatches(html), hasLength(1));
    expect('<use href="#material-add">'.allMatches(html), hasLength(3));
  });

  test('the Flutter names the docs promise are there', () {
    const names = <IconData>[
      Icons.add,
      Icons.delete,
      Icons.menu,
      Icons.close,
      Icons.arrow_back,
      Icons.edit,
      Icons.check,
      Icons.settings,
      Icons.person,
      Icons.home,
      Icons.search,
      Icons.more_vert,
      Icons.favorite,
      Icons.share,
    ];
    expect(names.every((i) => i.isSvg && i.svgBody!.isNotEmpty), isTrue);
    expect(names.map((i) => i.svgId).toSet(), hasLength(names.length));
  });

  test('every name of Flutter\'s Icons the pharmacy store needed is there', () {
    const names = <IconData>[
      Icons.medication,
      Icons.local_pharmacy,
      Icons.child_care,
      Icons.face,
      Icons.local_offer,
      Icons.add_shopping_cart,
      Icons.storefront,
      Icons.local_shipping,
      Icons.search_off,
      Icons.category,
      Icons.medication_outlined,
      Icons.local_pharmacy_rounded,
      Icons.storefront_sharp,
    ];
    expect(names.every((i) => i.isSvg && i.svgBody!.isNotEmpty), isTrue);
  });

  test('Flutter\'s spelled-out digits and other names resolve', () {
    // `3d_rotation` in Material is `threed_rotation` in Flutter.
    expect(Icons.threed_rotation.svgBody, isNotEmpty);
    expect(Icons.ten_k.svgBody, isNotEmpty);
    expect(Icons.twenty_four_mp_rounded.svgBody, isNotEmpty);
    // Flutter's alias of another icon is that icon: one symbol.
    expect(identical(Icons.copy, Icons.content_copy), isTrue);
    expect(Icons.copy_outlined.svgId, Icons.content_copy_outlined.svgId);
  });

  test('a new icon travels once, and only when drawn', () async {
    final html = await page(
      const Row(children: [Icon(Icons.medication), Icon(Icons.medication)]),
    );
    expect('<symbol id="material-medication"'.allMatches(html), hasLength(1));
    expect('<use href="#material-medication">'.allMatches(html), hasLength(2));
    expect(html, isNot(contains('material-local-pharmacy')));
  });

  test('outlined, rounded and sharp are variants with their own ids', () {
    expect(Icons.home_outlined.svgId, 'material-home-outlined');
    expect(Icons.home_rounded.svgId, 'material-home-rounded');
    expect(Icons.home_sharp.svgId, 'material-home-sharp');
    expect(Icons.home.svgBody, isNot(Icons.home_sharp.svgBody));
    // A variant drawn like the base is the base: one shape in the sprite.
    expect(identical(Icons.search_outlined, Icons.search), isTrue);
  });

  test('the sprite symbols carry no transparent box', () {
    expect(Icons.search.svgBody, isNot(contains('fill="none"')));
    expect(Icons.search.svgBody, isNot(contains('xmlns')));
  });

  group('matchTextDirection', () {
    test('arrow_back mirrors in right-to-left', () async {
      expect(Icons.arrow_back.matchTextDirection, isTrue);
      final html = await page(const Icon(Icons.arrow_back));
      expect(html, contains(':dir(rtl)'));
      expect(html, contains('scaleX(-1)'));
    });

    test('search never mirrors', () async {
      expect(Icons.search.matchTextDirection, isFalse);
      final html = await page(const Icon(Icons.search));
      expect(html, isNot(contains(':dir(rtl)')));
    });

    test('the flag is Flutter\'s on IconData.svg too', () async {
      const flipped = IconData.svg(
        'test-x',
        '<path d="M0 0h1"/>',
        matchTextDirection: true,
      );
      expect(await page(const Icon(flipped)), contains(':dir(rtl)'));
    });
  });

  test('semanticLabel names an Icons icon', () async {
    final html = await page(const Icon(Icons.delete, semanticLabel: 'Delete'));
    expect(html, contains('aria-label="Delete"'));
    expect(html, contains('role="img"'));
  });

  test('an empty semanticLabel is decorative, not an unnamed image', () async {
    final html = await page(const Icon(Icons.delete, semanticLabel: ''));
    expect(html, contains('aria-hidden="true"'));
    expect(html, isNot(contains('role="img"')));
    final font = await page(
      const Icon(IconData(0xe151, fontFamily: 'X'), semanticLabel: ''),
    );
    expect(font, contains('aria-hidden="true"'));
    expect(font, isNot(contains('role="img"')));
  });

  group('the generated Icons', () {
    // The generated source, read once: 8.7k declarations, no reflection.
    final source = File('lib/src/widgets/icons.dart').readAsStringSync();
    final svgs = [
      for (final m in RegExp(
        r"static const IconData\s+(\w+)\s*=\s*IconData\.svg\(\s*'([^']*)',\s*r'([^']*)'",
      ).allMatches(source))
        (name: m[1]!, id: m[2]!, body: m[3]!),
    ];

    test('every symbol id is material-<name> and unique', () {
      expect(svgs.length, greaterThan(6000));
      for (final i in svgs) {
        expect(i.id, 'material-${i.name.replaceAll('_', '-')}', reason: i.name);
      }
      expect(svgs.map((i) => i.id).toSet(), hasLength(svgs.length));
    });

    test(
      'a symbol body is only shapes: no text, scripts or paint overrides',
      () {
        final tags = RegExp(r'<(\w+)');
        const allowed = {
          'g', 'path', 'rect', 'circle', 'ellipse', 'polygon', //
        };
        for (final i in svgs) {
          for (final t in tags.allMatches(i.body)) {
            expect(allowed, contains(t[1]), reason: '${i.name} has <${t[1]}>');
          }
          // Only `none` paints: any other fill would ignore `color:`.
          for (final f in RegExp(r'fill="([^"]*)"').allMatches(i.body)) {
            expect(f[1], 'none', reason: i.name);
          }
          expect(i.body, isNot(contains('stroke')), reason: i.name);
          // (`style="fill:none"` hides a helper box, like `fill="none"`.)
          expect(
            i.body.replaceAll('style="fill:none"', ''),
            isNot(contains('style=')),
            reason: i.name,
          );
          expect(i.body, isNot(contains('<!')), reason: i.name);
        }
      },
    );

    test('an alias of another icon is the same style', () {
      String style(String n) => const [
        '_outlined',
        '_rounded',
        '_sharp',
      ].firstWhere(n.endsWith, orElse: () => '');
      final alias = RegExp(r'static const IconData\s+(\w+)\s*=\s*(\w+);');
      for (final m in alias.allMatches(source)) {
        final a = m[1]!, b = m[2]!;
        // web: Flutter's `wifi_tethering_error_rounded` is its own icon whose
        // codepoint is the rounded variant's: a Flutter naming quirk.
        if (a.startsWith('wifi_tethering_error_rounded')) continue;
        // `abc_outlined = abc` is a variant drawn like its base; the others
        // are Flutter's second names, which keep the style.
        final stem = b.replaceFirst(RegExp(r'_$'), '');
        if (style(b).isEmpty && a.startsWith(stem) && style(a).isNotEmpty) {
          continue;
        }
        expect(style(a), style(b), reason: '$a = $b');
      }
    });
  });

  test('digit spellings resolve to their own shape', () {
    expect(Icons.ten_k.svgId, 'material-ten-k');
    expect(Icons.one_k.svgBody, isNot(Icons.two_k.svgBody));
    expect(Icons.three_p.svgBody, isNot(Icons.three_mp.svgBody));
    expect(Icons.timer_10.svgBody, isNot(Icons.timer_3.svgBody));
    expect(Icons.exposure_plus_1.svgBody, isNot(Icons.exposure_plus_2.svgBody));
    expect(Icons.thirty_fps.svgBody, isNot(Icons.thirty_fps_select.svgBody));
  });

  test('names Material renamed still resolve', () {
    expect(Icons.door_back_door.isSvg, isTrue);
    expect(Icons.door_front_door_rounded.isSvg, isTrue);
    expect(Icons.door_front_door.svgBody, isNot(Icons.door_back_door.svgBody));
  });

  test('Dart-keyword names keep Flutter\'s trailing underscore', () {
    expect(Icons.class_.svgId, 'material-class-');
    expect(Icons.class_outlined.svgBody, isNot(Icons.class_.svgBody));
  });

  test('a flipped alias flips and an unflipped one does not', () {
    // Flutter's `matchTextDirection` list, sampled.
    for (final i in [
      Icons.arrow_back,
      Icons.arrow_forward_ios,
      Icons.navigate_next,
      Icons.send,
      Icons.reply,
      Icons.undo,
      Icons.format_list_bulleted,
      Icons.arrow_back_rounded,
    ]) {
      expect(i.matchTextDirection, isTrue);
    }
    for (final i in [
      Icons.add,
      Icons.search,
      Icons.home,
      Icons.close,
      Icons.favorite,
      Icons.arrow_upward,
      Icons.arrow_downward,
      Icons.expand_more,
    ]) {
      expect(i.matchTextDirection, isFalse);
    }
  });
}

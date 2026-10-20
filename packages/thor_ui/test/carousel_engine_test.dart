@TestOn('vm')
library;

// Fixtures: these builders tell waiting from done with `hasData` only, which
// is not the pattern the guide teaches for a nullable future.
// ignore_for_file: thor_lints/future_builder_nullable_has_data

import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// What a page with a carousel ships for the engine (rule 3, measured): the
// fallback controls only matter where the browser draws no `::scroll-button`,
// so a page whose only engine use is a carousel loads the engine only there.

const _native = 'selector(::scroll-button(*))';

CarouselView carousel({bool arrows = true}) => CarouselView(
  label: 'Hero',
  showArrows: arrows,
  showIndicators: !arrows,
  children: const [Text('a'), Text('b')],
);

Future<String> page(Widget child, {EngineLoading? loading}) => renderDocument(
  ThorApp(engineLoading: loading ?? EngineLoading.onIdle, child: child),
);

void main() {
  setUpAll(() => initializeThorTests(compactHtml: false));

  group('a page whose only engine use is a carousel', () {
    test(
      'ships no preload and no loader: Chromium downloads nothing',
      () async {
        final doc = await page(carousel());
        expect(doc, isNot(contains('rel="preload"')));
        expect(doc, isNot(contains('requestIdleCallback')));
        expect(doc, isNot(contains('thor-reload')));
      },
    );

    test(
      'asks for the engine only where the browser has no native arrows',
      () async {
        for (final arrows in [true, false]) {
          final doc = await page(carousel(arrows: arrows));
          final script = RegExp(
            r'<script[^>]*data-thor-engine="engine\.dart\.js"[^>]*>(.*?)</script>',
            dotAll: true,
          ).firstMatch(doc);
          expect(script, isNotNull, reason: doc);
          expect(script!.group(1), contains(_native));
          expect(script.group(1), contains('createElement("script")'));
          // A strict-CSP hash covers it: no handler attributes were added.
          expect(doc, isNot(contains(' onload=')));
          expect(doc, isNot(contains(' onclick=')));
        }
      },
    );

    test('a page with the engine for another reason keeps the full loader '
        'and no second script', () async {
      final doc = await page(
        Column(
          children: [
            carousel(),
            const DropdownMenu<int>(
              dropdownMenuEntries: [DropdownMenuEntry(value: 1, label: 'One')],
            ),
          ],
        ),
      );
      expect(doc, contains('rel="preload"'));
      expect(doc, contains('requestIdleCallback'));
      expect(doc, isNot(contains(_native)));
      expect('data-thor-engine='.allMatches(doc), hasLength(1));
    });

    test(
      'eager loading is the plain deferred script (CSP: no inline)',
      () async {
        final doc = await page(carousel(), loading: EngineLoading.eager);
        expect(doc, contains('defer'));
        expect(doc, isNot(contains(_native)));
        expect(doc, contains('src="engine.dart.js"'));
      },
    );

    test(
      'autoplay needs the engine everywhere, with or without controls',
      () async {
        for (final arrows in [true, false]) {
          final doc = await page(
            CarouselView(
              label: 'Hero',
              showArrows: arrows,
              autoPlay: const Duration(seconds: 3),
              children: const [Text('a'), Text('b')],
            ),
          );
          expect(doc, contains('data-t-carousel="3000"'));
          expect(doc, contains('rel="preload"'), reason: 'arrows: $arrows');
          expect(doc, contains('requestIdleCallback'));
          expect(doc, isNot(contains(_native)));
        }
      },
    );

    test('a page without controls ships nothing', () async {
      final doc = await page(
        const CarouselView(showArrows: false, children: [Text('a')]),
      );
      expect(doc, isNot(contains('engine')));
    });
  });

  group('late carousels', () {
    test(
      'a carousel streamed in late brings the conditional loader too',
      () async {
        final done = Completer<Object?>();
        final handler = RouteHandler<Widget>(
          renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
          routes: [
            PageRoute<Widget, Completer<Object?>>(
              path: 'x',
              load: (r) => done,
              build: (s) => FutureBuilder<Object?>(
                future: s.data.future,
                builder: (context, snap) =>
                    snap.hasData ? carousel() : const Text('loading'),
              ),
            ),
          ],
        );
        final r = await handler.handle(
          PageRequest(
            method: HttpMethod.get,
            uri: Uri.parse('http://site.test/x'),
            headers: {HttpHeader.host: 'site.test'},
          ),
        );
        final chunks = <String>[];
        final end = Completer<void>();
        r.stream!.listen(
          (c) => chunks.add(utf8.decode(c)),
          onDone: end.complete,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        done.complete(1);
        await end.future;
        final all = chunks.join();
        expect(all, contains('data-t-cv'));
        expect(all, contains(_native));
        expect('data-thor-engine='.allMatches(all), hasLength(1));
      },
    );
  });
}

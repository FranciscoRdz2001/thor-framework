@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// The member list thor generates for [ChartState], by hand (tests don't run the build).
abstract class _ChartStateMembers extends ThorState {
  @override
  String get $type => 'ChartState';

  @override
  List<ThorMember> get $members {
    final s = this as ChartState;
    return [
      ThorMember.state('last', s.last),
      ThorMember('onBar', s.onBar, arity: 1, call: (a) => s.onBar(a!)),
    ];
  }
}

class ChartState extends _ChartStateMembers {
  final last = state('');
  void onBar(String message) => last.value = message;
}

final chart = ChartState();

/// The loader's first bytes: present once on a page with Flutter views.
const _loaderStart =
    '<script>(()=>{var d=document,w=window,A="data-thor-flutter"';

int _count(String html, String part) => part.allMatches(html).length;

/// The decoded value of [attribute] on the first element that has it.
String? _attr(String html, String attribute) {
  final m = RegExp('$attribute="([^"]*)"').firstMatch(html);
  return m?[1]!
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}

void main() {
  initializeThorTests();

  group('markup', () {
    test('one sized host with the placeholder layer inside', () async {
      final html = await renderHtml(
        const FlutterView(height: 200, placeholder: Text('loading')),
      );
      expect(html, startsWith('<div '));
      expect(html, contains('data-thor-flutter="/flutter/"'));
      expect(html, contains('data-thor-flutter-load="visible"'));
      expect(html, contains('data-thor-flutter-placeholder'));
      expect(html, contains('loading'));
      // Host + placeholder layer + the Text: nothing else.
      expect(_count(html, '<div'), 2);
      // No data attribute for null data; busy only while JS loads it.
      expect(html, isNot(contains('data-thor-flutter-data')));
      expect(html, isNot(contains('aria-busy')));
      expect(html, isNot(contains('data-thor-flutter-state')));
    });

    test('no placeholder: an empty host', () async {
      final html = await renderHtml(const FlutterView(height: 200));
      expect(_count(html, '<div'), 1);
      expect(html, isNot(contains('data-thor-flutter-placeholder')));
    });

    test('src gets its trailing slash; an empty src is an error', () async {
      final html = await renderHtml(
        const FlutterView(src: '/apps/chart', height: 100),
      );
      expect(html, contains('data-thor-flutter="/apps/chart/"'));
      await expectLater(
        renderHtml(const FlutterView(src: ' ', height: 100)),
        throwsArgumentError,
      );
    });

    test('semanticLabel names a region; without it, no role', () async {
      final labeled = await renderHtml(
        const FlutterView(height: 100, semanticLabel: 'Sales "2026"'),
      );
      expect(labeled, contains('role="region"'));
      expect(_attr(labeled, 'aria-label'), 'Sales "2026"');
      final plain = await renderHtml(const FlutterView(height: 100));
      expect(plain, isNot(contains('role=')));
    });
  });

  group('initial data', () {
    test('any string survives the attribute and decodes back', () async {
      const data = {
        'text': '"></div><script>alert(1)</script>&amp; \'   ñ',
        'n': [1, 2.5, null, true],
        'nested': {'a': '<!--'},
      };
      final html = await renderHtml(
        const FlutterView(height: 100, initialData: data),
      );
      final raw = RegExp('data-thor-flutter-data="([^"]*)"').firstMatch(html)!;
      // A quote never closes the attribute early: the capture is the
      // whole JSON.
      expect(jsonDecode(_attr(html, 'data-thor-flutter-data')!), data);
      expect(raw[1], isNot(contains('"')));
      // The markup around it is intact: host + nothing injected.
      expect(_count(html.replaceFirst(raw[0]!, ''), '<script'), 0);
    });

    test('scalars and lists are sent as they are', () async {
      final html = await renderHtml(
        const FlutterView(height: 100, initialData: [1, 'a']),
      );
      expect(_attr(html, 'data-thor-flutter-data'), '[1,"a"]');
    });

    test('data JSON cannot encode fails the render (fail closed)', () async {
      await expectLater(
        renderHtml(FlutterView(height: 100, initialData: {'at': DateTime(0)})),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    });
  });

  group('size', () {
    Future<String> css(FlutterView view) async {
      final page = await renderDocument(ThorApp(child: view));
      return page;
    }

    test('height: fixed box, full width by default', () async {
      final page = await css(const FlutterView(height: 160));
      expect(page, contains('height: 160px'));
      expect(page, contains('width: 100%'));
      expect(page, isNot(contains('aspect-ratio')));
      expect(page, contains('position: relative'));
      expect(page, contains('overflow: hidden'));
    });

    test('aspectRatio: height from the width', () async {
      final page = await css(const FlutterView(aspectRatio: 16 / 9));
      expect(page, contains('aspect-ratio: 16 / 9'));
      expect(page, isNot(contains('height: ')));
    });

    test('width: fixed, but never wider than the parent', () async {
      final page = await css(const FlutterView(width: 320, height: 200));
      expect(page, contains('width: 320px'));
      expect(page, contains('max-width: 100%'));
    });

    test('no height and no aspectRatio is an error', () async {
      await expectLater(
        renderHtml(const FlutterView(width: 300)),
        throwsArgumentError,
      );
    });

    for (final bad in [0.0, -1.0, double.nan, double.infinity]) {
      test('$bad as a size is an error', () async {
        await expectLater(
          renderHtml(FlutterView(height: bad)),
          throwsArgumentError,
        );
        await expectLater(
          renderHtml(FlutterView(aspectRatio: bad)),
          throwsArgumentError,
        );
        await expectLater(
          renderHtml(FlutterView(width: bad, height: 10)),
          throwsArgumentError,
        );
      });
    }
  });

  group('loading', () {
    for (final mode in FlutterViewLoading.values) {
      test('${mode.name} is written for the loader', () async {
        final html = await renderHtml(FlutterView(height: 10, loading: mode));
        expect(html, contains('data-thor-flutter-load="${mode.name}"'));
      });
    }

    test(
      'the loader ships once, at the end of <body>, after every host',
      () async {
        final page = await renderDocument(
          const ThorApp(
            child: Column(
              children: [
                FlutterView(height: 100, initialData: {'v': 1}),
                Text('entre'),
                FlutterView(aspectRatio: 2, initialData: {'v': 2}),
              ],
            ),
          ),
        );
        expect(_count(page, _loaderStart), 1);
        expect(headOfPage(page), isNot(contains(_loaderStart)));
        expect(
          page.indexOf(_loaderStart),
          greaterThan(page.lastIndexOf('data-thor-flutter="/flutter/"')),
        );
        // No state: no engine for a page that only embeds Flutter.
        expect(page, isNot(contains('data-thor-engine')));
      },
    );

    test('a page without FlutterView ships no loader', () async {
      final page = await renderDocument(const ThorApp(child: Text('x')));
      expect(page, isNot(contains('thorFlutter')));
    });

    test(
      'without ThorApp: the host renders, no loader (needs ThorApp)',
      () async {
        final html = await renderDocument(const FlutterView(height: 10));
        expect(html, contains('data-thor-flutter='));
        expect(html, isNot(contains(_loaderStart)));
      },
    );

    test('two Flutter builds on one page is an error (one engine)', () async {
      await expectLater(
        renderDocument(
          const ThorApp(
            child: Column(
              children: [
                FlutterView(src: '/a/', height: 10),
                FlutterView(src: '/b/', height: 10),
              ],
            ),
          ),
        ),
        throwsStateError,
      );
    });

    test(
      'the same build written with and without slash is one build',
      () async {
        final page = await renderDocument(
          const ThorApp(
            child: Column(
              children: [
                FlutterView(src: '/a', height: 10),
                FlutterView(src: '/a/', height: 10),
              ],
            ),
          ),
        );
        expect(_count(page, _loaderStart), 1);
      },
    );

    test('a Cached subtree with a view still ships the loader', () async {
      Future<String> page() => renderDocument(
        const ThorApp(
          child: Cached(
            cacheKey: 'flutter-view-test',
            child: FlutterView(height: 10),
          ),
        ),
      );
      // 1st: new classes; 2nd: kept (every class shared); 3rd: replayed.
      for (var i = 0; i < 3; i++) {
        expect(_count(await page(), _loaderStart), 1, reason: 'render $i');
      }
    });
  });

  group('messages', () {
    test('onMessage binds the Flutter message event to the state', () async {
      final page = await renderDocument(
        ThorApp(child: FlutterView(height: 10, onMessage: chart.onBar)),
      );
      expect(
        page,
        contains('data-t-on="thor-flutter-message:ChartState.onBar"'),
      );
      // The page now has state: the engine ships too.
      expect(page, contains('data-thor-engine'));
    });

    test('a callback that is not a ThorState method binds nothing', () async {
      final html = await renderHtml(FlutterView(height: 10, onMessage: (_) {}));
      expect(html, isNot(contains('data-t-on')));
    });
  });
}

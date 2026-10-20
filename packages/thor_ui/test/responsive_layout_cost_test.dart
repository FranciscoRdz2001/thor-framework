@TestOn('vm')
library;

// `ResponsiveLayout` draws every variant and CSS hides the others: `thor dev`
// warns (THOR-R034) when two of them carry something heavy, so the page does
// not ship it twice by accident.
import 'dart:async';

import 'package:test/test.dart';
import 'package:thor_ui/src/foundation/deferred.dart'
    show DeferHolder, DeferRun, DeferScope;
import 'package:thor_ui/src/foundation/responsive.dart'
    show responsiveCostWarning;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Widget _done(BuildContext context, AsyncSnapshot<String> snapshot) =>
    Text(snapshot.data ?? 'loading');

/// Renders [layout] under a run that collects the dev warnings.
Future<List<String>> _warnings(Widget layout, {bool devRun = true}) async {
  final messages = <String>[];
  final holder = DeferHolder();
  if (devRun) {
    holder.run = DeferRun(
      stream: false,
      timeout: const Duration(seconds: 1),
      describe: (e) => ('$e', ServerErrorKind.client),
      warn: messages.add,
    );
  }
  await renderDocument(
    ThorApp(
      child: DeferScope(holder: holder, child: layout),
    ),
  );
  return messages;
}

String _big(String tag) => List.filled(1200, '$tag line of text. ').join();

void main() {
  setUpAll(initializeThorTests);

  group('ResponsiveLayout warns when both variants are heavy', () {
    test('a FutureBuilder in both', () async {
      final future = Completer<String>().future;
      final messages = await _warnings(
        ResponsiveLayout(
          mobile: FutureBuilder<String>(future: future, builder: _done),
          desktop: FutureBuilder<String>(future: future, builder: _done),
        ),
      );
      expect(messages, hasLength(1));
      expect(messages.single, contains('THOR-R034'));
      expect(messages.single, contains('FutureBuilder'));
      expect(messages.single, contains('mobile'));
      expect(messages.single, contains('desktop'));
    });

    test('a lot of HTML in both', () async {
      final messages = await _warnings(
        ResponsiveLayout(
          mobile: Text(_big('mobile')),
          desktop: Text(_big('desktop')),
        ),
      );
      expect(messages, hasLength(1));
      expect(messages.single, contains('THOR-R034'));
      expect(messages.single, contains('KB'));
    });

    test(
      'the same warning is said once per render, not once per draw',
      () async {
        final future = Completer<String>().future;
        final layout = ResponsiveLayout(
          mobile: FutureBuilder<String>(future: future, builder: _done),
          tablet: FutureBuilder<String>(future: future, builder: _done),
          desktop: FutureBuilder<String>(future: future, builder: _done),
        );
        final messages = <String>[];
        final holder = DeferHolder()
          ..run = DeferRun(
            stream: false,
            timeout: const Duration(seconds: 1),
            describe: (e) => ('$e', ServerErrorKind.client),
            warn: messages.add,
          );
        final app = ThorApp(
          child: DeferScope(holder: holder, child: layout),
        );
        await renderDocument(app);
        await renderDocument(app);
        expect(messages, hasLength(1));
        expect(messages.single, contains('tablet'));
      },
    );
  });

  group('ResponsiveLayout stays quiet when it is cheap', () {
    test('small variants, even with a FutureBuilder in one', () async {
      final future = Completer<String>().future;
      expect(
        await _warnings(
          const ResponsiveLayout(mobile: Text('Menu'), desktop: Text('Links')),
        ),
        isEmpty,
      );
      expect(
        await _warnings(
          ResponsiveLayout(
            mobile: const Text('Menu'),
            desktop: FutureBuilder<String>(future: future, builder: _done),
          ),
        ),
        isEmpty,
      );
    });

    test('one heavy variant and a light one', () async {
      expect(
        await _warnings(
          ResponsiveLayout(
            mobile: const Text('Open the full list'),
            desktop: Text(_big('desktop')),
          ),
        ),
        isEmpty,
      );
    });

    test('nothing is measured without a dev run (a release, a test)', () async {
      expect(
        await _warnings(
          ResponsiveLayout(
            mobile: Text(_big('mobile')),
            desktop: Text(_big('desktop')),
          ),
          devRun: false,
        ),
        isEmpty,
      );
      // And the page is the same as with one.
      final plain = await renderDocument(
        const ThorApp(
          child: ResponsiveLayout(mobile: Text('a'), desktop: Text('b')),
        ),
      );
      final watched = await renderDocument(
        ThorApp(
          child: DeferScope(
            holder: DeferHolder()
              ..run = DeferRun(
                stream: false,
                timeout: const Duration(seconds: 1),
                describe: (e) => ('$e', ServerErrorKind.client),
                warn: (_) {},
              ),
            child: const ResponsiveLayout(
              mobile: Text('a'),
              desktop: Text('b'),
            ),
          ),
        ),
      );
      expect(watched, plain);
    });
  });

  group('the rule', () {
    String? warn(List<({String name, int bytes, int futures, bool list})> b) =>
        responsiveCostWarning(b);

    test('two lists, two futures, or two big variants', () {
      expect(
        warn([
          (name: 'mobile', bytes: 900, futures: 0, list: true),
          (name: 'desktop', bytes: 900, futures: 0, list: true),
        ]),
        allOf(contains('THOR-R034'), contains('Watch.list')),
      );
      expect(
        warn([
          (name: 'mobile', bytes: 90, futures: 1, list: false),
          (name: 'desktop', bytes: 90, futures: 2, list: false),
        ]),
        contains('FutureBuilder'),
      );
      expect(
        warn([
          (name: 'mobile', bytes: 40 * 1024, futures: 0, list: false),
          (name: 'desktop', bytes: 40 * 1024, futures: 0, list: false),
        ]),
        contains('40 KB'),
      );
    });

    test('a threshold is not a tripwire', () {
      expect(
        warn([
          (name: 'mobile', bytes: 15 * 1024, futures: 0, list: false),
          (name: 'desktop', bytes: 15 * 1024, futures: 0, list: false),
        ]),
        isNull,
      );
      // One variant with it, the other without: nothing is repeated.
      expect(
        warn([
          (name: 'mobile', bytes: 90, futures: 1, list: true),
          (name: 'desktop', bytes: 90, futures: 0, list: false),
        ]),
        isNull,
      );
      expect(
        warn([(name: 'mobile', bytes: 1 << 20, futures: 3, list: true)]),
        isNull,
      );
    });
  });
}

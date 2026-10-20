// The engine's preload: the page asks for the file at low
// priority from its start, so a first interaction finds it on the way or
// already there.
import 'package:test/test.dart';
import 'package:thor_ui/src/engine/engine_script.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  setUpAll(initializeThorTests);

  const preload =
      '<link rel="preload" as="script" href="engine.dart.js" fetchpriority="low"/>';

  test('the deferred loader is preceded by a low-priority preload of the '
      'same file', () async {
    final html = await renderHtml(const EngineScript());
    expect(html, startsWith(preload));
    expect(html.indexOf(preload), lessThan(html.indexOf('data-thor-engine')));
    expect(html, contains('data-thor-engine="engine.dart.js"'));
    expect('rel="preload"'.allMatches(html), hasLength(1));
  });

  test(
    'the preload follows the src the app gives (a router app: root path)',
    () async {
      final html = await renderHtml(const EngineScript(src: '/e.js'));
      expect(html, contains('href="/e.js"'));
      expect(html, contains('data-thor-engine="/e.js"'));
    },
  );

  test(
    'an eager engine is a plain deferred script: nothing to preload',
    () async {
      final html = await renderHtml(
        const EngineScript(loading: EngineLoading.eager),
      );
      expect(html, isNot(contains('preload')));
      expect(html, contains('defer'));
    },
  );

  test('a page without the engine ships no preload and no script', () async {
    final html = await renderDocument(const ThorApp(child: Text('x')));
    expect(html, isNot(contains('preload')));
    expect(html, isNot(contains('engine')));
  });

  test('a page with the engine has the preload in the head, before the '
      'loader', () async {
    final html = await renderDocument(
      const ThorApp(
        child: DropdownMenu<int>(
          dropdownMenuEntries: [DropdownMenuEntry(value: 1, label: 'One')],
        ),
      ),
    );
    final head = headOfPage(html);
    expect(head, contains(preload));
    expect(head.indexOf(preload), lessThan(head.indexOf('data-thor-engine')));
    expect(bodyOfPage(html), isNot(contains('preload')));
  });

  test('the loader raises the priority only for an interaction', () {
    // Both paths are also checked in a browser test; here, that the priority
    // is set under a condition on the event, not for every
    // load (the idle callback gets a deadline, not an event).
    expect(engineLoaderScript, contains('x&&x.type&&(e.fetchPriority="high")'));
    expect(
      RegExp('fetchPriority').allMatches(engineLoaderScript),
      hasLength(1),
    );
  });
}

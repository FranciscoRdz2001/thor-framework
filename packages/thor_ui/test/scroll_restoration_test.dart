// SingleChildScrollView(restorationId:): the offset survives a page change
// (a sidebar every page repeats), like Astro Starlight's sidebar.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  initializeThorTests();

  test('a restorationId adds its script inside the view, last', () async {
    final html = await renderHtml(
      const SingleChildScrollView(
        restorationId: 'nav',
        child: Column(children: [Text('a'), Text('b')]),
      ),
    );
    // The Column is not fused into the view: the script needs its parent.
    expect(RegExp('<div').allMatches(html).length, greaterThanOrEqualTo(2));
    final script = html.indexOf('<script data-thor-restore>');
    expect(script, greaterThan(html.indexOf('b')));
    expect(html.indexOf('</script></div>'), greaterThan(script));
    expect(html, contains('"thor-scroll:nav"'));
    expect(html, contains('scrollTop'));
    expect(html, contains('pagehide'));
  });

  test('a horizontal view keeps scrollLeft', () async {
    final html = await renderHtml(
      const SingleChildScrollView(
        restorationId: 'tabs',
        scrollDirection: Axis.horizontal,
        child: Text('x'),
      ),
    );
    expect(html, contains('scrollLeft'));
    expect(html, isNot(contains('scrollTop')));
  });

  test('an id cannot close the script', () {
    final js = scrollRestorationScript('</script><img src=x onerror=alert(1)>');
    expect(js, isNot(contains('</script>')));
    expect(js, contains(r'\u003c/script>'));
  });

  test('the current link it brings into view is one that is shown', () {
    // A hidden copy (a closed group, a tab only shown on a phone) has no
    // place: following it scrolled the view back to the top
    // (tool/thor e2e sidebar).
    final js = scrollRestorationScript('nav');
    expect(js, contains('querySelectorAll("[aria-current=page]")'));
    expect(js, contains('getClientRects().length'));
    expect(js, isNot(contains('querySelector("[aria-current=page]")')));
  });

  test('without a restorationId there is no script', () async {
    final html = await renderHtml(
      const SingleChildScrollView(child: Text('x')),
    );
    expect(html, isNot(contains('<script')));
  });
}

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _render(Widget w) => renderDocument(ThorApp(child: w));

void main() {
  setUpAll(initializeThorTests);

  test('an Iframe is one iframe with a name and no border', () async {
    final html = await _render(
      const Iframe(src: '/preview', title: 'Canvas', lazy: true),
    );
    expect('<iframe'.allMatches(html), hasLength(1));
    expect(html, contains('src="/preview"'));
    expect(html, contains('title="Canvas"'));
    expect(html, contains('loading="lazy"'));
    expect(html, contains('border: 0'));
  });

  test('sandbox, allow and size become attributes and one class', () async {
    final html = await _render(
      const Iframe(
        srcdoc: '<p>hi</p>',
        title: 'Doc',
        width: 320,
        height: 200,
        sandbox: {IframeSandbox.scripts, IframeSandbox.sameOrigin},
        allow: 'fullscreen',
      ),
    );
    expect(html, contains('sandbox="allow-scripts allow-same-origin"'));
    expect(html, contains('allow="fullscreen"'));
    expect(html, contains('width: 320px'));
    expect(html, contains('height: 200px'));
    expect(html, contains('srcdoc="&lt;p&gt;hi&lt;/p&gt;"'));
  });

  test('wrappers fuse into the iframe instead of a div around it', () async {
    final html = await _render(
      const Opacity(
        opacity: 0.5,
        child: Iframe(src: '/p', title: 'P'),
      ),
    );
    expect('<iframe'.allMatches(html), hasLength(1));
    expect(html, contains('<body><iframe'));
    expect(html, contains('opacity'));
  });
}

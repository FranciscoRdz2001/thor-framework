@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

/// The `onclick` of the first element with [id], HTML-decoded.
Future<String?> _onclick(Widget child, String id) async {
  final html = await renderHtml(ThorApp(child: child));
  final tag = RegExp('<[a-z]+ id="$id"[^>]*>').firstMatch(html)?[0];
  if (tag == null) throw StateError('no #$id in $html');
  final raw = RegExp(r'onclick="([^"]*)"').firstMatch(tag)?[1];
  return raw
      ?.replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}

const _expected =
    'if(!event.defaultPrevented&&!event.metaKey&&!event.ctrlKey'
    '&&!event.shiftKey&&!event.altKey&&event.target.closest('
    "'a[href]:not([target]):not([download])'))";

void main() {
  setUpAll(initializeThorTests);

  test('a Drawer closes when a link inside is followed, by default', () async {
    expect(
      await _onclick(const Drawer(id: 'nav', child: Text('x')), 'nav'),
      '${_expected}this.close()',
    );
  });

  test('closeOnNavigate: false leaves no handler', () async {
    expect(
      await _onclick(
        const Drawer(id: 'nav', closeOnNavigate: false, child: Text('x')),
        'nav',
      ),
      isNull,
    );
  });

  test('a Popover panel hides itself the same way', () async {
    expect(
      await _onclick(
        const Popover(id: 'menu', trigger: Text('Menu'), child: Text('x')),
        'menu',
      ),
      '${_expected}this.hidePopover()',
    );
    expect(
      await _onclick(
        const Popover(
          id: 'menu',
          trigger: Text('Menu'),
          closeOnNavigate: false,
          child: Text('x'),
        ),
        'menu',
      ),
      isNull,
    );
  });

  test('the handler is an attribute: it adds no script element', () async {
    Future<int> scripts(bool close) async => '<script'
        .allMatches(
          await renderHtml(
            ThorApp(
              child: Drawer(
                id: 'nav',
                closeOnNavigate: close,
                child: const Text('x'),
              ),
            ),
          ),
        )
        .length;
    expect(await scripts(true), await scripts(false));
  });

  test('new tabs, downloads and modifier clicks are left alone', () {
    for (final guard in [
      'event.metaKey',
      'event.ctrlKey',
      'event.shiftKey',
      'event.altKey',
      'event.defaultPrevented',
      ':not([target])',
      ':not([download])',
    ]) {
      expect(_expected, contains(guard), reason: guard);
    }
  });
}

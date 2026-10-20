// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
// A form action keeps the page's query string (`?tab=account&/save`),
// never doubles the action key on a page that answered a failed POST, and a
// successful POST goes back to the page without it (post/redirect/get).
@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

class _SettingsPage extends ThorPage<void> {
  const _SettingsPage();

  static final calls = <String>[];

  Future<ActionResult?> save(PageRequest request) async {
    calls.add('save');
    return null;
  }

  Future<ActionResult?> drop(PageRequest request) async {
    calls.add('drop');
    return const ActionResult.fail(422);
  }

  Future<ActionResult?> keep(PageRequest request) async {
    calls.add('keep');
    return const ActionResult.success('kept');
  }

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      Form(
        onPost: save,
        child: Column(
          children: [
            const TextField(name: 'x'),
            FilledButton(
              buttonType: ButtonType.submit,
              onPressed: null,
              onPost: drop,
              child: const Text('Drop'),
            ),
          ],
        ),
      ),
      Form(
        preserveQuery: false,
        onPost: keep,
        child: const TextField(name: 'y'),
      ),
      Form(
        action: '/other?z=1&/old',
        onPost: keep,
        child: const TextField(name: 'w'),
      ),
    ],
  );
}

void main() {
  registerPageActions({
    _SettingsPage: [
      PageActionMethod.request('save', (p) => (p as _SettingsPage).save),
      PageActionMethod.request('drop', (p) => (p as _SettingsPage).drop),
      PageActionMethod.request('keep', (p) => (p as _SettingsPage).keep),
    ],
  });
  final app = ThorApp.router(
    routerConfig: ThorRouter([ThorRoute('/settings', const _SettingsPage())]),
  );
  final handler = RouteHandler<Widget>(
    routes: app.routes,
    renderer: WidgetRenderer.router(app),
  );

  Future<ThorResponse> send(String method, String query, {String body = ''}) {
    _SettingsPage.calls.clear();
    return handler.handle(
      PageRequest(
        method: HttpMethod.tryParse(method)!,
        uri: Uri.parse(
          'http://s.test/settings${query.isEmpty ? '' : '?$query'}',
        ),
        headers: const {
          HttpHeader.host: 's.test',
          HttpHeader.origin: 'http://s.test',
          HttpHeader.contentType: 'application/x-www-form-urlencoded',
        },
        body: Stream.value(utf8.encode(body)),
      ),
    );
  }

  String formTag(String html, int index) =>
      RegExp(r'<form[^>]*>').allMatches(html).elementAt(index)[0]!;

  String formaction(String html) =>
      RegExp(r'formaction="([^"]*)"').firstMatch(html)![1]!;

  group('the action URL of a form', () {
    test('keeps the query of the page, then the action', () async {
      final r = await send('GET', 'tab=account&page=2');
      expect(
        formTag(r.text, 0),
        contains('action="?tab=account&amp;page=2&amp;/save"'),
      );
    });

    test('a submit button that posts elsewhere keeps it too', () async {
      final r = await send('GET', 'tab=account');
      expect(formaction(r.text), '?tab=account&amp;/drop');
    });

    test('no query: the old short form', () async {
      final r = await send('GET', '');
      expect(formTag(r.text, 0), contains('action="?/save"'));
      expect(formaction(r.text), '?/drop');
    });

    test(
      'a page that answered a failed POST does not double the action',
      () async {
        // URL of a 422: `?tab=account&/drop`.
        final r = await send('POST', 'tab=account&/drop');
        expect(r.status, 422);
        expect(formTag(r.text, 0), contains('action="?tab=account&amp;/save"'));
        expect(formTag(r.text, 0), isNot(contains('/drop')));
        expect(formaction(r.text), '?tab=account&amp;/drop');
      },
    );

    test(
      'an action key written with escapes counts as an action key',
      () async {
        final r = await send('POST', 'tab=a&%2Fdrop');
        expect(r.status, 422);
        expect(formTag(r.text, 0), contains('action="?tab=a&amp;/save"'));
      },
    );

    test('unicode and an escaped & stay as the browser sent them', () async {
      final r = await send('GET', 'q=caf%C3%A9%20%26%20m%C3%A1s&sort=-name');
      expect(
        formTag(r.text, 0),
        contains(
          'action="?q=caf%C3%A9%20%26%20m%C3%A1s&amp;sort=-name&amp;/save"',
        ),
      );
    });

    test('a hostile query is escaped, not injected', () async {
      final r = await send('GET', 'q=%22%3E%3Cscript%3Ealert(1)%3C/script%3E');
      expect(r.text, isNot(contains('<script>alert(1)')));
      expect(formTag(r.text, 0), contains('action="?q=%22%3E%3Cscript%3E'));
    });

    test('preserveQuery: false gives the short form', () async {
      final r = await send('GET', 'tab=account');
      expect(formTag(r.text, 1), contains('action="?/keep"'));
    });

    test('an explicit action keeps its own URL (its action keys go)', () async {
      final r = await send('GET', 'tab=account');
      expect(formTag(r.text, 2), contains('action="/other?z=1&amp;/keep"'));
    });
  });

  group('after a successful POST', () {
    test('the redirect goes back to the page without the action', () async {
      final r = await send('POST', 'tab=account&/save');
      expect(r.status, 303);
      expect(r.headers['location'], '/settings?tab=account');
      expect(_SettingsPage.calls, ['save']);
    });

    test('with no other query it is the bare path', () async {
      final r = await send('POST', '/save');
      expect(r.headers['location'], '/settings');
    });

    test('an action key with escapes is dropped too', () async {
      final r = await send('POST', 'tab=a&%2Fsave&q=%C3%B1');
      expect(r.status, 303);
      expect(r.headers['location'], '/settings?tab=a&q=%C3%B1');
      expect(_SettingsPage.calls, ['save']);
    });

    test('empty pieces (&&) and the action first', () async {
      final r = await send('POST', '/save&&tab=a&');
      expect(r.headers['location'], '/settings?tab=a');
    });

    test('a value that is a slash is not an action key', () async {
      final r = await send('POST', 'next=/home&/save');
      expect(r.headers['location'], '/settings?next=/home');
    });
  });
}

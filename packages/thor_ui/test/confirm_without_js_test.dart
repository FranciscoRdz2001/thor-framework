// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
// `confirm:` with JavaScript off: what a browser sends is what the server
// reads (a button's own name/value, its formaction, a Form's hidden field),
// so the visitor is asked on a page of its own, and the action runs, with
// its argument, only after the second post.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

final _calls = <String>[];

class AskPage extends ThorPage<void> {
  const AskPage();

  Future<ActionResult?> del(PageRequest request, int id) async {
    _calls.add('del $id ${(await request.form()).toMap()}');
    return null;
  }

  Future<ActionResult?> wipe(PageRequest request) async {
    _calls.add('wipe ${(await request.form()).toMap()}');
    return null;
  }

  Future<ActionResult?> keep(PageRequest request) async {
    _calls.add('keep');
    return null;
  }

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      Form(
        child: Column(
          children: [
            const TextField(name: 'title'),
            FilledButton(
              onPost: del.withArg(7),
              confirm: const ConfirmSpec(
                'Delete #7?',
                message: 'No undo',
                confirmLabel: 'Delete',
              ),
              child: const Text('Delete 7'),
            ),
            FilledButton(
              onPost: wipe,
              confirm: const ConfirmSpec('Wipe it?'),
              child: const Text('Wipe'),
            ),
            FilledButton(onPost: keep, child: const Text('Keep')),
          ],
        ),
      ),
      Form(
        onPost: wipe,
        confirm: const ConfirmSpec('Send the form?'),
        child: Column(
          children: [
            const TextField(name: 'note'),
            FilledButton(
              buttonType: ButtonType.submit,
              onPressed: () {},
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    ],
  );
}

String? _attr(String tag, String name) {
  final m = RegExp('\\s$name="([^"]*)"').firstMatch(tag);
  return m == null
      ? null
      : m[1]!
            .replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'")
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&amp;', '&');
}

void main() {
  registerPageActions({
    AskPage: [
      PageActionMethod.args(
        'del',
        (p) => (p as AskPage).del,
        1,
        (x) => [int.parse(x[0])],
      ),
      PageActionMethod.request('wipe', (p) => (p as AskPage).wipe),
      PageActionMethod.request('keep', (p) => (p as AskPage).keep),
    ],
  });
  final app = ThorApp.router(
    routerConfig: ThorRouter([ThorRoute('/ask', const AskPage())]),
  );
  final handler = RouteHandler<Widget>(
    routes: app.routes,
    renderer: WidgetRenderer.router(app),
  );

  setUp(_calls.clear);

  Future<ThorResponse> post(String url, Map<String, String> fields) =>
      handler.handle(
        PageRequest(
          method: HttpMethod.post,
          uri: Uri.parse('http://s.test$url'),
          headers: const {
            HttpHeader.host: 's.test',
            HttpHeader.origin: 'http://s.test',
            HttpHeader.contentType: 'application/x-www-form-urlencoded',
          },
          body: Stream.value(
            utf8.encode(
              fields.entries
                  .map(
                    (e) =>
                        '${Uri.encodeQueryComponent(e.key)}='
                        '${Uri.encodeQueryComponent(e.value)}',
                  )
                  .join('&'),
            ),
          ),
        ),
      );

  /// Where a browser on /ask posts [ref] (a relative `formaction`/`action`).
  String resolve(String ref) {
    final to = Uri.parse('http://s.test/ask').resolve(ref);
    return '${to.path}${to.hasQuery ? '?${to.query}' : ''}';
  }

  late String html;
  setUpAll(() async {
    html = (await handler.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://s.test/ask'),
        headers: const {HttpHeader.host: 's.test'},
      ),
    )).text;
  });

  String button(String label) =>
      RegExp('<button[^>]*>[^<]*$label<').firstMatch(html)![0]!;

  /// What the browser posts for [tag] pressed with [fields] typed: the
  /// fields, then the button's own name and value, to its formaction.
  Future<ThorResponse> press(String tag, Map<String, String> fields) {
    final name = _attr(tag, 'name');
    return post(resolve(_attr(tag, 'formaction') ?? '/ask'), {
      ...fields,
      ?name: _attr(tag, 'value') ?? '',
    });
  }

  /// The second post of a confirmation page: its form, as the browser sends it.
  Future<ThorResponse> yes(String page) {
    final form = RegExp('<form[^>]*>').firstMatch(page)![0]!;
    final fields = {
      for (final m in RegExp('<input[^>]*>').allMatches(page))
        _attr(m[0]!, 'name')!: _attr(m[0]!, 'value') ?? '',
    };
    return post(resolve(_attr(form, 'action')!), fields);
  }

  group('what a button with confirm: sends', () {
    test('a button with an argument asks in its formaction', () {
      final b = button('Delete 7');
      expect(_attr(b, 'name'), 'thor-arg', reason: 'its argument stays');
      expect(_attr(b, 'value'), '7');
      final action = _attr(b, 'formaction')!;
      expect(action, startsWith('?/del&/thor-ask='));
      final ask = jsonDecode(
        Uri.splitQueryString(
          action.substring(action.indexOf('&') + 1),
        )['/thor-ask']!,
      );
      expect(ask, {'t': 'Delete #7?', 'm': 'No undo', 'o': 'Delete'});
      // The dialog's attributes stay for the page's script.
      expect(b, contains('data-t-confirm="Delete #7?"'));
    });

    test('a button without one asks in its name and value', () {
      final b = button('Wipe');
      expect(_attr(b, 'name'), 'thor-ask');
      expect(jsonDecode(_attr(b, 'value')!), {'t': 'Wipe it?'});
      expect(_attr(b, 'formaction'), '?/wipe');
    });

    test('a button with no confirm: sends nothing extra', () {
      final b = button('Keep');
      expect(b, isNot(contains('thor-ask')));
      expect(b, isNot(contains('data-t-confirm')));
    });

    test('a Form with confirm: posts the question as a hidden field', () {
      final form = RegExp(
        '<form[^>]*data-t-confirm[^>]*>.*?</form>',
        dotAll: true,
      ).firstMatch(html)![0]!;
      final field = RegExp(
        '<input[^>]*name="thor-ask"[^>]*>',
      ).firstMatch(form)![0]!;
      expect(field, contains('type="hidden"'));
      expect(jsonDecode(_attr(field, 'value')!), {'t': 'Send the form?'});
    });
  });

  group('without JavaScript, from the first post to the action', () {
    test(
      'a button with an argument: asked, then it runs with its argument',
      () async {
        final asked = await press(button('Delete 7'), {'title': 'keep me'});
        expect(asked.status, 200);
        expect(_calls, isEmpty, reason: 'nothing ran yet');
        expect(asked.text, contains('<h1>Delete #7?</h1>'));
        expect(asked.text, contains('No undo'));
        expect(asked.text, contains('>Delete</button>'));
        final done = await yes(asked.text);
        expect(done.status, 303);
        expect(_calls.single, startsWith('del 7'));
        expect(_calls.single, contains('title: keep me'));
      },
    );

    test('a plain button: asked, then it runs', () async {
      final asked = await press(button('Wipe'), {'title': 't'});
      expect(asked.text, contains('Wipe it?'));
      expect(_calls, isEmpty);
      expect((await yes(asked.text)).status, 303);
      expect(_calls.single, startsWith('wipe'));
    });

    test('a Form with confirm: asked, then it runs', () async {
      final form = RegExp(
        '<form[^>]*data-t-confirm[^>]*>',
      ).firstMatch(html)![0]!;
      final asked = await post(resolve(_attr(form, 'action')!), {
        'note': 'hi',
        'thor-ask': jsonEncode({'t': 'Send the form?'}),
      });
      expect(asked.text, contains('Send the form?'));
      expect(_calls, isEmpty);
      expect((await yes(asked.text)).status, 303);
      expect(_calls.single, contains('note: hi'));
    });

    test('the dialog\'s yes (JavaScript on) is not asked again', () async {
      final b = button('Delete 7');
      final r = await post(resolve(_attr(b, 'formaction')!), {
        'thor-arg': '7',
        'thor-confirmed': '1',
      });
      expect(r.status, 303);
      expect(_calls.single, startsWith('del 7'));
    });

    test('a button with no confirm: runs at once', () async {
      final r = await press(button('Keep'), {});
      expect(r.status, 303);
      expect(_calls, ['keep']);
    });
  });
}

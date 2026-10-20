// Edges of typed actions that typed_actions_test does not cover: URLs with
// a fragment or a query, one class on two routes, the old map with the same
// name, GET, multipart, errors in the method and fields of another schema.
import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

final class NoteForm extends FormSchema {
  const NoteForm._() : super(const [text]);

  static const schema = NoteForm._();

  static const text = TextSchemaField(
    'text',
    validators: [Validator.required('Write something')],
  );
}

final class OtherForm extends FormSchema {
  const OtherForm._() : super(const [name]);

  static const schema = OtherForm._();

  static const name = TextSchemaField('name');
}

final _calls = <String>[];

/// One class, two routes: each instance must run its own method.
class ListPage extends ThorPage<void> {
  const ListPage(this.kind);

  final String kind;

  Future<ActionResult?> add(
    PageRequest request,
    FormValues<NoteForm> values,
  ) async {
    _calls.add('$kind ${values.of(NoteForm.text)}');
    return null;
  }

  Future<ActionResult?> boom(PageRequest request) async =>
      throw StateError('backend down');

  Future<ActionResult?> wrongField(
    PageRequest request,
    FormValues<NoteForm> values,
  ) async {
    _calls.add('wrong ${values.of(OtherForm.name)}');
    return null;
  }

  Future<ActionResult?> unauthorized(
    PageRequest request,
    FormValues<NoteForm> values,
  ) async => values.invalid('Sign in again').fail(401);

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      Form(
        schema: NoteForm.schema,
        onValid: add,
        action: '/$kind#bottom',
        child: const Text('fragment'),
      ),
      Form(
        schema: NoteForm.schema,
        onValid: add,
        action: '/$kind?tab=a',
        child: const Text('query'),
      ),
      Form(
        schema: NoteForm.schema,
        onValid: add,
        action: '/$kind?tab=a#bottom',
        child: const Text('query and fragment'),
      ),
    ],
  );
}

class MutablePage extends ThorPage<void> {
  // Not const: the router holds this one instance.
  MutablePage();

  Future<ActionResult?> save(PageRequest request) async {
    _calls.add('mutable');
    return null;
  }

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      Form(onPost: save, child: const Text('x'));
}

void registerActions() => registerPageActions({
  ListPage: [
    PageActionMethod.valid('add', (p) => (p as ListPage).add, NoteForm.schema),
    PageActionMethod.request('boom', (p) => (p as ListPage).boom),
    PageActionMethod.valid(
      'wrongField',
      (p) => (p as ListPage).wrongField,
      NoteForm.schema,
    ),
    PageActionMethod.valid(
      'unauthorized',
      (p) => (p as ListPage).unauthorized,
      NoteForm.schema,
    ),
  ],
  MutablePage: [
    PageActionMethod.request('save', (p) => (p as MutablePage).save),
  ],
});

void main() {
  registerActions();
  final app = ThorApp.router(
    routerConfig: ThorRouter([
      ThorRoute('/todo', const ListPage('todo')),
      ThorRoute('/done', const ListPage('done')),
      ThorRoute('/mutable', MutablePage()),
    ]),
  );
  final handler = RouteHandler<Widget>(
    routes: app.routes,
    renderer: WidgetRenderer.router(app),
  );

  Future<ThorResponse> send(
    String method,
    String url, {
    String body = '',
    String type = 'application/x-www-form-urlencoded',
  }) => handler.handle(
    PageRequest(
      method: HttpMethod.tryParse(method)!,
      uri: Uri.parse('http://s.test$url'),
      headers: {
        HttpHeader.host: 's.test',
        HttpHeader.origin: 'http://s.test',
        HttpHeader.contentType: type,
      },
      body: Stream.value(utf8.encode(body)),
    ),
  );

  setUp(_calls.clear);

  group('URL', () {
    test('a fragment in action: stays after the method', () async {
      final html = (await send('GET', '/todo')).text;
      expect(html, contains('action="/todo?/add#bottom"'));
    });

    test('a query in action: joins with &', () async {
      final html = (await send('GET', '/todo')).text;
      expect(html, contains('action="/todo?tab=a&amp;/add"'));
    });

    test('a query and a fragment in action:', () async {
      final html = (await send('GET', '/todo')).text;
      expect(html, contains('action="/todo?tab=a&amp;/add#bottom"'));
    });
  });

  group('dispatch', () {
    test('one class in two routes runs each instance', () async {
      await send('POST', '/todo?/add', body: 'text=a');
      await send('POST', '/done?/add', body: 'text=b');
      expect(_calls, ['todo a', 'done b']);
    });

    test('a GET never runs an action', () async {
      final r = await send('GET', '/todo?/add');
      expect(_calls, isEmpty);
      expect(r.status, isNot(303));
    });

    test('a multipart form is checked with the schema too', () async {
      const boundary = 'XyZ';
      final r = await send(
        'POST',
        '/todo?/add',
        type: 'multipart/form-data; boundary=$boundary',
        body:
            '--$boundary\r\n'
            'Content-Disposition: form-data; name="text"\r\n\r\n'
            'from multipart\r\n'
            '--$boundary--\r\n',
      );
      expect(_calls, ['todo from multipart']);
      expect(r.status, 303);
    });

    test('an empty multipart form is a 422', () async {
      const boundary = 'XyZ';
      final r = await send(
        'POST',
        '/todo?/add',
        type: 'multipart/form-data; boundary=$boundary',
        body:
            '--$boundary\r\n'
            'Content-Disposition: form-data; name="text"\r\n\r\n'
            '\r\n'
            '--$boundary--\r\n',
      );
      expect(r.status, 422);
      expect(_calls, isEmpty);
    });

    test('a method that throws is a 500 without the message', () async {
      final r = await send('POST', '/todo?/boom');
      expect(r.status, 500);
      expect(r.text, isNot(contains('backend down')));
    });

    test('a field of another schema is THOR-P007, not a value', () async {
      final r = await send('POST', '/todo?/wrongField', body: 'text=a');
      expect(r.status, 500);
      expect(_calls, isEmpty);
    });

    test('invalid().fail(401) answers 401', () async {
      final r = await send('POST', '/todo?/unauthorized', body: 'text=a');
      expect(r.status, 401);
    });

    test('a page that is not const posts to its method', () async {
      final html = (await send('GET', '/mutable')).text;
      // Its only action: the page's path, and a keyless POST reaches it.
      expect(html, contains('action="/mutable"'));
      final r = await send('POST', '/mutable?/save');
      expect(_calls, ['mutable']);
      expect(r.status, 303);
      final keyless = await send('POST', '/mutable');
      expect(_calls, ['mutable', 'mutable']);
      expect(keyless.status, 303);
    });
  });
}

// A ListBox in a Form posts without JS: one value under its name, or one
// field per chosen value with `multiSelectionEnabled` (what a browser sends
// for a `<select multiple>`).
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

const _items = [
  ListBoxItem(value: 'es', child: Text('Español')),
  ListBoxItem(value: 'en', child: Text('English')),
  ListBoxItem(value: 'fr', child: Text('Français')),
];

class _LangPage extends ThorPage<void> {
  const _LangPage();

  Future<ActionResult?> save(PageRequest request) async {
    final form = await request.form();
    return ActionResult.success(
      'lang=${form['lang']} langs=${form.all('langs').join(',')}',
    );
  }

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      Form(
        onPost: save,
        child: const Column(
          children: [
            ListBox<String>(items: _items, name: 'lang'),
            ListBox<String>(
              items: _items,
              name: 'langs',
              multiSelectionEnabled: true,
            ),
            FilledButton(
              buttonType: ButtonType.submit,
              onPressed: null,
              child: Text('Save'),
            ),
          ],
        ),
      ),
      Text(
        'sent ${state.form is ActionResult ? (state.form! as ActionResult).data : state.form ?? ''}',
      ),
    ],
  );
}

void main() {
  registerPageActions({
    _LangPage: [PageActionMethod.request('save', (p) => (p as _LangPage).save)],
  });
  final app = ThorApp.router(
    routerConfig: ThorRouter([ThorRoute('/', const _LangPage())]),
  );
  RouteHandler<Widget> handler() => RouteHandler<Widget>(
    routes: app.routes,
    renderer: WidgetRenderer.router(app),
  );

  setUpAll(initializeThorTests);

  test('the page has two enabled <select size> fields in a <form>', () async {
    final res = await handler().client().get('/');
    expect(res, hasStatus(200));
    final form = res.html.querySelector('form')!;
    final selects = form.querySelectorAll('select');
    expect(selects, hasLength(2));
    expect(selects[0].attributes['name'], 'lang');
    expect(selects[0].attributes['size'], '4');
    expect(selects[0].attributes.containsKey('multiple'), isFalse);
    expect(selects[1].attributes['name'], 'langs');
    expect(selects[1].attributes.containsKey('multiple'), isTrue);
    expect(selects.every((s) => !s.attributes.containsKey('disabled')), isTrue);
    expect(form.attributes['method'], 'post');
  });

  test('the action gets one value, and every chosen one repeated', () async {
    // What the browser does on submit: post the fields to the form's action.
    final client = handler().client();
    final page = await client.get('/');
    final form = page.html.querySelector('form')!;
    expect(form.querySelector('button[type=submit]'), isNotNull);
    final res = await client.post(
      form.attributes['action']!,
      form: {
        'lang': 'en',
        'langs': ['es', 'fr'],
      },
    );
    expect(res, hasStatus(200));
    expect(res.text, contains('sent lang=en langs=es,fr'));
  });
}

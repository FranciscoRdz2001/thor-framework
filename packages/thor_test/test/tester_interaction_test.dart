// ThorTester: find.byKey / find.byType, enterText and tap over the
// no-JavaScript paths (forms and links through the app's handler).
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

class _Card extends StatelessWidget {
  const _Card(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Text(title);
}

Widget _el(String tag, [List<Widget>? children, Map<String, String>? attrs]) =>
    Widget.element(tag: tag, children: children, attributes: attrs);

class _FormPage extends ThorPage<void> {
  const _FormPage();

  Future<ActionResult?> save(PageRequest request) async {
    final form = await request.form();
    return ActionResult.success(
      'saved ${form['user']}/${form['note']}/${form['kind']}/${form['agree']}',
    );
  }

  Future<ActionResult?> leave(PageRequest request) async =>
      const Redirect(RouteUrl('/home'));

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      Text('${state.form ?? ''}'),
      _el(
        'form',
        [
          _el('input', null, {'name': 'user', 'value': 'old'}),
          _el('textarea', [const Widget.text('')], {'name': 'note'}),
          _el(
            'select',
            [
              _el('option', [const Widget.text('a')], {'value': 'a'}),
              _el('option', [const Widget.text('b')], {'value': 'b'}),
            ],
            {'name': 'kind'},
          ),
          _el('input', null, {'type': 'checkbox', 'name': 'agree'}),
          _el('button', [const Widget.text('Save')], {'type': 'submit'}),
        ],
        {'method': 'post', 'action': '?/save'},
      ),
      _el(
        'form',
        [
          _el('button', [const Widget.text('Leave')]),
        ],
        {'method': 'post', 'action': '?/leave'},
      ),
      _el('a', [const Widget.text('Go home')], {'href': '/home'}),
      _el('button', [const Widget.text('Plain')], {'type': 'button'}),
    ],
  );
}

class _RealFormPage extends ThorPage<void> {
  const _RealFormPage();

  Future<ActionResult?> save(PageRequest request) async {
    final form = await request.form();
    return ActionResult.success('real ${form['user']}');
  }

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      Text('${state.form ?? ''}'),
      Form(
        onPost: save,
        child: const Column(
          children: [
            TextFormField(
              name: 'user',
              decoration: InputDecoration(labelText: 'User'),
            ),
            ElevatedButton(
              buttonType: ButtonType.submit,
              onPressed: null,
              child: Text('Save'),
            ),
          ],
        ),
      ),
    ],
  );
}

class _HomePage extends ThorPage<void> {
  const _HomePage();
  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Text('home page');
}

void main() {
  registerPageActions({
    _RealFormPage: [
      PageActionMethod.request('save', (p) => (p as _RealFormPage).save),
    ],
    _FormPage: [
      PageActionMethod.request('save', (p) => (p as _FormPage).save),
      PageActionMethod.request('leave', (p) => (p as _FormPage).leave),
    ],
  });
  final app = ThorApp.router(
    routerConfig: ThorRouter([
      ThorRoute('/', const _FormPage()),
      ThorRoute('/real', const _RealFormPage()),
      ThorRoute('/home', const _HomePage()),
    ]),
  );
  ThorTestClient client() => RouteHandler<Widget>(
    routes: app.routes,
    renderer: WidgetRenderer.router(app),
  ).client();

  group('byKey and byType', () {
    testThor('find a pumped widget by type and key', (tester) async {
      await tester.pumpWidget(
        const Column(
          children: [
            _Card('one', key: ValueKey('a')),
            _Card('two', key: ValueKey('b')),
          ],
        ),
      );
      expect(find.byType(_Card), findsNWidgets(2));
      expect(find.byType(Text), findsWidgets);
      expect(find.byKey(const ValueKey('b')), findsOneWidget);
      expect(
        tester.widgetHtml(find.byKey(const ValueKey('b'))),
        contains('two'),
      );
      expect(find.byKey(const ValueKey('zz')), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(tester.html, isNot(contains('data-thor-w')));
    });

    testThor('a wrapper finds the element it decorates', (tester) async {
      await tester.pumpWidget(
        const Padding(padding: EdgeInsets.all(4), child: Text('p')),
      );
      expect(find.byType(Padding), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });
  });

  group('enterText and tap', () {
    testThor('a submit button sends the typed fields', (tester) async {
      await tester.visit(client(), '/');
      await tester.enterText(find.byTag('input').first, 'ana');
      await tester.enterText(find.byTag('textarea'), 'hello');
      await tester.enterText(find.byTag('select'), 'b');
      await tester.tap(find.byTag('input').last);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(tester.response, hasStatus(200));
      expect(find.text('saved ana/hello/b/on'), findsOneWidget);
    });

    testThor('unchecked boxes and untouched fields keep their defaults', (
      tester,
    ) async {
      await tester.visit(client(), '/');
      await tester.tap(find.text('Save'));
      expect(find.text('saved old//a/null'), findsOneWidget);
    });

    testThor('a redirect is followed and the new page shown', (tester) async {
      await tester.visit(client(), '/');
      await tester.tap(find.text('Leave'));
      expect(find.text('home page'), findsOneWidget);
    });

    testThor('a link is followed', (tester) async {
      await tester.visit(client(), '/');
      await tester.tap(find.text('Go home'));
      expect(find.text('home page'), findsOneWidget);
    });

    testThor('a button with no form path says it is browser-only', (
      tester,
    ) async {
      await tester.visit(client(), '/');
      expect(
        () => tester.tap(find.text('Plain')),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('ThorState'),
          ),
        ),
      );
    });

    testThor('real Form, TextFormField and submit button', (tester) async {
      await tester.visit(client(), '/real');
      await tester.enterText(find.byTag('input').first, 'ana');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(tester.html, contains('real ana'));
    });

    testThor('tap without a server explains how to get one', (tester) async {
      await tester.pumpWidget(
        _el('a', [const Widget.text('x')], {'href': '/'}),
      );
      expect(() => tester.tap(find.text('x')), throwsA(isA<StateError>()));
    });

    testThor('enterText rejects what is not a field', (tester) async {
      await tester.pumpWidget(const Text('t'));
      expect(
        () => tester.enterText(find.text('t'), 'x'),
        throwsA(isA<StateError>()),
      );
    });
  });
}

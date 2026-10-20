// These tests are about the button's wiring, not its name.
// ignore_for_file: thor_lints/icon_button_without_name
@TestOn('vm')
library;

// The page's one confirm dialog and snack bar (only where a state or a
// button asks for them), the `confirm:` of a submit button, and the server's
// flash: markup, contract with the inline scripts, escaping and the
// non-happy paths.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:thor_engine/src/js_minify.dart';
import 'package:thor_engine/src/js_rename.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/src/engine/feedback_script.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

/// A state whose code calls `confirm(…)` (what the build lists in `uses`).
class AsksState extends ThorState {
  final ok = state(0);

  @override
  String get $type => 'AsksState';

  @override
  Set<String> get uses => const {'confirm'};

  @override
  List<ThorMember> get $members => [
    ThorMember('remove', remove, call: (_) => remove()),
  ];

  void remove() {}
}

class TellsState extends ThorState {
  @override
  String get $type => 'TellsState';

  @override
  Set<String> get uses => const {'toast'};

  @override
  List<ThorMember> get $members => [
    ThorMember('save', save, call: (_) => save()),
  ];

  void save() {}
}

class PlainState extends ThorState {
  @override
  String get $type => 'PlainState';

  @override
  List<ThorMember> get $members => [ThorMember('go', go, call: (_) => go())];

  void go() {}
}

final asks = AsksState();
final tells = TellsState();
final plain = PlainState();

class FeedbackPage extends ThorPage<void> {
  const FeedbackPage(this.which);

  final String which;

  Future<ActionResult?> delete(PageRequest request) async => null;

  @override
  Widget build(BuildContext context, PageState<void> state) => switch (which) {
    'asks' => TextButton(onPressed: asks.remove, child: const Text('remove')),
    'tells' => TextButton(onPressed: tells.save, child: const Text('save')),
    'both' => Column(
      children: [
        TextButton(onPressed: asks.remove, child: const Text('remove')),
        TextButton(onPressed: tells.save, child: const Text('save')),
      ],
    ),
    'plain' => TextButton(onPressed: plain.go, child: const Text('go')),
    'button' => Column(
      children: [
        FilledButton(
          onPost: delete,
          confirm: const ConfirmSpec(
            'Delete "this" <order>?',
            message: 'No undo',
            confirmLabel: 'Delete',
            cancelLabel: 'Keep',
          ),
          child: const Text('Delete'),
        ),
        FilledButton(
          onPost: delete,
          confirm: const ConfirmSpec('Again?'),
          child: const Text('Delete 2'),
        ),
        IconButton(
          onPost: delete,
          confirm: const ConfirmSpec('Icon?'),
          icon: const Icon(IconData.svg('x', '<path d="M0 0"/>')),
        ),
      ],
    ),
    'form' => Form(
      onPost: delete,
      confirm: const ConfirmSpec('Send form?'),
      child: FilledButton(
        buttonType: ButtonType.submit,
        onPressed: () {},
        child: const Text('Send'),
      ),
    ),
    _ => const Text('nothing'),
  };
}

void registerActions() => registerPageActions({
  FeedbackPage: [
    PageActionMethod.request('delete', (p) => (p as FeedbackPage).delete),
  ],
});

void main() {
  initializeThorTests();
  registerActions();
  final app = ThorApp.router(
    serverMessages: const ServerMessages(ok: 'Got it', cancel: 'Never mind'),
    routerConfig: ThorRouter([
      for (final w in [
        'asks',
        'tells',
        'both',
        'plain',
        'button',
        'form',
        'none',
      ])
        ThorRoute('/$w', FeedbackPage(w)),
    ]),
  );
  final handler = RouteHandler<Widget>(
    routes: app.routes,
    renderer: WidgetRenderer.router(app),
  );

  Future<ThorResponse> get(String path, {String? cookie}) => handler.handle(
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://s.test$path'),
      headers: {HttpHeader.host: 's.test', HttpHeader.cookie: ?cookie},
    ),
  );

  int count(String html, String needle) => needle.allMatches(html).length;

  group('the confirm dialog of a state', () {
    late String html;
    setUpAll(() async => html = (await get('/asks')).text);

    test('one native dialog with the parts the script fills', () {
      expect(count(html, '<dialog'), 1);
      expect(html, contains('id="thor-confirm"'));
      expect(html, contains('data-t-c="t"'));
      expect(html, contains('data-t-c="m"'));
      expect(html, contains('data-t-c="o"'));
      expect(html, contains('data-t-c="n"'));
      // The answers are a `<form method=dialog>`: `returnValue` says which.
      expect(html, contains(RegExp('<form[^>]*method="dialog"')));
      expect(html, contains('value="ok"'));
      expect(html, contains('value="cancel"'));
    });

    test('the focus starts on the answer that does nothing', () {
      final cancel = RegExp(
        '<button[^>]*value="cancel"[^>]*>',
      ).firstMatch(html)!;
      expect(cancel[0], contains('autofocus'));
      final ok = RegExp('<button[^>]*value="ok"[^>]*>').firstMatch(html)!;
      expect(ok[0], isNot(contains('autofocus')));
    });

    test('the labels are the app\'s, and the message starts hidden', () {
      expect(html, contains('>Got it<'));
      expect(html, contains('>Never mind<'));
      expect(
        RegExp(
          'data-t-c="m"[^>]*hidden|hidden[^>]*data-t-c="m"',
        ).hasMatch(html),
        isTrue,
      );
    });

    test('the inline script comes once, after the dialog', () {
      expect(count(html, confirmScript), 1);
      expect(
        html.indexOf(confirmScript),
        greaterThan(html.indexOf('</dialog>')),
      );
    });

    test('no snack bar, no toast script', () {
      expect(html, isNot(contains('thor-toast')));
      expect(html, isNot(contains(toastScript)));
    });
  });

  group('the snack bar of a state', () {
    late String html;
    setUpAll(() async => html = (await get('/tells')).text);

    test('one live region and its looks, hidden', () {
      expect(count(html, 'id="thor-toast"'), 1);
      final bar = RegExp('<[^>]*id="thor-toast"[^>]*>').firstMatch(html)![0]!;
      expect(bar, contains('role="status"'));
      expect(bar, isNot(contains('data-t-on')));
      final template = html.substring(
        html.indexOf('<template id="thor-toast-kinds"'),
      );
      for (final k in ['off', 'info', 'success', 'error']) {
        expect(template, contains('data-k="$k"'));
      }
    });

    test(
      'the page\'s own bar does not ask for the hand-made one\'s script',
      () {
        expect(html, isNot(contains(snackScript)));
        expect(html, isNot(contains('data-snack="')));
      },
    );

    test('the bar is a manual popover (over modals), never the looks', () {
      final bar = RegExp('<[^>]*id="thor-toast"[^>]*>').firstMatch(html)![0]!;
      expect(bar, contains('popover="manual"'));
      final template = html.substring(
        html.indexOf('<template id="thor-toast-kinds"'),
      );
      expect(
        template.substring(0, template.indexOf('</template>')),
        isNot(contains('popover')),
      );
      // The script raises it into the top layer and inside an open modal.
      expect(toastScript, contains('showPopover'));
      expect(toastScript, contains(':modal'));
    });

    test('the browser\'s popover box is undone in its class', () {
      final bar = RegExp('<[^>]*id="thor-toast"[^>]*>').firstMatch(html)![0]!;
      final cls = RegExp('class="([^"]*)"').firstMatch(bar)![1]!;
      final rule = RegExp('\\.$cls\\{([^}]*)\\}').firstMatch(html)![1]!;
      for (final d in [
        'margin: 0',
        'top: auto',
        'right: auto',
        'border: none',
        'overflow: visible',
      ]) {
        expect(rule, contains(d));
      }
    });

    test('the looks are classes the server made (the browser makes none)', () {
      final template = html.substring(
        html.indexOf('<template id="thor-toast-kinds"'),
      );
      final classes = RegExp(
        r'data-k="(\w+)"[^>]*class="([^"]*)"|class="([^"]*)"[^>]*data-k="(\w+)"',
      ).allMatches(template).toList();
      expect(classes.length, 4);
      final css = html.substring(0, html.indexOf('</style>'));
      // The error look has its own colors.
      expect(css, contains('--t-error'));
    });

    test('the script comes once; no dialog', () {
      expect(count(html, toastScript), 1);
      expect(html, isNot(contains('<dialog')));
      expect(html, isNot(contains(confirmScript)));
    });
  });

  test('a page that uses neither ships neither', () async {
    final html = (await get('/plain')).text;
    expect(html, isNot(contains('thor-confirm')));
    expect(html, isNot(contains('thor-toast')));
    expect(html, isNot(contains('<dialog')));
    expect(html, isNot(contains('thorConfirm')));
    expect(html, isNot(contains('thorToast')));
  });

  test('two states asking and telling: one dialog, one bar', () async {
    final html = (await get('/both')).text;
    expect(count(html, 'id="thor-confirm"'), 1);
    expect(count(html, 'id="thor-toast"'), 1);
    expect(count(html, confirmScript), 1);
    expect(count(html, toastScript), 1);
  });

  group('confirm: on a submit button', () {
    late String html;
    setUpAll(() async => html = (await get('/button')).text);

    test('the button is a real submit with the question on it', () {
      final b = RegExp('<button[^>]*>[^<]*Delete<').firstMatch(html)![0]!;
      expect(b, contains('formaction="/button"'));
      expect(b, contains('type="submit"'));
      expect(
        b,
        contains('data-t-confirm="Delete &quot;this&quot; &lt;order&gt;?"'),
      );
      expect(b, contains('data-t-cm="No undo"'));
      expect(b, contains('data-t-co="Delete"'));
      expect(b, contains('data-t-cn="Keep"'));
      expect(html, isNot(contains('<order>')));
    });

    test('an IconButton and a Form ask the same way', () async {
      expect(html, contains('data-t-confirm="Icon?"'));
      final form = (await get('/form')).text;
      expect(form, contains(RegExp('<form[^>]*data-t-confirm="Send form\\?"')));
    });

    test('the dialog and its script come once for any number of buttons', () {
      expect(count(html, 'id="thor-confirm"'), 1);
      expect(count(html, confirmScript), 1);
    });

    test('without labels the button leaves them to the dialog', () {
      final b = RegExp('<button[^>]*>[^<]*Delete 2<').firstMatch(html)![0]!;
      expect(b, contains('data-t-confirm="Again?"'));
      expect(b, isNot(contains('data-t-cm=')));
      expect(b, isNot(contains('data-t-co=')));
    });
  });

  group('the server flash', () {
    test(
      'shows once as the snack bar, escaped, and clears the cookie',
      () async {
        final r = await get(
          '/none',
          cookie: 'thor-flash=success%3AOrder%20%3Cb%3Edeleted%3C%2Fb%3E',
        );
        expect(r.text, contains('Order &lt;b&gt;deleted&lt;/b&gt;'));
        expect(r.text, isNot(contains('<b>deleted')));
        final bar = RegExp(
          '<[^>]*id="thor-toast"[^>]*>',
        ).firstMatch(r.text)![0]!;
        expect(bar, contains('data-t-on'));
        expect(bar, contains('role="status"'));
        expect(
          r.cookies.single,
          allOf(startsWith('thor-flash=;'), contains('Max-Age=0')),
        );
        // Without JS: no script for a flash alone (the CSS hides it).
        expect(r.text, isNot(contains(toastScript)));
        expect(r.text, isNot(contains('<dialog')));
      },
    );

    test('a page without a flash has no bar and touches no cookie', () async {
      final r = await get('/none');
      expect(r.text, isNot(contains('thor-toast')));
      expect(r.cookies, isEmpty);
    });

    test('kinds: the look follows, an unknown one is info', () async {
      final ok = (await get('/none', cookie: 'thor-flash=error%3AOops')).text;
      final unknown = (await get('/none', cookie: 'thor-flash=evil%3AHi')).text;
      final info = (await get('/none', cookie: 'thor-flash=info%3AHi')).text;
      String bar(String html) =>
          RegExp('<[^>]*id="thor-toast"[^>]*>').firstMatch(html)![0]!;
      expect(bar(ok), isNot(equals(bar(info))));
      expect(bar(unknown), bar(info));
      expect(unknown, contains('>Hi<'));
    });

    test('a huge or blank cookie shows nothing', () async {
      final huge = (await get(
        '/none',
        cookie: 'thor-flash=info%3A${'y' * 9000}',
      )).text;
      expect(huge, contains('y' * 300));
      expect(huge, isNot(contains('y' * 301)));
      final blank = (await get('/none', cookie: 'thor-flash=info%3A%20')).text;
      expect(blank, isNot(contains('thor-toast')));
    });

    test('with a toast state the flash is the bar\'s first content', () async {
      final r = await get('/tells', cookie: 'thor-flash=info%3AHello');
      expect(count(r.text, 'id="thor-toast"'), 1);
      expect(r.text, contains('data-t-on'));
      expect(count(r.text, toastScript), 1);
    });
  });

  group('the inline scripts are their sources, minified', () {
    for (final (name, script) in [
      ('confirm', confirmScript),
      ('toast', toastScript),
      ('snack', snackScript),
    ]) {
      test(name, () async {
        final uri = await Isolate.resolvePackageUri(
          Uri.parse('package:thor_engine/lite/$name.js'),
        );
        final source = File.fromUri(uri!).readAsStringSync();
        expect(script, minifyJs(renameLocals(source)));
        expect(script, isNot(contains('</script')));
      });
    }
  });

  test('the encoded flash of the server reads back the same', () {
    final flash = FlashMessage('Saved: 50%', FlashKind.success);
    expect(utf8.encode(flash.cookieValue), isNotEmpty);
    expect(FlashMessage.parse(flash.cookieValue)!.message, 'Saved: 50%');
  });
}

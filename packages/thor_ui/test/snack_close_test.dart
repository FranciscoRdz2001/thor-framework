@TestOn('vm')
library;

// The snack bar's close icon and its position (Flutter's
// `SnackBar(showCloseIcon:, width:, margin:)` and
// `SnackBarThemeData(showCloseIcon:, closeIconColor:, width:, insetPadding:,
// behavior:)`), on a hand-made bar and on the page's own one (`toast()`):
// the markup, and the two scripts run in node over the server's HTML.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_ui/intl.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class _TellsState extends ThorState {
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

final _tells = _TellsState();

class _TellsPage extends ThorPage<void> {
  const _TellsPage();

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      TextButton(onPressed: _tells.save, child: const Text('save'));
}

Future<String> _bar(Widget bar, {SnackBarThemeData? theme}) => renderDocument(
  ThorApp(
    theme: theme == null ? null : ThemeData(snackBarTheme: theme),
    child: bar,
  ),
);

Future<String> _toastPage({SnackBarThemeData? theme, String? cookie}) async {
  final app = ThorApp.router(
    theme: theme == null ? null : ThemeData(snackBarTheme: theme),
    routerConfig: ThorRouter([ThorRoute('/t', const _TellsPage())]),
  );
  final handler = RouteHandler<Widget>(
    routes: app.routes,
    renderer: WidgetRenderer.router(app),
  );
  final r = await handler.handle(
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://s.test/t'),
      headers: {HttpHeader.host: 's.test', HttpHeader.cookie: ?cookie},
    ),
  );
  return r.text;
}

RegExpMatch? _closeButton(String html) =>
    RegExp('<button[^>]*data-snack-close[^>]*>').firstMatch(html);

void main() {
  initializeThorTests();

  group('SnackBar(showCloseIcon:)', () {
    test('is a real button with an accessible name', () async {
      final html = await _bar(
        const SnackBar(showCloseIcon: true, content: Text('Saved')),
      );
      final b = _closeButton(html)![0]!;
      expect(b, contains('type="button"'));
      expect(b, contains('aria-label="Close"'));
      expect(b, isNot(contains('disabled')));
      expect(b, isNot(contains('tabindex')));
      expect(html, contains('data-snack-text'));
      // After the message: the button is the last thing in the bar.
      expect(
        html.indexOf('>Saved<'),
        lessThan(html.indexOf('data-snack-close data-thor')),
      );
    });

    test('there is none by default', () async {
      final html = await _bar(const SnackBar(content: Text('Saved')));
      expect(_closeButton(html), isNull);
      expect(html, isNot(contains('data-snack-text')));
    });

    test('the theme turns it on and the parameter wins', () async {
      const theme = SnackBarThemeData(showCloseIcon: true);
      final on = await _bar(
        const SnackBar(content: Text('Saved')),
        theme: theme,
      );
      expect(_closeButton(on), isNotNull);
      final off = await _bar(
        const SnackBar(showCloseIcon: false, content: Text('Saved')),
        theme: theme,
      );
      expect(_closeButton(off), isNull);
    });

    test('closeIconColor colors the icon', () async {
      final html = await _bar(
        const SnackBar(
          showCloseIcon: true,
          closeIconColor: Color(0xFFFF0000),
          content: Text('Saved'),
        ),
      );
      expect(html, contains('color: #ff0000'));
      final themed = await _bar(
        const SnackBar(showCloseIcon: true, content: Text('Saved')),
        theme: const SnackBarThemeData(closeIconColor: Color(0xFF00FF00)),
      );
      expect(themed, contains('color: #00ff00'));
    });

    test('has a Spanish name under a Spanish locale', () async {
      final html = await renderDocument(
        const ThorApp(
          locale: Locale('es'),
          supportedLocales: [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          child: SnackBar(showCloseIcon: true, content: Text('Listo')),
        ),
      );
      expect(_closeButton(html)![0], contains('aria-label="Cerrar"'));
    });
  });

  group('where the bar sits', () {
    test('width and insetPadding of the theme (floating)', () async {
      final html = await _bar(
        const SnackBar(content: Text('Saved')),
        theme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          width: 320,
          insetPadding: EdgeInsets.fromLTRB(8, 0, 24, 72),
        ),
      );
      expect(html, contains('width: 320px'));
      // The bottom inset lifts it (above a bottom toolbar) and the sides
      // shift its centre and narrow its room.
      expect(
        html,
        contains('bottom: calc(max(72px, env(safe-area-inset-bottom))'),
      );
      expect(html, contains('left: calc(50% + -8px)'));
      expect(html, contains('max-width: calc(100vw - 32px)'));
    });

    test('margin of the bar wins over the theme\'s insetPadding', () async {
      final html = await _bar(
        const SnackBar(
          margin: EdgeInsets.only(bottom: 100),
          content: Text('S'),
        ),
        theme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          insetPadding: EdgeInsets.only(bottom: 72),
        ),
      );
      expect(html, contains('max(100px, env(safe-area-inset-bottom))'));
      expect(html, isNot(contains('max(72px')));
    });

    test('a fixed bar ignores width and insetPadding', () async {
      final html = await _bar(
        const SnackBar(content: Text('Saved')),
        theme: const SnackBarThemeData(
          width: 320,
          insetPadding: EdgeInsets.only(bottom: 72),
        ),
      );
      expect(html, isNot(contains('width: 320px')));
      expect(html, isNot(contains('72px')));
    });
  });

  group('the page\'s own snack bar (toast)', () {
    test('has the close button, and a place for the message', () async {
      final html = await _toastPage(
        theme: const SnackBarThemeData(showCloseIcon: true),
        cookie: 'thor-flash=info%3AHello',
      );
      expect(RegExp('id="thor-toast"').allMatches(html), hasLength(1));
      expect(_closeButton(html)![0], contains('aria-label="Close"'));
      expect(html, contains('data-snack-text'));
      expect(html, contains('Hello'));
    });

    test('has none by default', () async {
      final html = await _toastPage(cookie: 'thor-flash=info%3AHello');
      expect(_closeButton(html), isNull);
    });

    test('takes behavior and width from the theme', () async {
      final fixed = await _toastPage(
        theme: const SnackBarThemeData(behavior: SnackBarBehavior.fixed),
      );
      expect(fixed, contains('thor-snack-out-fixed'));
      final floating = await _toastPage(
        theme: const SnackBarThemeData(width: 400),
      );
      expect(floating, contains('width: 400px'));
      expect(floating, isNot(contains('thor-snack-out-fixed')));
    });
  });

  group('in node', () {
    final skip = Process.runSync('node', ['-v']).exitCode == 0
        ? null
        : 'node is not installed';

    Map<String, Object?> run(
      String html,
      String file,
      String script, {
      bool snack = false,
    }) {
      final js =
          '''
${File('test/support/mini_dom.js').readAsStringSync()}
const { parseHtml, body } = miniDom;
const proto = Object.getPrototypeOf(body);
Object.defineProperty(proto, 'dataset', { get() { return new Proxy({}, { get: (_, k) => this.getAttribute('data-' + String(k)) }); } });
Object.defineProperty(proto, 'className', {
  get() { return this.getAttribute('class') || ''; },
  set(v) { this.setAttribute('class', v); },
});
globalThis.MutationObserver = class { observe() {} };
globalThis.HTMLElement = function () {};
const handlers = {};
document.addEventListener = (t, f) => { handlers[t] = f; };
body.append(parseHtml(${jsonEncode(html)}));
${snack ? _snackStubs : _toastStubs}
const click = (el) => {
  const e = { target: el, type: 'click' };
  (handlers.click || (() => {}))(e);
  (listeners.click || (() => {}))(e);
};
const closeBtn = () => document.getElementById('thor-toast')?.querySelector('[data-snack-close]');
const out = {};
${File(file).readAsStringSync()}
$script
console.log(JSON.stringify(out));
''';
      final r = Process.runSync('node', ['-e', js], stdoutEncoding: utf8);
      if (r.exitCode != 0 || '${r.stderr}'.isNotEmpty) {
        fail('node failed:\n${r.stderr}');
      }
      return jsonDecode((r.stdout as String).trim()) as Map<String, Object?>;
    }

    test(
      'toast.js writes the message beside the button, and the button ends it',
      () async {
        final html = await _toastPage(
          theme: const SnackBarThemeData(showCloseIcon: true),
        );
        final out = run(html, '../thor_engine/lib/lite/toast.js', '''
document.thorToast('Saved', 'info', 4000);
out.shown = bar.hasAttribute('data-t-on');
out.button = !!closeBtn();
out.text = bar.querySelector('[data-snack-text]').textContent;
click(closeBtn());
out.after = bar.hasAttribute('data-t-on');
out.button2 = !!closeBtn();
document.thorToast('Next', 'info', 4000);
out.next = bar.querySelector('[data-snack-text]').textContent;
''');
        expect(out['shown'], isTrue);
        expect(out['button'], isTrue);
        expect(out['text'], 'Saved');
        expect(out['after'], isFalse);
        expect(out['button2'], isTrue);
        expect(out['next'], 'Next');
      },
      skip: skip,
    );

    test(
      'snack.js: the button hides a hand-made bar until its state shows it',
      () async {
        final html = await _bar(
          const SnackBar(showCloseIcon: true, content: Text('Saved')),
        );
        final out = run(html, '../thor_engine/lib/lite/snack.js', '''
out.before = [open(), el.hasAttribute('data-snack-closed')];
click(el.querySelector('[data-snack-close]'));
out.after = [open(), el.hasAttribute('data-snack-closed')];
el.setAttribute('data-snack', 'off');
mutate();
el.setAttribute('data-snack', 'on');
mutate();
out.again = [open(), el.hasAttribute('data-snack-closed')];
''', snack: true);
        expect(out['before'], [true, false]);
        expect(out['after'], [false, true]);
        expect(out['again'], [true, false]);
      },
      skip: skip,
    );

    test('toast.js still fills a bar with no close button', () async {
      final html = await _toastPage();
      final out = run(html, '../thor_engine/lib/lite/toast.js', '''
document.thorToast('Saved', 'info', 4000);
out.text = bar.textContent;
''');
      expect(out['text'], 'Saved');
    }, skip: skip);

    test('toast.js: closing shows the next one waiting', () async {
      final html = await _toastPage(
        theme: const SnackBarThemeData(showCloseIcon: true),
      );
      final out = run(html, '../thor_engine/lib/lite/toast.js', '''
document.thorToast('A', 'info', 4000);
document.thorToast('B', 'info', 4000);
click(closeBtn());
out.text = bar.querySelector('[data-snack-text]').textContent;
out.on = bar.hasAttribute('data-t-on');
''');
      expect(out['text'], 'B');
      expect(out['on'], isTrue);
    }, skip: skip);
  });
}

// What the toast's script needs of a bar that mini_dom does not have.
const _toastStubs = '''
const bar = document.getElementById('thor-toast');
bar.style = {};
bar.matches = () => false;
const listeners = {};
bar.addEventListener = (t, f) => { listeners[t] = f; };
''';

// The popover API and the selector of the hand-made bar, over mini_dom.
const _snackStubs = '''
const listeners = {};
const sel = '[data-snack]:not(#thor-toast)';
const plain = (e) => e.hasAttribute('data-snack') && e.id !== 'thor-toast';
const origMatches = proto.matches, origClosest = proto.closest, origAll = proto.querySelectorAll;
proto.matches = function (s) {
  if (s === ':popover-open') return !!this._open;
  return s === sel ? plain(this) : origMatches.call(this, s);
};
proto.closest = function (s) {
  if (s !== sel) return origClosest.call(this, s);
  for (let e = this; e; e = e.parentElement) if (plain(e)) return e;
  return null;
};
proto.querySelectorAll = function (s) {
  return s === sel ? origAll.call(this, '[data-snack]').filter(plain) : origAll.call(this, s);
};
HTMLElement.prototype.showPopover = proto.showPopover = function () { this._open = true; };
proto.hidePopover = function () { this._open = false; };
const el = document.querySelector('[data-snack]');
const open = () => !!el._open;
let observe;
globalThis.MutationObserver = class { constructor(f) { observe = f; } observe() {} };
const mutate = () => observe([{ type: 'attributes', target: el }]);
''';

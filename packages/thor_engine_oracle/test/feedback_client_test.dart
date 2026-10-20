@TestOn('browser')
library;

// On the dart2js engine, `confirm()` and `toast()` reach the page's inline
// scripts (`document.thorConfirm`, `document.thorToast`).
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';
import 'package:web/web.dart' as web;

void main() {
  late void Function()? undo;
  final doc = web.document as JSObject;

  setUp(
    () => undo = const FeedbackFeature().install(
      web.document.body!,
      (_, _, [_]) => null,
    ),
  );
  tearDown(() {
    undo?.call();
    doc.delete('thorConfirm'.toJS);
    doc.delete('thorToast'.toJS);
    doc.delete('thorToastHide'.toJS);
  });

  test(
    'confirm asks the page dialog with the spec and answers its promise',
    () async {
      final asked = <List<String?>>[];
      doc['thorConfirm'] = ((JSString t, JSAny? m, JSAny? o, JSAny? n) {
        asked.add([
          t.toDart,
          (m as JSString?)?.toDart,
          (o as JSString?)?.toDart,
          (n as JSString?)?.toDart,
        ]);
        return Future.value(true.toJS).toJS;
      }).toJS;
      expect(
        await confirm('Delete?', message: 'Sure', confirmLabel: 'Yes'),
        isTrue,
      );
      expect(asked.single, ['Delete?', 'Sure', 'Yes', null]);
    },
  );

  test('a page without a dialog says no, never yes', () async {
    expect(await confirm('Delete?'), isFalse);
  });

  test(
    'a dialog that answers no, or a promise that rejects, is a no',
    () async {
      doc['thorConfirm'] = ((JSString t) => Future.value(false.toJS).toJS).toJS;
      expect(await confirm('x'), isFalse);
      doc['thorConfirm'] = ((JSString t) => Future<JSBoolean>.error(
        'boom',
      ).toJS).toJS;
      expect(await confirm('x'), isFalse);
    },
  );

  test('toast hands the message, the kind and the milliseconds', () {
    final shown = <List<Object?>>[];
    doc['thorToast'] = ((JSString m, JSString k, JSAny? d) {
      shown.add([m.toDart, k.toDart, (d as JSNumber?)?.toDartInt]);
    }).toJS;
    toast(
      'Saved',
      kind: ToastKind.success,
      duration: const Duration(seconds: 2),
    );
    toast('Hi');
    expect(shown, [
      ['Saved', 'success', 2000],
      ['Hi', 'info', null],
    ]);
  });

  test('hideToast and clearToasts hand over whether to drop the waiting '
      'ones too', () {
    final asked = <bool>[];
    doc['thorToastHide'] = ((JSBoolean all) {
      asked.add(all.toDart);
    }).toJS;
    hideToast();
    clearToasts();
    expect(asked, [false, true]);
  });

  test('hiding without a bar does not throw', () {
    expect(hideToast, returnsNormally);
    expect(clearToasts, returnsNormally);
  });

  test('PageNavigator.go(flash:) leaves the cookie a server flash rides '
      'in', () {
    const name = 'thor-flash';
    void clear() => web.document.cookie = '$name=; Path=/; Max-Age=0';
    addTearDown(clear);
    PageNavigator.handler = (_, _) {};
    addTearDown(() => PageNavigator.handler = null);
    String? read() {
      for (final c in web.document.cookie.split(';')) {
        final t = c.trim();
        if (t.startsWith('$name=')) {
          return Uri.decodeComponent(t.substring(name.length + 1));
        }
      }
      return null;
    }

    PageNavigator.go('/x');
    expect(read(), isNull);
    PageNavigator.go('/x', flash: 'Saved: ✓', flashKind: ToastKind.success);
    expect(read(), 'success:Saved: ✓');
    PageNavigator.go('/x', flash: 'a' * 400);
    expect(read(), 'info:${'a' * 300}');
  });

  test('toast without a bar does not throw', () {
    expect(() => toast('x'), returnsNormally);
  });
}

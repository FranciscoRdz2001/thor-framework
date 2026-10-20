/// [confirm] and [toast] in the page ([FeedbackFeature]).
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:thor_engine/src/feedback.dart';
import 'package:thor_engine/src/navigation.dart' show PageNavigator;
import 'package:thor_engine_oracle/client.dart' show EngineFeature, EngineRun;
import 'package:web/web.dart' as web;

/// `confirm(…)`, `toast(…)`, `hideToast()` and `clearToasts()` from state
/// methods, through the page's own inline scripts (`document.thorConfirm`,
/// `document.thorToast`, `document.thorToastHide`): the
/// server writes the one dialog and the one snack bar, these only fill them.
/// With no dialog on the page a confirm says no (a page the server gave no
/// markup).
final class FeedbackFeature extends EngineFeature {
  /// The feature.
  const FeedbackFeature();

  @override
  void Function()? install(web.Element scope, EngineRun run) {
    Future<bool> ask(ConfirmSpec spec) async {
      final fn = (web.document as JSObject)['thorConfirm'];
      if (fn == null || fn.isUndefinedOrNull) {
        web.console.error(
          'thor: this page has no confirm dialog (THOR-S031)'.toJS,
        );
        return false;
      }
      final answer = (fn as JSFunction).callAsFunction(
        web.document,
        spec.title.toJS,
        spec.message?.toJS,
        spec.confirmLabel?.toJS,
        spec.cancelLabel?.toJS,
      );
      return (await (answer! as JSPromise<JSBoolean>).toDart).toDart;
    }

    void tell(String message, ToastKind kind, Duration? duration) {
      final fn = (web.document as JSObject)['thorToast'];
      if (fn == null || fn.isUndefinedOrNull) {
        web.console.error('thor: this page has no snack bar (THOR-S031)'.toJS);
        return;
      }
      (fn as JSFunction).callAsFunction(
        web.document,
        message.toJS,
        kind.name.toJS,
        duration?.inMilliseconds.toJS,
      );
    }

    void hide(bool all) {
      final fn = (web.document as JSObject)['thorToastHide'];
      // No bar, nothing to hide.
      if (fn == null || fn.isUndefinedOrNull) return;
      (fn as JSFunction).callAsFunction(web.document, all.toJS);
    }

    // `PageNavigator.go(flash:)`: the cookie a server flash rides in
    // (`kind:message`, 300 characters at most, two minutes), which the next
    // page that draws shows and clears.
    void flash(String message, ToastKind kind) {
      var text = message;
      if (text.length > 300) {
        // Never inside a surrogate pair.
        final end = text.codeUnitAt(299) & 0xFC00 == 0xD800 ? 299 : 300;
        text = text.substring(0, end);
      }
      final secure = web.window.location.protocol == 'https:' ? '; Secure' : '';
      web.document.cookie =
          'thor-flash=${Uri.encodeComponent('${kind.name}:$text')}'
          '; Path=/; Max-Age=120; SameSite=Lax$secure';
    }

    ThorFeedback.confirmHandler = ask;
    ThorFeedback.toastHandler = tell;
    ThorFeedback.toastHideHandler = hide;
    PageNavigator.flashHandler = flash;
    return () {
      if (identical(PageNavigator.flashHandler, flash)) {
        PageNavigator.flashHandler = null;
      }
      if (identical(ThorFeedback.confirmHandler, ask)) {
        ThorFeedback.confirmHandler = null;
      }
      if (identical(ThorFeedback.toastHandler, tell)) {
        ThorFeedback.toastHandler = null;
      }
      if (identical(ThorFeedback.toastHideHandler, hide)) {
        ThorFeedback.toastHideHandler = null;
      }
    };
  }
}

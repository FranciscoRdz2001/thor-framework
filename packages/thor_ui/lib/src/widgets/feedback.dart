import 'dart:convert';

import 'package:thor_engine/thor_engine.dart' show ConfirmSpec, ToastKind;
import 'package:thor_server/thor_server.dart'
    show FlashKind, FlashMessage, ServerMessages, askField, askQueryKey;
import 'package:thor_style/thor_style.dart' show MainAxisAlignment;

import '../core/core.dart';
import '../engine/feedback_script.dart';
import '../foundation/child_rules.dart';
import '../foundation/dialog_scope.dart' show PageSnackScope;
import '../foundation/parent_data.dart';
import '../foundation/style_registry.dart';
import '../foundation/theme_tokens.dart';
import 'buttons.dart';
import 'flex.dart';
import 'form.dart';
import 'material.dart' show AlertDialog, SnackBar, SnackBarBehavior;
import 'text.dart';
import 'theme.dart' show Theme;

/// The id of the page's one confirm dialog (`confirm(…)` of a state, and the
/// `confirm:` of a button).
const confirmDialogId = 'thor-confirm';

/// The id of the page's one snack bar (`toast(…)` of a state, and the
/// server's flash).
const toastId = 'thor-toast';

/// The id of the `<template>` that holds the snack bar's looks (its classes,
/// which the browser only swaps).
const toastLooksId = 'thor-toast-kinds';

/// The flash the request carries, for the page that draws: the renderer
/// (`WidgetRenderer`) reads it from the `thor-flash` cookie and clears it.
class FlashScope extends InheritedWidget {
  /// Publishes [flash] (or none) to [child].
  const FlashScope({super.key, required this.flash, required super.child});

  /// The message, or null.
  final FlashMessage? flash;

  /// The flash of the request above [context], or null.
  static FlashMessage? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FlashScope>()?.flash;

  @override
  bool updateShouldNotify(FlashScope oldWidget) => oldWidget.flash != flash;
}

/// The attributes of a button or a `Form` that make its submit ask first:
/// `data-t-confirm` (the question) and the rest of the [ConfirmSpec]. The
/// page's inline script asks in the shared dialog, and only when the
/// answer is yes the submit goes. Without JS the submit goes straight
/// (Rails' `data-confirm` and Phoenix's do the same).
Map<String, String> confirmAttributes(
  ThorStyleRegistry? registry,
  ConfirmSpec? spec,
) {
  if (spec == null) return const {};
  registry?.useConfirm();
  return {
    'data-t-confirm': spec.title,
    'data-t-cm': ?spec.message,
    'data-t-co': ?spec.confirmLabel,
    'data-t-cn': ?spec.cancelLabel,
  };
}

/// The question a control with `confirm:` carries in its POST, so the server
/// can ask it with a page when JavaScript is off (and the dialog never ran):
/// a JSON object (`t` the question, `m` the text under it, `o` and `n` the
/// labels), read by thor_server's `confirmationFor`.
String askValue(ConfirmSpec spec) => jsonEncode({
  't': spec.title,
  'm': ?spec.message,
  'o': ?spec.confirmLabel,
  'n': ?spec.cancelLabel,
});

/// [confirmAttributes] of a submit button, plus what makes the server ask
/// when the page's dialog doesn't: the question rides in the button's own
/// `name`/`value`, or, when that is taken (an action with an argument,
/// `name="thor-arg"`), in its `formaction` as a `/thor-ask` query key (which
/// starts with `/` like the action key, so it never reaches a rebuilt URL).
///
/// [submit] is what the button already has (`submitAttributes`). Without a
/// `confirm:` it is not touched.
Map<String, String> confirmSubmitAttributes(
  ThorStyleRegistry? registry,
  ConfirmSpec? spec,
  Map<String, String> submit, {
  bool submits = true,
}) {
  if (spec == null) return const {};
  // A button that submits nothing (`buttonType: ButtonType.button` with an engine method)
  // asks in the dialog or not at all.
  if (!submits) return confirmAttributes(registry, spec);
  final ask = askValue(spec);
  final action = submit['formaction'];
  return {
    ...confirmAttributes(registry, spec),
    // A button whose own name is taken carries the question in its URL: the
    // action's, or the document's own when the page's only action names none
    // (no path to post to).
    if (submit.containsKey('name'))
      'formaction': _withAsk(action ?? '', ask)
    else if (!submit.containsKey('name')) ...{
      'name': askField,
      'value': ask,
    },
  };
}

/// [url] with the question in its query, before a fragment.
String _withAsk(String url, String ask) {
  final hash = url.indexOf('#');
  final base = hash < 0 ? url : url.substring(0, hash);
  final fragment = hash < 0 ? '' : url.substring(hash);
  final join = base.contains('?') ? '&' : '?';
  return '$base$join$askQueryKey=${Uri.encodeQueryComponent(ask)}$fragment';
}

/// Sets attributes on the element of its child (the dialog's parts the
/// script fills, the snack bar's looks).
class _Attrs extends ParentDataWrapper {
  const _Attrs(this.attributes, {required super.child});

  final Map<String, String> attributes;

  @override
  WrapData get wrapData => WrapData(attributes: attributes);
}

/// What the page ships for `confirm`, `toast` and a flash, after the app
/// (so every flag is known): the dialog and the snack bar, each with the
/// inline script that drives it, only where the page uses them.
class SharedFeedback extends StatelessWidget implements ThorBuiltIn {
  /// The shared markup [registry] asks for, in [messages]' words, with
  /// [flash] showing in the snack bar.
  const SharedFeedback(this.registry, this.messages, this.flash, {super.key});

  /// What the page asked for.
  final ThorStyleRegistry registry;

  /// The dialog's default button labels (the app's language).
  final ServerMessages messages;

  /// The message the request carried, shown on this page.
  final FlashMessage? flash;

  @override
  Widget build(BuildContext context) => Widget.fragment([
    if (registry.usesSnack)
      const Widget.element(tag: 'script', children: [RawText(snackScript)]),
    if (registry.usesConfirm) ...[
      _ConfirmDialog(messages),
      const Widget.element(tag: 'script', children: [RawText(confirmScript)]),
    ],
    if (registry.usesToast || flash != null) ...[
      _ToastBar(flash),
      const _ToastLooks(),
      if (registry.usesToast)
        const Widget.element(tag: 'script', children: [RawText(toastScript)]),
    ],
  ]);
}

/// The one dialog: the question and the two answers, filled by the script
/// (`data-t-c`), closed by a `<form method=dialog>` whose pressed button
/// sets the dialog's `returnValue`. The focus starts on Cancel: the answer
/// that does nothing.
class _ConfirmDialog extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  const _ConfirmDialog(this.messages);

  final ServerMessages messages;

  @override
  Widget build(BuildContext context) => AlertDialog(
    id: confirmDialogId,
    // Esc answers no; a click outside does not: the second click of a
    // double click on the button that asked would close the question.
    barrierDismissible: false,
    title: const _Attrs({'data-t-c': 't'}, child: Text('')),
    content: const _Attrs({'data-t-c': 'm', 'hidden': ''}, child: Text('')),
    actions: [
      Form(
        formMethod: FormMethod.dialog,
        disableOnSubmit: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: 8,
          children: [
            _Attrs(
              const {'value': 'cancel', 'data-t-c': 'n', 'autofocus': ''},
              child: TextButton(
                buttonType: ButtonType.submit,
                onPressed: () {},
                child: Text(messages.cancel),
              ),
            ),
            _Attrs(
              const {'value': 'ok', 'data-t-c': 'o'},
              child: FilledButton(
                buttonType: ButtonType.submit,
                onPressed: () {},
                child: Text(messages.ok),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// The look of a snack bar of [kind]: the theme's inverse surface, an
/// error's own colors, a success's accent edge.
Widget _look(ToastKind kind, Widget bar) => switch (kind) {
  ToastKind.info => bar,
  ToastKind.success => WrapWith(
    const WrapData(
      css: {'border-inline-start': '4px solid ${ThemeTokens.primary}'},
    ),
    child: bar,
  ),
  ToastKind.error => WrapWith(
    const WrapData(
      css: {
        'background-color': ThemeTokens.error,
        'color': ThemeTokens.onError,
      },
    ),
    child: bar,
  ),
};

// The page's bar floats unless the theme says otherwise.
SnackBarBehavior _behavior(BuildContext context) =>
    Theme.of(context).snackBarTheme?.behavior ?? SnackBarBehavior.floating;

/// The one snack bar: hidden, or showing the server's flash (with no JS the
/// CSS animation hides it after its duration).
class _ToastBar extends StatelessWidget implements ThorBuiltIn {
  const _ToastBar(this.flash);

  final FlashMessage? flash;

  @override
  Widget build(BuildContext context) {
    final f = flash;
    // Exhaustive: a new FlashKind is a compile error here, not a render crash.
    final kind = switch (f?.kind) {
      null || FlashKind.info => ToastKind.info,
      FlashKind.success => ToastKind.success,
      FlashKind.error => ToastKind.error,
    };
    // web: a `popover="manual"`, so the script can put it in the top layer
    // over a modal <dialog> (Flutter's snack bar shows over routes); with
    // no JS it is never opened and stays the plain fixed bar it was.
    // The theme's `snackBarTheme` is the ScaffoldMessenger's default here
    // (behavior, width, inset, close icon); with none the bar floats.
    return _Attrs(
      {'id': toastId, 'popover': 'manual', if (f != null) 'data-t-on': ''},
      child: PageSnackScope(
        child: _look(
          kind,
          SnackBar(
            visible: f != null,
            behavior: _behavior(context),
            content: Text(f?.message ?? ''),
          ),
        ),
      ),
    );
  }
}

/// The looks the script swaps in: `off` and one showing per kind, as inert
/// markup (a `<template>`), so their classes come from the server.
class _ToastLooks extends StatelessWidget implements ThorBuiltIn {
  const _ToastLooks();

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'template',
    id: toastLooksId,
    children: [
      _Attrs(
        const {'data-k': 'off'},
        child: PageSnackScope(
          child: SnackBar(
            visible: false,
            behavior: _behavior(context),
            content: const Text(''),
          ),
        ),
      ),
      for (final kind in ToastKind.values)
        _Attrs(
          {'data-k': kind.name},
          child: PageSnackScope(
            child: _look(
              kind,
              SnackBar(behavior: _behavior(context), content: const Text('')),
            ),
          ),
        ),
    ],
  );
}

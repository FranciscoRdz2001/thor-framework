import 'package:thor_engine/thor_engine.dart';

import '../engine/watch.dart' show elementEventAttributes;
import '../foundation/parent_data.dart';

/// The page id of [controller] when a `ThorState` field holds it, else
/// null (a controller outside a state only exists on the server).
String? controllerIdOf(ThorController? controller) =>
    controller == null ? null : ThorState.controllerId(controller)?.$2;

/// Flutter's `CallbackShortcuts`: key presses inside [child] (while the
/// focus is in it) call methods of a `ThorState`.
///
/// ```dart
/// CallbackShortcuts(
///   bindings: {
///     const SingleActivator(LogicalKeyboardKey.arrowDown): grid.down,
///     const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): grid.undo,
///     const SingleActivator(LogicalKeyboardKey.enter): grid.edit.withArg(0),
///   },
///   child: Focus(child: table),
/// )
/// ```
///
/// Like in Flutter, the innermost matching shortcut wins and stops the
/// key, and a text field keeps the keys it edits with (letters, arrows,
/// Backspace); Enter, Escape and Tab still reach the shortcuts around it.
/// The element needs the focus: wrap it (or a descendant) in [Focus].
///
/// **Over a text field:** a binding with `overrideTextInput: true` also
/// answers when the focus is in a text field and the key is one it edits
/// with, and the caret does not move (a palette's arrows moving a highlight
/// while typing). Without it the keys stay in the field.
///
/// ```dart
/// CallbackShortcuts(
///   bindings: {
///     const SingleActivator(LogicalKeyboardKey.arrowDown, overrideTextInput: true): menu.next,
///   },
///   child: TextField(controller: menu.query),
/// )
/// ```
///
/// Activators: `SingleActivator` (a key and its modifiers) and
/// `CharacterActivator` (the character typed, whatever keys make it).
///
/// **Any character:** [onCharacter] gets every printable character that
/// no binding of this element took (one character, no Control or Meta):
/// a grid starts editing the selected cell with the key the user typed,
/// like a spreadsheet.
///
/// ```dart
/// CallbackShortcuts(
///   bindings: {const SingleActivator(LogicalKeyboardKey.enter): grid.edit},
///   onCharacter: grid.typeInto,   // void typeInto(String character)
///   child: Focus(child: table),
/// )
/// ```
///
/// **Nothing focused:** a key pressed while the focus is on the page
/// itself (`<body>`, as right after it loads) goes to the outermost
/// `CallbackShortcuts` on view, like Flutter's root focus scope: a ⌘K
/// declared in a layout works before anything was clicked.
///
/// `// web:` decorates [child]'s element instead of adding a
/// node; a callback that is not a `ThorState` method does nothing. Flutter
/// has no activator for "any character" (there it is `Focus.onKeyEvent`
/// reading `KeyEvent.character`, a closure the page can't run):
/// [onCharacter] is that case as a state method.
class CallbackShortcuts extends ParentDataWrapper {
  /// Calls `bindings[activator]` when its keys are pressed inside `child`.
  const CallbackShortcuts({
    super.key,
    required this.bindings,
    this.onCharacter,
    required super.child,
  });

  /// Each activator and the method it calls (a tear-off, or `withArg`).
  final Map<ShortcutActivator, void Function()> bindings;

  /// A printable character typed inside [child] that no binding took: the
  /// method gets it (a tear-off, or `withArg` for a two-parameter method).
  ///
  /// `// web:` no Flutter counterpart (see the class docs).
  final void Function(String character)? onCharacter;

  @override
  WrapData get wrapData {
    final specs = <String, String>{};
    void add(String spec, Function callback) {
      if (_bindingOf(callback, withArg: true) case final id?) {
        specs[spec] = id;
      }
    }

    for (final e in bindings.entries) {
      add(e.key.spec, e.value);
    }
    // Last: the element's own bindings win over "any character".
    if (onCharacter case final c?) add(anyCharacterSpec, c);
    return WrapData(
      attributes: specs.isEmpty
          ? const {}
          : {shortcutsAttr: encodeShortcuts(specs)},
    );
  }
}

/// The page id of [callback] when it is a `ThorState` method (with its
/// `withArg` argument if [withArg]), else null: a closure only exists on
/// the server.
String? _bindingOf(Function callback, {bool withArg = false}) {
  final bound = BoundCall.of(callback);
  if (bound != null && !withArg) {
    throw ArgumentError.value(
      callback,
      'callback',
      'a `withArg` method can not be bound here: the browser gives this '
          'method its own argument (write one method per value, or one '
          'intent class per value)',
    );
  }
  final found = ThorState.resolve(bound?.function ?? callback);
  if (found == null) return null;
  return bindingId(
    '${found.$1.idPrefix}.${found.$2.name}',
    bound == null
        ? null
        : encodeFixedArg(bound.arg, splits: found.$2.arity >= 2),
  );
}

/// Flutter's `Shortcuts`: key presses inside [child] (while the focus is in
/// it) become [Intent]s, and the nearest [Actions] around the focus that has
/// an action for the intent's type runs it.
///
/// ```dart
/// class SaveIntent extends Intent {
///   const SaveIntent();
/// }
///
/// Shortcuts(
///   shortcuts: const {
///     SingleActivator(LogicalKeyboardKey.keyS, meta: true): SaveIntent(),
///   },
///   child: Actions(
///     actions: {SaveIntent: CallbackAction<SaveIntent>(onInvoke: editor.save)},
///     child: Focus(child: form),
///   ),
/// )
/// // void save(SaveIntent intent) { … }   (in EditorViewModel)
/// ```
///
/// Like in Flutter, the `Shortcuts` nearest the focus that has a matching
/// activator decides the intent; with no action for it the key goes on to
/// the outer shortcuts. The keys a text field edits with stay in it, and
/// with nothing focused the outermost shortcuts on view answer, as with
/// [CallbackShortcuts].
///
/// `// web:` decorates [child]'s element instead of adding a node (with a
/// [CallbackShortcuts] or a `Focus(onKeyEvent:)` on the same element,
/// `onKeyEvent` goes first, then these, then the callbacks). Intents are
/// known by their class name.
class Shortcuts extends ParentDataWrapper {
  /// Maps the activators to intents inside `child`.
  const Shortcuts({
    super.key,
    required this.shortcuts,
    this.debugLabel,
    required super.child,
  });

  /// Each activator and the intent it means.
  final Map<ShortcutActivator, Intent> shortcuts;

  /// A name for debugging.
  final String? debugLabel;

  @override
  WrapData get wrapData => WrapData(
    attributes: shortcuts.isEmpty
        ? const {}
        : {
            intentShortcutsAttr: encodeShortcuts({
              for (final e in shortcuts.entries)
                e.key.spec: intentName(e.value),
            }),
          },
  );
}

/// Flutter's `Action`: what an intent does. In the page, a
/// [CallbackAction] (a method of a `ThorState`) or a [DoNothingAction].
///
/// `// web:` an `Action` subclass of the app (its own `invoke`) runs only on
/// the server; [Actions] says so when it renders.
abstract class Action<T extends Intent> {
  /// An action.
  const Action();

  /// Whether a key that invokes it stops there (Flutter's `consumesKey`).
  bool consumesKey(T intent) => true;
}

/// Flutter's `CallbackAction`: [onInvoke] runs when its intent is invoked.
///
/// [onInvoke] is a method of a `ThorState` that takes the intent
/// (`void save(SaveIntent intent)`), like the closure Flutter would take.
/// `// web:` the method gets the intent made again with its constructor
/// without arguments; a callback that is not a `ThorState` method does
/// nothing (the key goes on to outer actions).
class CallbackAction<T extends Intent> extends Action<T> {
  /// Runs [onInvoke] for the intent.
  const CallbackAction({required this.onInvoke});

  /// The state method the intent runs.
  final Object? Function(T intent) onInvoke;

  // Read here, where its type is exact (from an `Actions` map, typed
  // `CallbackAction<Intent>`, the read would fail its type check).
  Function get _callback => onInvoke;
}

/// Flutter's `DoNothingAction`: the intent does nothing; with [consumesKey]
/// (the default) the key stops there, which turns off an outer shortcut
/// inside a subtree.
class DoNothingAction extends Action<Intent> {
  /// Does nothing, and stops the key unless [consumesKey] is false.
  const DoNothingAction({bool consumesKey = true}) : _consumesKey = consumesKey;

  final bool _consumesKey;

  @override
  bool consumesKey(Intent intent) => _consumesKey;
}

/// Flutter's `Actions`: what each intent type does for the shortcuts of
/// the focus inside [child] (see [Shortcuts]).
///
/// ```dart
/// Actions(
///   actions: {
///     SaveIntent: CallbackAction<SaveIntent>(onInvoke: editor.save),
///     DeleteIntent: CallbackAction<DeleteIntent>(onInvoke: editor.delete),
///   },
///   child: …,
/// )
/// ```
///
/// Like in Flutter, the nearest `Actions` around the focus with an action
/// for the intent's type wins.
///
/// `// web:` decorates [child]'s element instead of adding a node.
/// `Actions.invoke(context, intent)` from code is a closure the page can't
/// run: a button calls the state method itself (`onPressed: editor.save…`).
class Actions extends ParentDataWrapper {
  /// The actions for the intents of `child`.
  const Actions({super.key, required this.actions, required super.child});

  /// Each intent type and its action.
  final Map<Type, Action<Intent>> actions;

  @override
  WrapData get wrapData {
    final ids = <String, String>{};
    for (final MapEntry(key: type, value: action) in actions.entries) {
      final String? id = switch (action) {
        DoNothingAction() => action._consumesKey ? '' : ignoreKeyAction,
        CallbackAction() => _bindingOf(action._callback),
        _ => throw ArgumentError.value(
          action,
          'actions[$type]',
          'only CallbackAction (a ThorState method) and DoNothingAction run '
              'in the page',
        ),
      };
      if (id != null) ids[intentName(type)] = id;
    }
    return WrapData(
      attributes: ids.isEmpty ? const {} : {actionsAttr: encodeActions(ids)},
    );
  }
}

/// Flutter's `FocusOnKeyEventCallback`: a key event for a [Focus] and what
/// it did with it.
typedef FocusOnKeyEventCallback =
    KeyEventResult Function(FocusNode node, KeyEvent event);

/// Flutter's `Focus`: makes [child]'s element able to take the keyboard
/// focus (`tabindex`), optionally owned by a [focusNode] of a `ThorState`
/// that moves the focus from a method (`node.requestFocus()`).
///
/// `// web:` [skipTraversal] keeps it out of the Tab order (`tabindex=-1`,
/// still focusable by a click or `requestFocus`); [autofocus] is the
/// native attribute (honored on the first load).
///
/// [onKeyEvent] is a method of a `ThorState` with Flutter's signature that
/// gets each key pressed inside (the focus on the element or a descendant)
/// and says what it did: `handled` stops the key (`preventDefault`, no outer
/// handler sees it), `ignored` lets it go on to the outer `Focus`es and
/// shortcuts, `skipRemainingHandlers` gives it to the browser.
///
/// ```dart
/// Focus(onKeyEvent: grid.onKey, child: table)
/// // KeyEventResult onKey(FocusNode node, KeyEvent event) {
/// //   if (event is! KeyDownEvent) return KeyEventResult.ignored;
/// //   if (event.logicalKey == LogicalKeyboardKey.enter) { … }
/// //   return KeyEventResult.ignored;
/// // }
/// ```
///
/// `// web:` only key downs arrive (and their repeats), and the keys a text
/// field edits with stay in it, as with [CallbackShortcuts]; the event has
/// `logicalKey` and `character`, the modifiers are
/// `HardwareKeyboard.instance`'s; `node` is not the page's (to move the
/// focus, use a [FocusNode] field of the state). A callback that is not a
/// `ThorState` method does nothing.
///
/// [onFocusChange] is a method of a `ThorState` that gets `true` when the
/// focus enters the element or any of its descendants and `false` when it
/// leaves them all: moving between two fields inside is no change. `// web:`
/// the window losing focus (or the devtools taking it) is a `false`, and
/// coming back a `true`, like the browser's `focusout`/`focusin`; the first
/// focus of a page is what loads the engine, so it reports as soon as the
/// engine is ready. Lite engine only.
class Focus extends ParentDataWrapper {
  /// Wraps `child` as a focus target.
  const Focus({
    super.key,
    this.focusNode,
    this.autofocus = false,
    this.canRequestFocus = true,
    this.skipTraversal = false,
    this.onFocusChange,
    this.onKeyEvent,
    required super.child,
  });

  /// Gets each key pressed inside and returns what it did with it.
  final FocusOnKeyEventCallback? onKeyEvent;

  /// Called with whether the element or a descendant has the focus, each
  /// time that changes.
  final void Function(bool hasFocus)? onFocusChange;

  /// The node of a `ThorState` that controls this target.
  final FocusNode? focusNode;

  /// Whether it takes the focus when the page loads.
  final bool autofocus;

  /// Whether it can take the focus at all.
  final bool canRequestFocus;

  /// Whether Tab skips it.
  final bool skipTraversal;

  @override
  WrapData get wrapData => WrapData(
    attributes: {
      if (canRequestFocus) 'tabindex': skipTraversal ? '-1' : '0',
      if (autofocus && canRequestFocus) 'autofocus': '',
      focusNodeAttr: ?controllerIdOf(focusNode),
      ...elementEventAttributes({'focus': onFocusChange}),
      if (onKeyEvent case final f?) keyEventAttr: ?_bindingOf(f),
    },
  );
}

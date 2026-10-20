/// Keyboard shortcuts with Flutter's names: [LogicalKeyboardKey],
/// [SingleActivator] and [HardwareKeyboard]. Pure data: thor_ui's
/// `CallbackShortcuts` writes them into the page and the engine's
/// `ShortcutsFeature` matches them against `keydown` events.
library;

import 'dart:convert';

/// Flutter's `LogicalKeyboardKey`: a key by what it means, not where it
/// is. `// web:` identified by the DOM's `KeyboardEvent.key` value
/// ([keyLabel]), so it follows the user's layout like Flutter's logical
/// keys do.
final class LogicalKeyboardKey {
  /// A key whose `KeyboardEvent.key` is [keyLabel].
  const LogicalKeyboardKey(this.keyLabel);

  /// The `KeyboardEvent.key` value (`ArrowDown`, `Enter`, `z`).
  final String keyLabel;

  /// ↑
  static const arrowUp = LogicalKeyboardKey('ArrowUp');

  /// ↓
  static const arrowDown = LogicalKeyboardKey('ArrowDown');

  /// ←
  static const arrowLeft = LogicalKeyboardKey('ArrowLeft');

  /// →
  static const arrowRight = LogicalKeyboardKey('ArrowRight');

  /// Enter / Return.
  static const enter = LogicalKeyboardKey('Enter');

  /// Escape.
  static const escape = LogicalKeyboardKey('Escape');

  /// Tab.
  static const tab = LogicalKeyboardKey('Tab');

  /// The space bar.
  static const space = LogicalKeyboardKey(' ');

  /// Backspace.
  static const backspace = LogicalKeyboardKey('Backspace');

  /// Delete (forward).
  static const delete = LogicalKeyboardKey('Delete');

  /// Home.
  static const home = LogicalKeyboardKey('Home');

  /// End.
  static const end = LogicalKeyboardKey('End');

  /// Page Up.
  static const pageUp = LogicalKeyboardKey('PageUp');

  /// Page Down.
  static const pageDown = LogicalKeyboardKey('PageDown');

  /// F2.
  static const f2 = LogicalKeyboardKey('F2');

  // web: a letter is its lower-case `KeyboardEvent.key` (Shift+K is `K`,
  // matched in any case); a digit or a sign is the character it types
  // unshifted on a US layout, so Shift+1 (`!`) is not digit1: use a
  // CharacterActivator for a shifted sign.
  /// A.
  static const keyA = LogicalKeyboardKey('a');

  /// B.
  static const keyB = LogicalKeyboardKey('b');

  /// C.
  static const keyC = LogicalKeyboardKey('c');

  /// D.
  static const keyD = LogicalKeyboardKey('d');

  /// E.
  static const keyE = LogicalKeyboardKey('e');

  /// F.
  static const keyF = LogicalKeyboardKey('f');

  /// G.
  static const keyG = LogicalKeyboardKey('g');

  /// H.
  static const keyH = LogicalKeyboardKey('h');

  /// I.
  static const keyI = LogicalKeyboardKey('i');

  /// J.
  static const keyJ = LogicalKeyboardKey('j');

  /// K.
  static const keyK = LogicalKeyboardKey('k');

  /// L.
  static const keyL = LogicalKeyboardKey('l');

  /// M.
  static const keyM = LogicalKeyboardKey('m');

  /// N.
  static const keyN = LogicalKeyboardKey('n');

  /// O.
  static const keyO = LogicalKeyboardKey('o');

  /// P.
  static const keyP = LogicalKeyboardKey('p');

  /// Q.
  static const keyQ = LogicalKeyboardKey('q');

  /// R.
  static const keyR = LogicalKeyboardKey('r');

  /// S.
  static const keyS = LogicalKeyboardKey('s');

  /// T.
  static const keyT = LogicalKeyboardKey('t');

  /// U.
  static const keyU = LogicalKeyboardKey('u');

  /// V.
  static const keyV = LogicalKeyboardKey('v');

  /// W.
  static const keyW = LogicalKeyboardKey('w');

  /// X.
  static const keyX = LogicalKeyboardKey('x');

  /// Y.
  static const keyY = LogicalKeyboardKey('y');

  /// Z.
  static const keyZ = LogicalKeyboardKey('z');

  /// 0.
  static const digit0 = LogicalKeyboardKey('0');

  /// 1.
  static const digit1 = LogicalKeyboardKey('1');

  /// 2.
  static const digit2 = LogicalKeyboardKey('2');

  /// 3.
  static const digit3 = LogicalKeyboardKey('3');

  /// 4.
  static const digit4 = LogicalKeyboardKey('4');

  /// 5.
  static const digit5 = LogicalKeyboardKey('5');

  /// 6.
  static const digit6 = LogicalKeyboardKey('6');

  /// 7.
  static const digit7 = LogicalKeyboardKey('7');

  /// 8.
  static const digit8 = LogicalKeyboardKey('8');

  /// 9.
  static const digit9 = LogicalKeyboardKey('9');

  /// `/`.
  static const slash = LogicalKeyboardKey('/');

  /// `.`.
  static const period = LogicalKeyboardKey('.');

  /// `,`.
  static const comma = LogicalKeyboardKey(',');

  /// `-`.
  static const minus = LogicalKeyboardKey('-');

  /// `=`.
  static const equal = LogicalKeyboardKey('=');

  /// `+`.
  static const add = LogicalKeyboardKey('+');

  @override
  bool operator ==(Object other) =>
      other is LogicalKeyboardKey &&
      other.keyLabel.toLowerCase() == keyLabel.toLowerCase();

  @override
  int get hashCode => keyLabel.toLowerCase().hashCode;

  @override
  String toString() => 'LogicalKeyboardKey($keyLabel)';
}

/// Flutter's `ShortcutActivator`: what a key press must be to trigger a
/// shortcut.
abstract interface class ShortcutActivator {
  /// The activator as the page's `data-tks` spec
  /// (`<modifiers>+<key>`, see [shortcutSpec]).
  String get spec;
}

/// Flutter's `SingleActivator`: [trigger] pressed with exactly these
/// modifiers.
///
/// `// web:` letters match in any case (Shift+Z is `Z` in the DOM);
/// [includeRepeats] false ignores auto-repeated `keydown`s. Like Flutter's,
/// it has no `==` of its own, so a `const` map can use it as a key.
final class SingleActivator implements ShortcutActivator {
  /// [trigger] with the given modifiers held.
  const SingleActivator(
    this.trigger, {
    this.control = false,
    this.shift = false,
    this.alt = false,
    this.meta = false,
    this.includeRepeats = true,
    this.skipWithTextSelection = false,
    this.overrideTextInput = false,
  });

  /// The key that triggers the shortcut.
  final LogicalKeyboardKey trigger;

  /// Whether Control must be held.
  final bool control;

  /// Whether Shift must be held.
  final bool shift;

  /// Whether Alt (Option) must be held.
  final bool alt;

  /// Whether Meta (Command, Windows) must be held.
  final bool meta;

  /// Whether a held key's repeated presses trigger it again.
  final bool includeRepeats;

  /// Whether the shortcut stays out of it while the page has selected text,
  /// so the browser's own key (Cmd+C copying the selection) works.
  ///
  /// `// web:` Flutter has no such flag: its text selection lives in the
  /// widgets. The browser has one selection for the whole page, and a
  /// shortcut like Cmd+C that copies a widget must not steal it.
  final bool skipWithTextSelection;

  /// Whether the shortcut also answers while a text field has the focus and
  /// the key is one the field edits with (arrows, Home, End, PageUp,
  /// PageDown, Backspace, Delete, letters), the key's default (the caret
  /// moving) being cancelled.
  ///
  /// `// web:` Flutter has no such flag: a focused `EditableText` handles
  /// those keys in its own `Actions`, below any `Shortcuts` above it. The
  /// browser's field is native, so by default the keys stay with it; this
  /// is the explicit opt-in for a palette whose up and down arrows move a
  /// highlight while the caret stays in the search field. Only
  /// `CallbackShortcuts` and `Shortcuts` honor it (never `Focus.onKeyEvent`
  /// or `onCharacter`).
  final bool overrideTextInput;

  @override
  String get spec => shortcutSpec(
    trigger.keyLabel,
    control: control,
    shift: shift,
    alt: alt,
    meta: meta,
    repeats: includeRepeats,
    skipWithTextSelection: skipWithTextSelection,
    overrideTextInput: overrideTextInput,
  );
}

/// Flutter's `CharacterActivator`: the key press that types [character]
/// (whatever keys the layout needs for it: `?` is Shift+/ on a US
/// keyboard), with exactly these modifiers. Shift is not checked (it is
/// part of the character).
///
/// ```dart
/// CallbackShortcuts(bindings: {const CharacterActivator('?'): help.show}, …)
/// ```
///
/// `// web:` matches the DOM's `KeyboardEvent.key`, case-sensitive.
final class CharacterActivator implements ShortcutActivator {
  /// The press that types [character] with the given modifiers held.
  const CharacterActivator(
    this.character, {
    this.alt = false,
    this.control = false,
    this.meta = false,
    this.includeRepeats = true,
    this.skipWithTextSelection = false,
    this.overrideTextInput = false,
  });

  /// The character typed (`?`, `a`, `A`).
  final String character;

  /// Whether Alt (Option) must be held.
  final bool alt;

  /// Whether Control must be held.
  final bool control;

  /// Whether Meta (Command, Windows) must be held.
  final bool meta;

  /// Whether a held key's repeated presses trigger it again.
  final bool includeRepeats;

  /// Whether the shortcut stays out of it while the page has selected text
  /// (see [SingleActivator.skipWithTextSelection]).
  final bool skipWithTextSelection;

  /// Whether the shortcut also answers while a text field has the focus
  /// (see [SingleActivator.overrideTextInput]).
  final bool overrideTextInput;

  @override
  String get spec =>
      '${control ? 'c' : ''}${alt ? 'a' : ''}${meta ? 'm' : ''}'
      '${includeRepeats ? '' : 'n'}${skipWithTextSelection ? 't' : ''}'
      '${overrideTextInput ? 'o' : ''}=${character.codeUnits.join('.')}';
}

/// The page form of `CallbackShortcuts(onCharacter:)`: any printable
/// character (one character, no Control or Meta) that no binding of the
/// same element took.
const anyCharacterSpec = '*';

/// Whether a `keydown`'s [key] types one printable character with no
/// command modifier ([anyCharacterSpec]): what spreadsheet-like grids start
/// editing with. Control+Alt (AltGr on Windows) still types.
bool isPrintableKey(
  String key, {
  required bool control,
  required bool alt,
  required bool meta,
}) {
  if (key.isEmpty || key.runes.length != 1) return false;
  final c = key.codeUnitAt(0);
  if (c < 0x20 || c == 0x7f) return false;
  return !meta && (!control || alt);
}

/// The page form of a shortcut: modifier letters (`c` control, `s` shift,
/// `a` alt, `m` meta, `n` no repeats, `t` not while the page has selected
/// text, `o` also while a text field has the focus), `+`, then the key in lowercase
/// (`cs+z`, `+arrowdown`, `+ ` for the space bar).
String shortcutSpec(
  String key, {
  bool control = false,
  bool shift = false,
  bool alt = false,
  bool meta = false,
  bool repeats = true,
  bool skipWithTextSelection = false,
  bool overrideTextInput = false,
}) =>
    '${control ? 'c' : ''}${shift ? 's' : ''}${alt ? 'a' : ''}'
    '${meta ? 'm' : ''}${repeats ? '' : 'n'}'
    '${skipWithTextSelection ? 't' : ''}${overrideTextInput ? 'o' : ''}+${key.toLowerCase()}';

final _letterOrDigitCode = RegExp(r'^(?:Key|Digit)(.)$');

/// The letter or digit of a `keydown`'s physical key ([code] `KeyS` → `s`,
/// `Digit1` → `1`) when its [key] is not ASCII, else null.
///
/// web: a non-Latin layout (Cyrillic, Greek) types `ы` on KeyS; like
/// Flutter web, a letter or digit shortcut then answers to the physical
/// key. An ASCII [key] keeps its own name, so a Latin layout (Dvorak's `o`
/// on KeyS) is never remapped.
String? physicalKeyName(String key, String code) {
  if (key.isEmpty || key.codeUnitAt(0) <= 0x7f) return null;
  return _letterOrDigitCode.firstMatch(code)?.group(1)!.toLowerCase();
}

/// Whether a `keydown` (its `key`, `code`, modifiers and `repeat`) matches
/// [spec] ([textSelected]: the page has selected text, which a spec with
/// `t` leaves to the browser). A `SingleActivator` falls back to the physical key ([code]) when [key]
/// is not ASCII.
bool shortcutMatches(
  String spec,
  String key, {
  required bool control,
  required bool shift,
  required bool alt,
  required bool meta,
  bool repeat = false,
  String code = '',
  bool textSelected = false,
}) {
  final at = spec.indexOf('+');
  if (at < 0) {
    // A CharacterActivator: `<mods>=<code units>`; Shift is ignored.
    final eq = spec.indexOf('=');
    if (eq < 0) return false;
    final mods = spec.substring(0, eq);
    if (spec.substring(eq + 1) != key.codeUnits.join('.')) return false;
    if (repeat && mods.contains('n')) return false;
    if (textSelected && mods.contains('t')) return false;
    return mods.contains('c') == control &&
        mods.contains('a') == alt &&
        mods.contains('m') == meta;
  }
  final mods = spec.substring(0, at);
  final name = spec.substring(at + 1);
  if (name != key.toLowerCase() && name != physicalKeyName(key, code)) {
    return false;
  }
  if (repeat && mods.contains('n')) return false;
  if (textSelected && mods.contains('t')) return false;
  return mods.contains('c') == control &&
      mods.contains('s') == shift &&
      mods.contains('a') == alt &&
      mods.contains('m') == meta;
}

/// Encodes `{spec: bindingId}` for the page (`data-tks`). Specs and ids
/// never contain `;` or `>` (keys are named, ids are member names).
String encodeShortcuts(Map<String, String> bindings) =>
    [for (final e in bindings.entries) '${e.key}>${e.value}'].join(';');

/// Parses [encodeShortcuts]'s output, in order.
List<(String, String)> decodeShortcuts(String value) => [
  for (final part in value.split(';'))
    if (part.lastIndexOf('>') case final at when at > 0)
      (part.substring(0, at), part.substring(at + 1)),
];

/// Flutter's `HardwareKeyboard`: which modifiers are held right now, for
/// a state method that reacts to a click differently with Shift
/// (`HardwareKeyboard.instance.isShiftPressed`).
///
/// The engine keeps it current from the page's keyboard and pointer
/// events (`ShortcutsFeature`); on the server nothing is pressed.
final class HardwareKeyboard {
  HardwareKeyboard._();

  /// The keyboard.
  static final instance = HardwareKeyboard._();

  bool _shift = false, _control = false, _alt = false, _meta = false;

  /// Whether Shift is held.
  bool get isShiftPressed => _shift;

  /// Whether Control is held.
  bool get isControlPressed => _control;

  /// Whether Alt (Option) is held.
  bool get isAltPressed => _alt;

  /// Whether Meta (Command, Windows) is held.
  bool get isMetaPressed => _meta;

  /// Engine only: the modifiers of the latest keyboard or pointer event.
  void syncModifiers({
    required bool shift,
    required bool control,
    required bool alt,
    required bool meta,
  }) {
    _shift = shift;
    _control = control;
    _alt = alt;
    _meta = meta;
  }
}

/// Flutter's `Intent`: what a key press means (`SaveIntent`), apart from
/// what it does (an action of an `Actions` widget, found by the intent's
/// type).
///
/// ```dart
/// class SaveIntent extends Intent {
///   const SaveIntent();
/// }
/// ```
///
/// `// web:` the page knows an intent by its class name: the method of a
/// `CallbackAction` gets the intent made again with its constructor without
/// arguments (fields do not travel: one class per meaning).
abstract class Intent {
  /// An intent.
  const Intent();
}

/// Flutter's `KeyEventResult`: what `Focus.onKeyEvent` did with a key.
enum KeyEventResult {
  /// Used: the key stops here (`preventDefault`, no outer handler sees it).
  handled,

  /// Not used: the outer handlers (and then the browser) get it.
  ignored,

  /// Not used, and no outer handler gets it: the browser does.
  skipRemainingHandlers,
}

/// Flutter's `KeyEvent`: a key press, as `Focus.onKeyEvent` gets it.
///
/// `// web:` the subset the page has: [logicalKey] (the DOM's
/// `KeyboardEvent.key`; a letter or digit of a non-Latin layout falls back
/// to its physical key, like `SingleActivator`) and [character]. The
/// modifiers are `HardwareKeyboard.instance`'s, as in Flutter. Only key
/// downs arrive ([KeyDownEvent], [KeyRepeatEvent] while held): no
/// [KeyUpEvent], no `physicalKey` or `timeStamp`.
sealed class KeyEvent {
  const KeyEvent({required this.logicalKey, this.character});

  /// The key, by what it means.
  final LogicalKeyboardKey logicalKey;

  /// The character the key types (`a`, `A`, `?`), or null (Enter, an arrow).
  final String? character;

  /// The event as the page sends it ([encodeKeyEvent]'s JSON).
  static KeyEvent decode(String value) {
    final [kind, key, char] = jsonDecode(value) as List<Object?>;
    final logical = LogicalKeyboardKey(key! as String);
    final character = char as String?;
    return kind == 1
        ? KeyRepeatEvent(logicalKey: logical, character: character)
        : KeyDownEvent(logicalKey: logical, character: character);
  }

  @override
  String toString() =>
      '$runtimeType(${logicalKey.keyLabel}, character: $character)';
}

/// A key pressed.
final class KeyDownEvent extends KeyEvent {
  /// A key pressed.
  const KeyDownEvent({required super.logicalKey, super.character});
}

/// A held key, pressed again by the keyboard's auto-repeat.
final class KeyRepeatEvent extends KeyEvent {
  /// A held key's repeat.
  const KeyRepeatEvent({required super.logicalKey, super.character});
}

/// A key released. `// web:` never sent to `Focus.onKeyEvent`; it is here
/// so code from Flutter that tests `event is KeyUpEvent` compiles.
final class KeyUpEvent extends KeyEvent {
  /// A key released.
  const KeyUpEvent({required super.logicalKey, super.character});
}

/// The `keyLabel` of a `keydown`'s logical key: one character in lowercase
/// (Shift+A is `a`, like the [LogicalKeyboardKey] constants), a named key as
/// the DOM names it (`Enter`), and a non-Latin letter or digit as its
/// physical key ([physicalKeyName]).
String logicalKeyLabel(String key, String code) {
  if (physicalKeyName(key, code) case final p?) return p;
  return key.runes.length == 1 ? key.toLowerCase() : key;
}

/// The character a `keydown`'s [key] types: one printable character, else
/// null.
String? keyCharacter(String key) {
  if (key.runes.length != 1) return null;
  final c = key.codeUnitAt(0);
  return c < 0x20 || c == 0x7f ? null : key;
}

/// A `keydown` as `Focus.onKeyEvent`'s argument in the page:
/// `[repeat ? 1 : 0, keyLabel, character]` as JSON ([KeyEvent.decode]).
String encodeKeyEvent(String key, String code, {bool repeat = false}) =>
    jsonEncode([repeat ? 1 : 0, logicalKeyLabel(key, code), keyCharacter(key)]);

/// An intent's name in the page (`data-tsi`, `data-tai`): its class name,
/// with anything but letters, digits, `_` and `$` as `_` (a generic
/// `Move<int>` is `Move_int_`).
String intentName(Object typeOrIntent) =>
    '${typeOrIntent is Type ? typeOrIntent : typeOrIntent.runtimeType}'
        .replaceAll(RegExp(r'[^\w$]'), '_');

/// Encodes `{intent name: binding id}` for an `Actions` (`data-tai`): an
/// empty id is `DoNothingAction` (the key stops, nothing runs) and
/// [ignoreKeyAction] is its `consumesKey: false`.
String encodeActions(Map<String, String> actions) =>
    [for (final e in actions.entries) '${e.key}>${e.value}'].join(';');

/// The id of `DoNothingAction(consumesKey: false)` in [encodeActions].
const ignoreKeyAction = '!';

/// The action [actions] (a `data-tai` value) has for [intent], or null.
String? actionFor(String actions, String intent) {
  for (final part in actions.split(';')) {
    final at = part.indexOf('>');
    if (at > 0 && part.substring(0, at) == intent) {
      return part.substring(at + 1);
    }
  }
  return null;
}

/// A message for the next page that draws (`Redirect(...).flash('Saved')`).
///
/// Rails' `flash`, Phoenix's `put_flash` and Remix's `session.flash` keep it
/// in the session for one request; a thor server has no session of its own,
/// so it rides a short-lived cookie: the action's redirect sets it, the next
/// page that draws shows it and clears it.
library;

/// The cookie a flash rides (`kind:message`, percent-encoded on the wire).
const flashCookie = 'thor-flash';

/// The cookie the form script leaves at every post: a mark of the tab that
/// posted (cookies are shared by tabs, `sessionStorage` is not). Not exported.
const scrollTabCookie = 'thor-tab';

/// The cookie `Redirect(resetScroll: true)` sets: the mark of [scrollTabCookie]
/// echoed back, for the form script of that tab to read (not `HttpOnly`) and
/// remove. Not exported.
const scrollResetCookie = 'thor-scroll';

/// How long the cookie lives: long enough for a redirect or two (a guard
/// sending the visitor through a sign-in first), short enough that a
/// message never turns up days later.
const flashLifetime = Duration(minutes: 2);

/// The longest message kept (a cookie has room for about 4 KB, and a
/// message is a sentence).
const flashMaxLength = 300;

/// What a flash is about: how the page draws it.
enum FlashKind {
  /// A plain note (the default).
  info,

  /// Something worked.
  success,

  /// Something failed.
  error,
}

/// A flash: its [kind] and its [message] (text: the page escapes it).
///
/// It is not signed: the cookie is the visitor's to write, and the worst a
/// forged one does is put a sentence of their own choosing on their own
/// screen. The page draws it as text, never as markup.
final class FlashMessage {
  /// A flash with [message], cut to [flashMaxLength].
  FlashMessage(String message, [this.kind = FlashKind.info])
    : message = _clip(message);

  /// The kind of message.
  final FlashKind kind;

  /// The text to show.
  final String message;

  /// The cookie value: `kind:message`.
  String get cookieValue => '${kind.name}:$message';

  /// The flash a cookie value holds, or null when there is none: empty,
  /// blank or absent. An unknown kind is [FlashKind.info]; the message is
  /// cut to [flashMaxLength] whatever the cookie says.
  static FlashMessage? parse(String? value) {
    if (value == null) return null;
    final colon = value.indexOf(':');
    final name = colon < 0 ? '' : value.substring(0, colon);
    final kind = FlashKind.values.where((k) => k.name == name).firstOrNull;
    // `kind:message`; without a colon the whole value is the message.
    final text = _clip(colon < 0 ? value : value.substring(colon + 1));
    if (text.trim().isEmpty) return null;
    return FlashMessage(text, kind ?? FlashKind.info);
  }

  // Never inside a surrogate pair: half an emoji is a broken character.
  static String _clip(String s) {
    if (s.length <= flashMaxLength) return s;
    final end = s.codeUnitAt(flashMaxLength - 1) & 0xFC00 == 0xD800
        ? flashMaxLength - 1
        : flashMaxLength;
    return s.substring(0, end);
  }
}

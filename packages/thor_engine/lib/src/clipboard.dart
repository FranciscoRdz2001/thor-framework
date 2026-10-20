/// Flutter's `Clipboard` and `ClipboardData`, for `ThorState` methods:
/// copy a selection as text, read what the user pastes. On the server they
/// do nothing; in the browser the engine's `ClipboardFeature` connects them
/// to the page.
library;

/// Flutter's `ClipboardData`: the text on the clipboard.
final class ClipboardData {
  /// Clipboard contents holding [text].
  const ClipboardData({required String this.text});

  /// The plain text.
  final String? text;
}

/// What the engine does for [Clipboard].
abstract interface class ClipboardDriver {
  /// Puts [text] on the clipboard.
  Future<void> write(String text);

  /// The clipboard's text (null if the page can't read it).
  Future<String?> read();

  /// Whether a `write` or `read` waits for the browser's own `copy`/`cut`
  /// or `paste` event (the key press that called it must not be stopped).
  bool get waitsForEvent;
}

/// Flutter's `Clipboard`, from a state method:
///
/// ```dart
/// void copy() => Clipboard.setData(ClipboardData(text: selectionAsTsv()));
///
/// Future<void> paste() async {
///   final data = await Clipboard.getData(Clipboard.kTextPlain);
///   if (data?.text case final text?) fill(text);
/// }
/// ```
///
/// `// web:` the browser only lets a page read the clipboard during a
/// paste, and write it freely during a copy. Called from a shortcut of
/// the page's own ⌘C/⌘X/⌘V (Ctrl on other systems), the engine lets the
/// key through and answers in the `copy`/`cut`/`paste` event that follows:
/// no permission prompt. Called from anything else (a button), it falls
/// back to `navigator.clipboard`, which may ask the user (reading) or fail;
/// then [getData] gives null. On the server both do nothing.
abstract final class Clipboard {
  /// The plain-text format.
  static const kTextPlain = 'text/plain';

  /// Engine only: the page's clipboard.
  static ClipboardDriver? driver;

  /// Puts [data]'s text on the clipboard.
  static Future<void> setData(ClipboardData data) =>
      driver?.write(data.text ?? '') ?? Future<void>.value();

  /// The clipboard's contents as [format] (only [kTextPlain]), or null.
  static Future<ClipboardData?> getData(String format) async {
    if (format != kTextPlain) return null;
    final text = await driver?.read();
    return text == null ? null : ClipboardData(text: text);
  }
}

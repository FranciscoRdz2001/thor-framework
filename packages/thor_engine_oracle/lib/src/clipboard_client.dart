/// [Clipboard] in the page ([ClipboardFeature]).
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:thor_engine/src/clipboard.dart';
import 'package:thor_engine_oracle/client.dart' show EngineFeature, EngineRun;
import 'package:web/web.dart' as web;

/// `Clipboard.setData` / `Clipboard.getData` from state methods.
///
/// A call waits for the browser's `copy`/`cut` (write) or `paste` (read)
/// event of the same key press, which carries the data with no permission
/// prompt. If none comes in that task (the call came from a click), it
/// falls back to the asynchronous `navigator.clipboard`.
final class ClipboardFeature extends EngineFeature {
  /// The feature.
  const ClipboardFeature();

  @override
  void Function()? install(web.Element scope, EngineRun run) {
    final driver = _PageClipboard();
    Clipboard.driver = driver;
    final onCopy = driver._copy.toJS;
    final onPaste = driver._paste.toJS;
    // The document: the event's target is whatever has the focus (or body).
    web.document
      ..addEventListener('copy', onCopy, true.toJS)
      ..addEventListener('cut', onCopy, true.toJS)
      ..addEventListener('paste', onPaste, true.toJS);
    return () {
      web.document
        ..removeEventListener('copy', onCopy, true.toJS)
        ..removeEventListener('cut', onCopy, true.toJS)
        ..removeEventListener('paste', onPaste, true.toJS);
      if (identical(Clipboard.driver, driver)) Clipboard.driver = null;
    };
  }
}

class _PageClipboard implements ClipboardDriver {
  String? _text;
  Completer<void>? _written;
  Completer<String?>? _read;

  @override
  bool get waitsForEvent => _written != null || _read != null;

  @override
  Future<void> write(String text) {
    _text = text;
    final done = _written ??= Completer<void>();
    _later(() {
      final pending = _text;
      if (pending == null || !identical(_written, done)) return;
      _text = null;
      _written = null;
      web.window.navigator.clipboard
          .writeText(pending)
          .toDart
          .then((_) => done.complete(), onError: (Object _) => done.complete());
    });
    return done.future;
  }

  @override
  Future<String?> read() {
    final done = _read ??= Completer<String?>();
    _later(() {
      if (!identical(_read, done)) return;
      _read = null;
      web.window.navigator.clipboard.readText().toDart.then(
        (t) => done.complete(t.toDart),
        onError: (Object _) => done.complete(null),
      );
    });
    return done.future;
  }

  void _copy(web.ClipboardEvent e) {
    final text = _text, done = _written;
    final data = e.clipboardData;
    if (text == null || done == null || data == null) return;
    data.setData(Clipboard.kTextPlain, text);
    e.preventDefault();
    _text = null;
    _written = null;
    done.complete();
  }

  void _paste(web.ClipboardEvent e) {
    final done = _read;
    final data = e.clipboardData;
    if (done == null || data == null) return;
    e.preventDefault();
    _read = null;
    done.complete(data.getData(Clipboard.kTextPlain));
  }
}

/// After the current task (the key press's own clipboard event runs
/// before any timer).
void _later(void Function() fn) => web.window.setTimeout(fn.toJS, 0.toJS);

/// Controllers as fields of a `ThorState`, with Flutter's names:
/// [ScrollController], [TextEditingController], [FocusNode] and
/// [DialogController] (plus [SystemNavigator] for the address bar). The widgets that use one
/// (`SingleChildScrollView(controller:)`, `TextField(controller:,
/// focusNode:)`, `Focus(focusNode:)`) write its id into the page; the
/// engine's `ControllersFeature` connects it to that element. State
/// methods read and drive them like in Flutter; on the server they are
/// plain values.
library;

import 'dart:async';

import 'easing.dart';
import 'reactive.dart';

/// A field type a `ThorState` exposes by id (the generator lists it as a
/// controller member): [ScrollController], [TextEditingController],
/// [FocusNode], and `AnimationController`.
abstract interface class ThorController {}

/// What the engine does for a [ScrollController].
abstract interface class ScrollDriver {
  /// Whether an element of the page is this controller's scroll view now.
  bool get hasView;

  /// Scrolls the controller's element to [offset] (px).
  void jumpTo(double offset);

  /// Scrolls the controller's element to [offset] (px) over [duration]
  /// along the CSS [easing] (null: linear); completes when it stops
  /// (arrived, or the visitor or another call moved it).
  Future<void> animateTo(double offset, Duration duration, String? easing);
}

/// Flutter's `ScrollPosition`, reduced to what a page reads.
final class ScrollPosition {
  ScrollPosition._(this._c);

  final ScrollController _c;

  /// The scroll offset (px), tracked.
  double get pixels => _c._pixels.value;

  /// The visible extent along the axis (px), tracked; 0 until the page
  /// measured it.
  double get viewportDimension => _c._viewport.value;

  /// The largest [pixels] (px), tracked.
  double get maxScrollExtent => _c._max.value;
}

/// Flutter's `ScrollController`, as a field of a `ThorState`:
///
/// ```dart
/// final scroll = ScrollController();
/// int firstRow() => (scroll.offset / rowHeight).floor();
/// void toTop() => scroll.jumpTo(0);
/// ```
///
/// The browser scrolls natively; the engine writes the element's offset
/// here on every `scroll` event (a signal: methods reading [offset] are
/// recomputed) and [jumpTo] moves the element.
class ScrollController implements ThorController {
  /// A controller starting at [initialScrollOffset].
  ScrollController({double initialScrollOffset = 0})
    : _pixels = Signal(initialScrollOffset),
      _start = initialScrollOffset > 0 ? initialScrollOffset : null;

  final Signal<double> _pixels;
  final Signal<double> _viewport = Signal(0);
  final Signal<double> _max = Signal(0);
  ScrollDriver? _driver;
  // Where the view starts, until the engine has taken it to the view.
  double? _start;

  /// The scroll offset (px), tracked.
  double get offset => _pixels.value;

  /// The position (offset, viewport and extent).
  late final ScrollPosition position = ScrollPosition._(this);

  /// Whether a scroll view on the page uses it right now (Flutter's
  /// `ScrollController.hasClients`): not tracked, and false on the server
  /// and while its view is not in the page (a variant that swaps it out).
  bool get hasClients => _driver?.hasView ?? false;

  /// Moves to [value] at once.
  void jumpTo(double value) {
    _pixels.value = value;
    _driver?.jumpTo(value);
  }

  /// Scrolls to [value] over [duration] along [curve] and completes when it
  /// stops (Flutter's `animateTo`).
  ///
  /// [curve] is any `Curve` (the engine doesn't depend on `thor_style`: it
  /// uses its CSS easing). An offset past the ends stops at them.
  ///
  /// `// web:` with `prefers-reduced-motion` it jumps; a visitor's own
  /// scroll (wheel, touch, key, drag), another `animateTo` or a `jumpTo`
  /// interrupts it, and the future then completes.
  Future<void> animateTo(
    double value, {
    required Duration duration,
    required Object curve,
  }) {
    final easing = cssEasingOf(curve);
    final driver = _driver;
    if (driver == null) {
      _pixels.value = value < 0 ? 0 : value;
      return Future.value();
    }
    return driver.animateTo(value, duration, easing);
  }

  /// Engine only: attaches the page's [driver].
  void attachDriver(ScrollDriver? driver) => _driver = driver;

  /// Engine only: where the view should start (px), once: the
  /// `initialScrollOffset`, or an offset asked for before the view was
  /// there. [viewportDimension] is the measured size of the view.
  double? takeStart(double viewportDimension) {
    // A view with no size yet (hidden) keeps the offset for later.
    if (viewportDimension == 0) return null;
    final start = _start;
    _start = null;
    return start;
  }

  /// Engine only: the element scrolled (or was measured).
  void updatePosition({
    required double pixels,
    required double viewportDimension,
    required double maxScrollExtent,
  }) => batch(() {
    _pixels.value = pixels;
    _viewport.value = viewportDimension;
    _max.value = maxScrollExtent;
  });
}

/// Flutter's `PageController`, as a field of a `ThorState`: the page a
/// `PageView(controller:)` shows, and the way to move it.
///
/// ```dart
/// final pages = PageController(initialPage: 1);   // PageView(controller: pages, …)
/// int current() => pages.page!.round();
/// void next() => pages.animateToPage(current() + 1,
///     duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
/// ```
///
/// A [ScrollController] over the view's scroll (`scroll-snap`): [page] is
/// the offset in viewports, [jumpToPage] and [animateToPage] move the
/// offset `page * viewportDimension` with the browser's own scroll. In a
/// right-to-left view, or a `reverse` one, offsets (and so pages) still
/// count from the first page.
///
/// `// web:` there is no `viewportFraction` (every page fills the view) nor
/// `keepPage` (the view is not rebuilt).
/// `initialPage` shows once the engine loads (the server can't know the
/// size of the view).
class PageController extends ScrollController {
  /// A controller starting at [initialPage].
  PageController({
    this.initialPage = 0,
    // Accepted so a Flutter call site compiles; the view is never rebuilt.
    // ignore: avoid_unused_constructor_parameters
    bool keepPage = true,
    double viewportFraction = 1.0,
  }) : _wanted = initialPage != 0 ? initialPage : null {
    if (viewportFraction != 1.0) {
      throw ArgumentError.value(
        viewportFraction,
        'viewportFraction',
        'a PageView page fills the view (the browser scrolls it with '
            '`scroll-snap`); use a smaller child inside each page instead',
      );
    }
  }

  /// The page it starts at.
  final int initialPage;

  // A page asked for while the view was not there or not measured.
  int? _wanted;

  /// The current page, tracked: the offset in viewports (fractional while it
  /// scrolls). Before the view is measured, the page asked for (or
  /// [initialPage]).
  double? get page {
    final viewport = position.viewportDimension;
    return viewport == 0
        ? (_wanted ?? initialPage).toDouble()
        : offset / viewport;
  }

  /// Moves to [page] at once.
  void jumpToPage(int page) {
    final viewport = position.viewportDimension;
    if (!hasClients || viewport == 0) {
      _wanted = page;
      return;
    }
    _wanted = null;
    jumpTo(page * viewport);
  }

  /// Scrolls to [page] over [duration] along [curve] and completes when it
  /// stops (see [ScrollController.animateTo]).
  Future<void> animateToPage(
    int page, {
    required Duration duration,
    required Object curve,
  }) {
    final viewport = position.viewportDimension;
    if (!hasClients || viewport == 0) {
      _wanted = page;
      return Future.value();
    }
    _wanted = null;
    return animateTo(page * viewport, duration: duration, curve: curve);
  }

  @override
  double? takeStart(double viewportDimension) {
    // A view with no size yet (hidden) keeps the page for later.
    if (viewportDimension == 0) return null;
    final page = _wanted;
    _wanted = null;
    final start = super.takeStart(viewportDimension);
    return page == null ? start : page * viewportDimension;
  }
}

/// What the engine does for a [TextEditingController].
abstract interface class TextDriver {
  /// Puts the controller's selection in the fields that use it, and reads
  /// back what each one really has ([TextEditingController.updateSelection]).
  void select();
}

/// Flutter's `TextEditingController`, as a field of a `ThorState`: the
/// text of the fields that use it (`TextField(controller: form.name)`).
/// Typing updates [text]; setting [text] in a method updates the fields.
final class TextEditingController implements ThorController {
  /// A controller holding [text].
  TextEditingController({String? text}) : _text = Signal(text ?? '');

  final Signal<String> _text;
  final Signal<TextSelection> _selection = Signal(
    const TextSelection.collapsed(offset: -1),
  );
  TextDriver? _driver;

  /// The current text, tracked.
  String get text => _text.value;

  /// `// web:` changing the text puts the caret at its end (what the
  /// browser does), where Flutter leaves the selection invalid; the text it
  /// already has moves nothing.
  set text(String value) {
    if (value == _text.peek()) return;
    batch(() {
      _text.value = value;
      _selection.value = TextSelection.collapsed(offset: value.length);
    });
  }

  /// The caret or the selected range, tracked. Invalid (`-1`) until the
  /// visitor or a method puts the caret somewhere.
  TextSelection get selection => _selection.value;

  /// Moves the caret or the selection of the fields that use this
  /// controller. Offsets past the ends of the text stop at them
  /// (`setSelectionRange` clamps too); an invalid one stays invalid.
  ///
  /// `// web:` it doesn't focus the field, and a field whose `type` has no
  /// selection (`email`, `number`) keeps only the value.
  set selection(TextSelection value) {
    if (!value.isValid) {
      _selection.value = const TextSelection.collapsed(offset: -1);
      return;
    }
    int fit(int o) => o < 0 ? 0 : (o > text.length ? text.length : o);
    final next = TextSelection(
      baseOffset: fit(value.baseOffset),
      extentOffset: fit(value.extentOffset),
    );
    // The same selection is not a change for whoever reads it (Flutter's
    // ValueNotifier ignores an equal value); the fields still hear it (they
    // may normalise the text, CRLF, and the read-back says what they have).
    if (next != _selection.peek()) _selection.value = next;
    // After this method's other changes (the text it is for may be set in
    // the same method).
    final driver = _driver;
    if (driver != null) scheduleMicrotask(driver.select);
  }

  /// Engine only: attaches the page's [driver].
  void attachDriver(TextDriver? driver) => _driver = driver;

  /// Engine only: the visitor moved the caret (or typed): what the field
  /// has.
  void updateSelection(TextSelection value) {
    if (value != _selection.peek()) _selection.value = value;
  }

  /// Engine only: the selection without tracking it.
  TextSelection get selectionNow => _selection.peek();

  /// The text and the selection together, tracked (Flutter's `value`).
  TextEditingValue get value =>
      TextEditingValue(text: text, selection: selection);

  /// Sets the text and the selection in one change: the fields show the
  /// text and put their caret where [value] says (kept inside the text).
  ///
  /// `// web:` a new text with no valid selection puts the caret at its end
  /// (what the browser does with a value it is given), where Flutter leaves
  /// it invalid; the same text with none keeps it invalid, like
  /// [selection].
  set value(TextEditingValue value) => batch(() {
    final changed = value.text != _text.peek();
    text = value.text;
    if (value.selection.isValid || !changed) selection = value.selection;
  });

  /// Empties the text.
  void clear() => text = '';
}

/// Flutter's `TextEditingValue`: the text of a field and where its caret is
/// (what `TextEditingController.value` holds, and what an
/// `AutocompleteOptionsBuilder` is asked about).
class TextEditingValue {
  /// A value with [text] and [selection] (a caret nowhere by default).
  const TextEditingValue({
    this.text = '',
    this.selection = const TextSelection.collapsed(offset: -1),
  });

  /// The empty text, no selection.
  static const empty = TextEditingValue();

  /// The text.
  final String text;

  /// The caret or the selected range.
  final TextSelection selection;

  /// A copy with [text] and [selection] replaced where given.
  TextEditingValue copyWith({String? text, TextSelection? selection}) =>
      TextEditingValue(
        text: text ?? this.text,
        selection: selection ?? this.selection,
      );

  @override
  bool operator ==(Object other) =>
      other is TextEditingValue &&
      other.text == text &&
      other.selection == selection;

  @override
  int get hashCode => Object.hash(text, selection);

  @override
  String toString() => 'TextEditingValue(text: "$text", selection: $selection)';
}

/// Flutter's `TextSelection`, reduced to offsets: where a field's caret or
/// selected range is ([baseOffset] is where it started, [extentOffset]
/// where it ends; a collapsed one is a caret).
final class TextSelection {
  /// A range from [baseOffset] to [extentOffset].
  const TextSelection({required this.baseOffset, required this.extentOffset});

  /// A caret at [offset].
  const TextSelection.collapsed({required int offset})
    : baseOffset = offset,
      extentOffset = offset;

  /// Where the selection started.
  final int baseOffset;

  /// Where the selection ends (the moving end).
  final int extentOffset;

  /// The lower offset.
  int get start => baseOffset < extentOffset ? baseOffset : extentOffset;

  /// The higher offset.
  int get end => baseOffset < extentOffset ? extentOffset : baseOffset;

  /// Whether it is a caret.
  bool get isCollapsed => baseOffset == extentOffset;

  /// Whether both ends are in the text (not `-1`).
  bool get isValid => baseOffset >= 0 && extentOffset >= 0;

  @override
  bool operator ==(Object other) =>
      other is TextSelection &&
      other.baseOffset == baseOffset &&
      other.extentOffset == extentOffset;

  @override
  int get hashCode => Object.hash(baseOffset, extentOffset);

  @override
  String toString() => 'TextSelection($baseOffset, $extentOffset)';
}

/// What the engine does for a [FocusNode].
abstract interface class FocusDriver {
  /// Focuses the node's element (and scrolls it into view).
  void requestFocus();

  /// Blurs the node's element if it has the focus.
  void unfocus();
}

/// Flutter's `FocusNode`, as a field of a `ThorState`: moves the keyboard
/// focus from a method (`editorFocus.requestFocus()` after opening an
/// editor). The widget that owns it is `Focus(focusNode:)` or
/// `TextField(focusNode:)`.
///
/// `// web:` the request runs after the current batch of updates (the
/// element may appear in the same method), and it also scrolls the
/// element into view (`nearest`), even when it already had the focus.
final class FocusNode implements ThorController {
  /// A focus node.
  FocusNode();

  final Signal<bool> _hasFocus = Signal(false);
  final List<void Function()> _listeners = [];
  FocusDriver? _driver;
  bool _disposed = false;

  /// Whether its element has the keyboard focus, tracked.
  bool get hasFocus => _hasFocus.value;

  /// Calls [listener] each time the focus moves in or out ([hasFocus] is
  /// already the new value), like Flutter's `ChangeNotifier`. Take it off
  /// with [removeListener] in `dispose()`.
  ///
  /// A listener added twice is called twice; one removed (by another
  /// listener too) is not called again, one added during a dispatch waits
  /// for the next. Throws a [StateError] after [dispose] (Flutter asserts).
  ///
  /// `// web:` only [hasFocus] changes are reported (Flutter's node also
  /// notifies for `hasPrimaryFocus` and `canRequestFocus`, which the page
  /// does not have).
  void addListener(void Function() listener) {
    if (_disposed) {
      throw StateError('A FocusNode was used after being disposed.');
    }
    _listeners.add(listener);
  }

  /// Stops calling [listener] (one registration of it, if added twice).
  void removeListener(void Function() listener) => _listeners.remove(listener);

  /// Forgets the listeners; [addListener] throws from now on.
  void dispose() {
    _disposed = true;
    _listeners.clear();
  }

  /// Gives its element the keyboard focus.
  void requestFocus() {
    final driver = _driver;
    if (driver != null) scheduleMicrotask(driver.requestFocus);
  }

  /// Takes the focus away from its element.
  void unfocus() => _driver?.unfocus();

  /// Engine only: attaches the page's [driver].
  void attachDriver(FocusDriver? driver) => _driver = driver;

  /// Engine only: the element gained or lost the focus.
  void updateFocus(bool focused) {
    if (_hasFocus.peek() == focused) return;
    _hasFocus.value = focused;
    // Every listener hears it: one that throws is reported and does not cut
    // the others short.
    for (final l in List.of(_listeners)) {
      // One an earlier listener removed is not called (Flutter's).
      if (!_listeners.contains(l)) continue;
      try {
        l();
      } catch (e, st) {
        print('FocusNode: a listener threw: $e\n$st');
      }
    }
  }
}

/// What the engine does for a [DialogController].
abstract interface class DialogDriver {
  /// Opens the controller's `<dialog>` as a modal (`showModal`).
  void open();

  /// Closes it.
  void close();
}

/// Opens and closes a native dialog (`Drawer`, `AlertDialog`,
/// `ModalBottomSheet`) from a state method, as a field of a `ThorState`:
///
/// ```dart
/// final details = DialogController();       // Drawer(controller: details, …)
/// void expand(int id) {
///   current.value = id;                     // the drawer shows this record
///   details.open();
/// }
/// bool detailsOpen() => details.isOpen;     // Watch(…): follows Esc too
/// ```
///
/// The dialog stays native: focus trap, Esc, the backdrop and the focus
/// going back where it was on close. [isOpen] follows every way it opens
/// or closes (a `DialogTrigger`, Esc, a click on the backdrop).
///
/// `// web:` Flutter opens dialogs with `showDialog` and drawers with
/// `Scaffold.of(context).openEndDrawer()`, both from a `BuildContext` the
/// page doesn't have in the browser; the controller mirrors
/// `MenuController` (`open`, `close`, `isOpen`). [open] runs after the
/// current batch of updates, like `FocusNode.requestFocus` (the dialog's
/// content changes in the same method).
final class DialogController implements ThorController {
  /// A controller for a closed dialog.
  DialogController();

  final Signal<bool> _open = Signal(false);
  DialogDriver? _driver;

  /// Whether its dialog is open, tracked.
  bool get isOpen => _open.value;

  /// Opens its dialog (modal).
  void open() {
    _open.value = true;
    final driver = _driver;
    if (driver != null) scheduleMicrotask(driver.open);
  }

  /// Closes its dialog.
  void close() {
    _open.value = false;
    _driver?.close();
  }

  /// Engine only: attaches the page's [driver].
  void attachDriver(DialogDriver? driver) => _driver = driver;

  /// Engine only: the dialog opened or closed.
  void updateOpen(bool open) => _open.value = open;
}

/// Flutter's `SystemNavigator`, for the address bar:
/// `SystemNavigator.routeInformationUpdated(uri: …, replace: true)` from a
/// state method keeps the URL in step with the page's state (a filter in
/// the query), so a reload renders the same view. No-op on the server.
abstract final class SystemNavigator {
  /// Engine only: writes the address (`history.pushState`/`replaceState`).
  static void Function(Uri uri, bool replace)? handler;

  /// Shows [uri] (or [location]) in the address bar without navigating; a
  /// new history entry unless [replace].
  static void routeInformationUpdated({
    String? location,
    Uri? uri,
    Object? state,
    bool replace = false,
  }) {
    final target = uri ?? (location == null ? null : Uri.parse(location));
    if (target != null) handler?.call(target, replace);
  }
}

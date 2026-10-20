part of 'style_registry.dart';

// Internal (hidden from `thor_ui.dart`): the per-process memo of what each
// element's class is made of.

/// Whether the render-time caches are on: the element style memo, the memos
/// of widget CSS and `Cached` fragments. Off, every element computes its
/// styles and every `Cached` builds its child: the reference output the
/// differential tests compare against (`package:thor_ui/testing.dart`).
bool renderCachesEnabled = true;

/// The declarations and conditions of one element's class, resolved from
/// its inputs (its own CSS, what the parent grants, the wrappers' data).
///
/// Shared by every element with the same inputs, in every render of the
/// process: [css] and [conditions] are never modified.
final class ElementStyle {
  /// [css] under [conditions] in [layer].
  ///
  /// An element with descendant rules (`Styled(descendants:)`) gets two
  /// classes: the rules that land on other elements (its descendant rules,
  /// its `' > *'` and `' .figure'` rules) go in [inside], so the variants of
  /// its own values (a `flex` its parent sets) share them instead of
  /// repeating them. The two classes never style the same element,
  /// so the order grouped rules give them changes nothing.
  factory ElementStyle(
    CssDeclarations css,
    List<ConditionalCss> conditions,
    ThorLayer layer,
  ) {
    if (!conditions.any((c) => c.when.isDescendant)) {
      return ElementStyle._(css, conditions, conditions, layer, null);
    }
    final own = [
      for (final c in conditions)
        if (!c.when._targetsOthers) c,
    ];
    final others = [
      for (final c in conditions)
        if (c.when._targetsOthers) c,
    ];
    return ElementStyle._(
      css,
      conditions,
      own,
      layer,
      ElementStyle._(const {}, others, others, layer, null),
    );
  }

  ElementStyle._(
    this.css,
    this.conditions,
    this._classConditions,
    this.layer,
    this.inside,
  ) : _key = css.isEmpty && _classConditions.isEmpty
          ? null
          : _StyleKey(layer, css, _classConditions);

  /// The class's own declarations.
  final CssDeclarations css;

  /// Its breakpoint, state and scheme rules, with those of [inside].
  final List<ConditionalCss> conditions;

  // The rules of the class itself: [conditions] without [inside]'s.
  final List<ConditionalCss> _classConditions;

  /// The second class of an element with descendant rules: the rules on
  /// the elements inside it (null for any other element).
  final ElementStyle? inside;

  /// Its cascade layer.
  final ThorLayer layer;

  final _StyleKey? _key;

  // The registry's shared entry for this style (name, rule text, string
  // key), found once: the shared cache only grows, so it stays valid.
  (String, String, String)? _shared;

  /// Whether there is nothing to put in a class.
  bool get isEmpty => _key == null;

  /// The variables of bound values (`BoundLength`) the class reads, by
  /// name: found once per style, so an element only checks a list.
  late final List<String> boundLengths = boundLengthsIn(css, conditions);

  /// The `--tr-` variables (a row's `RowLength`) the class reads.
  late final List<String> rowLengths = rowLengthsIn(css, conditions);
}

/// The class for [style] in [registry] (null when it has no declarations):
/// what `registry.classFor(style.css, …)` returns, without hashing or
/// comparing the declarations again once the style is known.
String? classForElementStyle(ThorStyleRegistry registry, ElementStyle style) {
  final key = style._key;
  if (key == null) return null;
  final shared = style._shared ??= ThorStyleRegistry._shared[key];
  if (shared != null) {
    final (name, inner, stringKey) = shared;
    final owners = registry._owners;
    if ((owners[name] ?? stringKey) == stringKey) {
      owners[name] = stringKey;
      registry._rules.putIfAbsent(name, () => (style.layer, inner));
      registry._recording?.addClass(name, style.layer, inner, stringKey);
      return name;
    }
  }
  return registry.classFor(
    style.css,
    conditions: style._classConditions,
    layer: style.layer,
  );
}

/// The conditions of [style]'s own class (without its [ElementStyle.inside]
/// rules): what a debug build names after the component.
List<ConditionalCss> elementClassConditions(ElementStyle style) =>
    style._classConditions;

/// The [ElementStyle] of an element whose class is made of these inputs,
/// from the per-process memo; [compute] builds it on a miss and must be a
/// pure function of them.
///
/// The inputs are the ones `thorElement` merges, in the order it merges
/// them: equal inputs (entry by entry, in order) give an equal style, so a
/// hit is exactly what [compute] would return.
ElementStyle elementStyle({
  required ThorLayer layer,
  required bool capsWidth,
  required CssDeclarations baseCss,
  required CssDeclarations wrapBaseCss,
  required CssDeclarations granted,
  required CssDeclarations css,
  required CssDeclarations flexible,
  required CssDeclarations wrapClassCss,
  required CssDeclarations wrapCss,
  required List<ConditionalCss> conditions,
  required List<ConditionalCss> wrapConditions,
  required (CssDeclarations, List<ConditionalCss>) Function() compute,
}) {
  return knownElementStyle(
        layer: layer,
        capsWidth: capsWidth,
        baseCss: baseCss,
        wrapBaseCss: wrapBaseCss,
        granted: granted,
        css: css,
        flexible: flexible,
        wrapClassCss: wrapClassCss,
        wrapCss: wrapCss,
        conditions: conditions,
        wrapConditions: wrapConditions,
      ) ??
      newElementStyle(layer, compute());
}

/// [elementStyle] in two steps, so the caller makes no closure for the
/// miss on every element: the style of these inputs from the memo, or null
/// (then [newElementStyle] with what they compute to, right after).
ElementStyle? knownElementStyle({
  required ThorLayer layer,
  required bool capsWidth,
  required CssDeclarations baseCss,
  required CssDeclarations wrapBaseCss,
  required CssDeclarations granted,
  required CssDeclarations css,
  required CssDeclarations flexible,
  required CssDeclarations wrapClassCss,
  required CssDeclarations wrapCss,
  required List<ConditionalCss> conditions,
  required List<ConditionalCss> wrapConditions,
}) {
  _missed = null;
  if (!renderCachesEnabled) return null;
  final key =
      _InputKey(
          2 +
              _InputKey.mapSize(baseCss) +
              _InputKey.mapSize(wrapBaseCss) +
              _InputKey.mapSize(granted) +
              _InputKey.mapSize(css) +
              _InputKey.mapSize(flexible) +
              _InputKey.mapSize(wrapClassCss) +
              _InputKey.mapSize(wrapCss) +
              _InputKey.conditionsSize(conditions) +
              _InputKey.conditionsSize(wrapConditions),
        )
        ..addInt(layer.index)
        ..addInt(capsWidth ? 1 : 0)
        ..addMap(baseCss)
        ..addMap(wrapBaseCss)
        ..addMap(granted)
        ..addMap(css)
        ..addMap(flexible)
        ..addMap(wrapClassCss)
        ..addMap(wrapCss)
        ..addConditions(conditions)
        ..addConditions(wrapConditions);
  final known = _elementStyles[key];
  if (known == null) _missed = key;
  return known;
}

/// The style of the inputs [knownElementStyle] just missed, made of what
/// they compute to ([computed]: the class's declarations and conditions),
/// kept in the memo.
ElementStyle newElementStyle(
  ThorLayer layer,
  (CssDeclarations, List<ConditionalCss>) computed,
) {
  final (own, all) = computed;
  final key = _missed;
  _missed = null;
  if (key == null) return ElementStyle(own, all, layer);
  // Bounded: styles built from data (a width per item) must not grow it
  // forever.
  if (_elementStyles.length >= _elementStylesLimit) _elementStyles.clear();
  // Kept by the process: its own read-only copies (compute may return one
  // of the widget's maps).
  return _elementStyles[key] = ElementStyle(
    Map.unmodifiable(own),
    List.unmodifiable([
      for (final c in all) ConditionalCss(c.when, Map.unmodifiable(c.css)),
    ]),
    layer,
  );
}

// The key of the last miss, for the [newElementStyle] that follows it
// (synchronous: nothing builds in between).
_InputKey? _missed;

final _elementStyles = <_InputKey, ElementStyle>{};
const _elementStylesLimit = 20000;

/// Number of element styles in the memo (tests).
int get elementStyleMemoSize => _elementStyles.length;

/// The inputs of an element's style flattened into one list (lengths as
/// ints, keys and values as strings, so no two different inputs flatten
/// alike), hashed as they are added. The list is fresh per lookup, so the
/// memo's keys never alias a widget's maps.
///
/// Sized up front ([mapSize], [conditionsSize]): one allocation per lookup,
/// never a growing list (this runs for every element of every page).
final class _InputKey {
  _InputKey(int size) : _parts = List<Object>.filled(size, 0);

  final List<Object> _parts;
  int _length = 0;
  int _hash = 0;

  /// Parts [addMap] adds for [css].
  static int mapSize(CssDeclarations css) => 1 + 2 * css.length;

  /// Parts [addConditions] adds for [conditions].
  static int conditionsSize(List<ConditionalCss> conditions) {
    var size = 1;
    for (final c in conditions) {
      size += 2 + mapSize(c.css);
    }
    return size;
  }

  void _add(Object part) {
    _parts[_length++] = part;
    var h = 0x1fffffff & (_hash + part.hashCode);
    h = 0x1fffffff & (h + ((0x0007ffff & h) << 10));
    _hash = h ^ (h >> 6);
  }

  void addInt(int value) => _add(value);

  void addMap(CssDeclarations css) {
    _add(css.length);
    if (css.isNotEmpty) css.forEach(_entry);
  }

  // One closure per key for every map it adds, not one per map.
  late final _entry = _addEntry;

  void _addEntry(String k, String v) {
    _add(k);
    _add(v);
  }

  void addConditions(List<ConditionalCss> conditions) {
    _add(conditions.length);
    for (final c in conditions) {
      _add(c.when._kind.index);
      _add(c.when._value);
      addMap(c.css);
    }
  }

  @override
  int get hashCode => _hash;

  @override
  bool operator ==(Object other) {
    if (other is! _InputKey || other._hash != _hash) return false;
    final a = _parts, b = other._parts;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// What a subtree registered in the page's registry while it was built:
/// the classes it used (each once, in first-use order), keyframes, typed
/// properties, SVG
/// symbols, preloaded images (`Image(priority: true)`), the names its
/// `Hero`es claimed, the page-level scripts it asked for (the form script,
/// the engine…) and whether it
/// used a `ThorState`. Replaying it into another
/// page's registry leaves that registry exactly as building the subtree
/// there would.
final class FragmentRecord {
  FragmentRecord._();

  final _classes = <(String, ThorLayer, String, String)>[];
  List<(String, String)> _keyframes = const [];
  List<(String, String)> _properties = const [];
  List<(String, String, String)> _symbols = const [];
  List<ImagePreload> _imagePreloads = const [];
  List<String> _heroNames = const [];
  Set<_PageUse> _uses = const {};

  /// Whether the subtree used a `ThorState` (its HTML carries per-request
  /// values).
  bool usedState = false;

  /// Whether every class came from the process-wide cache, so any page
  /// names it alike (a class named on this page, a hash collision or a
  /// debug component name is not).
  bool replayable = true;
}

final class _Recording {
  _Recording(this.parent);

  final _Recording? parent;
  final classes = <(String, ThorLayer, String, String)>[];
  final _seen = <String>{};
  final keyframes = <(String, String)>[];
  final properties = <(String, String)>[];
  final symbols = <(String, String, String)>[];
  final imagePreloads = <ImagePreload>[];
  final heroNames = <String>[];
  final uses = <_PageUse>{};
  bool usedState = false;
  bool replayable = true;

  void addClass(String name, ThorLayer layer, String inner, String key) {
    if (_seen.add(name)) classes.add((name, layer, inner, key));
  }
}

/// Starts recording what is registered in [registry] (see
/// [FragmentRecord]); recordings nest.
void beginFragmentRecord(ThorStyleRegistry registry) {
  registry._recording = _Recording(registry._recording);
}

/// Stops the innermost recording and returns it. What it recorded also
/// counts for the recording around it.
FragmentRecord endFragmentRecord(ThorStyleRegistry registry) {
  final r = registry._recording!;
  final parent = registry._recording = r.parent;
  if (parent != null) {
    for (final (name, layer, inner, key) in r.classes) {
      parent.addClass(name, layer, inner, key);
    }
    parent
      ..keyframes.addAll(r.keyframes)
      ..properties.addAll(r.properties)
      ..symbols.addAll(r.symbols)
      ..imagePreloads.addAll(r.imagePreloads)
      ..heroNames.addAll(r.heroNames)
      ..uses.addAll(r.uses)
      ..usedState = parent.usedState || r.usedState
      ..replayable = parent.replayable && r.replayable;
  }
  return FragmentRecord._()
    .._classes.addAll(r.classes)
    .._keyframes = List.unmodifiable(r.keyframes)
    .._properties = List.unmodifiable(r.properties)
    .._symbols = List.unmodifiable(r.symbols)
    .._imagePreloads = List.unmodifiable(r.imagePreloads)
    .._heroNames = List.unmodifiable(r.heroNames)
    .._uses = Set.unmodifiable(r.uses)
    ..usedState = r.usedState
    ..replayable = r.replayable;
}

/// Registers [record] in [registry] as building its subtree would. False,
/// and nothing registered, when a class name of the record belongs to
/// another style on this page (a hash collision): the subtree must be
/// built.
bool replayFragmentRecord(ThorStyleRegistry registry, FragmentRecord record) {
  final owners = registry._owners;
  for (final (name, _, _, key) in record._classes) {
    if ((owners[name] ?? key) != key) return false;
  }
  // A Hero name already on this page: building the subtree reports it.
  if (record._heroNames.any(registry._heroNames.contains)) return false;
  registry._heroNames.addAll(record._heroNames);
  final rules = registry._rules;
  final recording = registry._recording;
  for (final (name, layer, inner, key) in record._classes) {
    owners[name] = key;
    rules.putIfAbsent(name, () => (layer, inner));
    recording?.addClass(name, layer, inner, key);
  }
  for (final (name, body) in record._keyframes) {
    registry.addKeyframes(name, body);
  }
  for (final (prelude, body) in record._properties) {
    registry._addAtRule(prelude, body);
  }
  for (final (id, viewBox, body) in record._symbols) {
    registry.addSymbol(id, viewBox, body);
  }
  for (final image in record._imagePreloads) {
    registry.addImagePreload(image);
  }
  for (final use in record._uses) {
    switch (use) {
      case _PageUse.engine:
        registry.useEngine();
      case _PageUse.carouselControls:
        registry.useCarouselControls();
      case _PageUse.validation:
        registry.useValidation();
      case _PageUse.formScript:
        registry.useFormScript();
      case _PageUse.uploadScript:
        registry.useUploadScript();
      case _PageUse.lazyScript:
        registry.useLazyScript();
      case _PageUse.permanentScript:
        registry.usePermanentScript();
      case _PageUse.confirm:
        registry.useConfirm();
      case _PageUse.toast:
        registry.useToast();
      case _PageUse.snack:
        registry.useSnack();
      case _PageUse.postForm:
        registry.usePostForm();
    }
  }
  return true;
}

/// A page-level script or element a widget asks [ThorStyleRegistry] for
/// (`useFormScript`, `useEngine`…): a flag of the page, not markup of the
/// subtree, so a `Cached` fragment records it and its replay asks again.
enum _PageUse {
  engine,
  carouselControls,
  validation,
  formScript,
  uploadScript,
  lazyScript,
  permanentScript,
  confirm,
  toast,
  snack,
  postForm,
}

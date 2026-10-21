import 'package:thor_engine/css_text.dart';
import 'package:thor_engine/thor_engine.dart'
    show
        ServerCommandBase,
        ServerQuery,
        ThorState,
        encodeStateJson,
        stateJson,
        stateScriptId;
import 'package:thor_server/thor_server.dart'
    show LocaleRouting, LocaleStrategy, RouteNode, ServerMessages;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../core/document.dart' show DocumentAttributes, HeadPortal;
import '../core/framework.dart'
    show BuildChild, PageBuild, PageComponent, notePageAccess;
import '../core/markup.dart' show ElementNode, FragmentNode, ParentNode;
import '../engine/engine_script.dart';
import '../engine/flutter_loader.dart' show flutterLoaderScript;
import '../engine/form_script.dart' show formScript;
import '../engine/lazy_script.dart' show lazyScript;
import '../engine/permanent_script.dart' show permanentScript;
import '../engine/prefetch_script.dart'
    show prefetchLoaderScript, prefetchSrcAttr;
import '../engine/stay_script.dart' show stayScript;
import '../engine/theme_script.dart' show themeScript;
import '../engine/upload_script.dart' show uploadScript;
import '../engine/validation_script.dart' show validationScript;
import '../router/page_actions.dart' show postFormId;
import '../router/route_table.dart' show ThorRouter;
import '../widgets/feedback.dart' show FlashScope, SharedFeedback;
import '../widgets/theme.dart' show FontFace, Theme, ThemeData, ThemeMode;
import 'bound_lengths.dart';
import 'child_rules.dart' show ThorBuiltIn;
import 'css_rules.dart' show StyleRule, renderStyleRules;
import 'debug_inspector.dart';
import 'font_usage.dart';
import 'image_preload.dart';
import 'localizations.dart';
import 'material_localizations.dart';
import 'page_navigation.dart';
import 'responsive.dart' show HoverGroup;
import 'stylesheet.dart' show WindowSizeClass, Breakpoints;

export 'debug_inspector.dart';

part 'render_caches.dart';
part 'shared_sheets.dart';
part 'page_transitions.dart';

/// When extra declarations apply to an element: a media query, a container
/// query, or a state selector (`:hover`, `:focus-visible`…).
///
/// These are what inline styles can never express, and the reason thor
/// generates stylesheets instead of `style=""` attributes.
class CssCondition {
  const CssCondition._(this._kind, this._value)
    : _outer = null,
      _inner = null,
      _supports = null;

  /// Viewport at least [px] wide (mobile-first).
  CssCondition.minWidth(double px)
    : this._(_Kind.media, 'screen and (min-width: ${cssPx(px)})');

  /// Viewport narrower than [px].
  CssCondition.maxWidth(double px)
    : this._(_Kind.media, 'screen and (max-width: ${cssPx(px - 0.02)})');

  /// Nearest `LayoutScope` at least [px] wide: the web's `LayoutBuilder`.
  CssCondition.container(double px)
    : this._(_Kind.container, '(min-width: ${cssPx(px)})');

  /// Nearest `LayoutScope` narrower than [px].
  CssCondition.belowContainer(double px)
    : this._(_Kind.container, '(max-width: ${cssPx(px - 0.02)})');

  /// Any media query.
  const CssCondition.media(String query) : this._(_Kind.media, query);

  /// Viewport at least [breakpoint] wide, with the width of the theme's
  /// `Breakpoints` (resolved when the stylesheet is written).
  CssCondition.breakpoint(WindowSizeClass breakpoint)
    : this._(_Kind.media, 'screen and (min-width: {bp:${breakpoint.name}})');

  /// Viewport narrower than [breakpoint] (see [CssCondition.breakpoint]).
  CssCondition.belowBreakpoint(WindowSizeClass breakpoint)
    : this._(_Kind.media, 'screen and (max-width: {bp:${breakpoint.name}-})');

  /// [state] only while [width] holds: a hover that changes from a
  /// breakpoint up, written once as `@media … { .x:hover {…} }`. [width]
  /// is a media or container condition (a breakpoint, a container width);
  /// [state] is any other.
  CssCondition.both(CssCondition width, CssCondition state)
    : assert(
        width._kind == _Kind.media || width._kind == _Kind.container,
        'the first condition of both() is a media or a container query',
      ),
      _kind = _Kind.both,
      _value = '${width._value}|${state._value}',
      _outer = width,
      _inner = state,
      _supports = null;

  /// [inner] only where the browser supports [condition] (`@supports`): a
  /// rule that would break the page in a browser without the feature it
  /// goes with (`selector(::details-content)`).
  CssCondition.supports(String condition, CssCondition inner)
    : _kind = _Kind.supports,
      _value = '$condition|${inner._value}',
      _outer = null,
      _inner = inner,
      _supports = condition;

  /// A state / pseudo selector appended to the element's class
  /// (`':hover:not(:disabled)'`, `'::placeholder'`).
  const CssCondition.selector(String selector)
    : this._(_Kind.selector, selector);

  /// The styles an element starts from when it appears (entry
  /// transitions, no JS): `@starting-style { .x[open] {…} }` for
  /// `startingStyle('[open]')`.
  const CssCondition.startingStyle([String selector = ''])
    : this._(_Kind.startingStyle, selector);

  /// The styles an element starts from when it appears, only where it is
  /// [marker] or inside an element that is (`'[data-tli]'`):
  /// `@starting-style { .x:where([data-tli], [data-tli] *) {…} }`. What the
  /// rows of an `AnimatedList` that enter after the page loaded start from
  /// (the rows the server drew carry no marker, so they don't animate).
  const CssCondition.startingStyleWithin(String marker)
    : this._(_Kind.startingStyleWithin, marker);

  /// `:hover` on a control that is not disabled (`:disabled` or
  /// `aria-disabled="true"`), so hover styles never stick on it.
  static const hoverEnabled = CssCondition._(
    _Kind.selector,
    ':hover:not(:is(:disabled,[aria-disabled="true"]))',
  );

  /// `:active` on a control that is not disabled, like [hoverEnabled].
  static const pressedEnabled = CssCondition._(
    _Kind.selector,
    ':active:not(:is(:disabled,[aria-disabled="true"]))',
  );

  /// `::placeholder`.
  static const placeholder = CssCondition._(_Kind.selector, '::placeholder');

  /// The dark theme is showing: the system prefers dark and the page's
  /// theme switch (`ThemeToggle`) isn't flipped, or the system prefers light
  /// and it is. Without a switch on the page it is `prefers-color-scheme`.
  static const dark = CssCondition._(_Kind.scheme, 'dark');

  /// The light theme is showing (the opposite of [dark]).
  static const light = CssCondition._(_Kind.scheme, 'light');

  /// The page's theme switch (`ThemeToggle`) shows the dark theme on a
  /// system that prefers light: never on load (the choice isn't stored),
  /// only after the visitor flips it. What an image hidden until then
  /// needs, so it isn't downloaded before.
  static const switchedToDark = CssCondition._(_Kind.switched, 'dark');

  /// The switch shows the light theme on a system that prefers dark.
  static const switchedToLight = CssCondition._(_Kind.switched, 'light');

  /// Applies while an ancestor matches [ancestor] (`'.t-group:hover'`,
  /// `':root:has(#thor-theme:focus-visible)'`). The ancestor adds no
  /// specificity (`:where`), so the rule wins over the element's own only by
  /// coming later, like every other condition.
  const CssCondition.within(String ancestor) : this._(_Kind.within, ancestor);

  /// Applies inside a CSS `@scope` with [prelude], a root and an optional
  /// limit (see [detailsOpen]): below the nearest root that matches, and
  /// not past a limit. No specificity added, like [CssCondition.within].
  const CssCondition.scope(String prelude) : this._(_Kind.scope, prelude);

  /// While the nearest `<details>` around the element is open (the
  /// `.when(open:)` state): a nested `<details>` ends the scope, so what is
  /// inside it follows its own.
  static const detailsOpen = CssCondition.scope(
    '(details[open]) to (:scope details)',
  );

  /// Applies while the element right before this one matches [previous]
  /// (`':hover'`, `':focus-visible'`): `:where(previous) + .x`, no
  /// specificity added. What shows a `Tooltip`'s bubble next to its child.
  const CssCondition.after(String previous) : this._(_Kind.after, previous);

  /// Elements inside this one that match [selector] (`'h2'`, `'> * + *'`,
  /// `'th, td'`, `'a:hover'`) and that no thor widget builds: raw HTML
  /// (rendered markdown). The rules stop at the first thor element inside
  /// (marked [descendantBoundaryAttr]), so a component nested in the
  /// prose keeps its own styles, and the selector keeps the specificity it
  /// had (`.x h2`). What `Styled(descendants:)` uses.
  const CssCondition.descendant(String selector)
    : this._(_Kind.descendant, selector);

  /// Whether this is a [CssCondition.descendant] condition: its element
  /// marks the thor elements inside as the rules' limit.
  bool get isDescendant => _kind == _Kind.descendant;

  /// Whether the rule lands on other elements than the one with the class
  /// (its children, descendants or siblings: `' > *'`, `' .figure'`, a
  /// [CssCondition.descendant]) and never on that element itself.
  bool get _targetsOthers => switch (_kind) {
    _Kind.descendant => true,
    _Kind.selector || _Kind.startingStyle => _hasCombinator(_value),
    _Kind.both || _Kind.supports => _inner!._targetsOthers,
    _ => false,
  };

  /// Whether [selector] has a combinator (a space, `>`, `+`, `~`) outside
  /// parentheses and brackets: `' > *'` and `':hover > span'` do,
  /// `':is(a, b)'` and `'[x="a b"]'` don't.
  static bool _hasCombinator(String selector) {
    var depth = 0;
    String? quote;
    for (var i = 0; i < selector.length; i++) {
      final c = selector[i];
      if (quote != null) {
        if (c == quote) quote = null;
      } else if (c == '"' || c == "'") {
        quote = c;
      } else if (c == '(' || c == '[') {
        depth++;
      } else if (c == ')' || c == ']') {
        depth--;
      } else if (depth == 0 &&
          (c == ' ' || c == '>' || c == '+' || c == '~' || c == '\n')) {
        return true;
      }
    }
    return false;
  }

  /// A rule on [selector] itself (`':root:has(dialog:modal)'`), not on the
  /// element: what a widget that changes the whole page needs (a modal
  /// panel locking the document's scroll). The declarations are those of
  /// the [ConditionalCss]; the element's own class is not in the rule.
  /// Register it once with an element-less class (`classFor` with only this
  /// condition): classes are content hashes, so every widget that asks gets
  /// the one rule.
  @internal
  const CssCondition.page(String selector) : this._(_Kind.page, selector);

  /// `prefers-reduced-motion: reduce`.
  static const reducedMotion = CssCondition._(
    _Kind.media,
    '(prefers-reduced-motion: reduce)',
  );

  /// `prefers-contrast: more`: the visitor asked for more contrast. The
  /// theme's `highContrastTheme` is published under it.
  static const moreContrast = CssCondition._(
    _Kind.media,
    '(prefers-contrast: more)',
  );

  /// `forced-colors: active` (Windows High Contrast and the like): the
  /// browser replaces the page's colors by the system's, drops
  /// `box-shadow` and background images that carry meaning. What a control
  /// that shows its state with color only repeats with an outline, a
  /// border, a text decoration or its native look.
  static const forcedColors = CssCondition._(
    _Kind.media,
    '(forced-colors: active)',
  );

  /// `:hover`.
  static const hover = CssCondition._(_Kind.selector, ':hover');

  /// `:active`.
  static const pressed = CssCondition._(_Kind.selector, ':active');

  /// `:focus-visible`.
  static const focused = CssCondition._(_Kind.selector, ':focus-visible');

  /// `:focus-within`.
  static const focusWithin = CssCondition._(_Kind.selector, ':focus-within');

  /// `:disabled` or `[aria-disabled="true"]`: a native disabled control and
  /// the accessible one that stays focusable and does nothing. What
  /// `WidgetState.disabled` and `.when(disabled:)` match.
  static const disabled = CssCondition._(
    _Kind.selector,
    ':is(:disabled,[aria-disabled="true"])',
  );

  /// All direct children.
  static const children = CssCondition._(_Kind.selector, ' > *');

  /// Direct children that don't take the max width (see `LayoutHint`).
  static const alignedChildren = CssCondition._(
    _Kind.selector,
    ' > :not(.t-fill-w)',
  );

  final _Kind _kind;
  final String _value;

  // Only [CssCondition.both]: the query and what it holds around.
  final CssCondition? _outer;
  final CssCondition? _inner;

  // Only [CssCondition.supports]: the feature query.
  final String? _supports;

  String _wrap(String selector, String body) {
    if (_kind == _Kind.both) {
      // The inner rule keeps its own guard (`@media (hover: hover)`).
      final o = _outer!;
      return '@${o._kind == _Kind.media ? 'media' : 'container'} ${o._value}'
          '{${_inner!._wrap(selector, body)}}';
    }
    if (_kind == _Kind.supports) {
      return '@supports $_supports{${_inner!._wrap(selector, body)}}';
    }
    final rule = _rule(selector, body);
    // `// web:` hover only exists with a pointer that hovers (as in Flutter,
    // where it comes from a mouse): on touch a tap would leave the hover
    // styles stuck until the next tap elsewhere.
    return _hovers ? '@media (hover: hover){$rule}' : rule;
  }

  bool get _hovers =>
      (_kind == _Kind.selector ||
          _kind == _Kind.within ||
          _kind == _Kind.after ||
          _kind == _Kind.descendant) &&
      _value.contains(':hover');

  String _rule(String selector, String body) => switch (_kind) {
    _Kind.both || _Kind.supports => throw StateError('written by _wrap'),
    _Kind.media => '@media $_value{$selector{$body}}',
    _Kind.container => '@container $_value{$selector{$body}}',
    _Kind.selector => '$selector$_value{$body}',
    _Kind.startingStyle => '@starting-style{$selector$_value{$body}}',
    _Kind.startingStyleWithin =>
      '@starting-style{$selector:where($_value,$_value *){$body}}',
    _Kind.within => ':where($_value) $selector{$body}',
    _Kind.scope => '@scope $_value{$selector{$body}}',
    _Kind.after => ':where($_value) + $selector{$body}',
    _Kind.page => '$_value{$body}',
    _Kind.descendant => '${_descendants(selector, _value)}{$body}',
    _Kind.scheme => _schemeRules(_value == 'dark', selector, body),
    // The system prefers the other scheme, and the switch is flipped.
    _Kind.switched =>
      '@media ${_value == 'dark' ? 'not all and ' : ''}'
          '(prefers-color-scheme: dark)'
          '{:where(:root:has(#$themeToggleId:checked)) $selector{$body}}',
  };

  /// The selector of a [CssCondition.descendant] rule: [target] inside
  /// [root], limited by [_limited]. A list with a relative selector
  /// (`'> :first-child, > p'`) is written as one selector per item, since
  /// `:is()` takes no relative selectors and the browser would drop the
  /// whole rule.
  static String _descendants(String root, String target) {
    if (target.contains(',')) {
      final items = _splitList(target);
      if (items.any(_relative.hasMatch)) {
        final limit = _limit(root);
        return [
          for (final i in items) '$root ${_limitedOne(i, limit)}',
        ].join(',');
      }
    }
    return '$root ${_limited(root, target)}';
  }

  static final _relative = RegExp(r'^\s*[>+~]');

  /// The items of a selector list, split on the commas outside parentheses
  /// and brackets (`:is(a, b)` and `[x="a,b"]` stay whole).
  static List<String> _splitList(String list) {
    final items = <String>[];
    var depth = 0, start = 0;
    String? quote;
    for (var i = 0; i < list.length; i++) {
      final c = list[i];
      if (quote != null) {
        if (c == quote) quote = null;
      } else if (c == '"' || c == "'") {
        quote = c;
      } else if (c == '(' || c == '[') {
        depth++;
      } else if (c == ')' || c == ']') {
        depth--;
      } else if (c == ',' && depth == 0) {
        items.add(list.substring(start, i).trim());
        start = i + 1;
      }
    }
    items.add(list.substring(start).trim());
    return [
      for (final i in items)
        if (i.isNotEmpty) i,
    ];
  }

  /// [target] (inside [root]) unless it is, or is inside, a thor element
  /// inside [root]: `@scope (root) to ([data-tb])` without `@scope`, which
  /// the browsers thor supports don't all have (Firefox before 146). The
  /// limit sits in `:where()`, so it adds no specificity.
  static String _limited(String root, String target) {
    final limit = _limit(root);
    // A list (`th, td`) is scoped as a whole.
    if (target.contains(',')) return ':is($target)$limit';
    return _limitedOne(target, limit);
  }

  static String _limit(String root) =>
      ':where(:not($root [$descendantBoundaryAttr],'
      '$root [$descendantBoundaryAttr] *))';

  static String _limitedOne(String target, String limit) {
    // A pseudo-element ends the selector: the limit goes before it.
    final pseudo = target.indexOf('::');
    return pseudo < 0
        ? '$target$limit'
        : '${target.substring(0, pseudo)}$limit${target.substring(pseudo)}';
  }

  /// Two rules: system scheme with the switch off, the other one with it on.
  static String _schemeRules(bool dark, String selector, String body) {
    String scoped(bool flipped) {
      final root = flipped
          ? ':root:has(#$themeToggleId:checked)'
          : ':root:not(:has(#$themeToggleId:checked))';
      return selector == ':root'
          ? '$root{$body}'
          : ':where($root) $selector{$body}';
    }

    const prefersDark = '(prefers-color-scheme: dark)';
    const prefersLight = 'not all and (prefers-color-scheme: dark)';
    return '@media ${dark ? prefersDark : prefersLight}{${scoped(false)}}'
        '@media ${dark ? prefersLight : prefersDark}{${scoped(true)}}';
  }

  @override
  String toString() => '${_kind.name}:$_value';
}

enum _Kind {
  media,
  container,
  selector,
  startingStyle,
  startingStyleWithin,
  within,
  scope,
  after,
  page,
  scheme,
  switched,
  descendant,
  both,
  supports,
}

/// The attribute on thor elements inside an element with
/// [CssCondition.descendant] rules: where those rules stop.
const descendantBoundaryAttr = 'data-tb';

/// Published by an element with [CssCondition.descendant] rules to the
/// widgets inside it: their thor elements carry [descendantBoundaryAttr].
class DescendantRulesScope extends InheritedWidget {
  /// Marks the thor elements in [child].
  const DescendantRulesScope({super.key, required super.child});

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

/// DOM id of the page's theme switch (a hidden checkbox rendered by
/// `ThorApp` when it has a `darkTheme`; `ThemeToggle` is its label).
const themeToggleId = 'thor-theme';

/// Declarations that apply under a [CssCondition].
class ConditionalCss {
  /// Pairs [css] with the [when] condition it applies under.
  const ConditionalCss(this.when, this.css);

  /// The condition under which [css] applies.
  final CssCondition when;

  /// The declarations applied when [when] matches.
  final CssDeclarations css;
}

/// thor's cascade layers, lowest first, all inside one outer `thor` layer:
///
/// - `thor.reset`: the page reset (`thorResetStyles`);
/// - `thor.tokens`: the app theme (variables on `:root`, `color-scheme`);
/// - `thor.components`: component recipes (reserved);
/// - `thor.props` / `thor.overrides`: one class per element ([ThorLayer]).
///
/// App stylesheets are unlayered, so they override every thor layer. Every
/// page states this order first, so a stylesheet linked before it (a shared
/// one) or after it lands in the same place.
const thorLayerOrder =
    '@layer thor.reset,thor.tokens,thor.components,thor.props,thor.overrides;';

/// The layer of the page reset (`thorResetStyles`).
const thorResetLayer = 'thor.reset';

/// The layer of the app theme (variables on `:root`).
const thorTokensLayer = 'thor.tokens';

/// Cascade layers of the per-element classes, lowest first (see
/// [thorLayerOrder] for the whole order).
enum ThorLayer {
  /// Widget props (`Container(color: …)`): the defaults.
  props('thor.props'),

  /// Explicit overrides (`Responsive`, conditional wrappers) that must beat
  /// the props of the element they wrap.
  overrides('thor.overrides');

  const ThorLayer(this.cssName);

  /// The `@layer` name this layer is emitted under.
  final String cssName;
}

/// Collects the styles of every thor element into deduplicated classes.
///
/// Elements with identical styles share one class, so a list of 50 identical
/// cards costs one CSS rule instead of 50 `style` attributes. Class names are
/// content hashes: equal styles always get the same class. The browser never
/// generates styles (every state is rendered by the server).
class ThorStyleRegistry {
  ThorStyleRegistry._();

  /// A registry for one server render; flushed into `<head>` by [ThorApp].
  factory ThorStyleRegistry.server() => ThorStyleRegistry._();

  /// class name → (layer, rule body without the `@layer` wrapper).
  final Map<String, (ThorLayer, String)> _rules = {};
  bool _flushed = false;

  final Set<ThorState> _states = {};

  /// Records that the page uses [state] (a `Watch` or a callback bound to
  /// it): [ThorApp] then ships the engine script and the state's values.
  @internal
  void useState(ThorState state) {
    _recording?.usedState = true;
    _states.add(state);
    _capture?.add(state);
    // What its code asks the page for (`confirm`, `toast`).
    final uses = state.uses;
    if (uses.contains('confirm')) useConfirm();
    if (uses.contains('toast')) useToast();
  }

  /// The states the page uses.
  Set<ThorState> get usedStates => _states;

  Set<ThorState>? _capture;

  /// Starts collecting every state used from now on, even one the document
  /// already carries (what a fragment that refreshes the page's states needs
  /// to ship); [endCapture] hands them out.
  @internal
  void beginCapture() => _capture = {};

  /// The states used since [beginCapture].
  @internal
  Set<ThorState> endCapture() {
    final found = _capture ?? const <ThorState>{};
    _capture = null;
    return found;
  }

  bool _engine = false;

  /// Records that the page needs the engine even without a state (a date
  /// picker in a form that posts): [ThorApp] then ships the engine script.
  @internal
  void useEngine() {
    // Page-level output: a replayed fragment asks for it again.
    _recording?.uses.add(_PageUse.engine);
    _engine = true;
  }

  /// Whether the page ships the engine script: it uses a state, or a
  /// widget asked for it ([useEngine]).
  @internal
  bool get usesEngine => _engine || _states.isNotEmpty;

  bool _carouselControls = false;

  /// Records that the page has carousel controls the engine may have to
  /// show (browsers without `::scroll-button`). A page that needs the engine
  /// for nothing else ships only a tiny inline test that loads it where the
  /// browser draws no arrows of its own (Chromium downloads nothing).
  @internal
  void useCarouselControls() {
    // Page-level output: a replayed fragment asks for it again.
    _recording?.uses.add(_PageUse.carouselControls);
    _carouselControls = true;
  }

  bool _validation = false;

  /// Records that the page has a field with native validation rules and
  /// messages of its own (`TextFormField`): a page without the engine
  /// gets the engine's forms part inline, so the messages show.
  @internal
  void useValidation() {
    // Page-level output: a replayed fragment asks for it again.
    _recording?.uses.add(_PageUse.validation);
    _validation = true;
  }

  bool _formScript = false;
  bool _errorFocus = false;

  /// Records that the page has a form that navigates on submit (`Form`) or
  /// a field the server marked as wrong: [ThorApp] then ships the form
  /// script (the «sending» state and the focus of the first error), with or
  /// without the engine.
  @internal
  void useFormScript() {
    // Page-level output: a replayed fragment asks for it again.
    _recording?.uses.add(_PageUse.formScript);
    _formScript = true;
  }

  bool _uploadScript = false;

  /// Records that the page has an upload bar (`LinearProgressIndicator.upload`):
  /// [ThorApp] then ships the script that sends the files of its form with
  /// progress, after the form script.
  @internal
  void useUploadScript() {
    // Page-level output: a replayed fragment asks for it again.
    _recording?.uses.add(_PageUse.uploadScript);
    _uploadScript = true;
  }

  bool _stayScript = false;

  /// Records that the page has a form that saves where it stands
  /// (`Form(stay: true)`) or a file input that sends its form when files are
  /// chosen (`FileField(submitOnChange:)`): [ThorApp] then ships the script
  /// that does it, before the form script, with or without the engine.
  @internal
  void useStayScript() {
    // Page-level output: a replayed fragment asks for it again.
    _recording?.uses.add(_PageUse.stayScript);
    _stayScript = true;
    // The answer is a toast.
    useToast();
  }

  bool _lazyScript = false;

  /// Records that the page has a `LazyPiece`: [ThorApp] then ships the script
  /// that loads it when its trigger happens, with or without the engine.
  @internal
  void useLazyScript() {
    // Page-level output: a replayed fragment asks for it again.
    _recording?.uses.add(_PageUse.lazyScript);
    _lazyScript = true;
  }

  bool _permanentScript = false;

  /// Records that the page has an `ExpansionTile(permanentFrom:)`:
  /// [ThorApp] then ships the script that takes its header out of the Tab
  /// order from the breakpoint.
  @internal
  void usePermanentScript() {
    // Page-level output: a replayed fragment asks for it again.
    _recording?.uses.add(_PageUse.permanentScript);
    _permanentScript = true;
  }

  bool _confirm = false;
  bool _toast = false;

  /// Records that the page asks a confirmation (`confirm:` on a button, or a
  /// state that calls `confirm(…)`): [ThorApp] then ships the one dialog and
  /// its inline script.
  @internal
  void useConfirm() {
    // Page-level output: a replayed fragment asks for it again.
    _recording?.uses.add(_PageUse.confirm);
    _confirm = true;
  }

  /// Records that a state of the page calls `toast(…)`: [ThorApp] then ships
  /// the one snack bar, its looks and its inline script.
  @internal
  void useToast() {
    // Page-level output: a replayed fragment asks for it again.
    _recording?.uses.add(_PageUse.toast);
    _toast = true;
  }

  /// Whether the page ships the confirm dialog.
  @internal
  bool get usesConfirm => _confirm;

  /// Whether the page ships the snack bar's script (a server flash alone
  /// needs the bar and no script).
  @internal
  bool get usesToast => _toast;

  bool _snack = false;

  /// Records that the page has a `SnackBar` of its own (not the page's
  /// messenger): [ThorApp] then ships the inline script that puts it in the
  /// top layer while it shows.
  @internal
  void useSnack() {
    // Page-level output: a replayed fragment asks for it again.
    _recording?.uses.add(_PageUse.snack);
    _snack = true;
  }

  /// Whether the page ships the script of a hand-made snack bar.
  @internal
  bool get usesSnack => _snack;

  bool _postForm = false;

  /// Records that the page has a button that posts an action with
  /// arguments (`FilledButton(onPost: page.delete.bind(id))`): [ThorApp]
  /// then ships the one hidden form those buttons submit
  /// (`<form id="thor-post" method="post" hidden>`), and the form script.
  @internal
  void usePostForm() {
    // Page-level output: a replayed fragment asks for it again.
    _recording?.uses.add(_PageUse.postForm);
    _postForm = true;
    useFormScript();
  }

  bool _errorFocusAllowed = false;

  /// A `Form(failed:)` with the answer's `FormInvalid` renders: this page is
  /// the answer of a failed form, even when its action said `200`.
  void allowErrorFocus() => _errorFocusAllowed = true;

  /// Whether the caller is the first field of this page with a server
  /// error: only that one gets `autofocus` (GOV.UK error summary, Rails,
  /// Django: the first error, not all). Only when the page answers a failed
  /// form action; any other page (a GET, a demo with a fixed error) claims
  /// nothing and ships no script for it. Otherwise asks for the form script.
  ///
  /// The page answers a failed form when the status is an error (a 4xx or
  /// 5xx after a POST) or when a `Form(failed:)` with a `FormInvalid`
  /// renders in the answer of a POST, whatever the status ([allowErrorFocus]).
  bool claimErrorFocus() {
    if (!_errorFocusAllowed) return false;
    useFormScript();
    if (_errorFocus) return false;
    return _errorFocus = true;
  }

  var _ids = 0;

  /// A DOM id unique in this page (`<prefix><n>`), for widgets whose parts
  /// point at each other (`popovertarget`, `aria-controls`). Deterministic:
  /// the same page renders the same ids.
  String uniqueId(String prefix) {
    // Counted per page: a fragment replayed on another page could collide.
    _recording?.replayable = false;
    String id;
    do {
      id = '$prefix${++_ids}';
    } while (_claimedIds.contains(id));
    return id;
  }

  final _claimedIds = <String>{};

  /// Marks [id] (one the app wrote) as taken on this page, so the ids the
  /// page derives itself ([claimId], [uniqueId]) skip it when they come
  /// after. One written after a derived one can't be helped: keep the
  /// `t-` prefix and `dlg-`, `drawer-`… for the page.
  void reserveId(String id) => _claimedIds.add(id);

  /// [base] if no panel on this page has it yet, else `<base>-2`, `<base>-3`…
  /// the first free one (a key `a-2` next to a repeated `a` never collides).
  String claimId(String base) {
    _recording?.replayable = false;
    var id = base;
    for (var n = 2; !_claimedIds.add(id); n++) {
      id = '$base-$n';
    }
    return id;
  }

  final _fieldIds = <String, int>{};

  /// The DOM id of the form field [base] (`f-email`): [base] the first time
  /// this page asks, `<base>-2`, `<base>-3`… after, so two forms with a field
  /// of the same name don't share an id (a `<label for>` and an
  /// `aria-describedby` would point at the first one). Django's `prefix` and
  /// Rails' `form_with scope:` avoid it by naming the form; here the page
  /// order does. Deterministic: the same page renders the same ids.
  String fieldId(String base) {
    // Counted per page, like [uniqueId].
    _recording?.replayable = false;
    final n = _fieldIds[base] = (_fieldIds[base] ?? 0) + 1;
    return n == 1 ? base : '$base-$n';
  }

  String? _flutterSrc;

  /// Records that the page embeds the Flutter build at [src] (a
  /// `FlutterView`): [ThorApp] then ships the Flutter loader once, at the
  /// end of `<body>`. A page runs one Flutter engine, so a second build
  /// URL is an error.
  @internal
  void useFlutter(String src) {
    // The loader is page-level output a replayed fragment wouldn't restore.
    _recording?.replayable = false;
    final current = _flutterSrc;
    if (current != null && current != src) {
      throw StateError(
        'Every FlutterView of a page must use the same Flutter build '
        '(one engine per page): "$current" and "$src".',
      );
    }
    _flutterSrc = src;
  }

  /// The Flutter build the page embeds (see [useFlutter]), or null.
  String? get flutterSrc => _flutterSrc;

  LinkedStyleSheet? _linked;

  /// Links [sheet] (the app's shared stylesheet file): the classes, theme
  /// and keyframes it holds are left out of this page's `<style>`. A style
  /// of this page that another style of the sheet named first gets
  /// another name (as a hash collision would), never the sheet's rules.
  void link(LinkedStyleSheet sheet) {
    _linked = sheet;
    for (final MapEntry(:key, :value) in sheet._classes.entries) {
      _owners.putIfAbsent(key, () => value);
    }
  }

  /// How this page enters from another page of the app: the app's
  /// ([PageNavigation.pageTransition]), then each [PageTransitionScope]
  /// down the tree (a layout's, then its page's: the nearest wins).
  PageTransition? _transition;

  /// The `view-transition-name`s a `Hero` claimed on this page.
  final _heroNames = <String>{};

  /// Claims [name] (a `Hero`'s `view-transition-name`) for this page:
  /// `false` when another `Hero` of the page has it (a view transition
  /// with two elements of one name is skipped by the browser).
  bool claimViewTransitionName(String name) {
    if (!_heroNames.add(name)) return false;
    // A replayed fragment claims it again on its page.
    _recording?.heroNames.add(name);
    return true;
  }

  /// Runs each of [alternatives] (the states of one `Watch`: only one is
  /// in the page at a time) with the names claimed before them, so a
  /// `Hero` may repeat its tag from one state to the next but not within
  /// one. Afterwards every name any of them claimed is taken.
  ///
  /// The same goes for the ids the page derives ([uniqueId], [claimId],
  /// [fieldId]): each state counts from where the first one started, so a
  /// `Tooltip` or a field at the same place of two states gets the same id
  /// in both and the patch between them leaves it alone. Afterwards the
  /// counters are past every state's, so what follows never repeats one.
  void claimAlternatives(Iterable<void Function()> alternatives) {
    final before = {..._heroNames};
    final all = <String>{};
    final ids = _ids;
    final claimed = {..._claimedIds};
    final fields = {..._fieldIds};
    var lastId = ids;
    final allClaimed = <String>{...claimed};
    final allFields = <String, int>{...fields};
    for (final build in alternatives) {
      _heroNames
        ..clear()
        ..addAll(before);
      _ids = ids;
      _claimedIds
        ..clear()
        ..addAll(claimed);
      _fieldIds
        ..clear()
        ..addAll(fields);
      build();
      all.addAll(_heroNames);
      if (_ids > lastId) lastId = _ids;
      allClaimed.addAll(_claimedIds);
      for (final MapEntry(:key, :value) in _fieldIds.entries) {
        if (value > (allFields[key] ?? 0)) allFields[key] = value;
      }
    }
    _heroNames
      ..clear()
      ..addAll(all);
    _ids = lastId;
    _claimedIds
      ..clear()
      ..addAll(allClaimed);
    _fieldIds
      ..clear()
      ..addAll(allFields);
  }

  /// The timings of the `AnimatedSwitcher`s on this page (their
  /// `data-t-vt` values), in first-use order.
  final _switchers = <String>{};

  /// Registers switcher timing [key] ([switcherTiming]): the page ships
  /// its view transition rules ([switcherCss]).
  /// (A `Watch` never goes in a `Cached` fragment: nothing to record.)
  void addSwitcher(String key) => _switchers.add(key);

  /// The route module sheets of the page, root first ([ModuleStyles]).
  final _modules = <ModuleSheet>[];

  /// Whether module sheets are linked files ([SharedStylesScope.files]).
  bool _moduleFiles = false;

  /// SVG sprite symbols (id → `<symbol>` markup), shipped once per page.
  final Map<String, String> _symbols = {};
  final Map<String, String> _keyframes = {};
  // Top-level at-rules by prelude (`@property --x`, `@position-try --y`).
  final Map<String, String> _properties = {};

  // What the `Cached` fragment being built registers (innermost first).
  _Recording? _recording;

  /// Registers `@keyframes name {body}` once for the page's stylesheet.
  void addKeyframes(String name, String body) {
    _recording?.keyframes.add((name, body));
    _keyframes.putIfAbsent(name, () => body);
  }

  /// Registers `@property name {body}` once for the page's stylesheet: a
  /// typed custom property. With `inherits: false` the browser does not
  /// re-resolve the property in the whole subtree when it changes (what a
  /// gesture does on every pointer move). The client never writes this
  /// (rule 4): the server ships it only on the pages that use it.
  void addProperty(String name, String body) =>
      _addAtRule('@property $name', body);

  /// Registers `@position-try name {body}` once for the page's stylesheet:
  /// a named anchor-positioning fallback (`position-try-fallbacks: name`),
  /// which a try tactic can transform (`name flip-block`).
  void addPositionTry(String name, String body) =>
      _addAtRule('@position-try $name', body);

  // A top-level at-rule (`@property`, `@position-try`) by its prelude.
  void _addAtRule(String prelude, String body) {
    _recording?.properties.add((prelude, body));
    _properties.putIfAbsent(prelude, () => body);
  }

  /// Registers an SVG icon symbol; returns false if it is already known.
  bool addSymbol(String id, String viewBox, String body) {
    _recording?.symbols.add((id, viewBox, body));
    if (_symbols.containsKey(id)) return false;
    final symbol = '<symbol id="$id" viewBox="$viewBox">$body</symbol>';
    _symbols[id] = symbol;
    return true;
  }

  /// The registered `<symbol>` markup for the page's SVG sprite.
  String get spriteMarkup => _symbols.values.join();

  // What the document already carries once its first part went out (see
  // [markShipped]): what a part drawn later adds goes after it.
  Set<String> _shippedRules = const {};
  Set<String> _shippedKeyframes = const {};
  Set<String> _shippedProperties = const {};
  Set<String> _shippedSymbols = const {};
  Set<ThorState> _shippedStates = const {};
  bool _shippedEngine = false;
  bool _shippedFallback = false;

  /// Records that the document went out with what the registry holds now:
  /// the rules, the sprite, the states and the engine. A part of the page
  /// that is drawn afterwards (a deferred value, `FutureBuilder`) asks
  /// [takeLate] for what it added.
  void markShipped() {
    _flushed = true;
    _shippedRules = _rules.keys.toSet();
    _shippedKeyframes = _keyframes.keys.toSet();
    _shippedProperties = _properties.keys.toSet();
    _shippedSymbols = _symbols.keys.toSet();
    _shippedStates = {..._states};
    _shippedEngine = usesEngine;
    _shippedFallback = _carouselControls;
  }

  /// Lets a part of the page drawn after the document went out register its
  /// classes (a flushed registry answers `null` to [active], and its widgets
  /// write their styles inline): [takeLate] closes it again.
  void reopen() => _flushed = false;

  final Set<ThorState> _lateStates = {};

  /// The states [takeLate] handed out values for since the last
  /// [forgetLateStates]: what a part drawn late needs the browser to know.
  Set<ThorState> get lateStates => _lateStates;

  /// Starts counting [lateStates] again.
  void forgetLateStates() => _lateStates.clear();

  /// Closes the registry again after a part drawn late that failed.
  void close() => _flushed = true;

  /// The script of the engine the document was drawn with, to ship late
  /// when only a late part needs it.
  Widget Function()? _engineScript;
  Widget Function()? _fallbackScript;

  /// The prefetch fallback's test, to ship with an engine that only a late
  /// part brought (the document's head did not carry it); `null` once it is
  /// shipped or when the page has none.
  Widget Function()? _prefetchLoader;

  /// What the page needs for the widgets drawn since the last
  /// [markShipped] or [takeLate], to go with them: their classes (a
  /// `<style>` after the document's own), the icons they added to the sprite,
  /// the values of the states they use and the engine when nothing else had
  /// asked for it. Empty when they added nothing.
  ///
  /// `// web:` what only the whole page can say (the confirm dialog, the
  /// toast, a post form, the form script, a Flutter view) is not shipped
  /// late: use it in the part of the page that goes out first.
  ({String css, String sprite, Map<String, Object?> state, Widget? engine})
  takeLate() {
    final linked = _linked;
    bool shipped(String name) =>
        _shippedRules.contains(name) ||
        (linked != null &&
            linked._classes[name] != null &&
            linked._classes[name] == _owners[name]);
    final css = StringBuffer();
    for (final layer in ThorLayer.values) {
      final rules = [
        for (final MapEntry(key: name, value: (l, inner)) in _rules.entries)
          if (l == layer && !shipped(name))
            flattenRules(splitCssStatements(breakpoints.resolve(inner))),
      ];
      if (rules.isNotEmpty) {
        css.write(
          '@layer ${layer.cssName}{${dropThemeFallbacks(groupClassRules(rules), _themeVars)}}',
        );
      }
    }
    for (final e in _keyframes.entries) {
      if (_shippedKeyframes.contains(e.key)) continue;
      if (linked?._keyframes[e.key] == e.value) continue;
      css.write('@keyframes ${e.key}{${e.value}}');
    }
    for (final e in _properties.entries) {
      if (_shippedProperties.contains(e.key)) continue;
      if (linked?._properties[e.key] == e.value) continue;
      css.write('${e.key}{${e.value}}');
    }
    final sprite = [
      for (final e in _symbols.entries)
        if (!_shippedSymbols.contains(e.key)) e.value,
    ].join();
    final fresh = _states.difference(_shippedStates);
    final needsEngine = usesEngine && !_shippedEngine;
    // Only the carousel needs it: the conditional loader, once.
    final needsFallback = !usesEngine && _carouselControls && !_shippedFallback;
    final loader = needsEngine ? _prefetchLoader?.call() : null;
    if (loader != null) _prefetchLoader = null;
    final engine = needsEngine ? _engineScript?.call() : null;
    _lateStates.addAll(fresh);
    final late = (
      css: breakpoints.resolve(css.toString()),
      sprite: sprite,
      state: stateJson(fresh),
      engine: needsEngine
          ? (loader == null || engine == null
                ? engine
                : Widget.fragment([engine, loader]))
          : needsFallback
          ? _fallbackScript?.call()
          : null,
    );
    markShipped();
    return late;
  }

  /// Records that the element being rendered depends on where it is (it is
  /// inside a [DescendantRulesScope]): a `Cached` fragment holding it is
  /// never replayed elsewhere.
  void dependsOnPlace() => _recording?.replayable = false;

  /// Checks that [classes] (one element's) hold at most one class of this
  /// registry per layer: grouped rules reorder the rules of different
  /// classes, which is only safe when no element has two.
  /// Debug builds call it for every element; a violation is a thor bug.
  void debugCheckOneClassPerLayer(Iterable<String> classes, String tag) {
    final seen = <ThorLayer, String>{};
    for (final name in classes) {
      final layer = _rules[name]?.$1;
      if (layer == null) continue;
      final other = seen[layer];
      if (other != null && other != name) {
        throw StateError(
          '<$tag class="${classes.join(' ')}">: "$other" and "$name" are both '
          'in @layer ${layer.cssName}. thor emits one class per element and '
          'layer; grouped rules would change which one wins.',
        );
      }
      seen[layer] = name;
    }
  }

  /// Returns the class for [css] under [conditions], registering it if new.
  /// With a [named] name (debug builds: the app component's) the class is
  /// that instead of a content hash; another style under the same name gets
  /// `name-2`, `-3`…
  String classFor(
    CssDeclarations css, {
    List<ConditionalCss> conditions = const [],
    ThorLayer layer = ThorLayer.props,
    String? named,
  }) {
    if (named != null) {
      // Named after the page's components: not replayable elsewhere.
      _recording?.replayable = false;
      return _namedClass(named, css, conditions, layer);
    }
    // A server renders the same styles on every request: name and rule
    // text come from a per-process cache (unless the name is taken on this
    // page by another style, a hash collision). The lookup compares the
    // declarations entry by entry, so a hit (every element, every request)
    // skips building and hashing the string key.
    final shared = _shared[_StyleKey(layer, css, conditions)];
    if (shared != null) {
      final (name, inner, key) = shared;
      if ((_owners[name] ?? key) == key) {
        _owners[name] = key;
        _rules.putIfAbsent(name, () => (layer, inner));
        _recording?.addClass(name, layer, inner, key);
        return name;
      }
    }
    // Named on this page (a new style, or a hash collision): another page
    // could name it otherwise, so a fragment using it isn't kept yet.
    _recording?.replayable = false;
    // The key uses the raw values: sanitizing is deterministic, so equal raw
    // styles still get equal names.
    final key = _rawKey(layer, css, conditions);
    final name = _names[key] ??= _nameFor(key);
    if (!_rules.containsKey(name)) {
      final inner = _renderInner(name, css, conditions);
      _rules[name] = (layer, inner);
      if (_shared.length < _sharedLimit && !_sharedNames.contains(name)) {
        _shared[_StyleKey.copy(layer, css, conditions)] = (name, inner, key);
        _sharedNames.add(name);
      }
    }
    return name;
  }

  // Style → (class name, rule text, string key), shared by every render of
  // this isolate. Bounded: styles built from data (a width per item) must
  // not grow it forever.
  static final _shared = <_StyleKey, (String, String, String)>{};
  static final _sharedNames = <String>{};
  static const _sharedLimit = 20000;

  final _names = <String, String>{};

  /// Named classes of this page (debug): (name, style key) → class.
  final _named = <(String, String), String>{};

  String _namedClass(
    String name,
    CssDeclarations css,
    List<ConditionalCss> conditions,
    ThorLayer layer,
  ) {
    final key = _rawKey(layer, css, conditions);
    final known = _named[(name, key)];
    if (known != null) return known;
    // The same name on a style with other content (the style on a Column
    // and on a Row): a numbered class, never another style's rules.
    var candidate = name;
    for (
      var n = 2;
      _rules.containsKey(candidate) || (_owners[candidate] ?? key) != key;
      n++
    ) {
      candidate = '$name-$n';
    }
    _owners[candidate] = key;
    _rules[candidate] = (layer, _renderInner(candidate, css, conditions));
    return _named[(name, key)] = candidate;
  }

  /// Which style key owns each generated name (server side), to detect hash
  /// collisions.
  final _owners = <String, String>{};

  /// A content-hash name for [key]. Two different styles can share a 32-bit
  /// hash (≈1 in 10^4 pages with 1,000 rules); instead of silently giving the
  /// second element the first one's styles, the name is re-hashed with a salt
  /// until it is free. Deterministic: the same render order gives the same
  /// names.
  String _nameFor(String key) {
    var name = 't${stableHash(key)}';
    for (var salt = 1; ; salt++) {
      final owner = _owners[name];
      if (owner == null) {
        if (!_rules.containsKey(name)) _owners[name] = key;
        return name;
      }
      if (owner == key) return name;
      name = 't${stableHash('$key\u0004$salt')}';
    }
  }

  static String _rawKey(
    ThorLayer layer,
    CssDeclarations css,
    List<ConditionalCss> conditions,
  ) {
    final b = StringBuffer()..write(layer.index);
    void add(CssDeclarations d) {
      for (final e in d.entries) {
        b
          // Control characters: never part of a CSS name or a sane value,
          // so different styles can't produce the same key.
          ..write('\u0001')
          ..write(e.key)
          ..write('\u0002')
          ..write(e.value);
      }
    }

    add(css);
    for (final c in conditions) {
      b
        ..write('\u0003')
        ..write(c.when);
      add(c.css);
    }
    return b.toString();
  }

  static String _renderInner(
    String className,
    CssDeclarations css,
    List<ConditionalCss> conditions, {
    bool foldScheme = true,
  }) {
    // Colors that change with the theme go in the base rule as
    // `light-dark()`: no dark rules (the page sets `color-scheme`).
    if (foldScheme) (css, conditions) = foldSchemeColors(css, conditions);
    final selector = '.$className';
    final body = cssInline(css);
    final rule = StringBuffer();
    if (body.isNotEmpty) rule.write('$selector{$body}');
    for (final c in conditions) {
      rule.write(c.when._wrap(selector, cssInline(c.css)));
    }
    assert(
      _noAdaptiveMarkers(rule.toString()),
      'An adaptive value (`.when()`) reached the CSS of .$className '
      'unresolved: $rule',
    );
    return rule.toString();
  }

  // The characters that mark a value with variants (`Adaptable.when`):
  // `expandAdaptive` turns them into conditions, none may reach the page.
  static bool _noAdaptiveMarkers(String css) =>
      !css.contains(RegExp('[\u27e6\u27e7\u241f\u241e]'));

  /// Renders the rule block for [className] (one `@layer` rule, so it can be
  /// inserted with a single `insertRule`).
  static String renderRule(
    String className,
    CssDeclarations css, {
    List<ConditionalCss> conditions = const [],
    ThorLayer layer = ThorLayer.props,
  }) =>
      // Without a registry nothing sets the page's `color-scheme`: dark
      // rules stay rules.
      '@layer ${layer.cssName}{${_renderInner(className, css, conditions, foldScheme: false)}}';

  /// Whether this server registry was already written to the document; later
  /// elements (e.g. from async components) fall back to inline styles.
  bool get flushed => _flushed;

  /// Number of distinct classes registered so far.
  int get ruleCount => _rules.length;

  /// All rules, with the layer order declared up front.
  /// Rules are grouped in one block per layer (order within a layer is
  /// registration order, so conditions still follow their base rule).
  final _pageRules = <String>[];

  /// The theme variables this page defines (`--t-primary`…): a widget's
  /// `var(--t-primary, #6750a4)` needs no fallback then.
  Set<String> _themeVars = const {};

  /// The theme's text role variables (`--t-title-large-size`…): only
  /// thor's classes read them, so a page publishes the ones it reads.
  Set<String> _textVars = const {};

  // The theme's faces that ask for a preload (`FontFace.preload`).
  List<FontFace> _fontPreloads = const [];
  List<FontFace> _fontFaces = const [];

  /// The faces of the theme that ask for a `preload` and that this page's
  /// CSS uses: the family named in a `font-family` (the theme's stack on
  /// `:root`, a `TextStyle.fontFamily`, in any variant: hover, breakpoint,
  /// a dialog or popover drawn in the page) and, when the family has more
  /// than one face, a `font-weight` (and `font-style`) the face covers. A
  /// preload nothing uses is a console warning and a wasted request.
  ///
  /// The head's `<link rel=preload>` and the `Link` header come from this
  /// one list. Read it after the page is drawn.
  List<FontFace> get fontPreloads {
    final wanted = _fontPreloads;
    if (wanted.isEmpty) return const [];
    final css = StringBuffer();
    for (final rule in _pageRules) {
      css.write(rule.replaceAll(_fontFaceRule, ''));
    }
    for (final (_, inner) in _rules.values) {
      css.write(inner);
    }
    for (final module in _modules) {
      css.write(module.css);
    }
    return usedFontFaces(
      wanted,
      _fontFaces,
      breakpoints.resolve(css.toString()),
    );
  }

  static final _fontFaceRule = RegExp(r'@font-face\s*\{[^}]*\}');

  final _imagePreloads = <ImagePreload>{};

  /// The page's main images (`Image(priority: true)`), in order: preloaded
  /// in its `<head>`, and what a server renderer reports for the `Link`
  /// header.
  List<ImagePreload> get imagePreloads => _imagePreloads.toList();

  /// Preloads [image] (once).
  void addImagePreload(ImagePreload image) {
    _recording?.imagePreloads.add(image);
    _imagePreloads.add(image);
  }

  /// The widths `CssCondition.breakpoint` resolves to (the app theme's).
  Breakpoints breakpoints = const Breakpoints();

  /// The whole stylesheet: layer order, page rules, class rules, keyframes.
  ///
  /// A server renders the same pages over and over: in release the text is
  /// kept per process, keyed by what it is made of (class names are content
  /// hashes there), so the regex passes below run once per distinct page.
  String get cssText {
    if (kDebugMode) return _cssText();
    // What the text is made of, as parts (the same string instances page
    // after page, their hashes cached): no page-sized string joined and
    // hashed per request.
    final key = _CssKey([
      _pageRules.length,
      ..._pageRules,
      _rules.length,
      ..._rules.keys,
      _keyframes.length,
      for (final MapEntry(:key, :value) in _keyframes.entries) ...[key, value],
      _properties.length,
      for (final MapEntry(:key, :value) in _properties.entries) ...[key, value],
      _ThemeVarsKey(_themeVars),
      _appReads.length,
      ...breakpoints.widths,
      _linked?.href,
      _transition,
      _switchers.length,
      ..._switchers,
    ]);
    // A name is a content hash, but a rare collision is salted per page:
    // the rules themselves must match too (the same strings, from the
    // shared cache, so `==` returns at the identity check).
    final rules = [for (final (_, inner) in _rules.values) inner];
    final cached = _cssTexts[key];
    if (cached != null && _sameRules(cached.rules, rules)) return cached.css;
    // Bounded: pages whose classes come from data must not grow it forever.
    if (_cssTexts.length >= 512) _cssTexts.clear();
    final css = _cssText();
    _cssTexts[key] = (rules: rules, css: css);
    return css;
  }

  static final _cssTexts = <_CssKey, ({List<String> rules, String css})>{};

  static bool _sameRules(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// [transition]: the page's transition rules (per page: never part of a
  /// shared base sheet made from the specimens), and the theme's text role
  /// variables no rule of the page reads left out (a shared sheet keeps
  /// them all: it serves every page).
  String _cssText({bool transition = true}) {
    final out = StringBuffer(thorLayerOrder);
    final classes = StringBuffer();
    final linked = _linked;
    // What the linked sheet already holds: the same name for the same
    // style (a name it owns with another style was renamed on this page).
    bool shipped(String name) =>
        linked != null &&
        linked._classes[name] != null &&
        linked._classes[name] == _owners[name];
    for (final layer in ThorLayer.values) {
      // One at-rule per condition (`@media X{.a{…}.b{…}}`), not one per
      // class. Breakpoints are resolved first: their placeholders hold
      // braces.
      final rules = [
        for (final MapEntry(key: name, value: (l, inner)) in _rules.entries)
          if (l == layer && !shipped(name))
            flattenRules(splitCssStatements(breakpoints.resolve(inner))),
      ];
      if (rules.isNotEmpty) {
        classes.write(
          '@layer ${layer.cssName}{${dropThemeFallbacks(groupClassRules(rules), _themeVars)}}',
        );
      }
    }
    final after = StringBuffer(classes);
    // Per page (a route may choose its own): never in a shared sheet.
    if (transition) {
      if (_transition?.css case final rules?) after.write(rules);
      if (_switchers.isNotEmpty) after.write(switcherCss(_switchers));
    }
    for (final e in _keyframes.entries) {
      if (linked?._keyframes[e.key] == e.value) continue;
      after.write('@keyframes ${e.key}{${e.value}}');
    }
    for (final e in _properties.entries) {
      if (linked?._properties[e.key] == e.value) continue;
      after.write('${e.key}{${e.value}}');
    }
    // Page-wide rules (the app theme on :root/body): below the classes, so
    // widget props and app stylesheets both override them.
    if (_pageRules.isNotEmpty && _pageRules.join() != linked?._tokens) {
      var tokens = _pageRules.join();
      if (transition && _textVars.isNotEmpty) {
        final text = after.toString();
        // What reads a variable: the page's rules, the theme's own rules
        // (`body` reads bodyMedium), the app and module stylesheets. A
        // shared class the linked sheet holds reads its own copy.
        final read = {
          ..._appReads,
          ...readVariables(text),
          ...readVariables(tokens),
          if (linked != null) ...readVariables(linked.css),
        };
        // Resolved first: a breakpoint placeholder holds braces.
        tokens = dropVariables(breakpoints.resolve(tokens), {
          for (final v in _textVars)
            if (!read.contains(v)) v,
        });
      }
      out.write('@layer $thorTokensLayer{$tokens}');
    }
    out.write(after);
    return breakpoints.resolve(out.toString());
  }

  /// The registry to write to at [context], or null when styles must be
  /// inlined: no ThorApp, or a server render that already flushed its
  /// stylesheet (late async components).
  static ThorStyleRegistry? active(BuildContext context) {
    final registry = of(context);
    if (registry == null || registry.flushed) return null;
    return registry;
  }

  /// Class name + rule text for the no-ThorApp fallback (scoped `<style>`);
  /// the name only depends on the content, so equal widgets share it.
  static ({String className, String rules}) local(
    CssDeclarations css, {
    List<ConditionalCss> conditions = const [],
    ThorLayer layer = ThorLayer.props,
  }) {
    final key = StringBuffer('${layer.index}|${cssInline(css)}');
    for (final c in conditions) {
      key.write('|${c.when}|${cssInline(c.css)}');
    }
    final name = 'tl${stableHash(key.toString())}';
    return (
      className: name,
      rules: const Breakpoints().resolve(
        renderRule(name, css, conditions: conditions, layer: layer),
      ),
    );
  }

  /// The registry that applies at [context], if class extraction is on.
  static ThorStyleRegistry? of(BuildContext context) {
    // An app component's build that uses the page's registry is built only
    // at its place, never previewed.
    notePageAccess();
    final scope =
        context
                .getElementForInheritedWidgetOfExactType<_ThorStyleScope>()
                ?.widget
            as _ThorStyleScope?;
    return scope?.registry;
  }

  /// 32-bit FNV-1a with shift-based multiplication, so the result is
  /// identical on the Dart VM (server) and in JavaScript (dart2js), where
  /// plain `*` loses precision above 2^53.
  static String stableHash(String input) {
    var h = 0x811c9dc5;
    for (final c in input.codeUnits) {
      h = (h ^ c) & 0xFFFFFFFF;
      h =
          (h +
              ((h << 1) & 0xFFFFFFFF) +
              ((h << 4) & 0xFFFFFFFF) +
              ((h << 7) & 0xFFFFFFFF) +
              ((h << 8) & 0xFFFFFFFF) +
              ((h << 24) & 0xFFFFFFFF)) &
          0xFFFFFFFF;
    }
    return h.toRadixString(36);
  }
}

/// A style as a map key compared entry by entry (in order, like the string
/// key): cheaper than building that string when the lookup hits.
final class _StyleKey {
  _StyleKey(this.layer, this.css, this.conditions)
    : hashCode = _hash(layer, css, conditions);

  /// A key that owns its maps (callers may reuse theirs).
  _StyleKey.copy(
    ThorLayer layer,
    CssDeclarations css,
    List<ConditionalCss> conditions,
  ) : this(layer, Map.of(css), [
        for (final c in conditions) ConditionalCss(c.when, Map.of(c.css)),
      ]);

  final ThorLayer layer;
  final CssDeclarations css;
  final List<ConditionalCss> conditions;

  @override
  final int hashCode;

  static int _hash(
    ThorLayer layer,
    CssDeclarations css,
    List<ConditionalCss> conditions,
  ) {
    var h = layer.index;
    void add(CssDeclarations d) {
      for (final e in d.entries) {
        h = Object.hash(h, e.key, e.value);
      }
    }

    add(css);
    for (final c in conditions) {
      h = Object.hash(h, c.when._kind, c.when._value);
      add(c.css);
    }
    return h;
  }

  static bool _same(CssDeclarations a, CssDeclarations b) {
    if (a.length != b.length) return false;
    final other = b.entries.iterator;
    for (final e in a.entries) {
      other.moveNext();
      if (e.key != other.current.key || e.value != other.current.value) {
        return false;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    if (other is! _StyleKey ||
        other.hashCode != hashCode ||
        other.layer != layer ||
        other.conditions.length != conditions.length ||
        !_same(css, other.css)) {
      return false;
    }
    for (var i = 0; i < conditions.length; i++) {
      final a = conditions[i], b = other.conditions[i];
      if (a.when._kind != b.when._kind ||
          a.when._value != b.when._value ||
          !_same(a.css, b.css)) {
        return false;
      }
    }
    return true;
  }
}

const _styleId = 'thor-styles';
const _spriteId = 'thor-sprite';

class _ThorStyleScope extends InheritedWidget implements InheritedMemoKey {
  const _ThorStyleScope({required this.registry, required super.child});

  final ThorStyleRegistry registry;

  @override
  bool updateShouldNotify(covariant _ThorStyleScope oldComponent) =>
      !identical(oldComponent.registry, registry);

  // Every page has its registry; what a subtree registers in it is
  // recorded and replayed (FragmentRecord), so readers are alike.
  @override
  Object? get memoKey => _ThorStyleScope;
}

/// Root of a thor app, like `MaterialApp`: turns widget styles into
/// deduplicated, conditional stylesheets instead of inline `style` attributes.
///
/// On the server the collected rules are written into `<head>` once the tree
/// is built; in the browser new rules are inserted at runtime. Without a
/// ThorApp, widgets fall back to inline styles (and local `<style>` tags for
/// conditional rules), so everything still works, just less compactly.
class ThorApp extends StatelessWidget implements ThorBuiltIn {
  /// Wraps [child] with style extraction, like `MaterialApp` wraps an app.
  const ThorApp({
    super.key,
    required this.child,
    this.extractStyles = true,
    this.engineLoading = EngineLoading.onIdle,
    this.engineSrc = 'engine.dart.js',
    this.theme,
    this.darkTheme,
    this.highContrastTheme,
    this.highContrastDarkTheme,
    this.themeMode = ThemeMode.system,
    this.themeToggleLabel,
    this.navigation,
    this.locale,
    this.supportedLocales = const [Locale('en', 'US')],
    this.localizationsDelegates,
    this.localeResolutionCallback,
    this.localeListResolutionCallback,
    this.styles = const [],
    this.serverMessages = const ServerMessages(),
    this.callTimeout = const Duration(seconds: 30),
  }) : routerConfig = null,
       localeStrategy = LocaleStrategy.prefix,
       localeCookieName = 'locale',
       defaultLocale = null,
       localeBaseUrl = null;

  /// An app with routes, like `MaterialApp.router`: one value, declared
  /// once (top level), that the server reads when it starts. A request
  /// resolves its locale from [supportedLocales] and [localeStrategy]
  /// (the URL prefix, the [localeCookieName] cookie, `Accept-Language`),
  /// then matches [routerConfig], runs its middleware and loads, and draws
  /// the page inside this app ([page]): theme, locale, navigation and
  /// [styles] set here only.
  ///
  /// ```dart
  /// final app = ThorApp.router(
  ///   routerConfig: router,
  ///   supportedLocales: const [Locale('es'), Locale('en')],
  ///   localeStrategy: LocaleStrategy.prefixExceptDefault,
  ///   theme: appTheme,
  ///   styles: appStyles,
  /// );
  ///
  /// void main() => runApp(app);
  /// ```
  const ThorApp.router({
    super.key,
    required ThorRouter this.routerConfig,
    this.extractStyles = true,
    this.engineLoading = EngineLoading.onIdle,
    // web: from the site root, where `thor build` writes it: a relative
    // URL would resolve under a nested route (`/article/engine.dart.js`).
    this.engineSrc = '/engine.dart.js',
    this.theme,
    this.darkTheme,
    this.highContrastTheme,
    this.highContrastDarkTheme,
    this.themeMode = ThemeMode.system,
    this.themeToggleLabel,
    this.navigation,
    this.locale,
    this.supportedLocales = const [Locale('en', 'US')],
    this.localizationsDelegates,
    this.localeResolutionCallback,
    this.localeListResolutionCallback,
    this.styles = const [],
    this.localeStrategy = LocaleStrategy.prefix,
    this.localeCookieName = 'locale',
    this.defaultLocale,
    this.localeBaseUrl,
    this.serverMessages = const ServerMessages(),
    this.callTimeout = const Duration(seconds: 30),
  }) : child = const _NoPage();

  /// The routes of an app made with [ThorApp.router]; null otherwise.
  final ThorRouter? routerConfig;

  /// The texts of the errors of `query` and `command` calls, in the app's
  /// language (English by default): the server writes its own answers with
  /// them and puts the browser's (no network, a timeout) in each page that
  /// has server calls, so the client never carries a string. `// web:` no
  /// Flutter counterpart.
  final ServerMessages serverMessages;

  /// How long a `query` or `command` call waits for the server before it
  /// ends in an error of kind `ServerErrorKind.timeout` (30 s by default: a
  /// call that hangs is a bug, not a wait; fetch has no limit of its own).
  /// A call's own `timeout:` wins; [Duration.zero] means no limit. Only a
  /// value other than the default travels in the page. `// web:` no Flutter
  /// counterpart.
  final Duration callTimeout;

  /// The app's own stylesheet (`css('body')…`: the page basics no widget
  /// covers), in every page, like the theme. A route group's CSS is
  /// `Group(styles:)`. Read by the renderer (`WidgetRenderer.router`).
  final List<StyleRule> styles;

  /// Where a routed app's locale is in the URL (with more than one of
  /// [supportedLocales]). `// web:` no Flutter counterpart.
  final LocaleStrategy localeStrategy;

  /// The cookie that remembers a visitor's choice (`LocaleSwitcher`).
  final String localeCookieName;

  /// The locale without a prefix (`LocaleStrategy.prefixExceptDefault`)
  /// and the fallback; `null`: the first of [supportedLocales].
  final Locale? defaultLocale;

  /// The site's origin, for absolute `hreflang` links.
  final String? localeBaseUrl;

  /// The routes the server serves ([routerConfig]).
  List<RouteNode<Widget>> get routes =>
      (routerConfig ??
              (throw StateError(
                'ThorApp.router(routerConfig:) has the routes',
              )))
          .routes;

  /// How a routed app's locales map to URLs: `null` with one locale.
  LocaleRouting? get localeRouting {
    if (routerConfig == null || supportedLocales.length < 2) return null;
    return LocaleRouting(
      supportedLocales: supportedLocales,
      defaultLocale: defaultLocale ?? supportedLocales.first,
      strategy: localeStrategy,
      cookieName: localeCookieName,
      baseUrl: localeBaseUrl,
    );
  }

  /// This app around [page]: what the renderer draws each page in.
  ThorApp page(Widget page) => ThorApp(
    key: key,
    extractStyles: extractStyles,
    engineLoading: engineLoading,
    engineSrc: engineSrc,
    theme: theme,
    darkTheme: darkTheme,
    highContrastTheme: highContrastTheme,
    highContrastDarkTheme: highContrastDarkTheme,
    themeMode: themeMode,
    themeToggleLabel: themeToggleLabel,
    navigation: navigation,
    locale: locale,
    supportedLocales: supportedLocales,
    localizationsDelegates: localizationsDelegates,
    localeResolutionCallback: localeResolutionCallback,
    localeListResolutionCallback: localeListResolutionCallback,
    styles: styles,
    serverMessages: serverMessages,
    callTimeout: callTimeout,
    child: page,
  );

  /// Like `MaterialApp.locale`: the app's locale whatever the visitor
  /// prefers (resolved against [supportedLocales]). `null`: the visitor's
  /// (`// web:` the request's locale, `RouteHandler(locales:)`, or
  /// `THOR_LOCALE` in a static pre-render), else the first supported one.
  final Locale? locale;

  /// Like `MaterialApp.supportedLocales` (`AppLocalizations.supportedLocales`).
  final List<Locale> supportedLocales;

  /// Like `MaterialApp.localizationsDelegates`
  /// (`AppLocalizations.localizationsDelegates`). With it (or [locale]) the
  /// app sets `<html lang>` and `dir` from its locale.
  final List<LocalizationsDelegate<Object?>>? localizationsDelegates;

  /// Like `MaterialApp.localeResolutionCallback`.
  final LocaleResolutionCallback? localeResolutionCallback;

  /// Like `MaterialApp.localeListResolutionCallback` (asked first).
  final LocaleListResolutionCallback? localeListResolutionCallback;

  /// The locale the page renders in (Flutter's `WidgetsApp` resolution).
  Locale _resolveLocale(BuildContext context) {
    if (supportedLocales.isEmpty) {
      throw ArgumentError.value(
        supportedLocales,
        'supportedLocales',
        'must not be empty',
      );
    }
    final preferred = locale != null
        ? [locale!]
        : PreferredLocales.maybeOf(context);
    if (localeListResolutionCallback case final resolve?) {
      final chosen = resolve(preferred, supportedLocales);
      if (chosen != null) return chosen;
    }
    if (localeResolutionCallback case final resolve?) {
      final chosen = resolve(preferred?.firstOrNull, supportedLocales);
      if (chosen != null) return chosen;
    }
    return basicLocaleListResolution(preferred, supportedLocales);
  }

  /// How the browser moves between the app's pages: links fetched ahead
  /// (Speculation Rules) and view transitions, no JavaScript. `null`: a
  /// routed page (`WidgetRenderer`) gets `const PageNavigation()`, prefetch
  /// on hover; a single-document app gets nothing. Opt out with
  /// [PageNavigation.none].
  ///
  /// `// web:` no Flutter counterpart (a Flutter app is one document).
  final PageNavigation? navigation;

  /// The app's theme, like `MaterialApp.theme`: its roles become CSS
  /// variables on `:root` (`--t-primary`…) and the page background/text use
  /// `surface`/`onSurface`. `Theme.of(context)` returns it.
  final ThemeData? theme;

  /// Like `MaterialApp.darkTheme`. With [ThemeMode.system] it applies when
  /// the system prefers dark, and the page gets a no-JS theme switch
  /// (`ThemeToggle`) that flips it.
  final ThemeData? darkTheme;

  /// Like `MaterialApp.highContrastTheme`: the theme for visitors who asked
  /// for more contrast. `// web:` it is published as the variables that
  /// differ from [theme], under `@media (prefers-contrast: more)` (CSS, no
  /// JS). Without it, [theme] stays as it is. `// web:` with no [theme] (so
  /// no theme variables on the page) it has nothing to differ from and is
  /// ignored; give a [theme] too.
  final ThemeData? highContrastTheme;

  /// Like `MaterialApp.highContrastDarkTheme`: [darkTheme] for visitors who
  /// asked for more contrast. Without it the dark theme is unchanged.
  final ThemeData? highContrastDarkTheme;

  /// Like `MaterialApp.themeMode`.
  final ThemeMode themeMode;

  /// `// web:` the accessible name of the page's theme switch (the hidden
  /// checkbox a `ThemeToggle` labels, with a [darkTheme]). `null`: in the
  /// page's language (`<html lang>`), Spanish or else English.
  final String? themeToggleLabel;

  // Visually hidden but focusable: the checkbox is the switch's control.
  static const _srOnly =
      'position:absolute;width:1px;height:1px;margin:-1px;overflow:hidden;'
      'clip:rect(0,0,0,0);white-space:nowrap;border:0';

  // A server renders the same theme on every request (an app-level `final`):
  // its page rules are built once per isolate.
  static ({
    ThemeData? light,
    ThemeData? dark,
    ThemeData? highLight,
    ThemeData? highDark,
    ThemeMode mode,
    List<String> rules,
    Set<String> vars,
    Set<String> textVars,
  })?
  _lastTheme;

  void _publishTheme(ThorStyleRegistry registry) {
    final light = theme, dark = darkTheme;
    final base = themeMode == ThemeMode.dark && dark != null ? dark : light;
    if (base == null) return;
    registry
      ..breakpoints = base.breakpoints
      .._fontFaces = base.fonts
      .._fontPreloads = [
        for (final f in base.fonts)
          if (f.preload) f,
      ];
    final last = _lastTheme;
    if (last != null &&
        identical(last.light, light) &&
        identical(last.dark, dark) &&
        identical(last.highLight, highContrastTheme) &&
        identical(last.highDark, highContrastDarkTheme) &&
        last.mode == themeMode) {
      registry
        .._pageRules.addAll(last.rules)
        .._themeVars = last.vars
        .._textVars = last.textVars;
      return;
    }
    final rules = _themeRules(base, dark);
    // Every variable the page defines on :root (the dark theme and the
    // breakpoint type scale redefine the same names).
    final textVars = base.textTheme.toCssVariables().keys.toSet()
      // An app color token of the same name is the app's.
      ..removeAll(base.toCssVariables().keys);
    final vars = {...base.toCssVariables().keys, ...textVars};
    _lastTheme = (
      light: light,
      dark: dark,
      highLight: highContrastTheme,
      highDark: highContrastDarkTheme,
      mode: themeMode,
      rules: rules,
      vars: vars,
      textVars: textVars,
    );
    registry
      .._pageRules.addAll(rules)
      .._themeVars = vars
      .._textVars = textVars;
  }

  // The variables of the `:root` rule. With a light and a dark theme: one
  // list, each color that changes is `light-dark(light, dark)`. The dark
  // rule keeps what isn't a color, `color-scheme: dark` among it: that is
  // what picks the side of every `light-dark()` (and of the browser's own
  // controls).
  ({Map<String, String> rootVars, Map<String, String> darkOnly}) _variables(
    ThemeData base,
    ThemeData? dark,
  ) {
    final rootVars = {
      ...base.toCssVariables(),
      ...base.textTheme.toCssVariables(),
    };
    final schemed = themeMode == ThemeMode.system && dark != null;
    final darkOnly = <String, String>{};
    if (schemed) {
      final colors = {
        ...dark.colorScheme.toCssVariables().keys,
        for (final k in dark.colorTokens.keys) '--t-$k',
      }..remove('color-scheme');
      final darkVars = {...dark.toCssVariables()};
      // A light scaffold color with none in the dark theme: the dark one is
      // its surface, as in Flutter, not the light color.
      if (base.scaffoldBackgroundColor != null &&
          dark.scaffoldBackgroundColor == null) {
        if (darkVars['--t-surface'] case final surface?) {
          darkVars['--t-scaffold'] = surface;
        }
      }
      for (final MapEntry(:key, :value) in darkVars.entries) {
        final light = rootVars[key];
        if (light == value) continue;
        if (light != null &&
            (colors.contains(key) ||
                (key.startsWith('--') &&
                    isCssColor(light) &&
                    isCssColor(value)))) {
          rootVars[key] = 'light-dark($light, $value)';
        } else {
          darkOnly[key] = value;
        }
      }
    }
    return (rootVars: rootVars, darkOnly: darkOnly);
  }

  // Whether a theme of the page has its own scaffold color (`--t-scaffold`,
  // maybe only in the dark one).
  static bool _scaffold(ThemeData base, ThemeData? dark) =>
      base.scaffoldBackgroundColor != null ||
      dark?.scaffoldBackgroundColor != null;

  List<String> _themeRules(ThemeData base, ThemeData? dark) {
    String decl(Map<String, String> css) =>
        css.entries.map((e) => '${e.key}:${e.value}').join(';');
    final pageRules = <String>[];
    final (:rootVars, :darkOnly) = _variables(base, dark);
    pageRules
      ..add(':root{${decl(rootVars)}}')
      // The page text is bodyMedium, like Material's DefaultTextStyle.
      ..add(
        // A Flutter app fills the window: no browser margin.
        'body{margin:0;background-color:'
        '${_scaffold(base, dark) ? 'var(--t-scaffold,var(--t-surface))' : 'var(--t-surface)'};'
        'color:var(--t-on-surface);'
        '${decl(base.textTheme.bodyMedium.toCss())}}',
      );
    for (final face in base.fonts) {
      pageRules.add(face.css);
    }
    if (base.scrollbarTheme?.rule case final rule?) pageRules.add(rule);
    if (base.textSelectionTheme case final selection?) {
      final colors = {
        if (selection.selectionColor case final c?) 'background-color': c.css,
        if (selection.selectionTextColor case final c?) 'color': c.css,
      };
      if (colors.isNotEmpty) pageRules.add('::selection{${decl(colors)}}');
      if (selection.cursorColor case final c?) {
        pageRules.add(':root{caret-color:${c.css}}');
      }
    }
    if (base.focusColor case final c?) {
      pageRules.add(
        ':focus-visible{outline:2px solid ${c.css};outline-offset:2px}',
      );
    }
    // Text roles per breakpoint (`textTheme.when(medium: …)`): only the roles
    // that change, on :root, at the theme's widths.
    final textVariants = base.textTheme.variants?.variants ?? const {};
    for (final bp in WindowSizeClass.values) {
      final text = textVariants[bp.name];
      if (text == null) continue;
      final vars = text.diffCssVariables(base.textTheme);
      if (vars.isEmpty) continue;
      pageRules.add(CssCondition.breakpoint(bp)._wrap(':root', decl(vars)));
    }
    if (darkOnly.isNotEmpty) {
      pageRules.add(CssCondition.dark._wrap(':root', decl(darkOnly)));
    }
    // `highContrastTheme` (and its dark one): only the variables that differ,
    // after every other rule so the same specificity lets them win.
    if (highContrastTheme != null || highContrastDarkTheme != null) {
      // In dark mode, `highContrastDarkTheme` wins even with no `darkTheme`
      // (as in Flutter's MaterialApp).
      final hcMain = themeMode == ThemeMode.dark
          ? highContrastDarkTheme ??
                (dark != null ? base : highContrastTheme ?? base)
          : highContrastTheme ?? base;
      final hcDark = themeMode == ThemeMode.system && dark != null
          ? highContrastDarkTheme ?? dark
          : null;
      final hc = _variables(hcMain, hcDark);
      final hcVars = hc.rootVars;
      final changed = {
        for (final MapEntry(:key, :value) in hcVars.entries)
          if (rootVars[key] != value) key: value,
      };
      if (changed.isNotEmpty) {
        pageRules.add(CssCondition.moreContrast._wrap(':root', decl(changed)));
      }
      // The non-color variables of the dark side (text roles…) that differ.
      final changedDark = {
        for (final MapEntry(:key, :value) in hc.darkOnly.entries)
          if (darkOnly[key] != value) key: value,
      };
      if (changedDark.isNotEmpty) {
        pageRules.add(
          CssCondition.both(
            CssCondition.moreContrast,
            CssCondition.dark,
          )._wrap(':root', decl(changedDark)),
        );
      }
    }
    return List.unmodifiable(pageRules);
  }

  /// The app.
  final Widget child;

  /// Whether to extract widget styles into a stylesheet instead of inlining
  /// them.
  final bool extractStyles;

  /// When the engine script runs, on pages that use a `ThorState`.
  final EngineLoading engineLoading;

  /// URL of the compiled engine entry (generated `web/engine.dart`):
  /// `/engine.dart.js` with [ThorApp.router] (the site root, where `thor
  /// build` writes it), `engine.dart.js` next to a single page otherwise.
  /// Set it only to serve the engine from elsewhere (a CDN).
  final String engineSrc;

  @override
  Widget build(BuildContext context) {
    final active = themeMode == ThemeMode.dark ? darkTheme ?? theme : theme;
    final switchable = darkTheme != null && themeMode == ThemeMode.system;
    final appLocale = _resolveLocale(context);
    // The app's texts; the rest in the page's language.
    final messages = serverMessages.forLocale(appLocale);
    final localized = locale != null || localizationsDelegates != null;
    Widget inAppScope(Widget w) {
      final localized = Localizations(
        locale: appLocale,
        delegates: _withDefaultDelegates(localizationsDelegates),
        child: w,
      );
      return active == null
          ? localized
          : Theme.provide(data: active, child: localized);
    }

    final localizedChild = Localizations(
      locale: appLocale,
      delegates: _withDefaultDelegates(localizationsDelegates),
      child: switchable
          // Next to its ThemeToggle label; with none, after the page (last
          // Tab stop).
          ? Widget.fragment([
              child,
              _ThemeSwitch(label: themeToggleLabel, locale: appLocale),
            ])
          : child,
    );
    final app = Widget.fragment([
      if (localized)
        DocumentAttributes(
          attributes: {
            'lang': appLocale.toLanguageTag(),
            'dir': appLocale.textDirection.name,
          },
        ),
      if (active == null)
        localizedChild
      else
        Theme.provide(data: active, child: localizedChild),
    ]);
    if (!extractStyles) return app;
    final registry = ThorStyleRegistry.server();
    if (SharedStylesScope.maybeOf(context) case final shared?) {
      if (shared.sheet case final sheet?) registry.link(sheet);
      registry._moduleFiles = shared.files;
      registry._errorFocusAllowed = shared.errorFocus;
      shared.capture?.call(registry);
    }
    _publishTheme(registry);
    final nav =
        navigation ??
        (RoutedPageScope.isRouted(context) ? const PageNavigation() : null);
    registry._transition = nav?.pageTransition;
    return _ThorStyleScope(
      registry: registry,
      child: Widget.fragment([
        app,
        // web: inside the app's theme and language: the page's snack bar
        // takes `ThemeData.snackBarTheme` (behavior, width, close icon) and
        // the close button's name from them, as Flutter's ScaffoldMessenger.
        inAppScope(
          SharedFeedback(registry, messages, FlashScope.maybeOf(context)),
        ),
        _StyleFlush(
          registry,
          engineLoading,
          engineSrc,
          nav?.speculationRules,
          // Only a routed app serves the file (`WidgetRenderer.asset`).
          nav?.speculationRules != null && RoutedPageScope.isRouted(context)
              ? prefetchFallbackPath(nav!)
              : null,
          nav?.prefetchFallback == true,
          messages,
          callTimeout,
          switchable,
        ),
      ]),
    );
  }
}

/// Where [nav]'s prefetch fallback file is served (named by its content),
/// or `null` when it has none ([PageNavigation.prefetchFallbackScript]).
String? prefetchFallbackPath(PageNavigation nav) {
  final script = nav.prefetchFallbackScript;
  if (script == null) return null;
  // Every page asks, with the navigation's one (kept) script: hashed once,
  // not on every request.
  if (!identical(script, _lastFallbackScript)) {
    _lastFallbackPath =
        '/_thor/prefetch.${ThorStyleRegistry.stableHash(script)}.js';
    _lastFallbackScript = script;
  }
  return _lastFallbackPath;
}

String? _lastFallbackScript;
String? _lastFallbackPath;

Widget _stylesheet(String href) => Widget.element(
  tag: 'link',
  attributes: {'rel': 'stylesheet', 'href': href},
);

/// Built after the app (last sibling), so every element has registered its
/// rules by then.
class _StyleFlush extends StatelessWidget implements ThorBuiltIn {
  const _StyleFlush(
    this.registry,
    this.engineLoading,
    this.engineSrc,
    this.speculationRules,
    this.prefetchFallbackSrc,
    this.prefetchFallbackAlways,
    this.serverMessages,
    this.callTimeout,
    this.themeSwitch,
  );

  final ThorStyleRegistry registry;
  final bool themeSwitch;
  final EngineLoading engineLoading;
  final String engineSrc;
  final String? speculationRules;
  final String? prefetchFallbackSrc;

  /// `PageNavigation(prefetchFallback: true)`: the loader also on a page
  /// without the engine.
  final bool prefetchFallbackAlways;
  final ServerMessages serverMessages;
  final Duration callTimeout;

  @override
  Widget build(BuildContext context) {
    registry._flushed = true;
    registry._engineScript = () =>
        EngineScript(src: engineSrc, loading: engineLoading);
    registry._fallbackScript = () => engineLoading == EngineLoading.eager
        // A strict CSP allows no inline test: the plain deferred script.
        ? EngineScript(src: engineSrc, loading: engineLoading)
        : EngineScript.ifNoNativeCarousel(src: engineSrc);
    // The head and the end of the body are written from here: what the
    // registry holds now is what the document carries.
    // The prefetch fallback's test: on a page that ships JavaScript anyway
    // (the engine), or where the app asked for it. A page without the engine
    // stays script-free; one that gets the engine late (a streamed
    // part) brings the test with it ([ThorStyleRegistry.takeLate]).
    final prefetchSrc = prefetchFallbackSrc;
    final loader = prefetchSrc == null
        ? null
        : () => Widget.element(
            tag: 'script',
            attributes: {prefetchSrcAttr: prefetchSrc},
            children: const [RawText(prefetchLoaderScript)],
          );
    final loaderHere =
        loader != null && (prefetchFallbackAlways || registry.usesEngine);
    registry._prefetchLoader = loaderHere ? null : loader;
    registry.markShipped();
    final headEnd = Document.head(
      children: [
        for (final font in registry.fontPreloads)
          Widget.element(
            tag: 'link',
            attributes: {
              'rel': 'preload',
              'href': font.url,
              'as': 'font',
              'type': font.mimeType,
              'crossorigin': '',
            },
          ),
        for (final image in registry._imagePreloads)
          Widget.element(tag: 'link', attributes: image.attributes),
        // The shared files first, root module last: the page's own rules
        // come after them, like the inline ones they replace.
        if (registry._linked case final sheet?) _stylesheet(sheet.href),
        for (final module in registry._modules)
          registry._moduleFiles
              ? _stylesheet(module.href)
              : Widget.element(tag: 'style', children: [RawText(module.css)]),
        Widget.element(
          tag: 'style',
          id: _styleId,
          children: [RawText(registry.cssText)],
        ),
        // JSON the browser reads, not code it runs: a page without state
        // still ships no JS.
        if (speculationRules case final rules?)
          Widget.element(
            tag: 'script',
            attributes: const {'type': 'speculationrules'},
            children: [RawText(rules)],
          ),
        // Where the browser has no rules: a constant test that loads the
        // prefetch fallback (`/_thor/prefetch.<hash>.js`) after `load`.
        if (loaderHere) loader(),
        // The slide's back direction (PageTransition.script): the one page
        // script a transition needs, only on a page that slides.
        if (registry._transition?.script case final script?)
          Widget.element(tag: 'script', children: [RawText(script)]),
        if (kDebugMode)
          const Widget.element(
            tag: 'script',
            id: 'thor-debug-inspector',
            children: [RawText(debugInspectorScript)],
          ),
        if (registry.usesEngine)
          EngineScript(src: engineSrc, loading: engineLoading)
        else if (registry._carouselControls)
          registry._fallbackScript!(),
      ],
    );
    final head = themeSwitch
        ? Widget.fragment([
            // First in the head, before the app's own links: it sets the
            // switch before the first paint (see the script), and an inline
            // script after an external stylesheet (the app's fonts) would
            // wait for it, holding the parser until it arrives.
            const HeadPortal(
              leading: true,
              children: [
                Widget.element(tag: 'script', children: [RawText(themeScript)]),
              ],
            ),
            headEnd,
          ])
        : headEnd;
    // Only fields the server changed: the browser starts from the code's
    // values anyway.
    final json = stateJson(registry.usedStates);
    // The queries this page drew (`!q`, never an id: no state has that
    // name): a command's request names them, whether or not their state has
    // woken up in the browser, so the server refreshes those and not the
    // ones another visitor's page draws.
    final drawn = ServerQuery.of(registry.usedStates).keys.toList();
    if (drawn.isNotEmpty) json['!q'] = drawn;
    // The same for the texts of the errors the browser finds itself: the
    // app's (`ThorApp(serverMessages:)`), only where the page has queries or
    // commands (`!m`).
    if (drawn.isNotEmpty ||
        ServerCommandBase.of(registry.usedStates).isNotEmpty) {
      json['!m'] = serverMessages.toPage();
      // The default (30 s) is in the browser's code: only a change is sent.
      if (callTimeout != const Duration(seconds: 30)) {
        // setTimeout holds 2^31-1 ms; a negative one is none, and less than
        // a millisecond is one (inMilliseconds would truncate it to none).
        json['!t'] = callTimeout.isNegative
            ? 0
            : ((callTimeout.inMicroseconds + 999) ~/ 1000).clamp(0, 2147483647);
      }
    }
    final stateScript = json.isEmpty
        ? null
        : Widget.element(
            tag: 'script',
            id: stateScriptId,
            attributes: const {'type': 'application/json'},
            // `<` escaped: no value can close the element.
            children: [
              RawText(encodeStateJson(json).replaceAll('<', r'\u003c')),
            ],
          );
    // After every FlutterView host, so the loader finds them all.
    final flutterLoader = registry.flutterSrc == null
        ? null
        : const Widget.element(
            tag: 'script',
            children: [RawText(flutterLoaderScript)],
          );
    // After the fields it looks for; the engine brings its own copy.
    final validation = registry._validation && !registry.usesEngine
        ? const Widget.element(
            tag: 'script',
            children: [RawText(validationScript)],
          )
        : null;
    // Independent of the engine: it works before it loads and with either.
    final form = registry._formScript
        ? const Widget.element(tag: 'script', children: [RawText(formScript)])
        : null;
    // Before both: a submit it takes is cancelled, and they leave it alone.
    final stay = registry._stayScript
        ? const Widget.element(tag: 'script', children: [RawText(stayScript)])
        : null;
    // Before the form script: the address of a kept result is put back first,
    // so the form script keeps the place as for a same-path answer.
    final upload = registry._uploadScript
        ? const Widget.element(tag: 'script', children: [RawText(uploadScript)])
        : null;
    // The form the `onPost: page.x.bind(…)` buttons submit (`form=`): empty
    // and hidden, it only gives them a POST to send.
    final postForm = registry._postForm
        ? const Widget.element(
            tag: 'form',
            id: postFormId,
            attributes: {'method': 'post', 'hidden': ''},
          )
        : null;
    final sprite = registry.spriteMarkup;
    // After the pieces it watches (end of the body).
    final lazy = registry._lazyScript
        ? const Widget.element(tag: 'script', children: [RawText(lazyScript)])
        : null;
    final permanent = registry._permanentScript
        ? const Widget.element(
            tag: 'script',
            children: [RawText(permanentScript)],
          )
        : null;
    final tail = [
      ?flutterLoader,
      ?validation,
      ?postForm,
      ?stay,
      ?upload,
      ?form,
      ?lazy,
      ?permanent,
    ];
    if (sprite.isEmpty) {
      return stateScript == null && tail.isEmpty
          ? head
          : Widget.fragment([head, ?stateScript, ...tail]);
    }
    // One hidden sprite at the end of <body>: every <use href="#…"> on the
    // page points here, so each icon's paths are shipped once.
    return Widget.fragment([
      head,
      ?stateScript,
      Widget.element(
        tag: 'svg',
        id: _spriteId,
        attributes: const {
          'aria-hidden': 'true',
          'style': 'position:absolute;width:0;height:0;overflow:hidden',
        },
        children: [RawText(sprite)],
      ),
      ...tail,
    ]);
  }
}

/// [css] with its variants (`Adaptable.when`) split into conditions of the
/// same class: breakpoints before [conditions], states (hover…) after them,
/// like `Responsive`, and last the compounds (a hover that changes from a
/// breakpoint up, `md+hover`), which refine both. In a condition's own
/// declarations, breakpoint variants (`ConditionalCss(hover, {color:
/// marked})`) become the same compounds; states in them keep their base.
(CssDeclarations, List<ConditionalCss>) expandAdaptive(
  CssDeclarations css,
  List<ConditionalCss> conditions,
) {
  final hasMarkers =
      css.values.any(isAdaptive) ||
      conditions.any((c) => c.css.values.any(isAdaptive));
  if (!hasMarkers) return (css, conditions);
  final split = splitAdaptive(css);
  // What a condition's own variants add: (width, condition) pairs, applied
  // after the states.
  final refined = <ConditionalCss>[];
  final out = [
    for (final bp in WindowSizeClass.values)
      if (split.byBreakpoint[bp.name] case final changed?)
        ConditionalCss(CssCondition.breakpoint(bp), changed),
    // Container widths (`.when(container: {400: …})`), smallest first.
    for (final e in split.byBreakpoint.entries)
      if (containerWidthOf(e.key) case final w?)
        ConditionalCss(CssCondition.container(w.toDouble()), e.value),
    for (final c in conditions)
      if (c.css.values.any(isAdaptive)) ...[
        () {
          final own = splitAdaptive(c.css);
          for (final bp in WindowSizeClass.values) {
            if (own.byBreakpoint[bp.name] case final changed?) {
              refined.add(
                ConditionalCss(
                  CssCondition.both(CssCondition.breakpoint(bp), c.when),
                  changed,
                ),
              );
            }
          }
          for (final e in own.byBreakpoint.entries) {
            if (containerWidthOf(e.key) case final w?) {
              refined.add(
                ConditionalCss(
                  CssCondition.both(
                    CssCondition.container(w.toDouble()),
                    c.when,
                  ),
                  e.value,
                ),
              );
            }
          }
          return ConditionalCss(c.when, own.base);
        }(),
      ] else
        c,
    // States last: they win over breakpoints, like `Responsive`.
    for (final (state, condition) in _stateConditions)
      if (split.byBreakpoint[state] case final changed?)
        ConditionalCss(condition, changed),
    for (final name in [
      for (final k in split.byBreakpoint.keys) ?groupHoverNameOf(k),
    ]..sort())
      ConditionalCss(
        HoverGroup.hoveredIn(name),
        split.byBreakpoint['$groupHoverKeyPrefix$name']!,
      ),
    ...refined,
    // Compounds of the element's own variants (`md+hover`).
    for (final k in _compounds(split.byBreakpoint.keys))
      if (_compoundCondition(k) case final c?)
        ConditionalCss(c, split.byBreakpoint[k]!),
  ];
  return (split.base, out);
}

// The compound keys of [keys] in the order splitAdaptive wrote them.
List<String> _compounds(Iterable<String> keys) => [
  for (final k in keys)
    if (compoundOf(k) != null) k,
]..sort(compareCompoundKeys);

CssCondition? _compoundCondition(String key) {
  final (width, state) = compoundOf(key)!;
  final CssCondition? at;
  if (containerWidthOf(width) case final w?) {
    at = CssCondition.container(w.toDouble());
  } else {
    final bp = WindowSizeClass.values.where((b) => b.name == width);
    at = bp.isEmpty ? null : CssCondition.breakpoint(bp.first);
  }
  final CssCondition? on = groupHoverNameOf(state) != null
      ? HoverGroup.hoveredIn(groupHoverNameOf(state)!)
      : [
          for (final (name, c) in _stateConditions)
            if (name == state) c,
        ].firstOrNull;
  return at == null || on == null ? null : CssCondition.both(at, on);
}

const _stateConditions = [
  ('dark', CssCondition.dark),
  ('open', CssCondition.detailsOpen),
  ('group-hover', HoverGroup.hovered),
  ('hover', CssCondition.hover),
  ('focused', CssCondition.focused),
  ('focus-within', CssCondition.focusWithin),
  ('disabled', CssCondition.disabled),
  ('pressed', CssCondition.pressed),
];

/// The variables an app or module stylesheet reads (process-wide: those
/// sheets come from the code). A page keeps the theme's text role
/// variables they read ([noteAppStylesheet]).
final _appReads = <String>{};

/// Records what the app stylesheet [css] reads, so every page keeps the
/// theme variables it needs (the theme leaves out the text roles no rule of
/// a page reads).
void noteAppStylesheet(String css) => _appReads.addAll(readVariables(css));

final _varReference = RegExp(r'var\(\s*(--[\w-]+)');

/// The custom properties [css] reads (`var(--name…)`).
Set<String> readVariables(String css) => {
  for (final m in _varReference.allMatches(css)) m[1]!,
};

final _declaration = RegExp(r'(?<=[{;])(--[\w-]+):[^;{}]*;?');
final _emptyRoot = RegExp(r'@media[^{}]*\{:root\{\}\}|:root\{\}');

/// [css] without the declarations of the custom properties in [drop] (and
/// without a `:root` rule left empty).
String dropVariables(String css, Set<String> drop) {
  if (drop.isEmpty) return css;
  final out = css
      .replaceAllMapped(_declaration, (m) => drop.contains(m[1]) ? '' : m[0]!)
      .replaceAll(';}', '}');
  return out.replaceAll(_emptyRoot, '');
}

/// `var(--t-primary, #6750a4)` → `var(--t-primary)` for every variable in
/// [defined]: the page's theme defines it, so the fallback (there for a
/// widget without a theme) is dead weight. Nested fallbacks are kept whole
/// when the outer variable isn't defined.
String dropThemeFallbacks(String css, Set<String> defined) {
  if (defined.isEmpty || !css.contains('var(--')) return css;
  final out = StringBuffer();
  var i = 0;
  while (true) {
    final start = css.indexOf('var(--', i);
    if (start < 0) break;
    final nameEnd = css.indexOf(RegExp(r'[,)\s]'), start + 4);
    if (nameEnd < 0) break;
    final name = css.substring(start + 4, nameEnd);
    if (css[nameEnd] != ',' || !defined.contains(name)) {
      out.write(css.substring(i, nameEnd));
      i = nameEnd;
      continue;
    }
    // Skip the fallback up to this var's closing parenthesis.
    var depth = 1, j = nameEnd + 1;
    for (; j < css.length && depth > 0; j++) {
      if (css[j] == '(') depth++;
      if (css[j] == ')') depth--;
    }
    out
      ..write(css.substring(i, start))
      ..write('var($name)');
    i = j;
  }
  out.write(css.substring(i));
  return out.toString();
}

final _colorValue = RegExp(
  r'^(#[0-9a-f]{3,8}|(rgba?|hsla?|hwb|lab|lch|oklab|oklch|color|color-mix|'
  r'light-dark)\(.*\)|transparent|currentcolor)$',
  caseSensitive: false,
);

/// Whether [value] is written as a color (a hex, a color function,
/// `transparent`, `currentColor`); a `var()` or a keyword is not.
bool isCssColor(String value) => _colorValue.hasMatch(value.trim());

/// [css] with a theme's dark variables folded in: the custom properties of
/// a [CssCondition.dark] condition that also sets `color-scheme` (a
/// `Theme(darkData:)`, whose variables are its whole color scheme) become
/// `light-dark(light, dark)` in the base, and values equal to the base
/// leave the condition. What stays in it (`color-scheme: dark` at least)
/// picks the side of every `light-dark()` below the element.
///
/// Only there: `light-dark()` follows the element's `color-scheme`, which
/// only such a condition is sure to set, and a variable or value an
/// earlier condition sets (a breakpoint) is left alone, since the dark rule
/// used to win over it.
(CssDeclarations, List<ConditionalCss>) foldSchemeColors(
  CssDeclarations css,
  List<ConditionalCss> conditions,
) {
  if (!conditions.any(
    (c) =>
        c.when._kind == _Kind.scheme &&
        c.when._value == 'dark' &&
        c.css.containsKey('color-scheme'),
  )) {
    return (css, conditions);
  }
  final base = Map.of(css);
  final rest = <ConditionalCss>[];
  final setBefore = <String>{};
  for (final c in conditions) {
    if (c.when._kind != _Kind.scheme ||
        c.when._value != 'dark' ||
        !c.css.containsKey('color-scheme')) {
      rest.add(c);
      setBefore.addAll(c.css.keys);
      continue;
    }
    final kept = <String, String>{};
    for (final MapEntry(:key, :value) in c.css.entries) {
      final light = base[key];
      if (setBefore.contains(key) || light == null) {
        kept[key] = value;
      } else if (light == value) {
        // The same in both: the base already says it.
      } else if (key.startsWith('--') &&
          isCssColor(light) &&
          isCssColor(value)) {
        base[key] = 'light-dark($light, $value)';
      } else {
        kept[key] = value;
      }
    }
    if (kept.isNotEmpty) rest.add(ConditionalCss(c.when, kept));
    setBefore.addAll(c.css.keys);
  }
  return (base, rest);
}

/// The parts a page's stylesheet text is made of (`ThorStyleRegistry
/// .cssText`'s cache key): equal parts, equal text.
final class _CssKey {
  _CssKey(this._parts) : hashCode = Object.hashAll(_parts);

  final List<Object?> _parts;

  @override
  final int hashCode;

  @override
  bool operator ==(Object other) {
    if (other is! _CssKey || other.hashCode != hashCode) return false;
    final a = _parts, b = other._parts;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The theme's variables as a key part: the same set whatever its order,
/// and the same instance page after page (compared without copying).
final class _ThemeVarsKey {
  _ThemeVarsKey(this._vars) : hashCode = Object.hashAllUnordered(_vars);

  final Set<String> _vars;

  @override
  final int hashCode;

  @override
  bool operator ==(Object other) =>
      other is _ThemeVarsKey &&
      other.hashCode == hashCode &&
      (identical(other._vars, _vars) ||
          (other._vars.length == _vars.length &&
              other._vars.containsAll(_vars)));
}

/// The page of a [ThorApp.router] before a request gives it one.
class _NoPage extends StatelessWidget implements ThorBuiltIn {
  const _NoPage();

  @override
  Widget build(BuildContext context) => throw StateError(
    'ThorApp.router draws its routes: serve it (runApp, '
    'WidgetRenderer.router), do not render it as a widget',
  );
}

/// The theme switch, after the page: reads the `ThorLocalizations` the app
/// loaded for its locale and hands them to the input.
class _ThemeSwitch extends StatelessWidget {
  const _ThemeSwitch({required this.label, required this.locale});

  final String? label;
  final Locale locale;

  @override
  Widget build(BuildContext context) => _ThemeSwitchInput(
    label: label,
    locale: locale,
    loaded: ThorLocalizations.maybeOf(context),
  );
}

/// The delegates of the app plus the defaults for the types it leaves out
/// (`MaterialLocalizations`, `WidgetsLocalizations`, `ThorLocalizations`), as
/// a `WidgetsApp` does. One list per list of the app, so the widgets that
/// read them stay memoizable.
List<LocalizationsDelegate<Object?>> _withDefaultDelegates(
  List<LocalizationsDelegate<Object?>>? app,
) {
  if (app == null || app.isEmpty) return ThorLocalizations.delegates;
  return _merged[app] ??= [
    ...app,
    for (final d in ThorLocalizations.delegates)
      if (!app.any((a) => a.type == d.type)) d,
  ];
}

final _merged = Expando<List<LocalizationsDelegate<Object?>>>(
  'ThorApp delegates',
);

/// The hidden checkbox the theme switch flips (`#thor-theme`), named in the
/// page's language. Built after the page, so it reads the `<html lang>` the
/// page set (a localized [ThorApp], or the app's own document attributes).
class _ThemeSwitchInput extends PageComponent {
  const _ThemeSwitchInput({
    required this.label,
    required this.locale,
    required this.loaded,
  });

  final String? label;

  /// The locale of the app.
  final Locale locale;

  /// The app's `ThorLocalizations` for [locale], when it has a delegate.
  final ThorLocalizations? loaded;

  @override
  void buildInto(
    PageBuild page,
    Element element,
    ParentNode into,
    BuildChild build,
  ) {
    final lang = page.htmlAttributes['lang'];
    // The document's own `lang` (the app set one) names the page's
    // language; the app's locale otherwise.
    final texts = lang == null || lang.split('-').first == locale.languageCode
        ? loaded ?? ThorLocalizations.forLocale(locale)
        : ThorLocalizations.forLocale(Locale.tryParse(lang));
    // Next to its label when the page has a `ThemeToggle`, so the keyboard
    // reaches the switch where the person sees it (the top bar); at the end
    // of the page, the last Tab stop, when there is none.
    build(
      Widget.element(
        tag: 'input',
        id: themeToggleId,
        attributes: {
          'type': 'checkbox',
          'aria-label': label ?? texts.themeToggleLabel,
          'style': ThorApp._srOnly,
        },
      ),
      element,
      _toggleLabel(into) ?? into,
    );
  }

  /// The `<label for="thor-theme">` of a `ThemeToggle` built into [parent],
  /// unless it sits in a kept (cached) fragment, which later pages reuse as
  /// it is and must not change. A label outside any `<dialog>` wins: a page
  /// with a toggle in its bar and another in its phone drawer keeps the
  /// input in the bar, where the keyboard reaches it with the drawer closed
  /// (`// web:` a closed dialog's content is not focusable). The drawer's
  /// label still flips it by a click; only a page whose every toggle is in a
  /// dialog puts the input in one.
  static ParentNode? _toggleLabel(ParentNode parent) {
    ParentNode? inDialog;
    ParentNode? search(ParentNode node, bool dialog) {
      for (final child in node.children) {
        switch (child) {
          case ElementNode(tag: 'label', :final attributes)
              when attributes?['for'] == themeToggleId:
            if (!dialog) return child;
            inDialog ??= child;
          case ElementNode(:final tag):
            if (search(child, dialog || tag == 'dialog') case final found?) {
              return found;
            }
          case FragmentNode(kept: false):
            if (search(child, dialog) case final found?) return found;
          case _:
        }
      }
      return null;
    }

    return search(parent, false) ?? inDialog;
  }
}

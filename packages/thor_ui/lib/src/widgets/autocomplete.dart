import 'dart:async' show FutureOr;

import 'package:thor_engine/thor_engine.dart'
    show
        FocusNode,
        TextEditingController,
        TextEditingValue,
        TextSelection,
        autocompleteAttr,
        autocompleteInlineAttr,
        autocompleteNoneAttr,
        autocompleteOneAttr,
        autocompleteRoomVar,
        autocompleteStatusAttr,
        autocompleteUpAttr,
        dropdownActiveAttr;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../engine/watch.dart' show engineAttributes;
import '../foundation/child_rules.dart' show ThorBuiltIn, ThorElementWidget;
import '../foundation/element.dart';
import '../foundation/errors.dart';
import '../foundation/layout_hint.dart';
import '../foundation/material_localizations.dart' show ThorLocalizations;
import '../foundation/native_id.dart' show nativeId;
import '../foundation/style_registry.dart';
import '../foundation/theme_tokens.dart';
import 'dropdown_menu.dart' show MenuStyle, menuStyleCss;
import 'effects.dart' show Semantics;
import 'text_field.dart';

/// The anchor of the options panel: one name, scoped to each
/// autocomplete (`anchor-scope`), so every instance shares the same classes.
const _anchor = '--t-ac';

const _highlight = 'color-mix(in srgb, currentColor 10%, transparent)';

/// Flutter's `AutocompleteOptionsBuilder`: the options for what the field
/// holds.
///
/// `// web:` a page is written once: the build asks it for the field's
/// first text (`initialValue`, else empty) and the browser narrows what it
/// returned as the visitor types. A filter like Flutter's own example
/// (`option.contains(value.text)`) returns every option for the empty text,
/// which is what the page needs. Options that come from the server as the
/// visitor types are a `ThorState` list in `optionsViewBuilder` instead.
typedef AutocompleteOptionsBuilder<T extends Object> =
    FutureOr<Iterable<T>> Function(TextEditingValue textEditingValue);

/// Flutter's `AutocompleteOnSelected`.
typedef AutocompleteOnSelected<T extends Object> = void Function(T option);

/// Flutter's `AutocompleteOptionsViewBuilder`: the widget that shows the
/// [options] and calls [onSelected] for the one the visitor picks.
///
/// `// web:` [onSelected] does nothing here (a closure does not run in the
/// browser): rows pick by themselves (a link, or a method of a `ThorState`
/// with `withArg`) and the engine puts the picked row's text in the field.
/// Mark each row `Semantics(role: SemanticsRole.option, …)`.
typedef AutocompleteOptionsViewBuilder<T extends Object> =
    Widget Function(
      BuildContext context,
      AutocompleteOnSelected<T> onSelected,
      Iterable<T> options,
    );

/// Flutter's `AutocompleteFieldViewBuilder`: the field widget.
typedef AutocompleteFieldViewBuilder =
    Widget Function(
      BuildContext context,
      TextEditingController textEditingController,
      FocusNode focusNode,
      void Function() onFieldSubmitted,
    );

/// Flutter's `AutocompleteOptionToString`: the text of an option.
typedef AutocompleteOptionToString<T extends Object> =
    String Function(T option);

/// Flutter's `OptionsViewOpenDirection`: where the options view opens.
enum OptionsViewOpenDirection {
  /// Above the field.
  up,

  /// Below the field.
  down,

  /// Where there is more room, above or below.
  mostSpace,
}

int _fallbackIds = 0;

/// Flutter's `RawAutocomplete<T>`: a field with an options view anchored to
/// it, drawn by you ([fieldViewBuilder], [optionsViewBuilder]). Use
/// [Autocomplete] for the Material look.
///
/// The options view is a native popover (`popover="manual"`, so it sits in
/// the top layer: no sibling covers it and no `Stack` or `overflow` clips
/// it) anchored under the field with CSS anchor positioning. The engine's
/// `AutocompleteFeature` (added by the build when an app uses
/// `Autocomplete(` or `RawAutocomplete(`) opens it while the field has focus
/// and there is an option to show, moves a highlight with the arrow keys,
/// picks with Enter or a click (the field takes the option's text), and
/// closes on Esc, Tab or a click outside. Without JavaScript the field is a
/// plain text field and the view stays closed.
///
/// ```dart
/// RawAutocomplete<String>(
///   textEditingController: search.box,       // TextEditingController field
///   focusNode: search.focus,
///   optionsBuilder: (v) => const [],
///   fieldViewBuilder: (context, controller, focus, submit) =>
///       TextField(controller: controller, focusNode: focus),
///   optionsViewBuilder: (context, onSelected, options) => Watch.list(
///     search.names,
///     itemKey: search.nameOf,
///     each: (row) => Semantics(
///       role: SemanticsRole.option,
///       child: row.attribute(AttributeName.href, search.hrefOf, child: Link(href: RouteUrl('#'), child: row.text(search.nameOf))),
///     ),
///   ),
/// )
/// ```
///
/// `// web:` differences from Flutter's: [optionsBuilder] runs once, at
/// build; the options view is a widget the page holds, which a `ThorState`
/// list changes ([AutocompleteOptionsBuilder]); no option is highlighted
/// until the visitor moves to one, so Enter still submits a typed text
/// (Flutter picks the first option) unless [highlightFirst] is set.
///
/// **A palette (inline):** `inline: true` draws the options in the flow
/// (a `listbox` where you put the autocomplete, no popover), always visible
/// while there is an option, and `highlightFirst: true` keeps the first
/// option active so Enter picks it. With `inline` Esc is not taken by the
/// list: inside a `<dialog>` one press closes the dialog. Keys, with the
/// list inline: Up/Down wrap, PageUp/PageDown move a page of options, and
/// Ctrl or Cmd with Home/End go to the first or last option (plain
/// Home/End stay the caret's, as in the APG combobox).
class RawAutocomplete<T extends Object> extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn, LayoutHint {
  /// Creates an autocomplete.
  const RawAutocomplete({
    super.key,
    required this.optionsViewBuilder,
    required this.optionsBuilder,
    this.optionsViewOpenDirection = OptionsViewOpenDirection.down,
    this.displayStringForOption = defaultStringForOption,
    this.fieldViewBuilder,
    this.focusNode,
    this.textEditingController,
    this.initialValue,
    this.onSelected,
    this.filter,
    this.panelMaxHeight,
    this.resultsLabel,
    this.oneResultLabel,
    this.noResultsLabel,
    this.inline = false,
    this.highlightFirst = false,
    this.matchWords = false,
  }) : assert(
         // web: Flutter also takes an external field (a focusNode and a
         // controller, no builder); a page is written once, so the field is
         // always the one the builder returns.
         fieldViewBuilder != null,
         'RawAutocomplete needs a fieldViewBuilder: on the web the field '
         'is the one it returns (pass your own focusNode and '
         'textEditingController to it, not instead of it)',
       ),
       assert(
         focusNode == null || textEditingController != null,
         'a focusNode needs its textEditingController',
       ),
       assert(
         initialValue == null || textEditingController == null,
         'initialValue and textEditingController are exclusive',
       );

  /// The text of [option] (`option.toString()`).
  static String defaultStringForOption(Object? option) => option.toString();

  /// The options for the field's text (see [AutocompleteOptionsBuilder]).
  final AutocompleteOptionsBuilder<T> optionsBuilder;

  /// The widget of the options (see [AutocompleteOptionsViewBuilder]).
  final AutocompleteOptionsViewBuilder<T> optionsViewBuilder;

  /// Where the options view opens.
  final OptionsViewOpenDirection optionsViewOpenDirection;

  /// The text of an option, the one the field takes when it is picked.
  final AutocompleteOptionToString<T> displayStringForOption;

  /// The field. Without one, build it yourself with [focusNode] and
  /// [textEditingController] (not supported on the web yet: pass it).
  final AutocompleteFieldViewBuilder? fieldViewBuilder;

  /// A `FocusNode` field of a `ThorState` for the field.
  final FocusNode? focusNode;

  /// A `TextEditingController` field of a `ThorState`: the field's text,
  /// what [AutocompleteOptionsBuilder] is asked about at build.
  final TextEditingController? textEditingController;

  /// The field's first value (when [textEditingController] is not given).
  final TextEditingValue? initialValue;

  /// Called with the picked option. A method of a `ThorState` taking it runs
  /// in the browser (`String`, number, `bool` or `enum` options).
  final AutocompleteOnSelected<T>? onSelected;

  /// `// web:` whether the browser hides the options the typed text does not
  /// match (the text contains the typed one, any case). Default: yes for the
  /// options of [Autocomplete]'s own view, no for a view you build (a
  /// `ThorState` list is already the matching one).
  final bool? filter;

  /// Largest height of the options view before it scrolls (default: the
  /// room on screen).
  final double? panelMaxHeight;

  /// `// web:` what a screen reader hears (a polite live region) when the
  /// options change: this one for several, `{count}` being their number.
  /// Flutter announces through its semantics tree; the page has one region
  /// per field. Null: the page's language (`ThorLocalizations`).
  final String? resultsLabel;

  /// What is announced for exactly one option (null: the page's language).
  final String? oneResultLabel;

  /// What is announced when the typed text leaves no option (null: the
  /// page's language).
  final String? noResultsLabel;

  /// `// web:` no Flutter counterpart. Draws the options view in the flow,
  /// where the autocomplete is, instead of a popover under the field: it
  /// shows while there is an option and hides when there is none, with the
  /// same `listbox` / `option` roles and keyboard. [optionsViewOpenDirection]
  /// does not apply. Esc is left to the page (a `<dialog>` closes with one
  /// press); [panelMaxHeight] scrolls the view.
  final bool inline;

  /// `// web:` whether the first visible option is active whenever the
  /// options show or change (`aria-activedescendant` set), so Enter picks
  /// it, as Flutter's own `RawAutocomplete` does (it highlights the first).
  final bool highlightFirst;

  /// `// web:` how [filter] matches (it only applies while [filter] is true). False (default): the typed text, as a
  /// whole, appears in the option's text, any case, as Flutter's own example
  /// `optionsBuilder` does. True: every whitespace-separated word appears, in
  /// any order, ignoring case and accents (`new york` finds `York, New`;
  /// `cafe` finds `Café`). Flutter has no such filter built in (its
  /// `optionsBuilder` is the app's), so the default keeps its semantics.
  final bool matchWords;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) => _build<T>(
    context,
    inline: inline,
    highlightFirst: highlightFirst,
    matchWords: matchWords,
    optionsBuilder: optionsBuilder,
    optionsViewBuilder: optionsViewBuilder,
    fieldViewBuilder: fieldViewBuilder!,
    focusNode: focusNode,
    textEditingController: textEditingController,
    initialValue: initialValue,
    onSelected: onSelected,
    filter: filter ?? false,
    direction: optionsViewOpenDirection,
    maxHeight: panelMaxHeight,
    look: null,
    labels: _labels(context, resultsLabel, oneResultLabel, noResultsLabel),
    key: key,
  );
}

/// An autocomplete's build, [RawAutocomplete]'s and [Autocomplete]'s.
Widget _build<T extends Object>(
  BuildContext context, {
  bool inline = false,
  bool highlightFirst = false,
  bool matchWords = false,
  required AutocompleteOptionsBuilder<T> optionsBuilder,
  required AutocompleteOptionsViewBuilder<T> optionsViewBuilder,
  required AutocompleteFieldViewBuilder fieldViewBuilder,
  required FocusNode? focusNode,
  required TextEditingController? textEditingController,
  required TextEditingValue? initialValue,
  required AutocompleteOnSelected<T>? onSelected,
  required bool filter,
  required OptionsViewOpenDirection direction,
  required double? maxHeight,
  required CssDeclarations? look,
  required (String, String, String) labels,
  required Key? key,
}) {
  final registry = ThorStyleRegistry.active(context);
  registry?.useEngine();
  // `// web:` a `ValueKey` (`ValueKey(row.key)` in a `Watch.list` row) names
  // the panel: in the row template the key stays a token the browser fills,
  // so each row it draws gets its own panel id. Without one the page counts.
  final id = key is ValueKey
      ? nativeId(context, prefix: 'ac', key: key)
      : registry?.uniqueId('t-ac') ?? 't-ac-${++_fallbackIds}';
  final controller =
      textEditingController ?? TextEditingController(text: initialValue?.text);
  final value =
      initialValue ??
      TextEditingValue(
        text: textEditingController?.text ?? '',
        selection:
            textEditingController?.selection ??
            const TextSelection.collapsed(offset: -1),
      );
  final given = optionsBuilder(value);
  if (given is Future) {
    throw StateError(
      thorError(
        'THOR-R032',
        'optionsBuilder returned a Future: a page is written once, so it '
            'has to give its options at build time. For options that arrive '
            'as the visitor types (a search), keep them in a `ThorState` '
            'list and show it in `optionsViewBuilder` (`Watch.list`).',
      ),
    );
  }
  final options = given.toList();
  final field = fieldViewBuilder(
    context,
    controller,
    focusNode ?? FocusNode(),
    () {},
  );
  // `// web:` the callback is the app's (a method of a `ThorState` runs in
  // the browser: `onSelected.withArg(option)`); a closure does not.
  final view = optionsViewBuilder(context, onSelected ?? (_) {}, options);
  return autocompleteRoot(
    id: id,
    field: field,
    view: view,
    filter: filter,
    direction: direction,
    maxHeight: maxHeight,
    look: look,
    labels: labels,
    inline: inline,
    highlightFirst: highlightFirst,
    matchWords: matchWords,
  );
}

// The three announcements: the widget's own text, else the page's language.
(String, String, String) _labels(
  BuildContext context,
  String? several,
  String? one,
  String? none,
) {
  final l10n = ThorLocalizations.of(context);
  return (
    several ?? l10n.autocompleteResultsOther,
    one ?? l10n.autocompleteResultsOne,
    none ?? l10n.autocompleteNoResults,
  );
}

/// The markup of an autocomplete: [field], and [view] in a popover panel
/// anchored to it. [look] is the panel's own look (the Material one for
/// [Autocomplete]; none when the view draws itself).
Widget autocompleteRoot({
  required String id,
  required Widget field,
  required Widget view,
  required bool filter,
  required OptionsViewOpenDirection direction,
  required double? maxHeight,
  required CssDeclarations? look,
  required (String, String, String) labels,
  bool inline = false,
  bool highlightFirst = false,
  bool matchWords = false,
}) {
  // `// web:` the engine writes the room it measured on the visual viewport
  // ([autocompleteRoomVar]: the on-screen keyboard takes the layout
  // viewport's bottom without telling CSS); without it the cap is the rest.
  final room = maxHeight == null
      ? 'min(calc(100dvh - 16px), var($autocompleteRoomVar, 100dvh))'
      : 'min(${cssPx(maxHeight)}, calc(100dvh - 16px), '
            'var($autocompleteRoomVar, 100dvh))';
  final panel = inline
      ? thorElement(
          'div',
          id: '$id-list',
          debugName: 'AutocompleteInlinePanel',
          // In the flow: no `display` of its own, so the engine's `hidden`
          // (no option to show) takes it out like any element.
          css: {
            'box-sizing': 'border-box',
            'min-width': '0',
            if (maxHeight != null) ...{
              'max-height': cssPx(maxHeight),
              'overflow-y': 'auto',
              'overscroll-behavior': 'contain',
            },
            ...?look,
          },
          attributes: const {'role': 'listbox', autocompleteInlineAttr: ''},
          children: [view],
        )
      : _popoverPanel(
          id: id,
          direction: direction,
          room: room,
          look: look,
          view: view,
        );
  // `// web:` Flutter announces the options through its semantics tree; the
  // page has a polite live region the engine fills with the count.
  final status = thorElement(
    'div',
    debugName: 'AutocompleteStatus',
    css: const {
      'position': 'absolute',
      'width': '1px',
      'height': '1px',
      'overflow': 'hidden',
      'clip-path': 'inset(50%)',
      'white-space': 'nowrap',
    },
    attributes: {
      'role': 'status',
      'aria-live': 'polite',
      'aria-atomic': 'true',
      autocompleteStatusAttr: labels.$1,
      autocompleteOneAttr: labels.$2,
      autocompleteNoneAttr: labels.$3,
    },
  );
  return thorElement(
    'div',
    debugName: 'Autocomplete',
    fillsWidth: true,
    css: const {
      'display': 'block',
      'min-width': '0',
      'anchor-name': _anchor,
      'anchor-scope': _anchor,
    },
    // `f`: the browser hides the options the text does not match; `u`: the
    // panel is meant above, the engine never flips it; `i`: the view is in
    // the flow; `h`: the first option is kept active; `w`: `f` matches every
    // typed word, not the phrase.
    attributes: {
      autocompleteAttr:
          '${filter ? 'f' : ''}'
          '${direction == OptionsViewOpenDirection.up ? 'u' : ''}'
          '${inline ? 'i' : ''}'
          '${highlightFirst ? 'h' : ''}'
          '${matchWords ? 'w' : ''}',
    },
    children: [field, status, panel],
  );
}

Widget _popoverPanel({
  required String id,
  required OptionsViewOpenDirection direction,
  required String room,
  required CssDeclarations? look,
  required Widget view,
}) {
  return thorElement(
    'div',
    id: '$id-list',
    debugName: 'AutocompletePanel',
    css: {
      'position-anchor': _anchor,
      // The UA centers popovers (`inset: 0`); anchoring needs auto.
      'inset': 'auto',
      'position-area': switch (direction) {
        OptionsViewOpenDirection.up => 'block-start span-inline-end',
        _ => 'block-end span-inline-end',
      },
      'position-try': ?(direction == OptionsViewOpenDirection.mostSpace
          ? 'most-height flip-block'
          : null),
      'position-try-fallbacks':
          ?(direction == OptionsViewOpenDirection.mostSpace
          ? null
          : 'flip-block'),
      'margin': '0',
      'box-sizing': 'border-box',
      'min-width': 'anchor-size(width)',
      'max-width': 'calc(100vw - 16px)',
      'max-height': room,
      'padding': '0',
      'border': '0',
      'background': 'transparent',
      'color': 'inherit',
      if (look == null)
        // A view the app draws: nothing of the panel's own around it.
        'overflow': 'visible'
      else ...{
        'overflow-y': 'auto',
        'overscroll-behavior': 'contain',
        ...look,
      },
    },
    // The panel the engine opens above the field: the other side of the
    // same anchor (a variant of the same classes, nothing generated at runtime).
    conditions: const [
      ConditionalCss(CssCondition.selector('[$autocompleteUpAttr]'), {
        'position-area': 'block-start span-inline-end',
      }),
    ],
    attributes: const {'popover': 'manual', 'role': 'listbox'},
    children: [view],
  );
}

/// Flutter's `Autocomplete<T>` (Material): a text field that suggests
/// [optionsBuilder]'s options as the visitor types, in a panel under it.
///
/// ```dart
/// Autocomplete<String>(
///   optionsBuilder: (value) =>
///       fruits.where((f) => f.contains(value.text.toLowerCase())),
///   onSelected: order.pickFruit,        // void pickFruit(String fruit)
/// )
/// ```
///
/// A styled combobox on the Popover API (see [RawAutocomplete]): the panel
/// is in the top layer under the field, so no `Stack` clips it and no
/// sibling covers it. Rows are `option`s of a `listbox`; the field is the
/// `combobox` and announces the highlighted option through
/// `aria-activedescendant`.
///
/// `// web:` the options come from [optionsBuilder] once, at build (see
/// [AutocompleteOptionsBuilder]), and the browser keeps the ones whose text
/// contains what is typed. For options a server finds as the visitor types
/// (a store search), use [RawAutocomplete] with a `ThorState` list in
/// [optionsViewBuilder]. [onSelected] needs a method of a `ThorState` to run
/// in the browser, and the options encodable as a `ThorState` argument
/// (`String`, number, `bool`, `enum`).
class Autocomplete<T extends Object> extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn, LayoutHint {
  /// Creates an autocomplete.
  const Autocomplete({
    super.key,
    required this.optionsBuilder,
    this.displayStringForOption = RawAutocomplete.defaultStringForOption,
    this.fieldViewBuilder,
    this.focusNode,
    this.onSelected,
    this.optionsMaxHeight = 200,
    this.optionsViewBuilder,
    this.optionsViewOpenDirection = OptionsViewOpenDirection.down,
    this.textEditingController,
    this.initialValue,
    this.menuStyle,
    this.semanticLabel,
    this.resultsLabel,
    this.oneResultLabel,
    this.noResultsLabel,
  }) : assert(
         focusNode == null || textEditingController != null,
         'a focusNode needs its textEditingController',
       ),
       assert(
         initialValue == null || textEditingController == null,
         'initialValue and textEditingController are exclusive',
       );

  /// The options for the field's text, at build (see
  /// [AutocompleteOptionsBuilder]).
  final AutocompleteOptionsBuilder<T> optionsBuilder;

  /// The text of an option: what its row shows, what the field takes when
  /// it is picked and what the browser matches the typed text against.
  final AutocompleteOptionToString<T> displayStringForOption;

  /// The field (default: a [TextField]).
  final AutocompleteFieldViewBuilder? fieldViewBuilder;

  /// A `FocusNode` field of a `ThorState` for the field.
  final FocusNode? focusNode;

  /// Called with the picked option (see the class).
  final AutocompleteOnSelected<T>? onSelected;

  /// Largest height of the panel before it scrolls (Flutter: 200).
  final double optionsMaxHeight;

  /// Your own options view instead of the Material list.
  final AutocompleteOptionsViewBuilder<T>? optionsViewBuilder;

  /// Where the options open.
  final OptionsViewOpenDirection optionsViewOpenDirection;

  /// A `TextEditingController` field of a `ThorState` for the field.
  final TextEditingController? textEditingController;

  /// The field's first value.
  final TextEditingValue? initialValue;

  /// `// web:` the look of the default panel: fill, corners, border,
  /// shadow, padding.
  final MenuStyle? menuStyle;

  /// `// web:` the accessible name of the default field (Flutter's default
  /// field has none; a screen reader needs one). With your own
  /// [fieldViewBuilder], name the field there.
  final String? semanticLabel;

  /// `// web:` what a screen reader hears when the options change: this one
  /// for several, `{count}` being their number (see
  /// [RawAutocomplete.resultsLabel]).
  final String? resultsLabel;

  /// What is announced for exactly one option.
  final String? oneResultLabel;

  /// What is announced when the typed text leaves no option.
  final String? noResultsLabel;

  @override
  bool get fillsWidth => true;

  Widget _defaultField(
    BuildContext context,
    TextEditingController controller,
    FocusNode focusNode,
    void Function() onFieldSubmitted,
  ) {
    // Flutter's default field has no label; `semanticLabel:` names it.
    // ignore: thor_lints/text_field_without_label
    final field = TextField(controller: controller, focusNode: focusNode);
    return semanticLabel == null
        ? field
        : Semantics(label: semanticLabel, child: field);
  }

  @override
  Widget build(BuildContext context) {
    final custom = optionsViewBuilder;
    return _build<T>(
      context,
      optionsBuilder: optionsBuilder,
      optionsViewBuilder:
          custom ??
          (context, picked, options) => _OptionsList<T>(
            options: options,
            displayStringForOption: displayStringForOption,
            onSelected: onSelected,
          ),
      fieldViewBuilder: fieldViewBuilder ?? _defaultField,
      focusNode: focusNode,
      textEditingController: textEditingController,
      initialValue: initialValue,
      onSelected: onSelected,
      filter: custom == null,
      direction: optionsViewOpenDirection,
      maxHeight: optionsMaxHeight,
      labels: _labels(context, resultsLabel, oneResultLabel, noResultsLabel),
      key: key,
      // The Material panel, unless the view draws its own.
      look: custom != null
          ? null
          : {
              'background-color': ThemeTokens.surfaceContainer,
              'border-radius': '4px',
              'box-shadow':
                  '0 1px 3px rgba(0, 0, 0, 0.3), '
                  '0 4px 8px 3px rgba(0, 0, 0, 0.15)',
              ...?menuStyle == null ? null : menuStyleCss(menuStyle!),
            },
    );
  }
}

/// The default Material options list.
class _OptionsList<T extends Object> extends StatelessWidget
    implements ThorBuiltIn {
  const _OptionsList({
    required this.options,
    required this.displayStringForOption,
    required this.onSelected,
  });

  final Iterable<T> options;
  final AutocompleteOptionToString<T> displayStringForOption;
  final AutocompleteOnSelected<T>? onSelected;

  @override
  Widget build(BuildContext context) => Widget.fragment([
    for (final option in options)
      thorElement(
        'div',
        debugName: 'AutocompleteOption',
        css: const {
          'display': 'block',
          'box-sizing': 'border-box',
          'padding': '16px',
          'cursor': 'pointer',
          'user-select': 'none',
        },
        conditions: const [
          ConditionalCss(CssCondition.selector('[$dropdownActiveAttr]'), {
            'background-color': _highlight,
          }),
          // Filtered out (`hidden`): the row's display must not win.
          ConditionalCss(CssCondition.selector('[hidden]'), {
            'display': 'none',
          }),
        ],
        attributes: {
          'role': 'option',
          'aria-selected': 'false',
          ...engineAttributes({'click': onSelected}, arg: option),
        },
        children: [Widget.text(displayStringForOption(option))],
      ),
  ]);
}

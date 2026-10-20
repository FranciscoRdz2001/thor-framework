/// Typed HTML attributes: the names (`AriaAttribute`, `AttributeName`) and
/// the set of attributes of an element (`HtmlAttributes`).
library;

import 'dart:collection';

import '../core/markup.dart' show isHtmlAttributeName;

/// A WAI-ARIA state or property: `aria-<name>`.
///
/// ```dart
/// HtmlAttributes(aria: {AriaAttribute.label: 'Search', AriaAttribute.busy: true})
/// ```
///
/// `// web:` no Flutter counterpart (Flutter spells these in `Semantics`);
/// for a widget's own accessible name or role use `Semantics`.
enum AriaAttribute {
  /// `aria-activedescendant`.
  activedescendant,

  /// `aria-atomic`.
  atomic,

  /// `aria-autocomplete`.
  autocomplete,

  /// `aria-busy`.
  busy,

  /// `aria-checked`.
  checked,

  /// `aria-colcount`.
  colcount,

  /// `aria-colindex`.
  colindex,

  /// `aria-colspan`.
  colspan,

  /// `aria-controls`.
  controls,

  /// `aria-current`.
  current,

  /// `aria-describedby`.
  describedby,

  /// `aria-details`.
  details,

  /// `aria-disabled`.
  disabled,

  /// `aria-errormessage`.
  errormessage,

  /// `aria-expanded`.
  expanded,

  /// `aria-haspopup`.
  haspopup,

  /// `aria-hidden`.
  hidden,

  /// `aria-invalid`.
  invalid,

  /// `aria-keyshortcuts`.
  keyshortcuts,

  /// `aria-label`.
  label,

  /// `aria-labelledby`.
  labelledby,

  /// `aria-level`.
  level,

  /// `aria-live`.
  live,

  /// `aria-modal`.
  modal,

  /// `aria-multiline`.
  multiline,

  /// `aria-multiselectable`.
  multiselectable,

  /// `aria-orientation`.
  orientation,

  /// `aria-owns`.
  owns,

  /// `aria-placeholder`.
  placeholder,

  /// `aria-posinset`.
  posinset,

  /// `aria-pressed`.
  pressed,

  /// `aria-readonly`.
  readonly,

  /// `aria-relevant`.
  relevant,

  /// `aria-required`.
  required,

  /// `aria-roledescription`.
  roledescription,

  /// `aria-rowcount`.
  rowcount,

  /// `aria-rowindex`.
  rowindex,

  /// `aria-rowspan`.
  rowspan,

  /// `aria-selected`.
  selected,

  /// `aria-setsize`.
  setsize,

  /// `aria-sort`.
  sort,

  /// `aria-valuemax`.
  valuemax,

  /// `aria-valuemin`.
  valuemin,

  /// `aria-valuenow`.
  valuenow,

  /// `aria-valuetext`.
  valuetext;

  /// The attribute: `aria-label`.
  String get attribute => 'aria-$name';
}

/// An HTML attribute that is on or off: written bare when on, left out
/// when off.
enum BooleanAttribute {
  /// `autofocus`.
  autofocus,

  /// `checked`.
  checked,

  /// `disabled`.
  disabled,

  /// `hidden`.
  hidden,

  /// `inert`.
  inert,

  /// `multiple`.
  multiple,

  /// `open`.
  open,

  /// `readonly`.
  readonly,

  /// `required`.
  required,

  /// `selected`.
  selected,
}

/// The name of an HTML attribute that a state value can bind to
/// (`WatchAttributes`, `row.attribute`): the common ones as constants, the
/// rest from [AttributeName.ariaOf] and [AttributeName.data].
///
/// ```dart
/// WatchAttributes({AttributeName.ariaOf(AriaAttribute.rowcount): grid.rows}, …)
/// row.attribute(AttributeName.href, links.urlOf, child: Link(…))
/// ```
///
/// It *is* a `String`. A name a binding may not write (`on*`, `style`,
/// `class`, `type`) is refused where it is bound, not here.
///
/// `// web:` no Flutter counterpart (Flutter has no attributes).
extension type const AttributeName(String name) implements String {
  /// `value`.
  static const value = AttributeName('value');

  /// `disabled`.
  static const disabled = AttributeName('disabled');

  /// `readonly`.
  static const readonly = AttributeName('readonly');

  /// `hidden`.
  static const hidden = AttributeName('hidden');

  /// `checked`.
  static const checked = AttributeName('checked');

  /// Whether a `<details>` (an `ExpansionTile`) is open; a bool. The engine
  /// writes it when the state starts and each time the signals the method
  /// reads change, so a visitor's own toggle stands only until then.
  static const open = AttributeName('open');

  /// Whether the control takes the focus when the page loads; a bool.
  /// `// web:` the browser reads it once, as the page loads: a row added
  /// later does not take the focus.
  static const autofocus = AttributeName('autofocus');

  /// `href`.
  static const href = AttributeName('href');

  /// `src`.
  static const src = AttributeName('src');

  /// `alt`.
  static const alt = AttributeName('alt');

  /// `title`.
  static const title = AttributeName('title');

  /// `placeholder`.
  static const placeholder = AttributeName('placeholder');

  /// `label`.
  static const label = AttributeName('label');

  /// `id`.
  static const id = AttributeName('id');

  /// `role`.
  static const role = AttributeName('role');

  /// `tabindex`.
  static const tabIndex = AttributeName('tabindex');

  /// `min`.
  static const min = AttributeName('min');

  /// `max`.
  static const max = AttributeName('max');

  /// `step`.
  static const step = AttributeName('step');

  /// `datetime`.
  static const datetime = AttributeName('datetime');

  /// `aria-<name>` of [attribute].
  static AttributeName ariaOf(AriaAttribute attribute) =>
      AttributeName(attribute.attribute);

  /// `data-<key>`: [key] is lowercase letters, digits and `-`.
  factory AttributeName.data(String key) {
    _checkDataKey(key);
    return AttributeName('data-$key');
  }
}

void _checkDataKey(String key) {
  if (!RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(key)) {
    throw ArgumentError.value(
      key,
      'key',
      'a data attribute is data-<lowercase letters, digits and ->',
    );
  }
}

final _attributeName = RegExp(r'^[A-Za-z_][A-Za-z0-9_:.-]*$');

/// The attributes of one element, typed: ARIA states, `data-*`, the
/// global attributes and the boolean ones, and a validated escape for any
/// other name.
///
/// ```dart
/// TextField(
///   inputAttributes: HtmlAttributes(
///     aria: {AriaAttribute.label: 'Search'},
///     data: {'k': 'u0'},
///     flags: {BooleanAttribute.autofocus},
///   ),
/// )
/// TextField(inputAttributes: HtmlAttributes.custom({'type': 'time'}))
/// ```
///
/// It is an unmodifiable `Map<String, String>` (name → value), so
/// `package:thor_ui/html.dart`, the raw layer, takes it where it takes a
/// map (and also takes a plain map, unchecked). Every other API that
/// accepts attributes takes this class: a name that is not a valid
/// attribute name, or an event handler (`onclick`), is an `ArgumentError`.
///
/// `// web:` no Flutter counterpart (Flutter has no attributes).
final class HtmlAttributes extends UnmodifiableMapBase<String, String> {
  /// The attributes given: [aria] (`aria-*`, a value is a `String`, `bool`
  /// or `num`), [data] (`data-<key>`), the globals [id], [title] and
  /// [tabIndex], and the [flags] that are on. [custom] adds any other
  /// attribute (see [HtmlAttributes.custom]).
  factory HtmlAttributes({
    Map<AriaAttribute, Object>? aria,
    Map<String, String>? data,
    String? id,
    String? title,
    int? tabIndex,
    Set<BooleanAttribute> flags = const {},
    Map<String, String>? custom,
  }) {
    final out = <String, String>{
      if (aria != null)
        for (final MapEntry(:key, :value) in aria.entries)
          key.attribute: '$value',
      if (data != null)
        for (final MapEntry(:key, :value) in data.entries)
          AttributeName.data(key): value,
      'id': ?id,
      'title': ?title,
      if (tabIndex != null) 'tabindex': '$tabIndex',
      for (final flag in flags) flag.name: '',
    };
    if (custom != null) out.addAll(HtmlAttributes.custom(custom));
    return HtmlAttributes._(out);
  }

  /// Any attributes by name. Each name must be a valid attribute name
  /// (letters, digits, `_`, `:`, `.`, `-`) and not an event handler
  /// (`on…`): scripts do not travel in attributes.
  factory HtmlAttributes.custom(Map<String, String> attributes) {
    for (final name in attributes.keys) {
      if (!_attributeName.hasMatch(name) ||
          !isHtmlAttributeName(name) ||
          name.toLowerCase().startsWith('on')) {
        throw ArgumentError.value(
          name,
          'attributes',
          'not an HTML attribute name (event handlers like onclick are '
              'refused)',
        );
      }
    }
    return HtmlAttributes._(Map.unmodifiable(attributes));
  }

  HtmlAttributes._(this._map);

  /// No attributes.
  static final empty = HtmlAttributes._(const {});

  final Map<String, String> _map;

  /// These attributes and [other]'s; [other] wins on a name both have.
  HtmlAttributes merge(HtmlAttributes? other) => other == null || other.isEmpty
      ? this
      : HtmlAttributes._(Map.unmodifiable({..._map, ...other._map}));

  @override
  String? operator [](Object? key) => _map[key];

  @override
  Iterable<String> get keys => _map.keys;
}

/// [attributes] as [HtmlAttributes] without checking the names: for the
/// framework's own maps (validation rules, schema fields), whose names are
/// fixed in code. Not exported.
HtmlAttributes trustedAttributes(Map<String, String> attributes) =>
    HtmlAttributes._(attributes);

import 'package:thor_engine/thor_engine.dart'
    show
        FocusNode,
        TextEditingController,
        attributesAttr,
        clearAttr,
        decodeOn,
        encodeOn,
        enterEvent,
        focusNodeAttr,
        helperAttr,
        invalidAttr,
        rowAttributesAttr,
        textControllerAttr,
        untracked;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../engine/watch.dart' show Watch, WatchAttributes, engineAttributes;
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/errors.dart';
import '../foundation/graphemes.dart';
import '../foundation/html_attributes.dart';
import '../foundation/layout_hint.dart';
import '../foundation/parent_data.dart';
import '../foundation/row_bind.dart' show bindRowMarkers;
import '../foundation/style_registry.dart';
import '../foundation/theme_tokens.dart';
import 'autofill_group.dart' show AutofillSection, withAutofillSection;
import 'basic.dart' show boxCss;
import 'effects.dart' show Semantics, SemanticsRole;
import 'form_scope.dart';
import 'shortcuts.dart' show controllerIdOf;
import 'text.dart' show Text;
import 'theme.dart' show Theme;

// Flutter's InputDecorator icon slot: at least 48×48, or the decoration's
// prefixIconConstraints / suffixIconConstraints instead.
const _defaultIconConstraints = BoxConstraints(minWidth: 48, minHeight: 48);

Map<String, String> _iconBox(BoxConstraints? constraints) => {
  'display': 'grid',
  'place-items': 'center',
  ...(constraints ?? _defaultIconConstraints).toCss(),
  'flex': 'none',
};

// The roles a border that gives no color takes (Flutter's M3 defaults).
const _outlineRole = ThemeTokens.outline;
const _onSurfaceVariantRole = ThemeTokens.onSurfaceVariant;
const _primaryRole = ThemeTokens.primary;

const _inputBase = <String, String>{
  'flex': '1 1 0',
  'min-width': '0',
  'border': '0',
  'outline': '0',
  'margin': '0',
  'background': 'transparent',
  'font': 'inherit',
  'color': 'inherit',
  'box-sizing': 'border-box',
};

/// Flutter's `InputBorder` family.
///
/// Rendered as an inset `box-shadow` (plus `border-radius`), because Flutter
/// paints input borders without taking layout space.
///
/// A border that comes from `InputDecoration.border` (or the theme) and gives
/// no color (`BorderSide()`, black) is painted by the field with the color
/// scheme, like Flutter's `InputDecorator`: the enabled underline
/// `onSurfaceVariant`, the enabled outline `outline`, the focused one
/// `primary`. A border given as `enabledBorder`, `focusedBorder` or
/// `errorBorder` keeps its own color.
sealed class InputBorder {
  const InputBorder();

  /// No border: no shadow is painted.
  static const none = _NoInputBorder();

  /// The color and width of the line (Flutter's `InputBorder.borderSide`).
  BorderSide get borderSide;

  /// A copy with the given fields replaced.
  InputBorder copyWith({BorderSide? borderSide});

  /// The inset shadow that draws the border with its own [borderSide], or
  /// null for none.
  String? get shadow => _paint(borderSide.color.css, borderSide.width);

  /// Corner radii of the border, or null when the border is a straight line.
  BorderRadius? get borderRadius => null;

  // The scheme role the border takes when it gives no color.
  String get _role;

  String _shadowOf(String color, double width);

  // The shadow with [color] and [width] (null for none).
  String? _paint(String color, double width) =>
      borderSide.style == BorderStyle.none ? null : _shadowOf(color, width);

  // Whether the border chose its color (anything but `BorderSide()`'s black).
  bool get _hasColor => borderSide.color != const BorderSide().color;
}

class _NoInputBorder extends InputBorder {
  const _NoInputBorder();

  @override
  BorderSide get borderSide => BorderSide.none;

  @override
  InputBorder copyWith({BorderSide? borderSide}) => this;

  @override
  String get _role => _outlineRole;

  @override
  String _shadowOf(String color, double width) => '';

  @override
  String? _paint(String color, double width) => null;
}

/// Flutter's `OutlineInputBorder`.
class OutlineInputBorder extends InputBorder {
  /// Creates a border that outlines the field on every side.
  const OutlineInputBorder({
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.borderSide = const BorderSide(),
  });

  @override
  final BorderRadius borderRadius;

  /// The color and width of the outline. As `InputDecoration.border` with no
  /// color it is painted with the scheme's `outline` role.
  // web: Flutter reads the role at paint time; here it is the `--t-outline`
  // variable, so the dark theme gets its own value with no extra rule.
  @override
  final BorderSide borderSide;

  @override
  OutlineInputBorder copyWith({
    BorderRadius? borderRadius,
    BorderSide? borderSide,
  }) => OutlineInputBorder(
    borderRadius: borderRadius ?? this.borderRadius,
    borderSide: borderSide ?? this.borderSide,
  );

  @override
  String get _role => _outlineRole;

  @override
  String _shadowOf(String color, double width) =>
      'inset 0 0 0 ${cssPx(width)} $color';
}

/// Flutter's `UnderlineInputBorder`.
class UnderlineInputBorder extends InputBorder {
  /// Creates a border that draws a line under the field.
  const UnderlineInputBorder({this.borderSide = const BorderSide()});

  /// The color and width of the underline. As `InputDecoration.border` with
  /// no color it is painted with the scheme's `onSurfaceVariant` role.
  @override
  final BorderSide borderSide;

  @override
  UnderlineInputBorder copyWith({BorderSide? borderSide}) =>
      UnderlineInputBorder(borderSide: borderSide ?? this.borderSide);

  @override
  String get _role => _onSurfaceVariantRole;

  @override
  String _shadowOf(String color, double width) =>
      'inset 0 -${cssPx(width)} 0 0 $color';
}

/// What a field paints in its enabled and focused states, from its
/// decoration (Flutter's `_getDefaultBorder`): the `box-shadow` of each (null
/// for none) and the shape's radius. Not exported.
({String? enabled, String? focused, BorderRadius? radius}) resolveFieldBorders(
  InputDecoration d,
) {
  final base = d.border ?? const UnderlineInputBorder();
  // A border from `border:` that gave no color takes the scheme; one with a
  // color of its own keeps it, and so does `enabledBorder:`/`focusedBorder:`.
  final fromBorder = base._hasColor
      ? base.shadow
      : base._paint(base._role, base.borderSide.width);
  // web: Flutter's M3 focused field is 2 px of `primary`.
  final focusedFromBorder = base._hasColor
      ? base.shadow
      : base._paint(_primaryRole, 2);
  return (
    enabled: d.enabledBorder != null ? d.enabledBorder!.shadow : fromBorder,
    focused: d.focusedBorder != null
        ? d.focusedBorder!.shadow
        : focusedFromBorder,
    radius:
        (d.enabledBorder ?? base).borderRadius ??
        (d.focusedBorder ?? base).borderRadius,
  );
}

/// The border a `<select>` draws for [d]: the real `border` of its
/// `enabledBorder` (else `border`), with the scheme's role where the border
/// gives no color; null when the decoration names none (the select keeps its
/// own outline). Not exported.
CssDeclarations? selectBorderCss(InputDecoration d) {
  final b = d.enabledBorder ?? d.border;
  if (b == null) return null;
  if (b.borderSide.style == BorderStyle.none) return const {'border': '0'};
  final side = b._hasColor
      ? b.borderSide.css
      : '${cssPx(b.borderSide.width)} solid ${b._role}';
  return switch (b) {
    UnderlineInputBorder() => {'border': '0', 'border-bottom': side},
    _ => {'border': side},
  };
}

/// Flutter's `TextInputType` → `<input type>` / `inputmode`.
///
/// ```dart
/// TextField(keyboardType: TextInputType.number)          // digits
/// TextField(
///   keyboardType: TextInputType.numberWithOptions(decimal: true),
/// )                                                      // digits and a point
/// ```
class TextInputType {
  const TextInputType._(this.htmlType, this.inputMode, [this._name]);

  /// Numeric input with Flutter's options: [signed] allows a minus sign and
  /// [decimal] a decimal separator.
  ///
  /// `// web:` `decimal: true` is `inputmode="decimal"`; otherwise
  /// `inputmode="numeric"` (digits only). A browser has no keyboard with a
  /// minus but no point, so [signed] does not change the attribute: the
  /// field stays a text input, and the sign is the visitor's to type.
  const factory TextInputType.numberWithOptions({bool signed, bool decimal}) =
      _NumberInputType;

  /// Freeform text (`<input type="text">`).
  static const text = TextInputType._('text', 'text', 'text');

  /// Whole, unsigned numbers (`<input type="text" inputmode="numeric">`):
  /// Flutter's `numberWithOptions()`.
  static const number = _NumberInputType();

  /// A telephone number (`<input type="tel">`).
  static const phone = TextInputType._('tel', 'tel', 'phone');

  /// An email address (`<input type="email">`).
  static const emailAddress = TextInputType._('email', 'email', 'emailAddress');

  /// A URL (`<input type="url">`).
  static const url = TextInputType._('url', 'url', 'url');

  /// A search query (`<input type="search">`: the keyboard's search key).
  static const webSearch = TextInputType._('search', 'search', 'webSearch');

  /// Text over several lines (`<input type="text">`; `maxLines: null` or
  /// more than one makes the `<textarea>`).
  static const multiline = TextInputType._('text', 'text', 'multiline');

  /// A date and time (`<input type="text">`, the text keyboard).
  static const datetime = TextInputType._('text', 'text', 'datetime');

  /// A person's name (`<input type="text">`).
  static const name = TextInputType._('text', 'text', 'name');

  /// A postal address (`<input type="text">`).
  static const streetAddress = TextInputType._('text', 'text', 'streetAddress');

  /// No virtual keyboard (`inputmode="none"`): the page brings its own.
  static const none = TextInputType._('text', 'none', 'none');

  /// A password the visitor can see: plain text without autocorrection.
  /// The masking comes only from `obscureText`, as in Flutter.
  static const visiblePassword = TextInputType._(
    'text',
    'text',
    'visiblePassword',
  );

  /// The `<input type>` attribute value.
  final String htmlType;

  /// The `inputmode` attribute value.
  final String inputMode;

  final String? _name;

  @override
  String toString() => 'TextInputType.${_name ?? inputMode}';
}

class _NumberInputType extends TextInputType {
  const _NumberInputType({this.signed = false, this.decimal = false})
    : super._('text', decimal ? 'decimal' : 'numeric');

  /// Whether a minus sign is allowed.
  final bool signed;

  /// Whether a decimal separator is allowed.
  final bool decimal;

  @override
  bool operator ==(Object other) =>
      other is _NumberInputType &&
      other.signed == signed &&
      other.decimal == decimal;

  @override
  int get hashCode => Object.hash(signed, decimal);

  @override
  String toString() =>
      'TextInputType.numberWithOptions(signed: $signed, decimal: $decimal)';
}

/// Flutter's `TextInputAction` → the virtual keyboard's enter key
/// (`enterkeyhint`).
enum TextInputAction {
  /// No action (the browser's own key).
  none(null),

  /// No specific action (the browser's own key).
  unspecified(null),

  /// The input is finished (`enterkeyhint="done"`).
  done('done'),

  /// Go to the target of the text (`go`).
  go('go'),

  /// Search for the text (`search`).
  search('search'),

  /// Send the text (`send`).
  send('send'),

  /// Next field (`next`).
  next('next'),

  /// Previous field (`previous`).
  previous('previous'),

  /// Continue: the browser has no such key.
  continueAction(null),

  /// Join: the browser has no such key.
  join(null),

  /// Route: the browser has no such key.
  route(null),

  /// Emergency call: the browser has no such key.
  emergencyCall(null),

  /// A new line (`enterkeyhint="enter"`).
  newline('enter');

  const TextInputAction(this.enterKeyHint);

  /// The `enterkeyhint` value, or null when the browser has no such key.
  final String? enterKeyHint;
}

/// Flutter's `TextCapitalization` → `autocapitalize`.
enum TextCapitalization {
  /// Every character of a word starts in capitals (`words`).
  words('words'),

  /// The first letter of each sentence (`sentences`).
  sentences('sentences'),

  /// Every character (`characters`).
  characters('characters'),

  /// No capitalization (`off`).
  none('off');

  const TextCapitalization(this.autocapitalize);

  /// The `autocapitalize` value.
  final String autocapitalize;
}

/// Flutter's `FloatingLabelBehavior`.
///
/// web: the label always sits above the field. [never] makes it the
/// placeholder instead (a label that acts as a hint inside the field);
/// [auto] and [always] are the label above.
enum FloatingLabelBehavior {
  /// The label is the placeholder: no label above.
  never,

  /// The label above the field (Flutter floats it while the field is
  /// focused or filled).
  auto,

  /// The label above the field.
  always,
}

/// Flutter's `AutofillHints`: the names for `TextField.autofillHints`.
/// They go to the browser as their HTML `autocomplete` token (Flutter's own
/// mapping for the web); a string that is not one of these (`shipping`,
/// `home`, `off`) goes as it is, so an HTML token works too.
abstract final class AutofillHints {
  /// `birthday` → `bday`.
  static const String birthday = 'birthday';

  /// `birthdayDay` → `bday-day`.
  static const String birthdayDay = 'birthdayDay';

  /// `birthdayMonth` → `bday-month`.
  static const String birthdayMonth = 'birthdayMonth';

  /// `birthdayYear` → `bday-year`.
  static const String birthdayYear = 'birthdayYear';

  /// `countryCode` → `country`.
  static const String countryCode = 'countryCode';

  /// `countryName` → `country-name`.
  static const String countryName = 'countryName';

  /// `creditCardExpirationDate` → `cc-exp`.
  static const String creditCardExpirationDate = 'creditCardExpirationDate';

  /// `creditCardExpirationMonth` → `cc-exp-month`.
  static const String creditCardExpirationMonth = 'creditCardExpirationMonth';

  /// `creditCardExpirationYear` → `cc-exp-year`.
  static const String creditCardExpirationYear = 'creditCardExpirationYear';

  /// `creditCardFamilyName` → `cc-family-name`.
  static const String creditCardFamilyName = 'creditCardFamilyName';

  /// `creditCardGivenName` → `cc-given-name`.
  static const String creditCardGivenName = 'creditCardGivenName';

  /// `creditCardMiddleName` → `cc-additional-name`.
  static const String creditCardMiddleName = 'creditCardMiddleName';

  /// `creditCardName` → `cc-name`.
  static const String creditCardName = 'creditCardName';

  /// `creditCardNumber` → `cc-number`.
  static const String creditCardNumber = 'creditCardNumber';

  /// `creditCardSecurityCode` → `cc-csc`.
  static const String creditCardSecurityCode = 'creditCardSecurityCode';

  /// `creditCardType` → `cc-type`.
  static const String creditCardType = 'creditCardType';

  /// `email`.
  static const String email = 'email';

  /// `familyName` → `family-name`.
  static const String familyName = 'familyName';

  /// `fullStreetAddress` → `street-address`.
  static const String fullStreetAddress = 'fullStreetAddress';

  /// `gender` → `sex`.
  static const String gender = 'gender';

  /// `givenName` → `given-name`.
  static const String givenName = 'givenName';

  /// `jobTitle` → `organization-title`.
  static const String jobTitle = 'jobTitle';

  /// `language`.
  static const String language = 'language';

  /// `middleName` → `additional-name`.
  static const String middleName = 'middleName';

  /// `name`.
  static const String name = 'name';

  /// `namePrefix` → `honorific-prefix`.
  static const String namePrefix = 'namePrefix';

  /// `nameSuffix` → `honorific-suffix`.
  static const String nameSuffix = 'nameSuffix';

  /// `newPassword` → `new-password`.
  static const String newPassword = 'newPassword';

  /// `nickname`.
  static const String nickname = 'nickname';

  /// `oneTimeCode` → `one-time-code`.
  static const String oneTimeCode = 'oneTimeCode';

  /// `organizationName` → `organization`.
  static const String organizationName = 'organizationName';

  /// `password` → `current-password`.
  static const String password = 'password';

  /// `photo`.
  static const String photo = 'photo';

  /// `postalCode` → `postal-code`.
  static const String postalCode = 'postalCode';

  /// `streetAddressLevel1` → `address-level1` (the state or province).
  static const String streetAddressLevel1 = 'streetAddressLevel1';

  /// `streetAddressLevel2` → `address-level2` (the city).
  static const String streetAddressLevel2 = 'streetAddressLevel2';

  /// `streetAddressLine1` → `address-line1`.
  static const String streetAddressLine1 = 'streetAddressLine1';

  /// `streetAddressLine2` → `address-line2`.
  static const String streetAddressLine2 = 'streetAddressLine2';

  /// `streetAddressLine3` → `address-line3`.
  static const String streetAddressLine3 = 'streetAddressLine3';

  /// `telephoneNumber` → `tel`.
  static const String telephoneNumber = 'telephoneNumber';

  /// `telephoneNumberCountryCode` → `tel-country-code`.
  static const String telephoneNumberCountryCode = 'telephoneNumberCountryCode';

  /// `telephoneNumberNational` → `tel-national`.
  static const String telephoneNumberNational = 'telephoneNumberNational';

  /// `streetAddressLevel3` → `address-level3`.
  static const String streetAddressLevel3 = 'streetAddressLevel3';

  /// `streetAddressLevel4` → `address-level4`.
  static const String streetAddressLevel4 = 'streetAddressLevel4';

  /// `telephoneNumberAreaCode` → `tel-area-code`.
  static const String telephoneNumberAreaCode = 'telephoneNumberAreaCode';

  /// `telephoneNumberExtension` → `tel-extension`.
  static const String telephoneNumberExtension = 'telephoneNumberExtension';

  /// `telephoneNumberLocal` → `tel-local`.
  static const String telephoneNumberLocal = 'telephoneNumberLocal';

  /// `telephoneNumberLocalPrefix` → `tel-local-prefix`.
  static const String telephoneNumberLocalPrefix = 'telephoneNumberLocalPrefix';

  /// `telephoneNumberLocalSuffix` → `tel-local-suffix`.
  static const String telephoneNumberLocalSuffix = 'telephoneNumberLocalSuffix';

  /// `transactionAmount` → `transaction-amount`.
  static const String transactionAmount = 'transactionAmount';

  /// `transactionCurrency` → `transaction-currency`.
  static const String transactionCurrency = 'transactionCurrency';

  /// `url`.
  static const String url = 'url';

  /// `username`.
  static const String username = 'username';

  // Flutter's mapping to the browser's `autocomplete` tokens
  // (`BrowserAutofillHints` of the web engine); the rest goes as it is.
  static const _tokens = <String, String>{
    'birthday': 'bday',
    'birthdayDay': 'bday-day',
    'birthdayMonth': 'bday-month',
    'birthdayYear': 'bday-year',
    'countryCode': 'country',
    'countryName': 'country-name',
    'creditCardExpirationDate': 'cc-exp',
    'creditCardExpirationMonth': 'cc-exp-month',
    'creditCardExpirationYear': 'cc-exp-year',
    'creditCardFamilyName': 'cc-family-name',
    'creditCardGivenName': 'cc-given-name',
    'creditCardMiddleName': 'cc-additional-name',
    'creditCardName': 'cc-name',
    'creditCardNumber': 'cc-number',
    'creditCardSecurityCode': 'cc-csc',
    'creditCardType': 'cc-type',
    'familyName': 'family-name',
    'fullStreetAddress': 'street-address',
    'gender': 'sex',
    'givenName': 'given-name',
    'jobTitle': 'organization-title',
    'middleName': 'additional-name',
    'namePrefix': 'honorific-prefix',
    'nameSuffix': 'honorific-suffix',
    'newPassword': 'new-password',
    'oneTimeCode': 'one-time-code',
    'organizationName': 'organization',
    'password': 'current-password',
    'postalCode': 'postal-code',
    'streetAddressLevel1': 'address-level1',
    'streetAddressLevel2': 'address-level2',
    'streetAddressLevel3': 'address-level3',
    'streetAddressLevel4': 'address-level4',
    'streetAddressLine1': 'address-line1',
    'streetAddressLine2': 'address-line2',
    'streetAddressLine3': 'address-line3',
    'telephoneNumber': 'tel',
    'telephoneNumberAreaCode': 'tel-area-code',
    'telephoneNumberCountryCode': 'tel-country-code',
    'telephoneNumberExtension': 'tel-extension',
    'telephoneNumberLocal': 'tel-local',
    'telephoneNumberLocalPrefix': 'tel-local-prefix',
    'telephoneNumberLocalSuffix': 'tel-local-suffix',
    'telephoneNumberNational': 'tel-national',
    'transactionAmount': 'transaction-amount',
    'transactionCurrency': 'transaction-currency',
  };
}

/// The `autocomplete` value of [hints]: one token each, in order (`null`
/// for none). Not exported.
String? autofillToken(Iterable<String>? hints) {
  if (hints == null || hints.isEmpty) return null;
  return [for (final h in hints) AutofillHints._tokens[h] ?? h].join(' ');
}

/// Flutter's `InputDecoration`, subset.
class InputDecoration {
  /// Creates the visual properties for a `TextField`.
  const InputDecoration({
    this.label,
    this.labelText,
    this.helperText,
    this.errorText,
    this.errorTextWatch,
    this.hintText,
    this.hintStyle,
    this.helperStyle,
    this.errorStyle,
    this.hoverColor,
    this.errorBorder,
    this.prefixIcon,
    this.prefixIconConstraints,
    this.suffixIcon,
    this.suffixIconConstraints,
    this.filled = false,
    this.fillColor,
    this.contentPadding,
    this.border,
    this.enabledBorder,
    this.focusedBorder,
    this.constraints,
    this.isDense,
    this.labelStyle,
    this.icon,
    this.prefix,
    this.prefixText,
    this.suffix,
    this.suffixText,
    this.counter,
    this.counterText,
    this.floatingLabelBehavior,
    this.errorMaxLines,
    this.isCollapsed,
  }) : assert(
         label == null || labelText == null,
         'Declaring both label and labelText is not supported.',
       );

  /// A widget shown above the field instead of [labelText] (a `Text.rich`
  /// with a grey «optional»): it is the `<label>` for the control, so its
  /// text is the field's accessible name. Only one of [label] and
  /// [labelText]. In a `Watch.list` row, `label: row.text(todos.titleOf)`
  /// is a visible label that follows the row (`row.bind` is for attributes,
  /// not for [labelText]). `// web:` the label is always above the field, also with
  /// [FloatingLabelBehavior.never] (a placeholder can't hold a widget).
  final Widget? label;

  /// Style of the label above the field.
  final TextStyle? labelStyle;

  /// An icon before the field, outside its border (and before the label).
  final Widget? icon;

  /// A widget inside the border, before the input (after [prefixIcon]).
  /// Over [prefixText].
  final Widget? prefix;

  /// Text inside the border, before the input (`\$ `, `+52 `): not part of
  /// the value, and it keeps its spaces. `// web:` always shown (Flutter
  /// shows it while the label floats).
  final String? prefixText;

  /// A widget inside the border, after the input (before [suffixIcon]).
  /// Over [suffixText].
  final Widget? suffix;

  /// Text inside the border, after the input (`kg`, `USD`).
  final String? suffixText;

  /// A widget for the counter line, at the end of the helper's row. Over
  /// [counterText].
  final Widget? counter;

  /// The text at the end of the helper's row: replaces the live count of
  /// `TextField.maxLength` (`''` removes the counter).
  final String? counterText;

  /// Whether the label floats. `// web:` the label is always above the
  /// field; [FloatingLabelBehavior.never] makes it the placeholder.
  final FloatingLabelBehavior? floatingLabelBehavior;

  /// The most lines [errorText] takes (clamped with an ellipsis). Null does
  /// not clamp. `// web:` Flutter's default is one line.
  final int? errorMaxLines;

  /// Whether the decoration is as small as the input: no content padding
  /// (unless [contentPadding] says otherwise).
  final bool? isCollapsed;

  /// Whether the field is compact: less vertical padding (8 px instead of
  /// 16 px) when [contentPadding] is null.
  final bool? isDense;

  /// Shown above the field (a `<label>` for the control) and its
  /// accessible name.
  final String? labelText;

  /// Shown below the field when there is no error (the control's
  /// `aria-describedby`).
  final String? helperText;

  /// A server-side error (e.g. after a failed submit), shown below; the
  /// control gets `aria-invalid` and points at it (`aria-describedby`).
  final String? errorText;

  /// [errorText] bound to a `ThorState` method that returns the message
  /// (`String?`; null or empty: no error), kept current in the browser: the
  /// message line shows it (the helper text comes back when it is empty),
  /// the field gets the error border and `aria-invalid`, with no rebuild.
  /// Replaces `WatchAttributes({AttributeName.ariaOf(AriaAttribute.invalid): …})` on the field. Only
  /// `TextField` and `TextFormField` read it; a fixed [errorText] wins.
  ///
  /// ```dart
  /// TextField(decoration: InputDecoration(
  ///   labelText: 'Departure',
  ///   errorTextWatch: flights.startError,
  /// ))
  /// ```
  ///
  /// `// web:` no Flutter counterpart: Flutter rebuilds the widget with a new
  /// `errorText` (or reads `forceErrorText`); the page is not rebuilt here.
  final String? Function()? errorTextWatch;

  /// Placeholder text shown when the field is empty.
  final String? hintText;

  /// Style for `hintText`.
  final TextStyle? hintStyle;

  /// Icon shown before the input, in a 48×48 box.
  final Widget? prefixIcon;

  /// Icon shown after the input, in a 48×48 box.
  final Widget? suffixIcon;

  /// The size of the [prefixIcon]'s box; null is Flutter's default, 48×48
  /// at least. `BoxConstraints()` sizes it by the icon, so a dense field
  /// with an icon stays dense.
  final BoxConstraints? prefixIconConstraints;

  /// The size of the [suffixIcon]'s box; like [prefixIconConstraints].
  final BoxConstraints? suffixIconConstraints;

  /// Whether to paint `fillColor` behind the field.
  final bool filled;

  /// Background color when `filled` is true.
  final Color? fillColor;

  /// Padding around the input's text.
  final EdgeInsets? contentPadding;

  /// The border used when no more specific border is set.
  final InputBorder? border;

  /// The border shown when the field is enabled and not focused.
  final InputBorder? enabledBorder;

  /// The border shown when the field has focus.
  final InputBorder? focusedBorder;

  /// The border shown with an error (the server's `errorText` or a failed
  /// validation).
  final InputBorder? errorBorder;

  /// Style of the helper text below the field.
  final TextStyle? helperStyle;

  /// Style of the error text below the field.
  final TextStyle? errorStyle;

  /// Background while the pointer hovers the field (CSS `:hover`).
  final Color? hoverColor;

  /// Additional min/max size constraints on the field.
  final BoxConstraints? constraints;

  /// A copy with the given fields replaced (Flutter's `copyWith`).
  InputDecoration copyWith({
    Widget? label,
    String? labelText,
    String? helperText,
    String? errorText,
    String? Function()? errorTextWatch,
    String? hintText,
    TextStyle? hintStyle,
    TextStyle? helperStyle,
    TextStyle? errorStyle,
    Color? hoverColor,
    InputBorder? errorBorder,
    Widget? prefixIcon,
    BoxConstraints? prefixIconConstraints,
    Widget? suffixIcon,
    BoxConstraints? suffixIconConstraints,
    bool? filled,
    Color? fillColor,
    EdgeInsets? contentPadding,
    InputBorder? border,
    InputBorder? enabledBorder,
    InputBorder? focusedBorder,
    BoxConstraints? constraints,
    bool? isDense,
    TextStyle? labelStyle,
    Widget? icon,
    Widget? prefix,
    String? prefixText,
    Widget? suffix,
    String? suffixText,
    Widget? counter,
    String? counterText,
    FloatingLabelBehavior? floatingLabelBehavior,
    int? errorMaxLines,
    bool? isCollapsed,
  }) => InputDecoration(
    label: label ?? this.label,
    labelText: labelText ?? this.labelText,
    helperText: helperText ?? this.helperText,
    errorText: errorText ?? this.errorText,
    errorTextWatch: errorTextWatch ?? this.errorTextWatch,
    hintText: hintText ?? this.hintText,
    hintStyle: hintStyle ?? this.hintStyle,
    helperStyle: helperStyle ?? this.helperStyle,
    errorStyle: errorStyle ?? this.errorStyle,
    hoverColor: hoverColor ?? this.hoverColor,
    errorBorder: errorBorder ?? this.errorBorder,
    prefixIcon: prefixIcon ?? this.prefixIcon,
    prefixIconConstraints: prefixIconConstraints ?? this.prefixIconConstraints,
    suffixIcon: suffixIcon ?? this.suffixIcon,
    suffixIconConstraints: suffixIconConstraints ?? this.suffixIconConstraints,
    filled: filled ?? this.filled,
    fillColor: fillColor ?? this.fillColor,
    contentPadding: contentPadding ?? this.contentPadding,
    border: border ?? this.border,
    enabledBorder: enabledBorder ?? this.enabledBorder,
    focusedBorder: focusedBorder ?? this.focusedBorder,
    constraints: constraints ?? this.constraints,
    isDense: isDense ?? this.isDense,
    labelStyle: labelStyle ?? this.labelStyle,
    icon: icon ?? this.icon,
    prefix: prefix ?? this.prefix,
    prefixText: prefixText ?? this.prefixText,
    suffix: suffix ?? this.suffix,
    suffixText: suffixText ?? this.suffixText,
    counter: counter ?? this.counter,
    counterText: counterText ?? this.counterText,
    floatingLabelBehavior: floatingLabelBehavior ?? this.floatingLabelBehavior,
    errorMaxLines: errorMaxLines ?? this.errorMaxLines,
    isCollapsed: isCollapsed ?? this.isCollapsed,
  );

  /// This decoration with [theme]'s values where its own are null
  /// (Flutter's `applyDefaults`): what a field does with
  /// `ThemeData.inputDecorationTheme`.
  // web: `filled` is not nullable here: the theme's `filled: true` fills a
  // field that leaves it at its default.
  InputDecoration applyDefaults(InputDecorationTheme theme) => copyWith(
    hintStyle: hintStyle ?? theme.hintStyle,
    helperStyle: helperStyle ?? theme.helperStyle,
    errorStyle: errorStyle ?? theme.errorStyle,
    hoverColor: hoverColor ?? theme.hoverColor,
    errorBorder: errorBorder ?? theme.errorBorder,
    labelStyle: labelStyle ?? theme.labelStyle,
    filled: filled || theme.filled,
    fillColor: fillColor ?? theme.fillColor,
    contentPadding: contentPadding ?? theme.contentPadding,
    border: border ?? theme.border,
    enabledBorder: enabledBorder ?? theme.enabledBorder,
    focusedBorder: focusedBorder ?? theme.focusedBorder,
    constraints: constraints ?? theme.constraints,
    isDense: isDense ?? theme.isDense,
  );
}

/// Flutter's `InputDecorationTheme`, subset: the default look of fields
/// (`ThemeData.inputDecorationTheme`, under each field's own
/// `InputDecoration`) and of a field that builds its own decoration (a
/// `DropdownMenu`'s `inputDecorationTheme`).
class InputDecorationTheme {
  /// Creates the default look of input fields.
  const InputDecorationTheme({
    this.labelStyle,
    this.helperStyle,
    this.hintStyle,
    this.errorStyle,
    this.contentPadding,
    this.filled = false,
    this.fillColor,
    this.hoverColor,
    this.border,
    this.enabledBorder,
    this.focusedBorder,
    this.errorBorder,
    this.constraints,
    this.isDense = false,
  });

  /// Whether fields are compact (see `InputDecoration.isDense`).
  final bool isDense;

  /// Style of the label above the field.
  final TextStyle? labelStyle;

  /// Style of the helper text below the field.
  final TextStyle? helperStyle;

  /// Style of the hint shown while the field is empty.
  final TextStyle? hintStyle;

  /// Style of the error text below the field.
  final TextStyle? errorStyle;

  /// Padding around the field's content.
  final EdgeInsets? contentPadding;

  /// Whether to paint [fillColor] behind the field.
  final bool filled;

  /// Background color when [filled] is true.
  final Color? fillColor;

  /// Background while the pointer hovers the field.
  final Color? hoverColor;

  /// The border used when no more specific border is set.
  final InputBorder? border;

  /// The border shown when the field is enabled and not focused.
  final InputBorder? enabledBorder;

  /// The border shown when the field has focus.
  final InputBorder? focusedBorder;

  /// The border shown with an error.
  final InputBorder? errorBorder;

  /// Min/max size constraints on the field (a fixed height is
  /// `BoxConstraints.tightFor(height: 40)`). `// web:` on a multi-line
  /// field with fixed rows a tight height is the height its `<textarea>`
  /// starts at, and it can still be resized taller.
  final BoxConstraints? constraints;
}

/// Flutter's `TextField` → a native `<input>` inside a decorated row.
///
/// Layout follows Flutter's InputDecorator (Material 3): a prefix/suffix
/// icon sits in a 48×48 box, and when present it replaces the start/end
/// content padding (with a 4px gap). The focused border is applied with
/// `:focus-within`, so focus styling needs no Dart state.
///
/// With a `labelText`, `helperText` or `errorText` the row sits in a
/// column: the label above (a `<label for>` the control), the helper or
/// error line below (the control's `aria-describedby`; an error also sets
/// `aria-invalid`). `// web:` the label sits above the border instead of
/// floating inside it. The control's id is [id], else `f-<name>`, else one
/// unique in the page.
class TextField extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a native text input field.
  const TextField({
    super.key,
    this.decoration = const InputDecoration(),
    this.style,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.enabled,
    this.autofocus = false,
    this.name,
    this.initialValue,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.clearOnSubmitted = false,
    this.id,
    this.inputAttributes,
    this.readOnly = false,
    this.maxLength,
    this.textInputAction,
    this.textCapitalization,
    this.textAlign = TextAlign.start,
    this.autofillHints,
    this.datalist,
    this.obscuringCharacter = '\u2022',
    this.expands = false,
  }) : assert(
         maxLength == null || maxLength == noMaxLength || maxLength > 0,
         'maxLength must be null, TextField.noMaxLength or greater than 0',
       ),
       assert(
         obscuringCharacter.length == 1,
         'obscuringCharacter must be one character',
       ),
       assert(
         !expands || minLines == null,
         'an expanding field fills its height: minLines must be null',
       );

  /// If [maxLength] is this, the counter shows only the count and nothing
  /// limits the text.
  static const int noMaxLength = -1;

  /// Whether the text can't be edited (`readonly`): it can still be focused,
  /// selected and copied, and it is sent with a form (unlike [enabled]).
  ///
  /// web: the browser skips its own checks (`required`, `minlength`…) on a
  /// read-only field, where Flutter's `validator` still runs; a
  /// `FormSchema` on the server checks it either way.
  final bool readOnly;

  /// The most characters the field takes, counted as Flutter counts them:
  /// user-perceived characters (grapheme clusters), so an emoji is one. A
  /// counter (`0/20`, live) shows below the field unless
  /// [InputDecoration.counterText] is `''`; [noMaxLength] counts without
  /// limiting.
  ///
  /// web: the browser stops the text with `maxlength`, which counts UTF-16
  /// code units: it never lets more than [maxLength] characters in (also
  /// without JavaScript), but text with emoji or accents made of several
  /// units reaches that stop before the counter does. The live counter uses
  /// `Intl.Segmenter` (an inline `oninput` handler, no script file; a strict
  /// CSP blocks it and the counter then shows the value of the page's
  /// render).
  final int? maxLength;

  /// The enter key of the virtual keyboard (`enterkeyhint`). web: a
  /// keyboard hint only: the enter key still submits the form (or runs
  /// `onSubmitted`).
  final TextInputAction? textInputAction;

  /// How the virtual keyboard capitalizes (`autocapitalize`). Left null the
  /// browser decides (Flutter's `none` is `TextCapitalization.none`,
  /// which sets `autocapitalize="off"`).
  final TextCapitalization? textCapitalization;

  /// How the text aligns inside the field (`text-align`).
  final TextAlign textAlign;

  /// What the field holds, for the browser to autofill it (`autocomplete`):
  /// [AutofillHints] names or HTML tokens. Under [inputAttributes].
  final Iterable<String>? autofillHints;

  /// The id of a `Datalist` whose options the browser suggests while typing
  /// (`list`). Under [inputAttributes].
  ///
  /// `// web:` Flutter's `TextField` has no suggestions (`Autocomplete`
  /// draws its own overlay); this is the native `<datalist>`.
  final String? datalist;

  /// Flutter's character that hides a password. web: the browser draws its
  /// own dots in `<input type="password">`; this is accepted and not used.
  final String obscuringCharacter;

  /// Whether the field fills the height its parent gives it (a
  /// `<textarea>` with no rows; put it in an `Expanded` or a sized box, as in
  /// Flutter). [minLines] must be null.
  final bool expands;

  /// A `TextEditingController` field of a `ThorState`: the field shows its
  /// text (over [initialValue]) and typing updates it.
  final TextEditingController? controller;

  /// A `FocusNode` field of a `ThorState` that focuses this field from a
  /// method (`node.requestFocus()`).
  final FocusNode? focusNode;

  /// The visual properties (label, icons, border…) around the input.
  final InputDecoration decoration;

  // web: DOM id of the `<input>` (Flutter has none).
  /// DOM id of the `<input>`.
  final String? id;

  // web: more attributes for the `<input>`; Flutter has none.
  /// More attributes for the `<input>` (validation, autocomplete…).
  final HtmlAttributes? inputAttributes;

  /// The style to apply to the input's text.
  final TextStyle? style;

  /// The keyboard/`<input type>` to use for text entry. Null is
  /// [TextInputType.text].
  final TextInputType? keyboardType;

  /// Whether to hide the text being edited (`<input type="password">`).
  final bool obscureText;

  /// Visible lines: more than 1 makes a multi-line `<textarea>` with that
  /// many rows (Flutter: `maxLines`). Null grows without limit (from
  /// [minLines], 1 by default). `// web:` without [minLines] a number keeps
  /// that height and scrolls instead of growing up to `maxLines`; null and
  /// [minLines] grow with CSS `field-sizing: content` (a browser without it
  /// keeps the starting rows and scrolls).
  final int? maxLines;

  /// Lines shown when the field is empty (Flutter: `minLines`, at most
  /// [maxLines]): a `<textarea>` that starts that tall and grows with its
  /// text up to [maxLines]. `// web:` it grows with CSS `field-sizing`;
  /// browsers without it keep [minLines] rows and scroll.
  final int? minLines;

  /// Whether the field accepts input. Null is enabled.
  final bool? enabled;

  /// Whether to focus the field automatically when it is first shown.
  final bool autofocus;

  // web: the name a browser form sends the value under.
  /// Form field name.
  final String? name;

  /// The text to prefill the field with.
  final String? initialValue;

  /// Called with the current value on every keystroke (`input` event).
  final void Function(String value)? onChanged;

  /// Called with the current value when the field is submitted (Enter key).
  /// `// web:` with a `ThorState` method, Enter doesn't submit the
  /// enclosing form (it runs the method instead).
  final void Function(String value)? onSubmitted;

  // web: in Flutter, `controller.clear()` inside the callback.
  /// Empty the field after [onSubmitted] (a tag or chat input).
  final bool clearOnSubmitted;

  String? get _value {
    final c = controller;
    return c == null ? initialValue : untracked(() => c.text);
  }

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) {
    final field = fieldInForm(this, context);
    final d = themedDecoration(context, field.decoration);
    if (d.labelText == null &&
        d.label == null &&
        d.helperText == null &&
        d.errorText == null &&
        d.errorTextWatch == null &&
        !field._hasCounter(d) &&
        d.icon == null) {
      return _controlBound(
        context,
        (control) => field._row(d, id, const {}, control),
      );
    }
    return decoratedTextField(field, context);
  }

  /// The counter line's content: a widget, the decoration's text, or the
  /// count of [maxLength] (`3/20`); null when there is none.
  Widget? _counter(InputDecoration d, String inputId) {
    if (!_hasCounter(d)) return null;
    final custom = d.counter;
    final text = d.counterText ?? _count(graphemeCount(_value ?? ''));
    return thorElement(
      'span',
      css: const {
        'flex': 'none',
        'margin-inline-start': 'auto',
        'font-size': '12px',
        'line-height': '16px',
        'padding': '0 16px',
        'white-space': 'nowrap',
        'color': ThemeTokens.onSurfaceVariant,
      },
      attributes: {'id': '$inputId-cnt'},
      children: [custom ?? Widget.text(text)],
    );
  }

  String _count(int n) =>
      maxLength == null || maxLength == noMaxLength ? '$n' : '$n/$maxLength';

  /// The `oninput` that keeps the counter's count live: grapheme clusters
  /// through `Intl.Segmenter` (code points where the browser lacks it). Only
  /// for the count of [maxLength], not for a fixed text or widget.
  ///
  /// The same text for every field (the control's own `id` and `maxlength`
  /// say which counter and which limit), so a strict CSP that allows inline
  /// handlers by hash (`'unsafe-hashes'`) needs one hash for all of them.
  String? _liveCounter(InputDecoration d) {
    if (maxLength == null || d.counter != null || d.counterText != null) {
      return null;
    }
    return counterHandler;
  }

  bool _hasCounter(InputDecoration d) =>
      d.counter != null ||
      (d.counterText == null ? maxLength != null : d.counterText!.isNotEmpty);

  /// A copy with the value and the decoration the enclosing form decided
  /// (every parameter of the field goes along). Not exported.
  TextField _with({
    String? initialValue,
    InputDecoration? decoration,
    Iterable<String>? autofillHints,
  }) => TextField(
    key: key,
    decoration: decoration ?? this.decoration,
    style: style,
    keyboardType: keyboardType,
    obscureText: obscureText,
    maxLines: maxLines,
    minLines: minLines,
    enabled: enabled,
    autofocus: autofocus,
    name: name,
    initialValue: initialValue,
    controller: controller,
    focusNode: focusNode,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    clearOnSubmitted: clearOnSubmitted,
    id: id,
    inputAttributes: inputAttributes,
    readOnly: readOnly,
    maxLength: maxLength,
    textInputAction: textInputAction,
    textCapitalization: textCapitalization,
    textAlign: textAlign,
    autofillHints: autofillHints ?? this.autofillHints,
    datalist: datalist,
    obscuringCharacter: obscuringCharacter,
    expands: expands,
  );

  /// The bordered row with the control. [linked] are the attributes that tie
  /// the control to its message line (the caller's [inputAttributes] win).
  ///
  /// [control]: bound attributes of a wrapper that belong to the control
  /// (see [_controlBound]); they win over the field's own.
  Widget _row(
    InputDecoration d,
    String? inputId,
    Map<String, String> linked, [
    Map<String, String> control = const {},
    bool inColumn = false,
  ]) {
    assert(
      minLines == null ||
          (minLines! >= 1 && (maxLines == null || minLines! <= maxLines!)),
      'minLines must be between 1 and maxLines',
    );
    final padding = numericInsets(
      d.contentPadding ??
          (d.isCollapsed ?? false
              ? EdgeInsets.zero
              : d.isDense ?? false
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 16)),
      'InputDecoration.contentPadding',
    );
    final borders = resolveFieldBorders(d);
    final left = d.prefixIcon != null ? 4.0 : padding.left;
    final right = d.suffixIcon != null ? 4.0 : padding.right;
    // Text or a widget inside the border, next to the input: it carries the
    // padding of its side, so the input's text starts right after it.
    final hasPrefix = d.prefix != null || d.prefixText != null;
    final hasSuffix = d.suffix != null || d.suffixText != null;

    const ring = 'var(--t-field-ring, 0 0 #0000)';
    final errorShadow =
        d.errorBorder?.shadow ?? 'inset 0 0 0 2px ${ThemeTokens.error}';
    final multiline =
        maxLines == null || maxLines! > 1 || (minLines ?? 1) > 1 || expands;
    // Starts at minLines rows and grows with the text up to maxLines (or
    // without limit when maxLines is null).
    final grows =
        multiline && (minLines != null || maxLines == null) && !expands;
    final enabled = this.enabled ?? true;
    final keyboardType = this.keyboardType ?? TextInputType.text;
    final paddingY = cssPx(padding.top + padding.bottom);
    // web: a tight height on a fixed-rows `<textarea>` is the height it
    // starts at (Flutter would lay the field out at exactly that): the
    // `<textarea>` carries it so `resize: vertical` still works, and the row
    // only keeps it as a minimum so it grows with the resize.
    final tightHeight = d.constraints;
    final startHeight =
        multiline &&
            !grows &&
            !expands &&
            tightHeight != null &&
            tightHeight.minHeight > 0 &&
            tightHeight.minHeight == tightHeight.maxHeight
        ? tightHeight.minHeight
        : null;
    // web: with a `<label for>` above (the decorator's) the row is a plain
    // box: a second `<label>` around the input would name it twice. Alone,
    // the row is the label, so a click on its padding or affixes focuses
    // the input as Flutter's tap on the decorator does.
    final labelled = _labelShownAbove(d);
    final hint = d.hintText;
    final placeholder =
        hint ??
        (d.floatingLabelBehavior == FloatingLabelBehavior.never
            ? d.labelText
            : null);
    return thorElement(
      labelled ? 'div' : 'label',
      debugName: 'TextField',
      fillsWidth: true,
      css: {
        'display': 'flex',
        'align-items': 'center',
        'box-sizing': 'border-box',
        'min-width': '0',
        if (!labelled) 'cursor': 'text',
        // Flutter paints InputBorders without taking layout space: an inset
        // shadow does the same. `--t-field-ring` lets apps add a focus ring.
        'box-shadow': '${borders.enabled ?? '0 0 #0000'}, $ring',
        'transition-property': 'box-shadow',
        'transition-duration': '150ms',
        if (d.filled)
          'background-color': (d.fillColor ?? const Color(0x0A000000)).css,
        if (borders.radius case final radius?) 'border-radius': radius.css,
        ...?d.constraints?.toCss(),
        if (startHeight != null) 'max-height': 'none',
        // Fills the height it is given: the row grows in the decorator's
        // column, or is the whole height when it stands alone.
        if (expands)
          if (inColumn) ...{
            'flex': '1 1 auto',
            'min-height': '0',
          } else
            'height': '100%',
        if (!enabled) 'opacity': '0.6',
      },
      conditions: [
        if (d.hoverColor case final hover?)
          ConditionalCss(CssCondition.hoverEnabled, {
            'background-color': hover.css,
          }),
        if (borders.focused case final focused?)
          ConditionalCss(CssCondition.focusWithin, {
            'box-shadow': '$focused, $ring',
          }),
        // Invalid (engine validation or a server errorText): Material's
        // error border, over the focused one.
        ConditionalCss(
          const CssCondition.selector(':has(input[aria-invalid="true"])'),
          {'box-shadow': '$errorShadow, $ring'},
        ),
        if (multiline)
          ConditionalCss(
            const CssCondition.selector(':has(textarea[aria-invalid="true"])'),
            {'box-shadow': '$errorShadow, $ring'},
          ),
      ],
      children: [
        if (d.prefixIcon != null)
          thorElement(
            'span',
            css: _iconBox(d.prefixIconConstraints),
            children: [d.prefixIcon!],
          ),
        if (hasPrefix)
          _inlineAffix(
            d.prefix,
            d.prefixText,
            d,
            EdgeInsets.fromLTRB(left, padding.top, 0, padding.bottom),
          ),
        thorElement(
          multiline ? 'textarea' : 'input',
          id: inputId,
          css: {
            ..._inputBase,
            if (multiline) ...{
              'resize': expands ? 'none' : 'vertical',
              'align-self': 'stretch',
            },
            if (expands) 'height': '100%',
            if (startHeight != null) 'height': cssPx(startHeight),
            if (textAlign != TextAlign.start) 'text-align': textAlign.css,
            if (grows) ...{
              'field-sizing': 'content',
              'min-height': 'calc(${minLines ?? 1}lh + $paddingY)',
              if (maxLines != null && maxLines! > (minLines ?? 1))
                'max-height': 'calc(${maxLines}lh + $paddingY)',
            },
            ...?style?.toCss(),
            'padding': EdgeInsets.fromLTRB(
              hasPrefix ? 0 : left,
              padding.top,
              hasSuffix ? 0 : right,
              padding.bottom,
            ).css,
          },
          conditions: [
            ConditionalCss(CssCondition.placeholder, {
              'color':
                  d.hintStyle?.color?.css ??
                  'color-mix(in srgb, currentColor 60%, transparent)',
              if (d.hintStyle?.fontWeight != null)
                'font-weight': '${d.hintStyle!.fontWeight!.value}',
              if (d.hintStyle?.fontSize != null)
                'font-size': cssPx(d.hintStyle!.fontSize!),
              'opacity': '1',
            }),
          ],
          attributes: {
            if (expands)
              ...const <String, String>{}
            else if (multiline)
              'rows': '${minLines ?? maxLines ?? 1}'
            else
              'type': obscureText ? 'password' : keyboardType.htmlType,
            if (keyboardType.inputMode != 'text')
              'inputmode': keyboardType.inputMode,
            if (placeholder != null && placeholder.isNotEmpty)
              'placeholder': placeholder,
            // A placeholder is not a label; like Flutter's semantics, the
            // hint becomes the accessible name when there is no label. A
            // label shown above names it once, through its `<label for>`.
            if (!_namedByLabel(d))
              'aria-label': ?((d.labelText ?? '').trim().isEmpty
                  ? (hint == null || hint.isEmpty ? null : hint)
                  : d.labelText),
            'name': ?name,
            if (!multiline) 'value': ?_value,
            if (!enabled) 'disabled': '',
            if (readOnly) 'readonly': '',
            if (maxLength != null && maxLength! > 0) 'maxlength': '$maxLength',
            'enterkeyhint': ?textInputAction?.enterKeyHint,
            if (keyboardType == TextInputType.visiblePassword) ...const {
              'autocapitalize': 'off',
              'autocorrect': 'off',
              'spellcheck': 'false',
            },
            'autocapitalize': ?textCapitalization?.autocapitalize,
            'autocomplete': ?autofillToken(autofillHints),
            'list': ?datalist,
            if (autofocus) 'autofocus': '',
            textControllerAttr: ?controllerIdOf(controller),
            focusNodeAttr: ?controllerIdOf(focusNode),
            ...?inputAttributes,
            for (final MapEntry(:key, :value) in linked.entries)
              if (!(inputAttributes?.containsKey(key) ?? false)) key: value,
            ...engineAttributes({'input': onChanged, enterEvent: onSubmitted}),
            if (clearOnSubmitted && onSubmitted != null) clearAttr: '',
            // web: a `<textarea>` keeps its text as content, not as a `value`
            // attribute: a bound value (`row.attribute(AttributeName.value, …)`)
            // is drawn as the content, and the browser writes the control's
            // property.
            for (final MapEntry(:key, :value) in control.entries)
              if (!(multiline && key == 'value')) key: value,
          },
          children: [
            if (multiline && (control['value'] ?? _value) != null)
              Widget.text(control['value'] ?? _value!),
          ],
        ),
        if (hasSuffix)
          _inlineAffix(
            d.suffix,
            d.suffixText,
            d,
            EdgeInsets.fromLTRB(0, padding.top, right, padding.bottom),
          ),
        if (d.suffixIcon != null)
          thorElement(
            'span',
            css: _iconBox(d.suffixIconConstraints),
            children: [d.suffixIcon!],
          ),
      ],
    );
  }
}

/// The counter's `oninput` (see `TextField._liveCounter`). Not exported.
const counterHandler =
    'var v=this.value,'
    'n=window.Intl&&Intl.Segmenter?'
    '[...new Intl.Segmenter().segment(v)].length:[...v].length;'
    'document.getElementById(this.id+"-cnt").textContent='
    'n+(this.maxLength>0?"/"+this.maxLength:"")';

/// The text or widget of `prefix`/`suffix` inside the border, next to the
/// input: [padding] is its side's share of the content padding.
Widget _inlineAffix(
  Widget? widget,
  String? text,
  InputDecoration d,
  EdgeInsets padding,
) => thorElement(
  'span',
  css: {
    'display': 'flex',
    'align-items': 'center',
    'flex': 'none',
    'padding': padding.css,
    if (widget == null) ...{
      'white-space': 'pre',
      'color':
          d.hintStyle?.color?.css ??
          'color-mix(in srgb, currentColor 60%, transparent)',
    },
  },
  children: [widget ?? Widget.text(text!)],
);

/// [field] with what the enclosing `Form` says about its `name`: the value
/// that was sent (or the saved one) and its messages, under an explicit
/// `initialValue` and `errorText` of the field. A field with a controller,
/// a password (`obscureText`) or no name is left alone. Not exported.
TextField fieldInForm(TextField field, BuildContext context) {
  field = _inAutofillSection(field, context);
  final n = field.name;
  final scope = n == null ? null : FormScope.maybeOf(context);
  if (n == null || scope == null) return field;
  final fixed =
      field.obscureText ||
      field.controller != null ||
      (scope.schema?.fieldNamed(n)?.secret ?? false);
  final sent = fixed ? null : scope.failed?.values[n];
  final saved = fixed
      ? null
      : _forInput(scope.valueOf(n), field.inputAttributes?['type']);
  final d = field.decoration;
  final error = d.errorText ?? scope.errorTextOf(n);
  final value = sent ?? field.initialValue ?? saved;
  if (value == field.initialValue && error == d.errorText) return field;
  return field._with(
    initialValue: value,
    decoration: error == d.errorText ? d : d.copyWith(errorText: error),
  );
}

/// [field] with the `section-*` token of the `AutofillGroup` around it in
/// front of its hints (only a field that has hints: `off` and a hint that
/// names its own section are left alone).
TextField _inAutofillSection(TextField field, BuildContext context) {
  final hints = field.autofillHints;
  if (hints == null || hints.isEmpty) return field;
  final section = AutofillSection.of(context);
  if (section == null) return field;
  final token = autofillToken(hints)!;
  if (withAutofillSection(token, section) == token) return field;
  return field._with(
    initialValue: field.initialValue,
    autofillHints: ['section-$section', ...hints],
  );
}

var _fallbackIds = 0;

// A saved value as the input's type reads it: a model's `toJson` writes a
// date as `2024-05-01T10:20:30.000Z`, which `<input type=date>` ignores (the
// field would show empty). web: a date-time keeps its own clock digits (no
// zone conversion).
final _isoDateTime = RegExp(r'^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})');
String? _forInput(String? value, String? type) {
  if (value == null || (type != 'date' && type != 'datetime-local')) {
    return value;
  }
  final m = _isoDateTime.firstMatch(value);
  if (m == null) return value;
  return type == 'date' ? m[1] : '${m[1]}T${m[2]}';
}

/// `f-<name>`, made unique in the page (a second form with the same field
/// name gets `f-<name>-2`). Not exported.
String _fieldId(BuildContext context, String name) =>
    ThorStyleRegistry.active(context)?.fieldId('f-$name') ?? 'f-$name';

/// Marks the bound error text of a message line, and its helper text.
const _boundErrorAttr = 'data-error';
const _helpTextAttr = 'data-help-text';

const _messageCss = {
  'min-height': '16px',
  'font-size': '12px',
  'line-height': '16px',
  'padding': '0 16px',
  'color': ThemeTokens.onSurfaceVariant,
};

/// [field] with Flutter's InputDecorator around its row: the label above,
/// the helper/error line below (not exported: [TextField] and
/// `TextFormField` build through it). [message] keeps the line even with
/// no helper or error (a validated field shows its rules' messages there).
Widget decoratedTextField(
  TextField field,
  BuildContext context, {
  String debugName = 'TextField',
  bool message = false,
}) {
  final d = themedDecoration(context, field.decoration);
  final inputId = decoratedFieldId(context, field.id, field.name);
  final messageId = '$inputId-msg';
  final watch = d.errorTextWatch;
  final watched = watch == null ? null : untracked(watch);
  final error =
      d.errorText ?? (watched == null || watched.isEmpty ? null : watched);
  final hasMessage =
      message || error != null || watch != null || d.helperText != null;
  // `aria-invalid` follows the bound message in the browser.
  final bound = watch == null
      ? const <String, String>{}
      : WatchAttributes({
          AttributeName.ariaOf(AriaAttribute.invalid): watch,
        }, child: const Text('')).wrapData.attributes;
  // After a server error the person lands on the first wrong field.
  // A disabled field can't take it: the claim goes to the next one.
  final focusError =
      error != null &&
      (field.enabled ?? true) &&
      (ThorStyleRegistry.active(context)?.claimErrorFocus() ?? false);
  final live = field._liveCounter(d);
  return _controlBound(
    context,
    (control) => inputDecorator(
      debugName: debugName,
      decoration: d,
      inputId: inputId,
      message: hasMessage,
      errorWatch: d.errorText == null ? watch : null,
      counter: field._counter(d, inputId),
      field: field._row(
        d,
        inputId,
        {
          ...bound,
          // The counter is read with the message when the field is focused;
          // it is not a live region (it would talk over the typing).
          if (hasMessage || field._hasCounter(d))
            'aria-describedby': [
              if (hasMessage) messageId,
              if (field._hasCounter(d)) '$inputId-cnt',
            ].join(' '),
          if (error != null) 'aria-invalid': 'true',
          if (focusError) 'autofocus': '',
          'oninput': ?live,
        },
        control,
        true,
      ),
    ),
  );
}

/// [decoration] over the theme's `inputDecorationTheme` (Flutter's
/// `InputDecorator` does `decoration.applyDefaults(theme)`). Not exported.
InputDecoration themedDecoration(
  BuildContext context,
  InputDecoration decoration,
) {
  final theme = Theme.of(context).inputDecorationTheme;
  return theme == null ? decoration : decoration.applyDefaults(theme);
}

/// The id of a decorated field's control: [id], else `f-<name>` (unique in
/// the page), else one
/// unique in the page. Not exported.
String decoratedFieldId(BuildContext context, String? id, String? name) =>
    id ??
    (name != null ? _fieldId(context, name) : null) ??
    ThorStyleRegistry.active(context)?.uniqueId('t-tf') ??
    't-tf-${++_fallbackIds}';

/// Flutter's InputDecorator around [field] (the control's row): the label
/// above (a `<label for="[inputId]">`), the helper/error line below (id
/// `<inputId>-msg`, which the control points at with `aria-describedby`)
/// when [message]. Not exported: `TextField`, `TextFormField` and
/// `DropdownButtonFormField` build through it.
Widget inputDecorator({
  required String debugName,
  required InputDecoration decoration,
  required String inputId,
  required bool message,
  required Widget field,
  Widget? counter,
  String? Function()? errorWatch,
}) {
  final d = decoration;
  final error = d.errorText;
  final showLabel = _labelShownAbove(d);
  final clamp = error != null || errorWatch != null ? d.errorMaxLines : null;
  final messageLine = message
      ? WrapWith(
          WrapData(
            css: {
              ..._messageCss,
              // The helper's row is shared with the counter.
              if (counter != null) ...{'flex': '1 1 0'},
              if (error == null && errorWatch == null)
                ...?d.helperStyle?.toCss(),
              if (error != null) ...?d.errorStyle?.toCss(),
              // A message can't take more lines than errorMaxLines.
              if (clamp != null) ...{
                'display': '-webkit-box',
                '-webkit-box-orient': 'vertical',
                '-webkit-line-clamp': '$clamp',
                'overflow': 'hidden',
              },
            },
            attributes: {
              'id': '$inputId-msg',
              'aria-live': 'polite',
              helperAttr: ?d.helperText,
              if (error != null) invalidAttr: '',
            },
            conditions: [
              ConditionalCss(const CssCondition.selector('[$invalidAttr]'), {
                'color': ThemeTokens.error,
                // web: a failed validation in the browser marks the line
                // invalid without a rebuild, so the error style is a rule.
                ...?d.errorStyle?.toCss(),
              }),
              if (errorWatch != null) ...[
                // A bound message (`errorTextWatch`): the line looks invalid
                // while it has text, and the helper steps aside.
                ConditionalCss(
                  const CssCondition.selector(
                    ':has([$_boundErrorAttr]:not(:empty))',
                  ),
                  {'color': ThemeTokens.error, ...?d.errorStyle?.toCss()},
                ),
                const ConditionalCss(
                  CssCondition.selector(
                    ':has([$_boundErrorAttr]:not(:empty)) [$_helpTextAttr]',
                  ),
                  {'display': 'none'},
                ),
              ],
            ],
          ),
          child: errorWatch == null
              ? Text(error ?? d.helperText ?? '')
              : thorElement(
                  'span',
                  children: [
                    if (d.helperText != null)
                      thorElement(
                        'span',
                        attributes: const {_helpTextAttr: ''},
                        children: [Widget.text(d.helperText!)],
                      ),
                    WrapWith(
                      const WrapData(attributes: {_boundErrorAttr: ''}),
                      child: Watch(errorWatch),
                    ),
                  ],
                ),
        )
      : null;
  final column = thorElement(
    'div',
    debugName: d.icon != null ? null : debugName,
    fillsWidth: true,
    css: {...boxCss, 'gap': '4px', if (d.icon != null) 'flex': '1 1 0'},
    childRules: ChildRules.column,
    children: [
      if (showLabel)
        WrapWith(
          WrapData(
            attributes: {'for': inputId},
            css: {
              'font-size': '14px',
              'line-height': '20px',
              'font-weight': '500',
              'padding': '0 4px',
              ...?d.labelStyle?.toCss(),
            },
          ),
          child: Semantics(
            role: SemanticsRole.label,
            child: d.label ?? Text(d.labelText!),
          ),
        ),
      field,
      // The message line reserves its height: no layout shift when an
      // error appears.
      if (counter != null)
        thorElement(
          'div',
          css: const {
            'display': 'flex',
            'gap': '16px',
            'align-items': 'flex-start',
          },
          children: [?messageLine, counter],
        )
      else
        ?messageLine,
    ],
  );
  if (d.icon == null) return column;
  // The icon sits outside the container, before the label and the field.
  return thorElement(
    'div',
    debugName: debugName,
    fillsWidth: true,
    css: const {
      'display': 'flex',
      'align-items': 'flex-start',
      'min-width': '0',
    },
    children: [
      thorElement(
        'span',
        css: {
          'flex': 'none',
          'display': 'grid',
          'place-items': 'center',
          'min-width': '24px',
          'min-height': '48px',
          'padding-inline-end': '16px',
          // Level with the field, below the label line.
          if (showLabel) 'margin-top': '24px',
        },
        children: [d.icon!],
      ),
      column,
    ],
  );
}

/// Whether the decorator shows a `<label for>` above the field (`never`
/// makes a `labelText` the placeholder instead).
bool _labelShownAbove(InputDecoration d) =>
    d.label != null ||
    d.labelText != null &&
        d.floatingLabelBehavior != FloatingLabelBehavior.never;

/// Whether that label gives the control its accessible name (an empty
/// `labelText` leaves it to the hint).
bool _namedByLabel(InputDecoration d) =>
    d.label != null ||
    (d.labelText ?? '').trim().isNotEmpty &&
        d.floatingLabelBehavior != FloatingLabelBehavior.never;

/// Attributes bound by a wrapper (`row.attribute`, `WatchAttributes`)
/// that name or fill the control, not its box.
const _controlAttributeNames = {
  'value',
  'placeholder',
  'name',
  'min',
  'max',
  'step',
  'tabindex',
  'autofocus',
};

bool _isControlAttribute(String name) =>
    name.startsWith('aria-') || _controlAttributeNames.contains(name);

/// [build] with the bound attributes of the wrappers around the field that
/// belong to its control (`value`, `placeholder`, `aria-*`…), taken off the
/// field's outer element: `row.attribute(AttributeName.value, …, child: TextField())`
/// fills the `<input>`, not the `<label>` around it. The rest (`title`,
/// `data-*`…) stays on the outer element.
Widget _controlBound(
  BuildContext context,
  Widget Function(Map<String, String> control) build,
) {
  final scope = ChildRulesScope.maybeOf(context);
  final pending = scope?.pending;
  if (scope == null || pending == null || scope.isElement) {
    return build(const {});
  }
  final outer = {...bindRowMarkers(pending.attributes)};
  final control = <String, String>{};
  for (final attr in const [rowAttributesAttr, attributesAttr]) {
    final bound = outer[attr];
    if (bound == null) continue;
    final all = decodeOn(bound);
    final mine = {
      for (final MapEntry(:key, :value) in all.entries)
        if (_isControlAttribute(key)) key: value,
    };
    if (mine.isEmpty) continue;
    final rest = {
      for (final MapEntry(:key, :value) in all.entries)
        if (!mine.containsKey(key)) key: value,
    };
    control[attr] = encodeOn(mine);
    rest.isEmpty ? outer.remove(attr) : outer[attr] = encodeOn(rest);
    for (final name in mine.keys) {
      final value = outer.remove(name);
      if (value != null) control[name] = value;
    }
  }
  if (control.isEmpty) return build(const {});
  final p = pending;
  return ChildRulesScope(
    rules: scope.rules,
    pending: WrapData(
      classes: p.classes,
      baseCss: p.baseCss,
      css: p.css,
      classCss: p.classCss,
      conditions: p.conditions,
      attributes: outer,
      fillsWidth: p.fillsWidth,
      fixesWidth: p.fixesWidth,
      fillsHeight: p.fillsHeight,
      debugAttributes: p.debugAttributes,
      tag: p.tag,
      flexible: p.flexible,
      viewTransitionName: p.viewTransitionName,
    ),
    child: build(control),
  );
}

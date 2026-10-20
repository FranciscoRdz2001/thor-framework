import 'package:meta/meta.dart';
import 'package:thor_server/thor_server.dart';

import '../foundation/errors.dart';
import '../foundation/html_attributes.dart';
import '../foundation/material_localizations.dart' show ThorLocalizations;
import '../widgets/form.dart';
import '../widgets/text_field.dart';

/// A form declared once: the fields, their types and their rules.
///
/// The same object feeds the three layers of a form:
/// - **server, on submit**: [parse] checks the request with the rules the
///   browser checks (same semantics) and returns typed values
///   ([FormValid]) or the messages and the values to re-fill
///   ([FormInvalid], for `ActionResult.fail`);
/// - **server, on render**: each field gives its native constraint
///   attributes ([SchemaField.attributes]), its re-fill value and its
///   message from a failed submission;
/// - **browser**: nothing of the schema travels. The native constraints
///   validate with no JS; with the engine, `TextFormField` shows each
///   rule's message.
///
/// ```dart
/// abstract final class SignIn {
///   static const email = TextSchemaField('email', validators: [
///     Validator.required("email can't be blank"),
///     Validator.email('email is invalid'),
///   ]);
///   static const password = TextSchemaField('password', secret: true,
///       validators: [Validator.required("password can't be blank")]);
///   static const schema = FormSchema([email, password]);
/// }
///
/// // in LoginPage (a ThorPage): an action that parses the request
/// Future<ActionResult?> signIn(PageRequest request) async {
///   final form = await SignIn.schema.parse(request);
///   if (form is FormInvalid) return form.fail();
///   final values = form as FormValid;
///   await api.login(values.of(SignIn.email), values.of(SignIn.password));
///   return Redirect(homeRoute.link());
/// }
///
/// // its build
/// TextFormField(field: SignIn.email, form: state.form,
///     decoration: const InputDecoration(labelText: 'Email'));
/// ```
class FormSchema {
  /// A schema with [fields] (names must be unique).
  const FormSchema(this.fields);

  /// The fields, in the order their messages are listed.
  final List<SchemaField<Object?>> fields;

  /// The field named [name], or `null`.
  SchemaField<Object?>? fieldNamed(String name) {
    for (final f in fields) {
      if (f.name == name) return f;
    }
    return null;
  }

  /// Reads the submitted form of [request] and checks it.
  Future<FormResult> parse(PageRequest request) async =>
      validate(await request.form(), locale: request.locale);

  /// Checks [data]: every field's rules, in order; the first failing rule
  /// of each field gives its message.
  FormResult validate(FormData data, {Locale? locale}) {
    final l10n = ThorLocalizations.forLocale(locale);
    assert(
      fields.map((f) => f.name).toSet().length == fields.length,
      thorError('THOR-P008', 'two fields of a FormSchema share a name'),
    );
    final errors = <String, List<String>>{};
    final values = <String, Object?>{};
    for (final field in fields) {
      // A field whose `when:` is false is not checked: it gives its empty
      // value, whatever was sent.
      final active = field.when?.call(data) ?? true;
      final messages = active ? field._errors(data, l10n) : const <String>[];
      if (messages.isNotEmpty) {
        errors[field.name] = messages;
      } else {
        values[field.name] = field._parse(active ? data : const FormData({}));
      }
    }
    final refill = _refill(data);
    if (errors.isEmpty) return FormValid._(values, refill);
    return FormInvalid(
      fieldErrors: errors,
      values: refill.values,
      valueLists: refill.lists,
    );
  }

  ({Map<String, String> values, Map<String, List<String>> lists}) _refill(
    FormData data,
  ) => (
    values: {
      for (final f in fields)
        if (!f.secret && data[f.name] != null) f.name: data[f.name]!,
    },
    lists: {
      for (final f in fields)
        if (!f.secret && data.all(f.name).length > 1)
          f.name: List.of(data.all(f.name)),
    },
  );
}

/// The outcome of [FormSchema.parse].
sealed class FormResult {}

/// Every rule passed: the typed values.
final class FormValid extends FormResult {
  FormValid._(this._values, this._refill);

  final Map<String, Object?> _values;
  final ({Map<String, String> values, Map<String, List<String>> lists}) _refill;

  /// The value of [field], typed (`String` for a text field, `int?` for
  /// an [IntSchemaField]…).
  T of<T>(SchemaField<T> field) {
    if (!_values.containsKey(field.name)) {
      throw ArgumentError.value(
        field.name,
        'field',
        thorError(
          'THOR-P007',
          'not a field of the schema that parsed this form',
        ),
      );
    }
    return _values[field.name] as T;
  }

  /// A failure after the rules passed (the backend said no): [message]
  /// under [field], or for the whole form without one (none: add them
  /// with [FormInvalid.withError]); the values re-fill as usual.
  FormInvalid fail([String? message, SchemaField<Object?>? field]) {
    final failure = FormInvalid(
      values: _refill.values,
      valueLists: _refill.lists,
    );
    return message == null ? failure : failure.withError(message, field: field);
  }
}

/// Some rule failed (or the backend refused): what the page shows again.
///
/// A [Form] given this as `failed: state.form` refills every named field
/// and shows its messages (like Rails' `form_with model:` after a failed
/// `save`, or Django's bound form).
final class FormInvalid extends FormResult implements ActionOutcome {
  /// A failure with field [errors] (one message per field) and
  /// [fieldErrors] (several), the [formErrors] and the [values] to
  /// re-fill (never a secret field's). [valueLists] are the values of a
  /// field sent more than once (a repeated input), in order.
  FormInvalid({
    Map<String, String> errors = const {},
    Map<String, List<String>> fieldErrors = const {},
    this.formErrors = const [],
    this.values = const {},
    this.valueLists = const {},
  }) : _errors = _merge(errors, fieldErrors);

  static Map<String, List<String>> _merge(
    Map<String, String> one,
    Map<String, List<String>> many,
  ) {
    if (one.isEmpty && many.isEmpty) return const {};
    final out = <String, List<String>>{
      for (final e in one.entries) e.key: [e.value],
    };
    for (final e in many.entries) {
      if (e.value.isNotEmpty) (out[e.key] ??= []).addAll(e.value);
    }
    return out;
  }

  final Map<String, List<String>> _errors;

  /// Field name → its first message.
  Map<String, String> get errors => {
    for (final e in _errors.entries) e.key: e.value.first,
  };

  /// Every message of the field [name], in order (empty when it has none).
  List<String> errorsOf(String name) => _errors[name] ?? const [];

  /// Messages not tied to a field (what the backend said).
  final List<String> formErrors;

  /// Field name → the submitted value, to re-fill.
  final Map<String, String> values;

  /// Field name → every submitted value, for a field sent more than once
  /// (`tags=a&tags=b`), in order.
  final Map<String, List<String>> valueLists;

  /// Whether the field [name] was sent at all (an unchecked box is not).
  bool sent(String name) => values.containsKey(name);

  /// Every message: the fields' in schema order, then the form's.
  List<String> get messages => [
    for (final list in _errors.values) ...list,
    ...formErrors,
  ];

  /// This failure plus [message] (added under [field]'s other messages).
  FormInvalid withError(String message, {SchemaField<Object?>? field}) =>
      FormInvalid(
        fieldErrors: field == null
            ? _errors
            : {
                ..._errors,
                field.name: [...?_errors[field.name], message],
              },
        formErrors: field == null ? [...formErrors, message] : formErrors,
        values: values,
        valueLists: valueLists,
      );

  /// The page again with this failure as `state.form` (`422` by default).
  ActionResult fail([int status = 422]) => ActionResult.fail(status, this);

  /// Returned as is from an action, a failed form is a `422`.
  @override
  ActionResult get actionResult => fail();
}

/// A field of a [FormSchema] that yields a [T].
sealed class SchemaField<T> {
  const SchemaField();

  /// The form field name.
  String get name;

  /// The rules, in order (the browser's and the server's). A
  /// [Validator.all] stands for its rules.
  List<Validator> get validators;

  /// Never re-filled after a failure (passwords).
  bool get secret => false;

  /// The condition under which this field is checked: `null` (always), or
  /// a function of the submitted form, such as «only when creating»
  /// (`(data) => data['id'].isEmpty`, a top-level function so the field
  /// stays `const`). When it is `false` the field is not checked and gives
  /// its empty value (`''`, `null`, `false`), whatever was sent.
  ///
  /// The browser can't know the condition: the field's native rules are
  /// left out unless the page says they apply
  /// (`TextFormField(field:, applies: isNew)`); the server always decides.
  bool Function(FormData data)? get when => null;

  /// The native constraint attributes of [validators] (`required`,
  /// `minlength`, `pattern`, `type`…), for a control that is not a
  /// [TextFormField] (a styled `TextField`, a checkbox). A field with a
  /// [when] condition still lists them: it is the page that decides
  /// whether they apply.
  Map<String, String> get attributes => {
    for (final v in expandRules(validators)) ...v.attributes,
  };

  /// The value to re-fill from a failed submission ([form] is the page's
  /// `state.form`), or `null`.
  String? value(Object? form) =>
      form is FormInvalid && !secret ? form.values[name] : null;

  /// This field's message from a failed submission, or `null`.
  String? error(Object? form) => form is FormInvalid ? form.errors[name] : null;

  /// What `TextFormField(field: this)` builds: [w] with the name, rules,
  /// type, re-fill and message of this field (what [w] sets itself wins:
  /// the decoration, the keyboard, the initial value).
  @internal
  TextFormField resolveTextFormField(TextFormField w) => TextFormField(
    key: w.key,
    name: name,
    validators: when == null || w.applies ? validators : const [],
    checkedByServer: true,
    inputAttributes: trustedAttributes({
      ..._inputAttributes,
      ...?w.inputAttributes,
    }),
    obscureText: secret || w.obscureText,
    maxLines: w.maxLines,
    minLines: w.minLines,
    keyboardType: w.keyboardType ?? _keyboard,
    initialValue: value(w.form) ?? (secret ? null : w.initialValue),
    autofillHints: w.autofillHints,
    datalist: w.datalist,
    decoration: w.decoration.copyWith(
      errorText: error(w.form) ?? w.decoration.errorText,
    ),
    style: w.style,
    enabled: w.enabled,
    onChanged: w.onChanged,
    readOnly: w.readOnly,
    maxLength: w.maxLength,
    textInputAction: w.textInputAction,
    textCapitalization: w.textCapitalization,
    textAlign: w.textAlign,
    obscuringCharacter: w.obscuringCharacter,
    expands: w.expands,
  );

  TextInputType get _keyboard => TextInputType.text;

  /// What a text input of this field needs besides its rules (`type`).
  Map<String, String> get _inputAttributes => const {};

  /// The raw value (`''` when absent), line breaks as the browser counts
  /// them (a submitted `\r\n` is one character in `maxlength`).
  String _raw(FormData data) => (data[name] ?? '').replaceAll('\r\n', '\n');

  /// Every failing message of this field (the first failing rule's, for
  /// most fields).
  List<String> _errors(FormData data, ThorLocalizations l10n) => [
    ?_check(data, l10n),
  ];

  /// The first failing rule's message, or `null`.
  String? _check(FormData data, ThorLocalizations l10n) {
    final value = _raw(data);
    // Like the browser's `badInput`: a value the type can't hold first.
    if (_checkType(value, l10n) case final error?) return error;
    for (final v in expandRules(validators)) {
      if (v.check case final check?) {
        if (check(value) case final error?) return error;
      } else if (!_passes(v, value, data)) {
        return v.message;
      }
    }
    return null;
  }

  bool _passes(Validator v, String value, FormData data) {
    if (v.validity == 'valueMissing') return !_missing(data, value);
    // Like the browser: an empty optional field passes every other rule.
    if (value.isEmpty) return true;
    final a = v.attributes;
    return switch (v.validity) {
      'tooShort' => value.length >= int.parse(a['minlength']!),
      'tooLong' => value.length <= int.parse(a['maxlength']!),
      'patternMismatch' => RegExp(
        '^(?:${a['pattern']})\$',
        unicode: true,
      ).hasMatch(value),
      'typeMismatch' => _email.hasMatch(value),
      'rangeUnderflow' => _atLeast(value, a['min']!),
      'rangeOverflow' => _atMost(value, a['max']!),
      _ => throw UnsupportedError('no server check for ${v.validity}'),
    };
  }

  bool _atLeast(String value, String bound) =>
      (num.tryParse(value) ?? double.nan) >= num.parse(bound);

  bool _atMost(String value, String bound) =>
      (num.tryParse(value) ?? double.nan) <= num.parse(bound);

  bool _missing(FormData data, String value) => value.isEmpty;

  /// Whether nothing was sent for this field (what an [OptionalSchemaField]
  /// turns into `null`).
  bool _isEmpty(FormData data) => _raw(data).isEmpty;

  /// A value the type can't hold (`abc` for an int), or `null`.
  String? _checkType(String value, ThorLocalizations l10n) => null;

  T _parse(FormData data);

  // The HTML spec's valid e-mail address (what `type=email` accepts).
  static final _email = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}"
    r'[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
  );
}

/// A text field: its value as submitted (`''` when empty), or trimmed.
///
/// [trim] strips the whitespace around the value **before** the rules run
/// and in the parsed result, like the browser's value sanitization does for
/// `type=email` (so `' ana@x.com '` from `curl`, an autofill or a paste is
/// the address, not a failure of [Validator.email]). Left unset it trims
/// exactly where the browser would: a field with a [Validator.email] that is
/// not [secret]. Any other text keeps what was sent (a name with a
/// deliberate space, a code block), and a [secret] is never trimmed unless
/// asked (a password may start or end with a space). `trim: false` keeps an
/// e-mail as sent, so its spaces fail the rule.
final class TextSchemaField extends SchemaField<String> {
  /// A text field; [secret] is never re-filled (passwords). [trim]: see the
  /// class.
  const TextSchemaField(
    this.name, {
    this.validators = const [],
    this.secret = false,
    this.when,
    this.trim,
  });

  @override
  final String name;
  @override
  final List<Validator> validators;
  @override
  final bool secret;
  @override
  final bool Function(FormData data)? when;

  /// Whether the value is trimmed before the rules and in the result;
  /// `null` (the default): only for an e-mail field.
  final bool? trim;

  // web: type=email's value sanitization strips the spaces before submit;
  // the server does the same so a client that doesn't (curl) is not worse
  // off than a browser.
  bool get _trims =>
      trim ??
      (!secret &&
          expandRules(validators).any((v) => v.attributes['type'] == 'email'));

  @override
  String _raw(FormData data) {
    final value = super._raw(data);
    return _trims ? value.trim() : value;
  }

  @override
  TextInputType get _keyboard =>
      expandRules(validators).any((v) => v.attributes['type'] == 'email')
      ? TextInputType.emailAddress
      : TextInputType.text;

  @override
  String _parse(FormData data) => _raw(data);
}

/// A whole number (`null` when empty). A value that is not one fails
/// with [invalid].
final class IntSchemaField extends SchemaField<int?> {
  /// A number field.
  const IntSchemaField(
    this.name, {
    this.validators = const [],
    this.invalid,
    this.when,
  });

  @override
  final String name;
  @override
  final List<Validator> validators;
  @override
  final bool Function(FormData data)? when;

  /// The message for a value that is not a whole number.
  final String? invalid;

  @override
  Map<String, String> get attributes => {
    'type': 'number',
    'step': '1',
    ...super.attributes,
  };

  @override
  TextInputType get _keyboard => TextInputType.number;

  @override
  String? _checkType(String value, ThorLocalizations l10n) =>
      value.isEmpty || _int(value.trim()) != null
      ? null
      : invalid ?? l10n.formEnterWholeNumber;

  @override
  bool _atLeast(String value, String bound) =>
      (_int(value.trim()) ?? double.nan) >= num.parse(bound);

  @override
  bool _atMost(String value, String bound) =>
      (_int(value.trim()) ?? double.nan) <= num.parse(bound);

  @override
  int? _parse(FormData data) => _int(_raw(data).trim());

  // `int.tryParse` also takes `0x1A`; a number input never sends it.
  static final _digits = RegExp(r'^[+-]?[0-9]+$');
  static int? _int(String text) =>
      _digits.hasMatch(text) ? int.tryParse(text) : null;
}

/// A decimal number (`null` when empty). A value that is not one (`abc`,
/// `NaN`, `Infinity`, `0x10`, `1,5`) fails with [invalid].
final class DoubleSchemaField extends SchemaField<double?> {
  /// A decimal number field.
  const DoubleSchemaField(
    this.name, {
    this.validators = const [],
    this.invalid,
    this.when,
  });

  @override
  final String name;
  @override
  final List<Validator> validators;
  @override
  final bool Function(FormData data)? when;

  /// The message for a value that is not a number.
  final String? invalid;

  @override
  Map<String, String> get attributes => {
    'type': 'number',
    'step': 'any',
    ...super.attributes,
  };

  @override
  Map<String, String> get _inputAttributes => const {
    'type': 'number',
    'step': 'any',
  };

  @override
  TextInputType get _keyboard =>
      const TextInputType.numberWithOptions(decimal: true);

  @override
  String? _checkType(String value, ThorLocalizations l10n) =>
      value.isEmpty || _double(value.trim()) != null
      ? null
      : invalid ?? l10n.formEnterNumber;

  @override
  bool _atLeast(String value, String bound) =>
      (_double(value.trim()) ?? double.nan) >= num.parse(bound);

  @override
  bool _atMost(String value, String bound) =>
      (_double(value.trim()) ?? double.nan) <= num.parse(bound);

  @override
  double? _parse(FormData data) => _double(_raw(data).trim());

  // Digits, an optional fraction and exponent: not `NaN`, `Infinity`, hex
  // or `1_0`, which `double.tryParse` reads.
  static final _decimal = RegExp(
    r'^[+-]?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$',
  );
  static double? _double(String text) {
    if (!_decimal.hasMatch(text)) return null;
    final v = double.tryParse(text);
    return v != null && v.isFinite ? v : null;
  }
}

/// A calendar date, `yyyy-mm-dd` (what `<input type=date>` sends): a UTC
/// `DateTime` at midnight (`null` when empty). An impossible date
/// (`2023-02-29`) or another format fails with [invalid]. Bound it with
/// `Validator.minDate` / `Validator.maxDate`.
///
/// web: a date has no time zone here, so the value is `DateTime.utc`:
/// comparing it with `DateTime.now()` needs `.toUtc()`.
final class DateSchemaField extends SchemaField<DateTime?> {
  /// A date field.
  const DateSchemaField(
    this.name, {
    this.validators = const [],
    this.invalid,
    this.when,
  });

  @override
  final String name;
  @override
  final List<Validator> validators;
  @override
  final bool Function(FormData data)? when;

  /// The message for a value that is not a real date.
  final String? invalid;

  @override
  Map<String, String> get attributes => {'type': 'date', ...super.attributes};

  @override
  Map<String, String> get _inputAttributes => const {'type': 'date'};

  @override
  String? _checkType(String value, ThorLocalizations l10n) =>
      value.isEmpty || _date(value) != null
      ? null
      : invalid ?? l10n.formEnterValidDate;

  // Both are `yyyy-mm-dd` by now (the bound is the rule's own): ISO dates
  // sort as text.
  @override
  bool _atLeast(String value, String bound) => value.compareTo(bound) >= 0;

  @override
  bool _atMost(String value, String bound) => value.compareTo(bound) <= 0;

  @override
  DateTime? _parse(FormData data) => _date(_raw(data));

  static final _iso = RegExp(r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$');
  static DateTime? _date(String text) {
    final m = _iso.firstMatch(text);
    if (m == null) return null;
    final (y, mo, d) = (int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    if (y < 1 || mo < 1 || mo > 12 || d < 1) return null;
    final date = DateTime.utc(y, mo, d);
    // A day past the month's end rolls over into the next one.
    return date.month == mo ? date : null;
  }
}

/// A checkbox: `true` when it was sent checked. `Validator.required` means
/// it must be checked.
final class CheckboxSchemaField extends SchemaField<bool> {
  /// A checkbox field.
  const CheckboxSchemaField(this.name, {this.validators = const [], this.when});

  @override
  final String name;
  @override
  final List<Validator> validators;
  @override
  final bool Function(FormData data)? when;

  @override
  bool _missing(FormData data, String value) => data[name] == null;

  @override
  bool _parse(FormData data) => data[name] != null;
}

/// One of [choices] (a `<select>` or radio buttons): any other value is
/// refused with [invalid], whatever the browser allowed (a tampered form).
final class ChoiceSchemaField extends SchemaField<String> {
  /// A choice field.
  const ChoiceSchemaField(
    this.name, {
    required this.choices,
    this.validators = const [],
    this.invalid,
    this.when,
  });

  @override
  final String name;
  @override
  final List<Validator> validators;
  @override
  final bool Function(FormData data)? when;

  /// The accepted values.
  final List<String> choices;

  /// The message for a value outside [choices].
  final String? invalid;

  @override
  String? _checkType(String value, ThorLocalizations l10n) =>
      value.isEmpty || choices.contains(value)
      ? null
      : invalid ?? l10n.formChooseOption;

  @override
  String _parse(FormData data) => _raw(data);
}

/// [field] that may be left empty: an empty value is `null` (not `''`) and
/// its rules apply only when there is a value. `values.of(field)` is a
/// `T?`.
///
/// ```dart
/// static const bio = OptionalSchemaField(TextSchemaField('bio'));   // String?
/// ```
///
/// A field with `Validator.required` is not optional: THOR-P032.
final class OptionalSchemaField<T> extends SchemaField<T?> {
  /// [field], optional.
  const OptionalSchemaField(this.field);

  /// The field that does the work when there is a value.
  final SchemaField<T> field;

  @override
  String get name => field.name;

  @override
  List<Validator> get validators => field.validators;

  @override
  bool get secret => field.secret;

  @override
  bool Function(FormData data)? get when => field.when;

  @override
  Map<String, String> get attributes => field.attributes;

  @override
  TextInputType get _keyboard => field._keyboard;

  @override
  Map<String, String> get _inputAttributes => field._inputAttributes;

  @override
  List<String> _errors(FormData data, ThorLocalizations l10n) {
    assert(
      !expandRules(field.validators).any((v) => v.validity == 'valueMissing'),
      thorError(
        'THOR-P032',
        'the field `$name` is optional and also `Validator.required`: '
            'drop one of them',
      ),
    );
    return field._isEmpty(data) ? const [] : field._errors(data, l10n);
  }

  @override
  bool _isEmpty(FormData data) => field._isEmpty(data);

  @override
  T? _parse(FormData data) => field._isEmpty(data) ? null : field._parse(data);
}

/// [item] repeated: every value sent under its name, as a `List<T>`
/// (repeated inputs, a `<select multiple>`, a checkbox group), in the order
/// they came. Blank entries are skipped. Each item is checked with the
/// item's rules (every failing item adds its message), and [min] / [max]
/// count the items.
///
/// ```dart
/// static const tags = ListSchemaField(TextSchemaField('tags',
///     validators: [Validator.maxLength(20, 'Tag too long')]), max: 5);
/// // values.of(tags) → List<String>
/// ```
///
/// A repeated field re-fills with `FormScope.valuesOf(name)` (one value per
/// input).
final class ListSchemaField<T> extends SchemaField<List<T>> {
  /// A repeated [item] with at least [min] and at most [max] entries.
  const ListSchemaField(
    this.item, {
    this.min = 0,
    this.max,
    this.tooFew,
    this.tooMany,
  });

  /// One entry's field: its name is the list's.
  final SchemaField<T> item;

  /// Fewest entries.
  final int min;

  /// Most entries, or `null` for any number.
  final int? max;

  /// The message when there are fewer than [min] entries.
  final String? tooFew;

  /// The message when there are more than [max] entries.
  final String? tooMany;

  @override
  String get name => item.name;

  @override
  List<Validator> get validators => item.validators;

  // What the item says about its own value goes for the list.
  @override
  bool get secret => item.secret;

  @override
  bool Function(FormData data)? get when => item.when;

  @override
  Map<String, String> get attributes => item.attributes;

  @override
  TextInputType get _keyboard => item._keyboard;

  @override
  Map<String, String> get _inputAttributes => item._inputAttributes;

  // Blank is what the item says is empty: an e-mail of spaces is blank once
  // trimmed.
  Iterable<FormData> _entries(FormData data) sync* {
    for (final v in data.all(name)) {
      final entry = FormData({
        name: [v],
      });
      if (!item._isEmpty(entry)) yield entry;
    }
  }

  @override
  bool _isEmpty(FormData data) => _entries(data).isEmpty;

  @override
  List<String> _errors(FormData data, ThorLocalizations l10n) {
    final entries = _entries(data).toList();
    final messages = <String>[
      for (final e in entries) ...item._errors(e, l10n),
      if (entries.length < min) tooFew ?? l10n.formAddAtLeast(min),
      if (max case final m? when entries.length > m)
        tooMany ?? l10n.formAddAtMost(m),
    ];
    return messages;
  }

  @override
  List<T> _parse(FormData data) => [
    for (final e in _entries(data)) item._parse(e),
  ];
}

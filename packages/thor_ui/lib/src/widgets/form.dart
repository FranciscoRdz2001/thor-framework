import 'package:thor_engine/thor_engine.dart';
import 'package:thor_server/thor_server.dart' show askField;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../engine/watch.dart' show engineAttributes;
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/errors.dart';
import '../foundation/html_attributes.dart';
import '../foundation/layout_hint.dart';
import '../foundation/request_scope.dart';
import '../foundation/style_registry.dart';
import '../foundation/theme_tokens.dart';
import '../router/form_schema.dart' show FormInvalid, FormSchema, SchemaField;
import '../router/page_actions.dart';
import 'autofill_group.dart' show AutofillSection;
import 'basic.dart' show boxCss;
import 'feedback.dart' show askValue, confirmAttributes;
import 'form_scope.dart';
import 'text.dart' show Text;
import 'text_field.dart';

/// A value the form posts along with its fields and the visitor never sees:
/// `<input type="hidden">`.
///
/// ```dart
/// Form(
///   onPost: save,
///   child: Column(children: [
///     HiddenField(name: 'productId', value: '$id'),
///     TextField(name: 'quantity'),
///     FilledButton(buttonType: ButtonType.submit, child: Text('Add')),
///   ]),
/// )
/// ```
///
/// `// web:` Flutter keeps a form's state in widgets, so it has no hidden
/// field; the browser posts the DOM, and this is its way to carry a value the
/// user does not edit (an id, a CSRF token). For one value tied to a button
/// `onPost: save.withArg(id)` is shorter. On the server it reads like any
/// field (`request.form()['productId']`, or a schema field of the same name
/// in `FormValues`).
class HiddenField extends StatelessWidget {
  /// Posts [name]=[value] with the enclosing form.
  const HiddenField({super.key, required this.name, required this.value});

  /// Field name.
  final String name;

  /// Field value.
  final String value;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'input',
    attributes: {
      'type': 'hidden',
      'name': name,
      // `'${row.key}'` in the row of a `Watch.list` with an int key writes
      // the template's placeholder number: the browser fills `{{key}}`.
      'value': value.replaceAll('$templateIntKey', keyToken),
    },
  );
}

/// A validation rule of a [TextFormField].
///
/// web: Flutter's `validator` is a Dart function; here each rule is data
/// that compiles to the native constraint (`required`, `minlength`,
/// `pattern`…), so the browser validates with no JS at all, and the engine
/// only shows your [message] (per rule) below the field.
class Validator {
  const Validator._(this.validity, this._attribute, this._value, this.message)
    : check = null,
      _all = null;

  /// Several rules as one, in order: `validator: Validator.all([...])`.
  const Validator.all(List<Validator> rules)
    : validity = 'all',
      _attribute = null,
      _value = null,
      message = '',
      check = null,
      _all = rules;

  /// The rules this one stands for: itself, or those of [Validator.all]
  /// (nested ones flattened).
  List<Validator> get rules => switch (_attribute) {
    // `notBlank`: two rules that share its message (a `const` list can't
    // hold a parameter, so they are made here).
    'notBlank' => [
      Validator.required(message),
      // web: `\u0085` because Dart's `trim()` removes it and `\s` does not.
      Validator.pattern(r'[\s\S]*[^\s\u0085][\s\S]*', message),
    ],
    _ when _all != null => [for (final v in _all) ...v.rules],
    _ => [this],
  };

  /// Field must not be empty.
  const Validator.required(String message)
    : this._('valueMissing', 'required', '', message);

  /// At least [length] characters.
  ///
  /// web: an **empty** value passes (the browser and the server only check
  /// the length of what was written, so the field stays optional). Flutter's
  /// `value.length < 6` fails on empty: for that, put [Validator.required]
  /// (or [Validator.notBlank]) before it:
  /// `Validator.all([Validator.required('Required'), Validator.minLength(6, 'At least 6')])`.
  const Validator.minLength(int length, String message)
    : this._('tooShort', 'minlength', length, message);

  /// At most [length] characters.
  const Validator.maxLength(int length, String message)
    : this._('tooLong', 'maxlength', length, message);

  /// Must match [regExp]: a `String` (a JavaScript-compatible pattern that
  /// must match the **whole** value; `const`-friendly) or a `RegExp`, what a
  /// Flutter validator writes.
  ///
  /// ```dart
  /// validator: Validator.pattern(RegExp(r'[A-Z]'), 'Needs an upper case')
  /// ```
  ///
  /// web: a `RegExp` keeps `hasMatch`'s meaning: a match **anywhere** (so
  /// `RegExp(r'[A-Z]')` means "has an upper case"; anchor it with `^…$` for
  /// the whole value). The browser's native `pattern` is JavaScript's and
  /// carries no flags: a `RegExp` with `caseSensitive: false`, `multiLine`
  /// or `dotAll` is refused (an `AssertionError` in debug; write `[Aa]`).
  /// A `RegExp` is not `const`: a `static const` schema uses a `String`.
  /// An empty value passes: put [Validator.required] or
  /// [Validator.notBlank] first.
  const Validator.pattern(Pattern regExp, String message)
    : this._('patternMismatch', 'pattern', regExp, message);

  /// Not empty and not only whitespace: Flutter's
  /// `value == null || value.trim().isEmpty`, the check nearly every
  /// required text field writes. [Validator.required] alone accepts `'   '`,
  /// like the browser's `required`.
  ///
  /// web: it is a [Validator.required] plus a pattern that asks for one
  /// non-whitespace character, both with [message], so the browser and the
  /// server agree. It is `const` and flattens inside [Validator.all].
  const Validator.notBlank(this.message)
    : validity = 'all',
      _attribute = 'notBlank',
      _value = null,
      check = null,
      _all = null;

  /// Must be an e-mail address (sets `type=email`).
  const Validator.email(String message)
    : this._('typeMismatch', 'type', 'email', message);

  /// Number not below [value] (sets `type=number`).
  const Validator.min(num value, String message)
    : this._('rangeUnderflow', 'min', value, message);

  /// Number not above [value] (sets `type=number`).
  const Validator.max(num value, String message)
    : this._('rangeOverflow', 'max', value, message);

  /// A date (`yyyy-mm-dd`) not before [date], for a `DateSchemaField`.
  const Validator.minDate(String date, String message)
    : this._('rangeUnderflow', 'min', date, message);

  /// A date (`yyyy-mm-dd`) not after [date], for a `DateSchemaField`.
  const Validator.maxDate(String date, String message)
    : this._('rangeOverflow', 'max', date, message);

  /// A rule only the server checks (a `FormSchema` from
  /// `package:thor_ui/router.dart`): [check] returns the message, or `null`
  /// when the value passes. The browser can't run it: it adds no
  /// attribute, and its message shows after the form is sent.
  const Validator.custom(String? Function(String value) this.check)
    : validity = 'customError',
      _attribute = null,
      _value = null,
      message = '',
      _all = null;

  /// The server-only check of [Validator.custom], or `null`.
  final String? Function(String value)? check;

  /// The `ValidityState` flag this rule sets when it fails.
  final String validity;

  // The rule as one attribute and its value, so every rule can be `const`
  // (a `static const` schema field): a const map can't hold a parameter.
  final String? _attribute;
  final Object? _value;
  final List<Validator>? _all;

  /// The native HTML attributes that enforce this rule.
  Map<String, String> get attributes => switch (_attribute) {
    null || 'notBlank' => const {},
    // A number bound makes a number input; a date bound leaves the type to
    // the field (`type=date`).
    final a && ('min' || 'max') when _value is num => {
      'type': 'number',
      a: '$_value',
    },
    // A `RegExp` means what `hasMatch` says (a match anywhere): the native
    // pattern is the whole value, so it is wrapped.
    'pattern' when _value is RegExp => {'pattern': _regExpPattern(_value)},
    // A String is the whole value, written for Dart's RegExp (the server's):
    // what the browser's `v` flag reads differently is escaped the same way.
    'pattern' when _value is String => {'pattern': _forVFlag(_value)},
    'pattern' when _value is! String => throw AssertionError(
      'Validator.pattern takes a String or a RegExp: a Pattern of another '
      'kind has no native form',
    ),
    final a => {a: '$_value'},
  };

  static String _regExpPattern(RegExp r) {
    assert(
      r.isCaseSensitive && !r.isMultiLine && !r.isDotAll,
      thorError(
        'THOR-P035',
        'a RegExp with caseSensitive: false, multiLine or dotAll can not be '
            'a native `pattern`: write the flag in the pattern itself '
            '(`[Aa]`) or use a Validator.custom checked on the server',
      ),
    );
    assert(
      r.isUnicode || !_needsUnicode.hasMatch(r.pattern),
      thorError(
        'THOR-P035',
        'the RegExp `${r.pattern}` uses `\\p{..}` or `\\u{..}`, which Dart '
            'only reads as such with `unicode: true` (without it the server '
            'and the browser would not agree with your code)',
      ),
    );
    return '[\\s\\S]*(?:${_forVFlag(r.pattern)})[\\s\\S]*';
  }

  static final _needsUnicode = RegExp(r'(?<!\\)(?:\\\\)*\\(?:[pP]\{|u\{)');

  // web: the browser compiles the native `pattern` with the `v` flag, which
  // rejects inside a class what Dart accepts (an unescaped `-` that is not a
  // range, `(`, `[`, `{`, `}`, `|`, `/`, and doubled punctuators such as `&&`
  // or `~~`); the whole pattern would then be ignored by the browser while
  // the server kept enforcing it. They are escaped: the meaning is the same.
  static String _forVFlag(String p) {
    final out = StringBuffer();
    var i = 0;
    while (i < p.length) {
      final c = p[i];
      if (c == r'\') {
        if (i + 1 >= p.length) {
          out.write(c);
          i++;
          continue;
        }
        final e = p[i + 1];
        var end = i + 2;
        if ((e == 'p' || e == 'P' || e == 'u') &&
            end < p.length &&
            p[end] == '{') {
          final close = p.indexOf('}', end);
          if (close != -1) end = close + 1;
        }
        // An identity escape of anything else is a syntax error with `v`.
        out.write(_escapeOutside.contains(e) ? p.substring(i, end) : e);
        i = end;
        continue;
      }
      if (c == '{') {
        // A quantifier stays; a lone brace is a literal in Dart only.
        final q = _quantifier.matchAsPrefix(p, i);
        if (q != null) {
          out.write(q[0]);
          i += q[0]!.length;
        } else {
          out.write(r'\{');
          i++;
        }
        continue;
      }
      if (c == '}' || c == ']') {
        out.write('\\$c');
        i++;
        continue;
      }
      if (c != '[') {
        out.write(c);
        i++;
        continue;
      }
      out.write(c);
      i++;
      if (i < p.length && p[i] == '^') {
        out.write('^');
        i++;
      }
      var atStart = true;
      var prevAtom = false; // the last item can start a range
      var inRange = false; // a range operator was just written
      void atom() {
        if (inRange) {
          inRange = false;
          prevAtom = false;
        } else {
          prevAtom = true;
        }
      }

      while (i < p.length && p[i] != ']') {
        final k = p[i];
        if (k == r'\' && i + 1 < p.length) {
          final e = p[i + 1];
          var end = i + 2;
          if ((e == 'p' || e == 'P' || e == 'u') &&
              end < p.length &&
              p[end] == '{') {
            final close = p.indexOf('}', end);
            if (close != -1) end = close + 1;
          }
          // An identity escape the `v` flag does not know is the character.
          out.write(_escapeInClass.contains(e) ? p.substring(i, end) : e);
          i = end;
          if ('dDwWsSpP'.contains(e)) {
            prevAtom = false;
            inRange = false;
          } else {
            atom();
          }
        } else if (k == '-') {
          final next = i + 1 < p.length ? p[i + 1] : ']';
          if (prevAtom && !inRange && next != ']') {
            out.write('-');
            inRange = true;
            prevAtom = false;
          } else {
            out.write(r'\-');
            final start = atStart;
            atom();
            prevAtom = start;
          }
          i++;
        } else if ('([{}|/'.contains(k) || ')'.contains(k)) {
          out.write('\\$k');
          atom();
          i++;
        } else if (_doubled.contains(k) && i + 1 < p.length && p[i + 1] == k) {
          out.write('$k\\$k');
          atom();
          i += 2;
        } else {
          out.write(k);
          atom();
          i++;
        }
        atStart = false;
      }
      if (i < p.length) {
        out.write(']');
        i++;
      }
    }
    return out.toString();
  }

  static final _quantifier = RegExp(r'\{\d+(?:,\d*)?\}');

  // Escapes valid outside a class with `v`: syntax characters, `/`, the
  // class and assertion letters, control and unicode escapes, digits.
  static const _escapeOutside = r'^$\.*+?()[]{}|/dDwWsSbBpPkfnrtvcxu0123456789';

  // The same inside a class: also `-` and the reserved punctuators.
  static const _escapeInClass =
      r'^$\.*+?()[]{}|/-dDwWsSbpPfnrtvcxu0123456789&!#%,:;<=>@~'
      '`';

  static const _doubled = '&!#\$%*+,.:;<=>?@^`~';

  /// Shown below the field while this rule fails.
  final String message;
}

/// The rules of [validators] with every [Validator.all] flattened.
List<Validator> expandRules(List<Validator> validators) => [
  for (final v in validators) ...v.rules,
];

/// Flutter's `TextFormField`: a [TextField] with a label, validation rules
/// and the helper/error line below it.
///
/// [name] is the form field name and the base of the ids that link the
/// field to its message (`aria-describedby`).
class TextFormField extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a labeled, validated form field.
  const TextFormField({
    super.key,
    String? name,
    this.field,
    this.form,
    this.applies = false,
    this.decoration = const InputDecoration(),
    this.validator,
    this.validators = const [],
    this.checkedByServer = false,
    this.inputAttributes,
    this.style,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.enabled,
    this.initialValue,
    this.onChanged,
    this.readOnly = false,
    this.maxLength,
    this.textInputAction,
    this.textCapitalization,
    this.textAlign = TextAlign.start,
    this.autofillHints,
    this.datalist,
    this.obscuringCharacter = '\u2022',
    this.expands = false,
  }) : _name = name,
       assert(
         name != null || field != null,
         'a TextFormField needs a name or a field (a FormSchema field)',
       );

  /// A field of a [FormSchema] (`SignUp.email`): its name, rules (the
  /// browser's and the server's), type, re-fill and message come from it.
  ///
  /// ```dart
  /// TextFormField(field: SignUp.email, form: state.form, decoration: …)
  /// ```
  final SchemaField<Object?>? field;

  /// The page's `state.form` (the answer of a failed submission) that
  /// re-fills [field] and gives its message. Inside a
  /// `Form(failed:, schema:)` it is not needed.
  final Object? form;

  /// With [field]: the native rules of a field with a `when` condition
  /// apply on this page (required only when creating: `applies: isNew`).
  final bool applies;

  /// Same as Flutter's `TextField.readOnly` (see [TextField.readOnly]: the
  /// browser skips its checks on a read-only field, the server's schema
  /// does not).
  final bool readOnly;

  /// Same as Flutter's `TextField.maxLength` (see [TextField.maxLength]),
  /// with its counter in the message line.
  final int? maxLength;

  /// Same as Flutter's `TextField.textInputAction`.
  final TextInputAction? textInputAction;

  /// Same as Flutter's `TextField.textCapitalization`.
  final TextCapitalization? textCapitalization;

  /// Same as Flutter's `TextField.textAlign`.
  final TextAlign textAlign;

  /// Same as Flutter's `TextField.autofillHints`.
  final Iterable<String>? autofillHints;

  /// The id of a [Datalist] that suggests values (`TextField.datalist`).
  final String? datalist;

  /// Same as Flutter's `TextField.obscuringCharacter` (not used: the
  /// browser draws its own dots).
  final String obscuringCharacter;

  /// Same as Flutter's `TextField.expands`.
  final bool expands;

  // web: not in Flutter: a Flutter form reads its fields through `Form`'s
  // state; the browser sends them by name.
  /// The form field name, and the base of its message ids: [name] as
  /// given, else the one of [field].
  String get name => _name ?? field!.name;
  final String? _name;

  /// Label, helper and error text (Flutter's `InputDecoration`).
  final InputDecoration decoration;

  /// Flutter's `validator`, as data: one rule, or `Validator.all([...])`
  /// for several. The browser enforces it natively (`required`, `type=email`,
  /// `minlength`…) and shows your message; a `FormSchema` checks the same
  /// rules again on the server.
  ///
  /// ```dart
  /// TextFormField(name: 'email', validator: Validator.email('Invalid e-mail'))
  /// ```
  ///
  /// web: Flutter's `validator` is a closure `(value) => String?`. A closure
  /// can't run in the browser, so it is not accepted here:
  /// `Validator.custom((v) => …)` is the closure form and it runs **only on
  /// the server** (after the form is sent), so it needs a schema that checks
  /// the form (THOR-P031 otherwise: it would be skipped without a word).
  final Validator? validator;

  /// More rules the browser enforces natively, in order (after
  /// [validator]).
  final List<Validator> validators;

  // web: not in Flutter.
  /// The server checks these rules again, so a
  /// `Validator.custom` in them is not lost (a field of a `FormSchema` sets
  /// it: `TextFormField(field: SignUp.email)`).
  final bool checkedByServer;

  // web: not in Flutter.
  /// More attributes for the `<input>` (`type=date`,
  /// `step=any`…), over what the rules set.
  final HtmlAttributes? inputAttributes;

  /// Same as Flutter's `TextField.style`.
  final TextStyle? style;

  /// Same as Flutter's `TextField.keyboardType`.
  final TextInputType? keyboardType;

  /// Same as Flutter's `TextField.obscureText`.
  final bool obscureText;

  /// Same as Flutter's `TextField.maxLines`: more than 1 is a `<textarea>`
  /// with the same rules, label and message line.
  final int? maxLines;

  /// Same as Flutter's `TextField.minLines` (see [TextField.minLines]).
  final int? minLines;

  /// Same as Flutter's `TextField.enabled`.
  final bool? enabled;

  /// Same as Flutter's `TextField.initialValue`.
  final String? initialValue;

  /// Called with the field's value on every change.
  final void Function(String value)? onChanged;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) {
    final f = field;
    if (f != null) return f.resolveTextFormField(this).build(context);
    final inputId = decoratedFieldId(context, null, name);
    // The rules of the field, else those the form's schema has for its name
    // (one definition for the browser and the server).
    final own = expandRules([?validator, ...validators]);
    final declared = FormScope.maybeOf(context)?.schema?.fieldNamed(name);
    final schemaField = own.isEmpty ? declared : null;
    // A field the schema calls secret is a password: hidden, never refilled.
    final hidden = obscureText || (declared?.secret ?? false);
    final rules = expandRules(schemaField?.validators ?? own);
    // A closure rule needs the server: without it the field would skip it
    // in silence.
    // Its own closure rules run on the server when the form's schema has
    // the same closure under this name (a tear-off is one object).
    final declaredChecks = [
      for (final v in expandRules(declared?.validators ?? const []))
        if (v.check != null) v.check,
    ];
    assert(
      schemaField != null ||
          checkedByServer ||
          rules.every(
            (v) => v.check == null || declaredChecks.contains(v.check),
          ),
      thorError(
        'THOR-P031',
        '`$name` has a `Validator.custom` (server only) but nothing on the '
            'server runs it: declare the field in a FormSchema '
            '(`static const $name = TextSchemaField(...)`) and use '
            '`Form(schema:, onValid:)`',
      ),
    );
    final validates = rules.any((v) => v.check == null);
    // Its messages need the forms part: the engine's, or an inline copy.
    if (validates) ThorStyleRegistry.active(context)?.useValidation();
    final scope = FormScope.maybeOf(context);
    final serverError = decoration.errorText ?? scope?.errorTextOf(name);
    final attributes = <String, String>{
      ...?schemaField?.attributes,
      if (schemaField == null)
        for (final v in rules) ...v.attributes,
      ...?inputAttributes,
      for (final v in rules)
        if (v.check == null) 'data-msg-${v.validity.toLowerCase()}': v.message,
      if (validates) validateAttr: '',
      if (serverError != null) 'aria-invalid': 'true',
    };
    return decoratedTextField(
      fieldInForm(
        TextField(
          id: inputId,
          name: name,
          decoration: decoration,
          style: style,
          keyboardType: keyboardType,
          obscureText: hidden,
          maxLines: maxLines,
          minLines: minLines,
          enabled: enabled,
          initialValue: initialValue,
          onChanged: onChanged,
          inputAttributes: trustedAttributes(attributes),
          readOnly: readOnly,
          maxLength: maxLength,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          textAlign: textAlign,
          autofillHints: autofillHints,
          datalist: datalist,
          obscuringCharacter: obscuringCharacter,
          expands: expands,
        ),
        context,
      ),
      context,
      debugName: 'TextFormField',
      // The line the engine writes the rules' messages into (an error or
      // a helper keeps it anyway); `aria-describedby` points at it.
      message: validates,
    );
  }
}

/// Flutter's `Form` → a native `<form>`: the browser checks every field's
/// rules on submit (focusing the first invalid one), with or without JS.
///
/// The form posts to an action method of the page: [onValid]
/// receives the values of [schema] already checked on the server (an
/// invalid form re-renders with `422` and the method never runs); [onPost]
/// takes only the request. Both are tear-offs of the page's methods, and
/// [S] makes the compiler check that the method takes this schema's
/// values:
///
/// ```dart
/// Form(schema: ContactForm.schema, onValid: send, child: …)
/// Form(onPost: favorite, child: …)
/// ```
///
/// With thor_engine, [onSubmit] (a `ThorState` method) runs instead of
/// posting (only when every field is valid). Without JS the form posts.
class Form<S extends FormSchema> extends StatelessWidget
    implements LayoutHint, HeightHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a form.
  const Form({
    super.key,
    required this.child,
    this.schema,
    this.onValid,
    this.onPost,
    this.onSubmit,
    this.action,
    this.formMethod,
    this.encoding = FormEncoding.urlEncoded,
    this.disableOnSubmit = true,
    this.resetScroll = false,
    this.failed,
    this.defaults,
    this.noValidate = false,
    this.preserveQuery = true,

    this.confirm,
  }) : assert(
         onValid == null || onPost == null,
         'a form posts to one action: onValid or onPost',
       );

  /// The form's fields and controls.
  final Widget child;

  /// The fields [onValid] receives: the same schema the server checks
  /// before running it (`TextFormField(field:)` puts the same rules in the
  /// browser).
  final S? schema;

  /// The page's action method that receives the checked values:
  /// `Future<ActionResult?> send(PageRequest request, FormValues<S> values)`.
  final PageValidPost<S>? onValid;

  /// The page's action method that takes only the request:
  /// `Future<ActionResult?> favorite(PageRequest request)`.
  final PagePost? onPost;

  /// Run on a valid submit instead of posting: a `ThorState` method
  /// (`signup.send`), in the browser.
  final VoidCallback? onSubmit;

  // web: not in Flutter.
  /// Where the form posts (a URL: another page, `mailto:`).
  /// With [onValid] or [onPost], the page whose method it is
  /// (`action: articleRoute.link(…), onPost: const ArticlePage().favorite`).
  /// A `'?/name'` string is the old, unchecked form of [onPost].
  final String? action;

  // web: Flutter's `Form` submits nowhere; the browser's sends a request.
  /// The HTTP method the plain-HTML submit uses: [FormMethod.post] (the
  /// default) or [FormMethod.get] (a search or a filter: the fields go in the
  /// URL).
  final FormMethod? formMethod;

  /// `// web:` how the browser encodes what it sends: [FormEncoding.multipart]
  /// to send files ([FileField]). A `mailto:` [action] goes as `text/plain`
  /// on its own, so the mail client keeps the body.
  final FormEncoding encoding;

  /// `// web:` whether a submit marks the form as sending: it gets
  /// `data-pending` and `aria-busy="true"` and its submit buttons are
  /// disabled until the next page arrives (no double submit; the pressed
  /// button's name and value still go). Flutter has no submit to wait for.
  /// Turn it off for a form whose answer stays on the page (a
  /// download): with no navigation, nothing tells the page it is done.
  final bool disableOnSubmit;

  /// Start at the top when the answer is this same page. By default a post
  /// the page answers (itself, a `422`, a redirect to its path) keeps the
  /// scroll and the pressed button; set it for a form that starts the page
  /// over (a filter reset, back to page 1). The per-redirect way is
  /// `Redirect(url, resetScroll: true)`.
  final bool resetScroll;

  /// What the page's action answered after a failed submit
  /// (`state.form`): the named fields below refill with what was sent and
  /// show their messages, with no `value:` or `errorText:` on each. Anything
  /// that is not a `FormInvalid` (a `ActionResult.success` data) is ignored.
  ///
  /// ```dart
  /// Form(schema: SignUp.schema, onValid: send, failed: state.form,
  ///   child: Column(children: [
  ///     TextFormField(name: 'email'),         // refilled, with its message
  ///     Checkbox(name: 'terms', value: false),
  ///   ]))
  /// ```
  ///
  /// web: Flutter keeps the typed text in the browser; here the server
  /// answers the submit with a new page, so it draws the values again
  /// (like Rails' `form_with model:` or Django's bound form).
  final Object? failed;

  /// The saved values of an edit form: a `Map` by field name or an object
  /// with `toJson()` (a model). What was sent ([failed]) wins; a field's
  /// own `initialValue` wins over these. THOR-P030 for anything else.
  final Object? defaults;

  /// `// web:` skips the browser's own bubbles on submit (`novalidate`), so
  /// the messages of the server show in the page. Flutter's `Form` has no
  /// browser validation to skip. The rules still run on the server.
  final bool noValidate;

  /// `// web:` whether the form keeps the page's query string when it
  /// posts to one of the page's actions (`?tab=account&/save`, not
  /// `?/save`, which replaces the whole query and lands the answer on the
  /// wrong tab or page). On by default; the answer of a failed post never
  /// carries the previous action key. Only for [onValid] / [onPost] with no
  /// [action] of its own.
  final bool preserveQuery;

  // web: not in Flutter.
  /// Ask before the form submits (`onPost`, `onValid`, `action`
  /// or `onSubmit`): the page's one native `<dialog>` shows the question and
  /// the form goes only on a yes. Without JavaScript it goes straight (see
  /// `FilledButton(confirm:)`).
  final ConfirmSpec? confirm;

  /// Flutter's `Form` takes its child's size: it fills the width when what
  /// is inside does (a `Column(crossAxisAlignment: stretch)`, a field), so a
  /// centered form doesn't shrink to its content and grow when a message
  /// shows.
  @override
  bool get fillsWidth => layoutFillsWidth(child);

  @override
  bool get fillsHeight => layoutFillsHeight(child);

  @override
  Widget build(BuildContext context) {
    // A form the engine submits (`onSubmit`) doesn't navigate: nothing to
    // wait for.
    if (disableOnSubmit && onSubmit == null) {
      ThorStyleRegistry.active(context)?.useFormScript();
    }
    // The answer of a POST that carries the failed form shows its errors and
    // focuses the first: whatever the status the action chose (a soft `200`).
    // A GET never is one (`failed:` is the answer of an action), and a
    // showcase `errorText` claims nothing.
    final verb = RequestScope.maybeOf(context)?.method;
    // Only when it has a field to focus: a failure of the form as a whole
    // (`formErrors`) must not let a field elsewhere claim the focus.
    final answer = failed;
    if (answer is FormInvalid &&
        answer.errors.isNotEmpty &&
        verb != null &&
        !verb.isRead) {
      ThorStyleRegistry.active(context)?.allowErrorFocus();
    }
    assert(
      !AutofillSection.inOwnForm(context),
      thorError(
        'THOR-P036',
        'a `Form` is inside an `AutofillGroup` that renders a `<form>` (a '
            'form in a form is not HTML): make the `Form` the '
            '`AutofillGroup`\'s child, or put the group inside the `Form`',
      ),
    );
    return thorElement(
      'form',
      debugName: 'Form',
      fillsWidth: fillsWidth,
      fillsHeight: fillsHeight,
      css: const {...boxCss},
      // Sending (the form script sets it): the pointer says «wait».
      conditions: const [
        ConditionalCss(CssCondition.selector('[data-pending]'), {
          'cursor': 'progress',
        }),
      ],
      childRules: ChildRules.box,
      attributes: {
        'action': ?_actionUrl(context),
        'method': formMethod?.value ?? FormMethod.post.value,
        // The `AutofillGroup` around it that asked the browser to forget.
        if (AutofillSection.formOff(context)) 'autocomplete': 'off',
        if (encoding != FormEncoding.urlEncoded)
          'enctype': encoding.value
        // web: a `mailto:` form sent urlencoded opens the mail client with
        // `a=1&b=2` (or no body at all, in most clients); as plain text the
        // body is one `name=value` line per field.
        else if (action?.trimLeft().toLowerCase().startsWith('mailto:') ??
            false)
          'enctype': 'text/plain',
        if (!disableOnSubmit) 'data-t-nopending': '',
        if (resetScroll) 'data-t-reset': '',
        if (noValidate) 'novalidate': '',
        ...confirmAttributes(ThorStyleRegistry.active(context), confirm),
        ...engineAttributes({'submit': onSubmit}),
      },
      children: [
        // web: without JS the dialog never asks, so a form with `confirm:`
        // posts its question too and the server asks it with a page.
        if (confirm case final spec?)
          Widget.element(
            tag: 'input',
            attributes: {
              'type': 'hidden',
              'name': askField,
              'value': askValue(spec),
            },
          ),
        // `onPost: page.save.bind(id)`: the arguments go with the form.
        if (postArgOf(onPost) case final arg?)
          Widget.element(
            tag: 'input',
            attributes: {'type': 'hidden', 'name': postArgField, 'value': arg},
          ),
        // The scope only when there is something to give: a plain form
        // renders as before.
        InsideForm(
          child:
              scopeFromForm(
                failed: failed,
                defaults: defaults,
                schema: schema,
                child: child,
              ) ??
              child,
        ),
      ],
    );
  }
}

extension<S extends FormSchema> on Form<S> {
  String? _actionUrl(BuildContext context) {
    final request = RequestScope.maybeOf(context);
    final query = preserveQuery ? request?.uri.query : null;
    final path = request?.routePath;
    if (onValid case final m?) {
      final found = actionMethodOf(m, 'onValid');
      assert(
        schema == null || identical(schema, found.schema),
        thorError(
          'THOR-P020',
          '`schema:` is not the schema `onValid:` checks '
              '(${found.name} receives FormValues of another instance)',
        ),
      );
      return actionUrl(
        m,
        'onValid',
        base: action,
        query: query,
        requestPath: path,
        localize: request?.localizedPath,
        keyless: true,
      );
    }
    if (onPost case final m?) {
      return actionUrl(
        m,
        'onPost',
        base: action,
        query: query,
        requestPath: path,
        localize: request?.localizedPath,
        keyless: true,
      );
    }
    return action;
  }
}

/// Tells the widgets below a [Form] that they are inside one: a submit
/// button with `onPost:` outside any form needs the page's shared one.
class InsideForm extends InheritedWidget {
  /// Marks [child] as inside a form.
  const InsideForm({super.key, required super.child});

  /// Whether [context] is below a [Form].
  static bool isIn(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<InsideForm>() != null;

  @override
  bool updateShouldNotify(InsideForm oldWidget) => false;
}

/// The HTTP method of a [Form]'s plain-HTML submit (its `method`).
// web: Flutter's `Form` has no request to send.
enum FormMethod {
  /// `post`: the default; the fields go in the body.
  post('post'),

  /// `get`: the fields go in the URL (a search, a filter).
  get('get'),

  /// `dialog`: closes the `<dialog>` that holds the form, sending nothing.
  dialog('dialog');

  const FormMethod(this.value);

  /// The `method` value.
  final String value;
}

/// How a [Form] encodes what it sends (its `enctype`).
enum FormEncoding {
  /// Text fields only (the browser's default).
  urlEncoded('application/x-www-form-urlencoded'),

  /// Fields and files: needed by a [FileField]. On the server,
  /// `request.form()` reads both (`form.file('avatar')`).
  multipart('multipart/form-data');

  const FormEncoding(this.value);

  /// The `enctype` value.
  final String value;
}

/// The suggestions a text field offers while the user types, native and
/// with no JS: a `<datalist>`. A field names it with `TextField(datalist:
/// id)`.
///
/// ```dart
/// Column(children: [
///   const Datalist(id: 'colors', options: ['red', 'green', 'blue']),
///   const TextField(name: 'color', datalist: 'colors'),
/// ])
/// ```
///
/// `// web:` Flutter has no suggestions for a plain `TextField` (its
/// `Autocomplete` draws an overlay); the browser's `<datalist>` is the native
/// one. It draws nothing itself. The field still takes any text; use a
/// `DropdownButtonFormField` to limit it to the options. A row of a
/// `Watch.list` can name its list per row with
/// `row.attribute(const AttributeName('list'), vm.listOf, child: …)`.
class Datalist extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// A list [id] with a suggestion per [options] value.
  const Datalist({super.key, required this.id, required this.options});

  /// What a field names in `TextField(datalist:)`.
  final String id;

  /// The suggested values, in order.
  final List<String> options;

  @override
  Widget build(BuildContext context) => thorElement(
    'datalist',
    id: id,
    debugName: 'Datalist',
    children: [
      for (final option in options)
        thorElement('option', attributes: {'value': option}),
    ],
  );
}

/// `// web:` a file input (`<input type="file">`): Flutter has none (apps use
/// a plugin), the browser has a native one that works without JS. Put it in
/// a `Form(encoding: FormEncoding.multipart)`; the server reads it with
/// `(await request.form()).file(name)`.
class FileField extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// A file input named [name].
  const FileField({
    super.key,
    required this.name,
    this.label,
    this.accept = const [],
    this.multiple = false,
    this.required = false,
    this.enabled = true,
  });

  /// The form field's name.
  final String name;

  /// Text above the input (the input is inside its `<label>`).
  final String? label;

  /// What the picker offers: media types or extensions
  /// (`['image/*', '.pdf']`); any file when empty.
  final List<String> accept;

  /// Whether several files can be chosen.
  final bool multiple;

  /// Whether the form can't be sent without a file.
  final bool required;

  /// Whether it can be used.
  final bool enabled;

  static const _button = <String, String>{
    'margin-right': '12px',
    'padding': '8px 16px',
    'border': '1px solid ${ThemeTokens.outline}',
    'border-radius': '20px',
    'background': 'transparent',
    'color': ThemeTokens.primary,
    'font': 'inherit',
    'cursor': 'pointer',
  };

  @override
  Widget build(BuildContext context) => thorElement(
    'label',
    debugName: 'FileField',
    css: const {
      'display': 'flex',
      'flex-direction': 'column',
      'gap': '6px',
      'box-sizing': 'border-box',
      'min-width': '0',
    },
    childRules: ChildRules.column,
    children: [
      if (label case final label?) Text(label),
      thorElement(
        'input',
        css: const {'font': 'inherit', 'max-width': '100%'},
        conditions: const [
          ConditionalCss(
            CssCondition.selector('::file-selector-button'),
            _button,
          ),
          ConditionalCss(CssCondition.selector(':disabled'), {
            'opacity': '0.38',
          }),
        ],
        attributes: {
          'type': 'file',
          'name': name,
          if (accept.isNotEmpty) 'accept': accept.join(','),
          if (multiple) 'multiple': '',
          if (required) 'required': '',
          if (!enabled) 'disabled': '',
        },
      ),
    ],
  );
}

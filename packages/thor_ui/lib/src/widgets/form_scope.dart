import 'package:thor_engine/thor_engine.dart' show encodeArg, isoDate;

import '../core/core.dart';
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/errors.dart';
import '../foundation/theme_tokens.dart';
import '../router/form_schema.dart' show FormInvalid, FormSchema;
import 'basic.dart' show SizedBox;
import 'text.dart' show Text;

/// What a `Form` gives the named fields below it: the values and the
/// messages of a failed submission (`failed:`), the saved values of an
/// edit form (`defaults:`) and the rules of its schema.
///
/// A field with a `name` (`TextField`, `TextFormField`, `Checkbox`,
/// `Switch`, `Radio`, `Slider`, `DropdownButton`, `DropdownMenu`, the date
/// fields) reads it: the page does not pass each field its value.
///
/// web: Flutter's `Form` keeps state in the browser; a thor form is
/// re-rendered by the server after each submit, so the values travel in the
/// page. Rails' `form_with model:` refills the same way (from the
/// model, or from the submitted params after a failed `save`), and
/// Django's bound `Form` renders `initial` until data is bound.
class FormScope extends InheritedWidget {
  /// Publishes [failed], [defaults] and [schema] to [child].
  const FormScope({
    super.key,
    this.failed,
    this.defaults = const {},
    this.schema,
    required super.child,
  });

  /// The failed submission this page answers, or `null` (a `GET`, or a
  /// `state.form` that is not a [FormInvalid]).
  final FormInvalid? failed;

  /// The saved values of an edit form, by field name.
  final Map<String, Object?> defaults;

  /// The schema whose rules a `TextFormField` without its own uses.
  final FormSchema? schema;

  /// The scope of the form around [context], or `null`.
  static FormScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FormScope>();

  /// Whether the scope decides the state of the field [name]: a failed
  /// submission decides every field; defaults only the fields they name.
  bool decides(String name) => failed != null || defaults.containsKey(name);

  /// The text the field [name] shows: what was sent, else the saved value
  /// (`null` when neither has it). A field the failed form doesn't know
  /// (not in its schema) keeps its saved value.
  String? valueOf(String name) => failed?.values[name] ?? _text(defaults[name]);

  /// Every value of the field [name] (a repeated input), in order.
  List<String> valuesOf(String name) {
    if (failed case final f?) {
      return f.valueLists[name] ?? [?f.values[name]];
    }
    return switch (defaults[name]) {
      final List<Object?> l => [for (final v in l) ?_text(v)],
      final v => [?_text(v)],
    };
  }

  /// Whether the checkbox or switch [name] is checked: whether it was
  /// sent, else the saved value's truth. `null` when the scope doesn't
  /// decide.
  bool? checked(String name) {
    if (failed case final f?) return f.sent(name);
    if (!defaults.containsKey(name)) return null;
    return switch (defaults[name]) {
      null || false || 0 || '' || 'false' || 'off' => false,
      _ => true,
    };
  }

  /// The messages of the field [name], in order.
  List<String> errorsOf(String name) => failed?.errorsOf(name) ?? const [];

  /// The messages of [name] as the one text a field's message line shows
  /// (one per line), or `null` when it has none.
  String? errorTextOf(String name) {
    final all = errorsOf(name);
    return all.isEmpty ? null : all.join('\n');
  }

  @override
  bool updateShouldNotify(FormScope oldWidget) =>
      failed != oldWidget.failed ||
      defaults != oldWidget.defaults ||
      schema != oldWidget.schema;
}

/// A [FormScope] around [child] from what a `Form` was given, or `null`
/// when there is nothing to give: `failed` is a [FormInvalid] (anything
/// else an action returned is not a failed form), `defaults` a Map or an
/// object with `toJson()` (THOR-P030 otherwise). Not exported.
FormScope? scopeFromForm({
  Object? failed,
  Object? defaults,
  FormSchema? schema,
  required Widget child,
}) {
  final invalid = failed is FormInvalid ? failed : null;
  final saved = formDefaults(defaults);
  if (invalid == null && saved.isEmpty && schema == null) return null;
  return FormScope(
    failed: invalid,
    defaults: saved,
    schema: schema,
    child: child,
  );
}

/// [defaults] as a name → value map (a Map, or the `toJson()` of a typed
/// object); THOR-P030 for anything else. Not exported.
Map<String, Object?> formDefaults(Object? defaults) {
  if (defaults == null) return const {};
  Object? map = defaults;
  if (map is! Map) {
    try {
      // A typed object (a model): its own JSON, as for a query's data.
      // ignore: avoid_dynamic_calls
      map = (defaults as dynamic).toJson();
    } on NoSuchMethodError {
      map = null;
    }
  }
  if (map is Map) return {for (final e in map.entries) '${e.key}': e.value};
  throw ArgumentError.value(
    defaults.runtimeType.toString(),
    'defaults',
    thorError(
      'THOR-P030',
      '`Form(defaults:)` takes a Map or an object with `toJson()`: '
          'its keys are the field names',
    ),
  );
}

/// A default as the text a field shows: a date as `yyyy-mm-dd` (what
/// `<input type=date>` takes), a number or a string as itself.
String? _text(Object? value) => switch (value) {
  null => null,
  // A repeated field: this input shows the first, `valuesOf` has them all.
  final List<Object?> l => l.isEmpty ? null : _text(l.first),
  final DateTime d => isoDate(d),
  final Enum e => e.name,
  final bool b => b ? 'true' : 'false',
  _ => encodeArg(value),
};

/// The messages of the field [name] of the enclosing `Form`, where you put
/// them: for a control that has no message line of its own (a `Checkbox`,
/// a `Radio` group). Nothing when the field has no message.
///
/// ```dart
/// Checkbox(name: 'terms', value: false),
/// const FormFieldError('terms'),
/// ```
class FormFieldError extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// The messages of [name].
  const FormFieldError(this.name, {super.key});

  /// The field name.
  final String name;

  @override
  Widget build(BuildContext context) {
    final messages = FormScope.maybeOf(context)?.errorsOf(name) ?? const [];
    if (messages.isEmpty) return const SizedBox();
    return thorElement(
      'div',
      debugName: 'FormFieldError',
      css: const {
        'font-size': '12px',
        'line-height': '16px',
        'color': ThemeTokens.error,
        'white-space': 'pre-line',
      },
      attributes: {'role': 'alert', 'data-field-error': name},
      children: [Text(messages.join('\n'))],
    );
  }
}

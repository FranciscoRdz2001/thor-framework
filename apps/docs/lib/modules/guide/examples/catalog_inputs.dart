/// The component catalog: inputs (`docs/guia/es/componentes-entradas.md`).
/// Every example is a bench: a stage, a panel with Switches and Levels, and
/// a Code view that follows them. The ids (`cat-text-field`…) are the ones
/// the widget pages of the API reference reuse.
library;

import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import 'bench/bench_example.dart';
import 'bench/bench_kit.dart';
import 'bench/bench_kit_preview.dart';

/// The width of every stage of this page.
const _stageWidth = 320.0;

// ------------------------------------------------------------------ TextField

/// What the TextField panel controls.
class TextFieldBenchViewModel extends ThorState {
  /// With `helperText`.
  final helper = state(true);

  /// With a `prefixIcon`.
  final icon = state(true);

  /// With an `errorText`.
  final error = state(false);

  /// Whether the field takes input.
  final enabled = state(true);

  /// What the field has typed, for the greeting.
  final name = state('');

  /// The greeting under the field.
  String message() =>
      name.value.isEmpty ? 'Type your name' : 'Hello, ${name.value}';

  /// The `helperText` line.
  String helperCode() => helper.value
      ? "helperText: 'What should we call you?',"
      : 'helperText: null,';

  /// The `prefixIcon` line.
  String iconCode() => icon.value
      ? 'prefixIcon: Icon(Icons.person, size: 18),'
      : 'prefixIcon: null,';

  /// The `errorText` line.
  String errorCode() =>
      error.value ? "errorText: 'Enter your full name.'," : 'errorText: null,';

  /// The `enabled` line.
  String enabledCode() => 'enabled: ${enabled.value},';

  /// What the field calls on each key.
  void setName(String value) => name.value = value.trim();

  /// What the helper Switch calls.
  void setHelper(bool value) => helper.value = value;

  /// What the icon Switch calls.
  void setIcon(bool value) => icon.value = value;

  /// What the error Switch calls.
  void setError(bool value) => error.value = value;

  /// What the enabled Switch calls.
  void setEnabled(bool value) => enabled.value = value;
}

/// One instance, at the top level.
final textFieldBench = TextFieldBenchViewModel();

/// `cat-text-field`.
final textFieldExample = BenchExample(
  title: (t) => t.exInpTextFieldTitle,
  description: (t) => t.exInpTextFieldDescription,
  stage: const _TextFieldStage(),
  code: BenchCode([
    const BenchCodeLine('TextField('),
    BenchCodeLine.live(textFieldBench.enabledCode, indent: 1),
    const BenchCodeLine('decoration: InputDecoration(', indent: 1),
    const BenchCodeLine("labelText: 'Name',", indent: 2),
    const BenchCodeLine("hintText: 'Jane Doe',", indent: 2),
    BenchCodeLine.live(textFieldBench.helperCode, indent: 2),
    BenchCodeLine.live(textFieldBench.iconCode, indent: 2),
    BenchCodeLine.live(textFieldBench.errorCode, indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine('onChanged: textFieldBench.setName,', indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    boolSwitch(
      label: (t) => t.exInpHelper,
      value: textFieldBench.helper.value,
      onChanged: textFieldBench.setHelper,
    ),
    boolSwitch(
      label: (t) => t.exCatIcon,
      value: textFieldBench.icon.value,
      onChanged: textFieldBench.setIcon,
    ),
    boolSwitch(
      label: (t) => t.exInpError,
      value: textFieldBench.error.value,
      onChanged: textFieldBench.setError,
    ),
    enabledSwitch(
      value: textFieldBench.enabled.value,
      onChanged: textFieldBench.setEnabled,
    ),
  ],
);

class _TextFieldStage extends StatelessWidget {
  const _TextFieldStage();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _stageWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Watch.field(
            textFieldBench.helper,
            builder: (helper) => Watch.field(
              textFieldBench.icon,
              builder: (icon) => Watch.field(
                textFieldBench.error,
                builder: (error) => Watch.field(
                  textFieldBench.enabled,
                  builder: (enabled) => TextField(
                    enabled: enabled,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: 'Jane Doe',
                      helperText: helper ? 'What should we call you?' : null,
                      prefixIcon: icon
                          ? const Icon(Icons.person, size: 18)
                          : null,
                      errorText: error ? 'Enter your full name.' : null,
                    ),
                    onChanged: textFieldBench.setName,
                  ),
                ),
              ),
            ),
          ),
          Watch(textFieldBench.message),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------- TextField states

/// The kinds of field of the states bench.
enum FieldKind {
  /// An email, with a keyboard.
  email,

  /// A password: `obscureText`.
  password,

  /// Several lines: `maxLines`.
  comments,
}

/// The states of a field.
enum FieldMode {
  /// As is.
  normal,

  /// With an `errorText`.
  error,

  /// With `enabled: false`.
  disabled,
}

/// What the states panel controls.
class FieldStatesViewModel extends ThorState {
  /// The kind of field.
  final kind = state(FieldKind.email);

  /// Its state.
  final mode = state(FieldMode.error);

  /// The lines that set the kind.
  String kindCode() => switch (kind.value) {
    FieldKind.email => 'keyboardType: TextInputType.emailAddress,',
    FieldKind.password => 'obscureText: true,',
    FieldKind.comments => 'maxLines: 4,',
  };

  /// The `enabled` line.
  String enabledCode() => 'enabled: ${mode.value != FieldMode.disabled},';

  /// The `labelText` line, with the label the stage shows.
  String labelCode() => switch (kind.value) {
    FieldKind.email => "labelText: 'Email',",
    FieldKind.password => "labelText: 'Password',",
    FieldKind.comments => "labelText: 'Comments',",
  };

  /// The `errorText` line.
  String errorCode() => mode.value == FieldMode.error
      ? "errorText: 'Check this field.',"
      : 'errorText: null,';

  /// What the kind Switch calls.
  void setKind(Set<FieldKind> value) => kind.value = value.first;

  /// What the state Switch calls.
  void setMode(Set<FieldMode> value) => mode.value = value.first;
}

/// The label of each kind of field.
String fieldLabel(FieldKind kind) => switch (kind) {
  FieldKind.email => 'Email',
  FieldKind.password => 'Password',
  FieldKind.comments => 'Comments',
};

/// One instance, at the top level.
final fieldStates = FieldStatesViewModel();

/// `cat-text-field-states`.
final textFieldStatesExample = BenchExample(
  title: (t) => t.exInpStatesTitle,
  description: (t) => t.exInpStatesDescription,
  stage: const _FieldStatesStage(),
  code: BenchCode([
    const BenchCodeLine('TextField('),
    BenchCodeLine.live(fieldStates.kindCode, indent: 1),
    BenchCodeLine.live(fieldStates.enabledCode, indent: 1),
    const BenchCodeLine('decoration: InputDecoration(', indent: 1),
    BenchCodeLine.live(fieldStates.labelCode, indent: 2),
    BenchCodeLine.live(fieldStates.errorCode, indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    BenchSwitch<FieldKind>(
      label: (t) => t.exInpKind,
      value: fieldStates.kind.value,
      onChanged: fieldStates.setKind,
      segments: [
        BenchSegment(FieldKind.email, label: (t) => t.exInpKindEmail),
        BenchSegment(FieldKind.password, label: (t) => t.exInpSegPassword),
        BenchSegment(FieldKind.comments, label: (t) => t.exInpSegComments),
      ],
    ),
    BenchSwitch<FieldMode>(
      label: (t) => t.exInpMode,
      value: fieldStates.mode.value,
      onChanged: fieldStates.setMode,
      segments: [
        BenchSegment(FieldMode.normal, label: (t) => t.exInpStateNormal),
        BenchSegment(FieldMode.error, label: (t) => t.exInpStateError),
        BenchSegment(FieldMode.disabled, label: (t) => t.exInpModeLocked),
      ],
    ),
  ],
);

class _FieldStatesStage extends StatelessWidget {
  const _FieldStatesStage();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _stageWidth),
      child: Watch.field(
        fieldStates.kind,
        builder: (kind) => Watch.field(
          fieldStates.mode,
          builder: (mode) {
            final enabled = mode != FieldMode.disabled;
            final error = mode == FieldMode.error ? 'Check this field.' : null;
            return switch (kind) {
              FieldKind.email => TextField(
                initialValue: 'jane@',
                enabled: enabled,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: fieldLabel(kind),
                  errorText: error,
                ),
              ),
              FieldKind.password => TextField(
                enabled: enabled,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: fieldLabel(kind),
                  errorText: error,
                ),
              ),
              FieldKind.comments => TextField(
                enabled: enabled,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: fieldLabel(kind),
                  errorText: error,
                ),
              ),
            };
          },
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- TextFormField

/// The fields of the sign-up form, declared once with their rules: the
/// page's action checks the same rules on the server (`SignUp.schema.parse`).
abstract final class SignUp {
  /// A required, valid email.
  static const email = TextSchemaField(
    'email',
    validators: [
      Validator.required('Enter your email.'),
      Validator.email('That email is not valid.'),
    ],
  );

  /// A required name of at least three letters.
  static const nick = TextSchemaField(
    'nick',
    validators: [
      Validator.required('Enter your name.'),
      Validator.minLength(3, 'At least three letters.'),
    ],
  );

  /// Both, as the server checks them.
  static const schema = FormSchema([email, nick]);
}

/// The rules of the form field.
enum FormRule {
  /// `required` and `email`.
  email,

  /// `required` and `minLength`.
  nick,
}

/// What the TextFormField panel controls.
class FormFieldBenchViewModel extends ThorState {
  /// The field's rules.
  final rule = state(FormRule.email);

  /// What the form did on its last submit.
  final status = state('');

  /// The line under the form.
  String statusText() => status.value;

  /// With `helperText`.
  final helper = state(true);

  /// The field line of the Code view.
  String fieldCode() =>
      'TextFormField(field: SignUp.${rule.value == FormRule.email ? 'email' : 'nick'},';

  /// The rules, as declared.
  String rulesCode() => rule.value == FormRule.email
      ? '// Validator.required + Validator.email'
      : '// Validator.required + Validator.minLength(3)';

  /// The `labelText` line, with the label the stage shows.
  String labelCode() =>
      "labelText: '${rule.value == FormRule.email ? 'Email' : 'Name'}',";

  /// The `helperText` line.
  String helperCode() => helper.value
      ? "helperText: 'Leave it empty and press Send.',"
      : 'helperText: null,';

  /// What the form calls on a valid submit.
  void send() => status.value = 'Sent';

  /// What the rule Switch calls.
  void setRule(Set<FormRule> value) => rule.value = value.first;

  /// What the helper Switch calls.
  void setHelper(bool value) => helper.value = value;
}

/// One instance, at the top level.
final formFieldBench = FormFieldBenchViewModel();

/// `cat-text-form-field`.
final textFormFieldExample = BenchExample(
  title: (t) => t.exInpFormTitle,
  description: (t) => t.exInpFormDescription,
  stage: const _FormFieldStage(),
  code: BenchCode([
    BenchCodeLine.live(formFieldBench.rulesCode),
    BenchCodeLine.live(formFieldBench.fieldCode),
    const BenchCodeLine('decoration: InputDecoration(', indent: 1),
    BenchCodeLine.live(formFieldBench.labelCode, indent: 2),
    BenchCodeLine.live(formFieldBench.helperCode, indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine('),'),
  ]),
  controls: [
    BenchSwitch<FormRule>(
      label: (t) => t.exInpRule,
      value: formFieldBench.rule.value,
      onChanged: formFieldBench.setRule,
      segments: [
        BenchSegment(FormRule.email, label: (t) => t.exInpKindEmail),
        BenchSegment(FormRule.nick, label: (t) => t.exInpName),
      ],
    ),
    boolSwitch(
      label: (t) => t.exInpHelper,
      value: formFieldBench.helper.value,
      onChanged: formFieldBench.setHelper,
    ),
  ],
);

class _FormFieldStage extends StatelessWidget {
  const _FormFieldStage();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _stageWidth),
      child: Form(
        onSubmit: formFieldBench.send,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Watch.field(
              formFieldBench.rule,
              builder: (rule) => Watch.field(
                formFieldBench.helper,
                builder: (helper) {
                  final decoration = InputDecoration(
                    labelText: rule == FormRule.email ? 'Email' : 'Name',
                    helperText: helper
                        ? 'Leave it empty and press Send.'
                        : null,
                  );
                  return rule == FormRule.email
                      ? TextFormField(
                          field: SignUp.email,
                          decoration: decoration,
                        )
                      : TextFormField(
                          field: SignUp.nick,
                          decoration: decoration,
                        );
                },
              ),
            ),
            const FilledButton(
              buttonType: ButtonType.submit,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [Icon(Icons.send, size: 18), Text('Send')],
              ),
            ),
            Watch(formFieldBench.statusText),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- DropdownButton

/// What the DropdownButton panel controls.
class DropdownBenchViewModel extends ThorState {
  /// `isExpanded`.
  final expanded = state(false);

  /// With a `hint`.
  final hint = state(true);

  /// Whether `onChanged` is set.
  final enabled = state(true);

  /// The chosen method.
  final method = state('');

  /// The summary under the control.
  String summary() => switch (method.value) {
    '' => 'Choose a shipping method',
    'express' => r'Arrives tomorrow · $149',
    'pickup' => 'Pick up in store · free',
    _ => r'Arrives in 3 to 5 days · $59',
  };

  /// The `isExpanded` line.
  String expandedCode() => 'isExpanded: ${expanded.value},';

  /// The `hint` line.
  String hintCode() => hint.value ? "hint: 'Shipping'," : 'hint: null,';

  /// The `onChanged` line.
  String changedCode() => enabled.value
      ? 'onChanged: shippingChoice.setMethod,'
      : 'onChanged: null,';

  /// What the dropdown calls.
  void setMethod(String? value) => method.value = value ?? 'standard';

  /// What the expanded Switch calls.
  void setExpanded(bool value) => expanded.value = value;

  /// What the hint Switch calls.
  void setHint(bool value) => hint.value = value;

  /// What the enabled Switch calls.
  void setEnabled(bool value) => enabled.value = value;
}

/// One instance, at the top level.
final shippingChoice = DropdownBenchViewModel();

/// `cat-dropdown`.
final dropdownExample = BenchExample(
  title: (t) => t.exInpDropdownTitle,
  description: (t) => t.exInpDropdownDescription,
  stage: const _DropdownStage(),
  code: BenchCode([
    const BenchCodeLine('DropdownButton<String>('),
    const BenchCodeLine(
      'value: null, // nothing chosen: shows the hint',
      indent: 1,
    ),
    BenchCodeLine.live(shippingChoice.hintCode, indent: 1),
    BenchCodeLine.live(shippingChoice.expandedCode, indent: 1),
    const BenchCodeLine('items: [', indent: 1),
    const BenchCodeLine("DropdownMenuItem(value: 'standard', …),", indent: 2),
    const BenchCodeLine("DropdownMenuItem(value: 'express', …),", indent: 2),
    const BenchCodeLine("DropdownMenuItem(value: 'pickup', …),", indent: 2),
    const BenchCodeLine('],', indent: 1),
    BenchCodeLine.live(shippingChoice.changedCode, indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    boolSwitch(
      label: (t) => t.exInpExpanded,
      value: shippingChoice.expanded.value,
      onChanged: shippingChoice.setExpanded,
    ),
    boolSwitch(
      label: (t) => t.exInpHint,
      value: shippingChoice.hint.value,
      onChanged: shippingChoice.setHint,
    ),
    enabledSwitch(
      value: shippingChoice.enabled.value,
      onChanged: shippingChoice.setEnabled,
    ),
  ],
);

class _DropdownStage extends StatelessWidget {
  const _DropdownStage();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _stageWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Watch.field(
            shippingChoice.expanded,
            builder: (expanded) => Watch.field(
              shippingChoice.hint,
              builder: (hint) => Watch.field(
                shippingChoice.enabled,
                // `// web:` the frame is the width the field has; `isExpanded`
                // is the dropdown filling it.
                builder: (enabled) {
                  final dropdown = DropdownButton<String>(
                    value: null,
                    hint: hint ? 'Shipping' : null,
                    isExpanded: expanded,
                    items: const [
                      DropdownMenuItem(
                        value: 'standard',
                        child: Text('Standard'),
                      ),
                      DropdownMenuItem(
                        value: 'express',
                        child: Text('Express'),
                      ),
                      DropdownMenuItem(
                        value: 'pickup',
                        child: Text('Pick up in store'),
                      ),
                    ],
                    onChanged: enabled ? shippingChoice.setMethod : null,
                  );
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: const Border.fromBorderSide(
                        BorderSide(color: ThemeColor.outlineVariant),
                      ),
                    ),
                    // `// web:` a collapsed dropdown is as wide as its text: a
                    // row keeps the frame from stretching it.
                    child: expanded ? dropdown : Row(children: [dropdown]),
                  );
                },
              ),
            ),
          ),
          Watch(shippingChoice.summary),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- Autocomplete

/// The lists the autocomplete suggests from.
enum OptionList {
  /// Fruits.
  fruits,

  /// Colors.
  colors,
}

/// What the Autocomplete panel controls.
class AutocompleteBenchViewModel extends ThorState {
  /// Which list.
  final list = state(OptionList.fruits);

  /// Where the panel opens.
  final up = state(false);

  /// The panel's `optionsMaxHeight`, in steps of 40 px from 80.
  final height = state(3);

  /// The pick.
  final picked = state('none');

  /// The summary under the field.
  String summary() => 'You picked: ${picked.value}';

  /// The number next to the height Level.
  String heightText() => '${80 + height.value * 40} px';

  /// The `optionsMaxHeight` line.
  String heightCode() => 'optionsMaxHeight: ${80 + height.value * 40},';

  /// The direction line.
  String directionCode() => up.value
      ? 'optionsViewOpenDirection: OptionsViewOpenDirection.up,'
      : 'optionsViewOpenDirection: OptionsViewOpenDirection.down,';

  /// The options line.
  String optionsCode() => list.value == OptionList.fruits
      ? 'optionsBuilder: (v) => fruits.where((f) => f.contains(v.text)),'
      : 'optionsBuilder: (v) => colors.where((c) => c.contains(v.text)),';

  /// What the autocomplete calls.
  void pick(String value) => picked.value = value;

  /// What the list Switch calls.
  void setList(Set<OptionList> value) => list.value = value.first;

  /// What the direction Switch calls.
  void setUp(Set<bool> value) => up.value = value.first;

  /// What the height Level calls.
  void setHeight(double value) => height.value = ((value - 80) / 40).round();
}

/// One instance, at the top level.
final fruitPick = AutocompleteBenchViewModel();

const _fruitNames = ['apple', 'banana', 'mango', 'melon', 'orange', 'pear'];
const _colorNames = ['black', 'blue', 'green', 'orange', 'red', 'yellow'];

/// `cat-autocomplete`.
final autocompleteExample = BenchExample(
  title: (t) => t.exInpAutocompleteTitle,
  description: (t) => t.exInpAutocompleteDescription,
  stage: const _AutocompleteStage(),
  code: BenchCode([
    const BenchCodeLine('Autocomplete<String>('),
    BenchCodeLine.live(fruitPick.optionsCode, indent: 1),
    BenchCodeLine.live(fruitPick.directionCode, indent: 1),
    BenchCodeLine.live(fruitPick.heightCode, indent: 1),
    const BenchCodeLine('onSelected: fruitPick.pick,', indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    BenchSwitch<OptionList>(
      label: (t) => t.exInpList,
      value: fruitPick.list.value,
      onChanged: fruitPick.setList,
      segments: [
        BenchSegment(OptionList.fruits, label: (t) => t.exInpListFruits),
        BenchSegment(OptionList.colors, label: (t) => t.exInpListColors),
      ],
    ),
    BenchSwitch<bool>(
      label: (t) => t.exInpOpens,
      value: fruitPick.up.value,
      onChanged: fruitPick.setUp,
      segments: [
        BenchSegment(false, label: (t) => t.exInpOpensDown),
        BenchSegment(true, label: (t) => t.exInpOpensUp),
      ],
    ),
    pxLevel(
      label: (t) => t.exInpPanelHeight,
      value: 80 + fruitPick.height.value * 40,
      min: 80,
      max: 240,
      divisions: 4,
      onChanged: fruitPick.setHeight,
      valueText: fruitPick.heightText,
    ),
  ],
);

class _AutocompleteStage extends StatelessWidget {
  const _AutocompleteStage();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _stageWidth),
      child: Column(
        spacing: 12,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Watch.field(
            fruitPick.list,
            builder: (list) => Watch.field(
              fruitPick.up,
              builder: (up) => Watch.field(
                fruitPick.height,
                count: 5,
                builder: (step) {
                  final names = list == OptionList.fruits
                      ? _fruitNames
                      : _colorNames;
                  final field = Autocomplete<String>(
                    semanticLabel: 'Autocomplete',
                    optionsMaxHeight: 80.0 + step * 40,
                    optionsViewOpenDirection: up
                        ? OptionsViewOpenDirection.up
                        : OptionsViewOpenDirection.down,
                    optionsBuilder: (value) => names.where(
                      (f) => f.contains(value.text.toLowerCase()),
                    ),
                    onSelected: fruitPick.pick,
                  );
                  // The panel only exists while the field has focus: the
                  // preview draws it open, where and as tall as it opens.
                  final panel = Container(
                    decoration: BoxDecoration(
                      color: ThemeColor.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: const Border.fromBorderSide(
                        BorderSide(color: ThemeColor.outlineVariant),
                      ),
                    ),
                    constraints: BoxConstraints(maxHeight: 80.0 + step * 40),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final name in names)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Text(name),
                            ),
                        ],
                      ),
                    ),
                  );
                  final input = Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: const Border.fromBorderSide(
                        BorderSide(color: ThemeColor.primary, width: 2),
                      ),
                    ),
                    child: const Text(
                      'Autocomplete',
                      style: TextStyle(color: ThemeColor.onSurfaceVariant),
                    ),
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      field,
                      PreviewFrame(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 4,
                          children: up ? [panel, input] : [input, panel],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Watch(fruitPick.summary),
        ],
      ),
    );
  }
}

// --------------------------------------------------- DropdownButtonFormField

/// What the DropdownButtonFormField panel controls.
class DropdownFormBenchViewModel extends ThorState {
  /// With `helperText`.
  final helper = state(true);

  /// With an `errorText`.
  final error = state(false);

  /// Whether `onChanged` is set.
  final enabled = state(true);

  /// The `helperText` line.
  String helperCode() => helper.value
      ? "helperText: 'Sizes follow the US scale.',"
      : 'helperText: null,';

  /// The `errorText` line.
  String errorCode() => error.value
      ? "errorText: 'Choose a size to continue.',"
      : 'errorText: null,';

  /// The `onChanged` line.
  String changedCode() =>
      enabled.value ? 'onChanged: (_) {},' : 'onChanged: null,';

  /// What the helper Switch calls.
  void setHelper(bool value) => helper.value = value;

  /// What the error Switch calls.
  void setError(bool value) => error.value = value;

  /// What the enabled Switch calls.
  void setEnabled(bool value) => enabled.value = value;
}

/// One instance, at the top level.
final sizeField = DropdownFormBenchViewModel();

/// `cat-dropdown-form-field`.
final dropdownFormFieldExample = BenchExample(
  title: (t) => t.exInpDdffTitle,
  description: (t) => t.exInpDdffDescription,
  stage: const _DropdownFormStage(),
  code: BenchCode([
    const BenchCodeLine('DropdownButtonFormField<String>('),
    const BenchCodeLine("name: 'size',", indent: 1),
    const BenchCodeLine("hint: 'Choose a size',", indent: 1),
    const BenchCodeLine('decoration: InputDecoration(', indent: 1),
    const BenchCodeLine("labelText: 'Size',", indent: 2),
    BenchCodeLine.live(sizeField.helperCode, indent: 2),
    BenchCodeLine.live(sizeField.errorCode, indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine('items: [DropdownMenuItem(…), …],', indent: 1),
    BenchCodeLine.live(sizeField.changedCode, indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    boolSwitch(
      label: (t) => t.exInpHelper,
      value: sizeField.helper.value,
      onChanged: sizeField.setHelper,
    ),
    boolSwitch(
      label: (t) => t.exInpError,
      value: sizeField.error.value,
      onChanged: sizeField.setError,
    ),
    enabledSwitch(
      value: sizeField.enabled.value,
      onChanged: sizeField.setEnabled,
    ),
  ],
);

class _DropdownFormStage extends StatelessWidget {
  const _DropdownFormStage();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _stageWidth),
      child: Watch.field(
        sizeField.helper,
        builder: (helper) => Watch.field(
          sizeField.error,
          builder: (error) => Watch.field(
            sizeField.enabled,
            builder: (enabled) => DropdownButtonFormField<String>(
              name: 'size',
              hint: 'Choose a size',
              decoration: InputDecoration(
                labelText: 'Size',
                helperText: helper ? 'Sizes follow the US scale.' : null,
                errorText: error ? 'Choose a size to continue.' : null,
              ),
              items: const [
                DropdownMenuItem(value: 's', child: Text('Small')),
                DropdownMenuItem(value: 'm', child: Text('Medium')),
                DropdownMenuItem(value: 'l', child: Text('Large')),
              ],
              onChanged: enabled ? (_) {} : null,
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- Dates

/// The two date fields.
enum DateKind {
  /// `InputDatePickerFormField`: the browser's field.
  native,

  /// `DatePickerFormField`: the field and a calendar.
  calendar,
}

/// What the dates panel controls.
class DateBenchViewModel extends ThorState {
  /// Which field.
  final kind = state(DateKind.calendar);

  /// `acceptEmptyDate`.
  final allowEmpty = state(false);

  /// The picked day, as text.
  final day = state('');

  /// The summary under the field.
  String summary() => day.value.isEmpty ? 'No date' : 'Booked on ${day.value}';

  /// The constructor line.
  String headCode() => kind.value == DateKind.native
      ? 'InputDatePickerFormField('
      : 'DatePickerFormField(';

  /// The `acceptEmptyDate` line.
  String emptyCode() => 'acceptEmptyDate: ${allowEmpty.value},';

  /// The callback line.
  String callbackCode() => kind.value == DateKind.native
      ? '// the value travels with the form'
      : 'onDateChanged: booking.setDay,';

  /// What the date picker calls.
  void setDay(DateTime date) =>
      day.value = '${date.day}/${date.month}/${date.year}';

  /// What the kind Switch calls.
  void setKind(Set<DateKind> value) => kind.value = value.first;

  /// What the empty Switch calls.
  void setAllowEmpty(bool value) => allowEmpty.value = value;
}

/// One instance, at the top level.
final booking = DateBenchViewModel();

/// `cat-date-field`.
final dateFieldExample = BenchExample(
  title: (t) => t.exInpDateTitle,
  description: (t) => t.exInpDateDescription,
  stage: const _DateStage(),
  code: BenchCode([
    BenchCodeLine.live(booking.headCode),
    const BenchCodeLine("name: 'day',", indent: 1),
    const BenchCodeLine("fieldLabelText: 'Booking day',", indent: 1),
    const BenchCodeLine('firstDate: DateTime(2026),', indent: 1),
    const BenchCodeLine('lastDate: DateTime(2027, 12, 31),', indent: 1),
    BenchCodeLine.live(booking.emptyCode, indent: 1),
    BenchCodeLine.live(booking.callbackCode, indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    BenchSwitch<DateKind>(
      label: (t) => t.exInpDateKind,
      value: booking.kind.value,
      onChanged: booking.setKind,
      segments: [
        BenchSegment(DateKind.native, label: (t) => t.exInpDateNative),
        BenchSegment(DateKind.calendar, label: (t) => t.exInpDateCalendar),
      ],
    ),
    boolSwitch(
      label: (t) => t.exInpAllowEmpty,
      value: booking.allowEmpty.value,
      onChanged: booking.setAllowEmpty,
    ),
  ],
);

class _DateStage extends StatelessWidget {
  const _DateStage();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _stageWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Watch.field(
            booking.kind,
            builder: (kind) => Watch.field(
              booking.allowEmpty,
              builder: (empty) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  kind == DateKind.native
                      // The browser's own date field: works without JavaScript.
                      ? InputDatePickerFormField(
                          name: 'day',
                          fieldLabelText: 'Booking day',
                          firstDate: DateTime(2026),
                          lastDate: DateTime(2027, 12, 31),
                          acceptEmptyDate: empty,
                        )
                      // The field plus a calendar button that opens a picker.
                      : DatePickerFormField(
                          name: 'day',
                          fieldLabelText: 'Booking day',
                          firstDate: DateTime(2026),
                          lastDate: DateTime(2027, 12, 31),
                          acceptEmptyDate: empty,
                          onDateChanged: booking.setDay,
                        ),
                  NoteRow(
                    label: 'Leave empty',
                    value: Text(empty ? 'is valid' : 'is an error'),
                  ),
                ],
              ),
            ),
          ),
          Watch(booking.summary),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- Slider

/// What the Slider panel controls.
class SliderBenchViewModel extends ThorState {
  /// The steps between 0 and 100, in fours; 0 is continuous.
  final divisions = state(5);

  /// Whether `onChanged` is set.
  final enabled = state(true);

  /// The slider's value.
  final level = state(40.0);

  /// The label under the slider.
  String label() => 'Volume: ${level.value.round()}%';

  /// The number next to the divisions Level.
  String divisionsText() =>
      divisions.value == 0 ? '∞' : '${divisions.value * 4}';

  /// The `divisions` line.
  String divisionsCode() => divisions.value == 0
      ? 'divisions: null,'
      : 'divisions: ${divisions.value * 4},';

  /// The `onChanged` line.
  String changedCode() =>
      enabled.value ? 'onChanged: volume.setLevel,' : 'onChanged: null,';

  /// What the slider calls.
  void setLevel(double value) => level.value = value;

  /// What the divisions Level calls.
  void setDivisions(double value) => divisions.value = (value / 4).round();

  /// What the enabled Switch calls.
  void setEnabled(bool value) => enabled.value = value;
}

/// One instance, at the top level.
final volume = SliderBenchViewModel();

/// `cat-slider`.
final sliderExample = BenchExample(
  title: (t) => t.exInpSliderTitle,
  description: (t) => t.exInpSliderDescription,
  stage: const _SliderStage(),
  code: BenchCode([
    const BenchCodeLine('Slider('),
    const BenchCodeLine('value: 40,', indent: 1),
    const BenchCodeLine('max: 100,', indent: 1),
    BenchCodeLine.live(volume.divisionsCode, indent: 1),
    const BenchCodeLine("semanticLabel: 'Volume',", indent: 1),
    BenchCodeLine.live(volume.changedCode, indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    enabledSwitch(value: volume.enabled.value, onChanged: volume.setEnabled),
    BenchLevel(
      label: (t) => t.exInpDivisions,
      value: volume.divisions.value * 4,
      max: 40,
      divisions: 10,
      onChanged: volume.setDivisions,
      valueText: volume.divisionsText,
    ),
  ],
);

class _SliderStage extends StatelessWidget {
  const _SliderStage();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Watch.field(
            volume.divisions,
            count: 11,
            builder: (steps) => Watch.field(
              volume.enabled,
              builder: (enabled) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 4,
                children: [
                  Slider(
                    value: 40,
                    max: 100,
                    divisions: steps == 0 ? null : steps * 4,
                    semanticLabel: 'Volume',
                    onChanged: enabled ? volume.setLevel : null,
                  ),
                  // The positions the thumb can take, as marks (the browser
                  // draws none for a native range).
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; steps > 0 && i <= steps * 4; i++)
                          const Container(
                            width: 1,
                            height: 6,
                            color: ThemeColor.outline,
                          ),
                      ],
                    ),
                  ),
                  Center(
                    child: NoteRow(
                      label: 'Positions',
                      value: Text(steps == 0 ? 'continuous' : '${steps * 4}'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Watch(volume.label),
        ],
      ),
    );
  }
}

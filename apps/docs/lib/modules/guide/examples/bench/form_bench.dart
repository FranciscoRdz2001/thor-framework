/// The two benches of the forms guide.
///
/// `:::bench bench-form-rule`: a Switch picks the rule of a field; each rule
/// is a variant the server compiled, so the browser's own validation shows
/// the message when the form is sent.
///
/// `:::bench bench-form-phase`: the three moments of a form that goes to the
/// server. A real `Form` marks itself while it sends (`// web:` here a Switch
/// plays the moments, because this site has no server to answer).
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';

/// Which rule the field has.
enum FieldRule {
  /// Not empty.
  required,

  /// An email.
  email,

  /// At least eight characters.
  minLength,
}

/// What the rule Switch changes.
class FormRuleViewModel extends ThorState {
  /// The rule of the field.
  final rule = state(FieldRule.required);

  /// The `validators` line of the Code view.
  String ruleCode() => switch (rule.value) {
    FieldRule.required => "Validator.required('Enter your email.'),",
    FieldRule.email => "Validator.email('That email does not look valid.'),",
    FieldRule.minLength => "Validator.minLength(8, 'At least 8 characters.'),",
  };

  /// What a valid submit calls (`// web:` this site has no server to post to).
  void send() {}

  /// What the Switch calls.
  void setRule(Set<FieldRule> value) => rule.value = value.first;
}

/// One instance, at the top level: the browser boots with it.
final formRule = FormRuleViewModel();

/// The rule example: a Switch, the form and its code.
final formRuleBench = BenchExample(
  title: (t) => t.exFormsRuleTitle,
  description: (t) => t.exFormsRuleDescription,
  stage: const FormRuleStage(),
  code: BenchCode([
    const BenchCodeLine('TextFormField('),
    const BenchCodeLine("name: 'email',", indent: 1),
    const BenchCodeLine('validators: const [', indent: 1),
    BenchCodeLine.live(formRule.ruleCode, indent: 2),
    const BenchCodeLine('],', indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    BenchSwitch<FieldRule>(
      label: (t) => t.exFormsRuleLabel,
      value: formRule.rule.value,
      onChanged: formRule.setRule,
      segments: [
        BenchSegment(FieldRule.required, label: (t) => t.exFormsRuleRequired),
        BenchSegment(FieldRule.email, label: (t) => t.exFormsRuleEmail),
        BenchSegment(FieldRule.minLength, label: (t) => t.exFormsRuleMin),
      ],
    ),
  ],
);

/// The stage: the field with the chosen rule, and a submit button.
class FormRuleStage extends StatelessWidget {
  /// The stage of the example.
  const FormRuleStage({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch.field(
      formRule.rule,
      builder: (rule) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Form(
          onSubmit: formRule.send,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              TextFormField(
                name: 'email',
                decoration: InputDecoration(
                  labelText: 'Email',
                  helperText: switch (rule) {
                    FieldRule.required => 'Required.',
                    FieldRule.email => 'Must be an email address.',
                    FieldRule.minLength => 'At least 8 characters.',
                  },
                ),
                validators: [
                  switch (rule) {
                    FieldRule.required => const Validator.required(
                      'Enter your email.',
                    ),
                    FieldRule.email => const Validator.email(
                      'That email does not look valid.',
                    ),
                    FieldRule.minLength => const Validator.minLength(
                      8,
                      'At least 8 characters.',
                    ),
                  },
                ],
              ),
              const FilledButton(
                buttonType: ButtonType.submit,
                child: Text('Send'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The moments of a form that goes to the server.
enum FormPhase {
  /// Waiting for the person.
  editing,

  /// Sent, waiting for the answer.
  sending,

  /// The server said no (`422`).
  failed,
}

/// What the phase Switch changes.
class FormPhaseViewModel extends ThorState {
  /// Which moment the stage shows.
  final phase = state(FormPhase.editing);

  /// The line of the Code view that says what the form does now.
  String phaseCode() => switch (phase.value) {
    FormPhase.editing => '// waiting: the button sends',
    FormPhase.sending => '// data-pending, aria-busy: buttons disabled',
    FormPhase.failed => '// 422: failed: puts the values and the message back',
  };

  /// What a valid submit calls (`// web:` this site has no server to post to).
  void send() {}

  /// What the Switch calls.
  void setPhase(Set<FormPhase> value) => phase.value = value.first;
}

/// One instance, at the top level: the browser boots with it.
final formPhase = FormPhaseViewModel();

/// The phase example: a Switch, the form and its code.
final formPhaseBench = BenchExample(
  title: (t) => t.exFormsPhaseTitle,
  description: (t) => t.exFormsPhaseDescription,
  stage: const FormPhaseStage(),
  code: BenchCode([
    const BenchCodeLine('Form('),
    const BenchCodeLine('schema: SignUp.schema,', indent: 1),
    const BenchCodeLine('onValid: send,', indent: 1),
    const BenchCodeLine('failed: state.form,', indent: 1),
    const BenchCodeLine('child: …,', indent: 1),
    const BenchCodeLine(')'),
    BenchCodeLine.live(formPhase.phaseCode),
  ], appCode: true),
  controls: [
    BenchSwitch<FormPhase>(
      label: (t) => t.exFormsPhaseLabel,
      value: formPhase.phase.value,
      onChanged: formPhase.setPhase,
      segments: [
        BenchSegment(FormPhase.editing, label: (t) => t.exFormsPhaseEditing),
        BenchSegment(FormPhase.sending, label: (t) => t.exFormsPhaseSending),
        BenchSegment(FormPhase.failed, label: (t) => t.exFormsPhaseFailed),
      ],
    ),
  ],
);

/// The stage: the same form in each moment.
class FormPhaseStage extends StatelessWidget {
  /// The stage of the example.
  const FormPhaseStage({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch.field(
      formPhase.phase,
      builder: (phase) => SizedBox(
        width: 300,
        child: Form(
          onSubmit: formPhase.send,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              TextFormField(
                name: 'email',
                decoration: InputDecoration(
                  labelText: 'Email',
                  errorText: phase == FormPhase.failed
                      ? 'That email already has an account.'
                      : null,
                ),
              ),
              FilledButton(
                buttonType: ButtonType.submit,
                onPressed: phase == FormPhase.sending ? null : () {},
                child: Text(
                  phase == FormPhase.sending
                      ? 'Creating account…'
                      : 'Create account',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `:::bench bench-greeting`: the three things a state does. A text field
/// calls `setName` with what you type, a Switch calls `setSalutation`, and
/// the stage shows both with `Watch`.
library;

import 'package:thor_ui/thor_ui.dart';

import '../bench/bench_example.dart';

/// The words the Switch offers (the state keeps the choice, not the text).
enum Salutation {
  /// A plain hello.
  hello,

  /// A welcome.
  welcome,
}

/// What the text field, the Switch and the stage share.
class GreetingViewModel extends ThorState {
  /// What is typed in the text field.
  final name = state('Ana');

  /// Which word opens the greeting.
  final salutation = state(Salutation.hello);

  /// The name on the stage (a placeholder while the field is empty).
  String nameText() => name.value.isEmpty ? '...' : name.value;

  /// The `name` line of the Code view.
  String nameCode() => "final name = state('${name.value}');";

  /// The `salutation` line of the Code view.
  String salutationCode() =>
      'final salutation = state(Salutation.${salutation.value.name});';

  /// What the text field calls with each change.
  void setName(String value) => name.value = value;

  /// What the Switch calls.
  void setSalutation(Set<Salutation> value) => salutation.value = value.first;
}

/// One instance, at the top level: the browser boots with it.
final greeting = GreetingViewModel();

/// The example.
final greetingBench = BenchExample(
  title: (t) => t.exStateGreetingTitle,
  description: (t) => t.exStateGreetingDescription,
  stage: const GreetingStage(),
  code: BenchCode([
    const BenchCodeLine('class GreetingViewModel extends ThorState {'),
    BenchCodeLine.live(greeting.nameCode, indent: 1),
    BenchCodeLine.live(greeting.salutationCode, indent: 1),
    const BenchCodeLine(' '),
    const BenchCodeLine(
      'void setName(String value) => name.value = value;',
      indent: 1,
    ),
    const BenchCodeLine('}'),
    const BenchCodeLine(' '),
    const BenchCodeLine('TextField(onChanged: greeting.setName)'),
    const BenchCodeLine('Watch(greeting.nameText)'),
  ]),
  controls: [
    BenchSwitch<Salutation>(
      label: (t) => t.exStateGreetingSalutation,
      value: greeting.salutation.value,
      onChanged: greeting.setSalutation,
      segments: [
        BenchSegment(Salutation.hello, label: (t) => t.exStateGreetingHello),
        BenchSegment(Salutation.welcome, label: (t) => 'Welcome'),
      ],
    ),
  ],
);

/// The stage: a text field and the greeting that follows it.
class GreetingStage extends StatelessWidget {
  /// The stage of the example.
  const GreetingStage({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          TextField(
            initialValue: 'Ana',
            onChanged: greeting.setName,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          Row(
            spacing: 6,
            children: [
              Watch.field(
                greeting.salutation,
                builder: (salutation) => Text(
                  switch (salutation) {
                    Salutation.hello => 'Hello',
                    Salutation.welcome => 'Welcome',
                  },
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Watch(
                greeting.nameText,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: ThemeColor.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:thor_ui/thor_ui.dart';

import 'feedback_state.dart';

/// `confirm()` and `toast()` from a state method, next to a list they change.
class FeedbackCases extends StatelessWidget {
  const FeedbackCases({super.key});

  @override
  Widget build(BuildContext context) => Column(
    spacing: 8,
    children: [
      Watch.list(
        feedback.names,
        itemKey: feedback.nameOf,
        each: (row) => Row(
          spacing: 8,
          children: [
            row.text(feedback.nameOf),
            TextButton(
              onPressed: feedback.removeAsk.withArg(row.key),
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
      Row(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: feedback.askTwice,
            child: const Text('Two asks'),
          ),
          OutlinedButton(
            onPressed: feedback.say.withArg('Hello <b>'),
            child: const Text('Say'),
          ),
          OutlinedButton(onPressed: feedback.fail, child: const Text('Fail')),
        ],
      ),
      Watch(feedback.logText),
    ],
  );
}

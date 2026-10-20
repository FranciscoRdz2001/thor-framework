import 'package:thor_ui/thor_ui.dart';

import 'tokens.dart';

/// A page's `<h1>` and its one-line description.
class PageTitle extends StatelessWidget implements ThorElementWidget {
  /// The title [text] and its [description].
  const PageTitle(this.text, {super.key, this.description});

  /// The title.
  final String text;

  /// Under the title.
  final String? description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 4,
    children: [
      Semantics(headingLevel: 1, child: Text(text, style: titleStyle)),
      if (description != null)
        Text(description!, style: const TextStyle(color: muted)),
    ],
  );
}

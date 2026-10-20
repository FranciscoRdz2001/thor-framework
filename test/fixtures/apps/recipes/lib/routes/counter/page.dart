import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../likes_state.dart';
import '../../ui/page_title.dart';
import '../../ui/tokens.dart';

/// The page `/counter`.
class CounterPage extends ThorPage<void> {
  /// The one instance the build shares between requests.
  const CounterPage();

  /// `/counter`.
  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'Contador');

  /// A like button: the only part that needs JavaScript.
  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 16,
    children: [
      const PageTitle(
        'Estado en el navegador',
        description: 'Un ThorState: campos state() y métodos.',
      ),
      Row(
        spacing: 12,
        mainAxisSize: MainAxisSize.min,
        children: [
          Watch(
            likes.isLiked,
            builder: (liked) => FilledButton(
              onPressed: likes.toggle,
              child: Text(liked ? 'Ya no me gusta' : 'Me gusta'),
            ),
          ),
          Watch(likes.label, style: const TextStyle(color: muted)),
        ],
      ),
    ],
  );
}

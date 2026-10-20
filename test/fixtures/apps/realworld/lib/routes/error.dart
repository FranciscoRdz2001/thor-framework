import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

/// "Not found!" / "Something went wrong", like the reference.
class AppErrorPage extends ErrorPage {
  /// The page.
  const AppErrorPage();

  @override
  Widget build(BuildContext context, ErrorState state) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 64),
    child: Semantics(
      headingLevel: 1,
      child: Text(
        state.status == StatusCode.notFound
            ? 'Not found!'
            : 'Something went wrong',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w500,
        ).when(expanded: const TextStyle(fontSize: 64)),
      ),
    ),
  );
}

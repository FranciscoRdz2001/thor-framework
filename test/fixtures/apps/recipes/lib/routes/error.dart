import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../router.dart';

/// A missing page (or an error), with a way back.
class AppErrorPage extends ErrorPage {
  /// The page.
  const AppErrorPage();

  @override
  Widget build(BuildContext context, ErrorState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      Semantics(
        headingLevel: 1,
        child: Text(
          state.status == StatusCode.notFound
              ? 'No encontramos esa página'
              : 'Algo salió mal',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
      ),
      Link(href: homeRoute.link(), child: const Text('Volver al inicio')),
    ],
  );
}

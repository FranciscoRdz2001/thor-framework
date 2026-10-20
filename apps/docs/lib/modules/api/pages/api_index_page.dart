import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../core/content/redirects.dart';

/// The page `/api`: it only redirects.
class ApiIndexPage extends ThorPage<String> {
  /// Never renders: it only redirects.
  const ApiIndexPage();

  /// `/api` → the reference of `thor_ui`, in the reader's language.
  @override
  String load(PageRequest request) =>
      throw Redirect.permanent(request.localizedPath(indexRedirects['/api']!));

  @override
  Widget build(BuildContext context, PageState<String> state) =>
      const SizedBox.shrink();
}

import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../../api.dart';
import '../../../../session.dart';
import '../../../../widgets/auth.dart' show FormFailure;
import '../../../../widgets/editor.dart';

/// The page `/editor/:slug`.
class EditorBySlugPage extends ThorPage<Article> with EditorActions<Article> {
  /// The one instance the build shares between requests.
  const EditorBySlugPage();

  /// The article to edit.
  @override
  Future<Article> load(PageRequest request) => api.article(
    request.pathParameters['slug']!,
    token: request.signedIn.token,
  );

  /// Save the article (and add / remove tags without JS).
  @override
  bool get updates => true;

  /// Title.
  @override
  PageMeta meta(PageState<Article> state) =>
      const PageMeta(title: 'Editor • Conduit', robotsMeta: RobotsMeta.noindex);

  /// The editor filled with the article.
  @override
  Widget build(BuildContext context, PageState<Article> state) => EditorView(
    page: this,
    article: state.data,
    failure: state.form as FormFailure?,
  );
}

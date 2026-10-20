import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../widgets/auth.dart' show FormFailure;
import '../../../widgets/editor.dart';

/// The page `/editor`.
class EditorPage extends ThorPage<void> with EditorActions<void> {
  /// The one instance the build shares between requests.
  const EditorPage();

  /// Publish a new article (and add / remove tags without JS).
  @override
  bool get updates => false;

  /// Title.
  @override
  PageMeta meta(PageState<void> state) =>
      const PageMeta(title: 'Editor • Conduit', robotsMeta: RobotsMeta.noindex);

  /// An empty editor.
  @override
  Widget build(BuildContext context, PageState<void> state) =>
      EditorView(page: this, failure: state.form as FormFailure?);
}

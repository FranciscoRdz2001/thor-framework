import 'package:thor_ui/html.dart' show css;
import 'package:thor_ui/thor_ui.dart';

import 'data.dart';

/// The app's own rules: a hidden field's cells disappear while its column
/// marker (a direct child of the grid) has the class `gh<column>`.
List<StyleRule> get gridStyles => [
  for (final f in GridField.values.skip(1))
    css(
      '.grid-root:has(> .gh${f.index}) .gc${f.index}',
    ).props(const StyleProps(offstage: true)),
];

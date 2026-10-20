/// Error codes (docs/errores): every framework error or warning with a
/// code carries it and its page, so a message is one click from the cause
/// and the fix. The pages are the owner; `tool/test/error_codes_test.dart`
/// keeps code and pages in step.
library;

import 'package:thor_style/errors.dart' show thorError;
import 'package:thor_style/thor_style.dart'
    show EdgeInsets, EdgeInsetsDirectional, EdgeInsetsGeometry;

// `thorError` and `thorErrorsUrl` (a message with its code and page) are
// thor_style's: one copy for the packages that build on it.
export 'package:thor_style/errors.dart' show thorError, thorErrorsUrl;

/// [padding] when its sides are numbers; a StateError (THOR-R036) when a side
/// is a `Length`, which the
/// browser resolves and [owner] would otherwise read as 0 and drop without a
/// word. (A widget that takes an [EdgeInsets] already cannot be given an
/// `EdgeInsetsGeometry.allLength`: it is not an `EdgeInsets`.)
EdgeInsets numericInsets(EdgeInsets padding, String owner) {
  if (!padding.hasLengths) return padding;
  throw StateError(
    thorError(
      'THOR-R036',
      '$owner needs numeric insets: it adds them to its own, and a '
          'Length inset (a CSS variable) would count as 0. Use EdgeInsets.all / '
          'symmetric / only with numbers here.',
    ),
  );
}

/// The left plus right (or start plus end) of [padding], for a widget that
/// adds them up; a StateError (THOR-R036) for a geometry whose sides are
/// `Length`s, which the browser resolves.
double numericHorizontal(EdgeInsetsGeometry padding, String owner) =>
    switch (padding) {
      EdgeInsets() => padding.horizontal,
      EdgeInsetsDirectional() => padding.horizontal,
      _ => throw StateError(
        thorError(
          'THOR-R036',
          '$owner needs numeric insets: it adds the horizontal ones to its '
              'own, and a Length inset (EdgeInsetsGeometry.allLength, a CSS '
              'variable) is resolved by the browser. Use EdgeInsets.all / '
              'symmetric / only (or EdgeInsetsDirectional) with numbers here.',
        ),
      ),
    };

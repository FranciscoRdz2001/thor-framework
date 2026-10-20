/// Error codes (docs/errores): every framework error or warning with a
/// code carries it and its page, so a message is one click from the cause
/// and the fix. The pages are the owner; `tool/test/error_codes_test.dart`
/// keeps code and pages in step.
library;

// `thorError` and `thorErrorsUrl` are thor_style's: one copy for the
// packages that build on it.
export 'package:thor_style/errors.dart' show thorError, thorErrorsUrl;

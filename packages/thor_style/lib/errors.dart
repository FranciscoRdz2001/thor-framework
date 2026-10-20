/// The error codes' URL and the helper that writes it into a message: the one
/// copy that `thor_ui`, `thor_server` and `thor_builder` reuse (internal to
/// thor's packages: an app has no use for it).
library;

export 'src/errors.dart' show thorError, thorErrorsUrl;

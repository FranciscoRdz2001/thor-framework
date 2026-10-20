/// Error codes (docs/errores): a CLI error with a code carries it and its
/// page, so a message is one click from the cause and the fix. The pages are
/// the owner; `tool/test/error_codes_test.dart` keeps code and pages in step.
library;

// The one copy lives in thor_style (shared with thor_ui, thor_server and
// thor_builder): a change of the docs domain or the message format happens
// there and reaches the CLI too.
export 'package:thor_style/errors.dart' show thorError, thorErrorsUrl;

/// The shape of a diagnostic line (`file.dart:12:5: Error: message`; a path
/// may hold spaces): file, line, column, severity and message.
const diagnosticLinePattern =
    r'^(.+?\.dart):(\d+):(\d+): (Error|Warning): (.*)$';

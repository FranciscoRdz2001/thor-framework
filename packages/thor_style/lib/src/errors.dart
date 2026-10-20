/// Error codes (docs/errores): every framework error or warning with a
/// code carries it and its page, so a message is one click from the cause
/// and the fix. The pages are the owner; `tool/test/error_codes_test.dart`
/// keeps code and pages in step.
///
/// This is the one copy: `thor_ui`, `thor_server` and `thor_builder` reuse
/// it (`tool/error_codes.dart`).
library;

/// Where each code's page is. No language in it: the site sends
/// `/errores/<code>` to the page in the reader's language.
const thorErrorsUrl = 'https://thor-docs.vercel.app/errores/';

/// [message] with [code] and its page: `… (THOR-S001 · https://…/THOR-S001)`.
String thorError(String code, String message) =>
    '$message ($code · $thorErrorsUrl$code)';

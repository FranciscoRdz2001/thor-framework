/// Where the pages of thor's error codes are published: thor_style's copy
/// (tool/error_codes.dart keeps one per repository; the lite translator in
/// `lib/lite/` writes its codes with thor_style's `thorError`).
library;

import 'package:thor_style/errors.dart' show thorErrorsUrl;

export 'package:thor_style/errors.dart' show thorError;

/// The base of every code's page (`${errorsUrl}THOR-S011`).
const errorsUrl = thorErrorsUrl;

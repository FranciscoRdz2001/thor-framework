/// The errors module: the index of error codes and one page per code.
library;

import 'package:thor_ui/router.dart';

import 'pages/error_code_page.dart';
import 'pages/errors_page.dart';

/// Every error code, `/errores`.
final errorsRoute = ThorRoute('/errores', const ErrorsPage());

/// What an error code means and how to fix it, `/errores/:code`.
final errorCodeRoute = ThorRoute('/errores/:code', const ErrorCodePage());

/// Every route of the error codes.
final errorsModule = Group(children: [errorsRoute, errorCodeRoute]);

// One page: the sheet.
import 'package:thor_ui/router.dart';

import 'cells.dart';

/// Every route of the app.
final ThorRouter router = ThorRouter([ThorRoute('/', const CellsPage())]);

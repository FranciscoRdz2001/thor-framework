// The app's routes: the lazy pieces lab.
import 'package:thor_ui/router.dart';

import 'modules/piece/piece_routes.dart';

/// Every route of the app.
final ThorRouter router = ThorRouter([
  Group(children: [pieceModule]),
]);

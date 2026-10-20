import 'package:thor_ui/router.dart';

import 'pages/piece_page.dart';

/// `/piece`.
final pieceRoute = ThorRoute('/piece', const PiecePage());

/// The lazy pieces lab.
final pieceModule = Group(children: [pieceRoute]);

import 'package:thor_ui/router.dart';

import 'pages/burst_page.dart';
import 'pages/late_pages.dart';
import 'pages/piece_page.dart';

/// `/piece`.
final pieceRoute = ThorRoute('/piece', const PiecePage());

/// `/stream`: a `FutureBuilder` and the engine.
final streamRoute = ThorRoute('/stream', const StreamPage());

/// `/nested`: a piece inside a piece.
final nestedRoute = ThorRoute('/nested', const NestedPage());

/// `/burst`: pieces at once.
final burstRoute = ThorRoute('/burst', const BurstPage());

/// The lazy pieces lab.
final pieceModule = Group(
  children: [pieceRoute, streamRoute, nestedRoute, burstRoute],
);

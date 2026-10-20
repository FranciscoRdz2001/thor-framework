// `LazyPiece` and a `FutureBuilder` on test/fixtures/apps/lazy_pieces, in both engines
// (`tool/thor e2e lazy-pieces` is lite, `lazy-pieces-dart` dart2js): the
// checks of lazy_piece_check.mjs plus a piece inside a piece and the late
// content of a `FutureBuilder` bound by the engine.
process.env.LAZY_APP = 'lazy_pieces';
await import('./lazy_piece_check.mjs');

/// The thor-lite translator: an app's `ThorState` classes (and the code they
/// reach) as JS for the lite engine, or the constructs outside its subset.
///
/// One translator for the editor (the `thor_lite_subset` rule of this
/// plugin) and the build (`thor_builder`'s `lite_state` step, which writes
/// the bundle): both say the same thing about the same code.
///
/// Pure analyzer (and thor_style, for the CSS of a constant `Curve`): no
/// `analysis_server_plugin` import, so other packages can use it.
library;

export 'lite/data_class.dart';
export 'lite/lite_check.dart';
export 'lite/lite_hints.dart';
export 'lite/lite_state_js.dart';
export 'lite/row_lambdas.dart';
export 'lite/state_members.dart';

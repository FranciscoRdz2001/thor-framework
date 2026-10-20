import 'package:thor_ui/thor_ui.dart';

import '../../guide/examples/bench/bench_example.dart';
import '../../guide/examples/bench/card_style_bench.dart';

/// The home's one live example: the style reference of the guide
/// (`cardStyleBench`: a product card, its controls and its code), drawn by
/// the same [BenchView] as every `:::bench`.
class HomeBench extends StatelessWidget {
  /// The bench.
  const HomeBench({super.key});

  @override
  Widget build(BuildContext context) => BenchView('home-bench', cardStyleBench);
}

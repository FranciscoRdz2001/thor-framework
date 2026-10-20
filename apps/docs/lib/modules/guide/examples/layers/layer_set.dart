/// A layer diagram of the guide: the layers of an architecture, each with
/// what it is for and its code in Flutter and in Thor. `:::layers id` in the
/// markdown shows the set registered under `id` in `layer_sets.dart`.
///
/// The names of the layers (`View`, `ViewModel`, `Repository`…) are the ones
/// of Flutter's app architecture guide and stay as they are in every
/// language; what each layer is made of and what it is for are messages of
/// the ARB.
library;

import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../../core/i18n/docs_locale.dart';
import '../bench/bench_example.dart' show MessageOf;

/// One layer of a [LayerSet].
class LayerSpec {
  /// A layer named [title] (`View`) made of [kind], with its [description]
  /// and the code of both frameworks.
  const LayerSpec({
    required this.title,
    required this.kind,
    required this.description,
    required this.flutterCode,
    required this.thorCode,
  });

  /// The layer's name, as Flutter's architecture guide calls it.
  final String title;

  /// What it is made of (`Widget`, `ThorState`), a message.
  final MessageOf kind;

  /// What it is for, a message.
  final MessageOf description;

  /// The layer written in Flutter.
  final String flutterCode;

  /// The layer written in Thor.
  final String thorCode;
}

/// The layers of one feature, in the order the data flows.
class LayerSet {
  /// A set of [layers].
  const LayerSet(this.layers);

  /// The layers, in order.
  final List<LayerSpec> layers;
}

/// A [LayerSet] as a `StudioLayerDiagram`: click a layer to read what it is
/// for and its code, Flutter or Thor.
class LayersView extends StatelessWidget {
  /// The diagram of [set].
  const LayersView(this.set, {super.key});

  /// What to show.
  final LayerSet set;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return StudioLayerDiagram(
      layers: [
        for (final layer in set.layers)
          StudioLayer(
            title: layer.title,
            kind: layer.kind(t),
            description: layer.description(t),
            flutterCode: layer.flutterCode,
            thorCode: layer.thorCode,
          ),
      ],
    );
  }
}

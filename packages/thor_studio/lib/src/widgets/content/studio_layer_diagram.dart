import 'package:thor_ui/thor_ui.dart';

import '../../icons.dart';
import '../../theme/component_themes/studio_card_theme.dart';
import '../../theme/studio_extra_colors.dart';
import 'studio_flutter_compare.dart';

/// One layer of a [StudioLayerDiagram].
class StudioLayer {
  /// A layer named [title] with its [description] and the code of both
  /// frameworks.
  const StudioLayer({
    required this.title,
    this.kind,
    required this.description,
    required this.flutterCode,
    required this.thorCode,
  });

  /// The layer's name (`View`, `ViewModel`, `Repository`, `Service`).
  final String title;

  /// A small line above the name: what the layer is made of (`Widget`,
  /// `ThorState`).
  final String? kind;

  /// What the layer is for, in a sentence or two.
  final String description;

  /// The layer written in Flutter.
  final String flutterCode;

  /// The layer written in Thor.
  final String thorCode;
}

/// An architecture diagram whose layers you open: View → ViewModel →
/// Repository → Service, each with what it is for and its code in Flutter and
/// in Thor.
///
/// ```dart
/// StudioLayerDiagram(
///   label: l10n.layersLabel,
///   layers: [
///     StudioLayer(
///       title: 'View',
///       kind: 'Widget',
///       description: 'Shows the state and reports what the person does.',
///       flutterCode: viewFlutter,
///       thorCode: viewThor,
///     ),
///     // ViewModel, Repository, Service…
///   ],
///   flutterLabel: l10n.inFlutter,
///   thorLabel: l10n.inThor,
///   copyLabel: l10n.copy,
///   copiedLabel: l10n.copied,
/// )
/// ```
///
/// Nothing is hard-coded: the layers, their order and every label come from
/// the parameters.
///
/// `// web:` the layers are native radios (`DefaultTabController`, `TabBar`,
/// `TabBarView`) and each panel holds a [StudioFlutterCompare], so the whole
/// diagram works with no JavaScript, arrow keys move between layers and every
/// layer's code is in the page for search and print.
class StudioLayerDiagram extends StatelessWidget implements ThorElementWidget {
  /// A diagram over [layers]; the first one is open.
  const StudioLayerDiagram({
    super.key,
    required this.layers,
    this.id,
    this.initialIndex = 0,
    this.flutterLabel,
    this.thorLabel,
    this.copyButton = true,
    this.copyLabel,
    this.copiedLabel,
  });

  /// The layers, in the order of the data flow.
  final List<StudioLayer> layers;

  /// Names the radio group and the panels' ids (default: its place in the
  /// page).
  final String? id;

  /// The layer open when the page loads.
  final int initialIndex;

  /// The Flutter tab's text (default: `StudioLocalizations.flutterLabel`).
  final String? flutterLabel;

  /// The Thor tab's text (default: `StudioLocalizations.thorLabel`).
  final String? thorLabel;

  /// Whether the copy buttons show (it needs `scripts/studio-code.js`).
  final bool copyButton;

  /// The copy buttons' text (default: `StudioLocalizations.copy`).
  final String? copyLabel;

  /// The text after copying (default: [copyLabel]).
  final String? copiedLabel;

  @override
  Widget build(BuildContext context) {
    assert(layers.isNotEmpty, 'A StudioLayerDiagram needs a layer');
    final card = StudioCardThemeData.of(context);
    final scheme = Theme.of(context).colorScheme;
    final extra = StudioExtraColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: card.color,
        border: Border.all(color: card.borderColor),
        borderRadius: BorderRadius.circular(card.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: DefaultTabController(
        id: id,
        length: layers.length,
        initialIndex: initialIndex,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              isScrollable: true,
              indicatorColor: scheme.accent,
              labelColor: scheme.onSurface,
              unselectedLabelColor: scheme.onSurfaceVariant!,
              dividerColor: card.borderColor,
              tabs: [
                for (final (i, layer) in layers.indexed)
                  Tab(
                    height: 72,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 12,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (layer.kind != null)
                              Text(
                                layer.kind!,
                                style: text.bodySmall.copyWith(
                                  color: scheme.onSurfaceVariant!,
                                ),
                              ),
                            Text(
                              layer.title,
                              style: text.titleMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        // The flow between layers; the last has none.
                        if (i < layers.length - 1)
                          ExcludeSemantics(
                            child: Icon(
                              StudioIcons.arrowRight,
                              size: 16,
                              color: scheme.onSurfaceVariant!,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            TabBarView(
              children: [
                for (final (i, layer) in layers.indexed)
                  Padding(
                    padding: EdgeInsets.all(card.padding.left),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 16,
                      children: [
                        Styled(
                          style: const StyleProps(maxWidth: Length.ch(68)),
                          child: Text(
                            layer.description,
                            style: text.bodyLarge.copyWith(
                              color: extra.onSurfaceSoft,
                            ),
                          ),
                        ),
                        StudioFlutterCompare(
                          id: id == null ? null : '$id-code-$i',
                          flutterCode: layer.flutterCode,
                          thorCode: layer.thorCode,
                          flutterLabel: flutterLabel,
                          thorLabel: thorLabel,
                          copyButton: copyButton,
                          copyLabel: copyLabel,
                          copiedLabel: copiedLabel,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

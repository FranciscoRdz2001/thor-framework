// ignore_for_file: public_member_api_docs
// The bench of the design: an example frame with a live card on the stage,
// its controls in the side panel and the matching Dart in the Code view.
//
// The whole contract in one file: the controls call methods of one
// `ThorState`, the demo reads its fields, the Code view shows its text.
import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import 'section_frame.dart';

/// How the demo card is filled.
enum CardFill {
  /// The raised surface.
  soft,

  /// The strong action color.
  solid,
}

/// What the panel controls and the demo reads (the example's "view model").
///
/// A continuous value (the radius, the padding) follows the state as a bound
/// length (`radius.px`); the finite one (the fill) as `Watch` variants; the Code view is a text that follows both.
class BenchDemoState extends ThorState {
  final radius = state(20.0);
  final padding = state(24.0);
  final fill = state(CardFill.soft);

  // What the demo reads.
  double radiusPx() => radius.value;
  double paddingPx() => padding.value;

  // What the panel shows next to its bars.
  String radiusText() => '${radius.value.round()} px';
  String paddingText() => '${padding.value.round()} px';

  // What the Code view shows: the Dart that draws the card as it is now.
  String radiusCode() =>
      'borderRadius: BorderRadius.circular(${radius.value.round()}),';
  String paddingCode() => 'padding: EdgeInsets.all(${padding.value.round()}),';
  bool isSolid() => fill.value == CardFill.solid;

  // What the controls call.
  void setRadius(double value) => radius.value = value;
  void setPadding(double value) => padding.value = value;
  void setFill(Set<CardFill> value) =>
      fill.value = value.isEmpty ? CardFill.soft : value.first;
}

/// One top-level instance: the browser boots with it.
final benchDemo = BenchDemoState();

/// The bench section of the gallery.
class BenchSection extends StatelessWidget implements ThorElementWidget {
  /// The section.
  const BenchSection({super.key});

  @override
  Widget build(BuildContext context) => SectionFrame(
    label: 'banco',
    meta: 'escenario, panel y código',
    child: StudioBench(
      title: 'Tarjeta con radio',
      description: 'Cambia el radio, el relleno y el espacio de la tarjeta.',
      replayLabel: 'Repetir',
      stage: const _DemoCard(),
      code: const _DemoCode(),
      panel: StudioBenchPanel(
        groups: [
          StudioBenchGroup(
            label: 'Interruptores',
            children: [
              StudioBenchRow(
                label: 'Relleno',
                child: StudioSegmentedControl<CardFill>(
                  semanticLabel: 'Relleno',
                  selected: const {CardFill.soft},
                  onSelectionChanged: benchDemo.setFill,
                  segments: const [
                    StudioButtonSegment(
                      value: CardFill.soft,
                      label: Text('Suave'),
                    ),
                    StudioButtonSegment(
                      value: CardFill.solid,
                      label: Text('Pleno'),
                    ),
                  ],
                ),
              ),
              // Three labels share one row of equal cells (CSS only; a longer
              // one wraps inside its cell); with no `onSelectionChanged` the
              // browser keeps the choice.
              const StudioBenchRow(
                label: 'Alineación',
                child: StudioSegmentedControl<int>(
                  semanticLabel: 'Alineación',
                  selected: {0},
                  segments: [
                    StudioButtonSegment(value: 0, label: Text('Inicio')),
                    StudioButtonSegment(value: 1, label: Text('Centro')),
                    StudioButtonSegment(value: 2, label: Text('Final')),
                    StudioButtonSegment(value: 3, label: Text('Entre')),
                  ],
                ),
              ),
              // Long labels: the cells wrap onto a second row, never clipped.
              const StudioBenchRow(
                label: 'Campos',
                child: StudioSegmentedControl<int>(
                  semanticLabel: 'Campos',
                  selected: {1},
                  segments: [
                    StudioButtonSegment(value: 0, label: Text('Requerido')),
                    StudioButtonSegment(value: 1, label: Text('Correo')),
                    StudioButtonSegment(value: 2, label: Text('Mín. 8')),
                  ],
                ),
              ),
              // Icons only: each segment is named by its tooltip.
              const StudioBenchRow(
                label: 'Vista',
                child: StudioSegmentedControl<int>(
                  semanticLabel: 'Vista',
                  selected: {0},
                  segments: [
                    StudioButtonSegment(
                      value: 0,
                      icon: Icon(StudioIcons.menu, size: 16),
                      tooltip: 'Lista',
                    ),
                    StudioButtonSegment(
                      value: 1,
                      icon: Icon(StudioIcons.layoutGrid, size: 16),
                      tooltip: 'Cuadrícula',
                    ),
                  ],
                ),
              ),
            ],
          ),
          StudioBenchGroup(
            label: 'Niveles',
            children: [
              StudioLevelSlider(
                title: 'Radio',
                label: '20 px',
                value: 20,
                max: 48,
                divisions: 24,
                onChanged: benchDemo.setRadius,
                valueText: benchDemo.radiusText,
              ),
              StudioLevelSlider(
                title: 'Espacio',
                label: '24 px',
                value: 24,
                min: 8,
                max: 48,
                divisions: 20,
                onChanged: benchDemo.setPadding,
                valueText: benchDemo.paddingText,
              ),
            ],
          ),
        ],
        footer: [
          OutlinedButton.icon(
            href: '#banco',
            icon: const Icon(StudioIcons.link),
            label: const Text('Compartir'),
          ),
          const FilledButton(href: '#', child: Text('Abrir en la guía')),
        ],
      ),
    ),
  );
}

/// The card the controls change. The radius and the padding follow the state
/// (`radiusPx.px`); the fill is one of two precompiled variants.
class _DemoCard extends StatelessWidget implements ThorElementWidget {
  const _DemoCard();

  @override
  Widget build(BuildContext context) => Watch.field(
    benchDemo.fill,
    builder: (CardFill fill) => _Card(fill: fill),
  );
}

class _Card extends StatelessWidget implements ThorElementWidget {
  const _Card({required this.fill});

  final CardFill fill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final solid = fill == CardFill.solid;
    final ink = solid ? scheme.onPrimary : scheme.onSurface;
    final soft = solid ? scheme.onPrimary : scheme.onSurfaceVariant!;
    // The radius and the padding follow the state: no variable to name.
    return Container(
      width: 260,
      padding: EdgeInsetsGeometry.allLength(benchDemo.paddingPx.px),
      decoration: BoxDecoration(
        color: solid ? scheme.primary : scheme.surfaceContainer,
        borderRadius: BorderRadius.circularLength(benchDemo.radiusPx.px),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          const StudioStatusLabel(label: Text('Nuevo')),
          Text(
            'Resumen semanal',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
          Text(
            'Lo que cambió en tu app esta semana.',
            style: TextStyle(fontSize: 14, color: soft),
          ),
        ],
      ),
    );
  }
}

/// The Code view: the Dart of the card as it is now (plain text: a value
/// that moves cannot be highlighted by the server).
class _DemoCode extends StatelessWidget implements ThorElementWidget {
  const _DemoCode();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mono = StudioExtraTextStyles.of(
      context,
    ).codeMedium.copyWith(color: scheme.onSurface);
    // A <pre>: the lines keep their spaces and never wrap, the pane scrolls.
    return Semantics(
      role: SemanticsRole.preformatted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Container(', style: mono),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Watch(benchDemo.paddingCode, style: mono),
                Text('decoration: BoxDecoration(', style: mono),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Watch(benchDemo.radiusCode, style: mono),
                      Watch(
                        benchDemo.isSolid,
                        builder: (solid) => Text(
                          solid
                              ? 'color: scheme.primary,'
                              : 'color: scheme.surfaceContainer,',
                          style: mono,
                        ),
                      ),
                    ],
                  ),
                ),
                Text('),', style: mono),
                Text('child: …,', style: mono),
              ],
            ),
          ),
          Text(')', style: mono),
        ],
      ),
    );
  }
}

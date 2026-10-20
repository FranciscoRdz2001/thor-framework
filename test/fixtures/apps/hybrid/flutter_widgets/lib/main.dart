import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'thor_embed.dart';

/// The Flutter part of `test/fixtures/apps/hybrid`: two widgets a thor page embeds with
/// `FlutterView` — a bar chart and a counter pad. `initialData['view']`
/// says which one a view draws.
void main() {
  runThorEmbed(
    (context, embed) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF4F46E5)),
      home: Material(
        color: Colors.transparent,
        child: switch (embed.map['view']) {
          'chart' => BarChart(embed: embed),
          'counter' => CounterPad(embed: embed),
          final other => Center(child: Text('Vista desconocida: $other')),
        },
      ),
    ),
  );
  // Flutter's semantics tree (DOM nodes screen readers see) on from the
  // start, instead of behind the "enable accessibility" button.
  SemanticsBinding.instance.ensureSemantics();
}

/// Bars from `initialData['values']`; tapping one tells the page.
class BarChart extends StatefulWidget {
  const BarChart({super.key, required this.embed});

  final ThorEmbed embed;

  @override
  State<BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<BarChart> {
  int? _selected;

  List<num> get _values => [
    for (final v in (widget.embed.map['values'] as List? ?? const []))
      if (v is num) v,
  ];

  List<String> get _labels => [
    for (final v in (widget.embed.map['labels'] as List? ?? const [])) '$v',
  ];

  @override
  Widget build(BuildContext context) {
    final values = _values;
    final labels = _labels;
    final max = values.fold<num>(1, (m, v) => v > m ? v : m);
    final scheme = Theme.of(context).colorScheme;
    String label(int i) => i < labels.length ? labels[i] : '$i';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 8,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                label: '${label(i)}: ${values[i]}',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selected = i);
                    widget.embed.send({'bar': label(i), 'value': values[i]});
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${values[i]}'),
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: values[i] / max),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, _) => Container(
                          height: 160 * t,
                          decoration: BoxDecoration(
                            color: _selected == i
                                ? scheme.tertiary
                                : scheme.primary,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(label(i)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A counter that starts at `initialData['start']` and reports each change.
class CounterPad extends StatefulWidget {
  const CounterPad({super.key, required this.embed});

  final ThorEmbed embed;

  @override
  State<CounterPad> createState() => _CounterPadState();
}

class _CounterPadState extends State<CounterPad> {
  late int _count = (widget.embed.map['start'] as num? ?? 0).toInt();

  void _add(int delta) {
    setState(() => _count += delta);
    widget.embed.send({'count': _count});
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        IconButton.filledTonal(
          tooltip: 'Restar',
          onPressed: () => _add(-1),
          icon: const Icon(Icons.remove),
        ),
        Text('$_count', style: Theme.of(context).textTheme.displaySmall),
        IconButton.filled(
          tooltip: 'Sumar',
          onPressed: () => _add(1),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
  );
}

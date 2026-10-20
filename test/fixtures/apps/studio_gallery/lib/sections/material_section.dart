// Flutter's own Material widgets under StudioTheme: no studio wrapper, only
// the theme (`filledButtonTheme`, `chipTheme`, `cardTheme`, the color scheme
// roles…), in the light theme and in the dark one (a scoped `Theme`, so both
// show at once).
import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import 'section_frame.dart';

final _light = StudioTheme.light(fontsPath: 'fonts');
final _dark = StudioTheme.dark(fontsPath: 'fonts');

void _noop() {}

void _noopSelected(bool _) {}

void _noopInt(int? _) {}

/// The section: one stage per theme.
class MaterialSection extends StatelessWidget implements ThorElementWidget {
  /// The section.
  const MaterialSection({super.key});

  @override
  Widget build(BuildContext context) => SectionFrame(
    label: 'widgets de Material con StudioTheme',
    meta: 'sin envoltorios: solo el tema',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        _Stage(theme: _light, name: 'Claro'),
        _Stage(theme: _dark, name: 'Oscuro'),
      ],
    ),
  );
}

class _Stage extends StatelessWidget implements ThorElementWidget {
  const _Stage({required this.theme, required this.name});

  final ThemeData theme;
  final String name;

  @override
  Widget build(BuildContext context) => Theme(
    data: theme,
    child: Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(StudioRadii.inner),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 20,
            children: [
              Text(
                'Tema $name',
                style: text.titleSmall.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(onPressed: _noop, child: Text('Filled')),
                  FilledButton.tonal(onPressed: _noop, child: Text('Tonal')),
                  ElevatedButton(onPressed: _noop, child: Text('Elevated')),
                  OutlinedButton(onPressed: _noop, child: Text('Outlined')),
                  TextButton(onPressed: _noop, child: Text('Text')),
                  FilledButton(onPressed: null, child: Text('Disabled')),
                  IconButton(
                    onPressed: _noop,
                    tooltip: 'Buscar',
                    icon: Icon(StudioIcons.search, size: 18),
                  ),
                ],
              ),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: Text('Buttons'),
                    selected: true,
                    onSelected: _noopSelected,
                  ),
                  FilterChip(
                    label: Text('Inputs'),
                    selected: false,
                    onSelected: _noopSelected,
                  ),
                  ChoiceChip(
                    label: Text('Choice'),
                    selected: false,
                    onSelected: _noopSelected,
                  ),
                  ActionChip(label: Text('Action'), onPressed: _noop),
                  Chip(label: Text('Label')),
                ],
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(StudioSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      Text('Un Card plano', style: text.titleLarge),
                      Text(
                        'Superficie, radio de 28 y filete: el cardTheme del '
                        'estudio, sin una línea de estilo aquí.',
                        style: text.bodyMedium.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const ExpansionTile(
                title: Text('ExpansionTile'),
                children: [Text('El expansionTileTheme pone color y relleno.')],
              ),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ada Lovelace',
                ),
              ),
              Row(
                spacing: 20,
                children: [
                  const Switch(value: true),
                  const Checkbox(value: true),
                  RadioGroup<int>(
                    groupValue: 1,
                    name: 'material-radio-${name.toLowerCase()}',
                    onChanged: _noopInt,
                    child: const Radio<int>(value: 1),
                  ),
                  const Expanded(
                    child: Slider(value: 0.4, semanticLabel: 'Volumen'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

// ignore_for_file: public_member_api_docs
// (each example is named by its region; a doc comment would sit outside
// the code the site shows)
// The live examples of the styles guide (`tema-y-estilos.md`, en:
// `theme-and-styles.md`), in the same format as gallery.dart: each one
// between `// region: <id>` and
// `// endregion`. Free of state: every one works with the browser alone
// (hover, scroll, a container you resize). The `shared` region holds the
// values several examples use: the site adds the ones an example names to
// the code it shows.
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/thor_ui.dart';

// region: shared
// Theme roles, not literal colors: the same code reads well in both themes.
const _ink = ThemeColor.onSurface;
const _muted = ThemeColor.onSurfaceVariant;
const _line = ThemeColor.outlineVariant;
const _accent = ThemeColor.primary;
const _tint = ThemeColor.secondaryContainer;
const _card = ThemeColor.surfaceContainer;
const _mono = TextStyle(
  fontFamily: 'IBM Plex Mono',
  fontFamilyFallback: ['ui-monospace', 'monospace'],
  fontSize: 12,
);
// endregion

// region: units
class UnitBars extends StatelessWidget {
  const UnitBars({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    // 460 px wide, never wider than its parent (a phone), like in Flutter.
    width: 460,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        for (final (label, length) in [
          ('96.px', 96.px),
          ('50.percent', 50.percent),
          ('8.rem', 8.rem),
          ('20.ch', 20.ch),
          ('12.vw', 12.vw),
          (
            'Length.clamp(4.rem, 15.vw, 100.percent)',
            Length.clamp(4.rem, 15.vw, 100.percent),
          ),
        ])
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(label, style: _mono),
              // Min and max width: the bar measures exactly `length`.
              Styled(
                style: StyleProps(minWidth: length, maxWidth: length),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ],
          ),
      ],
    ),
  );
}
// endregion

// region: responsive-card
// Drag the stage's corner: under 440px of its own width the card stacks,
// from 440px on it lays out in a row. It follows its container (the
// LayoutScope), not the window.
class ResponsiveCard extends StatelessWidget {
  const ResponsiveCard({super.key});

  @override
  Widget build(BuildContext context) => LayoutScope(
    child: Container(
      decoration: BoxDecoration(
        color: _card,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Flex(
        direction: Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        layout: const FlexLayout().when(
          container: {
            440: const FlexLayout(
              direction: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.stretch,
            ),
          },
        ),
        children: [
          Styled(
            style: StyleProps(minHeight: 120.px).when(
              container: {440: StyleProps(minWidth: 160.px, maxWidth: 160.px)},
            ),
            child: const Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF818CF8), Color(0xFF4F46E5)],
                ),
              ),
            ),
          ),
          // Flexible, not Expanded: in the stacked layout the column has no
          // fixed height to share, and Expanded would collapse the text.
          const Flexible(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Text(
                    'Cold brew kit',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  Text(
                    'Everything for a clean, sweet coffee at home.',
                    style: TextStyle(color: _muted),
                  ),
                  Text(
                    r'$24.00',
                    style: TextStyle(fontWeight: FontWeight.w600, color: _ink),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
// endregion

// region: sticky-list
// Scroll inside the box: each letter stays on top until the next one
// pushes it out.
// The box scrolls: `focusable` lets the keyboard scroll it too, and the
// region role names it for a screen reader.
class StickyList extends StatelessWidget {
  const StickyList({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    role: SemanticsRole.region,
    focusable: true,
    label: 'Contacts',
    child: Styled(
      style: StyleProps(maxHeight: 220.px, overflowY: Overflow.auto),
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          color: _card,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (letter, names) in const [
              ('A', ['Ada', 'Alan', 'Anita']),
              ('B', ['Barbara', 'Bjarne']),
              ('D', ['Dennis', 'Donald', 'Dorothy']),
              ('G', ['Grace', 'Guido']),
            ]) ...[
              Styled(
                style: const StyleProps(
                  position: BoxPosition.sticky(top: Length.zero),
                  zIndex: 1,
                ),
                child: Container(
                  color: _tint,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: Text(
                    letter,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _accent,
                    ),
                  ),
                ),
              ),
              for (final name in names)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Text(name),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
// endregion

// region: hover-effects
// Hover each tile (or press it on a touch screen, where hover doesn't
// exist): the values change with .when(hover:, pressed:) and Styled's
// duration turns the change into a transition.
class HoverEffects extends StatelessWidget {
  const HoverEffects({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      _Tile(
        'turns',
        const StyleProps(turns: 0).when(
          hover: const StyleProps(turns: -0.02),
          pressed: const StyleProps(turns: -0.02),
        ),
      ),
      _Tile(
        'offset + scale',
        const StyleProps(offset: Offset.zero, scale: 1).when(
          hover: const StyleProps(offset: Offset(0, -6), scale: 1.04),
          pressed: const StyleProps(offset: Offset(0, -6), scale: 1.04),
        ),
      ),
      _Tile(
        'blur',
        const StyleProps(blur: 3).when(
          hover: const StyleProps(blur: 0),
          pressed: const StyleProps(blur: 0),
        ),
      ),
    ],
  );
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.style);

  final String label;
  final StyleProps style;

  @override
  Widget build(BuildContext context) => Styled(
    duration: const Duration(milliseconds: 220),
    style: style,
    child: Container(
      width: 120,
      height: 84,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _card,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: _mono),
    ),
  );
}
// endregion

// region: theme-follows-switch
// The dark switch is a state here because the docs page has one theme; in an
// app it is the system's mode or a ThemeToggle. What matters: the boxes read
// Theme.of(context) and follow, with nothing rebuilt by hand.
class ThemeSwitchViewModel extends ThorState {
  final dark = state(false);

  bool isDark() => dark.value;
  void setDark(bool on) => dark.value = on;
}

final themeSwitch = ThemeSwitchViewModel();

class ThemeSwitchExample extends StatelessWidget {
  const ThemeSwitchExample({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Switch(
            value: false,
            onChanged: themeSwitch.setDark,
            semanticLabel: 'Dark mode',
          ),
          const Text('Dark mode'),
        ],
      ),
      Watch(
        themeSwitch.isDark,
        builder: (dark) => Theme(
          data: ThemeData(
            colorScheme: dark
                ? const ColorScheme.dark()
                : const ColorScheme.light(),
          ),
          child: const _Swatches(),
        ),
      ),
    ],
  );
}

class _Swatches extends StatelessWidget {
  const _Swatches();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 120,
            height: 56,
            alignment: Alignment.center,
            color: scheme.primary,
            child: Text('primary', style: TextStyle(color: scheme.onPrimary)),
          ),
          Text('on the surface', style: TextStyle(color: scheme.onSurface)),
        ],
      ),
    );
  }
}
// endregion

// region: descendants
// HTML no widget builds (rendered markdown, a CMS body): styled by tag,
// scoped to this element.
class ReleaseNotes extends StatelessWidget {
  const ReleaseNotes({super.key});

  @override
  Widget build(BuildContext context) => Styled(
    descendants: {
      'h3': const StyleProps(
        textStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        // Only these two sides: the others keep the browser's.
        margin: EdgeInsetsGeometry.sides(
          top: Length.zero,
          bottom: Length.px(6),
        ),
      ),
      'li + li': const StyleProps(
        margin: EdgeInsetsGeometry.sides(top: Length.px(4)),
      ),
      'p': const StyleProps(
        textStyle: TextStyle(color: _muted, height: 1.6),
        margin: EdgeInsets.only(bottom: 8),
      ),
      'a': const StyleProps(
        textStyle: TextStyle(
          color: ThemeColor.onSurface,
          decoration: TextDecoration.underline,
        ),
      ),
      'code': StyleProps(
        textStyle: _mono,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: _tint,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      'ul': const StyleProps(
        padding: EdgeInsets.only(left: 18),
        margin: EdgeInsets.zero,
      ),
    },
    // 340 px wide, never wider than its parent (a phone), like in Flutter.
    child: const SizedBox(
      width: 340,
      child: html.RawText(
        '<h3>Release notes</h3>'
        '<p>Styles are typed: <code>16.px</code>, '
        '<code>StyleProps</code> and <a href="#">more</a>.</p>'
        '<ul><li>Units on the numbers</li><li>Typed web props</li></ul>',
      ),
    ),
  );
}
// endregion

// region: patterns
// A gradient repeated in tiles: dots and stripes, no image.
class TiledPatterns extends StatelessWidget {
  const TiledPatterns({super.key});

  @override
  Widget build(BuildContext context) => const Row(
    spacing: 12,
    children: [
      _Pattern(
        RadialGradient(
          colors: [Color(0x664F46E5), Color(0x00000000)],
          stops: [0.2, 0.2],
          tile: Size.square(14),
        ),
      ),
      _Pattern(
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x334F46E5),
            Color(0x334F46E5),
            Color(0x00000000),
            Color(0x00000000),
          ],
          stops: [0, 0.5, 0.5, 1],
          tile: Size.square(12),
        ),
      ),
    ],
  );
}

class _Pattern extends StatelessWidget {
  const _Pattern(this.gradient);

  final Gradient gradient;

  @override
  Widget build(BuildContext context) => Container(
    width: 140,
    height: 90,
    decoration: BoxDecoration(
      gradient: gradient,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(12),
    ),
  );
}

// endregion

// region: component-themes
// One place for the look of each widget kind: no widget below repeats it.
final _theme = ThemeData(
  cardTheme: const CardThemeData(
    color: _tint,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      side: BorderSide(color: _line),
    ),
  ),
  chipTheme: const ChipThemeData(
    backgroundColor: _card,
    shape: StadiumBorder(),
    side: BorderSide(color: _line),
  ),
  filledButtonTheme: const FilledButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(_accent),
      foregroundColor: WidgetStatePropertyAll(ThemeColor.onPrimary),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    ),
  ),
);

class ComponentThemes extends StatelessWidget {
  const ComponentThemes({super.key});

  @override
  Widget build(BuildContext context) => Theme.provide(
    data: _theme,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            const Text('Cold brew', style: TextStyle(color: _ink)),
            const Row(
              spacing: 8,
              children: [
                Chip(label: Text('1 l')),
                Chip(label: Text('Oat')),
              ],
            ),
            FilledButton(onPressed: () {}, child: const Text('Add')),
            // The widget's own parameter wins over the theme.
            const Chip(
              label: Text('Sold out'),
              backgroundColor: ThemeColor.surfaceContainerHighest,
            ),
          ],
        ),
      ),
    ),
  );
}

// endregion

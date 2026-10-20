// ignore_for_file: public_member_api_docs
// (each example is named by its region; a doc comment would sit outside
// the code the site shows)
// The live examples of the layout guide (`layout.md`), in the same format
// as gallery.dart: each one between `// region: <id>` and `// endregion`.
// Free of state: every one works with the browser alone. The `shared`
// region holds the values several examples use: the site adds the ones an
// example names to the code it shows.
import 'package:thor_ui/thor_ui.dart';

// region: shared
// Theme roles, not literal colors: the same code reads well in both themes.
const _brand = ThemeColor.primary;
const _brandSoft = ThemeColor.secondaryContainer;
const _stroke = ThemeColor.outlineVariant;
const _subtle = ThemeColor.onSurfaceVariant;
// endregion

// region: layout-sizes
class Sizes extends StatelessWidget {
  const Sizes({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 300,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(border: Border.all(color: _stroke)),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        // Exact size.
        SizedBox(width: 120, height: 32, child: _Fill('SizedBox 120')),
        // Size, padding and color in one widget.
        Container(
          width: 200,
          padding: EdgeInsets.all(8),
          color: _brandSoft,
          child: Text('Container 200'),
        ),
        // At least 160 wide, at most 260: grows with its text.
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: 160, maxWidth: 260),
          child: _Fill('ConstrainedBox: 160 to 260, with a long text'),
        ),
        // Half of the parent's width.
        FractionallySizedBox(
          widthFactor: 0.5,
          child: _Fill('50% of the parent'),
        ),
      ],
    ),
  );
}

class _Fill extends StatelessWidget {
  const _Fill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    color: _brandSoft,
    child: Text(label),
  );
}
// endregion

// region: layout-screen
// Resize the window. The bar fills its parent but never passes 20 % of
// the window's width (nor goes under 120); the box is at least a quarter
// of the window's height.
class ScreenSizes extends StatelessWidget {
  const ScreenSizes({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 340,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Styled(
          style: StyleProps(maxWidth: Length.clamp(120.px, 20.vw, 100.percent)),
          child: const SizedBox(
            width: double.infinity,
            height: 24,
            child: ColoredBox(color: _brand),
          ),
        ),
        Styled(
          style: StyleProps(minHeight: 25.dvh),
          child: const Container(
            width: 160,
            padding: EdgeInsets.all(8),
            color: _brandSoft,
            child: Text('25% of the window height'),
          ),
        ),
      ],
    ),
  );
}
// endregion

// region: layout-grid-extent
// GridView.extent counts the columns like Flutter: as many as fit the largest
// cell. Drag the corner of the box: 2 columns at 240 px, 3 at 440, 5 at 640.
class ExtentGrid extends StatelessWidget {
  const ExtentGrid({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 168,
    child: GridView.extent(
      maxCrossAxisExtent: 140,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.5,
      children: [for (var i = 1; i <= 10; i++) _ExtentCell('Cell $i')],
    ),
  );
}

class _ExtentCell extends StatelessWidget {
  const _ExtentCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _brandSoft,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(label),
  );
}
// endregion

// region: layout-scroll
// A scroll view needs a size on its axis: 140 high for the list, the
// parent's width for the row of cards.
class ScrollViews extends StatelessWidget {
  const ScrollViews({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 300,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Container(
          height: 140,
          decoration: BoxDecoration(border: Border.all(color: _stroke)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 1; i <= 12; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text('Order #$i'),
                  ),
              ],
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 8,
            children: [
              for (var i = 1; i <= 8; i++)
                Container(
                  width: 96,
                  height: 64,
                  alignment: Alignment.center,
                  color: _brandSoft,
                  child: Text('Card $i'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
// endregion

// region: layout-responsive
// Resize the window: a column on a phone, a row from medium (600 px) up; the
// padding grows too, and the note only shows from medium.
class ResponsiveProfile extends StatelessWidget {
  const ResponsiveProfile({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 480,
    child: Container(
      padding: const EdgeInsets.all(12).when(medium: const EdgeInsets.all(24)),
      decoration: BoxDecoration(border: Border.all(color: _stroke)),
      child: Flex(
        direction: Axis.vertical,
        spacing: 12,
        layout: const FlexLayout().when(
          medium: const FlexLayout(direction: Axis.horizontal),
        ),
        children: [
          const Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _brandSoft,
              shape: BoxShape.circle,
            ),
          ),
          const Text(
            'Ana Torres',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const ResponsiveVisibility(
            visibleFrom: WindowSizeClass.medium,
            child: Text(
              'Only on wide screens',
              style: TextStyle(color: _subtle),
            ),
          ),
        ],
      ),
    ),
  );
}

// endregion

// ignore_for_file: public_member_api_docs
// (each example is named by its region; a doc comment would sit outside
// the code the site shows)
// The icon catalog (docs/guia/es/componentes-contenido.md#icon). Each example sits between
// `// region: <id>` and `// endregion`: the site shows that code and renders
// the same widget on the page.
import 'package:thor_ui/thor_ui.dart';

// region: cat-icons
const _icons = <(String, IconData)>[
  ('add', Icons.add),
  ('close', Icons.close),
  ('check', Icons.check),
  ('edit', Icons.edit),
  ('delete', Icons.delete),
  ('search', Icons.search),
  ('menu', Icons.menu),
  ('settings', Icons.settings),
  ('home', Icons.home),
  ('person', Icons.person),
  ('favorite', Icons.favorite),
  ('share', Icons.share),
  ('arrow_back', Icons.arrow_back),
  ('arrow_forward', Icons.arrow_forward),
  ('more_vert', Icons.more_vert),
  ('notifications', Icons.notifications),
  ('lock', Icons.lock),
  ('visibility', Icons.visibility),
  ('info', Icons.info),
  ('warning', Icons.warning),
];

class IconsDemo extends StatelessWidget {
  const IconsDemo({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    alignment: WrapAlignment.center,
    children: [
      for (final (name, icon) in _icons)
        SizedBox(
          width: 96,
          child: Column(
            spacing: 4,
            children: [
              // Decorative: the name under it says what it is.
              Icon(icon, size: 28),
              Text(name, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
    ],
  );
}
// endregion

// region: cat-icon-variants
class IconVariantsDemo extends StatelessWidget {
  const IconVariantsDemo({super.key});

  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: 24,
    runSpacing: 12,
    alignment: WrapAlignment.center,
    children: [
      Icon(Icons.home, size: 32),
      Icon(Icons.home_outlined, size: 32),
      Icon(Icons.home_rounded, size: 32),
      Icon(Icons.home_sharp, size: 32),
      // Names the icon for a screen reader.
      Icon(Icons.star, size: 32, semanticLabel: 'Featured'),
      Icon(Icons.favorite, size: 32, color: Color(0xFFE11D48)),
    ],
  );
}

// endregion

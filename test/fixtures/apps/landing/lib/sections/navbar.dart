import 'package:thor_ui/thor_ui.dart';

import '../icons.dart' as icons;
import '../theme.dart';
import '../ui.dart';

const _routes = [
  ('#testimonials', 'Testimonials'),
  ('#team', 'Team'),
  ('#contact', 'Contact'),
  ('#faq', 'FAQ'),
];

const _features = [
  ('Widgets to HTML', 'Write Flutter-style widgets and ship semantic HTML.'),
  (
    'Generated CSS',
    'Styles are compiled on the server into small, shared classes.',
  ),
  (
    'Native First',
    'Menus, dialogs and drawers built on native browser elements.',
  ),
];

const _drawerLink = ButtonStyle(
  foregroundColor: WidgetStatePropertyAll(foreground),
  overlayColor: WidgetStatePropertyAll(muted),
  padding: WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  ),
  minimumSize: WidgetStatePropertyAll(Size.fromHeight(40)),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
  ),
  textStyle: WidgetStatePropertyAll(
    TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w500),
  ),
  alignment: Alignment.centerLeft,
);

const _repo = 'https://example.com/thor-starter';

/// The floating, sticky header: logo, the "Features" dropdown and links on
/// desktop, a side drawer on mobile.
class Navbar extends StatelessWidget implements ThorElementWidget {
  const Navbar({super.key});

  @override
  Widget build(BuildContext context) => Styled(
    classes: const ['site-header'],
    child: Styled(
      style: const StyleProps().when(
        medium: const StyleProps(widthFactor: 0.7),
        expanded: const StyleProps(widthFactor: 0.75),
      ),
      child: FractionallySizedBox(
        widthFactor: 0.9,
        child: Semantics(
          role: SemanticsRole.header,
          child: Container(
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(maxWidth: 1280),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
              boxShadow: const [
                BoxShadow(color: headerGlow, blurRadius: 5, inset: true),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Logo(),
                const ResponsiveVisibility(
                  hiddenFrom: WindowSizeClass.expanded,
                  child: _MobileMenu(),
                ),
                ResponsiveVisibility(
                  visibleFrom: WindowSizeClass.expanded,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      const _FeaturesMenu(),
                      for (final (href, label) in _routes)
                        TextButton(
                          href: href,
                          onPressed: null,
                          style: ghostButton,
                          child: Text(label),
                        ),
                    ],
                  ),
                ),
                const ResponsiveVisibility(
                  visibleFrom: WindowSizeClass.expanded,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      themeToggle,
                      TextButton(
                        href: _repo,
                        onPressed: null,
                        style: ButtonStyle(
                          foregroundColor: WidgetStatePropertyAll(foreground),
                          overlayColor: WidgetStatePropertyAll(muted),
                          padding: WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 12),
                          ),
                          minimumSize: WidgetStatePropertyAll(
                            Size.fromHeight(36),
                          ),
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        child: Icon(
                          icons.github,
                          size: 16,
                          semanticLabel: 'View the source',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// `DropdownMenu` with a picture and three feature items (600px wide).
class _FeaturesMenu extends StatelessWidget implements ThorElementWidget {
  const _FeaturesMenu();

  @override
  Widget build(BuildContext context) => Popover(
    id: 'features-menu',
    width: 600,
    style: const ButtonStyle(
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      minimumSize: WidgetStatePropertyAll(Size(0, 40)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    decoration: const BoxDecoration(
      color: card,
      border: Border.fromBorderSide(BorderSide(color: border)),
      borderRadius: BorderRadius.all(Radius.circular(6)),
      boxShadow: [
        BoxShadow(
          color: Color(0x1A000000),
          offset: Offset(0, 4),
          blurRadius: 6,
          spreadRadius: -1,
        ),
        BoxShadow(
          color: Color(0x1A000000),
          offset: Offset(0, 2),
          blurRadius: 4,
          spreadRadius: -2,
        ),
      ],
    ),
    trigger: const Text('Features'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Grid(
        layout: const GridLayout(columns: 2, gap: 20),
        children: [
          const ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(6)),
            child: Image.asset(
              'images/menu-art.jpg',
              semanticLabel: 'Abstract waves',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Column(
            spacing: 8,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (title, description) in _features)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0x00000000).when(hover: muted),
                    borderRadius: const BorderRadius.all(Radius.circular(6)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1,
                            fontWeight: FontWeight.w600,
                            color: foreground,
                          ),
                        ),
                      ),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ThemeText.bodySmall.copyWith(
                          color: mutedForeground,
                        ),
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

/// The menu icon and the `Sheet` it opens (a start-side `Drawer`).
class _MobileMenu extends StatelessWidget implements ThorElementWidget {
  const _MobileMenu();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      DialogTrigger(
        id: 'nav-drawer',
        child: TextButton(
          onPressed: () {},
          style: const ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(foreground),
            padding: WidgetStatePropertyAll(EdgeInsets.zero),
            minimumSize: WidgetStatePropertyAll(Size.square(24)),
          ),
          child: const Icon(icons.menu, semanticLabel: 'Open menu'),
        ),
      ),
      Drawer(
        id: 'nav-drawer',
        width: 384,
        backgroundColor: card,
        label: 'Menu',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 0, 16),
                  child: Logo(),
                ),
                Column(
                  spacing: 8,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (href, label) in _routes)
                      TextButton(
                        href: href,
                        onPressed: null,
                        style: _drawerLink,
                        child: Text(label),
                      ),
                  ],
                ),
              ],
            ),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Divider(height: 1, color: border),
                ),
                themeToggle,
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

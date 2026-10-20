import 'package:thor_ui/thor_ui.dart';

import '../icons.dart' as icons;
import '../theme.dart';
import '../ui.dart';

class Benefits extends StatelessWidget implements ThorElementWidget {
  const Benefits({super.key});

  static const _benefits = [
    (
      icons.blocks,
      'Familiar Widgets',
      'Rows, columns, cards and themes with the API you already know, '
          'rendered as semantic HTML.',
    ),
    (
      icons.chartLine,
      'Faster Pages',
      'Styles are generated on the server, so the browser gets small, '
          'cacheable CSS.',
    ),
    (
      icons.wallet,
      'Lower Costs',
      'Static pages deploy anywhere. No client framework to download '
          'before the first paint.',
    ),
    (
      icons.sparkle,
      'Quick Experiments',
      'Change a widget, reload the page and compare. Try a new idea in '
          'minutes.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Section(
    id: 'benefits',
    children: [
      Grid(
        // `lg:grid-cols-2 lg:gap-24`
        layout: const GridLayout().when(
          expanded: const GridLayout(columns: 2, gap: 96),
        ),
        alignItems: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(
                eyebrow: 'Benefits',
                title: 'Built for Speed',
                center: false,
                bottom: 0,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Text(
                  'Thor Starter turns the widgets you write into plain HTML '
                  'and CSS, so your pages are light, accessible and fast on '
                  'every device.',
                  style: ThemeText.titleLarge.copyWith(color: mutedForeground),
                ),
              ),
            ],
          ),
          Grid(
            layout: const GridLayout(
              gap: 16,
            ).when(expanded: const GridLayout(columns: 2)),
            children: [
              for (final (i, (icon, title, description)) in _benefits.indexed)
                // Hovering the card lifts it to the page color and
                // darkens its number.
                HoverGroup(
                  child: ShadCard(
                    color: surface.when(hover: background),
                    duration: const Duration(milliseconds: 150),
                    children: [
                      CardHeader(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: Icon(icon, size: 32, color: primary),
                              ),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 150),
                                style:
                                    TextStyle(
                                      color: mutedForeground.withValues(
                                        alpha: 0.15,
                                      ),
                                    ).when(
                                      groupHover: TextStyle(
                                        color: mutedForeground.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                child: Text(
                                  '0${i + 1}',
                                  style: text(48, weight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          CardTitle(title),
                        ],
                      ),
                      Padding(
                        padding: cardBody,
                        child: Text(
                          description,
                          style: const TextStyle(color: mutedForeground),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    ],
  );
}

class Features extends StatelessWidget implements ThorElementWidget {
  const Features({super.key});

  static const _features = [
    (
      icons.tabletSmartphone,
      'Responsive Layouts',
      'One widget tree for phones, tablets and desktops, with breakpoints '
          'in CSS.',
    ),
    (
      icons.badgeCheck,
      'Accessible by Default',
      'Native elements, real headings and labels that screen readers '
          'understand.',
    ),
    (
      icons.goal,
      'Typed Routes',
      'Pages and links are checked by the compiler, not discovered at '
          'runtime.',
    ),
    (
      icons.pictureInPicture,
      'Responsive Images',
      'The build writes WebP variants and the page lists them, so each '
          'device downloads the right size.',
    ),
    (
      icons.mousePointerClick,
      'Native Interactions',
      'Dialogs, drawers, menus and accordions that work without '
          'JavaScript.',
    ),
    (
      icons.newspaper,
      'Light and Dark',
      'A theme switch built on a checkbox and CSS variables, remembered '
          'across visits.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Section(
    id: 'features',
    children: [
      const SectionHeading(
        eyebrow: 'Features',
        title: 'Everything a Page Needs',
        subtitle:
            'The building blocks of a modern site, rendered on the server and '
            'enhanced in the browser only where it helps.',
      ),
      Grid(
        layout: const GridLayout(gap: 16).when(
          medium: const GridLayout(columns: 2),
          expanded: const GridLayout(columns: 3),
        ),
        children: [
          for (final (icon, title, description) in _features)
            ShadCard(
              color: background,
              bordered: false,
              shadow: false,
              children: [
                CardHeader(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.1),
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(icon, color: primary),
                    ),
                    CardTitle(title),
                  ],
                ),
                Padding(
                  padding: cardBody,
                  child: Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: mutedForeground),
                  ),
                ),
              ],
            ),
        ],
      ),
    ],
  );
}

class Services extends StatelessWidget implements ThorElementWidget {
  const Services({super.key});

  static const _services = [
    (
      'Static Export',
      'Publish the whole site as files on any static host.',
      false,
    ),
    (
      'Server Rendering',
      'Render pages per request with sessions, forms and cached data.',
      false,
    ),
    ('Form Handling', 'Validate and submit forms without client code.', false),
    ('Performance Reports', 'Measure every page on every build.', true),
  ];

  @override
  Widget build(BuildContext context) => Section(
    id: 'services',
    children: [
      const SectionHeading(
        eyebrow: 'Services',
        title: 'Ship With Confidence',
        subtitle:
            'From the first page to a busy production site, Thor Starter '
            'covers the path from code to users.',
      ),
      Center(
        child: Styled(
          style: const StyleProps().when(
            expanded: const StyleProps(widthFactor: 0.6),
          ),
          child: Grid(
            layout: const GridLayout(
              gap: 16,
            ).when(medium: const GridLayout(columns: 2)),
            children: [
              for (final (title, description, pro) in _services)
                Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    ShadCard(
                      color: surfaceStrong,
                      children: [
                        CardHeader(
                          children: [
                            CardTitle(title),
                            CardDescription(description),
                          ],
                        ),
                      ],
                    ),
                    if (pro)
                      const Positioned(
                        top: -8,
                        right: -12,
                        child: ShadBadge(
                          'PRO',
                          variant: BadgeVariant.secondary,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

class HowItWorks extends StatelessWidget implements ThorElementWidget {
  const HowItWorks({super.key});

  static const _steps = [
    (
      'Create',
      'Start a New Project',
      'Run one command and get a working site with a page, a layout and '
          'a theme.',
      'images/step-1.png',
    ),
    (
      'Build',
      'Compose Your Pages',
      'Write widgets, add state where the page needs it and watch the '
          'browser reload on every save.',
      'images/step-2.png',
    ),
    (
      'Test',
      'Check Every Change',
      'Render pages in tests and compare their HTML before anything '
          'ships.',
      'images/step-3.png',
    ),
    (
      'Ship',
      'Deploy Anywhere',
      'Build once and publish a static site or a small server binary.',
      'images/step-4.png',
    ),
  ];

  @override
  Widget build(BuildContext context) => Section(
    children: [
      const SectionHeading(
        eyebrow: 'How It Works',
        title: 'Step-by-Step Process',
        gap: 0,
      ),
      Center(
        child: Styled(
          style: const StyleProps().when(
            expanded: const StyleProps(widthFactor: 0.8),
          ),
          child: Column(
            spacing: 32,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, (badge, title, description, image))
                  in _steps.indexed)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The blurred blob behind each row, on alternating sides.
                    Positioned(
                      top: 0,
                      left: i.isOdd ? 0 : null,
                      right: i.isOdd ? null : 0,
                      child: Styled(
                        classes: const ['blob'],
                        child: Container(
                          constraints:
                              const BoxConstraints.tightFor(
                                width: 176,
                                height: 288,
                              ).when(
                                expanded: const BoxConstraints.tightFor(
                                  width: 256,
                                  height: 320,
                                ),
                              ),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      textDirection: i.isOdd
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CardHeader(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Row(
                                      textDirection: TextDirection.ltr,
                                      children: [ShadBadge(badge)],
                                    ),
                                  ),
                                  CardTitle(title),
                                ],
                              ),
                              FractionallySizedBox(
                                widthFactor: 0.8,
                                child: Padding(
                                  padding: cardBody,
                                  child: Text(
                                    description,
                                    style: const TextStyle(
                                      color: mutedForeground,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints.tightFor(width: 150)
                              .when(
                                medium: const BoxConstraints.tightFor(
                                  width: 250,
                                ),
                                expanded: const BoxConstraints.tightFor(
                                  width: 300,
                                ),
                              ),
                          child: Transform.flip(
                            flipX: true,
                            child: Image.asset(
                              image,
                              width: 150,
                              semanticLabel: 'Image describing $title',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

// ignore_for_file: thor_lints/avoid_raw_css
// (moving to typed values with theme.dart)
import 'package:thor_ui/thor_ui.dart';

import '../icons.dart' as icons;
import '../theme.dart';
import '../ui.dart';
import 'hero.dart' show GradientSpan;

class Testimonials extends StatelessWidget implements ThorElementWidget {
  const Testimonials({super.key});

  static const _reviews = [
    (
      'images/avatar-1.jpg',
      'Iris Vance',
      'Frontend Developer',
      'We moved our marketing site to Thor Starter in a weekend. The pages '
          'are plain HTML and CSS, and they load before the coffee is '
          'ready.',
    ),
    (
      'images/avatar-2.jpg',
      'Jonas Weber',
      'Mobile Developer',
      'I already knew the widget API, so the web felt familiar from day '
          'one. Rows, columns and themes just work.',
    ),
    (
      'images/avatar-3.jpg',
      'Kara Mensah',
      'Full Stack Developer',
      'The dark mode switch, the drawer and the dropdown work without a '
          'single line of client code. That alone sold the team.',
    ),
    (
      'images/avatar-4.jpg',
      'Liam Foster',
      'UI/UX Designer',
      'The generated CSS is small and predictable. Handing designs over '
          'to engineering has never been this smooth.',
    ),
    (
      'images/avatar-5.jpg',
      'Mei Tanaka',
      'Web Developer',
      'Responsive images, lazy sections and anchors that land exactly '
          'where they should. Our page scores are the best they have been.',
    ),
    (
      'images/avatar-6.jpg',
      'Noah Price',
      'Software Engineer',
      'Thor Starter let us launch our product page in record time, and '
          'the type checker caught every typo on the way.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Section(
    id: 'testimonials',
    children: [
      const SectionHeading(
        eyebrow: 'Testimonials',
        title: 'What Developers Say',
      ),
      // web: a native carousel: scroll snap, swipe/trackpad and the
      // browser's own previous/next buttons.
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Styled(
            style: const StyleProps().when(
              medium: const StyleProps(widthFactor: 0.9),
            ),
            child: FractionallySizedBox(
              widthFactor: 0.8,
              child: CarouselView(
                label: 'Testimonials',
                arrowPosition: CarouselArrowPosition.outside,
                layout: const CarouselLayout(itemsPerView: 1).when(
                  medium: const CarouselLayout(itemsPerView: 2),
                  expanded: const CarouselLayout(itemsPerView: 3),
                ),
                children: [
                  for (final (image, name, role, comment) in _reviews)
                    ShadCard(
                      color: surface,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 24),
                                    child: Row(
                                      spacing: 4,
                                      children: [
                                        for (var i = 0; i < 5; i++)
                                          const Icon(
                                            icons.starFilled,
                                            size: 16,
                                            color: primary,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 24),
                                    child: Text('"$comment"'),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.only(top: 24),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: border),
                                  ),
                                ),
                                child: Row(
                                  spacing: 16,
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundImage: image,
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CardTitle(name, size: 18),
                                        CardDescription(role),
                                      ],
                                    ),
                                  ],
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
          ),
        ),
      ),
    ],
  );
}

enum _Social {
  linkedIn(icons.linkedIn, 'LinkedIn'),
  github(icons.github, 'Github'),
  x(icons.xLogo, 'X');

  const _Social(this.icon, this.label);

  final IconData icon;
  final String label;
}

// Fictional people: the links go to each network's home page.
const _linkedIn = (_Social.linkedIn, 'https://www.linkedin.com/');
const _github = (_Social.github, 'https://github.com/');
const _x = (_Social.x, 'https://x.com/');

class Team extends StatelessWidget implements ThorElementWidget {
  const Team({super.key});

  static const _team = [
    (
      'images/team-1.jpg',
      'Ana',
      'Ortega',
      ['Product Designer', 'Design System Lead'],
      [_linkedIn, _github, _x],
    ),
    (
      'images/team-2.jpg',
      'Ben',
      'Okafor',
      ['Frontend Engineer'],
      [_linkedIn, _x],
    ),
    (
      'images/team-3.jpg',
      'Chloe',
      'Park',
      ['Backend Engineer', 'API Gardener'],
      [_linkedIn, _github],
    ),
    (
      'images/team-4.jpg',
      'Diego',
      'Ruiz',
      ['Platform Engineer', 'Build Pipeline Keeper'],
      [_linkedIn, _github, _x],
    ),
    (
      'images/team-5.jpg',
      'Elena',
      'Novak',
      ['Developer Advocate'],
      [_linkedIn],
    ),
    (
      'images/team-6.jpg',
      'Farid',
      'Haddad',
      ['Data Engineer', 'Dashboard Wrangler'],
      [_linkedIn, _github],
    ),
    (
      'images/team-7.jpg',
      'Grace',
      'Lindqvist',
      ['QA Engineer'],
      [_linkedIn, _github, _x],
    ),
    (
      'images/team-8.jpg',
      'Hugo',
      'Martin',
      ['Engineering Manager', 'Accessibility Champion'],
      [_x],
    ),
  ];

  @override
  Widget build(BuildContext context) => Section(
    id: 'team',
    padding: 64,
    smPadding: 96,
    maxWidth: 1280,
    children: [
      Padding(
        padding: EdgeInsets.zero.when(
          expanded: const EdgeInsets.symmetric(vertical: 32),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeading(
              eyebrow: 'Team',
              title: 'Meet the Team',
              gap: 0,
              bottom: 48,
            ),
            Grid(
              layout: const GridLayout(gap: 24).when(
                medium: const GridLayout(columns: 2),
                expanded: const GridLayout(columns: 3, gap: 32),
                large: const GridLayout(columns: 4),
              ),
              children: [
                for (final (image, first, last, positions, socials) in _team)
                  HoverGroup(
                    child: ShadCard(
                      color: surfaceStrong,
                      clip: true,
                      children: [
                        ClipRRect(
                          child: AspectRatio(
                            aspectRatio: 1,
                            // Grayscale photo that colors in and zooms while the card is hovered.
                            child: Styled(
                              style: const StyleProps().when(
                                groupHover: const StyleProps(
                                  scale: 1.05,
                                  raw: {'filter': 'saturate(1)'},
                                ),
                              ),
                              duration: const Duration(milliseconds: 300),
                              child: Styled(
                                style: const StyleProps(
                                  raw: {'filter': 'saturate(0)'},
                                ),
                                child: Image.asset(
                                  image,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  semanticLabel: '$first $last',
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Semantics(
                            headingLevel: 3,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: '$first '),
                                  TextSpan(
                                    text: last,
                                    style: const TextStyle(color: primary),
                                  ),
                                ],
                              ),
                              style: const TextStyle(
                                fontSize: 24,
                                height: 1,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.6,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final (i, p) in positions.indexed)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    i < positions.length - 1 ? '$p,' : p,
                                    style: const TextStyle(
                                      color: mutedForeground,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: Row(
                            spacing: 16,
                            children: [
                              for (final (social, url) in socials)
                                Styled(
                                  style: const StyleProps().when(
                                    hover: const StyleProps(opacity: 0.8),
                                  ),
                                  duration: const Duration(milliseconds: 150),
                                  child: Link(
                                    href: RouteUrl(url),
                                    newTab: true,
                                    label: 'Visit our ${social.label} page',
                                    child: Icon(social.icon, size: 20),
                                  ),
                                ),
                            ],
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
    ],
  );
}

class Community extends StatelessWidget implements ThorElementWidget {
  const Community({super.key});

  @override
  Widget build(BuildContext context) => Anchor(
    'community',
    child: Semantics(
      role: SemanticsRole.region,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1, color: border),
            Section(
              padding: 80,
              smPadding: 80,
              role: null,
              children: [
                Center(
                  child: Styled(
                    style: const StyleProps().when(
                      expanded: const StyleProps(widthFactor: 0.6),
                    ),
                    child: Column(
                      children: [
                        const CardHeader(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: Icon(icons.discord, size: 80),
                            ),
                            Semantics(
                              headingLevel: 3,
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: 'Join the '),
                                    GradientSpan('Community'),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                                style: ThemeText.displayMedium,
                              ),
                            ),
                          ],
                        ),
                        Styled(
                          style: const StyleProps().when(
                            expanded: const StyleProps(widthFactor: 0.8),
                          ),
                          child: Padding(
                            padding: cardBody,
                            child: Text(
                              'Ask questions, share what you build and help '
                              'shape what comes next. Everyone is welcome.',
                              textAlign: TextAlign.center,
                              style: ThemeText.titleLarge.copyWith(
                                color: mutedForeground,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: cardBody,
                          child: FilledButton(
                            href: 'https://discord.com/',
                            onPressed: null,
                            style: primaryButton,
                            child: const Text('Join Discord'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 1, color: border),
          ],
        ),
      ),
    ),
  );
}

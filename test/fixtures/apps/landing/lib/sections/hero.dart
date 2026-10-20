import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/thor_ui.dart';

import '../icons.dart' as icons;
import '../theme.dart';
import '../ui.dart';

/// Gradient words inside a headline (`bg-clip-text` from #D247BF to
/// primary). `// web:` Flutter paints this with
/// `TextStyle(foreground: Paint()..shader = …)`; here it is a class of the
/// app stylesheet on a plain inline `<span>`.
class GradientSpan extends InlineSpan {
  const GradientSpan(this.text);

  final String text;

  @override
  Widget toComponent() =>
      html.span(classes: 'gradient-text', [Widget.text(text)]);
}

class HeroSection extends StatelessWidget implements ThorElementWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) => Section(
    padding: 80,
    smPadding: 80,
    children: [
      Padding(
        padding: EdgeInsets.zero.when(
          medium: const EdgeInsets.symmetric(vertical: 128 - 80),
        ),
        child: Column(
          spacing: 32,
          children: [
            _badge(),
            _headline(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Text(
                "Write your pages with Flutter's widget API and ship semantic "
                'HTML with generated CSS. Thor Starter is a fictional product '
                'for this demo page.',
                textAlign: TextAlign.center,
                style: ThemeText.titleLarge.copyWith(color: mutedForeground),
              ),
            ),
            _actions(),
            const Padding(
              padding: EdgeInsets.only(top: 56),
              child: _HeroImage(),
            ),
          ],
        ),
      ),
    ],
  );

  static Widget _badge() => const ShadBadge(
    '',
    variant: BadgeVariant.outline,
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    size: 14,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(padding: EdgeInsets.only(right: 8), child: ShadBadge('New')),
        Text('Version 2.0 is out now!'),
      ],
    ),
  );

  static Widget _headline() => const ConstrainedBox(
    constraints: BoxConstraints(maxWidth: 768),
    child: Semantics(
      headingLevel: 1,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Ship fast web apps with '),
            GradientSpan('Thor Starter'),
          ],
        ),
        textAlign: TextAlign.center,
        style: ThemeText.displayLarge,
      ),
    ),
  );

  /// `w-5/6 md:w-1/4` of the text block.
  static Widget _cta(Widget button) => Styled(
    style: const StyleProps().when(medium: const StyleProps(widthFactor: 0.25)),
    child: FractionallySizedBox(widthFactor: 5 / 6, child: button),
  );

  // The buttons are sized against the text block (768px max).
  static Widget _actions() => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 768),
    child: SizedBox(
      width: double.infinity,
      child: Column(
        spacing: 16,
        children: [
          _cta(
            HoverGroup(
              child: FilledButton(
                href: '#pricing',
                onPressed: null,
                style: primaryButton,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Get Started',
                      style: text(14, weight: FontWeight.w700),
                    ),
                    // The arrow nudges right while the button is hovered.
                    Styled(
                      style: const StyleProps().when(
                        groupHover: const StyleProps(offset: Offset(4, 0)),
                      ),
                      duration: const Duration(milliseconds: 150),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(icons.arrowRight, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _cta(
            TextButton(
              href: '#features',
              onPressed: null,
              style: secondaryButton,
              child: Text(
                'See the features',
                style: text(14, weight: FontWeight.w700),
              ),
            ),
          ),
        ],
        layout: const FlexLayout().when(
          medium: const FlexLayout(
            direction: Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.center,
          ),
        ),
      ),
    ),
  );
}

/// The dashboard screenshot (light/dark variant by theme), its animated
/// glow behind and a fade into the page at the bottom.
class _HeroImage extends StatelessWidget implements ThorElementWidget {
  const _HeroImage();

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned(
        top: -24,
        right: 48,
        child: Styled(
          classes: const ['glow'],
          child: Styled(
            style: const StyleProps().when(
              expanded: const StyleProps(heightFactor: 0.8),
            ),
            child: FractionallySizedBox(
              widthFactor: 0.9,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
          ),
        ),
      ),
      // One screenshot per theme: only the file of the theme showing is
      // downloaded (a <picture> whose dark <source> follows the theme).
      Styled(
        classes: const ['hero-image'],
        child: Container(
          margin: EdgeInsets.zero,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          clipBehavior: Clip.hardEdge,
          // The build makes its WebP widths (web/images/, listed in
          // srcset): a phone downloads the 640px file.
          child: const Image.asset(
            'images/hero-image-light.webp',
            dark: 'images/hero-image-dark.webp',
            // The files are 1250×859: shown at 1200 wide, same ratio.
            width: 1200,
            height: 825,
            lazy: false,
            semanticLabel: 'dashboard of the Thor Starter app',
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          constraints: const BoxConstraints.tightFor(
            height: 80,
          ).when(medium: const BoxConstraints.tightFor(height: 112)),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                background.withValues(alpha: 0),
                background.withValues(alpha: 0.5),
                background,
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class Sponsors extends StatelessWidget implements ThorElementWidget {
  const Sponsors({super.key});

  static const _sponsors = [
    (icons.crown, 'Acmebrand'),
    (icons.vegan, 'Acmelogo'),
    (icons.ghost, 'Acmesponsor'),
    (icons.puzzle, 'Acmeipsum'),
    (icons.squirrel, 'Acme'),
    (icons.cookie, 'Accmee'),
    (icons.drama, 'Acmetech'),
  ];

  @override
  Widget build(BuildContext context) => Anchor(
    'sponsors',
    child: Center(
      child: FractionallySizedBox(
        widthFactor: 0.75,
        child: Semantics(
          role: SemanticsRole.region,
          child: Container(
            padding: const EdgeInsets.only(
              bottom: 96,
            ).when(medium: const EdgeInsets.only(bottom: 128)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Semantics(
                    headingLevel: 2,
                    child: Text(
                      'Our Platinum Sponsors',
                      textAlign: TextAlign.center,
                      style: ThemeText.titleMedium.when(
                        medium: ThemeText.titleLarge,
                      ),
                    ),
                  ),
                ),
                Container(
                  clipBehavior: Clip.hardEdge,
                  child: Styled(
                    classes: const ['marquee'],
                    child: Row(
                      spacing: 48,
                      children: [
                        for (final (icon, name) in _sponsors)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(icon),
                              ),
                              Text(
                                name,
                                softWrap: false,
                                style: text(
                                  20,
                                  weight: FontWeight.w500,
                                ).when(medium: text(24)),
                              ),
                            ],
                          ),
                      ],
                    ),
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

import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/thor_ui.dart';

import '../../../core/content/library.dart';
import '../../../core/i18n/docs_locale.dart';
import 'home_bench.dart';

/// The command that installs `thor`, as the installation page gives it.
const homeInstallCommand =
    'dart pub global activate --source path thor/packages/thor_cli';

/// What Thor is in one line, the two ways in (start, or come from Flutter)
/// and the install line; beside it (below it on a phone) the one live
/// example of the home.
class HomeHero extends StatelessWidget {
  /// The hero.
  const HomeHero({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final extra = StudioExtraColors.of(context);
    String page(String slug) => context.localized(guideBySlug(slug)!.path);
    final title = text.displayLarge.copyWith(color: scheme.onSurface);
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          headingLevel: 1,
          child: Styled(
            style: const StyleProps(textWrap: TextWrap.balance),
            child: Text(
              t.homeHeroTitle,
              // One notch under the display size on a phone, so the line
              // breaks in three, not five.
              style: title.copyWith(fontSize: 36).when(medium: title),
            ),
          ),
        ),
        const SizedBox(height: StudioSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            t.homeHeroLead,
            style: text.titleLarge.copyWith(
              color: extra.onSurfaceSoft,
              fontWeight: FontWeight.w400,
              height: 1.6,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: StudioSpacing.xl),
        Wrap(
          spacing: StudioSpacing.xs,
          runSpacing: StudioSpacing.xs,
          children: [
            FilledButton.icon(
              icon: const Icon(StudioIcons.arrowRight),
              label: Text(t.homeCtaStart),
              href: page('instalacion'),
            ),
            OutlinedButton(
              href: page('desde-flutter'),
              child: Text(t.homeCtaFlutter),
            ),
          ],
        ),
        const SizedBox(height: StudioSpacing.lg),
        const ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 560),
          child: StudioCodeBlock(
            homeInstallCommand,
            language: StudioCodeLanguage.bash,
          ),
        ),
        // The copy button of the install line is the studio's one script.
        const html.script(src: '/scripts/studio-code.js', defer: true),
      ],
    );
    return Container(
      // A soft indigo-to-violet light behind the live example, faded out
      // before the hero's edges.
      decoration: _glow(scheme.accent),
      // 96 above (with the body's 32), 72 below.
      padding:
          const EdgeInsets.only(
            top: StudioSpacing.lg,
            bottom: StudioSpacing.xxl,
          ).when(
            expanded: const EdgeInsets.only(
              top: StudioSpacing.xxl + StudioSpacing.md,
              bottom: StudioSpacing.section,
            ),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: StudioSpacing.xxl,
        layout: const FlexLayout().when(
          expanded: const FlexLayout(
            direction: Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.center,
          ),
        ),
        children: [
          Styled(style: _half, child: words),
          Styled(style: _half, child: const HomeBench()),
        ],
      ),
    );
  }
}

/// The hero's brand light: a radial wash of the accent into its companion
/// violet, transparent well before the box ends, centred on the example
/// beside the words (from 1024 px).
BoxDecoration _glow(Color accent) {
  BoxDecoration at(Alignment center) => BoxDecoration(
    gradient: RadialGradient(
      center: center,
      colors: [
        accent.withOpacity(0.28),
        StudioAccentColors.accentGlow.withOpacity(0.16),
        Colors.transparent,
      ],
      stops: const [0, 0.27, 0.54],
    ),
  );
  // A phone's hero is as wide as its cards: the light would only show as a
  // band between them, so it starts at 1024 px.
  return const BoxDecoration().when(expanded: at(const Alignment(0.5, 0)));
}

/// Each column takes half the row from 1024 px.
final _half = const StyleProps(minWidth: Length.px(0)).when(
  expanded: const StyleProps(
    flex: 1,
    flexBasis: Length.px(0),
    minWidth: Length.px(0),
  ),
);

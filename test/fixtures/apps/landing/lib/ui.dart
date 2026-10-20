// The page's small component kit (card, badge, button, section heading),
// built from thor widgets.
import 'package:thor_ui/thor_ui.dart';

import 'icons.dart' as icons;
import 'theme.dart';

/// Gives the child element a DOM `id` (an in-page `#anchor` target).
class Anchor extends ParentDataWrapper {
  const Anchor(this.id, {super.key, required super.child});

  final String id;

  @override
  WrapData get wrapData => WrapData(attributes: {'id': id});
}

/// Tailwind's `container` (centered, 32px gutters, 1400px max) as a page
/// section with `py-{top} sm:py-{smTop}` vertical padding.
class Section extends StatelessWidget implements ThorElementWidget {
  const Section({
    super.key,
    this.id,
    this.padding = 96,
    this.smPadding = 128,
    this.bottom,
    this.smBottom,
    this.maxWidth,
    this.role = SemanticsRole.region,
    required this.children,
  });

  final String? id;
  final double padding;
  final double smPadding;
  final double? bottom;
  final double? smBottom;

  /// Narrower than the container (`md:w-[700px]`, `max-w-7xl`).
  final double? maxWidth;

  /// What the section is (a `<section>`, the page's `<footer>`…); null for
  /// a plain `<div>`.
  final SemanticsRole? role;
  final List<Widget> children;

  static EdgeInsets _pad(double y, double? b) =>
      EdgeInsets.fromLTRB(32, y, 32, b ?? y);

  @override
  Widget build(BuildContext context) {
    Widget section = Styled(
      classes: const ['container'],
      child: Semantics(
        role: role,
        child: Container(
          padding: _pad(
            padding,
            bottom,
          ).when(medium: _pad(smPadding, smBottom)),
          constraints: BoxConstraints(maxWidth: maxWidth ?? 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
    if (id != null) section = Anchor(id!, child: section);
    return section;
  }
}

/// The eyebrow + title (+ subtitle) block that opens most sections.
class SectionHeading extends StatelessWidget implements ThorElementWidget {
  const SectionHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.center = true,
    this.gap = 16,
    this.bottom = 32,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final bool center;

  /// Space under the title.
  final double gap;

  /// Space under the whole block.
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final align = center ? TextAlign.center : TextAlign.start;
    return Padding(
      padding: EdgeInsets.only(bottom: subtitle == null ? bottom : 0),
      child: Column(
        crossAxisAlignment: center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              headingLevel: 2,
              child: Text(
                eyebrow,
                textAlign: align,
                style: ThemeText.titleMedium.copyWith(
                  color: primary,
                  letterSpacing: 0.9,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: Semantics(
              headingLevel: 2,
              child: Text(
                title,
                textAlign: align,
                style: ThemeText.headlineLarge,
              ),
            ),
          ),
          if (subtitle != null)
            Styled(
              style: const StyleProps().when(
                medium: const StyleProps(widthFactor: 0.5),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottom),
                child: Semantics(
                  headingLevel: 3,
                  child: Text(
                    subtitle!,
                    textAlign: align,
                    style: ThemeText.titleLarge.copyWith(
                      color: mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `Card`: 8px radius, 1px border, `shadow-sm`.
class ShadCard extends StatelessWidget implements ThorElementWidget {
  const ShadCard({
    super.key,
    this.color = card,
    this.bordered = true,
    this.shadow = true,
    this.clip = false,
    this.duration,
    required this.children,
  });

  final Color color;
  final bool bordered;
  final bool shadow;

  /// Whether content is clipped to the rounded corners (an edge-to-edge
  /// image).
  final bool clip;

  /// Transition between [color]'s states (`surface.when(hover: …)`).
  final Duration? duration;
  final List<Widget> children;

  static const _shadowSm = BoxShadow(
    color: Color(0x0D000000),
    offset: Offset(0, 1),
    blurRadius: 2,
  );

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
      border: bordered ? Border.all(color: border) : null,
      boxShadow: shadow ? const [_shadowSm] : null,
    );
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    final clipBehavior = clip ? Clip.hardEdge : Clip.none;
    return duration == null
        ? Container(
            decoration: decoration,
            clipBehavior: clipBehavior,
            child: column,
          )
        : AnimatedContainer(
            duration: duration!,
            decoration: decoration,
            clipBehavior: clipBehavior,
            child: column,
          );
  }
}

/// `CardHeader`: `p-6`, 6px between title and description.
class CardHeader extends StatelessWidget implements ThorElementWidget {
  const CardHeader({
    super.key,
    this.padding = const EdgeInsets.all(24),
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    required this.children,
  });

  final EdgeInsets padding;
  final CrossAxisAlignment crossAxisAlignment;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Column(
      spacing: 6,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    ),
  );
}

/// `CardTitle`: the theme's `headlineSmall` (24px semibold, tight).
class CardTitle extends StatelessWidget implements ThorElementWidget {
  const CardTitle(
    this.data, {
    super.key,
    this.size,
    this.smSize,
    this.textAlign,
  });

  final String data;

  /// A smaller title than the theme's `headlineSmall` (a name, a plan).
  final double? size;

  /// [size] from `WindowSizeClass.medium` up.
  final double? smSize;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Semantics(
    headingLevel: 3,
    child: Text(
      data,
      textAlign: textAlign,
      style: switch (size) {
        null => ThemeText.headlineSmall,
        final s => _sized(
          s,
        ).when(medium: smSize == null ? null : _sized(smSize!)),
      },
    ),
  );
}

// `text-lg` / `text-xl` bring their own 28px line height.
TextStyle _sized(double size) => TextStyle(
  fontSize: size,
  height: 28 / size,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.025 * size,
);

/// `CardDescription`: 14px muted.
class CardDescription extends StatelessWidget implements ThorElementWidget {
  const CardDescription(this.data, {super.key});

  final String data;

  @override
  Widget build(BuildContext context) =>
      Text(data, style: ThemeText.bodySmall.copyWith(color: mutedForeground));
}

/// Card body / footer padding: `p-6 pt-0`.
const cardBody = EdgeInsets.fromLTRB(24, 0, 24, 24);

/// Badge variants.
enum BadgeVariant { primary, secondary, outline }

/// `Badge`: pill, 12px semibold.
class ShadBadge extends StatelessWidget implements ThorElementWidget {
  const ShadBadge(
    this.label, {
    super.key,
    this.variant = BadgeVariant.primary,
    this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    this.size = 12,
  });

  final String label;
  final BadgeVariant variant;

  /// Replaces [label] (a badge inside a badge, like the hero's).
  final Widget? child;
  final EdgeInsets padding;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      BadgeVariant.primary => (primary, primaryForeground),
      BadgeVariant.secondary => (secondary, secondaryForeground),
      BadgeVariant.outline => (null, foreground),
    };
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: variant == BadgeVariant.outline
              ? border
              : const Color(0x00000000),
        ),
      ),
      child: DefaultTextStyle(
        style: text(size, weight: FontWeight.w600, color: fg),
        child: child ?? Text(label),
      ),
    );
  }
}

/// Button sizes: `h-10 px-4`, radius 6, 14px medium.
const _buttonShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(6)),
);
const _buttonText = TextStyle(
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w500,
);

/// `<Button>` (default variant).
final primaryButton = ButtonStyle(
  backgroundColor: const WidgetStatePropertyAll(primary),
  foregroundColor: const WidgetStatePropertyAll(primaryForeground),
  overlayColor: WidgetStatePropertyAll(primary.withValues(alpha: 0.9)),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  ),
  minimumSize: const WidgetStatePropertyAll(Size.fromHeight(40)),
  shape: const WidgetStatePropertyAll(_buttonShape),
  textStyle: const WidgetStatePropertyAll(_buttonText),
);

/// `<Button variant="secondary">`.
final secondaryButton = ButtonStyle(
  backgroundColor: const WidgetStatePropertyAll(secondary),
  foregroundColor: const WidgetStatePropertyAll(secondaryForeground),
  overlayColor: WidgetStatePropertyAll(secondary.withValues(alpha: 0.8)),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  ),
  minimumSize: const WidgetStatePropertyAll(Size.fromHeight(40)),
  shape: const WidgetStatePropertyAll(_buttonShape),
  textStyle: const WidgetStatePropertyAll(_buttonText),
);

/// `<Button variant="ghost">` (the navbar links).
const ghostButton = ButtonStyle(
  foregroundColor: WidgetStatePropertyAll(foreground),
  overlayColor: WidgetStatePropertyAll(muted),
  padding: WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  ),
  minimumSize: WidgetStatePropertyAll(Size.fromHeight(40)),
  shape: WidgetStatePropertyAll(_buttonShape),
  textStyle: WidgetStatePropertyAll(_buttonText),
);

/// `<Button variant="outline" size="icon">`, round (carousel arrows).
const iconButton = ButtonStyle(
  foregroundColor: WidgetStatePropertyAll(foreground),
  overlayColor: WidgetStatePropertyAll(muted),
  padding: WidgetStatePropertyAll(EdgeInsets.zero),
  minimumSize: WidgetStatePropertyAll(Size.square(40)),
  shape: WidgetStatePropertyAll(_buttonShape),
);

/// The brand mark: `ChevronsDown` on a primary gradient tile.
class Logo extends StatelessWidget implements ThorElementWidget {
  const Logo({super.key, this.label = 'Thor Starter', this.size = 18});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => Link(
    href: const RouteUrl('/'),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
            gradient: LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [primary, primary.withValues(alpha: 0.7), primary],
            ),
          ),
          child: const Icon(
            icons.chevronsDown,
            size: 36,
            color: Color(0xFFFFFFFF),
          ),
        ),
        Text(label, style: text(size, weight: FontWeight.w700)),
      ],
    ),
  );
}

/// The sun/moon switch (a label of ThorApp's theme checkbox: no JS).
const themeToggle = ThemeToggle(
  light: Icon(icons.sun, size: 16),
  dark: Icon(icons.moon, size: 16),
);

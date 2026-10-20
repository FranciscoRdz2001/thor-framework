/// The Conduit look with thor widgets: tokens, the page grid, buttons,
/// avatars and tags. Elements also carry the class names of the RealWorld
/// contract (`SELECTORS.md`, e.g. `.article-preview`), which the official
/// test suite uses to find them; the styles come from the widgets.
library;

import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/thor_ui.dart';

/// Brand green.
const brand = Color(0xFF33AA44);

/// Brand green, hovered.
const brandHover = Color(0xFF2B8E3A);

/// Brand green, dark (link hover).
const brandDark = Color(0xFF237630);

/// Destructive actions.
const danger = Color(0xFFB85C5C);

/// Secondary buttons.
const secondary = Color(0xFFCCCCCC);

/// Body text.
const ink = Color(0xFF373A3C);

/// Muted text.
const muted = Color(0xFF999999);

/// Light text (dates).
const light = Color(0xFFBBBBBB);

/// Lighter text (inactive tabs).
const lighter = Color(0xFFAAAAAA);

/// Hairlines.
const hairline = Color(0xFFEEEEEE);

/// White.
const white = Color(0xFFFFFFFF);

/// Near black (logo, headings).
const nearBlack = Color(0xFF222222);

/// The breakpoints of the theme (Bootstrap 4 alpha).
const conduitBreakpoints = Breakpoints(
  medium: 544,
  expanded: 768,
  large: 992,
  extraLarge: 1200,
);

/// The app theme: one instance for every request (its page rules are built
/// once, like a Flutter app's top-level theme).
final conduitTheme = ThemeData(breakpoints: conduitBreakpoints);

/// Adds the contract class names [classes] to [child]'s element.
Widget cls(String classes, Widget child) =>
    Styled(classes: classes.split(' '), child: child);

// Full width up to the max, centered; in a column flex an auto margin would
// size it to its content otherwise (a long code line would widen it).
const _centered = {
  'width': '100%',
  'margin-left': 'auto',
  'margin-right': 'auto',
  'min-width': '0',
};

/// `.container`: centered, 15 px gutters, the theme's max widths.
class PageContainer extends StatelessWidget implements ThorElementWidget {
  /// Wraps [child]; [maxWidth] replaces the breakpoint widths (the article
  /// column is 720 px).
  const PageContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.classes = 'container',
  });

  /// Content.
  final Widget child;

  /// Fixed max width instead of the breakpoint ones.
  final double? maxWidth;

  /// Contract classes.
  final String classes;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: SizedBox(
      width: double.infinity,
      child: Styled(
        classes: classes.split(' '),
        style: maxWidth != null
            ? StyleProps(
                constraints: BoxConstraints(maxWidth: maxWidth!),
                raw: _centered,
              )
            : const StyleProps(raw: _centered).when(
                medium: const StyleProps(
                  constraints: BoxConstraints(maxWidth: 576),
                ),
                expanded: const StyleProps(
                  constraints: BoxConstraints(maxWidth: 720),
                ),
                large: const StyleProps(
                  constraints: BoxConstraints(maxWidth: 940),
                ),
                extraLarge: const StyleProps(
                  constraints: BoxConstraints(maxWidth: 1140),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          // A block: the content takes the container's width.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [child],
          ),
        ),
      ),
    ),
  );
}

/// `.row`: columns that wrap, with 15 px gutters (−15 px outside).
class GridRow extends StatelessWidget implements ThorElementWidget {
  /// Columns ([Col]).
  const GridRow({super.key, required this.children, this.classes = 'row'});

  /// The columns.
  final List<Widget> children;

  /// Contract classes.
  final String classes;

  @override
  Widget build(BuildContext context) => Styled(
    classes: classes.split(' '),
    style: const StyleProps(
      // A negative margin (the gutter pulled outside): Container's margin
      // can't be negative.
      // ignore: thor_lints/widget_props_in_styled
      margin: EdgeInsets.symmetric(horizontal: -15),
    ),
    child: Flex(
      direction: Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.start,
      layout: const FlexLayout(wrap: true),
      children: children,
    ),
  );
}

/// A grid column: [xs] / [md] of 12 (below 768 px a column without [xs]
/// is a plain full-width block, as in the theme), [offset] at `md`.
class Col extends StatelessWidget implements ThorElementWidget {
  /// A column.
  const Col({
    super.key,
    this.xs,
    this.md,
    this.offset = 0,
    required this.child,
  });

  /// Columns out of 12 below `md` (`null`: a plain block).
  final int? xs;

  /// Columns out of 12 from `md`.
  final int? md;

  /// Left offset (columns) from `md`.
  final int offset;

  /// Content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const gutter = EdgeInsets.symmetric(horizontal: 15);
    final base = xs == null
        ? const StyleProps(widthFactor: 1)
        : StyleProps(widthFactor: xs! / 12, padding: gutter);
    return Styled(
      style: base.when(
        expanded: md == null
            ? null
            : StyleProps(
                widthFactor: md! / 12,
                padding: gutter,
                raw: offset == 0
                    ? null
                    : {
                        'margin-left':
                            '${(offset / 12 * 100).toStringAsFixed(5)}%',
                      },
              ),
      ),
      child: child,
    );
  }
}

/// Button variants of the theme.
enum ButtonKind {
  /// `.btn-primary`.
  primary('btn-primary'),

  /// `.btn-outline-primary`.
  outlinePrimary('btn-outline-primary'),

  /// `.btn-secondary` (following).
  secondary('btn-secondary'),

  /// `.btn-outline-secondary`.
  outlineSecondary('btn-outline-secondary'),

  /// `.btn-outline-danger`.
  outlineDanger('btn-outline-danger');

  const ButtonKind(this.className);

  /// Contract class.
  final String className;
}

/// Button sizes of the theme.
enum ButtonSize {
  /// `.btn-sm`.
  small,

  /// `.btn`.
  normal,

  /// `.btn-lg`.
  large,
}

/// The theme's `.btn` for [kind] and [size].
ButtonStyle conduitButton(
  ButtonKind kind, [
  ButtonSize size = ButtonSize.normal,
]) {
  final (padding, fontSize, radius) = switch (size) {
    ButtonSize.small => (
      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      14.0,
      6.0,
    ),
    ButtonSize.normal => (
      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      16.0,
      8.0,
    ),
    ButtonSize.large => (
      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      20.0,
      10.0,
    ),
  };
  final (fg, bg, border, hover, hoverFg) = switch (kind) {
    ButtonKind.primary => (white, brand, brand, brandHover, white),
    ButtonKind.outlinePrimary => (
      brand,
      Colors.transparent,
      brand,
      brand,
      white,
    ),
    ButtonKind.secondary => (
      white,
      secondary,
      secondary,
      const Color(0xFFB3B3B3),
      white,
    ),
    ButtonKind.outlineSecondary => (
      secondary,
      Colors.transparent,
      secondary,
      secondary,
      white,
    ),
    ButtonKind.outlineDanger => (
      danger,
      Colors.transparent,
      danger,
      danger,
      white,
    ),
  };
  return ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(bg),
    foregroundColor: WidgetStatePropertyAll(fg.when(hover: hoverFg)),
    overlayColor: WidgetStatePropertyAll(hover),
    padding: WidgetStatePropertyAll(padding),
    minimumSize: const WidgetStatePropertyAll(Size(0, 0)),
    side: WidgetStatePropertyAll(BorderSide(color: border)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    ),
    textStyle: WidgetStatePropertyAll(
      TextStyle(fontSize: fontSize, height: 1.25, fontWeight: FontWeight.w400),
    ),
  );
}

/// A submit button of the theme (inside a `Form`).
Widget submitButton(
  String label,
  ButtonKind kind, {
  ButtonSize size = ButtonSize.normal,
  Widget? icon,
}) => cls(
  'btn ${kind.className}${size == ButtonSize.large
      ? ' btn-lg'
      : size == ButtonSize.small
      ? ' btn-sm'
      : ''}',
  TextButton(
    buttonType: ButtonType.submit,
    onPressed: _native,
    style: conduitButton(kind, size),
    child: icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [icon, Text(label)],
          ),
  ),
);

// A native submit: its effect is the form post (no engine handler).
void _native() {}

/// An avatar: the user's image or the default one (`default-avatar.svg`).
class Avatar extends StatelessWidget {
  /// [image] of [name], [size] px round.
  const Avatar(
    this.image, {
    super.key,
    required this.name,
    this.size = 32,
    this.classes,
  });

  /// URL (`null` = default).
  final String? image;

  /// Whose (alt text).
  final String name;

  /// Diameter.
  final double size;

  /// Contract classes (`user-img`, `comment-author-img`…).
  final String? classes;

  @override
  Widget build(BuildContext context) => html.img(
    src: (image == null || image!.isEmpty) ? '/default-avatar.svg' : image!,
    alt: name,
    classes: ['avatar', ?classes].join(' '),
    attributes: {
      'width': cssNum(size),
      'height': cssNum(size),
      'style': 'width:${cssNum(size)}px;height:${cssNum(size)}px',
    },
  );
}

/// A tag pill (`.tag-default.tag-pill`), a link when [href] is set.
class TagPill extends StatelessWidget {
  /// Pill for [tag].
  const TagPill(
    this.tag, {
    super.key,
    this.href,
    this.outline = false,
    this.tagName = 'span',
    this.leading,
  });

  /// Tag text.
  final String tag;

  /// Link target (sidebar tags).
  final String? href;

  /// `.tag-outline` (article lists).
  final bool outline;

  /// Element when not a link (`li` in lists).
  final String tagName;

  /// Before the text (the editor's remove icon).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final classes = 'tag-default tag-pill${outline ? ' tag-outline' : ''}';
    final children = [?leading, Widget.text(tag)];
    return href != null
        ? html.a(href: href!, classes: classes, children)
        : Widget.element(tag: tagName, classes: classes, children: children);
  }
}

/// `ul.error-messages`: the API's validation messages.
class ErrorMessages extends StatelessWidget {
  /// Lists [messages] (nothing when empty).
  const ErrorMessages(this.messages, {super.key});

  /// "email is invalid"…
  final List<String> messages;

  @override
  Widget build(BuildContext context) => messages.isEmpty
      ? const SizedBox.shrink()
      : html.ul(classes: 'error-messages', [
          for (final m in messages) html.li([Widget.text(m)]),
        ]);
}

/// "Thu Apr 30 2026", like `Date.toDateString()`.
String dateString(DateTime d) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final l = d.toLocal();
  return '${days[l.weekday - 1]} ${months[l.month - 1]} ${'${l.day}'.padLeft(2, '0')} ${l.year}';
}

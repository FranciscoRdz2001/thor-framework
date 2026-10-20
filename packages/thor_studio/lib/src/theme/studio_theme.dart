import 'package:thor_ui/thor_ui.dart';

import '../tokens/color/studio_accent_colors.dart';
import '../tokens/color/studio_action_colors.dart';
import '../tokens/color/studio_border_colors.dart';
import '../tokens/color/studio_content_colors.dart';
import '../tokens/color/studio_palette.dart';
import '../tokens/color/studio_shadow_colors.dart';
import '../tokens/color/studio_status_colors.dart';
import '../tokens/color/studio_surface_colors.dart';
import '../tokens/motion/studio_durations.dart';
import '../tokens/shape/studio_radii.dart';
import '../tokens/spacing/studio_spacing.dart';
import '../tokens/typography/studio_font_families.dart';
import 'studio_extra_colors.dart';
import 'studio_extra_text_styles.dart';
import 'studio_type_roles.dart';

/// The studio's themes, the one thing an app wires up: the palette as
/// `--t-*` variables, a full Material 3 `ColorScheme` and `TextTheme` built
/// from it, Flutter's component themes (`filledButtonTheme`, `chipTheme`,
/// `cardTheme`…) so the plain Material widgets look studio, the two extension
/// groups for what Material has no role for, the self-hosted fonts, the
/// selection color and the focus ring.
///
/// ```dart
/// final theme = StudioTheme.light();
/// final darkTheme = StudioTheme.dark();
///
/// ThorApp(theme: theme, darkTheme: darkTheme, child: …)
/// ```
///
/// Like Flutter's `theme:` / `darkTheme:`; keep each in a top-level `final`
/// (one instance per app: the page rules are built once).
///
/// `// web:` every role of the scheme is a `ColorToken` that carries its light
/// and its dark value and is published as a CSS variable, so the light and
/// the dark theme have the same roles and the browser swaps them with no
/// rebuild.
abstract final class StudioTheme {
  /// The light theme. [fontsPath] is where the app serves the `.woff2` files
  /// of `thor_studio/fonts/` (the `thor` CLI copies them to `web/fonts/`).
  static ThemeData light({String fontsPath = '/fonts'}) =>
      _build(Brightness.light, fontsPath);

  /// The dark theme: the same roles, fonts and text, with the dark value of
  /// every color token. With `ThorApp(darkTheme:)` it follows the system, and
  /// a `ThemeToggle` switches (and remembers) it with no flash on load.
  static ThemeData dark({String fontsPath = '/fonts'}) =>
      _build(Brightness.dark, fontsPath);

  /// The studio's Material 3 `ColorScheme`, from the studio palette.
  ///
  /// | Role | Token |
  /// |---|---|
  /// | `primary` / `onPrimary` | the action pill (white in dark, ink in light) |
  /// | `primaryContainer` / `onPrimaryContainer` | raised, ink |
  /// | `secondary` / `onSecondary` | the soft ink, the page |
  /// | `secondaryContainer` / `onSecondaryContainer` | the accent tint, ink |
  /// | `tertiary` ... `onTertiaryContainer` | the accent blue family |
  /// | `error` / `onError`, `errorContainer` / `onErrorContainer` | danger |
  /// | `surface` / `onSurface` | the page, the ink |
  /// | `onSurfaceVariant` | the muted ink |
  /// | `surfaceContainerLowest` | the canvas the cards float on |
  /// | `surfaceContainerLow` ... `surfaceContainerHigh` | the card |
  /// | `surfaceContainerHighest` | the raised rows |
  /// | `outline` | the field line (3:1 on every surface) |
  /// | `outlineVariant` | the hairline |
  /// | `inverseSurface` / `onInverseSurface` | the ink, the card |
  ///
  /// Every value is a `ColorToken`, so [brightness] only sets `color-scheme`.
  static ColorScheme colorScheme(Brightness brightness) => ColorScheme(
    brightness: brightness,
    primary: StudioActionColors.action,
    onPrimary: StudioActionColors.onAction,
    primaryContainer: StudioSurfaceColors.raised,
    onPrimaryContainer: StudioContentColors.ink,
    secondary: StudioContentColors.inkSoft,
    onSecondary: StudioSurfaceColors.app,
    // Material's selected states (a rail's indicator, a selected chip) take
    // the accent tint.
    secondaryContainer: StudioAccentColors.accentTint,
    onSecondaryContainer: StudioContentColors.ink,
    tertiary: StudioAccentColors.accent,
    onTertiary: StudioAccentColors.accentInk,
    tertiaryContainer: StudioAccentColors.accentTint,
    onTertiaryContainer: StudioAccentColors.accent,
    error: StudioStatusColors.danger,
    onError: StudioAccentColors.accentInk,
    errorContainer: StudioStatusColors.dangerBg,
    onErrorContainer: StudioStatusColors.danger,
    surface: StudioSurfaceColors.app,
    onSurface: StudioContentColors.ink,
    onSurfaceVariant: StudioContentColors.muted,
    surfaceContainerLowest: StudioSurfaceColors.canvas,
    // Material's own fallbacks for a drawer, a dialog and a tooltip are
    // lavender light values: they take the card and the ink in both themes.
    surfaceContainerLow: StudioSurfaceColors.panel,
    surfaceContainer: StudioSurfaceColors.panel,
    surfaceContainerHigh: StudioSurfaceColors.panel,
    surfaceContainerHighest: StudioSurfaceColors.raised,
    inverseSurface: StudioContentColors.ink,
    onInverseSurface: StudioSurfaceColors.panel,
    inversePrimary: StudioAccentColors.accentTint,
    // Material's `outline` is the border of a control that must be found:
    // the field line, 3:1 against every surface. The hairline is the variant.
    outline: StudioBorderColors.field,
    outlineVariant: StudioBorderColors.line,
  );

  /// The studio's Material 3 `TextTheme`: display to label, in three sizes
  /// each, from the type tokens (`code*` styles are `StudioExtraTextStyles`).
  static TextTheme get textTheme => studioTextTheme();

  static ThemeData _build(Brightness brightness, String fontsPath) {
    final scheme = colorScheme(brightness);
    final text = textTheme;
    const pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(StudioRadii.control)),
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: StudioSpacing.lg);
    const buttonSize = Size(0, 40);
    const field = BorderSide(color: StudioBorderColors.field);
    const card = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(StudioRadii.card)),
    );
    const cardLine = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(StudioRadii.inner)),
      side: BorderSide(color: StudioBorderColors.line),
    );
    const sheet = RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(StudioRadii.card),
      ),
    );
    const small = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(StudioRadii.small)),
    );
    return ThemeData(
      fontFamily: StudioFontFamilies.sans,
      // Each token carries both sides; the theme publishes the one of its
      // brightness (and `light-dark()` when the page has both).
      tokens: StudioPalette.values,
      colorScheme: scheme,
      textTheme: text,
      extensions: const [
        StudioExtraColors.standard,
        StudioExtraTextStyles.standard,
      ],
      fonts: [
        // Variable: every weight in one file, the face of the first screen,
        // fetched with the page.
        FontFace(
          'Inter',
          url: '$fontsPath/inter-latin-wght-normal.woff2',
          weight: FontWeight.w100,
          maxWeight: FontWeight.w900,
          preload: true,
        ),
        FontFace(
          'IBM Plex Mono',
          url: '$fontsPath/ibm-plex-mono-latin-400-normal.woff2',
        ),
        FontFace(
          'IBM Plex Mono',
          url: '$fontsPath/ibm-plex-mono-latin-500-normal.woff2',
          weight: FontWeight.w500,
        ),
      ],
      // Flutter's component themes, so a plain `FilledButton`, `FilterChip`,
      // `Card` or `TextField` is already a studio pill, card or field. Colors
      // are the scheme's roles (they follow `copyWith(colorScheme:)`); only
      // what Material has no role for (a hover fill) is a token.
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          overlayColor: const WidgetStatePropertyAll(
            StudioActionColors.actionHover,
          ),
          padding: const WidgetStatePropertyAll(buttonPadding),
          minimumSize: const WidgetStatePropertyAll(buttonSize),
          shape: const WidgetStatePropertyAll(pill),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          animationDuration: StudioDurations.base,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(
            scheme.surfaceContainerHighest,
          ),
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
          overlayColor: const WidgetStatePropertyAll(StudioSurfaceColors.hover),
          padding: const WidgetStatePropertyAll(buttonPadding),
          minimumSize: const WidgetStatePropertyAll(buttonSize),
          shape: const WidgetStatePropertyAll(pill),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          animationDuration: StudioDurations.base,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
          overlayColor: const WidgetStatePropertyAll(StudioSurfaceColors.hover),
          padding: const WidgetStatePropertyAll(buttonPadding),
          minimumSize: const WidgetStatePropertyAll(buttonSize),
          shape: const WidgetStatePropertyAll(pill),
          side: const WidgetStatePropertyAll(
            BorderSide(color: StudioBorderColors.lineStrong),
          ),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          animationDuration: StudioDurations.base,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
          overlayColor: const WidgetStatePropertyAll(StudioSurfaceColors.hover),
          padding: const WidgetStatePropertyAll(buttonPadding),
          minimumSize: const WidgetStatePropertyAll(buttonSize),
          shape: const WidgetStatePropertyAll(pill),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          animationDuration: StudioDurations.base,
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStatePropertyAll(StudioSurfaceColors.hover),
          animationDuration: StudioDurations.base,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        // A selected chip keeps ink on the accent tint (Material's selected
        // state): one label color serves both states at 4.5:1.
        selectedColor: scheme.secondaryContainer,
        disabledColor: scheme.surfaceContainerHighest,
        shape: pill,
        side: const BorderSide(color: StudioBorderColors.line),
        labelStyle: text.labelLarge.copyWith(color: scheme.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.sm),
        showCheckmark: false,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(StudioRadii.card)),
          side: BorderSide(color: StudioBorderColors.line),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        collapsedIconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        collapsedTextColor: scheme.onSurface,
        tilePadding: const EdgeInsets.symmetric(horizontal: StudioSpacing.md),
        childrenPadding: const EdgeInsets.fromLTRB(
          StudioSpacing.md,
          0,
          StudioSpacing.md,
          StudioSpacing.md,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.surfaceContainerHighest,
      ),
      // The rest of Flutter's component themes: a plain `AlertDialog`,
      // `Tooltip`, `SnackBar`, `ModalBottomSheet`, `AppBar` or
      // `NavigationBar` is already a studio surface. Only what differs from
      // the scheme-driven Material default is set here.
      dialogTheme: const DialogThemeData(shape: card),
      // The drawer dims the page more than Material's 32 %.
      drawerTheme: const DrawerThemeData(scrimColor: StudioShadowColors.scrim),
      bottomSheetTheme: const BottomSheetThemeData(shape: sheet),
      snackBarTheme: const SnackBarThemeData(shape: small),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: StudioContentColors.ink,
          borderRadius: BorderRadius.all(Radius.circular(StudioRadii.small)),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(shape: cardLine),
      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        titleTextStyle: text.titleLarge,
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: StudioAccentColors.accent,
        labelColor: scheme.onSurface,
        labelStyle: text.labelLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.surfaceContainerHighest,
      ),
      // A field's border is the `field-line` token (3:1 on every surface, in
      // both themes), not the scheme's hairline; the focus border is the
      // accent, the error the danger role.
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(StudioRadii.small)),
          borderSide: field,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(StudioRadii.small)),
          borderSide: BorderSide(color: StudioAccentColors.accent, width: 2),
        ),
        labelStyle: text.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
        hintStyle: text.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        selectionColor: StudioAccentColors.selection,
        cursorColor: StudioAccentColors.accent,
      ),
      // web: the focus ring is one `:focus-visible` outline for every link,
      // button and control, in the accent (>= 3:1 on every surface).
      focusColor: StudioAccentColors.accent,
    );
  }
}

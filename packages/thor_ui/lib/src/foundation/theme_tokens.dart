/// The CSS variables of the theme as the widgets write them: `var(--t-name,
/// fallback)` with Material 3's light value as the fallback, so a widget
/// outside a `ThorApp` still looks right. One place for the literals the
/// widgets used to spell out by hand (the output is the same bytes).
///
/// Not exported: the public way to name a theme color is `ThemeColor`.
abstract final class ThemeTokens {
  /// `--t-body-large-line`.
  static const bodyLargeLine = 'var(--t-body-large-line, 24px)';

  /// `--t-body-large-size`.
  static const bodyLargeSize = 'var(--t-body-large-size, 16px)';

  /// `--t-body-large-tracking`.
  static const bodyLargeTracking = 'var(--t-body-large-tracking, normal)';

  /// `--t-body-medium-line`.
  static const bodyMediumLine = 'var(--t-body-medium-line, 20px)';

  /// `--t-body-medium-size`.
  static const bodyMediumSize = 'var(--t-body-medium-size, 14px)';

  /// `--t-body-medium-tracking`.
  static const bodyMediumTracking = 'var(--t-body-medium-tracking, normal)';

  /// `--t-error`.
  static const error = 'var(--t-error, #b3261e)';

  /// `--t-inverse-on-surface`.
  static const inverseOnSurface = 'var(--t-inverse-on-surface, #f5eff7)';

  /// `--t-inverse-surface`.
  static const inverseSurface = 'var(--t-inverse-surface, #322f35)';

  /// `--t-label-large-line`.
  static const labelLargeLine = 'var(--t-label-large-line, 20px)';

  /// `--t-label-large-size`.
  static const labelLargeSize = 'var(--t-label-large-size, 14px)';

  /// `--t-label-large-tracking`.
  static const labelLargeTracking = 'var(--t-label-large-tracking, normal)';

  /// `--t-label-large-weight`.
  static const labelLargeWeight = 'var(--t-label-large-weight, 500)';

  /// `--t-label-medium-line`.
  static const labelMediumLine = 'var(--t-label-medium-line, 16px)';

  /// `--t-label-medium-size`.
  static const labelMediumSize = 'var(--t-label-medium-size, 12px)';

  /// `--t-label-medium-tracking`.
  static const labelMediumTracking = 'var(--t-label-medium-tracking, normal)';

  /// `--t-label-medium-weight`.
  static const labelMediumWeight = 'var(--t-label-medium-weight, 500)';

  /// `--t-on-error`.
  static const onError = 'var(--t-on-error, #ffffff)';

  /// `--t-on-primary`.
  static const onPrimary = 'var(--t-on-primary, #ffffff)';

  /// `--t-on-primary-container`.
  static const onPrimaryContainer = 'var(--t-on-primary-container, #21005d)';

  /// `--t-on-secondary-container`.
  static const onSecondaryContainer =
      'var(--t-on-secondary-container, #1d192b)';

  /// `--t-on-surface`.
  static const onSurface = 'var(--t-on-surface, #1d1b20)';

  /// `--t-on-surface-variant`.
  static const onSurfaceVariant = 'var(--t-on-surface-variant, #49454f)';

  /// `--t-outline`.
  static const outline = 'var(--t-outline, #79747e)';

  /// `--t-outline-variant`.
  static const outlineVariant = 'var(--t-outline-variant, #cac4d0)';

  /// `--t-primary`.
  static const primary = 'var(--t-primary, #6750a4)';

  /// `--t-primary-container`.
  static const primaryContainer = 'var(--t-primary-container, #eaddff)';

  /// `--t-secondary-container`.
  static const secondaryContainer = 'var(--t-secondary-container, #e8def8)';

  /// `--t-snack-offset`.
  static const snackOffset = 'var(--t-snack-offset, 0px)';

  /// `--t-surface`.
  static const surface = 'var(--t-surface, #fef7ff)';

  /// `--t-surface-container`.
  static const surfaceContainer = 'var(--t-surface-container, #f3edf7)';

  /// `--t-surface-container-high`.
  static const surfaceContainerHigh =
      'var(--t-surface-container-high, #ece6f0)';

  /// `--t-surface-container-highest`.
  static const surfaceContainerHighest =
      'var(--t-surface-container-highest, #e6e0e9)';

  /// `--t-surface-container-low`.
  static const surfaceContainerLow = 'var(--t-surface-container-low, #f7f2fa)';
}

/// The tone of a callout, a chip or a badge: one enum for every widget that
/// says "info", "ok", "warning" or "danger".
///
/// The colors of a tone are `StudioToneColors` (foreground, background and
/// border), read from `StudioExtraColors.tone`. Color is never the only
/// signal: each widget pairs it with an icon or a title.
enum StudioTone {
  /// Information (the accent blue).
  info,

  /// Success, a measured win.
  ok,

  /// Caution.
  warn,

  /// Danger, a breaking change.
  danger,

  /// Neutral gray (a chip or badge with no status).
  neutral,

  /// How Flutter does it, when it differs (a teal).
  flutter;

  /// An alias of [info]: something worth knowing.
  static const StudioTone note = info;

  /// An alias of [ok]: a shortcut or a good practice.
  static const StudioTone tip = ok;

  /// An alias of [warn]: something that can go wrong.
  static const StudioTone warning = warn;
}

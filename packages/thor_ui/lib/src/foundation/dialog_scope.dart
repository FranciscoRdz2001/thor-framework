import 'package:thor_style/thor_style.dart' show Color;

import '../core/core.dart';
import 'stylesheet.dart' show WindowSizeClass;

/// The id of the native panel (`<dialog>`) whose content is being built:
/// what `DialogClose()` without an `id` closes.
///
/// `// web:` Flutter's `Navigator.pop(context)` pops the route the context
/// is in; here the "route" is the nearest dialog above the widget.
class DialogScope extends InheritedWidget implements InheritedMemoKey {
  /// Publishes [id] to [child] and below.
  const DialogScope({super.key, required this.id, required super.child});

  /// DOM id of the dialog.
  final String id;

  /// The id of the nearest dialog above [context], or null.
  static String? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DialogScope>()?.id;

  @override
  bool updateShouldNotify(covariant DialogScope oldComponent) =>
      oldComponent.id != id;

  @override
  Object? get memoKey => id;
}

/// The id a `DialogTrigger(dialog:)` chose for the dialog it carries: that
/// dialog (and no other below it) takes it instead of naming itself, so the
/// trigger's `commandfor` and the dialog's `id` are the same string.
class PresetDialogId extends InheritedWidget implements InheritedMemoKey {
  /// Publishes [id] for [dialog] to [child] (which is [dialog]).
  const PresetDialogId({
    super.key,
    required this.id,
    required this.dialog,
    this.byType = false,
    this.scope,
    required super.child,
  });

  /// Whether [dialog] is an app component: the dialog it builds is not
  /// [dialog] itself, so the first dialog of its type built below (in the
  /// same [scope]) takes the id.
  final bool byType;

  /// The [DialogScope] the trigger sits in: a dialog nested in the carried
  /// one has another scope above it and does not take the id.
  final String? scope;

  /// The chosen DOM id.
  final String id;

  /// The dialog widget that takes [id].
  final Widget dialog;

  /// [id] when [owner] is the dialog the nearest trigger carries.
  static String? of(BuildContext context, Widget owner) {
    final preset = context.dependOnInheritedWidgetOfExactType<PresetDialogId>();
    if (preset == null) return null;
    if (identical(preset.dialog, owner)) return preset.id;
    return preset.byType &&
            owner.runtimeType == preset.dialog.runtimeType &&
            DialogScope.maybeOf(context) == preset.scope
        ? preset.id
        : null;
  }

  @override
  bool updateShouldNotify(covariant PresetDialogId oldComponent) =>
      oldComponent.id != id;

  @override
  Object? get memoKey => id;
}

/// What a `Scaffold` tells its `AppBar` (and any `DrawerButton` below):
/// the ids of the drawers it holds, so the button opens them without the
/// app naming anything (Flutter's `Scaffold.of(context).openDrawer()`).
class ScaffoldScope extends InheritedWidget implements InheritedMemoKey {
  /// Publishes the drawers' ids to [child] and below.
  const ScaffoldScope({
    super.key,
    this.drawerId,
    this.endDrawerId,
    this.drawerPermanentFrom,
    this.endDrawerPermanentFrom,
    this.scrollBody = false,
    this.primary = true,
    required super.child,
  });

  /// Whether the scaffold's body is a `CustomScrollView`, which scrolls
  /// inside the scaffold (the app bar follows its scroll).
  final bool scrollBody;

  /// `Scaffold.primary`: whether its app bar clears the top inset.
  final bool primary;

  /// DOM id of `Scaffold.drawer`, if it has one.
  final String? drawerId;

  /// DOM id of `Scaffold.endDrawer`, if it has one.
  final String? endDrawerId;

  /// The breakpoint from which `Scaffold.drawer` is an inline panel (its
  /// `Drawer.permanentFrom`): the button that opens it has nothing to open
  /// from there.
  final WindowSizeClass? drawerPermanentFrom;

  /// Same, for `Scaffold.endDrawer`.
  final WindowSizeClass? endDrawerPermanentFrom;

  /// The nearest scaffold's drawers above [context], or null.
  static ScaffoldScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScaffoldScope>();

  @override
  bool updateShouldNotify(covariant ScaffoldScope oldComponent) =>
      oldComponent.drawerId != drawerId ||
      oldComponent.endDrawerId != endDrawerId ||
      oldComponent.drawerPermanentFrom != drawerPermanentFrom ||
      oldComponent.endDrawerPermanentFrom != endDrawerPermanentFrom ||
      oldComponent.scrollBody != scrollBody ||
      oldComponent.primary != primary;

  @override
  Object? get memoKey => (
    drawerId,
    endDrawerId,
    drawerPermanentFrom,
    endDrawerPermanentFrom,
    scrollBody,
    primary,
  );
}

/// What the `Scaffold` gives the `Drawer` it holds in a slot: its DOM id
/// and the side it slides from. Read by that `Drawer` only (it hands its
/// own content a clean slate).
class DrawerSlot extends InheritedWidget implements InheritedMemoKey {
  /// Publishes the slot to [child] (a `Drawer`).
  const DrawerSlot({
    super.key,
    this.id,
    this.end = false,
    this.scrimColor,
    required super.child,
  });

  /// `Scaffold.drawerScrimColor`: the dimmed page behind the drawer.
  final Color? scrimColor;

  /// DOM id the scaffold chose (null: no slot).
  final String? id;

  /// Whether it is the end drawer.
  final bool end;

  /// The nearest slot above [context], or null.
  static DrawerSlot? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DrawerSlot>();

  @override
  bool updateShouldNotify(covariant DrawerSlot oldComponent) =>
      oldComponent.id != id ||
      oldComponent.end != end ||
      oldComponent.scrimColor != scrimColor;

  @override
  Object? get memoKey => (id, end, scrimColor);
}

/// Marks the snack bar of the page's own messenger (`toast(…)` and the
/// flash): a `popover` the toast script drives, so its `SnackBar` does not
/// ask for the generic snack bar script.
class PageSnackScope extends InheritedWidget implements InheritedMemoKey {
  /// Marks [child] as the page's own snack bar.
  const PageSnackScope({super.key, required super.child});

  /// Whether [context] is inside the page's own snack bar.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageSnackScope>() != null;

  @override
  bool updateShouldNotify(covariant PageSnackScope oldComponent) => false;

  @override
  Object? get memoKey => true;
}

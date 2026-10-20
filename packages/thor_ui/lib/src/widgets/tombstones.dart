import 'package:thor_engine/thor_engine.dart' show AsyncSnapshot;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';

// Flutter names that thor does not have, kept only to guide the developer
// who types them. Each one is
//
//  * `@Deprecated` with the fix in the message, so the editor strikes the
//    name through and shows what to write instead;
//  * a class whose constructor (or a static method, for a name used as
//    `Name.of(context)`) throws an `UnsupportedError` with the same message
//    and a link, never a page that builds and renders nothing;
//  * `@Tombstone`: not a deprecation for `tool/thor api`: the snapshot marks
//    it `@tombstone` (apart from the real `@deprecated` names, counted
//    separately), it has no reference entry and no deprecation warning when it
//    goes.
//
// `// web:` the constructors that throw are not `const`: none of these is
// const in Flutter either (they take a closure), except
// `BottomNavigationBarItem`, which stays const and harmless because
// `BottomNavigationBar` throws.

/// Marks a name kept only to guide (see the file): out of the API count.
class Tombstone {
  /// Marks a tombstone.
  const Tombstone();
}

// The guide section for Flutter names thor does not have.
const _docs =
    'https://thor-docs.vercel.app/en/get-started/from-flutter'
    '#flutter-names-that-dont-exist';

UnsupportedError _gone(String name, String fix) =>
    UnsupportedError('$name does not exist in thor: $fix ($_docs)');

const _mediaQuery =
    'the server does not know the screen, and the browser lays it out: '
    'change a value per breakpoint with .when(medium: …), show or hide with '
    'ResponsiveVisibility, or follow a container with LayoutScope';

const _navigator =
    'each screen is a page with its URL: go with Link(href: route.link()), '
    'PageNavigator.go(url) from a state method, or a Redirect from an action. '
    'To close a drawer or a dialog (what Navigator.pop(context) does in an '
    'onTap), wrap the item: DialogClose(child: ListTile(onTap: state.method)) '
    'closes it and runs the method; from a state method use '
    'controller.close() of its DialogController';

/// Flutter's `MediaQuery`: there is none.
///
/// Use `.when(medium: …)` for a value per breakpoint, `ResponsiveVisibility`,
/// or `LayoutScope` for a container.
@Tombstone()
@Deprecated('MediaQuery does not exist in thor: $_mediaQuery ($_docs)')
class MediaQuery extends StatelessWidget {
  /// Throws: see the class.
  MediaQuery({super.key, required this.data, required this.child}) {
    throw _gone('MediaQuery', _mediaQuery);
  }

  /// Ignored.
  final MediaQueryData data;

  /// Ignored.
  final Widget child;

  /// Throws: see the class.
  static MediaQueryData of(BuildContext context) =>
      throw _gone('MediaQuery.of', _mediaQuery);

  /// Throws: see the class.
  static MediaQueryData? maybeOf(BuildContext context) =>
      throw _gone('MediaQuery.maybeOf', _mediaQuery);

  /// Throws: see the class.
  static Size sizeOf(BuildContext context) =>
      throw _gone('MediaQuery.sizeOf', _mediaQuery);

  /// Throws: see the class.
  static Orientation orientationOf(BuildContext context) =>
      throw _gone('MediaQuery.orientationOf', _mediaQuery);

  /// Throws: see the class.
  static EdgeInsets paddingOf(BuildContext context) =>
      throw _gone('MediaQuery.paddingOf', _mediaQuery);

  @override
  Widget build(BuildContext context) => throw _gone('MediaQuery', _mediaQuery);
}

/// What `MediaQuery.of` returns in Flutter; only so code type-checks.
@Tombstone()
@Deprecated('MediaQuery does not exist in thor: $_mediaQuery ($_docs)')
class MediaQueryData {
  /// Nothing to hold.
  const MediaQueryData();

  /// Throws: see `MediaQuery`.
  Size get size => throw _gone('MediaQueryData.size', _mediaQuery);

  /// Throws: see `MediaQuery`.
  Orientation get orientation =>
      throw _gone('MediaQueryData.orientation', _mediaQuery);

  /// Throws: see `MediaQuery`.
  EdgeInsets get padding => throw _gone('MediaQueryData.padding', _mediaQuery);

  /// Throws: see `MediaQuery`.
  double get devicePixelRatio =>
      throw _gone('MediaQueryData.devicePixelRatio', _mediaQuery);
}

/// Flutter's `Orientation`; only so code type-checks.
@Tombstone()
@Deprecated('Orientation does not exist in thor: $_mediaQuery ($_docs)')
enum Orientation {
  /// Taller than wide.
  portrait,

  /// Wider than tall.
  landscape,
}

const _layoutBuilder =
    'the layout runs in the browser, not in build: follow a container with '
    'LayoutScope and .when(container: {…}), or change a value per '
    'breakpoint with .when(medium: …)';

/// Flutter's `LayoutBuilder`: there is none.
///
/// Use `LayoutScope` with `.when(container: …)`, or `.when(medium: …)`.
@Tombstone()
@Deprecated('LayoutBuilder does not exist in thor: $_layoutBuilder ($_docs)')
class LayoutBuilder extends StatelessWidget {
  /// Throws: see the class.
  LayoutBuilder({super.key, required this.builder}) {
    throw _gone('LayoutBuilder', _layoutBuilder);
  }

  /// Ignored.
  final Widget Function(BuildContext context, BoxConstraints constraints)
  builder;

  @override
  Widget build(BuildContext context) =>
      throw _gone('LayoutBuilder', _layoutBuilder);
}

/// Flutter's `OrientationBuilder`: there is none.
///
/// Use `.when(medium: …)` breakpoints, or `LayoutScope` for a container.
@Tombstone()
@Deprecated(
  'OrientationBuilder does not exist in thor: $_layoutBuilder ($_docs)',
)
class OrientationBuilder extends StatelessWidget {
  /// Throws: see the class.
  OrientationBuilder({super.key, required this.builder}) {
    throw _gone('OrientationBuilder', _layoutBuilder);
  }

  /// Ignored.
  final Widget Function(BuildContext context, Orientation orientation) builder;

  @override
  Widget build(BuildContext context) =>
      throw _gone('OrientationBuilder', _layoutBuilder);
}

const _showDialog =
    'the dialog is part of the page: an AlertDialog opened with '
    'DialogTrigger, or with a DialogController from a state method; to ask '
    "and act on the answer, `await confirm('…')` in a state method";

/// Flutter's `showDialog`: there is none.
///
/// Put an `AlertDialog` in the page and open it with `DialogTrigger` or a
/// `DialogController`; from a state method, `await confirm('…')`.
@Tombstone()
@Deprecated('showDialog does not exist in thor: $_showDialog ($_docs)')
Future<T?> showDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  Object? routeSettings,
  Object? anchorPoint,
  Object? traversalEdgeBehavior,
  bool fullscreenDialog = false,
  bool? requestFocus,
}) => throw _gone('showDialog', _showDialog);

const _showModalBottomSheet =
    'the sheet is part of the page: a ModalBottomSheet opened with '
    'DialogTrigger, or with a DialogController from a state method';

/// Flutter's `showModalBottomSheet`: there is none.
///
/// Put a `ModalBottomSheet` in the page and open it with `DialogTrigger` or
/// a `DialogController`.
@Tombstone()
@Deprecated(
  'showModalBottomSheet does not exist in thor: $_showModalBottomSheet '
  '($_docs)',
)
Future<T?> showModalBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  Color? backgroundColor,
  String? barrierLabel,
  double? elevation,
  Object? shape,
  Object? clipBehavior,
  Object? constraints,
  Color? barrierColor,
  bool isScrollControlled = false,
  double scrollControlDisabledMaxHeightRatio = 9 / 16,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  bool useSafeArea = false,
  Object? routeSettings,
  Object? transitionAnimationController,
  Object? anchorPoint,
  Object? sheetAnimationStyle,
  bool? requestFocus,
}) => throw _gone('showModalBottomSheet', _showModalBottomSheet);

const _showDatePicker =
    'the picker is part of the page: a DatePickerFormField (a field with a '
    'calendar button) or a DatePickerDialog opened with DialogTrigger; its '
    'onDateChanged calls a state method';

/// Flutter's `showDatePicker`: there is none.
///
/// Use a `DatePickerFormField`, or a `DatePickerDialog` in the page.
@Tombstone()
@Deprecated('showDatePicker does not exist in thor: $_showDatePicker ($_docs)')
Future<DateTime?> showDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? currentDate,
  Object? initialEntryMode,
  bool Function(DateTime day)? selectableDayPredicate,
  String? helpText,
  String? cancelText,
  String? confirmText,
  Object? locale,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useRootNavigator = true,
  Object? routeSettings,
  Object? textDirection,
  Widget Function(BuildContext context, Widget? child)? builder,
  Object? initialDatePickerMode,
  String? errorFormatText,
  String? errorInvalidText,
  String? fieldHintText,
  String? fieldLabelText,
  Object? keyboardType,
  Object? anchorPoint,
  Object? onDatePickerModeChange,
  Object? switchToInputEntryModeIcon,
  Object? switchToCalendarEntryModeIcon,
}) => throw _gone('showDatePicker', _showDatePicker);

const _showTimePicker =
    'the picker is part of the page: a TimePickerDialog opened with '
    'DialogTrigger; its onTimePicked calls a state method';

/// Flutter's `showTimePicker`: there is none.
///
/// Put a `TimePickerDialog` in the page and open it with `DialogTrigger`.
@Tombstone()
@Deprecated('showTimePicker does not exist in thor: $_showTimePicker ($_docs)')
Future<Object?> showTimePicker({
  required BuildContext context,
  required Object initialTime,
  Widget Function(BuildContext context, Widget? child)? builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useRootNavigator = true,
  Object? initialEntryMode,
  String? cancelText,
  String? confirmText,
  String? helpText,
  String? errorInvalidText,
  String? hourLabelText,
  String? minuteLabelText,
  Object? routeSettings,
  Object? onEntryModeChanged,
  Object? anchorPoint,
  Object? orientation,
  Object? switchToInputEntryModeIcon,
  Object? switchToTimerEntryModeIcon,
}) => throw _gone('showTimePicker', _showTimePicker);

/// Flutter's `Navigator`: there is none.
///
/// Every screen is a page with its URL: `Link`, `route.link()`,
/// `PageNavigator.go`.
@Tombstone()
@Deprecated('Navigator does not exist in thor: $_navigator ($_docs)')
class Navigator extends StatelessWidget {
  /// Throws: see the class.
  Navigator({
    super.key,
    this.initialRoute,
    this.onGenerateRoute,
    this.pages = const [],
  }) {
    throw _gone('Navigator', _navigator);
  }

  /// Ignored.
  final String? initialRoute;

  /// Ignored.
  final Object? Function(Object? settings)? onGenerateRoute;

  /// Ignored.
  final List<Object> pages;

  /// Throws: see the class.
  static NavigatorState of(
    BuildContext context, {
    bool rootNavigator = false,
  }) => throw _gone('Navigator.of', _navigator);

  /// Throws: see the class.
  static NavigatorState? maybeOf(
    BuildContext context, {
    bool rootNavigator = false,
  }) => throw _gone('Navigator.maybeOf', _navigator);

  /// Throws: see the class.
  static Future<T?> push<T extends Object?>(
    BuildContext context,
    MaterialPageRoute<T> route,
  ) => throw _gone('Navigator.push', _navigator);

  /// Throws: see the class.
  static Future<T?> pushNamed<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) => throw _gone('Navigator.pushNamed', _navigator);

  /// Throws: see the class.
  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    BuildContext context,
    MaterialPageRoute<T> newRoute, {
    TO? result,
  }) => throw _gone('Navigator.pushReplacement', _navigator);

  /// Throws: see the class.
  static Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    BuildContext context,
    String routeName, {
    TO? result,
    Object? arguments,
  }) => throw _gone('Navigator.pushReplacementNamed', _navigator);

  /// Throws: see the class.
  static Future<T?> pushAndRemoveUntil<T extends Object?>(
    BuildContext context,
    MaterialPageRoute<T> newRoute,
    bool Function(Object route) predicate,
  ) => throw _gone('Navigator.pushAndRemoveUntil', _navigator);

  /// Throws: see the class.
  static Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    BuildContext context,
    String newRouteName,
    bool Function(Object route) predicate, {
    Object? arguments,
  }) => throw _gone('Navigator.pushNamedAndRemoveUntil', _navigator);

  /// Throws: see the class.
  static void pop<T extends Object?>(BuildContext context, [T? result]) =>
      throw _gone('Navigator.pop', _navigator);

  /// Throws: see the class.
  static Future<bool> maybePop<T extends Object?>(
    BuildContext context, [
    T? result,
  ]) => throw _gone('Navigator.maybePop', _navigator);

  /// Throws: see the class.
  static void popUntil(
    BuildContext context,
    bool Function(Object route) test,
  ) => throw _gone('Navigator.popUntil', _navigator);

  @override
  Widget build(BuildContext context) => throw _gone('Navigator', _navigator);
}

/// What `Navigator.of` returns in Flutter; only so code type-checks.
@Tombstone()
@Deprecated('Navigator does not exist in thor: $_navigator ($_docs)')
class NavigatorState {
  /// Nothing to hold.
  const NavigatorState();

  /// Throws: see `Navigator`.
  Future<T?> push<T extends Object?>(MaterialPageRoute<T> route) =>
      throw _gone('NavigatorState.push', _navigator);

  /// Throws: see `Navigator`.
  Future<T?> pushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) => throw _gone('NavigatorState.pushNamed', _navigator);

  /// Throws: see `Navigator`.
  Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    TO? result,
    Object? arguments,
  }) => throw _gone('NavigatorState.pushReplacementNamed', _navigator);

  /// Throws: see `Navigator`.
  Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    MaterialPageRoute<T> newRoute, {
    TO? result,
  }) => throw _gone('NavigatorState.pushReplacement', _navigator);

  /// Throws: see `Navigator`.
  Future<T?> pushAndRemoveUntil<T extends Object?>(
    MaterialPageRoute<T> newRoute,
    bool Function(Object route) predicate,
  ) => throw _gone('NavigatorState.pushAndRemoveUntil', _navigator);

  /// Throws: see `Navigator`.
  void popUntil(bool Function(Object route) test) =>
      throw _gone('NavigatorState.popUntil', _navigator);

  /// Throws: see `Navigator`.
  void pop<T extends Object?>([T? result]) =>
      throw _gone('NavigatorState.pop', _navigator);

  /// Throws: see `Navigator`.
  Future<bool> maybePop<T extends Object?>([T? result]) =>
      throw _gone('NavigatorState.maybePop', _navigator);

  /// Throws: see `Navigator`.
  bool canPop() => throw _gone('NavigatorState.canPop', _navigator);
}

/// Flutter's `MaterialPageRoute`: there is none (see `Navigator`).
@Tombstone()
@Deprecated('MaterialPageRoute does not exist in thor: $_navigator ($_docs)')
class MaterialPageRoute<T> {
  /// Throws: see the class.
  MaterialPageRoute({
    required this.builder,
    this.settings,
    this.maintainState = true,
    this.fullscreenDialog = false,
  }) {
    throw _gone('MaterialPageRoute', _navigator);
  }

  /// Ignored.
  final Widget Function(BuildContext context) builder;

  /// Ignored.
  final Object? settings;

  /// Ignored.
  final bool maintainState;

  /// Ignored.
  final bool fullscreenDialog;
}

const _messenger =
    'feedback is a page element: toast(…) from a state method (hideToast() '
    'and clearToasts() end it), or '
    "Redirect(url).flash('…') for the page after an action";

/// Flutter's `ScaffoldMessenger`: there is none.
///
/// Use `toast('…')` from a state method (`hideToast()` and `clearToasts()`
/// end it), or `Redirect(url).flash('…')`.
@Tombstone()
@Deprecated('ScaffoldMessenger does not exist in thor: $_messenger ($_docs)')
class ScaffoldMessenger extends StatelessWidget {
  /// Throws: see the class.
  ScaffoldMessenger({super.key, required this.child}) {
    throw _gone('ScaffoldMessenger', _messenger);
  }

  /// Ignored.
  final Widget child;

  /// Throws: see the class.
  static ScaffoldMessengerState of(BuildContext context) =>
      throw _gone('ScaffoldMessenger.of', _messenger);

  /// Throws: see the class.
  static ScaffoldMessengerState? maybeOf(BuildContext context) =>
      throw _gone('ScaffoldMessenger.maybeOf', _messenger);

  @override
  Widget build(BuildContext context) =>
      throw _gone('ScaffoldMessenger', _messenger);
}

/// What `ScaffoldMessenger.of` returns in Flutter; only so code
/// type-checks.
@Tombstone()
@Deprecated('ScaffoldMessenger does not exist in thor: $_messenger ($_docs)')
class ScaffoldMessengerState {
  /// Nothing to hold.
  const ScaffoldMessengerState();

  /// Throws: see `ScaffoldMessenger`.
  void showSnackBar(Widget snackBar) =>
      throw _gone('ScaffoldMessenger.showSnackBar', _messenger);

  /// Throws: see `ScaffoldMessenger`.
  void hideCurrentSnackBar() => throw _gone(
    'ScaffoldMessenger.hideCurrentSnackBar',
    'call hideToast() from a state method (the next toast waiting shows); '
        '$_messenger',
  );

  /// Throws: see `ScaffoldMessenger`.
  void clearSnackBars() => throw _gone(
    'ScaffoldMessenger.clearSnackBars',
    'call clearToasts() from a state method (the toast showing and the ones '
        'waiting go); $_messenger',
  );
}

const _streamBuilder =
    'a stream is state that changes in the browser: keep it in a ThorState '
    'field and show it with Watch; the server has nothing to subscribe to';

/// Flutter's `StreamBuilder`: there is none.
///
/// Keep the value in a `ThorState` field and show it with `Watch`.
@Tombstone()
@Deprecated('StreamBuilder does not exist in thor: $_streamBuilder ($_docs)')
class StreamBuilder<T> extends StatelessWidget {
  /// Throws: see the class.
  StreamBuilder({
    super.key,
    this.stream,
    this.initialData,
    required this.builder,
  }) {
    throw _gone('StreamBuilder', _streamBuilder);
  }

  /// Ignored.
  final Stream<T>? stream;

  /// Ignored.
  final T? initialData;

  /// Ignored.
  final Widget Function(BuildContext context, AsyncSnapshot<T> snapshot)
  builder;

  @override
  Widget build(BuildContext context) =>
      throw _gone('StreamBuilder', _streamBuilder);
}

const _bottomNavigationBar =
    'use NavigationBar with NavigationDestination (Material 3, a <nav> of '
    'links), as Scaffold(bottomNavigationBar:)';

/// Flutter's `BottomNavigationBar`: there is none.
///
/// Use `NavigationBar` (Material 3).
@Tombstone()
@Deprecated(
  'BottomNavigationBar does not exist in thor: $_bottomNavigationBar '
  '($_docs)',
)
class BottomNavigationBar extends StatelessWidget {
  /// Throws: see the class.
  BottomNavigationBar({
    super.key,
    required this.items,
    this.currentIndex = 0,
    this.onTap,
  }) {
    throw _gone('BottomNavigationBar', _bottomNavigationBar);
  }

  /// Ignored.
  final List<BottomNavigationBarItem> items;

  /// Ignored.
  final int currentIndex;

  /// Ignored.
  final void Function(int index)? onTap;

  @override
  Widget build(BuildContext context) =>
      throw _gone('BottomNavigationBar', _bottomNavigationBar);
}

/// An item of `BottomNavigationBar`; only so code type-checks (the bar
/// throws).
@Tombstone()
@Deprecated(
  'BottomNavigationBar does not exist in thor: $_bottomNavigationBar '
  '($_docs)',
)
class BottomNavigationBarItem {
  /// Nothing to hold.
  const BottomNavigationBarItem({
    required this.icon,
    this.label,
    this.activeIcon,
  });

  /// Ignored.
  final Widget icon;

  /// Ignored.
  final String? label;

  /// Ignored.
  final Widget? activeIcon;
}

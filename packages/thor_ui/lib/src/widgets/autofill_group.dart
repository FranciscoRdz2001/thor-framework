import '../core/core.dart';
import '../foundation/child_rules.dart';
import '../foundation/dialog_scope.dart' show DialogScope;
import '../foundation/element.dart';
import '../foundation/layout_hint.dart';
import '../foundation/transparent.dart' show resolveComponent;
import 'basic.dart' show boxCss;
import 'form.dart' show Form, InsideForm;

/// Flutter's `AutofillContextAction`: what happens to the autofill data of
/// an [AutofillGroup] when it goes away.
enum AutofillContextAction {
  /// The browser may save what the visitor typed (a password manager offers
  /// to remember it). Flutter's default.
  commit,

  /// The data is discarded: the group's `<form>` says `autocomplete="off"`.
  ///
  /// `// web:` a hint: browsers decide for themselves, and password managers
  /// often ignore it.
  cancel,
}

/// The `section-*` token of the nearest `AutofillGroup` that sets one, and
/// whether the group is a `<form>` of its own.
class AutofillSection extends InheritedWidget {
  /// Publishes [section] to [child].
  const AutofillSection({
    super.key,
    required this.section,
    this.ownsForm = false,
    this.off = false,
    required super.child,
  });

  /// Whether the group rendered its own `<form>`: a `Form` below it would
  /// nest one in the other.
  final bool ownsForm;

  /// Whether a `Form` that is the group's child says `autocomplete="off"`
  /// ([AutofillContextAction.cancel]).
  final bool off;

  /// Whether a `<form>` made by an `AutofillGroup` is above [context].
  static bool inOwnForm(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AutofillSection>()?.ownsForm ??
      false;

  /// Whether the `Form` that is an `AutofillGroup`'s child must say
  /// `autocomplete="off"`.
  static bool formOff(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AutofillSection>()?.off ??
      false;

  /// The section name, without the `section-` prefix; null for a group
  /// with none.
  final String? section;

  /// The section of the nearest group around [context] that sets one, or
  /// null.
  static String? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AutofillSection>()?.section;

  /// Whether [context] is inside an [AutofillGroup].
  static bool isIn(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AutofillSection>() != null;

  @override
  bool updateShouldNotify(AutofillSection oldWidget) =>
      oldWidget.section != section ||
      oldWidget.ownsForm != ownsForm ||
      oldWidget.off != off;
}

/// [token] (an `autocomplete` value) prefixed with `section-[section]`, so
/// the browser fills a group of fields as one (a shipping and a billing
/// address in the same page). `off`, an empty token and one that already
/// names a section stay as they are.
String? withAutofillSection(String? token, String? section) {
  if (token == null || section == null) return token;
  final t = token.trim();
  if (t.isEmpty ||
      t == 'off' ||
      t.split(RegExp(r'\s+')).first.startsWith('section-')) {
    return token;
  }
  return 'section-$section $t';
}

/// Flutter's `AutofillGroup`: the fields inside are one group for the
/// browser's autofill and password manager (a login's username and
/// password).
///
/// ```dart
/// AutofillGroup(
///   child: Column(children: [
///     TextField(name: 'user', autofillHints: [AutofillHints.username]),
///     TextField(name: 'pass', obscureText: true, autofillHints: [AutofillHints.password]),
///   ]),
/// )
/// ```
///
/// `// web:` browsers group fields by their `<form>`, so inside a `Form`
/// (or with a `Form` as its child, Flutter's usual order) the group adds
/// nothing; outside one it is a `<form autocomplete="on"
/// method="dialog">` (a submit never navigates, so the password never ends
/// up in the URL). Inside a dialog it adds no element either: a
/// `method="dialog"` form there would close the dialog on Enter. A `Form`
/// deeper below a group that is a `<form>` is an error (a form in a form is
/// not HTML): make the `Form` the group's child, or the group its child.
/// [section] is a web extra: it prefixes the `autocomplete`
/// of every field inside with `section-<name>`, so two groups on the page
/// (shipping and billing) are filled apart.
class AutofillGroup extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a group of autofillable fields.
  const AutofillGroup({
    super.key,
    required this.child,
    this.onDisposeAction = AutofillContextAction.commit,
    this.section,
  }) : assert(section != '', 'an autofill section is not empty');

  /// The fields.
  final Widget child;

  /// What the browser does with the data (see [AutofillContextAction]).
  final AutofillContextAction onDisposeAction;

  // web: not in Flutter.
  /// The `section-*` name the fields inside share.
  final String? section;

  @override
  bool get fillsWidth => layoutFillsWidth(child);

  @override
  Widget build(BuildContext context) {
    assert(
      section == null || !section!.contains(RegExp(r'\s')),
      'an autofill section is one token: no spaces',
    );
    final off = onDisposeAction == AutofillContextAction.cancel;
    AutofillSection group({bool ownsForm = false, bool off = false}) =>
        AutofillSection(
          section: section ?? AutofillSection.of(context),
          ownsForm: ownsForm,
          off: off,
          child: child,
        );
    // Inside a form (or a group that is one) the browser already groups
    // the fields; a <form> in a <form> is not HTML. A dialog's Enter would
    // close it (`method="dialog"`). A Form as the child is the group.
    if (InsideForm.isIn(context) ||
        AutofillSection.isIn(context) ||
        DialogScope.maybeOf(context) != null) {
      return group();
    }
    if (resolveComponent(child) is Form) return group(off: off);
    final inner = group(ownsForm: true);
    return thorElement(
      'form',
      debugName: 'AutofillGroup',
      fillsWidth: fillsWidth,
      css: const {...boxCss},
      childRules: ChildRules.box,
      attributes: {'method': 'dialog', 'autocomplete': off ? 'off' : 'on'},
      children: [inner],
    );
  }
}

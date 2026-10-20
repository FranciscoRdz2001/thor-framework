import '../core/core.dart' show Widget;
import '../foundation/transparent.dart' show resolveLeaf;
import 'dropdown_menu.dart' show DropdownMenu;
import 'effects.dart' show Semantics, SemanticsButton;
import 'form.dart' show TextFormField;
import 'material.dart' show ListTile;
import 'selection_controls.dart'
    show
        Checkbox,
        CheckboxListTile,
        DropdownButton,
        DropdownButtonFormField,
        ListBox,
        Radio,
        RadioListTile,
        SegmentedButton,
        Slider,
        Switch,
        SwitchListTile;
import 'text_field.dart';

/// Whether [child] (or what an app component around it builds) is a control
/// with its own role and focus (`<button>`, `<a>`, a field, a checkbox…): a
/// `role="button"` over it would replace what a screen reader announces
/// (a checkbox is not a button), and its Enter and Space are its own.
bool childIsNativeControl(Widget? child) =>
    _isNative(child) || _isNative(resolveLeaf(child));

bool _isNative(Widget? w) => switch (w) {
  // Semantics(button: true) makes a thor element a native <button>.
  Semantics(button: true) ||
  // Every button widget (IconButton and each `_ButtonBase`) is one.
  SemanticsButton() ||
  TextField() ||
  TextFormField() ||
  Checkbox() ||
  Switch() ||
  Radio() ||
  Slider() ||
  DropdownButton() ||
  DropdownButtonFormField() ||
  DropdownMenu() ||
  ListBox() ||
  SegmentedButton() ||
  // The `*ListTile` controls are a <label> around the input.
  CheckboxListTile() ||
  SwitchListTile() ||
  RadioListTile() => true,
  _ => false,
};

/// Whether [child] already has a role of its own (a native control, a
/// button, a list item): [Semantics] must not put a role over it, as that
/// would replace what a screen reader announces.
bool childHasOwnRole(Widget? child) =>
    childIsNativeControl(child) ||
    _hasRole(child) ||
    _hasRole(resolveLeaf(child));

bool _hasRole(Widget? w) => w is SemanticsButton || w is ListTile;

/// Whether [child] is a native `<input>` that exposes its own checked
/// state (a checkbox, a switch or a radio).
bool childIsNativeCheck(Widget? child) =>
    _isCheck(child) || _isCheck(resolveLeaf(child));

bool _isCheck(Widget? w) => w is Checkbox || w is Switch || w is Radio;

/// Whether [child] is a native range input (`<input type=range>`).
bool childIsNativeRange(Widget? child) =>
    child is Slider || resolveLeaf(child) is Slider;

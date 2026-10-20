import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// The instance fields of ThorState class [c] as the page sees them: its
/// own and those of the mixins it uses (`class X extends ThorState with M`),
/// one per name, the last definition in the order of resolution.
Iterable<FieldElement> stateFields(InterfaceElement c) {
  final byName = <String, FieldElement>{};
  for (final k in [for (final t in c.mixins) t.element, c]) {
    for (final f in k.fields) {
      if (f.name case final n?) byName[n] = f;
    }
  }
  return byName.values;
}

/// The methods of ThorState class [c], mixins included (see [stateFields]).
Iterable<MethodElement> stateMethods(InterfaceElement c) {
  final byName = <String, MethodElement>{};
  for (final k in [for (final t in c.mixins) t.element, c]) {
    for (final m in k.methods) {
      if (m.name case final n?) byName[n] = m;
    }
  }
  return byName.values;
}

/// The details class of a `GestureDetector` callback ([t] is one of thor_ui's
/// `TapDownDetails`, `TapUpDetails`, `DragUpdateDetails`, `DragEndDetails`), else null.
Element? gestureDetails(DartType t) {
  final e = t.element;
  return e != null &&
          const {
            'TapDownDetails',
            'TapUpDetails',
            'DragUpdateDetails',
            'DragEndDetails',
          }.contains(e.name) &&
          '${e.library?.uri}'.startsWith('package:thor_ui/')
      ? e
      : null;
}

bool _inEngine(Element e) =>
    '${e.library?.uri}'.startsWith('package:thor_engine/');

/// thor_engine's `KeyEvent` when [t] is it (a `Focus.onKeyEvent` method's
/// event), else null.
Element? keyEventType(DartType t) {
  final e = t.element;
  return e != null && e.name == 'KeyEvent' && _inEngine(e) ? e : null;
}

/// thor_engine's `FocusNode` when [t] is it, else null.
Element? focusNodeType(DartType t) {
  final e = t.element;
  return e != null && e.name == 'FocusNode' && _inEngine(e) ? e : null;
}

/// The class when [t] is an app's subclass of thor_engine's `Intent` (a
/// `CallbackAction` method's intent), else null.
ClassElement? intentType(DartType t) {
  final e = t.element;
  if (e is! ClassElement || _inEngine(e)) return null;
  return e.allSupertypes.any(
        (s) => s.element.name == 'Intent' && _inEngine(s.element),
      )
      ? e
      : null;
}

/// Whether intent class [c] can be made again in the page: a public,
/// concrete class with an unnamed generative constructor that takes no
/// required argument.
bool intentRebuildable(ClassElement c) {
  if (c.name?.startsWith('_') ?? true) return false;
  if (c.isAbstract) return false;
  final ctor = c.unnamedConstructor;
  return ctor != null &&
      !ctor.isFactory &&
      ctor.formalParameters.every((p) => p.isOptional);
}

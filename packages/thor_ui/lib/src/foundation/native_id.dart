import 'package:thor_engine/thor_engine.dart'
    show ThorController, ThorState, keyToken, templateIntKey;

import '../core/core.dart';
import 'dialog_scope.dart' show PresetDialogId;
import 'style_registry.dart';

var _fallbackIds = 0;

/// The DOM id of a native panel (a `<dialog>`, a popover, a tab group)
/// whose widget takes an optional `id`.
///
/// In order:
///
/// 1. the [id] the app wrote;
/// 2. the id derived from a [controller] held by a `ThorState`
///    (`dlg-CounterState-confirm`): a trigger with the same controller
///    derives the same one, so nothing has to be named twice;
/// 3. the id derived from a `ValueKey` ([key]): `dlg-42` for
///    `ValueKey(42)`, the same on every render and in any order (a
///    dialog per row of a list; `ValueKey(row.key)` in a `Watch.list` row
///    gives each row the browser draws its own); a repeated key gets `-2`, `-3`… by the
///    page order;
/// 4. otherwise `t-<prefix>1`, `t-<prefix>2`… counted by the page in build
///    order: deterministic (the same page renders the same ids), never
///    random.
///
/// `// web:` Flutter has no ids: its dialogs are found by the route they
/// push. Here the page holds them from the start and the browser looks
/// them up by id.
String nativeId(
  BuildContext context, {
  required String prefix,
  String? id,
  Key? key,
  ThorController? controller,
  Widget? owner,
}) {
  // A `DialogTrigger(dialog:)` already named this one.
  if (owner != null) {
    final preset = PresetDialogId.of(context, owner);
    if (preset != null) return preset;
  }
  final registry = ThorStyleRegistry.active(context);
  if (id != null) {
    registry?.reserveId(id);
    return id;
  }
  final derived = derivedNativeId(prefix, controller);
  if (derived != null) return derived;
  if (key is ValueKey) {
    // `web:` in a `Watch.list` row template the key is the placeholder the
    // browser fills (`{{key}}`): it stays in the id, so every row the
    // browser draws gets its own panel (sanitizing it would give them all
    // the same `menu-key`).
    final raw = key.value == templateIntKey ? keyToken : '${key.value}';
    final part = _identifier(
      raw.replaceAll(keyToken, 'THORKEYTOKEN'),
    ).replaceAll('THORKEYTOKEN', keyToken);
    if (part.isNotEmpty) {
      final base = '$prefix-$part';
      return registry?.claimId(base) ?? base;
    }
  }
  return registry?.uniqueId('t-$prefix') ?? 't-$prefix${++_fallbackIds}';
}

/// The id [controller] gives to its [prefix] panel, or null when no
/// `ThorState` field holds it (a trigger and its panel both ask).
String? derivedNativeId(String prefix, ThorController? controller) {
  if (controller == null) return null;
  final held = ThorState.controllerId(controller)?.$2;
  return held == null ? null : '$prefix-${_identifier(held)}';
}

/// [text] as the characters of a plain identifier (`[A-Za-z0-9_-]`).
String _identifier(String text) => text
    .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

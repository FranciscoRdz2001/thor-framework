import 'package:thor_ui/thor_ui.dart';

var _fallbackIds = 0;

/// The DOM id of a studio widget whose parts point at each other (a bench's
/// radio group, the sidebar a top bar opens, a locale menu).
///
/// [id] when the app wrote one; otherwise `t-<prefix>1`, `t-<prefix>2`…
/// counted by the page in build order: deterministic (the same page renders
/// the same ids), never random.
///
/// `// web:` Flutter has no ids; the browser looks these panels up by id.
String studioId(BuildContext context, String prefix, String? id) {
  final registry = ThorStyleRegistry.active(context);
  if (id != null) {
    registry?.reserveId(id);
    return id;
  }
  return registry?.uniqueId('t-$prefix') ?? 't-$prefix${++_fallbackIds}';
}

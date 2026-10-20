/// A state lives as long as the page names it (the lite engine's part
/// `lifecycle`): when the last element that names a state leaves the page
/// (a keyed row removed, a variant replaced for good) its `dispose()` runs
/// once, and when elements that name it come back its `onHydrated()` runs
/// again. Without this feature every state ends with the page.
///
/// `// web:` the state object stays (the engine is given its instances; it
/// cannot make a new one). What a new instance would reset is reset here:
/// the `state(...)` fields go back to the server's values and the effects
/// its `onHydrated` made stop. What it cannot reset is the object's plain
/// fields (a counter, a `Timer?`), which keep their values.
library;

import 'dart:js_interop';

import 'package:thor_engine/src/protocol.dart';
import 'package:thor_engine/src/thor_state.dart';
import 'package:thor_engine_oracle/client.dart' show EngineFeature, StateLife;
import 'package:web/web.dart' as web;

// The attributes that name a state: an id (the first nine), or a list of
// `event:id` split by `;`.
const _ids = [
  textAttr,
  variantAttr,
  listAttr,
  fieldAttr,
  rowVariantAttr,
  dialogControllerAttr,
  scrollControllerAttr,
  textControllerAttr,
  focusNodeAttr,
];
const _handlers = [
  onAttr,
  attributesAttr,
  variablesAttr,
  rowAttributesAttr,
  shortcutsAttr,
  gestureAttr,
];
final _selector = [
  for (final a in [..._ids, ..._handlers]) '[$a]',
].join(',');

// The id prefix of a binding id (`State#key.member`, maybe `~value`).
String _prefix(String id) {
  final arg = id.indexOf(idArgSeparator);
  final bare = arg < 0 ? id : id.substring(0, arg);
  return bare.substring(0, bare.lastIndexOf('.').clamp(0, bare.length));
}

/// The id prefixes of the states [els] (and what they hold) name.
Set<String> namedStates(Iterable<web.Element> els) {
  final out = <String>{};
  void read(web.Element el) {
    for (final a in _ids) {
      final v = el.getAttribute(a);
      if (v != null) out.add(_prefix(v));
    }
    for (final a in _handlers) {
      final v = el.getAttribute(a);
      if (v == null) continue;
      for (final one in v.split(';')) {
        out.add(_prefix(one.substring(one.indexOf(':') + 1)));
      }
    }
  }

  for (final el in els) {
    read(el);
    final inside = el.querySelectorAll(_selector);
    for (var i = 0; i < inside.length; i++) {
      read(inside.item(i)! as web.Element);
    }
  }
  return out;
}

/// `dispose()` when the page stops naming a state, `onHydrated()` when it
/// names it again.
final class LifecycleFeature extends EngineFeature {
  /// The feature.
  const LifecycleFeature();

  @override
  void Function()? followStates(
    web.Element scope,
    Iterable<ThorState> states,
    StateLife life,
  ) {
    // Only the states that override `dispose` live as long as the page names
    // them (the lite engine's `$l.d`): the others end with the page.
    final byPrefix = {
      for (final s in states)
        if (s.disposes) s.idPrefix: s,
    };
    final observer = web.MutationObserver(
      ((JSArray<web.MutationRecord> records, web.MutationObserver _) {
        final out = <web.Element>[], added = <web.Element>[];
        for (final r in records.toDart) {
          final removed = r.removedNodes, put = r.addedNodes;
          for (var i = 0; i < removed.length; i++) {
            final n = removed.item(i)!;
            if (n.nodeType == web.Node.ELEMENT_NODE) out.add(n as web.Element);
          }
          for (var i = 0; i < put.length; i++) {
            final n = put.item(i)!;
            if (n.nodeType == web.Node.ELEMENT_NODE) {
              added.add(n as web.Element);
            }
          }
        }
        // Elements that come back wake the states that had ended.
        if (added.isNotEmpty) {
          for (final p in namedStates(added.where((e) => e.isConnected))) {
            final s = byPrefix[p];
            if (s != null && !life.isLive(s)) life.wake(s);
          }
        }
        if (out.isEmpty) return;
        final gone = namedStates(out);
        if (gone.isEmpty) return;
        final here = namedStates([scope]);
        for (final p in gone) {
          final s = byPrefix[p];
          if (s != null && life.isLive(s) && !here.contains(p)) life.end(s);
        }
      }).toJS,
    );
    observer.observe(
      scope,
      web.MutationObserverInit(childList: true, subtree: true),
    );
    // ignore: unnecessary_lambdas
    return () => observer.disconnect();
  }
}

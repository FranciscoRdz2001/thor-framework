/// The page's resolver of state members, for the features that need what a
/// method returns (a confirmation, a `bool`): an action does not give it back.
/// `EngineFeature.collect` hands every feature the resolver (`startThor` keeps
/// one per page), and such a feature keeps it here.
library;

import 'package:thor_engine/src/protocol.dart' show argAttr, bindingId;
import 'package:thor_engine/src/thor_state.dart' show ThorMember;
import 'package:web/web.dart' as web;

/// The resolver `collect` got last (null before it).
ThorMember Function(String id)? pageMember;

/// Calls the state method [id] for [el]: with the element's fixed argument
/// ([argAttr]) and [value] (`fixed~value`, or either alone), like an action
/// does, and returns what it returns. Null when the page has no such member.
Object? callMember(String id, web.Element el, String? value) {
  final resolve = pageMember;
  if (resolve == null) return null;
  final call = resolve(id).call;
  if (call == null) return null;
  final fixed = el.getAttribute(argAttr);
  return call(
    fixed == null
        ? value
        : value == null
        ? fixed
        : bindingId(fixed, value),
  );
}

/// Looking for the engine's markers in a part of the page.
library;

import 'package:web/web.dart' as web;

/// [root] if it matches [selector], and what it holds that does (a part of
/// the page that arrived after hydration is a list of such roots).
List<web.Element> withRoot(web.Element root, String selector) {
  final list = root.querySelectorAll(selector);
  return [
    if (root.matches(selector)) root,
    for (var i = 0; i < list.length; i++) list.item(i)! as web.Element,
  ];
}

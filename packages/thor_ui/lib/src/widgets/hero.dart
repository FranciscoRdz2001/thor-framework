import '../foundation/parent_data.dart';

/// Flutter's `Hero`: an element that travels from one page to the next.
///
/// Give the element the same [tag] on both pages (a list's title and the
/// detail page's heading) and the browser moves and resizes it between
/// them during the page's view transition (a `PageTransition`), instead of
/// fading it with the rest of the page. Without a transition (the app's or
/// the page's), or in a browser without view transitions, it does nothing.
///
/// It adds no element and stays out of the way of the wrappers around it
/// (a `Padding` still merges into the child): [child]'s element gets
/// `view-transition-name` (`t-hero-` plus the [tag], escaped) in its
/// `style` attribute, so its class stays the one every similar element
/// shares. Two `Hero`es with one [tag] on a page are an error in debug
/// (THOR-R019); in release the second one is left out, as the browser
/// would skip the whole transition.
///
/// ```dart
/// // The list
/// Hero(tag: 'article-${a.slug}', child: Text(a.title))
/// // The article page
/// Hero(tag: 'article-${a.slug}', child: Text(a.title, style: h1))
/// ```
///
/// `// web:` Flutter flies the widget between two routes in memory; here
/// the browser morphs a snapshot of the element between two documents.
/// There is no `flightShuttleBuilder` or `createRectTween`.
class Hero extends ParentDataWrapper {
  /// Marks [child] as the element [tag] names across pages.
  const Hero({super.key, required this.tag, required super.child});

  /// Pairs this element with the one of the other page (any value: its
  /// `toString()` names it).
  final Object tag;

  /// The `view-transition-name` of [tag]: `t-hero-` plus the tag, with
  /// every character but ASCII letters, digits and `-` escaped as `_` and
  /// four hex digits (so two tags never share a name). What a page's own
  /// `::view-transition-group(…)` rules can target.
  static String nameFor(Object tag) {
    final out = StringBuffer('t-hero-');
    for (final unit in tag.toString().codeUnits) {
      final plain =
          (unit >= 0x30 && unit <= 0x39) ||
          (unit >= 0x41 && unit <= 0x5a) ||
          (unit >= 0x61 && unit <= 0x7a) ||
          unit == 0x2d;
      if (plain) {
        out.writeCharCode(unit);
      } else {
        out.write('_${unit.toRadixString(16).padLeft(4, '0')}');
      }
    }
    return out.toString();
  }

  @override
  WrapData get wrapData => WrapData(viewTransitionName: nameFor(tag));
}

import 'dart:async' show Zone;
import 'dart:convert';

import 'package:thor_engine/thor_engine.dart' show switcherAttr;
import 'package:thor_style/thor_style.dart' show Curve, Curves, cssDuration;

import '../core/core.dart';
import '../engine/prefetch_script.dart';

/// When the browser starts loading a linked page ahead of the click
/// (`eagerness` of the Speculation Rules API).
enum SpeculationEagerness {
  /// As soon as the rules are seen: every matching link on the page. Only
  /// for pages with a handful of links.
  immediate,

  /// On a short hover (~10 ms) on desktop; on mobile, soon after a link
  /// enters the viewport.
  eager,

  /// On hover (~200 ms) or pointer down; on mobile, a link that stays in
  /// the viewport. The default: few wasted requests.
  moderate,

  /// On pointer or touch down only: almost no wasted requests, a smaller
  /// head start.
  conservative,
}

/// Where a page's speculation rules travel.
enum SpeculationDelivery {
  /// An inline `<script type="speculationrules">` in every page (the
  /// default; the only one a static site can have).
  inline,

  /// A file the server names in the `Speculation-Rules` response header
  /// (`/_thor/speculation.<hash>.json`): the page has no inline script, so a
  /// strict CSP (`script-src 'sha256-…'`) needs no hash for it. The renderer
  /// must get the same [PageNavigation] (`WidgetRenderer.router` reads it
  /// from the app). Only a server app: a static export has no headers.
  header,
}

/// Set while a page that opted out of prefetch (`PageRoute.prefetch:
/// false`) renders: its inline rules are left out.
const noPrefetchZoneKey = #thorNoPrefetch;

/// The attribute that keeps one link out of the page's speculation rules
/// (`Link(prefetch: false)` sets it).
const noPrefetchAttribute = 'data-no-prefetch';

/// How a multi-page app moves between its pages, with no JavaScript:
/// [Speculation Rules](https://developer.chrome.com/docs/web-platform/prerender-pages)
/// that fetch a linked page before the click, and cross-document
/// [view transitions](https://developer.chrome.com/docs/web-platform/view-transitions/cross-document).
///
/// Browsers without support (or with JavaScript disabled) just navigate:
/// every page still works as a plain document.
///
/// `ThorApp(navigation:)` takes it. When it is `null`, a routed app
/// (`WidgetRenderer`) gets `const PageNavigation()` (prefetch on hover)
/// and a single-document app gets nothing.
///
/// Only `<a href>` links to the same origin are candidates, never forms:
/// an action (`POST`) is never fetched ahead. Links are left out when they
/// open elsewhere (`target` other than `_self`), download (`download`),
/// carry `rel="nofollow"` or `data-no-prefetch` (`Link(prefetch: false)`),
/// or match one of the [exclude] patterns.
///
/// ```dart
/// ThorApp(
///   navigation: const PageNavigation(
///     exclude: ['/logout', '/admin/*'],
///     viewTransition: true,
///   ),
///   child: page,
/// )
/// ```
///
/// `// web:` Flutter's `Navigator` swaps routes in memory; here every page
/// is a document and the browser does the navigation, fetched ahead.
@immutable
class PageNavigation {
  /// Navigation settings; the defaults prefetch a same-origin link on hover.
  const PageNavigation({
    this.prefetch = SpeculationEagerness.moderate,
    this.prerender,
    this.exclude = const [],
    this.viewTransition = false,
    this.transition,
    this.delivery = SpeculationDelivery.inline,
    this.prefetchFallback,
  });

  /// No speculation rules and no view transitions: plain navigations.
  static const none = PageNavigation(prefetch: null);

  /// When a linked page's HTML is fetched ahead (`null`: never). The
  /// response is kept in memory for a few minutes and used by the click.
  final SpeculationEagerness? prefetch;

  /// When a linked page is rendered ahead in a hidden tab, scripts
  /// included (`null`, the default: never). A click then shows it
  /// instantly. Costs memory and runs the page's code for pages the
  /// visitor may never open: use [SpeculationEagerness.conservative] or
  /// [SpeculationEagerness.moderate].
  final SpeculationEagerness? prerender;

  /// URL patterns never fetched ahead, resolved against the page
  /// (`'/logout'`, `'/admin/*'`, `'/item/:id'`): routes whose `GET` has
  /// side effects or is expensive. `URLPattern` syntax.
  final List<String> exclude;

  /// Cross-fades from page to page (`@view-transition { navigation:
  /// auto }`), skipped under `prefers-reduced-motion`. Both pages must opt
  /// in, so set it on the app, not on one page. The same as
  /// `transition: PageTransition.fade()`.
  final bool viewTransition;

  /// How every page of the app enters (`null`: [viewTransition]'s
  /// cross-fade, or none). A layout or a page overrides it with a
  /// `PageTransitionScope` around what it builds.
  final PageTransition? transition;

  /// How the rules reach the browser: inline in each page, or in the
  /// `Speculation-Rules` header (for a strict CSP). See [SpeculationDelivery].
  final SpeculationDelivery delivery;

  /// Whether a browser without Speculation Rules (Firefox, Safari) also
  /// prefetches: a small file, loaded only there, adds `<link rel=prefetch>`
  /// on hover or focus (a press for `conservative`), with the same links
  /// and [exclude] patterns, never with `Save-Data`. Only a routed app with
  /// inline [delivery]; a page that opted out of prefetch carries nothing.
  ///
  /// `null` (the default): only a page that already ships the engine carries
  /// the 241 B inline test that loads it; a page without JavaScript stays
  /// without any. `true`: every page does, engine or not (the
  /// app accepts one inline script per page). `false`: none.
  final bool? prefetchFallback;

  /// The transition a page gets from the app: [transition], else the
  /// cross-fade of [viewTransition], else none (`null`).
  PageTransition? get pageTransition =>
      transition ?? (viewTransition ? const PageTransition.fade() : null);

  static const _excludedLinks =
      '[$noPrefetchAttribute],[rel~=nofollow],[download],'
      '[target]:not([target=_self])';

  /// The body of `<script type="speculationrules">`, or `null` when there
  /// is nothing to speculate. `<` is escaped, so a pattern can never close
  /// the element.
  ///
  /// `null` too when the rules go in a header ([delivery]) or the page being
  /// rendered opted out of prefetch.
  String? get speculationRules {
    if (delivery == SpeculationDelivery.header ||
        Zone.current[noPrefetchZoneKey] == true) {
      return null;
    }
    return speculationRulesJson;
  }

  /// The rules whatever the [delivery] (what the header's file holds), or
  /// `null` when there is nothing to speculate.
  String? get speculationRulesJson {
    if (prefetch == null && prerender == null) return null;
    // Every page asks; an app's navigation is one (const) value.
    return _rules[this] ??= _speculationRules();
  }

  static final _rules = Expando<String>();

  String _speculationRules() {
    final where = {
      'and': [
        // Relative to the page: same origin only.
        {'href_matches': '/*'},
        {
          'not': {'selector_matches': _excludedLinks},
        },
        if (exclude.isNotEmpty)
          {
            'not': {'href_matches': exclude},
          },
      ],
    };
    List<Map<String, Object>> rule(SpeculationEagerness e) => [
      {'source': 'document', 'where': where, 'eagerness': e.name},
    ];
    final rules = {
      if (prefetch case final e?) 'prefetch': rule(e),
      if (prerender case final e?) 'prerender': rule(e),
    };
    return jsonEncode(rules).replaceAll('<', r'\u003c');
  }

  /// The prefetch fallback file's text (`/_thor/prefetch.<hash>.js`), or
  /// `null` when there is none: no prefetch, [prefetchFallback] `false`, or the
  /// rules travel in a header (a strict CSP has no inline loader).
  String? get prefetchFallbackScript {
    if (prefetchFallback == false ||
        delivery == SpeculationDelivery.header ||
        speculationRulesJson == null) {
      return null;
    }
    return _fallbacks[this] ??= prefetchScript(
      hoverDelay: switch (prefetch ??
          prerender ??
          SpeculationEagerness.moderate) {
        SpeculationEagerness.immediate || SpeculationEagerness.eager => 50,
        SpeculationEagerness.moderate => 200,
        SpeculationEagerness.conservative => null,
      },
      excludedLinks: _excludedLinks,
      exclude: [for (final p in exclude) ?patternToRegExp(p)],
    );
  }

  static final _fallbacks = Expando<String>();

  /// The page rules behind [pageTransition], or `null`.
  String? get viewTransitionCss => pageTransition?.css;

  @override
  bool operator ==(Object other) =>
      other is PageNavigation &&
      other.prefetch == prefetch &&
      other.prerender == prerender &&
      other.viewTransition == viewTransition &&
      other.transition == transition &&
      other.delivery == delivery &&
      other.prefetchFallback == prefetchFallback &&
      _sameList(other.exclude, exclude);

  @override
  int get hashCode => Object.hash(
    prefetch,
    prerender,
    viewTransition,
    transition,
    delivery,
    prefetchFallback,
    Object.hashAll(exclude),
  );

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

enum _TransitionKind { none, fade, slide, fadeUp }

/// How a page enters when the visitor comes from another page of the app:
/// a cross-document view transition (`@view-transition`), drawn by the
/// browser between two documents. No JavaScript, no client router: each
/// page is still a plain document, and a browser without view transitions
/// (or with `prefers-reduced-motion`) just navigates.
///
/// The page being opened decides: its rules style the snapshot of the page
/// it leaves (`::view-transition-old`) and its own
/// (`::view-transition-new`). Both pages must opt in, so
/// [PageTransition.none] on either side means no transition.
///
/// Set it for the whole app with `PageNavigation(transition:)`, and for a
/// layout's pages or one page with a `PageTransitionScope` around what it
/// builds (the nearest wins). Elements that should travel between the two
/// pages (a title, a picture) go in a `Hero`.
///
/// ```dart
/// // An article page.
/// Widget build(BuildContext context, PageState<Article> state) =>
///     PageTransitionScope(
///       transition: const PageTransition.slide(),
///       child: ArticleView(state.data),
///     );
/// ```
///
/// `// web:` Flutter's route transitions animate two widget trees in
/// memory; here the browser animates snapshots of two documents. `slide`
/// reverses on a back navigation through a tiny `pagereveal` script (the
/// page can't tell it from CSS alone); without it, or in a browser without
/// the Navigation API, it always moves forward.
@immutable
class PageTransition {
  const PageTransition._(this._kind, this.duration, this.curve);

  /// No transition: this page opts out of view transitions.
  static const none = PageTransition._(_TransitionKind.none, null, null);

  /// The browser's cross-fade. [duration] and [curve] (`null`: the
  /// browser's, 0.25 s ease) apply to every element that transitions,
  /// `Hero`es included.
  const PageTransition.fade({this.duration, this.curve})
    : _kind = _TransitionKind.fade;

  /// The new page slides in from the end while the old one slides out.
  const PageTransition.slide({
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.fastOutSlowIn,
  }) : _kind = _TransitionKind.slide;

  /// The new page rises a quarter of the screen and fades in over the old
  /// one: Flutter's `FadeUpwardsPageTransitionsBuilder`.
  const PageTransition.fadeUp({
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.fastOutSlowIn,
  }) : _kind = _TransitionKind.fadeUp;

  final _TransitionKind _kind;

  /// How long the page (and every `Hero`) takes to move (`null`: the
  /// browser's).
  final Duration? duration;

  /// The easing of every animation of the transition (`null`: the
  /// browser's).
  final Curve? curve;

  /// The inline script a page with this transition needs, or `null`. Only
  /// [PageTransition.slide] has a direction: on `pagereveal` it adds the
  /// view-transition type `back` when the page is reached by traversing the
  /// history to an earlier entry (Navigation API `activation`, so Chromium;
  /// elsewhere the slide stays forward). No transition, no effect.
  String? get script => _kind == _TransitionKind.slide ? _backScript : null;

  static const _backScript =
      'addEventListener("pagereveal",function(e){var a=window.navigation&&'
      'navigation.activation;if(e.viewTransition&&a&&a.navigationType==='
      '"traverse"&&a.from&&a.entry.index<a.from.index)'
      'e.viewTransition.types.add("back")})';

  /// The page rules: `@view-transition` and its pseudo-elements, all under
  /// `prefers-reduced-motion: no-preference` and `scripting: enabled`;
  /// `null` for [none].
  String? get css => _css[this] ??= _render();

  static final _css = <PageTransition, String?>{};

  String? _render() {
    if (_kind == _TransitionKind.none) return null;
    // The transition's overlay never takes a click: it goes to the new
    // page, already live underneath (a fast visitor or test clicks during
    // the animation).
    final out = StringBuffer(
      '{@view-transition{navigation:auto}'
      '::view-transition{pointer-events:none}',
    );
    final timing = [
      if (duration case final d?) 'animation-duration:${cssDuration(d)}',
      if (curve case final c?) 'animation-timing-function:${c.css}',
    ];
    if (timing.isNotEmpty) {
      // A group's snapshots inherit its timing (the browser's own rules).
      out.write('::view-transition-group(*){${timing.join(';')}}');
    }
    switch (_kind) {
      case _TransitionKind.slide:
        out
          ..write(
            '@keyframes t-vt-slide-out{to{transform:translateX(-30%);opacity:0}}',
          )
          ..write(
            '@keyframes t-vt-slide-in{from{transform:translateX(30%);opacity:0}}',
          )
          ..write(
            '::view-transition-old(root){animation-name:t-vt-slide-out;'
            'mix-blend-mode:normal}'
            '::view-transition-new(root){animation-name:t-vt-slide-in;'
            'mix-blend-mode:normal}',
          )
          // Back: the same motion mirrored, under the `back` type that
          // [script] adds on a traversal to an earlier entry. One rule per
          // selector: a browser without the pseudo-class drops only these.
          ..write(
            '@keyframes t-vt-slide-out-back{to{transform:translateX(30%);opacity:0}}',
          )
          ..write(
            '@keyframes t-vt-slide-in-back{from{transform:translateX(-30%);opacity:0}}',
          )
          ..write(
            ':root:active-view-transition-type(back)::view-transition-old(root)'
            '{animation-name:t-vt-slide-out-back}',
          )
          ..write(
            ':root:active-view-transition-type(back)::view-transition-new(root)'
            '{animation-name:t-vt-slide-in-back}',
          );
      case _TransitionKind.fadeUp:
        out
          ..write(
            '@keyframes t-vt-fade-up{from{transform:translateY(25%);opacity:0}}',
          )
          ..write(
            // The old page stays under the new one, as in Flutter.
            '::view-transition-old(root){animation:none;mix-blend-mode:normal}'
            '::view-transition-new(root){animation-name:t-vt-fade-up;'
            'mix-blend-mode:normal}',
          );
      case _TransitionKind.fade || _TransitionKind.none:
        break;
    }
    out.write('}');
    // Only with scripting: a transition is an enhancement, and with
    // scripting off the browser renders no frame while it runs, so a click
    // made during it never lands. Without it navigation is instant.
    return '@media (prefers-reduced-motion:no-preference) and '
        '(scripting:enabled)$out';
  }

  @override
  bool operator ==(Object other) =>
      other is PageTransition &&
      other._kind == _kind &&
      other.duration == duration &&
      other.curve == curve;

  @override
  int get hashCode => Object.hash(_kind, duration, curve);

  @override
  String toString() => 'PageTransition.${_kind.name}';
}

/// Marks a page rendered by the router (one document of a multi-page app):
/// a `ThorApp` without `navigation` below it uses the default
/// [PageNavigation]. `WidgetRenderer` puts it there.
class RoutedPageScope extends InheritedWidget implements InheritedMemoKey {
  /// Marks [child] as a routed page.
  const RoutedPageScope({super.key, required super.child});

  /// Whether [context] is inside a routed page.
  static bool isRouted(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RoutedPageScope>() != null;

  @override
  bool updateShouldNotify(RoutedPageScope oldWidget) => false;

  /// Readers only see that it is there.
  @override
  Object? get memoKey => RoutedPageScope;
}

/// The timing of an `AnimatedSwitcher` as its element carries it
/// ([switcherAttr]): the incoming state's duration and easing, then the
/// outgoing one's.
String switcherTiming({
  required Duration duration,
  Duration? reverseDuration,
  Curve switchInCurve = Curves.linear,
  Curve switchOutCurve = Curves.linear,
}) =>
    '${cssDuration(duration)}|${switchInCurve.css}|'
    '${cssDuration(reverseDuration ?? duration)}|${switchOutCurve.css}';

/// The page rules of in-page view transitions ([switcherAttr]) for the
/// timings [keys] ([switcherTiming]). They only match while the engine
/// runs one (it puts the key on the document element), so they never
/// touch a page transition. The rest of the page changes at once (the
/// `root` snapshot doesn't fade, and its named elements are left out);
/// the switcher's own element
/// cross-fades or morphs, and every `Hero` inside it glides to its new
/// place.
String switcherCss(Iterable<String> keys) {
  const on = ':root[$switcherAttr]';
  final out = StringBuffer(
    // The overlay never takes a click (the page is live underneath).
    '$on::view-transition{pointer-events:none}'
    '$on::view-transition-old(root){animation:none;opacity:0}'
    '$on::view-transition-new(root){animation:none}'
    '$on [$switcherAttr]{view-transition-name:match-element}'
    // Nothing else of the page takes part: a name the app gave for its page
    // transitions (a layout's main area) would be captured and animate the
    // whole page as if it navigated. A Hero's inline name still wins.
    '$on :not([$switcherAttr]:not(:root),[$switcherAttr]:not(:root) *)'
    '{view-transition-name:none}',
  );
  for (final key in keys) {
    final parts = key.split('|');
    // Only what switcherTiming writes: no quote, brace or escape.
    if (parts.length != 4 || key.contains(RegExp(r'["\\{};<>]'))) continue;
    final at = ':root[$switcherAttr="$key"]';
    out.write(
      '$at::view-transition-group(*),$at::view-transition-new(*)'
      '{animation-duration:${parts[0]};animation-timing-function:${parts[1]}}'
      '$at::view-transition-old(*)'
      '{animation-duration:${parts[2]};animation-timing-function:${parts[3]}}',
    );
  }
  return out.toString();
}

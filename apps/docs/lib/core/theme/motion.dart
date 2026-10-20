/// The site's own motion, as page rules: the frame staying put while the
/// page changes (the old page fades out in 90 ms, the new one in over
/// 120 ms), and the theme fading instead of flashing. Everything else that moves (hover, press, folding, the drawer,
/// the bench) belongs to the studio's components and follows its motion
/// tokens. All CSS (the site ships no framework JavaScript); with
/// `prefers-reduced-motion` nothing moves.
library;

import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/html.dart' show css;
import 'package:thor_ui/thor_ui.dart';

import 'docs_theme.dart';

/// How long a page change takes (the app's `PageTransition.fade`): the
/// groups of the frame and the page's snapshots run on it.
const docsPageFade = Duration(milliseconds: 150);

/// The page that goes: a quick fade (90 ms), so the next one is not seen
/// through it.
const _leave = CssAnimation(
  'docs-leave',
  Duration(milliseconds: 90),
  curve: StudioCurves.enter,
  fill: AnimationFill.both,
);

/// The page that arrives: its fade (120 ms).
const _arrive = CssAnimation(
  'docs-arrive',
  StudioDurations.fast,
  curve: StudioCurves.enter,
  fill: AnimationFill.both,
);

/// The sidebar's group between pages: it keeps the group's timing (its
/// snapshots cross-fade on it, so only the current-page marker changes) but
/// moves nothing. The browser's own animation would carry the old sidebar
/// from where it was to where the new page has it: from a page's end (the
/// prev/next cards) the sticky list was pushed up by the footer, and the
/// whole list slid down the window.
const _still = CssAnimation('docs-still', docsPageFade);

/// The rules.
final List<StyleRule> motionStyles = [
  css.keyframes('docs-leave', {'to': const StyleProps(opacity: 0)}),
  css.keyframes('docs-arrive', {'from': const StyleProps(opacity: 0)}),
  css.keyframes('docs-still', const {}),
  // Between pages (the app opts in: `PageTransition.fade` in app.dart): the
  // top bar and the sidebar are captured on their own, so they do not fade
  // with the page; the phone drawer (a <dialog> in the top layer) is
  // captured with them instead of cross-fading over the next page.
  // `:where()` keeps the id from outranking the framework's rule that
  // leaves every name out of an in-page switch (an `AnimatedSwitcher`):
  // with the id's weight the sidebar was captured and redrawn on each one.
  css('header').props(const StyleProps(viewTransitionName: 'docs-bar')),
  css(
    ':where(#studio-sidebar)',
  ).props(const StyleProps(viewTransitionName: 'docs-nav')),
  // From the column's width the sidebar is a column as tall as the page with
  // a sticky list in it: what shows is the list, so the list is captured.
  // The column's snapshot (thousands of pixels, the list somewhere in it)
  // was placed by its top, which a scrolled page has far above the window.
  css.media('screen and (min-width: ${docsBreakpoints.expanded.toInt()}px)', [
    css(
      ':where(#studio-sidebar)',
    ).props(const StyleProps(viewTransitionName: 'none')),
    css(
      ':where(#studio-sidebar [data-studio-sidebar-scroll])',
    ).props(const StyleProps(viewTransitionName: 'docs-nav')),
  ]),
  css(
    '::view-transition-group(docs-nav)',
  ).props(const StyleProps(animation: [_still])),
  // The rest (content, contents list, footer): out fast, in a little slower,
  // not blended (`plus-lighter` would double the brightness of what both
  // pages share). The same guard `PageTransition` writes for its own rules.
  css.media(
    '(prefers-reduced-motion: no-preference) and (scripting: enabled)',
    [
      css('::view-transition-old(root)').props(
        const StyleProps(animation: [_leave], mixBlendMode: BlendMode.srcOver),
      ),
      css('::view-transition-new(root)').props(
        const StyleProps(animation: [_arrive], mixBlendMode: BlendMode.srcOver),
      ),
    ],
  ),

  // The theme change as a cross-fade, not a flash.
  ...StudioMotionStyles.themeFade,
];

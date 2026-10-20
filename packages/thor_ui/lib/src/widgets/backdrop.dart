import 'package:thor_style/thor_style.dart' show Color;

import '../core/core.dart' show BuildContext;

import '../foundation/style_registry.dart'
    show ConditionalCss, CssCondition, ThorStyleRegistry;

/// Locks the document's scroll while a modal `<dialog>` is open, and keeps
/// the scroll of the dialog itself from chaining to the page.
///
/// `// web:` Flutter has no page scroll to lock: a route covers the
/// `Scaffold`'s body and a gesture on it never reaches the page below. A
/// browser page scrolls under a modal `<dialog>` (the top layer only makes
/// the rest inert), so every modal panel (`Drawer`, `AlertDialog`, `Dialog`,
/// `ModalBottomSheet`, the date pickers) registers this one page rule:
///
/// - `overflow: hidden` on the root while any `dialog:modal` exists: the
///   wheel and touch have nothing to scroll; `scrollbar-gutter: stable`
///   keeps the page from shifting where the scrollbar takes space.
/// - `overscroll-behavior: none` on the root as well: touch browsers that
///   ignore `overflow: hidden` on the root for a gesture (older iOS Safari)
///   still do not chain or rubber-band the page behind.
/// - [modalOverscroll] on the dialog (its own scroll container): a long
///   panel scrolls inside and never hands the gesture over at its ends.
///
/// Pure CSS, shipped only on the pages that have a modal panel (rule 4).
/// An inline `Drawer(permanentFrom:)` is not `:modal`, so it locks nothing.
void lockScrollWhileModal(BuildContext context) {
  ThorStyleRegistry.active(
    context,
  )?.classFor(const {}, conditions: const [modalScrollLock]);
}

/// The one page rule of [lockScrollWhileModal].
const modalScrollLock = ConditionalCss(
  CssCondition.page(':root:has(dialog:modal)'),
  {
    'overflow': 'hidden',
    'scrollbar-gutter': 'stable',
    'overscroll-behavior': 'none',
  },
);

/// The dialog's own scroll stays in it (see [lockScrollWhileModal]).
const modalOverscroll = {'overscroll-behavior': 'contain'};

/// The dimmed page behind a modal panel that slides (`Drawer`,
/// `ModalBottomSheet`), fading in and out with the panel instead of
/// appearing and vanishing at once: on close it would otherwise stay fully
/// dark for the whole slide (on a phone, while the next page loads).
///
/// Needs the panel's own `display`/`overlay` transition (it keeps the panel,
/// and so its backdrop, in the top layer until the fade ends).
List<ConditionalCss> fadingBackdrop(String duration, {Color? color}) => [
  ConditionalCss(const CssCondition.selector('::backdrop'), {
    'background-color': 'rgba(0, 0, 0, 0)',
    'transition':
        'background-color $duration, '
        'overlay $duration allow-discrete, display $duration allow-discrete',
  }),
  ConditionalCss(const CssCondition.selector('[open]::backdrop'), {
    'background-color': color?.css ?? 'rgba(0, 0, 0, 0.32)',
  }),
  const ConditionalCss(CssCondition.startingStyle('[open]::backdrop'), {
    'background-color': 'rgba(0, 0, 0, 0)',
  }),
];

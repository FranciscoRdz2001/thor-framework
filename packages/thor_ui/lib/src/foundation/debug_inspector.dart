// No imports: the browser tests load it alone (dart2js can't compile
// the rest of the render core, which reaches the server).

/// Debug-only runtime checks, the web counterpart of Flutter's layout
/// errors: it outlines and logs overflowing Rows/Columns ("A RenderFlex
/// overflowed…"), Expanded/Flexible outside a flex ("Incorrect use of
/// ParentDataWidget"), and zero-width LayoutScopes (unbounded
/// LayoutBuilder). Re-runs on resize and DOM changes. Never emitted in release.
///
/// An overflow is how far the children's boxes (with their margins) pass
/// the flex's content box on its main axis, at either end (a reversed or
/// RTL flex overflows at the start). Not `scrollWidth`/`scrollHeight`: a
/// text with a tight line-height (a 44px heading on 50px lines) spills its
/// glyphs out of its own line box, which scrolls but lays nothing out of
/// place. Nor the painted box (`getBoundingClientRect`): a transform moves
/// the paint, not the layout, so the boxes come from the offsets.
const debugInspectorScript = r"""
(() => {
  const mark = 'data-thor-warning';
  const run = () => {
    for (const e of document.querySelectorAll('[' + mark + ']')) {
      e.style.outline = ''; e.removeAttribute(mark);
    }
    const px = (v) => parseFloat(v) || 0;
    const boxes = (e) => [...e.children].flatMap((k) => {
      const ks = getComputedStyle(k);
      if (ks.display === 'contents') return boxes(k);
      if (ks.display === 'none' || ks.position === 'absolute' || ks.position === 'fixed') return [];
      return [[k, ks]];
    });
    // The layout box, in the same frame for the flex and its children: the
    // offset chain ignores every transform (translate, rotate, scale), which
    // moves the paint and not the layout (a Flutter Transform, a spinning
    // CircularProgressIndicator, a SlideTransition mid-entrance). An SVG has
    // no offsets: its box goes relative to the flex's painted one.
    const at = (n) => {
      let x = n.offsetLeft, y = n.offsetTop;
      for (let p = n.offsetParent; p; p = p.offsetParent) {
        x += p.offsetLeft + p.clientLeft; y += p.offsetTop + p.clientTop;
      }
      return { left: x, top: y, right: x + n.offsetWidth, bottom: y + n.offsetHeight };
    };
    const laid = (e, k) => {
      const f = at(e);
      if (k.offsetWidth !== undefined) return at(k);
      const [q, r] = [k.getBoundingClientRect(), e.getBoundingClientRect()];
      return { left: f.left + q.left - r.left, top: f.top + q.top - r.top,
        right: f.left + q.right - r.left, bottom: f.top + q.bottom - r.top };
    };
    const overflow = (e, cs, row) => {
      const r = at(e);
      const start = row
        ? r.left + px(cs.borderLeftWidth) + px(cs.paddingLeft)
        : r.top + px(cs.borderTopWidth) + px(cs.paddingTop);
      const end = row
        ? r.right - px(cs.borderRightWidth) - px(cs.paddingRight)
        : r.bottom - px(cs.borderBottomWidth) - px(cs.paddingBottom);
      let over = 0;
      for (const [k, ks] of boxes(e)) {
        const q = laid(e, k);
        const near = row ? q.left - px(ks.marginLeft) : q.top - px(ks.marginTop);
        const far = row ? q.right + px(ks.marginRight) : q.bottom + px(ks.marginBottom);
        over = Math.max(over, far - end, start - near);
      }
      return Math.round(over);
    };
    const warn = (e, msg) => {
      if (e.hasAttribute(mark)) return;
      console.warn('thor: ' + msg, e);
      e.style.outline = '2px dashed #e11d48';
      e.setAttribute(mark, msg);
    };
    for (const e of document.querySelectorAll('[data-thor=Row], [data-thor=Column], [data-thor=Flex]')) {
      // Not laid out (a closed dialog, a hidden breakpoint): its empty
      // box minus its padding would read as an overflow.
      if (!e.getClientRects().length) continue;
      const cs = getComputedStyle(e);
      const row = cs.flexDirection.startsWith('row');
      // A flex that scrolls on its own (ListView, a pinned sidebar) holds
      // more than it shows on purpose: not an overflow.
      if (/auto|scroll/.test(row ? cs.overflowX : cs.overflowY)) continue;
      const over = overflow(e, cs, row);
      if (over > 1) warn(e, 'A ' + (row ? 'Row' : 'Column') + ' overflowed by ' + over + 'px. Wrap the long child in Expanded or Flexible. (THOR-L001)');
    }
    for (const e of document.querySelectorAll('[data-thor-flex-item]')) {
      const p = e.parentElement;
      // Hidden (a breakpoint's ResponsiveVisibility): nothing is laid out.
      if (p && p.offsetParent === null && getComputedStyle(p).position !== 'fixed') continue;
      if (p && !getComputedStyle(p).display.includes('flex')) warn(e, 'Expanded/Flexible is not a direct child of a Row, Column or Flex (incorrect use of ParentDataWidget). (THOR-L002)');
    }
    // A text field a screen reader announces with no name: thor wraps the
    // input in an empty label element, so just `aria-label` (labelText,
    // hintText, Semantics), a label with text (`for` or around it),
    // `aria-labelledby` or `title` name it. A Text written beside the field
    // names nothing.
    const bare = new Set(['hidden', 'submit', 'button', 'reset', 'image', 'checkbox', 'radio', 'file', 'range', 'color']);
    const said = (l) => {
      if ((l.getAttribute('aria-label') || '').trim()) return true;
      // thor's own wrapper holds prefix/suffix text ('$ ', 'kg'), no name.
      if (l.getAttribute('data-thor') === 'TextField') return false;
      const c = l.cloneNode(true);
      for (const k of c.querySelectorAll('input, textarea, select')) k.remove();
      return c.textContent.trim() !== '';
    };
    for (const e of document.querySelectorAll('[data-thor=TextField] input, [data-thor=TextField] textarea')) {
      if (bare.has(e.type)) continue;
      const attr = (n) => (e.getAttribute(n) || '').trim();
      if (attr('aria-label') || attr('aria-labelledby') || attr('title')) continue;
      if ([...(e.labels || [])].some(said)) continue;
      warn(e, 'A text field has no accessible name: a screen reader announces just "edit text". Give it InputDecoration(labelText:) or hintText:, or wrap it in Semantics(label:). A Text beside it names nothing. (THOR-L004)');
    }
    for (const e of document.querySelectorAll('[data-thor=LayoutScope]')) {
      if (e.getBoundingClientRect().width === 0 && e.offsetParent) warn(e, 'LayoutScope has zero width: it needs a bounded width (e.g. inside Expanded). (THOR-L003)');
    }
  };
  let timer;
  const schedule = () => { clearTimeout(timer); timer = setTimeout(run, 150); };
  addEventListener('load', () => document.fonts.ready.then(run));
  addEventListener('resize', schedule);
  new MutationObserver(schedule).observe(document.documentElement, {
    subtree: true, childList: true, attributes: true, attributeFilter: ['class'],
  });
})();
""";

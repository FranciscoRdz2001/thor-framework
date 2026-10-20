import 'package:thor_style/thor_style.dart';

/// The height reserved for a row that has not been rendered yet when the app
/// gives no `itemExtent` (the browser remembers the real one afterwards).
const double lazyRowEstimate = 40;

/// `content-visibility: auto` + `contain-intrinsic-size`, the CSS that makes
/// the browser skip style, layout and paint of what is off screen. Server
/// precompiled: no JS, and the rows stay in the DOM (find in page, SEO).
CssDeclarations lazyLayoutCss(bool on, double estimate) => {
  if (on) ...{
    'content-visibility': 'auto',
    'contain-intrinsic-size': 'auto ${cssPx(estimate)}',
  },
};

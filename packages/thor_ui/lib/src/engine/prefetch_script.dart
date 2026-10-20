/// The prefetch fallback for browsers without Speculation Rules (Firefox,
/// Safari): `<link rel=prefetch>` on hover or focus.
///
/// Two pieces, so Chromium (which has the rules) pays almost nothing:
/// [prefetchLoaderScript], a constant inline test in every page that has
/// rules, loads the file only where `<script type=speculationrules>` is not
/// supported, after `load`; [prefetchScript] is that file, made from the
/// app's `PageNavigation` (`/_thor/prefetch.<hash>.js`).
library;

/// The attribute of the inline loader that holds the file's URL.
const prefetchSrcAttr = 'data-thor-prefetch';

/// The inline test behind the fallback: a constant text (its hash is in
/// `docs/guia/es/sesion-y-seguridad.md`, `csp_hashes_test.dart`).
const prefetchLoaderScript =
    '(()=>{var d=document,u=d.currentScript.getAttribute("$prefetchSrcAttr");'
    'HTMLScriptElement.supports&&HTMLScriptElement.supports("speculationrules")'
    '||addEventListener("load",()=>{var s=d.createElement("script");'
    's.src=u;d.head.append(s)})})()';

/// Most prefetches in flight at once.
const _inFlight = 3;

/// The fallback file: waits [hoverDelay] ms on a hovered or focused link
/// (`null`: only a press, the `conservative` eagerness), skips what the
/// rules skip ([excludedLinks], the selector of the links left out, and
/// [exclude], regular expressions of the path), `Save-Data` and
/// `prefers-reduced-data`, action URLs (`?/name`), another origin and the
/// current page, and keeps at most three in flight.
String prefetchScript({
  required int? hoverDelay,
  required String excludedLinks,
  required List<String> exclude,
}) {
  final hover = hoverDelay == null
      ? ''
      : 'd.addEventListener("pointerover",e=>{var a=A(e);clearTimeout(t);'
            'a&&e.pointerType!=="touch"&&(t=setTimeout(()=>G(a),$hoverDelay))},!0);'
            'd.addEventListener("pointerout",()=>clearTimeout(t),!0);'
            // Its own timer: a pointer that moves while the keyboard waits
            // (a scroll under it) must not cancel the focus.
            'd.addEventListener("focusin",e=>{var a=A(e);clearTimeout(u);'
            'a&&(u=setTimeout(()=>G(a),$hoverDelay))},!0);'
            'd.addEventListener("focusout",()=>clearTimeout(u),!0);';
  return '(()=>{var d=document,L=location,n=0,t,u,s={},c=navigator.connection,'
      'Z=[${exclude.join(',')}];'
      'if(c&&c.saveData||matchMedia("(prefers-reduced-data:reduce)").matches)'
      'return;'
      'var A=e=>e.target.closest&&e.target.closest("a[href]"),'
      'G=a=>{var k=a.pathname+a.search;'
      'if(n<$_inFlight&&a.origin===L.origin&&!s[k]&&k!==L.pathname+L.search'
      '&&a.search.slice(0,2)!=="?/"&&!a.matches(${_js(excludedLinks)})'
      '&&!Z.some(r=>r.test(a.pathname))){s[k]=1;n++;'
      'var l=d.createElement("link"),o=1,f=()=>{o&&(o=0,n--)};'
      'l.onload=l.onerror=()=>{f();l.remove()};setTimeout(f,3e3);'
      'l.rel="prefetch";l.href=a.href;d.head.append(l)}};'
      '$hover'
      'd.addEventListener("pointerdown",e=>{var a=A(e);a&&G(a)},!0)})()';
}

/// A JavaScript string literal of [v].
String _js(String v) => '"${v.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

/// The regular expression (a JavaScript literal) of a `URLPattern` path
/// like `/admin/*` or `/item/:id`: `*` is anything, `:name` one segment.
/// `null` for a pattern that is not a path.
String? patternToRegExp(String pattern) {
  if (!pattern.startsWith('/')) return null;
  final out = StringBuffer('^');
  for (var i = 0; i < pattern.length; i++) {
    final ch = pattern[i];
    if (ch == '*') {
      out.write('.*');
    } else if (ch == ':' &&
        i + 1 < pattern.length &&
        RegExp(r'\w').hasMatch(pattern[i + 1])) {
      out.write('[^/]+');
      while (i + 1 < pattern.length && RegExp(r'\w').hasMatch(pattern[i + 1])) {
        i++;
      }
    } else if (r'\^$.|?+()[]{}/'.contains(ch)) {
      out.write('\\$ch');
    } else {
      out.write(ch);
    }
  }
  return '/$out\$/';
}

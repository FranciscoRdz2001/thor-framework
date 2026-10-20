/// The script of an `ExpansionTile(permanentFrom:)` page, inlined
/// at the end of the `<body>`: from the breakpoint up the tile is an open
/// block and its header must not be a Tab stop, which CSS alone can't say.
/// The script puts `tabindex="-1"` on the header while the viewport is at
/// least the tile's `data-thor-pf` pixels wide and takes it off below (it
/// follows the media query), only where the browser has `::details-content`
/// (without it the tile stays an accordion at every width and its header
/// must stay reachable). Engine-free, so it works with either engine and with
/// none; it fires again for the nodes a late part brings (`thor:stream`).
///
/// `// web:` a screen reader still calls the header a (disclosure) button:
/// nothing here changes how the browser exposes a `<summary>`.
///
/// A constant text: its hash is in `docs/guia/es/sesion-y-seguridad.md`
/// (`csp_hashes_test.dart`).
const permanentScript =
    r"""(function(){var D=document,A='data-thor-pf';if(!(window.CSS&&CSS.supports&&CSS.supports('selector(::details-content)')))return;function one(d){if(d._pf)return;d._pf=1;var s=d.querySelector(':scope>summary'),m=matchMedia('screen and (min-width:'+d.getAttribute(A)+'px)');if(!s)return;function f(){m.matches?s.setAttribute('tabindex','-1'):s.removeAttribute('tabindex')}f();m.addEventListener('change',f)}function scan(r){(r.matches&&r.matches('['+A+']')?[r]:[]).concat([].slice.call(r.querySelectorAll('['+A+']'))).forEach(one)}D.documentElement.addEventListener('thor:stream',function(e){((e.detail&&e.detail.nodes)||[]).forEach(function(n){n.nodeType==1&&scan(n)})});scan(D)})();""";

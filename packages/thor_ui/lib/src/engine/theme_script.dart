/// The script that remembers the visitor's light/dark choice, inlined first
/// in the `<head>` of a page with the theme switch (`ThorApp(darkTheme:)`).
/// Engine-free (it works with any engine and with none).
///
/// The switch is the hidden checkbox `#thor-theme`; checked means «the
/// other scheme than the system's». The script keeps the scheme the visitor
/// sees (`dark`/`light`) in `localStorage['thor:theme']` on every change,
/// and, before the first paint, sets the checkbox as soon as the parser
/// creates it (a `MutationObserver` runs before the browser paints). Blocked
/// storage throws: every access is in `try`/`catch`, and the page then works
/// per view, as with no script. A constant text: its hash is in
/// `docs/guia/es/sesion-y-seguridad.md` (`csp_hashes_test.dart`).
///
/// The stored choice wins over the system: when the system's preference
/// changes, the checkbox is recomputed against the new one. A choice made in
/// another tab (`storage` event) is applied here without a reload, and
/// clearing the storage returns to the system.
const themeScript =
    r"""(()=>{const D=document,m=matchMedia('(prefers-color-scheme: dark)'),I='thor-theme',K='thor:theme',g=()=>{try{const c=localStorage.getItem(K);return c==='dark'||c==='light'?c:null}catch{return null}},s=(r)=>{const c=g(),i=D.getElementById(I);if(i&&(c||r))i.checked=!!c&&(c==='dark')!==m.matches;return i;};if(g()){const o=new MutationObserver(()=>s()&&o.disconnect());o.observe(D.documentElement,{childList:true,subtree:true});D.addEventListener('DOMContentLoaded',()=>{o.disconnect();s();});}m.addEventListener('change',()=>s());addEventListener('storage',(e)=>{if(e.key===K||e.key===null)s(1);});D.addEventListener('change',(e)=>{const t=e.target;if(t.id===I)try{localStorage.setItem(K,t.checked!==m.matches?'dark':'light');}catch{}});})();""";

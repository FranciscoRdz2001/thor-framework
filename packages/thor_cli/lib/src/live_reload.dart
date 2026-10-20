/// The script `thor dev` puts in every page (see `DevProxy`). No `dart:io`:
/// the browser tests load it too.
library;

/// Where pages listen for reloads (server-sent events).
const liveReloadEventsPath = '/__thor/events';

/// `sessionStorage` key prefix (plus `location.pathname`) of a page's
/// scroll across a reload.
const liveReloadScrollKey = 'thor:scroll:';

/// Key prefix of a page's changed form fields and focus.
const liveReloadFormKey = 'thor:form:';

/// Key prefix of a page's `ThorState` values: written from the engine's
/// `__thorDevState`, read by the engine itself (thor_engine's
/// `devStateKey`: keep them equal).
const liveReloadStateKey = 'thor:state:';

/// [liveReloadScript] for a page served when the pages' version was [stamp]
/// (`DevProxy.stamp`): the page compares it with what the proxy says when
/// it connects, so a change that happened while it was loading (a reload
/// that reached the old page, a problem that came right after) still
/// reloads it. Without a stamp the first `hello` is the baseline.
String liveReloadScriptFor(String stamp) {
  assert(liveReloadScript.contains(_baseline));
  return liveReloadScript.replaceFirst(_baseline, "let run='$stamp';");
}

const _baseline = 'let run=null;';

/// The script pages get in development: reload when the app changes (or
/// when a newer `thor dev` run answers) and come back as they were.
///
/// Before reloading it stores, per tab (`sessionStorage`) and per path:
/// - the scroll;
/// - the fields the user changed (`input`, `textarea`, `select` with an
///   `id` or a `name`; not passwords, hidden or file inputs, nor fields a
///   `Watch` fills) and the focused one, with its selection;
/// - the `ThorState` values, from the engine (`thor dev` compiles it with
///   `-Dthor.dev=true`, which exposes `__thorDevState`).
///
/// After the reload each one is taken back once. While the engine restores
/// the state the page stays hidden (at most 1.5 s), so it never paints the
/// server's values first; the engine is asked to load right away instead of
/// on idle. A page without the engine (the error page of a build that
/// failed) leaves the stored values for the next page that has one.
const liveReloadScript =
    '<script id="thor-live-reload">(()=>{'
    'const d=document,h=d.documentElement,p=location.pathname,'
    "K='$liveReloadScrollKey'+p,F='$liveReloadFormKey'+p,"
    "S='$liveReloadStateKey'+p,"
    // sessionStorage can be missing or throw (sandboxed frames, quota).
    'G=f=>{try{return f(sessionStorage)}catch(e){}},'
    "C='input,textarea,select',"
    "N=['password','hidden','file','submit','button','reset','image'],"
    // Fields a Watch fills (data-tt) or a list row renders (data-tf) come
    // back with the state.
    "ok=e=>!N.includes(e.type)&&!e.matches('[data-tt],[data-tf]'),"
    // A field's key: its id; else its name (+ value for radios and
    // checkboxes, + position among same-named fields).
    "key=e=>e.id?'#'+e.id:!e.name?null:"
    "e.type=='radio'||e.type=='checkbox'?e.name+'='+e.value:"
    "e.name+'@'+[...d.getElementsByName(e.name)].indexOf(e),"
    'all=()=>[...d.querySelectorAll(C)].filter(ok),'
    "box=e=>e.type=='checkbox'||e.type=='radio',"
    "sel=e=>e.tagName=='SELECT',"
    // Scroll.
    'y=G(s=>s.getItem(K));'
    'if(y!=null){G(s=>s.removeItem(K));'
    "addEventListener('load',()=>scrollTo(0,+y));}"
    // Fields and focus: only what the user changed from the page's
    // defaults (a default changed in the code shows).
    'const r=G(s=>s.getItem(F));'
    'if(r!=null){let o=null,n=0;try{o=JSON.parse(r)}catch(e){}'
    'if(o&&o.f){const m=new Map(all().map(e=>[key(e),e]));'
    'for(const k in o.f){const e=m.get(k),v=o.f[k];if(!e)continue;'
    "if(box(e)){if(typeof v=='boolean'){e.checked=v;n++}}"
    'else if(sel(e)){if(Array.isArray(v)&&v.length==e.options.length)'
    '{v.forEach((x,i)=>e.options[i].selected=!!x);n++}}'
    "else if(typeof v=='string'){e.value=v;n++}}"
    "const a=o.a&&(o.a[0]=='#'?d.getElementById(o.a.slice(1)):m.get(o.a));"
    'if(a&&a.focus){a.focus({preventScroll:true});n++;'
    'try{if(o.s)a.setSelectionRange(o.s[0],o.s[1])}catch(e){}}}'
    // Nothing here to fill (an error page): keep them for the next one.
    'if(n||!o)G(s=>s.removeItem(F))}'
    // State: hidden until the engine restored it (next frame after
    // hydration), and the engine loads now rather than on idle.
    "if(G(s=>s.getItem(S))!=null&&d.querySelector('script[data-thor-engine],"
    "script[src*=\"engine\"]')){"
    "const u=()=>h.style.removeProperty('visibility');"
    "h.style.visibility='hidden';"
    "d.addEventListener('thor:hydrated',()=>requestAnimationFrame(u),"
    '{once:true});setTimeout(u,1500);'
    "dispatchEvent(new Event('pointerdown'))}"
    'let run=null;let es=null;'
    'const go=()=>{G(s=>s.setItem(K,String(scrollY)));'
    'const f={};for(const e of all()){const k=key(e);if(!k)continue;'
    'if(box(e)){if(e.checked!=e.defaultChecked)f[k]=e.checked}'
    'else if(sel(e)){const v=[...e.options].map(o=>o.selected);'
    'if([...e.options].some(o=>o.selected!=o.defaultSelected))f[k]=v}'
    'else if(e.value!=e.defaultValue)f[k]=e.value}'
    'const a=d.activeElement,'
    "ak=a&&a!=d.body&&a.matches?(a.id?'#'+a.id:a.matches(C)&&ok(a)?key(a):null):null,"
    'o={f};if(ak){o.a=ak;'
    "try{if(typeof a.selectionStart=='number')o.s=[a.selectionStart,a.selectionEnd]}catch(e){}}"
    'if(ak||Object.keys(f).length)G(s=>s.setItem(F,JSON.stringify(o)));'
    // The engine's snapshot; a page without it keeps the stored one.
    'const t=window.__thorDevState;'
    "if(typeof t=='function')G(s=>s.setItem(S,t()));"
    'location.reload();};'
    // One connection per visible tab: HTTP/1.1 allows 6 per host, and a 7th
    // tab's page would wait forever. A hidden tab closes its own; showing
    // it again, the `hello` of the new one says if it missed a change.
    "const on=()=>{if(es)return;es=new EventSource('$liveReloadEventsPath');"
    "es.addEventListener('hello',e=>{if(run!==null&&e.data!==run)go();"
    'run=e.data;});'
    "es.addEventListener('reload',go)},"
    'off=()=>{if(es){es.close();es=null}},'
    'vis=()=>d.hidden?off():on();'
    "d.addEventListener('visibilitychange',vis);vis();"
    '})();</script>';

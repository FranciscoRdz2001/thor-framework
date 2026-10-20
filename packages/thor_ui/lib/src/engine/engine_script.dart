import 'package:thor_engine/thor_engine.dart'
    show
        clearAttr,
        enterEvent,
        hydratedEvent,
        intentShortcutsAttr,
        keyEventAttr,
        onAttr,
        shortcutsAttr;

import '../core/core.dart';
import '../foundation/child_rules.dart' show ThorBuiltIn;

/// When the browser runs the page's engine script.
enum EngineLoading {
  /// A plain `<script defer>`: runs right after parsing, before `load`.
  /// Use it under a strict Content Security Policy (no inline scripts).
  eager,

  /// Loads the script when the main thread goes idle after `load`, or on the first
  /// `pointerdown`/`keydown`/`focusin`/`touchstart`, whichever comes first.
  /// Interactions on engine-handled elements before it is ready are queued
  /// and replayed once it hydrates, so no tap is lost.
  onIdle,
}

/// The `<script>` that starts `thor_engine` on a page (put it in
/// `Document(head: [...])`).
///
/// With [EngineLoading.onIdle] (the default) the engine stays out of the
/// critical path: first paint and the `load` event don't wait for it. A
/// ~1 KB (gzip) inline loader queues `click`, `input`, `change`, `submit`
/// and `keydown` events that reach an element with an engine handler before
/// hydration and replays them afterwards (a replayed click is a plain
/// `Event`, so a native checkbox is not toggled twice; a queued submit is
/// cancelled and re-dispatched). A key is replayed as a clone of the
/// original, with its `key` and modifiers: ⌘K under a `CallbackShortcuts`,
/// Enter in a field with `onSubmitted` and Enter/Space on a `Gesture`
/// (`role="button"`) work from the first press.
///
/// `// web:` until the engine loads, only native behavior runs (links,
/// `<details>`, `<dialog>` with `commandfor` where supported, forms without
/// an engine action).
class EngineScript extends StatelessWidget implements ThorBuiltIn {
  /// Creates the engine's script tag for [src].
  const EngineScript({
    super.key,
    this.src = 'engine.dart.js',
    this.loading = EngineLoading.onIdle,
  }) : _conditional = false;

  /// The engine for a page that needs it for nothing but a carousel's
  /// fallback controls: a tiny inline test loads it only where the browser
  /// draws no `::scroll-button` (Firefox, Safari), at low priority.
  ///
  /// `// web:` a page of only static carousels ships no JavaScript to
  /// Chromium.
  const EngineScript.ifNoNativeCarousel({
    super.key,
    this.src = 'engine.dart.js',
  }) : loading = EngineLoading.onIdle,
       _conditional = true;

  final bool _conditional;

  /// URL of the compiled engine entry (`web/engine.dart` → `engine.dart.js`).
  final String src;

  /// When the script runs.
  final EngineLoading loading;

  @override
  Widget build(BuildContext context) => _conditional
      ? Widget.element(
          tag: 'script',
          attributes: {engineSrcAttr: src},
          children: const [RawText(carouselEngineScript)],
        )
      : switch (loading) {
          EngineLoading.eager => Widget.element(
            tag: 'script',
            attributes: {'src': src, 'defer': ''},
          ),
          // The URL is an attribute, not text inside the script: the export
          // optimizer rewrites it to the content-hashed file by DOM. The preload
          // (`href` is rewritten too) fetches the file at low priority from the
          // start of the page, so it is there when the loader asks for it; a first
          // interaction raises it (see the loader).
          EngineLoading.onIdle => Widget.fragment([
            Widget.element(
              tag: 'link',
              attributes: {
                'rel': 'preload',
                'as': 'script',
                'href': src,
                'fetchpriority': 'low',
              },
            ),
            Widget.element(
              tag: 'script',
              attributes: {engineSrcAttr: src},
              children: const [RawText(engineLoaderScript)],
            ),
          ]),
        };
}

/// The test behind [EngineScript.ifNoNativeCarousel]: where the browser
/// draws the carousel's arrows and dots itself it does nothing.
///
/// `// web:` it does not add the engine a second time when a script for it is
/// already on the page (a streamed piece that needs the engine brings its own
/// loader): Firefox and Safari would run it twice.
const carouselEngineScript =
    '(()=>{var d=document,u=d.currentScript.getAttribute("$engineSrcAttr"),'
    'e=d.createElement("script");'
    'CSS.supports("selector(::scroll-button(*))")||'
    '[].some.call(d.scripts,x=>x.getAttribute("src")==u)||'
    // A failed file is the other loader's to recover from (it reloads the
    // page once, see [engineLoaderScript]): this one only says it failed, so
    // the page that carries no other loader pays for nothing more.
    '(e.src=u,e.fetchPriority="low",'
    'e.onerror=()=>{d._tf=1;d.dispatchEvent(new Event("thor-failed"))},'
    'd.head.append(e))})()';

/// The attribute of the loader `<script>` that holds the engine's URL.
const engineSrcAttr = 'data-thor-engine';

/// The inline loader behind [EngineLoading.onIdle]; it reads the engine's
/// URL from its own [engineSrcAttr].
///
/// If the engine fails to load (a cached page whose content-hashed engine
/// was removed by a newer deploy) it reloads the page once, to get the new
/// HTML with its engine; a `sessionStorage` mark per path prevents loops
/// and is cleared once the engine hydrates.
const engineLoaderScript =
    '(()=>{'
    'var d=document,w=window,c=d.currentScript,'
    'u=c.getAttribute("$engineSrcAttr"),'
    'q=[],P=new Map,s=0,k="thor-reload:"+location.pathname,'
    // sessionStorage can be missing or throw (sandboxed/private contexts).
    'G=f=>{try{return f(w.sessionStorage)}catch(x){}},'
    'T=["pointerdown","keydown","focusin","touchstart"],'
    // What handles keys: shortcuts (both kinds) and `Focus(onKeyEvent:)`.
    'M="[$shortcutsAttr],[$intentShortcutsAttr],[$keyEventAttr]",'
    'E=["click","input","change","submit","keydown"],'
    // Stop intercepting: the browser's own behavior is all there is.
    'X=()=>E.forEach(t=>d.removeEventListener(t,Q,!0)),'
    // The closest `$onAttr` element (from n up) whose spec has type t: the
    // engine's own bubbling, so what it would run is what gets queued.
    'H=(n,t)=>{for(;n&&!(";"+n.getAttribute("$onAttr")).includes(";"+t+":");)n=n.parentElement?.closest("[$onAttr]");return n},'
    // Load once (idle or first sign of interaction). If the engine fails
    // and there is no reload left (or no sessionStorage to count it), the
    // page stays native: a form submits, a link follows.
    // An engine script already on the page (the carousel's conditional loader
    // added it first) is the one that hydrates: not a second download.
    'L=x=>{if(s)return;s=1;T.forEach(t=>w.removeEventListener(t,L,!0));'
    // If that one fails, this loader takes over (with the reload below).
    'if([].some.call(d.scripts,y=>y.getAttribute("src")==u)&&!d._tf){'
    'd.addEventListener("thor-failed",()=>{s=0;L()},{once:!0});return}'
    // An interaction (an event, not the idle callback's deadline) raises the
    // priority of the download, or of the preload already in flight.
    'var e=d.createElement("script");e.src=u;x&&x.type&&(e.fetchPriority="high");'
    'e.onerror=()=>G(S=>{if(!S.getItem(k)){S.setItem(k,1);location.reload();return 1}})||X();'
    'd.head.append(e)},'
    // Queue events that the engine would handle: its own delegation goes up
    // to the closest `$onAttr` element that handles the type. A keydown counts when a
    // shortcut or `onKeyEvent` element (or <body>, if the page has one) sees it, on
    // Enter in a field with an `$enterEvent` handler, or on Enter/Space on a
    // role=button target with handlers; the last two are cancelled like the
    // engine does (no form submit, no page scroll). An Enter keeps the
    // field's value of that moment (a `$clearAttr` field, only what was typed since
    // the previous Enter: the engine would have emptied it in between).
    'Q=e=>{var y=e.type,k=e.key,K=y=="keydown",Z=e.target,n=Z.closest?.("[$onAttr]"),'
    'h=H(n,K?"$enterEvent":y),B=Z==d.body||Z==d.documentElement,'
    'p=K?k=="Enter"&&h||n==Z&&(k=="Enter"||k==" ")&&n.getAttribute("$onAttr")&&n.getAttribute("role")=="button":h;'
    'if(K&&e.isComposing)return;'
    'if(p||K&&(Z.closest?.(M)||B&&d.querySelector(M))){'
    'if(p&&(K||y=="submit"||y=="click"&&h.tagName=="A"&&h.hasAttribute("href")&&!e.button&&!e.ctrlKey&&!e.metaKey&&!e.shiftKey&&!e.altKey&&(!h.target||h.target=="_self")&&!h.hasAttribute("download")))e.preventDefault();'
    'var r=k=="Enter"?Z.value:null,f=r;'
    'if(r!=null&&Z.hasAttribute("$clearAttr")){f=r.startsWith(P.get(Z)||"")?r.slice((P.get(Z)||"").length):r;P.set(Z,r)}'
    'q.push([e,Z,r,f])}};'
    'E.forEach(t=>d.addEventListener(t,Q,!0));'
    'T.forEach(t=>w.addEventListener(t,L,{capture:!0,passive:!0}));'
    // A key is replayed as a clone of the original (`key`, modifiers, `code`),
    // the rest as plain events (a replayed click must not toggle a native
    // checkbox twice). A field holds what it held at each Enter while the
    // engine reads it; afterwards it gets back what was typed since the last
    // Enter (its live value minus that Enter's text, or the live value if the
    // user replaced the text), unless the engine left it alone.
    'd.addEventListener("$hydratedEvent",()=>{'
    'G(S=>S.removeItem(k));X();var W=new Map;'
    'q.forEach(([e,n,v,f])=>{if(v!=null){W.has(n)||W.set(n,[n.value]);W.get(n)[1]=v;n.value=f}'
    'n.dispatchEvent(e.type=="keydown"?new e.constructor(e.type,e):'
    'new Event(e.type,{bubbles:!0,cancelable:!0}))});'
    'W.forEach(([l,c],n)=>n.value=n.value==c?l:l.startsWith(c)?l.slice(c.length):l);'
    'q=[]},{once:!0});'
    // Idle loading waits for `load`, so the engine never delays it.
    'var I=()=>w.requestIdleCallback?requestIdleCallback(L,{timeout:2e3}):setTimeout(L,200);'
    'd.readyState=="complete"?I():w.addEventListener("load",I,{once:!0})'
    '})()';

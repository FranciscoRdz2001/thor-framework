/// The attribute of a `FlutterView` host: the base URL of the Flutter build.
const flutterAttr = 'data-thor-flutter';

/// JSON of the view's `initialData` (absent when null).
const flutterDataAttr = 'data-thor-flutter-data';

/// When the view loads (`eager`, `idle`, `visible`, `interaction`).
const flutterLoadAttr = 'data-thor-flutter-load';

/// Set by the loader: `loading`, `ready` (first frame painted) or `error`.
const flutterStateAttr = 'data-thor-flutter-state';

/// Marks the placeholder layer, removed once Flutter paints.
const flutterPlaceholderAttr = 'data-thor-flutter-placeholder';

/// Event the Flutter side dispatches on the host after the first frame.
const flutterReadyEvent = 'thor-flutter-ready';

/// Bubbling event (`detail`: a JSON string) the Flutter side dispatches on
/// the host to send a message to the page (`FlutterView.onMessage`).
const flutterMessageEvent = 'thor-flutter-message';

/// The file of the Flutter build the loader starts (thor's multi-view
/// bootstrap, see `thor build`).
const flutterBootstrapFile = 'flutter_bootstrap.js';

/// The inline loader shipped once at the end of `<body>` on pages with a
/// `FlutterView`.
///
/// Each host mounts on its own trigger ([flutterLoadAttr]); the first one
/// loads the build's [flutterBootstrapFile], which starts one Flutter
/// engine in multi-view mode and hands its app to `window.thorFlutter`.
/// Every host then becomes a view of that app (`addView` with its
/// `initialData`). The placeholder stays until the view reports its first
/// frame ([flutterReadyEvent]); if the build fails to load, the host gets
/// `data-thor-flutter-state="error"` and keeps the placeholder.
const flutterLoaderScript =
    '(()=>{'
    'var d=document,w=window,A="$flutterAttr",'
    'H=d.querySelectorAll("["+A+"]"),a,q=[],s=0;'
    'if(!H.length)return;'
    'var S=(h,v)=>{h.setAttribute("$flutterStateAttr",v);'
    'v=="loading"?h.setAttribute("aria-busy","true"):h.removeAttribute("aria-busy")},'
    // Adds host h as a view of the app.
    'V=h=>{var j=h.getAttribute("$flutterDataAttr");'
    'h.addEventListener("$flutterReadyEvent",()=>{S(h,"ready");'
    'var p=h.querySelector(":scope>[$flutterPlaceholderAttr]");p&&p.remove()},'
    '{once:!0});'
    'try{a.addView({hostElement:h,initialData:j?JSON.parse(j):null})}'
    'catch(e){S(h,"error");throw e}},'
    // Loads the Flutter build once.
    'L=()=>{if(s)return;s=1;var e=d.createElement("script");'
    'e.src=H[0].getAttribute(A)+"$flutterBootstrapFile";e.async=!0;'
    'e.onerror=()=>{s=2;q.forEach(h=>S(h,"error"))};d.head.append(e)},'
    'M=h=>{if(h.T)return;h.T=1;'
    'a?(S(h,"loading"),V(h)):s>1?S(h,"error"):(S(h,"loading"),q.push(h),L())},'
    'O=w.IntersectionObserver&&new IntersectionObserver(E=>E.forEach(e=>{'
    'if(e.isIntersecting){O.unobserve(e.target);M(e.target)}}),'
    '{rootMargin:"200px"}),'
    // Idle mounting waits for `load`, like the engine's loader.
    'I=f=>{var i=()=>w.requestIdleCallback?requestIdleCallback(f,{timeout:2e3})'
    ':setTimeout(f,200);d.readyState=="complete"?i():'
    'w.addEventListener("load",i,{once:!0})};'
    'w.thorFlutter=x=>{a=x;q.forEach(V);q=[]};'
    'H.forEach(h=>{var m=h.getAttribute("$flutterLoadAttr");'
    'm=="eager"?M(h):m=="idle"?I(()=>M(h)):'
    'm=="interaction"?["pointerdown","focusin","keydown"].forEach('
    't=>h.addEventListener(t,()=>M(h),{once:!0})):'
    'O?O.observe(h):M(h)})'
    '})()';

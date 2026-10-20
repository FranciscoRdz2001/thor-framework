/// The script that loads a `LazyPiece` when its trigger happens,
/// inlined at the end of the `<body>` of a page that has one. Engine-free: it
/// works with either engine and with none (it only inserts HTML; the lite
/// engine's `stream` part binds the states in it, like the pieces of a
/// `FutureBuilder`).
///
/// A piece is `<div data-thor-lazy="/page?thor-piece=id"
/// data-thor-lazy-on="open|visible|idle">` holding its fallback (a link, what
/// a browser without JavaScript keeps). The script:
///
/// - `open`: loads it when the closest `<details>`, `<dialog>` or popover
///   opens (watching the `open` attribute, which every way of opening sets,
///   and `toggle` for popovers); a piece with no such parent is `visible`;
/// - `visible`: loads it when it comes near the viewport;
/// - `idle`: loads it at once (when the visitor asked to save data, as
///   `visible`: nothing is fetched that nobody is about to see).
///
/// It asks the server for the fragment, puts it in place of the fallback, adds
/// the values of the states it brought to `#thor-state`, loads the engine
/// (the file the fragment's engine loader names) when only the piece needs it,
/// and fires `thor:stream` on `<html>`
/// with the new nodes (what the `FutureBuilder`'s swap script does). A failed
/// request keeps the fallback and marks `data-thor-lazy-state="error"`; the
/// next time the trigger happens it tries again. An answer that is a whole
/// document (a static host ignores the query and sends the page) is a failed
/// request too.
///
/// Under a Content-Security-Policy with a nonce, the pieces' `<style>`s and
/// the engine script it creates carry the nonce of this script
/// (`document.currentScript.nonce`): the fragment is a separate response,
/// its own nonce would never match the page's policy. Only the `<style>`s
/// Thor wrote (the ones that carry the fragment's own nonce, which the
/// response names in `x-thor-piece-nonce`) get it: a `<style>` that came in
/// as text has no way to know that nonce, so it stays blocked.
///
/// A constant text: its hash is in `docs/guia/es/sesion-y-seguridad.md`
/// (`csp_hashes_test.dart`).
const lazyScript =
    r"""(function(){var D=document,W,N=D.currentScript&&D.currentScript.nonce,A='data-thor-lazy',S=A+'-state',C='details,dialog,[popover]';function go(e){var s=e.getAttribute(S);if(s&&s!='error')return;e.setAttribute(S,'loading');e.setAttribute('aria-busy','true');fetch(e.getAttribute(A),{credentials:'same-origin',headers:{'x-thor-piece':'1'}}).then(function(r){if(!r.ok)throw 0;W=r.headers.get('x-thor-piece-nonce');return r.text()}).then(function(t){if(/^\s*<(!doctype|html)/i.test(t))throw 0;var p=D.createElement('template'),j,m,n,x=[];p.innerHTML=t;N&&W&&p.content.querySelectorAll('style').forEach(function(q){if(q.getAttribute('nonce')==W){q.setAttribute('nonce',N);q.nonce=N}});p.content.querySelectorAll('script[data-thor-engine]').forEach(function(q){x.push(q.getAttribute('data-thor-engine'));q.remove()});j=p.content.querySelector('script['+A+'-json]');if(j){j.remove();m=D.getElementById('thor-state');if(m)m.textContent=JSON.stringify(Object.assign(JSON.parse(m.textContent),JSON.parse(j.textContent)));else{j.removeAttribute(A+'-json');j.id='thor-state';D.body.append(j)}}n=[].slice.call(p.content.childNodes);e.replaceChildren.apply(e,n);e.setAttribute(S,'done');e.removeAttribute('aria-busy');x.forEach(function(u){if(!D.querySelector('script[src="'+u+'"]')){var s=D.createElement('script');N&&(s.nonce=N);s.src=u;D.head.append(s)}});D.documentElement.dispatchEvent(new CustomEvent('thor:stream',{detail:{nodes:n.filter(function(k){return k.nodeType==1})}}));n.forEach(function(k){k.nodeType==1&&scan(k)})}).catch(function(){e.setAttribute(S,'error');e.removeAttribute('aria-busy')})}var io=window.IntersectionObserver&&new IntersectionObserver(function(r){r.forEach(function(i){if(i.isIntersecting){io.unobserve(i.target);go(i.target)}})},{rootMargin:'200px'});function up(h){return h.matches('details,dialog')?h.open:h.matches(':popover-open')}function scan(r){var sd=navigator.connection&&navigator.connection.saveData;(r.matches&&r.matches('['+A+']')?[r]:[]).concat([].slice.call(r.querySelectorAll('['+A+']'))).forEach(function(e){if(e.hasAttribute(S))return;var o=e.getAttribute(A+'-on'),h=o=='open'&&e.closest(C);if(o=='idle'&&!sd||h&&up(h))go(e);else if(!h)io?io.observe(e):go(e)})}function opened(h){[].forEach.call(h.querySelectorAll('['+A+'-on=open]'),function(e){if(e.closest(C)==h)go(e)})}new MutationObserver(function(r){r.forEach(function(m){if(m.target.open)opened(m.target)})}).observe(D.documentElement,{attributes:true,attributeFilter:['open'],subtree:true});D.addEventListener('toggle',function(e){var h=e.target;if(h.matches&&h.matches('[popover]')&&up(h))opened(h)},true);scan(D)})();""";

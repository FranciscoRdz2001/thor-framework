/// The script that loads a `LazyPiece` when its trigger happens,
/// inlined at the end of the `<body>` of a page that has one. Engine-free: it
/// works with either engine and with none (it only inserts HTML; the lite
/// engine's `stream` part binds the states in it, like the pieces of a
/// `FutureBuilder`).
///
/// A piece is `<div data-thor-lazy="/page?thor-piece=id"
/// data-thor-lazy-on="open|visible|idle">` holding its fallback (a link, what
/// a browser without JavaScript keeps). The same script also runs the
/// regions of the page:
///
/// - `<a data-thor-lazy="…" data-thor-lazy-as="replace"
///   data-thor-lazy-on="click|visible" href="…">` (`LoadMore`): the rows of
///   the next page and the next control replace the link; a click goes to
///   `href` when the request fails;
/// - `<a data-thor-lazy="…" data-thor-lazy-as="into" data-thor-lazy-into="r"
///   data-thor-lazy-open="d" data-thor-lazy-on="click">` (`Link(fetch:)`):
///   the answer fills `<… data-thor-region="r">` and the dialog or popover
///   `d` opens; a second click on the same link only opens it. With
///   `data-thor-lazy-history="push|replace"` the link's `href` also goes to
///   the address bar (`pushState` / `replaceState`) once the answer is in, and
///   the region is remembered (`data-thor-lazy-hist`: its piece) so a
///   `popstate` (back, forward) asks it again for the URL it lands on,
///   reloading the page when that fails;
/// - `<form data-thor-live="r" data-thor-live-ms="350">` (`Form(live:)`): on
///   input (debounced) and on submit it asks for the region `r` with the
///   form's fields as the query, replaces the region's content and writes
///   the query to the address bar with `replaceState`; the answer of an
///   earlier keystroke is cancelled;
/// - a `thor:region` event on the document (`detail`: a region id, what
///   `PageRegion.refresh` from a state method fires): the region is asked for
///   again from the page's current URL (the one its `Link(fetch:)` last
///   filled it from, when it has one) and swapped; an earlier request for the
///   same region is cancelled.
///
/// - `<dialog open data-thor-open>` (`Dialog(initiallyOpen: true)`): the
///   server drew a modal dialog open; the script closes it and shows it again
///   with `showModal()`, in the page and in every fragment it inserts (a
///   browser without `showModal` keeps it as drawn);
///
/// The script:
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
/// with the new nodes (what the `FutureBuilder`'s swap script does) and, when
/// the answer's state script has `data-thor-lazy-sync` (a
/// `Region(syncState: true)`), its text as `detail.sync`: the engine's
/// `stream` part sets those fields in the states that already run. A failed
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
    r"""(function(){var D=document,W,N=D.currentScript&&D.currentScript.nonce,A='data-thor-lazy',S=A+'-state',C='details,dialog,[popover]',T,K={};function R(i){return D.querySelector('[data-thor-region="'+i+'"]')}function ask(u,f,g,z){fetch(u,{credentials:'same-origin',headers:{'x-thor-piece':'1'},signal:z}).then(function(r){if(!r.ok)throw 0;W=r.headers.get('x-thor-piece-nonce');return r.text()}).then(function(t){if(/^\s*<(!doctype|html)/i.test(t))throw 0;if(z&&z.aborted)return;var p=D.createElement('template'),j,m,n,y,x=[];p.innerHTML=t;N&&W&&p.content.querySelectorAll('style').forEach(function(q){if(q.getAttribute('nonce')==W){q.setAttribute('nonce',N);q.nonce=N}});p.content.querySelectorAll('script[data-thor-engine]').forEach(function(q){x.push(q.getAttribute('data-thor-engine'));q.remove()});j=p.content.querySelector('script['+A+'-json]');if(j){y=j.hasAttribute(A+'-sync')?j.textContent:0;j.remove();m=D.getElementById('thor-state');if(m)m.textContent=JSON.stringify(Object.assign(JSON.parse(m.textContent),JSON.parse(j.textContent)));else{j.removeAttribute(A+'-json');j.id='thor-state';D.body.append(j)}}n=[].slice.call(p.content.childNodes);f(n);x.forEach(function(u){if(!D.querySelector('script[src="'+u+'"]')){var s=D.createElement('script');N&&(s.nonce=N);s.src=u;D.head.append(s)}});D.documentElement.dispatchEvent(new CustomEvent('thor:stream',{detail:{nodes:n.filter(function(k){return k.nodeType==1}),sync:y}}));n.forEach(function(k){k.nodeType==1&&scan(k)})}).catch(function(){z&&z.aborted||g()})}function show(e){var d=D.getElementById(e.getAttribute(A+'-open'));if(d&&!d.open&&!d.matches(':popover-open'))d.showModal?d.showModal():d.showPopover&&d.showPopover()}function go(e){var s=e.getAttribute(S),u=e.getAttribute(A),a=e.getAttribute(A+'-as'),t=a=='into'&&R(e.getAttribute(A+'-into'));if(s&&s!='error')return;if(a=='into'&&!t)return e.href&&(location.href=e.href);if(t&&t.getAttribute(A+'-of')==u)return show(e);e.setAttribute(S,'loading');e.setAttribute('aria-busy','true');ask(u,function(n){if(a=='replace'){var k=n.filter(function(c){return c.nodeType==1})[0];e.replaceWith.apply(e,n);if(k&&e.getAttribute(A+'-on')=='click'&&D.activeElement==D.body){k.hasAttribute('tabindex')||k.setAttribute('tabindex','-1');k.focus({preventScroll:true})}}else if(t){t.replaceChildren.apply(t,n);t.setAttribute(A+'-of',u);e.removeAttribute(S);e.removeAttribute('aria-busy');hist(e,t,u);show(e)}else{e.replaceChildren.apply(e,n);e.setAttribute(S,'done');e.removeAttribute('aria-busy')}},function(){e.setAttribute(S,'error');e.removeAttribute('aria-busy');e.getAttribute(A+'-on')=='click'&&e.href&&(location.href=e.href)})}function live(f){var i=f.getAttribute('data-thor-live'),t=R(i),u,q;if(!t)return;u=new URL(f.getAttribute('action')||location.href,location.href);q=new URLSearchParams(new FormData(f)).toString();u.search=q;var h=u.pathname+u.search;u.searchParams.set('thor-piece',i);swap(t,u.pathname+u.search,function(){history.replaceState(history.state,'',h)})}function hist(e,t,u){var m=e.getAttribute(A+'-history'),h=e.getAttribute('href');if(!m||!h)return;t.setAttribute(A+'-hist',new URL(u,location.href).searchParams.get('thor-piece'));try{history[m=='push'?'pushState':'replaceState'](m=='push'?'thor':history.state,'',h)}catch(x){}}function swap(t,u,d,g){var i=t.getAttribute('data-thor-region');K[i]&&K[i].abort();K[i]=new AbortController;t.setAttribute('aria-busy','true');ask(u,function(n){t.replaceChildren.apply(t,n);t.removeAttribute('aria-busy');d&&d()},function(){t.removeAttribute('aria-busy');g&&g()},K[i].signal)}function again(i){var t=/^[\w.\-]+$/.test(i)&&R(i),u=t&&t.getAttribute(A+'-of'),l;if(!t)return;if(!u){l=new URL(location.href);l.searchParams.set('thor-piece',i);u=l.pathname+l.search}swap(t,u)}var io=window.IntersectionObserver&&new IntersectionObserver(function(r){r.forEach(function(i){if(i.isIntersecting){io.unobserve(i.target);go(i.target)}})},{rootMargin:'200px'});function up(h){return h.matches('details,dialog')?h.open:h.matches(':popover-open')}function scan(r){var sd=navigator.connection&&navigator.connection.saveData;(r.matches&&r.matches('dialog[data-thor-open]')?[r]:[]).concat([].slice.call(r.querySelectorAll('dialog[data-thor-open]'))).forEach(function(d){d.removeAttribute('data-thor-open');if(d.showModal&&d.isConnected!==false){d.removeAttribute('open');d.showModal()}});(r.matches&&r.matches('['+A+']')?[r]:[]).concat([].slice.call(r.querySelectorAll('['+A+']'))).forEach(function(e){if(e.hasAttribute(S))return;var o=e.getAttribute(A+'-on'),h=o=='open'&&e.closest(C);if(o=='click')return;if(o=='idle'&&!sd||h&&up(h))go(e);else if(!h)io?io.observe(e):go(e)})}function opened(h){[].forEach.call(h.querySelectorAll('['+A+'-on=open]'),function(e){if(e.closest(C)==h)go(e)})}new MutationObserver(function(r){r.forEach(function(m){if(m.target.open)opened(m.target)})}).observe(D.documentElement,{attributes:true,attributeFilter:['open'],subtree:true});D.addEventListener('toggle',function(e){var h=e.target;if(h.matches&&h.matches('[popover]')&&up(h))opened(h)},true);D.addEventListener('click',function(v){var e=v.target.closest&&v.target.closest('['+A+'-on=click]');if(!e||v.defaultPrevented||v.button||v.metaKey||v.ctrlKey||v.shiftKey||v.altKey)return;v.preventDefault();go(e)});D.addEventListener('input',function(v){var f=v.target.form;if(f&&f.hasAttribute('data-thor-live')){clearTimeout(T);T=setTimeout(function(){live(f)},+f.getAttribute('data-thor-live-ms')||350)}});D.addEventListener('submit',function(v){var f=v.target;if(f.hasAttribute&&f.hasAttribute('data-thor-live')&&!v.defaultPrevented){v.preventDefault();clearTimeout(T);live(f)}});window.addEventListener('popstate',function(){[].forEach.call(D.querySelectorAll('['+A+'-hist]'),function(t){var l=new URL(location.href),u;l.searchParams.set('thor-piece',t.getAttribute(A+'-hist'));u=l.pathname+l.search;if(t.getAttribute(A+'-of')==u)return;swap(t,u,function(){t.setAttribute(A+'-of',u)},function(){location.reload()})})});D.addEventListener('thor:region',function(v){again(v.detail)});scan(D)})();""";

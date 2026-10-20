import 'dart:convert';

import '../errors.dart';
import 'inspect.dart' show InspectEditor;

/// The overlay: [entries] (server errors, compile errors, lint findings)
/// shown over the page, plus the browser's own uncaught errors as they
/// happen. Errors cover the page; warnings are a small badge. Files open in
/// [editor] (`THOR_EDITOR`; none: shown, not linked). Dev only: `thor
/// dev`'s proxy adds it; a page never carries it otherwise, and with
/// nothing to show the proxy doesn't add it either.
///
/// With [ui] false (`THOR_OVERLAY=off`) nothing is drawn: the page only gets
/// `window.__thorDevErrors` (the entries, plus the browser's uncaught errors
/// as they happen) and a `thor:dev-errors` event on `window` each time the
/// list changes, for a host that shows its own notice (an editor embedding
/// the app in an iframe).
String overlayScript(
  List<Map<String, Object?>> entries, [
  InspectEditor editor = InspectEditor.vscode,
  bool ui = true,
]) =>
    '<script id="thor-dev-overlay">'
    'window.__thorDevErrors=${jsonEncode(_bounded(entries)).replaceAll('<', r'\u003c')};'
    '${_overlayJs.replaceFirst('%ERRORS_URL%', thorErrorsUrl).replaceFirst('%LINK%', editor.linkTemplate).replaceFirst('%UI%', '$ui')}</script>';

/// The most entries the page carries: thousands of findings would make
/// every page megabytes (the terminal lists them all).
const maxOverlayEntries = 100;

/// [entries] cleaned (see [_clean]) and cut to [maxOverlayEntries], errors
/// first, with one entry saying how many more there are.
List<Object?> _bounded(List<Map<String, Object?>> entries) {
  var shown = entries;
  var more = 0;
  var cutErrors = false;
  if (entries.length > maxOverlayEntries) {
    bool isError(Map<String, Object?> e) => e['severity'] != 'warning';
    final sorted = [
      ...entries.where(isError),
      ...entries.where((e) => !isError(e)),
    ];
    shown = sorted.take(maxOverlayEntries - 1).toList();
    more = entries.length - shown.length;
    cutErrors = sorted.skip(shown.length).any(isError);
  }
  return [
    for (final e in shown) _clean(e),
    if (more > 0)
      {
        'phase': 'diagnostics',
        'title': 'More findings',
        'severity': cutErrors ? 'error' : 'warning',
        'message': '$more more not shown here (the terminal lists them all)',
        'where': '',
        'frames': const <Object?>[],
      },
  ];
}

// What a terminal draws and a page must not: ANSI escapes, other control
// characters, and the bidirectional overrides that make text read as
// something else.
final _controls = RegExp(
  '\u001B\\[[0-9;?]*[ -/]*[@-~]|[\u0000-\u0008\u000B-\u001F\u007F]'
  '|[\u202A-\u202E\u2066-\u2069\u2028\u2029]',
);

Object? _clean(Object? value) => switch (value) {
  final String s => s.replaceAll(_controls, ''),
  final List<Object?> l => [for (final v in l) _clean(v)],
  final Map<String, Object?> m => {
    for (final e in m.entries) e.key: _clean(e.value),
  },
  _ => value,
};

// Shadow DOM: the page's CSS doesn't reach it, and it doesn't reach the
// page. Errors: a dialog (Esc or the button closes it and leaves a badge
// that opens it again). Warnings only: a badge that opens the same list and
// can be dismissed (it stays dismissed, in this tab, until the warnings
// change).
const _overlayJs = r"""(()=>{
const E=window.__thorDevErrors||[];
const esc=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const link=(f,l,c)=>%LINK%;
let host=null,open=true;
const UI=%UI%;
const css=`:host{all:initial}
.bg{position:fixed;inset:0;z-index:2147483647;background:rgba(0,0,0,.55)}
.box{position:fixed;inset:4vh 0 auto;z-index:2147483647;margin:0 auto;width:min(960px,calc(100vw - 24px));max-height:92vh;overflow:auto;box-sizing:border-box;background:#fff;color:#1f2328;border-top:6px solid #cf222e;border-radius:8px;box-shadow:0 10px 40px rgba(0,0,0,.4);font:14px/1.5 ui-sans-serif,system-ui,sans-serif;padding:20px 24px}
.box.warn{border-top-color:#bf8700}
@media (prefers-color-scheme:dark){.box{background:#161b22;color:#e6edf3}.code,.stack,.fix{background:#0d1117!important}}
h2{display:flex;flex-wrap:wrap;align-items:center;gap:8px;font-size:13px;font-weight:600;margin:0 0 4px}
.pill{border-radius:10px;padding:0 8px;font-size:11px;color:#fff;background:#cf222e}
.warn .pill,.pill.w{background:#bf8700}
.msg{font:600 16px/1.4 ui-monospace,monospace;white-space:pre-wrap;overflow-wrap:anywhere;margin:0 0 8px}
.where{opacity:.7;font-size:12px;margin-bottom:12px;overflow-wrap:anywhere}
a{color:#0969da;overflow-wrap:anywhere}
.loc{font:12px/1.4 ui-monospace,monospace}
.code{background:#f6f8fa;border-radius:6px;padding:8px 0;font:12px/1.6 ui-monospace,monospace;overflow:auto;margin:6px 0 12px}
.code div{white-space:pre;padding:0 12px}.code .hit{background:rgba(207,34,46,.15)}
.code b{display:inline-block;min-width:3em;opacity:.5;font-weight:400}
.fix{background:#f6f8fa;border-left:3px solid #1a7f37;border-radius:4px;padding:6px 12px;margin:6px 0 12px;overflow-wrap:anywhere}
.fix b{color:#1a7f37;margin-right:6px}.fix code{font:12px ui-monospace,monospace}
details{margin:6px 0 16px}summary{cursor:pointer;opacity:.8}
.stack{background:#f6f8fa;border-radius:6px;padding:8px 12px;font:12px/1.6 ui-monospace,monospace;overflow:auto}
.stack div{white-space:pre}.o0{opacity:.45}.o2{font-weight:700}
.close{position:absolute;top:12px;right:14px;border:0;background:none;font-size:20px;cursor:pointer;color:inherit}
hr{border:0;border-top:1px solid rgba(128,128,128,.3);margin:16px 0}
.tip{font-size:12px;opacity:.6}
.badge{position:fixed;left:12px;bottom:12px;z-index:2147483647;display:flex;align-items:center;font:600 12px/1 ui-sans-serif,system-ui,sans-serif;border-radius:16px;color:#fff;background:#cf222e;box-shadow:0 4px 14px rgba(0,0,0,.35)}
.badge.w{background:#bf8700}
.badge button{all:unset;cursor:pointer;color:inherit;padding:8px 12px}
.badge .x{padding:8px 10px 8px 0;opacity:.8}`;
const PH={middleware:'middleware',load:'load',action:'form action',build:'build',request:'request',guard:'guard','error page':'error page',compile:'compile error',engine:'engine',codegen:'code generation',browser:'browser',diagnostics:'check'};
const U='%ERRORS_URL%';
// A code in a legacy message (THOR-S001) links to its page; the URL it
// carries goes.
const codes=s=>esc(String(s).split(' · '+U).map((p,i)=>i?p.replace(/^THOR-[SRLPB]\d{3}/,''):p).join('')).replace(/THOR-[SRLPB]\d{3}/g,c=>`<a href="${U}${c}" target="_blank" rel="noopener">${c}</a>`);
// `x` in a fix is code.
const ticks=s=>esc(s).replace(/`([^`]+)`/g,'<code>$1</code>');
const isWarn=e=>e.severity=='warning';
const place=(p,t)=>{const u=p.path&&link(p.path,p.line,p.column||1);return u?`<a href="${esc(u)}">${esc(t)}</a>`:esc(t)};
const entry=e=>{
const w=isWarn(e);
let h=`<h2><span class="pill${w?' w':''}">${w?'warning':'error'}</span>`;
if(e.code)h+=`<a href="${esc(e.doc||U+e.code)}" target="_blank" rel="noopener">${esc(e.code)}</a> · `;
h+=`${esc(PH[e.phase]||e.phase)} · ${esc(e.title)}</h2><p class="msg">${e.code?esc(e.message):codes(e.message)}</p>`;
if(e.where)h+=`<div class="where">${esc(e.where)}</div>`;
if(e.at){h+=`<div class="loc">${place(e.at,e.at.file+':'+e.at.line+(e.at.column?':'+e.at.column:''))}</div>`;
if(e.at.code&&e.at.code.length){h+='<div class="code">'+e.at.code.map(([n,t])=>`<div class="${n==e.at.line?'hit':''}"><b>${n}</b>${esc(t)}</div>`).join('')+'</div>';}}
if(e.fix)h+=`<div class="fix"><b>fix</b>${ticks(e.fix)}</div>`;
if(e.frames&&e.frames.length){h+=`<details${e.at?'':' open'}><summary>stack (${e.frames.length})</summary><div class="stack">`+e.frames.map(f=>`<div class="o${f.owner}">${f.path?place(f,f.text):esc(f.text)}</div>`).join('')+'</div></details>';}
return h;};
// Warnings dismissed in this tab stay dismissed until they change.
const SK='thor:dev-warnings-dismissed';
const sig=()=>E.filter(isWarn).map(e=>[e.code,e.at&&e.at.path,e.at&&e.at.line,e.message].join('|')).join('\n');
const dismissed=()=>{try{return sessionStorage.getItem(SK)===sig()}catch(_){return false}};
const dismiss=()=>{try{sessionStorage.setItem(SK,sig())}catch(_){}render(false)};
const render=(modal)=>{
if(!UI)return;
open=modal;
const errs=E.filter(e=>!isWarn(e)),warns=E.filter(isWarn);
if(!E.length||(!modal&&!errs.length&&dismissed())){host&&host.remove();return}
if(!host){host=document.createElement('thor-dev-overlay');host.attachShadow({mode:'open'});}
const root=host.shadowRoot;
const n=(k,s)=>k+' '+s+(k==1?'':'s');
let h=`<style>${css}</style>`;
if(modal){
h+=`<div class="bg"></div><div class="box${errs.length?'':' warn'}" role="alertdialog" aria-label="thor dev diagnostics"><button class="close" aria-label="Close">×</button>`
+[...errs,...warns].map(entry).join('<hr>')
+'<p class="tip">thor dev · fix the code and save: the page reloads. Esc closes this.</p></div>';
}else if(errs.length||(warns.length&&!dismissed())){
h+=`<div class="badge${errs.length?'':' w'}"><button class="open" aria-label="Show diagnostics">${errs.length?n(errs.length,'error'):n(warns.length,'warning')}${errs.length&&warns.length?' · '+n(warns.length,'warning'):''}</button>`
+(errs.length?'':'<button class="x" aria-label="Dismiss">×</button>')+'</div>';
}
root.innerHTML=h;
const q=s=>root.querySelector(s);
q('.close')&&(q('.close').onclick=()=>render(false));
q('.bg')&&(q('.bg').onclick=()=>render(false));
q('.open')&&(q('.open').onclick=()=>render(true));
q('.x')&&(q('.x').onclick=dismiss);
(document.body||document.documentElement).appendChild(host);};
const show=()=>{if(!E.length)return;dispatchEvent(new CustomEvent('thor:dev-errors',{detail:E}));render(E.some(e=>!isWarn(e)))};
addEventListener('keydown',e=>{if(e.key=='Escape'&&open)render(false)});
// An error that repeats (a timer that throws every frame) is one entry, and
// there are at most 50: rendering thousands would freeze the page.
// An engine that did not build leaves a page nobody can click: headless
// tools read the console, not the overlay.
for(const e of E)if(e.phase=='engine'&&e.severity!='warning')console.error('[thor dev] '+(e.code?e.code+' · ':'')+e.title+': '+e.message+(e.at?' ('+e.at.file+':'+e.at.line+')':''));
const seen=new Set();
const browser=(message,stack)=>{const k=String(message)+'\n'+String(stack||'');if(seen.has(k)||seen.size>=50)return;seen.add(k);E.push({phase:'browser',title:'Uncaught error',severity:'error',message:String(message),frames:String(stack||'').split('\n').filter(Boolean).map(t=>({text:t.trim(),owner:1}))});show();};
addEventListener('error',e=>browser(e.message,e.error&&e.error.stack));
addEventListener('unhandledrejection',e=>browser(e.reason&&e.reason.message||e.reason,e.reason&&e.reason.stack));
if(document.readyState=='loading')addEventListener('DOMContentLoaded',show);else show();
})();""";

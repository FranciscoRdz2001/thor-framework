/// The inspector `thor dev` puts in every page: Alt (Option) + click on an
/// element opens, in the editor, the app code that built it; a panel lists
/// the chain of app widgets above it. No `dart:io`: the browser tests load
/// it too.
///
/// Contract: the server writes `data-thor-src="/abs/file.dart:
/// line:column"` on each element when `THOR_DEV=1` (`ThorInspect` in
/// thor_ui) and `data-thor="Row"` with the widget's name in debug; this
/// script only reads them. Release pages have neither and never get it.
library;

/// The editors [inspectScript] can open, by their `THOR_EDITOR` name.
enum InspectEditor {
  /// Visual Studio Code (the default).
  vscode,

  /// Cursor.
  cursor,

  /// Zed.
  zed,

  /// IntelliJ IDEA / Android Studio (`idea://`).
  idea,

  /// Nothing opens: the panel shows the location to copy.
  none;

  /// The editor named [name] (`THOR_EDITOR`), or [vscode].
  static InspectEditor parse(String? name) => values.firstWhere(
    (e) => e.name == name?.trim().toLowerCase(),
    orElse: () => vscode,
  );

  // A path in a URL: spaces, `#` and `?` would end it early.
  static const _path = r"encodeURI(f).replace(/#/g,'%23').replace(/\?/g,'%3F')";

  /// The link that opens a file at a line and column (JavaScript
  /// template: `f`, `l`, `c` are variables of the script).
  String get linkTemplate => switch (this) {
    vscode => '`vscode://file\${$_path}:\${l}:\${c}`',
    cursor => '`cursor://file\${$_path}:\${l}:\${c}`',
    zed => '`zed://file\${$_path}:\${l}:\${c}`',
    idea => r'`idea://open?file=${encodeURIComponent(f)}&line=${l}`',
    none => "''",
  };
}

/// The inspector script for [editor]. Alt+hover outlines the element and
/// names its widget and file; Alt+click opens the file and shows the chain
/// (Esc closes it). Everything it draws lives in a Shadow DOM.
String inspectScript([InspectEditor editor = InspectEditor.vscode]) =>
    '<script id="thor-inspect">(()=>{'
    "const A='data-thor-src',d=document;"
    'let host,root,box,tip,panel;'
    'const ui=()=>{if(host)return;host=d.createElement("thor-inspect");'
    "host.style.cssText='position:fixed;inset:0;pointer-events:none;"
    "z-index:2147483646';root=host.attachShadow({mode:'open'});"
    'root.innerHTML=`<style>'
    '.b{position:fixed;border:2px solid #7c3aed;background:#7c3aed22;'
    'border-radius:2px;display:none}'
    '.t{position:fixed;font:12px/1.4 ui-monospace,monospace;background:#1f2328;'
    'color:#fff;padding:3px 6px;border-radius:4px;display:none;'
    'white-space:nowrap}'
    '.p{position:fixed;right:12px;bottom:12px;max-width:min(560px,90vw);'
    'max-height:50vh;overflow:auto;pointer-events:auto;background:#fff;'
    'color:#1f2328;font:12px/1.5 ui-monospace,monospace;border:1px solid '
    '#d0d7de;border-radius:8px;box-shadow:0 8px 24px #0003;display:none}'
    '.p header{display:flex;justify-content:space-between;padding:6px 10px;'
    'border-bottom:1px solid #d0d7de;font-weight:600}'
    '.p button{all:unset;cursor:pointer;padding:0 4px}'
    '.p a{display:block;padding:4px 10px;color:inherit;text-decoration:none}'
    '.p a:hover{background:#f6f8fa}.p small{color:#57606a}'
    '</style><div class=b></div><div class=t></div>'
    '<div class=p role=dialog aria-label="thor inspector"><header>'
    '<span>thor · widgets</span><button aria-label=Close>×</button>'
    '</header><nav></nav></div>`;'
    "box=root.querySelector('.b');tip=root.querySelector('.t');"
    "panel=root.querySelector('.p');"
    "root.querySelector('button').onclick=()=>panel.style.display='none';"
    'd.body.append(host)};'
    // `/abs/app/lib/x.dart:12:3` → parts; the label keeps the path from
    // `lib/` (or the file name).
    "const parse=s=>{const m=/^(.*):(\\d+):(\\d+)\$/.exec(s||'');"
    'if(!m)return null;const f=m[1],i=f.lastIndexOf("/lib/");'
    'return{f,l:m[2],c:m[3],label:(i<0?f.split("/").pop():f.slice(i+1))'
    "+':'+m[2]}};"
    'const link=({f,l,c})=>${editor.linkTemplate};'
    'const at=e=>e&&e.closest?e.closest(`[\${A}]`):null;'
    "const name=e=>{const n=e.closest('[data-thor]');"
    "return n?n.getAttribute('data-thor'):e.tagName.toLowerCase()};"
    // The app widgets above: each distinct source once, nearest first.
    'const chain=e=>{const out=[];let last=null;'
    'for(let n=at(e);n;n=at(n.parentElement)){const s=n.getAttribute(A);'
    'if(s!==last){const p=parse(s);if(p)out.push({...p,w:name(n)});last=s}}'
    'return out};'
    'const hide=()=>{if(box){box.style.display=tip.style.display="none"}};'
    'const show=e=>{const n=at(e);if(!n)return hide();ui();'
    'const r=n.getBoundingClientRect(),p=parse(n.getAttribute(A));'
    'Object.assign(box.style,{display:"block",left:r.left+"px",top:r.top+"px",'
    'width:r.width+"px",height:r.height+"px"});'
    'tip.textContent=name(n)+"  "+(p?p.label:"");'
    'Object.assign(tip.style,{display:"block",left:Math.max(4,r.left)+"px",'
    'top:(r.top>24?r.top-22:r.bottom+2)+"px"})};'
    'const open=p=>{const u=link(p);if(u)location.href=u};'
    "addEventListener('mousemove',e=>e.altKey?show(e.target):hide(),"
    '{passive:true});'
    "addEventListener('keyup',e=>{if(e.key==='Alt')hide()});"
    "addEventListener('keydown',e=>{if(e.key==='Escape'&&panel)"
    "panel.style.display='none'});"
    "addEventListener('click',e=>{if(!e.altKey)return;const c=chain(e.target);"
    'if(!c.length)return;e.preventDefault();e.stopPropagation();ui();'
    "const nav=root.querySelector('nav');nav.textContent='';"
    'for(const p of c){const a=d.createElement("a");a.href=link(p)||"#";'
    'a.innerHTML="<b></b> <small></small>";a.firstChild.textContent=p.w;'
    'a.lastChild.textContent=p.label;a.title=p.f+":"+p.l+":"+p.c;'
    'a.onclick=ev=>{ev.preventDefault();open(p)};nav.append(a)}'
    "panel.style.display='block';hide();open(c[0])},true);"
    '})();</script>';

/// The engine's forms part (`thor_engine/lib/lite/parts/forms.js`,
/// minified): native validation that shows the page's own messages
/// (`data-msg-<flag>`) instead of the browser's, in the browser's language.
/// Inlined at the end of a page with validated fields that doesn't load the
/// engine, which would bring it. A test keeps it equal to the part.
const validationScript =
    r"""((D)=>{const R=D.documentElement;if(!R.querySelector('[data-t-validate]'))return;const c=['valueMissing','typeMismatch','badInput','patternMismatch','tooShort','tooLong','rangeUnderflow','rangeOverflow','stepMismatch'];const a=new WeakSet();function check(d){let msg=null;for(const f of c){if(d.validity[f]){msg=d.getAttribute(`data-msg-${f.toLowerCase()}`)??d.validationMessage;break;}}
d.setAttribute('aria-invalid',`${msg!=null}`);const h=d.getAttribute('aria-describedby')?.split(' ')[0];const g=h==null?null:D.getElementById(h);if(!g)return;g.textContent=msg??g.getAttribute('data-helper')??'';msg==null?g.removeAttribute('data-invalid'):g.setAttribute('data-invalid','');}
const b=(e)=>{const t=e.target;return t instanceof HTMLInputElement&&t.hasAttribute('data-t-validate')?t:null;};R.addEventListener('focusout',(e)=>{const i=b(e);if(i)a.add(i),check(i);});R.addEventListener('input',(e)=>{const i=b(e);if(i&&a.has(i))check(i);});R.addEventListener('invalid',(e)=>{const i=b(e);if(!i)return;e.preventDefault();a.add(i);check(i);if(R.querySelector('[data-t-validate]:invalid')===i)i.focus();},true,);})(document);""";

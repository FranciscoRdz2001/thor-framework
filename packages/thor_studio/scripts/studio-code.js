// thor_studio: the copy button of the code blocks (a progressive
// enhancement). Without this file the buttons stay hidden and the code is
// plain, selectable text.
//
// Load it once per page:  html.script(src: 'scripts/studio-code.js', defer: true)
// The `thor` command copies it into the app's web/scripts/.
(() => {
  // Shows the copy buttons (hidden until a script can make them work).
  document.documentElement.setAttribute('data-studio-js', '');

  const RESET_MS = 1600;

  document.addEventListener('click', (event) => {
    const button = event.target instanceof Element
      ? event.target.closest('[data-studio-copy]')
      : null;
    if (!button) return;
    const pane = button.closest('[data-studio-code]');
    const code = pane && pane.querySelector('pre');
    if (!code) return;

    const done = () => {
      // The label is the button's last non-blank text node, or, on an icon-only
      // button, its `aria-label`; the copied label is the button's own
      // `data-studio-copy` value.
      const text =
        [...button.childNodes]
          .reverse()
          .find((n) => n.nodeType === Node.TEXT_NODE && n.nodeValue.trim()) ||
        null;
      const read = () =>
        text ? text.nodeValue : button.getAttribute('aria-label') || '';
      const write = (value) => {
        if (text) {
          text.nodeValue = value;
        } else {
          button.setAttribute('aria-label', value);
          button.setAttribute('title', value);
        }
      };
      const original = button.getAttribute('data-original-label') || read();
      button.setAttribute('data-original-label', original);
      write(button.getAttribute('data-studio-copy') || original);
      button.setAttribute('data-copied', '');
      clearTimeout(button._studioTimer);
      button._studioTimer = setTimeout(() => {
        write(original);
        button.removeAttribute('data-copied');
      }, RESET_MS);
    };

    const text = code.textContent || '';
    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard
        .writeText(text)
        .then(done, () => fallback(text) && done());
    } else if (fallback(text)) {
      done();
    }
  });

  // A page served over http has no navigator.clipboard: copy through a
  // hidden field.
  function fallback(text) {
    const field = document.createElement('textarea');
    field.value = text;
    field.setAttribute('readonly', '');
    field.style.cssText = 'position:fixed;top:0;left:0;opacity:0';
    document.body.appendChild(field);
    field.select();
    let ok = false;
    try {
      ok = document.execCommand('copy');
    } catch (_) {
      ok = false;
    }
    field.remove();
    return ok;
  }
})();

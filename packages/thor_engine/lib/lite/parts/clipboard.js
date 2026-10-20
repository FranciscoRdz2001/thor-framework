// thor-lite part "clipboard": `Clipboard.setData` / `Clipboard.getData`
// from translated states (the dart2js engine's ClipboardFeature).
//
// A call waits for the browser's `copy`/`cut` (write) or `paste` (read)
// event of the same key press, which carries the data with no permission
// prompt. If none comes in that task (the call came from a click), it
// falls back to the asynchronous `navigator.clipboard`.
((T, D) => {
  let text = null, written = null, read = null;
  const later = (f) => setTimeout(f, 0);
  const pending = () => {
    let ok;
    const p = new Promise((r) => (ok = r));
    p.ok = ok;
    return p;
  };
  T.clip = {
    get waits() {
      return written != null || read != null;
    },
    write(t) {
      text = t;
      const done = (written ||= pending());
      later(() => {
        if (text == null || written !== done) return;
        const t = text;
        text = written = null;
        navigator.clipboard.writeText(t).then(() => done.ok(), () => done.ok());
      });
      return done;
    },
    read() {
      const done = (read ||= pending());
      later(() => {
        if (read !== done) return;
        read = null;
        navigator.clipboard.readText().then((t) => done.ok(t), () => done.ok(null));
      });
      return done;
    },
  };
  const copy = (e) => {
    const done = written, data = e.clipboardData;
    if (text == null || !done || !data) return;
    data.setData('text/plain', text);
    e.preventDefault();
    text = written = null;
    done.ok();
  };
  D.addEventListener('copy', copy, true);
  D.addEventListener('cut', copy, true);
  D.addEventListener(
    'paste',
    (e) => {
      const done = read, data = e.clipboardData;
      if (!done || !data) return;
      e.preventDefault();
      read = null;
      done.ok(data.getData('text/plain'));
    },
    true,
  );
})(thor, document);

// The page's one confirm dialog: `document.thorConfirm(title, message,
// ok, cancel)` → Promise<boolean> for a state's `confirm(...)`, and the
// `data-t-confirm` of a submit button or a form that asks before it submits.
// Inlined next to the `<dialog id="thor-confirm">` the server wrote, so it
// works before the engine loads and with either engine.
//
// The dialog is native: the focus trap, Esc, the backdrop and the focus going
// back are the browser's. Its buttons are a `<form method=dialog>`: the one
// pressed sets `returnValue` (`ok`); Esc or a click outside leave it empty,
// which is a no. Asks wait their turn (one dialog, one question at a time).
((D) => {
  const d = D.getElementById('thor-confirm');
  if (!d || !d.showModal) return;
  const el = (k) => d.querySelector(`[data-t-c=${k}]`);
  const title = el('t'), text = el('m'), ok = el('o'), no = el('n');
  // The labels the server wrote (the app's language) stay the defaults.
  const yes = ok.textContent, nay = no.textContent;
  const queue = [];
  let busy = false;
  const next = () => {
    if (busy || !queue.length) return;
    busy = true;
    const [q, done] = queue.shift();
    title.textContent = q[0];
    text.textContent = q[1] || '';
    text.hidden = !q[1];
    ok.textContent = q[2] || yes;
    no.textContent = q[3] || nay;
    d.returnValue = '';
    const end = () => {
      busy = false;
      done(d.returnValue === 'ok');
      next();
    };
    d.addEventListener('close', end, { once: true });
    // A dialog that can't open (already open, or out of the page) is a no,
    // and the questions behind it still get their turn.
    try {
      d.showModal();
    } catch {
      d.removeEventListener('close', end);
      d.returnValue = '';
      end();
    }
  };
  const ask = (...q) => new Promise((done) => {
    queue.push([q, done]);
    next();
  });
  D.thorConfirm = ask;
  // Asked before anything else sees the submit (the engine's included); once
  // it is a yes the same submit goes again, past this.
  const sure = new WeakSet();
  D.addEventListener('submit', (e) => {
    const f = e.target, s = e.submitter;
    const c = s?.hasAttribute('data-t-confirm') ? s : f.hasAttribute?.('data-t-confirm') ? f : null;
    if (!c) return;
    if (sure.has(f)) return sure.delete(f);
    e.preventDefault();
    e.stopImmediatePropagation();
    const a = (n) => c.getAttribute(`data-t-c${n}`);
    ask(c.getAttribute('data-t-confirm'), a('m'), a('o'), a('n')).then((answer) => {
      if (!answer || !f.isConnected) return;
      // The answer goes with the post: without it the server (which asks
      // again when JavaScript is off) would take this one for unanswered.
      if (!f.querySelector('input[name=thor-confirmed]')) {
        const i = D.createElement('input');
        i.type = 'hidden';
        i.name = 'thor-confirmed';
        i.value = '1';
        f.append(i);
      }
      sure.add(f);
      f.requestSubmit(s?.isConnected && s.form === f ? s : undefined);
    });
  }, true);
})(document);

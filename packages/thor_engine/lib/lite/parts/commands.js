// thor-lite part "commands": Invoker Commands (`DialogTrigger` /
// `DialogClose`: `commandfor` + `command`). Where the browser lacks them it
// does what they do on any element; where it has them it does it only on
// what is not a button (a tappable card: the browser runs the command on a
// button only), and Enter / Space press such an element like a click.
// Loaded when the page has one (the dart2js engine's CommandsFeature).
((D) => {
  const native = 'command' in D.createElement('button');
  const isButton = (b) => b.tagName === 'BUTTON' || b.tagName === 'INPUT';
  const run = (e, b) => {
    if (!b || (native && isButton(b)) || b.getAttribute('aria-disabled') === 'true') return;
    const d = D.getElementById(b.getAttribute('commandfor'));
    if (!d?.showModal) return;
    const c = b.getAttribute('command');
    if (c === 'show-modal') d.open || d.showModal();
    else if (c === 'close') d.close();
  };
  const R = D.documentElement;
  R.addEventListener('click', (e) => run(e, e.target?.closest?.('[commandfor]')));
  R.addEventListener('keydown', (e) => {
    const b = e.target;
    if ((e.key === 'Enter' || e.key === ' ') && !isButton(b) && b.hasAttribute?.('commandfor') && b.getAttribute('role') === 'button') {
      e.preventDefault();
      run(e, b);
    }
  });
})(document);

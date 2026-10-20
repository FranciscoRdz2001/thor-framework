// thor-lite part "commands": the Invoker Commands polyfill (`DialogTrigger` /
// `DialogClose`: `<button commandfor command>`) where the browser lacks it
// (the dart2js engine's CommandsFeature). Loaded when the page has one.
((D) => {
  if ('command' in D.createElement('button')) return;
  D.documentElement.addEventListener('click', (e) => {
    const b = e.target?.closest?.('[commandfor]');
    const d = b && D.getElementById(b.getAttribute('commandfor'));
    if (!d?.showModal) return;
    const c = b.getAttribute('command');
    if (c === 'show-modal') d.open || d.showModal();
    else if (c === 'close') d.close();
  });
})(document);

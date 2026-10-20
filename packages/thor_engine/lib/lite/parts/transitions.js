// thor-lite part "transitions": `onEnd` of implicit animations runs once
// per change, after every property of the element finished (the browser
// fires one `transitionend` per property). The dart2js engine's
// TransitionsFeature. Loaded when the page has a `transitionend:` handler.
((R) => {
  const running = new WeakMap();
  const count = (e, d) => {
    const t = e.target, left = (running.get(t) ?? 0) + d;
    left <= 0 ? running.delete(t) : running.set(t, left);
  };
  R.addEventListener('transitionrun', (e) => count(e, 1));
  R.addEventListener('transitioncancel', (e) => count(e, -1));
  // Capture: before the runtime's own listener, and stops the event while
  // other properties of the element are still running.
  R.addEventListener(
    'transitionend',
    (e) => {
      const t = e.target, left = (running.get(t) ?? 1) - 1;
      left <= 0 ? running.delete(t) : running.set(t, left);
      if (left > 0) e.stopImmediatePropagation();
    },
    true,
  );
})(document.documentElement);

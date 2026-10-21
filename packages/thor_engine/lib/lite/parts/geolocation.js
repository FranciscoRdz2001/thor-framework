// thor-lite part "geolocation": thor_ui's `GeolocationRequest`
// (`data-t-geo="ok:id;err:id"`, `data-t-geo-o="highAccuracy|timeout|maxAge"`).
//
// A click on the element (or inside it) asks `navigator.geolocation` once for
// the position. `ok` gets `latitude~longitude~accuracy`, `err` the reason:
// `denied`, `unavailable`, `timeout` or `unsupported`. Only a click asks
// (browsers refuse, and visitors dislike, a prompt at load). A second click
// while the first waits is ignored. The click's default (a link) is stopped:
// the element is a button for the position.
((D, W) => {
  const A = 'data-t-geo', O = 'data-t-geo-o';
  const busy = new WeakSet();
  const reasons = ['unavailable', 'denied', 'unavailable', 'timeout'];
  D.documentElement.addEventListener(
    'click',
    (e) => {
      const el = e.target instanceof Element ? e.target.closest(`[${A}]`) : null;
      if (!el || busy.has(el)) return;
      const on = parseOn(el.getAttribute(A));
      e.preventDefault();
      const fail = (why) => on.err && run(on.err, el, why);
      const geo = W.navigator?.geolocation;
      if (!geo) return fail('unsupported');
      const [hi, to, age] = (el.getAttribute(O) ?? '').split('|');
      busy.add(el);
      const done = (f) => (x) => {
        busy.delete(el);
        f(x);
      };
      geo.getCurrentPosition(
        done((p) => on.ok && run(on.ok, el, `${p.coords.latitude}~${p.coords.longitude}~${p.coords.accuracy}`)),
        done((x) => fail(reasons[x?.code] ?? 'unavailable')),
        { enableHighAccuracy: hi === '1', timeout: +to || undefined, maximumAge: +age || 0 },
      );
    },
    true,
  );
})(document, window);

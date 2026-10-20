// thor-lite part "animation_controller": AnimationController (needs
// "controllers"), the dart2js engine's AnimationsFeature and the controller
// of thor_engine's animation.dart in one. The server precompiled the
// keyframes of every *Transition a controller drives (`data-ta`, a JSON list
// of tracks {c: controller id, k: keyframes, r: reversed, v: value, a: CSS
// animation}); this plays them with the Web Animations API on one fixed
// timeline (SPAN ms = the controller's whole range), the controller's
// durations as playback rates, with a target-less animation as its clock.
// `status` is AnimationStatus's index (dismissed, forward, reverse,
// completed); the translator maps it to the enum. A state with one starts
// at load, like every state of the dart2js engine.
((T, D) => {
  const { all } = T.ctl;
  const { batch } = T; // value, status and playback move together
  const SPAN = 1000;
  const opts = { duration: SPAN, fill: 'both' };
  const bad = (n, v, m) => {
    throw new Error(`Invalid argument (${n}): ${m}: ${v}`);
  };
  const chk = (d, n) => (d != null && d.us < 0 ? bad(n, d, 'must not be negative') : d ?? null);
  const need = (d, m) => {
    if (d == null) {
      throw new Error(
        `Bad state: AnimationController.${m}() called with no default duration: set \`duration\` in the constructor or before calling it.`,
      );
    }
    return d;
  };
  // The easing of a move from `f` to `e` (fractions of the range) with the CSS
  // `curve` over that stretch: a `linear()` of the whole range, the identity
  // outside the stretch, that inside it goes from `f` to `e` along the curve
  // (clamped to the range, like the controller's value). The browser
  // evaluates the curve: an animation with that easing, paused at each
  // sample. Where it can't (no `linear()`) the move is linear.
  const compose = (curve, f, e) => {
    try {
      const probe = new Animation(new KeyframeEffect(null, null, { duration: 1000, easing: curve, fill: 'both' }));
      probe.pause();
      const at = [];
      for (let i = 0; i <= 32; i++) {
        probe.currentTime = (i / 32) * 1000;
        const c = probe.effect.getComputedTiming().progress ?? i / 32;
        at.push([f + ((e - f) * i) / 32, Math.min(1, Math.max(0, f + (e - f) * c))]);
      }
      probe.cancel();
      if (e < f) at.reverse();
      const n = (v, d) => +v.toFixed(d);
      const css = `linear(${[...(Math.min(f, e) > 0 ? [[0, 0]] : []), ...at, ...(Math.max(f, e) < 1 ? [[1, 1]] : [])].map(([q, v]) => `${n(v, 4)} ${n(q * 100, 2)}%`).join(', ')})`;
      new KeyframeEffect(null, null, { easing: css });
      return css;
    } catch {
      return 'linear';
    }
  };
  // The value (fraction of the range) a move from `f` to `e` along the CSS
  // `curve` has at the pass progress `q`: the identity outside its stretch.
  const value = (curve, f, e, q) => {
    if (q < Math.min(f, e) || q > Math.max(f, e)) return q;
    try {
      const probe = new Animation(new KeyframeEffect(null, null, { duration: 1000, easing: curve, fill: 'both' }));
      probe.pause();
      probe.currentTime = (e === f ? 1 : (q - f) / (e - f)) * 1000;
      const c = probe.effect.getComputedTiming().progress;
      probe.cancel();
      return Math.min(1, Math.max(0, f + (e - f) * c));
    } catch {
      return q;
    }
  };
  // Flutter's fling spring (mass 1, stiffness 500, critically damped) for a
  // move of `d` value units at `v` units/s towards its target, which Flutter
  // puts 0.01 past the bound so the controller reaches it: the ms it takes
  // and its progress sampled into a CSS linear() easing (0 to 1).
  const spring = (d, v) => {
    const w = 22.360679774997898, s0 = d + 0.01, b = w * s0 - v, left = (t) => (s0 + b * t) * Math.exp(-w * t);
    let ms = 1;
    while (ms < 10000 && left(ms / 1000) > 0.01) ms++;
    const st = [];
    for (let i = 0; i <= 32; i++) st.push(i === 32 ? 1 : +Math.min(1, Math.max(0, (s0 - left((ms / 1000) * (i / 32))) / d)).toFixed(4));
    return [ms, `linear(${st.join(', ')})`];
  };
  // A curve is the CSS easing the translator wrote (none for linear).
  const curve = (c) => {
    if (c != null && typeof c !== 'string') bad('curve', c, 'must be a CSS easing (Curves.x)');
    return c && c !== 'linear' ? c : undefined;
  };
  class Anim {
    // Like Flutter's: a disposed controller has nothing to play with.
    live(m) {
      if (this.x) throw new Error(`Bad state: AnimationController.${m}() called after dispose()`);
    }
    constructor(id, value, duration, reverseDuration, debugLabel, lowerBound = 0, upperBound = 1) {
      all[(this.id = id)] = this;
      this.pr = []; // the promises of animateTo / animateBack / fling still playing
      if (!isFinite(lowerBound) || !isFinite(upperBound) || !(lowerBound < upperBound)) {
        throw new Error(
          `Invalid argument(s): AnimationController: lowerBound (${lowerBound}) must be less than upperBound (${upperBound}), and both finite.`,
        );
      }
      this.lowerBound = lowerBound;
      this.upperBound = upperBound;
      this.debugLabel = debugLabel ?? null;
      this.d = chk(duration, 'duration');
      this.rd = chk(reverseDuration, 'reverseDuration');
      this.v = T.signal(lowerBound);
      this.s = T.signal(0);
      this.pb = T.signal(null); // {f: from, w: sweep, r: reverse, i: iterations, a: alternate, m: [min, max] of a loop over a stretch}
      this.fw = true;
      if (value != null) {
        if (!isFinite(value)) bad('value', value, 'must be a finite number');
        batch(() => {
          this.v.value = this.cl(value);
          this.s.value = this.at(this.v.peek());
        });
      }
      this.drive();
    }
    // The driver: the clock and every element animation of this controller.
    drive() {
      const lead = (this.lead = new Animation(new KeyframeEffect(null, null, opts)));
      lead.pause();
      const list = (this.all = [[lead, null, null]]);
      let from;
      for (const el of D.querySelectorAll('[data-ta]')) {
        for (const t of JSON.parse(el.getAttribute('data-ta'))) {
          if (t.c !== this.id) continue;
          if (from == null) {
            if (t.a != null) {
              for (const a of el.getAnimations()) {
                if (!(a instanceof CSSAnimation) || a.animationName !== t.a) continue;
                let p = a.effect?.getComputedTiming().progress;
                // Reduced motion: the CSS animation (1 ms) rests at its end,
                // but it may not have run yet (progress 0).
                if (this.rm) {
                  const dir = a.effect?.getTiming().direction;
                  p = dir === 'reverse' || dir === 'alternate-reverse' ? 0 : 1;
                }
                a.cancel();
                // An eased move (`x`: [curve, from, to]): the pass the CSS
                // animation is at is not the value, the curve of the move is.
                if (p != null && t.x && !this.rm) p = value(t.x[0], t.x[1], t.x[2], p);
                // A loop over a stretch of the range: the pass, not the value.
                if (p != null && t.w) p = t.w[0] + p * (t.w[1] - t.w[0]);
                if (p != null) from = this.lowerBound + p * (this.upperBound - this.lowerBound);
              }
            } else if (typeof t.v === 'number') from = t.v;
          }
          const a = el.animate(t.k ?? null, opts);
          a.pause();
          list.push([a, t.k ?? null, t.r ?? null]);
        }
      }
      // A finish queued before another play() started is stale.
      lead.onfinish = () => lead.playState === 'finished' && this.fin();
      if (from != null && isFinite(from)) this.v.value = this.cl(from);
      const v = this.v.peek();
      this.seek(this.toT(v));
      if (from != null) this.st(this.at(v));
    }
    // Stops the playback; whoever awaits an animateTo / animateBack / fling
    // is released (it ended, or something else moved the controller).
    halt() {
      this.pb.value = null;
      for (const ok of this.pr.splice(0)) ok();
    }
    get rm() {
      return matchMedia('(prefers-reduced-motion: reduce)').matches;
    }
    get t() {
      const l = this.lead;
      return l.effect?.getComputedTiming().progress ?? (l.currentTime ?? 0) / SPAN;
    }
    play(p) {
      // A move that stops short of the bound (animateTo) can't run on a
      // negative rate, which only ends at 0: backwards it plays the reversed
      // direction forwards in time, for the part of a pass that it covers.
      const part = p.r && p.e != null, speed = SPAN / (p.w.us / 1000);
      // The move's curve; the others play linearly.
      // A loop over a stretch (`p.m` = [min, max]) maps the pass to it.
      const m = p.m, easing = m ? `linear(${+m[0].toFixed(4)}, ${+m[1].toFixed(4)})` : p.x ? compose(p.x, p.f, p.e ?? (p.r ? 0 : 1)) : 'linear';
      const at = m ? (m[1] === m[0] ? 0 : (Math.min(m[1], Math.max(m[0], p.f)) - m[0]) / (m[1] - m[0])) : p.f;
      for (const [a, k, r] of this.all) {
        a.effect.updateTiming({ iterations: p.i, direction: part ? 'reverse' : p.a ? 'alternate' : 'normal', easing });
        if (r != null) a.effect.setKeyframes(p.r ? r : k);
        a.playbackRate = p.r && !part ? -speed : speed;
        a.currentTime = (part ? 1 - p.f : at) * SPAN;
        a.play();
      }
    }
    seek(t) {
      // The keyframes stay: stopped mid-reverse, a reverseCurve still applies.
      for (const [a] of this.all) {
        a.pause();
        a.effect.updateTiming({ iterations: 1, direction: 'normal', easing: 'linear' });
        a.playbackRate = 1;
        a.currentTime = t * SPAN;
      }
    }
    get value() {
      return this.fT(this.t);
    }
    set value(n) {
      this.live('value=');
      if (!isFinite(n)) bad('value', n, 'must be a finite number');
      batch(() => {
        this.halt();
        const v = this.cl(n);
        this.v.value = v;
        this.seek(this.toT(v));
        this.st(this.at(v));
      });
    }
    get status() {
      return this.s.value;
    }
    get isAnimating() {
      return this.pb.value != null;
    }
    get isCompleted() {
      return this.s.value === 3;
    }
    get isDismissed() {
      return this.s.value === 0;
    }
    get isForwardOrCompleted() {
      const s = this.s.value;
      return s === 1 || s === 3;
    }
    get duration() {
      return this.d;
    }
    set duration(d) {
      this.d = chk(d, 'duration');
    }
    get reverseDuration() {
      return this.rd;
    }
    set reverseDuration(d) {
      this.rd = chk(d, 'reverseDuration');
    }
    forward(from) {
      this.live('forward');
      const d = need(this.d, 'forward');
      this.fw = true;
      batch(() => {
        if (from != null) this.value = from;
        this.to(this.upperBound, d);
      });
    }
    reverse(from) {
      this.live('reverse');
      const d = need(this.rd ?? this.d, 'reverse');
      this.fw = false;
      batch(() => {
        if (from != null) this.value = from;
        this.to(this.lowerBound, d);
      });
    }
    toggle(from) {
      const s = this.s.value;
      s === 1 || s === 3 ? this.reverse(from) : this.forward(from);
    }
    // animateTo / animateBack / fling: a move to `target`. An explicit
    // duration is this move's; a default one is a full pass's (`fb`); a
    // fling (`vel`) takes the time its spring takes. `x` is the curve's CSS
    // easing, over the stretch of the move.
    mv(m, target, ex, fb, fwd, x, vel) {
      this.live(m);
      if (!isFinite(target)) bad('target', target, 'must be a finite number');
      const base = vel != null ? { us: 0 } : chk(ex, 'duration') ?? need(fb, m), t = this.cl(target);
      this.fw = fwd;
      return new Promise((ok) => {
        batch(() => {
          const v = this.value;
          this.halt();
          const fr = Math.abs(t - v) / (this.upperBound - this.lowerBound);
          let us = ex ? base.us : base.us * fr;
          if (vel != null && fr !== 0) {
            const [ms, css] = spring(Math.abs(t - v), vel);
            us = ms * 1000;
            x = css;
          }
          if (fr === 0 || us === 0) return this.jump(t, 1);
          const e = t === this.lowerBound || t === this.upperBound ? null : this.toT(t), r = t < v;
          this.go({ f: this.toT(v), w: { us: ex || vel != null ? Math.round(us / fr) : base.us }, r, i: e == null ? 1 : r ? 1 - e : e, a: false, e, x }, fwd ? 1 : 2);
        });
        this.pb.peek() ? this.pr.push(ok) : ok();
      });
    }
    animateTo(target, duration, c) {
      return this.mv('animateTo', target, duration, this.d, true, curve(c));
    }
    animateBack(target, duration, c) {
      return this.mv('animateBack', target, duration, this.rd ?? this.d, false, curve(c));
    }
    // Flutter's spring, sampled into an easing (the browser has no springs).
    fling(velocity = 1) {
      if (!isFinite(velocity)) bad('velocity', velocity, 'must be finite');
      return this.mv('fling', velocity < 0 ? this.lowerBound : this.upperBound, null, null, velocity >= 0, null, Math.abs(velocity));
    }
    repeat(min, max, reverse = false, period, count) {
      this.live('repeat');
      const p = need(chk(period, 'period') ?? this.d, 'repeat');
      if (count != null && count < 1) bad('count', count, 'must be at least 1');
      const lo = min ?? this.lowerBound, hi = max ?? this.upperBound;
      batch(() => {
        this.halt();
        if (p.us === 0) return;
        this.fw = true;
        const m = lo > this.lowerBound || hi < this.upperBound ? [this.toT(lo), this.toT(hi)] : null;
        this.go({ f: this.toT(this.value), w: p, r: false, i: count ?? Infinity, a: reverse, m }, 1);
      });
    }
    stop() {
      if (this.pb.peek() == null) return;
      const v = this.value;
      batch(() => {
        this.halt();
        this.v.value = v;
        this.seek(this.toT(v));
      });
    }
    reset() {
      this.value = this.lowerBound;
    }
    dispose() {
      this.stop();
      this.x = 1;
    }
    // The page's animation reached its end.
    fin() {
      if (this.pb.peek() == null) return;
      const v = this.fT(this.t), part = this.pb.peek().e != null;
      batch(() => {
        this.halt();
        this.v.value = v;
        // A move that stopped short of the bound ends like Flutter's: completed
        // if the call ran forwards, dismissed if backwards.
        this.st(part ? this.end() : v >= this.upperBound ? 3 : this.at(v));
      });
    }
    to(target, sweep) {
      const v = this.value;
      this.halt();
      if (sweep.us === 0 || v === target) return this.jump(target);
      this.go(
        { f: this.toT(v), w: sweep, r: target === this.lowerBound, i: 1, a: false },
        target === this.upperBound ? 1 : 2,
      );
    }
    go(p, status) {
      // Reduced motion: nothing moves; it jumps to where the playback rests.
      if (this.rm) return p.e != null ? this.jump(this.lowerBound + p.e * (this.upperBound - this.lowerBound), 1) : this.jump(p.m ? this.lowerBound + p.m[1] * (this.upperBound - this.lowerBound) : p.r ? this.lowerBound : this.upperBound);
      this.pb.value = p;
      this.st(status);
      this.play(p);
    }
    // With `fin` the status is the one a finished animateTo / animateBack
    // has, wherever it landed.
    jump(target, fin) {
      this.halt();
      this.v.value = target;
      this.seek(this.toT(target));
      this.st(fin ? this.end() : this.at(target));
    }
    end() {
      return this.fw ? 3 : 0;
    }
    at(v) {
      return v === this.lowerBound ? 0 : v === this.upperBound ? 3 : this.fw ? 1 : 2;
    }
    st(next) {
      if (this.s.peek() !== next) this.s.value = next;
    }
    cl(v) {
      return Math.min(Math.max(v, this.lowerBound), this.upperBound);
    }
    toT(v) {
      return (v - this.lowerBound) / (this.upperBound - this.lowerBound);
    }
    fT(t) {
      return this.cl(this.lowerBound + t * (this.upperBound - this.lowerBound));
    }
  }

  T.ctl.anim = (id, ...a) => new Anim(id, ...a);
})(thor, document);

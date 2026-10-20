// thor-lite part "duration": Dart's Duration (microseconds, an integer JS
// number like Dart's on the web) for translated states. `eq` is Dart's `==`;
// the operators are methods (`plus`, `minus`, `times`, `div`, `neg`).
((T) => {
  const tdiv = (a, b) => Math.trunc(a / b) || 0;
  class Dur {
    constructor(us) {
      this.us = us;
    }
    static of(d = 0, h = 0, mi = 0, s = 0, ms = 0, us = 0) {
      return new Dur(us + 1000 * ms + 1e6 * s + 6e7 * mi + 36e8 * h + 864e8 * d);
    }
    get inDays() {
      return tdiv(this.us, 864e8);
    }
    get inHours() {
      return tdiv(this.us, 36e8);
    }
    get inMinutes() {
      return tdiv(this.us, 6e7);
    }
    get inSeconds() {
      return tdiv(this.us, 1e6);
    }
    get inMilliseconds() {
      return tdiv(this.us, 1000);
    }
    get inMicroseconds() {
      return this.us;
    }
    get isNegative() {
      return this.us < 0;
    }
    abs() {
      return new Dur(Math.abs(this.us));
    }
    neg() {
      return new Dur(0 - this.us);
    }
    plus(o) {
      return new Dur(this.us + o.us);
    }
    minus(o) {
      return new Dur(this.us - o.us);
    }
    // Rounded half away from zero, like Dart's `round()`.
    times(f) {
      const x = this.us * f;
      return new Dur(x < 0 ? 0 - Math.round(0 - x) : Math.round(x));
    }
    div(q) {
      if (q === 0) throw new Error('IntegerDivisionByZeroException');
      return new Dur(tdiv(this.us, q));
    }
    compareTo(o) {
      return this.us < o.us ? -1 : this.us > o.us ? 1 : 0;
    }
    eq(o) {
      return o instanceof Dur && this.us === o.us;
    }
    toString() {
      let us = this.us, h = tdiv(us, 36e8);
      const neg = us < 0;
      us %= 36e8;
      if (neg) (h = 0 - h), (us = 0 - us);
      const p2 = (n) => (n < 10 ? '0' : '') + n;
      return `${neg ? '-' : ''}${h}:${p2(tdiv(us, 6e7))}:${p2(tdiv(us % 6e7, 1e6))}.${`${us % 1e6}`.padStart(6, '0')}`;
    }
  }
  Dur.zero = new Dur(0);
  (T.dt ||= {}).Dur = Dur;
})(thor);

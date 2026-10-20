// thor-lite part "datetime": Dart's DateTime for states translated from Dart
// (thor_builder's lite_state_js), loaded only when a state uses it. The
// semantics are Dart's on the web (the dart2js engine's): milliseconds since
// the epoch + a microsecond (0–999) + whether it is UTC; the local fields
// come from the browser's Date, the text forms are Dart's. `eq` is Dart's
// `==`. Methods returning a Duration need the "duration" part.
((T) => {
  const MAX = 864e13;
  const mod = (a, b) => ((a % b) + b) % b;
  const p2 = (n) => (n < 10 ? '0' : '') + n;
  const p3 = (n) => (n < 10 ? '00' : n < 100 ? '0' : '') + n;
  const p4 = (n) => {
    const a = Math.abs(n);
    return a >= 1000 ? `${n}` : (n < 0 ? '-' : '') + (a < 10 ? '000' : a < 100 ? '00' : '0') + a;
  };
  const bad = (m) => {
    throw new Error(m);
  };

  // Primitives.valueFromDecomposedDate: milliseconds, or null out of range.
  function value(u, y, mo, d, h, mi, s, ms, us) {
    let m = mo - 1;
    if (0 <= y && y < 100) {
      y += 400;
      m -= 4800;
    }
    const lo = mod(us, 1000);
    ms += (us - lo) / 1000;
    const v = u ? Date.UTC(y, m, d, h, mi, s, ms) : new Date(y, m, d, h, mi, s, ms).valueOf();
    return Number.isNaN(v) || v < -MAX || v > MAX || (v === MAX && lo) ? null : v;
  }

  const checked = (v, us, u) => {
    if (us < 0 || us > 999 || v < -MAX || v > MAX || (v === MAX && us)) bad(`RangeError: ${v}, ${us}`);
    return new DT(v, us, u);
  };

  class DT {
    constructor(v, us, u) {
      this.v = v; // millisecondsSinceEpoch
      this.us = us; // microsecond, 0–999
      this.u = u; // isUtc
    }
    // DateTime(...) (u false) / DateTime.utc(...) (u true).
    static of(u, y, mo = 1, d = 1, h = 0, mi = 0, s = 0, ms = 0, us = 0) {
      const v = value(u, y, mo, d, h, mi, s, ms, us);
      if (v == null) bad(`Invalid argument(s): (${y}, ${mo}, ${d}, ${h}, ${mi}, ${s}, ${ms}, ${us})`);
      return new DT(v, mod(us, 1000), u);
    }
    static now(u) {
      return new DT(Date.now(), 0, u);
    }
    static ms(v, u = false) {
      return checked(v, 0, u);
    }
    static micro(us, u = false) {
      const lo = mod(us, 1000);
      return checked((us - lo) / 1000, lo, u);
    }
    // A DateTime, null (no match) or undefined (out of range).
    static p(s) {
      const m = /^([+-]?\d{4,6})-?(\d\d)-?(\d\d)(?:[ T](\d\d)(?::?(\d\d)(?::?(\d\d)(?:[.,](\d+))?)?)?( ?[zZ]| ?([-+])(\d\d)(?::?(\d\d))?)?)?$/.exec(s);
      if (!m) return null;
      const n = (x) => (x == null ? 0 : parseInt(x, 10));
      let f = 0;
      for (let i = 0; i < 6; i++) f = f * 10 + (m[7] && i < m[7].length ? m[7].charCodeAt(i) ^ 0x30 : 0);
      let mi = n(m[5]);
      const u = m[8] != null;
      if (m[9]) mi -= (m[9] === '-' ? -1 : 1) * (n(m[11]) + 60 * n(m[10]));
      const us = f % 1000;
      const v = value(u, n(m[1]), n(m[2]), n(m[3]), n(m[4]), mi, n(m[6]), (f - us) / 1000, us);
      return v == null ? undefined : checked(v, us, u);
    }
    static parse(s) {
      const d = DT.p(s);
      if (d == null) bad(`FormatException: ${d === null ? 'Invalid date format' : 'Time out of range'}\n${s}`);
      return d;
    }
    static tryParse(s) {
      return DT.p(s) ?? null;
    }
    // [year, month, day, hour, minute, second, millisecond, JS day] (computed once).
    get f() {
      if (!this.x) {
        const j = new Date(this.v), g = this.u ? 'getUTC' : 'get';
        this.x = ['FullYear', 'Month', 'Date', 'Hours', 'Minutes', 'Seconds', 'Milliseconds', 'Day'].map((n) => j[g + n]() + 0);
        this.x[1]++;
      }
      return this.x;
    }
    get year() {
      return this.f[0];
    }
    get month() {
      return this.f[1];
    }
    get day() {
      return this.f[2];
    }
    get hour() {
      return this.f[3];
    }
    get minute() {
      return this.f[4];
    }
    get second() {
      return this.f[5];
    }
    get millisecond() {
      return this.f[6];
    }
    get weekday() {
      return ((this.f[7] + 6) % 7) + 1;
    }
    get microsecond() {
      return this.us;
    }
    get isUtc() {
      return this.u;
    }
    get millisecondsSinceEpoch() {
      return this.v;
    }
    get microsecondsSinceEpoch() {
      return 1000 * this.v + this.us;
    }
    get timeZoneOffset() {
      return new T.dt.Dur(this.u ? 0 : -new Date(this.v).getTimezoneOffset() * 6e7);
    }
    toUtc() {
      return this.u ? this : new DT(this.v, this.us, true);
    }
    toLocal() {
      return this.u ? new DT(this.v, this.us, false) : this;
    }
    add(d) {
      return this.m(d.us);
    }
    subtract(d) {
      return this.m(0 - d.us);
    }
    m(d) {
      const lo = mod(d, 1000), s = this.us + lo, us = s % 1000;
      return checked(this.v + (s - us) / 1000 + (d - lo) / 1000, us, this.u);
    }
    difference(o) {
      return new T.dt.Dur((this.v - o.v) * 1000 + this.us - o.us);
    }
    isBefore(o) {
      return this.compareTo(o) < 0;
    }
    isAfter(o) {
      return this.compareTo(o) > 0;
    }
    isAtSameMomentAs(o) {
      return this.v === o.v && this.us === o.us;
    }
    compareTo(o) {
      return this.v < o.v ? -1 : this.v > o.v ? 1 : this.us < o.us ? -1 : this.us > o.us ? 1 : 0;
    }
    eq(o) {
      return o instanceof DT && this.v === o.v && this.us === o.us && this.u === o.u;
    }
    copyWith(y, mo, d, h, mi, s, ms, us, u) {
      const f = this.f;
      return DT.of(u ?? this.u, y ?? f[0], mo ?? f[1], d ?? f[2], h ?? f[3], mi ?? f[4], s ?? f[5], ms ?? f[6], us ?? this.us);
    }
    t(sep, y) {
      const f = this.f;
      return `${y}-${p2(f[1])}-${p2(f[2])}${sep}${p2(f[3])}:${p2(f[4])}:${p2(f[5])}.${p3(f[6])}${this.us ? p3(this.us) : ''}${this.u ? 'Z' : ''}`;
    }
    toString() {
      return this.t(' ', p4(this.f[0]));
    }
    toIso8601String() {
      const y = this.f[0], a = Math.abs(y);
      return this.t('T', a <= 9999 ? p4(y) : (y < 0 ? '-' : '+') + (a >= 1e5 ? '' : '0') + a);
    }
  }

  (T.dt ||= {}).DT = DT;
})(thor);

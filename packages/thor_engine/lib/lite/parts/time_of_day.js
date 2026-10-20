// thor-lite part "time_of_day": thor's TimeOfDay (package:thor_engine
// dates.dart) for translated states. `period` is DayPeriod's index.
((T) => {
  class TOD {
    constructor(hour, minute) {
      this.hour = hour;
      this.minute = minute;
    }
    static from(d) {
      return new TOD(d.hour, d.minute);
    }
    replacing(h, m) {
      return new TOD(h ?? this.hour, m ?? this.minute);
    }
    get period() {
      return this.hour < 12 ? 0 : 1;
    }
    get hourOfPeriod() {
      return this.hour === 0 || this.hour === 12 ? 12 : this.hour % 12;
    }
    get periodOffset() {
      return this.period * 12;
    }
    compareTo(o) {
      return this.hour * 60 + this.minute - (o.hour * 60 + o.minute);
    }
    isBefore(o) {
      return this.compareTo(o) < 0;
    }
    isAfter(o) {
      return this.compareTo(o) > 0;
    }
    isAtSameTimeAs(o) {
      return this.compareTo(o) === 0;
    }
    eq(o) {
      return o instanceof TOD && this.hour === o.hour && this.minute === o.minute;
    }
    toString() {
      const p2 = (n) => (n < 10 ? '0' : '') + n;
      return `TimeOfDay(${p2(this.hour)}:${p2(this.minute)})`;
    }
  }
  (T.dt ||= {}).TOD = TOD;
})(thor);

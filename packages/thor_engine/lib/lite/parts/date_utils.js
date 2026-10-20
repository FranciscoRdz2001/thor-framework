// thor-lite part "date_utils": thor's DateUtils (package:thor_engine
// dates.dart) for translated states; needs the "datetime" part.
((T) => {
  const of = (y, m, d) => T.dt.DT.of(false, y, m, d);
  const same = (a, b, day) => a?.year === b?.year && a?.month === b?.month && (!day || a?.day === b?.day) && a != null;
  T.dt.DU = {
    dateOnly: (d) => of(d.year, d.month, d.day),
    isSameDay: (a, b) => same(a, b, 1),
    isSameMonth: (a, b) => same(a, b, 0),
    monthDelta: (a, b) => (b.year - a.year) * 12 + b.month - a.month,
    addMonthsToMonthDate: (d, n) => of(d.year, d.month + n),
    addDaysToDate: (d, n) => of(d.year, d.month, d.day + n),
    getDaysInMonth: (y, m) => (m === 2 ? ((y % 4 === 0 && y % 100 !== 0) || y % 400 === 0 ? 29 : 28) : [31, 0, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1]),
  };
})(thor);

// thor-lite part "date_picker": CalendarDatePicker, DatePickerDialog,
// TimePickerDialog and the date fields (the dart2js engine's
// DatePickerFeature: month navigation, the year list, picking a day, the ARIA
// date-grid keyboard, the dialogs' confirm / cancel). Loaded when the page
// has a calendar or a picker dialog.
//
// The server renders the first month (6 × 7 cells, always); this rewrites the
// texts and attributes of those same cells for the others. Selecting a day
// writes `yyyy-mm-dd` into the calendar's hidden input and fires `change`
// there, where `onDateChanged` is bound like any control's callback. Dates
// are UTC milliseconds (whole days).
((W, D) => {
  const DAY = 864e5;
  const utc = (y, m, d = 1) => Date.UTC(y, m - 1, d);
  const Y = (t) => new Date(t).getUTCFullYear();
  const M = (t) => new Date(t).getUTCMonth() + 1;
  const Dd = (t) => new Date(t).getUTCDate();
  const wd = (t) => new Date(t).getUTCDay(); // 0 = Sunday
  const inMonth = (y, m) => new Date(Date.UTC(y, m, 0)).getUTCDate();
  const p = (n, w) => `${n}`.padStart(w, '0');
  const iso = (t) => `${p(Y(t), 4)}-${p(M(t), 2)}-${p(Dd(t), 2)}`;
  // `yyyy-mm-dd` or `yyyy-mm` (the 1st), or null.
  const parse = (s) => {
    const f = s?.split('-');
    if (!f || f.length < 2 || f.length > 3) return null;
    const n = (x) => (/^[+-]?\d+$/.test(x.trim()) ? +x : null);
    const y = n(f[0]), m = n(f[1]), d = f.length === 3 ? n(f[2]) : 1;
    return y == null || m == null || d == null || m < 1 || m > 12 || d < 1 || d > inMonth(y, m) ? null : utc(y, m, d);
  };
  const ALPHA = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
  // The disabled days (`encodeDayMask`), as a function of the day index (0 = first): two characters of header (bits 0-6 the
  // weekdays off on every day, bit 7 = six days a character), then run lengths (5 bits a character, bit 5 = more) or the bitmap.
  const decodeMask = (mask, first) => {
    const h = ALPHA.indexOf(mask[0]) | (ALPHA.indexOf(mask[1]) << 6);
    const w0 = wd(first);
    const body = mask.slice(2);
    const flips = [];
    if (!(h & 128)) {
      for (let k = 0, at = 0, n = 0, s = 0; k < body.length; k++) {
        const v = ALPHA.indexOf(body[k]);
        n += (v & 31) * 2 ** s;
        if (v & 32) s += 5;
        else flips.push((at += n)), (n = s = 0);
      }
    }
    return (i) => {
      if (i < 0) return false;
      if ((h >> ((w0 + i) % 7)) & 1) return true;
      if (h & 128) return Math.trunc(i / 6) < body.length && ((ALPHA.indexOf(body[Math.trunc(i / 6)]) >> i % 6) & 1) === 1;
      let lo = 0, hi = flips.length;
      while (lo < hi) {
        const mid = (lo + hi) >> 1;
        if (flips[mid] <= i) lo = mid + 1;
        else hi = mid;
      }
      return (lo & 1) === 1;
    };
  };
  const el = (t) => (t?.closest ? t : null);
  const flag = (e, n, on, v) => (on ? e.getAttribute(n) !== v && e.setAttribute(n, v) : e.removeAttribute(n));

  const cals = new WeakMap();
  const cal = (root) => {
    let c = cals.get(root);
    if (!c) cals.set(root, (c = new Cal(root)));
    return c;
  };

  class Cal {
    constructor(root) {
      this.root = root;
      const f = root.getAttribute('data-t-date').split('|');
      this.first = parse(f[0]);
      this.last = parse(f[1]);
      this.t0 = parse(f[2]);
      this.fdw = +f[3];
      this.months = f[4].split(',');
      this.shortMonths = f[5].split(',');
      this.shortDays = f[6].split(',');
      this.monthYear = f[7];
      this.medium = f[8];
      this.noDate = f[9];
      this.mask = f[10] ? decodeMask(f[10], this.first) : null;
      // The locale's digits (`٠١٢…`): the server writes numbers with them.
      this.digits = Array.from(f[11] || '0123456789');
      // Without the page's currentDate: the reader's today.
      const now = new Date();
      this.today = this.t0 ?? utc(now.getFullYear(), now.getMonth() + 1, now.getDate());
      this.month = parse(root.getAttribute('data-t-month'));
    }
    num(n) {
      return `${n}`.replace(/\d/g, (c) => this.digits[+c] ?? c);
    }
    get input() {
      return this.root.querySelector('[data-t-value]');
    }
    get value() {
      return parse(this.input.value);
    }
    enabled(t) {
      return t >= this.first && t <= this.last && !(this.mask && this.mask(Math.round((t - this.first) / DAY)));
    }
    clamp(t) {
      return t < this.first ? this.first : t > this.last ? this.last : t;
    }
    dateOf(cell) {
      // By position, not by text: the digits may not be ASCII.
      const i = Array.prototype.indexOf.call(this.root.querySelectorAll('[data-t-days] td'), cell);
      const n = i - this.offset() + 1;
      return i < 0 || n < 1 || n > inMonth(Y(this.month), M(this.month)) ? null : utc(Y(this.month), M(this.month), n);
    }
    offset() {
      return (((wd(this.month) - this.fdw) % 7) + 7) % 7;
    }
    show(to, focus, move) {
      const m = utc(Y(to), M(to));
      const lo = utc(Y(this.first), M(this.first)), hi = utc(Y(this.last), M(this.last));
      const t = m < lo ? lo : m > hi ? hi : m;
      const changed = t !== this.month;
      this.month = t;
      this.render(focus);
      if (changed) {
        this.root.setAttribute('data-t-month', iso(t).slice(0, 7));
        this.root.dispatchEvent(new CustomEvent('thor-month', { bubbles: true, detail: iso(t) }));
      }
      if (move) this.focused()?.focus();
    }
    focused() {
      return this.root.querySelector('[data-t-days] td[tabindex="0"]');
    }
    render(focus) {
      const y = Y(this.month), m = M(this.month);
      const off = this.offset();
      const count = inMonth(y, m);
      const dayIn = (t) => (t != null && Y(t) === y && M(t) === m ? Dd(t) : null);
      const enabledIn = (t) => {
        const n = dayIn(t);
        return n != null && this.enabled(utc(y, m, n)) ? n : null;
      };
      const sel = this.value;
      // The keyboard may rest on a disabled day; the first stop may not.
      let stop = dayIn(focus) ?? enabledIn(sel) ?? enabledIn(this.today);
      for (let d = 1; d <= count && stop == null; d++) if (this.enabled(utc(y, m, d))) stop = d;
      stop ??= 1;
      const s = dayIn(sel), now = dayIn(this.today);
      const auto = !!this.root.closest('dialog');
      const cells = this.root.querySelectorAll('[data-t-days] td');
      for (let i = 0; i < cells.length && i < 42; i++) {
        const cell = cells[i], n = i - off + 1;
        const day = n >= 1 && n <= count ? n : null;
        const text = day == null ? '' : this.num(day);
        if (cell.textContent !== text) cell.textContent = text;
        if (day == null) {
          for (const a of ['tabindex', 'autofocus', 'aria-selected', 'aria-current', 'aria-disabled']) cell.removeAttribute(a);
          continue;
        }
        cell.setAttribute('tabindex', day === stop ? '0' : '-1');
        flag(cell, 'autofocus', auto && day === stop, '');
        flag(cell, 'aria-selected', day === s, 'true');
        flag(cell, 'aria-current', day === now, 'date');
        flag(cell, 'aria-disabled', !this.enabled(utc(y, m, day)), 'true');
      }
      const label = this.monthYear.replaceAll('{M}', this.months[m - 1]).replaceAll('{y}', this.num(y));
      const span = this.root.querySelector('[data-t-years] span');
      if (span) span.textContent = label;
      this.root.querySelector('[role="grid"]')?.setAttribute('aria-label', label);
      for (const nav of this.root.querySelectorAll('[data-t-nav]')) {
        const end = nav.getAttribute('data-t-nav') === '1' ? this.last : this.first;
        flag(nav, 'disabled', Y(end) === y && M(end) === m, '');
      }
    }
    pick(cell) {
      const day = this.dateOf(cell);
      if (day == null) return;
      cell.focus();
      this.select(day);
    }
    select(day) {
      if (!this.enabled(day)) return;
      const input = this.input, text = iso(day);
      if (input.value !== text) {
        input.value = text;
        input.dispatchEvent(new Event('change', { bubbles: true }));
      }
      this.render(day);
      this.headline();
    }
    // The dialog's headline: the pending date.
    headline() {
      const h = this.root.closest('dialog')?.querySelector('[data-t-headline]');
      if (!h) return;
      const d = this.value;
      h.textContent =
        d == null
          ? this.noDate
          : this.medium.replaceAll('{w}', this.shortDays[wd(d)]).replaceAll('{m}', this.shortMonths[M(d) - 1]).replaceAll('{d}', this.num(Dd(d)));
    }
    reset(text) {
      this.input.value = text;
      this.mode(false);
      const d = parse(text);
      this.show(d ?? this.today, d);
      this.headline();
    }
    key(cell, e) {
      const day = this.dateOf(cell);
      if (day == null) return false;
      if (e.key === 'Enter' || e.key === ' ') {
        this.select(day);
        return true;
      }
      const rtl = !!this.root.closest('[dir="rtl"]');
      const w = (((wd(day) - this.fdw) % 7) + 7) % 7;
      const byDays = (n) => utc(Y(day), M(day), Dd(day) + n);
      const byMonths = (n) => {
        const t = utc(Y(day), M(day) + n);
        const c = inMonth(Y(t), M(t));
        return utc(Y(t), M(t), Dd(day) > c ? c : Dd(day));
      };
      const to = {
        ArrowLeft: () => byDays(rtl ? 1 : -1),
        ArrowRight: () => byDays(rtl ? -1 : 1),
        ArrowUp: () => byDays(-7),
        ArrowDown: () => byDays(7),
        Home: () => byDays(-w),
        End: () => byDays(6 - w),
        PageUp: () => byMonths(e.shiftKey ? -12 : -1),
        PageDown: () => byMonths(e.shiftKey ? 12 : 1),
      }[e.key];
      if (!to) return false;
      const t = this.clamp(to());
      this.show(t, t, true);
      return true;
    }
    mode(years) {
      this.root.setAttribute('data-t-mode', years ? 'year' : 'day');
      this.root.querySelector('[data-t-years]')?.setAttribute('aria-expanded', `${years}`);
    }
    toggleYears() {
      const years = this.root.getAttribute('data-t-mode') !== 'year';
      this.mode(years);
      if (!years) return this.focused()?.focus();
      const list = this.root.querySelector('[data-t-year-list]');
      if (!list) return;
      if (!list.querySelector('button')) {
        // Filled once, from the server's template button.
        const proto = list.querySelector('template')?.content.firstElementChild;
        if (!proto) return;
        for (let y = Y(this.first); y <= Y(this.last); y++) {
          const b = proto.cloneNode(true);
          b.textContent = this.num(y);
          b.value = y;
          list.append(b);
        }
      }
      let current;
      for (const b of list.querySelectorAll('button')) {
        const y = +b.value, on = y === Y(this.month);
        flag(b, 'aria-pressed', on, 'true');
        flag(b, 'aria-current', y === Y(this.today), 'date');
        if (on) current = b;
      }
      current?.focus();
      current?.scrollIntoView({ block: 'center' });
    }
    pickYear(year) {
      this.mode(false);
      const s = this.value;
      this.show(utc(year, M(this.month)), s != null && Y(s) === year ? s : null, true);
    }
  }

  // Where a picker dialog's result goes: the field it names, or its own hidden input.
  const out = (dialog) => {
    const t = dialog.getAttribute('data-t-picker');
    return t ? D.getElementById(t) : dialog.querySelector('[data-t-pick-out]');
  };
  // OK: the pending value becomes the result (`change` on the output).
  const confirm = (dialog) => {
    const o = out(dialog), pending = dialog.querySelector('[data-t-pick]');
    if (o && pending && o.value !== pending.value) {
      o.value = pending.value;
      o.dispatchEvent(new Event('change', { bubbles: true }));
    }
    dialog.close();
  };
  // The pending value back to the result (on open and on cancel).
  const reset = (dialog) => {
    const o = out(dialog), pending = dialog.querySelector('[data-t-pick]');
    if (!o || !pending) return;
    const root = pending.closest('[data-t-date]');
    if (root) cal(root).reset(o.value);
    else pending.value = o.value;
  };

  // At load: controls that only work with a runtime, the reader's today.
  for (const b of D.querySelectorAll('[data-t-date-open][hidden]')) b.removeAttribute('hidden');
  for (const root of D.querySelectorAll('[data-t-date]')) {
    const c = cal(root);
    if (c.t0 == null) c.render();
  }
  for (const f of D.querySelectorAll('[data-t-date-field]')) f.setAttribute('data-t-ready', '');

  const R = D.documentElement;
  R.addEventListener('click', (e) => {
    const t = el(e.target);
    if (!t) return;
    const cell = t.closest('td'), root = t.closest('[data-t-date]');
    if (root && cell && root.contains(cell)) return cal(root).pick(cell);
    const nav = t.closest('[data-t-nav]');
    if (root && nav) {
      const c = cal(root);
      return c.show(utc(Y(c.month), M(c.month) + +nav.getAttribute('data-t-nav')));
    }
    if (root && t.closest('[data-t-years]')) return cal(root).toggleYears();
    const year = t.closest('[data-t-year-list] button');
    if (root && year) return cal(root).pickYear(+year.value);
    const ok = t.closest('[data-t-pick-ok]');
    if (ok) {
      const d = ok.closest('dialog');
      return d && confirm(d);
    }
    const open = t.closest('[data-t-date-open]');
    // Before the command opens it: start from the field's value.
    const dialog = open && D.getElementById(open.getAttribute('commandfor') ?? '');
    if (dialog) reset(dialog);
  });
  R.addEventListener('keydown', (e) => {
    const t = el(e.target);
    const root = t?.localName === 'td' && t.closest('[data-t-date]');
    if (root && cal(root).key(t, e)) e.preventDefault();
  });
  // Closing without confirming (Cancel, Esc, the backdrop, a controller) drops the pending value.
  R.addEventListener(
    'close',
    (e) => {
      const t = el(e.target);
      if (t?.hasAttribute('data-t-picker')) reset(t);
    },
    true,
  );
  // A cleared date field has no date for `onDateSubmitted`.
  R.addEventListener(
    'change',
    (e) => {
      const t = el(e.target);
      if (t?.hasAttribute('data-t-date-field') && !t.value) e.stopImmediatePropagation();
    },
    true,
  );
  (W.thorEvents ||= []).push('thor-month');
})(window, document);

// thor-lite part "text_controller": TextEditingController (needs "controllers").
((T, D) => {
  const { all, find, of, on } = T.ctl;
  const val = (el) => (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' ? el.value : '');
  const put = (el, t) => {
    if ((el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') && el.value !== t) {
      el.value = t;
      T.count(el);
    }
  };
  // A caret or a range, from where it started (`baseOffset`) to where it
  // ends (Flutter's TextSelection); -1 is "nowhere yet".
  class Sel {
    constructor(b, e = b) {
      this.baseOffset = b;
      this.extentOffset = e;
    }
    get start() {
      return Math.min(this.baseOffset, this.extentOffset);
    }
    get end() {
      return Math.max(this.baseOffset, this.extentOffset);
    }
    get isCollapsed() {
      return this.baseOffset === this.extentOffset;
    }
    get isValid() {
      return this.start >= 0;
    }
    eq(o) {
      return this.baseOffset === o.baseOffset && this.extentOffset === o.extentOffset;
    }
    toString() {
      return `TextSelection(${this.baseOffset}, ${this.extentOffset})`;
    }
  }
  // Flutter's TextEditingValue: the text and the selection together.
  class Val {
    constructor(text = '', selection = new Sel(-1)) {
      this.text = text;
      this.selection = selection;
    }
    copyWith(text, selection) {
      return new Val(text ?? this.text, selection ?? this.selection);
    }
    eq(o) {
      return this.text === o.text && this.selection.eq(o.selection);
    }
    toString() {
      return `TextEditingValue(text: "${this.text}", selection: ${this.selection})`;
    }
  }
  class Text {
    constructor(id, text) {
      all[(this.id = id)] = this;
      // The server wrote its text into the field; the user may have typed since.
      const el = find('data-ttc', id);
      this.t = T.signal(el ? val(el) : (text ?? ''));
      this.s = T.signal(new Sel(-1));
      T.effect(() => {
        const t = this.t.value;
        for (const el of D.querySelectorAll(`[data-ttc="${id}"]`)) put(el, t);
      });
    }
    get text() {
      return this.t.value;
    }
    // The browser puts the caret at the end of a value it is given (not of
    // the one it already has).
    set text(v) {
      if (v !== this.t.peek())
        T.batch(() => {
          this.t.value = v;
          this.s.value = new Sel(v.length);
        });
    }
    clear() {
      this.text = '';
    }
    get value() {
      return new Val(this.text, this.selection);
    }
    // A new text with no valid selection puts the caret at its end; the same
    // text with none leaves it invalid (see the Dart controller).
    set value(v) {
      T.batch(() => {
        const changed = v.text !== this.t.peek();
        this.text = v.text;
        if (v.selection.isValid || !changed) this.selection = v.selection;
      });
    }
    get selection() {
      return this.s.value;
    }
    // Offsets past the text stop at its ends (as `setSelectionRange` does);
    // a negative one is "nowhere". It lands after this method's other
    // changes (the text it is for may be set in the same method) and the
    // field's own answer is read back.
    set selection(v) {
      const n = this.t.peek().length, f = (o) => Math.min(o, n);
      const next = v.isValid ? new Sel(f(v.baseOffset), f(v.extentOffset)) : new Sel(-1);
      // The same selection is not a change for whoever reads it; the fields
      // still hear it (they may normalise the text, CRLF, and the read-back
      // below says what they really have).
      if (!next.eq(this.s.peek())) this.s.value = next;
      queueMicrotask(() => {
        const s = this.s.peek();
        if (!s.isValid) return;
        for (const el of D.querySelectorAll(`[data-ttc="${this.id}"]`)) {
          try {
            el.setSelectionRange(s.start, s.end, s.baseOffset > s.extentOffset ? 'backward' : 'none');
            this.rd(el);
          } catch {} // a type with no selection (email, number)
        }
      });
    }
    // What the visitor did: the field's caret or range.
    rd(el) {
      const a = el.selectionStart, z = el.selectionEnd;
      if (a == null) return;
      const s = el.selectionDirection === 'backward' ? new Sel(z, a) : new Sel(a, z);
      if (!s.eq(this.s.peek())) this.s.value = s;
    }
  }
  // Capture: the controller holds the new text before any `onChanged`.
  on(
    'input',
    (e) => {
      const c = of('data-ttc', e.target);
      if (c) T.batch(() => ((c.t.value = val(e.target)), c.rd(e.target)));
    },
    true,
  );
  // The caret is the focused field's: a field another one's text was put
  // into moves its own caret, which is not the visitor's.
  for (const t of ['select', 'selectionchange', 'keyup']) {
    on(
      t,
      (e) => {
        const c = e.target === D.activeElement && of('data-ttc', e.target);
        if (c) c.rd(e.target);
      },
      true,
    );
  }
  // A copy of server markup replaced a subtree: its fields show the controllers' text.
  on(
    'thor:adopted',
    (e) => {
      const r = e.target;
      for (const el of [r, ...r.querySelectorAll('[data-ttc]')]) {
        const c = all[el.getAttribute('data-ttc')];
        if (c) put(el, T.untracked(() => c.text));
      }
    },
    true,
  );

  T.ctl.text = (id, text) => new Text(id, text);
  T.ctl.sel = (b, e) => new Sel(b, e);
  T.ctl.val = (t, s) => new Val(t, s);
})(thor, document);

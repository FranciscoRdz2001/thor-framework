// thor-lite part "focus_node": FocusNode (needs "controllers").
((T, D) => {
  const { all, find, of, on } = T.ctl;
  class Focus {
    constructor(id) {
      all[(this.id = id)] = this;
      const el = find('data-tfn', id);
      this.f = T.signal(!!el && el === D.activeElement);
      this.ls = [];
    }
    // Called each time the focus moves in or out (hasFocus is already new).
    addListener(f) {
      if (this.x) throw new Error('Bad state: A FocusNode was used after being disposed.');
      this.ls.push(f);
    }
    removeListener(f) {
      const i = this.ls.indexOf(f);
      if (i >= 0) this.ls.splice(i, 1);
    }
    dispose() {
      this.x = 1;
      this.ls.length = 0;
    }
    // A listener that throws is reported and does not cut the others short.
    set(v) {
      if (this.f.peek() === v) return;
      this.f.value = v;
      for (const l of [...this.ls]) {
        // One an earlier listener removed is not called.
        if (!this.ls.includes(l)) continue;
        try {
          l();
        } catch (e) {
          (window.reportError || console.error)(e);
        }
      }
    }
    get hasFocus() {
      return this.f.value;
    }
    // After the current batch (the element may appear in the same method);
    // scrolls it into view too, like the dart2js engine.
    requestFocus() {
      queueMicrotask(() => {
        const el = find('data-tfn', this.id);
        if (!el) return;
        el.focus({ preventScroll: true });
        el.scrollIntoView({ block: 'nearest', inline: 'nearest' });
      });
    }
    unfocus() {
      const el = find('data-tfn', this.id);
      if (el && D.activeElement === el) el.blur();
    }
  }
  const focus = (v) => (e) => {
    const c = of('data-tfn', e.target);
    if (c) c.set(v);
  };
  on('focusin', focus(true));
  on('focusout', focus(false));

  T.ctl.focus = (id) => new Focus(id);
})(thor, document);

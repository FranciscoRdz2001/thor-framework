// thor-lite part "dialog_controller": DialogController (needs "controllers").
((T, D) => {
  const { all, find, of, on } = T.ctl;
  class Dialog {
    constructor(id) {
      all[(this.id = id)] = this;
      this.o = T.signal(!!find('data-tdc', id)?.open);
    }
    get isOpen() {
      return this.o.value;
    }
    get d() {
      const d = find('data-tdc', this.id);
      return d?.showModal ? d : null;
    }
    // After the current batch: the dialog's content changes in the same method.
    open() {
      this.o.value = true;
      queueMicrotask(() => {
        const d = this.d;
        if (d && !d.open) d.showModal();
      });
    }
    close() {
      this.o.value = false;
      const d = this.d;
      if (d?.open) d.close();
    }
  }
  // `close` and `toggle` don't bubble: captured.
  const dialog = (e) => {
    const d = e.target;
    if (d?.tagName === 'DIALOG') {
      const c = of('data-tdc', d);
      if (c) c.o.value = d.open;
    }
  };
  on('close', dialog, true);
  on('toggle', dialog, true);

  T.ctl.dialog = (id) => new Dialog(id);
})(thor, document);

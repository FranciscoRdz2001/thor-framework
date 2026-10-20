// thor-lite part "controllers": what ScrollController, TextEditingController,
// FocusNode and DialogController (one part each: scroll_controller,
// text_controller, focus_node, dialog_controller) share, as fields of a
// translated state (the dart2js engine's ControllersFeature). Loaded only
// when a state has one.
//
// The page names a controller by id on its element (`data-tsc`, `data-ttc`,
// `data-tfn`, `data-tdc` = `State.field`). A controller starts from its
// element (the dialog's `open`, the field's text, the focus, the scroll
// position), so a state can still be created lazily: an event on one of
// those elements (typing, focus, a dialog opening or closing, a scroll)
// creates the state that owns it first, then updates the controller. A
// state with a ScrollController is created at load (its measures can be
// shown), like every state in the dart2js engine.
((T, D) => {
  const all = {}; // controller id → controller (states already created)
  const find = (a, id) => D.querySelector(`[${a}="${id}"]`);
  // The controller of `el` for attribute `a`, creating its state if needed.
  const of = (a, el) => {
    const id = el?.getAttribute?.(a);
    if (id == null) return;
    if (!all[id]) T.use(id.slice(0, id.lastIndexOf('.')));
    return all[id];
  };
  const on = (t, f, o) => D.documentElement.addEventListener(t, f, o);

  T.ctl = { all, find, of, on };
})(thor, document);

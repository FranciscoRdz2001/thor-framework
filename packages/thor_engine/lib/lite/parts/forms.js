// thor-lite part "forms": native validation with the page's own messages
// (the dart2js engine's FormsFeature). Loaded when the page has a
// `data-t-validate` field.
//
// The browser checks the rules (required, minlength, pattern…); this only
// writes the message of the first failing rule (`data-msg-<flag>`) into the
// field's `aria-describedby` element (its `data-helper` text otherwise),
// toggles `aria-invalid` and `data-invalid`, and replaces the browser's
// bubble on submit. Messages show after the user leaves a field or submits,
// and clear as soon as the value is valid.
((D) => {
  const R = D.documentElement;
  if (!R.querySelector('[data-t-validate]')) return;
  const FLAGS = ['valueMissing', 'typeMismatch', 'badInput', 'patternMismatch', 'tooShort', 'tooLong', 'rangeUnderflow', 'rangeOverflow', 'stepMismatch'];
  const touched = new WeakSet();

  function check(input) {
    let msg = null;
    for (const f of FLAGS) {
      if (input.validity[f]) {
        msg = input.getAttribute(`data-msg-${f.toLowerCase()}`) ?? input.validationMessage;
        break;
      }
    }
    input.setAttribute('aria-invalid', `${msg != null}`);
    const id = input.getAttribute('aria-describedby')?.split(' ')[0];
    const box = id == null ? null : D.getElementById(id);
    if (!box) return;
    box.textContent = msg ?? box.getAttribute('data-helper') ?? '';
    msg == null ? box.removeAttribute('data-invalid') : box.setAttribute('data-invalid', '');
  }

  const field = (e) => {
    const t = e.target;
    return t instanceof HTMLInputElement && t.hasAttribute('data-t-validate') ? t : null;
  };

  R.addEventListener('focusout', (e) => {
    const i = field(e);
    if (i) touched.add(i), check(i);
  });
  R.addEventListener('input', (e) => {
    const i = field(e);
    if (i && touched.has(i)) check(i);
  });
  // Fired for each invalid field on submit: our message instead of the
  // browser's bubble (the browser still focuses the first one).
  R.addEventListener(
    'invalid',
    (e) => {
      const i = field(e);
      if (!i) return;
      e.preventDefault();
      touched.add(i);
      check(i);
      if (R.querySelector('[data-t-validate]:invalid') === i) i.focus();
    },
    true,
  );
})(document);

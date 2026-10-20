// "Copy as Markdown": the link goes to the page's .md (that is what it
// does without JavaScript); with it, the click copies the text instead, and
// the button's name (and its tooltip) says its `data-copied` label ("Copied") for a moment.
document.addEventListener('click', function (e) {
  var a = e.target.closest && e.target.closest('a[data-copy-md], [data-copy-md] a');
  if (!a || !navigator.clipboard || e.metaKey || e.ctrlKey || e.shiftKey) return;
  e.preventDefault();
  var host = a.closest('[data-copy-md]') || a;
  var done = host.getAttribute('data-copied') || '';
  var name = a.getAttribute('aria-label') || '';
  var tip = document.getElementById(a.getAttribute('aria-describedby') || '');
  var tipText = tip && tip.textContent;
  var say = function (text, tipValue) {
    if (text) a.setAttribute('aria-label', text);
    if (tip && tipValue) tip.textContent = tipValue;
  };
  fetch(a.href)
    .then(function (r) { return r.text(); })
    .then(function (md) { return navigator.clipboard.writeText(md); })
    .then(
      function () { say(done, done); },
      function () { location.href = a.href; }
    )
    .then(function () {
      setTimeout(function () { say(name, tipText); }, 1500);
    });
});

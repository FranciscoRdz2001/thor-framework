// The site script, on every page (loaded by the footer): the search field of
// the top bar, Cmd+K / Ctrl+K and "/" open the search dialog, where Pagefind
// answers as you type. Without this script the field is a link to the search
// page (`data-search-href`). The sidebar keeps its own place and brings the
// current page into view (`StudioScaffold.sidebarRestorationId`).
(function () {
  var script = document.currentScript;
  var href = script && script.getAttribute('data-search-href');

  if (!href) return;
  var dialog = document.getElementById('docs-search');
  var out = document.getElementById('docs-search-results');
  var input = dialog && dialog.querySelector('input[name=q]');
  var pill = document.querySelector('header a[href="' + href + '"]');

  // The pill is drawn for the Mac key; elsewhere the hint says Ctrl.
  var mac = /Mac|iPhone|iPad/.test(navigator.platform || navigator.userAgent);
  if (!mac) {
    var hint = pill && pill.querySelector('[role=kbd], kbd');
    if (hint && hint.textContent.trim() === '⌘K') hint.textContent = 'Ctrl K';
  }

  var open = function () {
    if (!dialog || !input) { location.href = href; return; }
    if (!dialog.open) dialog.showModal();
    input.focus();
    input.select();
  };
  document.querySelectorAll('header a[href="' + href + '"]').forEach(function (a) {
    a.addEventListener('click', function (e) {
      if (e.metaKey || e.ctrlKey || e.shiftKey) return;
      e.preventDefault();
      open();
    });
  });
  addEventListener('keydown', function (event) {
    var tag = (event.target && event.target.tagName) || '';
    var typing = /^(INPUT|TEXTAREA|SELECT)$/.test(tag) || (event.target && event.target.isContentEditable);
    var chord = (event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k';
    if (chord || (event.key === '/' && !typing && !event.metaKey && !event.ctrlKey)) {
      event.preventDefault();
      open();
    }
  });
  if (!dialog || !out || !input) return;

  var base = out.getAttribute('data-base') || '/';
  var msg = function (name) { return out.getAttribute('data-msg-' + name) || ''; };
  var clean = function (url) { return url.replace(/(?:index)?\.html$/, '').replace(/(.)\/$/, '$1'); };
  var plain = function (text) {
    return String(text || '').toLowerCase().normalize('NFD')
      .replace(/[̀-ͯ]/g, '').replace(/[`'"«»]/g, '').replace(/\s+/g, ' ').trim();
  };
  var pagefind;
  var load = function () {
    return (pagefind = pagefind || import(base + 'pagefind/pagefind.js').then(function (p) {
      return p.options({ baseUrl: base }).then(function () { return p; });
    }));
  };
  var say = function (text) {
    out.textContent = '';
    var p = document.createElement('p');
    p.className = 'dsr-note';
    p.textContent = text;
    out.appendChild(p);
  };
  var rows = function () { return Array.prototype.slice.call(out.querySelectorAll('.dsr-row')); };
  var mark = function (i) {
    var all = rows();
    all.forEach(function (r, k) {
      if (k === i) { r.setAttribute('data-current', ''); r.scrollIntoView({ block: 'nearest' }); }
      else r.removeAttribute('data-current');
    });
  };
  // The hits by section, the page whose title is the query first.
  var draw = function (query, hits) {
    out.textContent = '';
    if (!hits.length) return say(msg('none').replace('{query}', query));
    var wanted = plain(query);
    var groups = [];
    var byName = {};
    hits.forEach(function (hit) {
      var exact = plain(hit.meta && hit.meta.title) === wanted;
      var name = exact ? msg('best') : (hit.meta && hit.meta.section) || '';
      if (!byName[name]) {
        byName[name] = { name: name, hits: [] };
        if (exact) groups.unshift(byName[name]); else groups.push(byName[name]);
      }
      if (byName[name].hits.length < 6) byName[name].hits.push(hit);
    });
    groups.forEach(function (group) {
      var box = document.createElement('section');
      box.className = 'dsr-group';
      if (group.name) {
        var h = document.createElement('h3');
        h.className = 'dsr-label';
        h.textContent = group.name;
        box.appendChild(h);
      }
      group.hits.forEach(function (hit) {
        // A row: the title is the link, the whole row takes the click.
        var row = document.createElement('div');
        row.className = 'dsr-row';
        var title = document.createElement('a');
        title.className = 'dsr-title';
        title.href = clean(hit.url);
        title.textContent = (hit.meta && hit.meta.title) || clean(hit.url);
        var excerpt = document.createElement('div');
        excerpt.className = 'dsr-excerpt';
        // Pagefind's excerpt: escaped text with <mark> around the matches.
        excerpt.innerHTML = hit.excerpt;
        row.appendChild(title);
        row.appendChild(excerpt);
        row.addEventListener('click', function (e) {
          if (e.target !== title) location.href = title.href;
        });
        box.appendChild(row);
      });
      out.appendChild(box);
    });
    mark(0);
  };
  var run = function () {
    var query = input.value.trim();
    if (!query) return say(msg('prompt'));
    load().then(function (p) {
      return p.debouncedSearch(query, {}, 120);
    }).then(function (found) {
      if (!found) return; // a newer query replaced this one
      return Promise.all(found.results.slice(0, 30).map(function (r) { return r.data(); }))
        .then(function (hits) { draw(query, hits); });
    }).catch(function () { say(msg('error')); });
  };
  input.addEventListener('input', run);
  input.addEventListener('keydown', function (e) {
    var all = rows();
    var i = all.findIndex(function (r) { return r.hasAttribute('data-current'); });
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault();
      if (!all.length) return;
      mark(e.key === 'ArrowDown' ? Math.min(i + 1, all.length - 1) : Math.max(i - 1, 0));
    } else if (e.key === 'Escape') {
      // A search field clears itself on the first Esc; here Esc closes.
      e.preventDefault();
      dialog.close();
    } else if (e.key === 'Enter' && i >= 0) {
      e.preventDefault();
      location.href = all[i].querySelector('a').href;
    }
  });
  // Enter with no hit marked goes to the search page (the form's GET).
})();

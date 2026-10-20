// The search page's enhancement: Pagefind (the index `tool/docs_index.sh`
// writes next to the exported pages) is fetched when there is a query.
(function () {
  var clean = function (url) { return url.replace(/(?:index)?\.html$/, '').replace(/(.)\/$/, '$1'); };

  // A title or a query without case, accents or code marks: "`Row`" and
  // "row" are the same word.
  var plain = function (text) {
    return String(text || '')
      .toLowerCase()
      .normalize('NFD')
      .replace(/[̀-ͯ]/g, '')
      .replace(/[`'"«»]/g, '')
      .replace(/\s+/g, ' ')
      .trim();
  };

  // Orders Pagefind's hits (each with its `score`) for the page: the pages
  // whose title is the query come first, on their own ("best match"); the
  // rest go in sections, the section of the best hit first, and the hits of
  // a section by score. Pagefind already sorts by score: ties keep its order.
  var rank = function (hits, query) {
    var wanted = plain(query);
    var indexed = hits.map(function (hit, i) { return { hit: hit, i: i }; });
    var byScore = function (a, b) {
      return ((b.hit.score || 0) - (a.hit.score || 0)) || (a.i - b.i);
    };
    var isExact = function (x) { return plain(x.hit.meta && x.hit.meta.title) === wanted; };
    var best = indexed.filter(isExact).sort(byScore).map(function (x) { return x.hit; });
    var groups = [];
    var byName = {};
    indexed.filter(function (x) { return !isExact(x); }).sort(byScore).forEach(function (x) {
      var name = (x.hit.meta && x.hit.meta.section) || '';
      if (!byName[name]) {
        byName[name] = { name: name, hits: [], score: x.hit.score || 0 };
        groups.push(byName[name]);
      }
      byName[name].hits.push(x.hit);
    });
    // Sorted by score, the first hit of a group is its best: the groups
    // already stand in the order of their best hit.
    return { best: best, groups: groups };
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = { rank: rank, plain: plain };
  if (typeof document === 'undefined') return;

  var out = document.getElementById('docs-results');
  var input = document.querySelector('main [role=search] input');
  if (!out || !input) return;
  // Where the site lives (`/` or `/thor/`): the server writes it.
  var base = out.getAttribute('data-base') || '/';
  var pagefind;
  // The messages, in the page's language: the server writes them.
  var msg = function (name) { return out.getAttribute('data-msg-' + name) || ''; };
  // The count's message by the page language's plural category (`one`,
  // `few`, `other`…, CLDR); the server writes one per category the language
  // uses, and `other` is always there.
  var rules = new Intl.PluralRules(document.documentElement.lang || undefined);
  var plural = function (count) {
    return msg(rules.select(count)) || msg('other');
  };
  var fill = function (template, values) {
    return template.replace(/{(\w+)}/g, function (_, key) { return values[key]; });
  };
  var load = function () {
    return (pagefind = pagefind || import(base + 'pagefind/pagefind.js').then(function (p) {
      return p.options({ baseUrl: base }).then(function () { return p; });
    }));
  };
  var say = function (text) {
    out.textContent = '';
    var p = document.createElement('p');
    p.className = 'docs-hit-note';
    p.textContent = text;
    out.appendChild(p);
  };
  // Hits of a section show a few at a time; the rest sit behind "show more".
  var PER_GROUP = 4;
  var hitNode = function (hit) {
    var li = document.createElement('div');
    li.className = 'docs-hit';
    var a = document.createElement('a');
    a.className = 'docs-hit-title';
    a.href = clean(hit.url);
    a.textContent = (hit.meta && hit.meta.title) || clean(hit.url);
    var p = document.createElement('p');
    p.className = 'docs-hit-excerpt';
    // Pagefind's excerpt: escaped text with <mark> around the matches.
    p.innerHTML = hit.excerpt;
    li.appendChild(a);
    li.appendChild(p);
    return li;
  };
  var groupNode = function (name, list, limit) {
    var box = document.createElement('section');
    box.className = 'docs-hit-group';
    if (name) {
      var h = document.createElement('h2');
      h.className = 'docs-hit-section';
      h.textContent = name;
      box.appendChild(h);
    }
    var rest = [];
    list.forEach(function (hit, k) {
      var node = hitNode(hit);
      if (k >= limit) {
        node.hidden = true;
        rest.push(node);
      }
      box.appendChild(node);
    });
    if (rest.length) {
      var more = document.createElement('button');
      more.type = 'button';
      more.className = 'docs-hit-more';
      var shown = false;
      var label = function () {
        more.textContent = shown ? msg('less') : fill(msg('more'), { count: rest.length });
        more.setAttribute('aria-expanded', shown ? 'true' : 'false');
      };
      label();
      more.addEventListener('click', function () {
        shown = !shown;
        rest.forEach(function (node) { node.hidden = !shown; });
        label();
      });
      box.appendChild(more);
    }
    return box;
  };
  var draw = function (query, hits) {
    out.textContent = '';
    var n = document.createElement('p');
    n.className = 'docs-hit-note';
    n.textContent = hits.length
      ? fill(plural(hits.length), { count: hits.length, query: query })
      : fill(msg('none'), { query: query });
    out.appendChild(n);
    var ranked = rank(hits, query);
    if (ranked.best.length) {
      out.appendChild(groupNode(msg('best'), ranked.best, ranked.best.length));
    }
    ranked.groups.forEach(function (group) {
      out.appendChild(groupNode(group.name, group.hits, PER_GROUP));
    });
  };
  var run = function (query) {
    query = query.trim();
    if (!query) return say(msg('prompt'));
    load().then(function (p) {
      return p.debouncedSearch(query, {}, 150);
    }).then(function (found) {
      // null: a newer query replaced this one.
      if (!found) return;
      return Promise.all(found.results.slice(0, 60).map(function (r) {
        return r.data().then(function (hit) { hit.score = r.score; return hit; });
      })).then(function (hits) { draw(query, hits); });
    }).catch(function () {
      say(msg('error'));
    });
  };
  var params = new URLSearchParams(location.search);
  input.value = params.get('q') || '';
  if (input.value) run(input.value);
  else say(msg('prompt'));
  input.addEventListener('input', function () {
    var q = input.value.trim();
    history.replaceState(null, '', q ? '?q=' + encodeURIComponent(q) : location.pathname);
    run(input.value);
  });
  // The form is a GET to this same page: Enter must not reload it.
  var form = input.closest('[role=search]');
  if (form) form.addEventListener('submit', function (e) { e.preventDefault(); });
})();

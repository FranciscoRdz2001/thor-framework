/// The lite engine of a static site, one bundle per page set.
///
/// A site used to ship one engine file with every state and every part any
/// page needs. Here each page gets the states its markup names (and what
/// those use) and the parts that code and that markup need; pages that need
/// the same share a file, and a page whose needs are a little smaller than a
/// bigger bundle's takes that one instead (one file in the cache for both).
library;

import 'dart:convert';
import 'dart:io';

import '../fingerprint.dart' show contentHash;

/// The line before each top-level item of thor_builder's lite state.
const _itemMark = '  // @item';

final _declared = RegExp(
  r'^\s*(?:class|const|let|var|function\*?|async function\*?)\s+([\w$]+)',
);
final _definedState = RegExp(r"^\s*thor\.def\('([^']+)'");
final _stateOptions = RegExp(r'^\s*\}, \{ (.*) \}\);\s*$');
final _identifier = RegExp(r'(?:(?<=\.\.\.)|(?<![.\w$]))[A-Za-z_$][\w$]*');

/// [stateJs] (thor_builder's lite state) with only what a page whose markup
/// is [page] needs: the states its elements name, those it wakes by itself
/// (global, eager or persisted) and what they use, and the helpers, classes
/// and functions those states reference. The `// thor-lite parts:` line is
/// rewritten to the parts the kept helpers bring.
///
/// Returns the state as it is when it has no item marks (written by an older
/// thor_builder). [keptStates], if given, gets the names of the kept states.
String pruneLiteStates(String stateJs, String page, {Set<String>? keptStates}) {
  final lines = stateJs.split('\n');
  final open = lines.indexOf('{');
  final close = lines.lastIndexOf('}');
  if (open < 0 || close < open || !stateJs.contains('\n$_itemMark\n')) {
    return stateJs;
  }
  final head = lines.sublist(0, open + 1);
  final tail = lines.sublist(close);
  final items = <_Item>[];
  for (final line in lines.sublist(open + 1, close)) {
    if (line == _itemMark) {
      items.add(_Item());
    } else {
      // Lines before the first mark (none today) join a first, unnamed item.
      if (items.isEmpty) items.add(_Item());
      items.last.lines.add(line);
    }
  }
  for (final item in items) {
    item.init();
  }

  final byName = <String, _Item>{
    for (final i in items)
      for (final n in i.names) n: i,
  };
  final kept = <_Item>{};
  final work = <_Item>[];
  void keep(_Item i) {
    if (kept.add(i)) work.add(i);
  }

  final states = [
    for (final i in items)
      if (i.state != null) i,
  ];
  bool mentions(String text, String name) =>
      RegExp('(?<![\\w\$])${RegExp.escape(name)}(?![\\w\$])').hasMatch(text);
  for (final i in items) {
    final state = i.state;
    if (state == null) {
      // Not a declaration (`thor.K = …`): runs whatever the page is.
      if (i.name == null) keep(i);
      continue;
    }
    final o = i.options;
    if (state.startsWith(r'$') ||
        o.contains('eager') ||
        o.contains('cookies') ||
        (o.contains('idle') && !o.contains('named')) ||
        mentions(page, state)) {
      keep(i);
    }
  }
  while (work.isNotEmpty) {
    final i = work.removeLast();
    for (final m in _identifier.allMatches(i.text)) {
      final d = byName[m[0]];
      if (d != null && !d.isState) keep(d);
    }
    // `uses: ['Other']`, a state read by name.
    for (final s in states) {
      if (!kept.contains(s) && mentions(i.text, s.state!)) keep(s);
    }
  }

  final body = [
    for (final i in items)
      if (kept.contains(i)) ...[_itemMark, ...i.lines],
  ];
  keptStates?.addAll([
    for (final i in kept)
      if (i.state != null) i.state!,
  ]);

  // The parts: those of the helpers kept, and `json` for code with Maps (the
  // rule thor_builder follows for the whole file).
  final helperParts = <String, List<String>>{};
  for (final line in head) {
    const mark = '// thor-lite helper-parts: ';
    if (line.startsWith(mark)) {
      for (final entry in line.substring(mark.length).split(' ')) {
        final eq = entry.indexOf('=');
        if (eq > 0) {
          helperParts[entry.substring(0, eq)] = entry
              .substring(eq + 1)
              .split(',');
        }
      }
    }
  }
  final parts = <String>{
    for (final i in kept) ...?helperParts[i.name],
    // A state's own (`// @parts`: the controllers, the lifecycle).
    for (final i in kept)
      for (final line in i.lines.map((l) => l.trim()))
        if (line.startsWith('// @parts '))
          ...line.substring('// @parts '.length).split(' '),
    if (RegExp(r'\bMap\b|\.get\(').hasMatch(body.join('\n'))) 'json',
  }.toList()..sort();
  final newHead = [
    for (final line in head)
      if (line.startsWith('// thor-lite helper-parts: '))
        ...const <String>[]
      else if (line.startsWith('// thor-lite parts: '))
        ...(parts.isEmpty
            ? const <String>[]
            : ['// thor-lite parts: ${parts.join(' ')}'])
      else
        line,
  ];
  return [...newHead, ...body, ...tail].join('\n');
}

class _Item {
  final lines = <String>[];
  late final String text = lines.join('\n');

  /// The name it declares at top level, if it declares one.
  String? name;

  /// Every name it declares at its own level (an enum with members is a
  /// class and its `X\$values` array in one item).
  final names = <String>[];

  /// The state a `thor.def` defines.
  String? state;

  /// The options of a state's `thor.def`, as text.
  String options = '';

  bool get isState => state != null;

  void init() {
    final first = lines.firstWhere(
      (l) => l.trim().isNotEmpty,
      orElse: () => '',
    );
    if (_definedState.firstMatch(first) case final m?) {
      state = name = m[1];
      options =
          lines.reversed
              .map(_stateOptions.firstMatch)
              .firstWhere((m) => m != null, orElse: () => null)
              ?.group(1) ??
          '';
    } else {
      name = _declared.firstMatch(first)?.group(1);
    }
    if (name != null) names.add(name!);
    final indent = first.length - first.trimLeft().length;
    for (final l in lines.skip(1)) {
      if (l.length - l.trimLeft().length != indent) continue;
      if (_declared.firstMatch(l)?.group(1) case final n?) names.add(n);
    }
  }
}

/// How many bytes (gzip) the page that needs the least of a shared bundle may
/// carry more than it needs: below this, one more file in the cache costs more
/// than the bytes.
const liteBundleMergeBytes = 2048;

/// Groups the pages' [needs] (the states and parts each one wants, one entry
/// per distinct need) into the bundles that serve them: the groups of indexes.
///
/// Starting with one bundle per entry, it joins the two whose union costs the
/// least over the bigger of them, as long as no page of the result carries
/// more than [mergeBytes] over the bundle it would have alone. [cost] is the
/// size in bytes (gzip, estimated) of a bundle with the given states and
/// parts. Pages of a site that differ by a part or a state of a few hundred
/// bytes end up on one file, which a visitor keeps in the cache from one page
/// to the next; pages that differ by a lot keep their own.
List<List<int>> groupLiteBundles(
  List<({Set<String> states, Set<String> parts})> needs,
  int Function(Set<String> states, Set<String> parts) cost, {
  int mergeBytes = liteBundleMergeBytes,
}) {
  final groups = <int, _Group>{};
  for (var i = 0; i < needs.length; i++) {
    final c = cost(needs[i].states, needs[i].parts);
    groups[i] = _Group([i], needs[i].states, needs[i].parts, c, c);
  }
  // (a, b) → the union and what it costs; recomputed only for a new group.
  final pairs = <(int, int), (_Group, int)?>{};
  (_Group, int)? join(int a, int b) {
    final x = groups[a]!, y = groups[b]!;
    final states = {...x.states, ...y.states};
    final parts = {...x.parts, ...y.parts};
    final c = cost(states, parts);
    // The page that needs the least pays the most.
    if (c - (x.alone < y.alone ? x.alone : y.alone) >= mergeBytes) return null;
    final extra = c - (x.cost > y.cost ? x.cost : y.cost);
    return (
      _Group(
        [...x.members, ...y.members],
        states,
        parts,
        c,
        x.alone < y.alone ? x.alone : y.alone,
      ),
      extra,
    );
  }

  var next = needs.length;
  for (;;) {
    final ids = groups.keys.toList()..sort();
    (int, int)? best;
    var bestExtra = 0;
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final key = (ids[i], ids[j]);
        final found = pairs.putIfAbsent(key, () => join(ids[i], ids[j]));
        if (found != null && (best == null || found.$2 < bestExtra)) {
          best = key;
          bestExtra = found.$2;
        }
      }
    }
    if (best == null) break;
    final (a, b) = best;
    final merged = pairs[best]!.$1;
    groups
      ..remove(a)
      ..remove(b);
    pairs.removeWhere(
      (k, _) => k.$1 == a || k.$2 == a || k.$1 == b || k.$2 == b,
    );
    groups[next++] = merged;
  }
  return [for (final g in groups.values) g.members..sort()]
    ..sort((a, b) => a.first.compareTo(b.first));
}

class _Group {
  _Group(this.members, this.states, this.parts, this.cost, this.alone);
  final List<int> members;
  final Set<String> states;
  final Set<String> parts;

  /// The estimated cost of this group's bundle.
  final int cost;

  /// The least a page of the group would cost with a bundle of its own.
  final int alone;
}

/// The pages of [siteDir] that load the engine (`data-thor-engine`), by
/// their path relative to it.
Map<String, String> enginePages(String siteDir) {
  final root = Directory(siteDir);
  return {
    for (final f in root.listSync(recursive: true))
      if (f is File && f.path.endsWith('.html'))
        if (f.readAsStringSync() case final text
            when text.contains('data-thor-engine'))
          f.path.substring(root.path.length + 1): text,
  };
}

/// The page [text] pointing at [file] instead of `engine.dart.js`, in the
/// attributes that hold the engine's URL (the loader's, its preload, a
/// plain script). Prose that names the file stays.
String pointPageAt(String text, String file) => text.replaceAllMapped(
  RegExp(
    r'''((?:data-thor-engine|href|src)=["'])([^"']*?)engine\.dart\.js(["'])''',
  ),
  (m) => '${m[1]}${m[2]}$file${m[3]}',
);

/// The content-hashed name of an engine bundle with [js].
String liteBundleName(String js) =>
    'engine.dart.${contentHash(utf8.encode(js))}.js';

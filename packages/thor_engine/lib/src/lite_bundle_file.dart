import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'atomic_write.dart';
import 'lite_bundle.dart';
import 'lite_site.dart';

/// Writes the lite engine's bundle of the app in [appDir] into [outPath]:
/// what `dart run thor_engine:lite_bundle` does (thor dev's builder
/// worker runs it in its own process). [statePath] is the app's states in
/// JS (thor_builder's lite_state); with [siteDir] (a static site) a
/// feature's part ships only if a page has its markup. Returns the line
/// the command prints.
Future<String> writeLiteBundle({
  required String statePath,
  required String appDir,
  required String outPath,
  String? siteDir,
  bool minify = true,
  bool dev = false,
}) async {
  final stateJs = File(statePath).readAsStringSync();
  final entry = File('$appDir/.dart_tool/thor/engine.dart');
  final site = siteDir == null ? null : Directory(siteDir);
  List<String> read(Directory dir, String ext) => [
    if (dir.existsSync())
      for (final f in dir.listSync(recursive: true))
        if (f is File && f.path.endsWith(ext)) f.readAsStringSync(),
  ];
  final parts = {
    ...litePartsFor(
      stateJs: stateJs,
      engineEntry: entry.existsSync() ? entry.readAsStringSync() : '',
      pages: site == null ? null : read(site, '.html'),
      sources: site == null
          ? read(Directory('$appDir/lib'), '.dart').join('\n')
          : '',
    ),
    // The kept states are Maps in the order of the text (part json).
    if (dev) ...['json', 'dev_state'],
  }.toList();
  final js = await _compose(appDir, parts, stateJs, minify);
  writeFileIfChanged(File(outPath), js);
  final gz = gzip.encode(utf8.encode(js)).length;
  final extras = parts.isEmpty ? '' : ' + ${parts.join(', ')}';
  return '$outPath: lite engine$extras, '
      '${(js.length / 1024).toStringAsFixed(1)} KB, '
      '${(gz / 1024).toStringAsFixed(1)} KB gz';
}

/// The bundle of [parts] (in bundle order) and [stateJs] for the app in
/// [appDir].
Future<String> _compose(
  String appDir,
  List<String> parts,
  String stateJs,
  bool minify,
) async {
  // The app's languages: the ARB files of lib/l10n (app_pt_BR.arb → pt_BR).
  final l10n = Directory('$appDir/lib/l10n');
  final locales = [
    if (l10n.existsSync())
      for (final f in l10n.listSync())
        if (RegExp(r'^[A-Za-z]+_(.+)\.arb$').firstMatch(f.uri.pathSegments.last)
            case final m?)
          m.group(1)!,
  ];
  final lite = await Isolate.resolvePackageUri(
    Uri.parse('package:thor_engine/lite/runtime.js'),
  );
  final dir = File.fromUri(lite!).parent.path;
  return liteBundle(
    runtime: File('$dir/runtime.js').readAsStringSync(),
    parts: {
      for (final p in parts)
        p: p == 'intl' && locales.isNotEmpty
            // Only the app's languages' plural rules.
            ? trimIntlPart(File('$dir/parts/$p.js').readAsStringSync(), locales)
            : File('$dir/parts/$p.js').readAsStringSync(),
    },
    stateJs: stateJs,
    minify: minify,
  );
}

/// Writes the lite engine of the static site in [siteDir], one bundle per
/// set of pages (see `lite_site.dart`), next to [outPath] (the
/// `engine.dart.js` the pages name) as `engine.dart.<hash>.js`, and points
/// each page at its own. A page loads the states its markup names and the
/// parts that code and markup need; a page that needs a little less than
/// another's bundle shares it ([mergeBytes]). Returns the lines the command
/// prints.
Future<String> writeLiteSiteBundles({
  required String statePath,
  required String appDir,
  required String outPath,
  required String siteDir,
  bool minify = true,
  int mergeBytes = liteBundleMergeBytes,
}) async {
  final stateJs = File(statePath).readAsStringSync();
  final entry = File('$appDir/.dart_tool/thor/engine.dart');
  final engineEntry = entry.existsSync() ? entry.readAsStringSync() : '';
  final pages = enginePages(siteDir);
  final paths = pages.keys.toList()..sort();

  int gzOf(String js) => gzip.encode(utf8.encode(js)).length;
  // What each page needs; pages with the same needs are one entry.
  final needs = <({Set<String> states, Set<String> parts})>[];
  final entryOf = <String, int>{};
  final entryKeys = <String, int>{};
  for (final path in paths) {
    final states = <String>{};
    final js = pruneLiteStates(stateJs, pages[path]!, keptStates: states);
    final parts = litePartsFor(
      stateJs: js,
      engineEntry: engineEntry,
      pages: [pages[path]!],
    ).toSet();
    final key =
        '${(states.toList()..sort()).join(',')}|${(parts.toList()..sort()).join(',')}';
    entryOf[path] = entryKeys.putIfAbsent(key, () {
      needs.add((states: states, parts: parts));
      return needs.length - 1;
    });
  }

  // What a state or a part adds to a bundle (gzip, on its own: the sum
  // over-counts what they share, which is the safe side).
  final base = gzOf(
    await _compose(appDir, const [], pruneLiteStates(stateJs, ''), minify),
  );
  final partCost = <String, int>{};
  final stateCost = <String, int>{};
  for (final n in needs) {
    for (final part in n.parts) {
      partCost[part] ??=
          gzOf(
            await _compose(
              appDir,
              [part],
              pruneLiteStates(stateJs, ''),
              minify,
            ),
          ) -
          base;
    }
    for (final state in n.states) {
      stateCost[state] ??=
          gzOf(
            await _compose(
              appDir,
              const [],
              pruneLiteStates(stateJs, ' $state '),
              minify,
            ),
          ) -
          base;
    }
  }
  int cost(Set<String> states, Set<String> parts) {
    var total = base;
    for (final s in states) {
      total += stateCost[s] ?? 0;
    }
    for (final p in parts) {
      total += partCost[p] ?? 0;
    }
    return total;
  }

  final groups = groupLiteBundles(needs, cost, mergeBytes: mergeBytes);

  // One bundle per group: the union of what its pages need.
  final dir = File(outPath).parent;
  final fileOf = <String, String>{}; // page path → its file
  final lines = <String>[];
  final names = <String>{};
  for (final group in groups) {
    final members = [
      for (final path in paths)
        if (group.contains(entryOf[path])) path,
    ];
    final states = <String>{};
    final js = pruneLiteStates(
      stateJs,
      [for (final i in group) ...needs[i].states].join(' '),
      keptStates: states,
    );
    final parts = litePartsFor(
      stateJs: js,
      engineEntry: engineEntry,
      pages: [for (final path in members) pages[path]!],
    );
    final bundle = await _compose(appDir, parts, js, minify);
    final name = liteBundleName(bundle);
    names.add(name);
    writeFileIfChanged(File('${dir.path}/$name'), bundle);
    for (final path in members) {
      fileOf[path] = name;
    }
    lines.add(
      '$name: lite engine${parts.isEmpty ? '' : ' + ${parts.join(', ')}'}, '
      '${(bundle.length / 1024).toStringAsFixed(1)} KB, '
      '${(gzOf(bundle) / 1024).toStringAsFixed(1)} KB gz '
      '(${members.join(', ')})',
    );
  }
  // Stale bundles of an earlier run and the single file this replaces.
  final hashedName = RegExp(r'^engine\.dart\.[0-9a-f]{8}\.js$');
  for (final f in dir.listSync().whereType<File>()) {
    final file = f.uri.pathSegments.last;
    if (file == 'engine.dart.js' ||
        (hashedName.hasMatch(file) && !names.contains(file))) {
      f.deleteSync();
    }
  }
  for (final path in paths) {
    final next = pointPageAt(pages[path]!, fileOf[path]!);
    if (next != pages[path]) File('$siteDir/$path').writeAsStringSync(next);
  }
  return lines.join('\n');
}

/// The changes pages: what each package's `CHANGELOG.md` says that an app
/// developer needs (`/cambios`, `/cambios/<package>`), and the migration
/// notes (what breaks or is `@Deprecated`, and what to use) pulled out of
/// them. The filter and the classification are `changelog_filter.dart`.
library;

import 'dart:io';

import '../../modules/changes/changes_routes.dart';
import '../i18n/docs_locale.dart';
import 'changelog_filter.dart';
import 'library.dart';

/// The packages with a page of changes, in the order the site lists them:
/// the ones an app writes against first.
const changelogPackages = [
  'thor_ui',
  'thor_style',
  'thor_server',
  'thor_studio',
  'thor_cli',
  'thor_test',
  'thor_lints',
  'thor_engine',
  'thor_builder',
];

/// The packages that are not an app's API: an entry shows only when it
/// breaks, deprecates or is about what the app writes or sees (`state`,
/// `query`, a `THOR-*` code).
const _strictPackages = {'thor_engine', 'thor_builder'};

/// What each package is, in a few words, in the page's language.
String _role(AppLocalizations t, String package) => switch (package) {
  'thor_ui' => t.changesRoleThorUi,
  'thor_style' => t.changesRoleThorStyle,
  'thor_engine' => t.changesRoleThorEngine,
  'thor_server' => t.changesRoleThorServer,
  'thor_studio' => t.changesRoleThorStudio,
  'thor_builder' => t.changesRoleThorBuilder,
  'thor_cli' => t.changesRoleThorCli,
  'thor_lints' => t.changesRoleThorLints,
  'thor_test' => t.changesRoleThorTest,
  _ => package,
};

/// Where the packages are: next to `docs/`.
String packagesDir() => '${docsDir()}/../packages';

final _releases = <String, List<Release>>{};

/// The releases of [package] an app developer reads (empty when it has no
/// changelog, or nothing in it that an app meets).
List<Release> changelogReleases(String package) => _releases[package] ??= () {
  final file = File('${packagesDir()}/$package/CHANGELOG.md');
  if (!file.existsSync()) return const <Release>[];
  return releasesOf(
    file.readAsStringSync(),
    strict: _strictPackages.contains(package),
  );
}();

/// How many changes [package] has not released yet.
int unreleasedCount(String package) => [
  for (final r in changelogReleases(package))
    if (r.isUnreleased) ...r.changes,
].length;

/// The heading of a release, in the page's language.
String _versionHeading(AppLocalizations t, String heading) {
  if (heading == 'Unreleased') return t.changesVersionUnreleased;
  final version = RegExp(r'^(\d[\w.+-]*)').firstMatch(heading)?[1];
  return version == null ? heading : t.changesVersionNotPublished(version);
}

/// [changes] of one [kind] as a list under a heading, or nothing.
void _group(
  StringBuffer b,
  String heading,
  Iterable<Change> changes,
  ChangeKind kind,
) {
  final entries = [
    for (final c in changes)
      if (c.kind == kind) c.markdown,
  ];
  if (entries.isEmpty) return;
  b
    ..writeln('\n### $heading\n')
    ..writeln(entries.join('\n'));
}

/// The page of [package]'s changes (Markdown), or null if there is none.
String? changelogMarkdown(String package, AppLocalizations t) {
  if (!changelogPackages.contains(package)) return null;
  final releases = changelogReleases(package);
  if (releases.isEmpty) return null;
  final b = StringBuffer()
    ..writeln('# `$package`\n')
    ..writeln(t.changesPackageIntro(package, _role(t, package)))
    ..writeln('\n${t.changesLanguageNote}');
  // What breaks an app, gathered at the top: found in the notes, never
  // hunted for in a page of a thousand lines.
  final breaking = [
    for (final r in releases)
      for (final c in r.changes)
        if (c.kind == ChangeKind.breaking) c.markdown,
  ];
  if (breaking.isNotEmpty) {
    b.writeln('\n:::warning ${t.changesBreakingTitle}');
    b.writeln(breaking.join('\n'));
    b.writeln(':::');
  }
  for (final release in releases) {
    b.writeln('\n## ${_versionHeading(t, release.heading)}');
    _group(b, t.changesGroupDeprecated, release.changes, ChangeKind.deprecated);
    _group(b, t.changesGroupAdded, release.changes, ChangeKind.added);
    _group(b, t.changesGroupChanged, release.changes, ChangeKind.changed);
  }
  return b.toString();
}

/// The entries that break or are deprecated in what is not released yet,
/// by package: what to change in an app.
Map<String, List<String>> migrationNotes() {
  final out = <String, List<String>>{};
  for (final package in changelogPackages) {
    final notes = [
      for (final r in changelogReleases(package))
        if (r.isUnreleased)
          for (final c in r.changes)
            if (c.kind == ChangeKind.breaking ||
                c.kind == ChangeKind.deprecated)
              c.markdown,
    ];
    if (notes.isNotEmpty) out[package] = notes;
  }
  return out;
}

/// The page `/cambios` (Markdown): the migration notes, and the packages.
String changesIndexMarkdown(AppLocalizations t) {
  final b = StringBuffer()
    ..writeln('# ${t.changesTitle}')
    ..writeln()
    ..writeln(t.changesIndexIntro)
    ..writeln()
    ..writeln('## ${t.changesMigrateHeading}')
    ..writeln()
    ..writeln(t.changesMigrateIntro);
  final notes = migrationNotes();
  if (notes.isEmpty) b.writeln('\n${t.changesMigrateNone}');
  for (final MapEntry(key: package, value: entries) in notes.entries) {
    b
      ..writeln('\n### `$package`\n')
      ..writeln(entries.join('\n'));
  }
  b
    ..writeln('\n## ${t.changesPackagesHeading}\n')
    ..writeln(
      '| ${t.changesColPackage} | ${t.changesColRole} | '
      '${t.changesColCount} |',
    )
    ..writeln('| --- | --- | --- |');
  for (final package in changelogPackages) {
    if (changelogReleases(package).isEmpty) continue;
    b.writeln(
      '| [`$package`](${changesPackageRoute.link({'package': package})}) | ${_role(t, package)} | '
      '${unreleasedCount(package)} |',
    );
  }
  return b.toString();
}

/// The pages of the changes: `/cambios` and one per package.
List<String> changesPaths() => [
  changesRoute.link(),
  for (final p in changelogPackages)
    if (changelogReleases(p).isNotEmpty)
      changesPackageRoute.link({'package': p}),
];

import 'package:docs/core/content/changelog.dart';
import 'package:docs/core/content/changelog_filter.dart';
import 'package:docs/core/content/library.dart';
import 'package:docs/core/i18n/docs_locale.dart';
import 'package:test/test.dart';

import 'guide_public_test.dart' show privateTerms;

/// What `/cambios` must never show: the regex of
/// `tool/test/error_pages_test.dart`, plus the English words of the
/// changelogs for the same things (the browser runtime and its builds),
/// plus what no public text names ([privateTerms]).
final _banned = RegExp(
  r'\blite\b|dart2js|\bmotor\b|\bengines?\b|tool/|\bapps/|packages/'
  r'|\.dart_tool|data-t[a-z-]*|thorElement'
  r'|ChildRules|WrapData|\]\(\.\./(?!guia/)|docs/\d',
  caseSensitive: false,
);

String? _bannedIn(String text) =>
    _banned.firstMatch(text)?.group(0) ??
    privateTerms.values
        .map((p) => p.firstMatch(text)?.group(0))
        .nonNulls
        .firstOrNull;

String _text(String html) => html.replaceAll(RegExp('<[^>]+>'), ' ');

void main() {
  group('the changelog filter', () {
    test('an entry about internals does not appear', () {
      expect(cleanEntry('- The lite engine keeps the rows.'), isNull);
      expect(
        cleanEntry(
          '- `Scaffold` is faster. See `tool/golden.sh` for it.',
        )!.markdown,
        '- `Scaffold` is faster.',
      );
    });

    test('references to files go, the text stays', () {
      final change = cleanEntry(
        '- `Watch.list(virtual: true)` (docs/x.md): rows near the viewport.\n'
        '  See [the guide](docs/guia/es/listas-largas.md) and '
        '[Flutter](https://flutter.dev).',
      )!;
      expect(change.markdown, isNot(contains('docs/x.md')));
      expect(change.markdown, contains('the guide'));
      expect(change.markdown, isNot(contains('listas-largas.md')));
      expect(change.markdown, contains('(https://flutter.dev)'));
    });

    test('an entry is new, changed, deprecated or breaking', () {
      ChangeKind kind(String entry) => cleanEntry(entry)!.kind;
      expect(kind('- `Button.dense` makes it smaller.'), ChangeKind.added);
      expect(
        kind('- Fix: `Expanded` no longer collapses.'),
        ChangeKind.changed,
      );
      expect(
        kind('- `Text(headingLevel:)` is `@Deprecated`: use `Semantics`.'),
        ChangeKind.deprecated,
      );
      expect(kind('- **Breaking:** `Old` is removed.'), ChangeKind.breaking);
      // Mentioning the word is not a deprecation.
      expect(
        kind('- No deprecated `Text(headingLevel:)` is written.'),
        ChangeKind.added,
      );
    });

    test('the labels the sections already say are dropped', () {
      expect(cleanEntry('- Fix: `A` works.')!.markdown, '- `A` works.');
      expect(cleanEntry('- New: `B` exists.')!.markdown, '- `B` exists.');
    });

    test('a long entry keeps what it is and drops the maintainers notes', () {
      final change = cleanEntry(
        '- `X` does this. It also does that. And it measured 3 ms.',
      )!;
      expect(change.markdown, '- `X` does this. It also does that.');
      // A migration keeps everything.
      expect(
        cleanEntry(
          '- **Breaking:** `X` goes. Use `Y`. Same for `Z`.',
        )!.markdown,
        contains('Same for `Z`'),
      );
    });

    test('a package that is not the app API shows what the app meets', () {
      expect(cleanEntry('- Faster parsing.', strict: true), isNull);
      expect(
        cleanEntry('- `query(fn)` gets `refresh`.', strict: true),
        isNotNull,
      );
      expect(cleanEntry('- **Breaking:** x is gone.', strict: true), isNotNull);
    });

    test('releases come with their entries and "Nothing yet" is none', () {
      final releases = releasesOf(
        '# Changelog\n\nintro\n\n## Unreleased\n\n- Nothing yet.\n\n'
        '## 0.1.0 (not published)\n\n- `A` exists.\n- Uses the lite engine.\n',
      );
      expect([for (final r in releases) r.heading], ['0.1.0 (not published)']);
      expect(releases.single.changes, hasLength(1));
    });
  });

  group('the changes pages', () {
    for (final locale in docsLocales) {
      test('/cambios and every package page are clean in $locale', () {
        final t = messagesFor(locale);
        final pages = {
          'index': changesIndexMarkdown(t),
          for (final p in changelogPackages) p: changelogMarkdown(p, t) ?? '',
        };
        expect(
          pages.values.where((m) => m.isNotEmpty),
          hasLength(greaterThan(5)),
        );
        for (final MapEntry(:key, :value) in pages.entries) {
          expect(_bannedIn(value), isNull, reason: 'markdown of $key');
          final html = renderMarkdown(value, source: 'x', locale: locale).html;
          expect(_bannedIn(_text(html)), isNull, reason: 'page $key');
        }
      });
    }

    test('every page is a path of the site and has entries', () {
      expect(changesPaths(), contains('/cambios'));
      expect(changesPaths(), contains('/cambios/thor_ui'));
      for (final package in changelogPackages) {
        final count = changelogReleases(package).length;
        expect(
          changesPaths().contains('/cambios/$package'),
          count > 0,
          reason: package,
        );
      }
    });

    test('the headings and the notes come from the messages', () {
      final t = messagesFor('es');
      final ui = changelogMarkdown('thor_ui', t)!;
      expect(ui, contains('## ${t.changesVersionNotPublished('0.1.0')}'));
      expect(ui, contains('### ${t.changesGroupAdded}'));
      expect(ui, isNot(contains(':::warning')));
      expect(ui, contains(t.changesLanguageNote));
      final index = changesIndexMarkdown(t);
      expect(index, contains('## ${t.changesMigrateHeading}'));
      expect(index, contains('| ${t.changesColPackage} |'));
      // What is not API of an app has no page unless an app meets it.
      expect(
        changelogReleases('thor_engine').expand((r) => r.changes),
        everyElement(
          predicate<Change>(
            (c) =>
                c.kind == ChangeKind.breaking ||
                c.kind == ChangeKind.deprecated ||
                appFacing.hasMatch(c.markdown),
          ),
        ),
      );
    });

    test('the interface strings of the site never name repository tools', () {
      final t = messagesFor('es');
      expect(t.searchNoIndex, isNot(contains('tool/')));
      expect(t.searchNoIndex, isNot(contains('.sh')));
    });
  });
}

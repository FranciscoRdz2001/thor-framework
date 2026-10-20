import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/thor_cli.dart';

/// A fake `git`: answers by the first words of the command, null (failure)
/// for what it doesn't know.
GitRunner fakeGit(Map<String, String?> answers) =>
    (dir, args) async => answers[args.join(' ')];

const _base = {
  'rev-parse --show-toplevel': '/co',
  'log -1 --format=%h%x09%cs': 'abc1234\t2026-09-30',
  'symbolic-ref --short -q HEAD': 'master',
  'symbolic-ref --short -q refs/remotes/origin/HEAD': 'origin/master',
  'rev-list --left-right --count HEAD...@{u}': '0\t0',
  'status --porcelain --untracked-files=no': '',
};

Future<CheckoutStatus> statusWith(Map<String, String?> changes) =>
    checkoutStatus('/co', git: fakeGit({..._base, ...changes}));

void main() {
  group('checkoutStatus', () {
    test('up to date, clean, on the default branch: no warnings', () async {
      final s = await statusWith({});
      expect(s.isGit, isTrue);
      expect(s.commit, 'abc1234');
      expect(s.date, '2026-09-30');
      expect(s.branch, 'master');
      expect(s.warnings, isEmpty);
      expect(s.describe(), '/co @ abc1234 (2026-09-30), master');
    });

    test('behind its upstream warns with the count and the fix', () async {
      final s = await statusWith({
        'rev-list --left-right --count HEAD...@{u}': '0\t430',
      });
      expect(s.behind, 430);
      expect(s.warnings.single, contains('430 commits behind'));
      expect(s.warnings.single, contains('git -C /co pull'));
      expect(s.warnings.single, contains('tool/thor setup'));
    });

    test('one commit behind is singular', () async {
      final s = await statusWith({
        'rev-list --left-right --count HEAD...@{u}': '0\t1',
      });
      expect(s.warnings.single, contains('1 commit behind'));
      expect(s.warnings.single, isNot(contains('1 commits')));
    });

    test('ahead only is not a warning', () async {
      final s = await statusWith({
        'rev-list --left-right --count HEAD...@{u}': '3\t0',
      });
      expect(s.ahead, 3);
      expect(s.behind, 0);
      expect(s.warnings, isEmpty);
      expect(s.describe(), contains('3 ahead'));
    });

    test('ahead and behind both show', () async {
      final s = await statusWith({
        'rev-list --left-right --count HEAD...@{u}': '2\t5',
      });
      expect(s.warnings.single, contains('5 commits behind'));
      expect(s.describe(), contains('2 ahead'));
    });

    test('uncommitted changes warn', () async {
      final s = await statusWith({
        'status --porcelain --untracked-files=no':
            ' M packages/thor_ui/x.dart\n',
      });
      expect(s.dirty, isTrue);
      expect(s.warnings.single, contains('uncommitted changes'));
    });

    test('another branch than the default warns', () async {
      final s = await statusWith({'symbolic-ref --short -q HEAD': 'feature'});
      expect(s.branch, 'feature');
      expect(s.warnings.single, contains('"feature"'));
      expect(s.warnings.single, contains('master'));
    });

    test('the default is main when origin/HEAD says so', () async {
      final s = await statusWith({
        'symbolic-ref --short -q refs/remotes/origin/HEAD': 'origin/main',
        'symbolic-ref --short -q HEAD': 'main',
      });
      expect(s.warnings, isEmpty);
    });

    test('detached HEAD warns and has no branch', () async {
      final s = await statusWith({
        'symbolic-ref --short -q HEAD': null,
        'rev-list --left-right --count HEAD...@{u}': null,
      });
      expect(s.branch, isNull);
      expect(s.detached, isTrue);
      expect(s.warnings.single, contains('detached'));
      expect(s.describe(), contains('detached HEAD'));
    });

    test('no upstream: no behind count, a note and no warning', () async {
      final s = await statusWith({
        'rev-list --left-right --count HEAD...@{u}': null,
      });
      expect(s.behind, isNull);
      expect(s.warnings, isEmpty);
      expect(s.notes.single, contains('no upstream'));
    });

    test('unknown default branch: no branch warning', () async {
      final s = await statusWith({
        'symbolic-ref --short -q refs/remotes/origin/HEAD': null,
        'symbolic-ref --short -q HEAD': 'whatever',
        'rev-parse --verify -q refs/heads/main': null,
        'rev-parse --verify -q refs/heads/master': null,
      });
      expect(s.warnings, isEmpty);
    });

    test('not a git checkout (git fails): a note, no warnings', () async {
      final s = await checkoutStatus('/co', git: fakeGit({}));
      expect(s.isGit, isFalse);
      expect(s.warnings, isEmpty);
      expect(s.describe(), '/co (not a git checkout)');
      expect(s.notes.single, contains('git'));
    });

    test('a folder inside another repository is not a checkout', () async {
      final s = await statusWith({'rev-parse --show-toplevel': '/elsewhere'});
      expect(s.isGit, isFalse);
    });

    test('git missing from the PATH is the same as not a repo', () async {
      final s = await checkoutStatus(
        '/co',
        git: (dir, args) async => throw const ProcessException('git', []),
      );
      expect(s.isGit, isFalse);
    });

    test('garbage from rev-list is no count, not a crash', () async {
      final s = await statusWith({
        'rev-list --left-right --count HEAD...@{u}': 'nonsense',
      });
      expect(s.behind, isNull);
    });
  });

  group('checkoutStatus with the real git', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('thor_checkout'));
    tearDown(() => tmp.deleteSync(recursive: true));

    ProcessResult git(String dir, List<String> args) => Process.runSync('git', [
      '-c',
      'user.name=t',
      '-c',
      'user.email=t@t',
      '-c',
      'commit.gpgsign=false',
      '-c',
      'init.defaultBranch=master',
      ...args,
    ], workingDirectory: dir);

    test('a plain folder is not a checkout', () async {
      expect((await checkoutStatus(tmp.path)).isGit, isFalse);
    });

    test('behind its upstream, then dirty, then detached', () async {
      final origin = p.join(tmp.path, 'origin');
      Directory(origin).createSync();
      git(origin, ['init', '-q']);
      File(p.join(origin, 'a')).writeAsStringSync('1');
      git(origin, ['add', '.']);
      git(origin, ['commit', '-qm', 'one']);
      final clone = p.join(tmp.path, 'clone');
      git(tmp.path, ['clone', '-q', origin, clone]);
      File(p.join(origin, 'a')).writeAsStringSync('2');
      git(origin, ['commit', '-qam', 'two']);
      git(clone, ['fetch', '-q']);

      var s = await checkoutStatus(clone);
      expect(s.isGit, isTrue);
      expect(s.branch, 'master');
      expect(s.behind, 1);
      expect(s.warnings.single, contains('1 commit behind'));

      File(p.join(clone, 'a')).writeAsStringSync('dirty');
      s = await checkoutStatus(clone);
      expect(s.dirty, isTrue);

      git(clone, ['checkout', '-q', '--detach']);
      s = await checkoutStatus(clone);
      expect(s.detached, isTrue);
    });
  });
}

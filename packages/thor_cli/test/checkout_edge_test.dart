import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/thor_cli.dart';

/// Odd checkouts, against the real git.
void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('thor_checkout_e'));
  tearDown(() => tmp.deleteSync(recursive: true));

  ProcessResult git(
    String dir,
    List<String> args, {
    Map<String, String>? env,
  }) => Process.runSync(
    'git',
    [
      '-c',
      'user.name=t',
      '-c',
      'user.email=t@t',
      '-c',
      'commit.gpgsign=false',
      '-c',
      'init.defaultBranch=master',
      '-c',
      'protocol.file.allow=always',
      ...args,
    ],
    workingDirectory: dir,
    environment: env,
  );

  String repo(String name) {
    final dir = p.join(tmp.path, name);
    Directory(dir).createSync(recursive: true);
    git(dir, ['init', '-q']);
    File(p.join(dir, 'a')).writeAsStringSync('1');
    git(dir, ['add', '.']);
    git(dir, ['commit', '-qm', 'one']);
    return dir;
  }

  test('a linked worktree (.git is a file) is a checkout', () async {
    final main = repo('main');
    final wt = p.join(tmp.path, 'wt');
    git(main, ['worktree', 'add', '-q', '-b', 'feature', wt]);
    expect(FileSystemEntity.isFileSync(p.join(wt, '.git')), isTrue);
    final s = await checkoutStatus(wt);
    expect(s.isGit, isTrue);
    expect(s.branch, 'feature');
    expect(s.warnings.single, contains('"feature", not "master"'));
  });

  test('a submodule checkout is a checkout', () async {
    final lib = repo('lib');
    final host = repo('host');
    git(host, ['submodule', 'add', '-q', lib, 'sub']);
    final s = await checkoutStatus(p.join(host, 'sub'));
    expect(s.isGit, isTrue);
    expect(s.commit, isNot('?'));
  });

  test('a shallow clone reports its state', () async {
    final origin = repo('origin');
    File(p.join(origin, 'a')).writeAsStringSync('2');
    git(origin, ['commit', '-qam', 'two']);
    final clone = p.join(tmp.path, 'shallow');
    git(tmp.path, ['clone', '-q', '--depth', '1', 'file://$origin', clone]);
    File(p.join(origin, 'a')).writeAsStringSync('3');
    git(origin, ['commit', '-qam', 'three']);
    git(clone, ['fetch', '-q', '--depth', '1']);
    final s = await checkoutStatus(clone);
    expect(s.isGit, isTrue);
    expect(s.behind, 1);
  });

  test('an upstream and remote named differently', () async {
    final origin = repo('origin');
    git(origin, ['branch', '-q', '-m', 'trunk']);
    final clone = p.join(tmp.path, 'clone');
    git(tmp.path, ['clone', '-q', '-o', 'upstream', origin, clone]);
    File(p.join(origin, 'a')).writeAsStringSync('2');
    git(origin, ['commit', '-qam', 'two']);
    git(clone, ['fetch', '-q']);
    final s = await checkoutStatus(clone);
    expect(s.behind, 1);
    expect(s.branch, 'trunk');
    // The default branch is trunk (remote HEAD): not "on another branch".
    expect(
      s.warnings.where((w) => w.contains('not "')),
      isEmpty,
      reason: '${s.warnings}',
    );
  });

  test('a branch named like a remote does not confuse the default', () async {
    final origin = repo('origin');
    final clone = p.join(tmp.path, 'clone');
    git(tmp.path, ['clone', '-q', origin, clone]);
    git(clone, ['checkout', '-q', '-b', 'origin/fix']);
    final s = await checkoutStatus(clone);
    expect(s.defaultBranch, 'master');
    expect(s.branch, 'origin/fix');
  });

  test('git output in another locale parses the same', () async {
    final origin = repo('origin');
    final clone = p.join(tmp.path, 'clone');
    git(tmp.path, ['clone', '-q', origin, clone]);
    File(p.join(clone, 'a')).writeAsStringSync('dirty');
    final s = await checkoutStatus(
      clone,
      git: (dir, args) async {
        final r = await Process.run(
          'git',
          args,
          workingDirectory: dir,
          environment: {'LANG': 'de_DE.UTF-8', 'LC_ALL': 'de_DE.UTF-8'},
        );
        return r.exitCode == 0 ? (r.stdout as String).trim() : null;
      },
    );
    expect(s.dirty, isTrue);
    expect(s.behind, 0);
  });

  test('a path with spaces and unicode', () async {
    final dir = repo('Mi proyecto ñ ü');
    final s = await checkoutStatus(dir);
    expect(s.isGit, isTrue);
    expect(s.describe(), contains('Mi proyecto ñ ü'));
  });

  test('a symlinked checkout path is the same checkout', () async {
    final dir = repo('real');
    final link = p.join(tmp.path, 'link');
    Link(link).createSync(dir);
    expect((await checkoutStatus(link)).isGit, isTrue);
  });

  test('status does not write to the repository', () async {
    final dir = repo('ro');
    // Make the index stat-dirty, as after a touch: a plain `git status`
    // would rewrite .git/index, a read must not.
    final file = File(p.join(dir, 'a'));
    file.setLastModifiedSync(DateTime.now().add(const Duration(hours: 1)));
    final index = File(p.join(dir, '.git', 'index'));
    final before = index.lastModifiedSync();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await checkoutStatus(dir);
    expect(index.lastModifiedSync(), before);
  });

  test('a hung git is killed at the timeout, not left running', () async {
    final script = File(
      p.join(tmp.path, 'git'),
    )..writeAsStringSync('#!/bin/sh\necho \$\$ >"${tmp.path}/pid"\nsleep 60\n');
    Process.runSync('chmod', ['+x', script.path]);
    final path = '${tmp.path}:${Platform.environment['PATH']}';
    final r = await runGitWith(
      tmp.path,
      ['status'],
      environment: {'PATH': path},
      timeout: const Duration(milliseconds: 500),
    );
    expect(r, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final pid = int.parse(
      File(p.join(tmp.path, 'pid')).readAsStringSync().trim(),
    );
    final alive = Process.runSync('kill', ['-0', '$pid']).exitCode == 0;
    if (alive) Process.killPid(pid);
    expect(alive, isFalse, reason: 'git survived its timeout');
  });
}

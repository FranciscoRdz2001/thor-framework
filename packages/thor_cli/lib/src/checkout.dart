import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Runs `git <args>` in a folder: its trimmed stdout, or null when git
/// fails (not a repository, no upstream…) or is not installed.
typedef GitRunner = Future<String?> Function(String dir, List<String> args);

/// The real `git`. Reads only: nothing here changes the checkout.
Future<String?> runGit(String dir, List<String> args) => runGitWith(dir, args);

/// [runGit] with the environment and the time limit explicit. Git runs with
/// `LC_ALL=C` (stable output whatever the user's locale) and without
/// optional locks (`git status` would otherwise refresh `.git/index`); a git
/// that outlives [timeout] is killed, not left behind.
Future<String?> runGitWith(
  String dir,
  List<String> args, {
  Map<String, String>? environment,
  Duration timeout = const Duration(seconds: 10),
}) async {
  Process process;
  try {
    process = await Process.start(
      'git',
      args,
      workingDirectory: dir,
      environment: {'LC_ALL': 'C', 'GIT_OPTIONAL_LOCKS': '0', ...?environment},
    );
  } on ProcessException {
    return null;
  }
  process.stdin.close().ignore();
  final out = process.stdout.transform(utf8.decoder).join();
  process.stderr.drain<void>().ignore();
  try {
    final code = await process.exitCode.timeout(timeout);
    return code == 0 ? (await out).trim() : null;
  } on TimeoutException {
    process.kill(ProcessSignal.sigkill);
    return null;
  } on Exception {
    return null;
  }
}

/// Which thor a project is made from, and whether it is stale: the global
/// `thor` is installed from a checkout (`dart pub global activate --source
/// path`), and a project takes its packages from whatever state that
/// checkout is in, silently.
class CheckoutStatus {
  CheckoutStatus._({
    required this.root,
    this.isGit = false,
    this.commit,
    this.date,
    this.branch,
    this.defaultBranch,
    this.behind,
    this.ahead,
    this.dirty = false,
  });

  /// The checkout's folder.
  final String root;

  /// Whether [root] is the top of a git working tree.
  final bool isGit;

  /// The short hash of `HEAD`.
  final String? commit;

  /// The commit date (`YYYY-MM-DD`).
  final String? date;

  /// The current branch; null when detached.
  final String? branch;

  /// The branch the repository calls its default, when it can tell.
  final String? defaultBranch;

  /// Commits of the upstream not in `HEAD`, as of the last fetch; null
  /// without an upstream.
  final int? behind;

  /// Commits of `HEAD` not in the upstream; null without an upstream.
  final int? ahead;

  /// Whether tracked files have uncommitted changes.
  final bool dirty;

  /// `HEAD` is on no branch.
  bool get detached => isGit && branch == null;

  String get _behindWarning =>
      'this checkout is $behind commit${behind == 1 ? '' : 's'} behind its '
      'upstream (as of the last fetch): `git -C $root pull`, then '
      '`tool/thor setup`.';

  /// What deserves attention: a stale or unusual checkout.
  List<String> get warnings => [
    if (isGit && (behind ?? 0) > 0) _behindWarning,
    if (dirty) 'this checkout has uncommitted changes.',
    if (detached)
      'HEAD is detached: the project gets whatever commit is checked out.'
    else if (branch != null && defaultBranch != null && branch != defaultBranch)
      'this checkout is on "$branch", not "$defaultBranch".',
  ];

  /// Facts that are not problems.
  List<String> get notes => [
    if (!isGit)
      'not a git checkout (or git is missing): its version is unknown.'
    else if (behind == null && !detached)
      'no upstream configured: cannot tell whether it is behind.',
  ];

  /// One line: where thor comes from, its commit, date and branch.
  String describe() {
    if (!isGit) return '$root (not a git checkout)';
    final where = detached ? 'detached HEAD' : branch;
    final extra = (ahead ?? 0) > 0 ? ', $ahead ahead' : '';
    return '$root @ $commit ($date), $where$extra';
  }
}

/// The state of the thor checkout at [root], reading git without fetching
/// (pass [git] to fake it in a test).
Future<CheckoutStatus> checkoutStatus(
  String root, {
  GitRunner git = runGit,
}) async {
  Future<String?> run(List<String> args) async {
    try {
      return await git(root, args);
    } on Exception {
      return null;
    }
  }

  final top = await run(['rev-parse', '--show-toplevel']);
  // A folder inside some other repository is not a checkout of its own.
  if (top == null || !_same(top, root)) return CheckoutStatus._(root: root);

  final log = (await run(['log', '-1', r'--format=%h%x09%cs']))?.split('\t');
  final branch = await run(['symbolic-ref', '--short', '-q', 'HEAD']);
  var defaultBranch = (await run([
    'symbolic-ref',
    '--short',
    '-q',
    'refs/remotes/origin/HEAD',
  ]))?.replaceFirst('origin/', '');
  if (defaultBranch == null) {
    for (final candidate in ['main', 'master']) {
      if (await run(['rev-parse', '--verify', '-q', 'refs/heads/$candidate']) !=
          null) {
        defaultBranch = candidate;
        break;
      }
    }
  }
  final counts = (await run([
    'rev-list',
    '--left-right',
    '--count',
    'HEAD...@{u}',
  ]))?.split(RegExp(r'\s+'));
  final ahead = counts?.length == 2 ? int.tryParse(counts![0]) : null;
  final behind = counts?.length == 2 ? int.tryParse(counts![1]) : null;
  final status = await run(['status', '--porcelain', '--untracked-files=no']);

  return CheckoutStatus._(
    root: root,
    isGit: true,
    commit: log != null && log.length == 2 ? log[0] : '?',
    date: log != null && log.length == 2 ? log[1] : '?',
    branch: branch == null || branch.isEmpty ? null : branch,
    defaultBranch: defaultBranch,
    behind: behind,
    ahead: ahead,
    dirty: status != null && status.isNotEmpty,
  );
}

bool _same(String a, String b) {
  String real(String path) {
    try {
      return Directory(path).resolveSymbolicLinksSync();
    } on FileSystemException {
      return p.normalize(path);
    }
  }

  return real(a) == real(b);
}

/// Prints [status]: the line, then each warning and note.
void reportCheckout(
  CheckoutStatus status, {
  required void Function(String) line,
  required void Function(String) warn,
  required void Function(String) note,
}) {
  line('thor: ${status.describe()}');
  status.warnings.forEach(warn);
  status.notes.forEach(note);
}

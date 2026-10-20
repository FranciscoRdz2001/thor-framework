/// Where the project's source lives: the one place that knows the host, the
/// repository and its branch, so a link to a file is `repoFile(path)`.
library;

/// The repository, for links to source files the site doesn't publish.
const repositoryUrl = 'https://github.com/FranciscoRdz2001/thor-framework';

/// The branch the links point to.
const repositoryBranch = 'master';

/// What the host shows at a path.
enum RepoView {
  /// A file.
  blob,

  /// A folder.
  tree,

  /// A file in the host's editor.
  edit,
}

/// The host's page for [path] (from the repository's root) in [view].
String repoFile(String path, {RepoView view = RepoView.blob}) =>
    '$repositoryUrl/${view.name}/$repositoryBranch/$path';

/// The contribution guide: `contribuir` left the site for `CONTRIBUTING.md`.
const contributingUrl = '$repositoryUrl/blob/$repositoryBranch/CONTRIBUTING.md';

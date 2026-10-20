/// `:::bench bench-start-install`: from the commands to the first page. A
/// Switch picks where the project takes Thor from, another the title of its
/// home page; the Code view writes the commands and the stage shows the page
/// `thor dev` opens.
///
/// Both choices are finite, so the stage is `Watch.field` variants the
/// server compiled ahead and the Code view lines are methods of the state.
library;

import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../../core/content/repository.dart';
import 'bench_example.dart';

/// The clone URL of the project's repository.
const _repo = '$repositoryUrl.git';

/// Where the new project takes Thor from.
enum InstallSource {
  /// The checkout the `thor` command was installed from.
  local,

  /// A git repository (a project to share or deploy).
  git,
}

/// The title `thor create --title` writes on the home page.
enum InstallTitle {
  /// The default.
  hello,

  /// A custom one.
  store,
}

/// What the panel controls and the stage reads.
class InstallViewModel extends ThorState {
  /// Where Thor comes from.
  final source = state(InstallSource.local);

  /// The home page's title.
  final title = state(InstallTitle.hello);

  /// The `thor create` line of the Code view.
  String createCode() {
    final line = StringBuffer('thor create my_app');
    if (source.value == InstallSource.git) line.write(' --git <url>');
    if (title.value == InstallTitle.store) line.write(" --title 'My store'");
    return line.toString();
  }

  /// The first line of the `pubspec.yaml` dependency `thor create` writes.
  String sourceLine() => source.value == InstallSource.local
      ? '    path: ../thor/packages/thor_ui'
      : '    git: {url: <url>, path: packages/thor_ui}';

  /// What the source Switch calls.
  void setSource(Set<InstallSource> value) => source.value = value.first;

  /// What the title Switch calls.
  void setTitle(Set<InstallTitle> value) => title.value = value.first;
}

/// One instance, at the top level: the browser boots with it.
final install = InstallViewModel();

/// The example: two Switches, the page and the commands.
final installBench = BenchExample(
  title: (t) => t.exStartInstallTitle,
  description: (t) => t.exStartInstallDescription,
  stage: const InstallStage(),
  code: BenchCode([
    const BenchCodeLine('git clone $_repo thor'),
    const BenchCodeLine(
      'dart pub global activate --source path thor/packages/thor_cli',
    ),
    BenchCodeLine.live(install.createCode),
    const BenchCodeLine('cd my_app'),
    const BenchCodeLine('thor dev'),
  ], language: 'bash'),
  controls: [
    BenchSwitch<InstallSource>(
      label: (t) => t.exStartInstallSource,
      value: install.source.value,
      onChanged: install.setSource,
      segments: [
        BenchSegment(
          InstallSource.local,
          label: (t) => t.exStartInstallSourceLocal,
        ),
        BenchSegment(InstallSource.git, label: (t) => 'Git'),
      ],
    ),
    BenchSwitch<InstallTitle>(
      label: (t) => t.exStartInstallTitleLabel,
      value: install.title.value,
      onChanged: install.setTitle,
      segments: [
        BenchSegment(InstallTitle.hello, label: (t) => 'Hello, Thor'),
        BenchSegment(InstallTitle.store, label: (t) => 'My store'),
      ],
    ),
  ],
);

/// The stage: the address `thor dev` serves and the page it shows.
class InstallStage extends StatelessWidget {
  /// The stage of the example.
  const InstallStage({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 16,
    children: [
      Watch.field(
        install.title,
        builder: (title) => _FirstPage(
          title: title == InstallTitle.store ? 'My store' : 'Hello, Thor',
        ),
      ),
      const _Pubspec(),
    ],
  );
}

/// The dependency the project's `pubspec.yaml` gets: where Thor comes from.
class _Pubspec extends StatelessWidget {
  const _Pubspec();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mono = StudioExtraTextStyles.of(context);
    final style = mono.codeMedium.copyWith(color: scheme.onSurfaceVariant!);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('my_app/pubspec.yaml', style: style),
            Text('dependencies:', style: style),
            Text('  thor_ui:', style: style),
            Watch(install.sourceLine, style: style),
          ],
        ),
      ),
    );
  }
}

class _FirstPage extends StatelessWidget {
  const _FirstPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final mono = StudioExtraTextStyles.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Text(
                'localhost:4300',
                style: mono.codeMedium.copyWith(
                  color: scheme.onSurfaceVariant!,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Semantics(
                    headingLevel: 1,
                    child: Text(title, style: text.titleLarge),
                  ),
                  Text(
                    'Edit lib/modules/home/pages/home_page.dart and save: the page updates by itself.',
                    style: text.bodySmall.copyWith(
                      color: scheme.onSurfaceVariant!,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

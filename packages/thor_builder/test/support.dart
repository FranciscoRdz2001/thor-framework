import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';

/// Runs [builder] on [sources] (`'app|lib/x.dart': code`) and returns what
/// it generated, by asset id. [logs] collects its messages.
Future<Map<String, String>> generate(
  Builder builder,
  Map<String, String> sources, {
  List<String>? logs,
}) async {
  final rw = TestReaderWriter(rootPackage: 'app');
  await rw.testing.loadIsolateSources();
  await testBuilder(
    builder,
    sources,
    rootPackage: 'app',
    readerWriter: rw,
    onLog: (r) => logs?.add('${r.level.name}: ${r.message}'),
  );
  // Outputs are stored under the build's generated folder; key them by
  // where the app sees them.
  const generated = '.dart_tool/build/generated/app/';
  return {
    for (final id in rw.testing.assets)
      if (id.package == 'app' && id.path.startsWith(generated))
        'app|${id.path.substring(generated.length)}': rw.testing.readString(id),
  };
}

/// The compile errors of [library] with [sources] (hand-written and
/// generated files together): generated code must compile, not just
/// contain the right text.
Future<List<String>> compileErrors(
  Map<String, String> sources,
  String library,
) => resolveSources(
  sources,
  (resolver) async {
    final lib = await resolver.libraryFor(AssetId.parse(library));
    final errors = <String>[];
    for (final fragment in [
      lib.firstFragment,
      ...lib.firstFragment.partIncludes.map((p) => p.includedFragment).nonNulls,
    ]) {
      final result =
          await lib.session.getErrors(fragment.source.fullName) as ErrorsResult;
      errors.addAll([
        for (final d in result.diagnostics)
          if (d.severity == Severity.error)
            '${fragment.source.shortName}: ${d.message}',
      ]);
    }
    return errors;
  },
  rootPackage: 'app',
  readAllSourcesFromFilesystem: true,
);

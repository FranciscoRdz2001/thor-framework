import 'package:build/build.dart';
import 'package:glob/glob.dart';

import 'format.dart' show formatDart;
import 'l10n/generate.dart';

/// Generates `lib/l10n/app_localizations.thor.dart` from the ARB files of
/// `lib/l10n/` (Flutter's `gen-l10n`, as a build step): a typed
/// `AppLocalizations` with a getter or method per message, one subclass per
/// locale, `lookupAppLocalizations` and the delegate.
///
/// Options (`build.yaml`, `thor_builder:thor_l10n`): `template_arb_file`
/// (`app_en.arb`), `output_class` (`AppLocalizations`) and
/// `missing_translations` (`warning`, or `error` to fail the build when a
/// locale lacks a message).
class ThorL10nBuilder implements Builder {
  /// A builder with the app's options.
  ThorL10nBuilder({
    this.templateArbFile = 'app_en.arb',
    this.outputClass = 'AppLocalizations',
    this.missingAreErrors = false,
  });

  /// The complete ARB file, whose placeholders are the contract.
  final String templateArbFile;

  /// The generated class.
  final String outputClass;

  /// Whether a missing translation fails the build.
  final bool missingAreErrors;

  @override
  final buildExtensions = const {
    r'$package$': ['lib/l10n/app_localizations.thor.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final package = buildStep.inputId.package;
    final files = <String, String>{};
    await for (final id in buildStep.findAssets(Glob('lib/l10n/*.arb'))) {
      files[id.pathSegments.last] = await buildStep.readAsString(id);
    }
    if (files.isEmpty) return;
    final result = generateLocalizations(
      files,
      templateArbFile: templateArbFile,
      outputClass: outputClass,
      missingAreErrors: missingAreErrors,
    );
    for (final w in result.warnings) {
      log.warning('lib/l10n/$w');
    }
    final code = result.code;
    if (code == null) {
      for (final e in result.errors) {
        log.severe('lib/l10n/$e');
      }
      return;
    }
    if (code.contains("'package:intl/") &&
        !await _dependsOnIntl(buildStep, package)) {
      log.severe(
        'lib/l10n: plurals and formatted placeholders use package:intl; '
        'add `intl: ^0.20.2` to the dependencies of pubspec.yaml',
      );
      return;
    }
    await buildStep.writeAsString(
      AssetId(package, 'lib/l10n/app_localizations.thor.dart'),
      formatDart(code),
    );
  }

  /// Whether the app's pubspec lists `intl` under `dependencies`.
  static Future<bool> _dependsOnIntl(BuildStep step, String package) async {
    final id = AssetId(package, 'pubspec.yaml');
    if (!await step.canRead(id)) return true; // can't tell: let it compile
    var inDependencies = false;
    for (final line in (await step.readAsString(id)).split('\n')) {
      if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
        inDependencies = line.trimRight() == 'dependencies:';
      } else if (inDependencies && RegExp(r'^\s+intl\s*:').hasMatch(line)) {
        return true;
      }
    }
    return false;
  }
}

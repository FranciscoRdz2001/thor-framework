/// Builders of thor apps (applied automatically by `build_runner` to an app
/// that depends on thor_builder).
library;

import 'package:build/build.dart';

import 'src/l10n_builder.dart';

/// `lib/l10n/app_localizations.thor.dart`: the typed messages of the ARB
/// files in `lib/l10n/`.
Builder thorL10nBuilder(BuilderOptions options) => ThorL10nBuilder(
  templateArbFile:
      options.config['template_arb_file'] as String? ?? 'app_en.arb',
  outputClass: options.config['output_class'] as String? ?? 'AppLocalizations',
  missingAreErrors: options.config['missing_translations'] == 'error',
);

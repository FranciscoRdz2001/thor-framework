import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/router.dart' show RequestScope;
import 'package:thor_ui/thor_ui.dart';

import '../../../core/i18n/docs_locale.dart';
import '../search_routes.dart';

/// The search form: a GET to the search page itself (without JavaScript it
/// is a plain form; `search.js` answers as you type).
class SearchBox extends StatelessWidget {
  /// The form.
  const SearchBox({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final prefix = RequestScope.of(context).publicPathPrefix;
    final pill = BorderRadius.circular(StudioRadii.control);
    return StudioAttributes(
      {
        'role': 'search',
        'action': '$prefix${context.localized(searchRoute.link())}',
        'method': 'get',
      },
      child: Semantics(
        role: SemanticsRole.form,
        child: TextField(
          name: 'q',
          autofocus: true,
          keyboardType: TextInputType.webSearch,
          style: text.bodyLarge.copyWith(color: scheme.onSurface),
          decoration: InputDecoration(
            hintText: t.searchHint,
            hintStyle: text.bodyLarge.copyWith(color: scheme.onSurfaceVariant!),
            filled: true,
            fillColor: scheme.surfaceContainer,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: StudioSpacing.lg,
              vertical: StudioSpacing.sm,
            ),
            border: OutlineInputBorder(
              borderRadius: pill,
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: pill,
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: pill,
              borderSide: BorderSide(color: scheme.accent, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

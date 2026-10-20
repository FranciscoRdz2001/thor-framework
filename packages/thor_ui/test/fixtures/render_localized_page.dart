// A localized static app, run by static_render_test.dart with
// `THOR_LOCALE`: prints the locale it rendered in.
import 'package:thor_ui/server.dart';
import 'package:thor_ui/thor_ui.dart';

class _Locale extends StatelessWidget implements ThorElementWidget {
  const _Locale();

  @override
  Widget build(BuildContext context) =>
      Text('in ${Localizations.localeOf(context).toLanguageTag()}');
}

void main() {
  initializeThor(styles: const []);
  runApp(
    const Document(
      title: 'Fixture',
      body: ThorApp(
        supportedLocales: [Locale('en'), Locale('ar')],
        localizationsDelegates: [],
        child: _Locale(),
      ),
    ),
  );
}

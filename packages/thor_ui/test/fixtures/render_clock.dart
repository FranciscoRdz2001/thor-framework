// Prints the month the date picker opens on (`render_clock_test.dart`).
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<void> main() async {
  initializeThorTests();
  final html = bodyOfPage(
    await renderDocument(
      ThorApp(
        child: CalendarDatePicker(
          initialDate: null,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          onDateChanged: (_) {},
        ),
      ),
    ),
  );
  print(RegExp(r'role="grid" aria-label="([^"]*)"').firstMatch(html)![1]);
}

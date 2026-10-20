// ignore_for_file: public_member_api_docs
// (each value is named by its region; a doc comment would sit outside the
// code the site shows)
// What the previews of the component catalog share (catalog_*.dart): the
// colours of a modal's backdrop and shadow, and the view model of the
// decorative buttons.
import 'package:thor_ui/thor_ui.dart';

/// The dimmed backdrop of a modal, as the previews of the catalog draw it.
const scrimColor = Color(0x52000000);

/// The shadow of an open dialog, as the previews of the catalog draw it.
const modalShadowColor = Color(0x33000000);

/// What the decorative buttons of the demos call: a button with no handler
/// is disabled, and a demo's button should look enabled. The message says
/// what it is.
class DemoViewModel extends ThorState {
  /// Tells the visitor the button is part of a demonstration.
  void notice() => toast('This is a demo: the button does nothing else.');
}

/// One instance, at the top level.
final demo = DemoViewModel();

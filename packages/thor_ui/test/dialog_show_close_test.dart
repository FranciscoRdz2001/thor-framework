// `showClose: true` on a dialog, sheet or drawer puts the close button in
// its corner: a labelled icon button that closes the panel it is in.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget body) => renderDocument(ThorApp(child: body));

void main() {
  final named = <String, Widget>{
    'AlertDialog': const AlertDialog(
      id: 'p',
      showClose: true,
      closeLabel: 'Cerrar',
      title: Text('t'),
    ),
    'Dialog': const Dialog(
      id: 'p',
      showClose: true,
      closeLabel: 'Cerrar',
      child: Text('c'),
    ),
    'ModalBottomSheet': const ModalBottomSheet(
      id: 'p',
      showClose: true,
      closeLabel: 'Cerrar',
      child: Text('c'),
    ),
    'Drawer': const Drawer(
      id: 'p',
      showClose: true,
      closeLabel: 'Cerrar',
      child: Text('c'),
    ),
  };
  for (final MapEntry(:key, :value) in named.entries) {
    test('$key names its close button with closeLabel', () async {
      final html = await _page(value);
      final button = RegExp(
        r'<button[^>]*command="close"[^>]*>',
      ).firstMatch(html)!;
      expect(button.group(0), contains('aria-label="Cerrar"'));
      expect(button.group(0), isNot(contains('Close')));
    });
  }

  final panels = <String, Widget Function(bool)>{
    'AlertDialog': (s) => AlertDialog(
      id: 'p',
      showClose: s,
      title: const Text('t'),
      content: const Text('c'),
    ),
    'Dialog': (s) => Dialog(id: 'p', showClose: s, child: const Text('c')),
    'ModalBottomSheet': (s) =>
        ModalBottomSheet(id: 'p', showClose: s, child: const Text('c')),
    'Drawer': (s) => Drawer(id: 'p', showClose: s, child: const Text('c')),
  };

  for (final MapEntry(:key, :value) in panels.entries) {
    test('$key brings a close button when asked', () async {
      final html = await _page(value(true));
      final button = RegExp(
        r'<button[^>]*command="close"[^>]*>',
      ).firstMatch(html);
      expect(button, isNotNull, reason: html);
      expect(button!.group(0), contains('commandfor="p"'));
      expect(button.group(0), contains('aria-label="Close"'));
    });

    test('$key has none by default', () async {
      final html = await _page(value(false));
      expect(html, isNot(contains('command="close"')));
    });
  }

  test('an inline drawer hides the button from its breakpoint', () async {
    final html = await _page(
      const Drawer(
        id: 'p',
        showClose: true,
        permanentFrom: WindowSizeClass.expanded,
        child: Text('c'),
      ),
    );
    expect(html, contains('command="close"'));
    expect(
      html,
      matches(RegExp(r'@media[^{]*min-width[^{]*\{[^}]*display: none')),
    );
  });
}

// The lite translator's side of `Shortcuts`/`Actions` and
// `Focus(onKeyEvent:)`: a CallbackAction's method gets its intent
// made again, an onKeyEvent method gets the page's event and returns a
// KeyEventResult the `key_actions` part reads by name.
import 'package:test/test.dart';

import 'lite_oracle.dart';

void main() {
  test('a CallbackAction method gets its intent, made again', () async {
    final js = await translate('''
$header
class SaveIntent extends Intent {
  const SaveIntent();
  String get label => 'save';
}

class EditorState extends ThorState {
  final log = state('');

  void save(SaveIntent intent) => log.value = '\${log.value}|\${intent.label}';
  String label() => log.value;
}
''');
    if (!hasNode) return markTestSkipped('node is not installed');
    final out = runJs(js, 'S.save(); S.save(null); out.log = S.label();');
    expect(out['log'], '|save|save');
  });

  test('an intent the page can not make again is a build error', () async {
    final errors = await liteErrors('''
$header
class MoveIntent extends Intent {
  const MoveIntent(this.by);
  final int by;
}

class GridState extends ThorState {
  final at = state(0);

  void move(MoveIntent intent) => at.value += intent.by;
}
''');
    expect(errors.single.message, contains('constructor without arguments'));
  });

  test('onKeyEvent gets the KeyEvent and returns a KeyEventResult', () async {
    final js = await translate('''
$header
class GridState extends ThorState {
  final log = state('');

  KeyEventResult onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      log.value = '\${log.value}|enter\${event is KeyRepeatEvent ? '+' : ''}';
      return KeyEventResult.handled;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.keyS:
        log.value = '\${log.value}|s:\${event.character}';
        return KeyEventResult.skipRemainingHandlers;
      default:
        log.value = '\${log.value}|\${event.logicalKey.keyLabel}:\${event.character ?? '-'}';
        return KeyEventResult.ignored;
    }
  }

  String label() => log.value;
}
''');
    if (!hasNode) return markTestSkipped('node is not installed');
    final out = runJs(js, '''
const r = [
  S.onKey('[0,"Enter",null]'), S.onKey('[1,"Enter",null]'),
  S.onKey('[0,"s","S"]'), S.onKey('[0,"ArrowUp",null]'), S.onKey('[0,"~","~"]'),
];
out.results = r.map((x) => x.name);
out.log = S.label();
''');
    expect(out['results'], [
      'handled',
      'handled',
      'skipRemainingHandlers',
      'ignored',
      'ignored',
    ]);
    expect(out['log'], '|enter|enter+|s:S|ArrowUp:-|~:~');
  });

  test('the onKeyEvent FocusNode is not the page\'s: using it fails', () async {
    final errors = await liteErrors('''
$header
class GridState extends ThorState {
  KeyEventResult onKey(FocusNode node, KeyEvent event) {
    node.unfocus();
    return KeyEventResult.handled;
  }
}
''');
    expect(errors.single.message, contains('FocusNode field of the state'));
  });
}

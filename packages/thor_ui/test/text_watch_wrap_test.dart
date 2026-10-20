@TestOn('vm')
library;

// A text bound to a state field keeps its line breaks whatever the server
// drew (the browser may bring a `\n` later), and `DefaultTextStyle.softWrap`
// asks for it without CSS.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

abstract class _LogMembers extends ThorState {
  @override
  String get $type => 'LogState';

  @override
  List<ThorMember> get $members {
    final s = this as LogState;
    return [ThorMember.state('text', s.text)];
  }
}

class LogState extends _LogMembers {
  final text = state('one line');
}

final log = LogState();

void main() {
  initializeThorTests();

  group('Watch text', () {
    test('keeps line breaks even when the server drew none', () async {
      final out = await renderHtml(Watch(log.text.call));
      expect(out, contains('data-tt="LogState.text"'));
      expect(out, contains('white-space: pre-wrap'));
    });

    test('a builder draws the app widget as it is', () async {
      final out = await renderHtml(Watch(log.text.call, builder: Text.new));
      expect(out, isNot(contains('pre-wrap')));
    });
  });

  group('DefaultTextStyle.softWrap', () {
    Future<String> wrapped(bool? softWrap) => renderHtml(
      DefaultTextStyle(
        style: const TextStyle(),
        softWrap: softWrap,
        child: const Text('a'),
      ),
    );

    test('false is pre, true is pre-wrap, null leaves it', () async {
      expect(await wrapped(false), contains('white-space: pre'));
      expect(await wrapped(false), isNot(contains('pre-wrap')));
      expect(await wrapped(true), contains('white-space: pre-wrap'));
      expect(await wrapped(null), isNot(contains('white-space')));
    });

    test('merge takes it too', () async {
      final out = await renderHtml(
        const DefaultTextStyle.merge(softWrap: true, child: Text('a')),
      );
      expect(out, contains('white-space: pre-wrap'));
    });
  });
}

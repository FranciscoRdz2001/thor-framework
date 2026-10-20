// `ServerEvent.toast`: the `thor-toast` event the lite engine shows in the
// page's snack bar from any `events()` stream.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

void main() {
  test('is a named event with the message, kind and duration as JSON', () {
    final e = ServerEvent.toast(
      'x.dart changed',
      kind: FlashKind.success,
      duration: const Duration(seconds: 3),
      id: '7',
    );
    expect(e.event, 'thor-toast');
    expect(e.event, ServerEvent.toastEventName);
    expect(e.id, '7');
    expect(jsonDecode(e.data), {
      'message': 'x.dart changed',
      'kind': 'success',
      'duration': 3000,
    });
  });

  test('defaults to info with no duration, and cuts a long message', () {
    final plain = ServerEvent.toast('hi');
    expect(jsonDecode(plain.data), {'message': 'hi', 'kind': 'info'});
    final long = ServerEvent.toast('a' * 1000);
    expect(
      (jsonDecode(long.data) as Map)['message'],
      hasLength(flashMaxLength),
    );
    // A zero or negative duration is the snack bar's own.
    expect(
      jsonDecode(ServerEvent.toast('z', duration: Duration.zero).data),
      isNot(contains('duration')),
    );
  });

  test('a message with line breaks stays one data line on the wire', () {
    final bytes = utf8.decode(ServerEvent.toast('a\nb\r\nc').encode());
    expect(bytes, startsWith('event: thor-toast\ndata: {'));
    expect(RegExp('\n').allMatches(bytes), hasLength(3));
  });
}

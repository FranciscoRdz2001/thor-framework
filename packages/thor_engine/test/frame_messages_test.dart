import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

class _Driver implements FrameMessagesDriver {
  final posts = <(String?, String, String)>[];
  final listeners = <void Function(String, String)>[];
  final cancelled = <int>[];

  @override
  void post(String? frameId, String message, String targetOrigin) =>
      posts.add((frameId, message, targetOrigin));

  @override
  FrameSubscription listen(
    List<String> origins,
    void Function(String origin, String message) onMessage,
  ) {
    listeners.add(onMessage);
    final n = listeners.length;
    return FrameSubscription(() => cancelled.add(n));
  }
}

void main() {
  tearDown(() => FrameMessages.driver = null);

  group('origins', () {
    test('only explicit http(s) origins are valid', () {
      for (final ok in [
        'https://a.com',
        'http://localhost:8080',
        'https://preview.example.com:4443',
        'http://[::1]:3000',
      ]) {
        expect(FrameMessages.isValidOrigin(ok), isTrue, reason: ok);
      }
      for (final bad in [
        '*',
        'null',
        '',
        ' ',
        'https://*.a.com',
        'https://a.com/',
        'https://a.com/x',
        'https://a.com?x=1',
        'https://a.com#x',
        'https://u:p@a.com',
        'https://a.com:443',
        'http://a.com:80',
        'ftp://a.com',
        'javascript:alert(1)',
        'data:text/html,x',
        'a.com',
        '//a.com',
        'https://A.com',
        'https://',
      ]) {
        expect(FrameMessages.isValidOrigin(bad), isFalse, reason: bad);
      }
    });

    test('a bad origin throws on every call, with no driver too', () {
      for (final bad in ['*', 'null', 'https://a.com/']) {
        expect(
          () => FrameMessages.postToParent('x', targetOrigin: bad),
          throwsA(
            isA<ArgumentError>().having(
              (e) => '$e',
              'message',
              contains('THOR-S044'),
            ),
          ),
        );
        expect(
          () => FrameMessages.postToFrame('f', 'x', targetOrigin: bad),
          throwsArgumentError,
        );
        expect(
          () => FrameMessages.listen(origins: [bad], onMessage: (_, _) {}),
          throwsArgumentError,
        );
      }
      expect(
        () => FrameMessages.listen(origins: [], onMessage: (_, _) {}),
        throwsArgumentError,
      );
    });
  });

  group('driver', () {
    test('nothing happens on the server', () {
      FrameMessages.postToParent('x', targetOrigin: 'https://a.com');
      FrameMessages.postToFrame('f', 'x', targetOrigin: 'https://a.com');
      FrameMessages.listen(
        origins: ['https://a.com'],
        onMessage: (_, _) {},
      ).cancel();
    });

    test('calls reach the driver', () {
      final d = FrameMessages.driver = _Driver();
      FrameMessages.postToParent('a', targetOrigin: 'https://a.com');
      FrameMessages.postToFrame('canvas', 'b', targetOrigin: 'https://b.com');
      expect(d.posts, [
        (null, 'a', 'https://a.com'),
        ('canvas', 'b', 'https://b.com'),
      ]);
      final sub = FrameMessages.listen(
        origins: ['https://a.com'],
        onMessage: (_, _) {},
      );
      sub.cancel();
      sub.cancel();
      expect(d.cancelled, [1]);
    });
  });
}

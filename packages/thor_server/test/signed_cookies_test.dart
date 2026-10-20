// SignedCookies: server-side expiry (`maxAge`) and key rotation. Prior art:
// Plug.Crypto `MessageVerifier` + `max_age`, iron-session `ttl` and its map of
// passwords, Rails `MessageVerifier` rotations, itsdangerous
// `TimestampSigner.unsign(max_age:)`. `purpose:`: Rails `MessageVerifier`
// (`generate(…, purpose:)`) and itsdangerous' `salt`.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

const _k1 = 'k1-0123456789abcdef0123456789abcdef';
const _k2 = 'k2-0123456789abcdef0123456789abcdef';
const _k3 = 'k3-0123456789abcdef0123456789abcdef';

/// A cookie without an issue time: `payload.signature` over the payload
/// alone.
String _untimed(String secret, String value) {
  final payload = base64Url.encode(utf8.encode(value)).replaceAll('=', '');
  final sig = base64Url
      .encode(
        Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(payload)).bytes,
      )
      .replaceAll('=', '');
  return '$payload.$sig';
}

void main() {
  late DateTime now;
  DateTime clock() => now;

  setUp(() => now = DateTime.utc(2026, 1, 1, 12));

  group('expiry', () {
    test('a value verifies until maxAge and not after', () {
      final s = SignedCookies(
        _k1,
        maxAge: const Duration(hours: 1),
        clock: clock,
      );
      final c = s.sign('ana');
      now = now.add(const Duration(minutes: 59, seconds: 59));
      expect(s.verify(c), 'ana');
      now = now.add(const Duration(seconds: 1));
      expect(s.verify(c), isNull);
    });

    test(
      'an expired cookie stays rejected (the cache never resurrects it)',
      () {
        final s = SignedCookies(
          _k1,
          maxAge: const Duration(minutes: 1),
          clock: clock,
        );
        final c = s.sign('ana');
        expect(s.verify(c), 'ana'); // now cached
        now = now.add(const Duration(minutes: 2));
        expect(s.verify(c), isNull);
        expect(s.verify(c), isNull);
      },
    );

    test('maxAge zero rejects everything, even at the issue instant', () {
      final s = SignedCookies(_k1, maxAge: Duration.zero, clock: clock);
      expect(s.verify(s.sign('ana')), isNull);
    });

    test('a negative maxAge is a mistake', () {
      expect(
        () => SignedCookies(_k1, maxAge: const Duration(seconds: -1)),
        throwsArgumentError,
      );
    });

    test('without maxAge a signed value never expires', () {
      final s = SignedCookies(_k1, clock: clock);
      final c = s.sign('ana');
      now = now.add(const Duration(days: 3650));
      expect(s.verify(c), 'ana');
    });

    test('the issue time cannot be edited: the signature covers it', () {
      final s = SignedCookies(
        _k1,
        maxAge: const Duration(minutes: 1),
        clock: clock,
      );
      final parts = s.sign('ana').split('.');
      now = now.add(const Duration(minutes: 5));
      final fresh = now.millisecondsSinceEpoch ~/ 1000;
      expect(s.verify('${parts[0]}.$fresh.${parts[2]}'), isNull);
    });

    test('the payload cannot be swapped for another value', () {
      final s = SignedCookies(_k1, clock: clock);
      final a = s.sign('ana').split('.');
      final b = s.sign('root').split('.');
      expect(s.verify('${b[0]}.${a[1]}.${a[2]}'), isNull);
    });

    test('a clock a little ahead (another instance) is tolerated', () {
      final other = SignedCookies(
        _k1,
        maxAge: const Duration(hours: 1),
        clock: clock,
      );
      final c = other.sign('ana');
      now = now.subtract(const Duration(seconds: 30)); // this one runs behind
      expect(other.verify(c), 'ana');
    });

    test('an issue time far in the future is rejected', () {
      final s = SignedCookies(
        _k1,
        maxAge: const Duration(hours: 1),
        clock: clock,
      );
      final c = s.sign('ana');
      now = now.subtract(const Duration(hours: 1));
      expect(s.verify(c), isNull);
    });

    test('malformed cookies are null, never a throw', () {
      final s = SignedCookies(_k1, clock: clock);
      for (final bad in [
        '',
        '.',
        '..',
        'a.b.c.d',
        'YW5h.notanumber.sig',
        'YW5h.-5.sig',
        'YW5h..sig',
        '%%%.1.x',
      ]) {
        expect(s.verify(bad), isNull, reason: bad);
      }
      expect(s.verify(null), isNull);
    });
  });

  group('rotation', () {
    test('signs with the first key, verifies with any', () {
      final old = SignedCookies(_k1);
      final rotated = SignedCookies(_k2, previousSecrets: [_k1]);
      expect(rotated.verify(old.sign('ana')), 'ana');
      // New cookies are signed with the new key: the old signer refuses them.
      expect(old.verify(rotated.sign('ana')), isNull);
      expect(SignedCookies(_k2).verify(rotated.sign('ana')), 'ana');
    });

    test('a key that was retired stops working', () {
      final old = SignedCookies(_k1);
      final rotated = SignedCookies(_k2, previousSecrets: [_k1]);
      final c = old.sign('ana');
      expect(rotated.verify(c), 'ana');
      expect(SignedCookies(_k2).verify(c), isNull); // k1 dropped from the list
    });

    test('a key that was never known is rejected', () {
      final rotated = SignedCookies(_k2, previousSecrets: [_k1]);
      expect(rotated.verify(SignedCookies(_k3).sign('ana')), isNull);
    });

    test('rotation mid-session: the old cookie keeps its original expiry', () {
      final old = SignedCookies(
        _k1,
        maxAge: const Duration(hours: 1),
        clock: clock,
      );
      final c = old.sign('ana');
      now = now.add(const Duration(minutes: 30));
      final rotated = SignedCookies(
        _k2,
        previousSecrets: [_k1],
        maxAge: const Duration(hours: 1),
        clock: clock,
      );
      expect(rotated.verify(c), 'ana');
      now = now.add(const Duration(minutes: 31));
      expect(rotated.verify(c), isNull); // rotating does not renew it
    });

    test('a previous key shorter than 32 bytes is refused too', () {
      expect(
        () => SignedCookies(_k1, previousSecrets: ['short']),
        throwsArgumentError,
      );
    });

    test('the same key listed twice is harmless', () {
      final s = SignedCookies(_k1, previousSecrets: [_k1]);
      expect(s.verify(s.sign('ana')), 'ana');
    });

    test('a tampered signature fails against every key', () {
      final s = SignedCookies(_k1, previousSecrets: [_k2]);
      final c = s.sign('ana');
      final flipped =
          '${c.substring(0, c.length - 1)}${c.endsWith('A') ? 'B' : 'A'}';
      expect(s.verify(flipped), isNull);
    });
  });

  group('cookies without an issue time', () {
    test('are rejected, with or without maxAge', () {
      expect(
        SignedCookies(_k1, clock: clock).verify(_untimed(_k1, 'ana')),
        isNull,
      );
      final s = SignedCookies(
        _k1,
        maxAge: const Duration(days: 30),
        clock: clock,
      );
      expect(s.verify(_untimed(_k1, 'ana')), isNull);
      expect(
        SignedCookies(_k2, previousSecrets: [_k1]).verify(_untimed(_k1, 'a')),
        isNull,
      );
    });

    test('cannot be forged from a timed one', () {
      final s = SignedCookies(_k1, clock: clock);
      final parts = s.sign('ana').split('.');
      expect(s.verify('${parts[0]}.${parts[2]}'), isNull);
    });
  });

  group('purpose', () {
    test('a value signed for one purpose is rejected under another', () {
      final session = SignedCookies(_k1, purpose: 'session', clock: clock);
      final flash = SignedCookies(_k1, purpose: 'flash', clock: clock);
      final c = session.sign('ana');
      expect(session.verify(c), 'ana');
      expect(flash.verify(c), isNull);
      expect(session.verify(flash.sign('ana')), isNull);
    });

    test('the cache of verified cookies does not cross purposes', () {
      final session = SignedCookies(_k1, purpose: 'session', clock: clock);
      final c = session.sign('ana');
      expect(session.verify(c), 'ana'); // now cached in `session`
      expect(SignedCookies(_k1, purpose: 'flash').verify(c), isNull);
    });

    test('no value signed without purpose can carry a purposed signature', () {
      // The unpurposed signer only signs base64url text and digits, never a
      // newline, so `purpose\ntext` is out of its reach.
      final plain = SignedCookies(_k1, clock: clock);
      final a = SignedCookies(_k1, purpose: 'a', clock: clock);
      for (final v in ['a\nb', 'a', '\n', 'session\nx', 'propósito\n😀']) {
        expect(a.verify(plain.sign(v)), isNull);
        expect(plain.verify(a.sign(v)), isNull);
        expect(
          SignedCookies(_k1, purpose: 'ñ', clock: clock).verify(a.sign(v)),
          isNull,
        );
      }
      final ab = SignedCookies(_k1, purpose: 'a\u{1F600}', clock: clock);
      expect(ab.verify(ab.sign('x')), 'x');
    });

    test('with and without a purpose never verify each other', () {
      final plain = SignedCookies(_k1, clock: clock);
      final session = SignedCookies(_k1, purpose: 'session', clock: clock);
      expect(plain.verify(session.sign('ana')), isNull);
      expect(session.verify(plain.sign('ana')), isNull);
    });

    test('purposes that are prefixes of each other stay apart', () {
      final a = SignedCookies(_k1, purpose: 'a', clock: clock);
      final ab = SignedCookies(_k1, purpose: 'ab', clock: clock);
      expect(ab.verify(a.sign('x')), isNull);
      expect(a.verify(ab.sign('x')), isNull);
    });

    test('without a purpose the format is the one of before', () {
      final s = SignedCookies(_k1, clock: clock);
      final parts = s.sign('ana').split('.');
      final payload = parts[0];
      final signed = '$payload.${parts[1]}';
      final sig = base64Url
          .encode(
            Hmac(sha256, utf8.encode(_k1)).convert(utf8.encode(signed)).bytes,
          )
          .replaceAll('=', '');
      expect(parts[2], sig);
    });

    test('a purposed cookie has the same shape and expires like the rest', () {
      final s = SignedCookies(
        _k1,
        purpose: 'session',
        maxAge: const Duration(hours: 1),
        clock: clock,
      );
      final c = s.sign('ana');
      expect(c.split('.'), hasLength(3));
      now = now.add(const Duration(hours: 1));
      expect(s.verify(c), isNull);
    });

    test('rotation keeps working with a purpose', () {
      final old = SignedCookies(_k1, purpose: 'session', clock: clock);
      final rotated = SignedCookies(
        _k2,
        previousSecrets: [_k1],
        purpose: 'session',
        clock: clock,
      );
      expect(rotated.verify(old.sign('ana')), 'ana');
    });

    test('an empty purpose or one with a newline is refused', () {
      expect(() => SignedCookies(_k1, purpose: ''), throwsArgumentError);
      expect(() => SignedCookies(_k1, purpose: 'a\nb'), throwsArgumentError);
    });
  });

  group('session without expiry warns under thor dev', () {
    late bool wasEnabled;
    late List<String> said;
    late void Function(String) was;

    setUp(() {
      wasEnabled = ThorDev.enabled;
      was = SignedCookies.onWarning;
      SignedCookies.resetWarnings();
      said = [];
      SignedCookies.onWarning = said.add;
    });

    tearDown(() {
      ThorDev.enabled = wasEnabled;
      SignedCookies.onWarning = was;
      SignedCookies.resetWarnings();
    });

    test('built on every request it still says so once per process', () {
      ThorDev.enabled = true;
      for (var i = 0; i < 5; i++) {
        SignedCookies(_k1, purpose: 'session');
      }
      expect(said, hasLength(1));
    });

    test('a session with no maxAge says so once, with the code', () {
      ThorDev.enabled = true;
      SignedCookies(_k1, purpose: 'session');
      expect(said, hasLength(1));
      expect(said.single, contains('THOR-P033'));
      expect(said.single, contains('maxAge'));
    });

    test('a session with a maxAge, another purpose or a release is quiet', () {
      ThorDev.enabled = true;
      SignedCookies(_k1, purpose: 'session', maxAge: const Duration(days: 30));
      SignedCookies(_k1, purpose: 'flash');
      SignedCookies(_k1);
      ThorDev.enabled = false;
      SignedCookies(_k1, purpose: 'session');
      expect(said, isEmpty);
    });
  });
}

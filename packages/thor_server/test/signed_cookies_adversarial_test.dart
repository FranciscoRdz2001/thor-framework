// SignedCookies, attacker's view. Prior art: itsdangerous `TimestampSigner`
// (separator + timestamp under the signature), Plug.Crypto `MessageVerifier`
// (base64 segments, so no separator ambiguity).
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

const _k1 = 'k1-0123456789abcdef0123456789abcdef';
const _k2 = 'k2-0123456789abcdef0123456789abcdef';

String _b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');
String _sig(String secret, String text) =>
    _b64(Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(text)).bytes);

void main() {
  late DateTime now;
  setUp(() => now = DateTime.utc(2026, 1, 1, 12));
  SignedCookies make({
    Duration? maxAge = const Duration(hours: 1),
    List<String> previous = const [],
  }) => SignedCookies(
    _k1,
    previousSecrets: previous,
    maxAge: maxAge,
    clock: () => now,
  );

  test('payload with dots or the separator never re-splits', () {
    final s = make();
    for (final v in ['a.b', '.', 'a.1.b', '1700000000', '...', '']) {
      expect(s.verify(s.sign(v)), v);
    }
    final c = s.sign('a.b').split('.');
    // Moving the time into the payload or dropping it fails.
    expect(s.verify('${c[0]}.${c[2]}'), isNull);
    expect(s.verify('${c[0]}.${c[1]}.${c[1]}.${c[2]}'), isNull);
    expect(s.verify('${c[0]}..${c[2]}'), isNull);
  });

  test('a tampered, padded or extended time is rejected', () {
    final s = make();
    final c = s.sign('ana').split('.');
    final t = int.parse(c[1]);
    for (final forged in [
      '${t + 1}',
      '${t - 1}',
      '0$t',
      '00$t',
      '+$t',
      '-$t',
      ' $t',
      '$t ',
      '$t.0',
      '${t}e0',
      '0x${t.toRadixString(16)}',
      '99999999999999999999999999',
      '9223372036854775807',
      '-9223372036854775808',
      '',
      'NaN',
    ]) {
      expect(s.verify('${c[0]}.$forged.${c[2]}'), isNull, reason: forged);
    }
  });

  test('a validly signed but absurd time is still bounded', () {
    final s = make();
    for (final t in ['9223372036854775807', '0', '99999999999999999999']) {
      final text = '${_b64(utf8.encode('x'))}.$t';
      expect(s.verify('$text.${_sig(_k1, text)}'), isNull, reason: t);
    }
    // Far future is forged; near past inside maxAge is fine.
    final ok =
        '${_b64(utf8.encode('x'))}.${now.millisecondsSinceEpoch ~/ 1000}';
    expect(s.verify('$ok.${_sig(_k1, ok)}'), 'x');
  });

  test('stripping the time cannot make an untimed cookie', () {
    for (final maxAge in [null, const Duration(hours: 1)]) {
      final s = make(maxAge: maxAge);
      final c = s.sign('ana').split('.');
      // The signature covers `payload.time`, not `payload`.
      expect(s.verify('${c[0]}.${c[2]}'), isNull, reason: 'maxAge=$maxAge');
    }
    // A signature over the payload alone never passes.
    final p = _b64(utf8.encode('ana'));
    final untimed = '$p.${_sig(_k1, p)}';
    expect(make().verify(untimed), isNull);
    expect(make(maxAge: null).verify(untimed), isNull);
  });

  test('a cookie of a secret dropped from previousSecrets stops working', () {
    final old = SignedCookies(_k2, clock: () => now).sign('ana');
    expect(make(previous: [_k2]).verify(old), 'ana');
    final s = make(previous: [_k2]);
    expect(s.verify(old), 'ana'); // cached now
    expect(make().verify(old), isNull);
  });

  test('the verified cache re-checks age and stays bounded', () {
    final s = make();
    final c = s.sign('ana');
    expect(s.verify(c), 'ana');
    now = now.add(const Duration(hours: 2));
    expect(s.verify(c), isNull);
    final small = SignedCookies(_k1, clock: () => now);
    final old = SignedCookies.maxVerified;
    SignedCookies.maxVerified = 8;
    addTearDown(() => SignedCookies.maxVerified = old);
    for (var i = 0; i < 100; i++) {
      expect(small.verify(small.sign('v$i')), 'v$i');
    }
    // Forged values are never remembered: still rejected afterwards.
    expect(small.verify('${_b64(utf8.encode('x'))}.1.AAAA'), isNull);
  });

  test('garbage never throws', () {
    final s = make();
    for (final g in [
      '',
      '.',
      '..',
      '...',
      'a.b.c.d',
      '%%.1.x',
      'A' * 5000,
      '\u0000.1.x',
      'é.1.é',
      '${_b64([0xff, 0xfe])}.1.${'A' * 43}',
    ]) {
      expect(s.verify(g), isNull, reason: g);
    }
  });
}

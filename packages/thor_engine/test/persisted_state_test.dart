import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

Object? _read(String raw) => jsonDecode(Uri.decodeComponent(raw));

/// A request with [cookies], reading signals the way a page render does.
T _inRequest<T>(Map<String, String> cookies, T Function() body) =>
    SignalScope.withCookies(cookies, _read, () => SignalScope.run(body));

void main() {
  test('a request draws the page with the persisted value', () {
    final collapsed = state(false, cookie: 'sidebar');
    final width = state(240, cookie: 'width');
    expect(
      _inRequest({'thor-s.sidebar': 'true', 'thor-s.width': '180'}, () {
        return (collapsed.value, width.value, collapsed.changed);
      }),
      (true, 180, true),
    );
    // Another request (or none) never sees it.
    expect(_inRequest({}, () => collapsed.value), isFalse);
    expect(collapsed.value, isFalse);
  });

  test('a value that is not the field\'s is ignored, never an error', () {
    final collapsed = state(false, cookie: 'sidebar');
    final tags = state(<String>['a'], cookie: 'tags');
    for (final raw in [
      '"yes"', // another type
      '1',
      'not json',
      '%E0%A4%A', // bad percent-encoding
      'x' * (StateSignal.maxCookieLength + 1),
    ]) {
      expect(
        _inRequest({'thor-s.sidebar': raw}, () => collapsed.value),
        isFalse,
        reason: raw,
      );
    }
    expect(
      _inRequest({'thor-s.tags': Uri.encodeComponent('["b",3]')}, () {
        return tags.value;
      }),
      ['a'],
    );
    expect(
      _inRequest({'thor-s.tags': Uri.encodeComponent('["b","c"]')}, () {
        return tags.value;
      }),
      ['b', 'c'],
    );
  });

  test('decode runs on the cookie too; the first read decides per request', () {
    final mode = state<Duration>(
      Duration.zero,
      encode: (d) => d.inSeconds,
      decode: (j) => Duration(seconds: j! as int),
      cookie: 'lap',
    );
    expect(
      _inRequest({'thor-s.lap': '90'}, () {
        final first = mode.value;
        mode.value = const Duration(seconds: 5); // the page's own write wins
        return (first, mode.value);
      }),
      (const Duration(seconds: 90), const Duration(seconds: 5)),
    );
  });

  test('without the server\'s cookies (a static build) the code\'s value', () {
    final collapsed = state(false, cookie: 'sidebar');
    expect(SignalScope.run(() => collapsed.value), isFalse);
  });

  test('a cookie name is 1–40 letters, digits, _ or - (THOR-S009)', () {
    for (final bad in ['', 'a b', 'a;b', 'ñ', 'x' * 41, 'a=b']) {
      expect(
        () => state(0, cookie: bad),
        throwsA(
          isA<ArgumentError>().having((e) => '$e', 'text', contains('S009')),
        ),
        reason: bad,
      );
    }
    expect(state(0, cookie: 'Side_bar-2').cookie, 'Side_bar-2');
  });

  test("a local field: the server draws the code's value, never a cookie", () {
    final draft = state('', local: 'draft');
    expect(draft.local, 'draft');
    expect(draft.cookie, isNull);
    expect(
      _inRequest({'thor-s.draft': '%22hola%22'}, () {
        return (draft.value, draft.changed);
      }),
      ('', false),
    );
    // A new state keeps what the browser applied (like a cookie field).
    draft.value = 'x';
    draft.startOver();
    expect(draft.value, 'x');
  });

  test('a local key follows the cookie rule; one place only (THOR-S009)', () {
    for (final bad in ['', 'a b', 'ñ', 'x' * 41]) {
      expect(
        () => state(0, local: bad),
        throwsA(
          isA<ArgumentError>().having((e) => '$e', 'text', contains('S009')),
        ),
        reason: bad,
      );
    }
    expect(
      () => state(0, cookie: 'a', local: 'b'),
      throwsA(
        isA<ArgumentError>().having((e) => '$e', 'text', contains('not both')),
      ),
    );
  });

  group('localScope', () {
    test('compiles as a late final field of a ThorState', () {
      // A plain initializer cannot read `store` (no `this` yet): the field
      // that names the scope is `late final`.
      final view = _ScopedState();
      view.store.value = 'shop-a';
      expect(view.items.localKey, 'cart:shop-a');
    });

    test('names the storage key after the scope field', () {
      final store = state('shop-a');
      final cart = state(<String>[], local: 'cart', localScope: store);
      expect(cart.localKey, 'cart:shop-a');
      store.value = 'shop-b';
      expect(cart.localKey, 'cart:shop-b');
      expect(state(0, local: 'plain').localKey, 'plain');
      expect(state(0).localKey, isNull);
    });

    test('an empty or huge scope has no key (memory only)', () {
      final store = state('');
      final cart = state(0, local: 'cart', localScope: store);
      expect(cart.localKey, isNull);
      store.value = 'x' * (StateSignal.maxLocalScopeLength + 1);
      expect(cart.localKey, isNull);
      store.value = 'x' * StateSignal.maxLocalScopeLength;
      expect(cart.localKey, isNotNull);
    });

    test('needs local:', () {
      expect(
        () => state(0, cookie: 'c', localScope: state('a')),
        throwsArgumentError,
      );
    });
  });
}

class _ScopedState extends ThorState {
  final store = state('');
  late final items = state(<String>[], local: 'cart', localScope: store);
}

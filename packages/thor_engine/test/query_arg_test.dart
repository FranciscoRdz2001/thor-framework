// A query's argument can be a class (or a record) that travels as JSON:
// The server decodes what the browser sends with the `fromJson` the builder
// passes to `members`, and a hostile shape is an ArgumentError (a 400), not
// A TypeError out of the app's code.
import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

class OrdersFilter {
  const OrdersFilter({this.q = '', this.page = 1, this.tags = const []});
  factory OrdersFilter.fromJson(Map<String, Object?> json) => OrdersFilter(
    q: json['q']! as String,
    page: json['page']! as int,
    tags: (json['tags']! as List<Object?>).cast<String>(),
  );
  final String q;
  final int page;
  final List<String> tags;
  OrdersFilter copyWith({String? q, int? page, List<String>? tags}) =>
      OrdersFilter(
        q: q ?? this.q,
        page: page ?? this.page,
        tags: tags ?? this.tags,
      );
  Map<String, Object?> toJson() => {'q': q, 'page': page, 'tags': tags};
}

class ListState extends ThorState {
  ListState({super.key});
  final orders = queryWith(
    (OrdersFilter f) async => '${f.q}|${f.page}|${f.tags.join(',')}',
    arg: const OrdersFilter(),
  );
  final byRecord = queryWith(
    ((String, int) r) async => '${r.$1}${r.$2}',
    arg: ('', 1),
  );
}

// A state with its members made (the builder's decoders are set there).
ListState _make() {
  final s = ListState();
  s.members;
  return s;
}

void main() {
  setUpAll(
    () => ThorState.register({
      ListState: ThorStateType('ListState', (state) {
        final s = state as ListState;
        return [
          ...s.orders.members(
            'orders',
            argToJson: (a) => a.toJson(),
            argFromJson: OrdersFilter.fromJson,
          ),
          ...s.byRecord.members(
            'byRecord',
            argToJson: (a) => {r'$1': a.$1, r'$2': a.$2},
            argFromJson: (j) => (j[r'$1']! as String, j[r'$2']! as int),
          ),
        ];
      }),
    }),
  );

  group('a class argument', () {
    test('the server decodes the browser\'s JSON with nested lists', () async {
      final s = _make();
      final call = s.orders.callWith({
        'q': 'ñandú 日本',
        'page': 3,
        'tags': ['b', 'a'],
      });
      expect(await call(), 'ñandú 日本|3|b,a');
    });

    test(
      'an equal instance is not needed: only the shape is checked',
      () async {
        final s = _make();
        expect(
          await s.orders.callWith({'q': '', 'page': 1, 'tags': <String>[]})(),
          '|1|',
        );
      },
    );

    test('a hostile shape is an ArgumentError, never a TypeError', () {
      final s = _make();
      for (final bad in <Object?>[
        null,
        3,
        'x',
        <Object?>[],
        <String, Object?>{},
        {'q': 5, 'page': 1, 'tags': <String>[]},
        {'q': '', 'page': '1', 'tags': <String>[]},
        {'q': '', 'page': 1, 'tags': 'a'},
        {
          'q': '',
          'page': 1,
          'tags': [1, 2],
        },
        {'q': '', 'page': 1e99, 'tags': <String>[]},
      ]) {
        expect(
          () => s.orders.callWith(bad),
          throwsA(isA<ArgumentError>()),
          reason: '$bad',
        );
      }
    });

    test('without the builder\'s decoder a map is refused, not guessed', () {
      final q = queryWith(
        (OrdersFilter f) async => f.q,
        arg: const OrdersFilter(),
      );
      expect(() => q.callWith({'q': 'a'}), throwsA(isA<ArgumentError>()));
      // An instance (a unit test's own call) goes through.
      expect(() => q.callWith(const OrdersFilter(q: 'a')), returnsNormally);
    });

    test('the arg signal writes its JSON with the same encoder', () {
      final s = _make();
      s.orders.arg.value = const OrdersFilter(q: 'x', page: 2, tags: ['t']);
      expect(s.orders.arg.toJson(), {
        'q': 'x',
        'page': 2,
        'tags': ['t'],
      });
    });
  });

  group('a record argument', () {
    test('travels as its fields', () async {
      final s = _make();
      expect(await s.byRecord.callWith({r'$1': 'a', r'$2': 7})(), 'a7');
      expect(
        () => s.byRecord.callWith({r'$1': 'a', r'$2': 'seven'}),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('a hostile argument from the browser is a bad request', () {
    test('the wrong JSON is an ArgumentError, never another error', () {
      final s = _make();
      for (final bad in <Object?>[
        null,
        1,
        'text',
        true,
        [1, 2],
        <String, Object?>{},
        {'q': 1, 'page': 1, 'tags': <String>[]},
        {'q': '', 'page': '1', 'tags': <String>[]},
        {'q': '', 'page': 1.5, 'tags': <String>[]},
        {'q': '', 'page': 1, 'tags': 'a'},
        {
          'q': '',
          'page': 1,
          'tags': [1],
        },
        {
          'q': '',
          'page': 1,
          'tags': [null],
        },
        {
          '__proto__': {'page': 1},
          'q': '',
          'page': 1,
          'tags': <String>[],
        },
        {
          'q': List.filled(50, '').toString(),
          'page': 1 << 62,
          'tags': <String>[],
        },
      ]) {
        final wrong =
            bad is Map &&
            (bad['q'] is String) &&
            bad['page'] is int &&
            bad['tags'] is List &&
            (bad['tags'] as List).every((e) => e is String);
        if (wrong) {
          expect(() => s.orders.callWith(bad), returnsNormally, reason: '$bad');
        } else {
          expect(
            () => s.orders.callWith(bad),
            throwsArgumentError,
            reason: '$bad',
          );
        }
      }
    });

    test('a deep nest is a bad request, not a stack overflow', () {
      Object? deep = 'x';
      for (var i = 0; i < 100000; i++) {
        deep = [deep];
      }
      expect(
        () => _make().orders.callWith({'q': '', 'page': 1, 'tags': deep}),
        throwsA(anything),
      );
    });

    test('a record with a missing or mistyped field is a bad request', () {
      final s = _make();
      for (final bad in <Object?>[
        <String, Object?>{},
        {r'$1': 'a'},
        {r'$1': 1, r'$2': 1},
        {r'$1': 'a', r'$2': 'b'},
        {r'$1': 'a', r'$2': null},
      ]) {
        expect(
          () => s.byRecord.callWith(bad),
          throwsArgumentError,
          reason: '$bad',
        );
      }
    });
  });
}

// `events(url)`: the value an event brings (replace, keyed merge),
// the connection signal, the snapshot and the checks of the url.
import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

class Item {
  const Item(this.id, this.n);
  final String id;
  final int n;
}

ServerEventStream<List<Item>> _feed({String? key}) {
  final e = events<List<Item>>('/f', event: 'tick', key: key);
  e.members(
    'feed',
    item: (j) => Item((j! as Map)['id'] as String, (j as Map)['n'] as int),
    list: (xs) => <Item>[for (final x in xs) x as Item],
  );
  return e;
}

String _show(ServerEventStream<List<Item>> e) => [
  for (final i in e.data.peek() ?? const <Item>[]) '${i.id}${i.n}',
].join(' ');

void main() {
  test('without a key an event is the new value', () {
    final e = _feed();
    e.receive([
      {'id': 'a', 'n': 1},
    ]);
    expect(_show(e), 'a1');
    e.receive([
      {'id': 'b', 'n': 2},
    ]);
    expect(_show(e), 'b2');
  });

  test('with a key only the items that changed are new objects', () {
    final e = _feed(key: 'id');
    e.receive({
      'replace': [
        {'id': 'a', 'n': 1},
        {'id': 'b', 'n': 1},
        {'id': 'c', 'n': 1},
      ],
    });
    final before = e.data.peek()!;
    e.receive([
      {'id': 'b', 'n': 2},
      {'id': 'd', 'n': 1},
    ]);
    final after = e.data.peek()!;
    expect(_show(e), 'a1 b2 c1 d1');
    expect(identical(after[0], before[0]), isTrue);
    expect(identical(after[2], before[2]), isTrue);
    expect(identical(after[1], before[1]), isFalse);
    e.receive({
      'remove': ['a', 'zz'],
      'upsert': [
        {'id': 'c', 'n': 9},
      ],
    });
    expect(_show(e), 'b2 c9 d1');
    e.receive([
      {'id': 'a', 'n': 5},
    ]);
    expect(_show(e), 'b2 c9 d1 a5');
  });

  test('the page\'s value gives the keys to merge by', () {
    final e = _feed(key: 'id');
    e.data.restoreJson([
      {'id': 'a', 'n': 1},
      {'id': 'b', 'n': 1},
    ]);
    e.receive([
      {'id': 'b', 'n': 7},
    ]);
    expect(_show(e), 'a1 b7');
  });

  test('a shape it does not know throws and leaves the value', () {
    final e = _feed(key: 'id');
    e.receive([
      {'id': 'a', 'n': 1},
    ]);
    expect(() => e.receive('x'), throwsFormatException);
    expect(() => e.receive({'upsert': 3}), throwsFormatException);
    expect(_show(e), 'a1');
  });

  test('connection starts waiting; its snapshot follows it', () {
    final e = _feed();
    expect(e.connection.value, ConnectionState.waiting);
    expect(e.snapshot.connectionState, ConnectionState.waiting);
    e.receive([
      {'id': 'a', 'n': 1},
    ]);
    e.connection.value = ConnectionState.active;
    expect(e.snapshot.connectionState, ConnectionState.active);
    expect(e.snapshot.hasData, isTrue);
  });

  test('members: the query\'s and the connection', () {
    final names = [for (final m in _feed().members('feed')) m.name];
    expect(names, containsAll(['feed', 'feed\$data', 'feed\$connection']));
  });

  test('only a path of the app', () {
    for (final bad in ['https://x.com/s', '//x.com/s', 's', '/a b', r'/a\b']) {
      expect(() => events<String>(bad), throwsArgumentError, reason: bad);
    }
    expect(() => events<String>('/s', event: ''), throwsArgumentError);
    expect(events<String>('/s?x=1').url, '/s?x=1');
  });

  test('items without a key are appended, never replaced', () {
    final e = events<List<Object?>>('/f', key: 'id');
    e.receive([
      {'n': 1},
      {'n': 2},
      {'id': 'a', 'n': 3},
    ]);
    e.receive([
      {'n': 4},
      {'id': 'a', 'n': 5},
    ]);
    expect(e.data.peek()!.map((x) => (x! as Map)['n']), [1, 2, 5, 4]);
  });

  test('events without initial: a hand-made call is a precise error', () {
    final e = events<List<String>>('/f');
    expect(e.run(), throwsStateError);
  });

  test('without a key the {replace: …} envelope sets the value', () {
    final e = _feed();
    e.receive({
      'replace': [
        {'id': 'a', 'n': 1},
        {'id': 'b', 'n': 2},
      ],
    });
    expect(_show(e), 'a1 b2');
    e.receive([
      {'id': 'c', 'n': 3},
    ]);
    expect(_show(e), 'c3');
  });
}

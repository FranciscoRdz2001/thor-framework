import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

var _writes = 0;

Future<int> _add(String sku) async => ++_writes;
Future<void> _clear() async => _writes = 0;

class Edit {
  const Edit(this.row, this.text);
  factory Edit.fromJson(Map<String, Object?> json) =>
      Edit(json['row']! as String, json['text']! as String);
  final String row;
  final String text;
  Map<String, Object?> toJson() => {'row': row, 'text': text};
}

Future<String> _apply(Edit e) async => '${e.row}=${e.text}';

class ShopState extends ThorState {
  ShopState({super.key});

  final items = query(() async => _writes);
  final add = commandWith(_add);
  final clear = command(_clear);
  final discount = commandWith((double pct) async => pct);
  final edit = commandWith(_apply);
}

void main() {
  setUpAll(
    () => ThorState.register({
      ShopState: ThorStateType('ShopState', (state) {
        final s = state as ShopState;
        return [
          ...s.items.members('items'),
          ...s.add.members('add'),
          ...s.clear.members('clear'),
          ...s.discount.members('discount'),
          ...s.edit.members(
            'edit',
            argToJson: (a) => a.toJson(),
            argFromJson: Edit.fromJson,
          ),
        ];
      }),
    }),
  );

  setUp(() => _writes = 0);

  test('members: the command, its four signals and run', () {
    final s = ShopState();
    expect(
      [
        for (final m in s.members)
          if (m.name.startsWith('add')) m.name,
      ],
      [
        'add',
        r'add$pending',
        r'add$error',
        r'add$errorKind',
        r'add$result',
        r'add$run',
      ],
    );
    final command = s.members.firstWhere((m) => m.name == 'add');
    expect(command.command, same(s.add));
    expect(command.function, isNull);
    final pending = s.members.firstWhere((m) => m.name == r'add$pending');
    expect(pending.variants, [false, true]);
    expect(pending.signal, same(s.add.pending));
  });

  test('a button binds run: the tear-off resolves to its id', () {
    final s = ShopState(key: 'bound');
    final (state, member) = ThorState.resolve(s.add.run)!;
    expect(state, same(s));
    expect(member.name, r'add$run');
    expect(member.arity, 1);
    expect(ThorState.resolve(s.clear.run)!.$2.name, r'clear$run');
    expect(ThorState.resolve(s.clear.run)!.$2.arity, 0);
    // withArg keeps the tear-off it wraps.
    expect(BoundCall.of(s.add.run.withArg('taza'))!.function, s.add.run);
  });

  test('run never calls the server function outside the browser', () {
    final s = ShopState(key: 'run');
    s.add.run('taza');
    s.clear.run();
    final run = s.members.firstWhere((m) => m.name == r'add$run');
    run.call!('taza');
    expect(_writes, 0);
    expect(s.add.pending.value, isFalse);
  });

  test('find and of: by page id, commands only', () {
    final s = ShopState(key: 'find');
    expect(ServerCommandBase.find('ShopState#find.add'), same(s.add));
    expect(ServerCommandBase.find('ShopState#find.items'), isNull);
    expect(ServerCommandBase.find('ShopState#find.nope'), isNull);
    expect(ServerQuery.find('ShopState#find.add'), isNull);
    expect(ServerCommandBase.of([s]).keys, [
      'ShopState#find.add',
      'ShopState#find.clear',
      'ShopState#find.discount',
      'ShopState#find.edit',
    ]);
  });

  test('callWith checks the argument before anything runs', () async {
    final s = ShopState(key: 'args');
    for (final bad in [1, null, true, <String>[]]) {
      expect(() => s.add.callWith(bad), throwsArgumentError, reason: '$bad');
    }
    expect(_writes, 0);
    expect(await s.add.callWith('taza')(), 1);
    // A JSON int is a double where the command takes one.
    expect(await s.discount.callWith(10)(), 10.0);
    // No argument: whatever the body says is ignored.
    await s.clear.callWith('x')();
    expect(_writes, 0);
  });

  test('callWith decodes a class argument with its fromJson', () async {
    final s = ShopState(key: 'class');
    expect(s.members, isNotEmpty);
    expect(await s.edit.callWith({'row': 'a#1', 'text': 'hi'})(), 'a#1=hi');
    // A shape the builder's fromJson can't read is a bad request, before
    // anything runs.
    for (final bad in [
      'a#1',
      1,
      null,
      <String, Object?>{'row': 'a'},
      <String, Object?>{'row': 1, 'text': 'x'},
    ]) {
      expect(() => s.edit.callWith(bad), throwsArgumentError, reason: '$bad');
    }
  });
}

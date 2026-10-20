@TestOn('vm')
library;

// `row.text((o) => o.customer)`: a lambda that reads one String property
// of the row is bound like a method of the state; anything else says so.
import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart'
    show RowProbeLog, hasRowProbe, registerRowProbes;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

enum Tier { free, pro, team }

class Person {
  const Person(
    this.id,
    this.name,
    this.city, {
    this.vip = false,
    this.tier = Tier.free,
  });
  final int id;
  final String name;
  final String city;
  final bool vip;
  final Tier tier;
}

/// What thor generates for `Person` (by hand: tests don't run the build).
class _PersonProbe implements Person {
  _PersonProbe(this.log);
  final RowProbeLog log;

  @override
  String get name {
    log.read('name');
    return RowProbeLog.marker('name');
  }

  @override
  String get city {
    log.read('city');
    return RowProbeLog.marker('city');
  }

  @override
  bool get vip => log.choose('vip', const [false, true]) as bool;

  @override
  Tier get tier => log.choose('tier', Tier.values) as Tier;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    log.read('');
    return super.noSuchMethod(invocation);
  }
}

/// A row class nobody made a probe for.
class Unprobed {
  const Unprobed(this.title);
  final String title;
}

abstract class _RosterMembers extends ThorState {
  @override
  String get $type => 'RosterState';

  @override
  List<ThorMember> get $members {
    final s = this as RosterState;
    return [
      ThorMember.state('people', s.people),
      ThorMember.state('other', s.other),
      ThorMember(
        'idOf',
        s.idOf,
        arity: 1,
        callWithItem: (i) => s.idOf(i as Person),
      ),
      ThorMember(
        'nameOf',
        s.nameOf,
        arity: 1,
        callWithItem: (i) => s.nameOf(i as Person),
      ),
      ThorMember('setOn', s.setOn, arity: 1, call: (a) => s.setOn(a == 'true')),
      ThorMember(
        'titleKey',
        s.titleKey,
        arity: 1,
        callWithItem: (i) => s.titleKey(i as Unprobed),
      ),
    ];
  }
}

class RosterState extends _RosterMembers {
  final people = state<List<Person>>(const [
    Person(1, 'Ana', 'Lima', vip: true, tier: Tier.pro),
    Person(2, '<b>Luis</b>', 'Quito', tier: Tier.team),
  ]);
  final other = state<List<Unprobed>>(const [Unprobed('x')]);

  void setOn(bool? on) {}
  int idOf(Person p) => p.id;
  String nameOf(Person p) => p.name;
  String titleKey(Unprobed u) => u.title;
}

final roster = RosterState();

Future<String> people(Widget Function(WatchRow<Person, int> row) each) =>
    renderHtml(
      Watch.list(roster.people.call, itemKey: roster.idOf, each: each),
    );

void main() {
  initializeThorTests();
  setUpAll(() => registerRowProbes({Person: _PersonProbe.new}));

  group('a lambda that reads one property', () {
    test('binds the property and shows its value, escaped', () async {
      final html = await people((row) => row.text((o) => o.name));
      expect(html, contains(r'data-tf="$Rows.name"'));
      expect(html, contains('>Ana<'));
      expect(html, contains('&lt;b&gt;Luis&lt;/b&gt;'));
      expect(html, isNot(contains('<b>Luis')));
    });

    test('the template carries the binding and no value', () async {
      final html = await people((row) => row.text((o) => o.city));
      final template = html.substring(html.indexOf('<template'));
      expect(template, contains(r'data-tf="$Rows.city"'));
      expect(template, isNot(contains('Lima')));
    });

    test('a method of the state still works, next to a lambda', () async {
      final html = await people(
        (row) =>
            Row(children: [row.text(roster.nameOf), row.text((o) => o.city)]),
      );
      expect(html, contains('data-tf="RosterState.nameOf"'));
      expect(html, contains(r'data-tf="$Rows.city"'));
    });

    test('style and overflow still apply', () async {
      final html = await people(
        (row) => row.text(
          (o) => o.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
      expect(html, contains('text-overflow: ellipsis'));
    });
  });

  group('row.bind with a lambda', () {
    test('binds the property to the widget attribute, escaped', () async {
      final html = await people(
        (row) => Checkbox(
          value: false,
          semanticLabel: row.bind((o) => o.name),
          onChanged: roster.setOn,
        ),
      );
      expect(html, contains('aria-label="Ana"'));
      expect(html, contains('aria-label="&lt;b&gt;Luis&lt;/b&gt;"'));
      expect(html, contains(r'data-tfa="aria-label:$Rows.name"'));
      final template = html.substring(html.indexOf('<template'));
      expect(template, isNot(contains('Ana')));
      expect(template, contains(r'data-tfa="aria-label:$Rows.name"'));
    });

    test('a lambda that does more says how to fix it', () async {
      await expectLater(
        people(
          (row) => Checkbox(
            value: false,
            semanticLabel: row.bind((o) => o.name.toUpperCase()),
            onChanged: roster.setOn,
          ),
        ),
        throwsA(
          isA<Object>()
              .having((e) => '$e', 'message', contains('THOR-S033'))
              .having(
                (e) => '$e',
                'fix',
                contains('row.bind(state.customerOf)'),
              ),
        ),
      );
    });
  });

  group('a lambda that does more says how to fix it', () {
    for (final (label, build)
        in <(String, Widget Function(WatchRow<Person, int>))>[
          ('a method call', (r) => r.text((o) => o.name.toUpperCase())),
          ('an interpolation', (r) => r.text((o) => '${o.name}!')),
          ('two properties', (r) => r.text((o) => o.name + o.city)),
          ('a constant', (r) => r.text((o) => 'fixed')),
          ('a property that is not a String', (r) => r.text((o) => '${o.id}')),
          ('a ternary', (r) => r.text((o) => o.id > 1 ? o.name : o.city)),
        ]) {
      test(label, () async {
        await expectLater(
          people(build),
          throwsA(
            isA<Object>()
                .having((e) => '$e', 'message', contains('THOR-S033'))
                .having(
                  (e) => '$e',
                  'fix',
                  contains('row.text(state.customerOf)'),
                ),
          ),
        );
      });
    }
  });

  group('row.attribute and row.field with a lambda', () {
    test(
      'row.attribute binds the property, escaped, and the template has no value',
      () async {
        final html = await people(
          (row) => row.attribute(
            AttributeName.title,
            (o) => o.name,
            child: const Text('x'),
          ),
        );
        expect(html, contains('title="Ana"'));
        expect(html, contains('title="&lt;b&gt;Luis&lt;/b&gt;"'));
        expect(html, contains(r'data-tfa="title:$Rows.name"'));
        final template = html.substring(html.indexOf('<template'));
        expect(template, isNot(contains('Ana')));
        expect(template, contains(r'data-tfa="title:$Rows.name"'));
      },
    );

    test(
      'row.attribute still checks the attribute name and the URL value',
      () async {
        await expectLater(
          people(
            (row) => row.attribute(
              const AttributeName('onclick'),
              (o) => o.name,
              child: const Text('x'),
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
        final html = await people(
          (row) => row.attribute(
            AttributeName.href,
            (o) => o.name,
            child: const Text('x'),
          ),
        );
        // `Ana` is not an unsafe scheme: it stays; an unsafe one is dropped by
        // the same rule as a method's.
        expect(html, contains('href="Ana"'));
      },
    );

    test('row.field writes a hidden input bound to the property', () async {
      final html = await people((row) => row.field('who', (o) => o.name));
      expect(html, contains('name="who"'));
      expect(html, contains('value="Ana"'));
      expect(html, contains(r'data-tf="$Rows.name"'));
      final template = html.substring(html.indexOf('<template'));
      expect(template, contains(r'data-tf="$Rows.name"'));
      expect(template, isNot(contains('value="Ana"')));
    });

    test('a method of the state still works for both', () async {
      final html = await people(
        (row) => Column(
          children: [
            row.attribute(
              AttributeName.title,
              roster.nameOf,
              child: const Text('x'),
            ),
            row.field('who', roster.nameOf),
          ],
        ),
      );
      expect(html, contains('data-tfa="title:RosterState.nameOf"'));
      expect(html, contains('data-tf="RosterState.nameOf"'));
    });

    for (final (label, build, code)
        in <(String, Widget Function(WatchRow<Person, int>), String)>[
          (
            'attribute: a lambda that does more',
            (r) => r.attribute(
              AttributeName.title,
              (o) => o.name.toUpperCase(),
              child: const Text('x'),
            ),
            'row.attribute',
          ),
          (
            'attribute: a property that is not a String',
            (r) => r.attribute(
              AttributeName.title,
              (o) => o.id,
              child: const Text('x'),
            ),
            'row.attribute',
          ),
          (
            'field: a lambda that does more',
            (r) => r.field('who', (o) => '${o.name}!'),
            'row.field',
          ),
        ]) {
      test(label, () async {
        await expectLater(
          people(build),
          throwsA(
            isA<Object>()
                .having((e) => '$e', 'message', contains('THOR-S033'))
                .having((e) => '$e', 'names the call', contains(code))
                .having(
                  (e) => '$e',
                  'fix',
                  contains(
                    "$code(${code == 'row.attribute' ? 'AttributeName.title' : "'name'"}, "
                    'state.customerOf',
                  ),
                ),
          ),
        );
      });
    }
  });

  group('row.watch with a lambda', () {
    Widget chip(bool vip) => Text(vip ? 'VIP' : 'regular');

    test('a bool property picks the state of each row', () async {
      final html = await people(
        (row) => row.watch<bool>((o) => o.vip, builder: chip),
      );
      expect(html, contains(r'data-tvf="$Rows.vip"'));
      // Ana is vip (state 1), Luis is not (state 0).
      expect(RegExp(r'data-tvi="1"').allMatches(html), isNotEmpty);
      expect(html, contains('>VIP<'));
      expect(html, contains('>regular<'));
      final template = html.substring(html.indexOf('<template'));
      expect(template, contains(r'data-tvf="$Rows.vip"'));
    });

    test('an enum property has a state per value', () async {
      final html = await people(
        (row) => row.watch<Tier>(
          (o) => o.tier,
          builder: (t) => Text('plan ${t.name}'),
        ),
      );
      expect(html, contains(r'data-tvf="$Rows.tier"'));
      expect(html, contains('plan pro'));
      expect(html, contains('plan team'));
      final template = html.substring(html.indexOf('<template'));
      // The template carries the other states (free, pro, team).
      for (final t in ['free', 'pro', 'team']) {
        expect(template, contains('plan $t'), reason: t);
      }
    });

    for (final (label, build)
        in <(String, Widget Function(WatchRow<Person, int>))>[
          (
            'a comparison',
            (r) => r.watch<bool>((o) => o.id > 1, builder: (on) => Text('$on')),
          ),
          (
            'a negation',
            (r) => r.watch<bool>((o) => !o.vip, builder: (on) => Text('$on')),
          ),
          (
            'a constant',
            (r) => r.watch<bool>((o) => true, builder: (on) => Text('$on')),
          ),
          (
            'a String property',
            (r) => r.watch<String>((o) => o.name, builder: Text.new),
          ),
        ]) {
      test('$label says how to fix it', () async {
        await expectLater(
          people(build),
          throwsA(
            isA<Object>()
                .having((e) => '$e', 'message', contains('THOR-S033'))
                .having((e) => '$e', 'names the call', contains('row.watch'))
                .having((e) => '$e', 'fix', contains('method of the state')),
          ),
        );
      });
    }
  });

  test('a row class without a probe says to run through thor', () async {
    expect(hasRowProbe(Unprobed), isFalse);
    await expectLater(
      renderHtml(
        Watch.list(
          roster.other.call,
          itemKey: roster.titleKey,
          each: (row) => row.text((u) => u.title),
        ),
      ),
      throwsA(
        isA<Object>().having((e) => '$e', 'message', contains('THOR-S032')),
      ),
    );
  });
}

@TestOn('vm')
library;

// Adversarial: a row property with quotes, markup and unsafe URLs lands in
// attributes, fields and text escaped (the lambda form takes the same path as
// a method of the state).
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class Person {
  const Person(this.id, this.name, this.city);
  final int id;
  final String name;
  final String city;
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
  dynamic noSuchMethod(Invocation invocation) {
    log.read('');
    return super.noSuchMethod(invocation);
  }
}

abstract class _RosterMembers extends ThorState {
  @override
  String get $type => 'RosterState';

  @override
  List<ThorMember> get $members {
    final s = this as RosterState;
    return [
      ThorMember.state('people', s.people),
      ThorMember(
        'idOf',
        s.idOf,
        arity: 1,
        callWithItem: (i) => s.idOf(i as Person),
      ),
    ];
  }
}

const _hostile = '"><script>alert(1)</script> \' onmouseover=\'x';

class RosterState extends _RosterMembers {
  final people = state<List<Person>>(const [
    Person(1, _hostile, 'javascript:alert(1)'),
  ]);
  int idOf(Person p) => p.id;
}

final roster = RosterState();

Future<String> people(Widget Function(WatchRow<Person, int> row) each) =>
    renderHtml(
      Watch.list(roster.people.call, itemKey: roster.idOf, each: each),
    );

void main() {
  initializeThorTests();
  setUpAll(() => registerRowProbes({Person: _PersonProbe.new}));

  test('row.attribute escapes quotes and markup of the value', () async {
    final html = await people(
      (row) => row.attribute(
        AttributeName.title,
        (o) => o.name,
        child: const Text('x'),
      ),
    );
    final item = html.substring(0, html.indexOf('<template'));
    expect(item, isNot(contains('<script>')));
    expect(item, isNot(contains('title=""><')));
    expect(item, contains('title="&quot;&gt;&lt;script&gt;'));
    // The single quotes sit inside a double-quoted value: they can not end it.
    expect(
      RegExp(r'title="[^"]*"').firstMatch(item)![0],
      contains('onmouseover'),
    );
  });

  test('row.field escapes the value of the hidden input', () async {
    final html = await people((row) => row.field('who', (o) => o.name));
    final item = html.substring(0, html.indexOf('<template'));
    expect(item, isNot(contains('<script>')));
    expect(item, contains('value="&quot;&gt;&lt;script&gt;'));
  });

  test('row.text and row.bind escape too', () async {
    final text = await people((row) => row.text((o) => o.name));
    expect(
      text.substring(0, text.indexOf('<template')),
      isNot(contains('<script>')),
    );
    final bound = await people(
      (row) => Checkbox(
        value: false,
        semanticLabel: row.bind((o) => o.name),
        onChanged: (_) {},
      ),
    );
    expect(
      bound.substring(0, bound.indexOf('<template')),
      isNot(contains('<script>')),
    );
  });

  test('a javascript: value of href is dropped, as for a method', () async {
    final html = await people(
      (row) => row.attribute(
        AttributeName.href,
        (o) => o.city,
        child: const Text('x'),
      ),
    );
    expect(
      html.substring(0, html.indexOf('<template')),
      isNot(contains('javascript:')),
    );
  });

  test('an attribute name with a quote or a space is refused', () async {
    for (final name in ['a" onmouseover="x', 'a b', 'on click', 'srcdoc']) {
      await expectLater(
        people(
          (row) => row.attribute(
            AttributeName(name),
            (o) => o.name,
            child: const Text('x'),
          ),
        ),
        throwsA(isA<ArgumentError>()),
        reason: name,
      );
    }
  });
}

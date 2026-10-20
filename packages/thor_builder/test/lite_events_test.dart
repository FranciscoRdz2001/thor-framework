import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_builder/src/app_entries.dart' show engineFeatures;
import 'package:thor_lints/lite.dart';

/// Resolves `lib/s.dart` and translates it.
Future<String> _translate(
  String source, {
  bool shortNames = false,
  Map<String, String> parts = const {},
}) async {
  final units = await resolveSources(
    {
      'app|lib/s.dart': source,
      for (final p in parts.entries) 'app|lib/${p.key}': p.value,
    },
    (resolver) async {
      final lib = await resolver.libraryFor(AssetId.parse('app|lib/s.dart'));
      final result =
          await lib.session.getResolvedLibraryByElement(lib)
              as ResolvedLibraryResult;
      return [
        for (final u in result.units)
          LiteUnit('lib/${u.path.split('/').last}', u.unit),
      ];
    },
    rootPackage: 'app',
    readAllSourcesFromFilesystem: true,
  );
  return translateLiteStates(units, shortNames: shortNames);
}

Future<LiteTranslationException> _fails(String source) async {
  try {
    await _translate(source);
  } on LiteTranslationException catch (e) {
    return e;
  }
  fail('expected lite errors');
}

String _state(String field, {String extra = ''}) =>
    """
import 'package:thor_ui/thor_ui.dart';

class Q {
  const Q(this.id);
  factory Q.fromJson(Map<String, Object?> j) => Q(j['id']! as String);
  final String id;
  Map<String, Object?> toJson() => {'id': id};
}

class S extends ThorState {
  $field
  $extra
}
""";

void main() {
  _stateModels();
  test(
    'events() becomes the events part, opened and closed with the state',
    () async {
      final js = await _translate(
        _state(
          "final feed = events<List<Q>>('/q/stream', event: 'tick', "
          "initial: () => <Q>[], key: 'id');",
          extra: 'String c() => feed.connection.value.name;',
        ),
      );
      expect(js, contains('thor-lite parts: events'));
      expect(js, contains("u: '/q/stream', e: 'tick', k: 'id'"));
      expect(js, contains('i: 1'));
      expect(js, contains('feed.start()'));
      expect(js, contains('feed.stop()'));
      expect(js, contains("'feed\$connection'"));
      expect(js, contains('named: true'));
    },
  );

  test('without initial the page waits for the first event', () async {
    final js = await _translate(_state("final feed = events<String>('/s');"));
    expect(js, contains('i: 0'));
    expect(js, contains("e: 'message'"));
  });

  test('enhanced enums keep their base class and no events part ships '
      'without events()', () async {
    final js = await _translate('''
import 'package:thor_ui/thor_ui.dart';

enum Tone {
  warm(1),
  cold(2);

  const Tone(this.level);
  final int level;
}

class S extends ThorState {
  final tone = state(Tone.warm);
  int level() => tone.value.level;
}
''');
    expect(js, contains('extends \$E'));
    expect(js, isNot(contains('thor.events')));
    expect(js, isNot(contains('thor-lite parts: events')));
    expect(js, isNot(contains(' events')));
  });

  test('the engine feature is for events() fields, not any method', () {
    final uses = engineFeatures['EventsFeature']!;
    const state = 'class S extends ThorState {\n';
    expect(uses("${state}final feed = events<List<int>>('/s');}"), isTrue);
    expect(uses("${state}late final f = events('/s');}"), isTrue);
    expect(uses("${state}void x() => bus.events('/s');}"), isFalse);
    expect(uses('${state}List<int> events() => [];}'), isFalse);
    expect(uses('class Bus { final x = events(); }'), isFalse);
  });

  group('THOR-B012 for what the browser cannot know', () {
    Future<void> rejects(String field, Matcher message) async {
      final e = await _fails(_state(field));
      expect(e.errors.map((x) => x.message).join('\n'), message);
    }

    test('another origin', () async {
      await rejects(
        "final f = events<String>('https://x.com/s');",
        contains('never another origin'),
      );
      await rejects(
        "final f = events<String>('//x.com/s');",
        contains('never another origin'),
      );
      await rejects(
        "final f = events<String>('s');",
        contains('never another origin'),
      );
    });

    test('a url, event or key that is not a literal', () async {
      await rejects(
        "static const u = '/s';\n  final f = events<String>(u);",
        anyOf(contains('Static fields'), contains('string literal')),
      );
      await rejects(
        "final f = events<String>('/s', event: 'a' + 'b');",
        contains('`event:` as a string literal'),
      );
      await rejects(
        "final f = events<List<Q>>('/s', key: 'i' 'd'.toString());",
        contains('`key:` as a string literal'),
      );
    });

    test('a key or event that could break the JS points at itself', () async {
      for (final key in [r"a\'b", r'a\nb', 'a b', '1a', '']) {
        final e = await _fails(
          _state("final f = events<List<Q>>('/s', key: '$key');"),
        );
        expect(e.errors.single.message, contains('`key:` is the name'));
        expect(e.errors.single.toString(), contains("key: '"));
      }
      final e = await _fails(
        _state("final f = events<String>('/s', event: '');"),
      );
      expect(e.errors.single.message, contains('not an event name'));
    });

    test('an option it does not have', () async {
      await rejects(
        "final f = events<String>('/s', retry: 1);",
        contains('no `retry:`'),
      );
    });

    test('a key on something that is not a list', () async {
      await rejects(
        "final f = events<String>('/s', key: 'id');",
        contains('`key:` merges the items of a list'),
      );
    });

    test('not in a final field, or a member the lite subset lacks', () async {
      await rejects(
        "var f = events<String>('/s');",
        contains('an event stream is made in a `final` field'),
      );
      final e = await _fails(
        _state(
          "final f = events<String>('/s');",
          extra: 'void x() => f.setArg(1);',
        ),
      );
      expect(e.errors.single.message, contains('ServerEventStream.setArg'));
    });
  });
}

// A `state(...)` that holds the app's own class (or a list or map of them)
// is read back with its `fromJson`, with no `decode:`: the same as a
// query's result.
void _stateModels() {
  test('state<List<Q>> decodes with Q.fromJson, no decode: needed', () async {
    final js = await _translate(_state('final rows = state<List<Q>>(<Q>[]);'));
    expect(js, contains(r'$.state('));
    expect(js, contains('(j) => j.map((x) => Q.fromJson(x))'));
    expect(js, contains('toJson'));
  });

  test('state<Q?> and state<Map<String, Q>> too; encode/decode win', () async {
    final one = await _translate(_state('final q = state<Q?>(null);'));
    expect(one, contains('(j) => j == null ? null : Q.fromJson(j)'));
    final map = await _translate(
      _state('final m = state<Map<String, Q>>(<String, Q>{});'),
    );
    expect(
      map,
      contains('new Map([...j].map(([k, x]) => [k, Q.fromJson(x)]))'),
    );
    final own = await _translate(
      _state(
        'final rows = state<List<Q>>(<Q>[], '
        'encode: (l) => [for (final q in l) q.id], '
        'decode: (j) => [for (final i in j! as List) Q(i as String)]);',
      ),
    );
    expect(own, isNot(contains('Q.fromJson(x)')));
  });
}

// One lite engine per page of a static site: the states and parts a page
// needs (lib/src/lite_site.dart).
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/lite.dart';

// What thor_builder writes: a header, then items each after a mark.
const _state = r'''
// GENERATED CODE - DO NOT MODIFY BY HAND (thor_builder, bin/lite_state.dart).
// The app's ThorState classes for the thor-lite runtime.
// thor-lite parts: controllers datetime json lifecycle text_controller
// thor-lite helper-parts: $DT=datetime $json=json
{
  // @item
  const $DT = thor.DT;
  // @item
  const $json = thor.json;
  // @item
  class Point { constructor(x) { this.x = x; } }
  // @item
  const shared = (a) => new Point(a);
  // @item
  const dateOnly = (d) => new $DT(d);
  // @item
  thor.def('CounterState', ($) => {
    const n = $.state('n', 0);
    return { inc: () => { n.value++; }, $s: { n } };
  });
  // @item
  thor.def('PointsState', ($) => {
    const p = $.state('p', shared(1));
    return { $s: { p } };
  });
  // @item
  thor.def('DatesState', ($) => {
    const d = $.state('d', dateOnly(1));
    return { $s: { d } };
  });
  // @item
  thor.def('FormState', ($) => {
    const t = $.p.text();
    return { $s: {} };
  });
  // @parts text_controller
  // @item
  thor.def('ClockState', ($) => {
    return { $l: { h: () => {} } };
  }, { idle: true });
  // @parts lifecycle
  // @item
  thor.def('TickerState', ($) => {
    const c = $.use('CounterState');
    return { $s: {} };
  }, { idle: true, named: true, uses: ['CounterState'] });
}
''';

// An enum with members is a class and its `$values` array in one item.
const _enumState = r'''
// GENERATED CODE - DO NOT MODIFY BY HAND (thor_builder, bin/lite_state.dart).
{
  // @item
  class u extends $E { get code() { return 'x'; } }
  const u$values = Object.freeze([new u('Curve', 0, 'a')]);
  // @item
  thor.def('CurveState', ($) => {
    const c = $.state('c', u$values[0]);
    return { $s: { c } };
  });
  // @item
  thor.def('OtherState', ($) => ({ $s: {} }));
}
''';

String _page(String names) => '<div data-tt="$names">';

void main() {
  group('pruneLiteStates', () {
    test('keeps the `\$values` of an enum with members a state reaches', () {
      final js = pruneLiteStates(_enumState, _page('CurveState.c~0'));
      expect(js, contains('class u'));
      expect(js, contains(r'const u$values'));
      expect(js, isNot(contains('OtherState')));
    });

    test('keeps the states the page names and what they use', () {
      final kept = <String>{};
      final js = pruneLiteStates(
        _state,
        _page('PointsState.p~0'),
        keptStates: kept,
      );
      expect(js, contains("thor.def('PointsState'"));
      expect(js, contains('const shared'));
      expect(js, contains('class Point'));
      expect(js, isNot(contains("thor.def('CounterState'")));
      expect(js, isNot(contains("thor.def('DatesState'")));
      expect(js, isNot(contains(r'const $DT')));
      expect(js, isNot(contains('dateOnly')));
      // A global state (idle, not named) wakes on every page.
      expect(js, contains("thor.def('ClockState'"));
      expect(kept, {'PointsState', 'ClockState'});
    });

    test('the parts follow what was kept', () {
      String partsOf(String page) =>
          RegExp(
            r'^// thor-lite parts: (.*)$',
            multiLine: true,
          ).firstMatch(pruneLiteStates(_state, page))?.group(1) ??
          '';
      // The clock (always) brings lifecycle; a state of its own, its part.
      expect(partsOf(_page('PointsState.p')), 'lifecycle');
      expect(partsOf(_page('DatesState.d')), 'datetime lifecycle');
      expect(partsOf(_page('FormState.x')), 'lifecycle text_controller');
    });

    test('a state with a local field is on every page, with its part', () {
      const js = r'''
// GENERATED CODE - DO NOT MODIFY BY HAND (thor_builder, bin/lite_state.dart).
// thor-lite parts: json local_storage
// thor-lite helper-parts: $local=local_storage,json
{
  // @item
  const $local = thor.local;
  // @item
  thor.def('DraftState', ($) => {
    const t = $local($.state('t', ''), 'draft', null, (x) => typeof x === 'string', null);
    return { $s: { t } };
  }, { eager: $local.has('DraftState', 'draft') });
  // @item
  thor.def('OtherState', ($) => ({ $s: {} }));
}
''';
      final kept = <String>{};
      final out = pruneLiteStates(js, _page('X.y'), keptStates: kept);
      // Its stored value may change the page, and another tab may store
      // one: it starts on any page.
      expect(kept, {'DraftState'});
      expect(out, contains(r'const $local = thor.local;'));
      expect(out, contains('// thor-lite parts: json local_storage'));
    });

    test('a state another uses by name comes with it', () {
      final kept = <String>{};
      pruneLiteStates(_state, _page('TickerState.t'), keptStates: kept);
      expect(kept, containsAll(['TickerState', 'CounterState']));
    });

    test('a page that names every state keeps them all', () {
      final kept = <String>{};
      pruneLiteStates(
        _state,
        _page(
          'CounterState PointsState DatesState FormState ClockState '
          'TickerState',
        ),
        keptStates: kept,
      );
      expect(kept, hasLength(6));
    });

    test('a file without marks is left alone', () {
      const old = '// thor-lite parts: json\n{\n  const a = 1;\n}\n';
      expect(pruneLiteStates(old, ''), old);
    });

    test('its states are not named by a longer name', () {
      final kept = <String>{};
      pruneLiteStates(_state, _page('MyCounterStateX.t'), keptStates: kept);
      expect(kept, isNot(contains('CounterState')));
    });
  });

  group('groupLiteBundles', () {
    // A bundle costs 8000 plus 1000 per part and 3000 per state.
    int cost(Set<String> states, Set<String> parts) =>
        8000 + 1000 * parts.length + 3000 * states.length;
    ({Set<String> states, Set<String> parts}) need(
      Iterable<String> states,
      Iterable<String> parts,
    ) => (states: states.toSet(), parts: parts.toSet());

    test('pages that differ by a little share one bundle', () {
      final groups = groupLiteBundles([
        need(['A'], ['x']),
        need(['A'], ['x', 'y']),
        need(['A'], ['y']),
      ], cost);
      expect(groups, [
        [0, 1, 2],
      ]);
    });

    test('pages that differ by a lot keep their own', () {
      final groups = groupLiteBundles([
        need(['A'], ['x']),
        need(['B', 'C'], ['x', 'y', 'z']),
        need(['A'], ['x', 'y']),
      ], cost);
      expect(groups, [
        [0, 2],
        [1],
      ]);
    });

    test('no page pays more than the bound over its own bundle', () {
      // Each step adds 1000: a chain would reach 4000 over the first.
      final needs = [
        for (var i = 0; i < 5; i++)
          need(['A'], ['p0', for (var j = 1; j <= i; j++) 'p$j']),
      ];
      final groups = groupLiteBundles(needs, cost, mergeBytes: 2000);
      for (final g in groups) {
        final alone = [
          for (final i in g) cost(needs[i].states, needs[i].parts),
        ];
        final union = {for (final i in g) ...needs[i].parts};
        expect(
          cost({'A'}, union) - alone.reduce((a, b) => a < b ? a : b),
          lessThan(2000),
        );
      }
      expect(groups.length, greaterThan(1));
    });

    test('a bound of zero merges nothing', () {
      final groups = groupLiteBundles(
        [
          need(['A'], ['x']),
          need(['A'], ['x', 'y']),
        ],
        cost,
        mergeBytes: 0,
      );
      expect(groups, [
        [0],
        [1],
      ]);
    });
  });

  test('pointPageAt rewrites the engine URL attributes, not prose', () {
    const page =
        '<link rel="preload" as="script" href="/engine.dart.js">'
        '<script data-thor-engine="/engine.dart.js">x</script>'
        '<p>edit engine.dart.js by hand</p>';
    final next = pointPageAt(page, 'engine.dart.0badc0de.js');
    expect(next, contains('href="/engine.dart.0badc0de.js"'));
    expect(next, contains('data-thor-engine="/engine.dart.0badc0de.js"'));
    expect(next, contains('<p>edit engine.dart.js by hand</p>'));
  });

  group('writeLiteSiteBundles', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('lite_site'));
    tearDown(() => dir.deleteSync(recursive: true));

    String loader(String body) =>
        '<html><body>$body'
        '<script data-thor-engine="/engine.dart.js"></script></body></html>';

    test('each page loads its own file, with its states only', () async {
      final site = Directory('${dir.path}/site')..createSync();
      File('${site.path}/engine.dart.js').writeAsStringSync('old');
      File(
        '${site.path}/index.html',
      ).writeAsStringSync(loader('<span data-tt="CounterState.n"></span>'));
      File(
        '${site.path}/dates.html',
      ).writeAsStringSync(loader('<span data-tt="DatesState.d"></span>'));
      File('${site.path}/plain.html').writeAsStringSync('<p>no engine</p>');
      File('${dir.path}/state.js').writeAsStringSync(_state);
      final out = await writeLiteSiteBundles(
        statePath: '${dir.path}/state.js',
        appDir: dir.path,
        outPath: '${site.path}/engine.dart.js',
        siteDir: site.path,
        mergeBytes: 0,
      );
      expect(out, contains('index.html'));
      final names = {
        for (final page in ['index', 'dates'])
          page: RegExp(
            r'data-thor-engine="/(engine\.dart\.[0-9a-f]{8}\.js)"',
          ).firstMatch(File('${site.path}/$page.html').readAsStringSync())![1]!,
      };
      expect(names.values.toSet(), hasLength(2));
      expect(File('${site.path}/engine.dart.js').existsSync(), isFalse);
      expect(
        File('${site.path}/plain.html').readAsStringSync(),
        '<p>no engine</p>',
      );
      final index = File('${site.path}/${names['index']}').readAsStringSync();
      final dates = File('${site.path}/${names['dates']}').readAsStringSync();
      expect(index, contains('CounterState'));
      expect(index, isNot(contains('DatesState')));
      expect(dates, contains('DatesState'));
      expect(dates, isNot(contains('CounterState')));
      // The page with the dates ships their part, the other does not.
      expect(dates.length, greaterThan(index.length));
      // A second run changes nothing and leaves no stale file.
      File('${site.path}/engine.dart.deadbeef.js').writeAsStringSync('stale');
      await writeLiteSiteBundles(
        statePath: '${dir.path}/state.js',
        appDir: dir.path,
        outPath: '${site.path}/engine.dart.js',
        siteDir: site.path,
        mergeBytes: 0,
      );
      expect(
        File('${site.path}/engine.dart.deadbeef.js').existsSync(),
        isFalse,
      );
      expect(File('${site.path}/${names['index']}').existsSync(), isTrue);
    });
  });
}

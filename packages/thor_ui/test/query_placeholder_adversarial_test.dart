@TestOn('vm')
library;

// ignore_for_file: thor_lints/query_builder_reads_data
// The builders here read the data on purpose: that is what is tested.

// Adversarial checks of the placeholder snapshot (#17): what a builder that
// the server calls with `hasData` and no data does to the page, and what it
// tells the developer.
import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart' show ThorDev;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class PhState extends ThorState {
  PhState({super.key});

  final items = query(() async => <String>['a', 'b']);
  final count = query(() async => 3);
  final maybe = query<List<String>?>(() async => null);
  final inner = query(() async => <String>['z']);

  List<String> rows() => items.data.value ?? const <String>[];
  String rowKey(String s) => s;
  String rowText(String s) => s;
}

void main() {
  initializeThorTests();
  setUpAll(
    () => ThorState.register({
      PhState: ThorStateType('PhState', (state) {
        final s = state as PhState;
        return [
          ...s.items.members('items'),
          ...s.count.members('count'),
          ...s.maybe.members('maybe'),
          ...s.inner.members('inner'),
          ThorMember('rows', s.rows, call: (_) => s.rows()),
          ThorMember(
            'rowKey',
            s.rowKey,
            callWithItem: (i) => s.rowKey(i! as String),
          ),
          ThorMember(
            'rowText',
            s.rowText,
            callWithItem: (i) => s.rowText(i! as String),
          ),
        ];
      }),
    }),
  );

  bool has(String html, int p) => html.contains('data-tp-$p');

  test('a state left out because its builder reads the data says why in '
      'dev, with the error and the app frame', () async {
    final lines = <String>[];
    final oldSink = ThorDev.errorSink;
    final oldEnabled = ThorDev.enabled;
    ThorDev.errorSink = lines.add;
    ThorDev.enabled = true;
    addTearDown(() {
      ThorDev.errorSink = oldSink;
      ThorDev.enabled = oldEnabled;
    });
    final s = PhState(key: 'dev');
    final html = await renderHtml(
      QueryBuilder<List<String>>(
        query: s.items,
        builder: (context, snap) =>
            Text(snap.hasData ? snap.data!.join() : 'waiting'),
      ),
    );
    expect(has(html, 2), isFalse);
    expect(lines, hasLength(greaterThanOrEqualTo(1)));
    expect(lines.join('\n'), contains('THOR-S037'));
    expect(lines.join('\n'), contains('StateError'));
    expect(lines.join('\n'), contains('query_placeholder_adversarial_test'));
  });

  test('outside dev nothing is written', () async {
    final lines = <String>[];
    final oldSink = ThorDev.errorSink;
    ThorDev.errorSink = lines.add;
    addTearDown(() => ThorDev.errorSink = oldSink);
    final s = PhState(key: 'nodev');
    await renderHtml(
      QueryBuilder<List<String>>(
        query: s.items,
        builder: (context, snap) =>
            Text(snap.hasData ? snap.data!.join() : 'waiting'),
      ),
    );
    expect(lines, isEmpty);
  });

  test('requireData of a nullable type does not hand back the null: the '
      'state is left out', () async {
    final s = PhState(key: 'nul');
    final html = await renderHtml(
      QueryBuilder<List<String>?>(
        query: s.maybe,
        builder: (context, snap) =>
            Text(snap.hasData ? (snap.requireData ?? const ['?']).join() : 'w'),
      ),
    );
    expect(has(html, 2), isFalse);
  });

  test('a null-tolerant read of the data (`data ?? []`) is left out, never '
      'shipped as the empty state', () async {
    final s = PhState(key: 'tol');
    final html = await renderHtml(
      QueryBuilder<List<String>>(
        query: s.items,
        builder: (context, snap) => snap.hasData
            ? Text((snap.data ?? const <String>[]).isEmpty ? 'empty' : 'rows')
            : const Text('w'),
      ),
    );
    expect(has(html, 2), isFalse);
    expect(html, isNot(contains('empty')));
  });

  test('a non-nullable T: data! on the placeholder is left out, hasData '
      'alone ships', () async {
    final s = PhState(key: 'int');
    final bad = await renderHtml(
      QueryBuilder<int>(
        query: s.count,
        builder: (context, snap) =>
            Text(snap.hasData ? '${snap.data! + 1}' : 'w'),
      ),
    );
    expect(has(bad, 2), isFalse);
    final good = await renderHtml(
      QueryBuilder<int>(
        query: s.count,
        builder: (context, snap) => Text(snap.hasData ? 'n' : 'w'),
      ),
    );
    expect(has(good, 2), isTrue);
  });

  test(
    'a QueryBuilder in a state of another: each marks an element of its own',
    () async {
      final s = PhState(key: 'nest');
      await s.items.prefetch((e) => ('x', ServerErrorKind.server));
      await s.inner.prefetch((e) => ('x', ServerErrorKind.server));
      final html = await renderHtml(
        QueryBuilder<List<String>>(
          query: s.items,
          builder: (context, snap) => snap.hasData
              ? QueryBuilder<List<String>>(
                  query: s.inner,
                  builder: (context, i) =>
                      Text(i.hasData ? 'inner ready' : 'inner wait'),
                )
              : const Text('outer wait'),
        ),
      );
      // Each QueryBuilder marks an element of its own (the outer one's state
      // holds the inner one, so it needs its box).
      for (final id in ['items', 'inner']) {
        expect(
          RegExp(
            '<[a-z]+ [^>]*data-tv="PhState#nest.$id\\\$phase"',
          ).allMatches(html).length,
          1,
          reason: id,
        );
      }
    },
  );

  test('a Watch.list in the done state of a placeholder: the template ships, '
      'no rows', () async {
    final s = PhState(key: 'list');
    final html = await renderHtml(
      QueryBuilder<List<String>>(
        query: s.items,
        builder: (context, snap) => snap.hasData
            ? Watch.list(
                s.rows,
                itemKey: s.rowKey,
                each: (row) => row.text(s.rowText),
              )
            : const Text('wait'),
      ),
    );
    expect(html, contains('data-tvt="PhState#list.items\$phase" data-i="2"'));
    expect(html, contains('data-tlt'));
  });

  test('a builder with a side effect runs once per state, not per request '
      'only (documented: it runs for each state)', () async {
    final s = PhState(key: 'fx');
    var calls = 0;
    await renderHtml(
      QueryBuilder<List<String>>(
        query: s.items,
        builder: (context, snap) {
          calls++;
          return Text(snap.hasData ? 'r' : 'w');
        },
      ),
    );
    // live + 4 other states, plus the layout hints that ask for the state.
    expect(calls, lessThan(12));
  });
}

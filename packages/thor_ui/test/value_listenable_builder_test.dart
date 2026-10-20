@TestOn('vm')
library;

// `ValueListenableBuilder` on a ThorState field is a `Watch`: every value
// is rendered by the server, the browser shows the one that matches.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

enum Mood { calm, busy }

abstract class _Members extends ThorState {
  @override
  String get $type => 'Toggle';

  @override
  List<ThorMember> get $members {
    final s = this as Toggle;
    return [
      ThorMember.state('open', s.open, variants: const [false, true]),
      ThorMember.state('mood', s.mood, variants: Mood.values),
      ThorMember.state('count', s.count),
      ThorMember.state('name', s.name),
      ThorMember('flip', s.flip, call: (_) => s.flip()),
    ];
  }
}

class Toggle extends _Members {
  final open = state(false);
  final mood = state(Mood.calm);
  final count = state(3);
  final name = state('Ana');
  void flip() => open.value = !open.value;
}

final toggle = Toggle();

void main() {
  initializeThorTests();

  test('a bool field is a finite state: same markup as Watch', () async {
    final vlb = await renderHtml(
      ValueListenableBuilder<bool>(
        valueListenable: toggle.open,
        builder: (context, open, child) =>
            Text(open ? 'panel open' : 'panel closed'),
      ),
    );
    final watch = await renderHtml(
      Watch(
        toggle.open.call,
        builder: (open) => Text(open ? 'panel open' : 'panel closed'),
      ),
    );
    expect(vlb, watch);
    expect(vlb, contains('data-tv="Toggle.open"'));
    expect(vlb, contains('panel closed'));
    expect(vlb, contains('panel open')); // the other value, precompiled
  });

  test('an enum field: one state per value', () async {
    final html = await renderHtml(
      ValueListenableBuilder<Mood>(
        valueListenable: toggle.mood,
        builder: (context, mood, child) => Text(mood.name),
      ),
    );
    expect(html, contains('data-tv="Toggle.mood"'));
    expect(html, contains('calm'));
    expect(html, contains('busy'));
  });

  test('child is handed to the builder untouched', () async {
    final html = await renderHtml(
      ValueListenableBuilder<bool>(
        valueListenable: toggle.open,
        child: const Text('fijo'),
        builder: (context, open, child) =>
            Column(children: [Text(open ? 'yes' : 'no'), child!]),
      ),
    );
    expect(RegExp('fijo').allMatches(html).length, greaterThanOrEqualTo(1));
    expect(html, contains('data-tv="Toggle.open"'));
  });

  test('a plain ValueNotifier is drawn once, with its value (Flutter code '
      'still renders; nothing reacts)', () async {
    final notifier = ValueNotifier(7);
    final html = await renderHtml(
      ValueListenableBuilder<int>(
        valueListenable: notifier,
        builder: (context, n, child) => Text('n=$n'),
      ),
    );
    expect(html, contains('n=7'));
    expect(html, isNot(contains('data-tv')));
  });

  test('an int or a String field cannot be rebuilt in the browser: the error '
      'says what to write', () async {
    Future<Object> failure(Widget w) async {
      try {
        await renderHtml(w);
      } on ArgumentError catch (e) {
        return e.message as Object;
      }
      fail('expected an ArgumentError');
    }

    final intError = await failure(
      ValueListenableBuilder<int>(
        valueListenable: toggle.count,
        builder: (context, n, child) => Text('$n'),
      ),
    );
    expect(intError, contains('THOR-S013'));
    expect(intError, contains('.count.call, count:'));
    final string = await failure(
      ValueListenableBuilder<String>(
        valueListenable: toggle.name,
        builder: (context, s, child) => Text(s),
      ),
    );
    expect(string, contains('THOR-S013'));
    expect(string, contains('Watch(state.name)'));
  });

  test(
    'a StateSignal that is not a field of a ThorState is an error',
    () async {
      final loose = state(true);
      try {
        await renderHtml(
          ValueListenableBuilder<bool>(
            valueListenable: loose,
            builder: (context, v, child) => Text('$v'),
          ),
        );
        fail('expected an error');
      } on ArgumentError catch (e) {
        expect('${e.message}', contains('THOR-S013'));
        expect('${e.message}', contains('top-level'));
      }
    },
  );
}

@TestOn('browser')
library;

// `derived(...)` in the dart2js engine: the engine's computed signal. Three
// readers (what three Watches are: effects over the same source) share one
// computation per change of its dependency, and none while nothing changes.
import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';

var computes = 0;

abstract class _Members extends ThorState {
  _Members();

  @override
  String get $type => 'Quakes';

  @override
  List<ThorMember> get $members {
    final s = this as _Quakes;
    return [
      ThorMember.state('rows', s.rows),
      ThorMember.state('min', s.min),
      ThorMember('visible', s.visible.call, call: (_) => s.visible.value),
    ];
  }
}

class _Quakes extends _Members {
  final rows = state(<int>[3, 1, 2]);
  final min = state(0);
  late final visible = derived(() {
    computes++;
    return [...rows.value.where((r) => r >= min.value)]..sort();
  });
}

void main() {
  test('a derived read by three watches computes once per change', () {
    computes = 0;
    final quakes = _Quakes();
    final seen = <String>[];
    for (var i = 0; i < 3; i++) {
      effect(() => seen.add('$i:${quakes.visible.value.join(',')}'));
    }
    // the page's Watch finds it by its tear-off, like a method
    expect(quakes.memberOf(quakes.visible.call)?.name, 'visible');
    expect(computes, 1);

    quakes.min.value = 2;
    expect(computes, 2);
    quakes.rows.value = [...quakes.rows.value, 5];
    expect(computes, 3);
    expect(seen.last, '2:2,3,5');

    // nothing changes: nothing computes
    for (var i = 0; i < 10; i++) {
      quakes.visible.value;
    }
    quakes.min.value = 2;
    expect(computes, 3);
  });
}

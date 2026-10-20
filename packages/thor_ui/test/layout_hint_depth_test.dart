@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/src/foundation/element.dart' show thorElement;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

/// A leaf that counts how often its layout hint is asked.
class _Probe extends StatelessWidget implements ThorElementWidget, LayoutHint {
  const _Probe(this.asked);

  final List<int> asked;

  @override
  bool get fillsWidth {
    asked[0]++;
    return false;
  }

  @override
  Widget build(BuildContext context) => thorElement('span', children: const []);
}

void main() {
  setUpAll(initializeThorTests);

  // Every Container asks its child whether it fills the width, which asks
  // its own child…: without a memo a chain of d boxes asks the leaf O(d²)
  // times (a 2000-deep page took 63 ms, 4× the 1000-deep one).
  test(
    'a deep chain asks each layout hint a bounded number of times',
    () async {
      final asked = [0];
      Widget child = _Probe(asked);
      for (var i = 0; i < 300; i++) {
        child = Container(padding: EdgeInsets.all(i % 3 + 1.0), child: child);
      }
      await renderHtml(child);
      expect(asked[0], lessThan(10));
    },
  );

  // A `Watch`'s hint follows its request's state: a widget shared between
  // renders is asked again in each one.
  test('the remembered hints last one render', () async {
    final asked = [0];
    final shared = Container(child: _Probe(asked));
    await renderHtml(shared);
    await renderHtml(shared);
    expect(asked[0], 2);
  });
}

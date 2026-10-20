@TestOn('vm')
library;

// `SplitPane`: the server draws the panes and the divider (the first size is
// CSS, so the page works with no JS); the lite engine's `split_pane` part
// moves the divider. The part is run in node over the server's own markup,
// with a layout stand-in that follows the CSS (`clamp()` on `--tsp`).
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/lite.dart' show litePartsFor;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

abstract class _LayoutMembers extends ThorState {
  @override
  String get $type => 'LayoutState';

  @override
  List<ThorMember> get $members {
    final s = this as LayoutState;
    return [
      ThorMember(
        'setSplit',
        s.setSplit,
        arity: 1,
        call: (a) => s.setSplit(double.parse(a!)),
      ),
    ];
  }
}

class LayoutState extends _LayoutMembers {
  void setSplit(double fraction) {}
}

final layout = LayoutState();

Future<String> _html(Widget w) => renderHtml(ThorApp(child: w));

const _panes = (first: Text('left'), second: Text('right'));

final _hasNode = () {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();

void main() {
  initializeThorTests();

  group('markup', () {
    test('two panes and a window splitter between them', () async {
      final html = await _html(
        SplitPane(
          first: _panes.first,
          second: _panes.second,
          initialFraction: 0.25,
          minFirstSize: 120,
          minSecondSize: 200,
          semanticLabel: 'Resize the sidebar',
        ),
      );
      expect(html, contains('data-t-split="x"'));
      expect(html, contains('data-t-split-min="120,200"'));
      final body = html.substring(html.indexOf('<body'));
      expect(html, contains('role="separator"'));
      expect(html, contains('tabindex="0"'));
      expect(html, contains('aria-orientation="vertical"'));
      expect(html, contains('aria-valuenow="25"'));
      expect(html, contains('aria-valuemin="0"'));
      expect(html, contains('aria-valuemax="100"'));
      expect(html, contains('aria-label="Resize the sidebar"'));
      expect(html, contains('data-t-split-bar'));
      expect(
        body.indexOf('>left<'),
        lessThan(body.indexOf('data-t-split-bar')),
      );
      expect(body.indexOf('data-t-split-bar'), lessThan(body.indexOf('right')));
    });

    test('the divider controls the first pane', () async {
      final html = await _html(
        SplitPane(id: 'side', first: _panes.first, second: _panes.second),
      );
      expect(html, contains('id="side"'));
      expect(html, contains('aria-controls="side"'));
    });

    test('the first size is CSS: clamp() over the fraction', () async {
      final html = await _html(
        SplitPane(
          first: _panes.first,
          second: _panes.second,
          initialFraction: 0.3,
          minFirstSize: 100,
          minSecondSize: 50,
          dividerThickness: 8,
        ),
      );
      expect(html, contains('--tsp: 0.3'));
      expect(
        html,
        contains(
          'width: clamp(100px, calc((100% - 8px) * var(--tsp)), '
          'calc(100% - 8px - 50px))',
        ),
      );
      expect(html, contains('cursor: col-resize'));
      expect(html, contains('touch-action: none'));
    });

    test('vertical: stacked, a horizontal line, heights', () async {
      final html = await _html(
        SplitPane(
          axis: Axis.vertical,
          first: _panes.first,
          second: _panes.second,
        ),
      );
      expect(html, contains('data-t-split="y"'));
      expect(html, contains('aria-orientation="horizontal"'));
      expect(html, contains('flex-direction: column'));
      expect(html, contains('height: clamp('));
      expect(html, contains('cursor: row-resize'));
    });

    test('onChanged is a state method on the root', () async {
      final html = await _html(
        SplitPane(
          first: _panes.first,
          second: _panes.second,
          onChanged: layout.setSplit,
        ),
      );
      expect(html, contains('data-t-ev="split:LayoutState.setSplit"'));
    });

    test('the default label names the divider', () async {
      final html = await _html(
        SplitPane(first: _panes.first, second: _panes.second),
      );
      expect(html, contains('aria-label="Resize panes"'));
      expect(html, isNot(contains('data-t-ev')));
    });

    test('the lite bundle ships the part for a page that has one', () {
      final parts = litePartsFor(
        stateJs: '',
        engineEntry: 'SplitPaneFeature()',
        pages: ['<div data-t-split="x"></div>'],
      );
      expect(parts, contains('split_pane'));
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'SplitPaneFeature()',
          pages: ['<div></div>'],
        ),
        isNot(contains('split_pane')),
      );
    });
  });

  group('the part, in node', () {
    final skip = _hasNode ? null : 'node is not installed';

    // Runs [script] against the pane [html] draws: `out` collects results.
    Future<Map<String, Object?>> run(
      Widget pane,
      String script, {
      String direction = 'ltr',
      int length = 1000,
    }) async {
      final html = await _html(pane);
      final js =
          '''
${File('test/support/mini_dom.js').readAsStringSync()}
const { parseHtml, body } = miniDom;
const handlers = {};
document.documentElement.addEventListener = (t, f) => { handlers[t] = f; };
document.readyState = 'complete';
window.addEventListener = () => {};
window.getComputedStyle = () => ({ direction: ${jsonEncode(direction)} });
const calls = [];
globalThis.parseOn = (s) => Object.fromEntries(s.split(';').filter(Boolean).map((p) => p.split(':')));
globalThis.run = (id, el, v) => calls.push([id, v]);
body.append(parseHtml(${jsonEncode(html)}));
const root = document.querySelector('[data-t-split]');
const bar = document.querySelector('[data-t-split-bar]');
const x = root.getAttribute('data-t-split') === 'x';
const rtl = ${jsonEncode(direction)} === 'rtl';
const THICK = 10, LENGTH = $length, ORIGIN = 100;
const mins = root.getAttribute('data-t-split-min').split(',').map(Number);
root.style = { vars: {}, setProperty(k, v) { this.vars[k] = v; } };
bar.setPointerCapture = () => {};
bar.releasePointerCapture = () => {};
bar.focus = () => {};
// The CSS: clamp(min1, (length - bar) * tsp, length - bar - min2).
const tsp = () => +(root.style.vars['--tsp'] ?? ${jsonEncode(RegExp(r'--tsp: ([\d.]+)').firstMatch(html)![1])});
const first = () => Math.min(Math.max((LENGTH - THICK) * tsp(), mins[0]), Math.max(LENGTH - THICK - mins[1], mins[0]));
root.getBoundingClientRect = () => x
  ? { left: ORIGIN, right: ORIGIN + LENGTH, width: LENGTH, top: 0, height: 300 }
  : { top: ORIGIN, left: 0, width: 300, height: LENGTH, right: 300 };
bar.getBoundingClientRect = () => {
  const f = first();
  return x
    ? (rtl ? { right: ORIGIN + LENGTH - f, left: ORIGIN + LENGTH - f - THICK, width: THICK } : { left: ORIGIN + f, right: ORIGIN + f + THICK, width: THICK })
    : { top: ORIGIN + f, height: THICK, bottom: ORIGIN + f + THICK };
};
const ev = (o) => ({ target: bar, button: 0, pointerId: 1, preventDefault() { this.prevented = true; }, ...o });
const fire = (t, o) => { const e = ev(o); handlers[t](e); return e; };
const aria = () => ['aria-valuenow', 'aria-valuemin', 'aria-valuemax'].map((n) => +bar.getAttribute(n));
const out = {};
$script
console.log(JSON.stringify(out));
''';
      return _runWithPart(
        js,
        File('../thor_engine/lib/lite/parts/split_pane.js').readAsStringSync(),
      );
    }

    test('a drag moves the divider and keeps the grabbed point', () async {
      final out = await run(
        SplitPane(
          first: _panes.first,
          second: _panes.second,
          onChanged: layout.setSplit,
        ),
        '''
fire('pointerdown', { clientX: 100 + 495 + 4 });      // grabbed 4px into the divider
fire('pointermove', { clientX: 100 + 300 + 4 });
out.tsp = tsp();
out.first = first();
out.aria = aria();
out.dragging = bar.hasAttribute('data-dragging');
out.during = calls.length;
fire('pointerup', {});
out.after = calls;
out.draggingAfter = bar.hasAttribute('data-dragging');
''',
      );
      expect(out['first'], closeTo(300, 0.5));
      expect(out['tsp'], closeTo(300 / 990, 0.0001));
      expect(out['aria'], [30, 0, 100]);
      expect(out['dragging'], isTrue);
      // Nothing is told while the pointer moves, only when it lets go.
      expect(out['during'], 0);
      expect(out['after'], [
        ['LayoutState.setSplit', '0.303'],
      ]);
      expect(out['draggingAfter'], isFalse);
    }, skip: skip);

    test('a drag stops at the minimum sizes', () async {
      final out = await run(
        SplitPane(
          first: _panes.first,
          second: _panes.second,
          minFirstSize: 150,
          minSecondSize: 250,
        ),
        '''
fire('pointerdown', { clientX: 100 + 495 + 5 });
fire('pointermove', { clientX: 0 });
out.low = first();
out.lowAria = aria();
fire('pointermove', { clientX: 5000 });
out.high = first();
out.highAria = aria();
fire('pointerup', {});
''',
      );
      expect(out['low'], 150);
      expect(out['high'], 740 - 0); // 1000 - 10 - 250
      // The bounds in aria are the percents of the room.
      expect((out['lowAria'] as List)[1], 16); // ceil(150 / 990)
      expect((out['highAria'] as List)[2], 74); // floor(740 / 990)
    }, skip: skip);

    test('only the primary button and a pointer on the divider drag', () async {
      final out = await run(
        SplitPane(first: _panes.first, second: _panes.second),
        '''
fire('pointerdown', { clientX: 600, button: 2 });
fire('pointermove', { clientX: 200 });
out.right = first();
fire('pointerdown', { clientX: 600, target: root.querySelector('div') });
fire('pointermove', { clientX: 200 });
out.pane = first();
''',
      );
      expect(out['right'], closeTo(495, 0.01));
      expect(out['pane'], closeTo(495, 0.01));
    }, skip: skip);

    test(
      'arrows resize by 2 %, Shift by 10 %, Home and End go to the ends',
      () async {
        final out = await run(
          SplitPane(
            first: _panes.first,
            second: _panes.second,
            minFirstSize: 100,
            minSecondSize: 100,
            onChanged: layout.setSplit,
          ),
          '''
const key = (k, o = {}) => fire('keydown', { key: k, ...o });
key('ArrowRight'); out.right = first();
key('ArrowRight', { shiftKey: true }); out.shiftRight = first();
key('ArrowLeft'); out.left = first();
key('ArrowDown'); out.down = first();      // not this axis' key
key('Home'); out.home = first();
key('End'); out.end = first();
out.endAria = aria();
const tab = key('Tab'); out.tabPrevented = !!tab.prevented;
const arrow = key('ArrowLeft'); out.arrowPrevented = !!arrow.prevented;
out.calls = calls.length;
''',
        );
        // 2 % of the 990 px of room is 19.8 px.
        expect(out['right'], closeTo(495 + 19.8, 0.5));
        expect(out['shiftRight'], closeTo(495 + 19.8 + 99, 0.7));
        expect(out['left'], closeTo(495 + 99, 0.9));
        expect(out['down'], out['left']);
        expect(out['home'], 100);
        expect(out['end'], 890 - 0);
        expect(out['endAria'], [90, 11, 89]);
        expect(out['tabPrevented'], isFalse);
        expect(out['arrowPrevented'], isTrue);
        // A call for each key that moved it (Home, End and the arrows).
        expect(out['calls'], 6);
      },
      skip: skip,
    );

    test(
      'stacked: Up and Down, and the pointer runs along the height',
      () async {
        final out = await run(
          SplitPane(
            axis: Axis.vertical,
            first: _panes.first,
            second: _panes.second,
          ),
          '''
const key = (k, o = {}) => fire('keydown', { key: k, ...o });
key('ArrowDown'); out.down = first();
key('ArrowRight'); out.right = first();       // not this axis' key
fire('pointerdown', { clientY: 100 + out.down + 5 });
fire('pointermove', { clientY: 100 + 200 + 5 });
out.dragged = first();
fire('pointerup', {});
''',
        );
        expect(out['down'], closeTo(495 + 19.8, 0.5));
        expect(out['right'], out['down']);
        expect(out['dragged'], closeTo(200, 0.5));
      },
      skip: skip,
    );

    test(
      'in a right-to-left row the arrows and the pointer are mirrored',
      () async {
        final out = await run(
          SplitPane(first: _panes.first, second: _panes.second),
          '''
const key = (k, o = {}) => fire('keydown', { key: k, ...o });
key('ArrowLeft'); out.left = first();          // towards the end: bigger
fire('pointerdown', { clientX: 100 + 1000 - out.left - 5 });
fire('pointermove', { clientX: 100 + 1000 - 300 - 5 });
out.dragged = first();
fire('pointerup', {});
''',
          direction: 'rtl',
        );
        expect(out['left'], closeTo(495 + 19.8, 0.5));
        expect(out['dragged'], closeTo(300, 0.5));
      },
      skip: skip,
    );

    test(
      'the part reads the real layout for the bounds when it wakes',
      () async {
        final out = await run(
          SplitPane(
            first: _panes.first,
            second: _panes.second,
            initialFraction: 0.1,
            minFirstSize: 200,
          ),
          '''
out.aria = aria();
''',
        );
        // 10 % of the room is under the minimum: the divider says 20 %.
        expect((out['aria'] as List)[0], 20);
        expect((out['aria'] as List)[1], 21);
      },
      skip: skip,
    );
  });
}

// The part goes between the stand-ins and the script (`const out = {};`).
Map<String, Object?> _runWithPart(String js, String part) {
  final at = js.indexOf('const out = {};');
  final r = Process.runSync('node', [
    '-e',
    '${js.substring(0, at)}$part\n${js.substring(at)}',
  ], stdoutEncoding: utf8);
  if (r.exitCode != 0 || '${r.stderr}'.isNotEmpty) {
    fail('node failed:\n${r.stderr}');
  }
  return jsonDecode((r.stdout as String).trim()) as Map<String, Object?>;
}

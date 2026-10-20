@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// The member list thor generates for [_Nd], by hand.
abstract class _NdMembers extends ThorState {
  @override
  String get $type => 'Nd';

  @override
  List<ThorMember> get $members {
    final s = this as _Nd;
    return [
      ThorMember('started', s.started, call: (_) => s.started()),
      ThorMember('ended', s.ended, arity: 1, call: (a) => s.ended(a == 'true')),
      ThorMember('canDrop', s.canDrop, arity: 1, call: (a) => s.canDrop(a!)),
      ThorMember('dropped', s.dropped, arity: 1, call: (a) => s.dropped(a!)),
    ];
  }
}

class _Nd extends _NdMembers {
  void started() {}
  void ended(bool accepted) {}
  bool canDrop(String data) => true;
  void dropped(String data) {}
}

final _nd = _Nd();
const _chip = SizedBox(width: 40, height: 20);

void main() {
  initializeThorTests();

  test(
    'a NativeDraggable is the child\'s element, draggable, with data',
    () async {
      final html = await renderHtml(
        NativeDraggable<String>(
          data: 'node-7',
          mimeType: 'application/x-node',
          dataTransfer: const {'text/uri-list': 'https://x.test/n/7'},
          effectAllowed: DragEffect.copy,
          onDragStarted: _nd.started,
          onDragEnd: _nd.ended,
          child: _chip,
        ),
      );
      expect(html, contains('draggable="true"'));
      expect(html, contains('data-t-nd="start:Nd.started;end:Nd.ended"'));
      expect(html, contains('data-t-nd-data="node-7"'));
      expect(html, contains('data-t-nd-type="String"'));
      expect(html, contains('data-t-nd-cfg="application/x-node|copy"'));
      expect(
        html,
        contains(
          'data-t-nd-xfer="{&quot;text/uri-list&quot;:&quot;https://x.test/n/7&quot;}"',
        ),
      );
      // One element, no wrapper, and not the pointer draggable's markers.
      expect(RegExp('<div').allMatches(html), hasLength(1));
      expect(html, isNot(contains('data-t-dg')));
      expect(html, isNot(contains('<template')));
    },
  );

  test('without data nothing is written, and the defaults are text', () async {
    final html = await renderHtml(const NativeDraggable(child: _chip));
    expect(html, contains('data-t-nd-cfg="text/plain|copyMove"'));
    expect(html, isNot(contains('data-t-nd-data')));
    expect(html, isNot(contains('data-t-nd-xfer')));
  });

  test('draggingStyle is CSS on the dragged marker', () async {
    final html = await renderDocument(
      const ThorApp(
        child: NativeDraggable<String>(
          data: 'a',
          draggingStyle: StyleProps(opacity: 0.4),
          child: _chip,
        ),
      ),
    );
    expect(
      RegExp(r'\[data-t-nd-active\]\{[^}]*opacity: 0\.4').hasMatch(html),
      isTrue,
      reason: html,
    );
  });

  test('a NativeDragTarget marks the builder\'s element', () async {
    final html = await renderHtml(
      NativeDragTarget<String>(
        onWillAcceptWithDetails: _nd.canDrop,
        onAcceptWithDetails: _nd.dropped,
        acceptMimeTypes: const ['text/uri-list', 'Files'],
        dropEffect: DragEffect.move,
        builder: (context, candidates, rejected) => _chip,
      ),
    );
    expect(html, contains('data-t-nt="accept:Nd.canDrop;drop:Nd.dropped"'));
    expect(html, contains('data-t-nd-type="String"'));
    expect(html, contains('data-t-nt-mime="text/uri-list\nFiles"'));
    expect(html, contains('data-t-nt-effect="move"'));
    expect(RegExp('<div').allMatches(html), hasLength(1));
  });

  test('over and reject styles are the pointer target\'s selectors', () async {
    final html = await renderDocument(
      ThorApp(
        child: NativeDragTarget<String>(
          overStyle: const StyleProps(opacity: 0.5),
          rejectStyle: const StyleProps(opacity: 0.2),
          builder: (context, candidates, rejected) => _chip,
        ),
      ),
    );
    expect(html, contains('[data-t-dt-over]'));
    expect(html, contains('[data-t-dt-reject]'));
  });
}

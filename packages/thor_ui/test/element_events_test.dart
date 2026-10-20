@TestOn('vm')
library;

// MouseRegion.onEnter/onExit, Focus.onFocusChange and
// ExpansionTile.onExpansionChanged reach the browser as one `data-t-ev`
// marker (the events the delegated `data-t-on` cannot carry: they do not
// bubble, or need the related target to tell a child from the edge).
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

abstract class _HoverMembers extends ThorState {
  @override
  String get $type => 'Hover';

  @override
  List<ThorMember> get $members {
    final s = this as _Hover;
    return [
      ThorMember('enter', s.enter, call: (_) => s.enter()),
      ThorMember('leave', s.leave, call: (_) => s.leave()),
      ThorMember(
        'focused',
        s.focused,
        arity: 1,
        call: (a) => s.focused(a == 'true'),
      ),
      ThorMember(
        'expanded',
        s.expanded,
        arity: 1,
        call: (a) => s.expanded(a == 'true'),
      ),
      ThorMember(
        'tagged',
        s.tagged,
        arity: 2,
        call: (a) {
          final x = splitArgs(a, 2);
          return s.tagged(x[0], x[1] == 'true');
        },
      ),
    ];
  }
}

class _Hover extends _HoverMembers {
  void enter() {}
  void leave() {}
  void focused(bool hasFocus) {}
  void expanded(bool open) {}
  void tagged(String tag, bool open) {}
}

final _hover = _Hover();
const _box = SizedBox(width: 10, height: 10);

void main() {
  initializeThorTests();

  test('MouseRegion marks enter and leave and fuses into the child', () async {
    final html = await renderHtml(
      MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: _hover.enter,
        onExit: _hover.leave,
        child: _box,
      ),
    );
    expect(RegExp('<div').allMatches(html), hasLength(1));
    expect(html, contains('data-t-ev="enter:Hover.enter;leave:Hover.leave"'));
    expect(html, contains('cursor: pointer'));
  });

  test('a MouseRegion with no listeners marks nothing', () async {
    final html = await renderHtml(
      const MouseRegion(cursor: SystemMouseCursors.click, child: _box),
    );
    expect(html, isNot(contains('data-t-ev')));
  });

  test('Focus marks onFocusChange next to its tabindex', () async {
    final html = await renderHtml(
      Focus(onFocusChange: _hover.focused, child: _box),
    );
    expect(html, contains('data-t-ev="focus:Hover.focused"'));
    expect(html, contains('tabindex="0"'));
  });

  test(
    'a Focus that cannot take focus still reports its descendants',
    () async {
      final html = await renderHtml(
        Focus(
          canRequestFocus: false,
          onFocusChange: _hover.focused,
          child: _box,
        ),
      );
      expect(html, contains('data-t-ev="focus:Hover.focused"'));
      expect(html, isNot(contains('tabindex')));
    },
  );

  test(
    'ExpansionTile marks onExpansionChanged on the details element',
    () async {
      final html = await renderHtml(
        ExpansionTile(
          title: const Text('t'),
          initiallyExpanded: true,
          onExpansionChanged: _hover.expanded,
          children: const [Text('c')],
        ),
      );
      expect(html, contains('<details'));
      expect(html, contains('data-t-ev="toggle:Hover.expanded"'));
      // The expand itself stays native: `open` from the server, no JS.
      expect(html, contains(' open'));
    },
  );

  test('ExpansionPanelList keeps each tile\'s onExpansionChanged', () async {
    final html = await renderHtml(
      ExpansionPanelList(
        name: 'faq',
        children: [
          ExpansionTile(
            title: const Text('t'),
            onExpansionChanged: _hover.expanded,
            children: const [Text('c')],
          ),
        ],
      ),
    );
    expect(html, contains('data-t-ev="toggle:Hover.expanded"'));
  });

  test('withArg gives the handler its fixed argument first', () async {
    final html = await renderHtml(
      ExpansionTile(
        title: const Text('t'),
        onExpansionChanged: _hover.tagged.withArg('faq'),
        children: const [Text('c')],
      ),
    );
    expect(html, contains('data-t-ev="toggle:Hover.tagged"'));
    expect(html, contains('data-tx="faq"'));
  });
}

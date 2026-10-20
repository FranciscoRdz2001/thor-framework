@TestOn('vm')
library;

// `AnimatedList`: the rows of a `Watch.list` that enter and leave with
// CSS (`@starting-style`, a transition and a delayed removal), the Flutter
// `itemBuilder(context, index, animation)` shape adapted to a keyed row.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class Note {
  const Note(this.id, this.title);
  final int id;
  final String title;
}

abstract class _NotesMembers extends ThorState {
  @override
  String get $type => 'NotesState';

  @override
  List<ThorMember> get $members {
    final s = this as NotesState;
    return [
      ThorMember.state('notes', s.notes),
      ThorMember(
        'idOf',
        s.idOf,
        arity: 1,
        callWithItem: (i) => s.idOf(i as Note),
      ),
      ThorMember(
        'titleOf',
        s.titleOf,
        arity: 1,
        callWithItem: (i) => s.titleOf(i as Note),
      ),
    ];
  }
}

class NotesState extends _NotesMembers {
  final notes = state<List<Note>>(const [Note(1, 'One'), Note(2, 'Two')]);
  int idOf(Note n) => n.id;
  String titleOf(Note n) => n.title;
}

final notes = NotesState();

Future<String> page(
  Widget Function(
    BuildContext context,
    WatchRow<Note, int> row,
    Animation<double> animation,
  )
  itemBuilder, {
  Duration duration = const Duration(milliseconds: 300),
}) async => (await renderDocument(
  ThorApp(
    child: AnimatedList<Note, int>(
      notes.notes.call,
      itemKey: notes.idOf,
      duration: duration,
      itemBuilder: itemBuilder,
    ),
  ),
)).replaceAll(': ', ':').replaceAll('; ', ';');

const _from = BoxDecoration(
  color: Color(0xFFFF0000),
  borderRadius: BorderRadius.all(Radius.circular(4)),
);
const _to = BoxDecoration(
  color: Color(0xFF0000FF),
  borderRadius: BorderRadius.all(Radius.circular(20)),
);

void main() {
  initializeThorTests();

  group('the markup', () {
    test('a Watch.list whose container says how long a row takes to '
        'leave', () async {
      final html = await page(
        (context, row, animation) =>
            FadeTransition(opacity: animation, child: row.text(notes.titleOf)),
      );
      expect(html, contains('data-tl="NotesState.notes"'));
      expect(html, contains('data-tlx="300"'));
      expect(html, contains('>One<'));
      expect(html, contains('>Two<'));
    });

    test(
      'only the row template enters: the rows the server drew rest',
      () async {
        final html = await page(
          (context, row, animation) => FadeTransition(
            opacity: animation,
            child: row.text(notes.titleOf),
          ),
        );
        final template = html.indexOf('<template');
        final body = html.indexOf('<body');
        expect(html.substring(body, template), isNot(contains('data-tli')));
        expect(html.substring(template), contains('data-tli'));
      },
    );

    test('no animation: no engine for animations, no keyframes', () async {
      final html = await page(
        (context, row, animation) =>
            FadeTransition(opacity: animation, child: row.text(notes.titleOf)),
      );
      expect(html, isNot(contains('data-ta')));
      expect(html, isNot(contains('@keyframes')));
    });
  });

  group('the animation a row gets', () {
    test('FadeTransition: rests at 1, enters from 0 and leaves to 0', () async {
      final html = await page(
        (context, row, animation) =>
            FadeTransition(opacity: animation, child: row.text(notes.titleOf)),
      );
      expect(html, contains('opacity:1'));
      expect(html, contains('transition-property:opacity'));
      expect(html, contains('transition-duration:300ms'));
      expect(html, contains('transition-timing-function:linear'));
      expect(
        html,
        matches(
          RegExp(
            r'@starting-style\{\.\w+:where\(\[data-tli\],\[data-tli\] \*\)'
            r'\{opacity:0\}\}',
          ),
        ),
      );
      expect(
        html,
        matches(
          RegExp(r'\.\w+:where\(\[data-tlo\],\[data-tlo\] \*\)\{opacity:0\}'),
        ),
      );
    });

    test('a curve is the easing of the transition', () async {
      final html = await page(
        (context, row, animation) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: row.text(notes.titleOf),
        ),
      );
      expect(
        html,
        contains('transition-timing-function:${Curves.easeOut.css}'),
      );
    });

    test('a tween maps the ends: the row slides in from the left', () async {
      final html = await page(
        (context, row, animation) => SlideTransition(
          position: Tween(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: row.text(notes.titleOf),
        ),
      );
      expect(html, contains('translate:0% 0%'));
      expect(html, contains('transition-property:translate'));
      expect(html, contains('{translate:-100% 0%}'));
    });

    test('SizeTransition grows and shrinks the row', () async {
      final html = await page(
        (context, row, animation) => SizeTransition(
          sizeFactor: animation,
          child: row.text(notes.titleOf),
        ),
      );
      expect(html, contains('grid-template-rows:1fr'));
      expect(
        html,
        contains('transition-property:grid-template-rows, visibility'),
      );
      expect(html, contains('{grid-template-rows:0fr'));
      expect(html, contains('visibility:hidden'));
    });

    test('two transitions on one row each have their own property', () async {
      final html = await page(
        (context, row, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.8, end: 1.0).animate(animation),
            child: row.text(notes.titleOf),
          ),
        ),
      );
      expect(html, contains('transition-property:opacity, scale'));
      expect(html, contains('transition-duration:300ms'));
      expect(html, contains('{scale:0.8}'));
      expect(html, contains('{opacity:0}'));
    });

    test('the duration is the list\'s', () async {
      final html = await page(
        (context, row, animation) =>
            FadeTransition(opacity: animation, child: row.text(notes.titleOf)),
        duration: const Duration(milliseconds: 120),
      );
      expect(html, contains('data-tlx="120"'));
      expect(html, contains('transition-duration:120ms'));
    });

    test('reduced motion: the transition is instant', () async {
      final html = await page(
        (context, row, animation) =>
            FadeTransition(opacity: animation, child: row.text(notes.titleOf)),
      );
      expect(
        html,
        matches(
          RegExp(
            r'@media \(prefers-reduced-motion:reduce\)\{\.\w+'
            r'\{transition-duration:1ms\}\}',
          ),
        ),
      );
    });

    test('the animation reads as completed (a finished row)', () async {
      late Animation<double> seen;
      await page((context, row, animation) {
        seen = animation;
        return row.text(notes.titleOf);
      });
      expect(seen.value, 1);
      expect(seen.status, AnimationStatus.completed);
      expect(seen.isCompleted, isTrue);
    });
  });

  test('the row builder gets the typed row', () async {
    final html = await page(
      (context, row, animation) =>
          FadeTransition(opacity: animation, child: Text('${row.key}')),
    );
    expect(html, contains('data-tk="1"'));
  });

  test('a controller of its own still works: it is not the list\'s', () async {
    await expectLater(
      page(
        (context, row, animation) => FadeTransition(
          opacity: Tween(
            begin: 0.0,
            end: 1.0,
          ).animate(AnimationController(duration: const Duration(seconds: 1))),
          child: row.text(notes.titleOf),
        ),
      ),
      completes,
      reason: 'a normal controller still works: it is not the list\'s',
    );
  });

  test('inside an AnimatedList row it enters and leaves', () async {
    final html = await renderDocument(
      ThorApp(
        child: AnimatedList<Note, int>(
          notes.notes.call,
          itemKey: notes.idOf,
          itemBuilder: (context, row, animation) => DecoratedBoxTransition(
            decoration: DecorationTween(
              begin: _from,
              end: _to,
            ).animate(animation),
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      ),
    );
    expect(html, contains('@starting-style'));
    expect(html, contains('data-tlo'));
  });
}

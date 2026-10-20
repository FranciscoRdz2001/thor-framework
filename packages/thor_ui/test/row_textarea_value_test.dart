@TestOn('vm')
library;

// `row.attribute(AttributeName.value, …)` around a multi-line `TextField`: a
// `<textarea>` keeps its text as content, so the row's value is drawn there
// (not as a `value` attribute) and the binding stays for the browser.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class Snippet {
  const Snippet(this.id, this.code);
  final int id;
  final String code;
}

/// What thor generates for `Snippet` (by hand: tests don't run the build).
class _SnippetProbe implements Snippet {
  _SnippetProbe(this.log);
  final RowProbeLog log;

  @override
  int get id => log.integer('id');

  @override
  String get code {
    log.read('code');
    return RowProbeLog.marker('code');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    log.read('');
    return super.noSuchMethod(invocation);
  }
}

abstract class _Members extends ThorState {
  @override
  String get $type => 'SnippetsState';

  @override
  List<ThorMember> get $members {
    final s = this as SnippetsState;
    return [
      ThorMember.state('snippets', s.snippets),
      ThorMember(
        'idOf',
        s.idOf,
        arity: 1,
        callWithItem: (i) => s.idOf(i as Snippet),
      ),
    ];
  }
}

class SnippetsState extends _Members {
  final snippets = state<List<Snippet>>(const [
    Snippet(1, 'a < b\nreturn 1;'),
    Snippet(2, ''),
  ]);

  int idOf(Snippet s) => s.id;
}

final snippets = SnippetsState();

void main() {
  initializeThorTests();
  setUpAll(() => registerRowProbes({Snippet: _SnippetProbe.new}));

  Future<String> rows(Widget Function(WatchRow<Snippet, int> row) each) =>
      renderHtml(
        Watch.list(snippets.snippets.call, itemKey: snippets.idOf, each: each),
      );

  test('a multi-line field gets the row value as its content', () async {
    final out = await rows(
      (row) => row.attribute(
        AttributeName.value,
        (s) => s.code,
        child: const TextField(
          maxLines: 3,
          decoration: InputDecoration(labelText: 'Code'),
        ),
      ),
    );
    expect(out, contains('<textarea'));
    expect(out, contains('a &lt; b\nreturn 1;</textarea>'));
    expect(out, isNot(contains(RegExp(r'<textarea[^>]* value='))));
    expect(out, contains(r'data-tfa="value:$Rows.code"'));
    // The template the browser clones carries it empty.
    final template = out.substring(out.indexOf('<template'));
    expect(template, contains('></textarea>'));
  });

  test('a one-line field keeps the value attribute', () async {
    final out = await rows(
      (row) => row.attribute(
        AttributeName.value,
        (s) => s.code,
        child: const TextField(decoration: InputDecoration(labelText: 'Code')),
      ),
    );
    expect(out, contains('<input'));
    expect(out, contains('value="a &lt; b'));
    expect(out, isNot(contains('<textarea')));
  });
}

@TestOn('vm')
library;

// A row's `row.text(...)` as the child of a `DropdownMenuItem` (or a
// `ListBoxItem`) is the text of the `<option>` itself, bound with `data-tf`:
// the select's parser drops a `<span>` inside an option.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class Prop {
  const Prop(this.id, this.fallback);
  final int id;
  final String fallback;
}

/// What thor generates for `Prop` (by hand: tests don't run the build).
class _PropProbe implements Prop {
  _PropProbe(this.log);
  final RowProbeLog log;

  @override
  int get id => log.integer('id');

  @override
  String get fallback {
    log.read('fallback');
    return RowProbeLog.marker('fallback');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    log.read('');
    return super.noSuchMethod(invocation);
  }
}

abstract class _Members extends ThorState {
  @override
  String get $type => 'PropsState';

  @override
  List<ThorMember> get $members {
    final s = this as PropsState;
    return [
      ThorMember.state('props', s.props),
      ThorMember(
        'idOf',
        s.idOf,
        arity: 1,
        callWithItem: (i) => s.idOf(i as Prop),
      ),
    ];
  }
}

class PropsState extends _Members {
  final props = state<List<Prop>>(const [Prop(1, 'Auto'), Prop(2, 'Row')]);

  int idOf(Prop p) => p.id;
}

final props = PropsState();

void main() {
  initializeThorTests();
  setUpAll(() => registerRowProbes({Prop: _PropProbe.new}));

  Future<String> rows(Widget Function(WatchRow<Prop, int> row) each) =>
      renderHtml(Watch.list(props.props.call, itemKey: props.idOf, each: each));

  test('a DropdownMenuItem with row.text binds the option itself', () async {
    final out = await rows(
      (row) => DropdownButton<String>(
        semanticLabel: 'Size',
        value: 'a',
        onChanged: null,
        items: [
          DropdownMenuItem(value: 'a', child: row.text((p) => p.fallback)),
        ],
      ),
    );
    expect(
      out,
      contains(
        r'<option value="a" selected data-tf="$Rows.fallback">Auto</option>',
      ),
    );
    expect(
      out,
      contains(
        r'<option value="a" selected data-tf="$Rows.fallback">Row</option>',
      ),
    );
    expect(out, isNot(contains('<span')));
    // The template the browser clones carries it empty.
    final template = out.substring(out.indexOf('<template'));
    expect(template, contains(r'data-tf="$Rows.fallback"></option>'));
  });

  test('a ListBoxItem too, and a plain Text stays plain', () async {
    final out = await rows(
      (row) => ListBox<String>(
        semanticLabel: 'Sizes',
        value: 'a',
        onChanged: null,
        items: [
          ListBoxItem(value: 'a', child: row.text((p) => p.fallback)),
          const ListBoxItem(value: 'b', child: Text('Fixed')),
        ],
      ),
    );
    expect(out, contains(r'data-tf="$Rows.fallback">Auto</option>'));
    expect(out, contains('>Fixed</option>'));
  });
}

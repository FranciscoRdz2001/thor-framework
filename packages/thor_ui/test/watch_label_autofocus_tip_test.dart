@TestOn('vm')
library;

// A visible per-row label for a TextField, `row.attribute(autofocus)`, and
// a Tooltip / IconButton tooltip that follow a state method.
import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart'
    show isBindableAttribute, safeAttributeValue;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class Prop {
  const Prop(this.id, this.label);
  final String id;
  final String label;
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
      ThorMember(
        'labelOf',
        s.labelOf,
        arity: 1,
        callWithItem: (i) => s.labelOf(i as Prop),
      ),
      ThorMember(
        'focusOf',
        s.focusOf,
        arity: 1,
        callWithItem: (i) => s.focusOf(i as Prop),
      ),
      ThorMember('undoTip', s.undoTip, call: (_) => s.undoTip()),
    ];
  }
}

class PropsState extends _Members {
  final props = state<List<Prop>>(const [
    Prop('a', 'Draft'),
    Prop('b', 'Margen'),
  ]);

  String idOf(Prop p) => p.id;
  String labelOf(Prop p) => p.label;
  bool focusOf(Prop p) => p.id == 'a';
  String undoTip() => 'Undo: Draft';
}

final props = PropsState();

void main() {
  setUpAll(initializeThorTests);

  Future<String> page(Widget child) => renderDocument(ThorApp(child: child));

  String body(String html) =>
      html.substring(html.indexOf('<body'), html.indexOf('</body>'));

  group('item 23: a visible label per row', () {
    test('InputDecoration(label: row.text) is a bound <label>', () async {
      final html = body(
        await page(
          Watch.list(
            props.props.call,
            itemKey: props.idOf,
            each: (row) => TextField(
              decoration: InputDecoration(label: row.text(props.labelOf)),
            ),
          ),
        ),
      );
      expect(html, contains('<label'));
      // The `<label for>` itself carries the binding and the first value.
      expect(
        html,
        matches(
          RegExp(r'<label[^>]*data-tf="PropsState.labelOf"[^>]*>Draft</label>'),
        ),
      );
      expect(html, contains('>Margen</label>'));
      // Named by its label, not by an `aria-label` copy.
      expect(html, isNot(contains('aria-label')));
      final template = html.substring(html.indexOf('<template'));
      expect(template, contains('data-tf="PropsState.labelOf"'));
    });

    test('labelText: row.bind says to use label: row.text', () async {
      await expectLater(
        page(
          Watch.list(
            props.props.call,
            itemKey: props.idOf,
            each: (row) => TextField(
              decoration: InputDecoration(labelText: row.bind(props.labelOf)),
            ),
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => '$e',
            'message',
            contains('row.text'),
          ),
        ),
      );
    });
  });

  group('item 26: row.attribute(autofocus)', () {
    test('autofocus is bindable', () {
      expect(isBindableAttribute('autofocus'), isTrue);
      expect(safeAttributeValue('autofocus', 'true'), '');
      expect(safeAttributeValue('autofocus', 'false'), isNull);
    });

    test('goes to the <input> of a TextField, on when true', () async {
      final html = body(
        await page(
          Watch.list(
            props.props.call,
            itemKey: props.idOf,
            each: (row) => row.attribute(
              AttributeName.autofocus,
              props.focusOf,
              child: const TextField(
                decoration: InputDecoration(hintText: 'Value'),
              ),
            ),
          ),
        ),
      );
      final inputs = RegExp(
        r'<input[^>]*>',
      ).allMatches(html).map((m) => m[0]!).toList();
      expect(inputs[0], contains(' autofocus'));
      expect(inputs[0], contains('autofocus:PropsState.focusOf'));
      expect(inputs[1], isNot(contains(' autofocus=')));
      expect(inputs[1], isNot(matches(RegExp(r' autofocus[ >]'))));
      expect(inputs[1], contains('autofocus:PropsState.focusOf'));
    });
  });

  group('item 27: tooltips that follow a state', () {
    test('Tooltip(messageWatch) binds the bubble text', () async {
      final html = body(
        await page(
          Tooltip(
            messageWatch: props.undoTip,
            child: const TextButton(child: Text('b')),
          ),
        ),
      );
      expect(html, contains('role="tooltip"'));
      expect(html, contains('data-tt="PropsState.undoTip"'));
      expect(html, contains('>Undo: Draft<'));
    });

    test('IconButton(tooltipWatch) binds aria-label and title', () async {
      final html = body(
        await page(
          IconButton(
            tooltipWatch: props.undoTip,
            icon: const Text('x'),
            onPressed: () {},
          ),
        ),
      );
      expect(html, contains('aria-label="Undo: Draft"'));
      expect(html, contains('title="Undo: Draft"'));
      expect(html, contains('aria-label:PropsState.undoTip'));
    });
  });
}

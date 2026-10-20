@TestOn('vm')
library;

// Bound values with their own widget API, instead of `WatchAttributes` maps:
// `LinearProgressIndicator.watch`, `Slider.watch`, `InputDecoration(
// errorTextWatch:)` and `row.link`.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class Person {
  const Person(this.id, this.url);
  final int id;
  final String url;
}

class _PersonProbe implements Person {
  _PersonProbe(this.log);
  final RowProbeLog log;

  @override
  String get url {
    log.read('url');
    return RowProbeLog.marker('url');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    log.read('');
    return super.noSuchMethod(invocation);
  }
}

abstract class _Members extends ThorState {
  @override
  String get $type => 'BoundState';

  @override
  List<ThorMember> get $members {
    final s = this as BoundState;
    return [
      ThorMember('fraction', s.fraction, call: (_) => s.fraction()),
      ThorMember('level', s.level, call: (_) => s.level()),
      ThorMember('dateError', s.dateError, call: (_) => s.dateError()),
      ThorMember('noError', s.noError, call: (_) => s.noError()),
      ThorMember.state('people', s.people),
      ThorMember(
        'idOf',
        s.idOf,
        arity: 1,
        callWithItem: (i) => s.idOf(i as Person),
      ),
      ThorMember(
        'urlOf',
        s.urlOf,
        arity: 1,
        callWithItem: (i) => s.urlOf(i as Person),
      ),
    ];
  }
}

class BoundState extends _Members {
  final people = state<List<Person>>(const [Person(1, '/a/1')]);
  double? fraction() => 0.25;
  double level() => 30;
  String? dateError() => 'Use dd.mm.yyyy';
  String? noError() => null;
  int idOf(Person p) => p.id;
  String urlOf(Person p) => p.url;
}

final bound = BoundState();

Future<String> _body(Widget w) async =>
    bodyOfPage(await renderDocument(ThorApp(child: w)));

String _tag(String html, String name) =>
    RegExp('<$name[^>]*>').firstMatch(html)![0]!;

void main() {
  setUpAll(() {
    initializeThorTests();
    registerRowProbes({Person: _PersonProbe.new});
  });

  group('LinearProgressIndicator.watch', () {
    test('binds the value of the native progress', () async {
      final html = await _body(LinearProgressIndicator.watch(bound.fraction));
      final tag = _tag(html, 'progress');
      expect(tag, contains('value="0.25"'));
      expect(tag, contains('max="1"'));
      expect(tag, contains('data-tca='));
      expect('<progress'.allMatches(html), hasLength(1));
    });

    test('the plain constructor binds nothing', () async {
      final html = await _body(const LinearProgressIndicator(value: 0.5));
      expect(html, isNot(contains('data-tca=')));
    });
  });

  group('Slider.watch', () {
    test('binds the value of the range input', () async {
      final html = await _body(
        Slider.watch(bound.level, min: 5, max: 100, semanticLabel: 'Size'),
      );
      final tag = _tag(html, 'input');
      expect(tag, contains('type="range"'));
      expect(tag, contains('value="30"'));
      expect(tag, contains('min="5"'));
      expect(tag, contains('data-tca='));
    });

    test('a first value outside the range is clamped', () async {
      final html = await _body(Slider.watch(bound.level, min: 0, max: 10));
      expect(_tag(html, 'input'), contains('value="10"'));
    });
  });

  group('InputDecoration(errorTextWatch:)', () {
    test(
      'the message, aria-invalid and the bound text start in sync',
      () async {
        final html = await _body(
          TextField(
            decoration: InputDecoration(
              labelText: 'Date',
              helperText: 'dd.mm.yyyy',
              errorTextWatch: bound.dateError,
            ),
          ),
        );
        final input = _tag(html, 'input');
        expect(input, contains('aria-invalid="true"'));
        expect(input, contains('data-tca='));
        expect(html, contains('Use dd.mm.yyyy'));
        // The helper stays in the page for when the error clears.
        expect(html, contains('data-help-text'));
        expect(html, contains('data-error'));
      },
    );

    test('no error: no aria-invalid, an empty bound text', () async {
      final html = await _body(
        TextField(
          decoration: InputDecoration(
            labelText: 'Date',
            helperText: 'dd.mm.yyyy',
            errorTextWatch: bound.noError,
          ),
        ),
      );
      expect(_tag(html, 'input'), isNot(contains('aria-invalid="')));
      expect(html, contains('dd.mm.yyyy'));
    });

    test('a TextFormField reads it too', () async {
      final html = await _body(
        TextFormField(
          name: 'date',
          decoration: InputDecoration(
            labelText: 'Date',
            errorTextWatch: bound.dateError,
          ),
        ),
      );
      expect(_tag(html, 'input'), contains('aria-invalid="true"'));
    });

    test('a fixed errorText wins over the bound one', () async {
      final html = await _body(
        TextField(
          decoration: InputDecoration(
            labelText: 'Date',
            errorText: 'Fixed',
            errorTextWatch: bound.noError,
          ),
        ),
      );
      expect(html, contains('Fixed'));
      expect(_tag(html, 'input'), contains('aria-invalid="true"'));
    });
  });

  group('row.link', () {
    test('a Link with the row href', () async {
      final html = await renderHtml(
        Watch.list(
          bound.people.call,
          itemKey: bound.idOf,
          each: (row) => row.link(bound.urlOf, child: const Text('Open')),
        ),
      );
      final item = html.substring(0, html.indexOf('<template'));
      expect(item, contains('<a '));
      expect(item, contains('href="/a/1"'));
      expect('<a '.allMatches(item), hasLength(1));
    });

    test('the lambda form and newTab work too', () async {
      final html = await renderHtml(
        Watch.list(
          bound.people.call,
          itemKey: bound.idOf,
          each: (row) =>
              row.link((p) => p.url, newTab: true, child: const Text('Open')),
        ),
      );
      final item = html.substring(0, html.indexOf('<template'));
      expect(item, contains('href="/a/1"'));
      expect(item, contains('target="_blank"'));
    });
  });
}

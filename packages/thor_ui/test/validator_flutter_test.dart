// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
// What a Flutter developer writes in a `validator:` and how it maps
// to a rule: a `RegExp` (partial match, like `hasMatch`), "not blank after
// trim", and `minLength` over an empty value.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class _Custom implements Pattern {
  @override
  Iterable<Match> allMatches(String string, [int start = 0]) => const [];

  @override
  Match? matchAsPrefix(String string, [int start = 0]) => null;
}

abstract final class _F {
  // A String pattern is the whole value (HTML `pattern`).
  static const whole = TextSchemaField(
    'whole',
    validators: [Validator.pattern('[a-z]{2}', 'whole')],
  );
  // A RegExp is what `hasMatch` says: a match anywhere.
  static final upper = TextSchemaField(
    'upper',
    validators: [Validator.pattern(RegExp(r'[A-Z]'), 'needs an upper case')],
  );
  static final anchored = TextSchemaField(
    'anchored',
    validators: [Validator.pattern(RegExp(r'^\d{3}$'), 'three digits')],
  );
  static final multi = TextSchemaField(
    'multi',
    validators: [Validator.pattern(RegExp(r'a|b'), 'a or b')],
  );
  static const name = TextSchemaField(
    'name',
    validators: [Validator.notBlank('write your name')],
  );
  static const short = TextSchemaField(
    'short',
    validators: [Validator.minLength(3, 'too short')],
  );
  static const shortRequired = TextSchemaField(
    'shortRequired',
    validators: [
      Validator.required('required'),
      Validator.minLength(3, 'too short'),
    ],
  );
  static final schema = FormSchema([
    whole,
    upper,
    anchored,
    multi,
    name,
    short,
    shortRequired,
  ]);
}

const _base = {'name': 'Ana', 'shortRequired': 'abc'};

String? _error(Map<String, String> fields, SchemaField<Object?> f) {
  final r = _F.schema.validate(
    FormData({
      for (final e in {..._base, ...fields}.entries) e.key: [e.value],
    }),
  );
  return r is FormInvalid ? r.errors[f.name] : null;
}

Future<String> _html(Widget w) async =>
    bodyOfPage(await renderDocument(ThorApp(child: w)));

void main() {
  setUpAll(initializeThorTests);

  group('Validator.pattern with a RegExp', () {
    test('matches anywhere, like RegExp.hasMatch; a String is the whole', () {
      expect(_error({'upper': 'abC'}, _F.upper), isNull);
      expect(_error({'upper': 'abc'}, _F.upper), 'needs an upper case');
      expect(_error({'whole': 'ab'}, _F.whole), isNull);
      expect(_error({'whole': 'abc'}, _F.whole), 'whole');
    });

    test('an anchored RegExp is still the whole value', () {
      expect(_error({'anchored': '123'}, _F.anchored), isNull);
      expect(_error({'anchored': '1234'}, _F.anchored), 'three digits');
      expect(_error({'anchored': 'a123'}, _F.anchored), 'three digits');
      expect(_error({'anchored': '12\n3'}, _F.anchored), 'three digits');
    });

    test('an alternation is not cut by the wrapper', () {
      expect(_error({'multi': 'xxbxx'}, _F.multi), isNull);
      expect(_error({'multi': 'xyz'}, _F.multi), 'a or b');
    });

    test('an empty optional field passes (like every rule but required)', () {
      expect(_error({'upper': ''}, _F.upper), isNull);
    });

    test('the browser gets a native pattern of the same meaning', () async {
      final html = await _html(
        TextFormField(
          name: 'code',
          validator: Validator.pattern(RegExp(r'^\d{3}$'), 'three digits'),
        ),
      );
      expect(html, contains('pattern="[\\s\\S]*(?:^\\d{3}\$)[\\s\\S]*"'));
      expect(html, contains('data-msg-patternmismatch="three digits"'));
    });

    test('the same String keeps its attribute as written', () async {
      final html = await _html(
        const TextFormField(
          name: 'code',
          validator: Validator.pattern(r'\d{3}', 'three digits'),
        ),
      );
      expect(html, contains('pattern="\\d{3}"'));
    });

    test('a String with class syntax the v flag rejects is escaped', () async {
      // `[\w.-]+` is valid for Dart's RegExp (the server) but invalid with
      // the browser's `v` flag, which would drop the whole pattern.
      final html = await _html(
        const TextFormField(
          name: 'user',
          validator: Validator.pattern(r'[\w.-]+', 'letters, dots, dashes'),
        ),
      );
      expect(html, contains(r'pattern="[\w.\-]+"'));
    });

    test('flags the native pattern cannot carry are refused, not dropped', () {
      for (final r in [
        RegExp('a', caseSensitive: false),
        RegExp('a', multiLine: true),
        RegExp('a', dotAll: true),
      ]) {
        expect(
          () => Validator.pattern(r, 'm').attributes,
          throwsA(isA<AssertionError>()),
          reason: '${r.isCaseSensitive} ${r.isMultiLine} ${r.isDotAll}',
        );
      }
      // unicode: true is what the browser does already.
      expect(
        Validator.pattern(RegExp('a', unicode: true), 'm').attributes,
        isNotEmpty,
      );
    });

    // The browser compiles `pattern` with the `v` flag, which rejects what a
    // Dart (and a `u`) RegExp accepts inside a class: the whole pattern is
    // then ignored. The RegExp translation escapes those.
    test('class syntax the `v` flag rejects is escaped', () {
      String attr(String p) =>
          Validator.pattern(RegExp(p), 'm').attributes['pattern']!;
      String inner(String p) {
        final a = attr(p);
        return a.substring(r'[\s\S]*(?:'.length, a.length - r')[\s\S]*'.length);
      }

      expect(inner(r'[\w.-]+'), r'[\w.\-]+');
      expect(inner(r'[-a-z]'), r'[\-a-z]');
      expect(inner(r'[a-z-]'), r'[a-z\-]');
      expect(inner(r'[a-]'), r'[a\-]');
      expect(inner(r'[\s-]'), r'[\s\-]');
      expect(inner(r'[a|b]'), r'[a\|b]');
      expect(inner(r'[(]'), r'[\(]');
      expect(inner(r'[[]'), r'[\[]');
      expect(inner(r'[a&&b]'), r'[a&\&b]');
      expect(inner(r'[~~]'), r'[~\~]');
      expect(inner(r'[a-z]'), r'[a-z]');
      expect(inner(r'[^a-z0-9]'), r'[^a-z0-9]');
      expect(inner(r'[\]\-]'), r'[\]\-]');
      expect(inner(r'[--a]'), r'[\--a]');
      expect(inner(r'[a-z-9]'), r'[a-z\-9]');
      // Outside a class nothing changes.
      expect(inner(r'a-b(c|d)\(x\)'), r'a-b(c|d)\(x\)');
    });

    test('identity escapes and lone brackets Dart accepts are rewritten', () {
      String attr(String p) => Validator.pattern(p, 'm').attributes['pattern']!;

      expect(attr(r'^(?:\d{3}\-\d{4})$'), r'^(?:\d{3}-\d{4})$');
      expect(attr(r'[A-Za-z0-9\_]+'), r'[A-Za-z0-9_]+');
      expect(attr(r'a\@b'), r'a@b');
      expect(attr('a]'), r'a\]');
      expect(attr('x{'), r'x\{');
      expect(attr('x}'), r'x\}');
      // What is valid is untouched: syntax escapes, quantifiers, classes.
      expect(attr(r'\.\/\(\d{2,3}\w{1,}\s{2,}'), r'\.\/\(\d{2,3}\w{1,}\s{2,}');
      expect(attr(r'[\-\.\]\/\&]'), r'[\-\.\]\/\&]');
      expect(attr(r'\p{L}+'), r'\p{L}+');
    });

    test('a \\p or \\u{} RegExp without unicode: true is refused', () {
      for (final p in [r'\p{L}', r'[\p{Lu}]', r'\P{L}', r'\u{1F600}']) {
        expect(
          () => Validator.pattern(RegExp(p), 'm').attributes,
          throwsA(isA<AssertionError>()),
          reason: p,
        );
        expect(
          Validator.pattern(RegExp(p, unicode: true), 'm').attributes,
          isNotEmpty,
          reason: p,
        );
      }
    });

    test('a Pattern that is neither a String nor a RegExp is refused', () {
      expect(
        () => Validator.pattern(_Custom(), 'm').attributes,
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Validator.notBlank', () {
    test('empty and only spaces fail; anything with a visible char passes', () {
      expect(_error({'name': ''}, _F.name), 'write your name');
      expect(_error({'name': '   '}, _F.name), 'write your name');
      expect(_error({'name': '\t  　'}, _F.name), 'write your name');
      // Dart's trim() also removes U+0085 (NEL), which JavaScript's \s keeps.
      expect(_error({'name': '\u0085'}, _F.name), 'write your name');
      expect(
        _error({'name': '\u00a0\u2003\ufeff'}, _F.name),
        'write your name',
      );
      // A zero-width space is not whitespace for trim() nor for \s.
      expect(_error({'name': '\u200b'}, _F.name), isNull);
      expect(_error({'name': ' a '}, _F.name), isNull);
      expect(_error({'name': 'Ana López'}, _F.name), isNull);
    });

    test('an absent field is blank too', () {
      final r = _F.schema.validate(
        const FormData({
          'shortRequired': ['abc'],
        }),
      );
      expect((r as FormInvalid).errors['name'], 'write your name');
    });

    test('it is a required and a pattern: the browser enforces both', () async {
      final html = await _html(
        const TextFormField(
          name: 'name',
          validator: Validator.notBlank('write your name'),
        ),
      );
      expect(html, contains('required'));
      expect(html, contains('pattern="[\\s\\S]*[^\\s\\u0085][\\s\\S]*"'));
      expect(html, contains('data-msg-valuemissing="write your name"'));
      expect(html, contains('data-msg-patternmismatch="write your name"'));
    });

    test('it nests in Validator.all and keeps the order', () {
      const v = Validator.all([
        Validator.notBlank('blank'),
        Validator.minLength(3, 'short'),
      ]);
      expect(
        [for (final r in v.rules) r.validity],
        ['valueMissing', 'patternMismatch', 'tooShort'],
      );
    });

    test('plain required still accepts only spaces (native behaviour)', () {
      expect(_error({'shortRequired': '   '}, _F.shortRequired), isNull);
    });
  });

  group('minLength over an empty value', () {
    test('an empty field passes minLength alone (optional field)', () {
      expect(_error({'short': ''}, _F.short), isNull);
      expect(_error({'short': 'ab'}, _F.short), 'too short');
      expect(_error({'short': 'abc'}, _F.short), isNull);
    });

    test('with required, empty is the required message, not the short one', () {
      expect(_error({'shortRequired': ''}, _F.shortRequired), 'required');
      expect(_error({'shortRequired': 'ab'}, _F.shortRequired), 'too short');
    });
  });
}

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  initializeThorTests();

  test('an identifier is the element id, on the child itself', () async {
    final html = await renderHtml(
      const Semantics(
        identifier: 'contact',
        child: SizedBox(height: 10, child: Text('x')),
      ),
    );
    expect(html, contains('id="contact"'));
    // A wrapper: fused into its child (the one element), not a new one.
    expect(RegExp(r'<[a-z]').allMatches(html), hasLength(1));
  });

  test('it goes with a heading level on the same element', () async {
    final html = await renderHtml(
      const Semantics(
        identifier: 'soluciones',
        headingLevel: 2,
        child: Text('What we offer'),
      ),
    );
    expect(html, contains('<h2'));
    expect(RegExp(r'<h2[^>]*id="soluciones"').hasMatch(html), isTrue);
  });

  test('no identifier, no id', () async {
    final html = await renderHtml(
      const Semantics(label: 'x', child: SizedBox(height: 1)),
    );
    expect(html, isNot(contains(' id=')));
  });

  test('a hostile identifier stays one attribute value', () async {
    final html = await renderHtml(
      const Semantics(
        identifier: 'a" onclick="alert(1)',
        child: SizedBox(height: 1),
      ),
    );
    expect(html, isNot(contains('onclick="alert(1)"')));
  });

  test('two ids on one element fail loudly (THOR-R022), never one wins', () {
    expect(
      () => renderHtml(
        const Semantics(
          identifier: 'a',
          child: Semantics(identifier: 'b', child: SizedBox(height: 1)),
        ),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('THOR-R022'),
        ),
      ),
    );
  });

  test('the same id twice on one element is fine', () async {
    final html = await renderHtml(
      const Semantics(
        identifier: 'a',
        child: Semantics(identifier: 'a', child: SizedBox(height: 1)),
      ),
    );
    expect('id="a"'.allMatches(html), hasLength(1));
  });

  test('a widget whose id is on an inner element does not clash', () async {
    // DropdownMenu(id:) puts its id on its own field, not on the wrapper
    // the identifier lands on.
    final html = await renderHtml(
      const Semantics(
        identifier: 'a',
        child: DropdownMenu<int>(
          id: 'dd',
          dropdownMenuEntries: [DropdownMenuEntry(value: 1, label: 'x')],
        ),
      ),
    );
    expect(html, contains('id="a"'));
  });
}

@TestOn('vm')
library;

// InputChip, `href` on chips (a chip that navigates is an <a>), and the
// delete affordance (a second control next to the body, never nested in it).
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void _noop(Object? _) {}
void _none() {}

Future<String> _body(Widget w) async {
  final html = await renderDocument(ThorApp(child: w));
  final end = html.indexOf('<svg id="thor-sprite"');
  return html.substring(html.indexOf('<body'), end < 0 ? html.length : end);
}

Future<String> _doc(Widget w) => renderDocument(ThorApp(child: w));

int _count(String html, Pattern p) => p.allMatches(html).length;

void main() {
  setUpAll(initializeThorTests);

  group('href: a chip that navigates is a link', () {
    test('every chip becomes an <a href> with its own look', () async {
      for (final (name, chip) in <(String, Widget)>[
        ('Chip', const Chip(label: Text('Red'), href: '/c/red')),
        (
          'ActionChip',
          const ActionChip(label: Text('Red'), onPressed: null, href: '/c/red'),
        ),
        (
          'FilterChip',
          const FilterChip(
            label: Text('Red'),
            selected: false,
            onSelected: null,
            href: '/c/red',
          ),
        ),
        (
          'ChoiceChip',
          const ChoiceChip(
            label: Text('Red'),
            selected: false,
            onSelected: null,
            href: '/c/red',
          ),
        ),
        ('InputChip', const InputChip(label: Text('Red'), href: '/c/red')),
      ]) {
        final html = await _body(chip);
        expect(html, startsWith('<body><a '), reason: name);
        expect(html, contains('href="/c/red"'), reason: name);
        expect(html, contains('data-thor="$name"'), reason: name);
        expect(html, isNot(contains('<button')), reason: name);
        expect(html, isNot(contains('disabled')), reason: name);
        expect(html, isNot(contains('aria-pressed')), reason: name);
      }
    });

    test('a selected link chip is the current item, not a toggle', () async {
      final on = await _body(
        const FilterChip(
          label: Text('Red'),
          selected: true,
          onSelected: null,
          href: '/c/red',
        ),
      );
      expect(on, contains('aria-current="true"'));
      final off = await _body(
        const FilterChip(
          label: Text('Red'),
          selected: false,
          onSelected: null,
          href: '/c/red',
        ),
      );
      expect(off, isNot(contains('aria-current')));
      // The selected look is a condition of the same class.
      final css = await _doc(
        const ChoiceChip(
          label: Text('x'),
          selected: true,
          onSelected: null,
          href: '/x',
        ),
      );
      expect(css, matches(RegExp(r'\.t\w+\[aria-current="true"\]\{')));
    });

    test(
      'an href chip keeps working without JS: no handler is needed',
      () async {
        final html = await _body(
          const ActionChip(label: Text('Go'), onPressed: null, href: '/go'),
        );
        expect(html, isNot(contains('data-t-on')));
      },
    );

    test('Chip(href:) with an avatar keeps both inside the link', () async {
      final html = await _body(
        const Chip(
          avatar: Icon(IconData.svg('x', '<path d="M0 0"/>')),
          label: Text('Red'),
          href: '/c/red',
        ),
      );
      expect(
        html,
        matches(RegExp(r'<a [^>]*><svg.*</svg><span[^>]*>Red</span></a>')),
      );
    });
  });

  group('InputChip', () {
    test('without callbacks it is a static chip, like Chip', () async {
      final html = await _body(const InputChip(label: Text('Red')));
      expect(html, startsWith('<body><span '));
      expect(html, contains('data-thor="InputChip"'));
    });

    test('onPressed makes it a button; onSelected a toggle', () async {
      final press = await _body(
        const InputChip(label: Text('Red'), onPressed: _none),
      );
      expect(press, contains('<button'));
      expect(press, isNot(contains('aria-pressed')));
      final toggle = await _body(
        const InputChip(label: Text('Red'), selected: true, onSelected: _noop),
      );
      expect(toggle, contains('aria-pressed="true"'));
      final off = await _body(
        const InputChip(label: Text('Red'), onSelected: _noop),
      );
      expect(off, contains('aria-pressed="false"'));
    });

    test('onSelected and onPressed together are Flutter\'s assert', () {
      expect(
        () => InputChip(
          label: const Text('x'),
          onSelected: _noop,
          onPressed: _none,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('isEnabled: false disables the controls', () async {
      final html = await _body(
        const InputChip(
          label: Text('Red'),
          onPressed: _none,
          onDeleted: _none,
          isEnabled: false,
        ),
      );
      expect(_count(html, RegExp(r'\sdisabled[\s>]')), 2);
    });
  });

  test(
    'a long label wraps inside its container instead of overflowing',
    () async {
      for (final w in const [
        Chip(label: Text('x')),
        InputChip(label: Text('x'), onDeleted: _none),
        InputChip(label: Text('x'), href: '/x', deleteHref: '/'),
      ]) {
        final css = await _doc(w);
        expect(css, contains('max-width: 100%'));
        expect(css, contains('min-height: 32px'));
        expect(css, isNot(contains('white-space: nowrap')));
      }
      // The body of a chip with a delete control can shrink; the X cannot.
      final css = await _doc(
        const InputChip(label: Text('x'), onPressed: _none, onDeleted: _none),
      );
      expect(css, contains(RegExp(r'min-width:\s?0')));
      expect(css, contains(RegExp(r'flex:\s?none')));
    },
  );

  group('delete affordance', () {
    test('a button next to the body, with an accessible name', () async {
      final html = await _body(
        const InputChip(label: Text('Red'), onPressed: _none, onDeleted: _none),
      );
      // The chip is a wrapper of two controls: no button inside a button.
      expect(html, startsWith('<body><span '));
      expect(html, contains('data-thor="InputChip"'));
      expect(_count(html, '<button'), 2);
      expect(html, isNot(matches(RegExp(r'<button[^>]*><button'))));
      expect(html, contains('aria-label="Delete Red"'));
      expect(html, contains('title="Delete"'));
    });

    test(
      'deleteButtonTooltipMessage names it; a custom icon replaces the X',
      () async {
        final html = await _body(
          const InputChip(
            label: Text('Red'),
            onDeleted: _none,
            deleteButtonTooltipMessage: 'Remove',
            deleteIcon: Icon(IconData.svg('trash', '<path d="M1 1"/>')),
          ),
        );
        expect(html, contains('aria-label="Remove Red"'));
        expect(html, contains('href="#trash"'));
        expect(html, isNot(contains('material-cancel')));
      },
    );

    test('a static label stays a text node in the wrapper', () async {
      final html = await _body(
        const InputChip(label: Text('Red'), onDeleted: _none),
      );
      expect(_count(html, '<button'), 1);
      expect(html, matches(RegExp(r'<span [^>]*>Red<button')));
    });

    test(
      'deleteHref makes the delete a link (a filter you remove by URL)',
      () async {
        final html = await _body(
          const InputChip(
            label: Text('Red'),
            href: '/c',
            deleteHref: '/',
            deleteButtonTooltipMessage: 'Remove',
          ),
        );
        expect(html, contains('href="/c"'));
        expect(
          html,
          matches(RegExp(r'<a [^>]*href="/" aria-label="Remove Red"')),
        );
        expect(html, isNot(contains('<button')));
      },
    );

    test('Chip takes onDeleted too (Flutter\'s Chip does)', () async {
      final html = await _body(
        const Chip(label: Text('Red'), onDeleted: _none),
      );
      expect(html, contains('data-thor="Chip"'));
      expect(html, contains('aria-label="Delete Red"'));
    });

    test(
      'selected is on the body; the wrapper styles itself with :has()',
      () async {
        final doc = await _doc(
          const InputChip(
            label: Text('Red'),
            selected: true,
            onSelected: _noop,
            onDeleted: _none,
          ),
        );
        expect(doc, contains('aria-pressed="true"'));
        expect(doc, matches(RegExp(r':has\(> \[aria-pressed="true"\]\)\{')));
      },
    );

    test('no onDeleted, no delete: nothing extra is drawn', () async {
      final html = await _body(
        const InputChip(label: Text('Red'), onPressed: _none),
      );
      expect(_count(html, '<button'), 1);
      expect(html, isNot(contains('aria-label')));
    });
  });

  test(
    'Filter, Choice and Action chips take an avatar and a tooltip',
    () async {
      final html = await _body(
        const FilterChip(
          avatar: Icon(IconData.svg('x', '<path d="M0 0"/>')),
          label: Text('Red'),
          selected: false,
          onSelected: _noop,
          tooltip: 'Filter by red',
        ),
      );
      expect(html, contains('title="Filter by red"'));
      expect(
        html,
        matches(RegExp(r'<svg.*</svg><span[^>]*>Red</span></button>')),
      );
    },
  );
}

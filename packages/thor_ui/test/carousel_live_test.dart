@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// A carousel whose items are a live list (`Watch.list` with a `CarouselView`
// container): the server draws no rows, only the row template, so the controls
// can't depend on the item count it sees. The browser decides: native controls
// hide themselves (CSS `:has`), the fallback ones (engine part) show and sync.

abstract class _Members extends ThorState {
  @override
  String get $type => 'SlidesState';

  @override
  List<ThorMember> get $members {
    final s = this as SlidesState;
    return [
      ThorMember.state('slides', s.slides),
      ThorMember(
        'idOf',
        s.idOf,
        arity: 1,
        callWithItem: (i) => s.idOf(i as int),
      ),
    ];
  }
}

class SlidesState extends _Members {
  final slides = state<List<int>>(const []);
  int idOf(int n) => n;
}

final slidesState = SlidesState();

Future<String> page(
  Widget Function(List<Widget> rows) container, {
  List<int> initial = const [],
}) {
  slidesState.slides.value = initial;
  return renderDocument(
    ThorApp(
      child: Watch.list(
        slidesState.slides.call,
        itemKey: slidesState.idOf,
        container: container,
        each: (row) => const Text('slide'),
      ),
    ),
  );
}

Widget Function(List<Widget>) live({
  bool dots = true,
  CarouselIndicatorStyle? style,
  ButtonStyle? arrow,
}) =>
    (rows) => CarouselView(
      label: 'Live',
      showIndicators: dots,
      indicatorStyle: style,
      arrowStyle: arrow,
      children: rows,
    );

String head(String html) => html.substring(0, html.indexOf('</head>'));
String bodyOf(String html) => html.substring(html.indexOf('<body'));

void main() {
  setUpAll(() => initializeThorTests(compactHtml: false));

  for (final n in [0, 1, 3]) {
    test('a live list of $n rows still gets the controls', () async {
      final doc = await page(live(), initial: [for (var i = 0; i < n; i++) i]);
      final css = head(doc);
      final body = bodyOf(doc);
      expect(css, contains('::scroll-button(left)'));
      expect(css, contains('::scroll-marker'));
      expect(body, contains('data-t-cv-prev'));
      expect(body, contains('data-t-cv-next'));
      expect(body, contains('data-t-cv-dots'));
    });
  }

  test('native controls hide while the list has fewer than two rows', () async {
    final css = head(await page(live()));
    expect(
      css,
      contains(
        ':not(:has(> :nth-child(2 of :not(template))))::scroll-button(*)',
      ),
    );
    expect(
      css,
      contains(
        ':not(:has(> :nth-child(2 of :not(template))))::scroll-marker-group',
      ),
    );
  });

  test(
    'a static carousel writes no hiding rule (its count is known)',
    () async {
      final doc = await renderDocument(
        const ThorApp(child: CarouselView(children: [Text('a'), Text('b')])),
      );
      expect(doc, isNot(contains(':nth-child(2 of')));
    },
  );

  test(
    'the fallback dots are a template: the browser clones one per row',
    () async {
      final body = bodyOf(await page(live(), initial: [1, 2, 3]));
      final dots = body.substring(body.indexOf('data-t-cv-dots'));
      expect(dots, contains('<template data-t-cv-dot'));
      // No dot per row drawn by the server: the template is the only one.
      expect(RegExp('aria-label="Slide ').allMatches(body), hasLength(1));
      expect(body, contains('aria-label="Slide "'));
      // The count is the browser's to write (rows come and go): it only
      // needs the word that joins it.
      expect(body, contains('data-t-cv-of="of"'));
    },
  );

  test(
    'the native dots of a live list cannot know the count: Slide n',
    () async {
      final css = head(await page(live(), initial: [1, 2, 3]));
      expect(css, contains("content: '' / 'Slide ' counter(t-slide);"));
    },
  );

  test('without dots the live list has arrows only', () async {
    final doc = await page(live(dots: false));
    expect(bodyOf(doc), isNot(contains('data-t-cv-dots')));
    expect(head(doc), isNot(contains('::scroll-marker')));
    expect(head(doc), contains('::scroll-button(left)'));
  });

  test('a live list asks for the carousel part', () async {
    final doc = await page(live());
    expect(doc, contains('data-thor-engine'));
  });

  group('dot and arrow shapes', () {
    test(
      'activeSize and shape reach the native and the fallback dots',
      () async {
        final doc = await page(
          live(
            style: const CarouselIndicatorStyle(
              activeSize: Size(48, 12),
              size: 12,
              shape: StadiumBorder(),
            ),
          ),
          initial: [1, 2],
        );
        final css = head(doc);
        final i = css.indexOf(':target-current{');
        expect(i, isNonNegative, reason: css);
        final native = css.substring(i, css.indexOf('}', i));
        expect(native, contains('width: 48px'));
        expect(native, contains('height: 12px'));
        final j = css.indexOf('[aria-current="true"]{');
        expect(j, isNonNegative, reason: css);
        final fb = css.substring(j, css.indexOf('}', j));
        expect(fb, contains('width: 48px'));
        expect(fb, contains('height: 12px'));
      },
    );

    test('the arrow glyph takes ButtonStyle.iconSize', () async {
      final doc = await page(
        live(arrow: IconButton.styleFrom(iconSize: 20)),
        initial: [1, 2],
      );
      expect(head(doc), contains('background-size: 20px'));
      expect(head(doc), isNot(contains('background-size: 50%')));
    });

    test('the default glyph stays half the arrow', () async {
      expect(
        head(await page(live(), initial: [1, 2])),
        contains('background-size: 50%'),
      );
    });
  });
}

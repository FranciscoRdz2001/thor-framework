@TestOn('vm')
library;

// The render core on its own: build order, lookups, wrappers, the head
// portal, escaping and failure, on trees no app would write.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart' show Locale;
import 'package:thor_ui/src/core/document.dart';
import 'package:thor_ui/src/core/framework.dart';
import 'package:thor_ui/src/core/markup.dart';
import 'package:thor_ui/src/core/notifier.dart';
import 'package:thor_ui/src/core/page.dart';
import 'package:thor_ui/src/foundation/css_rules.dart' show css;
import 'package:thor_ui/src/foundation/layout_hint.dart';
import 'package:thor_ui/testing.dart' as ui;
import 'package:thor_ui/thor_ui.dart' as ui;

String _html(Widget c) =>
    writeComponent(c, standalone: true, compact: true).trim();

String _page(Widget c, {bool compact = true}) =>
    writeComponent(c, compact: compact);

Widget _el(String tag, [List<Widget>? children]) =>
    Widget.element(tag: tag, children: children);

class _Build extends StatelessWidget {
  const _Build(this.builder);
  final Widget Function(BuildContext) builder;
  @override
  Widget build(BuildContext context) => builder(context);
}

class _Value extends InheritedWidget {
  const _Value(this.value, {required super.child});
  final String value;
  @override
  bool updateShouldNotify(_Value old) => old.value != value;
}

/// Keeps the first fragment it builds and adds it again, as it is, on
/// every later build (what `Cached` does, without its checks).
class _Replay extends StatelessWidget {
  _Replay(this.child);
  final Widget child;
  FragmentNode? kept;
  final calls = <({bool wrapped, bool head})>[];

  @override
  Widget build(BuildContext context) => ReplayableWidget(
    child: child,
    replayOrBuild: (element, {required wrapped, required build}) {
      if (kept case final kept?) return kept;
      final built = build();
      calls.add((wrapped: wrapped, head: built.head));
      return kept = built.node..kept = true;
    },
  );
}

/// A layout hint that counts how often it is asked.
class _Hinted extends StatelessWidget implements LayoutHint {
  _Hinted();
  var asked = 0;

  @override
  bool get fillsWidth {
    asked++;
    return true;
  }

  @override
  Widget build(BuildContext context) => _el('i');
}

class _SubValue extends _Value {
  const _SubValue(super.value, {required super.child});
}

final _log = <String>[];

/// Hands the page, its element and its `build` to the test, which builds
/// under it after the page was written (what `FutureBuilder` does).
class _Later extends PageComponent {
  const _Later(this.keep);
  final void Function(PageBuild, Element, BuildChild) keep;

  @override
  void buildInto(
    PageBuild page,
    Element element,
    ParentNode into,
    BuildChild build,
  ) {
    keep(page, element, build);
    build(const Widget.text('first'), element, into);
  }
}

/// Draws its child, and a template that is not the widget the wrappers above
/// decorate (what a `Draggable` does with its feedback).
class _Pair extends PageComponent {
  const _Pair();

  @override
  void buildInto(
    PageBuild page,
    Element element,
    ParentNode into,
    BuildChild build,
  ) {
    build(_el('p', [const Widget.text('a')]), element, into);
    final template = FragmentNode();
    build(_el('i', [const Widget.text('b')]), element, template, bare: true);
    into.add(ElementNode('template')..children.addAll(template.children));
  }
}

/// Builds [child] in its place, as it is.
class _Through extends PageComponent {
  const _Through(this.child);
  final Widget child;

  @override
  void buildInto(
    PageBuild page,
    Element element,
    ParentNode into,
    BuildChild build,
  ) => build(child, element, into);
}

class _Stateful extends StatefulWidget {
  const _Stateful(this.name, {this.child});
  final String name;
  final Widget? child;
  @override
  State createState() => _StatefulState();
}

class _StatefulState extends State<_Stateful> {
  @override
  void initState() => _log.add('init ${widget.name}');
  @override
  void didChangeDependencies() => _log.add('deps ${widget.name}');
  @override
  Widget build(BuildContext context) {
    _log.add('build ${widget.name} mounted=$mounted');
    return widget.child ?? Widget.text(widget.name);
  }

  @override
  void dispose() => _log.add('dispose ${widget.name}');
}

void main() {
  setUp(_log.clear);

  group('pathological trees', () {
    test('10 000 children, in order', () {
      final html = _html(
        _el('ul', [
          for (var i = 0; i < 10000; i++) _el('li', [Widget.text('$i')]),
        ]),
      );
      expect(RegExp('<li>').allMatches(html), hasLength(10000));
      expect(html, startsWith('<ul><li>0</li><li>1</li>'));
      expect(html, endsWith('<li>9999</li></ul>'));
    });

    test('500 levels of elements and components', () {
      Widget nest(int n) => n == 0
          ? const Widget.text('deep')
          : _Build((_) => _el('div', [nest(n - 1)]));
      final html = _html(nest(500));
      expect(RegExp('<div>').allMatches(html), hasLength(500));
      expect(html, contains('deep'));
    });

    test('a tree too deep for the stack fails with THOR-R020, its depth '
        'and the two ends of its chain', () {
      Widget nest(int n) => n == 0
          ? const Widget.text('deep')
          : _Build((_) => _el('div', [nest(n - 1)]));
      Object? error;
      try {
        _page(_Value('root', child: nest(200000)));
      } on Object catch (e) {
        error = e;
      }
      expect(error, isA<StateError>());
      final message = '$error';
      expect(message, contains('THOR-R020'));
      expect(message, matches(RegExp(r'\d{3,} elements deep')));
      expect(message, contains('_Value > _Build'));
      expect(message, contains('_Build > <div>'));
      expect(message.length, lessThan(2000));
      // The next page renders: nothing is left half-built.
      expect(_html(_el('p')), '<p></p>');
    });

    test('empty fragments, and a component that builds a component that '
        'builds a fragment, leave no trace', () {
      expect(
        _html(
          _el('div', [
            const Widget.empty(),
            const Widget.fragment([]),
            _Build(
              (_) => _Build((_) => const Widget.fragment([Widget.text('x')])),
            ),
            const Widget.fragment([Widget.fragment([])]),
          ]),
        ),
        '<div>x</div>',
      );
    });

    test('text that looks like markup is text', () {
      const nasty =
          '</style><script>alert(1)</script><!-- --> "q" \'a\' & '
          '\u{1F600} \u0000';
      final html = _html(_el('p', [const Widget.text(nasty)]));
      expect(html, isNot(contains('<script>')));
      expect(html, isNot(contains('</style>')));
      expect(html, isNot(contains('<!--')));
      expect(html, contains('&lt;/style&gt;'));
      expect(html, contains('\u{1F600}'));
    });

    test('attribute values cannot leave the attribute', () {
      final html = _html(
        const Widget.element(
          tag: 'a',
          id: '"><script>',
          classes: 'a" onclick="x',
          styles: Styles(raw: {'color': 'red" onload="y'}),
          attributes: {'title': '"><img src=x onerror=z>'},
        ),
      );
      expect(RegExp(r'<[a-z]').allMatches(html), hasLength(1));
      expect(html, isNot(contains('onclick="')));
      expect(html, isNot(contains('onload="')));
    });

    test('a tag or attribute name that could break the markup fails', () {
      expect(() => _html(_el('div onload=x')), throwsArgumentError);
      expect(() => _html(_el('script>')), throwsArgumentError);
      expect(
        () => _html(const Widget.element(tag: 'a', attributes: {'x"y': '1'})),
        throwsArgumentError,
      );
      expect(
        () => _html(const Widget.element(tag: 'a', attributes: {'a b': '1'})),
        throwsArgumentError,
      );
    });

    test('void elements have no closing tag and drop their children', () {
      expect(
        _html(
          _el('div', [
            _el('br'),
            _el('IMG'),
            _el('input', [const Widget.text('x')]),
          ]),
        ),
        '<div><br/><img/><input/></div>',
      );
    });

    test('empty attribute values are bare attributes; attribute order is '
        'id, class, style, then the rest', () {
      expect(
        _html(
          const Widget.element(
            tag: 'details',
            attributes: {'open': '', 'data-x': '1'},
            styles: Styles(raw: {'a': '1', 'b': '2'}),
            classes: 'c',
            id: 'i',
          ),
        ),
        '<details id="i" class="c" style="a: 1; b: 2" open data-x="1"></details>',
      );
    });
  });

  group('wrappers', () {
    test('a wrapper\'s style attribute joins the element\'s styles', () {
      final html = _html(
        const Widget.wrapElement(
          attributes: {'style': '--v: 1; view-transition-name: hero'},
          child: Widget.element(
            tag: 'div',
            styles: Styles(raw: {'color': 'red'}),
          ),
        ),
      );
      expect(
        html,
        '<div style="color: red; --v: 1; view-transition-name: hero"></div>',
      );
    });

    test('nested wrappers merge from the outside in; the element wins', () {
      final html = _html(
        Widget.wrapElement(
          id: 'outer',
          classes: 'o',
          styles: const Styles(raw: {'a': 'outer', 'b': 'outer'}),
          attributes: const {'x': 'outer', 'y': 'outer'},
          child: _Build(
            (_) => const Widget.wrapElement(
              classes: 'i',
              styles: Styles(raw: {'a': 'inner'}),
              attributes: {'x': 'inner'},
              child: Widget.element(
                tag: 'div',
                classes: 'own',
                styles: Styles(raw: {'b': 'own'}),
                attributes: {'y': 'own'},
              ),
            ),
          ),
        ),
      );
      expect(
        html,
        '<div id="outer" class="o i own" style="a: inner; b: own" '
        'x="inner" y="own"></div>',
      );
    });

    test('the element takes the wrappers: its children start clean; '
        'siblings in a fragment each take them', () {
      final html = _html(
        Widget.wrapElement(
          classes: 'w',
          child: Widget.fragment([
            _el('a', [_el('b')]),
            const Widget.text('t'),
            _el('c'),
          ]),
        ),
      );
      expect(html, '<a class="w"><b></b></a>t<c class="w"></c>');
    });

    test('an element id wins over every wrapper id', () {
      expect(
        _html(
          const Widget.wrapElement(
            id: 'w',
            child: Widget.element(tag: 'i', id: 'own'),
          ),
        ),
        '<i id="own"></i>',
      );
    });
  });

  group('lookups', () {
    test('the nearest inherited component of the exact type', () {
      String? seen;
      String? sub;
      _html(
        _Value(
          'far',
          child: _SubValue(
            'sub',
            child: _Value(
              'near',
              child: _Build((context) {
                seen = context
                    .dependOnInheritedWidgetOfExactType<_Value>()
                    ?.value;
                sub = context
                    .dependOnInheritedWidgetOfExactType<_SubValue>()
                    ?.value;
                return const Widget.empty();
              }),
            ),
          ),
        ),
      );
      expect(seen, 'near');
      expect(sub, 'sub');
    });

    test('answers stay right once a node has remembered them', () {
      // Lookups are remembered per node of the inherited chain: a nearer
      // one below, a missing type and a sibling branch must still resolve
      // on their own.
      final seen = <String, String?>{};
      Widget look(String name) => _Build((context) {
        seen[name] = context
            .dependOnInheritedWidgetOfExactType<_Value>()
            ?.value;
        seen['$name sub'] = context
            .dependOnInheritedWidgetOfExactType<_SubValue>()
            ?.value;
        return const Widget.empty();
      });
      _html(
        _Value(
          'far',
          child: Widget.fragment([
            _SubValue('s1', child: Widget.fragment([look('a'), look('b')])),
            _SubValue(
              's2',
              child: Widget.fragment([
                look('c'),
                _Value('near', child: look('d')),
              ]),
            ),
            look('e'),
          ]),
        ),
      );
      expect(seen, {
        'a': 'far',
        'a sub': 's1',
        'b': 'far',
        'b sub': 's1',
        'c': 'far',
        'c sub': 's2',
        'd': 'near',
        'd sub': 's2',
        'e': 'far',
        'e sub': null,
      });
    });

    test('nothing above: null, not a throw', () {
      Object? found = 'unset';
      _html(
        _Build((context) {
          found = context.getElementForInheritedWidgetOfExactType<_Value>();
          return const Widget.empty();
        }),
      );
      expect(found, isNull);
    });

    test('an inherited value is not visible to siblings or above', () {
      final seen = <String?>[];
      Widget probe() => _Build((context) {
        seen.add(context.dependOnInheritedWidgetOfExactType<_Value>()?.value);
        return const Widget.empty();
      });
      _html(Widget.fragment([probe(), _Value('v', child: probe()), probe()]));
      expect(seen, [null, 'v', null]);
    });

    test('ancestors, nearest first, until the visitor says stop', () {
      final names = <String>[];
      _html(
        _Value(
          'a',
          child: _Build(
            (_) => _Build((context) {
              context.visitAncestorElements((e) {
                names.add(e.widget.runtimeType.toString());
                return e.widget is! _Value;
              });
              return const Widget.empty();
            }),
          ),
        ),
      );
      expect(names, ['_Build', '_Value']);
    });
  });

  group('buildingContext', () {
    test('null outside a build; inside, the context being built', () {
      expect(buildingContext(), isNull);
      bool? inside;
      String? seen;
      final html = _html(
        _Value(
          'outer',
          child: _Build((context) {
            inside = identical(buildingContext(), context);
            seen = buildingContext()
                ?.dependOnInheritedWidgetOfExactType<_Value>()
                ?.value;
            return _el('b');
          }),
        ),
      );
      expect(html, '<b></b>');
      expect(inside, isTrue);
      expect(seen, 'outer');
      expect(buildingContext(), isNull);
    });
  });

  group('previewBuild', () {
    test('nothing is previewed outside a build', () {
      expect(previewBuild(_Build((_) => _el('p'))), isNull);
    });

    test('a preview is what the page uses: built once', () {
      var builds = 0;
      final child = _Build((_) {
        builds++;
        return _el('i');
      });
      Widget? seen;
      final html = _html(
        _Build((_) {
          seen = previewBuild(child);
          return _el('b', [child]);
        }),
      );
      expect(html, '<b><i></i></b>');
      expect(seen, isA<Widget>());
      expect(builds, 1);
    });

    test('a lookup that finds another widget at its place: built again', () {
      var builds = 0;
      final child = _Build((context) {
        builds++;
        final v = context.dependOnInheritedWidgetOfExactType<_Value>();
        return Widget.text(v?.value ?? 'none');
      });
      final html = _html(
        _Value(
          'outer',
          child: _Build((_) {
            previewBuild(child);
            return _el('b', [_Value('inner', child: child)]);
          }),
        ),
      );
      expect(html, '<b>inner</b>');
      expect(builds, 2);
    });

    test('a build that throws where the parent is: null, then built', () {
      final child = _Build(
        (context) => Widget.text(
          context.dependOnInheritedWidgetOfExactType<_Value>()!.value,
        ),
      );
      Widget? seen = _el('x');
      final html = _html(
        _Build((_) {
          seen = previewBuild(child);
          return _Value('v', child: child);
        }),
      );
      expect(seen, isNull);
      expect(html, 'v');
    });

    test('one widget in two places: the preview serves one', () {
      var builds = 0;
      final child = _Build((_) {
        builds++;
        return _el('i');
      });
      final html = _html(
        _Build((_) {
          previewBuild(child);
          return _el('b', [child, child]);
        }),
      );
      expect(html, '<b><i></i><i></i></b>');
      expect(builds, 2, reason: 'the preview used once, then built there');
    });

    test('a build that reaches for the page is not previewed', () {
      var builds = 0;
      final child = _Build((_) {
        builds++;
        notePageAccess();
        return _el('i');
      });
      final html = _html(
        _Build((_) => _el('b', [if (previewBuild(child) == null) child])),
      );
      expect(html, '<b><i></i></b>');
      expect(builds, 2, reason: 'the dropped preview, then its place');
    });
  });

  group('layout hints', () {
    test('asked once per widget until cleared', () {
      final w = _Hinted();
      clearLayoutHints();
      expect(layoutFillsWidth(w), isTrue);
      expect(layoutFillsWidth(w), isTrue);
      expect(w.asked, 1);
      clearLayoutHints();
      expect(layoutFillsWidth(w), isTrue);
      expect(w.asked, 2);
      clearLayoutHints();
    });
  });

  group('state', () {
    test('init, dependencies, build in tree order; dispose after the page', () {
      _html(
        _el('div', [
          const _Stateful('a', child: _Stateful('b')),
          const _Stateful('c'),
        ]),
      );
      expect(_log, [
        'init a',
        'deps a',
        'build a mounted=true',
        'init b',
        'deps b',
        'build b mounted=true',
        'init c',
        'deps c',
        'build c mounted=true',
        'dispose a',
        'dispose b',
        'dispose c',
      ]);
    });

    test(
      'a failing build fails the page and still disposes what was built',
      () {
        expect(
          () => _html(
            _el('div', [
              const _Stateful('a'),
              _Build((_) => throw StateError('boom')),
            ]),
          ),
          throwsStateError,
        );
        expect(_log, contains('dispose a'));
      },
    );

    test('setState on the server fails in debug', () {
      expect(
        () => _html(
          _Build((context) {
            _StatefulState().setState(() {});
            return const Widget.empty();
          }),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('a page component and the wrappers above it', () {
    test('what it builds takes them; what it builds bare does not', () {
      expect(
        _html(
          const Widget.wrapElement(attributes: {'data-w': '1'}, child: _Pair()),
        ),
        '<p data-w="1">a</p>\n<template><i>b</i></template>',
      );
    });
  });

  group('mapElementChildren', () {
    test('an element with its children replaced, its own data kept', () {
      final mapped = mapElementChildren(
        Widget.element(
          tag: 'template',
          attributes: const {'data-x': '1'},
          children: [_el('b'), _el('i')],
        ),
        (c) => _el('p', [c]),
      );
      expect(
        _html(mapped!),
        '<template data-x="1"><p><b></b></p><p><i></i></p></template>',
      );
    });

    test('anything else is null', () {
      expect(mapElementChildren(const Widget.text('a'), (c) => c), isNull);
      expect(mapElementChildren(const Widget.fragment([]), (c) => c), isNull);
    });
  });

  group('late builds (streaming)', () {
    late PageBuild page;
    late Element element;
    late BuildChild build;

    String later(Widget widget) => page.late(() {
      final node = FragmentNode();
      build(widget, element, node);
      return utf8.decode(writeChildrenUtf8(node));
    });

    setUp(() {
      _html(
        _Value(
          'v1',
          child: _el('div', [
            _Later((p, e, b) {
              page = p;
              element = e;
              build = b;
            }),
          ]),
        ),
      );
    });

    test('built under the same element: the inherited values are there', () {
      final html = later(
        _Build(
          (c) => _el('b', [
            Widget.text(c.dependOnInheritedWidgetOfExactType<_Value>()!.value),
          ]),
        ),
      );
      expect(html, '<b>v1</b>');
    });

    test('no line break or whitespace between the pieces', () {
      expect(later(Widget.fragment([_el('i'), _el('u')])), '<i></i><u></u>');
    });

    test('the states it creates are disposed when it ends', () {
      _log.clear();
      later(const _Stateful('late'));
      expect(_log, [
        'init late',
        'deps late',
        'build late mounted=true',
        'dispose late',
      ]);
      // The page's own states are not disposed twice.
      _log.clear();
      later(const _Stateful('again'));
      expect(_log.where((l) => l.startsWith('dispose')), ['dispose again']);
    });

    test('a failing build throws and still disposes what was built', () {
      expect(
        () => later(
          _el('div', [
            const _Stateful('a'),
            _Build((_) => throw StateError('boom')),
          ]),
        ),
        throwsStateError,
      );
      expect(_log, contains('dispose a'));
    });
  });

  group('document and head', () {
    Widget head(
      String? title, {
      List<Widget>? children,
      Map<String, String>? meta,
    }) => Document.head(title: title, meta: meta, children: children);

    test('the document: doctype, html, head in order, body', () {
      final page = _page(
        const Document(title: 'T', lang: Locale('es'), body: Widget.text('b')),
      );
      expect(
        page,
        '<!DOCTYPE html>\n<html lang="es"><head><base href="/"/>'
        '<meta charset="utf-8"/><title>T</title>'
        '<meta name="viewport" content="width=device-width, initial-scale=1.0"/>'
        '</head><body>b</body></html>\n',
      );
    });

    test('Document(lang:) writes the locale as its BCP 47 tag', () {
      final page = _page(
        const Document(
          lang: Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
            countryCode: 'TW',
          ),
          base: null,
          charset: null,
          viewport: null,
          body: Widget.text('b'),
        ),
      );
      expect(page, contains('<html lang="zh-Hant-TW">'));
    });

    test('DocumentAttributes set <html> attributes from inside the page, '
        'over the document\'s own', () {
      final page = _page(
        const Document(
          lang: Locale('es'),
          dir: 'ltr',
          base: null,
          charset: null,
          viewport: null,
          body: Widget.fragment([
            Widget.text('b'),
            DocumentAttributes(attributes: {'lang': 'ar', 'dir': 'rtl'}),
          ]),
        ),
      );
      expect(page, contains('<html lang="ar" dir="rtl">'));
      expect(page, contains('<body>b</body>'));
    });

    test('DocumentAttributes leave a standalone fragment without <html>', () {
      final html = writeComponent(
        const Widget.fragment([
          Widget.text('b'),
          DocumentAttributes(attributes: {'lang': 'ar'}),
        ]),
        standalone: true,
        compact: true,
      );
      expect(html.trim(), 'b');
    });

    test(
      'base is normalized with slashes; null base and viewport are left out',
      () {
        expect(
          _page(const Document(base: 'app', body: Widget.empty())),
          contains('<base href="/app/"/>'),
        );
        final page = _page(
          const Document(base: null, viewport: null, body: Widget.empty()),
        );
        expect(page, isNot(contains('<base')));
        expect(page, isNot(contains('viewport')));
      },
    );

    test('a later, deeper duplicate replaces the first in its place; a '
        'later, shallower one is dropped', () {
      final page = _page(
        Document(
          title: 'page',
          body: _el('main', [
            head('deeper'),
            head(
              null,
              children: [
                const Widget.element(
                  tag: 'link',
                  id: 'x',
                  attributes: {'n': '1'},
                ),
              ],
            ),
            head(
              null,
              children: [
                const Widget.element(
                  tag: 'link',
                  id: 'x',
                  attributes: {'n': '2'},
                ),
              ],
            ),
          ]),
        ),
      );
      final inHead = page.substring(
        page.indexOf('<head>'),
        page.indexOf('</head>'),
      );
      expect(RegExp('<title>').allMatches(inHead), hasLength(1));
      expect(inHead, contains('<title>deeper</title>'));
      // Title first: it keeps the place of the document's own title.
      expect(inHead.indexOf('<title>'), lessThan(inHead.indexOf('viewport')));
      expect(inHead, contains('n="2"'));
      expect(inHead, isNot(contains('n="1"')));
      // The portals left nothing in the body.
      expect(
        page.substring(page.indexOf('<body')),
        '<body><main></main></body></html>\n',
      );
    });

    test('a leading portal goes to the start of the head, after the base and '
        'the charset, before the document\'s own head elements', () {
      final page = _page(
        Document(
          title: 'page',
          head: const [
            Widget.element(tag: 'link', attributes: {'rel': 'stylesheet'}),
          ],
          body: _el('main', [
            head('later'),
            const HeadPortal(
              leading: true,
              children: [
                Widget.element(tag: 'script', id: 's', attributes: {'n': '1'}),
              ],
            ),
            const HeadPortal(
              leading: true,
              children: [
                Widget.element(tag: 'script', id: 's', attributes: {'n': '2'}),
              ],
            ),
          ]),
        ),
      );
      final inHead = page.substring(
        page.indexOf('<head>'),
        page.indexOf('</head>'),
      );
      expect(
        inHead,
        startsWith(
          '<head><base href="/"/><meta charset="utf-8"/>'
          '<script id="s" n="2"></script><link rel="stylesheet"/>',
        ),
      );
      // A duplicate id is still one element; the others stay at the end.
      expect(RegExp('id="s"').allMatches(inHead), hasLength(1));
      expect(
        inHead,
        endsWith(
          '<title>later</title>'
          '<meta name="viewport" content="width=device-width, initial-scale=1.0"/>',
        ),
      );
    });

    test('a shallower duplicate after a deeper one does not replace it', () {
      final page = _page(
        Document(
          body: Widget.fragment([
            _Build((_) => _Build((_) => head(null, meta: {'k': 'deep'}))),
            head(null, meta: {'k': 'shallow'}),
          ]),
        ),
      );
      expect(page, contains('content="deep"'));
      expect(page, isNot(contains('content="shallow"')));
    });

    test('a standalone fragment gets no document; a page without one gets '
        'html, head and body around it', () {
      expect(_html(const Widget.text('x')), 'x');
      expect(
        _page(Widget.fragment([_el('p'), head('t')])),
        '<!DOCTYPE html>\n<html><head><title>t</title>'
        '</head><body><p></p></body></html>\n',
      );
    });

    test('the app stylesheet goes last in the head, after the portal content, '
        'minified when compact', () {
      final page = writeComponent(
        const Document(body: Widget.empty()),
        styles: [
          // The stylesheet writes raw values as given.
          // ignore: thor_lints/avoid_raw_css
          css('.a').styles(raw: {'color': 'red'}),
        ],
        compact: true,
      );
      expect(
        page,
        contains('initial-scale=1.0"/><style>.a{color:red;}</style></head>'),
      );
    });
  });

  group('keys and listenables', () {
    test('value keys compare by value and type; unique keys by identity', () {
      expect(const ValueKey(1), const ValueKey(1));
      expect(const ValueKey(1), isNot(const ValueKey('1')));
      expect(UniqueKey(), isNot(UniqueKey()));
      expect(GlobalKey().currentState, isNull);
    });

    test('a value notifier notifies on change only; a listener added while '
        'notifying runs from the next change', () {
      final n = ValueNotifier(0);
      final calls = <int>[];
      void added() => calls.add(-1);
      n.addListener(() {
        calls.add(n.value);
        n.addListener(added);
      });
      n
        ..value = 0
        ..value = 1
        ..value = 2;
      expect(calls, [1, 2, -1]);
    });

    test('a disposed notifier is not usable', () {
      final n = ChangeNotifier()..dispose();
      expect(() => n.addListener(() {}), throwsA(isA<AssertionError>()));
    });
  });

  group('indented (debug) output', () {
    test('short content stays on one line; long content breaks', () {
      expect(
        _page(_el('div', [_el('i')]), compact: false),
        contains('<div><i></i></div>'),
      );
      final long = _page(
        _el('div', [
          for (var i = 0; i < 10; i++) _el('section', [Widget.text('item $i')]),
        ]),
        compact: false,
      );
      expect(long, contains('<div>\n'));
      expect(long, contains('\n      <section>item 0</section>'));
    });

    test('a textarea keeps its value byte for byte', () {
      for (final value in ['one\ntwo', '${'long ' * 30}\nend']) {
        final tree = _el('div', [
          _el('textarea', [Widget.text(value)]),
          _el('p'),
        ]);
        final pretty = _page(tree, compact: false);
        expect(pretty, contains('<textarea>$value</textarea>'));
      }
    });

    test('a span keeps its content as it is', () {
      final page = _page(
        _el('span', [
          for (var i = 0; i < 20; i++) _el('b', [Widget.text('word $i')]),
        ]),
        compact: false,
      );
      final span = page.substring(
        page.indexOf('<span>'),
        page.indexOf('</span>'),
      );
      expect(span, isNot(contains('\n')));
    });
  });

  group('replayed subtrees', () {
    test('a kept fragment writes the same HTML at every place and page', () {
      final replay = _Replay(
        _el('ul', [
          for (var i = 0; i < 3; i++) _el('li', [Widget.text('<$i> & "x"')]),
        ]),
      );
      Widget page() => _el('main', [replay, _el('hr'), replay]);
      final first = _page(page());
      expect(first, contains('<ul><li>&lt;0&gt; &amp; "x"</li>'));
      expect(
        RegExp('<ul>').allMatches(first).length,
        2,
        reason: 'the same nodes, twice in one page',
      );
      expect(_page(page()), first);
      // Indented: written at each place's depth, not the first one's.
      expect(
        _page(_el('div', [replay]), compact: false),
        _page(_el('div', [replay.child]), compact: false),
      );
      expect(replay.calls, hasLength(1));
    });

    test('its build sees the wrappers above and reports head content', () {
      final wrapped = _Replay(_el('b'));
      expect(
        _html(Widget.wrapElement(classes: 'w', child: wrapped)),
        '<b class="w"></b>',
      );
      expect(wrapped.calls.single, (wrapped: true, head: false));

      final head = _Replay(const Document.head(title: 'x'));
      expect(_page(head), contains('<title>x</title>'));
      expect(head.calls.single, (wrapped: false, head: true));
    });

    test('wrappers and inherited values reach it through a page '
        'component', () {
      final replay = _Replay(
        _Build(
          (context) => _el('b', [
            Widget.text(
              context.dependOnInheritedWidgetOfExactType<_Value>()!.value,
            ),
          ]),
        ),
      );
      Widget page() => _Value(
        'v',
        child: Widget.wrapElement(classes: 'w', child: _Through(replay)),
      );
      expect(_html(page()), '<b class="w">v</b>');
      expect(_html(page()), '<b class="w">v</b>');
      expect(replay.calls.single, (wrapped: true, head: false));
    });

    test('an error while building it propagates', () {
      final failing = _Replay(_Build((_) => throw StateError('boom')));
      expect(() => _html(failing), throwsStateError);
      expect(failing.kept, isNull);
    });
  });

  group('UTF-8 writer', () {
    // What a release server sends must be the bytes of the compact string
    // writer, for any text: escapes, every UTF-8 length, broken surrogates.
    void same(RootNode root) => expect(
      writePageUtf8(root),
      utf8.encode(writePage(root, compact: true)),
    );

    ElementNode el(
      String tag, {
      String? id,
      String? classes,
      Map<String, String>? styles,
      Map<String, String>? attributes,
      List<Node> children = const [],
    }) {
      final e = ElementNode(
        tag,
        id: id,
        classes: classes,
        styles: styles,
        attributes: attributes,
      );
      children.forEach(e.add);
      return e;
    }

    const texts = [
      '',
      'plain ascii',
      '<script>&"\'/ stays text</script>',
      'café, niño, ¿qué?', // 2 bytes
      '→ • … € 中文', // 3 bytes
      '😀 emoji 👩‍💻', // surrogate pairs: 4 bytes
      '\uD800 lone high, \uDC00 lone low, end \uD83D', // U+FFFD each
      '&amp; already escaped &lt;',
    ];

    test('text, raw text and attributes of every kind', () {
      for (final t in texts) {
        same(
          RootNode()
            ..add(TextNode('<!DOCTYPE html>', raw: true))
            ..add(
              el(
                'DIV',
                id: t,
                classes: 'a $t',
                styles: {'content': '"$t"', 'color': 'red'},
                attributes: {'data-x': t, 'hidden': '', 'title': '"$t"'},
                children: [
                  TextNode(t),
                  TextNode(t, raw: true),
                  el('br'),
                  el('img', attributes: {'alt': t}),
                  el('p', children: [TextNode('a'), el('span')]),
                ],
              ),
            ),
        );
      }
    });

    test('a scroll view mark becomes a tab stop, the same in every writer', () {
      RootNode page(List<Node> inside, {Map<String, String>? more}) =>
          RootNode()..add(
            el(
              'div',
              attributes: {scrollFocusAttr: '', ...?more},
              children: inside,
            ),
          );
      String both(RootNode root) {
        same(root);
        return writePage(root, compact: true);
      }

      expect(both(page([TextNode('x')])), '<div tabindex="0">x</div>\n');
      // Named by the app: a region.
      expect(
        both(page([TextNode('x')], more: {'aria-label': 'Rows'})),
        '<div tabindex="0" role="region" aria-label="Rows">x</div>\n',
      );
      // Something to tab to inside: no stop of its own.
      for (final inside in [
        el('a', attributes: {'href': '/x'}),
        el('button'),
        el('input', attributes: {'type': 'text'}),
        el('span', attributes: {'tabindex': '0'}),
        el('div', children: [el('summary')]),
      ]) {
        expect(both(page([inside])), startsWith('<div>'));
      }
      // …but not what a keyboard skips.
      for (final inside in [
        el('a'),
        el('button', attributes: {'disabled': ''}),
        el('input', attributes: {'type': 'hidden'}),
        el('span', attributes: {'tabindex': '-1'}),
      ]) {
        expect(both(page([inside])), startsWith('<div tabindex="0">'));
      }
      // What a `<template>` holds is not in the page yet.
      expect(
        both(page([el('template', attributes: {})..add(el('button'))])),
        startsWith('<div tabindex="0">'),
      );
      // Raw HTML is read for what it may hold.
      expect(
        both(page([TextNode('<button>x</button>', raw: true)])),
        startsWith('<div>'),
      );
    });

    test('fragments, kept fragments written twice, and a long page', () {
      final kept = FragmentNode()
        ..kept = true
        ..add(el('b', children: [TextNode('kept → 😀 &')]));
      final big = el('main');
      for (var i = 0; i < 2000; i++) {
        big.add(el('li', classes: 'c$i', children: [TextNode(texts[i % 8])]));
      }
      same(
        RootNode()
          ..add(FragmentNode()..add(el('i')))
          ..add(kept)
          ..add(el('section', children: [kept]))
          ..add(big),
      );
    });

    test('a long raw text written again keeps its bytes', () {
      // The same instance page after page (a cached stylesheet), an equal
      // copy, and texts of every UTF-8 length past the size kept.
      for (final t in texts.skip(1)) {
        final long = List.filled(600 ~/ t.length + 1, t).join();
        final copy = String.fromCharCodes(long.codeUnits);
        for (var page = 0; page < 3; page++) {
          for (final raw in [long, copy, long]) {
            same(
              RootNode()..add(
                el('style', children: [TextNode(raw, raw: true), el('i')]),
              ),
            );
          }
        }
      }
      // Hundreds of different long texts, each written twice: the kept
      // bytes stay bounded and right.
      for (var i = 0; i < 600; i++) {
        final t = 'é$i ${'x' * 600}';
        same(RootNode()..add(TextNode(t, raw: true)));
        same(RootNode()..add(TextNode(t, raw: true)));
      }
    });

    test('a page built from widgets', () {
      final root = RootNode();
      final page = PageBuild();
      page.buildRoot(
        const Document(
          title: 'títle → 😀',
          body: Widget.element(
            tag: 'p',
            attributes: {'data-q': '"q" & <q>'},
            children: [Widget.text('cuerpo <b> & ¿qué? 😀 \uD800')],
          ),
        ),
        root,
      );
      page.dispose();
      same(root);
    });
  });

  group('type paths', () {
    // Where each _Build sits, by its label, for a page of [root].
    Map<String, TypePath> paths(Widget Function(Widget Function(String)) root) {
      final found = <String, TypePath>{};
      Widget at(String label) => _Build((context) {
        found[label] = typePathOf(context as Element);
        return Widget.text(label);
      });
      final page = PageBuild();
      page.buildRoot(root(at), RootNode());
      page.dispose();
      return found;
    }

    test('the same types above are the same path, on any page', () {
      final a = paths(
        (at) => _el('main', [
          _el('div', [at('x')]),
        ]),
      );
      final b = paths(
        (at) => _el('main', [
          _el('p'),
          _el('div', [at('x')]),
        ]),
      );
      // Siblings don't matter; the types from the root down do.
      expect(identical(a['x'], b['x']), isTrue);
    });

    test('another type at any level is another path', () {
      final a = paths(
        (at) => _el('main', [
          _el('div', [at('x')]),
        ]),
      );
      final b = paths((at) => _Value('v', child: _el('div', [at('x')])));
      final c = paths(
        (at) => _el('main', [
          _Value('v', child: _el('div', [at('x')])),
        ]),
      );
      expect(identical(a['x'], b['x']), isFalse);
      expect(identical(a['x'], c['x']), isFalse);
      expect(identical(b['x'], c['x']), isFalse);
      var depth = 0;
      for (TypePath? p = c['x']; p != null; p = p.parent) {
        depth++;
      }
      expect(depth, greaterThan(3));
    });
  });

  group('widget trace', () {
    test('marks the element a widget built, with its type and key', () {
      final trace = WidgetTrace();
      PageBuild.trace = trace;
      final String html;
      try {
        html = _html(
          _el('main', [
            const _Build(_leaf),
            const _Keyed(key: ValueKey('k'), child: _Build(_leaf)),
          ]),
        );
      } finally {
        PageBuild.trace = null;
      }
      expect(RegExp('data-thor-w="').allMatches(html), hasLength(2));
      final keyed = trace.widgets.where((w) => w.key == const ValueKey('k'));
      expect(keyed.single.type, _Keyed);
      expect(trace.widgets.map((w) => w.type), contains(_Build));
    });

    test('writes nothing when it is off', () {
      expect(PageBuild.trace, isNull);
      expect(_html(const _Build(_leaf)), isNot(contains('data-thor-w')));
    });
  });

  group('adaptive markers', () {
    setUpAll(ui.initializeThorTests);

    // The internal marker of a value with variants (`⟦base␟c640␞value⟧`)
    // is split into conditions of the class: none reaches the stylesheet.
    test('never reach the stylesheet', () async {
      // A parent that turns from column to row at a container width grants
      // its child `align-self` per direction; a wrapper sets the same
      // property for that width: both are one marker, not a marker in one.
      final html = await ui.renderDocument(
        ui.ThorApp(
          child: ui.LayoutScope(
            child: ui.Column(
              crossAxisAlignment: ui.CrossAxisAlignment.stretch,
              layout: const ui.FlexLayout().when(
                container: {
                  640: const ui.FlexLayout(direction: ui.Axis.horizontal),
                },
              ),
              children: [
                ui.Styled(
                  style: const ui.StyleProps().when(
                    container: {
                      640: const ui.StyleProps(
                        alignSelf: ui.CrossAxisAlignment.stretch,
                      ),
                    },
                  ),
                  child: const ui.SizedBox.expand(child: ui.Text('a')),
                ),
              ],
            ),
          ),
        ),
      );
      for (final marker in ['\u27e6', '\u27e7', '\u241f', '\u241e']) {
        expect(html, isNot(contains(marker)));
      }
      expect(
        html,
        matches(
          RegExp(
            r'\{[^}]*align-self: stretch[^}]*\}'
            r'@container \(min-width: 640px\)\{[^@]*align-self: stretch',
          ),
        ),
      );
    });

    test('are in no recorded golden', () {
      final golden = Directory('../../test/golden');
      if (!golden.existsSync()) return;
      final marker = RegExp('[\u27e6\u27e7\u241f\u241e]');
      final leaks = [
        for (final f in golden.listSync(recursive: true).whereType<File>())
          if (RegExp(r'\.(css|html)$').hasMatch(f.path) &&
              marker.hasMatch(f.readAsStringSync()))
            f.path,
      ];
      expect(leaks, isEmpty);
    });
  });
}

Widget _leaf(BuildContext context) => _el('span');

class _Keyed extends StatelessWidget {
  const _Keyed({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

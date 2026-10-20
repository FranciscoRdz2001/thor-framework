import 'dart:async';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;
import 'package:test_api/scaffolding.dart' as scaffolding;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart' show Key, Widget;

import 'finders.dart';
import 'test_client.dart';

final _testerKey = Object();

/// The widget tester of [testThor]: Flutter's `WidgetTester` over the
/// HTML a widget renders (no engine, no browser).
///
/// It drives what a visitor with no JavaScript can do: read the page
/// ([pumpWidget], [visit]), fill a form ([enterText]) and submit it or
/// follow a link ([tap]). What the browser does (a `ThorState` method run by
/// the lite engine) is not run here: test that in Chrome.
class ThorTester {
  ThorTester._();

  /// The tester of the running [testThor] body, for [Finder]s.
  static ThorTester get current {
    final tester = Zone.current[_testerKey];
    if (tester is! ThorTester) {
      throw StateError(
        'No ThorTester: a Finder only works inside testThor(...).',
      );
    }
    return tester;
  }

  dom.DocumentFragment _fragment = dom.DocumentFragment();
  String _html = '';
  Expando<List<({Type type, Key? key})>> _widgets = Expando('widgets');
  ThorTestClient? _client;
  ThorTestResponse? _response;

  /// The rendered page of the last [pumpWidget] or [visit] (empty before).
  dom.DocumentFragment get fragment => _fragment;

  /// The rendered HTML of the last [pumpWidget]; for [visit] and [tap], the
  /// full response document (`<head>` and `<body>`).
  String get html => _html;

  /// The last answer the server gave to [visit] or [tap], or null.
  ThorTestResponse? get response => _response;

  static final _marker = RegExp(' ${WidgetTrace.attribute}="[0-9 ]*"');

  /// Renders [widget] to HTML, replacing what was rendered before.
  ///
  /// `// web:` there is no frame loop: this is one server render, the
  /// HTML a visitor with no JavaScript gets. The render also records which
  /// widgets built each element (with the render caches off), for
  /// `find.byType` and `find.byKey`.
  Future<void> pumpWidget(Widget widget) async {
    final traced = await renderHtmlTraced(widget);
    _widgets = Expando('widgets');
    _response = null;
    _html = traced.html.replaceAll(_marker, '');
    _fragment = parser.parseFragment(traced.html);
    void walk(dom.Node node) {
      if (node is dom.Element) {
        final indexes = node.attributes.remove(WidgetTrace.attribute);
        if (indexes != null) {
          _widgets[node] = [
            for (final i in indexes.split(' ')) traced.widgets[int.parse(i)],
          ];
        }
      }
      node.nodes.forEach(walk);
    }

    _fragment.nodes.forEach(walk);
  }

  /// The widgets that built [element], innermost first: what `find.byType`
  /// and `find.byKey` read. Empty for a page that came from a server
  /// ([visit], [tap]), which keeps no widget tree.
  List<({Type type, Key? key})> widgetsOf(dom.Element element) =>
      _widgets[element] ?? const [];

  /// Loads the page at [path] of [client]'s app (redirects followed) as
  /// what the tester shows, and makes [client] the one [tap] talks to.
  ///
  /// `// web:` the page comes from the server as HTML, so there is no widget
  /// tree: `find.byType` and `find.byKey` find nothing on it.
  Future<void> visit(ThorTestClient client, String path) async {
    _client = client;
    _show(await client.get(path, follow: true));
  }

  void _show(ThorTestResponse response) {
    _response = response;
    _widgets = Expando('widgets');
    _html = response.text;
    _fragment = parser.parseFragment(_html);
  }

  /// Does nothing: there is no frame loop, so everything has already
  /// happened when an `await` returns. Here for tests ported from Flutter.
  Future<void> pump([Duration? duration]) async {}

  /// Does nothing, like [pump], and returns 0 frames.
  Future<int> pumpAndSettle() async => 0;

  /// The single element [finder] finds; fails if there are none or many.
  dom.Element element(Finder finder) {
    final found = finder.evaluate().toList();
    if (found.length != 1) {
      throw StateError(
        'Expected one element for ${finder.description}, '
        'found ${found.length}.',
      );
    }
    return found.single;
  }

  /// The HTML of the single element [finder] finds (`outerHtml`), to check
  /// attributes: `expect(tester.widgetHtml(find.text('Go')), contains('type="button"'))`.
  String widgetHtml(Finder finder) => element(finder).outerHtml;

  /// Sets what a visitor would type in the form field [finder] finds: an
  /// `<input>` (its `value`), a `<textarea>` (its text) or a `<select>` (the
  /// option whose `value` or text is [text]). A later [tap] on the form's
  /// submit button sends it.
  ///
  /// `// web:` it only changes the HTML the tester holds; nothing runs
  /// `onChanged` (a `ThorState` method, see [tap]). For a checkbox or radio
  /// use [tap], which toggles `checked`.
  Future<void> enterText(Finder finder, String text) async {
    final field = element(finder);
    switch (field.localName) {
      case 'textarea':
        field.nodes
          ..clear()
          ..add(dom.Text(text));
      case 'select':
        final options = field.querySelectorAll('option');
        final match = options.where(
          (o) => (o.attributes['value'] ?? o.text.trim()) == text,
        );
        if (match.isEmpty) {
          throw StateError('The ${finder.description} has no option "$text".');
        }
        for (final o in options) {
          o.attributes.remove('selected');
        }
        match.first.attributes['selected'] = '';
      case 'input':
        final type = (field.attributes['type'] ?? 'text').toLowerCase();
        if (const {
          'checkbox',
          'radio',
          'file',
          'submit',
          'button',
          'image',
        }.contains(type)) {
          throw StateError(
            'enterText cannot type into <input type="$type"> '
            '(${finder.description}).',
          );
        }
        field.attributes['value'] = text;
      default:
        throw StateError(
          'enterText needs an input, a textarea or a select; '
          '${finder.description} is a <${field.localName}>.',
        );
    }
  }

  /// Taps the element [finder] finds the way a visitor with no JavaScript
  /// would: a submit button (or any element inside one) sends its form, a
  /// link (or an element inside one) is followed, a checkbox or radio is
  /// toggled. The answer (redirects followed) becomes the page the tester
  /// shows and [response] holds it.
  ///
  /// Sending and following need a server: call [visit] first.
  ///
  /// `// web:` this is the no-JavaScript path only. A button whose
  /// `onPressed` runs a `ThorState` method does its work in the browser
  /// (the lite engine); `ThorTester` does not run it and `tap` throws a
  /// [StateError] saying so. Test that in Chrome (`dart test -p chrome`, see
  /// docs/guia/en/testing.md).
  Future<void> tap(Finder finder) async {
    final target = element(finder);
    final control = _closest(target, const {'button', 'input', 'a'});
    if (control != null) {
      if (control.localName == 'input') {
        final type = (control.attributes['type'] ?? 'text').toLowerCase();
        if (type == 'checkbox') return _toggle(control);
        if (type == 'radio') return _check(control);
      }
      if (control.localName == 'a') {
        final href = control.attributes['href'];
        if (href != null && href.isNotEmpty && !href.startsWith('#')) {
          final client = _needClient(finder);
          final uri = (client.location ?? client.origin).resolve(href);
          if (uri.scheme == 'http' || uri.scheme == 'https') {
            _show(await client.get(uri.toString(), follow: true));
            return;
          }
        }
      } else if (_submits(control)) {
        final form = _formOf(control);
        if (form != null) return _submit(form, control, finder);
      }
    }
    throw StateError(
      'tap(${finder.description}) has nothing to do without JavaScript: it '
      'is not a submit button, a link, a checkbox or a radio. If its '
      'onPressed runs a ThorState method, that runs in the browser (lite '
      'engine), not in ThorTester: test it with `dart test -p chrome`.',
    );
  }

  ThorTestClient _needClient(Finder finder) =>
      _client ??
      (throw StateError(
        'tap(${finder.description}) needs a server to send or follow: '
        "call tester.visit(handler.client(), '/path') first.",
      ));

  static dom.Element? _closest(dom.Element from, Set<String> tags) {
    for (dom.Element? e = from; e != null; e = e.parent) {
      if (tags.contains(e.localName)) return e;
    }
    return null;
  }

  static bool _submits(dom.Element control) {
    final type = control.attributes['type']?.toLowerCase();
    return switch (control.localName) {
      'button' => type == null || type == 'submit',
      'input' => type == 'submit' || type == 'image',
      _ => false,
    };
  }

  dom.Element? _formOf(dom.Element control) {
    final id = control.attributes['form'];
    if (id != null) return _fragment.querySelector('form[id="$id"]');
    return _closest(control, const {'form'});
  }

  static void _toggle(dom.Element box) {
    if (box.attributes.containsKey('checked')) {
      box.attributes.remove('checked');
    } else {
      box.attributes['checked'] = '';
    }
  }

  void _check(dom.Element radio) {
    final name = radio.attributes['name'];
    if (name != null) {
      for (final other in _fragment.querySelectorAll('input[type="radio"]')) {
        if (other.attributes['name'] == name) {
          other.attributes.remove('checked');
        }
      }
    }
    radio.attributes['checked'] = '';
  }

  /// The fields a browser sends for [form], in document order.
  Map<String, List<String>> _fieldsOf(dom.Element form) {
    final fields = <String, List<String>>{};
    void add(String name, String value) => (fields[name] ??= []).add(value);
    final id = form.id;
    final controls = [
      ...form.querySelectorAll('input, textarea, select'),
      if (id.isNotEmpty)
        ..._fragment
            .querySelectorAll(
              'input[form="$id"], textarea[form="$id"], '
              'select[form="$id"]',
            )
            .where((e) => !form.contains(e)),
    ];
    for (final c in controls) {
      final name = c.attributes['name'];
      if (name == null ||
          name.isEmpty ||
          c.attributes.containsKey('disabled')) {
        continue;
      }
      switch (c.localName) {
        case 'textarea':
          add(name, c.text);
        case 'select':
          final options = c.querySelectorAll('option');
          var picked = options
              .where((o) => o.attributes.containsKey('selected'))
              .toList();
          if (picked.isEmpty &&
              options.isNotEmpty &&
              !c.attributes.containsKey('multiple')) {
            picked = [options.first];
          }
          for (final o in picked) {
            add(name, o.attributes['value'] ?? o.text.trim());
          }
        case 'input':
          final type = (c.attributes['type'] ?? 'text').toLowerCase();
          if (const {
            'submit',
            'button',
            'image',
            'reset',
            'file',
          }.contains(type)) {
            continue;
          }
          final toggle = type == 'checkbox' || type == 'radio';
          if (toggle && !c.attributes.containsKey('checked')) continue;
          add(name, c.attributes['value'] ?? (toggle ? 'on' : ''));
      }
    }
    return fields;
  }

  Future<void> _submit(
    dom.Element form,
    dom.Element submitter,
    Finder finder,
  ) async {
    final client = _needClient(finder);
    final fields = _fieldsOf(form);
    final submitName = submitter.attributes['name'];
    if (submitName != null && submitName.isNotEmpty) {
      (fields[submitName] ??= []).add(submitter.attributes['value'] ?? '');
    }
    final method =
        (submitter.attributes['formmethod'] ??
                form.attributes['method'] ??
                'get')
            .toLowerCase();
    final action =
        submitter.attributes['formaction'] ?? form.attributes['action'] ?? '';
    final base = client.location ?? client.origin;
    final target = base.resolve(action.isEmpty ? base.path : action);
    if (method == 'post') {
      final body = {
        for (final e in fields.entries)
          e.key: e.value.length == 1 ? e.value.single : e.value,
      };
      _show(await client.post(target.toString(), form: body, follow: true));
    } else {
      final query = [
        for (final e in fields.entries)
          for (final v in e.value)
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(v)}',
      ].join('&');
      _show(
        await client.get(target.replace(query: query).toString(), follow: true),
      );
    }
  }
}

/// Flutter's `testWidgets` for Thor: [body] gets a [ThorTester] and the
/// `find` finders work inside it.
///
/// ```dart
/// testThor('says hi', (tester) async {
///   await tester.pumpWidget(const Text('Hi'));
///   expect(find.text('Hi'), findsOneWidget);
/// });
/// ```
void testThor(
  Object description,
  Future<void> Function(ThorTester tester) body, {
  Object? skip,
  scaffolding.Timeout? timeout,
  dynamic tags,
}) {
  scaffolding.test(
    description,
    () {
      initializeThorTests();
      final tester = ThorTester._();
      return runZoned(() => body(tester), zoneValues: {_testerKey: tester});
    },
    skip: skip,
    timeout: timeout,
    tags: tags,
  );
}

@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_ui/src/foundation/style_registry.dart';
import 'package:web/web.dart' as web;

/// The `margin-top` of each element with an id in [markup], under the
/// descendant rules of [root] (`p` → 14px) written as thor writes them.
Map<String, String> marginsWith(
  String markup, {
  String root = 'x',
  String extra = '',
}) {
  final style = web.document.createElement('style')
    ..textContent =
        '$thorLayerOrder'
        '${ThorStyleRegistry.renderRule(root, const {'display': 'block'}, conditions: const [
          ConditionalCss(CssCondition.descendant('p'), {'margin-top': '14px'}),
        ])}'
        '$extra';
  final host = web.document.createElement('div')..innerHTML = markup.toJS;
  web.document.head!.append(style);
  web.document.body!.append(host);
  try {
    final out = <String, String>{};
    final found = host.querySelectorAll('[id]');
    for (var i = 0; i < found.length; i++) {
      final el = found.item(i)! as web.Element;
      out[el.id] = web.window.getComputedStyle(el).marginTop;
    }
    return out;
  } finally {
    style.remove();
    host.remove();
  }
}

void main() {
  test('raw HTML inside gets the rule, a nested thor element does not', () {
    final m = marginsWith(
      '<div class="x"><p id="raw">a</p>'
      '<p id="widget" class="w" data-tb>card text</p>'
      '<div class="w" data-tb><p id="inside">inside the card</p></div></div>',
    );
    expect(m['raw'], '14px');
    // The browser's own paragraph margin (16px), not the rule's.
    expect(m['widget'], '16px', reason: 'a thor element is the limit');
    expect(m['inside'], '16px', reason: 'and so is what it holds');
  });

  test('before: a plain descendant selector reached nested widgets', () {
    // What a plain `.x p{…}` rule does to the same markup.
    final style = web.document.createElement('style')
      ..textContent = '.x p{margin-top:14px}';
    final host = web.document.createElement('div')
      ..innerHTML =
          '<div class="x"><p class="w" data-tb id="widget">card</p></div>'.toJS;
    web.document.head!.append(style);
    web.document.body!.append(host);
    final widget = host.querySelector('#widget')!;
    expect(web.window.getComputedStyle(widget).marginTop, '14px');
    style.remove();
    host.remove();
  });

  test('a scope inside a thor element still styles its own prose', () {
    // A Prose inside a Card inside another Prose: the Card is a limit of
    // the outer rules only.
    final m = marginsWith(
      '<div class="x"><div data-tb>'
      '<div class="y" data-tb><p id="inner">inner prose</p></div>'
      '</div></div>',
      extra: ThorStyleRegistry.renderRule(
        'y',
        const {'display': 'block'},
        conditions: const [
          ConditionalCss(CssCondition.descendant('p'), {'margin-top': '9px'}),
        ],
      ),
    );
    expect(m['inner'], '9px');
  });

  test('a list of relative selectors reaches each item', () {
    final style = web.document.createElement('style')
      ..textContent =
          '$thorLayerOrder'
          '${ThorStyleRegistry.renderRule('x', const {'display': 'block'}, conditions: const [
            ConditionalCss(CssCondition.descendant('> :first-child, > div > p'), {'margin-top': '0px'}),
          ])}';
    final host = web.document.createElement('div')
      ..innerHTML =
          '<div class="x"><p id="first">a</p><div><p id="nested">b</p></div>'
                  '<p id="other">c</p></div>'
              .toJS;
    web.document.head!.append(style);
    web.document.body!.append(host);
    String top(String id) =>
        web.window.getComputedStyle(host.querySelector('#$id')!).marginTop;
    try {
      expect(top('first'), '0px');
      expect(top('nested'), '0px');
      expect(top('other'), '16px', reason: 'the browser default');
    } finally {
      style.remove();
      host.remove();
    }
  });

  test('the limit adds no specificity: a thor class still wins', () {
    // Same layer, the element's own class written first: `.x p` (0,1,1)
    // beats `.w` (0,1,0) only for raw HTML, never for the limit itself.
    final m = marginsWith(
      '<div class="x"><p id="raw" class="app">a</p></div>',
      extra: '@layer thor.props{.app{margin-top:3px}}',
    );
    expect(m['raw'], '14px', reason: 'same specificity as before: .x p');
  });
}

@TestOn('browser')
library;

import 'package:test/test.dart';
import 'package:thor_ui/src/foundation/style_registry.dart' show thorLayerOrder;
import 'package:web/web.dart' as web;

/// The color [css] gives `<p class="x">` in a real cascade.
String colorWith(String css) {
  final style = web.document.createElement('style')..textContent = css;
  final p = web.document.createElement('p')..className = 'x';
  web.document.head!.append(style);
  web.document.body!.append(p);
  try {
    return web.window.getComputedStyle(p).color;
  } finally {
    style.remove();
    p.remove();
  }
}

const red = 'rgb(255, 0, 0)';
const green = 'rgb(0, 128, 0)';

void main() {
  test('each thor layer beats the ones before it', () {
    const layers = [
      'thor.reset',
      'thor.tokens',
      'thor.components',
      'thor.props',
      'thor.overrides',
    ];
    for (var i = 1; i < layers.length; i++) {
      // Written in the opposite order: only the stated order may decide.
      expect(
        colorWith(
          '$thorLayerOrder'
          '@layer ${layers[i]}{.x{color:green}}'
          '@layer ${layers[i - 1]}{.x{color:red}}',
        ),
        green,
        reason: '${layers[i]} over ${layers[i - 1]}',
      );
    }
  });

  test('an unlayered app stylesheet beats every thor layer', () {
    expect(
      colorWith(
        '$thorLayerOrder.x{color:green}@layer thor.overrides{.x{color:red}}',
      ),
      green,
    );
  });

  test('a rule straight in @layer thor would beat widget props', () {
    // Why css.layer(name: 'thor') is written as thor.reset.
    expect(
      colorWith(
        '$thorLayerOrder@layer thor.props{.x{color:green}}'
        '@layer thor{.x{color:red}}',
      ),
      red,
    );
  });

  test('the order holds when a linked sheet comes first', () {
    // A shared stylesheet states the order before the page's.
    final shared = web.document.createElement('style')
      ..textContent = '$thorLayerOrder@layer thor.props{.x{color:green}}';
    web.document.head!.append(shared);
    // ignore: unnecessary_lambdas
    addTearDown(() => shared.remove());
    expect(colorWith('$thorLayerOrder@layer thor.reset{.x{color:red}}'), green);
  });

  test('module sheets: after the base, the deepest wins and every one '
      'beats thor', () {
    // The <head> of a page in group b inside group a: base, module a,
    // module b, then the page's own classes.
    final sheets = [
      '$thorLayerOrder@layer thor.components{.x{color:red}}.x{color:red}',
      '.x{color:red}',
      '.x{color:green}',
    ].map((css) => web.document.createElement('style')..textContent = css);
    for (final s in sheets) {
      web.document.head!.append(s);
      // ignore: unnecessary_lambdas
      addTearDown(() => s.remove());
    }
    expect(colorWith('$thorLayerOrder@layer thor.props{.x{color:red}}'), green);
  });

  test('a component sheet gives way to the element props', () {
    expect(
      colorWith(
        '$thorLayerOrder@layer thor.props{.x{color:green}}'
        '@layer thor.components{.x{color:red}}',
      ),
      green,
    );
  });
}

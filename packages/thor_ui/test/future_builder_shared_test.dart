@TestOn('vm')
library;

// One future shown in two places (the variants of a `ResponsiveLayout`): the
// late piece is drawn and sent once, and fills both.
import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Widget _result(BuildContext context, AsyncSnapshot<String> snap) => snap.hasData
    ? Column(
        children: [for (var i = 0; i < 5; i++) Text('row $i ${snap.data}')],
      )
    : const Text('loading');

class HtmlUnescape {
  const HtmlUnescape();
  String convert(String s) => s
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&#x2F;', '/')
      .replaceAll('&amp;', '&');
}

void main() {
  initializeThorTests();

  late Completer<String> a;
  late Completer<String> b;
  late List<Object> errors;

  RouteHandler<Widget> handler(
    Widget Function(Completer<String>, Completer<String>) page,
  ) => RouteHandler<Widget>(
    renderer: WidgetRenderer(app: (p) => ThorApp(child: p)),
    onError: (request, error, stack) => errors.add(error),
    routes: [
      PageRoute<Widget, void>(
        path: 'p',
        load: (r) {},
        build: (s) => page(a, b),
      ),
    ],
  );

  PageRequest get(String path) => PageRequest(
    method: HttpMethod.get,
    uri: Uri.parse('http://site.test$path'),
    headers: {HttpHeader.host: 'site.test'},
  );

  Future<List<String>> run(
    RouteHandler<Widget> h,
    void Function() finish,
  ) async {
    final r = await h.handle(get('/p'));
    final chunks = <String>[];
    final done = Completer<void>();
    r.stream!.listen((c) => chunks.add(utf8.decode(c)), onDone: done.complete);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    finish();
    await done.future;
    return chunks;
  }

  setUp(() {
    a = Completer();
    b = Completer();
    errors = [];
  });

  test(
    'the same FutureBuilder in two variants: one piece fills both',
    () async {
      final h = handler((a, b) {
        final results = FutureBuilder<String>(
          future: a.future,
          builder: _result,
        );
        return ResponsiveLayout(
          mobile: Column(children: [const Text('m'), results]),
          desktop: Row(children: [const Text('d'), results]),
        );
      });
      final chunks = await run(h, () => a.complete('X'));
      // shell, one piece, closing.
      expect(chunks, hasLength(3));
      expect(chunks.first, contains('<!--thor:1-->'));
      expect(chunks.first, contains('<!--thor:2-->'));
      expect('row 0 X'.allMatches(chunks[1]), hasLength(1));
      expect(chunks[1], contains('data-thor-end="1,2"'));
      expect('id="thor-d'.allMatches(chunks[1]), hasLength(1));
    },
  );

  test('a tear-off builder of the same future is the same piece', () async {
    final h = handler(
      (a, b) => ResponsiveLayout(
        mobile: FutureBuilder<String>(future: a.future, builder: _result),
        desktop: FutureBuilder<String>(future: a.future, builder: _result),
      ),
    );
    final chunks = await run(h, () => a.complete('X'));
    expect(chunks, hasLength(3));
    expect(chunks[1], contains('data-thor-end="1,2"'));
  });

  test('different builders or different futures stay apart', () async {
    final h = handler(
      (a, b) => ResponsiveLayout(
        mobile: FutureBuilder<String>(future: a.future, builder: _result),
        tablet: FutureBuilder<String>(
          future: a.future,
          builder: (c, s) => Text(s.hasData ? 'other ${s.data}' : 'loading'),
        ),
        desktop: FutureBuilder<String>(future: b.future, builder: _result),
      ),
    );
    final chunks = await run(h, () {
      a.complete('X');
      b.complete('Y');
    });
    // shell, three pieces, closing.
    expect(chunks, hasLength(5));
    final ends = RegExp(
      r'data-thor-end="([\d,]+)"',
    ).allMatches(chunks.join()).map((m) => m[1]).toList();
    expect(ends..sort(), ['1', '2', '3']);
  });

  test('three variants share one piece', () async {
    final h = handler((a, b) {
      final results = FutureBuilder<String>(future: a.future, builder: _result);
      return ResponsiveLayout(
        mobile: results,
        tablet: results,
        desktop: results,
      );
    });
    final chunks = await run(h, () => a.complete('X'));
    expect(chunks, hasLength(3));
    expect(chunks[1], contains('data-thor-end="1,2,3"'));
  });

  test('a place found after the piece went out gets its own', () async {
    // The inner place is in the late piece of `a`, drawn when `a` is done:
    // `b`'s first place was in the shell, so the pieces differ in id.
    final h = handler((a, b) {
      final inner = FutureBuilder<String>(future: b.future, builder: _result);
      return Column(
        children: [
          inner,
          FutureBuilder<String>(
            future: a.future,
            builder: (c, s) => s.hasData
                ? Column(children: [const Text('outer'), inner])
                : const Text('w'),
          ),
        ],
      );
    });
    final chunks = await run(h, () {
      b.complete('Y');
      Future<void>.delayed(
        const Duration(milliseconds: 20),
        () => a.complete('X'),
      );
    });
    final all = chunks.join();
    // `b` was done before `a`'s piece was drawn: the inner place of that
    // piece is drawn finished, and the first one got its piece.
    expect(all, contains('data-thor-end="1"'));
    expect(all, contains('data-thor-end="2"'));
    expect('row 0 Y'.allMatches(all).length, greaterThanOrEqualTo(2));
  });

  test('the failure of a shared future is told once to onError', () async {
    final h = handler((a, b) {
      final results = FutureBuilder<String>(
        future: a.future,
        builder: (c, s) => Text(s.hasError ? 'failed' : 'loading'),
      );
      return ResponsiveLayout(mobile: results, desktop: results);
    });
    final chunks = await run(h, () => a.completeError(StateError('boom')));
    expect(chunks[1], contains('failed'));
    expect(chunks[1], contains('data-thor-end="1,2"'));
    expect(errors, hasLength(1));
  });

  test('hostile text in an attribute of a top element stays a value in '
      'data-thor-cls', () async {
    const nasty =
        '"><script>alert(1)</script>\' onmouseover=alert(2) javascript:x';
    final h = handler((a, b) {
      final results = FutureBuilder<String>(
        future: a.future,
        builder: (c, snap) => snap.hasData
            ? Semantics(label: nasty, child: Text('r ${snap.data}'))
            : const Text('loading'),
      );
      return ResponsiveLayout(
        mobile: Column(children: [const Text('m'), results]),
        desktop: Row(
          children: [
            const Text('d'),
            Expanded(child: results),
          ],
        ),
      );
    });
    final chunks = await run(h, () => a.complete('X'));
    final piece = chunks[1];
    // Nothing of it outside a quoted value.
    expect(piece, isNot(contains('<script>alert')));
    final attr = RegExp(r'data-thor-cls="([^"]*)"').firstMatch(piece);
    expect(attr, isNotNull);
    if (attr != null) {
      final json = const HtmlUnescape().convert(attr.group(1)!);
      for (final tags in jsonDecode(json) as List) {
        if (tags == null) continue;
        for (final tag in (tags as List).cast<String>()) {
          // One start tag; every attribute is name="value" with no raw
          // quote, `<` or `>` inside the value.
          expect(
            tag,
            matches(
              RegExp(r'^<[a-z0-9]+( [\w:-]+="[^"<>]*")*>(</[a-z0-9]+>)?$'),
            ),
            reason: tag,
          );
          final names = RegExp(
            r' ([\w:-]+)="',
          ).allMatches(tag).map((m) => m.group(1)!);
          expect(names.where((n) => n.startsWith('on')), isEmpty);
        }
      }
    }
  });
}

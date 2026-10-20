import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'plain error ${state.status}';
}

PageRequest _get(String path) => PageRequest(
  method: HttpMethod.get,
  uri: Uri.parse('http://site.test$path'),
  headers: {HttpHeader.host: 'site.test'},
);

class Company {
  const Company(this.name);
  final String name;
}

class Team {
  const Team(this.name);
  final String name;
}

void main() {
  late List<Object> errors;
  late List<String> log;
  late Completer<Company> company;

  RouteHandler<String> handler(List<RouteNode<String>> children) =>
      RouteHandler<String>(
        renderer: _Renderer(),
        onError: (request, error, stack) => errors.add(error),
        routes: [
          LayoutRoute<String, Company>(
            load: (r) {
              log.add('company start');
              return company.future;
            },
            build: (s, child) => child,
            error: (e) => 'error ${e.status}',
            children: [
              LayoutRoute<String, Team>(
                path: 'team',
                load: (r) async {
                  final c = await r.parent<Company>();
                  return Team('${c.name} team');
                },
                build: (s, child) => child,
                children: children,
              ),
            ],
          ),
        ],
      );

  setUp(() {
    errors = [];
    log = [];
    company = Completer();
  });

  test('a page waits for the one layout it asks for', () async {
    final h = handler([
      PageRoute<String, String>(
        load: (r) async {
          final team = await r.parent<Team>();
          final c = await r.parent<Company>();
          return '${team.name} of ${c.name}';
        },
        build: (s) => s.data,
      ),
    ]);
    final response = h.handle(_get('/team'));
    await Future<void>.delayed(Duration.zero);
    company.complete(const Company('Acme'));
    expect((await response).text, 'Acme team of Acme');
  });

  test('loads that do not ask still start together (no cascade)', () async {
    final h = handler([
      PageRoute<String, String>(
        load: (r) {
          log.add('page start');
          return 'page';
        },
        build: (s) => s.data,
      ),
    ]);
    final response = h.handle(_get('/team'));
    await Future<void>.delayed(Duration.zero);
    // The page's load ran while the company's is still pending.
    expect(log, ['company start', 'page start']);
    company.complete(const Company('Acme'));
    expect((await response).text, 'page');
  });

  test('asking for a type no layout loads names what they load', () async {
    final h = handler([
      PageRoute<String, String>(
        load: (r) async => '${await r.parent<DateTime>()}',
        build: (s) => s.data,
      ),
    ]);
    company.complete(const Company('Acme'));
    final r = await h.handle(_get('/team'));
    expect(r.status, 500);
    expect(
      '${errors.single}',
      allOf(
        contains(
          'parent<DateTime>(): no layout above this route loads a DateTime',
        ),
        contains('Company'),
        contains('Team'),
      ),
    );
  });

  test("a layout's failure reaches the page that waits for it", () async {
    final h = handler([
      PageRoute<String, String>(
        load: (r) async => (await r.parent<Company>()).name,
        build: (s) => s.data,
      ),
    ]);
    final response = h.handle(_get('/team'));
    await Future<void>.delayed(Duration.zero);
    company.completeError(const NotFound('No company'));
    final r = await response;
    expect(r.status, 404);
    // The first level that failed decides: the root layout's own 404.
    expect(r.text, 'plain error 404');
    expect(errors, isEmpty);
  });

  test('a layout sees only the levels above it', () async {
    final h = RouteHandler<String>(
      renderer: _Renderer(),
      onError: (request, error, stack) => errors.add(error),
      routes: [
        LayoutRoute<String, String>(
          load: (r) async => r.parent<String>(),
          build: (s, child) => child,
          children: [
            PageRoute<String, String>(
              load: (r) => 'page',
              build: (s) => s.data,
            ),
          ],
        ),
      ],
    );
    final r = await h.handle(_get('/'));
    expect(r.status, 500);
    expect('${errors.single}', contains('no layout above has a load'));
  });

  test('an untyped layout load is matched by its value', () async {
    final h = RouteHandler<String>(
      renderer: _Renderer(),
      onError: (request, error, stack) => errors.add(error),
      routes: [
        LayoutRoute<String, Object?>(
          load: (r) => const Company('Untyped'),
          build: (s, child) => child,
          children: [
            PageRoute<String, String>(
              load: (r) async => (await r.parent<Company>()).name,
              build: (s) => s.data,
            ),
          ],
        ),
      ],
    );
    expect((await h.handle(_get('/'))).text, 'Untyped');
  });

  test('outside a load it is an error', () {
    expect(
      () => _get('/').parent<Company>(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('only works inside a load'),
        ),
      ),
    );
  });
}

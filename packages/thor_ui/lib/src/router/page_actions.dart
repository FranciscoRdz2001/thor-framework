import 'dart:async';

import 'package:thor_engine/thor_engine.dart' show encodeArgs, splitArgs;
import 'package:thor_server/thor_server.dart';

import '../foundation/errors.dart';
import '../foundation/style_registry.dart' show ThorStyleRegistry;
import 'form_schema.dart';

/// A form action that takes only the request: a method of the page
/// (`Future<ActionResult?> favorite(PageRequest request)`), passed as
/// `Form(onPost: favorite)` or `FilledButton(onPost: favorite)`.
typedef PagePost = FutureOr<ActionResult?> Function(PageRequest request);

/// A form action that receives the values of schema [S], already checked:
/// a method of the page
/// (`Future<ActionResult?> send(PageRequest request, FormValues<ContactForm> values)`),
/// passed as `Form(schema: ContactForm.schema, onValid: send)`.
typedef PageValidPost<S extends FormSchema> =
    FutureOr<ActionResult?> Function(PageRequest request, FormValues<S> values);

/// The values of a submitted form of schema [S] that passed every rule:
/// what an `onValid:` action method receives. The method never runs with
/// an invalid form (the page answers `422` with the messages first).
///
/// ```dart
/// Future<ActionResult?> send(PageRequest request, FormValues<ContactForm> values) async {
///   final email = values.of(ContactForm.email);   // String
///   if (await repo.exists(email)) {
///     return values.fail('That e-mail is taken', ContactForm.email);
///   }
///   …
/// }
/// ```
final class FormValues<S extends FormSchema> {
  /// The values of a valid form (a test builds them with
  /// `FormValues.from(schema.validate(data) as FormValid)`).
  FormValues.from(FormValid form) : _form = form;

  final FormValid _form;

  /// The value of [field], typed by the field (`String` for a text field,
  /// `int?` for an `IntSchemaField`…). A field of another schema is
  /// THOR-P007.
  T of<T>(SchemaField<T> field) => _form.of(field);

  /// The page again with [message] (under [field], or for the whole form)
  /// and the values re-filled: a `422` for a failure the rules can't see
  /// (the backend said no).
  ActionResult fail([String? message, SchemaField<Object?>? field]) =>
      invalid(message, field).fail();

  /// The failure [fail] answers, to add more messages or pick the status:
  /// `values.invalid().withError(a).withError(b).fail(401)`.
  FormInvalid invalid([String? message, SchemaField<Object?>? field]) =>
      _form.fail(message, field);
}

/// The field a submit button of an action with arguments posts them in
/// (`FilledButton(onPost: delete.withArg(id))`): the value of `name=thor-arg`.
const postArgField = 'thor-arg';

/// The id of the page's one hidden POST form, which every button of an
/// action with arguments belongs to (`form="thor-post"`).
const postFormId = 'thor-post';

/// `onPost: const OrdersPage().delete.withArg(order.id)`: an action method of
/// a page with one argument (`delete(PageRequest request, int id)`) with the
/// argument fixed. The button posts it as text and the server parses it back
/// to the parameter's type (`int`, `double`, `bool`, `String`, an enum…): a
/// value of another type is a `400`, never a `500`.
///
/// `// web:` Flutter has no server action. It is the same `withArg` a state
/// method has, for a method whose first parameter is the [PageRequest] (the
/// button fixes the second). Dart needs the two extensions told apart: the
/// state's `withArg` also fits `R Function(A, B)` (it would fix the request),
/// so this one has the same `on` type with `R` bound to what an action
/// returns, which makes it the more specific one (a method that returns
/// `void`, like every state method, never matches it). The first parameter is
/// then checked when the action is bound, not by the compiler.
extension PageActionWithArg<A, B, R extends FutureOr<ActionResult?>>
    on R Function(A, B) {
  /// This action with [arg] fixed.
  PagePost withArg(B arg) {
    _needRequest<A>('withArg');
    Future<ActionResult?> post(PageRequest request) async =>
        this(request as A, arg);
    _bound[post] = _Bound(this, [arg]);
    return post;
  }
}

/// `onPost: page.grant.withArgs(Role.guest, true)`: an action method with
/// two arguments fixed (see [PageActionWithArg]).
extension PageActionWithArgs2<A, B, C, R extends FutureOr<ActionResult?>>
    on R Function(A, B, C) {
  /// This action with [b] and [c] fixed.
  PagePost withArgs(B b, C c) {
    _needRequest<A>('withArgs');
    Future<ActionResult?> post(PageRequest request) async =>
        this(request as A, b, c);
    _bound[post] = _Bound(this, [b, c]);
    return post;
  }
}

/// `onPost: page.move.withArgs(id, Column.done, true)`: three arguments fixed.
extension PageActionWithArgs3<A, B, C>
    on FutureOr<ActionResult?> Function(PageRequest, A, B, C) {
  /// This action with [a], [b] and [c] fixed.
  PagePost withArgs(A a, B b, C c) {
    Future<ActionResult?> post(PageRequest request) async =>
        this(request, a, b, c);
    _bound[post] = _Bound(this, [a, b, c]);
    return post;
  }
}

// The extensions above take any first parameter type (that is what makes them
// win over the state's `withArg`): an action's is the request.
bool _takesRequest<A>() => <PageRequest>[] is List<A>;

void _needRequest<A>(String name) {
  if (!_takesRequest<A>()) {
    throw StateError(
      thorError(
        'THOR-P020',
        '`$name` on a page action needs a method whose first parameter is '
            'the PageRequest, not $A',
      ),
    );
  }
}

/// A bound action: the method's tear-off and its arguments.
final class _Bound {
  const _Bound(this.method, this.args);

  final Function method;
  final List<Object?> args;
}

final _bound = Expando<_Bound>('thor.bind');

/// An action method of a page class, as the generated registry
/// (`.dart_tool/thor/actions.dart`) lists it. Apps never write these.
final class PageActionMethod {
  /// [name], a method that takes only the request ([method] tears it off a
  /// page).
  PageActionMethod.request(this.name, PagePost Function(Object page) method)
    : schema = null,
      _method = method,
      argCount = 0,
      _parse = null,
      _run = ((page, request, _) => method(page)(request));

  /// [name], a method that takes the request and [argCount] arguments after it
  /// (`delete(PageRequest request, int id)`): [method] tears it off a page
  /// and [parse] turns the texts the button posted (one per argument) into
  /// the values, of the parameters' types. A text [parse] rejects is a `400`.
  PageActionMethod.args(
    this.name,
    Function Function(Object page) method,
    this.argCount,
    List<Object?> Function(List<String> parts) parse,
  ) : schema = null,
      _method = method,
      _run = null,
      _parse = parse;

  PageActionMethod._(this.name, this._method, this.schema, this._run)
    : argCount = 0,
      _parse = null;

  /// How many arguments follow the request (0 for a plain action).
  final int argCount;

  final List<Object?> Function(List<String> parts)? _parse;

  /// [name], a method that receives the values of [schema] ([method] tears
  /// it off a page).
  static PageActionMethod valid<S extends FormSchema>(
    String name,
    PageValidPost<S> Function(Object page) method,
    S schema,
  ) => PageActionMethod._(
    name,
    method,
    schema,
    (page, request, form) => method(page)(request, FormValues<S>.from(form!)),
  );

  /// The method's name: the `?/name` of the URL.
  final String name;

  /// The schema checked before the method runs, or null.
  final FormSchema? schema;

  final Function Function(Object page) _method;
  final FutureOr<ActionResult?> Function(
    Object page,
    PageRequest request,
    FormValid? form,
  )?
  _run;

  /// Runs the method of [page] for [request]: with a [schema], the form is
  /// checked first and an invalid one answers `422` without running it.
  Future<ActionResult?> run(Object page, PageRequest request) async {
    if (_parse case final parse?) {
      final values = await _argsOf(request, parse);
      return await Function.apply(_method(page), [request, ...values])
          as ActionResult?;
    }
    final run = _run!;
    final s = schema;
    if (s == null) return run(page, request, null);
    return switch (await s.parse(request)) {
      final FormInvalid invalid => invalid.fail(),
      final FormValid valid => await run(page, request, valid),
    };
  }

  /// The arguments the button posted, typed: a missing or malformed one is
  /// a `400`.
  Future<List<Object?>> _argsOf(
    PageRequest request,
    List<Object?> Function(List<String> parts) parse,
  ) async {
    final form = await request.form();
    final all = form.all(postArgField);
    if (all.isEmpty) {
      throw const HttpError(400, 'Missing the argument of the action.');
    }
    // A field of the Form named like the argument (or two buttons' values)
    // would pick one silently: the request is ambiguous, not the dev's value.
    if (all.length > 1) {
      throw const HttpError(400, 'The argument of the action is ambiguous.');
    }
    final posted = all.single;
    try {
      final values = parse(splitArgs(posted, argCount));
      if (values.length == argCount) return values;
      // A value the visitor could write (`curl`, a hand-edited form) of the
      // wrong type: `FormatException`, `ArgumentError`, a failed cast.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      // Answered below.
    }
    throw const HttpError(400, 'The argument of the action is not valid.');
  }
}

var _methods = <Type, List<PageActionMethod>>{};
var _registered = false;
final _pages = Set<Object>.identity();
Map<Function, (PageActionMethod, Object)>? _index;

/// Installs the action methods of the app's page classes: what the
/// generated `.dart_tool/thor/actions.dart` calls (`thor dev`, `thor
/// build`, `thor test` run it in every isolate, and again after a hot
/// reload).
void registerPageActions(Map<Type, List<PageActionMethod>> methods) {
  _methods = methods;
  _registered = true;
  _index = null;
}

/// The registered action methods of [page]'s class.
List<PageActionMethod> pageActionMethods(Object page) =>
    _methods[page.runtimeType] ?? const [];

/// Notes a page instance of the route table: its tear-offs are what a
/// `Form(onPost:)` can name.
void notePage(Object page) {
  if (_pages.add(page)) _index = null;
}

/// Whether [method] is the only action of [page]: no other registered method.
/// Such a page posts to its own path
/// with no `?/name`, and the server routes a POST without a key to it.
bool _isOnlyAction(PageActionMethod method, Object page) {
  final names = {for (final m in pageActionMethods(page)) m.name};
  return names.length == 1 && names.single == method.name;
}

/// The registered action method [method] is (a tear-off of a routed
/// page's method: tear-offs of the same method of the same instance are
/// equal), for the widget parameter [parameter]; THOR-P020 when it is none.
PageActionMethod actionMethodOf(Function method, String parameter) =>
    _lookup(method, parameter).$1;

(PageActionMethod, Object) _lookup(Function method, String parameter) {
  method = _bound[method]?.method ?? method;
  final index = _index ??= {
    for (final page in _pages)
      for (final m in pageActionMethods(page)) m._method(page): (m, page),
  };
  if (index[method] case final found?) return found;
  throw StateError(
    thorError(
      'THOR-P020',
      _registered
          ? '`$parameter:` got a function that is not an action method of a '
                'page in the router. Pass a public method of the page '
                '(`$parameter: send`) returning FutureOr<ActionResult?> and '
                'taking (PageRequest) or (PageRequest, FormValues<S>), not a '
                'closure; the page must be a Route of the ThorRouter'
          : '`$parameter:` needs the registry of action methods that thor '
                'generates: run the app with `thor dev`, `thor build` or '
                '`thor test`',
    ),
  );
}

/// A route a page is served at: its URL pattern and whether a path is its.
typedef PageRouteInfo = ({
  String path,
  bool hasParams,
  bool Function(String path) matches,
});

final _routes = Map<Object, List<PageRouteInfo>>.identity();

/// Notes that [page] is served at [route] (the `ThorRouter` calls it for each
/// `ThorRoute`): what lets an action of another page post to that page's URL.
///
/// [owner] is the router that notes it: a page is a `const` instance shared by
/// every router built in the isolate (a test file builds one per test), so
/// the routes an older router noted for [page] are dropped, not added to.
void notePageRoute(Object page, PageRouteInfo route, {Object? owner}) {
  final known = _routes[page] ??= [];
  if (owner != null && _routeOwners[page] != owner) {
    known.clear();
    _routeOwners[page] = owner;
  }
  // A router built again (a hot reload, a test) notes the same route again.
  if (known.every((r) => r.path != route.path)) known.add(route);
}

final _routeOwners = Map<Object, Object>.identity();

/// Where the page of [method] lives when it is not the page being rendered
/// ([currentPath], the request's path): its route's path, for a button or
/// form of another page to post to (`/cart?/add`). Null when the action
/// belongs to the current page (the relative `?/add`, which keeps working
/// under any URL of it, `/p/:slug` too), when [currentPath] is unknown, or
/// when the page has no route noted.
///
/// THOR-P020 when the page is on a route with parameters (no URL to post to
/// without values: pass `action: route.link({...})` to the `Form`) or on
/// several routes.
String? pageBaseOf(Function method, String parameter, String? currentPath) {
  if (currentPath == null) return null;
  final (found, page) = _lookup(method, parameter);
  final routes = _routes[page];
  if (routes == null || routes.isEmpty) return null;
  if (routes.any((r) => r.matches(currentPath))) return null;
  Never fail(String why) => throw StateError(
    thorError(
      'THOR-P020',
      '`$parameter:` is the action `${found.name}` of a page that is not '
          'this one (${routes.map((r) => r.path).join(', ')}), and $why',
    ),
  );
  if (routes.length > 1) {
    fail('the page is on several routes: pass `action:` with its URL');
  }
  if (routes.single.hasParams) {
    fail(
      'its route has parameters, so there is no URL to post to: pass '
      '`action: route.link({...})` to the `Form`, or write the button with '
      '`formAction:`',
    );
  }
  return routes.single.path;
}

/// The URL a form or a submit button posts to for the page's action
/// [method] (a tear-off: `?/removeTag`), for what the widgets can't say:
/// an extra query (`'${formActionUrl(removeTag)}&tag=$tag'`) or a raw
/// `html.button(attributes: {'formaction': …})`. THOR-P020 when [method] is
/// not a registered action method of a routed page.
String formActionUrl(Function method) => actionUrl(method, 'formActionUrl')!;

/// The `formaction`/`action` URL of [method]: `?/name`, or [base] (another
/// page's URL) with `?/name` appended.
///
/// [query] is the page's own query (`state.request.uri.query`): it goes
/// first, so the action doesn't drop it (`?tab=account&/save`; a form that
/// posts to `?/save` alone replaces the whole query). The action keys of a
/// previous post (`/drop` on the page a failed post answered) never travel:
/// two would run the first.
///
/// With no [base], [requestPath] (the request's, without its locale prefix)
/// decides, and [localize] (`request.localizedPath`) puts the language back: a [method] of another
/// routed page gets that page's path ([pageBaseOf]) and the query of this
/// page does not go with it.
///
/// With [keyless], a [method] that is the only action of its page gets no
/// key: the page's path (and [query]), which the server routes to that
/// action. `null` then means «no URL to name»: a form without
/// `action` posts to the document's own, so the page's query stays.
String? actionUrl(
  Function method,
  String parameter, {
  String? base,
  String? query,
  String? requestPath,
  String Function(String path)? localize,
  bool keyless = false,
}) {
  final (found, page) = _lookup(method, parameter);
  final name = found.name;
  final only = keyless && _isOnlyAction(found, page);
  if (base == null || base.isEmpty || base == '?') {
    base = pageBaseOf(method, parameter, requestPath);
    // The visitor's language stays (`/en/cart`): the post answers there.
    if (base != null && localize != null) base = localize(base);
  }
  if (base == null || base.isEmpty || base == '?') {
    final kept = queryWithoutAction(query ?? '');
    if (only) {
      final own = _ownPath(
        requestPath == null || localize == null
            ? requestPath
            : localize(requestPath),
      );
      if (own != null) return kept.isEmpty ? own : '$own?$kept';
      // No path to name: the query alone, or the document's own URL.
      return kept.isEmpty ? null : '?$kept';
    }
    return kept.isEmpty ? '?/$name' : '?$kept&/$name';
  }
  // The method goes in the query, before a fragment (`/a#end` →
  // `/a?/name#end`): after the `#` the browser would not send it.
  final hash = base.indexOf('#');
  final url = hash < 0 ? base : base.substring(0, hash);
  final fragment = hash < 0 ? '' : base.substring(hash);
  final mark = url.indexOf('?');
  final path = mark < 0 ? url : url.substring(0, mark);
  final kept = mark < 0 ? '' : queryWithoutAction(url.substring(mark + 1));
  if (only) return kept.isEmpty ? '$path$fragment' : '$path?$kept$fragment';
  return kept.isEmpty ? '$path?/$name$fragment' : '$path?$kept&/$name$fragment';
}

/// [path] as a path of this site (one leading `/`, so `//host` is never
/// another origin), or null when it is none a form should post to.
String? _ownPath(String? path) {
  if (path == null || path.isEmpty) return null;
  if (RegExp(r'[\\\x00-\x1f\x7f]').hasMatch(path)) return null;
  return path.replaceFirst(RegExp(r'^/+'), '/');
}

/// The arguments [onPost] carries (`page.delete.withArg(id)`) as the value a
/// button or form posts in [postArgField], or null when it has none.
String? postArgOf(PagePost? onPost) {
  final bound = onPost == null ? null : _bound[onPost];
  if (bound == null) return null;
  final method = actionMethodOf(bound.method, 'onPost');
  if (method.argCount != bound.args.length) {
    throw StateError(
      thorError(
        'THOR-P020',
        '`onPost:` binds ${bound.args.length} argument(s) but the action '
            '`${method.name}` takes ${method.argCount}',
      ),
    );
  }
  return encodeArgs(bound.args);
}

/// A submit button's `formaction`: [onPost]'s or [onValid]'s URL, else the
/// plain [formAction] string.
///
/// [query] is the page's query, kept like [actionUrl] does.
String? submitActionUrl(
  String? formAction,
  PagePost? onPost,
  PageValidPost<Never>? onValid, {
  String? query,
  String? requestPath,
  String Function(String path)? localize,
}) {
  if (onPost != null) {
    return actionUrl(
      onPost,
      'onPost',
      query: query,
      requestPath: requestPath,
      localize: localize,
      keyless: true,
    );
  }
  if (onValid != null) {
    return actionUrl(
      onValid,
      'onValid',
      query: query,
      requestPath: requestPath,
      localize: localize,
      keyless: true,
    );
  }
  return formAction;
}

/// The attributes of a submit button for its action: `formaction`, and for
/// an [onPost] with arguments (`page.delete.withArg(id)`) its `name`/`value`
/// (the arguments, posted with the button). Outside a `Form` ([inForm]
/// false) an `onPost` takes `form`, the page's shared POST form (the page
/// then ships it, once); inside one the button keeps its own form, so the
/// submit sends the `Form`'s fields along with the arguments (the HTML
/// `form` attribute would send the shared, empty one). Without JS it is the
/// browser's own form submit. [query] and [requestPath] are the page's, used like
/// [actionUrl] does.
Map<String, String> submitAttributes(
  ThorStyleRegistry? registry,
  String? formAction,
  PagePost? onPost,
  PageValidPost<Never>? onValid, {
  bool inForm = false,
  String? query,
  String? requestPath,
  String Function(String path)? localize,
}) {
  final url = submitActionUrl(
    formAction,
    onPost,
    onValid,
    query: query,
    requestPath: requestPath,
    localize: localize,
  );
  final arg = postArgOf(onPost);
  // An action out of any `Form` has no form to submit: it takes the page's
  // shared one. In a `Form` the button submits that one, fields included.
  final shared = onPost != null && !inForm;
  if (shared) registry?.usePostForm();
  return {
    'formaction': ?url,
    if (arg != null) ...{'name': postArgField, 'value': arg},
    if (shared) 'form': postFormId,
  };
}

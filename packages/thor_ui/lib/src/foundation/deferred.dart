/// A value that arrives after the page went out: `FutureBuilder`, and what
/// the renderer needs to send it later (streaming SSR).
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:thor_engine/thor_engine.dart'
    show
        AsyncSnapshot,
        ConnectionState,
        ServerErrorKind,
        encodeStateJson,
        stateJson;
import 'package:thor_server/thor_server.dart' show NotFound, PageRequest;

import '../core/core.dart';
import '../core/framework.dart' show BuildChild, PageBuild, PageComponent;
import '../core/markup.dart'
    show ElementNode, FragmentNode, ParentNode, TextNode, writeChildrenUtf8;
import 'child_rules.dart' show ThorBuiltIn;
import 'element.dart' show thorElement;
import 'errors.dart' show thorError;
import 'layout_hint.dart';
import 'request_scope.dart' show RequestScope;
import 'style_registry.dart' show ThorStyleRegistry;

/// How a [FutureBuilder]'s future ended.
sealed class DeferOutcome {
  const DeferOutcome();

  /// What a builder is given for this outcome.
  AsyncSnapshot<T> snapshot<T>();
}

/// A future that completed with [value].
final class DeferDone extends DeferOutcome {
  /// Done with [value].
  const DeferDone(this.value);

  /// The value.
  final Object? value;

  @override
  AsyncSnapshot<T> snapshot<T>() => AsyncSnapshot<T>.done(value as T?);
}

/// A future that failed (or took too long).
final class DeferFailed extends DeferOutcome {
  /// Failed with [error], told to the visitor as [message].
  const DeferFailed(this.error, this.stack, this.message, this.kind);

  /// What was thrown.
  final Object error;

  /// Where.
  final StackTrace? stack;

  /// The visitor's message.
  final String message;

  /// Why, for the builder to branch on.
  final ServerErrorKind kind;

  @override
  AsyncSnapshot<T> snapshot<T>() =>
      AsyncSnapshot<T>.withError(ConnectionState.done, message, kind);
}

// How the futures this process listened to ended, once they have: a future
// that is done when the page is drawn is drawn done, with no skeleton.
final _known = Expando<Object>('deferred outcomes');

/// One render of a page, as far as its deferred values go.
///
/// [stream]: the page goes out in pieces, each [FutureBuilder] draws what its
/// builder says for a future that is not done, and the renderer sends the
/// rest as the futures complete. Not [stream]: the page is drawn again with
/// the outcomes of [settled] until none is missing (a page kept in the
/// cache, an export, a test).
final class DeferRun {
  /// A run; [describe] says how to tell the visitor about an error.
  DeferRun({
    required this.stream,
    required this.timeout,
    required this.describe,
    this.report,
    this.warn,
  });

  /// Whether the page goes out in pieces. A fragment request turns it off
  /// once the page was drawn: what the piece holds is waited for.
  bool stream;

  /// How long a future may take once the page went out.
  final Duration timeout;

  /// The visitor's message and kind for an error.
  final (String, ServerErrorKind) Function(Object error) describe;

  /// Reports an error the visitor doesn't see (the app's `onError`).
  final void Function(Object error, StackTrace stack)? report;

  /// Under `thor dev`: where a hint about a `FutureBuilder` goes (see
  /// [_DeferredPlace]); null in a release, which then checks nothing.
  final void Function(String message)? warn;

  final _warned = HashSet<Future<Object?>>.identity();

  /// Says [message] once for [future] (a settled draw repeats itself).
  void _warnOnce(Future<Object?> future, String message) {
    if (_warned.add(future)) warn?.call(message);
  }

  /// How many [FutureBuilder]s this run built so far: a dev check measures
  /// a part of the page by the difference (`ResponsiveLayout`, THOR-R034).
  int futureBuilders = 0;

  final _said = HashSet<String>();

  /// Says [message] once in this run, whatever draws it again: a hint no
  /// future owns (see [warn]).
  void warnOnce(String message) {
    if (_said.add(message)) warn?.call(message);
  }

  /// The outcomes of the futures awaited so far (when not [stream]).
  final Map<Future<Object?>, DeferOutcome> settled = HashMap.identity();

  /// The futures this draw found that [settled] doesn't hold (not [stream]).
  final Set<Future<Object?>> unresolved = HashSet.identity();

  /// The pieces of the page that wait for a value, in the order they were
  /// found.
  final List<DeferSlot> slots = [];

  /// The piece a fragment request asks for (`?thor-piece=id`), or null: the
  /// page is drawn as usual and the [LazyPiece] with that id leaves its
  /// [lazy] here instead of drawing its content.
  String? lazyId;

  /// Draws the piece [lazyId] names (its `load`, then its builder, where the
  /// placeholder is), once the page has been drawn.
  Future<DeferPiece> Function(PageRequest request)? lazy;

  /// Runs after each draw of the piece [lazyId] names, to wait for what the
  /// draw found that is not a future (the queries of its states): true when
  /// it waited for something, and the piece is drawn again.
  Future<bool> Function()? afterLazyDraw;

  int _next = 0;
  int _taken = 0;

  /// Forgets what a draw found, to draw again (the outcomes are kept).
  void reset() {
    lazy = null;
    slots.clear();
    unresolved.clear();
    _next = 0;
    _taken = 0;
  }

  /// The slots found since the last call.
  List<DeferSlot> takeNew() {
    final fresh = slots.sublist(_taken);
    _taken = slots.length;
    return fresh;
  }

  /// Listens to [future] now (a failure nobody reads yet is not an
  /// unhandled error), and says how it ended: a [DeferDone] or the error
  /// with its stack.
  Future<Object> _listen(Future<Object?> future) => future.then<Object>(
    (v) => _known[future] = DeferDone(v),
    onError: (Object e, StackTrace st) => _known[future] = (e, st),
  );

  final _timers = <Timer>{};
  final _gone = Completer<void>();

  /// Completes when the client left ([dispose]): nothing is waited for.
  Future<void> get gone => _gone.future;

  /// The client left: the clocks of the futures still on their way stop (a
  /// future that never completes would otherwise report its timeout to a
  /// log nobody reads, and hold a timer), and what is left is not reported.
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    if (!_gone.isCompleted) _gone.complete();
  }

  /// How [listened] (see [_listen]) ended, in [timeout] at most. Failures
  /// are reported here, once per run of the outcome.
  Future<DeferOutcome> _outcomeOf(Future<Object> listened) {
    final outcome = Completer<DeferOutcome>();
    late final Timer timer;
    timer = Timer(timeout, () {
      _timers.remove(timer);
      if (outcome.isCompleted) return;
      outcome.complete(
        failure(
          TimeoutException('Future not completed', timeout),
          StackTrace.current,
        ),
      );
    });
    _timers.add(timer);
    listened.then((end) {
      timer.cancel();
      _timers.remove(timer);
      if (outcome.isCompleted || _gone.isCompleted) return;
      if (end is DeferOutcome) {
        outcome.complete(end);
      } else {
        final (error, stack) = end as (Object, StackTrace);
        outcome.complete(failure(error, stack));
      }
    });
    return outcome.future;
  }

  /// The outcome of an error: reported, and told to the visitor as
  /// [describe] says.
  DeferFailed failure(Object error, StackTrace stack) {
    report?.call(error, stack);
    final (message, kind) = describe(error);
    return DeferFailed(error, stack, message, kind);
  }

  /// Waits for every future of [unresolved] and keeps their outcomes.
  Future<void> settle() async {
    final waiting = unresolved.toList();
    unresolved.clear();
    final outcomes = await Future.wait([
      for (final f in waiting) _outcomeOf(_listen(f)),
    ]);
    for (var i = 0; i < waiting.length; i++) {
      settled[waiting[i]] = outcomes[i];
    }
  }
}

/// A place of the page that waits for a future (see [DeferRun]).
final class DeferSlot {
  DeferSlot._(
    this.id,
    this._run,
    this.source,
    this._listened,
    this._page,
    this._element,
    this._build,
    this._zone,
    this._registry,
    this._widgetFor,
    this._future,
    this._probe,
  );

  /// Its number in the page: the markers `<!--thor:id-->` hold the place.
  final int id;

  /// The future it waits for (places that wait for the same one are sent
  /// together).
  final Future<Object?> source;

  final Future<Object> _listened;
  final DeferRun _run;

  /// How its future ended, in the run's timeout at most (never throws).
  /// Starts counting when first read: when the page is out.
  late final Future<DeferOutcome> outcome = _run._outcomeOf(_listened);

  final PageBuild _page;
  final Element _element;
  final BuildChild _build;
  final Zone _zone;
  final ThorStyleRegistry? _registry;
  final Widget Function(DeferOutcome outcome) _widgetFor;
  final Future<Object?> _future;
  final String? Function(BuildChild build, Element element) _probe;

  /// Under `thor dev`: tells the terminal when [outcome] is a future that
  /// answered null and the builder drew for it what it draws while waiting
  /// (`hasData` is false for null: the visitor is left with the skeleton).
  void check(DeferOutcome outcome) {
    if (_run.warn == null || outcome is! DeferDone || outcome.value != null) {
      return;
    }
    final message = _zone.run(
      () => _page.late(() {
        final registry = _registry?..reopen();
        try {
          return _probe(_build, _element);
        } finally {
          // What the probe drew is not part of the page.
          registry?.takeLate();
          registry?.close();
        }
      }),
    );
    if (message != null) _run._warnOnce(_future, message);
  }

  /// The HTML of the place for [outcome], drawn where it was found (its
  /// zone and context), and what the page needs for it: the classes it
  /// added, the icons, the values of the states it uses and the engine.
  /// With [shape] it also writes the HTML without the attributes of the top
  /// elements (what the parent gives them), to tell whether two places got
  /// the same result.
  DeferPiece render(DeferOutcome outcome, {bool shape = false}) => _zone.run(
    () => _page.late(() {
      final registry = _registry?..reopen();
      final node = FragmentNode();
      DeferPiece? piece;
      try {
        _build(_widgetFor(outcome), _element, node);
        final late = registry?.takeLate();
        final html = writeChildrenUtf8(node);
        final roots = shape ? _roots(node) : const <ElementNode>[];
        List<int>? blank;
        final tags = <String>[];
        if (shape) {
          final kept = [
            for (final r in roots) (r.id, r.classes, r.styles, r.attributes),
          ];
          for (final r in roots) {
            tags.add(
              utf8.decode(writeChildrenUtf8(FragmentNode()..add(_bare(r)))),
            );
            r.id = r.classes = r.styles = r.attributes = null;
          }
          blank = writeChildrenUtf8(node);
          for (var i = 0; i < roots.length; i++) {
            final (id, classes, styles, attributes) = kept[i];
            roots[i]
              ..id = id
              ..classes = classes
              ..styles = styles
              ..attributes = attributes;
          }
        }
        final engine = FragmentNode();
        if (late?.engine case final script?) _build(script, _element, engine);
        piece = DeferPiece(
          html: html,
          css: late?.css ?? '',
          sprite: late?.sprite ?? '',
          state: late?.state ?? const {},
          engine: writeChildrenUtf8(engine),
          shape: blank,
          roots: tags,
        );
      } finally {
        registry?.close();
      }
      return piece;
    }),
  );

  // [e] with its attributes and no children: its start tag, written.
  static ElementNode _bare(ElementNode e) => ElementNode(
    e.tag,
    id: e.id,
    classes: e.classes,
    styles: e.styles,
    attributes: e.attributes,
  );

  // The elements at the top of a piece, through fragments.
  static List<ElementNode> _roots(ParentNode node) => [
    for (final child in node.children)
      if (child is ElementNode)
        child
      else if (child is FragmentNode)
        ..._roots(child),
  ];
}

/// What a [DeferSlot] drew for an outcome.
final class DeferPiece {
  /// A piece.
  const DeferPiece({
    required this.html,
    this.css = '',
    this.sprite = '',
    this.state = const {},
    List<int>? engine,
    this.shape,
    this.roots = const [],
    this.sync = false,
  }) : engine = engine ?? const [];

  /// The HTML that goes where the placeholder was.
  final List<int> html;

  /// The classes the piece added to the page's stylesheet.
  final String css;

  /// The `<symbol>`s it added to the page's icon sprite.
  final String sprite;

  /// The values of the states it uses that the page didn't have (with
  /// [sync], every state it uses).
  final Map<String, Object?> state;

  /// Whether the browser replaces the values of the states it already has
  /// with those of [state] (a `Region(syncState: true)` answer).
  final bool sync;

  /// The engine's script, when only this piece needs it.
  final List<int> engine;

  /// [html] without the attributes of the top elements, when asked for.
  final List<int>? shape;

  /// The start tag of each top element (what its parent gave it: classes,
  /// `data-thor-flex-item`), when [shape] was asked for.
  final List<String> roots;

  /// [next], drawn again after this one (a value arrived that the first
  /// draw waited for): its HTML, and what both added to the page.
  DeferPiece then(DeferPiece next) => DeferPiece(
    html: next.html,
    css: css + next.css,
    sprite: sprite + next.sprite,
    state: {...state, ...next.state},
    engine: engine.isEmpty ? next.engine : engine,
    sync: sync || next.sync,
  );

  /// This piece with its [state] replaced ([sync]: the browser takes them
  /// over the ones it has).
  DeferPiece withState(Map<String, Object?> state, {bool sync = false}) =>
      DeferPiece(
        html: html,
        css: css,
        sprite: sprite,
        state: state,
        engine: engine,
        sync: sync,
      );

  /// This piece with what [other] (the same HTML, drawn for another place)
  /// brought that this one didn't.
  DeferPiece merged(DeferPiece other) => DeferPiece(
    html: html,
    css: css + other.css,
    sprite: sprite + other.sprite,
    state: {...state, ...other.state},
    engine: engine.isEmpty ? other.engine : engine,
    shape: shape,
    roots: roots,
    sync: sync || other.sync,
  );
}

/// Holds the [DeferRun] of the draw in progress: the renderer sets a new
/// one before each draw of the page.
final class DeferHolder {
  /// A holder with no run: [FutureBuilder] draws what it says for a future
  /// that is not done (a render outside a route).
  DeferHolder();

  /// The run of the draw in progress.
  DeferRun? run;
}

/// Gives the [FutureBuilder]s below it the [DeferRun] of the render.
class DeferScope extends InheritedWidget {
  /// A scope that reads its run from [holder].
  const DeferScope({super.key, required this.holder, required super.child});

  /// Where the run is.
  final DeferHolder holder;

  @override
  bool updateShouldNotify(DeferScope oldComponent) => false;
}

/// Flutter's `FutureBuilder`: draws [builder] with the state of [future].
///
/// The page goes out at once with what [builder] draws for a future that is
/// not done (its `waiting` snapshot: a skeleton), and when the future
/// completes the server sends what [builder] draws for the result, which
/// replaces it. Nothing else of the page waits for it.
///
/// ```dart
/// // ThorPage.load: start the call, don't await it
/// Home(featured: defer(search(featured)));
///
/// // build
/// FutureBuilder<List<Product>>(
///   future: data.featured,
///   builder: (context, snapshot) => snapshot.hasData
///       ? ProductGrid(snapshot.data!)
///       : snapshot.hasError ? const Text('Try again later') : const Skeleton(height: 240),
/// )
/// ```
///
/// `snapshot.hasData` is `false` when the future completes with `null` (as in
/// Flutter): with a nullable `T`, tell waiting from done with
/// `snapshot.connectionState == ConnectionState.done`, or the skeleton stays
/// for good (THOR-R033; `thor dev` and the `future_builder_nullable_has_data`
/// lint say so).
///
/// `// web:` the future comes from `load` (create it there, and wrap it in
/// `defer` so a failure nobody reads yet is not an unhandled error): one
/// created in `build` is created again by every draw. A page kept in the
/// cache (`cache:`), an export and the test client draw once with every
/// future done. The `<head>` (title, meta, canonical) is written before the
/// future ends: it can't depend on it. `snapshot.error` is the visitor's
/// message, never the exception (that goes to `onError`). The builder's
/// result goes into its place in the page: no `<tr>`/`<td>` as the direct
/// result inside a table (defer the whole table).
class FutureBuilder<T> extends StatelessWidget {
  /// Draws [builder] with [future]'s state.
  const FutureBuilder({
    super.key,
    required this.future,
    required this.builder,
    this.initialData,
  });

  /// The future, started in `load`; null draws a snapshot with no
  /// connection.
  final Future<T>? future;

  /// What `snapshot.data` holds while the future is not done.
  final T? initialData;

  /// Draws a snapshot of the future.
  final Widget Function(BuildContext context, AsyncSnapshot<T> snapshot)
  builder;

  @override
  Widget build(BuildContext context) => _DeferredPlace<T>(this, context);
}

class _DeferredPlace<T> extends PageComponent
    implements ThorBuiltIn, LayoutHint, HeightHint {
  const _DeferredPlace(this.owner, this.context);

  final FutureBuilder<T> owner;
  final BuildContext context;

  AsyncSnapshot<T> get _waiting => owner.future == null
      ? const AsyncSnapshot.nothing()
      : AsyncSnapshot<T>.waiting(owner.initialData);

  Widget _draw(AsyncSnapshot<T> snapshot) => owner.builder(context, snapshot);

  /// Dev only: a message when the builder draws the same for a future that
  /// answered null as for one that is still waiting (so the skeleton stays
  /// for good), null when it tells them apart.
  String? _stuckOnNull(BuildChild build, Element element) {
    String html(AsyncSnapshot<T> snapshot) {
      final node = FragmentNode();
      build(_draw(snapshot), element, node);
      return utf8.decode(writeChildrenUtf8(node), allowMalformed: true);
    }

    try {
      if (html(_waiting) != html(AsyncSnapshot<T>.done(null))) return null;
    } on Object {
      // A builder that fails for null (or for waiting): a hint is not worth
      // breaking the page, and the real draw reports it as it always did.
      return null;
    }
    return thorError(
      'THOR-R033',
      'FutureBuilder<$T> completed with null and its builder drew the same '
          'as while waiting: `snapshot.hasData` is false for null, so the '
          'skeleton stays. Check `snapshot.connectionState == '
          'ConnectionState.done` first',
    );
  }

  @override
  bool get fillsWidth => layoutFillsWidth(_draw(_waiting));

  @override
  bool get fillsHeight => layoutFillsHeight(_draw(_waiting));

  @override
  void buildInto(
    PageBuild page,
    Element element,
    ParentNode into,
    BuildChild build,
  ) {
    final future = owner.future;
    final run = element
        .dependOnInheritedWidgetOfExactType<DeferScope>()
        ?.holder
        .run;
    if (future == null || run == null) {
      return build(_draw(_waiting), element, into);
    }
    run.futureBuilders++;
    if (!run.stream) {
      final outcome = run.settled[future];
      if (outcome == null) run.unresolved.add(future);
      if (outcome is DeferDone && outcome.value == null && run.warn != null) {
        final message = _stuckOnNull(build, element);
        if (message != null) run._warnOnce(future, message);
      }
      return build(
        _draw(outcome == null ? _waiting : outcome.snapshot<T>()),
        element,
        into,
      );
    }
    // Done already (awaited in `load`, or drawn before): no skeleton to
    // replace.
    if (_known[future] case final end?) {
      final outcome = switch (end) {
        final DeferOutcome o => o,
        (final Object e, final StackTrace st) => run.failure(e, st),
        _ => null,
      };
      if (outcome != null) {
        return build(_draw(outcome.snapshot<T>()), element, into);
      }
    }
    final slot = DeferSlot._(
      ++run._next,
      run,
      future,
      run._listen(future),
      page,
      element,
      build,
      Zone.current,
      ThorStyleRegistry.of(element),
      (outcome) => _draw(outcome.snapshot<T>()),
      future,
      _stuckOnNull,
    );
    run.slots.add(slot);
    into.add(TextNode('<!--thor:${slot.id}-->', raw: true));
    build(_draw(_waiting), element, into);
    into.add(TextNode('<!--/thor:${slot.id}-->', raw: true));
  }
}

/// Zone key the server's load sets (`headWaitKey` of thor_server).
const _headWaitKey = #thor.headWait;

/// A reasonable `headBudget` for a `defer(head: true)` future whose head data
/// is only cosmetic (a title, a description): 300 ms. There is no budget unless
/// a call passes one.
const defaultHeadBudget = Duration(milliseconds: 300);

/// Starts [future] for a page that shows it later (`FutureBuilder`): the
/// same future, marked as handled, so a failure that happens before the page
/// reads it (or on a page that never does) is not an unhandled error that
/// stops the server. The error still reaches whoever listens.
///
/// ```dart
/// Future<Home> load(PageRequest request) async => Home(
///   user: await users.me(request),       // the page waits for this
///   featured: defer(catalog.featured()), // and shows this when it comes
/// );
/// ```
///
/// With [head] the page's `<head>` and status depend on the future: the server
/// **waits for it to finish** after `load` returns, before the first byte. Then
/// `meta` reads its value ([resolvedValue]) and a `NotFound`/`HttpError`/
/// `Redirect` it throws answers the real status, like an `await` in `load`
/// (any other error is a `500`, and a future that never finishes a `504` after
/// `deferTimeout`; the rest of the page's deferred futures still stream). The
/// status never depends on how slow the backend is.
///
/// ```dart
/// Future<ProductData> load(PageRequest request) async => ProductData(
///   product: defer(catalog.product(request.param('slug')), head: true),
/// );
///
/// PageMeta meta(PageState<ProductData> state) => PageMeta(
///   title: resolvedValue(state.data.product)?.name ?? 'Product',
/// );
/// ```
///
/// [headBudget] is an explicit opt-in for head data that is **only cosmetic**
/// (a title that can fall back): the server waits at most that long, then
/// streams the page with the head `meta` gave without the value. **A budget
/// trades status correctness for latency**: if the future later fails with a
/// `NotFound`, the page already answered `200` (a soft 404 that search engines
/// can index, and that caches and monitoring see differently from the next
/// request). Under `thor dev` that case prints `THOR-S038`. Do not set one on
/// a future that decides the status.
///
/// `// web:` no Flutter counterpart (an app has no HTTP response): the status
/// and the `<head>` leave before the body streams, so a future that decides
/// them is awaited first. The choice is per future, and the deadline is
/// opt-in.
Future<T> defer<T>(
  Future<T> future, {
  bool head = false,
  Duration? headBudget,
}) {
  // Listened to now: if the page awaits it in `load` (or it is done before the
  // page is drawn), it is drawn done at once, with no skeleton.
  future.then<Object>(
    (v) => _known[future] = DeferDone(v),
    onError: (Object e, StackTrace st) => _known[future] = (e, st),
  );
  if (head) {
    final mark = Zone.current[_headWaitKey];
    if (mark is void Function(Future<Object?>, Duration?)) {
      mark(future, headBudget);
    }
  }
  return future;
}

/// The value of [future] if it already finished with one, or null: what
/// `meta` reads from a `defer(head: true)` future (always done when `meta`
/// runs, unless it had an opt-in `headBudget` that ran out).
///
/// `// web:` Flutter has no sync read of a `Future` (`FutureBuilder` shows
/// its `initialData` until it completes); `meta` runs once, on the server,
/// and can't wait.
T? resolvedValue<T>(Future<T>? future) {
  if (future == null) return null;
  return switch (_known[future]) {
    DeferDone(:final value) => value as T?,
    _ => null,
  };
}

/// The query parameter of the URL of a [LazyPiece]'s fragment: the page's
/// own URL plus `thor-piece=<id>`.
const lazyPieceParameter = 'thor-piece';

/// What makes a [LazyPiece] load.
enum LazyTrigger {
  /// When the closest `<details>` (an `ExpansionTile`), `<dialog>` (a
  /// `Dialog`, a `Drawer`) or popover opens; a piece with none of them above
  /// is [visible].
  open,

  /// When it comes near the viewport.
  visible,

  /// At once, when the page is ready.
  idle,
}

/// A part of the page the server draws only when the browser asks for it:
/// the lazy content of an accordion, a drawer or a tab, which the page does
/// not carry (a menu with 750 entries, the reviews of a product).
///
/// ```dart
/// ExpansionTile(
///   title: Text(department.name),
///   children: [
///     LazyPiece<List<Category>>(
///       id: 'branch-${department.slug}',
///       load: (request) => categories.branch(department.slug),
///       builder: (context, branch) => Column(children: [
///         for (final c in branch) Link(href: c.url, child: Text(c.name)),
///       ]),
///       fallback: Link(href: department.url, child: Text('See all')),
///     ),
///   ],
/// )
/// ```
///
/// The page has a `<div>` with the [fallback] in it and the URL of the piece.
/// When the [trigger] happens (the accordion opens) a script asks for it
/// (`GET` the page's URL plus `thor-piece=<id>`), the server draws the page
/// as always and answers only this piece: [load] runs, [builder] builds
/// what it returns where the placeholder was (so the theme, the locale and
/// the route's scopes are those of the page), with the classes it needs. The
/// browser puts it in place of the fallback and the states it uses are
/// bound, like the content of a `FutureBuilder`.
///
/// Without JavaScript the page keeps the [fallback]: make it a link to a page
/// that has the same content (`Link(href: …)`), so nobody misses it. Search
/// engines see the same, and a failed request leaves it too (the next time
/// the trigger happens it tries again).
///
/// `// web:` Flutter has no counterpart (everything is already on the
/// device). The page's own `load` runs for the fragment's request too (the
/// builder needs the page's data in scope): keep it cheap or cached (a page
/// with `cache:` keeps its fragments too), and leave what is heavy to [load].
/// The [id] names the piece in the page (`[A-Za-z0-9_-.]`) and must not
/// repeat. A static export keeps the [fallback] (there is no server to ask).
/// The piece can use `Watch` and the states of the page; a `query()` or a
/// `FutureBuilder` in it is waited for (the fragment goes out whole, like a
/// page that waits), and another `LazyPiece` in it is a piece of its own: its
/// fallback comes with the outer one and it loads when its trigger happens
/// (the URL names both: `thor-piece=outer:inner`).
class LazyPiece<T> extends StatelessWidget implements ThorBuiltIn {
  /// A piece called [id] that draws [builder] with what [load] returns.
  const LazyPiece({
    super.key,
    required this.id,
    required this.load,
    required this.builder,
    this.fallback,
    this.trigger = LazyTrigger.open,
  });

  /// Names the piece in the page: part of the fragment's URL.
  final String id;

  /// Gets what [builder] draws, on the server, when the browser asks (not
  /// when the page is drawn). `NotFound` and `HttpError` become the answer's
  /// status; the browser then keeps the [fallback].
  final Future<T> Function(PageRequest request) load;

  /// Draws the piece with what [load] returned.
  final Widget Function(BuildContext context, T data) builder;

  /// What the page shows until the piece arrives and always without
  /// JavaScript: usually a `Link` to a page with the same content.
  final Widget? fallback;

  /// What loads it (default: when the accordion, dialog or drawer around it
  /// opens).
  final LazyTrigger trigger;

  @override
  Widget build(BuildContext context) => _LazyPlace<T>(this, context);
}

// Marks what a lazy piece draws, and the path of ids from the page to it
// (`outer:inner`): a piece in it asks for itself by that path.
class _InLazy extends InheritedWidget {
  const _InLazy({required this.path, required super.child});

  final String path;

  @override
  bool updateShouldNotify(_InLazy oldComponent) => false;
}

final _lazyId = RegExp(r'^[A-Za-z0-9_.\-]+$');

// How many times a piece is drawn again for what it waited for.
const _lazyPasses = 8;

class _LazyPlace<T> extends PageComponent implements ThorBuiltIn {
  const _LazyPlace(this.owner, this.context);

  final LazyPiece<T> owner;
  final BuildContext context;

  @override
  void buildInto(
    PageBuild page,
    Element element,
    ParentNode into,
    BuildChild build,
  ) {
    final request = element
        .dependOnInheritedWidgetOfExactType<RequestScope>()
        ?.request;
    final run = element
        .dependOnInheritedWidgetOfExactType<DeferScope>()
        ?.holder
        .run;
    final parent = element.dependOnInheritedWidgetOfExactType<_InLazy>()?.path;
    final path = parent == null ? owner.id : '$parent:${owner.id}';
    // No request (a test, a render outside a route) or a page written as a
    // file (no server to ask): nothing to ask for, the fallback is the content.
    final url = request == null || run == null || request.isExport
        ? null
        : _urlOf(request.uri, path);
    if (url != null && !_lazyId.hasMatch(owner.id)) {
      throw ArgumentError.value(
        owner.id,
        'id',
        thorError(
          'THOR-R035',
          'LazyPiece(id: …) is part of a URL: use letters, digits, `-`, `_` '
              'and `.`',
        ),
      );
    }
    if (url != null) {
      final registry = ThorStyleRegistry.of(element);
      registry?.useLazyScript();
      final wanted = run!.lazyId;
      // The piece asked for, or one around it (its content holds the
      // piece asked for: drawn to reach it, and not answered).
      final target = wanted == path;
      if (run.lazy == null &&
          wanted != null &&
          (target || wanted.startsWith('$path:'))) {
        final slot = DeferSlot._(
          0,
          run,
          Future<Object?>.value(),
          Future<Object>.value(const DeferDone(null)),
          page,
          element,
          build,
          Zone.current,
          registry,
          (outcome) => _InLazy(
            path: path,
            child: owner.builder(context, (outcome as DeferDone).value as T),
          ),
          Future<Object?>.value(),
          (_, _) => null,
        );
        run.lazy = target
            ? (request) => _answer(slot, run, registry, request)
            : (request) async {
                final data = await owner.load(request);
                // The piece inside leaves its own answer here.
                run.lazy = null;
                slot.render(DeferDone(data));
                final inner = run.lazy;
                if (inner == null) throw const NotFound();
                return inner(request);
              };
      }
    }
    build(
      thorElement(
        'div',
        debugName: 'LazyPiece',
        attributes: {
          if (url != null) ...{
            'data-thor-lazy': url,
            'data-thor-lazy-on': owner.trigger.name,
          },
        },
        children: [?owner.fallback],
      ),
      element,
      into,
    );
  }

  /// Loads the piece and draws it, waiting for the futures and the queries
  /// it holds (the fragment is as complete as a page that waits).
  Future<DeferPiece> _answer(
    DeferSlot slot,
    DeferRun run,
    ThorStyleRegistry? registry,
    PageRequest request,
  ) async =>
      _drawPiece(slot, run, registry, owner.id, await owner.load(request));

  static String _urlOf(Uri page, String id) {
    try {
      // Every value of a repeated key (`?f=red&f=size-9`), not the last.
      final query = <String, Iterable<String>>{
        ...page.queryParametersAll,
        lazyPieceParameter: [id],
      };
      return Uri(path: page.path, queryParameters: query).toString();
    } on FormatException {
      // A query that does not decode: kept as it came.
      return Uri(
        path: page.path,
        query:
            '${page.query}&$lazyPieceParameter=${Uri.encodeQueryComponent(id)}',
      ).toString();
    }
  }
}

// Draws the piece [id] of a fragment request with [data]: what the page's
// ancestors of the piece drew is not the piece's, and the futures and the
// queries it holds are waited for (the fragment goes out whole).
Future<DeferPiece> _drawPiece(
  DeferSlot slot,
  DeferRun run,
  ThorStyleRegistry? registry,
  String id,
  Object? data, {
  bool sync = false,
}) async {
  // What the page's ancestors of the piece drew is not the piece's.
  registry?.forgetLateStates();
  if (sync) registry?.beginCapture();
  run.stream = false;
  DeferPiece? drawn;
  for (var pass = 1; ; pass++) {
    if (pass > _lazyPasses) {
      throw StateError(
        thorError(
          'THOR-R031',
          'a FutureBuilder inside the piece $id got a new future on every '
              'draw: create the future in the piece\'s `load`, not in '
              '`builder`',
        ),
      );
    }
    run.unresolved.clear();
    final next = slot.render(DeferDone(data));
    drawn = drawn == null ? next : drawn.then(next);
    var again = false;
    if (run.unresolved.isNotEmpty) {
      await run.settle();
      again = true;
    }
    if (await run.afterLazyDraw?.call() ?? false) again = true;
    if (!again) break;
  }
  // The values of the states it used, as they are once its queries ran; with
  // [sync], those of every state it reads, also the ones the page has.
  if (registry == null) return drawn;
  return sync
      ? drawn.withState(stateJson(registry.endCapture()), sync: true)
      : drawn.withState(stateJson(registry.lateStates));
}

// The URL of the page [page] with `thor-piece=<piece>` (when given) and the
// query value [param]=[value] (when given) in place of what it had; every
// other key keeps all its values (`?f=red&f=size-9`).
String _pieceUrl(Uri page, {String? piece, String? param, String? value}) {
  Map<String, Iterable<String>> query;
  try {
    query = {...page.queryParametersAll}..remove(lazyPieceParameter);
  } on FormatException {
    // A query that does not decode: kept as it came.
    final extra = [
      if (param != null) '$param=${Uri.encodeQueryComponent(value ?? '')}',
      if (piece != null)
        '$lazyPieceParameter=${Uri.encodeQueryComponent(piece)}',
    ].join('&');
    return Uri(
      path: page.path,
      query: [
        if (page.query.isNotEmpty) page.query,
        if (extra.isNotEmpty) extra,
      ].join('&'),
    ).toString();
  }
  if (param != null) query[param] = [value ?? ''];
  if (piece != null) query[lazyPieceParameter] = [piece];
  return Uri(
    path: page.path,
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

// Offers the answer of an inline piece (a [Region], a [LoadMore]): when the
// request asks for [path], [content] is what the browser gets. True for the
// piece asked for, whose place in the page's own draw then stays empty.
bool _offerInline(
  PageBuild page,
  Element element,
  BuildChild build,
  DeferRun run,
  ThorStyleRegistry? registry,
  String path,
  String id,
  Widget content, {
  bool sync = false,
}) {
  if (run.lazy != null || run.lazyId != path) return false;
  final slot = DeferSlot._(
    0,
    run,
    Future<Object?>.value(),
    Future<Object>.value(const DeferDone(null)),
    page,
    element,
    build,
    Zone.current,
    registry,
    (_) => _InLazy(path: path, child: content),
    Future<Object?>.value(),
    (_, _) => null,
  );
  run.lazy = (request) => _drawPiece(slot, run, registry, id, null, sync: sync);
  return true;
}

// The `id` of a piece (or the `param` of a `LoadMore`), or an error that says
// what it is: it is part of a URL.
void _checkPieceId(String value, String label) {
  if (_lazyId.hasMatch(value)) return;
  throw ArgumentError.value(
    value,
    label,
    thorError(
      'THOR-R035',
      '$label is part of a URL: use letters, digits, `-`, `_` and `.`',
    ),
  );
}

/// A part of the page that can be asked for alone: the server draws the page
/// as always and answers only this region (`GET` the page's URL plus
/// `thor-piece=<id>`), and the browser puts the answer in place of the
/// region's content. It is what a live search, a product shown in a dialog or
/// any "update this part" needs, with the page's own `load` and `build`
/// deciding what is inside.
///
/// ```dart
/// // The page's load reads `?q=`; the region is its results.
/// Form(
///   formMethod: FormMethod.get,
///   live: 'results',
///   child: TextFormField(name: 'q'),
/// )
/// Region(id: 'results', child: ResultsList(state.data)),
/// ```
///
/// Without JavaScript the `Form` submits and the page loads whole. What fills
/// a region from outside: `Form(live:)` (replaces its content as the visitor
/// types), `Link(fetch:)` (shows another page's region here) and, inside the
/// region, nothing: it is drawn by the page. The region's content may use
/// `Watch`, buttons and the states of the page.
///
/// A state the region reads keeps the value the page gave it when the region
/// is swapped, unless [syncState] is true: then the answer also carries the
/// current value of every state the region reads, and the browser replaces
/// the ones it has with them (see [syncState]).
///
/// `// web:` Flutter has no counterpart. The page's `load` runs for the
/// fragment's request too (the region needs the page's data in scope): keep it
/// cheap or give the page `cache:`, which keeps its fragments as well. The
/// [id] names the region in the page (`[A-Za-z0-9_-.]`) and must not repeat. A
/// static export draws the content with no region around it.
class Region extends StatelessWidget implements ThorBuiltIn {
  /// A region called [id] that holds [child].
  const Region({
    super.key,
    required this.id,
    required this.child,
    this.syncState = false,
  });

  /// Names the region in the page: part of the fragment's URL.
  final String id;

  /// Whether a swap of this region also updates the states it reads.
  ///
  /// By default a fragment brings the values only of states the page did not
  /// send yet; one the page already has keeps its current value, which is
  /// right for what the visitor changes in the browser (a counter, a typed
  /// draft). A state whose value comes from the server for this very region
  /// (the free slots of the week the region shows) would stay stale: with
  /// `syncState: true` the answer carries the value, as the server computed
  /// it for that request, of **every** state the region's content reads, and
  /// the running engine takes it over its own (the fields of the states, not
  /// only the HTML). Use it on regions whose states are server-derived; a
  /// field the visitor edits and the region reads is overwritten.
  ///
  /// `// web:` the lite engine applies the values; a state not running yet
  /// simply starts from them.
  final bool syncState;

  /// The content, drawn by the page and by the fragment's request.
  final Widget child;

  @override
  Widget build(BuildContext context) => _InlinePlace(
    context,
    id: id,
    widget: 'Region',
    sync: syncState,
    content: (request, path) => child,
    wrap: (content) => thorElement(
      'div',
      debugName: 'Region',
      // The region adds no box: its content lays out in the page's flow.
      css: const {'display': 'contents'},
      attributes: {'data-thor-region': id},
      children: [content],
    ),
  );
}

/// What makes a [LoadMore] fetch the next page.
enum LoadMoreTrigger {
  /// A click (or Enter) on the control.
  click,

  /// The control coming near the viewport: infinite scroll.
  visible,
}

/// The next page of a list the server drew, appended to it: the rows of a
/// listing, a "Load more" control after them, and no reload. The page's
/// `load` reads the position (`?cursor=…`) and the page draws its [items]
/// and the [next] cursor; the browser asks for the same page with the next
/// cursor, the server answers only this piece (the next rows and the next
/// control) and the browser puts it where the control was.
///
/// ```dart
/// Grid(
///   children: [
///     LoadMore(
///       id: 'places',
///       items: [for (final p in state.data.items) PlaceCard(p)],
///       next: state.data.next, // null: the last page, no control
///       child: const Text('Load more'),
///     ),
///   ],
/// )
/// ```
///
/// [child] is the control: a `Text`, a `Container`, a chip (not a button: it
/// becomes the `<a>`). It is a real link to the same page with `?cursor=…`
/// (`rel="next"`), so without JavaScript, for a search engine, with a modified
/// click or if the request fails, the visitor goes to the next page. A
/// [LoadMoreTrigger.visible] control loads by itself when it nears the
/// screen (infinite scroll).
///
/// [items] and the control are the widget's siblings in its parent: put it in
/// the `Column`, `Grid` or `Wrap` that holds the rows. The control keeps the
/// rest of the page's query (`?q=pizza&cursor=…`).
///
/// `// web:` Flutter's `ListView.builder` asks the model for more; here the
/// server draws the rows, the page's `load` runs for each request (keep the
/// rows' query cheap) and the state of the earlier rows stays in the browser.
class LoadMore extends StatelessWidget implements ThorBuiltIn {
  /// Rows [items] and a control for the page that follows [next].
  const LoadMore({
    super.key,
    required this.id,
    required this.items,
    required this.next,
    required this.child,
    this.param = 'cursor',
    this.trigger = LoadMoreTrigger.click,
  });

  /// Names the list in the page: part of the fragment's URL.
  final String id;

  /// The rows of this page.
  final List<Widget> items;

  /// The value of [param] for the next page, or null when there is none.
  final String? next;

  /// The control's content.
  final Widget child;

  /// The query key that carries [next] (`?cursor=…`).
  final String param;

  /// What makes the browser fetch the next page.
  final LoadMoreTrigger trigger;

  @override
  Widget build(BuildContext context) {
    _checkPieceId(param, 'LoadMore(param:)');
    return _InlinePlace(
      context,
      id: id,
      widget: 'LoadMore',
      content: (request, path) {
        final more = next;
        final control = more == null || request == null
            ? null
            : Widget.wrapElement(
                tag: 'a',
                attributes: {
                  'href': _pieceUrl(request.uri, param: param, value: more),
                  'rel': 'next',
                  if (!request.isExport) ...{
                    'data-thor-lazy': _pieceUrl(
                      request.uri,
                      piece: path,
                      param: param,
                      value: more,
                    ),
                    'data-thor-lazy-on': trigger.name,
                    'data-thor-lazy-as': 'replace',
                  },
                },
                child: child,
              );
        return Widget.fragment([...items, ?control]);
      },
      wrap: (content) => content,
    );
  }
}

// A piece the page draws itself and the server can answer alone: a [Region]
// or a [LoadMore]. [content] is the piece's widgets; [wrap] puts them in the
// page (with the attributes the page needs for the script).
class _InlinePlace extends PageComponent implements ThorBuiltIn {
  const _InlinePlace(
    this.context, {
    required this.id,
    required this.widget,
    required this.content,
    required this.wrap,
    this.sync = false,
  });

  final BuildContext context;
  final String id;
  final String widget;
  final Widget Function(PageRequest? request, String path) content;
  final Widget Function(Widget content) wrap;
  final bool sync;

  @override
  void buildInto(
    PageBuild page,
    Element element,
    ParentNode into,
    BuildChild build,
  ) {
    final request = element
        .dependOnInheritedWidgetOfExactType<RequestScope>()
        ?.request;
    final run = element
        .dependOnInheritedWidgetOfExactType<DeferScope>()
        ?.holder
        .run;
    final parent = element.dependOnInheritedWidgetOfExactType<_InLazy>()?.path;
    final path = parent == null ? id : '$parent:$id';
    // No request (a test, a render outside a route), a static export or no
    // run: nothing to ask the server for.
    final live = request != null && run != null && !request.isExport;
    final drawn = content(request, path);
    var mine = false;
    if (live) {
      _checkPieceId(id, '$widget(id:)');
      final registry = ThorStyleRegistry.of(element);
      registry?.useLazyScript();
      mine = _offerInline(
        page,
        element,
        build,
        run,
        registry,
        path,
        id,
        drawn,
        sync: sync,
      );
    }
    // The piece asked for is drawn by its answer, not twice.
    final inner = mine
        ? const Widget.empty()
        : _InLazy(path: path, child: drawn);
    build(live ? wrap(inner) : inner, element, into);
  }
}

/// The answer to a fragment request: [piece] as the browser inserts it (see
/// `lazyScript`): the rules the piece adds, its icons, its HTML, the values
/// of the states it uses and the engine when only it needs it.
///
/// [nonce] is the placeholder a Content-Security-Policy middleware turns into
/// this response's nonce; the piece's `<style>` carries it, and the loader
/// (which is given the same nonce in `x-thor-piece-nonce`) takes only the
/// styles that carry it, never one that came in as text.
List<int> lazyFragment(DeferPiece piece, {String? nonce}) {
  final out = BytesBuilder(copy: false)
    ..add(utf8.encode(pieceAssets(piece, nonce)))
    ..add(piece.html);
  final attributes = piece.sync
      ? 'data-thor-lazy-json data-thor-lazy-sync'
      : 'data-thor-lazy-json';
  if (pieceStateScript(piece, attributes) case final script?) {
    out.add(utf8.encode(script));
  }
  return (out..add(piece.engine)).takeBytes();
}

/// The rules and icons [piece] adds (`<style>` with the [nonce], the hidden
/// icon sprite): what a lazy fragment and a streamed piece both start with.
String pieceAssets(DeferPiece piece, String? nonce) {
  final out = StringBuffer();
  if (piece.css.isNotEmpty) {
    final attr = nonce == null ? '' : ' nonce="$nonce"';
    out.write('<style$attr>${piece.css}</style>');
  }
  if (piece.sprite.isNotEmpty) {
    out.write(
      '<svg aria-hidden="true" '
      'style="position:absolute;width:0;height:0;overflow:hidden">'
      '${piece.sprite}</svg>',
    );
  }
  return '$out';
}

/// The `<script type="application/json">` with the values of the states
/// [piece] uses, carrying [attributes] (`id="…"`, a data attribute); null
/// when there are none. A value that is not JSON is THOR-S041 naming its
/// field ([encodeStateJson]).
String? pieceStateScript(DeferPiece piece, String attributes) {
  if (piece.state.isEmpty) return null;
  // `<` escaped: no value can close the element.
  return '<script type="application/json" $attributes>'
      '${encodeStateJson(piece.state).replaceAll('<', r'\u003c')}</script>';
}

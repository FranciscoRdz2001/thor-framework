/// Browser runtime of thor_engine.
///
/// `hydrate([...bindings])` attaches the declared bindings to the HTML the
/// server rendered. It never builds a component tree: it finds the marked
/// nodes, runs one effect per binding and installs one delegated listener
/// per event type. Static HTML costs nothing.
library;

import 'dart:async' show Timer, scheduleMicrotask;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:thor_engine/src/reactive.dart' show collectEffects;
import 'package:thor_engine/thor_engine.dart';
import 'package:thor_engine_oracle/src/animations.dart';
import 'package:thor_engine_oracle/src/autocomplete_client.dart';
import 'package:thor_engine_oracle/src/carousel_client.dart';
import 'package:thor_engine_oracle/src/clipboard_client.dart';
import 'package:thor_engine_oracle/src/controllers_client.dart';
import 'package:thor_engine_oracle/src/date_picker_client.dart';
import 'package:thor_engine_oracle/src/dev_client.dart'
    show devReload, installDevState;
import 'package:thor_engine_oracle/src/dismissible_client.dart';
import 'package:thor_engine_oracle/src/dom_scan.dart';
import 'package:thor_engine_oracle/src/drag_drop_client.dart';
import 'package:thor_engine_oracle/src/dropdown_client.dart';
import 'package:thor_engine_oracle/src/element_events.dart';
import 'package:thor_engine_oracle/src/feedback_client.dart';
import 'package:thor_engine_oracle/src/gestures.dart';
import 'package:thor_engine_oracle/src/json_interop.dart';
import 'package:thor_engine_oracle/src/keyboard_nav_client.dart';
import 'package:thor_engine_oracle/src/lifecycle_client.dart';
import 'package:thor_engine_oracle/src/persisted_client.dart';
import 'package:thor_engine_oracle/src/probe.dart';
import 'package:thor_engine_oracle/src/reorderable_client.dart';
import 'package:thor_engine_oracle/src/shortcuts_client.dart';
import 'package:thor_engine_oracle/src/size_animation_client.dart';
import 'package:web/web.dart' as web;

export 'package:thor_engine/thor_engine.dart';
export 'package:thor_engine_oracle/src/animations.dart' show AnimationsFeature;
export 'package:thor_engine_oracle/src/autocomplete_client.dart'
    show AutocompleteFeature;
export 'package:thor_engine_oracle/src/carousel_client.dart'
    show CarouselFeature;
export 'package:thor_engine_oracle/src/clipboard_client.dart'
    show ClipboardFeature;
export 'package:thor_engine_oracle/src/controllers_client.dart'
    show ControllersFeature, VariablesFeature;
export 'package:thor_engine_oracle/src/date_picker_client.dart'
    show DatePickerFeature;
export 'package:thor_engine_oracle/src/dismissible_client.dart'
    show DismissibleFeature;
export 'package:thor_engine_oracle/src/drag_drop_client.dart'
    show DragDropFeature;
export 'package:thor_engine_oracle/src/dropdown_client.dart'
    show DropdownMenuFeature;
export 'package:thor_engine_oracle/src/element_events.dart'
    show ElementEventsFeature;
export 'package:thor_engine_oracle/src/events_client.dart' show EventsFeature;
export 'package:thor_engine_oracle/src/feedback_client.dart'
    show FeedbackFeature;
export 'package:thor_engine_oracle/src/gestures.dart' show GesturesFeature;
export 'package:thor_engine_oracle/src/keyboard_nav_client.dart'
    show MenuFeature, SplitPaneFeature, TabsFeature;
export 'package:thor_engine_oracle/src/lifecycle_client.dart'
    show LifecycleFeature;
export 'package:thor_engine_oracle/src/persisted_client.dart'
    show PersistedStatesFeature;
export 'package:thor_engine_oracle/src/reorderable_client.dart'
    show ReorderableFeature;
export 'package:thor_engine_oracle/src/row_readers.dart' show RowReaders;
export 'package:thor_engine_oracle/src/shortcuts_client.dart'
    show ShortcutsFeature, consumesKey;
export 'package:thor_engine_oracle/src/size_animation_client.dart'
    show SizeAnimationsFeature;

/// An optional part of the engine. The generated entry lists only the
/// features the app uses, so dart2js drops the others (a counter doesn't
/// ship list reconciliation or form validation).
abstract base class EngineFeature {
  /// Const constructor for subclasses.
  const EngineFeature();

  /// Adds the bindings of this feature's markers in [scope] ([startThor]);
  /// [member] resolves an id to its state member, [seen] dedupes ids. With
  /// [late] the scope is a part of the page that arrived after hydration:
  /// what the first call made for the page (a controller's driver) is kept,
  /// this one only adds what the part brings.
  void collect(
    web.Element scope,
    ThorMember Function(String id) member,
    List<Binding> bindings,
    Set<String> seen, {
    bool late = false,
  }) {}

  /// Installs page-wide behavior at hydration; [run] invokes an action of
  /// the page by id. Returns its undo.
  void Function()? install(web.Element scope, EngineRun run) => null;

  /// Follows which states the page still names (a state ends when its last
  /// element leaves): [life] ends and wakes them. Returns its undo.
  void Function()? followStates(
    web.Element scope,
    Iterable<ThorState> states,
    StateLife life,
  ) => null;

  /// What [install] did for the markup it found, for [part]: a part of the
  /// page that arrived after hydration (the page-wide listeners are on the
  /// scope already). Returns its undo.
  void Function()? installLate(web.Element part, EngineRun run) => null;

  /// Runs once the page is hydrated, with every state member of the page
  /// (a persisted field moves to its cookie then). Returns its undo.
  void Function()? afterHydration(Iterable<ThorMember> members) => null;
}

/// What [startThor] lets a feature do with the life of the states
/// ([EngineFeature.followStates]).
abstract interface class StateLife {
  /// Whether [state] runs: woken and not ended.
  bool isLive(ThorState state);

  /// Ends [state]: its `dispose()` runs (a throw is reported).
  void end(ThorState state);

  /// Wakes an ended [state] again: its `onHydrated()` runs.
  void wake(ThorState state);
}

/// `Watch` with a builder: finite states.
final class VariantsFeature extends EngineFeature {
  /// The feature.
  const VariantsFeature();

  @override
  void collect(
    web.Element scope,
    ThorMember Function(String id) member,
    List<Binding> bindings,
    Set<String> seen, {
    bool late = false,
  }) {
    for (final el in _deep(scope, '[$variantAttr]')) {
      final id = el.getAttribute(variantAttr)!;
      if (!seen.add('v$id')) continue;
      final (name, arg) = parseBindingId(id);
      final m = member(name);
      final values = m.variants;
      bindings.add(
        VariantBinding(
          id,
          count: values?.length ?? 0,
          index: () {
            final v = m.call!(arg);
            return values == null ? v! as int : values.indexOf(v);
          },
        ),
      );
    }
  }
}

/// `WatchRow`: keyed lists and row states.
final class ListsFeature extends EngineFeature {
  /// The feature; [rowAttributes] when a row binds attributes
  /// (`row.attribute`), which the generated entry passes only then.
  const ListsFeature({
    this.rowAttributes,
    this.animatedRows = false,
    this.virtualLists,
  });

  /// Whether a list animates its rows' exit (`AnimatedList`): a removed row
  /// stays, marked, for the time the container says, which the generated
  /// entry passes only then.
  final bool animatedRows;

  /// Per-row attributes (`row.attribute`), or null when no list binds them:
  /// dart2js then leaves their code (and the URL checks) out of the bundle.
  final RowAttributes? rowAttributes;

  /// Windowing of the lists that ask for it (`Watch.list(virtual: true)`), or
  /// null when none does: dart2js then leaves its code out of the bundle.
  final VirtualLists? virtualLists;

  @override
  void collect(
    web.Element scope,
    ThorMember Function(String id) member,
    List<Binding> bindings,
    Set<String> seen, {
    bool late = false,
  }) {
    // The same list can be shown twice (a sidebar and its drawer copy),
    // each with its own row template: one binding reads the fields of all.
    final containers = <String, List<web.Element>>{};
    for (final el in _deep(scope, '[$listAttr]')) {
      (containers[el.getAttribute(listAttr)!] ??= []).addAll(_listHosts(el));
    }
    for (final MapEntry(key: id, value: els) in containers.entries) {
      if (!seen.add('l$id')) continue;
      _rowAttributes ??= rowAttributes;
      if (animatedRows) _animatedRows = true;
      _virtualLists ??= virtualLists;
      // A list per instance (`Watch.list(state.branchOf.withArg(slug))`): the
      // id carries the argument the method gets.
      final (sourceName, sourceArg) = parseBindingId(id);
      final source = member(sourceName);
      final key = member(els[0].getAttribute(listKeyAttr)!);
      final fields = <String, String Function(Object? item)>{};
      final states = <String, int Function(Object? item)>{};
      final selections = <String, String Function()>{};
      for (final el in els) {
        final template = _templateOf(el);
        if (template == null || !template.isA<web.HTMLTemplateElement>()) {
          continue;
        }
        final content = (template as web.HTMLTemplateElement).content;
        // A row field's id is a binding id: the method, and a fixed
        // argument when it has one (`cellLabel.withArg(3)`).
        void field(String id) {
          if (fields.containsKey(id)) return;
          final (name, arg) = parseBindingId(id);
          final f = member(name);
          fields[id] = (item) => '${f.callItem(item, arg)}';
        }

        for (final el in _inFragment(content, '[$fieldAttr]')) {
          field(el.getAttribute(fieldAttr)!);
        }
        _rowAttributes?.fieldIds(content).forEach(field);
        for (final el in _inFragment(content, '[$rowVariantAttr]')) {
          final id = el.getAttribute(rowVariantAttr)!;
          final (name, arg) = parseBindingId(id);
          final m = member(name);
          // `row.selected`: the id is a field of a state, not a method of the
          // item (the first state of the template's element carries the mark).
          if (el.hasAttribute(rowSelectAttr)) {
            selections[id] = () => '${m.call!(arg)}';
            continue;
          }
          final values = m.variants;
          states[id] = (item) {
            final v = m.callItem(item, arg);
            return values == null ? v! as int : values.indexOf(v);
          };
        }
      }
      bindings.add(
        ListBinding<Object?>(
          id,
          items: () => source.call!(sourceArg)! as List<Object?>,
          key: (item) => '${key.callWithItem!(item)}',
          fields: fields,
          states: states,
          selections: selections,
        ),
      );
    }
  }
}

/// `Form` validation with the page's own messages.
final class FormsFeature extends EngineFeature {
  /// The feature.
  const FormsFeature();

  @override
  void Function()? install(web.Element scope, EngineRun run) =>
      _installValidation(scope);
}

/// The Invoker Commands polyfill (`DialogTrigger` / `DialogClose`).
final class CommandsFeature extends EngineFeature {
  /// The feature.
  const CommandsFeature();

  @override
  void Function()? install(web.Element scope, EngineRun run) =>
      _polyfillCommands(scope);
}

/// `onEnd` of implicit animations: one call per change, after every
/// property of the element finished (the browser fires one `transitionend`
/// per property).
final class TransitionsFeature extends EngineFeature {
  /// The feature.
  const TransitionsFeature();

  @override
  void Function()? install(web.Element scope, EngineRun run) {
    final running = Expando<int>('thor.transitions');
    void count(web.Event e, int delta) {
      final t = e.target;
      if (t == null) return;
      final left = (running[t] ?? 0) + delta;
      running[t] = left <= 0 ? null : left;
    }

    final run = ((web.Event e) => count(e, 1)).toJS;
    final cancel = ((web.Event e) => count(e, -1)).toJS;
    // Capture phase: runs before the engine's own listener, and stops the
    // event while other properties of the element are still running.
    final end = ((web.Event e) {
      final t = e.target;
      if (t == null) return;
      final left = (running[t] ?? 1) - 1;
      running[t] = left <= 0 ? null : left;
      if (left > 0) e.stopImmediatePropagation();
    }).toJS;
    scope
      ..addEventListener('transitionrun', run)
      ..addEventListener('transitioncancel', cancel)
      ..addEventListener('transitionend', end, true.toJS);
    return () => scope
      ..removeEventListener('transitionrun', run)
      ..removeEventListener('transitioncancel', cancel)
      ..removeEventListener('transitionend', end, true.toJS);
  }
}

/// Enter / Space on `role="button"` tap targets (`Gesture` on a
/// non-interactive element), like a native button.
final class KeyboardFeature extends EngineFeature {
  /// The feature.
  const KeyboardFeature();

  @override
  void Function()? install(web.Element scope, EngineRun run) {
    final keys = ((web.KeyboardEvent e) {
      if (e.key != 'Enter' && e.key != ' ') return;
      final t = e.target;
      if (t == null || !t.isA<web.Element>()) return;
      final el = t as web.Element;
      if (el.getAttribute('role') != 'button' || !el.hasAttribute(onAttr)) {
        return;
      }
      e.preventDefault();
      (el as web.HTMLElement).click();
    }).toJS;
    scope.addEventListener('keydown', keys);
    return () => scope.removeEventListener('keydown', keys);
  }
}

/// Runs the page's action [id] for [el]: with the element's fixed argument
/// (`data-tx`), [value] (a gesture's result), or both (`fixed~value`).
/// Without [el], [value] is the whole argument (a shortcut's `withArg`).
/// Returns the method's result (a `Focus.onKeyEvent`'s `KeyEventResult`).
typedef EngineRun =
    Object? Function(String id, web.Element? el, [String? value]);

/// Every feature. Not a default anywhere: referencing it keeps all of them
/// in the bundle, so only hand-written entries that want everything pass it.
const allEngineFeatures = <EngineFeature>[
  VariantsFeature(),
  ListsFeature(rowAttributes: RowAttributes(), virtualLists: VirtualLists()),
  FormsFeature(),
  CommandsFeature(),
  TransitionsFeature(),
  KeyboardFeature(),
  ElementEventsFeature(),
  SizeAnimationsFeature(),
  GesturesFeature(),
  DismissibleFeature(),
  DragDropFeature(),
  ReorderableFeature(),
  AnimationsFeature(),
  ShortcutsFeature(),
  ControllersFeature(),
  VariablesFeature(),
  ClipboardFeature(),
  FeedbackFeature(),
  DatePickerFeature(),
  DropdownMenuFeature(),
  TabsFeature(),
  MenuFeature(),
  PersistedStatesFeature(),
  LifecycleFeature(),
];

/// What the markup in [scope] needs that [features] leave out: one message
/// per missing feature, naming it and the marker that needs it. [startThor]
/// prints them in debug builds.
List<String> missingFeatures(web.Element scope, List<EngineFeature> features) {
  final commandsNative = (web.document.createElement('button') as JSObject).has(
    'command',
  );
  return [
    for (final (feature, name, selector) in [
      (VariantsFeature, 'VariantsFeature', '[$variantAttr]'),
      (ListsFeature, 'ListsFeature', '[$listAttr]'),
      (FormsFeature, 'FormsFeature', '[$validateAttr]'),
      (
        CommandsFeature,
        'CommandsFeature',
        commandsNative ? '[commandfor]:not(button):not(input)' : '[commandfor]',
      ),
      (TransitionsFeature, 'TransitionsFeature', '[$onAttr*="transitionend:"]'),
      (KeyboardFeature, 'KeyboardFeature', '[role="button"][$onAttr]'),
      (GesturesFeature, 'GesturesFeature', '[$gestureAttr]'),
      (DismissibleFeature, 'DismissibleFeature', '[$dismissibleAttr]'),
      (
        DragDropFeature,
        'DragDropFeature',
        '[$dragSourceAttr],[$dragTargetAttr]',
      ),
      (ReorderableFeature, 'ReorderableFeature', '[$reorderAttr]'),
      (ElementEventsFeature, 'ElementEventsFeature', '[$elementEventsAttr]'),
      (SizeAnimationsFeature, 'SizeAnimationsFeature', '[$sizeAnimationAttr]'),
      (
        CarouselFeature,
        'CarouselFeature',
        '[$carouselAttr],[$carouselControlsAttr]',
      ),
      (AnimationsFeature, 'AnimationsFeature', '[$animationAttr]'),
      (
        ShortcutsFeature,
        'ShortcutsFeature',
        '[$shortcutsAttr],[$intentShortcutsAttr],[$keyEventAttr]',
      ),
      (
        ControllersFeature,
        'ControllersFeature',
        '[$scrollControllerAttr],[$textControllerAttr],[$focusNodeAttr],'
            '[$dialogControllerAttr]',
      ),
      (
        VariablesFeature,
        'VariablesFeature',
        '[$variablesAttr],[$attributesAttr]',
      ),
      (
        DatePickerFeature,
        'DatePickerFeature',
        '[$datePickerAttr],[$pickerDialogAttr]',
      ),
      (DropdownMenuFeature, 'DropdownMenuFeature', '[$dropdownAttr]'),
      (TabsFeature, 'TabsFeature', '[$tabsAttr]'),
      (SplitPaneFeature, 'SplitPaneFeature', '[$splitPaneAttr]'),
      (MenuFeature, 'MenuFeature', '[$menuAttr]'),
      (AutocompleteFeature, 'AutocompleteFeature', '[$autocompleteAttr]'),
    ])
      if (!features.any((f) => f.runtimeType == feature) &&
          _deep(scope, selector).isNotEmpty)
        _missingFeature(name, selector),
    if (_deep(scope, '[$rowAttributesAttr]').isNotEmpty &&
        !features.any((f) => f is ListsFeature && f.rowAttributes != null))
      _rowAttributesMissing,
  ];
}

const _rowAttributesMissing =
    'thor: the page binds row attributes ([$rowAttributesAttr]) but the '
    'engine entry passes ListsFeature() without '
    '`rowAttributes: RowAttributes()`: those attributes stay as the server '
    'wrote them.';

String _missingFeature(String name, String selector) =>
    'thor: the page uses $name ($selector) but the engine entry leaves it '
    'out, so that part will not react. Widgets from another package are '
    'not scanned: set `thor: all_features: true` in the app pubspec.yaml.';

/// Attaches [bindings] to the document (or [root]) with [features] (texts
/// and actions are always on). Returns a function that detaches everything.
/// Low level: apps call [startThor] through the generated entry.
///
/// [late] is for a part of the page that arrived after hydration (`root` is
/// its top node): it binds what is in it and what [listening] (the event
/// types the page already handles, filled as types are added) doesn't cover,
/// and leaves what is page-wide (the features' `install`) to the first call; the
/// features' `installLate` prepares the part.
void Function() hydrate(
  List<Binding> bindings, {
  web.Element? root,
  List<EngineFeature> features = const [],
  bool late = false,
  Set<String>? listening,
}) {
  final scope = root ?? web.document.documentElement!;
  final disposers = <void Function()>[];
  _restoreState(bindings);

  // One pass over the marked nodes (a single selector), then plain lookups.
  final texts = <String, List<web.Element>>{};
  // Every element of a binding id is its own instance: the same state can
  // be watched twice (a chevron and the items it opens), or a sidebar
  // rendered twice (desktop and a drawer copy).
  final variants = <String, List<web.Element>>{};
  final types = <String>{};
  final listHosts = <String, List<web.Element>>{};
  final marked = withRoot(
    scope,
    '[$textAttr],[$variantAttr],[$onAttr],[$listAttr],'
    'template[$listTemplateAttr]',
  );
  for (final el in marked) {
    final text = el.getAttribute(textAttr);
    if (text != null) (texts[text] ??= []).add(el);
    final variant = el.getAttribute(variantAttr);
    if (variant != null) (variants[variant] ??= []).add(el);
    final list = el.getAttribute(listAttr);
    if (list != null) (listHosts[list] ??= []).addAll(_listHosts(el));
    if (el.hasAttribute(listTemplateAttr)) {
      final row = _rowOf(el);
      if (row != null) {
        // Handlers of rows that don't exist yet still need their listener.
        for (final r in [row, ..._all(row, '[$onAttr]')]) {
          final spec = r.getAttribute(onAttr);
          if (spec != null) types.addAll(decodeOn(spec).keys);
        }
      }
    }
    final on = el.getAttribute(onAttr);
    if (on != null) types.addAll(decodeOn(on).keys);
  }

  // Handlers that only a template carries (a state's other markup, a row)
  // still need their listener.
  for (final el in _deep(scope, '[$onAttr]')) {
    final spec = el.getAttribute(onAttr);
    if (spec != null) types.addAll(decodeOn(spec).keys);
  }

  _syncMixed(scope);

  // A variant whose states differ in structure is replaced by a copy of its
  // template: the text bindings inside the new subtree join their binding.
  final textBindings = {
    for (final b in bindings.whereType<TextBinding>()) b.id: b,
  };
  final variantBindings = {
    for (final b in bindings.whereType<VariantBinding>()) b.id: b,
  };
  final states = <String, _States>{};
  final actions = <String, Action>{};
  late final void Function(web.Element subtree, web.Element? replaced) adopt;
  late final void Function(web.Element row) wire;

  // One delegated listener per event type, on the scope (a late part: only
  // for the types the page's own listeners don't hear).
  final heard = <String>{};
  void listen(Iterable<String> kinds) {
    for (final type in kinds.toList()) {
      if (!heard.add(type) || !(listening?.add(type) ?? true)) continue;
      final enter = type == enterEvent;
      final listener = ((web.Event e) {
        if (enter) {
          final key = e as web.KeyboardEvent;
          if (key.key != 'Enter' || key.isComposing) return;
        }
        final target = e.target;
        if (target == null || !target.isA<web.Element>()) return;
        final origin = target as web.Element;
        // Bubbling like the browser's (and the lite runtime's): the closest
        // `data-t-on` that handles this type wins; one that does not lets the
        // event go on to the next ancestor, until stopPropagation.
        var el = ownEventOnly(type) ? origin : origin.closest('[$onAttr]');
        String? id;
        while (el != null) {
          final spec = el.getAttribute(onAttr);
          if (spec != null && (id = decodeOn(spec)[type]) != null) break;
          el = ownEventOnly(type) || e.cancelBubble
              ? null
              : el.parentElement?.closest('[$onAttr]');
        }
        if (el == null || id == null) return;
        final action = actions[id];
        if (action == null) return;
        // A handled submit stays on the page (the browser already validated);
        // Enter in a field, or a click on a submit button, runs its action
        // instead of posting the form (the post is the no-JS path).
        if (type == 'submit' ||
            enter ||
            (type == 'click' && (_isSubmit(el) || _isPlainLinkClick(el, e)))) {
          e.preventDefault();
        }
        final fixed = el.getAttribute(argAttr);
        final value = _controlValue(origin) ?? _eventDetail(e);
        action.run(
          fixed == null
              ? value
              : el.hasAttribute(argWithValueAttr)
              ? bindingId(fixed, value ?? '')
              : fixed,
        );
        if (enter &&
            el.hasAttribute(clearAttr) &&
            origin.isA<web.HTMLInputElement>()) {
          (origin as web.HTMLInputElement).value = '';
        }
        if (type == 'change') _keepControlled(origin);
      }).toJS;
      final domType = enter ? 'keydown' : type;
      scope.addEventListener(domType, listener);
      disposers.add(() => scope.removeEventListener(domType, listener));
    }
  }

  // The elements a subtree brought (a row the browser cloned, a state's
  // other markup): kept apart from the page's own, they are dropped once
  // they are not in the page (`prune`).
  final wiredTexts = <String, List<web.Element>>{};
  final lists = <String, _Lists>{};
  var wired = 0, cap = 256, pruning = false;

  /// Drops what a subtree that left the page left bound: texts, instances
  /// and list containers of rows that were removed.
  void prune() {
    pruning = false;
    wired = 0;
    for (final nodes in wiredTexts.values) {
      nodes.removeWhere((n) => !n.isConnected);
      wired += nodes.length;
    }
    for (final group in states.values) {
      group.all.removeWhere((i) => i.wired && !i.live.isConnected);
      wired += group.all.length;
    }
    for (final group in lists.values) {
      group.all.removeWhere((l) => l.wired && !l.container.isConnected);
    }
    cap = wired * 2 < 256 ? 256 : wired * 2;
  }

  void tracked(int count) {
    wired += count;
    if (wired > cap && !pruning) {
      pruning = true;
      // After the rows that are being made are in the page.
      scheduleMicrotask(prune);
    }
  }

  // The states in [first], a group: made when a state is first met inside
  // a subtree (its Watch lived in a template), at the state the server drew
  // there.
  _States? groupOf(String id, web.Element first) {
    final found = states[id];
    if (found != null) return found;
    final b = variantBindings[id];
    if (b == null) return null;
    final group = states[id] = _States(b.index, initial: _drawn(first));
    disposers.add(
      effect(() {
        final index = b.index();
        group.all.removeWhere((i) => i.wired && !i.live.isConnected);
        for (final instance in group.all.toList()) {
          instance.sync(index, adopt);
        }
      }),
    );
    return group;
  }

  // A list container that joins its list: the rows it holds, and the items.
  void join(String id, web.Element host, {bool wired = false}) {
    final group = lists[id];
    if (group == null) return;
    if (group.all.any((l) => identical(l.container, host))) return;
    final state = _ListState(
      host,
      switch (_templateOf(host)) {
        final t? => _rowOf(t),
        null => null,
      },
      group.binding.fieldsOf,
      group.binding.states.isEmpty ? null : group.binding.statesOf,
      wire: wire,
      wired: wired,
    ).._selected = group.selected;
    state.window = _virtualLists?._attach(state);
    group.all.add(state);
    final entries = group.entries;
    if (entries != null) group.reads?.add(() => state.update(entries));
  }

  // The bindings of a subtree that came into the page after the first scan
  // (`subtree`): a row cloned from a template, the markup of another state
  // of a variant, a part that arrived late. `replaced` is what it took the
  // place of, if anything: the states, texts and lists in it move to the
  // copy (the instances that lived there keep their state).
  //
  // So do the states inside it: the instances that lived in the replaced
  // subtree move, in document order, to the fresh copy of the server's
  // markup and catch up with their current value; a state only the copy
  // has gets a new instance, one only the old subtree had is dropped.
  adopt = (web.Element subtree, web.Element? replaced) {
    final gone = replaced == null
        ? <web.Element>[]
        : _all(replaced, '[$variantAttr]');
    final moved = <_Instance>[];
    for (final el in _all(subtree, '[$variantAttr]')) {
      final id = el.getAttribute(variantAttr)!;
      final group = groupOf(id, el);
      if (group == null) continue;
      _Instance? instance;
      for (final old in gone) {
        instance = group.of(old);
        if (instance != null) {
          gone.remove(old);
          break;
        }
      }
      if (instance == null) {
        instance = _Instance(group, el, wired: replaced == null);
        // A state can bring a handler the live markup doesn't have.
        for (final ops in instance.ops.values) {
          for (final op in ops) {
            if (op.attr == onAttr && op.value != null) {
              listen(decodeOn(op.value!).keys);
            }
          }
        }
      } else {
        instance.bind(el);
      }
      moved.add(instance);
    }
    for (final old in gone) {
      final group = states[old.getAttribute(variantAttr)];
      group?.all.remove(group.of(old));
    }
    // Bound first, synced after: a state that replaces its own element
    // finds the ones inside it already on the copy. One dropped meanwhile
    // (its outer state replaced it again) is left alone.
    for (final instance in moved) {
      if (subtree.contains(instance.live)) {
        instance.sync(untracked(instance.group.index), adopt);
      }
    }
    // Features with state of their own in the DOM (a controller's text)
    // bring the copy up to date.
    if (replaced != null) subtree.dispatchEvent(web.CustomEvent(adoptedEvent));
    if (replaced != null) {
      for (final el in [replaced, ..._all(replaced, '[$textAttr]')]) {
        final id = el.getAttribute(textAttr);
        if (id == null) continue;
        texts[id]?.remove(el);
        wiredTexts[id]?.remove(el);
      }
    }
    var count = moved.length;
    for (final el in [subtree, ..._all(subtree, '[$textAttr]')]) {
      final id = el.getAttribute(textAttr);
      final b = id == null ? null : textBindings[id];
      if (b == null) continue;
      (wiredTexts[id!] ??= []).add(el);
      count++;
      _setText(el, untracked(b.text));
    }
    // The lists inside: the containers of the old subtree leave theirs, the
    // copy's join (their rows are the server's, or come from the items).
    if (replaced != null) {
      for (final group in lists.values) {
        group.all.removeWhere((l) => replaced.contains(l.container));
      }
    }
    for (final el in withRoot(subtree, '[$listAttr]')) {
      final id = el.getAttribute(listAttr)!;
      for (final host in _listHosts(el)) {
        join(id, host, wired: true);
        count++;
      }
    }
    tracked(count);
  };

  // A row the browser cloned: its other states, texts and lists.
  wire = (web.Element row) => adopt(row, null);

  for (final b in bindings) {
    switch (b) {
      case TextBinding():
        final nodes = texts[b.id] ??= [];
        final more = wiredTexts[b.id] ??= [];
        disposers.add(
          effect(() {
            final text = b.text();
            for (final n in nodes) {
              _setText(n, text);
            }
            if (more.isNotEmpty) {
              more.removeWhere((n) => !n.isConnected);
              for (final n in more) {
                _setText(n, text);
              }
            }
          }),
        );
      case VariantBinding():
        final els = variants[b.id] ?? const <web.Element>[];
        if (els.isEmpty && late) {
          // Met only in this part's templates: made when one is brought in.
          continue;
        }
        // The server's state, as lite's `group`: the client's value, unless
        // the element ships that value as a patch or a template (the JSON
        // of `#thor-state` or an `events()` default disagrees with the
        // markup): then the state the server drew, so the first effect
        // brings the markup to the client's value.
        int? initial;
        if (els.isNotEmpty) {
          final drawn = _drawn(els.first);
          if (late) {
            initial = drawn;
          } else {
            final now = untracked(b.index);
            initial = _seenOf(els.first).contains(now) ? drawn : now;
          }
        }
        final group = states[b.id] = _States(b.index, initial: initial);
        for (final el in els) {
          // A state can bring a handler the live markup doesn't have (a
          // button enabled in another state): its event needs a listener.
          for (final ops in _Instance(group, el).ops.values) {
            for (final op in ops) {
              if (op.attr == onAttr && op.value != null) {
                types.addAll(decodeOn(op.value!).keys);
              }
            }
          }
        }
        disposers.add(
          effect(() {
            final index = b.index();
            group.all.removeWhere((i) => i.wired && !i.live.isConnected);
            for (final instance in group.all.toList()) {
              instance.sync(index, adopt);
            }
          }),
        );
      case ListBinding():
        final group = lists[b.id] = _Lists(b);
        // The rows render under `reads`, apart from the items: a read
        // outside the item (another state's field) that changes renders
        // every row again. A list that reads only its items keeps no source.
        void render(List<(String, Object?)> entries, {required bool all}) {
          for (final state in group.all.toList()) {
            if (all) state.generation++;
            state.update(entries);
          }
        }

        final reads = group.reads = RowReads(
          () => render(group.entries!, all: true),
        );
        disposers
          ..add(reads.dispose)
          ..add(
            effect(() {
              final entries = group.entries = b.entries();
              // A read outside the items moved too (both in one batch).
              final all = reads.changed;
              group.all.removeWhere((l) => l.wired && !l.container.isConnected);
              all
                  ? reads.rebuild(() => render(entries, all: true))
                  : reads.add(() => render(entries, all: false));
            }),
          );
        // A `row.selected` field is read here, once for the list: only the rows
        // that were and are now selected change state (Solid's `createSelector`).
        for (final MapEntry(key: sid, value: read) in b.selections.entries) {
          disposers.add(
            effect(() {
              final next = read();
              final prev = group.selected[sid];
              group.selected[sid] = next;
              if (prev == null || prev == next) return;
              for (final state in group.all.toList()) {
                state.reselect(prev, next);
              }
            }),
          );
        }
        // Each container (the same list shown twice) keeps its own rows.
        for (final host in listHosts[b.id] ?? const <web.Element>[]) {
          join(b.id, host);
        }
      case Action():
        actions[b.id] = b;
      case StateBinding():
        break; // restored before hydration
    }
  }

  listen(types);

  assert(() {
    EngineRetained retained() => EngineRetained(
      [for (final n in wiredTexts.values) ...n].length,
      [for (final g in states.values) ...g.all].length,
      [for (final g in lists.values) ...g.all].length,
      disposers.length,
    );
    EngineProbe.sources.add(retained);
    disposers.add(() => EngineProbe.sources.remove(retained));
    return true;
  }());

  Object? run(String id, web.Element? el, [String? value]) {
    final action = actions[id];
    if (action == null) return null;
    final fixed = el?.getAttribute(argAttr);
    return action.run(
      fixed == null
          ? value
          : value == null
          ? fixed
          : bindingId(fixed, value),
    );
  }

  if (late) {
    for (final f in features) {
      final undo = f.installLate(scope, run);
      if (undo != null) disposers.add(undo);
    }
  } else {
    for (final f in features) {
      final undo = f.install(scope, run);
      if (undo != null) disposers.add(undo);
    }

    // The page's deferred loader (if any) replays the events it queued while
    // the engine was loading.
    web.document.dispatchEvent(web.CustomEvent(hydratedEvent));
  }

  return () {
    for (final d in disposers) {
      d();
    }
  };
}

/// The elements of one `Watch` binding id with finite states.
class _States {
  _States(this.index, {int? initial}) : initial = initial ?? untracked(index);

  final int Function() index;

  /// The server's state: the one every copy of its markup shows.
  final int initial;
  final List<_Instance> all = [];

  _Instance? of(web.Element el) {
    for (final i in all) {
      if (identical(i.live, el)) return i;
    }
    return null;
  }
}

/// One element of a [_States]: its own states (the `<template>`s after it
/// and its own patches) and where it is.
class _Instance {
  _Instance(this.group, this.live, {this.wired = false})
    : current = group.initial {
    group.all.add(this);
    bind(live);
  }

  final _States group;

  /// Brought in by a subtree after the first scan (a row, a late part): it
  /// is dropped once it is no longer in the page.
  final bool wired;
  web.Element live;
  int current;
  Map<int, web.Element> sources = {};
  Map<int, List<PatchOp>> ops = {};

  // The live markup is the server's state: before the first switch, keep
  // what's needed to come back to it.
  web.Element? pristine;
  List<PatchOp>? base;

  /// Moves to [el]: the server's markup, or a fresh copy of it (a state
  /// inside a replaced state) with this state's templates or patches as
  /// the server rendered them there.
  void bind(web.Element el) {
    live = el;
    final fresh = <int, web.Element>{
      for (
        var t = el.nextElementSibling;
        t != null &&
            t.getAttribute(variantTemplateAttr) == el.getAttribute(variantAttr);
        t = t.nextElementSibling
      )
        int.parse(t.getAttribute(variantIndexAttr)!):
            ?(t as web.HTMLTemplateElement).content.firstElementChild,
    };
    if (fresh.isNotEmpty) sources = fresh;
    final freshOps = _patchesOf(el);
    if (freshOps.isNotEmpty) ops = freshOps;
    current = group.initial;
    base = null;
    // States inside this one: kept at the server's state now, so every
    // copy made from here shows them as their templates and patches expect.
    pristine = sources.isNotEmpty && el.querySelector('[$variantAttr]') != null
        ? el.cloneNode(true) as web.Element
        : null;
  }

  void sync(int index, void Function(web.Element, web.Element) adopt) {
    _wireComposition();
    // A swap would end an IME composition in progress in a field inside the
    // state: it waits for the composition to end (same as lite).
    if (_ime != null && live.contains(_ime)) {
      _late[this] = adopt;
      return;
    }
    if (index == current) return;
    var el = live;
    if (sources.isNotEmpty) pristine ??= el.cloneNode(true) as web.Element;
    base ??= _baseOf(el, ops.values);
    // Back to the server's state, then to the target. A state with another
    // structure replaces the element (then `live` follows).
    void to(web.Element source) {
      // States inside the state: their templates can differ from one state
      // to another, so the subtree is replaced and they move to the copy
      // (adopt) instead of being patched in place.
      final next =
          source.querySelector('[$variantAttr]') != null ||
              _bound(el) != _bound(source)
          ? _replace(el, source)
          : _patch(el, source);
      if (identical(next, el)) return;
      final old = el;
      live = el = next;
      adopt(next, old);
    }

    if (current != group.initial) {
      if (ops.containsKey(current)) _apply(el, base!);
      if (sources.containsKey(current)) to(pristine!);
    }
    if (ops[index] case final target?) _apply(el, target);
    if (sources[index] case final target?) to(target);
    _syncMixed(el);
    live = el;
    current = index;
  }
}

web.Node? _ime;
final _late = <_Instance, void Function(web.Element, web.Element)>{};
var _compositionWired = false;

void _wireComposition() {
  if (_compositionWired) return;
  _compositionWired = true;
  web.window.addEventListener(
    'compositionstart',
    ((web.Event e) => _ime = e.target as web.Node?).toJS,
    true.toJS,
  );
  web.window.addEventListener(
    'compositionend',
    ((web.Event _) {
      _ime = null;
      web.window.setTimeout(
        (() {
          final late = {..._late};
          _late.clear();
          for (final MapEntry(key: instance, value: adopt) in late.entries) {
            if (instance.live.isConnected) {
              instance.sync(untracked(instance.group.index), adopt);
            }
          }
        }).toJS,
        0.toJS,
      );
    }).toJS,
    true.toJS,
  );
}

/// What [el] binds, in document order: a patch leaves a bound element
/// alone, so states that bind other members there are another structure
/// (the copy replaces the element and its bindings move to it).
String _bound(web.Element el) => [
  for (final e in _all(
    el,
    '[$textAttr],[$fieldAttr],[$variantAttr],[$rowVariantAttr],[$listAttr]',
  ))
    [
      for (final a in const [
        textAttr,
        fieldAttr,
        variantAttr,
        rowVariantAttr,
        listAttr,
      ])
        e.getAttribute(a),
    ].join(','),
].join(';');

/// The state the server drew in [el]: the first index that its other states
/// (patches and templates) don't cover. A state met only inside another
/// state's template starts there.
int _drawn(web.Element el) {
  final seen = _seenOf(el);
  var i = 0;
  while (seen.contains(i)) {
    i++;
  }
  return i;
}

/// The states [el] ships as a patch or a template: not the one it draws.
Set<int> _seenOf(web.Element el) {
  final id = el.getAttribute(variantAttr);
  final seen = <int>{
    for (final n in el.getAttributeNames().toDart)
      if (n.toDart.startsWith('$patchAttr-'))
        int.parse(n.toDart.substring(patchAttr.length + 1)),
  };
  for (
    var t = el.nextElementSibling;
    t != null && t.getAttribute(variantTemplateAttr) == id;
    t = t.nextElementSibling
  ) {
    seen.add(int.parse(t.getAttribute(variantIndexAttr)!));
  }
  return seen;
}

/// A list's row template (its `<template>`'s element), with the states of
/// the row's own element (`row.watch` as the row) moved into it.
web.Element? _rowOf(web.Element template) {
  final row = (template as web.HTMLTemplateElement).content.firstElementChild;
  // Its other states are the row's next siblings; keep them with it.
  for (var next = row?.nextElementSibling; next != null;) {
    final state = next;
    next = next.nextElementSibling;
    if (state.hasAttribute(rowVariantTemplateAttr)) row!.append(state);
  }
  return row;
}

/// The row template among [el]'s own children (of the list [el] marks):
/// rows come before it, and what a `container:` puts after the rows (a
/// footer) after it.
web.Element? _templateOf(web.Element el) {
  final id = el.getAttribute(listAttr);
  for (var t = el.lastElementChild; t != null; t = t.previousElementSibling) {
    if (t.hasAttribute(listTemplateAttr) &&
        (id == null || t.getAttribute(listTemplateAttr) == id)) {
      return t;
    }
  }
  return null;
}

/// The elements that hold a list's rows. `container:` may wrap it in another
/// element (`Center`, `DecoratedBox`): the marker sits on the outer one, the
/// rows and their template on the inner one, which is where the list works.
/// The marker moves there (the rest of the engine looks for it). A container
/// with several roots (a list per breakpoint) has a box around them: every
/// copy is a host.
List<web.Element> _listHosts(web.Element el) {
  if (_templateOf(el) != null) return [el];
  final id = el.getAttribute(listAttr);
  final hosts = <web.Element>[];
  for (final t in _all(el, 'template[$listTemplateAttr]')) {
    final host = t.parentElement;
    if (host == null ||
        t.getAttribute(listTemplateAttr) != id ||
        !identical(host.closest('[$listAttr]'), el) ||
        hosts.contains(host)) {
      continue;
    }
    hosts.add(host);
  }
  for (final host in hosts) {
    for (final a in [listAttr, listKeyAttr, listVirtualAttr]) {
      final v = el.getAttribute(a);
      if (v != null) host.setAttribute(a, v);
    }
  }
  if (hosts.isEmpty) return [el];
  el
    ..removeAttribute(listAttr)
    ..removeAttribute(listKeyAttr)
    ..removeAttribute(listVirtualAttr);
  return hosts;
}

/// [root] if it matches [selector], and what it holds that does (a part of
/// the page that arrived after hydration is a list of such roots).
/// [withRoot] and what the `<template>`s under [root] hold, at any depth: the
/// other states of a variant and the row of a list are in the page as
/// templates, and what they bind (a state met only there, a list in a
/// variant, another state's text in a row) needs its binding before a copy
/// of them is put in the page.
List<web.Element> _deep(web.Element root, String selector) {
  final out = <web.Element>[if (root.matches(selector)) root];
  void walk(web.NodeList found, web.NodeList templates) {
    for (var i = 0; i < found.length; i++) {
      out.add(found.item(i)! as web.Element);
    }
    for (var i = 0; i < templates.length; i++) {
      final content = (templates.item(i)! as web.HTMLTemplateElement).content;
      walk(
        content.querySelectorAll(selector),
        content.querySelectorAll('template'),
      );
    }
  }

  walk(root.querySelectorAll(selector), root.querySelectorAll('template'));
  return out;
}

List<web.Element> _all(web.Element root, String selector) {
  final list = root.querySelectorAll(selector);
  return [for (var i = 0; i < list.length; i++) list.item(i)! as web.Element];
}

List<web.Element> _inFragment(web.DocumentFragment root, String selector) {
  final list = root.querySelectorAll(selector);
  return [for (var i = 0; i < list.length; i++) list.item(i)! as web.Element];
}

/// Windowing of engine lists (`Watch.list(virtual: true)`, `data-tlv`): an
/// optional part of [ListsFeature], so an app that has none doesn't ship it.
///
/// The server draws every row (it works without JS, find in page, SEO); once
/// the list runs, only the rows near the viewport stay in the page and two
/// spacers (`aria-hidden`, the one thing the client sizes) stand in for the
/// others, so the scrollbar and the offsets stay as if all were there. Rows
/// have a fixed extent, so which rows are visible is arithmetic over the
/// scroller's position. The window moves only when the visible rows come
/// within half the overscan of its edge; a row with the focus in it stays in
/// the page so a scroll doesn't drop the focus; rows say their place in the
/// whole list (`aria-setsize`, `aria-posinset`). The lite engine's
/// `virtual_list` part does the same.
final class VirtualLists {
  /// The part.
  const VirtualLists();

  _Window? _attach(_ListState list) {
    final x = double.tryParse(
      list.container.getAttribute(listVirtualAttr) ?? '',
    );
    if (x == null || x <= 0 || list.template == null) return null;
    return _Window(list, x);
  }
}

VirtualLists? _virtualLists;

class _Window {
  _Window(this.list, this.extent) {
    final c = list.container;
    top = _spacer();
    bottom = _spacer();
    c.insertBefore(top, c.firstChild);
    c.insertBefore(bottom, list._templateNode());
  }

  final _ListState list;
  final double extent;
  late final web.HTMLElement top;
  late final web.HTMLElement bottom;
  List<(String, Object?)> all = const [];
  int start = 0;
  int end = 0;
  int _frame = 0;
  bool _started = false;
  web.Element? _scroller;

  static web.HTMLElement _spacer() {
    final d = web.document.createElement('div') as web.HTMLElement;
    d.setAttribute('aria-hidden', 'true');
    d.style.setProperty('flex', 'none');
    return d;
  }

  // The list itself when it scrolls (a `ListView` is its own scroller), else
  // the nearest ancestor that does.
  static web.Element? _scrollerOf(web.Element el) {
    for (
      web.Element? p = el;
      p != null && p != web.document.body;
      p = p.parentElement
    ) {
      final o = web.window.getComputedStyle(p).overflowY;
      if (o == 'auto' || o == 'scroll' || o == 'overlay') return p;
    }
    return null;
  }

  void set(List<(String, Object?)> entries) {
    all = entries;
    if (!_started) {
      _started = true;
      final sc = _scroller = _scrollerOf(list.container);
      final later = ((JSAny? _) => _later()).toJS;
      (sc ?? web.window).addEventListener(
        'scroll',
        later,
        web.AddEventListenerOptions(passive: true),
      );
      web.window.addEventListener('resize', later);
      web.ResizeObserver(
        ((JSArray<web.ResizeObserverEntry> _, web.ResizeObserver _) => _later())
            .toJS,
      ).observe(sc ?? list.container);
    }
    sync(force: true);
  }

  void _later() {
    if (_frame != 0) return;
    _frame = web.window.requestAnimationFrame(
      ((num _) {
        _frame = 0;
        untracked(sync);
      }).toJS,
    );
  }

  void sync({bool force = false}) {
    final c = list.container;
    if (!c.isConnected) return;
    final n = all.length;
    final box = _scroller?.getBoundingClientRect();
    final vt = box?.top ?? 0.0;
    final vb = box?.bottom ?? web.window.innerHeight.toDouble();
    final o = top.getBoundingClientRect().top;
    final over = math.max(8, ((vb - vt) / extent / 2).ceil());
    final va = math.max(0, ((vt - o) / extent).floor());
    final vz = math.min(n, ((vb - o) / extent).ceil());
    // The window still covers the visible rows with half the overscan to spare.
    if (!force &&
        (start == 0 || va - over / 2 >= start) &&
        (end == n || vz + over / 2 <= end)) {
      return;
    }
    start = math.min(n, math.max(0, va - over));
    end = math.max(start, math.min(n, vz + over));
    final slice = all.sublist(start, end);
    var pin = -1;
    var above = false;
    final f = web.document.activeElement;
    if (f != null && f != web.document.body && c.contains(f)) {
      String? key;
      for (final e in list.rows.entries) {
        if (e.value.element.contains(f)) {
          key = e.key;
          break;
        }
      }
      final i = key == null ? -1 : all.indexWhere((e) => e.$1 == key);
      if (i >= 0 && (i < start || i >= end)) {
        pin = i;
        above = i < start;
        if (above) {
          slice.insert(0, all[i]);
        } else {
          slice.add(all[i]);
        }
      }
    }
    list.apply(slice);
    final shift = pin >= 0 && above ? 1 : 0;
    top.style.height = _px((start - shift) * extent);
    bottom.style.height = _px(
      (n - end - (pin >= 0 && !above ? 1 : 0)) * extent,
    );
    for (var j = 0; j < slice.length; j++) {
      final at = pin >= 0 && (above ? j == 0 : j == slice.length - 1)
          ? pin
          : start + j - shift;
      final el = list.rows[slice[j].$1]?.element;
      if (el == null) continue;
      if (el.getAttribute('aria-posinset') != '${at + 1}') {
        el.setAttribute('aria-posinset', '${at + 1}');
      }
      if (el.getAttribute('aria-setsize') != '$n') {
        el.setAttribute('aria-setsize', '$n');
      }
    }
  }

  static String _px(double v) => '${v == v.roundToDouble() ? v.round() : v}px';
}

/// Per-row attributes of engine lists (`row.attribute`): an optional part
/// of [ListsFeature], so an app whose rows bind none doesn't ship it.
final class RowAttributes {
  /// The part.
  const RowAttributes();

  /// The field ids the bound attributes in a row template read.
  Iterable<String> fieldIds(web.DocumentFragment template) => [
    for (final el in _inFragment(template, '[$rowAttributesAttr]'))
      ...decodeOn(el.getAttribute(rowAttributesAttr)!).values,
  ];

  /// The bound attributes of a rendered [row]: (element, name, field id).
  List<(web.Element, String, String)> inRow(web.Element row) => [
    for (final el in [row, ..._all(row, '[$rowAttributesAttr]')])
      if (el.getAttribute(rowAttributesAttr) case final bound?)
        for (final e in decodeOn(bound).entries) (el, e.key, e.value),
  ];

  /// Adds [el]'s bound attributes to a row plan, at [path].
  void plan(
    web.Element el,
    List<int> path,
    List<(List<int>, String, String)> out,
  ) {
    final bound = el.getAttribute(rowAttributesAttr);
    if (bound == null) return;
    for (final e in decodeOn(bound).entries) {
      out.add((path, e.key, e.value));
    }
  }

  /// Writes a row's bound attributes from its field [texts] (sanitized).
  void write(
    List<(web.Element, String, String)> attributes,
    Map<String, String> texts,
  ) {
    for (final (el, name, id) in attributes) {
      final value = texts[id];
      if (value != null) writeBoundAttribute(el, name, value);
    }
  }
}

/// The page's [RowAttributes], set by [ListsFeature] when it has one.
RowAttributes? _rowAttributes;

class _Row {
  _Row(this.key, this.element, this.fields, this.states, this.attributes);

  final String key;

  /// The row's element. A state of the row element itself with another
  /// structure replaces it ([_ListState._swapped]).
  web.Element element;

  /// Field name → its elements (a text and a hidden input can show the
  /// same field), found once.
  Map<String, List<web.Element>> fields;

  /// Bound attributes: (element, attribute name, field id).
  List<(web.Element, String, String)> attributes;

  /// Row-state name → its element (same structure in every state).
  Map<String, web.Element> states;

  /// The item last rendered (identical item → nothing to do).
  Object? item = _unset;

  /// The list's generation when the row last rendered: one that moved (a
  /// read outside the items changed) renders the row again.
  int generation = 0;
}

const _unset = Object();

/// Keyed reconciliation of one list container:
/// 1. rows whose key is gone are removed first;
/// 2. texts are written only for items that changed (identity, then text);
/// 3. only rows outside the longest increasing subsequence of the old order
///    move, so a swap moves two nodes, not the whole list;
/// 4. when every row is new they are inserted in one fragment.
/// What cloning a row needs, computed once from the template: where the
/// fields are and which attributes hold the key placeholder.
class _RowPlan {
  _RowPlan(web.Element template) {
    void walk(web.Element el, List<int> path) {
      final field = el.getAttribute(fieldAttr);
      if (field != null) (fields[field] ??= []).add(path);
      _rowAttributes?.plan(el, path, attributes);
      if (el.hasAttribute(textAttr) ||
          el.hasAttribute(variantAttr) ||
          el.hasAttribute(listAttr)) {
        wires = true;
      }
      for (final n in el.getAttributeNames().toDart) {
        final name = n.toDart;
        final value = el.getAttribute(name)!;
        if (value.contains(keyToken)) tokens.add((path, name, value));
      }
      var i = 0;
      for (var c = el.firstElementChild; c != null; c = c.nextElementSibling) {
        walk(c, [...path, i++]);
      }
    }

    walk(template, const []);
  }

  final Map<String, List<List<int>>> fields = {};
  final List<(List<int>, String, String)> tokens = [];

  /// Whether a row holds bindings of other states (a text, a state, a
  /// list): a clone is wired to them.
  bool wires = false;

  /// Bound attributes: (path, attribute name, field id).
  final List<(List<int>, String, String)> attributes = [];
}

/// One list binding: its containers (the same list can be shown twice) and
/// the items they were last given.
class _Lists {
  _Lists(this.binding);

  final ListBinding<Object?> binding;
  final List<_ListState> all = [];
  List<(String, Object?)>? entries;

  /// What the rows read outside their items.
  RowReads? reads;

  /// The value of each `row.selected` field, as text (see
  /// [ListBinding.selections]).
  final Map<String, String> selected = {};
}

class _ListState {
  _ListState(
    this.container,
    web.Element? template,
    this.fieldsOf,
    this.statesOf, {
    this.wire,
    this.wired = false,
  }) : template = template == null ? null : _prototype(template),
       stateSources = template == null ? const {} : _stateSources(template) {
    plan = this.template == null ? null : _RowPlan(this.template!);
    for (
      var c = container.firstElementChild;
      c != null;
      c = c.nextElementSibling
    ) {
      final k = c.getAttribute(itemKeyAttr);
      if (k != null) {
        rows[k] = _Row(
          k,
          c,
          _fieldsIn(c),
          _statesIn(c),
          _rowAttributes?.inRow(c) ?? const [],
        );
      }
    }
    order.addAll(rows.keys);
  }

  /// The row template without its row-state `<template>`s (cloned rows
  /// don't carry them; every row patches from [stateSources]).
  static web.Element _prototype(web.Element template) {
    final clean = template.cloneNode(true) as web.Element;
    for (final t in _all(clean, 'template[$rowVariantTemplateAttr]')) {
      t.remove();
    }
    _dropRowPatches(clean);
    return clean;
  }

  /// Removes the row-state patches (`data-tp-<n>` on `data-tvf` elements)
  /// under [root]: live rows never carry them. A finite state's own
  /// patches (`data-tv`) stay.
  static void _dropRowPatches(web.Element root) {
    for (final el in [root, ..._all(root, '[$rowVariantAttr]')]) {
      if (!el.hasAttribute(rowVariantAttr)) continue;
      for (final n in el.getAttributeNames().toDart) {
        if (n.toDart.startsWith('$patchAttr-')) el.removeAttribute(n.toDart);
      }
    }
  }

  /// Row-state name → its states, in order, from the row template.
  static Map<String, List<web.Element>> _stateSources(web.Element template) {
    final sources = <String, List<web.Element>>{};
    for (final el in [template, ..._all(template, '[$rowVariantAttr]')]) {
      final name = el.getAttribute(rowVariantAttr);
      if (name == null || sources.containsKey(name)) continue;
      final list = sources[name] = [el];
      // A state that only differs in attributes and texts ships as a patch
      // of the template's element: its source is that element patched.
      for (final MapEntry(key: i, value: ops) in _patchesOf(el).entries) {
        final source = el.cloneNode(true) as web.Element;
        _dropRowPatches(source);
        _apply(source, ops);
        while (list.length <= i) {
          list.add(source);
        }
        list[i] = source;
      }
    }
    _dropRowPatches(template);
    for (final t in _all(template, 'template[$rowVariantTemplateAttr]')) {
      final name = t.getAttribute(rowVariantTemplateAttr)!;
      final i = int.parse(t.getAttribute(variantIndexAttr)!);
      final first = (t as web.HTMLTemplateElement).content.firstElementChild;
      final list = sources[name];
      if (first == null || list == null) continue;
      while (list.length <= i) {
        list.add(first);
      }
      list[i] = first;
    }
    // Sources are compared node by node with live rows, which never carry
    // the nested states' templates: without them a nested state would look
    // like another structure and its element would be replaced.
    for (final list in sources.values) {
      for (final el in list) {
        for (final t in _all(el, 'template[$rowVariantTemplateAttr]')) {
          t.remove();
        }
      }
    }
    return sources;
  }

  final web.Element container;

  /// Brought in after the first scan: dropped once it leaves the page.
  final bool wired;

  /// Binds what a cloned row holds of other states (null: the page binds no
  /// such thing, or the list is used alone).
  final void Function(web.Element row)? wire;
  final web.Element? template;
  late final _RowPlan? plan;
  final Map<String, List<web.Element>> stateSources;
  final Map<String, String> Function(
    Object? item,
    void Function(Object, StackTrace) onError,
  )
  fieldsOf;
  final Map<String, int> Function(
    Object? item,
    void Function(Object, StackTrace) onError,
  )?
  statesOf;
  final Map<String, _Row> rows = {};

  /// Keys in current DOM order.
  final List<String> order = [];

  /// The list's windowing (`Watch.list(virtual: true)`), or null.
  _Window? window;

  void update(List<(String, Object?)> entries) {
    final w = window;
    if (w != null) {
      w.set(entries);
    } else {
      apply(entries);
    }
  }

  /// Reconciles the rows with [entries] (the whole list, or a window's).
  void apply(List<(String, Object?)> entries) {
    final next = [for (final (k, _) in entries) k];

    // Same keys in the same order (an update): only texts can change.
    if (next.length == order.length) {
      var same = true;
      for (var i = 0; i < next.length && same; i++) {
        same = next[i] == order[i];
      }
      if (same) {
        for (final (k, item) in entries) {
          _render(rows[k]!, item);
        }
        return;
      }
    }
    final keep = next.toSet();

    // 1. Removals first: they never shift the rows that stay.
    final old = <String>[];
    for (final k in order) {
      if (keep.contains(k)) {
        old.add(k);
      } else {
        final gone = rows.remove(k)!.element;
        if (_animatedRows) {
          _leave(container, gone);
        } else {
          gone.remove();
        }
      }
    }

    // 2. Create / update rows.
    final entered = <web.Element>[];
    for (final (k, item) in entries) {
      var row = rows[k];
      if (row == null) {
        final t = template;
        if (t == null) continue;
        row = rows[k] = _clone(t, plan!, k);
        if (_animatedRows) entered.add(row.element);
      }
      _render(row, item);
    }

    // 3. Placement.
    final anchorAtEnd = window?.bottom ?? _templateNode();
    if (old.isEmpty) {
      final fragment = web.document.createDocumentFragment();
      for (final k in next) {
        final r = rows[k];
        if (r != null) fragment.appendChild(r.element);
      }
      container.insertBefore(fragment, anchorAtEnd);
    } else {
      final oldIndex = {for (var i = 0; i < old.length; i++) old[i]: i};
      final seq = [for (final k in next) oldIndex[k] ?? -1];
      final stable = _lis(seq);
      web.Node? anchor = anchorAtEnd;
      for (var i = next.length - 1; i >= 0; i--) {
        final r = rows[next[i]];
        if (r == null) continue;
        if (!stable.contains(i)) container.insertBefore(r.element, anchor);
        anchor = r.element;
      }
    }
    order
      ..clear()
      ..addAll(next.where(rows.containsKey));
    if (entered.isNotEmpty) _entered(entered);
  }

  /// Moves when a read outside the items changed (see [RowReads]): every
  /// row renders again though its item is the same.
  int generation = 0;

  void _render(_Row row, Object? item) {
    if (identical(row.item, item) && row.generation == generation) return;
    row.generation = generation;
    // A field or a state that throws is reported and the row keeps what it
    // had (its template text); the row is not marked rendered, so the next
    // render retries it (the lite engine's rows).
    var failed = false;
    void fail(Object e, StackTrace _) {
      failed = true;
      web.console.error('$e'.toJS);
    }

    _settle(row, item, fail);
    final texts = fieldsOf(item, fail);
    for (final f in row.fields.entries) {
      final text = texts[f.key];
      if (text == null) continue;
      for (final el in f.value) {
        _setText(el, text);
      }
    }
    if (row.attributes.isNotEmpty) _rowAttributes?.write(row.attributes, texts);
    row.item = failed ? _unset : item;
  }

  /// The value of each `row.selected` field of the list (shared with the
  /// list's binding), as text.
  Map<String, String> _selected = const {};

  // Brings the row's finite states to the ones [item] (and the selection)
  // say; true when one was replaced by another structure (the row's fields
  // write again then). With [only] just the `row.selected` ones.
  bool _settle(
    _Row row,
    Object? item,
    void Function(Object, StackTrace) fail, {
    bool only = false,
  }) {
    final states = statesOf;
    if (row.states.isEmpty || (states == null && _selected.isEmpty)) {
      return false;
    }
    var swapped = false;
    // A swap can bring nested states: they are read again after it.
    for (var again = 8; again > 0; again--) {
      var moved = false;
      final wanted = only || states == null
          ? <String, int>{}
          : states(item, fail);
      for (final e in _selected.entries) {
        wanted[e.key] = row.key == e.value ? 1 : 0;
      }
      for (final e in wanted.entries) {
        final el = row.states[e.key];
        final source = stateSources[e.key];
        if (el == null || source == null || e.value >= source.length) {
          continue;
        }
        final index = '${e.value}';
        if (el.getAttribute(rowVariantIndexAttr) == index) continue;
        final n = _patch(el, source[e.value]);
        n.setAttribute(rowVariantIndexAttr, index);
        if (identical(n, el)) continue;
        _swapped(row, el, n);
        moved = swapped = true;
        break;
      }
      if (!moved) break;
    }
    return swapped;
  }

  /// A `row.selected` field moved from [previous] to [next]: only the rows
  /// with those keys change state.
  void reselect(String previous, String next) {
    for (final k in {previous, next}) {
      final row = rows[k];
      if (row == null || identical(row.item, _unset)) continue;
      final item = row.item;
      if (_settle(
        row,
        item,
        (e, _) => web.console.error('$e'.toJS),
        only: true,
      )) {
        row.item = _unset;
        _render(row, item);
      }
    }
  }

  // A state with another structure replaced [old] by [fresh]: the row
  // points at what is in the page again (its states, fields and bound
  // attributes); the fields write after this, as the new nodes hold the
  // template's text.
  void _swapped(_Row row, web.Element old, web.Element fresh) {
    if (identical(old, row.element)) {
      row.element = fresh;
      fresh.setAttribute(itemKeyAttr, row.key);
    }
    // The key in the attributes of the state's markup, as in a clone.
    for (final e in [fresh, ..._all(fresh, '*')]) {
      for (final n in e.getAttributeNames().toDart) {
        final name = n.toDart, value = e.getAttribute(name)!;
        if (value.contains(keyToken)) {
          e.setAttribute(
            name,
            fillKey(value, row.key, id: name.startsWith('data-t')),
          );
        }
      }
    }
    row.fields = _fieldsIn(row.element);
    row.states = _statesIn(row.element);
    row.attributes = _rowAttributes?.inRow(row.element) ?? const [];
    if (plan?.wires ?? false) wire?.call(fresh);
  }

  _Row _clone(web.Element template, _RowPlan plan, String key) {
    final el = template.cloneNode(true) as web.Element;
    el.setAttribute(itemKeyAttr, key);
    for (final (path, name, value) in plan.tokens) {
      _at(
        el,
        path,
      ).setAttribute(name, fillKey(value, key, id: name.startsWith('data-t')));
    }
    _syncMixed(el);
    if (plan.wires) wire?.call(el);
    return _Row(
      key,
      el,
      {
        for (final f in plan.fields.entries)
          f.key: [for (final path in f.value) _at(el, path)],
      },
      _statesIn(el),
      [
        for (final (path, name, id) in plan.attributes)
          (_at(el, path), name, id),
      ],
    );
  }

  // The row template: the container's last child, or before what a
  // `container:` put after the rows.
  web.Node? _templateNode() => _templateOf(container);
}

Map<String, web.Element> _statesIn(web.Element row) => {
  for (final el in [row, ..._all(row, '[$rowVariantAttr]')])
    ?el.getAttribute(rowVariantAttr): el,
};

Map<String, List<web.Element>> _fieldsIn(web.Element row) {
  final fields = <String, List<web.Element>>{};
  for (final el in [row, ..._all(row, '[$fieldAttr]')]) {
    final name = el.getAttribute(fieldAttr);
    if (name != null) (fields[name] ??= []).add(el);
  }
  return fields;
}

/// Indices (into [seq]) of a longest strictly increasing subsequence of the
/// non-negative values of [seq] (negative = new row). O(n log n).
Set<int> _lis(List<int> seq) {
  final tails = <int>[];
  final prev = List<int>.filled(seq.length, -1);
  for (var i = 0; i < seq.length; i++) {
    final v = seq[i];
    if (v < 0) continue;
    var lo = 0, hi = tails.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (seq[tails[mid]] < v) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo > 0) prev[i] = tails[lo - 1];
    if (lo == tails.length) {
      tails.add(i);
    } else {
      tails[lo] = i;
    }
  }
  final out = <int>{};
  for (var i = tails.isEmpty ? -1 : tails.last; i >= 0; i = prev[i]) {
    out.add(i);
  }
  return out;
}

String? _stateText;
Map<Object?, Object?>? _stateData;

/// The server's `#thor-state` as a map (parsed by the browser's
/// `JSON.parse`), or null when there is none or it is not an object.
///
/// A broken payload (a truncated response, a proxy that rewrote the page)
/// must not kill the page: it reports one `console.error` and the states
/// start from the values in their code, like the lite runtime's `saved()`.
/// The result is kept per text, so `startThor` and `hydrate` share one
/// parse and one report.
Map<Object?, Object?>? _serverState() {
  final text = web.document.getElementById(stateScriptId)?.textContent;
  if (text == null || text.isEmpty) return null;
  if (text == _stateText) return _stateData;
  Object? data;
  try {
    data = jsonToDart(
      (globalContext['JSON']! as JSObject).callMethod<JSAny?>(
        'parse'.toJS,
        text.toJS,
      ),
    );
  } on Object catch (error) {
    web.console.error('thor: #thor-state is not valid JSON: $error'.toJS);
  }
  _stateText = text;
  return _stateData = data is Map ? data : null;
}

/// Runs [restore] (one field's value from `#thor-state`); a value that does
/// not fit the field is reported and left out, never thrown.
void _restoreOne(String id, void Function() restore) {
  try {
    restore();
  } on Object catch (error) {
    web.console.error(
      'thor: #thor-state value of $id does not fit: $error'.toJS,
    );
  }
}

/// Restores the [StateBinding]s from the server's JSON (parsed by the
/// browser's `JSON.parse`: no Dart JSON decoder in the bundle).
///
/// A value that does not fit its field (a string for an `int`: a page cached
/// from a deploy that changed the type, a hand-edited payload) is that
/// field's problem only: it reports one `console.error` and starts from the
/// value in its code, and the others are restored. It never stops the
/// hydration (the whole page would be inert), like a broken payload.
void _restoreState(List<Binding> bindings) {
  final states = bindings.whereType<StateBinding<Object?>>().toList();
  if (states.isEmpty) return;
  final data = _serverState();
  if (data == null) return;
  batch(() {
    for (final s in states) {
      if (data.containsKey(s.id)) {
        _restoreOne(s.id, () => s.restore(data[s.id]));
      }
    }
  });
}

// ValidityState flags in the order a field reports them.
const _validity = [
  'valueMissing',
  'typeMismatch',
  'badInput',
  'patternMismatch',
  'tooShort',
  'tooLong',
  'rangeUnderflow',
  'rangeOverflow',
  'stepMismatch',
];

/// Native validation with the page's own messages: the browser checks the
/// rules (required, minlength, pattern…); this only writes the message of
/// the first failing rule into the field's `aria-describedby` element,
/// toggles `aria-invalid`, and replaces the browser bubble on submit.
/// Messages appear after the user leaves a field or submits, and clear as
/// soon as the value becomes valid.
void Function() _installValidation(web.Element scope) {
  // An Expando, not a Set: a form of a part that left the page is freed.
  final touched = Expando<bool>('thor.touched');

  void check(web.HTMLInputElement input) {
    final validity = input.validity as JSObject;
    String? message;
    for (final flag in _validity) {
      if ((validity[flag] as JSBoolean?)?.toDart ?? false) {
        message =
            input.getAttribute('data-msg-${flag.toLowerCase()}') ??
            input.validationMessage;
        break;
      }
    }
    input.setAttribute('aria-invalid', '${message != null}');
    final id = input.getAttribute('aria-describedby')?.split(' ').first;
    final box = id == null ? null : web.document.getElementById(id);
    if (box == null) return;
    box.textContent = message ?? box.getAttribute(helperAttr) ?? '';
    message == null
        ? box.removeAttribute(invalidAttr)
        : box.setAttribute(invalidAttr, '');
  }

  web.HTMLInputElement? field(web.Event e) {
    final t = e.target;
    if (t == null || !t.isA<web.HTMLInputElement>()) return null;
    final input = t as web.HTMLInputElement;
    return input.hasAttribute(validateAttr) ? input : null;
  }

  final onLeave = ((web.Event e) {
    final input = field(e);
    if (input == null) return;
    touched[input] = true;
    check(input);
  }).toJS;
  final onInput = ((web.Event e) {
    final input = field(e);
    if (input != null && touched[input] != null) check(input);
  }).toJS;
  // Fired for each invalid field on submit: show our message instead of
  // the browser's bubble (the browser still focuses the first one).
  final onInvalid = ((web.Event e) {
    final input = field(e);
    if (input == null) return;
    e.preventDefault();
    touched[input] = true;
    check(input);
    if (identical(scope.querySelector('[$validateAttr]:invalid'), input)) {
      input.focus();
    }
  }).toJS;
  scope.addEventListener('focusout', onLeave);
  scope.addEventListener('input', onInput);
  scope.addEventListener('invalid', onInvalid, true.toJS);
  return () {
    scope.removeEventListener('focusout', onLeave);
    scope.removeEventListener('input', onInput);
    scope.removeEventListener('invalid', onInvalid, true.toJS);
  };
}

/// `<button commandfor="id" command="show-modal|close">` opens and closes a
/// `<dialog>` natively (Invoker Commands). Where the browser lacks it, one
/// delegated listener does the same; where it has it, the listener serves
/// what is not a button (a tappable card), pressed also with Enter / Space.
/// Returns the remover.
void Function()? _polyfillCommands(web.Element scope) {
  final supported = (web.document.createElement('button') as JSObject).has(
    'command',
  );
  bool isButton(web.Element e) => e.tagName == 'BUTTON' || e.tagName == 'INPUT';
  void run(web.Element? button) {
    if (button == null ||
        (supported && isButton(button)) ||
        button.getAttribute('aria-disabled') == 'true') {
      return;
    }
    final dialog = web.document.getElementById(
      button.getAttribute('commandfor')!,
    );
    if (dialog == null || !dialog.isA<web.HTMLDialogElement>()) return;
    final d = dialog as web.HTMLDialogElement;
    switch (button.getAttribute('command')) {
      case 'show-modal':
        if (!d.open) d.showModal();
      case 'close':
        d.close();
    }
  }

  final onClick = ((web.Event e) {
    final target = e.target;
    if (target == null || !target.isA<web.Element>()) return;
    run((target as web.Element).closest('[commandfor]'));
  }).toJS;
  final onKey = ((web.KeyboardEvent e) {
    final target = e.target;
    if ((e.key != 'Enter' && e.key != ' ') ||
        target == null ||
        !target.isA<web.Element>()) {
      return;
    }
    final el = target as web.Element;
    if (isButton(el) ||
        !el.hasAttribute('commandfor') ||
        el.getAttribute('role') != 'button') {
      return;
    }
    e.preventDefault();
    run(el);
  }).toJS;
  scope.addEventListener('click', onClick);
  scope.addEventListener('keydown', onKey);
  return () {
    scope.removeEventListener('click', onClick);
    scope.removeEventListener('keydown', onKey);
  };
}

/// A checkbox's mixed state only exists as the `indeterminate` property
/// (there is no HTML attribute, and browsers ignore `aria-checked` on a
/// native checkbox): servers mark it with `aria-checked="mixed"` and the
/// runtime turns that into the property, for assistive tech and
/// `:indeterminate`.
void _syncMixed(web.Element root) {
  final boxes = root.querySelectorAll('input[type=checkbox]');
  void sync(web.HTMLInputElement input) =>
      input.indeterminate = input.getAttribute('aria-checked') == 'mixed';
  if (root.isA<web.HTMLInputElement>()) sync(root as web.HTMLInputElement);
  for (var i = 0; i < boxes.length; i++) {
    sync(boxes.item(i)! as web.HTMLInputElement);
  }
}

/// The live values of every (path, attribute) that some patch touches: the
/// patch that restores the server's variant.
List<PatchOp> _baseOf(web.Element root, Iterable<List<PatchOp>> patches) {
  final seen = <String>{};
  return [
    for (final patch in patches)
      for (final op in patch)
        if (seen.add('${op.path.join('.')}|${op.attr}'))
          PatchOp(op.path, op.attr, _read(_at(root, op.path), op.attr)),
  ];
}

web.Element _at(web.Element root, List<int> path) {
  var el = root;
  for (final i in path) {
    el = el.children.item(i)!;
  }
  return el;
}

String? _read(web.Element el, String attr) =>
    attr == '#' ? el.textContent : el.getAttribute(attr);

void _apply(web.Element root, List<PatchOp> patch) {
  for (final op in patch) {
    final el = _at(root, op.path);
    if (op.attr == '#') {
      el.textContent = op.value ?? '';
    } else if (op.value == null) {
      el.removeAttribute(op.attr);
    } else if (el.getAttribute(op.attr) != op.value) {
      el.setAttribute(op.attr, op.value!);
    }
    if (op.attr == 'checked' || op.attr == 'selected') {
      _syncControl(el, op.attr, on: op.value != null);
    }
  }
}

/// A state's `checked` (checkbox, radio) or `selected` (option) is the
/// control's live property: once the user touched the control the
/// attribute no longer moves it, so a state change sets the property too.
void _syncControl(web.Element el, String attr, {required bool on}) {
  if (attr == 'checked' && el.isA<web.HTMLInputElement>()) {
    final input = el as web.HTMLInputElement;
    if (input.checked != on) input.checked = on;
  } else if (attr == 'selected' && el.isA<web.HTMLOptionElement>()) {
    final option = el as web.HTMLOptionElement;
    if (option.selected != on) option.selected = on;
  }
}

/// A checkbox or radio whose `checked` comes from a state (it is, or is
/// inside, a `Watch` state): after its action ran, it shows what the
/// state says, not the click (Flutter's `Checkbox(value:)` is controlled).
/// A method that ignored the change leaves the box as it was.
void _keepControlled(web.Element el) {
  if (!el.isA<web.HTMLInputElement>()) return;
  final input = el as web.HTMLInputElement;
  if (input.type != 'checkbox' && input.type != 'radio') return;
  if (!input.isConnected ||
      input.closest('[$variantAttr],[$rowVariantAttr]') == null) {
    return;
  }
  _syncControl(input, 'checked', on: input.hasAttribute('checked'));
}

/// The value of a native control, for actions bound to `input`/`change`
/// without an explicit argument: `checked` for checkboxes and switches,
/// `value` for everything else (range, select, radio, text).
/// A plain primary click on an `<a href>` that has a click handler: the
/// handler runs and the page does not navigate (the `href` is the no-JS
/// path). A modified or middle click, `target` other than `_self` and
/// `download` keep the browser's own behavior.
// web: Flutter has no links; a "load more" link is both a route and a method.
bool _isPlainLinkClick(web.Element el, web.Event e) {
  if (!el.isA<web.HTMLAnchorElement>() || !el.hasAttribute('href')) {
    return false;
  }
  if (!e.isA<web.MouseEvent>()) return false;
  final m = e as web.MouseEvent;
  final target = el.getAttribute('target');
  return m.button == 0 &&
      !m.ctrlKey &&
      !m.metaKey &&
      !m.shiftKey &&
      !m.altKey &&
      (target == null || target.isEmpty || target == '_self') &&
      !el.hasAttribute('download');
}

bool _isSubmit(web.Element el) =>
    el.isA<web.HTMLButtonElement>() &&
    (el as web.HTMLButtonElement).type == 'submit';

/// A custom event's string `detail` (a message from an embedded Flutter
/// view, `thor-flutter-message`), or null.
String? _eventDetail(web.Event e) {
  if (!e.isA<web.CustomEvent>()) return null;
  final detail = (e as web.CustomEvent).detail;
  return detail.isA<JSString>() ? (detail as JSString).toDart : null;
}

String? _controlValue(web.Element el) => switch (el) {
  _ when el.isA<web.HTMLInputElement>() => _inputValue(
    el as web.HTMLInputElement,
  ),
  _ when el.isA<web.HTMLSelectElement>() => _selectValue(
    el as web.HTMLSelectElement,
  ),
  _ when el.isA<web.HTMLTextAreaElement>() =>
    (el as web.HTMLTextAreaElement).value,
  _ => null,
};

/// A `<select multiple>` (ListBox): every chosen value, U+001F apart.
String _selectValue(web.HTMLSelectElement select) {
  if (!select.multiple) return select.value;
  final chosen = select.selectedOptions;
  return [
    for (var i = 0; i < chosen.length; i++)
      (chosen.item(i)! as web.HTMLOptionElement).value,
  ].join('\u001f');
}

String _inputValue(web.HTMLInputElement input) =>
    input.type == 'checkbox' ? '${input.checked}' : input.value;

/// The optimizer's patches on [el] (`data-tp-<index>`).
Map<int, List<PatchOp>> _patchesOf(web.Element el) => {
  for (final n in el.getAttributeNames().toDart)
    if (n.toDart.startsWith('$patchAttr-'))
      int.parse(n.toDart.substring(patchAttr.length + 1)): decodePatch(
        el.getAttribute(n.toDart)!,
      ),
};

/// Puts a copy of [source] in [live]'s place, keeping the engine's markers
/// of [live]. Returns the copy.
web.Element _replace(web.Element live, web.Element source) {
  final clone = source.cloneNode(true) as web.Element;
  for (final a in [variantAttr, onAttr, argAttr, rowVariantAttr]) {
    final v = live.getAttribute(a);
    if (v != null) clone.setAttribute(a, v);
  }
  final restore = _heldFocus(live);
  live.replaceWith(clone);
  restore?.call(clone);
  return clone;
}

/// The focused element inside [old] is destroyed by a swap: returns what puts
/// focus, text, selection and scroll back on its counterpart in the new node,
/// or null when focus is not inside [old]. The counterpart is found by id,
/// else name (the n-th of several that repeat), else by its index among the
/// same tag, but only for a field with neither and only while the count is the
/// same (an inserted field would shift it). The typed text comes back only
/// when the user typed it (differs from its default) and the new variant did
/// not change that default on purpose (a reset, a value from the server).
/// Same as `held` in lite/runtime.js.
void Function(web.Element)? _heldFocus(web.Element old) {
  final a = web.document.activeElement;
  if (a == null || !old.contains(a)) return null;
  final tag = a.tagName;
  List<web.Element> same(web.Element r) => [
    for (final e in [r, ..._all(r, tag)])
      if (e.tagName == tag) e,
  ];
  final list = same(old);
  final index = list.indexOf(a);
  final id = a.id;
  final name = a.getAttribute('name');
  int nth(String? Function(web.Element) key, String v) =>
      list.where((e) => key(e) == v).toList().indexOf(a);
  final idIndex = id.isNotEmpty ? nth((e) => e.id, id) : 0;
  final nameIndex = name != null ? nth((e) => e.getAttribute('name'), name) : 0;
  // A text control's text and selection (null selection: not a text input).
  final value = _fieldText(a);
  final defaultValue = _fieldDefault(a);
  final selection = _selectionOf(a);
  final (top, left) = (a.scrollTop, a.scrollLeft);
  return (c) {
    if (web.document.activeElement != web.document.body) return;
    final all = same(c);
    web.Element? pick(String? Function(web.Element) key, String v, int i) {
      final m = all.where((e) => key(e) == v).toList();
      return i < m.length ? m[i] : m.firstOrNull;
    }

    final b =
        (id.isNotEmpty ? pick((e) => e.id, id, idIndex) : null) ??
        (name != null
            ? pick((e) => e.getAttribute('name'), name, nameIndex)
            : null) ??
        (id.isEmpty && name == null && all.length == list.length
            ? all[index]
            : null);
    if (b == null || !b.isA<web.HTMLElement>()) return;
    (b as web.HTMLElement).focus(web.FocusOptions(preventScroll: true));
    if (value != null &&
        value != defaultValue &&
        _fieldDefault(b) == defaultValue &&
        _fieldText(b) != value) {
      _setFieldText(b, value);
    }
    if (selection != null) {
      final now = _fieldText(b) ?? '';
      _select(b, now == value ? selection : (now.length, now.length, 'none'));
    }
    b.scrollTop = top;
    b.scrollLeft = left;
  };
}

String? _fieldDefault(web.Element el) => switch (el) {
  _ when el.isA<web.HTMLInputElement>() =>
    (el as web.HTMLInputElement).defaultValue,
  _ when el.isA<web.HTMLTextAreaElement>() =>
    (el as web.HTMLTextAreaElement).defaultValue,
  _ => null,
};

String? _fieldText(web.Element el) => switch (el) {
  _ when el.isA<web.HTMLInputElement>() => (el as web.HTMLInputElement).value,
  _ when el.isA<web.HTMLTextAreaElement>() =>
    (el as web.HTMLTextAreaElement).value,
  _ => null,
};

void _setFieldText(web.Element el, String v) {
  if (el.isA<web.HTMLInputElement>()) {
    (el as web.HTMLInputElement).value = v;
  } else if (el.isA<web.HTMLTextAreaElement>()) {
    (el as web.HTMLTextAreaElement).value = v;
  }
}

/// `(start, end, direction)`, or null where there is no selection (a
/// checkbox, a button, a `div`).
(int, int, String)? _selectionOf(web.Element el) {
  int? start, end;
  String? dir;
  if (el.isA<web.HTMLInputElement>()) {
    final i = el as web.HTMLInputElement;
    // `selectionStart` throws on some types in old browsers, null in new ones.
    try {
      (start, end, dir) = (
        i.selectionStart,
        i.selectionEnd,
        i.selectionDirection,
      );
    } catch (_) {}
  } else if (el.isA<web.HTMLTextAreaElement>()) {
    final t = el as web.HTMLTextAreaElement;
    (start, end, dir) = (
      t.selectionStart,
      t.selectionEnd,
      t.selectionDirection,
    );
  }
  return start == null || end == null ? null : (start, end, dir ?? 'none');
}

void _select(web.Element el, (int, int, String) s) {
  try {
    if (el.isA<web.HTMLInputElement>()) {
      (el as web.HTMLInputElement).setSelectionRange(s.$1, s.$2, s.$3);
    } else if (el.isA<web.HTMLTextAreaElement>()) {
      (el as web.HTMLTextAreaElement).setSelectionRange(s.$1, s.$2, s.$3);
    }
  } catch (_) {}
}

/// Copies classes, state attributes and texts from [source] (a variant
/// rendered by the server) onto [live], node by node. Structure is the same
/// by construction; a mismatch falls back to replacing the subtree.
/// Returns the element that is now in the page: [live] itself, or its
/// replacement when [source] has another structure.
///
/// [look] is for a bound text (a text, a row field): it keeps its content,
/// the state only gives it its look (class and state attributes).
web.Element _patch(web.Element live, web.Element source, {bool look = false}) {
  if (live.tagName != source.tagName ||
      (!look && live.childNodes.length != source.childNodes.length)) {
    return _replace(live, source);
  }
  final cls = source.getAttribute('class');
  if (live.getAttribute('class') != cls) {
    cls == null
        ? live.removeAttribute('class')
        : live.setAttribute('class', cls);
  }
  // Attributes bound to state values keep theirs (their binding owns them).
  final bound = [
    for (final m in [rowAttributesAttr, attributesAttr])
      if (live.getAttribute(m) case final ids?) ...decodeOn(ids).keys,
  ];
  // A row's custom properties (`row.length`) live in its `style`: a state
  // does not copy the template's over them.
  if (bound.any((n) => n.startsWith('--'))) bound.add('style');
  // A state's own argument (a chip's next value, `data-tx`) changes with it.
  for (final a in const [...variantAttributes, argAttr]) {
    if (bound.contains(a)) continue;
    var v = source.getAttribute(a);
    // A row state's source is the row template: its key placeholder
    // becomes the row's key.
    if (v != null && v.contains(keyToken)) {
      final key = live.closest('[$itemKeyAttr]')?.getAttribute(itemKeyAttr);
      if (key != null) v = fillKey(v, key);
    }
    if (live.getAttribute(a) != v) {
      v == null ? live.removeAttribute(a) : live.setAttribute(a, v);
    }
  }
  for (final a in const ['checked', 'selected']) {
    final on = source.hasAttribute(a);
    if (live.hasAttribute(a) != on) {
      on ? live.setAttribute(a, '') : live.removeAttribute(a);
    }
    _syncControl(live, a, on: on);
  }
  if (look) return live;
  final a = live.childNodes, b = source.childNodes;
  for (var i = 0; i < a.length; i++) {
    final x = a.item(i)!, y = b.item(i)!;
    if (x.nodeType == web.Node.ELEMENT_NODE &&
        y.nodeType == web.Node.ELEMENT_NODE) {
      // Another state keeps its own: its state is its own, not the source's.
      if ((x as web.Element).hasAttribute(variantAttr) ||
          x.hasAttribute(rowVariantAttr)) {
        continue;
      }
      // A nested binding (a text, a row field) keeps its own content, and
      // takes the look of this state.
      _patch(
        x,
        y as web.Element,
        look: x.hasAttribute(textAttr) || x.hasAttribute(fieldAttr),
      );
    } else if (x.nodeType == web.Node.TEXT_NODE &&
        x.textContent != y.textContent) {
      x.textContent = y.textContent;
    }
  }
  return live;
}

/// Sets [el]'s text. When it holds a single text node, only that node's data
/// changes: assigning `textContent` would replace the node,
/// which costs a node allocation and a larger paint invalidation.
void _setText(web.Node el, String text) {
  // A form field in a row (a hidden input per item): its value.
  if (el.isA<web.HTMLInputElement>()) {
    final input = el as web.HTMLInputElement;
    if (input.value != text) input.value = text;
    return;
  }
  final first = el.firstChild;
  if (first != null && first.nextSibling == null && first.nodeType == 3) {
    final node = first as web.Text;
    if (node.data != text) node.data = text;
  } else if (el.textContent != text) {
    el.textContent = text;
  }
}

/// Hydrates a page built with `ThorState`s (thor_ui's `Watch` and widget
/// callbacks): finds every marker in the page, resolves its id against the
/// members of [states] and attaches the matching binding. Reactive fields
/// start from the values the server wrote into the page.
///
/// The build generates the page's call (`web/engine.dart`); apps don't
/// write it. In `thor dev` (an engine compiled with `-Dthor.dev=true`) the
/// fields also keep their values across the dev server's reloads.
void Function() startThor(
  List<ThorState> states, {
  web.Element? root,
  List<EngineFeature> features = const [],
}) {
  final scope = root ?? web.document.documentElement!;
  // Debug builds only (asserts are gone in release): the generated entry
  // picks features from the app's source text, and widgets from another
  // package escape that scan; without its feature a list or a dialog just
  // doesn't react, so say which one is missing.
  assert(() {
    for (final message in missingFeatures(scope, features)) {
      web.console.warn(message.toJS);
    }
    return true;
  }());
  final members = <String, ThorMember>{
    for (final s in states)
      for (final m in s.members) '${s.idPrefix}.${m.name}': m,
  };
  ThorMember member(String id) =>
      members[id] ??
      (throw StateError('No ThorState member "$id" on this page (THOR-S005).'));

  // Reactive fields from the server's JSON.
  final restored = <String>{};
  void restoreFresh() {
    final json = _serverState();
    if (json == null) return;
    batch(() {
      for (final e in json.entries) {
        // A part that arrived later brings the values of the states it
        // uses: the ones already running keep what they have.
        if (!restored.add('${e.key}')) continue;
        final signal = members['${e.key}']?.signal;
        if (signal != null) {
          _restoreOne('${e.key}', () => signal.restoreJson(e.value));
        }
      }
    });
  }

  restoreFresh();

  // The bindings of [at]: the page, or a part of it that arrived later.
  List<Binding> bindingsOf(web.Element at, {bool late = false}) {
    final bindings = <Binding>[];
    final seen = <String>{};
    for (final el in _deep(at, '[$textAttr]')) {
      final id = el.getAttribute(textAttr)!;
      if (!seen.add('t$id')) continue;
      final (name, arg) = parseBindingId(id);
      final m = member(name);
      // Null is no text, as on the server.
      bindings.add(TextBinding(id, () => '${m.call!(arg) ?? ''}'));
    }
    for (final f in features) {
      f.collect(at, member, bindings, seen, late: late);
    }
    // Every callable member is an action: some only appear in a variant's
    // patch or a row template, not in the page's first markup.
    for (final e in members.entries) {
      final call = e.value.call;
      if (call != null) bindings.add(Action(e.key, call));
    }
    return bindings;
  }

  final bindings = bindingsOf(scope);
  final listening = <String>{};
  final detach = hydrate(
    bindings,
    root: root,
    features: features,
    listening: listening,
  );
  // After hydration (like `thor dev`'s values below): the bindings took the
  // server's markup as it is and move from it in this same task, before
  // the page paints.
  final after = [for (final f in features) ?f.afterHydration(members.values)];
  // `thor dev` only (a compile-time constant: release builds drop it). The
  // values from before the reload win over the server's, once; applied
  // after hydration, so every binding moves from the server's markup to
  // them in this same task, before the page paints.
  if (devReload) installDevState(states);
  // The states' life (`onHydrated`, `dispose`). `// web:` with dart2js every
  // state wakes here, at the start, and ends when the page is unloaded (a
  // page kept for the back button is not); the lite engine wakes a state at
  // idle and also ends it when its elements leave the page.
  var live = true;
  // The states that ended before the page did (a feature that follows what
  // the page names: `LifecycleFeature`).
  final ended = <ThorState>{};
  // The effects each state's `onHydrated` made, to stop with it (the lite
  // engine's `fx`).
  final owned = <ThorState, List<void Function()>>{};
  void wakeUp(ThorState s) {
    final mine = collectEffects(() => _reported(s.onHydrated));
    if (mine.isNotEmpty) (owned[s] ??= []).addAll(mine);
  }

  void stopOwned(ThorState s) {
    for (final stop in owned.remove(s) ?? const <void Function()>[]) {
      stop();
    }
  }

  void end() {
    if (!live) return;
    live = false;
    for (final s in states) {
      if (ended.contains(s)) continue;
      _reported(s.dispose);
      stopOwned(s);
    }
  }

  final onHide = ((web.Event e) {
    if (!(e as web.PageTransitionEvent).persisted) end();
  }).toJS;
  web.window.addEventListener('pagehide', onHide);
  // A part of the page that arrives after hydration (a `FutureBuilder`'s
  // result, a `LazyPiece`): the loader fires `thor:stream` on <html> with the
  // nodes it put in place, and they are bound like the page was: the states
  // (`Watch`, callbacks, lists, variants) and what the features install
  // page-wide (`installLate`: a date picker's controls, a controller's
  // animations; the delegated listeners of the others already reach it).
  // The bound parts, by their top node: one that arrives again (the same
  // nodes) is bound once, and the ones that left the page let go of what
  // they bound (the lite engine keeps one effect per text id and drops the
  // nodes that are gone).
  final lateParts = <web.Element, void Function()>{};
  final onStream = ((web.Event e) {
    final nodes = (e as web.CustomEvent).detail;
    if (!nodes.isA<JSObject>()) return;
    final list = (nodes as JSObject).getProperty<JSAny?>('nodes'.toJS);
    if (list == null || !list.isA<JSArray>()) return;
    restoreFresh();
    for (final gone in [
      for (final part in lateParts.keys)
        if (!part.isConnected) part,
    ]) {
      lateParts.remove(gone)!();
    }
    for (final n in (list as JSArray<JSAny?>).toDart) {
      if (n == null || !n.isA<web.Element>()) continue;
      final at = n as web.Element;
      if (!at.isConnected || lateParts.containsKey(at)) continue;
      _reported(() {
        lateParts[at] = hydrate(
          bindingsOf(at, late: true),
          root: at,
          features: features,
          late: true,
          listening: listening,
        );
        // Controllers' views and fields in it take what their controllers
        // hold now (the same event a replaced subtree fires).
        at.dispatchEvent(web.CustomEvent(adoptedEvent));
      });
    }
  }).toJS;
  final streamHost = web.document.documentElement;
  streamHost?.addEventListener('thor:stream', onStream);
  batch(() {
    for (final s in states) {
      wakeUp(s);
    }
  });
  // A state that comes back to the page starts where a new one does: the
  // fields from the server's values (the lite engine makes a new instance;
  // dart2js keeps the object, so its plain fields stay).
  void startOver(ThorState s) {
    final json = _serverState();
    for (final m in s.members) {
      final signal = m.signal;
      if (signal == null) continue;
      final id = '${s.idPrefix}.${m.name}';
      _reported(
        () => signal.startOver(
          fromServer: json?.containsKey(id) ?? false,
          json: json?[id],
        ),
      );
    }
  }

  final life = _Life(ended, wakeUp, stopOwned, startOver);
  final following = [
    for (final f in features) ?f.followStates(scope, states, life),
  ];
  return () {
    for (final undo in following) {
      undo();
    }
    web.window.removeEventListener('pagehide', onHide);
    streamHost?.removeEventListener('thor:stream', onStream);
    for (final d in lateParts.values) {
      d();
    }
    end();
    for (final undo in after) {
      undo();
    }
    detach();
  };
}

/// Runs [f]; a throw is reported to the console (like the lite engine), not
/// thrown: one state's failure must not stop the others.
void _reported(void Function() f) {
  try {
    f();
    // ignore: avoid_catches_without_on_clauses
  } catch (e) {
    web.console.error('$e'.toJS);
  }
}

class _Life implements StateLife {
  _Life(this.ended, this.hydrate, this.stopOwned, this.startOver);

  final Set<ThorState> ended;
  final void Function(ThorState) hydrate;
  final void Function(ThorState) stopOwned;
  final void Function(ThorState) startOver;

  @override
  bool isLive(ThorState state) => !ended.contains(state);

  @override
  void end(ThorState state) {
    if (!ended.add(state)) return;
    _reported(state.dispose);
    stopOwned(state);
  }

  @override
  void wake(ThorState state) {
    if (!ended.remove(state)) return;
    batch(() {
      startOver(state);
      hydrate(state);
    });
  }
}

/// Whether the page has lists that animate their rows' exit
/// (`ListsFeature(animatedRows: true)`).
bool _animatedRows = false;

/// An `AnimatedList` row that left its list: it stays, marked and inert, so
/// its transitions run to their start, and goes after the container's
/// `data-tlx` milliseconds (at once with reduced motion or without the mark).
void _leave(web.Element container, web.Element row) {
  final ms = int.tryParse(container.getAttribute(listExitAttr) ?? '');
  if (ms == null ||
      ms <= 0 ||
      web.window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    row.remove();
    return;
  }
  row
    ..setAttribute(listLeavingAttr, '')
    ..setAttribute('inert', '');
  // ignore: unnecessary_lambdas
  Timer(Duration(milliseconds: ms), () => row.remove());
}

/// Rows the browser added to a list: their `data-tli` (the `@starting-style`
/// of their transitions) is not needed once they have appeared, and would
/// replay if the row were moved by a remove and insert.
void _entered(List<web.Element> rows) {
  void drop(num _) {
    for (final r in rows) {
      r.removeAttribute(listEnterAttr);
    }
  }

  web.window.requestAnimationFrame(
    ((num _) => web.window.requestAnimationFrame(drop.toJS)).toJS,
  );
}

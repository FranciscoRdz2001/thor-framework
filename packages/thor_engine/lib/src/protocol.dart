/// The markup contract between a server (any: thor_ui, a template
/// engine, static HTML) and the client runtime (the lite engine's
/// `lib/lite/` reads the same attributes).
library;

/// `<span data-tt="cart-label">View cart · 3</span>`: the element's text
/// is `TextBinding` `cart-label`.
const textAttr = 'data-tt';

/// `<button data-tv="chip-2">…</button>` followed by one
/// `<template data-tvt="chip-2" data-i="0|1…">` per variant: the element is
/// the live instance of `VariantBinding` `chip-2`; the templates hold every
/// variant, rendered by the server in the same place (same classes).
const variantAttr = 'data-tv';

/// Marks a variant's `<template>`, paired with `[variantIndexAttr]`.
const variantTemplateAttr = 'data-tvt';

/// Index of the variant a `<template>` holds.
const variantIndexAttr = 'data-i';

/// On a [variantAttr] element (thor_ui's `AnimatedSwitcher`): switching
/// its state runs in a view transition (where the browser has them and
/// motion is not reduced). While it runs, the engine copies the value to
/// the document element, where the page's rules for that value set the
/// timing: `<in duration>|<in easing>|<out duration>|<out easing>`.
const switcherAttr = 'data-t-vt';

/// `<ul data-tl="cart">` is the container of `ListBinding` `cart`; its rows
/// carry `data-tk="<key>"` and its last child is the row template
/// `<template data-tlt="cart">`. Inside a row, `data-tf="name"` marks the
/// element whose text is field `name`, and [keyToken] in any attribute of
/// the template is replaced by the row's key when cloning.
const listAttr = 'data-tl';

/// Marks a `ListBinding`'s row template, cloned for new rows.
const listTemplateAttr = 'data-tlt';

/// A row's stable key.
const itemKeyAttr = 'data-tk';

/// Marks the element within a row whose text is one of a `ListBinding`'s
/// named fields.
const fieldAttr = 'data-tf';

/// On an element whose action takes a fixed argument plus the control's
/// value (`setSwitch.withArg(i)` on a `Switch`): the engine passes
/// `<data-tx>~<value>`.
const argWithValueAttr = 'data-txv';

/// Inside a list row: an element with finite states computed from the
/// item (the state method's id); `data-tvi` is its current state index. In
/// the row template it carries each other state as a patch of itself
/// (`data-tp-<n>`, see `patchAttr`), or, when that state has another
/// structure, as a `<template data-tvft="…" data-i="n">` right after it.
/// Live rows carry neither.
const rowVariantAttr = 'data-tvf';

/// Current state index of a [rowVariantAttr] element.
const rowVariantIndexAttr = 'data-tvi';

/// A row-state template (see [rowVariantAttr]).
const rowVariantTemplateAttr = 'data-tvft';

/// On a list container: id of the state method that gives each item's key.
const listKeyAttr = 'data-tlk';

/// On a list container that windows its rows (`Watch.list(virtual: true)`):
/// every row's extent in px. The server draws all the rows; once the list
/// runs, the engine keeps the ones near the viewport and sizes two spacers
/// for the rest (see `VirtualLists`).
const listVirtualAttr = 'data-tlv';

/// Inside a row of a tree (`Watch.tree`): the element that holds the row's
/// child rows, drawn with the same row template; its value is the id of
/// the state method that gives an item's children. In the template it is
/// empty: the engine clones the list's one template into it for each child,
/// so the template never contains itself.
const treeChildrenAttr = 'data-tlc';

/// Inside a list row: HTML attributes of the element whose values are row
/// fields, `href:<field id>;aria-label:<field id>` (same format as
/// [onAttr]). The server writes the first values; the engine rewrites
/// them when the row's item changes, through [safeAttributeValue]. A name
/// that is a custom property (`--x:<field id>`, `row.length`) is a
/// number of pixels, written into the element's `style` like
/// [variablesAttr] does outside a list.
const rowAttributesAttr = 'data-tfa';

/// On the first state of a [rowVariantAttr] element whose state is whether the
/// row's key is the value of a field of a state (`row.selected`): the
/// [rowVariantAttr] value is that field's id, not a method of the item, and
/// the engine only touches the rows that were and are now selected when the
/// field changes, instead of asking every row.
const rowSelectAttr = 'data-tvs';

/// HTML attributes of an element bound to state values outside a list
/// (thor_ui's `WatchAttributes`): `aria-rowcount:<binding id>;…` (same
/// format as [onAttr]), written through [safeAttributeValue].
const attributesAttr = 'data-tca';

/// An element with [attributesAttr] whose first values the server left out
/// (`WatchAttributes(clientOnly:)`): the engine starts the states it names
/// when the page loads, without waiting for an event, so those attributes
/// are written before the user can act.
const attributesAtStartAttr = 'data-tcs';

/// Attributes whose value is a URL: a bound value must pass [isSafeUrl].
const urlAttributes = {'href', 'src', 'action', 'formaction', 'poster', 'cite'};

/// Attributes that are on or off: a binding gives a `bool` (its text,
/// `true`, turns the attribute on, written empty; any other value takes it
/// off), and in the browser the element's property follows (`disabled`,
/// `readOnly`, `hidden`, `checked`; a `<details>` follows its `open` attribute
/// by itself).
const booleanAttributes = {
  'disabled',
  'readonly',
  'hidden',
  'checked',
  'open',
  'autofocus',
};

/// Whether [name] is one of the [booleanAttributes].
bool isBooleanAttribute(String name) => booleanAttributes.contains(name);

/// Other attributes a binding may write (besides `aria-*` and `data-*`).
/// Left out on purpose: event handlers (`on*`), `style` and `class` (the
/// client never generates styles), `srcdoc`/`srcset` (markup or URL lists)
/// and anything that changes what an element is (`type`, `is`).
const _bindableAttributes = {
  ...urlAttributes,
  ...booleanAttributes,
  'alt',
  'title',
  'value',
  'placeholder',
  'list',
  'label',
  'lang',
  'dir',
  'id',
  'name',
  'role',
  'target',
  'rel',
  'download',
  'hreflang',
  'datetime',
  'min',
  'max',
  'step',
  'width',
  'height',
  'tabindex',
};

/// Whether a binding may write attribute [name]: `aria-*`, `data-*` (not
/// the engine's own `data-t*` markers) and a fixed set of plain
/// attributes (`href`, `src`, `alt`, `title`, `value`…). Never an event
/// handler (`on*`), `style` or `class`.
bool isBindableAttribute(String name) {
  // `[a-z][a-z0-9-]*`, by hand: a RegExp would bring dart2js' regex
  // support into every engine with a list.
  if (name.isEmpty || !_isLower(name.codeUnitAt(0))) return false;
  for (final c in name.codeUnits) {
    if (!_isLower(c) && !_isDigit(c) && c != 0x2D) return false;
  }
  if (name.startsWith('aria-')) return name.length > 5;
  if (name.startsWith('data-')) {
    return name.length > 5 && !name.startsWith('data-t');
  }
  return _bindableAttributes.contains(name);
}

/// Whether [url] is safe in a URL attribute: relative, or with the
/// `http`, `https`, `mailto` or `tel` scheme. `javascript:`, `data:`,
/// `vbscript:` and any other scheme are rejected, also when disguised with
/// case, spaces or control characters (the browser strips them before
/// reading the scheme).
bool isSafeUrl(String url) {
  // Without controls, spaces and DEL, as the browser reads it (by hand, no
  // RegExp: see [isBindableAttribute]).
  final clean = String.fromCharCodes([
    for (final c in url.codeUnits)
      if (c > 0x20 && c != 0x7F) c,
  ]);
  // A scheme is `[a-zA-Z][a-zA-Z0-9+.-]*` before the first `:`.
  final colon = clean.indexOf(':');
  if (colon < 1) return true; // relative: a path, `?q`, `#id`, `//host`
  final scheme = clean.substring(0, colon).toLowerCase();
  if (!_isLower(scheme.codeUnitAt(0))) return true;
  for (final c in scheme.codeUnits) {
    // `/`, `?` or `#` before the colon: a relative URL (`a/b:c`).
    if (!_isLower(c) && !_isDigit(c) && c != 0x2B && c != 0x2E && c != 0x2D) {
      return true;
    }
  }
  return const {'http', 'https', 'mailto', 'tel'}.contains(scheme);
}

bool _isLower(int c) => c >= 0x61 && c <= 0x7A;

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

/// The value a binding writes into attribute [name], or null to remove
/// the attribute: a URL attribute ([urlAttributes]) with an empty or
/// unsafe value ([isSafeUrl]) is removed, and so is any attribute a
/// binding may not write ([isBindableAttribute]). A boolean attribute
/// ([booleanAttributes]) is `''` (present) for `true` and removed otherwise.
/// `aria-invalid` is on for any text but `false` or none (a field's error
/// message is its source: `InputDecoration(errorTextWatch:)`), written
/// `true` (`grammar` and `spelling` stay).
String? safeAttributeValue(String name, String value) {
  if (!isBindableAttribute(name)) return null;
  if (name == 'aria-invalid') {
    if (value.isEmpty || value == 'false') return null;
    return value == 'grammar' || value == 'spelling' ? value : 'true';
  }
  if (isBooleanAttribute(name)) return value == 'true' ? '' : null;
  if (urlAttributes.contains(name)) {
    return value.trim().isEmpty || !isSafeUrl(value) ? null : value;
  }
  return value;
}

/// Separates a member id from its argument in a binding id
/// (`CartState.isSelected~3`).
const idArgSeparator = '~';

/// The binding id of member [memberId] called with [arg] (none: just the
/// id). Member ids never contain the separator: the key of a keyed state
/// goes escaped in its id (`ThorState.idPrefix`), so the argument needs no
/// escaping.
String bindingId(String memberId, [String? arg]) =>
    arg == null ? memberId : '$memberId$idArgSeparator$arg';

/// `(memberId, arg)` of a binding id made by [bindingId].
(String, String?) parseBindingId(String id) {
  final i = id.indexOf(idArgSeparator);
  return i < 0 ? (id, null) : (id.substring(0, i), id.substring(i + 1));
}

/// The name of the state the properties a row lambda reads live in
/// (`row.text((o) => o.customer)` binds `$Rows.customer`): the lite bundle
/// defines it, with one reader per property the app's lambdas use.
const rowFieldsState = r'$Rows';

/// Placeholder replaced by the row's key when cloning the row template.
const keyToken = '{{key}}';

/// The `int` a list row's template stands in for the key with (`row.key` of
/// an `int` key is this in the template, and `encodeArg` writes it as
/// [keyToken]): JavaScript's `Number.MIN_SAFE_INTEGER`, which no real id is.
/// A row whose key is this is an error.
const templateIntKey = -9007199254740991;

/// `<script type="application/json" id="thor-state">{"id": value…}</script>`:
/// values of the `StateBinding`s, restored before hydration.
const stateScriptId = 'thor-state';

/// Dispatched (not bubbling) on a subtree the engine just put in the page
/// in place of another (a state with another structure): features that
/// keep values in the DOM, like a text controller's field, refresh it.
const adoptedEvent = 'thor:adopted';

/// What a hidden view announces when its controller takes it to its initial
/// page once it has a size: the page `onPageChanged` reports from.
const pageStartEvent = 'thor:pagestart';

/// Dispatched on `document` when `hydrate` finishes: the deferred engine
/// loader replays the interactions it queued before that.
const hydratedEvent = 'thor:hydrated';

/// Form fields: an input with `data-t-validate` gets its messages from
/// `data-msg-<validity flag, lowercase>` (e.g. `data-msg-valuemissing`); the
/// element named by its `aria-describedby` shows the message (its
/// `data-helper` text otherwise) and gets `data-invalid` while it fails.
const validateAttr = 'data-t-validate';

/// Marks the element showing the field's normal helper text.
const helperAttr = 'data-helper';

/// Set on the message element while the field fails validation.
const invalidAttr = 'data-invalid';

/// `data-t-on="click:cart-add;transitionend:bump-reset"` binds DOM events
/// to `Action`s. Events reach the closest element with a handler for their
/// type, like bubbling (a `change` inside a `<label>` row reaches the row; a
/// child that only handles `input` lets a `click` go on to its parent) — except
/// transition/animation events, which only count for the element itself
/// (a child's transition must not trigger its parent's handler).
const onAttr = 'data-t-on';

/// Pseudo-event for [onAttr]: the Enter key in a field (`keydown` with
/// `Enter`, outside an IME composition). The browser's default (submitting
/// the form) is prevented; the action gets the field's value.
const enterEvent = 'enter';

/// On a field with an [enterEvent] handler: empty it after the action (a
/// tag or chat input).
const clearAttr = 'data-t-clear';

/// Whether [type] only fires handlers on the event's own target.
bool ownEventOnly(String type) =>
    type.startsWith('transition') || type.startsWith('animation');

/// Argument passed to the action (`data-tx="3"`). Without it, an action on
/// a native control receives the control's value (`checked` for a
/// checkbox, `value` otherwise).
const argAttr = 'data-tx';

/// Formats [onAttr] for `{event: actionId}`.
String encodeOn(Map<String, String> handlers) =>
    [for (final e in handlers.entries) '${e.key}:${e.value}'].join(';');

/// Parses [onAttr] into `{event: actionId}`.
Map<String, String> decodeOn(String value) => {
  for (final part in value.split(';'))
    if (part.contains(':'))
      part.substring(0, part.indexOf(':')): part.substring(
        part.indexOf(':') + 1,
      ),
};

/// Attributes a variant switch copies besides `class` (state that styles
/// or assistive tech read). Everything else stays as rendered.
const variantAttributes = [
  'aria-label',
  'title',
  'aria-pressed',
  'aria-checked',
  'aria-selected',
  'aria-expanded',
  'aria-current',
  'disabled',
  'style',
];

/// Gestures of an element (thor_ui's `Gesture`): `tapd:id;tapu:id;dtap:id;
/// long:id;swipe:id;drag:id;scale:id` (same format as [onAttr]); `tapd` and
/// `tapu` get the position inside the element, `x~y`.
const gestureAttr = 'data-tg';

/// Element events of an element (thor_ui's `MouseRegion.onEnter/onExit`,
/// `Focus.onFocusChange`, `ExpansionTile.onExpansionChanged`,
/// `PageView.onPageChanged`):
/// `enter:id;leave:id;focus:id;toggle:id;page:id` (same format as [onAttr]).
/// Not in [onAttr] because the events do not bubble (`toggle`, `scroll`) or
/// need the related target to tell a child boundary from the edge
/// (`enter`/`leave`, `focus`); the handler gets `true`/`false` for `focus`
/// and `toggle`, the page index for `page`.
const elementEventsAttr = 'data-t-ev';

/// Options of a [elementEventsAttr] `visible:` event (thor_ui's
/// `VisibilityDetector`): `<threshold>|<margin px>|<once 0 or 1>`, the share
/// of the element that must show (0 to 1), how far outside the viewport it
/// counts as showing, and whether it reports only its first appearance.
const visibilityAttr = 'data-t-vis';

/// A click on this element asks the browser for the position (thor_ui's
/// `GeolocationRequest`): `ok:id;err:id` (same format as [onAttr]). `ok` gets
/// `latitude~longitude~accuracy` (metres) and `err` one of `denied`,
/// `unavailable`, `timeout` or `unsupported`.
const geolocationAttr = 'data-t-geo';

/// Options of a [geolocationAttr]: `highAccuracy|timeoutMs|maxAgeMs`, the
/// first 0 or 1 and 0 in the others leaving the browser's default.
const geolocationOptionsAttr = 'data-t-geo-o';

/// A click on this element shares a page, a text or a link with the device's
/// own share sheet (thor_ui's `ShareRequest`): `result:id` (same format as
/// [onAttr]); the handler gets `shared`, `cancelled`, `copied`, `link` or
/// `failed`.
const shareAttr = 'data-t-share';

/// What a [shareAttr] element shares, as JSON: `{"title":…,"text":…,"url":…}`
/// (a missing `url` is the current page).
const shareDataAttr = 'data-t-share-d';

/// An element whose height follows its content's, animated (thor_ui's
/// `AnimatedSize` and `AnimatedCrossFade`): `<ms>|<easing>|<ms shrinking>`.
/// Its only child is the measured content.
const sizeAnimationAttr = 'data-tsz';

/// The container of an `AnimatedList`'s rows: how long a row takes to leave,
/// in milliseconds. The engine keeps a removed row, marked [listLeavingAttr],
/// that long before it drops it.
const listExitAttr = 'data-tlx';

/// A row that enters (the `AnimatedList` row template carries it, so the rows
/// the browser adds do and the ones the server drew don't): the CSS
/// `@starting-style` of its transitions apply while it is there, and the
/// engine takes it off once the row has appeared.
const listEnterAttr = 'data-tli';

/// A row of an `AnimatedList` that is leaving: the engine sets it so its
/// transitions run to their start, and removes the row afterwards.
const listLeavingAttr = 'data-tlo';

/// A carousel that advances by itself (thor_ui's `CarouselView(autoPlay:)`):
/// the interval in milliseconds.
const carouselAttr = 'data-t-carousel';

/// The wrapper of a carousel's fallback controls (thor_ui's `CarouselView`):
/// its first child is the scroller. Buttons inside carry [carouselPrevAttr],
/// [carouselNextAttr] and the dots' group [carouselDotsAttr]; all `hidden`
/// until the engine finds the browser draws no `::scroll-button`.
const carouselControlsAttr = 'data-t-cv';

/// The fallback previous button.
const carouselPrevAttr = 'data-t-cv-prev';

/// The fallback next button.
const carouselNextAttr = 'data-t-cv-next';

/// The fallback dots' group: one button per item.
const carouselDotsAttr = 'data-t-cv-dots';

/// A `<template>` inside the fallback dots' group: the one dot the engine
/// clones per item, for a carousel whose items are a live list (the server
/// can't know how many there will be). Its `aria-label` is the label's
/// prefix: the item's number is appended.
const carouselDotTemplateAttr = 'data-t-cv-dot';

/// On the dot template: the word between a dot's number and the count
/// (`of`, giving "Slide 2 of 5"). The engine writes the count, which the
/// server can't know for a live list.
const carouselDotOfAttr = 'data-t-cv-of';

/// Swipe setup: `<axis h|v>|<dismiss 0|1>|<threshold 0..1>`.
const swipeAttr = 'data-tg-swipe';

/// Drag setup: `<axis h|v|f>|<snap back 0|1>|<keyboard step px>`, plus a
/// 4th field `1` when the end reports Flutter's `DragEndDetails`
/// (`vx~vy~lx~ly~gx~gy`) instead of `dx~dy`.
const dragAttr = 'data-tg-drag';

/// Pinch setup: `<min>|<max>|<snap back 0|1>|<keyboard step>`.
const scaleAttr = 'data-tg-scale';

/// While a finger or the mouse moves the element (no transition).
const gestureActiveAttr = 'data-tg-active';

/// While the element animates back or away after a gesture.
const gestureReleaseAttr = 'data-tg-release';

/// A swiped-away element, fading out.
const gestureOutAttr = 'data-tg-out';

/// The root of a thor_ui `Dismissible`: the state methods it calls,
/// `dismissed:id;confirm:id` (same format as [onAttr]; the element's
/// [argAttr] is their fixed argument). The root holds the backgrounds
/// ([dismissibleBackgroundAttr]) and the body ([dismissibleBodyAttr]).
const dismissibleAttr = 'data-t-dm';

/// A `Dismissible`'s setup: `axis|startToEnd|endToStart|up|down|movement|
/// resize` where the axis is `h` or `v`, each direction is its threshold (a
/// fraction of the size, or `-` when that direction is not allowed) and the
/// durations are milliseconds; a resize of 0 skips the collapse.
const dismissibleSetupAttr = 'data-t-dm-cfg';

/// The element of a `Dismissible` that follows the pointer (its `translate`
/// reads [dismissibleVarX] and [dismissibleVarY]).
const dismissibleBodyAttr = 'data-t-dm-body';

/// A `Dismissible` background, under the body: the space-separated
/// `DismissDirection` names (`startToEnd`, `endToStart`, `up`, `down`) it is
/// shown for.
const dismissibleBackgroundAttr = 'data-t-dm-bg';

/// On the body while the pointer moves it (no transition).
const dismissibleDragAttr = 'data-t-dm-drag';

/// On the body while it animates back or away.
const dismissibleOutAttr = 'data-t-dm-out';

/// On the root while it collapses.
const dismissibleGoneAttr = 'data-t-dm-gone';

/// On the background the body currently reveals.
const dismissibleOnAttr = 'data-t-dm-on';

/// The body's offset along each axis (written by the engine as pixels).
const dismissibleVarX = '--t-dm-x';

/// See [dismissibleVarX].
const dismissibleVarY = '--t-dm-y';

/// The element of a thor_ui `Draggable` / `LongPressDraggable` (the child's
/// own): the state methods it calls, `start:id;done:id;cancel:id;end:id`
/// (same format as [onAttr]; [argAttr] is their fixed argument). The data it
/// carries is [dragDataAttr], its Dart type [dragTypeAttr].
const dragSourceAttr = 'data-t-dg';

/// The data of a draggable, as `encodeArg` writes it (a `Map` or a `List` as
/// JSON): what the target's methods receive.
const dragDataAttr = 'data-t-dg-data';

/// The Dart type of a draggable's data (`String`, `int`…) or of what a drag
/// target takes: a target accepts a draggable of its type (`Object` and
/// `dynamic` accept all, `num` an `int` or a `double`).
const dragTypeAttr = 'data-t-dg-type';

/// A draggable's setup: `axis|delay|anchor|max|offsetX|offsetY` where the axis
/// is `h`, `v` or `f` (free), the delay is the hold in milliseconds before the
/// drag starts (0: at once), the anchor is `c` (the child's corner at the
/// pointer's distance from it) or `p` (the feedback's corner at the pointer),
/// `max` is 0 for a draggable that is turned off, and the offset is Flutter's
/// `feedbackOffset`.
const dragSetupAttr = 'data-t-dg-cfg';

/// The announcements of a draggable, when the page is not in English: the
/// labels separated by a line break (see thor_ui's `DragLabels`).
const dragLabelsAttr = 'data-t-dg-say';

/// A `<template>` (a child of the draggable's element, or right after it) with
/// the feedback widget: the engine clones it under the pointer.
const dragFeedbackAttr = 'data-t-dg-fb';

/// A `<template>` with the `childWhenDragging` widget, shown in place of the
/// draggable while it is dragged.
const dragPlaceholderAttr = 'data-t-dg-ph';

/// On the feedback clone the engine puts in the page while a drag runs (its
/// class holds `position: fixed` and reads [dragVarX] and [dragVarY]).
const dragGhostAttr = 'data-t-dg-ghost';

/// On the draggable while it is dragged.
const dragActiveAttr = 'data-t-dg-active';

/// On the draggable while its `childWhenDragging` stands in for it.
const dragGoneAttr = 'data-t-dg-gone';

/// The element of a thor_ui `DragTarget`: the state methods it calls,
/// `accept:id;drop:id;leave:id;move:id` (same format as [onAttr]).
const dragTargetAttr = 'data-t-dt';

/// On a drag target while a draggable it accepts is over it.
const dragOverAttr = 'data-t-dt-over';

/// On a drag target while a draggable it does not accept is over it.
const dragRejectAttr = 'data-t-dt-reject';

/// The feedback's position (written by the engine as pixels).
const dragVarX = '--t-dg-x';

/// See [dragVarX].
const dragVarY = '--t-dg-y';

/// The element of a thor_ui `NativeDraggable` (the browser's own drag and
/// drop, `dataTransfer`): the state methods it calls,
/// `start:id;done:id;cancel:id;end:id` (same format as [onAttr]; [argAttr] is
/// their fixed argument). Lite engine only.
const nativeDragSourceAttr = 'data-t-nd';

/// The data of a native draggable, as `encodeArg` writes it (see
/// [dragDataAttr]): what the in-page target's methods receive and what is
/// written to `dataTransfer` under the main MIME type.
const nativeDragDataAttr = 'data-t-nd-data';

/// The Dart type of a native draggable's data, or of what a native drop
/// target takes (see [dragTypeAttr]).
const nativeDragTypeAttr = 'data-t-nd-type';

/// A native draggable's setup: `mimeType|effectAllowed`.
const nativeDragSetupAttr = 'data-t-nd-cfg';

/// A JSON object of MIME type → text written to `dataTransfer` besides the
/// main data: what a page in a frame reads with `getData`.
const nativeDragTransferAttr = 'data-t-nd-xfer';

/// On the native draggable while it is dragged.
const nativeDragActiveAttr = 'data-t-nd-active';

/// The element of a thor_ui `NativeDragTarget`: the state methods it calls,
/// `accept:id;drop:id;leave:id;move:id` (same format as [onAttr]). It is
/// marked with [dragOverAttr] / [dragRejectAttr] while a drag is over it.
const nativeDropTargetAttr = 'data-t-nt';

/// The MIME types (one per line) a native drop target takes from a drag that
/// does not come from this page's native draggables (`Files`, `text/uri-list`).
const nativeDropMimeAttr = 'data-t-nt-mime';

/// A native drop target's `dropEffect` (`copy`, `move`, `link`); the first
/// one the drag allows when absent.
const nativeDropEffectAttr = 'data-t-nt-effect';

/// The container of a thor_ui `ReorderableListView`: the state methods it
/// calls, `reorder:id;start:id;end:id` (same format as [onAttr]; [argAttr] is
/// their fixed argument). Its items are the children with [reorderItemAttr].
const reorderAttr = 'data-t-ro';

/// A reorderable list's setup: `axis|touch` where the axis is `h` or `v` and
/// `touch` is 1 when a held finger anywhere on an item drags it
/// (`buildDefaultDragHandles`).
const reorderSetupAttr = 'data-t-ro-cfg';

/// An item of a reorderable list (not its header or footer, not the row
/// template's `<template>`).
const reorderItemAttr = 'data-t-ro-item';

/// What starts a reorder drag: a default handle or a
/// `ReorderableDragStartListener` (immediately), a
/// `ReorderableDelayedDragStartListener` (value `delayed`: after a hold).
const reorderHandleAttr = 'data-t-ro-h';

/// The announcements of a reorderable list, when the page is not in English:
/// the labels separated by a line break (see thor_ui's `ReorderLabels`).
const reorderLabelsAttr = 'data-t-ro-say';

/// On the item that is being dragged.
const reorderDragAttr = 'data-t-ro-drag';

/// On an item that moves out of the way (it transitions to its new place).
const reorderShiftAttr = 'data-t-ro-shift';

/// On the dragged item while it settles in its place.
const reorderSettleAttr = 'data-t-ro-settle';

/// An item's offset along each axis (written by the engine as pixels).
const reorderVarX = '--t-ro-x';

/// See [reorderVarX].
const reorderVarY = '--t-ro-y';

/// Explicit animations of an element (thor_ui's `*Transition` widgets with
/// an `AnimationController` of a `ThorState`): a JSON array of tracks,
/// `{"c": controller id, "k": keyframes, "r": reverse keyframes (a
/// `reverseCurve`), "v": the controller's value on the server, "a": the
/// name of the CSS animation that runs it until the engine takes over}`.
/// Keyframe offsets are fractions of the controller's range.
const animationAttr = 'data-ta';

/// Keyboard shortcuts of an element and its subtree (thor_ui's
/// `CallbackShortcuts`): `<spec>><binding id>;…` (see `encodeShortcuts`),
/// matched against `keydown` from the innermost element outward.
const shortcutsAttr = 'data-tks';

/// Flutter's `Shortcuts` on an element: `<spec>><intent name>;…` (see
/// `intentName`), matched against `keydown` like [shortcutsAttr]; the
/// intent's action is looked up from the focused element outward
/// ([actionsAttr]).
const intentShortcutsAttr = 'data-tsi';

/// Flutter's `Actions` on an element: `<intent name>><binding id>;…` (see
/// `encodeActions`).
const actionsAttr = 'data-tai';

/// `Focus(onKeyEvent:)`: the binding id of the method that gets each
/// `keydown` inside the element (a `KeyEvent`) and returns a
/// `KeyEventResult`.
const keyEventAttr = 'data-tke';

/// The `ScrollController` (its id) of a scrolling element.
const scrollControllerAttr = 'data-tsc';

/// On a scrolling element (a [scrollControllerAttr] one, or a `PageView`
/// that reports its page) that scrolls horizontally: its controller follows
/// `scrollLeft`, and its page is read from it.
const horizontalScrollAttr = 'data-tsc-h';

/// The `TextEditingController` (its id) of an `<input>` / `<textarea>`.
const textControllerAttr = 'data-ttc';

/// The `FocusNode` (its id) of a focusable element.
const focusNodeAttr = 'data-tfn';

/// The `DialogController` (its id) of a `<dialog>` (a `Drawer`,
/// `AlertDialog` or `ModalBottomSheet`).
const dialogControllerAttr = 'data-tdc';

/// The root of a thor_ui `DropdownMenu` (a listbox select). Its value holds
/// the menu's options: `s` when typing on the button jumps to the first
/// entry starting with the typed text (`enableSearch`); `f` / `n` when
/// opening focuses the filter field always / never (`requestFocusOnTap`;
/// neither: unless the pointer is coarse, so a phone's keyboard stays down).
const dropdownAttr = 'data-t-dd';

/// The `<div>` of a thor_ui `TabBar`: the lite engine's `tabs` part promotes
/// its radios to the WAI-ARIA tabs pattern (roles, roving tabindex, arrow
/// keys).
const tabsAttr = 'data-t-tabs';

/// The root of a thor_ui `SplitPane`: `x` when the panes sit side by side,
/// `y` when stacked. The lite engine's `split_pane` part moves its divider
/// (pointer drag and keys) by writing the fraction into `--tsp`.
const splitPaneAttr = 'data-t-split';

/// The smallest sizes of a `SplitPane`'s panes in pixels, `first,second`
/// (on the root, next to [splitPaneAttr]).
const splitPaneMinAttr = 'data-t-split-min';

/// The divider of a `SplitPane` (`role="separator"`).
const splitPaneBarAttr = 'data-t-split-bar';

/// The popover of a thor_ui `PopupMenuButton`, `MenuAnchor` or
/// `SubmenuButton`: the lite engine's `menu` part gives it the menu
/// keyboard (arrows, Home/End, type-ahead, submenus).
const menuAttr = 'data-t-menu';

/// The text of a `DropdownMenu`'s button: the picked entry's label, or the
/// hint (then with [dropdownHintAttr]) while nothing is picked.
const dropdownLabelAttr = 'data-tdl';

/// On a `DropdownMenu`'s button text while it shows the hint.
const dropdownHintAttr = 'data-hint';

/// On the `DropdownMenu` entry the keyboard or the pointer highlights.
const dropdownActiveAttr = 'data-active';

/// The root of a thor_ui `Autocomplete` / `RawAutocomplete`: a field and an
/// options panel (a manual popover) anchored to it. Its value holds `f` when
/// the browser hides the options the typed text does not match (the options
/// of `Autocomplete`'s own view); a view the app builds is already the
/// matching one. It holds `u` when the panel opens above by design (the
/// engine does not flip it), `i` when the view is in the flow (no popover:
/// see [autocompleteInlineAttr]) and `h` when the first visible option is
/// kept active.
const autocompleteAttr = 'data-t-ac';

/// On the panel of an inline autocomplete (`RawAutocomplete(inline: true)`):
/// a `listbox` in the flow that the engine hides (`hidden`) while there is
/// no option to show, instead of a popover it opens.
const autocompleteInlineAttr = 'data-t-inl';

/// The polite live region of an autocomplete (inside its root): the engine
/// writes the number of options there when it changes. Its value is the text
/// for several results, `{count}` standing for the number; [autocompleteOneAttr]
/// and [autocompleteNoneAttr] are the texts for one and for none (the page's
/// language, so a translation is three parameters of the widget).
const autocompleteStatusAttr = 'data-t-ac-status';

/// The text of [autocompleteStatusAttr] for exactly one result.
const autocompleteOneAttr = 'data-t-ac-one';

/// The text of [autocompleteStatusAttr] for no result.
const autocompleteNoneAttr = 'data-t-ac-none';

/// On an autocomplete's panel while the engine opens it above the field
/// (the on-screen keyboard or the viewport leaves no room below): the
/// precompiled variant that anchors it on the other side.
const autocompleteUpAttr = 'data-t-up';

/// The room (a length, written by the engine as a value) the panel has on
/// the side it opens to; it caps the panel's height.
const autocompleteRoomVar = '--t-ac-room';

/// CSS custom properties of an element bound to state values (thor_ui's
/// `WatchVariables`): `--name:<binding id>;…`. The method returns a
/// number of pixels; the engine writes `<n>px` into the element's
/// `style` (a value, never a declaration of its own).
const variablesAttr = 'data-tcv';

/// Parses [variablesAttr] into `(property, binding id)` pairs.
List<(String, String)> decodeVariables(String value) => [
  for (final part in value.split(';'))
    if (part.indexOf(':') case final at when at > 2)
      (part.substring(0, at), part.substring(at + 1)),
];

/// Whether [name] is a CSS custom property name thor writes
/// (`--` + letters, digits, `-`, `_`).
bool isCssVariableName(String name) => _cssVariableName.hasMatch(name);

// Made once: a list of rows asks it for every row.
final _cssVariableName = RegExp(r'^--[A-Za-z0-9_-]+$');

/// A number of pixels as thor writes it into a custom property: finite,
/// at most two decimals (`12px`, `12.5px`; `0px` for NaN/infinite).
String cssPxValue(num value) {
  if (!value.isFinite) return '0px';
  final rounded = (value * 100).roundToDouble() / 100;
  final text = rounded == rounded.truncateToDouble()
      ? '${rounded.toInt()}'
      : '$rounded';
  return '${text}px';
}

/// Prefix of the custom properties a row's `row.color(…)` writes
/// (`--tr-color-<binding>`): the engine writes a color into them
/// ([safeCssColor]), where the other `--` names of a row get pixels.
const rowColorPrefix = '--tr-color-';

/// [value] as a color a binding may write into a custom property, or null
/// (the property is left unset): `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`, a
/// plain `rgb()`/`rgba()`/`hsl()`/`hsla()`/`oklch()`/`oklab()` with numbers
/// (no nested function, `url()`, quotes or `;`), or a keyword (`red`,
/// `transparent`, `currentcolor`). Anything else is not a color a data
/// value may bring.
String? safeCssColor(String value) {
  // By hand, no RegExp: see [isBindableAttribute].
  final s = value.trim();
  if (s.isEmpty || s.length > 64) return null;
  bool all(String text, bool Function(int c) ok) => text.codeUnits.every(ok);
  bool hex(int c) =>
      _isDigit(c) || (c >= 0x61 && c <= 0x66) || (c >= 0x41 && c <= 0x46);
  bool letter(int c) => _isLower(c) || (c >= 0x41 && c <= 0x5A);
  if (s.startsWith('#')) {
    final digits = s.substring(1);
    return const {3, 4, 6, 8}.contains(digits.length) && all(digits, hex)
        ? s
        : null;
  }
  final open = s.indexOf('(');
  if (open < 0) {
    return s.length >= 3 && s.length <= 24 && all(s, letter) ? s : null;
  }
  const functions = {'rgb', 'rgba', 'hsl', 'hsla', 'oklch', 'oklab'};
  if (!functions.contains(s.substring(0, open)) || !s.endsWith(')')) {
    return null;
  }
  final body = s.substring(open + 1, s.length - 1);
  return all(
        body,
        (c) =>
            letter(c) ||
            _isDigit(c) ||
            c == 0x2E || // .
            c == 0x2C || // ,
            c == 0x25 || // %
            c == 0x2F || // /
            c == 0x20 || // space
            c == 0x2B || // +
            c == 0x2D, // -
      )
      ? s
      : null;
}

/// Prefix of the cookie a persisted page state lives in
/// (`state(…, cookie: 'sidebar')` → `thor-s.sidebar`): the engine writes
/// it when the value changes, the server reads it before drawing the page.
const persistedStateCookiePrefix = 'thor-s.';

/// Prefix of the `localStorage` key a page state persisted with
/// `state(…, local: 'draft')` lives in (`thor-s.draft`): the engine writes
/// it when the value changes and reads it when the state starts; the server
/// never sees it.
const persistedStateLocalPrefix = 'thor-s.';

/// The pieces of a page that follow its document: what a `FutureBuilder`
/// draws once its future is done, with the script that puts it in place.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import '../core/markup.dart' show stampingNonce;
import '../foundation/deferred.dart';

/// Puts the late piece `i` where its placeholder is: the nodes between the
/// comments `thor:i` and `/thor:i` go, the ones of `#thor-d<i>` (a hidden
/// `<div>`: parsed as a template would be, and visible without JavaScript
/// by the page's `<noscript>` rule) take their place, and the state values
/// the piece brought join `#thor-state`. `thor:stream` tells the engine,
/// which wires what is new. `i` may be a list
/// (`1,2`): the same result in several places (the variants of a
/// `ResponsiveLayout`), sent once; the first place takes the nodes, the
/// others a copy.
///
/// The one script of the page (a constant text: a strict CSP lists its
/// hash, docs/guia/es/sesion-y-seguridad.md) that stays watching: a piece ends with
/// `<template data-thor-end="i">`, and the observer swaps the piece when
/// that arrives. No piece carries a script of its own, so a CSP without
/// `'unsafe-inline'` runs them all with this one hash.
const deferScript =
    '(function(){function \$thor(i,q){'
    'var d=document,I=i.split(","),t=d.getElementById("thor-d"+I[0]),'
    'j=d.getElementById("thor-s"+I[0]),m=d.getElementById("thor-state"),'
    'c=[...t.childNodes],o,a=[];q=q?JSON.parse(q):[];'
    'I.forEach(function(k,x){var w=d.createTreeWalker(d,128),n,s,e,b;'
    'while(n=w.nextNode())'
    'if(n.data=="thor:"+k)s=n;else if(n.data=="/thor:"+k){e=n;break}'
    'if(s&&e){while((n=s.nextSibling)!=e)n.remove();'
    'b=x?c.map(function(n){return n.cloneNode(true)}):c;'
    'if(x&&q[x-1])b.filter(function(n){return n.nodeType==1})'
    '.forEach(function(n,y){var p=d.createElement("template"),f;'
    'p.innerHTML=q[x-1][y];f=p.content.firstChild;'
    '[...n.attributes].forEach(function(t){n.removeAttribute(t.name)});'
    '[...f.attributes].forEach(function(t){'
    '/^on/i.test(t.name)||n.setAttribute(t.name,t.value)})});'
    'e.before(...b);a.push(...b)}});'
    't.remove();'
    'if(j){o=JSON.parse(j.textContent);'
    'if(m){m.textContent=JSON.stringify({...JSON.parse(m.textContent),...o});j.remove()}'
    'else j.id="thor-state"}'
    'd.documentElement.dispatchEvent(new CustomEvent("thor:stream",{detail:{nodes:a}}))}'
    'new MutationObserver(function(r){r.forEach(function(m){'
    'm.addedNodes.forEach(function(n){'
    'if(n.nodeName=="TEMPLATE"&&n.hasAttribute("data-thor-end")){'
    'var i=n.getAttribute("data-thor-end"),q=n.getAttribute("data-thor-cls");'
    'n.remove();\$thor(i,q)}})})})'
    '.observe(document.documentElement,{childList:true,subtree:true})})()';

/// What the document ends with when it has late pieces, before they come:
/// the script and the rule that shows them without JavaScript (after the
/// page, in the order they came).
List<int> _head(String? token) {
  final nonce = token == null ? '' : ' nonce="$token"';
  return utf8.encode(
    '<noscript><style$nonce>[data-thor-late]{display:block}'
    '[data-thor-skeleton]{display:none}</style></noscript>'
    '<script$nonce>$deferScript</script>',
  );
}

const _attribute = HtmlEscape(HtmlEscapeMode.attribute);
final _closing = utf8.encode('</body></html>\n');
final _closingTag = utf8.encode('</body></html>');

/// [shell] (a whole document) cut before its closing tags, and the script
/// that puts the late pieces in place added: what the page goes out as.
///
/// [nonce] is the placeholder a Content-Security-Policy middleware turns into
/// the request's nonce (null: no policy): the script and style written here,
/// and the ones of every piece, carry it.
List<int> openShell(List<int> shell, {String? nonce}) {
  var end = shell.length;
  // `</body></html>` and a line break at most: from the end.
  final from = shell.length - _closingTag.length - 2;
  for (var i = shell.length - _closingTag.length; i >= 0 && i >= from; i--) {
    var same = true;
    for (var k = 0; k < _closingTag.length && same; k++) {
      same = shell[i + k] == _closingTag[k];
    }
    if (same) {
      end = i;
      break;
    }
  }
  final head = _head(nonce);
  return Uint8List(end + head.length)
    ..setRange(0, end, shell)
    ..setRange(end, end + head.length, head);
}

/// The pieces of [run] as their futures complete, then the end of the
/// document. A builder that throws is reported, and draws its error state.
///
/// Cancelling it (the client left) takes effect at once, even while every
/// future is still on its way: the clocks stop ([DeferRun.dispose]).
Stream<List<int>> latePieces(DeferRun run, {String? nonce}) {
  StreamSubscription<List<int>>? sub;
  late final StreamController<List<int>> out;
  out = StreamController<List<int>>(
    onListen: () {
      sub = _pieces(
        run,
        nonce,
      ).listen(out.add, onError: out.addError, onDone: out.close);
    },
    onPause: () => sub?.pause(),
    onResume: () => sub?.resume(),
    onCancel: () {
      run.dispose();
      // Not awaited: the generator is parked on a future that may never end.
      sub?.cancel().ignore();
    },
  );
  return out.stream;
}

Stream<List<int>> _pieces(DeferRun run, String? nonce) async* {
  final waiting = <DeferSlot>[...run.takeNew()];
  while (waiting.isNotEmpty) {
    // One clock per future: the places that wait for the same one end
    // together.
    final leaders = <DeferSlot>[];
    final seen = HashSet<Future<Object?>>.identity();
    for (final s in waiting) {
      if (seen.add(s.source)) leaders.add(s);
    }
    final next = await Future.any<(DeferSlot, DeferOutcome)?>([
      run.gone.then((_) => null),
      for (final s in leaders) s.outcome.then((o) => (s, o)),
    ]);
    if (next == null) return;
    final (leader, outcome) = next;
    final group = [
      for (final s in waiting)
        if (identical(s.source, leader.source)) s,
    ];
    waiting.removeWhere(group.contains);
    // The same result in two places (the variants of a `ResponsiveLayout`)
    // goes once, for both.
    final out = <_Shared>[];
    for (final slot in group) {
      final piece = _draw(run, slot, outcome, nonce, shape: group.length > 1);
      final same = out.indexWhere((o) => o.accepts(piece));
      if (same < 0) {
        out.add(_Shared(slot.id, piece));
      } else {
        out[same].add(slot.id, piece);
      }
    }
    // In thor dev, a place whose future ended in null and still shows its
    // waiting branch is reported (THOR-R033).
    for (final slot in group) {
      slot.check(outcome);
    }
    for (final o in out) {
      yield _chunk(o.ids, o.piece, o.classes, nonce);
    }
    waiting.addAll(run.takeNew());
  }
  yield _closing;
}

DeferPiece _draw(
  DeferRun run,
  DeferSlot slot,
  DeferOutcome outcome,
  String? nonce, {
  required bool shape,
}) {
  try {
    // The elements of the piece (its engine script among them) carry the
    // nonce placeholder, as the ones of the shell do.
    return stampingNonce(nonce, () => slot.render(outcome, shape: shape));
  } on Object catch (e, st) {
    // The builder threw for this outcome: the visitor gets its error state.
    try {
      return stampingNonce(nonce, () => slot.render(run.failure(e, st)));
    } on Object catch (e, st) {
      run.failure(e, st);
      return const DeferPiece(html: []);
    }
  }
}

/// The places one result goes to: the piece is drawn for the first, the
/// others (the same result under another parent, so other attributes on its top
/// elements) get a copy with their start tags.
final class _Shared {
  _Shared(int id, this.piece) : ids = [id];

  final List<int> ids;
  DeferPiece piece;

  /// The start tags of the top elements of the places after the first
  /// (null: the same as the first's).
  final List<List<String>?> classes = [];

  bool accepts(DeferPiece other) {
    final a = piece.shape, b = other.shape;
    if (a == null || b == null || a.length != b.length) return false;
    if (piece.roots.length != other.roots.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void add(int id, DeferPiece other) {
    ids.add(id);
    var same = true;
    for (var i = 0; i < other.roots.length; i++) {
      if (other.roots[i] != piece.roots[i]) same = false;
    }
    classes.add(same ? null : other.roots);
    piece = piece.merged(other);
  }
}

List<int> _chunk(
  List<int> ids,
  DeferPiece piece,
  List<List<String>?> classes,
  String? nonce,
) {
  final id = ids.first;
  final out = BytesBuilder(copy: false);
  void text(String s) => out.add(utf8.encode(s));
  text(pieceAssets(piece, nonce));
  text('<div hidden data-thor-late id="thor-d$id">');
  out.add(piece.html);
  text('</div>');
  if (pieceStateScript(piece, 'id="thor-s$id"') case final script?) {
    text(script);
  }
  out.add(piece.engine);
  final patch = classes.any((c) => c != null)
      ? ' data-thor-cls="${_attribute.convert(jsonEncode(classes))}"'
      : '';
  text('<template data-thor-end="${ids.join(',')}"$patch></template>');
  return out.takeBytes();
}

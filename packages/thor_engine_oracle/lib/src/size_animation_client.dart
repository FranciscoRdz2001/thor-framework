/// `AnimatedSize` and `AnimatedCrossFade` (`data-tsz`): a clipping element
/// whose only child measures the content. A `ResizeObserver` on the measured
/// child animates the element's `height` with the Web Animations API from
/// the height it has to the new one (a change mid-way starts from the
/// current height); with `prefers-reduced-motion` the size follows the
/// content at once. With the `w` field it animates the width too, and a
/// `transitionend` fires on the element when an animation finishes (`onEnd`).
/// The lite engine's `parts/animated_size.js` is the same.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:thor_engine/src/protocol.dart';
import 'package:thor_engine_oracle/client.dart' show EngineFeature, EngineRun;
import 'package:web/web.dart' as web;

/// Size animations of `AnimatedSize` and `AnimatedCrossFade`.
final class SizeAnimationsFeature extends EngineFeature {
  /// The feature.
  const SizeAnimationsFeature();

  @override
  void Function()? install(web.Element scope, EngineRun run) {
    final states = Expando<_Size>('thor.size');
    late final web.ResizeObserver observer;
    void end(web.Element el) => el.dispatchEvent(
      web.Event('transitionend', web.EventInit(bubbles: true)),
    );
    void follow(web.Element inner) {
      final s = states[inner];
      if (s == null) return;
      final el = s.el;
      // Not rendered (a hidden tab, a closed details): its size is unknown,
      // not zero, so showing it later is not a growth from nothing.
      if (inner.getClientRects().length == 0) {
        s.anim?.cancel();
        s.anim = null;
        s.height = -1;
        return;
      }
      final box = inner.getBoundingClientRect();
      final h = box.height, w = box.width;
      if (s.height < 0) {
        s.height = h;
        s.width = w;
        return;
      }
      final parts = (el.getAttribute(sizeAnimationAttr) ?? '').split('|');
      final both = parts.length > 3 && parts[3] == 'w';
      if ((h - s.height).abs() < 0.5 && !(both && (w - s.width).abs() >= 0.5)) {
        return;
      }
      final now = s.anim != null ? el.getBoundingClientRect() : null;
      final from = now?.height ?? s.height;
      final fromW = now?.width ?? s.width;
      s.anim?.cancel();
      s.anim = null;
      s.height = h;
      s.width = w;
      final same =
          (from - h).abs() < 0.5 && !(both && (fromW - w).abs() >= 0.5);
      if (!el.isConnected || same) return;
      if (web.window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
        end(el);
        return;
      }
      final shrinking = h < from && !(both && w > fromW);
      final ms = double.tryParse(parts[shrinking && parts.length > 2 ? 2 : 0]);
      if (ms == null || ms <= 0) {
        end(el);
        return;
      }
      final frame = JSObject()..['height'] = '${from}px'.toJS;
      final last = JSObject()..['height'] = '${h}px'.toJS;
      if (both) {
        frame['width'] = '${fromW}px'.toJS;
        last['width'] = '${w}px'.toJS;
      }
      final options = JSObject()
        ..['duration'] = ms.toJS
        ..['easing'] =
            (parts.length > 1 && parts[1].isNotEmpty ? parts[1] : 'linear')
                .toJS;
      final a = el.animate([frame, last].toJS, options);
      s.anim = a;
      a
        ..onfinish = ((web.Event _) {
          if (s.anim == a) s.anim = null;
          end(el);
        }).toJS
        ..oncancel = ((web.Event _) {
          if (s.anim == a) s.anim = null;
        }).toJS;
    }

    observer = web.ResizeObserver(
      ((JSArray<web.ResizeObserverEntry> entries, web.ResizeObserver _) {
        for (final e in entries.toDart) {
          follow(e.target);
        }
      }).toJS,
    );
    void watch() {
      final all = scope.querySelectorAll('[$sizeAnimationAttr]');
      for (var i = 0; i < all.length; i++) {
        final el = all.item(i)! as web.Element;
        final inner = el.firstElementChild;
        if (inner == null || states[inner] != null) continue;
        // The size now, before anything changes it; unknown when not shown.
        final shown = inner.getClientRects().length > 0;
        final box = inner.getBoundingClientRect();
        states[inner] = shown
            ? _Size(el, box.height, box.width)
            : _Size(el, -1, -1);
        observer.observe(inner);
      }
    }

    watch();
    // Shells the page gains later (a `Watch` that swaps a subtree, a row):
    // the lite engine looks again whenever a state wakes.
    final added = web.MutationObserver(
      ((JSArray<web.MutationRecord> _, web.MutationObserver _) => watch()).toJS,
    )..observe(scope, web.MutationObserverInit(childList: true, subtree: true));
    return () {
      added.disconnect();
      observer.disconnect();
    };
  }
}

class _Size {
  _Size(this.el, this.height, this.width);
  final web.Element el;
  double height;
  double width;
  web.Animation? anim;
}

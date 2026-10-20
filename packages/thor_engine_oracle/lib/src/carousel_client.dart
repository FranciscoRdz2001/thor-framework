/// `CarouselView`'s fallback controls (`data-t-cv`) and `autoPlay:`.
///
/// Controls: where the browser draws no `::scroll-button` (Firefox, Safari)
/// the server's hidden buttons are shown and wired: previous/next scroll one
/// page, disabled at the ends from the scroll position, and a dot per item
/// that scrolls to it and carries aria-current while it is the first one in
/// view. A carousel whose items are a live list (the server drew only the
/// row template) has a `<template data-t-cv-dot>` in the dots' group: a dot
/// is cloned from it per item, and the controls hide while there are fewer
/// than two. Where the browser has them nothing is shown. The lite engine's
/// `parts/carousel.js` is the same.
///
/// Autoplay (`data-t-carousel="<ms>"`): the carousel
/// advances one item every `<ms>` and goes back to the first after the
/// last. Scrolling, snapping, arrows and dots are the browser's (CSS); this
/// only moves the scroller. It stops while the visitor interacts (pointer
/// over, focus inside, touch, keys) and never runs with
/// `prefers-reduced-motion`, in a hidden tab or off screen. The lite
/// engine's `parts/carousel.js` is the same.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:thor_engine/src/protocol.dart';
import 'package:thor_engine_oracle/client.dart' show EngineFeature, EngineRun;
import 'package:web/web.dart' as web;

/// Autoplay of `CarouselView(autoPlay:)`.
final class CarouselFeature extends EngineFeature {
  /// The feature.
  const CarouselFeature();

  @override
  void Function()? install(web.Element scope, EngineRun run) {
    final seen = Expando<bool>('thor.carousel');
    final timers = <Timer>[];
    void start(web.Element el) {
      final ms = int.tryParse(el.getAttribute(carouselAttr) ?? '');
      if (ms == null || ms <= 0) return;
      var busy = 0;
      var last = 0;
      var visible = true;
      // The fallback arrows and dots are siblings of the scroller: pointer
      // and focus on them count as being in the carousel.
      final w = el.closest('[$carouselControlsAttr]') ?? el;
      void touched(web.Event _) => last = DateTime.now().millisecondsSinceEpoch;
      w
        ..addEventListener(
          'pointerenter',
          ((web.PointerEvent e) {
            if (e.pointerType == 'mouse') busy++;
          }).toJS,
        )
        ..addEventListener(
          'pointerleave',
          ((web.PointerEvent e) {
            if (e.pointerType == 'mouse') busy = math.max(0, busy - 1);
            last = DateTime.now().millisecondsSinceEpoch;
          }).toJS,
        )
        ..addEventListener('focusin', ((web.Event _) => busy++).toJS)
        ..addEventListener(
          'focusout',
          ((web.Event _) {
            busy = math.max(0, busy - 1);
            last = DateTime.now().millisecondsSinceEpoch;
          }).toJS,
        );
      for (final t in ['touchstart', 'pointerdown', 'wheel', 'keydown']) {
        w.addEventListener(t, touched.toJS);
      }
      if ((web.window as JSObject).has('IntersectionObserver')) {
        web.IntersectionObserver(
          ((
                JSArray<web.IntersectionObserverEntry> es,
                web.IntersectionObserver _,
              ) {
                visible = es.toDart.last.isIntersecting;
              })
              .toJS,
        ).observe(el);
      }
      void tick(Timer timer) {
        if (!el.isConnected) return timer.cancel();
        if (busy > 0 ||
            !visible ||
            web.document.hidden ||
            web.window.matchMedia('(prefers-reduced-motion: reduce)').matches ||
            DateTime.now().millisecondsSinceEpoch - last < ms) {
          return;
        }
        final items = el.children;
        if (items.length < 2 || el.scrollWidth <= el.clientWidth + 1) return;
        final rtl = web.window.getComputedStyle(el).direction == 'rtl';
        final left = el.scrollLeft.abs();
        final end = left + el.clientWidth >= el.scrollWidth - 2;
        final step =
            items.item(1)!.getBoundingClientRect().left -
            items.item(0)!.getBoundingClientRect().left;
        final to = end ? 0.0 : left + step.abs();
        el.scrollTo(
          web.ScrollToOptions(left: rtl ? -to : to, behavior: 'smooth'),
        );
      }

      timers.add(Timer.periodic(Duration(milliseconds: ms), tick));
    }

    bool reduced() =>
        web.window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    void controls(web.Element w) {
      if (web.CSS.supports('selector(::scroll-button(*))')) return;
      final sc = w.firstElementChild;
      if (sc == null) return;
      final prev = w.querySelector('[$carouselPrevAttr]');
      final next = w.querySelector('[$carouselNextAttr]');
      final group = w.querySelector('[$carouselDotsAttr]') as web.HTMLElement?;
      // The items: the template of a live list is not one.
      List<web.Element> real() => [
        for (var i = 0; i < sc.children.length; i++)
          if (sc.children.item(i)!.localName != 'template')
            sc.children.item(i)!,
      ];
      final tpl =
          group?.querySelector('template[$carouselDotTemplateAttr]')
              as web.HTMLTemplateElement?;
      final dots = <web.Element>[
        if (group != null)
          for (var i = 0; i < group.children.length; i++)
            if (group.children.item(i)! != tpl) group.children.item(i)!,
      ];
      var items = real();
      bool rtl() => web.window.getComputedStyle(sc).direction == 'rtl';
      double page() {
        if (items.length < 2) return sc.clientWidth.toDouble();
        final pitch =
            (items[1].getBoundingClientRect().left -
                    items[0].getBoundingClientRect().left)
                .abs();
        final n = math.max(1, ((sc.clientWidth + 1) / pitch).round());
        return pitch * n;
      }

      void by(double d) => sc.scrollBy(
        web.ScrollToOptions(left: d, behavior: reduced() ? 'auto' : 'smooth'),
      );
      // aria-disabled, not disabled: a button that disables itself under the
      // visitor's focus (Next at the end) would drop it to the page.
      bool off(web.Element b) => b.getAttribute('aria-disabled') == 'true';
      double sign() => rtl() ? -1 : 1;
      prev?.addEventListener(
        'click',
        ((web.Event _) {
          if (!off(prev)) by(-sign() * page());
        }).toJS,
      );
      next?.addEventListener(
        'click',
        ((web.Event _) {
          if (!off(next)) by(sign() * page());
        }).toJS,
      );
      group?.addEventListener(
        'click',
        ((web.Event e) {
          final b = (e.target as web.Element?)?.closest('button');
          final i = b == null ? -1 : dots.indexOf(b);
          if (i >= 0 && i < items.length) {
            by(
              items[i].getBoundingClientRect().left -
                  sc.getBoundingClientRect().left,
            );
          }
        }).toJS,
      );
      var frame = 0;
      void update() {
        frame = 0;
        items = real();
        // Fewer than two items has nowhere to go: no controls (a live list
        // starts empty).
        final few = items.length < 2;
        for (final e in [prev, next, group]) {
          if (e == null) continue;
          if (few) {
            e.setAttribute('hidden', '');
          } else {
            e.removeAttribute('hidden');
          }
        }
        if (tpl != null) {
          while (dots.length > items.length) {
            dots.removeLast().remove();
          }
          while (dots.length < items.length) {
            final d =
                tpl.content.firstElementChild!.cloneNode(true) as web.Element;
            dots.add(group!.appendChild(d) as web.Element);
          }
          // "Slide 2 of 5": the template's label is the prefix, its `of`
          // word joins the count (it changes as rows come and go: all are
          // renamed).
          final prefix = tpl.content.firstElementChild!.getAttribute(
            'aria-label',
          );
          final of = tpl.getAttribute(carouselDotOfAttr) ?? '';
          for (var i = 0; i < dots.length; i++) {
            dots[i].setAttribute(
              'aria-label',
              '$prefix${i + 1}${of.isEmpty ? '' : ' $of ${items.length}'}',
            );
          }
        }
        if (few) return;
        final left = sc.scrollLeft.abs();
        final max = sc.scrollWidth - sc.clientWidth;
        final atStart = left <= 1;
        final atEnd = left >= max - 1;
        void set(web.Element? b, bool v) {
          if (b == null) return;
          if (v) {
            b.setAttribute('aria-disabled', 'true');
          } else {
            b.removeAttribute('aria-disabled');
          }
        }

        set(prev, atStart);
        set(next, atEnd);
        if (dots.isEmpty) return;
        var cur = 0;
        var best = double.infinity;
        final edge = sc.getBoundingClientRect().left;
        for (var i = 0; i < items.length; i++) {
          final d = (items[i].getBoundingClientRect().left - edge).abs();
          if (d < best) {
            best = d;
            cur = i;
          }
        }
        if (atEnd && max > 1) cur = items.length - 1;
        for (var i = 0; i < dots.length; i++) {
          if (i == cur) {
            dots[i].setAttribute('aria-current', 'true');
          } else {
            dots[i].removeAttribute('aria-current');
          }
        }
      }

      void schedule() {
        if (frame == 0) {
          frame = web.window.requestAnimationFrame(
            ((double _) => update()).toJS,
          );
        }
      }

      sc.addEventListener('scroll', ((web.Event _) => schedule()).toJS);
      web.ResizeObserver(
        ((JSArray<web.ResizeObserverEntry> _, web.ResizeObserver _) =>
                schedule())
            .toJS,
      ).observe(sc);
      // A live list's rows come and go.
      if (tpl != null) {
        web.MutationObserver(
          ((JSArray<web.MutationRecord> _, web.MutationObserver _) =>
                  schedule())
              .toJS,
        ).observe(sc, web.MutationObserverInit(childList: true));
      }
      update();
    }

    void watch([web.Element? from]) {
      final root = from ?? scope;
      final all = root.querySelectorAll('[$carouselAttr]');
      final ws = root.querySelectorAll('[$carouselControlsAttr]');
      final own = <web.Element>[
        if (from != null && from.matches('[$carouselAttr]')) from,
        for (var i = 0; i < all.length; i++) all.item(i)! as web.Element,
      ];
      for (final el in own) {
        if (seen[el] != null) continue;
        seen[el] = true;
        start(el);
      }
      final wrappers = <web.Element>[
        if (from != null && from.matches('[$carouselControlsAttr]')) from,
        for (var i = 0; i < ws.length; i++) ws.item(i)! as web.Element,
      ];
      for (final el in wrappers) {
        if (seen[el] != null) continue;
        seen[el] = true;
        controls(el);
      }
    }

    watch();
    // Carousels that arrive after the page (a list's rows, a streamed piece,
    // a dialog's content): wired where they land.
    final observer =
        web.MutationObserver(
          ((JSArray<web.MutationRecord> ms, web.MutationObserver _) {
            for (final m in ms.toDart) {
              final added = m.addedNodes;
              for (var i = 0; i < added.length; i++) {
                final n = added.item(i)!;
                if (n.nodeType == 1) watch(n as web.Element);
              }
            }
          }).toJS,
        )..observe(
          web.document.documentElement!,
          web.MutationObserverInit(childList: true, subtree: true),
        );
    return () {
      observer.disconnect();
      for (final t in timers) {
        t.cancel();
      }
    };
  }
}

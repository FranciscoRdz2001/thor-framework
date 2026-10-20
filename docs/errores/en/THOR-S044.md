# THOR-S044 · A `postMessage` origin that is not explicit

**Where:** `thor_engine` · `FrameMessages.postToParent`, `postToFrame` and `listen`.

## What happened

You asked to send to, or listen from, an origin that is not `https://host[:port]` (or `http://…`): `'*'`, `'null'`, a path (`https://a.com/x`), a wildcard, a default port (`https://a.com:443`), upper case, or an empty `origins` list.

## Why

`postMessage` with `'*'` hands the message to whatever is in the target window, and listening without checking `origin` obeys any page that can open a frame. Thor offers no such door: every origin is written in full. The browser writes an origin without its default port and in lower case, so one written another way would never match an event's origin.

## How to fix it

```dart
// WRONG: anyone can receive the message
FrameMessages.postToFrame('canvas', json, targetOrigin: '*');
```

```dart
// RIGHT: the frame's exact origin
FrameMessages.postToFrame('canvas', json,
    targetOrigin: 'https://preview.example.com');
```

More in [Interactivity](../../guia/en/interactivity.md) (windows and frames).

[All codes](README.md)

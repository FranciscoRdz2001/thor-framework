# THOR-S038 · A page with `headBudget` answered 200 and its resource didn't exist

**Where:** `thor dev` · server terminal, with the page's route.

## What happened

A `defer(f, head: true, headBudget: …)` used up its budget, the page went out with `200`, and then the future failed with `NotFound`, `HttpError` or `Redirect`. With a faster backend that same URL would have answered `404`.

```dart
product: defer(catalog.product(slug), head: true, headBudget: defaultHeadBudget),
```

## Why

The HTTP status can't be changed once the first byte has gone out. A budget trades status correctness for latency: the same URL gives `200` or `404` depending on how slow the backend is, a search engine can index the "soft 404" and a cache or a monitor see different responses.

## How to fix it

```dart
// RIGHT: without a budget, the server awaits the future and the state is real
product: defer(catalog.product(slug), head: true),

// or await the data in load
final product = await catalog.product(slug);
```

Keep `headBudget` only for cosmetic head data (a title that has a fallback), never for the data that decides the status.

[All codes](README.md)

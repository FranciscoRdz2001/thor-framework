# THOR-B030 · A row lambda the build cannot give to the browser

**Where:** `thor build`, `thor dev`, `thor test` (the generation step) · `row.text((o) => …)` (and `bindText`, `bind`, `attribute`, `field`) and `row.watch((o) => …)`.

## What happened

The build found a `row.text(lambda)` over a `Watch.list` row that is neither a `String` property as is (`(o) => o.customer`) nor an `int`, `num`, `double` or `bool` as text (`(o) => '${o.id}'`, `o.id.toString()`; in `row.watch`, a `bool` or enum property: `(o) => o.isOffer`), or whose row is a class that cannot be probed: private, with type parameters, or `final`, `sealed` or `base`.

## Why

See [THOR-S033](THOR-S033.md): the browser reads the property, it does not run the lambda. To know which one it reads, the server calls the lambda with a probe that the build writes as an `implements` of the row's class; a class that cannot be implemented from another file has no probe.

## How to fix it

A state method instead of the lambda (`row.text(orders.customerOf)`), or a public row class, without type parameters and without `final`/`sealed`/`base`.

[All codes](README.md)

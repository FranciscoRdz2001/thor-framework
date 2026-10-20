# THOR-S033 · A row lambda that does more than read a property

**Where:** `thor_ui` · `row.text(…)` (and `bind`, `attribute`, `field`, `watch`) when painting (and THOR-B030 when building).

## What happened

`row.text` received a lambda that isn't just `(o) => o.property` (for `row.watch`, a `bool` or enum property): it calls a method (`o.name.trim()`), interpolates, joins two properties, reads something that isn't a `String` (an `int`, `num`, `double` or `bool` does work as text: `'${o.id}'` or `o.id.toString()`) or returns a constant.

## Why

The lambda runs on the server to paint the row; the browser can't run it. For new rows and changes it reads each item's property itself, so it only understands "read this property and show it as is".

## How to fix it

```dart
// WRONG
row.text((o) => o.customer.toUpperCase())
row.text((o) => '${o.first} ${o.last}')
```

```dart
// RIGHT: a state method
String customerOf(Order o) => o.customer.toUpperCase();
String fullName(Person p) => '${p.first} ${p.last}';

row.text(orders.customerOf)
row.text(people.fullName)

// or just the property, as is
row.text((o) => o.customer)
row.text((o) => '${o.id}')   // an int as text
```

[All codes](README.md)

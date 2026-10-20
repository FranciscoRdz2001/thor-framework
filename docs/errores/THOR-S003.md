# THOR-S003 · `Watch` con `builder` sobre un valor que no es finito

**Dónde:** `thor_ui` · `Watch(builder:)`, `Watch.field(builder:)`, `row.watch`.

## Qué pasó

Un `Watch` con `builder` (o `row.watch`) observa un valor que no es `bool` ni `enum`, y no se pasó `count:` para un `int`; o un campo nullable (`bool?`, `Mood?`): el `null` no tiene copia que pintar.

## Por qué

Un `Watch` con `builder` se renderiza **una vez por estado posible** en el servidor y el navegador alterna entre esas versiones. Por eso necesita un conjunto finito y conocido: `bool`, un `enum`, o un `int` con `count:`.

## Cómo se arregla

```dart
// WRONG
Watch(state.selectedName, builder: (name) => Text(name)) // String: infinito
```

```dart
// RIGHT
// Texto que cambia: sin builder.
Watch(state.selectedName)

// Estructura que cambia: un bool o un enum.
bool hasSelection() => selected.value != null;
Watch(state.hasSelection, builder: (yes) => yes ? const Details() : const Empty())

// Un int acotado (un método, o el campo con Watch.field):
Watch(state.step, count: 3, builder: (i) => Steps(i))
Watch.field(state.step, count: 3, builder: (i) => Steps(i))

// Un bool? o un enum?: quita el null (state(false), o un caso `none`),
// o mira un método que lo resuelva:
bool shown() => flag.value ?? false;
```

[Todos los códigos](README.md)

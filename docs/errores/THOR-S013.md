# THOR-S013 · Un `ValueListenableBuilder` que el navegador no puede reconstruir

**Dónde:** `thor_ui` · el servidor, al pintar la página.

## Qué pasó

`ValueListenableBuilder` recibió un `StateSignal` que no es un campo de un `ThorState` de nivel superior, o cuyo valor no tiene un conjunto finito de casos (un `int`, un `String`, o un `bool?` / enum nullable: el `null` no tiene copia que pintar).

## Por qué

El servidor pinta el `builder` una vez por cada valor posible (un `bool`, cada caso de un enum) y el navegador muestra el que toca, igual que `Watch(..., builder:)`. Un `int` o un `String` tienen infinitos valores: no hay nada que pintar de antemano. El navegador encuentra el campo por su nombre, así que tiene que ser un campo de un estado de nivel superior ([THOR-S012](THOR-S012.md)).

## Cómo se arregla

```dart
// WRONG
ValueListenableBuilder<String>(
  valueListenable: profile.name,
  builder: (context, name, child) => Text('Hola, $name'),
)
```

```dart
// RIGHT: un String se muestra como texto
Watch(profile.name)

// un texto con más palabras: un método del estado que lo arma
String greeting() => 'Hola, ${name.value}';
Watch(profile.greeting)

// un int: sus valores de 0 a n - 1
Watch(rating.stars.call, count: 6, builder: (n) => Text('★' * n))

// un bool? o un enum?: quita el null (state(false), o un caso `none` en el enum)
final open = state(false);

// un bool o un enum funciona tal cual
ValueListenableBuilder<bool>(
  valueListenable: panel.open,
  builder: (context, open, child) => Text(open ? 'Abierto' : 'Cerrado'),
)
```

Un `ValueNotifier` suelto (que no es un campo `state(...)`) se pinta una vez con su valor y nunca reacciona en el navegador; como campo de un `ThorState`, `thor build` lo rechaza.

[Todos los códigos](README.md)

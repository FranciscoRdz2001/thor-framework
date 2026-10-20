# THOR-B012 · Un estado usa algo que no puede correr en el navegador

**Dónde:** `thor build` / `thor dev`, y en el editor (`dart analyze` con `thor_lints`: la regla `thor_lite_subset`, con el mismo mensaje y arreglo).

## Qué pasó

Un `ThorState` de la app, o código que usa, tiene una construcción que no se puede ejecutar en el navegador (un paquete como `intl` o `uuid`, `==` sobre records, generadores…). También las clases de datos que viajan al navegador (el tipo de un `events<T>`, un `query<T>` o un `state<T>`: su `fromJson`, su `toJson` y los métodos que el estado llama), aunque estén en otro archivo: el editor lo marca en el archivo de la clase. El mensaje lista cada una con su archivo y línea; el build se detiene sin escribir nada.

## Por qué

Los métodos de un estado corren en el navegador. Lo que no puede ejecutarse igual allí es un error, no un comportamiento distinto.

## Cómo se arregla

**1. Llévalo al servidor.** Una `query(fn)` calcula un valor y un `command(fn)` lo cambia; `fn` corre en el servidor, así que puede usar cualquier paquete:

```dart
// WRONG: intl and uuid inside the browser state
class LedgerState extends ThorState {
  final cents = state(0);
  String total() => NumberFormat.currency(locale: 'es_MX').format(cents.value / 100);
  void add(int c) { cents.value += c; lastId.value = const Uuid().v4(); }
}
```

```dart
// RIGHT: the work on the server
class LedgerState extends ThorState {
  final total = query(ledgerRepo.totalLabel);   // NumberFormat on the server
  final add = commandWith(ledgerRepo.add);      // Uuid on the server
}
```

Después de un `command`, las `query` de la página vuelven en la misma respuesta. Detalle en [Estado](../guia/es/estado.md#datos-del-servidor).

**2. Reescríbelo con lo básico de Dart** (números, texto, listas, mapas, fechas, `enum` y clases propias). También entran los campos `static const` y `static final` del estado y `FormatException.message`.

## Cada construcción y su arreglo

Lo que el build reconoce y el «fix:» que sugiere (lo que no está aquí recibe la salida general: llevarlo al servidor o reescribirlo):

| Construcción | Qué hacer |
|---|---|
| `Future.wait(cleanUp:)` | quitar `cleanUp:` y liberar lo que hizo cada futuro en un `try`/`finally` después del `await`, o llevar el trabajo a un `query()`/`command()` del servidor |
| `Timer.run` | `Timer(Duration.zero, callback)` |
| `.wait` (de un record o una lista de futuros: `(a, b).wait`) | `await Future.wait([a, b])` y leer la lista: un fallo es el primer error mismo, no un `ParallelWaitError` |
| `.timeout` | cortarlo en el servidor, o un `Timer` con el plazo |
| `Completer.sync` | `Completer()`: sus oyentes corren en una microtarea, no dentro de `complete()` |
| `Stream`, `StreamController`, `.listen`, `await for` | sin streams: `Timer.periodic`, o leer los datos con un `query()` |
| `sync*` (y `async*`: generadores) | devolver una `List` armada con un ciclo; una secuencia larga va en un `query()` |
| `mixin` (un `mixin class`, uno de un paquete, o con miembros `static`) | un `mixin` declarado en la app y sin miembros `static`; o composición: un campo de la clase auxiliar o una función de nivel superior |
| `operator +` (y todo operador propio salvo `==`: `[]`, `<`…) | escribir un método (`a.plus(b)`) |
| `compare by value` (`Set` o clave de `Map` de `DateTime`, `Duration` o `TimeOfDay`) | una clave `String` o `int` (`item.id`, `fecha.millisecondsSinceEpoch`). El `==` de dos colecciones (`List`, `Set`, `Map`) sí se traduce: es identidad, como en Dart |
| `is Map<String, dynamic>` (y `is List<T>`, `is Set<T>`, `case List<int> l`, patrones de mapa o lista con tipos sobre algo que no es estáticamente `Map`/`List`) | JS no guarda los tipos: probar `is Map` / `is List` sin argumentos y después `as List<T>` o un cast por elemento, o una factory `fromJson` |
| `.whereType` (de un tipo con argumentos: `whereType<List<int>>()`) | `l.where((x) => x is List).map((x) => x as List<int>)` |
| `lastIndexOf(RegExp)` (y un `RegExp` en `endsWith`, `trim`…) | recorrer `RegExp.allMatches` y quedarse con la última, o un patrón `String` |
| `extension type` | una clase con un campo `final`, o el tipo subyacente |
| `late` (variables locales, de nivel superior, y campos del estado o de una clase, salvo `late final x = …` con su inicializador en un estado o una clase, que sí se traduce: se calcula al leerlo la primera vez) | darle valor donde se declara (`final x = …`), o hacerla nullable y verificar con `!` |
| `super` (salvo `super.dispose()` y `super.onHydrated()`, que no hacen nada) | quitar la llamada; cancelar los `Timer` en `dispose()` |
| `ValueNotifier` (un campo del estado que es un `ValueNotifier` o `ChangeNotifier` suelto) | hacerlo un campo `state(...)`: un `StateSignal` ya es un `ValueNotifier` y sí reacciona en el navegador |
| `interpolate a Map` | imprimir las entradas con `m.entries.map(...).join(', ')` |
| `interpolate a record` | interpolar cada campo (`${r.$1}, ${r.$2}`) |
| `interpolate a List<Object>` (o `Set`/`Iterable` de `Object`/`dynamic`) | tiparla (`List<String>`) o `items.map((i) => i.name).join(', ')` |
| `interpolate a list of objects` (`List`, `Set` o `Iterable` de una clase sin `toString()`) | `join` de un campo, o un `toString()` en la clase del elemento |
| `interpolate a class` | darle un `toString()` o interpolar sus campos |
| `getRange`, `removeRange` | `sublist(a, b)`; para quitar, reconstruir la lista con `sublist` |
| `runtimeType` | probar con `is`, o un `kind` propio |
| `index on dynamic` | castear antes: `(d as Map)['k']` |
| `extends` (de una clase que no es de la app) | extender una clase de la app, o componer |
| `*.g.dart` (un error en código generado: `.g.dart`, `.freezed.dart`, `.gr.dart`) | el archivo es generado, no se edita: no dejar la salida de ese builder dentro de un `ThorState` (una clase a mano, o llevarlo a un `query()`) |
| `integer above 2^53` | mandarlo como `String`, o calcularlo en un `query()` |

## Si el error nombra `events(url, …)`

Un campo `events` se traduce con una URL, un `event:` y un `key:` literales, y la URL es una ruta de la app (`/stream`, un solo `/` al inicio: nunca otro origen). Otra cosa es este error con la razón: pasa literales, quita la opción que `events` no tiene (`retry:`…), usa `key:` solo con `List<…>` y declara el campo `final`. Detalle en [Datos en vivo](../guia/es/datos-vivos.md#eventos-del-servidor).

[Todos los códigos](README.md)

# THOR-R032 · El `optionsBuilder` de un `Autocomplete` devolvió un `Future`

**Dónde:** `thor_ui` · `Autocomplete(optionsBuilder:)` o
`RawAutocomplete(optionsBuilder:)`.

## Qué pasó

El `optionsBuilder` es `async` o devuelve un `Future`.

## Por qué

Una página se escribe una vez: el servidor llama a `optionsBuilder` al
construir, con el texto inicial del campo, y no puede esperar un futuro ni
volver a llamarlo mientras la persona escribe. El navegador solo filtra las
opciones que recibió.

## Cómo se arregla

Opciones fijas: devuélvelas en el momento.

```dart
// WRONG
Autocomplete<String>(optionsBuilder: (v) async => await api.names())
```

```dart
// RIGHT: una lista fija
Autocomplete<String>(optionsBuilder: (v) => names.where((n) => n.contains(v.text)))
```

Opciones que el servidor busca mientras escribes (un buscador): guárdalas en
una lista de un `ThorState` y muéstrala en `optionsViewBuilder` de un
`RawAutocomplete`.

```dart
RawAutocomplete<String>(
  optionsBuilder: (v) => const [],
  textEditingController: search.box,
  focusNode: search.focus,
  fieldViewBuilder: (context, controller, focus, submit) =>
      TextField(controller: controller, focusNode: focus),
  optionsViewBuilder: (context, onSelected, options) => Watch.list(
    search.names,
    itemKey: search.nameOf,
    each: (row) => Semantics(
      role: SemanticsRole.option,
      child: row.text(search.nameOf),
    ),
  ),
)
```

[Todos los códigos](README.md)

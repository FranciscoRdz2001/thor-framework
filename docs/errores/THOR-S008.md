# THOR-S008 · `PageNavigator.go` a una ubicación que no es una página

**Dónde:** `thor_ui` · `PageNavigator.go`.

## Qué pasó

Un método del estado llamó `PageNavigator.go` con una ubicación que no es relativa ni `http:`/`https:` (`javascript:`, `data:`, `vbscript:`…).

## Por qué

`go` carga la siguiente página como documento. Una ubicación con otro esquema no es una página: con un valor que viene del usuario (un parámetro, un campo) sería una puerta para ejecutar código en la página. El chequeo ignora los caracteres de control y espacios como lo hace el navegador (`java\tscript:` también se rechaza).

## Cómo se arregla

```dart
// WRONG: el destino viene del usuario sin revisar
void open() => PageNavigator.go(link.value);
```

```dart
// RIGHT: una ruta de la app (tipada) o una URL http(s)
void open(String slug) => PageNavigator.go(Routes.article(slug: slug));
```

Si el error se puede dar (un destino que viene de datos), atrápalo como `ArgumentError`.

[Todos los códigos](README.md)

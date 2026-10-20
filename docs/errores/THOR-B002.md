# THOR-B002 · Un método de `ThorState` se omite

**Dónde:** `thor build` / `thor dev` · aviso.

## Qué pasó

Un método público del estado no se puede llamar desde el navegador, así que thor lo deja fuera (aviso, no error). Las causas: más de tres parámetros, parámetros opcionales o con nombre, un parámetro que no es un valor simple en un método de varios parámetros, o un tipo de parámetro que el archivo no importa.

## Por qué

El navegador llama a los métodos con argumentos que viajan en el HTML como texto: solo valores simples (`int`, `double`, `String`, `bool`, `enum`, `DateTime`, `TimeOfDay`) o el ítem de una fila.

## Cómo se arregla

```dart
// WRONG
void addLine(String name, {int qty = 1}) { ... }       // con nombre
void move(Line line, Line target, int at, bool copy) { ... } // cuatro
```

```dart
// RIGHT
void addLine(String name) { ... }
void moveTo(int at, Line line) { ... }   // argumento fijo con withArg + ítem

// Lo que no es para el navegador: privado (_helper) o static.
```

[Todos los códigos](README.md)

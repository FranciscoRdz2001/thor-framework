# THOR-R023 · Los canales de un color del tema no se conocen en el servidor

**Dónde:** `thor_style` · `Color.value`, `alpha`, `red`, `green`, `blue`, `opacity` y `Color.alphaBlend` sobre una variable del tema, un `Color.css` o un color con `.when()` (comprueba `hasChannels` antes).

## Qué pasó

Un color que viene del tema (`ThemeColor.primary`, `Theme.of(context).colorScheme.primary`, un `ColorToken`) se lee por sus canales: `.value`, `.red`, `.opacity`… o entra en `Color.alphaBlend`.

## Por qué

Ese color es una variable CSS (`var(--t-primary)`): en claro vale una cosa y en oscuro otra, y el navegador decide cuál. El servidor pinta la página una sola vez, así que cualquier número que sacara sería el del modo equivocado, y el error no se vería hasta que alguien abra el modo oscuro. Fallar es mejor que pintar mal en silencio.

## Cómo se arregla

```dart
// WRONG
final light = Theme.of(context).colorScheme.primary.value > 0x80000000;
final soft = Color.alphaBlend(scheme.primary.withValues(alpha: .1), scheme.surface);
```

```dart
// RIGHT: una transparencia se mezcla en el navegador y sigue al tema
color: scheme.primary.withValues(alpha: 0.1)

// dos colores según el modo: .when()
color: Colors.white.when(dark: Colors.black)

// los canales de un color fijo sí se leen
const Color(0xFF6750A4).red

// el color que el servidor conoce (el claro; el oscuro con themeMode: dark),
// para una cuenta que vale en un solo modo: no sigue al tema
scheme.primary.fallback!.red
```

[Todos los códigos](README.md)

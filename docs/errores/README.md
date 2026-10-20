# Códigos de error

Los errores y avisos más comunes de Thor llevan un código estable
(`THOR-S001`) y una página aquí con la causa y cómo arreglarlo
(`/errores/THOR-S001`). Los del navegador y del inspector de desarrollo
llevan solo el código, y el overlay de `thor dev` los enlaza igual.

Un código no se reutiliza ni cambia de significado: si un error deja de
existir, su página se borra y el código queda sin uso.

Letras: **S** estado · **R** render · **L** layout (inspector) ·
**P** páginas y servidor · **B** build y generación de código.

## Estado

| Código | Qué pasa |
|---|---|
| [THOR-S001](THOR-S001.md) | Un `Watch` o un callback recibe un closure |
| [THOR-S002](THOR-S002.md) | Un método por fila no recibe el ítem |
| [THOR-S003](THOR-S003.md) | `Watch` con `builder` sobre un valor que no es finito |
| [THOR-S005](THOR-S005.md) | El navegador no encuentra un miembro de un `ThorState` |
| [THOR-S006](THOR-S006.md) | Una página usa un `ThorState` sin `ThorApp` |
| [THOR-S007](THOR-S007.md) | `Cached` contiene widgets ligados a un `ThorState` |
| [THOR-S008](THOR-S008.md) | `PageNavigator.go` a una ubicación que no es una página |
| [THOR-S009](THOR-S009.md) | Nombre inválido de un campo persistido (`cookie:` o `local:`) |
| [THOR-S010](THOR-S010.md) | Un `ThorState` sin registrar (la app corrió sin thor) |
| [THOR-S011](THOR-S011.md) | Un callback es un closure que usa un `ThorState` |
| [THOR-S012](THOR-S012.md) | Un `ThorState` creado fuera del nivel superior |
| [THOR-S013](THOR-S013.md) | Un `ValueListenableBuilder` que el navegador no puede reconstruir |
| [THOR-S014](THOR-S014.md) | `setState` en un `StatefulWidget` |
| [THOR-S015](THOR-S015.md) | Un estado leído mientras el servidor pinta (se congela en el navegador) |
| [THOR-S016](THOR-S016.md) | Un `AnimatedSwitcher` sin estados que cambiar |
| [THOR-S030](THOR-S030.md) | La clave de una fila que no es texto ni entero |
| [THOR-S031](THOR-S031.md) | Una página sin el diálogo o el aviso que un estado pide |
| [THOR-S032](THOR-S032.md) | Una fila con lambda sin la sonda de su clase |
| [THOR-S033](THOR-S033.md) | Un lambda de fila que hace más que leer una propiedad |
| [THOR-S034](THOR-S034.md) | Un método del estado llamado con `row.key` (o leyendo estado de la fila) al pintar: se evalúa una vez, con la clave de la plantilla |
| [THOR-S035](THOR-S035.md) | `row.bind` en un atributo que un binding no puede escribir |
| [THOR-S036](THOR-S036.md) | `row.bind` usado como texto o transformado |
| [THOR-S037](THOR-S037.md) | Un estado de `QueryBuilder` que lee `snapshot.data` y no se pudo dibujar sin dato |
| [THOR-S038](THOR-S038.md) | Una página con `headBudget` respondió 200 y su recurso no existía |
| [THOR-S039](THOR-S039.md) | El navegador llamó a una consulta o comando que el registro no declara |
| [THOR-S040](THOR-S040.md) | `Watch.list(virtual: true)` sin `itemExtent` |
| [THOR-S041](THOR-S041.md) | Un campo `state(...)` con una clase que no viaja como JSON |
| [THOR-S042](THOR-S042.md) | Una `row.length` leída fuera de su fila |
| [THOR-S043](THOR-S043.md) | Una key repetida en un `Watch.tree` (o un nodo que es su propio descendiente) |
| [THOR-S044](THOR-S044.md) | Un origen de `postMessage` que no es explícito (`'*'`, `'null'`, con ruta o puerto por defecto) |

## Render

| Código | Qué pasa |
|---|---|
| [THOR-R001](THOR-R001.md) | thor no sabe construir este widget |
| [THOR-R002](THOR-R002.md) | `Cached` está dentro de un wrapper |
| [THOR-R003](THOR-R003.md) | `Cached` contiene el `<head>` o el documento |
| [THOR-R004](THOR-R004.md) | `.when()` dentro de una hoja de estilos |
| [THOR-R005](THOR-R005.md) | `@keyframes` anidado |
| [THOR-R006](THOR-R006.md) | No hay `Localizations` arriba del widget |
| [THOR-R007](THOR-R007.md) | Un delegado de traducciones carga de forma asíncrona |
| [THOR-R008](THOR-R008.md) | Falta `DefaultTabController` |
| [THOR-R009](THOR-R009.md) | El largo del `DefaultTabController` no coincide |
| [THOR-R010](THOR-R010.md) | `RequestScope.of` fuera de una página |
| [THOR-R011](THOR-R011.md) | Un ancho de columna de `Table` que CSS no puede expresar |
| [THOR-R012](THOR-R012.md) | Los especímenes de la hoja compartida no se dibujan |
| [THOR-R013](THOR-R013.md) | Una utilidad o variante de `tw()` que thor no conoce |
| [THOR-R014](THOR-R014.md) | Dos utilidades de `tw()` fijan la misma propiedad |
| [THOR-R015](THOR-R015.md) | `8.px` dentro de un `const` |
| [THOR-R016](THOR-R016.md) | Un `unicodeRange` de `FontFace` que no es un rango |
| [THOR-R017](THOR-R017.md) | Un widget `const` que lee algo más que sus campos (memo en `verify`) |
| [THOR-R018](THOR-R018.md) | Un argumento de `Style` que no es CSS |
| [THOR-R019](THOR-R019.md) | Dos `Hero` con el mismo `tag` en una página |
| [THOR-R020](THOR-R020.md) | Un árbol de widgets demasiado profundo para la pila |
| [THOR-R021](THOR-R021.md) | Un color del tema declarado dos veces (`colorTokens` y `tokens`) |
| [THOR-R022](THOR-R022.md) | Un elemento con dos ids (`Semantics(identifier:)` sobre otro id) |
| [THOR-R023](THOR-R023.md) | Los canales de un color del tema no se conocen en el servidor |
| [THOR-R031](THOR-R031.md) | Un `FutureBuilder` recibió un futuro nuevo en cada pasada (créalo en `load`) |
| [THOR-R032](THOR-R032.md) | El `optionsBuilder` de un `Autocomplete` devolvió un `Future` |
| [THOR-R033](THOR-R033.md) | Un `FutureBuilder` deja el esqueleto cuando su futuro termina en `null` |
| [THOR-R034](THOR-R034.md) | Un `ResponsiveLayout` lleva lo mismo pesado (un `FutureBuilder`, un `Watch.list` o mucho HTML) en dos variantes |
| [THOR-R035](THOR-R035.md) | El `id` de un `LazyPiece` no cabe en una URL |
| [THOR-R036](THOR-R036.md) | Un widget que suma rellenos recibió uno dado como `Length` |
| [THOR-R037](THOR-R037.md) | Un valor que depende de la dirección del texto (`start`/`end`) llegó a un lugar que necesita el lado físico |
| [THOR-R038](THOR-R038.md) | Un segmento de `SegmentedButton` sin `Text` ni `tooltip` no tiene nombre accesible |
| [THOR-R040](THOR-R040.md) | Un callback de `GestureDetector` o `InkWell` que el navegador no puede dar |

## Layout (inspector de desarrollo)

| Código | Qué pasa |
|---|---|
| [THOR-L001](THOR-L001.md) | Un `Row` o una `Column` se desborda |
| [THOR-L002](THOR-L002.md) | `Expanded`/`Flexible` fuera de un flex |
| [THOR-L003](THOR-L003.md) | `LayoutScope` de ancho cero |
| [THOR-L004](THOR-L004.md) | Un campo de texto sin nombre accesible |

## Páginas y servidor

| Código | Qué pasa |
|---|---|
| [THOR-P001](THOR-P001.md) | Dos rutas atrapan las mismas URLs |
| [THOR-P002](THOR-P002.md) | Exportar un sitio que negocia el idioma |
| [THOR-P003](THOR-P003.md) | El secreto de `SignedCookies` es corto |
| [THOR-P004](THOR-P004.md) | `next()` dos veces en un middleware |
| [THOR-P005](THOR-P005.md) | Falta un valor en `request.context` |
| [THOR-P006](THOR-P006.md) | `request.parent<T>()` sin un layout que cargue `T` |
| [THOR-P007](THOR-P007.md) | Un campo de otro esquema en `FormValid.of` |
| [THOR-P008](THOR-P008.md) | Dos campos de un `FormSchema` con el mismo nombre |
| [THOR-P009](THOR-P009.md) | Una acción devolvió un valor que no es un resultado |
| [THOR-P010](THOR-P010.md) | Una cookie después de la respuesta temprana (`earlyHints`) |
| [THOR-P011](THOR-P011.md) | El entorno no es válido |
| [THOR-P012](THOR-P012.md) | Un secreto del entorno llegó a una página |
| [THOR-P013](THOR-P013.md) | Una página con datos sin `load` |
| [THOR-P014](THOR-P014.md) | Una ruta o un enlace mal formado |
| [THOR-P015](THOR-P015.md) | `request.param` de un parámetro que la ruta no tiene |
| [THOR-P016](THOR-P016.md) | Un middleware de la lista falló |
| [THOR-P019](THOR-P019.md) | `PageRequest.current` fuera de una query o un comando |
| [THOR-P020](THOR-P020.md) | Un formulario apunta a algo que no es una acción de la página |
| [THOR-P030](THOR-P030.md) | `Form(defaults:)` no es un mapa ni un objeto con `toJson()` |
| [THOR-P031](THOR-P031.md) | Un `Validator.custom` en un `TextFormField` que ningún esquema del servidor revisa |
| [THOR-P032](THOR-P032.md) | Un `OptionalSchemaField` con `Validator.required` |
| [THOR-P033](THOR-P033.md) | Una sesión firmada sin `maxAge` |
| [THOR-P034](THOR-P034.md) | Una `query` o un `command` lanzó una excepción que no es `HttpError` (la página solo muestra el mensaje genérico) |
| [THOR-P035](THOR-P035.md) | Un `RegExp` con banderas (`caseSensitive: false`…) en un `Validator.pattern` |
| [THOR-P036](THOR-P036.md) | Un `Form` dentro de un `AutofillGroup` que ya es un `<form>` |
| [THOR-P037](THOR-P037.md) | `PageRequest.loaded<D>()` sin datos cargados |

## Build y generación de código

| Código | Qué pasa |
|---|---|
| [THOR-B002](THOR-B002.md) | Un método de `ThorState` se omite |
| [THOR-B010](THOR-B010.md) | Falta `cwebp` para las variantes de las imágenes |
| [THOR-B011](THOR-B011.md) | Una imagen de `web/images/` que el build no puede leer |
| [THOR-B012](THOR-B012.md) | Un estado usa algo que no puede correr en el navegador |
| [THOR-B013](THOR-B013.md) | Falta un codificador AVIF para las imágenes |
| [THOR-B014](THOR-B014.md) | Una fuente que `thor fonts metrics` no puede leer |
| [THOR-B016](THOR-B016.md) | A un idioma le faltan mensajes |
| [THOR-B017](THOR-B017.md) | Un destino de deploy que no aplica a esta app |
| [THOR-B018](THOR-B018.md) | Una clase de estado que el registro no puede nombrar |
| [THOR-B021](THOR-B021.md) | Una query o un comando cuyo valor o argumento no viaja como JSON |
| [THOR-B023](THOR-B023.md) | Una página con acciones que el registro no puede nombrar |
| [THOR-B024](THOR-B024.md) | Un método de acción con un esquema que thor no puede construir |
| [THOR-B030](THOR-B030.md) | Un lambda de fila que el build no puede dar al navegador |
| [THOR-B033](THOR-B033.md) | Un `ValueNotifier` suelto como campo de un estado |
| [THOR-B035](THOR-B035.md) | Un `derived(...)` que escribe un campo |
| [THOR-B036](THOR-B036.md) | Dos estados con el mismo nombre de clase |

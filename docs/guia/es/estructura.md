# Estructura del proyecto

Agrupa el código por módulo del negocio, con las capas dentro de cada uno, y decide qué carpeta puede importar a cuál.

:::flutter Flutter: carpetas por capa (`ui/`, `data/`) · Thor: carpetas por módulo, con las capas dentro

## Carpetas por módulo

Cada módulo es un `Group` de la tabla de rutas, con su layout, sus permisos, sus datos y sus componentes. `router.dart` solo compone los módulos.

:::example demo-explorer
:::

## Dónde va cada archivo

Un archivo va en la carpeta más baja que lo usa, y sube cuando otro módulo lo necesita.

| Si es… | Va en |
|---|---|
| Un componente sin términos del negocio | `core/widgets/` |
| Un componente del negocio | `modules/sales/widgets/`, o `modules/sales/orders/widgets/` si es de una sola funcionalidad |
| Una llamada al backend | `modules/sales/data/` |
| Un ViewModel o las reglas de un formulario | `modules/sales/orders/state/` y `modules/sales/orders/forms/` |
| La sesión y los permisos de varios módulos | `core/session/` y `core/auth/`; una regla de un solo módulo, en `modules/sales/middleware/` |
| El encabezado, la navegación o el pie | `shell/` |

`thor add page`, `thor add state` y `thor add middleware` crean cada archivo en su carpeta ([El comando thor](cli.md)).

## Las dependencias bajan

Un archivo importa de su módulo y de `core/`; nunca de otro módulo, salvo sus rutas para enlazar.

| Quién importa | Puede importar |
|---|---|
| `router.dart` y `shell/` | `core/` y las rutas (`*_routes.dart`) de cada módulo |
| Una página | `core/`, su módulo y su submódulo; de otro módulo, solo sus rutas |
| Un componente | `core/`, su módulo y su submódulo |
| Un repositorio | `core/` y los modelos de su módulo |
| `core/` | solo `core/` |

Si dos módulos necesitan lo mismo, el código sube a `core/`.

> **Nota:** La página de error general va en `shell/app_error_page.dart`, en el `Group` raíz, y cada módulo puede tener la suya ([Rutas y navegación](navegacion.md#páginas-de-error)).

## Siguientes pasos

:::cards
- [Capa de interfaz](capa-ui.md) — la vista y las dos mitades del ViewModel
- [Capa de datos](capa-datos.md) — repositorios, servicios e inyección
- [Patrones](patrones.md) — commands, errores y estado optimista
:::

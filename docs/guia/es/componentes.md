# Componentes

Los widgets de Material de Thor, por categoría, con los nombres y parámetros de Flutter y un ejemplo vivo de cada uno.

:::cards
- [Botones](componentes-botones.md) — `FilledButton`, `OutlinedButton`, `TextButton`, `IconButton` y `FloatingActionButton`
- [Entradas](componentes-entradas.md) — `TextField`, `TextFormField`, `DropdownButton`, `Autocomplete`, fechas y `Slider`
- [Selección](componentes-seleccion.md) — `Checkbox`, `Switch`, `Radio`, `SegmentedButton` y chips
- [Contenido](componentes-contenido.md) — `Text`, `Icon`, `Image`, `Card`, `ListTile`, `DataTable` y `CarouselView`
- [Navegación](componentes-navegacion.md) — `AppBar`, `Scaffold`, `TabBar`, `Drawer`, `NavigationBar` y `Link`
- [Avisos](componentes-avisos.md) — `AlertDialog`, `Dialog`, `SnackBar`, progreso y `PopupMenuButton`
:::

## Widgets de Flutter sin equivalente

| Widget de Flutter | Qué usar en Thor |
| --- | --- |
| `ToggleButtons` | `SegmentedButton` ([Selección](componentes-seleccion.md#segmentedbutton)) |
| `RangeSlider` | dos `Slider`, uno para cada extremo |
| `SearchBar`, `SearchAnchor` | `Autocomplete` o `TextField` con `prefixIcon` ([Entradas](componentes-entradas.md#autocomplete)) |
| `Stepper` | un `ExpansionTile` por paso, con el mismo `name` ([Contenido](componentes-contenido.md#expansiontile)) |
| `SimpleDialog`, `AboutDialog` | `Dialog` o `AlertDialog` ([Avisos](componentes-avisos.md)) |
| `NavigationDrawer`, `BottomAppBar` | `Drawer` con `ListTile`, `NavigationBar` ([Navegación](componentes-navegacion.md)) |

Las funciones de Flutter que abren algo con un `BuildContext` (`showDialog`, `showModalBottomSheet`, `ScaffoldMessenger`) tienen su equivalente en [Si vienes de Flutter](desde-flutter.md#nombres-de-flutter-que-no-existen).

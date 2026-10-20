# Components

Thor's Material widgets, by category, with Flutter's names and parameters and a live example of each one.

:::cards
- [Buttons](components-buttons.md) — `FilledButton`, `OutlinedButton`, `TextButton`, `IconButton` and `FloatingActionButton`
- [Inputs](components-inputs.md) — `TextField`, `TextFormField`, `DropdownButton`, `Autocomplete`, dates and `Slider`
- [Selection](components-selection.md) — `Checkbox`, `Switch`, `Radio`, `SegmentedButton` and chips
- [Content](components-content.md) — `Text`, `Icon`, `Image`, `Card`, `ListTile`, `DataTable` and `CarouselView`
- [Navigation](components-navigation.md) — `AppBar`, `Scaffold`, `TabBar`, `Drawer`, `NavigationBar` and `Link`
- [Feedback](components-feedback.md) — `AlertDialog`, `Dialog`, `SnackBar`, progress and `PopupMenuButton`
:::

## Flutter widgets without an equivalent

| Flutter widget | What to use in Thor |
| --- | --- |
| `ToggleButtons` | `SegmentedButton` ([Selection](components-selection.md#segmentedbutton)) |
| `RangeSlider` | two `Slider`s, one for each end |
| `SearchBar`, `SearchAnchor` | `Autocomplete` or `TextField` with `prefixIcon` ([Inputs](components-inputs.md#autocomplete)) |
| `Stepper` | one `ExpansionTile` per step, with the same `name` ([Content](components-content.md#expansiontile)) |
| `SimpleDialog`, `AboutDialog` | `Dialog` or `AlertDialog` ([Feedback](components-feedback.md)) |
| `NavigationDrawer`, `BottomAppBar` | `Drawer` with `ListTile`, `NavigationBar` ([Navigation](components-navigation.md)) |

Flutter functions that open something with a `BuildContext` (`showDialog`, `showModalBottomSheet`, `ScaffoldMessenger`) have their equivalent in [Coming from Flutter](from-flutter.md#flutter-names-that-dont-exist).

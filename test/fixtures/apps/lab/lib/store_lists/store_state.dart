import 'package:thor_ui/thor_ui.dart';

/// A category of the store's menu.
class Category {
  const Category(this.slug, this.name);

  final String slug;
  final String name;

  String get url => '/c/$slug';
}

/// What the store page changes in the browser: the branches of its menu (one
/// list per department), and the accordion's toggles.
class StoreState extends ThorState {
  final branches = state<Map<String, List<String>>>(const {
    'food': ['fruit', 'bread'],
    'home': ['lamp'],
    'toys': [],
  });

  /// What `onExpansionChanged` heard, in order: `+food` opened, `-food` closed.
  final log = state('');

  /// A list per instance: `Watch.list(store.branchOf.withArg(slug))`.
  List<String> branchOf(String slug) => branches.value[slug] ?? const [];
  String rowKey(String name) => name;
  String rowName(String name) => name;
  String rowUrl(String name) => '/c/$name';

  void addTo(String slug) {
    branches.value = {
      ...branches.value,
      slug: [...branchOf(slug), 'new${branchOf(slug).length}'],
    };
  }

  void toggled(String slug, bool open) {
    log.value = '${log.value}${open ? '+' : '-'}$slug ';
  }

  String logText() => log.value.trim();
}

/// The store page's state.
final store = StoreState();

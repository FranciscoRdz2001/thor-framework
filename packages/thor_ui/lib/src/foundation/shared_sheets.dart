part of 'style_registry.dart';

// Stylesheet files a page links instead of carrying them inline:
// the base sheet of a server app and the sheets of its route modules
// (`Group(styles:)`). Both come from the code, never from the traffic, so
// every isolate of a server makes the same file for the same name.

/// A stylesheet file every page of a server app links (`WidgetRenderer(
/// shareStyles: true)`): the layer order, the app stylesheet, the theme and
/// the classes of the declared specimens. A page leaves out of its own
/// `<style>` what the file holds.
final class LinkedStyleSheet {
  LinkedStyleSheet._({
    required this.href,
    required this.css,
    required Map<String, String> classes,
    required String? tokens,
    required Map<String, String> keyframes,
    required Map<String, String> properties,
  }) : _classes = classes,
       _tokens = tokens,
       _keyframes = keyframes,
       _properties = properties;

  /// The sheet of what [registry] (a render of the specimens) registered,
  /// after [appCss] (the app stylesheet): the same text on every isolate
  /// that renders the same code.
  factory LinkedStyleSheet.of(ThorStyleRegistry registry, String appCss) {
    // The page's transition stays in each page (a route may choose another).
    final own = registry._cssText(transition: false);
    // The layer order first: the app's layered rules (the reset) and the
    // theme land in thor's layers.
    final css = '$thorLayerOrder$appCss${own.substring(thorLayerOrder.length)}';
    return LinkedStyleSheet._(
      href: '${_assetsDir}base.${ThorStyleRegistry.stableHash(css)}.css',
      css: css,
      classes: {
        for (final name in registry._rules.keys) name: ?registry._owners[name],
      },
      tokens: registry._pageRules.isEmpty ? null : registry._pageRules.join(),
      keyframes: {...registry._keyframes},
      properties: {...registry._properties},
    );
  }

  /// Site path of the file (`/_thor/base.<hash>.css`).
  final String href;

  /// Its text.
  final String css;

  /// Class name → the style it names: a page leaves a class out only when
  /// its own style of that name is this one.
  final Map<String, String> _classes;

  /// The theme rules (`thor.tokens`), or null.
  final String? _tokens;

  final Map<String, String> _keyframes;
  final Map<String, String> _properties;
}

/// The stylesheet of a route module (`Group(styles:)`): app rules every
/// page of the group gets, after the ones of the groups above it
/// (outermost first, so the deepest wins between equals).
///
/// Unlayered, like the app stylesheet: they beat every thor layer. Made
/// once per process from the code (`Group(styles:)`), so every
/// isolate names it the same.
final class ModuleSheet {
  ModuleSheet._(this.css)
    : href = '${_assetsDir}module.${ThorStyleRegistry.stableHash(css)}.css';

  /// The sheet of [rules] (one per distinct text in the process).
  factory ModuleSheet.of(List<StyleRule> rules) {
    final css = renderStyleRules(rules);
    noteAppStylesheet(css);
    final sheet = ModuleSheet._(css);
    return _byHref.putIfAbsent(sheet.href, () => sheet);
  }

  static final _byHref = <String, ModuleSheet>{};

  /// The sheet at [href], if this process made one.
  static ModuleSheet? at(String href) => _byHref[href];

  /// Every sheet this process made (what an export writes).
  static Iterable<ModuleSheet> get all => _byHref.values;

  /// Site path of the file (`/_thor/module.<hash>.css`).
  final String href;

  /// Its text.
  final String css;
}

/// Gives the pages under it the rules of a route module ([ModuleSheet]):
/// a `<link>` to its file when the renderer serves it, else a `<style>`.
/// What `Group(styles:)` wraps a module's layout in.
class ModuleStyles extends StatelessWidget implements ThorBuiltIn {
  /// Adds [sheet] to the page [child] is on.
  const ModuleStyles({super.key, required this.sheet, required this.child});

  /// The module's rules.
  final ModuleSheet sheet;

  /// The module's pages.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final registry = ThorStyleRegistry.active(context);
    if (registry == null) {
      // No ThorApp (or a late subtree): the rules go with the markup.
      return Widget.fragment([
        Widget.element(tag: 'style', children: [RawText(sheet.css)]),
        child,
      ]);
    }
    // Page-level output a replayed fragment wouldn't restore.
    registry._recording?.replayable = false;
    if (!registry._modules.contains(sheet)) registry._modules.add(sheet);
    return child;
  }
}

/// How the pages below get their shared stylesheets: what `WidgetRenderer`
/// puts above each page (`ThorApp` reads it).
class SharedStylesScope extends InheritedWidget {
  /// [sheet] linked by every page below (null: none); with [files] the
  /// module sheets are linked files too (else inline `<style>`s).
  /// [capture] receives the page's registry (the specimen render that
  /// makes the sheet).
  const SharedStylesScope({
    super.key,
    this.sheet,
    this.files = false,
    this.capture,
    this.errorFocus = false,
    required super.child,
  });

  /// The base sheet the pages link, or null.
  final LinkedStyleSheet? sheet;

  /// Whether module sheets are linked files.
  final bool files;

  /// Receives the registry of the page below.
  final void Function(ThorStyleRegistry registry)? capture;

  /// Whether this page is the answer of a failed form action (a `POST`
  /// re-rendered with a `4xx`/`5xx`): only then the first field with an
  /// error takes the focus. A page that merely shows an error (a `GET`, a
  /// showcase demo) never moves the focus or the scroll.
  final bool errorFocus;

  /// The nearest scope above [context], or null.
  static SharedStylesScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SharedStylesScope>();

  @override
  bool updateShouldNotify(SharedStylesScope oldWidget) =>
      oldWidget.sheet != sheet ||
      oldWidget.files != files ||
      oldWidget.errorFocus != errorFocus ||
      oldWidget.capture != capture;
}

const _assetsDir = '/_thor/';

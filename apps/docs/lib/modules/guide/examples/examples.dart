/// Live examples: `:::example id` in the markdown shows the widget of
/// `gallery.dart` (or another example file) on a `StudioBench` stage, with a
/// "View code" view: the Flutter code (read from that file), and the HTML
/// and CSS thor really generates for it. `:::bench id` shows an example with
/// controls (`bench/bench_example.dart`).
library;

import 'dart:io';

import 'package:thor_ui/testing.dart' show bodyOfPage, renderDocument;
import 'package:thor_ui/thor_ui.dart';

import 'architecture_examples.dart';
import 'bench/animated_list_bench.dart';
import 'bench/bench_example.dart';
import 'bench/card_style_bench.dart';
import 'bench/counter_step_bench.dart';
import 'bench/derived_bench.dart';
import 'bench/drag_bench.dart';
import 'bench/explicit_bench.dart';
import 'bench/form_bench.dart';
import 'bench/icon_variants_bench.dart';
import 'bench/implicit_bench.dart';
import 'bench/install_bench.dart';
import 'bench/lazy_piece_bench.dart';
import 'bench/live_feed_bench.dart';
import 'bench/locale_bench.dart';
import 'bench/long_list_bench.dart';
import 'bench/motion_choreo_bench.dart';
import 'bench/motion_curves_bench.dart';
import 'bench/motion_position_bench.dart';
import 'bench/motion_scroll_bench.dart';
import 'bench/motion_switch_bench.dart';
import 'bench/overlay_bench.dart';
import 'bench/page_transition_bench.dart';
import 'bench/query_bench.dart';
import 'bench/row_alignment_bench.dart';
import 'bench/semantics_bench.dart';
import 'bench/tap_position_bench.dart';
import 'bench/text_style_bench.dart';
import 'bench/theme_colors_bench.dart';
import 'bench/tween_bench.dart';
import 'catalog_buttons.dart' as cat_buttons;
import 'catalog_content.dart' as cat_content;
import 'catalog_feedback.dart' as cat_feedback;
import 'catalog_icons.dart' as cat_icons;
import 'catalog_inputs.dart' as cat_inputs;
import 'catalog_motion.dart' as cat_motion;
import 'catalog_navigation.dart' as cat_navigation;
import 'catalog_selection.dart' as cat_selection;
import 'form_examples.dart' as forms;
import 'gallery.dart' as gallery;
import 'get_started_examples.dart' as start;
import 'layout_examples.dart' as layout;
import 'learn/column_bench.dart';
import 'learn/compose_bench.dart';
import 'learn/flex_bench.dart';
import 'learn/greeting_bench.dart';
import 'learn/grid_bench.dart';
import 'learn/load_bench.dart';
import 'learn/middleware_bench.dart';
import 'learn/responsive_bench.dart';
import 'learn/route_link_bench.dart';
import 'learn/stack_bench.dart';
import 'learn/wrap_bench.dart';
import 'recipes_basic.dart' as recipes_basic;
import 'recipes_lists.dart' as recipes_lists;
import 'recipes_motion.dart' as recipes_motion;
import 'recipes_page.dart' as recipes_page;
import 'routing_examples.dart' as routing;
import 'state_examples.dart' as states;
import 'structure.dart' as structure;
import 'styles.dart' as styles;

export 'example_view.dart' show ExampleEmbed;

/// An example: [title], whether the browser alone runs it, the widget.
class DocExample {
  /// An example.
  const DocExample(
    MessageOf this.title,
    this.build, {
    this.native = true,
    this.stage = false,
    this.bare = false,
  }) : bench = null;

  /// An example with controls: its name, stage, code and panel are what
  /// [bench] declares. It always needs the engine (its controls drive a
  /// `ThorState`).
  DocExample.bench(BenchExample this.bench)
    : title = null,
      build = (() => const SizedBox.shrink()),
      native = false,
      stage = false,
      bare = false;

  /// Its name in the header.
  final MessageOf? title;

  /// Builds it.
  final Widget Function() build;

  /// Whether the browser alone runs it (else it needs the engine).
  final bool native;

  /// Shown in a box the reader resizes (an example that follows its
  /// container, `.when(container:)`).
  final bool stage;

  /// An illustration of the guide: shown as it is, without the example's
  /// header, stage or code.
  final bool bare;

  /// What an example with controls declares (`:::bench`), or null.
  final BenchExample? bench;
}

/// Every example, by the id the markdown names.
final examples = <String, DocExample>{
  // The reference examples with controls (`:::bench id`): one for layout, one
  // for style and one for state.
  'bench-row-align': DocExample.bench(rowAlignmentBench),
  'bench-card-style': DocExample.bench(cardStyleBench),
  'bench-counter-step': DocExample.bench(stepCounterBench),
  // The "Aprender" benches.
  'bench-column-align': DocExample.bench(columnAlignBench),
  'bench-flex': DocExample.bench(flexBench),
  'bench-stack': DocExample.bench(stackBench),
  'bench-wrap': DocExample.bench(wrapBench),
  'bench-grid': DocExample.bench(gridBench),
  'bench-responsive': DocExample.bench(responsiveBench),
  'bench-compose': DocExample.bench(composeBench),
  'bench-greeting': DocExample.bench(greetingBench),
  'bench-route-link': DocExample.bench(routeLinkBench),
  'bench-middleware': DocExample.bench(middlewareBench),
  'bench-load': DocExample.bench(loadBench),
  // UI (1): theme and styles, motion, gestures and icons.
  'bench-theme-colors': DocExample.bench(themeColorsBench),
  'bench-text-style': DocExample.bench(textStyleBench),
  'bench-implicit': DocExample.bench(implicitBench),
  'bench-tween': DocExample.bench(tweenBench),
  'bench-explicit': DocExample.bench(explicitBench),
  'bench-curves': DocExample.bench(curvesBench),
  'bench-position': DocExample.bench(positionBench),
  'bench-switcher': DocExample.bench(switcherBench),
  'bench-stagger': DocExample.bench(staggerBench),
  'bench-repeat': DocExample.bench(repeatBench),
  'bench-scroll-reveal': DocExample.bench(scrollRevealBench),
  'bench-animated-list': DocExample.bench(animatedListBench),
  'bench-page-transition': DocExample.bench(pageTransitionBench),
  'bench-tap-position': DocExample.bench(tapPositionBench),
  'bench-drag': DocExample.bench(dragBench),
  'bench-icons': DocExample.bench(iconVariantsBench),
  // Architecture (architecture_examples.dart).
  'bench-command': DocExample.bench(commandBench),
  'bench-optimistic': DocExample.bench(optimisticBench),
  // Data and state.
  'bench-state-derived': DocExample.bench(derivedBench),
  'bench-state-query': DocExample.bench(queryBench),
  'bench-live-feed': DocExample.bench(liveFeedBench),
  'bench-lazy-piece': DocExample.bench(lazyPieceBench),
  'bench-form-rule': DocExample.bench(formRuleBench),
  'bench-form-phase': DocExample.bench(formPhaseBench),
  'bench-start-install': DocExample.bench(installBench),
  // Get started (get_started_examples.dart).
  'start-widget-to-web': DocExample(
    (t) => t.exTitleStartWidgetToWeb,
    () => const start.WelcomeCard(),
  ),
  'start-store-grid': DocExample(
    (t) => t.exTitleStartStoreGrid,
    () => const start.StoreGrid(),
  ),
  'start-cart': DocExample(
    (t) => t.exTitleStartCart,
    () => const start.CartExample(),
    native: false,
  ),
  'start-checkout': DocExample(
    (t) => t.exTitleStartCheckout,
    () => const start.OrderForm(),
    native: false,
  ),
  'bench-overlay': DocExample.bench(overlayBench),
  'bench-long-list': DocExample.bench(longListBench),
  'bench-semantics': DocExample.bench(semanticsBenchExample),
  'bench-locale': DocExample.bench(localeBenchExample),
  'card': DocExample((t) => t.exTitleCard, () => const gallery.CoffeeCard()),
  'hover': DocExample(
    (t) => t.exTitleHover,
    () => const gallery.HoverColorBox(),
  ),
  'accordion': DocExample(
    (t) => t.exTitleAccordion,
    () => const gallery.FaqAccordion(),
  ),
  'carousel': DocExample(
    (t) => t.exTitleCarousel,
    () => const gallery.OffersCarousel(),
  ),
  'tabs': DocExample((t) => t.exTitleTabs, () => const gallery.OrderTabs()),
  'dialog': DocExample(
    (t) => t.exTitleDialog,
    () => const gallery.ConfirmChargeDialog(),
  ),
  'menu': DocExample((t) => t.exTitleMenu, () => const gallery.SortMenu()),
  'menu-anchor': DocExample(
    (t) => t.exTitleMenuAnchor,
    () => const gallery.AccountMenu(),
  ),
  // Forms (form_examples.dart).
  'form-controls': DocExample(
    (t) => t.exTitleFormControls,
    () => const forms.FormControlsDemo(),
    native: false,
  ),
  'form-submit': DocExample(
    (t) => t.exTitleFormSubmit,
    () => const forms.NewsletterDemo(),
    native: false,
  ),
  'form-schema': DocExample(
    (t) => t.exTitleFormSchema,
    () => const forms.SignUpView(),
  ),
  'form-schema-failed': DocExample(
    (t) => t.exTitleFormSchemaFailed,
    () => const forms.SignUpFailed(),
  ),
  'form-upload': DocExample(
    (t) => t.exTitleFormUpload,
    () => const forms.UploadDemo(),
  ),
  'form-field-params': DocExample(
    (t) => t.exTitleFormFieldParams,
    () => const forms.FieldParamsDemo(),
  ),
  'slider-bubble': DocExample(
    (t) => t.exTitleSliderBubble,
    () => const forms.SliderBubbleDemo(),
  ),
  'segmented-pill': DocExample(
    (t) => t.exTitleSegmentedPill,
    () => const forms.SegmentedPillDemo(),
  ),
  'scale': DocExample((t) => t.exTitleScale, () => const gallery.GrowOnHover()),
  'entrance': DocExample(
    (t) => t.exTitleEntrance,
    () => const gallery.LiveEntrance(),
  ),
  'chips': DocExample(
    (t) => t.exTitleChips,
    () => const gallery.ChipsAndProgress(),
  ),
  'product-card': DocExample(
    (t) => t.exTitleProductCard,
    () => const gallery.ColdBrewCard(),
  ),
  'wrappers': DocExample(
    (t) => t.exTitleWrappers,
    () => const gallery.TotalRow(),
  ),
  'grid': DocExample((t) => t.exTitleGrid, () => const gallery.ProductGrid()),
  'variants': DocExample(
    (t) => t.exTitleVariants,
    () => const gallery.ResponsiveVariants(),
  ),
  'hover-group': DocExample(
    (t) => t.exTitleHoverGroup,
    () => const gallery.HoverGroupCard(),
  ),
  // The layout guide (layout_examples.dart).
  'layout-sizes': DocExample(
    (t) => t.exTitleLayoutSizes,
    () => const layout.Sizes(),
  ),
  'layout-screen': DocExample(
    (t) => t.exTitleLayoutScreen,
    () => const layout.ScreenSizes(),
  ),
  'layout-grid-extent': DocExample(
    (t) => t.exTitleLayoutGridExtent,
    () => const layout.ExtentGrid(),
    stage: true,
  ),
  'layout-scroll': DocExample(
    (t) => t.exTitleLayoutScroll,
    () => const layout.ScrollViews(),
  ),
  'layout-responsive': DocExample(
    (t) => t.exTitleLayoutResponsive,
    () => const layout.ResponsiveProfile(),
  ),
  // The styles guide (styles.dart).
  'units': DocExample((t) => t.exTitleUnits, () => const styles.UnitBars()),
  'responsive-card': DocExample(
    (t) => t.exTitleResponsiveCard,
    () => const styles.ResponsiveCard(),
    stage: true,
  ),
  'sticky-list': DocExample(
    (t) => t.exTitleStickyList,
    () => const styles.StickyList(),
  ),
  'hover-effects': DocExample(
    (t) => t.exTitleHoverEffects,
    () => const styles.HoverEffects(),
  ),
  'component-themes': DocExample(
    (t) => t.exTitleComponentThemes,
    () => const styles.ComponentThemes(),
  ),
  'theme-follows-switch': DocExample(
    (t) => t.exTitleThemeFollowsSwitch,
    () => const styles.ThemeSwitchExample(),
    native: false,
  ),
  'descendants': DocExample(
    (t) => t.exTitleDescendants,
    () => const styles.ReleaseNotes(),
  ),
  'patterns': DocExample(
    (t) => t.exTitlePatterns,
    () => const styles.TiledPatterns(),
  ),
  // Project structure (structure.dart).
  'demo-explorer': DocExample(
    (t) => t.exTitleDemoExplorer,
    () => const structure.ExplorerView(),
    native: false,
    bare: true,
  ),
  // "Estado" (state_examples.dart): they need the engine.
  'state-bool': DocExample(
    (t) => t.exTitleStateBool,
    () => const states.FavoriteExample(),
    native: false,
  ),
  'state-enum': DocExample(
    (t) => t.exTitleStateEnum,
    () => const states.PlanExample(),
    native: false,
  ),
  'state-todo': DocExample(
    (t) => t.exTitleStateTodo,
    () => const states.TodoExample(),
    native: false,
  ),
  'state-form': DocExample(
    (t) => t.exTitleStateForm,
    () => const states.OrderExample(),
    native: false,
  ),
  'state-keyed': DocExample(
    (t) => t.exTitleStateKeyed,
    () => const states.ScoreExample(),
    native: false,
  ),
  'state-controllers': DocExample(
    (t) => t.exTitleStateControllers,
    () => const states.ProfileExample(),
    native: false,
  ),
  'state-pages': DocExample(
    (t) => t.exTitleStatePages,
    () => const states.DeckExample(),
    native: false,
  ),
  'state-lifecycle': DocExample(
    (t) => t.exTitleStateLifecycle,
    () => const states.ClockExample(),
    native: false,
  ),
  'state-feedback': DocExample(
    (t) => t.exTitleStateFeedback,
    () => const states.TasksExample(),
    native: false,
  ),
  'state-set': DocExample(
    (t) => t.exTitleStateSet,
    () => const states.ChipsExample(),
    native: false,
  ),
  'state-notifier': DocExample(
    (t) => t.exTitleStateNotifier,
    () => const states.PanelExample(),
    native: false,
  ),
  // Routes and data (routing_examples.dart).
  'routes-tree': DocExample(
    (t) => t.exTitleRoutesTree,
    () => const routing.RouteTreeView(),
    bare: true,
  ),
  'routes-nav': DocExample(
    (t) => t.exTitleRoutesNav,
    () => const routing.GuideNav(path: '/empezar/primera-app'),
  ),
  'data-form': DocExample(
    (t) => t.exTitleDataForm,
    () => const routing.ContactFormView(),
  ),
  'data-form-failed': DocExample(
    (t) => t.exTitleDataFormFailed,
    () => const routing.ContactFormFailed(),
  ),
  // The component catalog (catalog_*.dart), a page per category.
  'cat-filled-button': DocExample.bench(cat_buttons.filledButtonBench),
  'cat-outlined-button': DocExample.bench(cat_buttons.outlinedButtonBench),
  'cat-text-button': DocExample.bench(cat_buttons.textButtonBench),
  'cat-icon-button': DocExample.bench(cat_buttons.iconButtonBench),
  'cat-button-style': DocExample.bench(cat_buttons.buttonStyleBench),
  'cat-elevated-button': DocExample.bench(cat_buttons.elevatedButtonBench),
  'cat-icon-labels': DocExample.bench(cat_buttons.iconLabelsBench),
  'cat-fab': DocExample.bench(cat_buttons.fabBench),
  'cat-icon-button-variants': DocExample.bench(cat_buttons.iconVariantsBench),
  'cat-icons': DocExample(
    (t) => t.exTitleCatIcons,
    () => const cat_icons.IconsDemo(),
  ),
  'cat-icon-variants': DocExample(
    (t) => t.exTitleCatIconVariants,
    () => const cat_icons.IconVariantsDemo(),
  ),
  'cat-text-field': DocExample.bench(cat_inputs.textFieldExample),
  'cat-text-field-states': DocExample.bench(cat_inputs.textFieldStatesExample),
  'cat-text-form-field': DocExample.bench(cat_inputs.textFormFieldExample),
  'cat-dropdown': DocExample.bench(cat_inputs.dropdownExample),
  'cat-autocomplete': DocExample.bench(cat_inputs.autocompleteExample),
  'cat-dropdown-form-field': DocExample.bench(
    cat_inputs.dropdownFormFieldExample,
  ),
  'cat-date-field': DocExample.bench(cat_inputs.dateFieldExample),
  'cat-slider': DocExample.bench(cat_inputs.sliderExample),
  'cat-checkbox': DocExample.bench(cat_selection.checkboxBench),
  'cat-switch': DocExample.bench(cat_selection.switchBench),
  'cat-radio': DocExample.bench(cat_selection.radioBench),
  'cat-segmented-button': DocExample.bench(cat_selection.segmentedButtonBench),
  'cat-choice-chip': DocExample.bench(cat_selection.choiceChipBench),
  'cat-input-chip': DocExample.bench(cat_selection.inputChipBench),
  'cat-link-chip': DocExample.bench(cat_selection.linkChipBench),
  'cat-filter-chip': DocExample.bench(cat_selection.filterChipBench),
  'cat-list-tiles': DocExample.bench(cat_selection.listTilesBench),
  'cat-text': DocExample.bench(cat_content.textBenchExample),
  'cat-icon': DocExample.bench(cat_content.iconBenchExample),
  'cat-image': DocExample.bench(cat_content.imageBenchExample),
  'cat-image-builders': DocExample.bench(cat_content.imageBuildersBench),
  'cat-rich-text': DocExample.bench(cat_content.richTextBench),
  'cat-card': DocExample.bench(cat_content.cardBenchExample),
  'cat-list-tile': DocExample.bench(cat_content.listTileBenchExample),
  'cat-html-widget': DocExample.bench(cat_content.htmlWidgetBench),
  'cat-divider': DocExample.bench(cat_content.dividerBenchExample),
  'cat-avatar-badge': DocExample.bench(cat_content.avatarBadgeBench),
  'cat-chip': DocExample.bench(cat_content.chipBench),
  'cat-tooltip': DocExample.bench(cat_content.tooltipBenchExample),
  'cat-data-table': DocExample.bench(cat_content.dataTableBenchExample),
  'cat-expansion-tile': DocExample.bench(cat_content.expansionTileBench),
  // Animations, gestures and pointer events (catalog_motion.dart).
  'motion-animated-size': DocExample(
    (t) => t.exTitleMotionAnimatedSize,
    () => const cat_motion.AnimatedSizeDemo(),
    native: false,
  ),
  'events-hover-focus': DocExample(
    (t) => t.exTitleEventsHoverFocus,
    () => const cat_motion.PointerEventsDemo(),
    native: false,
  ),
  'events-expansion': DocExample(
    (t) => t.exTitleEventsExpansion,
    () => const cat_motion.ExpansionEventsDemo(),
    native: false,
  ),
  'gesture-inkwell': DocExample(
    (t) => t.exTitleGestureInkwell,
    () => const cat_motion.InkWellDemo(),
    native: false,
  ),
  'gesture-swipe-keys': DocExample(
    (t) => t.exTitleGestureSwipeKeys,
    () => const cat_motion.SwipeKeysDemo(),
    native: false,
  ),
  'gesture-dismissible': DocExample(
    (t) => t.exTitleGestureDismissible,
    () => const cat_motion.DismissibleDemo(),
    native: false,
  ),
  'gesture-draggable': DocExample(
    (t) => t.exTitleGestureDraggable,
    () => const cat_motion.DraggableDemo(),
    native: false,
  ),
  'gesture-reorderable': DocExample(
    (t) => t.exTitleGestureReorderable,
    () => const cat_motion.ReorderableDemo(),
    native: false,
  ),
  'cat-app-bar': DocExample.bench(cat_navigation.appBarBench),
  'cat-tabs': DocExample.bench(cat_navigation.tabsBench),
  'cat-drawer': DocExample.bench(cat_navigation.drawerBench),
  'nav-slivers': DocExample(
    (t) => t.exTitleNavSlivers,
    () => const cat_navigation.SliversDemo(),
    native: true,
  ),
  'dialog-permanent-drawer': DocExample(
    (t) => t.exTitleDialogPermanentDrawer,
    () => const cat_navigation.PermanentDrawerDemo(),
  ),
  'cat-navigation-bar': DocExample.bench(cat_navigation.navigationBarBench),
  'cat-navigation-rail': DocExample.bench(cat_navigation.navigationRailBench),
  'cat-link': DocExample.bench(cat_navigation.linkBench),
  'cat-bottom-sheet': DocExample.bench(cat_navigation.bottomSheetBench),
  'cat-alert-dialog': DocExample.bench(cat_feedback.alertDialogBench),
  'cat-dialog-controller': DocExample.bench(cat_feedback.dialogControllerBench),
  'cat-snackbar': DocExample.bench(cat_feedback.snackBarBench),
  'cat-progress': DocExample.bench(cat_feedback.progressBench),
  'cat-popup-menu': DocExample.bench(cat_feedback.popupMenuBench),
  // The widget pages of the reference look for `cat-<widget>`: the same
  // benches under those names.
  'cat-dialog': DocExample.bench(cat_feedback.dialogControllerBench),
  'cat-snack-bar': DocExample.bench(cat_feedback.snackBarBench),
  'cat-linear-progress-indicator': DocExample.bench(cat_feedback.progressBench),
  'cat-circular-progress-indicator': DocExample.bench(
    cat_feedback.progressBench,
  ),
  'cat-popup-menu-button': DocExample.bench(cat_feedback.popupMenuBench),
  // The recipes (recipes_*.dart), a page per recipe.
  'recipe-counter': DocExample.bench(recipes_basic.counterRecipeBench),
  'recipe-slide': DocExample.bench(recipes_motion.slideRecipeBench),
  'recipe-copy': DocExample.bench(recipes_motion.copyRecipeBench),
  'recipe-tabs': DocExample.bench(recipes_motion.tabsRecipeBench),
  'recipe-toasts': DocExample.bench(recipes_motion.toastRecipeBench),
  'recipe-temperature': DocExample.bench(recipes_basic.temperatureRecipeBench),
  'recipe-flights': DocExample(
    (t) => t.exTitleRecipeFlights,
    () => const recipes_basic.FlightBooker(),
    native: false,
  ),
  'recipe-timer': DocExample.bench(recipes_basic.timerRecipeBench),
  'recipe-crud': DocExample(
    (t) => t.exTitleRecipeCrud,
    () => const recipes_lists.CrudRecipe(),
    native: false,
  ),
  'recipe-circles': DocExample(
    (t) => t.exTitleRecipeCircles,
    () => const recipes_lists.CirclesRecipe(),
    native: false,
  ),
  'recipe-cells': DocExample(
    (t) => t.exTitleRecipeCells,
    () => const recipes_lists.CellsRecipe(),
    native: false,
  ),
  'recipe-content-page': DocExample.bench(recipes_page.contentPageBench),
};

/// What an example generates: its Flutter source, HTML and CSS.
class ExampleCode {
  /// The code of an example.
  const ExampleCode(this.dart, this.html, this.css);

  /// The example's source as the site shows it: its imports, the shared
  /// values it uses and its region of `gallery.dart`, `styles.dart` or
  /// `state_examples.dart`.
  final String dart;

  /// The body the widget becomes (pretty-printed).
  final String html;

  /// The rules of its classes.
  final String css;
}

final _code = <String, ExampleCode>{};

/// The code of example [id], once [prepareExamples] rendered it.
ExampleCode? exampleCode(String id) => _code[id];

/// Renders the examples [ids] (once per process): the page's build reads
/// them synchronously.
Future<void> prepareExamples(Iterable<String> ids) async {
  for (final id in ids) {
    if (_code.containsKey(id)) continue;
    final example = examples[id];
    // An example with controls shows live code, not generated HTML.
    if (example == null || example.bare || example.bench != null) continue;
    final page = await renderDocument(ThorApp(child: example.build()));
    final body = _bodyInner(bodyOfPage(page));
    _code[id] = ExampleCode(
      _source(id),
      _prettyHtml(body),
      _cssFor(page, body),
    );
  }
}

// ── Source ──

String? _gallery;

/// The example files, read once: each region lives in one of them.
String _sources() => [
  for (final name in [
    'gallery',
    'get_started_examples',
    'styles',
    'state_examples',
    'routing_examples',
    'form_examples',
    'layout_examples',
    'catalog_shared',
    'catalog_buttons',
    'catalog_inputs',
    'catalog_selection',
    'catalog_content',
    'catalog_motion',
    'catalog_navigation',
    'catalog_feedback',
    'catalog_icons',
    'recipes_basic',
    'recipes_lists',
    'recipes_page',
  ])
    [
      'lib/modules/guide/examples/$name.dart',
      'apps/docs/lib/modules/guide/examples/$name.dart',
    ].map(File.new).firstWhere((f) => f.existsSync()).readAsStringSync(),
].join('\n');

String _region(String id) {
  _gallery ??= _sources();
  final start = _gallery!.indexOf('// region: $id\n');
  if (start < 0) return '';
  final from = start + '// region: $id\n'.length;
  final end = _gallery!.indexOf('// endregion', from);
  return _gallery!.substring(from, end).trimRight();
}

/// The declarations of every `shared` region (`const _ink = …;` of the
/// styles guide, a catalog's shared constants), by name
/// (each example file may have one; names don't repeat across them).
List<(String, String)> _shared() {
  _gallery ??= _sources();
  final sources = _gallery!;
  return [
    for (final region in RegExp(
      r'// region: (?:catalog-)?shared\n([\s\S]*?)// endregion',
    ).allMatches(sources))
      for (final m in RegExp(
        r'^const (\w+) =[\s\S]*?;$',
        multiLine: true,
      ).allMatches(region[1]!))
        (m[1]!, m[0]!),
  ];
}

/// The code a reader can copy: imports, the shared values the example uses
/// and its region.
String _source(String id) {
  final region = _region(id);
  if (region.isEmpty) return '';
  final shared = [
    for (final (name, declaration) in _shared())
      if (RegExp('\\b$name\\b').hasMatch(region)) declaration,
  ];
  return [
    [
      if (region.contains('dart:async') || region.contains('Timer'))
        "import 'dart:async';",
      if (region.contains('html.'))
        "import 'package:thor_ui/html.dart' as html;",
      if (region.contains(
        RegExp(r'\b(Route|FormSchema|FormInvalid|guideRoute|\w*SchemaField)\b'),
      ))
        "import 'package:thor_ui/router.dart';",
      "import 'package:thor_ui/thor_ui.dart';",
    ].join('\n'),
    if (shared.isNotEmpty) shared.join('\n'),
    region,
  ].join('\n\n');
}

// ── HTML ──

String _bodyInner(String body) {
  final open = body.indexOf('>') + 1;
  final close = body.lastIndexOf('</body>');
  return body
      .substring(open, close < 0 ? body.length : close)
      .replaceAll(RegExp(r'<script\b[\s\S]*?</script>'), '')
      // Debug builds mark elements for the inspector (`data-thor`,
      // `data-thor-flex-item`, `data-thor-grid-item`…); release doesn't.
      .replaceAll(RegExp(r' data-thor(-[\w-]+)?(="[^"]*")?'), '')
      .trim();
}

const _void = {'input', 'img', 'br', 'hr', 'meta', 'link', 'use', 'path'};

/// One tag per line, children indented; short text stays inline.
String _prettyHtml(String html) {
  final out = StringBuffer();
  var depth = 0;
  final tokens = RegExp(r'<[^>]+>|[^<]+').allMatches(html).map((m) => m[0]!);
  String? pendingOpen;
  void line(String s) => out.writeln('${'  ' * depth}$s');
  for (final t in tokens) {
    if (t.startsWith('</')) {
      if (pendingOpen != null) {
        line('$pendingOpen$t');
        pendingOpen = null;
      } else {
        depth = depth > 0 ? depth - 1 : 0;
        line(t);
      }
      continue;
    }
    if (t.startsWith('<')) {
      if (pendingOpen != null) {
        line(pendingOpen);
        depth++;
        pendingOpen = null;
      }
      final name = RegExp(r'^<([a-zA-Z0-9-]+)').firstMatch(t)?[1] ?? '';
      if (t.endsWith('/>') || _void.contains(name.toLowerCase())) {
        line(t);
      } else {
        pendingOpen = t;
      }
      continue;
    }
    final text = t.trim();
    if (text.isEmpty) continue;
    if (pendingOpen != null) {
      pendingOpen = '$pendingOpen$text';
    } else {
      line(text);
    }
  }
  if (pendingOpen != null) line(pendingOpen);
  return out.toString().trimRight();
}

// ── CSS ──

/// The rules of the classes in [body], from the page's stylesheet (its
/// layers unwrapped; media and container queries kept around their rules).
String _cssFor(String page, String body) {
  final classes = {
    for (final m in RegExp(r'class="([^"]*)"').allMatches(body))
      ...m[1]!.split(' ').where((c) => c.isNotEmpty),
  };
  // The sheet may carry attributes (`data-named`).
  final open = RegExp('<style id="thor-styles"[^>]*>').firstMatch(page);
  if (open == null) return '';
  final end = page.indexOf('</style>', open.end);
  final sheet = page.substring(open.end, end);
  final out = StringBuffer();
  void walk(String css, String? wrapper) {
    var i = 0;
    while (i < css.length) {
      final brace = css.indexOf('{', i);
      final semi = css.indexOf(';', i);
      if (brace < 0) break;
      if (semi >= 0 && semi < brace) {
        i = semi + 1; // `@layer a, b;`
        continue;
      }
      final selector = css.substring(i, brace).trim();
      var depth = 1, j = brace + 1;
      while (j < css.length && depth > 0) {
        if (css[j] == '{') depth++;
        if (css[j] == '}') depth--;
        j++;
      }
      final inner = css.substring(brace + 1, j - 1);
      if (selector.startsWith('@layer')) {
        if (!selector.contains('thor.props') &&
            !selector.contains('thor.overrides')) {
          i = j;
          continue;
        }
        walk(inner, wrapper);
      } else if (selector.startsWith('@media') ||
          selector.startsWith('@container') ||
          selector.startsWith('@starting-style') ||
          selector.startsWith('@supports')) {
        walk(inner, selector);
      } else if (classes.any((c) => selector.contains('.$c'))) {
        final decls = inner
            .split(';')
            .map((d) => d.trim())
            .where((d) => d.isNotEmpty)
            .toList();
        final pad = wrapper == null ? '' : '  ';
        if (wrapper != null) out.writeln('$wrapper {');
        out.writeln('$pad$selector {');
        for (final d in decls) {
          out.writeln('$pad  $d;');
        }
        out.writeln('$pad}');
        if (wrapper != null) out.writeln('}');
      }
      i = j;
    }
  }

  walk(sheet, null);
  return out.toString().trimRight();
}

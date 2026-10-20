/// The thor studio design system: big cards on a near-black (or near-white)
/// page, pill controls, Inter and IBM Plex Mono, borders instead of shadows,
/// short purposeful motion. Built from public thor_ui widgets; no
/// JavaScript. Themed like Flutter's Material: a full Material 3 color scheme
/// and text theme, Flutter's component themes, and one `ThemeExtension` per
/// component for what Material has no widget for.
///
/// ```dart
/// // One instance each (top-level finals): palette, text, component
/// // themes, fonts, selection and focus ring. No stylesheet to wire up.
/// final theme = StudioTheme.light(fontsPath: '/fonts');
/// final darkTheme = StudioTheme.dark(fontsPath: '/fonts');
/// ThorApp(theme: theme, darkTheme: darkTheme, child: StudioScaffold(
///   skipLabel: 'Skip to content',
///   appBar: StudioTopBar(brand: const StudioBrand(name: 'thor')),
///   drawer: StudioSideNav(label: 'Docs', sections: …),
///   sidebarLabel: 'Docs',
///   menuLabel: 'Open navigation',
///   body: StudioProse(html),
/// ))
/// ```
library;

export 'src/attributes.dart';
export 'src/highlight.dart';
export 'src/icons.dart';
export 'src/l10n/studio_localizations.dart';
export 'src/theme/component_themes/studio_bench_theme.dart';
export 'src/theme/component_themes/studio_button_theme.dart';
export 'src/theme/component_themes/studio_callout_theme.dart';
export 'src/theme/component_themes/studio_card_theme.dart';
export 'src/theme/component_themes/studio_chip_theme.dart';
export 'src/theme/component_themes/studio_code_theme.dart';
export 'src/theme/component_themes/studio_nav_theme.dart';
export 'src/theme/component_themes/studio_panel_theme.dart';
export 'src/theme/component_themes/studio_segmented_button_theme.dart';
export 'src/theme/component_themes/studio_slider_theme.dart';
export 'src/theme/studio_extra_colors.dart';
export 'src/theme/studio_extra_text_styles.dart';
export 'src/theme/studio_theme.dart';
export 'src/tokens/color/studio_accent_colors.dart';
export 'src/tokens/color/studio_action_colors.dart';
export 'src/tokens/color/studio_bench_colors.dart';
export 'src/tokens/color/studio_border_colors.dart';
export 'src/tokens/color/studio_content_colors.dart';
export 'src/tokens/color/studio_palette.dart';
export 'src/tokens/color/studio_shadow_colors.dart';
export 'src/tokens/color/studio_status_colors.dart';
export 'src/tokens/color/studio_surface_colors.dart';
export 'src/tokens/color/studio_syntax_colors.dart';
export 'src/tokens/color/studio_tone.dart';
export 'src/tokens/color/studio_tone_colors.dart';
export 'src/tokens/elevation/studio_shadows.dart';
export 'src/tokens/motion/studio_curves.dart';
export 'src/tokens/motion/studio_durations.dart';
export 'src/tokens/motion/studio_motion.dart';
export 'src/tokens/motion/studio_motion_styles.dart';
export 'src/tokens/shape/studio_radii.dart';
export 'src/tokens/spacing/studio_layout.dart';
export 'src/tokens/spacing/studio_spacing.dart';
export 'src/tokens/typography/studio_font_families.dart';
export 'src/tokens/typography/studio_font_weights.dart';
export 'src/tokens/typography/studio_letter_spacing.dart';
export 'src/tokens/typography/studio_line_heights.dart';
export 'src/tokens/typography/studio_type_scale.dart';
export 'src/widgets/bench/studio_bench.dart';
export 'src/widgets/bench/studio_bench_group.dart';
export 'src/widgets/bench/studio_bench_panel.dart';
export 'src/widgets/bench/studio_bench_row.dart';
export 'src/widgets/content/studio_callout.dart';
export 'src/widgets/content/studio_card_grid.dart';
export 'src/widgets/content/studio_code_block.dart';
export 'src/widgets/content/studio_code_tabs.dart';
export 'src/widgets/content/studio_compare_summary.dart';
export 'src/widgets/content/studio_content_icons.dart';
export 'src/widgets/content/studio_file_tree.dart';
export 'src/widgets/content/studio_flutter_compare.dart';
export 'src/widgets/content/studio_kbd.dart';
export 'src/widgets/content/studio_layer_diagram.dart';
export 'src/widgets/content/studio_link_card.dart';
export 'src/widgets/content/studio_prose.dart';
export 'src/widgets/content/studio_steps.dart';
export 'src/widgets/content/studio_table.dart';
export 'src/widgets/content/support/studio_code_diff.dart';
export 'src/widgets/content/support/studio_code_language.dart';
export 'src/widgets/content/support/studio_line_range.dart';
export 'src/widgets/feedback/studio_status_label.dart';
export 'src/widgets/inputs/studio_filter_chip.dart';
export 'src/widgets/inputs/studio_level_slider.dart';
export 'src/widgets/inputs/studio_segmented_control.dart'
    show StudioButtonSegment, StudioSegmentedControl;
export 'src/widgets/layout/studio_brand.dart';
export 'src/widgets/layout/studio_footer.dart';
export 'src/widgets/layout/studio_page_header.dart';
export 'src/widgets/layout/studio_scaffold.dart';
export 'src/widgets/layout/studio_top_bar.dart';
export 'src/widgets/navigation/studio_breadcrumbs.dart';
export 'src/widgets/navigation/studio_icon_button.dart';
export 'src/widgets/navigation/studio_locale_option.dart';
export 'src/widgets/navigation/studio_locale_switcher.dart';
export 'src/widgets/navigation/studio_nav_destination.dart';
export 'src/widgets/navigation/studio_nav_section.dart';
export 'src/widgets/navigation/studio_pager_links.dart';
export 'src/widgets/navigation/studio_search_dialog.dart';
export 'src/widgets/navigation/studio_search_pill.dart';
export 'src/widgets/navigation/studio_side_nav.dart';
export 'src/widgets/navigation/studio_table_of_contents.dart';
export 'src/widgets/navigation/studio_theme_choice.dart';
export 'src/widgets/navigation/studio_theme_toggle.dart';
export 'src/widgets/navigation/studio_toc_entry.dart';

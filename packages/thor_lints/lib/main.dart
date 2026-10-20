/// thor's analyzer plugin: `dart analyze` and IDEs load it from the
/// workspace `analysis_options.yaml` (`plugins: thor_lints: path: …`).
library;

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/animated_switcher_rule.dart';
import 'src/avoid_raw_css.dart';
import 'src/css_literals.dart';
import 'src/env_var_not_in_schema.dart';
import 'src/frozen_state_read_rule.dart';
import 'src/future_builder_nullable_has_data.dart';
import 'src/icon_button_without_name.dart';
import 'src/length_unit_in_const.dart';
import 'src/lite_subset_rule.dart';
import 'src/missing_thor_element_widget.dart';
import 'src/query_builder_reads_data.dart';
import 'src/row_server_read_rule.dart';
import 'src/state_misuse_rule.dart';
import 'src/stateful_set_state_rule.dart';
import 'src/style_css_names.dart';
import 'src/text_field_without_label.dart';
import 'src/untyped_form_action.dart';
import 'src/watch_field_builder.dart';
import 'src/widget_assists.dart';
import 'src/widget_props_in_styled.dart';

/// The plugin instance the analysis server looks up.
final plugin = ThorLintsPlugin();

/// Registers thor's rules and editor assists.
class ThorLintsPlugin extends Plugin {
  @override
  String get name => 'thor_lints';

  @override
  void register(PluginRegistry registry) {
    registry
      ..registerWarningRule(MissingThorElementWidget())
      // Styled is for web-only values: a value a Flutter widget owns goes
      // through that widget.
      ..registerWarningRule(WidgetPropsInStyled())
      // `8.px` in a const: the compiler's error doesn't name the fix.
      ..registerWarningRule(LengthUnitInConst())
      // The web layer's Style speaks CSS: name the property a Flutter
      // name or value meant.
      ..registerWarningRule(StyleCssNames())
      // A closure where the browser needs a state's member, a state that
      // is not a top-level variable (THOR-S001/S011/S012).
      // `Watch(state.field, builder:)`: the analyzer and the compiler
      // infer different value types; only the compiler fails.
      ..registerWarningRule(WatchFieldBuilder())
      // `QueryBuilder`'s builder runs on the server: `snapshot.data` read
      // there is frozen, the value goes through Watch.
      ..registerWarningRule(QueryBuilderReadsData())
      // `FutureBuilder<T?>` that tells done from waiting with `hasData`
      // only: a future that answers null keeps the skeleton (THOR-R033).
      ..registerWarningRule(FutureBuilderNullableHasData())
      // Compiles, looks right, does nothing in the browser: `setState`
      // (THOR-S014), an `AnimatedSwitcher` with nothing to switch
      // (THOR-S016).
      // A state read while the server draws (THOR-S015).
      ..registerWarningRule(FrozenStateRead())
      // A state member called with `row.key` in a list row's builder
      // (THOR-S034): wrong in the rows the browser adds.
      ..registerWarningRule(RowServerRead())
      ..registerWarningRule(StatefulSetState())
      ..registerWarningRule(AnimatedSwitcherWithoutWatch())
      ..registerWarningRule(StateMisuseRule())
      // What the lite translator can't write as JS, with the build's
      // message and fix (THOR-B012).
      ..registerWarningRule(LiteSubsetRule())
      // An icon is decorative: a button with only one has no accessible
      // name unless it gets a `tooltip:`.
      ..registerWarningRule(IconButtonWithoutName())
      // The same for a text field: a `Text` beside it names nothing.
      ..registerWarningRule(TextFieldWithoutLabel())
      // A variable declared but missing from its `EnvSchema([...])`: it is
      // never loaded and `env.of` fails on the first request (THOR-P011).
      ..registerWarningRule(EnvVarNotInSchema())
      ..registerFixForRule(StateMisuseRule.callback, PassStateMember.new)
      ..registerFixForRule(StateMisuseRule.watch, PassStateMember.new)
      // A form action as a '?/name' string or a closure: a page method's
      // tear-off is checked by the compiler.
      ..registerWarningRule(UntypedFormAction())
      // A custom property named by a string more than once in a file, a
      // color written as `Color.css('#…')` or `Color.css('var(--…)')`.
      ..registerWarningRule(DuplicateCssVariableName())
      ..registerWarningRule(AvoidColorCssString())
      // Opt-in (`diagnostics: avoid_raw_css: true`): apps adopt it as they
      // move to typed styles.
      ..registerLintRule(AvoidRawCss());
    registerWidgetAssists(registry);
  }
}

/// thor: Flutter's widget API for the web.
///
/// The only import an app needs, the same way you import
/// `package:flutter/material.dart` in Flutter. The widget model uses
/// Flutter's names (`Widget`, `StatelessWidget`, `State`, `BuildContext`…);
/// only those are re-exported from the widget tree. Use `Widget.text('…')`
/// for a raw text node and `import 'package:thor_ui/html.dart' as html;` for
/// raw HTML.
library;

export 'package:meta/meta.dart'
    show immutable, mustCallSuper, protected, visibleForTesting;
export 'package:thor_engine/sanitize.dart' show HtmlPolicy, sanitizeHtml;
export 'package:thor_engine/thor_engine.dart'
    show
        Animation,
        AnimationController,
        AnimationStatus,
        AnimationStatusListener,
        AsyncSnapshot,
        CharacterActivator,
        Clipboard,
        ClipboardData,
        Computed,
        ConnectionState,
        DatePickerMode,
        DateUtils,
        DayPeriod,
        DialogController,
        FocusNode,
        FrameMessages,
        FrameSubscription,
        HardwareKeyboard,
        Intent,
        KeyDownEvent,
        KeyEvent,
        KeyEventResult,
        KeyRepeatEvent,
        KeyUpEvent,
        LogicalKeyboardKey,
        PageController,
        PageNavigator,
        PageRegion,
        ScrollController,
        ScrollPosition,
        ServerCommand,
        ServerCommandBase,
        ServerCommandWith,
        ServerErrorKind,
        ServerEventStream,
        ServerQuery,
        SelectableDayPredicate,
        ShortcutActivator,
        SingleActivator,
        SystemNavigator,
        TextEditingController,
        TextEditingValue,
        TextSelection,
        RowProbeLog,
        ThorController,
        ThorFeedback,
        ToastKind,
        Signal,
        ReadSignal,
        ConfirmSpec,
        StateBoolToggle,
        StateSetOps,
        StateSignal,
        ThorMember,
        ThorState,
        ThorStateType,
        TimeOfDay,
        ViewPhase,
        ViewRange,
        WithArg,
        WithBothArgs,
        WithFirstArg,
        WithFirstOfThreeArgs,
        WithThreeArgs,
        batch,
        effect,
        splitArgs,
        command,
        commandWith,
        clearToasts,
        confirm,
        derived,
        hideToast,
        toast,
        events,
        query,
        queryWith,
        registerJsonModel,
        registerRowProbes,
        state,
        untracked;
export 'package:thor_server/image_manifest.dart'
    show ImageEntry, ImageManifest, ImageVariant;
export 'package:thor_server/server_messages.dart' show ServerMessages;
export 'package:thor_server/thor_server.dart' show RouteUrl;
export 'package:thor_style/thor_style.dart';

export 'src/animation/tween.dart'
    show
        Animatable,
        AlwaysStoppedAnimation,
        AnimationDrive,
        ColorTween,
        ConstantTween,
        CurveTween,
        CurvedAnimation,
        DecorationTween,
        IntTween,
        ReverseAnimation,
        Tween,
        TweenSequence,
        TweenSequenceItem;
export 'src/core/core.dart'
    show
        BuildContext,
        Builder,
        ChangeNotifier,
        Widget,
        GlobalKey,
        InheritedMemoKey,
        InheritedWidget,
        Key,
        Listenable,
        ListenableBuilder,
        State,
        StatefulWidget,
        StatelessWidget,
        UniqueKey,
        ValueKey,
        ValueListenable,
        ValueNotifier;
export 'src/engine/engine_script.dart' show EngineLoading;
export 'src/engine/watch.dart'
    show
        BoundLength,
        BoundLengthOfField,
        BoundLengthOfMethod,
        QueryBuilder,
        QueryError,
        RowColor,
        RowLength,
        RowTextBinding,
        ValueListenableBuilder,
        Watch,
        WatchAttributes,
        WatchItem,
        WatchRow,
        WatchVariables;
export 'src/foundation/base_styles.dart';
export 'src/foundation/child_rules.dart';
export 'src/foundation/const_memo.dart';
export 'src/foundation/css_rules.dart' show StyleRule;
export 'src/foundation/deferred.dart'
    show
        FutureBuilder,
        LazyPiece,
        LazyTrigger,
        LoadMore,
        LoadMoreTrigger,
        Region,
        defaultHeadBudget,
        defer,
        resolvedValue;
export 'src/foundation/foundation.dart';
export 'src/foundation/html_attributes.dart'
    show AriaAttribute, AttributeName, BooleanAttribute, HtmlAttributes;
export 'src/foundation/image_manifest_scope.dart';
export 'src/foundation/image_preload.dart';
export 'src/foundation/inspect.dart';
export 'src/foundation/layout_hint.dart' hide clearLayoutHints;
export 'src/foundation/localizations.dart' hide PreferredLocales;
export 'src/foundation/material_localizations.dart'
    hide MaterialStringsEn, MaterialStringsEs;
export 'src/foundation/page_navigation.dart'
    show
        PageNavigation,
        PageTransition,
        SpeculationDelivery,
        SpeculationEagerness,
        noPrefetchAttribute;
export 'src/foundation/parent_data.dart'
    hide RowWrapWith, mergeAttributes, splitNestedAttributes;
export 'src/foundation/responsive.dart' hide VariantCost, responsiveCostWarning;
export 'src/foundation/style_registry.dart'
    hide
        DescendantRulesScope,
        ElementStyle,
        FragmentRecord,
        LinkedStyleSheet,
        ModuleSheet,
        ModuleStyles,
        SharedStylesScope,
        beginFragmentRecord,
        classForElementStyle,
        elementClassConditions,
        elementStyle,
        elementStyleMemoSize,
        knownElementStyle,
        newElementStyle,
        endFragmentRecord,
        foldSchemeColors,
        noteAppStylesheet,
        readVariables,
        dropVariables,
        isCssColor,
        renderCachesEnabled,
        thorResetLayer,
        replayFragmentRecord;
export 'src/foundation/stylesheet.dart';
export 'src/foundation/widget_state.dart';
// `onPost: page.add.withArg(x)` in a widget that imports only this library
// (a Dart extension is only in scope where it is imported).
export 'src/router/page_actions.dart'
    show
        PageActionWithArg,
        PageActionWithArgs2,
        PageActionWithArgs3,
        PagePost,
        PageValidPost;
// The values the typed flex, grid and selection fields of `StyleProps` take
// (for HTML no widget builds); the rest of `src/web/style.dart` stays in
// `web.dart`.
export 'src/web/style.dart'
    show ContainerType, Display, GridTrack, GridTracks, UserSelect;
export 'src/widgets/animated_list.dart';
export 'src/widgets/animated_size.dart';
export 'src/widgets/animated_switcher.dart';
export 'src/widgets/app_bar.dart';
export 'src/widgets/autocomplete.dart';
export 'src/widgets/autofill_group.dart'
    show AutofillContextAction, AutofillGroup;
export 'src/widgets/basic.dart' hide padWith;
export 'src/widgets/buttons.dart'
    hide ButtonStyleResolved, buttonStyleCss, buttonStyleFrom;
export 'src/widgets/cached.dart';
export 'src/widgets/component_themes.dart';
export 'src/widgets/data_table.dart';
export 'src/widgets/date_picker.dart';
export 'src/widgets/dismissible.dart';
export 'src/widgets/divider.dart';
export 'src/widgets/draggable.dart';
export 'src/widgets/dropdown_menu.dart' hide menuStyleCss;
export 'src/widgets/effects.dart' hide SemanticsButton;
export 'src/widgets/expandable_text.dart';
export 'src/widgets/flex.dart';
export 'src/widgets/flutter_view.dart';
export 'src/widgets/form.dart' hide InsideForm;
export 'src/widgets/form_scope.dart' show FormFieldError, FormScope;
export 'src/widgets/gesture.dart'
    hide gestureFollows, gestureRegisterStyles, gestureWrapData;
export 'src/widgets/gesture_details.dart';
export 'src/widgets/gesture_detector.dart';
export 'src/widgets/grid.dart' hide gridCellCss;
export 'src/widgets/hero.dart';
export 'src/widgets/html_widget.dart';
export 'src/widgets/icon.dart' hide IconSizeGiven;
export 'src/widgets/icons.dart';
export 'src/widgets/iframe.dart';
export 'src/widgets/image.dart';
export 'src/widgets/implicit_animations.dart';
export 'src/widgets/interaction.dart';
export 'src/widgets/material.dart';
export 'src/widgets/native_draggable.dart';
export 'src/widgets/navigation.dart' hide closeOnNavigateHandler;
export 'src/widgets/navigation_bar.dart';
export 'src/widgets/navigation_rail.dart';
export 'src/widgets/page_view.dart';
export 'src/widgets/pagination.dart';
export 'src/widgets/ratio_text.dart';
export 'src/widgets/reorderable.dart';
export 'src/widgets/rich_text.dart';
export 'src/widgets/scaffold.dart';
export 'src/widgets/scroll.dart';
export 'src/widgets/selection_controls.dart';
export 'src/widgets/shortcuts.dart' hide controllerIdOf;
export 'src/widgets/skeleton.dart';
export 'src/widgets/slivers.dart' hide sliverItems;
export 'src/widgets/split_pane.dart';
export 'src/widgets/stack.dart';
export 'src/widgets/tab_bar.dart';
export 'src/widgets/table.dart'
    hide
        TableCellSpec,
        TableRowSpec,
        TableSection,
        paintedBorder,
        paintedDecorationCss,
        paintedEdge,
        tableElement;
export 'src/widgets/text.dart' hide withoutTextDefaults;
export 'src/widgets/text_field.dart'
    hide
        autofillToken,
        counterHandler,
        decoratedFieldId,
        decoratedTextField,
        fieldInForm,
        inputDecorator,
        themedDecoration;
export 'src/widgets/theme.dart';
export 'src/widgets/tombstones.dart' hide Tombstone;
export 'src/widgets/transitions.dart';

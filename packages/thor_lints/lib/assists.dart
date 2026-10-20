/// The editor assists for thor widgets as a library (Wrap with …, Remove
/// this widget, Swap with child / parent, Move widget up / down), for a
/// tool that edits thor code and wants the same rules as the analyzer
/// plugin.
///
/// Two layers. The pure edit functions ([wrapEdits], [wrapFlexEdits],
/// [wrapWatchEdits], [removeWidgetEdits], [swapWithChildEdits],
/// [swapWithParentEdits], [moveWidgetEdits]) take the source text and a
/// caret offset and return `List<SourceEdit>` (apply with
/// `SourceEdit.applySequence`); they parse the text themselves, with no
/// analyzer session. The producers below are built on the same functions,
/// so an editor and the analyzer plugin write the same code. Without types,
/// any capitalised call is taken for a widget (the producers also check
/// that it is one).
///
/// What is here: the pieces that decide, with no plugin context —
/// [isThorWidgetType], [thorWidgetAt] (the widget under a caret),
/// [namedArgument] and [Wrapper.all] (the widgets "Wrap with" offers, with
/// their arguments) — and the assist classes themselves ([WrapWith],
/// [WrapWithFlex], [WrapWithWatch], [RemoveWidget], [SwapWithChild],
/// [SwapWithParent], [MoveWidget]) for a host that runs analyzer correction
/// producers (`analysis_server_plugin`'s `CorrectionProducerContext`).
///
/// Using them needs `package:analysis_server_plugin`, which this package
/// already depends on. A tool without a producer context checks its own
/// operations against these (same widgets, same wrappers) instead of
/// copying the rules.
library;

export 'src/widget_assists.dart'
    show
        MoveWidget,
        RemoveWidget,
        SwapWithChild,
        SwapWithParent,
        WrapWith,
        WrapWithFlex,
        WrapWithWatch,
        WrapWithWidget,
        isThorWidgetType,
        namedArgument,
        thorUiLibrary,
        thorWidgetAt;
export 'src/widget_edits.dart'
    show
        EditStyle,
        Wrapper,
        moveWidgetEdits,
        removeWidgetEdits,
        swapWithChildEdits,
        swapWithParentEdits,
        watchSourceToken,
        wrapEdits,
        wrapFlexEdits,
        wrapWatchEdits;

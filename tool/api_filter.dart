// What the public reference leaves out. The reference (docs/api, the pages
// of the docs site) is for whoever builds an app with Thor: what an app
// imports and writes. A name can be exported by a facade only because
// generated code, the engine or a package of the repo needs it; it stays in
// the recorded API snapshot (kept stable by the deprecation policy) but gets no page.
//
// Used by `gen_api_docs.dart`; `test/api_filter_test.dart` fails if one of
// these names reaches the generated reference.

/// Topics whose declarations are for authors of Thor itself, not for apps.
const internalTopics = {'autores'};

/// Where a name an app does need goes, when its file belongs to an internal
/// topic.
const movedNames = {'ThorApp': 'widgets'};

/// Names an app never writes: protocol constants, helpers called by
/// generated code, the render and style plumbing and engine internals.
const internalNames = <String>{
  // Render core and development inspector.
  'ConstMemo', 'ConstMemoMode', 'InheritedMemoKey', 'MultipleRoots',
  'InspectSourceOwner', 'ThorInspect', 'inspectSourceAttribute',
  'visibleForTesting',
  // CSS and DOM helpers of the widgets.
  'boxCss', 'buttonResetCss', 'composeTransforms', 'flexCss', 'listResetCss',
  'padInto', 'scrollRestorationScript', 'expandRules', 'autocompleteRoot',
  'noPrefetchAttribute', 'ImageManifestScope', 'ImagePreload',
  'cssDuration', 'cssTransition', 'implicitAnimation', 'mergeCss',
  'sampledCss',
  // Adaptive and compound style keys.
  'SortedByKey', 'CssDeclarationsX', 'adaptiveBreakpoints', 'adaptiveStates',
  'compareCompoundKeys', 'compoundKey', 'compoundOf', 'containerKeyOf',
  'containerKeyPrefix', 'containerWidthOf', 'cssBox', 'cssInline', 'cssNum',
  'cssPx', 'cssSafeValue', 'cssUrl', 'groupHoverKeyPrefix',
  'groupHoverNameOf', 'isAdaptive', 'isCssPropertyName', 'isStateKey',
  'isWidthKey', 'markAdaptive', 'mergeAdaptive', 'resolveAdaptive',
  'splitAdaptive', 'thorResetStyles',
  // The state protocol: what the generated registry and the browser use.
  'RowProbeLog', 'RowTextBinding', 'registerRowProbes', 'ThorMember',
  'ThorStateType', 'WithArg', 'WithBothArgs', 'WithFirstArg',
  'WithFirstOfThreeArgs', 'WithThreeArgs', 'splitArgs', 'resolvedValue',
  'defaultHeadBudget', 'ServerCommandBase',
  // Page actions, server calls and the render pipeline.
  'PageActionMethod',
  'PageActionWithArg', 'PageActionWithArgs2', 'PageActionWithArgs3',
  'PagePost', 'PageValidPost', 'registerPageActions', 'ServerCallIds',
  'ServerCommands', 'ServerQueries', 'commandHeader', 'queryHeader',
  'askQueryKey', 'askField', 'confirmedField', 'runQueryFor',
  'queryWithoutAction', 'formActionUrl', 'persistedStateCookiePrefix',
  'RendererAsset', 'RendererAssets', 'rendererAssetsDir',
  'RequestScopedRenderer', 'RouteTableNode', 'RouteNode', 'RouteEntry',
  'thorHttpTransportKey', 'runWithThorHttpTransport', 'chainMiddleware',
  'namedMiddleware', 'middlewareName', 'fileForPath', 'routeLayout',
  'routePage', 'flashCookie', 'flashLifetime', 'flashMaxLength',
  'imageManifestPath', 'currentImageManifest', 'loadImageManifest',
};

/// Annotations that take a member or a declaration out of the reference.
const internalAnnotations = ['@internal', '@visibleForTesting'];

/// [text] without internal decision ids (`ADR-` and a number): they never
/// reach the reference.
String scrubDoc(String text) => text
    .replaceAll(RegExp(r'\s*\((?:see )?ADR-\d+\)'), '')
    .replaceAll(RegExp(r',\s*ADR-\d+\)'), ')')
    .replaceAll(RegExp(r'\s*\(ADR-\d+,\s*'), ' (')
    .replaceAll(RegExp(r'\s*ADR-\d+\b'), '');

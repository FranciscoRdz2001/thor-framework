{{flutter_js}}
{{flutter_build_config}}
// thor: multi-view bootstrap for thor_ui's FlutterView (written by `thor build`
// when missing; keep this marker line). URLs resolve from this script, not
// from the page, so the build can live under any path (/flutter/).
(() => {
  const script = document.currentScript;
  const base = new URL('.', script.src).href;
  const config = { entrypointBaseUrl: base, assetBase: base };
  if (_flutter.buildConfig.useLocalCanvasKit) {
    config.canvasKitBaseUrl = base + 'canvaskit/';
  }
  _flutter.loader.load({
    config,
    nonce: script.nonce || undefined,
    onEntrypointLoaded: async (initializer) => {
      const engine = await initializer.initializeEngine({
        ...config,
        multiViewEnabled: true,
      });
      const app = await engine.runApp();
      // The page's FlutterView loader adds the views; opened on its own
      // (`flutter run`), the app draws one view in <body>.
      if (typeof window.thorFlutter === 'function') window.thorFlutter(app);
      else app.addView({ hostElement: document.body });
    },
  });
})();

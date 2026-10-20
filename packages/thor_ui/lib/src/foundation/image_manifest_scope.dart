import 'package:thor_server/image_manifest.dart';

import '../core/core.dart';

/// The build's image manifest for the widgets below:
/// `Image.asset` reads its name here for `srcset`, `sizes` and the
/// intrinsic `width`/`height`. `runApp` (a static app) and `WidgetRenderer`
/// (a server app) put it above every page; without one, an image renders
/// what the app wrote.
class ImageManifestScope extends InheritedWidget implements InheritedMemoKey {
  /// Gives [manifest] to [child].
  const ImageManifestScope({
    super.key,
    required this.manifest,
    required super.child,
  });

  /// The images the build knows.
  final ImageManifest manifest;

  /// The manifest above [context], or `null`.
  static ImageManifest? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ImageManifestScope>()
      ?.manifest;

  @override
  bool updateShouldNotify(ImageManifestScope oldWidget) =>
      oldWidget.manifest != manifest;

  /// Readers see only this value.
  @override
  Object? get memoKey => manifest;
}

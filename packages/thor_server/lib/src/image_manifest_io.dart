import 'dart:convert';
import 'dart:io';

import '../image_manifest.dart';
import 'dev.dart';

/// Where a build leaves the manifest of a server app, relative to the app.
const imageManifestPath = 'build/images.json';

ImageManifest? _current;

/// The manifest pages render with: [loadImageManifest] on first use. Under
/// `thor dev` it is read again after every hot reload: `thor dev`
/// re-measures `web/images/` when an image changes and reloads, so a new
/// image gets its size and `srcset` without a restart.
ImageManifest currentImageManifest() {
  final known = _current;
  if (known != null) return known;
  if (ThorDev.enabled) ThorDev.onReassemble(_forgetImageManifest);
  return _current = loadImageManifest();
}

void _forgetImageManifest() => _current = null;

/// The manifest the build (or `thor dev`) wrote for this process: the file
/// named by `THOR_IMAGES`, else [imageManifestPath] under the working
/// directory when it exists, else [ImageManifest.empty]. A file that
/// exists but doesn't parse throws: a page must not quietly lose its sizes.
ImageManifest loadImageManifest({String? path}) {
  final named = path ?? Platform.environment['THOR_IMAGES'];
  final file = File(named ?? imageManifestPath);
  if (!file.existsSync()) {
    if (named != null && named.isNotEmpty) {
      throw FileSystemException('THOR_IMAGES names no file', file.path);
    }
    return ImageManifest.empty;
  }
  try {
    return ImageManifest.fromJson(jsonDecode(file.readAsStringSync()));
  } on FormatException catch (e) {
    throw FormatException('${file.path}: ${e.message}');
  }
}

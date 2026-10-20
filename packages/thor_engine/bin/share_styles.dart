// dart run thor_engine:share_styles build/site
//
// The site's shared stylesheets, then short class names on every page (the
// pages that load the shared sheet got theirs with it).
import 'dart:io';

import 'package:thor_engine/optimize.dart';
import 'package:thor_engine/shared_styles.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run thor_engine:share_styles <site dir>');
    exitCode = 64;
    return;
  }
  final site = Directory(args.single).absolute;
  final r = shareSiteStyles(site.path);
  stdout.writeln(
    r.base == null
        ? '${args.single}: ${r.pages} pages, nothing shared'
        : '${args.single}: ${r.sharing} of ${r.pages} pages load '
              '${r.base} (${r.baseBytes} bytes: theme'
              '${r.sharedAppStyles ? ' and app stylesheet' : ''})'
              '${r.sheet == null ? '' : ' and ${r.sheet} (${r.sheetBytes} '
                        'bytes: ${r.sharedClasses} classes)'}',
  );
  for (final f in site.listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.html') || r.named.contains(f.path)) continue;
    // thor_ui already rendered the variants as patches.
    final report = optimizeHtml(f.readAsStringSync(), patchVariants: false);
    f.writeAsStringSync(report.html);
  }
}

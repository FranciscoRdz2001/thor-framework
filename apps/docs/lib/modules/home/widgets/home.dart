/// The home page: a hero with one live example beside it, the three ways in,
/// a compact index of the guide and the reference. No sidebar: the index is
/// the map.
library;

import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../shell/docs_scaffold.dart';
import 'home_hero.dart';
import 'home_sections.dart';

/// The home's content width.
const homeWidth = 1280.0;

/// The home page.
class Home extends StatelessWidget {
  /// The home page.
  const Home({super.key});

  @override
  Widget build(BuildContext context) => const DocsScaffold(
    path: '/',
    sidebar: false,
    maxContentWidth: homeWidth,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeHero(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: StudioSpacing.section,
          children: [HomeStart(), HomeGuide(), HomeReference()],
        ),
      ],
    ),
  );
}

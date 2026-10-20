import 'package:thor_ui/thor_ui.dart';

import 'sections/closing.dart';
import 'sections/features.dart';
import 'sections/hero.dart';
import 'sections/navbar.dart';
import 'sections/people.dart';

/// The whole landing page, section by section.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  // Below the first screen every section skips layout and paint until it
  // nears the viewport (estimates: their desktop heights).
  static const _below = [
    (Sponsors(), 212.0),
    (Benefits(), 784.0),
    (Features(), 940.0),
    (Services(), 672.0),
    (HowItWorks(), 1460.0),
    (Testimonials(), 680.0),
    (Team(), 1300.0),
    (Community(), 600.0),
    (Pricing(), 900.0),
    (Contact(), 790.0),
    (Faq(), 690.0),
    (Footer(), 500.0),
  ];

  @override
  Widget build(BuildContext context) => Widget.fragment([
    const Navbar(),
    const HeroSection(),
    for (final (section, height) in _below)
      LazyLayout(extentEstimate: height, child: section),
  ]);
}

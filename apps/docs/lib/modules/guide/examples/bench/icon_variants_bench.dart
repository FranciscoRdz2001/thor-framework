/// `:::bench bench-icons`: the four variants of Material icons. A Switch picks
/// the variant, a Level the size; the same six names change shape.
///
/// Both are finite, so each combination is a set of icons the server drew;
/// the page carries only the ones it draws.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';

/// The size steps: 16, 24, 32, 40 and 48 px.
const _sizeSteps = 5;

/// The variants of an icon name.
enum IconVariant {
  /// `Icons.home`.
  filled,

  /// `Icons.home_outlined`.
  outlined,

  /// `Icons.home_rounded`.
  rounded,

  /// `Icons.home_sharp`.
  sharp;

  /// The suffix the Code view shows.
  String get suffix => switch (this) {
    IconVariant.filled => '',
    IconVariant.outlined => '_outlined',
    IconVariant.rounded => '_rounded',
    IconVariant.sharp => '_sharp',
  };
}

/// The six icons of [variant]. A function of its own: the enum is read by
/// the state, which runs in the browser, and Flutter's icons stay on the
/// server.
List<IconData> iconsOf(IconVariant variant) => switch (variant) {
  IconVariant.filled => const [
    Icons.home,
    Icons.delete,
    Icons.lock,
    Icons.settings,
    Icons.notifications,
    Icons.person,
  ],
  IconVariant.outlined => const [
    Icons.home_outlined,
    Icons.delete_outlined,
    Icons.lock_outlined,
    Icons.settings_outlined,
    Icons.notifications_outlined,
    Icons.person_outlined,
  ],
  IconVariant.rounded => const [
    Icons.home_rounded,
    Icons.delete_rounded,
    Icons.lock_rounded,
    Icons.settings_rounded,
    Icons.notifications_rounded,
    Icons.person_rounded,
  ],
  IconVariant.sharp => const [
    Icons.home_sharp,
    Icons.delete_sharp,
    Icons.lock_sharp,
    Icons.settings_sharp,
    Icons.notifications_sharp,
    Icons.person_sharp,
  ],
};

/// What the panel controls and the stage reads.
class IconVariantsViewModel extends ThorState {
  /// The variant.
  final variant = state(IconVariant.filled);

  /// The size, as a step.
  final step = state(1);

  /// The size in px.
  int px() => 16 + step.value * 8;

  /// The number next to the size Level's bar.
  String sizeText() => '${px()} px';

  /// The `Icon` line of the Code view.
  String iconCode() =>
      'Icon(Icons.home${variant.value.suffix}, size: ${px()}),';

  /// What the variant Switch calls.
  void setVariant(Set<IconVariant> value) => variant.value = value.first;

  /// What the size Level calls.
  void setSize(double value) => step.value = ((value - 16) / 8).round();
}

/// One instance, at the top level: the browser boots with it.
final iconVariants = IconVariantsViewModel();

/// The example: a Switch, a Level, the stage and its code.
final iconVariantsBench = BenchExample(
  title: (t) => t.exIconsTitle,
  description: (t) => t.exIconsDescription,
  stage: const IconVariantsStage(),
  code: BenchCode([BenchCodeLine.live(iconVariants.iconCode)]),
  controls: [
    BenchSwitch<IconVariant>(
      label: (t) => t.exIconsVariant,
      value: iconVariants.variant.value,
      onChanged: iconVariants.setVariant,
      segments: [
        BenchSegment(IconVariant.filled, label: (t) => t.exIconsFilled),
        BenchSegment(IconVariant.outlined, label: (t) => t.exIconsOutlined),
        BenchSegment(IconVariant.rounded, label: (t) => t.exIconsRounded),
        BenchSegment(IconVariant.sharp, label: (t) => t.exIconsSharp),
      ],
    ),
    BenchLevel(
      label: (t) => t.exIconsSize,
      value: 16 + iconVariants.step.value * 8,
      min: 16,
      max: 16.0 + (_sizeSteps - 1) * 8,
      divisions: _sizeSteps - 1,
      onChanged: iconVariants.setSize,
      valueText: iconVariants.sizeText,
    ),
  ],
);

/// The stage: the six icons.
class IconVariantsStage extends StatelessWidget {
  /// The stage of the example.
  const IconVariantsStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    iconVariants.variant,
    builder: (variant) => Watch.field(
      iconVariants.step,
      count: _sizeSteps,
      builder: (step) => SizedBox(
        width: 280,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 20,
          children: [
            for (final icon in iconsOf(variant))
              Icon(icon, size: 16.0 + step * 8, color: ThemeColor.onSurface),
          ],
        ),
      ),
    ),
  );
}

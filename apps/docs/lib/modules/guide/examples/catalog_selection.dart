/// The component catalog: selection controls
/// (`docs/guia/es/componentes-seleccion.md`). Every example is a bench: a
/// stage, a panel with Switches and Levels, and a Code view that follows
/// them. The ids (`cat-checkbox`…) are the ones the widget pages of the API
/// reference reuse.
library;

import 'package:thor_ui/thor_ui.dart';

import '../../../core/i18n/docs_locale.dart';
import 'bench/bench_example.dart';
import 'bench/bench_kit.dart';
import 'bench/bench_kit_preview.dart';

// -------------------------------------------------------------------- Checkbox

/// The three values of a tristate checkbox.
enum CheckValue {
  /// `false`.
  off,

  /// `true`.
  on,

  /// `null`.
  mixed,
}

/// What the Checkbox panel controls.
class CheckboxBenchViewModel extends ThorState {
  /// The checkbox's value.
  final value = state(CheckValue.off);

  /// Whether `onChanged` is set.
  final enabled = state(true);

  /// The `value` line of the Code view.
  String valueCode() => switch (value.value) {
    CheckValue.off => 'value: false,',
    CheckValue.on => 'value: true,',
    CheckValue.mixed => 'value: null,',
  };

  /// The `onChanged` line.
  String changedCode() =>
      enabled.value ? 'onChanged: terms.setAccepted,' : 'onChanged: null,';

  /// What the checkbox calls (`null` is the mixed state).
  void setAccepted(bool? next) => value.value = switch (next) {
    true => CheckValue.on,
    false => CheckValue.off,
    null => CheckValue.mixed,
  };

  /// What the value Switch calls.
  void setValue(Set<CheckValue> next) => value.value = next.first;

  /// What the enabled Switch calls.
  void setEnabled(bool next) => enabled.value = next;
}

/// One instance, at the top level: the browser boots with it.
final terms = CheckboxBenchViewModel();

/// `cat-checkbox`.
final checkboxBench = BenchExample(
  title: (t) => t.exSelCheckboxTitle,
  description: (t) => t.exSelCheckboxDescription,
  stage: const _CheckboxStage(),
  code: BenchCode([
    const BenchCodeLine('Checkbox('),
    BenchCodeLine.live(terms.valueCode, indent: 1),
    const BenchCodeLine('tristate: true,', indent: 1),
    const BenchCodeLine("semanticLabel: 'I accept the terms',", indent: 1),
    BenchCodeLine.live(terms.changedCode, indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    BenchSwitch<CheckValue>(
      label: (t) => t.exSelValue,
      value: terms.value.value,
      onChanged: terms.setValue,
      segments: [
        BenchSegment(CheckValue.off, label: (t) => t.exSelOff),
        BenchSegment(CheckValue.on, label: (t) => t.exCatYes),
        BenchSegment(CheckValue.mixed, label: (t) => t.exSelMixed),
      ],
    ),
    enabledSwitch(value: terms.enabled.value, onChanged: terms.setEnabled),
  ],
);

class _CheckboxStage extends StatelessWidget {
  const _CheckboxStage();

  @override
  Widget build(BuildContext context) {
    return Watch.field(
      terms.value,
      builder: (value) => Watch.field(
        terms.enabled,
        builder: (enabled) => Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Checkbox(
              value: switch (value) {
                CheckValue.off => false,
                CheckValue.on => true,
                CheckValue.mixed => null,
              },
              tristate: true,
              semanticLabel: 'I accept the terms',
              onChanged: enabled ? terms.setAccepted : null,
            ),
            const Text('I accept the terms'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------- Switch

/// What the Switch panel controls.
class SwitchBenchViewModel extends ThorState {
  /// On or off.
  final on = state(true);

  /// Whether `onChanged` is set.
  final enabled = state(true);

  /// The `value` line.
  String valueCode() => 'value: ${on.value},';

  /// The `onChanged` line.
  String changedCode() =>
      enabled.value ? 'onChanged: wifiSetting.setOn,' : 'onChanged: null,';

  /// What the switch calls.
  void setOn(bool next) => on.value = next;

  /// What the value Switch calls.
  void setValue(bool next) => on.value = next;

  /// What the enabled Switch calls.
  void setEnabled(bool next) => enabled.value = next;
}

/// One instance, at the top level.
final wifiSetting = SwitchBenchViewModel();

/// `cat-switch`.
final switchBench = BenchExample(
  title: (t) => t.exSelSwitchTitle,
  description: (t) => t.exSelSwitchDescription,
  stage: const _SwitchStage(),
  code: BenchCode([
    const BenchCodeLine('Switch('),
    BenchCodeLine.live(wifiSetting.valueCode, indent: 1),
    const BenchCodeLine("semanticLabel: 'Wi-Fi',", indent: 1),
    BenchCodeLine.live(wifiSetting.changedCode, indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    boolSwitch(
      label: (t) => t.exSelOn,
      value: wifiSetting.on.value,
      onChanged: wifiSetting.setValue,
    ),
    enabledSwitch(
      value: wifiSetting.enabled.value,
      onChanged: wifiSetting.setEnabled,
    ),
  ],
);

class _SwitchStage extends StatelessWidget {
  const _SwitchStage();

  @override
  Widget build(BuildContext context) {
    return Watch.field(
      wifiSetting.on,
      builder: (on) => Watch.field(
        wifiSetting.enabled,
        builder: (enabled) => Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Switch(
              value: on,
              semanticLabel: 'Wi-Fi',
              onChanged: enabled ? wifiSetting.setOn : null,
            ),
            const Text('Wi-Fi'),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------- Radio

/// The payment methods of the radio group.
enum PayMethod {
  /// Card.
  card,

  /// Cash.
  cash,

  /// Bank transfer.
  transfer,
}

/// What the RadioGroup panel controls.
class RadioBenchViewModel extends ThorState {
  /// The chosen method.
  final method = state(PayMethod.card);

  /// Whether the group's `onChanged` is set.
  final enabled = state(true);

  /// The `groupValue` line.
  String valueCode() => 'groupValue: PayMethod.${method.value.name},';

  /// The `onChanged` line.
  String changedCode() =>
      enabled.value ? 'onChanged: payment.setMethod,' : 'onChanged: null,';

  /// What the group calls.
  void setMethod(PayMethod? next) => method.value = next ?? PayMethod.card;

  /// What the Switch calls: its `onSelectionChanged` takes a set.
  void chooseMethod(Set<PayMethod> next) => method.value = next.first;

  /// What the enabled Switch calls.
  void setEnabled(bool next) => enabled.value = next;
}

/// One instance, at the top level.
final payment = RadioBenchViewModel();

/// `cat-radio`.
final radioBench = BenchExample(
  title: (t) => t.exSelRadioTitle,
  description: (t) => t.exSelRadioDescription,
  stage: const _RadioStage(),
  code: BenchCode([
    const BenchCodeLine('RadioGroup<PayMethod>('),
    BenchCodeLine.live(payment.valueCode, indent: 1),
    const BenchCodeLine("name: 'payment',", indent: 1),
    BenchCodeLine.live(payment.changedCode, indent: 1),
    const BenchCodeLine('child: Column(children: [', indent: 1),
    const BenchCodeLine('Radio<PayMethod>(value: PayMethod.card),', indent: 2),
    const BenchCodeLine('Radio<PayMethod>(value: PayMethod.cash),', indent: 2),
    const BenchCodeLine('…', indent: 2),
    const BenchCodeLine(']),', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<PayMethod>(
      label: (t) => t.exSelChosen,
      value: payment.method.value,
      onChanged: payment.chooseMethod,
      segments: [
        BenchSegment(PayMethod.card, label: (t) => t.exSelCard),
        BenchSegment(PayMethod.cash, label: (t) => t.exSelCash),
        BenchSegment(PayMethod.transfer, label: (t) => t.exSelTransfer),
      ],
    ),
    enabledSwitch(value: payment.enabled.value, onChanged: payment.setEnabled),
  ],
);

class _RadioStage extends StatelessWidget {
  const _RadioStage();

  @override
  Widget build(BuildContext context) {
    const names = {
      PayMethod.card: 'Card',
      PayMethod.cash: 'Cash',
      PayMethod.transfer: 'Bank transfer',
    };
    return Watch.field(
      payment.method,
      builder: (method) => Watch.field(
        payment.enabled,
        builder: (enabled) => RadioGroup<PayMethod>(
          groupValue: method,
          // The radios share one native group (arrow keys, no JS).
          name: 'payment',
          onChanged: enabled ? payment.setMethod : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              for (final entry in names.entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    Radio<PayMethod>(
                      value: entry.key,
                      semanticLabel: entry.value,
                    ),
                    Text(entry.value),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- SegmentedButton

/// The views of the segmented button.
enum BrowseView {
  /// Rows.
  list,

  /// Tiles.
  grid,
}

/// What the SegmentedButton panel controls.
class SegmentedBenchViewModel extends ThorState {
  /// The chosen view.
  final view = state(BrowseView.list);

  /// Whether `onSelectionChanged` is set.
  final enabled = state(true);

  /// The `selected` line.
  String selectedCode() => 'selected: {BrowseView.${view.value.name}},';

  /// The `onSelectionChanged` line.
  String changedCode() => enabled.value
      ? 'onSelectionChanged: browse.setView,'
      : 'onSelectionChanged: null,';

  /// What the segmented button calls: the set the person picked.
  void setView(Set<BrowseView> next) {
    if (next.isNotEmpty) view.value = next.first;
  }

  /// What the enabled Switch calls.
  void setEnabled(bool next) => enabled.value = next;
}

/// One instance, at the top level.
final browse = SegmentedBenchViewModel();

/// `cat-segmented-button`.
final segmentedButtonBench = BenchExample(
  title: (t) => t.exSelSegmentedTitle,
  description: (t) => t.exSelSegmentedDescription,
  stage: const _SegmentedStage(),
  code: BenchCode([
    const BenchCodeLine('SegmentedButton<BrowseView>('),
    const BenchCodeLine('segments: const [', indent: 1),
    const BenchCodeLine(
      "ButtonSegment(value: BrowseView.list, label: Text('List')),",
      indent: 2,
    ),
    const BenchCodeLine(
      "ButtonSegment(value: BrowseView.grid, label: Text('Grid')),",
      indent: 2,
    ),
    const BenchCodeLine('],', indent: 1),
    BenchCodeLine.live(browse.selectedCode, indent: 1),
    BenchCodeLine.live(browse.changedCode, indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    enabledSwitch(value: browse.enabled.value, onChanged: browse.setEnabled),
  ],
);

class _SegmentedStage extends StatelessWidget {
  const _SegmentedStage();

  @override
  Widget build(BuildContext context) {
    return Watch.field(
      browse.view,
      builder: (view) => Watch.field(
        browse.enabled,
        builder: (enabled) => SegmentedButton<BrowseView>(
          segments: const [
            ButtonSegment(value: BrowseView.list, label: Text('List')),
            ButtonSegment(value: BrowseView.grid, label: Text('Grid')),
          ],
          selected: {view},
          semanticLabel: 'View',
          onSelectionChanged: enabled ? browse.setView : null,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ ChoiceChip

/// What the ChoiceChip panel controls.
class ChoiceChipBenchViewModel extends ThorState {
  /// The chosen size (0 small, 1 medium, 2 large).
  final size = state(1);

  /// Whether `onSelected` is set.
  final enabled = state(true);

  /// Whether chip [index] is the chosen one.
  bool isSize(int index) => size.value == index;

  /// The field the chips read, with the size that is chosen.
  String sizeCode() =>
      'final size = state(${size.value}); // ${const ['small', 'medium', 'large'][size.value]}';

  /// The `onSelected` line.
  String changedCode() => enabled.value
      ? 'onSelected: cupSize.pick.withArg(i),'
      : 'onSelected: null,';

  /// What a chip calls.
  void pick(int index, bool selected) {
    if (selected) size.value = index;
  }

  /// What the chosen Switch calls.
  void setSize(Set<int> index) => size.value = index.first;

  /// What the enabled Switch calls.
  void setEnabled(bool next) => enabled.value = next;
}

/// One instance, at the top level.
final cupSize = ChoiceChipBenchViewModel();

/// `cat-choice-chip`.
final choiceChipBench = BenchExample(
  title: (t) => t.exSelChoiceTitle,
  description: (t) => t.exSelChoiceDescription,
  stage: const _ChoiceChipStage(),
  code: BenchCode([
    BenchCodeLine.live(cupSize.sizeCode),
    const BenchCodeLine('Watch('),
    const BenchCodeLine('cupSize.isSize.withArg(i),', indent: 1),
    const BenchCodeLine('builder: (on) => ChoiceChip(', indent: 1),
    const BenchCodeLine('label: Text(sizes[i]),', indent: 2),
    const BenchCodeLine('selected: on,', indent: 2),
    BenchCodeLine.live(cupSize.changedCode, indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    BenchSwitch<int>(
      label: (t) => t.exSelChosen,
      value: cupSize.size.value,
      onChanged: cupSize.setSize,
      segments: [
        BenchSegment(0, label: (t) => t.exCatSmall),
        BenchSegment(1, label: (t) => t.exCatMedium),
        BenchSegment(2, label: (t) => t.exCatLarge),
      ],
    ),
    enabledSwitch(value: cupSize.enabled.value, onChanged: cupSize.setEnabled),
  ],
);

class _ChoiceChipStage extends StatelessWidget {
  const _ChoiceChipStage();

  @override
  Widget build(BuildContext context) {
    const sizes = ['Small', 'Medium', 'Large'];
    return Column(
      spacing: 16,
      children: [
        Watch.field(
          cupSize.enabled,
          builder: (enabled) => Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < sizes.length; i++)
                Watch(
                  cupSize.isSize.withArg(i),
                  builder: (on) => ChoiceChip(
                    label: Text(sizes[i]),
                    selected: on,
                    onSelected: enabled ? cupSize.pick.withArg(i) : null,
                  ),
                ),
            ],
          ),
        ),
        // The selected chip's fill is subtle on a dark stage: the value the
        // state holds is written out.
        Watch.field(
          cupSize.size,
          count: 3,
          builder: (size) => NoteRow(label: 'Chosen', value: Text(sizes[size])),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------- InputChip

/// What the InputChip panel controls.
class InputChipBenchViewModel extends ThorState {
  /// How many chips were put on the stage (1 to 4).
  final count = state(3);

  /// The chips still shown (indexes).
  final shown = state(<int>[0, 1, 2]);

  /// Whether the chips have an `onDeleted`.
  final deletable = state(true);

  /// Whether `isEnabled` is true.
  final enabled = state(true);

  /// Whether chip [index] is shown.
  bool isShown(int index) => shown.value.contains(index);

  /// The number next to the count Level.
  String countText() => '${count.value}';

  /// The field the chips read: the ones still on the stage.
  String shownCode() => 'final shown = state(<int>${shown.value});';

  /// The `onDeleted` line.
  String deletedCode() => deletable.value
      ? 'onDeleted: tags.remove.withArg(i),'
      : '// no onDeleted: a plain label';

  /// The `isEnabled` line.
  String enabledCode() => 'isEnabled: ${enabled.value},';

  /// What the chip's cross calls.
  void remove(int index) => shown.value = [
    for (final i in shown.value)
      if (i != index) i,
  ];

  /// What the count Level calls: puts that many chips back.
  void setCount(double next) {
    count.value = next.round();
    shown.value = [for (var i = 0; i < count.value; i++) i];
  }

  /// What the delete Switch calls.
  void setDeletable(bool next) => deletable.value = next;

  /// What the enabled Switch calls.
  void setEnabled(bool next) => enabled.value = next;
}

/// One instance, at the top level.
final tags = InputChipBenchViewModel();

/// `cat-input-chip`.
final inputChipBench = BenchExample(
  title: (t) => t.exSelInputTitle,
  description: (t) => t.exSelInputDescription,
  stage: const _InputChipStage(),
  code: BenchCode([
    BenchCodeLine.live(tags.shownCode),
    const BenchCodeLine('InputChip('),
    const BenchCodeLine('label: Text(names[i]),', indent: 1),
    BenchCodeLine.live(tags.deletedCode, indent: 1),
    BenchCodeLine.live(tags.enabledCode, indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    boolSwitch(
      label: (t) => t.exSelDeletable,
      value: tags.deletable.value,
      onChanged: tags.setDeletable,
    ),
    enabledSwitch(value: tags.enabled.value, onChanged: tags.setEnabled),
    BenchLevel(
      label: (t) => t.exSelChips,
      value: tags.count.value,
      min: 1,
      max: 4,
      divisions: 3,
      onChanged: tags.setCount,
      valueText: tags.countText,
    ),
  ],
);

class _InputChipStage extends StatelessWidget {
  const _InputChipStage();

  @override
  Widget build(BuildContext context) {
    const names = ['Vegan', 'Gluten-free', 'Organic', 'Local'];
    return Watch.field(
      tags.deletable,
      builder: (deletable) => Watch.field(
        tags.enabled,
        builder: (enabled) => Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < names.length; i++)
              Watch(
                tags.isShown.withArg(i),
                builder: (on) => on
                    ? InputChip(
                        label: Text(names[i]),
                        isEnabled: enabled,
                        onDeleted: deletable ? tags.remove.withArg(i) : null,
                        deleteButtonTooltipMessage: 'Remove',
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Link chips

/// What the link chips panel controls.
class LinkChipBenchViewModel extends ThorState {
  /// Whether the filter chip is selected.
  final selected = state(true);

  /// Whether the filter chip shows its checkmark.
  final checkmark = state(true);

  /// Whether the input chip's cross is a link (`deleteHref`).
  final deleteLink = state(true);

  /// The `selected` line.
  String selectedCode() => 'selected: ${selected.value},';

  /// The `showCheckmark` line.
  String checkmarkCode() => 'showCheckmark: ${checkmark.value},';

  /// The `deleteHref` line of the input chip.
  String deleteCode() =>
      deleteLink.value ? "deleteHref: '/wines'," : '// no deleteHref';

  /// What the selected Switch calls.
  void setSelected(bool next) => selected.value = next;

  /// What the checkmark Switch calls.
  void setCheckmark(bool next) => checkmark.value = next;

  /// What the delete Switch calls.
  void setDeleteLink(bool next) => deleteLink.value = next;
}

/// One instance, at the top level.
final linkChips = LinkChipBenchViewModel();

/// `cat-link-chip`.
final linkChipBench = BenchExample(
  title: (t) => t.exSelLinkTitle,
  description: (t) => t.exSelLinkDescription,
  stage: const _LinkChipStage(),
  code: BenchCode([
    const BenchCodeLine('FilterChip('),
    const BenchCodeLine("label: Text('Red'),", indent: 1),
    BenchCodeLine.live(linkChips.selectedCode, indent: 1),
    BenchCodeLine.live(linkChips.checkmarkCode, indent: 1),
    const BenchCodeLine("href: '/wines?type=red',", indent: 1),
    const BenchCodeLine(')'),
    const BenchCodeLine('InputChip('),
    const BenchCodeLine("label: Text('Under 200'),", indent: 1),
    const BenchCodeLine("href: '/wines?max=200',", indent: 1),
    BenchCodeLine.live(linkChips.deleteCode, indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    boolSwitch(
      label: (t) => t.exSelSelected,
      value: linkChips.selected.value,
      onChanged: linkChips.setSelected,
    ),
    boolSwitch(
      label: (t) => t.exSelCheckmark,
      value: linkChips.checkmark.value,
      onChanged: linkChips.setCheckmark,
    ),
    boolSwitch(
      label: (t) => t.exSelDeleteLink,
      value: linkChips.deleteLink.value,
      onChanged: linkChips.setDeleteLink,
    ),
  ],
);

class _LinkChipStage extends StatelessWidget {
  const _LinkChipStage();

  @override
  Widget build(BuildContext context) {
    // `// web:` href and deleteHref do not exist in Flutter; they make the
    // chip an <a> that works without JavaScript.
    final href = context.localized('/componentes/componentes-seleccion');
    return Watch.field(
      linkChips.selected,
      builder: (selected) => Watch.field(
        linkChips.checkmark,
        builder: (checkmark) => Watch.field(
          linkChips.deleteLink,
          builder: (deleteLink) => Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilterChip(
                label: const Text('Red'),
                selected: selected,
                onSelected: null,
                href: href,
                showCheckmark: checkmark,
              ),
              InputChip(
                label: const Text('Under 200'),
                href: href,
                deleteHref: deleteLink ? href : null,
                deleteButtonTooltipMessage: 'Remove',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ FilterChip

/// What the FilterChip panel controls.
class FilterChipBenchViewModel extends ThorState {
  /// The chosen toppings (indexes).
  final picked = state(<int>[0]);

  /// Whether a chosen chip shows its checkmark.
  final checkmark = state(true);

  /// Whether `onSelected` is set.
  final enabled = state(true);

  /// Whether topping [index] is chosen.
  bool isPicked(int index) => picked.value.contains(index);

  /// How many are chosen, as the text next to the label.
  String countText() => '${picked.value.length}';

  /// The `showCheckmark` line.
  String checkmarkCode() => 'showCheckmark: ${checkmark.value},';

  /// The `onSelected` line.
  String changedCode() => enabled.value
      ? 'onSelected: toppings.toggle.withArg(i),'
      : 'onSelected: null,';

  /// What a chip calls.
  void toggle(int index, bool selected) => picked.value = [
    for (final i in picked.value)
      if (i != index) i,
    if (selected) index,
  ];

  /// What the checkmark Switch calls.
  void setCheckmark(bool next) => checkmark.value = next;

  /// What the enabled Switch calls.
  void setEnabled(bool next) => enabled.value = next;
}

/// One instance, at the top level.
final toppings = FilterChipBenchViewModel();

/// `cat-filter-chip`.
final filterChipBench = BenchExample(
  title: (t) => t.exSelFilterTitle,
  description: (t) => t.exSelFilterDescription,
  stage: const _FilterChipStage(),
  code: BenchCode([
    const BenchCodeLine('Watch('),
    const BenchCodeLine('toppings.isPicked.withArg(i),', indent: 1),
    const BenchCodeLine('builder: (on) => FilterChip(', indent: 1),
    const BenchCodeLine('label: Text(extras[i]),', indent: 2),
    const BenchCodeLine('selected: on,', indent: 2),
    BenchCodeLine.live(toppings.checkmarkCode, indent: 2),
    BenchCodeLine.live(toppings.changedCode, indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    boolSwitch(
      label: (t) => t.exSelCheckmark,
      value: toppings.checkmark.value,
      onChanged: toppings.setCheckmark,
    ),
    enabledSwitch(
      value: toppings.enabled.value,
      onChanged: toppings.setEnabled,
    ),
  ],
);

class _FilterChipStage extends StatelessWidget {
  const _FilterChipStage();

  @override
  Widget build(BuildContext context) {
    const extras = ['Cinnamon', 'Cream', 'Caramel', 'Oat milk'];
    return Column(
      spacing: 12,
      children: [
        Watch.field(
          toppings.checkmark,
          builder: (checkmark) => Watch.field(
            toppings.enabled,
            builder: (enabled) => Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < extras.length; i++)
                  Watch(
                    toppings.isPicked.withArg(i),
                    builder: (on) => FilterChip(
                      label: Text(extras[i]),
                      selected: on,
                      showCheckmark: checkmark,
                      onSelected: enabled ? toppings.toggle.withArg(i) : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            const Text(
              'Extras',
              style: TextStyle(
                fontSize: 13,
                color: ThemeColor.onSurfaceVariant,
              ),
            ),
            Watch(
              toppings.countText,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ List tiles

/// Which tile the list tiles bench shows.
enum TileKind {
  /// `CheckboxListTile`.
  checkbox,

  /// `SwitchListTile`.
  switchTile,

  /// `RadioListTile`.
  radio,
}

/// Where the tile's control goes.
enum TileSide {
  /// `ListTileControlAffinity.leading`.
  leading,

  /// `ListTileControlAffinity.trailing`.
  trailing,
}

/// The countries of the radio tiles.
enum Country {
  /// Mexico.
  mx,

  /// Colombia.
  co,
}

/// What the list tiles panel controls.
class ListTilesBenchViewModel extends ThorState {
  /// The tile.
  final kind = state(TileKind.checkbox);

  /// Whether the tile has a `subtitle`.
  final subtitle = state(true);

  /// Where the control goes.
  final side = state(TileSide.leading);

  /// Whether `onChanged` is set.
  final enabled = state(true);

  /// The last value the tile reported.
  final last = state(false);

  /// The constructor line.
  String headCode() => switch (kind.value) {
    TileKind.checkbox => 'CheckboxListTile(',
    TileKind.switchTile => 'SwitchListTile(',
    TileKind.radio => 'RadioListTile<Country>(',
  };

  /// The `value` line: the tile's own for a checkbox or a switch, the
  /// radio's for a radio tile.
  String valueCode() => switch (kind.value) {
    TileKind.checkbox => 'value: true,',
    TileKind.switchTile => 'value: false,',
    TileKind.radio => 'value: Country.mx,',
  };

  /// The `title` line.
  String titleCode() => switch (kind.value) {
    TileKind.checkbox => "title: Text('Remember me'),",
    TileKind.switchTile => "title: Text('Airplane mode'),",
    TileKind.radio => "title: Text('Mexico'),",
  };

  /// The `subtitle` line.
  String subtitleCode() =>
      subtitle.value ? "subtitle: Text('On this device')," : '// no subtitle';

  /// The `controlAffinity` line.
  String sideCode() =>
      'controlAffinity: ListTileControlAffinity.${side.value.name},';

  /// The `onChanged` line.
  String changedCode() => kind.value == TileKind.radio
      ? (enabled.value
            ? '// RadioGroup(onChanged: settings.setCountry)'
            : '// RadioGroup(onChanged: null)')
      : (enabled.value ? 'onChanged: settings.toggle,' : 'onChanged: null,');

  /// What a checkbox or switch tile calls.
  void toggle(bool? next) => last.value = next ?? false;

  /// What the radio group calls.
  void setCountry(Country? next) => last.value = next == Country.co;

  /// What the tile Switch calls.
  void setKind(Set<TileKind> next) => kind.value = next.first;

  /// What the subtitle Switch calls.
  void setSubtitle(bool next) => subtitle.value = next;

  /// What the side Switch calls.
  void setSide(Set<TileSide> next) => side.value = next.first;

  /// What the enabled Switch calls.
  void setEnabled(bool next) => enabled.value = next;
}

/// One instance, at the top level.
final settings = ListTilesBenchViewModel();

/// `cat-list-tiles`.
final listTilesBench = BenchExample(
  title: (t) => t.exSelTilesTitle,
  description: (t) => t.exSelTilesDescription,
  stage: const _ListTilesStage(),
  code: BenchCode([
    BenchCodeLine.live(settings.headCode),
    BenchCodeLine.live(settings.valueCode, indent: 1),
    BenchCodeLine.live(settings.titleCode, indent: 1),
    BenchCodeLine.live(settings.subtitleCode, indent: 1),
    BenchCodeLine.live(settings.sideCode, indent: 1),
    BenchCodeLine.live(settings.changedCode, indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    BenchSwitch<TileKind>(
      label: (t) => t.exSelTile,
      value: settings.kind.value,
      onChanged: settings.setKind,
      segments: [
        BenchSegment(TileKind.checkbox, label: (t) => t.exSelTileCheckbox),
        BenchSegment(TileKind.switchTile, label: (t) => t.exSelTileSwitch),
        BenchSegment(TileKind.radio, label: (t) => t.exSelTileRadio),
      ],
    ),
    BenchSwitch<TileSide>(
      label: (t) => t.exSelControl,
      value: settings.side.value,
      onChanged: settings.setSide,
      segments: [
        BenchSegment(TileSide.leading, label: (t) => t.exSelLeading),
        BenchSegment(TileSide.trailing, label: (t) => t.exSelTrailing),
      ],
    ),
    boolSwitch(
      label: (t) => t.exSelSubtitle,
      value: settings.subtitle.value,
      onChanged: settings.setSubtitle,
    ),
    enabledSwitch(
      value: settings.enabled.value,
      onChanged: settings.setEnabled,
    ),
  ],
);

class _ListTilesStage extends StatelessWidget {
  const _ListTilesStage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Watch.field(
        settings.kind,
        builder: (kind) => Watch.field(
          settings.subtitle,
          builder: (subtitle) => Watch.field(
            settings.side,
            builder: (side) => Watch.field(
              settings.enabled,
              builder: (enabled) {
                final affinity = side == TileSide.leading
                    ? ListTileControlAffinity.leading
                    : ListTileControlAffinity.trailing;
                final sub = subtitle ? const Text('On this device') : null;
                return switch (kind) {
                  TileKind.checkbox => CheckboxListTile(
                    value: true,
                    title: const Text('Remember me'),
                    subtitle: sub,
                    controlAffinity: affinity,
                    onChanged: enabled ? settings.toggle : null,
                  ),
                  TileKind.switchTile => SwitchListTile(
                    value: false,
                    title: const Text('Airplane mode'),
                    subtitle: sub,
                    controlAffinity: affinity,
                    onChanged: enabled ? settings.toggle : null,
                  ),
                  TileKind.radio => RadioGroup<Country>(
                    groupValue: Country.mx,
                    name: 'country',
                    onChanged: enabled ? settings.setCountry : null,
                    child: Column(
                      children: [
                        RadioListTile<Country>(
                          value: Country.mx,
                          title: const Text('Mexico'),
                          subtitle: sub,
                          controlAffinity: affinity,
                        ),
                        RadioListTile<Country>(
                          value: Country.co,
                          title: const Text('Colombia'),
                          subtitle: sub,
                          controlAffinity: affinity,
                        ),
                      ],
                    ),
                  ),
                };
              },
            ),
          ),
        ),
      ),
    );
  }
}

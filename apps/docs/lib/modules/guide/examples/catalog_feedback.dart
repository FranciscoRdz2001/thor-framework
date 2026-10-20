// ignore_for_file: public_member_api_docs
// (each example is named by its region or its bench; a doc comment would sit
// outside the code the site shows)
// The component catalog: dialogs, snackbars, progress and menus
// (docs/guia/es/componentes-avisos.md). The `cat-*` examples are benches: a
// stage, a panel with Switches and Levels, and a Code view that follows
// them.
import 'dart:async';

import 'package:thor_ui/thor_ui.dart';

import 'bench/bench_example.dart';
import 'bench/bench_kit.dart';
import 'bench/bench_kit_preview.dart';
import 'catalog_shared.dart';

// ----------------------------------------------------------------- AlertDialog

/// What the AlertDialog panel controls.
class AlertDialogViewModel extends ThorState {
  /// `barrierDismissible`.
  final dismissible = state(true);

  /// Whether the dialog has a `content`.
  final withContent = state(true);

  /// Whether it has two actions (else one).
  final twoActions = state(true);

  /// The `content` line of the Code view.
  String contentCode() => withContent.value
      ? "content: Text('You will lose what you wrote.'),"
      : 'content: null,';

  /// The second action's line: a comment when there is one action.
  String secondActionCode() => twoActions.value
      ? "DialogClose(child: FilledButton(child: Text('Discard'))),"
      : '// one action';

  /// The `barrierDismissible` line.
  String barrierCode() => 'barrierDismissible: ${dismissible.value},';

  /// What the barrier Switch calls.
  void setDismissible(bool value) => dismissible.value = value;

  /// What the content Switch calls.
  void setContent(bool value) => withContent.value = value;

  /// What the actions Switch calls.
  void setActions(bool value) => twoActions.value = value;
}

/// One instance, at the top level.
final alertDialog = AlertDialogViewModel();

/// `cat-alert-dialog`.
final alertDialogBench = BenchExample(
  title: (t) => t.exFbAlertTitle,
  description: (t) => t.exFbAlertDescription,
  stage: const _AlertDialogStage(),
  code: BenchCode([
    const BenchCodeLine('DialogTrigger('),
    const BenchCodeLine('dialog: AlertDialog(', indent: 1),
    const BenchCodeLine("title: Text('Discard draft?'),", indent: 2),
    BenchCodeLine.live(alertDialog.contentCode, indent: 2),
    const BenchCodeLine('actions: [', indent: 2),
    const BenchCodeLine(
      "DialogClose(child: TextButton(child: Text('Keep'))),",
      indent: 3,
    ),
    BenchCodeLine.live(alertDialog.secondActionCode, indent: 3),
    const BenchCodeLine('],', indent: 2),
    BenchCodeLine.live(alertDialog.barrierCode, indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine(
      "child: OutlinedButton(child: Text('Discard draft')),",
      indent: 1,
    ),
    const BenchCodeLine(')'),
  ]),
  controls: [
    boolSwitch(
      label: (t) => t.exFbBarrier,
      value: alertDialog.dismissible.value,
      onChanged: alertDialog.setDismissible,
    ),
    boolSwitch(
      label: (t) => t.exFbContent,
      value: alertDialog.withContent.value,
      onChanged: alertDialog.setContent,
    ),
    boolSwitch(
      label: (t) => t.exFbTwoActions,
      value: alertDialog.twoActions.value,
      onChanged: alertDialog.setActions,
    ),
  ],
);

class _AlertDialogStage extends StatelessWidget {
  const _AlertDialogStage();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 12,
      children: [
        Watch.field(
          alertDialog.dismissible,
          builder: (dismissible) => Watch.field(
            alertDialog.withContent,
            builder: (withContent) => Watch.field(
              alertDialog.twoActions,
              builder: (two) => Column(
                spacing: 12,
                children: [
                  DialogTrigger(
                    dialog: AlertDialog(
                      // web: the variants swap the dialog's content, not the
                      // dialog: one id for all of them, named by its buttons
                      // too (a reader's app, without variants, needs neither).
                      id: 'cat-discard',
                      barrierDismissible: dismissible,
                      title: const Text('Discard draft?'),
                      content: withContent
                          ? const Text('You will lose what you wrote.')
                          : null,
                      actions: [
                        const DialogClose(
                          id: 'cat-discard',
                          child: TextButton(child: Text('Keep')),
                        ),
                        if (two)
                          const DialogClose(
                            id: 'cat-discard',
                            child: FilledButton(child: Text('Discard')),
                          ),
                      ],
                    ),
                    child: const OutlinedButton(child: Text('Discard draft')),
                  ),
                  // The dialog is closed until the button opens it: this is
                  // the same dialog drawn open, over its backdrop.
                  PreviewFrame(
                    scrim: true,
                    child: ModalSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 12,
                        children: [
                          const Text(
                            'Discard draft?',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (withContent)
                            const Text(
                              'You will lose what you wrote.',
                              style: TextStyle(
                                color: ThemeColor.onSurfaceVariant,
                              ),
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: demo.notice,
                                child: const Text('Keep'),
                              ),
                              if (two)
                                FilledButton(
                                  onPressed: demo.notice,
                                  child: const Text('Discard'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    dismissible
                        ? 'Tapping outside the dialog closes it'
                        : 'Tapping outside the dialog does not close it',
                    style: const TextStyle(
                      fontSize: 13,
                      color: ThemeColor.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ DialogController

/// What the DialogController panel controls.
class ContactsViewModel extends ThorState {
  /// How many contacts there are.
  final count = state(3);

  /// Whether deleting also closes the dialog.
  final closeAfter = state(true);

  /// The controller of the dialog.
  final confirm = DialogController();

  /// The number on the stage.
  String countText() => '${count.value}';

  /// The `count` field of the Code view.
  String countCode() => 'final count = state(${count.value});';

  /// The `delete` body of the Code view.
  String closeCode() => closeAfter.value ? 'confirm.close();' : '// stays open';

  /// What the "delete one" button calls.
  void askDelete() => confirm.open();

  /// What the dialog's confirm button calls.
  void delete() {
    if (count.value > 0) count.value--;
    if (closeAfter.value) confirm.close();
  }

  /// What the count Level calls.
  void setCount(double value) => count.value = value.round();

  /// What the close Switch calls.
  void setCloseAfter(bool value) => closeAfter.value = value;
}

/// One instance, at the top level.
final contacts = ContactsViewModel();

/// `cat-dialog-controller`.
final dialogControllerBench = BenchExample(
  title: (t) => t.exFbControllerTitle,
  description: (t) => t.exFbControllerDescription,
  stage: const _DialogControllerStage(),
  code: BenchCode([
    const BenchCodeLine('class ContactsViewModel extends ThorState {'),
    BenchCodeLine.live(contacts.countCode, indent: 1),
    const BenchCodeLine('final confirm = DialogController();', indent: 1),
    const BenchCodeLine(' '),
    const BenchCodeLine('void askDelete() => confirm.open();', indent: 1),
    const BenchCodeLine('void delete() {', indent: 1),
    const BenchCodeLine('if (count.value > 0) count.value--;', indent: 2),
    BenchCodeLine.live(contacts.closeCode, indent: 2),
    const BenchCodeLine('}', indent: 1),
    const BenchCodeLine('}'),
  ]),
  controls: [
    boolSwitch(
      label: (t) => t.exFbCloseAfter,
      value: contacts.closeAfter.value,
      onChanged: contacts.setCloseAfter,
    ),
    BenchLevel(
      label: (t) => t.exFbContacts,
      value: contacts.count.value,
      max: 9,
      divisions: 9,
      onChanged: contacts.setCount,
      valueText: contacts.countText,
    ),
  ],
);

class _DialogControllerStage extends StatelessWidget {
  const _DialogControllerStage();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 12,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            const Text(
              'Contacts',
              style: TextStyle(
                fontSize: 13,
                color: ThemeColor.onSurfaceVariant,
              ),
            ),
            Watch(
              contacts.countText,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        Watch.field(
          contacts.closeAfter,
          builder: (closes) => NoteRow(
            label: 'After deleting',
            value: Text(closes ? 'closes' : 'stays open'),
          ),
        ),
        FilledButton(
          onPressed: contacts.askDelete,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [Icon(Icons.delete, size: 18), Text('Delete one')],
          ),
        ),
        Dialog(
          label: 'Delete contact',
          controller: contacts.confirm,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                const Text(
                  'Delete a contact?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  spacing: 8,
                  children: [
                    const DialogClose(child: TextButton(child: Text('Cancel'))),
                    FilledButton(
                      onPressed: contacts.delete,
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- SnackBar

/// How long the snack bar stays.
enum SnackDuration {
  /// 2 seconds.
  short,

  /// 4 seconds (Flutter's default).
  medium,

  /// 6 seconds.
  long,
}

/// What the SnackBar panel controls.
class SaveNoticeViewModel extends ThorState {
  /// Whether it is shown.
  final shown = state(false);

  /// With an `action` button.
  final withAction = state(false);

  /// Floating (a rounded bar, centered) or fixed (the full width, the default).
  final floating = state(false);

  /// How long it stays.
  final duration = state(SnackDuration.medium);

  /// The hide timer (not a field: the browser keeps it).
  Timer? hideTimer;

  /// Whether it is shown, for the stage.
  bool isShown() => shown.value;

  int _seconds() => switch (duration.value) {
    SnackDuration.short => 2,
    SnackDuration.medium => 4,
    SnackDuration.long => 6,
  };

  /// The `duration` line of the Code view.
  String durationCode() => 'duration: Duration(seconds: ${_seconds()}),';

  /// The `behavior` line.
  String behaviorCode() => floating.value
      ? 'behavior: SnackBarBehavior.floating,'
      : 'behavior: SnackBarBehavior.fixed, // default';

  /// The `action` line.
  String actionCode() => withAction.value
      ? "action: TextButton(onPressed: saveNotice.undo, child: Text('Undo')),"
      : 'action: null,';

  /// What the "save" button calls.
  void save() {
    shown.value = true;
    // To show it again it goes back through visible: false.
    hideTimer?.cancel();
    hideTimer = Timer(Duration(seconds: _seconds()), () => shown.value = false);
  }

  /// What the action button calls: the bar goes away.
  void undo() {
    hideTimer?.cancel();
    shown.value = false;
  }

  /// What the floating Switch calls.
  void setFloating(bool value) => floating.value = value;

  /// What the action Switch calls.
  void setAction(bool value) => withAction.value = value;

  /// What the duration Switch calls.
  void setDuration(Set<SnackDuration> value) => duration.value = value.first;
}

/// One instance, at the top level.
final saveNotice = SaveNoticeViewModel();

/// `cat-snackbar`.
final snackBarBench = BenchExample(
  title: (t) => t.exFbSnackTitle,
  description: (t) => t.exFbSnackDescription,
  stage: const _SnackBarStage(),
  code: BenchCode([
    const BenchCodeLine('Watch('),
    const BenchCodeLine('saveNotice.isShown,', indent: 1),
    const BenchCodeLine('builder: (shown) => SnackBar(', indent: 1),
    const BenchCodeLine('visible: shown,', indent: 2),
    BenchCodeLine.live(saveNotice.behaviorCode, indent: 2),
    BenchCodeLine.live(saveNotice.durationCode, indent: 2),
    BenchCodeLine.live(saveNotice.actionCode, indent: 2),
    const BenchCodeLine("content: Text('Changes saved'),", indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    boolSwitch(
      label: (t) => t.exFbFloating,
      value: saveNotice.floating.value,
      onChanged: saveNotice.setFloating,
    ),
    boolSwitch(
      label: (t) => t.exFbAction,
      value: saveNotice.withAction.value,
      onChanged: saveNotice.setAction,
    ),
    BenchSwitch<SnackDuration>(
      label: (t) => t.exFbDuration,
      value: saveNotice.duration.value,
      onChanged: saveNotice.setDuration,
      segments: [
        BenchSegment(SnackDuration.short, label: (t) => t.exFbDur2),
        BenchSegment(SnackDuration.medium, label: (t) => t.exFbDur4),
        BenchSegment(SnackDuration.long, label: (t) => t.exFbDur6),
      ],
    ),
  ],
);

class _SnackBarStage extends StatelessWidget {
  const _SnackBarStage();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 16,
      children: [
        FilledButton(onPressed: saveNotice.save, child: const Text('Save')),
        Watch.field(
          saveNotice.withAction,
          builder: (withAction) => Watch.field(
            saveNotice.floating,
            builder: (floating) => Watch.field(
              saveNotice.duration,
              builder: (duration) {
                final seconds = switch (duration) {
                  SnackDuration.short => 2,
                  SnackDuration.medium => 4,
                  SnackDuration.long => 6,
                };
                return Column(
                  spacing: 12,
                  children: [
                    // The real bar shows at the bottom of the window when the
                    // button is pressed; the preview draws it in place.
                    PreviewFrame(
                      child: Align(
                        alignment: floating
                            ? Alignment.center
                            : Alignment.centerLeft,
                        child: Container(
                          width: floating ? null : double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: ThemeColor.inverseSurface,
                            borderRadius: BorderRadius.circular(
                              floating ? 4 : 0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: floating
                                ? MainAxisSize.min
                                : MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            spacing: 12,
                            children: [
                              const Text(
                                'Changes saved',
                                style: TextStyle(
                                  color: ThemeColor.onInverseSurface,
                                ),
                              ),
                              if (withAction)
                                const Text(
                                  'Undo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: ThemeColor.inversePrimary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    NoteRow(label: 'Hides after', value: Text('$seconds s')),
                    Watch(
                      saveNotice.isShown,
                      builder: (shown) => SnackBar(
                        visible: shown,
                        duration: Duration(seconds: seconds),
                        behavior: floating
                            ? SnackBarBehavior.floating
                            : SnackBarBehavior.fixed,
                        content: const Text('Changes saved'),
                        action: withAction
                            ? TextButton(
                                onPressed: saveNotice.undo,
                                child: const Text('Undo'),
                              )
                            : null,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- Progress

/// The shape of the progress indicator.
enum ProgressShape {
  /// `LinearProgressIndicator`.
  linear,

  /// `CircularProgressIndicator`.
  circular,
}

/// What the progress panel controls.
class UploadViewModel extends ThorState {
  /// The shape.
  final shape = state(ProgressShape.linear);

  /// Whether it has a `value` (else it spins without end).
  final determinate = state(true);

  /// The value, in tenths (0 to 10).
  final step = state(4);

  /// The percentage on the stage and next to the Level's bar.
  String percentText() => '${step.value * 10}%';

  /// The constructor line of the Code view.
  String headCode() => shape.value == ProgressShape.linear
      ? 'LinearProgressIndicator('
      : 'CircularProgressIndicator(';

  /// The `value` line.
  String valueCode() =>
      determinate.value ? 'value: ${step.value / 10},' : 'value: null,';

  /// What the shape Switch calls.
  void setShape(Set<ProgressShape> value) => shape.value = value.first;

  /// What the determinate Switch calls.
  void setDeterminate(bool value) => determinate.value = value;

  /// What the value Level calls.
  void setStep(double value) => step.value = (value / 10).round();
}

/// One instance, at the top level.
final upload = UploadViewModel();

/// `cat-progress`.
final progressBench = BenchExample(
  title: (t) => t.exFbProgressTitle,
  description: (t) => t.exFbProgressDescription,
  stage: const _ProgressStage(),
  code: BenchCode([
    BenchCodeLine.live(upload.headCode),
    BenchCodeLine.live(upload.valueCode, indent: 1),
    const BenchCodeLine("semanticsLabel: 'Upload',", indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    BenchSwitch<ProgressShape>(
      label: (t) => t.exFbShape,
      value: upload.shape.value,
      onChanged: upload.setShape,
      segments: [
        BenchSegment(ProgressShape.linear, label: (t) => t.exFbLinear),
        BenchSegment(ProgressShape.circular, label: (t) => t.exFbCircular),
      ],
    ),
    boolSwitch(
      label: (t) => t.exFbDeterminate,
      value: upload.determinate.value,
      onChanged: upload.setDeterminate,
    ),
    BenchLevel(
      label: (t) => t.exFbValue,
      value: upload.step.value * 10,
      max: 100,
      divisions: 10,
      onChanged: upload.setStep,
      valueText: upload.percentText,
    ),
  ],
);

class _ProgressStage extends StatelessWidget {
  const _ProgressStage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Watch.field(
            upload.shape,
            builder: (shape) => Watch.field(
              upload.determinate,
              builder: (determinate) => Watch.field(
                upload.step,
                count: 11,
                builder: (i) {
                  final double? value = determinate ? i / 10 : null;
                  // `// web:` an indeterminate indicator turns forever: it
                  // gets a box of its own so the page doesn't read its
                  // turning corners as an overflow.
                  return shape == ProgressShape.linear
                      ? LinearProgressIndicator(
                          value: value,
                          semanticsLabel: 'Upload',
                        )
                      : Center(
                          child: CircularProgressIndicator(
                            value: value,
                            size: 40,
                            semanticsLabel: 'Upload',
                          ),
                        );
                },
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Upload',
                style: TextStyle(
                  fontSize: 13,
                  color: ThemeColor.onSurfaceVariant,
                ),
              ),
              Watch(
                upload.percentText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- PopupMenuButton

/// What the PopupMenuButton panel controls.
class SortOrderViewModel extends ThorState {
  /// The option the menu last returned.
  final order = state('recent');

  /// Whether the menu marks the current option (`initialValue`).
  final markCurrent = state(true);

  /// Whether the last option can be chosen.
  final lastEnabled = state(true);

  /// The option on the stage.
  String chosen() => order.value;

  /// The `initialValue` line of the Code view.
  String initialCode() =>
      markCurrent.value ? "initialValue: 'recent'," : 'initialValue: null,';

  /// The last item's line.
  String lastCode() => lastEnabled.value
      ? "PopupMenuItem(value: 'name', child: Text('By name')),"
      : "PopupMenuItem(value: 'name', enabled: false, child: …),";

  /// What the menu calls.
  void setOrder(String value) => order.value = value;

  /// What the mark Switch calls.
  void setMarkCurrent(bool value) => markCurrent.value = value;

  /// What the last-item Switch calls.
  void setLastEnabled(bool value) => lastEnabled.value = value;
}

/// One instance, at the top level.
final sortOrder = SortOrderViewModel();

/// `cat-popup-menu`.
final popupMenuBench = BenchExample(
  title: (t) => t.exFbPopupTitle,
  description: (t) => t.exFbPopupDescription,
  stage: const _PopupMenuStage(),
  code: BenchCode([
    const BenchCodeLine('PopupMenuButton('),
    const BenchCodeLine("tooltip: 'Sort',", indent: 1),
    const BenchCodeLine('onSelected: sortOrder.setOrder,', indent: 1),
    BenchCodeLine.live(sortOrder.initialCode, indent: 1),
    const BenchCodeLine('items: [', indent: 1),
    const BenchCodeLine(
      "PopupMenuItem(value: 'recent', child: Text('Most recent')),",
      indent: 2,
    ),
    const BenchCodeLine(
      "PopupMenuItem(value: 'price', child: Text('By price')),",
      indent: 2,
    ),
    BenchCodeLine.live(sortOrder.lastCode, indent: 2),
    const BenchCodeLine('],', indent: 1),
    const BenchCodeLine('child: Icon(Icons.more_vert),', indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    boolSwitch(
      label: (t) => t.exFbMarkCurrent,
      value: sortOrder.markCurrent.value,
      onChanged: sortOrder.setMarkCurrent,
    ),
    boolSwitch(
      label: (t) => t.exFbLastEnabled,
      value: sortOrder.lastEnabled.value,
      onChanged: sortOrder.setLastEnabled,
    ),
  ],
);

class _PopupMenuStage extends StatelessWidget {
  const _PopupMenuStage();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 12,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            const Text(
              'Chosen',
              style: TextStyle(
                fontSize: 13,
                color: ThemeColor.onSurfaceVariant,
              ),
            ),
            Watch(
              sortOrder.chosen,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        Watch.field(
          sortOrder.markCurrent,
          builder: (mark) => Watch.field(
            sortOrder.lastEnabled,
            builder: (lastEnabled) => Column(
              spacing: 12,
              children: [
                PopupMenuButton(
                  tooltip: 'Sort',
                  onSelected: sortOrder.setOrder,
                  initialValue: mark ? 'recent' : null,
                  items: [
                    const PopupMenuItem(
                      value: 'recent',
                      child: Text('Most recent'),
                    ),
                    const PopupMenuItem(
                      value: 'price',
                      child: Text('By price'),
                    ),
                    PopupMenuItem(
                      value: 'name',
                      enabled: lastEnabled,
                      child: const Text('By name'),
                    ),
                  ],
                  child: const Icon(Icons.more_vert),
                ),
                // The menu is closed until the button opens it: this is the
                // same menu drawn open.
                PreviewFrame(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (value, label, enabled) in [
                        ('recent', 'Most recent', true),
                        ('price', 'By price', true),
                        ('name', 'By name', lastEnabled),
                      ])
                        Opacity(
                          opacity: enabled ? 1 : 0.38,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: mark && value == 'recent'
                                  ? ThemeColor.secondaryContainer
                                  : null,
                            ),
                            child: Text(label),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

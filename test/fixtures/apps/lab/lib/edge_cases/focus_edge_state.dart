import 'package:thor_ui/thor_ui.dart';

class EdgeRow {
  const EdgeRow(this.id, this.n);
  final int id;
  final int n;
}

/// State of the adversarial focus-swap scenarios (focus-edge check): every
/// scenario has a counter whose parity (or value) picks the `Watch` variant.
class FocusEdgeState extends ThorState {
  final resetMode = state(0);
  final vanish = state(0);
  final insert = state(0);
  final types = state(0);
  final fast = state(0);
  final chk = state(false);
  final fc = state(0);
  final nestOuter = state(0);
  final nestInner = state(0);
  final sp = state(0);
  final rows = state<List<EdgeRow>>(const [EdgeRow(1, 0), EdgeRow(2, 0)]);

  int resetV() => resetMode.value;
  int vanishV() => vanish.value;
  int insertV() => insert.value;
  int typesV() => types.value % 2;
  int fastV() => fast.value % 2;
  int fcV() => (chk.value ? 1 : 0) + (fc.value % 2) * 2;
  int outerV() => nestOuter.value % 2;
  int innerV() => nestInner.value % 2;
  int spV() => sp.value % 2;

  String idOf(EdgeRow r) => '${r.id}';
  int nOf(EdgeRow r) => r.n % 2;

  void onReset(String v) {
    if (v.endsWith('!')) resetMode.value = 1;
  }

  void clearReset() => resetMode.value = 0;
  void goVanish(String _) => vanish.value = 1;
  void goInsert(String _) => insert.value = 1;
  void bumpTypes(String _) => types.value++;
  void bumpFast(String _) => fast.value++;
  void toggleChk(bool? _) {
    chk.value = !chk.value;
    fc.value++;
  }

  void pressBtn() => fc.value++;
  void bumpNest(String _) {
    nestOuter.value++;
    nestInner.value++;
  }

  void bumpSp(String _) => sp.value++;

  void bumpRow(String key, String _) {
    rows.value = [
      for (final r in rows.value)
        if ('${r.id}' == key) EdgeRow(r.id, r.n + 1) else r,
    ];
  }
}

final focusEdge = FocusEdgeState();

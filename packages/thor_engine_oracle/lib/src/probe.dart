/// What the engine keeps for the subtrees it binds after the first scan, for
/// tests (a leak shows as a count that grows with every swap). Filled in
/// debug builds only: release builds drop the assert that fills it, and the
/// class with it.
library;

/// The counters of every live `hydrate` call.
final class EngineProbe {
  EngineProbe._();

  /// One entry per attached `hydrate`: how much it retains.
  static final List<EngineRetained Function()> sources = [];

  /// The sum over every attached `hydrate`.
  static EngineRetained total() {
    var texts = 0, instances = 0, lists = 0, disposers = 0;
    for (final s in sources) {
      final r = s();
      texts += r.texts;
      instances += r.instances;
      lists += r.lists;
      disposers += r.disposers;
    }
    return EngineRetained(texts, instances, lists, disposers);
  }
}

/// What one `hydrate` retains.
final class EngineRetained {
  /// The counts.
  const EngineRetained(this.texts, this.instances, this.lists, this.disposers);

  /// Text nodes bound after the first scan (a row's or a variant copy's).
  final int texts;

  /// Variant elements (`_Instance`) in all groups.
  final int instances;

  /// List containers in all groups.
  final int lists;

  /// Undo functions held for the page's life.
  final int disposers;

  @override
  String toString() =>
      'texts=$texts instances=$instances lists=$lists disposers=$disposers';
}

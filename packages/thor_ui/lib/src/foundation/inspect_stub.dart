/// No source lookups: the browser and AOT builds.
library;

/// Whether the inspector is on without a test setting it.
bool enabledByDefault() => false;

/// `file:line:column` of what builds [owner] (see `ThorInspect.sourceOf`).
String? sourceOf(Object owner) => null;

/// Forgets the looked-up sources (nothing to forget here).
void clearSources() {}

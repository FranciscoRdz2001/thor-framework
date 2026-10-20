# Written by tool/thor setup (THOR_SETUP_SHIM=0 keeps pub's script).
# ROOT (above) is the checkout. The snapshot is trusted only while its stamp
# (the Dart that built it, and its size) matches and no source is newer.
SNAP="$ROOT/.dart_tool/thor/thor.jit"
STAMP="$SNAP.stamp"
if ! command -v dart >/dev/null 2>&1; then
  echo "thor: dart is not on PATH" >&2
  exit 127
fi
if [ ! -f "$ROOT/packages/thor_cli/bin/thor.dart" ]; then
  echo "thor: the checkout $ROOT is gone or moved; run tool/thor setup in its new place" >&2
  exit 1
fi
stamp() { printf '%s\n%s\n' "$(dart --version 2>&1)" "$(wc -c <"${1:-$SNAP}" 2>/dev/null | tr -d ' ')"; }
# Atomic: build aside, then rename, so a concurrent run never sees a torn file.
build() {
  tmp="$SNAP.tmp.$$"
  mkdir -p "$ROOT/.dart_tool/thor" 2>/dev/null || return 1
  echo "thor: rebuilding the CLI snapshot…" >&2
  if (cd "$ROOT" && dart compile jit-snapshot -o "$tmp" packages/thor_cli/bin/thor.dart help >/dev/null 2>&1) \
    && [ -s "$tmp" ] && stamp "$tmp" >"$STAMP.tmp.$$" 2>/dev/null \
    && mv -f "$tmp" "$SNAP" 2>/dev/null && mv -f "$STAMP.tmp.$$" "$STAMP" 2>/dev/null; then
    return 0
  fi
  rm -f "$tmp" "$STAMP.tmp.$$" 2>/dev/null
  return 1
}
if [ ! -f "$SNAP" ] || [ "$(cat "$STAMP" 2>/dev/null)" != "$(stamp)" ] \
  || [ "$ROOT/pubspec.lock" -nt "$SNAP" ] \
  || [ -n "$(find "$ROOT"/packages/*/lib "$ROOT/packages/thor_cli/bin" -name '*.dart' -newer "$SNAP" -print -quit 2>/dev/null)" ]; then
  build || exec dart "$ROOT/packages/thor_cli/bin/thor.dart" "$@"
fi
exec dart "$SNAP" "$@"

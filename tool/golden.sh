#!/usr/bin/env bash
# Golden output of every app: the release HTML (its CSS is inline) of each
# page and the site's shared stylesheet, and the sha256 of every other file
# the page loads (engine JS, fonts). The yardstick of any render change: whatever
# changes inside thor, what the apps ship must stay byte-identical
# or have each difference justified.
#
#   tool/golden.sh record [--jobs N] [app...]   write test/golden/<app>/
#   tool/golden.sh check  [--jobs N] [app...]   build again and diff against it
#
# The apps go through a bounded pool (tool/pool.mjs, default half the
# cores; `--jobs 1` = one after another): each has its own build directory,
# and the servers of the server apps take free ports when they start.
#
# An intended output change (a new widget style) is recorded again, in its
# own commit.
#
# Static apps: `thor build`, plus their page in debug (`_debug.html`). docs and lab: `thor export`
# (lab, the many-pages fixture, also in debug: `_debug/<page>.html`). realworld and grid: their
# release executable against the deterministic mock API
# (test/e2e/mock_api), on a fixed list of routes. Times of day
# and "N minutes ago" are normalized.
#
# A page bigger than GOLDEN_MAX_BYTES (200 KB) is kept as its sha256 and
# size (`<page>.sha256`), not its text: a grid page is half a megabyte and
# every recording would add it to the repository again. When one changes,
# `check` renders the same app at the last commit that recorded its golden
# (in a temporary worktree) and prints the diff of the whole page.
#
# The date is fixed (`THOR_NOW`, default 2026-09-30; `GOLDEN_NOW` overrides it):
# the date pickers render the same page any day.
#
# The landing's images need cwebp: without it the build fails.
# The encoded variants are listed without their bytes' hash (they depend
# on the encoder's version; their names don't).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# The render clock pinned (`thorNow()` in thor_ui: the date picker's today and
# month): a golden must not change with the day it is recorded or checked.
# Every process the script starts (build, export, the servers) inherits it.
# Move it only with a recording of the goldens, in its own commit.
export THOR_NOW="${GOLDEN_NOW:-2026-09-30T12:00:00}"
GOLDEN="$ROOT/test/golden"
# Free ports picked when a server starts (after its build), so several apps
# can be checked at once and two worktrees can record at the same time
# without one server answering the other's requests. GOLDEN_MOCK_PORT and
# GOLDEN_SERVER_PORT pin them (then run with --jobs 1).
free_port() {
  node -e 'const s = require("net").createServer().listen(0, () => {
    console.log(s.address().port); s.close(); });'
}
pick_ports() {
  MOCK_PORT=${GOLDEN_MOCK_PORT:-$(free_port)}
  SERVER_PORT=${GOLDEN_SERVER_PORT:-$(free_port)}
  while [[ "$SERVER_PORT" == "$MOCK_PORT" ]]; do SERVER_PORT=$(free_port); done
}

MAX_BYTES=${GOLDEN_MAX_BYTES:-200000}

say() { printf '\033[1;36m▸ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

STATIC_APPS=(content_engine counter gallery_engine landing list_engine studio_gallery)
SERVER_APPS=(realworld grid)
EXPORT_APPS=(docs lab)

thor_cli() { dart run thor_cli:thor "$@"; }

# Where an app lives, by name (apps/ or test/fixtures/apps/).
app_dir() {
  local root
  for root in apps test/fixtures/apps; do
    [[ -f "$root/$1/pubspec.yaml" ]] && { echo "$root/$1"; return 0; }
  done
  return 1
}

# Processes this script starts; always stopped, even on failure.
PIDS=()
cleanup() {
  for pid in "${PIDS[@]:-}"; do
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
  done
}
BASE_TREE=""
finish() {
  cleanup
  [[ -n "${SERVER_LOG:-}" ]] && rm -f "$SERVER_LOG"
  if [[ -n "$BASE_TREE" ]]; then
    git -C "$ROOT" worktree remove --force "$BASE_TREE" >/dev/null 2>&1 || true
  fi
}
trap finish EXIT INT TERM

# Normalizes what depends on the clock, nothing else.
normalize() {
  sed -E \
    -e 's/Rendered at [0-9:]+/Rendered at HH:MM:SS/g' \
    -e 's/[0-9]+ (second|minute|hour|day|month|year)s? ago/N UNIT ago/g'
}

# A file's sha256, except the image variants the build encodes
# (images/<name>-<width>.<hash>.webp): their bytes depend on the
# machine's cwebp; their name (from the source and the parameters) doesn't.
asset_hash() {
  if [[ "$1" =~ ^\./images/.+-[0-9]+\.[0-9a-f]{8}\.webp$ ]]; then
    echo encoded
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# Copies a built site: pages as-is (normalized), other files as hashes.
snapshot_site() {
  local site="$1" out="$2"
  mkdir -p "$out"
  # Pages and the shared stylesheet (_thor/styles.<hash>.css) as text.
  (cd "$site" && find . -type f \( -name '*.html' -o -path './_thor/*.css' \) | sort) | while read -r page; do
    mkdir -p "$out/$(dirname "$page")"
    normalize <"$site/$page" >"$out/$page"
  done
  (cd "$site" && find . -type f ! -name '*.html' ! -path './_thor/*.css' | sort | while read -r f; do
    printf '%s  %s\n' "$(asset_hash "$f")" "$f"
  done) >"$out/_assets.sha256"
}

snapshot_static() {
  local app="$1" out="$2"
  thor_cli build "$(app_dir "$app")" >/dev/null
  snapshot_site "$(app_dir "$app")/build/site" "$out"
  # The same page in debug: indented HTML and the debug class names,
  # which release drops (the render core must match both).
  # Through thor's generated entry (it registers the app's states).
  (cd "$(app_dir "$app")" && THOR_RENDER_TO="$out/_debug.html.tmp" \
    dart run .dart_tool/thor/server.dart >/dev/null)
  normalize <"$out/_debug.html.tmp" >"$out/_debug.html"
  rm "$out/_debug.html.tmp"
}

snapshot_export() {
  local app="$1" out="$2"
  thor_cli export "$(app_dir "$app")" >/dev/null
  snapshot_site "$(app_dir "$app")/build/site" "$out"
  if [[ "$app" == lab ]]; then
    # The same pages in debug (indented HTML, debug class names), through
    # thor's generated export entry: the render core must match both.
    (cd "$(app_dir "$app")" && dart run .dart_tool/thor/export.dart "$out/_debug" >/dev/null)
    local page
    while read -r page; do
      normalize <"$page" >"$page.tmp" && mv "$page.tmp" "$page"
    done < <(find "$out/_debug" -name '*.html')
  fi
}

SERVER_LOG="$(mktemp)"

wait_for() {
  local url="$1"
  for _ in $(seq 1 100); do
    curl -s -o /dev/null "$url" && return 0
    sleep 0.1
  done
  tail -20 "$SERVER_LOG" >&2 || true
  fail "nothing answered at $url"
}

snapshot_server() {
  local app="$1" out="$2" routes=()
  case "$app" in
    realworld) routes=(/ '/?page=2' /tag/css
      /article/server-rendering-without-the-hydration-tax
      /profile/johndoe /login /register /nope) ;;
    grid) routes=(/ '/?f=status:isValue:Beta&s=budget:desc'
      '/?g=owner&h=notes,url&rh=tall&q=aurora' /nope) ;;
  esac
  thor_cli build "$(app_dir "$app")" >/dev/null
  pick_ports
  for port in "$MOCK_PORT" "$SERVER_PORT"; do
    if lsof -ti "tcp:$port" -sTCP:LISTEN >/dev/null; then fail "port $port is busy"; fi
  done
  node test/e2e/mock_api/server.mjs --port "$MOCK_PORT" >/dev/null 2>&1 &
  PIDS+=($!)
  wait_for "http://localhost:$MOCK_PORT/api/tags"
  (cd "$(app_dir "$app")" &&
    PORT=$SERVER_PORT ISOLATES=1 \
      REALWORLD_API="http://localhost:$MOCK_PORT/api" \
      SESSION_SECRET=golden-session-secret-of-at-least-32-bytes \
      exec build/server >"$SERVER_LOG" 2>&1) &
  PIDS+=($!)
  wait_for "http://localhost:$SERVER_PORT/"
  mkdir -p "$out"
  for route in "${routes[@]}"; do
    local file
    file=$(printf '%s' "$route" | sed -E 's#^/##; s#[/?=&:]#_#g')
    [[ -z "$file" ]] && file=index
    local status
    status=$(curl -s -o "$out/$file.tmp" -w '%{http_code}' "http://localhost:$SERVER_PORT$route")
    { printf '<!-- status %s -->\n' "$status"; normalize <"$out/$file.tmp"; } >"$out/$file.html"
    rm "$out/$file.tmp"
  done
  (cd "$(app_dir "$app")/build/public" && find . -type f | sort | while read -r f; do
    printf '%s  %s\n' "$(asset_hash "$f")" "$f"
  done) >"$out/_assets.sha256"
  cleanup
  PIDS=()
}

snapshot() {
  local app="$1" out="$2"
  rm -rf "$out"
  if [[ " ${STATIC_APPS[*]} " == *" $app "* ]]; then
    snapshot_static "$app" "$out"
  elif [[ " ${EXPORT_APPS[*]} " == *" $app "* ]]; then
    snapshot_export "$app" "$out"
  elif [[ " ${SERVER_APPS[*]} " == *" $app "* ]]; then
    snapshot_server "$app" "$out"
  else
    fail "unknown app: $app"
  fi
}

# docs: the pages the site generates by the hundred (one per widget, one per
# error code) stay in the golden as a hash, except a sample whose text is
# kept in full (a widget with a live example, a layout one, two error codes):
# 8.5 MB of generated HTML would go into git again with every recording.
# The hash still catches any change; the sample shows what one looks like.
# Each language has them under its prefix (`en/api`, `es/errores`…).
DOCS_FULL_SAMPLE=(en/api/thor_ui/controls/ElevatedButton.html
  en/api/thor_ui/layout/Row.html en/errors/THOR-B002.html
  es/api/thor_ui/controles/ElevatedButton.html es/errores/THOR-S014.html)

# Writes `<page>.sha256` ("<sha256>  <bytes>") and removes the page.
hash_page() {
  printf '%s  %s\n' "$(shasum -a 256 "$1" | cut -d' ' -f1)" \
    "$(wc -c <"$1" | tr -d ' ')" >"$1.sha256"
  rm "$1"
}

# Pages over MAX_BYTES become `<page>.sha256`; docs also hashes its
# generated pages (see DOCS_FULL_SAMPLE).
shrink() {
  local out="$1" app="${2:-}" page
  while read -r page; do hash_page "$page"; done < <(
    find "$out" -type f \( -name '*.html' -o -name '*.css' \) -size "+${MAX_BYTES}c")
  if [[ "$app" == docs ]]; then
    while read -r page; do
      [[ " ${DOCS_FULL_SAMPLE[*]} " == *" ${page#"$out"/} "* ]] || hash_page "$page"
    done < <(find "$out"/*/api -mindepth 3 -name '*.html'
      find "$out"/*/errores "$out"/*/errors -name '*.html' 2>/dev/null)
  fi
}

# The whole-page diff of every hashed page of [app] that changed: the app
# rendered again at the last commit that recorded its golden (the code
# that produced those hashes), in a temporary worktree.
full_diffs() {
  local app="$1" current="$2" hashed="$3" out="$4" base
  base=$(git -C "$ROOT" log -1 --format=%H -- "test/golden/$app")
  [[ -z "$base" ]] && base=$(git -C "$ROOT" rev-parse HEAD)
  if [[ -n "$BASE_TREE" ]]; then
    git -C "$ROOT" worktree remove --force "$BASE_TREE" >/dev/null 2>&1 || true
  fi
  BASE_TREE="$tmp/base-tree-$app"
  git -C "$ROOT" worktree add --detach -q "$BASE_TREE" "$base"
  (cd "$BASE_TREE" && dart pub get >/dev/null)
  (cd "$BASE_TREE" && snapshot "$app" "$tmp/base-$app")
  while read -r page; do
    {
      printf '\n=== %s (whole page, recorded commit vs now)\n' "$page"
      # One tag per line: a page is one long line, its diff would be all.
      diff <(sed 's/></>\
</g' "$tmp/base-$app/$page") <(sed 's/></>\
</g' "$current/$page") || true
    } >>"$out"
  done <<<"$hashed"
}

mode="${1:-}"
shift || true
jobs=""
apps=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --jobs) jobs="${2:?--jobs needs a number}"; shift ;;
    *) apps+=("$1") ;;
  esac
  shift
done
[[ ${#apps[@]} -eq 0 ]] && apps=("${STATIC_APPS[@]}" "${EXPORT_APPS[@]}" "${SERVER_APPS[@]}")

# One app: record its golden, or build it again and diff (exit 1 if it differs).
golden_one() {
  local mode="$1" app="$2"
  case "$mode" in
    record)
      snapshot "$app" "$GOLDEN/$app"
      shrink "$GOLDEN/$app" "$app"
      ;;
    check)
      snapshot "$app" "$tmp/$app.full"
      cp -R "$tmp/$app.full" "$tmp/$app"
      shrink "$tmp/$app" "$app"
      if ! diff -r "$GOLDEN/$app" "$tmp/$app" >"$tmp/$app.diff"; then
        # Hashed pages that changed: show what changed in them.
        local hashed
        hashed=$(cd "$tmp/$app" && find . -name '*.sha256' ! -name '_assets.sha256' |
          while read -r h; do
            cmp -s "$h" "$GOLDEN/$app/$h" || echo "${h%.sha256}"
          done)
        if [[ -n "$hashed" ]]; then
          full_diffs "$app" "$tmp/$app.full" "$hashed" "$tmp/$app.diff"
        fi
        printf '  differs: %s lines (%s)\n' "$(wc -l <"$tmp/$app.diff" | tr -d ' ')" "$tmp/$app.diff"
        head -c 4000 "$tmp/$app.diff"
        return 1
      fi
      ;;
  esac
}

# All the apps through the pool; the app's output comes as one block.
golden_all() {
  local mode="$1" one
  if [[ "${jobs:-}" == 1 || ${#apps[@]} -eq 1 ]]; then
    for one in "${apps[@]}"; do
      say "Golden $mode $one"
      golden_one "$mode" "$one" || changed=1
    done
    return
  fi
  command -v node >/dev/null || fail "node is needed for the pool (or use --jobs 1)"
  local list
  list="$(for one in "${apps[@]}"; do
    printf 'golden %s\t\t\ttool/golden.sh _one %s %s\n' "$one" "$mode" "$one"
  done)"
  # Every worker shares the temporary directory of the run.
  GOLDEN_TMP="$tmp" node tool/pool.mjs --title "golden $mode" ${jobs:+--jobs "$jobs"} <<<"$list" || changed=1
}

tmp="${GOLDEN_TMP:-}"
changed=0
case "$mode" in
  _one) # internal: one app in a worker of the pool
    [[ -n "$tmp" ]] || tmp=$(mktemp -d)
    golden_one "${apps[0]}" "${apps[1]}"
    ;;
  record)
    golden_all record
    [[ $changed -eq 0 ]] || fail "record failed"
    ;;
  check)
    tmp=$(mktemp -d)
    golden_all check
    if [[ $changed -eq 0 ]]; then
      say "Byte-identical"
      # The full snapshots of every app are kept only on request.
      if [[ -n "${GOLDEN_KEEP:-}" ]]; then say "Snapshots kept in $tmp"; else rm -rf "$tmp"; fi
    else
      fail "Output changed (diffs above; snapshots kept in $tmp)"
    fi
    ;;
  *) fail "usage: tool/golden.sh record|check [--jobs N] [app...]" ;;
esac

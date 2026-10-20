#!/usr/bin/env bash
# Indexes an exported docs site for its search page (/buscar): Pagefind reads
# the pages' `data-pagefind-body` and writes `pagefind/` next to them.
#
#   tool/docs_index.sh [site-dir]     (default apps/docs/build/site)
#
# Run it after every export: `tool/thor export docs` does it itself, and so
# does tool/deploy_docs.sh. A bare `thor export apps/docs` leaves the site
# without an index (the search page then finds nothing).
#
# Needs node (npx fetches the pinned pagefind; nothing is installed).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE="${1:-$ROOT/apps/docs/build/site}"
[ -d "$SITE" ] || { echo "no such site: $SITE (tool/thor export docs)" >&2; exit 1; }
command -v npx >/dev/null || { echo "npx missing (install node)" >&2; exit 1; }

npx --yes pagefind@1.5.2 --site "$SITE" --quiet

# Only the engine (pagefind.js, its worker, wasm and index) is used: the
# search page draws its own results, so the stock UI is left out of the deploy.
rm -f "$SITE"/pagefind/pagefind-*ui*.{js,css} "$SITE"/pagefind/pagefind-highlight.js

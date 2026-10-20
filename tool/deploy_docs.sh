#!/usr/bin/env bash
# Publishes the docs site (apps/docs) to Vercel production:
# https://thor-docs.vercel.app (project `thor-docs`).
#
#   tool/deploy_docs.sh [base-url]   (needs `vercel` logged in)
#
# The site is exported with its base URL (sitemap, robots, canonical),
# given a card per page (tool/og_cards.mjs; needs Chrome, optional), indexed for its search page (tool/docs_index.sh; needs node) and deployed
# as static files from a temporary folder, with apps/docs/deploy/vercel.json
# (clean URLs: pages are `name.html`, links are `/name`), uploaded as one
# archive (the free plan caps uploads per day).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
BASE_URL="${1:-https://thor-docs.vercel.app}"

say() { printf '\033[1;36m▸ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }
command -v vercel >/dev/null || fail "vercel CLI missing (brew install vercel-cli)"
# In CI (.github/workflows/docs-deploy.yml) VERCEL_TOKEN, VERCEL_ORG_ID and
# VERCEL_PROJECT_ID stand in for the login and the link.
if [ -z "${VERCEL_TOKEN:-}" ]; then
  vercel whoami >/dev/null 2>&1 || fail "vercel is not logged in (vercel login)"
fi
# The vercel CLI reads VERCEL_TOKEN, VERCEL_ORG_ID and VERCEL_PROJECT_ID
# from the environment itself: nothing goes in argv, where `ps` shows it.

say "Export docs ($BASE_URL)"
dart run thor_cli:thor export apps/docs --base-url "$BASE_URL" >/dev/null

# A card per page (title and section; ~15 s). Optional: without it (OG_CARDS=0,
# or no Chrome) every page keeps the default card.
if [ "${OG_CARDS:-1}" != 0 ]; then
  say "Cards (Open Graph)"
  node tool/og_cards.mjs apps/docs/build/site || echo "no per-page cards (the default one stays)" >&2
fi

say "Search index (Pagefind)"
tool/docs_index.sh apps/docs/build/site

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R apps/docs/build/site/. "$STAGE/"
cp apps/docs/deploy/vercel.json "$STAGE/"

say "Deploy to Vercel (production)"
(cd "$STAGE" &&
  if [ -z "${VERCEL_PROJECT_ID:-}" ]; then
    vercel link --yes --project thor-docs >/dev/null
  fi &&
  vercel deploy --prod --yes --archive=tgz)

#!/usr/bin/env bash
# Run everything CI would run. Green here means safe to deploy.
#
# Usage:  ./scripts/preflight.sh
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

log() { printf "\n\033[1;36m── %s ──\033[0m\n" "$*"; }

log "Backend: pytest"
(
  cd backend
  python -m pytest tests -q -p no:langsmith
)

log "Flutter: pub get"
(
  cd mobile
  flutter pub get > /dev/null
)

log "Flutter: analyze"
(
  cd mobile
  flutter analyze
)

log "Flutter: web release build"
(
  cd mobile
  # Use a placeholder URL; the real one is supplied at deploy time.
  flutter build web --release --dart-define=API_BASE_URL=https://api.example.com > /dev/null
)

log "All green — safe to deploy."

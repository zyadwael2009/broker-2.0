#!/usr/bin/env bash
# Build the Flutter Web bundle for deployment under /app/.
#
# Usage:
#   ./scripts/build-web-app.sh
#   ./scripts/build-web-app.sh https://api.wasit.app https://wasit.app
#
# Output: mobile/build/web/  — served by Flask's webapp blueprint at /app/*.
set -euo pipefail

API_BASE_URL="${1:-http://localhost:5150}"
PUBLIC_BASE_URL="${2:-http://localhost:5150}"
BASE_HREF="${3:-/app/}"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mobile="$(cd "$here/../mobile" && pwd)"

echo "Building Flutter Web…"
echo "  API_BASE_URL    = $API_BASE_URL"
echo "  PUBLIC_BASE_URL = $PUBLIC_BASE_URL"
echo "  base-href       = $BASE_HREF"

cd "$mobile"
flutter build web --release \
    --base-href "$BASE_HREF" \
    --dart-define=API_BASE_URL="$API_BASE_URL" \
    --dart-define=PUBLIC_BASE_URL="$PUBLIC_BASE_URL"

out="$mobile/build/web/index.html"
if [[ -f "$out" ]]; then
    size=$(wc -c <"$out")
    echo ""
    echo "OK — built to $mobile/build/web/ (index.html $size bytes)"
    echo "Boot the backend, then open http://localhost:5150/app/"
else
    echo "Build finished but $out does not exist." >&2
    exit 1
fi

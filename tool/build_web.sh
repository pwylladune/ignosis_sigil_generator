#!/bin/sh
# Builds the production web app into build/web.
#
# The rite API address is compiled in. Without the define the studio builds
# and runs, but the rite (payment and the on-chain burn) is off.
#
# Deploy the result with: netlify deploy --prod --dir build/web
set -eu
cd "$(dirname "$0")/.."
RITE_API="${IGNOSIS_RITE_API:-https://api.ignosis.net}"
flutter build web --release --dart-define=IGNOSIS_RITE_API="$RITE_API"
grep -q "$RITE_API" build/web/main.dart.js || { echo "The rite API address is not in the build" >&2; exit 1; }
echo "Built build/web with the rite API at $RITE_API"

#!/bin/sh
# Volumes are mounted owned by root. Hand the data directory to the
# unprivileged node user, then run the server as that user.
set -e
if [ -n "$RITE_LEDGER_PATH" ]; then
  dir=$(dirname "$RITE_LEDGER_PATH")
  mkdir -p "$dir"
  chown node:node "$dir"
fi
exec su-exec node "$@"

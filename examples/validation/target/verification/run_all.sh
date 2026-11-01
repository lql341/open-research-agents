#!/usr/bin/env bash
# Human-owned numerical verification. Exit 0 PASS, 1 FAIL, 2 UNVERIFIED.
# Extra arguments (such as a workstream name) are ignored.
set -uo pipefail
BIN="${BUILD_DIR:-build}/adv_mms"
if [ ! -x "$BIN" ]; then
  echo "UNVERIFIED: $BIN not built (run the build step first)" >&2
  exit 2
fi
exec "$BIN"

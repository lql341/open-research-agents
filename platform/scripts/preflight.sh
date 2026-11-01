#!/usr/bin/env bash
# Usage (inside target repo): preflight.sh [workstream]
# Refuses to start a worker if the human-owned foundations are not ready.
set -uo pipefail
MODULE="${1:-}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "preflight: not inside a git repository"; exit 2; }
cd "$ROOT"
fail=0
warn=0
ok()   { printf '  ok   %s\n' "$1"; }
bad()  { printf '  FAIL %s\n' "$1"; fail=1; }
note() { printf '  warn %s\n' "$1"; warn=1; }

[ -f .agentlab/domain.env ] || { echo "preflight: missing .agentlab/domain.env; run install_domain.sh/install_target.sh first"; exit 2; }
# shellcheck disable=SC1091
source .agentlab/domain.env

MODE="${AGENTLAB_MODE:-worker}"
REQUIRE_CORE="${REQUIRE_CORE:-1}"
REQUIRE_CONTRACTS="${REQUIRE_CONTRACTS:-1}"
REQUIRE_UNIT="${REQUIRE_UNIT:-1}"
UNIT_DIR="${UNIT_DIR:-tests/unit}"
BUILD_FILE="${BUILD_FILE:-CMakeLists.txt}"
BASE="${BASE_REF:-main}"

echo "preflight: $ROOT${MODULE:+ (workstream: $MODULE)} mode=$MODE"

if [ "$MODE" = "audit" ]; then
  ok "audit mode: read-only; skipping contracts/core/build/unit/verification checks"
else
  if [ "$REQUIRE_CONTRACTS" = "1" ]; then
    if [ -d .agentlab/contracts ]; then
      if hits=$(grep -RIn --exclude-dir=.git -E 'TODO|\[CONFIRM\]' .agentlab/contracts 2>/dev/null); then
        bad "contracts still contain TODO/[CONFIRM]:"
        printf '%s\n' "$hits" | sed 's/^/       /'
      else
        ok "contracts have no TODO/[CONFIRM]"
      fi
    else
      bad "missing .agentlab/contracts/"
    fi
  fi

  if [ "$REQUIRE_CORE" = "1" ]; then
    if [ -d core ] && [ -n "$(find core -type f 2>/dev/null | head -1)" ]; then
      ok "core/ exists and is non-empty"
    else
      bad "missing or empty core/"
    fi
  fi

  [ -f "$BUILD_FILE" ] && ok "$BUILD_FILE exists" || bad "missing $BUILD_FILE"

  if [ "$REQUIRE_UNIT" = "1" ]; then
    if find "$UNIT_DIR" -type f \( -name '*.cpp' -o -name '*.cc' -o -name '*.cxx' \) 2>/dev/null | head -1 | grep -q .; then
      ok "$UNIT_DIR has C++ test sources"
    else
      bad "$UNIT_DIR has no C++ test source"
    fi
  fi

  if [ -n "${VERIFY_CMD:-}" ]; then
    if [ -f .agentlab/verification/run_all.sh ]; then
      if grep -q 'UNVERIFIED' .agentlab/verification/run_all.sh 2>/dev/null; then
        note "verification is still a placeholder; worker gate will be UNVERIFIED and integration gate will fail"
      else
        ok "verification runner exists"
      fi
    else
      bad "missing .agentlab/verification/run_all.sh"
    fi
  fi
fi

if [ -n "$MODULE" ]; then
  if [ -f ".agentlab/scope/$MODULE.txt" ] && grep -qvE '^[[:space:]]*(#|$)' ".agentlab/scope/$MODULE.txt"; then
    ok "scope/$MODULE.txt exists and is non-empty"
  else
    bad "missing or empty .agentlab/scope/$MODULE.txt"
  fi
fi

if git rev-parse --verify "$BASE" >/dev/null 2>&1; then
  ok "base ref $BASE exists"
else
  bad "base ref $BASE does not exist"
fi

if [ -n "$(git status --porcelain)" ]; then
  note "working tree is dirty; run_worker.sh will refuse to start"
else
  ok "working tree is clean"
fi

echo "preflight: $([ $fail -eq 0 ] && echo PASS || echo FAIL)${warn:+ (with warnings)}"
exit $fail

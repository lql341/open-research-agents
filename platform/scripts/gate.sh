#!/usr/bin/env bash
# Usage (inside target repo/worktree): gate.sh [module]
# GATE_MODE=worker|integration|release (default: worker)
# Exit: 0 PASS, 1 FAIL, 2 UNVERIFIED
set -uo pipefail
PLATFORM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "gate: not inside a git repository"; exit 1; }
cd "$ROOT"
[ -f .agentlab/domain.env ] || { echo "gate: missing .agentlab/domain.env"; exit 1; }
# shellcheck disable=SC1091
source .agentlab/domain.env
MODULE="${1:-}"
GATE_MODE="${GATE_MODE:-worker}"
fail=0
unverified=0

run() { bash -c "$1"; }
step() {
  local name="$1"; shift
  echo "== $name"
  "$@" || { echo "FAILED: $name"; fail=1; }
}

if [ -n "$MODULE" ]; then
  step scope "$PLATFORM/scope_check.sh" "$MODULE" "${BASE_REF:-main}"
fi
if [ $fail -eq 0 ]; then
  step build run "${BUILD_CMD:?BUILD_CMD missing in .agentlab/domain.env}"
fi
if [ $fail -eq 0 ]; then
  step unit run "${UNIT_CMD:?UNIT_CMD missing in .agentlab/domain.env}"
fi
if [ $fail -eq 0 ] && [ -n "${VERIFY_CMD:-}" ]; then
  echo "== verification"
  if [ -n "$MODULE" ]; then
    # shellcheck disable=SC2086
    bash -c "$VERIFY_CMD $MODULE"
  else
    bash -c "$VERIFY_CMD"
  fi
  rc=$?
  if [ $rc -eq 2 ]; then
    unverified=1
    echo "VERIFICATION: UNVERIFIED"
  elif [ $rc -ne 0 ]; then
    fail=1
    echo "FAILED: verification (exit $rc)"
  fi
fi

status=pass
[ $fail -ne 0 ] && status=fail
[ $fail -eq 0 ] && [ $unverified -eq 1 ] && status=unverified

# Integration refuses UNVERIFIED; keep the explicit status and exit 2.
if [ "$GATE_MODE" = "integration" ] && [ "$status" = "unverified" ]; then
  echo "integration gate requires G3 numerical verification; register a real case."
fi
if [ "$GATE_MODE" = "release" ] && [ "$status" != "pass" ]; then
  status=fail
fi

case "$status" in
  pass) gate_rc=0 ;;
  unverified) gate_rc=2 ;;
  *) gate_rc=1 ;;
esac
"$PLATFORM/repro_snapshot.sh" "${MODULE:-integration}" "$GATE_MODE" "$status" "$gate_rc" || true

echo "----"
UPPER=$(printf '%s' "$status" | tr '[:lower:]' '[:upper:]')
echo "GATE $UPPER (mode: $GATE_MODE)"
[ "$status" = "pass" ] && exit 0
[ "$status" = "unverified" ] && exit 2
exit 1

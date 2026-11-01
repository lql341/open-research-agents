#!/usr/bin/env bash
# Usage (inside target repo): preflight.sh [module]
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

echo "preflight: $ROOT${MODULE:+ (module: $MODULE)}"

[ -f .agentlab/domain.env ] || { echo "preflight: missing .agentlab/domain.env; run install_domain.sh first"; exit 2; }
# shellcheck disable=SC1091
source .agentlab/domain.env

# 1. Contracts must be human-confirmed.
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

# 2. Human-owned numeric core.
if [ -d core ] && [ -n "$(find core -type f 2>/dev/null | head -1)" ]; then
  ok "core/ exists and is non-empty"
else
  bad "missing or empty core/ (Field/Mesh/Comm)"
fi

# 3. Build entry point.
[ -f CMakeLists.txt ] && ok "CMakeLists.txt exists" || bad "missing CMakeLists.txt"

# 4. At least one unit test source.
if find tests/unit -type f \( -name '*.cpp' -o -name '*.cc' -o -name '*.cxx' \) 2>/dev/null | head -1 | grep -q .; then
  ok "tests/unit has source files"
else
  bad "tests/unit has no C++ test source; add ctest tests with label 'unit'"
fi

# 5. Scope for the requested module.
if [ -n "$MODULE" ]; then
  if [ -f ".agentlab/scope/$MODULE.txt" ] && grep -qvE '^[[:space:]]*(#|$)' ".agentlab/scope/$MODULE.txt"; then
    ok "scope/$MODULE.txt exists and is non-empty"
  else
    bad "missing or empty .agentlab/scope/$MODULE.txt"
  fi
fi

# 6. Verification runner.
if [ -f .agentlab/verification/run_all.sh ]; then
  if grep -q 'UNVERIFIED' .agentlab/verification/run_all.sh 2>/dev/null; then
    note "verification is still a placeholder; worker gate will be UNVERIFIED and integration gate will fail"
  else
    ok "verification runner exists"
  fi
else
  bad "missing .agentlab/verification/run_all.sh"
fi

# 7. Base ref.
BASE="${BASE_REF:-main}"
if git rev-parse --verify "$BASE" >/dev/null 2>&1; then
  ok "base ref $BASE exists"
else
  bad "base ref $BASE does not exist"
fi

# 8. Clean working tree (warning here; run_worker enforces it).
if [ -n "$(git status --porcelain)" ]; then
  note "working tree is dirty; run_worker.sh will refuse to start"
else
  ok "working tree is clean"
fi

echo "preflight: $([ $fail -eq 0 ] && echo PASS || echo FAIL)${warn:+ (with warnings)}"
exit $fail

#!/usr/bin/env bash
# Usage (inside target repo main checkout, clean tree): integrate.sh [workstream...]
# Ends on the integration branch; merge the base branch only after human approval.
set -euo pipefail
PLATFORM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel)"; cd "$ROOT"
[ -f .agentlab/domain.env ] || { echo "integrate: missing .agentlab/domain.env"; exit 2; }
# shellcheck disable=SC1091
source .agentlab/domain.env
BASE="${BASE_REF:-main}"

git diff --quiet && git diff --cached --quiet || { echo "working tree is dirty"; exit 1; }
git fetch --all --prune >/dev/null 2>&1 || true

MODULES="${*:-$MODULES}"
git checkout -B integration "$BASE"
for m in $MODULES; do
  echo "== merge agent/$m"
  git merge --no-ff -m "integrate: $m" "agent/$m" || {
    echo "conflict: $m. Ask the worker to rebase on latest $BASE, or write an RFC."
    git merge --abort || true
    git checkout "$BASE"
    exit 1
  }
done

set +e
GATE_MODE=integration "$PLATFORM/gate.sh"
rc=$?
set -e

# Keep the integration branch clean: commit the audit record produced by the gate.
if [ -d .agentlab/repro ] && [ -n "$(git ls-files --others --exclude-standard .agentlab/repro)" ]; then
  git add .agentlab/repro
  git commit -m "repro: integration $(date -u +%Y%m%dT%H%M%SZ)" >/dev/null || true
fi
if [ $rc -eq 0 ]; then
  echo "GATE PASS. Review the integration branch, then merge $BASE after human approval."
  exit 0
fi
if [ $rc -eq 2 ]; then
  echo "GATE UNVERIFIED. Register a real verification case before integration."
  exit 2
fi
echo "GATE FAIL."
exit 1

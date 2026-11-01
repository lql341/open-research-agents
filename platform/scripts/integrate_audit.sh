#!/usr/bin/env bash
# Usage (inside target repo main checkout, clean tree): integrate_audit.sh [workstream...]
# Merges read-only audit branches into an audit-integration branch.
# It refuses any change outside .agentlab/reports, .agentlab/RFC, .agentlab/repro.
# It does NOT build, run tests, or merge the base branch. A human reviews and merges.
set -euo pipefail
PLATFORM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel)"; cd "$ROOT"
[ -f .agentlab/domain.env ] || { echo "integrate_audit: missing .agentlab/domain.env"; exit 2; }
# shellcheck disable=SC1091
source .agentlab/domain.env
BASE="${BASE_REF:-main}"

git diff --quiet && git diff --cached --quiet || { echo "working tree is dirty"; exit 1; }
git fetch --all --prune >/dev/null 2>&1 || true

MODULES="${*:-$MODULES}"
git checkout -B audit-integration "$BASE"
for m in $MODULES; do
  echo "== merge agent/$m"
  git merge --no-ff -m "audit: merge $m" "agent/$m" || {
    echo "conflict: $m. Rebase the audit branch on $BASE or resolve manually."
    git merge --abort || true
    git checkout "$BASE"
    exit 1
  }
done

BAD=$(git diff --name-only "$BASE"...HEAD | grep -vE '^\.agentlab/(reports|RFC|repro)/' || true)
if [ -n "$BAD" ]; then
  echo "audit merge contains non-audit files:"
  printf '%s\n' "$BAD" | sed 's/^/  /'
  echo "Refusing. Audit branches may only add reports, RFCs, and repro records."
  exit 1
fi

echo "audit-integration is ready."
echo "Review .agentlab/reports/*.md and .agentlab/RFC/*.md, then merge audit-integration into $BASE."

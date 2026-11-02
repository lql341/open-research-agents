#!/usr/bin/env bash
# Usage (inside target repo/worktree): scope_check.sh <module> [base_ref]
# Reads the scope from base_ref, so a worker cannot widen its own scope.
set -euo pipefail
MODULE="${1:?usage: scope_check.sh <module> [base_ref]}"
BASE="${2:-main}"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

git rev-parse --verify "$BASE" >/dev/null 2>&1 || { echo "scope_check: base ref missing: $BASE"; exit 2; }
SCOPE=$(git show "$BASE:.agentlab/scope/$MODULE.txt" 2>/dev/null) || {
  echo "scope_check: missing $BASE:.agentlab/scope/$MODULE.txt"; exit 2; }

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
{
  git diff --name-only "$BASE"...HEAD
  git diff --name-only
  # Untracked repro and decision records are audit artifacts written by the
  # gate or by a human. Committed ones are still checked above.
  git ls-files --others --exclude-standard | grep -vE '^\.agentlab/(repro|decisions)/' || true
} | sort -u > "$tmp"

bad=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  ok=0
  while IFS= read -r p; do
    [[ -z "$p" || "$p" == \#* ]] && continue
    if [[ "$p" == *'*'* || "$p" == *'?'* || "$p" == *'['* ]]; then
      # shellcheck disable=SC2053
      [[ "$f" == $p ]] && { ok=1; break; }
    else
      [[ "$f" == "$p" || "$f" == "$p"* ]] && { ok=1; break; }
    fi
  done <<< "$SCOPE"
  if [ $ok -eq 0 ]; then
    echo "OUT OF SCOPE: $f"
    bad=1
  fi
done < "$tmp"

if [ $bad -eq 0 ]; then
  echo "scope: $MODULE OK ($(wc -l < "$tmp" | tr -d ' ') changed files)"
fi
exit $bad

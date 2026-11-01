#!/usr/bin/env bash
# Platform smoke test: no model calls, no network.
# Copies the cfd-mini template into a temp git repo and exercises preflight/gate/scope.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
TARGET="$TMP/cfd-mini"

cp -R "$ROOT/examples/cfd-mini" "$TARGET"
cd "$TARGET"
git init -q -b main
git add .
git commit -q -m "init cfd-mini"

pass=0
fail=0
check() { if "$@"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAILED: $*"; fi; }

echo "== preflight"
if "$ROOT/platform/scripts/preflight.sh" spatial >/tmp/agentlab-preflight.log 2>&1; then
  pass=$((pass+1))
else
  fail=$((fail+1)); cat /tmp/agentlab-preflight.log
fi

echo "== worker gate (expect UNVERIFIED=2)"
set +e
"$ROOT/platform/scripts/gate.sh" spatial >/tmp/agentlab-gate.log 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "expected 2, got $rc"; tail -20 /tmp/agentlab-gate.log; }
grep -q "GATE UNVERIFIED" /tmp/agentlab-gate.log && pass=$((pass+1)) || { fail=$((fail+1)); echo "missing GATE UNVERIFIED"; }

echo "== integration gate (expect UNVERIFIED=2)"
set +e
GATE_MODE=integration "$ROOT/platform/scripts/gate.sh" >/tmp/agentlab-gate-int.log 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "expected 2, got $rc"; tail -20 /tmp/agentlab-gate-int.log; }

echo "== scope check rejects out-of-scope file"
echo hack > core/hack.txt
set +e
"$ROOT/platform/scripts/scope_check.sh" spatial main >/tmp/agentlab-scope.log 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "scope check accepted an out-of-scope file"; }
grep -q "OUT OF SCOPE: core/hack.txt" /tmp/agentlab-scope.log && pass=$((pass+1)) || { fail=$((fail+1)); echo "missing out-of-scope diagnostic"; }
rm -f core/hack.txt

echo "----"
echo "smoke: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

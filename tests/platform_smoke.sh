#!/usr/bin/env bash
# Platform smoke test: no model calls, no network.
# Copies the cfd-mini template into a temp git repo and exercises preflight/gate/scope.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
TARGET="$TMP/cfd-mini"

cp -R "$ROOT/tests/fixtures/mini-target" "$TARGET"
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

echo "== audit preflight"
if AGENTLAB_MODE=audit "$ROOT/platform/scripts/preflight.sh" spatial >/tmp/agentlab-preflight-audit.log 2>&1; then
  pass=$((pass+1))
else
  fail=$((fail+1)); cat /tmp/agentlab-preflight-audit.log
fi

echo "== audit gate (expect PASS=0)"
set +e
AGENTLAB_MODE=audit "$ROOT/platform/scripts/gate.sh" spatial >/tmp/agentlab-gate-audit.log 2>&1
rc=$?
set -e
[ "$rc" -eq 0 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "expected 0, got $rc"; tail -20 /tmp/agentlab-gate-audit.log; }
grep -q "GATE PASS (mode: audit" /tmp/agentlab-gate-audit.log && pass=$((pass+1)) || { fail=$((fail+1)); echo "missing audit PASS"; }

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

echo "== agentlab CLI"
if "$ROOT/bin/agentlab" version >/tmp/agentlab-version.log 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAILED: agentlab version"; cat /tmp/agentlab-version.log; fi
if "$ROOT/bin/agentlab" config >/tmp/agentlab-config.log 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAILED: agentlab config"; fi
grep -q "pi.bin" /tmp/agentlab-config.log && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: agentlab config output"; }

if "$ROOT/bin/agentlab" status >/tmp/agentlab-status.log 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAILED: agentlab status"; cat /tmp/agentlab-status.log; fi
grep -q "WORKSTREAM" /tmp/agentlab-status.log && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: status header"; }

if "$ROOT/bin/agentlab" status --json >/tmp/agentlab-status.json 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAILED: agentlab status --json"; fi
python3 -c "import json,sys; json.load(open('/tmp/agentlab-status.json'))" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: status --json is not valid JSON"; }

if "$ROOT/bin/agentlab" doctor >/tmp/agentlab-doctor.log 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAILED: agentlab doctor"; cat /tmp/agentlab-doctor.log; fi

# The CLI must pass a configured Pi profile only to its children.
TMP_PROFILE="$(mktemp -d)"
cat > "$TMP/agentlab-cli.toml" <<TOML
[pi]
bin = "$TMP/fake-pi-profile.sh"
profile = "$TMP_PROFILE"
TOML
cat > "$TMP/fake-pi-profile.sh" <<'SH'
#!/bin/sh
echo "PROFILE=${PI_CODING_AGENT_DIR:-unset}"
SH
chmod +x "$TMP/fake-pi-profile.sh"
if AGENTLAB_CONFIG="$TMP/agentlab-cli.toml" "$ROOT/bin/agentlab" run spatial >/tmp/agentlab-run.log 2>&1 || true; then :; fi
grep -q "PROFILE=$TMP_PROFILE" /tmp/agentlab-run.log && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: worker did not receive PI_CODING_AGENT_DIR"; tail -5 /tmp/agentlab-run.log; }
if [ -z "${PI_CODING_AGENT_DIR:-}" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAILED: agentlab leaked PI_CODING_AGENT_DIR into the caller"; fi
rm -rf "$TMP_PROFILE"

echo "----"
echo "smoke: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

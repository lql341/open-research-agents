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

echo "== generated repro records do not fail scope"
mkdir -p .agentlab/repro
printf '{}\n' > .agentlab/repro/spatial-manual.json
set +e
"$ROOT/platform/scripts/scope_check.sh" spatial main >/tmp/agentlab-scope-repro.log 2>&1
rc=$?
set -e
[ $rc -eq 0 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: untracked repro record failed scope"; cat /tmp/agentlab-scope-repro.log; }
rm -f .agentlab/repro/spatial-manual.json

echo "== agentlab CLI"
if "$ROOT/bin/agentlab" version >/tmp/agentlab-version.log 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAILED: agentlab version"; cat /tmp/agentlab-version.log; fi
if "$ROOT/bin/agentlab" config >/tmp/agentlab-config.log 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAILED: agentlab config"; fi
grep -q "pi.bin" /tmp/agentlab-config.log && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: agentlab config output"; }

if "$ROOT/bin/agentlab" status >/tmp/agentlab-status.log 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAILED: agentlab status"; cat /tmp/agentlab-status.log; fi
grep -q "WORKSTREAM" /tmp/agentlab-status.log && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: status header"; }

if "$ROOT/bin/agentlab" status --json >/tmp/agentlab-status.json 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAILED: agentlab status --json"; fi
python3 -c "import json,sys; json.load(open('/tmp/agentlab-status.json'))" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: status --json is not valid JSON"; }

if "$ROOT/bin/agentlab" doctor >/tmp/agentlab-doctor.log 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAILED: agentlab doctor"; cat /tmp/agentlab-doctor.log; fi

if "$ROOT/bin/agentlab" --help >/tmp/agentlab-help.txt 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAILED: agentlab --help"; fi
grep -q "Target repository" /tmp/agentlab-help.txt && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: help does not explain target resolution"; }
grep -q "current git" /tmp/agentlab-help.txt && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: help does not mention current git"; }

if "$ROOT/bin/agentlab" ticket --help >/tmp/agentlab-ticket-help.txt 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAILED: ticket --help"; fi
grep -q "new" /tmp/agentlab-ticket-help.txt && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: ticket help missing commands"; }

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

echo "== install / update / uninstall lifecycle"
LIFE="$(mktemp -d)"
LIFE_REPO="$LIFE/repo"
export LIFE_REPO
# A clean repository with no pre-existing .agentlab: this exercises the
# install path rather than the "keep what is already there" path.
mkdir -p "$LIFE_REPO"
( cd "$LIFE_REPO" && git init -q -b main && echo "# lifecycle" > README.md \
  && git add . && git commit -q -m init ) >/dev/null

if "$ROOT/bin/agentlab" install cfd oneflow "$LIFE_REPO" >/tmp/agentlab-life-install.log 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAILED: install"; cat /tmp/agentlab-life-install.log; fi
grep -q "installed domain=cfd target=oneflow" /tmp/agentlab-life-install.log && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: install did not report the pack"; }
[ -f "$LIFE_REPO/.agentlab/.pack" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: .agentlab/.pack missing"; }
[ -f "$LIFE_REPO/.agentlab/AGENTS.md" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: generated AGENTS.md missing"; }
grep -q "# --- target: oneflow ---" "$LIFE_REPO/.agentlab/AGENTS.md" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: target rules not merged"; }
[ -f "$LIFE_REPO/.agentlab/scope/spatial.txt" ] && { fail=$((fail+1)); echo "FAILED: domain scope survived a target-scoped install"; } || pass=$((pass+1))
[ -d "$LIFE_REPO/.agentlab/tickets" ] && [ -d "$LIFE_REPO/.agentlab/candidates" ] && [ -d "$LIFE_REPO/.agentlab/sources" ] && [ -d "$LIFE_REPO/.agentlab/decisions" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: install did not create inbox/ticket directories"; }

( cd "$LIFE_REPO" && sed -i.bak 's/^BASE_REF=dev/BASE_REF=main/' .agentlab/target.env && rm -f .agentlab/target.env.bak && git add -A && git commit -q -m install ) >/dev/null

# Second install must not add anything.
if "$ROOT/bin/agentlab" install cfd oneflow "$LIFE_REPO" >/tmp/agentlab-life-reinstall.log 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAILED: reinstall"; fi
grep -q "added " /tmp/agentlab-life-reinstall.log && { fail=$((fail+1)); echo "FAILED: reinstall added files"; } || pass=$((pass+1))

# update with no platform change reports up to date.
if ( cd "$LIFE_REPO" && "$ROOT/bin/agentlab" update --no-pull >/tmp/agentlab-life-update.log 2>&1 ); then pass=$((pass+1)); else fail=$((fail+1)); echo "FAILED: update"; cat /tmp/agentlab-life-update.log; fi
grep -q "AGENTS.md is up to date" /tmp/agentlab-life-update.log && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: update did not compare AGENTS.md"; }

# update adds a missing env key without changing existing values.
python3 - <<'PYCHECK'
from pathlib import Path
import os
p=Path(os.environ['LIFE_REPO']) / '.agentlab' / 'target.env'
s=p.read_text()
p.write_text('\n'.join(line for line in s.splitlines() if not line.startswith('GITHUB_CLI='))+ '\n')
PYCHECK
if ( cd "$LIFE_REPO" && "$ROOT/bin/agentlab" update --no-pull >/tmp/agentlab-life-update-keys.log 2>&1 ); then pass=$((pass+1)); else fail=$((fail+1)); echo "FAILED: update env merge"; cat /tmp/agentlab-life-update-keys.log; fi
grep -q '^GITHUB_CLI=gh-agent' "$LIFE_REPO/.agentlab/target.env" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: update did not restore GITHUB_CLI"; }
grep -q '^AGENTLAB_MODE=audit' "$LIFE_REPO/.agentlab/target.env" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: update changed an existing env value"; }

# uninstall removes the pack and the generated pointer.
if ( cd "$LIFE_REPO" && "$ROOT/bin/agentlab" uninstall --yes >/tmp/agentlab-life-uninstall.log 2>&1 ); then pass=$((pass+1)); else fail=$((fail+1)); echo "FAILED: uninstall"; cat /tmp/agentlab-life-uninstall.log; fi
[ -d "$LIFE_REPO/.agentlab" ] && { fail=$((fail+1)); echo "FAILED: .agentlab survived uninstall"; } || pass=$((pass+1))
[ -f "$LIFE_REPO/AGENTS.md" ] && { fail=$((fail+1)); echo "FAILED: generated AGENTS.md survived uninstall"; } || pass=$((pass+1))
# uninstall on a clean repo is a no-op success.
( cd "$LIFE_REPO" && "$ROOT/bin/agentlab" uninstall --yes >/dev/null 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: second uninstall should be a no-op"; }
rm -rf "$LIFE"

echo "== worker session guards"
SESS="$TMP/sess"
SESS_REPO="$SESS/repo"
WT="$SESS/wt"
mkdir -p "$SESS_REPO" "$WT/sessions" "$WT/logs"
cp -R "$ROOT/tests/fixtures/mini-target/." "$SESS_REPO/"
( cd "$SESS_REPO" && git init -q -b main && git add -A && git commit -q -m init ) >/dev/null
cat > "$WT/sessions/2026-01-01T00-00-00-000Z_agentlab-spatial.jsonl" <<'JSONL'
{"type":"session","version":3,"id":"agentlab-spatial"}
{"type":"model_change","provider":"ghost","modelId":"gone-1"}
JSONL
cat > "$SESS/fake-pi.sh" <<'SH'
#!/bin/sh
if [ "$1" = "--list-models" ]; then
  printf 'provider  model                       context  max-out\n'
  printf 'real      good-model                  1M       8K\n'
  exit 0
fi
echo "fake pi ran"
exit 0
SH
chmod +x "$SESS/fake-pi.sh"

set +e
( cd "$SESS_REPO" && WT_ROOT="$WT" PI_BIN="$SESS/fake-pi.sh" "$ROOT/bin/agentlab" run spatial >/tmp/agentlab-pin.log 2>&1 )
rc=$?
set -e
[ $rc -eq 3 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: expected exit 3 for a session pinned to an unavailable model, got $rc"; tail -6 /tmp/agentlab-pin.log; }
grep -q "pinned to an unavailable model" /tmp/agentlab-pin.log && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: no pin diagnostic"; }
grep -q -- "--reset-session" /tmp/agentlab-pin.log && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: no reset hint"; }

set +e
( cd "$SESS_REPO" && WT_ROOT="$WT" PI_BIN="$SESS/fake-pi.sh" "$ROOT/bin/agentlab" run spatial --reset-session >/tmp/agentlab-reset.log 2>&1 )
rc=$?
set -e
[ $rc -ne 3 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: --reset-session still refused (exit 3)"; }
grep -q "cleared the spatial session history" /tmp/agentlab-reset.log && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: --reset-session did not clear the session"; }
ls "$WT/sessions"/*agentlab-spatial*.jsonl >/dev/null 2>&1 && { fail=$((fail+1)); echo "FAILED: session file survived --reset-session"; } || pass=$((pass+1))

echo "== an available pinned model is not rejected"
cat > "$WT/sessions/2026-01-02T00-00-00-000Z_agentlab-spatial.jsonl" <<'JSONL'
{"type":"session","version":3,"id":"agentlab-spatial"}
{"type":"model_change","provider":"real","modelId":"good-model"}
JSONL
set +e
( cd "$SESS_REPO" && WT_ROOT="$WT" PI_BIN="$SESS/fake-pi.sh" "$ROOT/bin/agentlab" run spatial >/tmp/agentlab-pin-ok.log 2>&1 )
rc=$?
set -e
[ $rc -ne 3 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: rejected an available model (false positive)"; tail -8 /tmp/agentlab-pin-ok.log; }
grep -q "pinned to an unavailable model" /tmp/agentlab-pin-ok.log && { fail=$((fail+1)); echo "FAILED: false-positive pin warning"; } || pass=$((pass+1))

echo "== status surfaces the last worker error"
printf 'preflight: ok\nOpenAI API error (400): model_not_found gpt-5.5\n' > "$WT/logs/spatial-20260101T000000Z.log"
( cd "$SESS_REPO" && WT_ROOT="$WT" "$ROOT/bin/agentlab" status >/tmp/agentlab-status-log.log 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: status with logs"; }
grep -q "Recent worker logs" /tmp/agentlab-status-log.log && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: status does not list worker logs"; }
grep -q "OpenAI API error" /tmp/agentlab-status-log.log && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: status does not surface the worker error"; }

echo "== integrate refuses an untracked file"
printf 'scratch\n' > "$SESS_REPO/untracked.txt"
set +e
( cd "$SESS_REPO" && WT_ROOT="$WT" "$ROOT/bin/agentlab" integrate spatial >/tmp/agentlab-integrate-dirty.log 2>&1 )
rc=$?
set -e
[ $rc -ne 0 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: integrate accepted an untracked file"; }
grep -q "working tree is dirty" /tmp/agentlab-integrate-dirty.log && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: no dirty-tree diagnostic"; }
grep -q -- "--worktree" /tmp/agentlab-integrate-dirty.log && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: no worktree hint"; }
rm -f "$SESS_REPO/untracked.txt"

echo "== attention inbox"
INBOX="$TMP/inbox"
INBOX_WT="$TMP/inbox-wt"
mkdir -p "$INBOX" "$INBOX_WT/logs"
cp -R "$ROOT/tests/fixtures/mini-target/." "$INBOX/"
( cd "$INBOX" && git init -q -b main && git add -A && git commit -q -m init ) >/dev/null
cat > "$INBOX/.agentlab/reports/spatial.md" <<'REPORT'
# Report: spatial

status: need_decision
updated: 2026-11-01
commit: abc1234
REPORT
cat > "$INBOX/.agentlab/RFC/spatial-test.md" <<'RFC'
# RFC: test

Status: proposed | approved | rejected (only a human changes this)
RFC
cat > "$INBOX/.agentlab/repro/spatial-20261101T000000Z.json" <<'GATE'
{"gate_mode":"worker","gate_status":"unverified","git_commit":"abc1234","time_utc":"2026-11-01T00:00:00Z"}
GATE
printf 'preflight: ok\nOpenAI API error (400): model_not_found\n' > "$INBOX_WT/logs/spatial-20261101T000000Z.log"

set +e
( cd "$INBOX" && WT_ROOT="$INBOX_WT" "$ROOT/bin/agentlab" inbox --json >/tmp/agentlab-inbox.json 2>/tmp/agentlab-inbox.err )
rc=$?
set -e
[ $rc -eq 0 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: inbox --json"; cat /tmp/agentlab-inbox.err; }
python3 - <<'PYCHECK' && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: inbox categories"; }
import json
d=json.load(open('/tmp/agentlab-inbox.json'))
items={i['id']:i for i in d['items']}
assert items['report:spatial']['category']=='pending'
assert items['rfc:spatial-test']['category']=='pending'
assert items['worker:spatial:spatial-20261101T000000Z.log']['category']=='pending'
assert items['gate:spatial:spatial-20261101T000000Z.json']['category']=='review'
PYCHECK

( cd "$INBOX" && WT_ROOT="$INBOX_WT" "$ROOT/bin/agentlab" inbox >/tmp/agentlab-inbox.txt 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: inbox text"; }
grep -q "pending (3)" /tmp/agentlab-inbox.txt && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: inbox pending count"; }
grep -q "review (1)" /tmp/agentlab-inbox.txt && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: inbox review count"; }

( cd "$INBOX" && WT_ROOT="$INBOX_WT" "$ROOT/bin/agentlab" decide report:spatial --ack --note "reviewed" >/tmp/agentlab-decide.txt 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: decide report"; }
( cd "$INBOX" && WT_ROOT="$INBOX_WT" "$ROOT/bin/agentlab" decide rfc:spatial-test --approve >/tmp/agentlab-decide-rfc.txt 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: decide rfc"; }
grep -qi "Status: approved" "$INBOX/.agentlab/RFC/spatial-test.md" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: RFC status not updated"; }
( cd "$INBOX" && WT_ROOT="$INBOX_WT" "$ROOT/bin/agentlab" inbox --json >/tmp/agentlab-inbox-after.json 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: inbox after decide"; }
python3 - <<'PYCHECK2' && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: decided items still visible"; }
import json
ids={i['id'] for i in json.load(open('/tmp/agentlab-inbox-after.json'))['items']}
assert 'report:spatial' not in ids
assert 'rfc:spatial-test' not in ids
PYCHECK2
rm -rf "$INBOX" "$INBOX_WT"

echo "== ticket ledger"
TICKET="$TMP/ticket"
mkdir -p "$TICKET"
cp -R "$ROOT/tests/fixtures/mini-target/." "$TICKET/"
( cd "$TICKET" && git init -q -b main && git add -A && git commit -q -m init ) >/dev/null

( cd "$TICKET" && "$ROOT/bin/agentlab" ticket new t1 --title "Ticket test" --workstream spatial >/tmp/agentlab-ticket-new.txt 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: ticket new"; cat /tmp/agentlab-ticket-new.txt; }
( cd "$TICKET" && "$ROOT/bin/agentlab" ticket show t1 --json >/tmp/agentlab-ticket.json 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: ticket show"; }
python3 - <<'PYCHECK' && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: ticket fields"; }
import json
t=json.load(open('/tmp/agentlab-ticket.json'))
assert t['status']=='proposed'
assert len(t['policy_version'])==16
assert t['scope_ref']=='.agentlab/scope/spatial.txt'
PYCHECK

( cd "$TICKET" && "$ROOT/bin/agentlab" inbox --json >/tmp/agentlab-ticket-inbox.json 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: ticket inbox"; }
python3 - <<'PYCHECK' && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: ticket inbox item"; }
import json
items={i['id']:i for i in json.load(open('/tmp/agentlab-ticket-inbox.json'))['items']}
assert items['ticket:t1']['category']=='pending'
assert items['ticket:t1']['kind']=='ticket'
PYCHECK

( cd "$TICKET" && "$ROOT/bin/agentlab" decide ticket:t1 --approve --note "approved" >/tmp/agentlab-ticket-approve.txt 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: ticket approve"; }
( cd "$TICKET" && "$ROOT/bin/agentlab" ticket show t1 --json >/tmp/agentlab-ticket-authorized.json 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: ticket show authorized"; }
python3 - <<'PYCHECK' && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: ticket authorized"; }
import json
assert json.load(open('/tmp/agentlab-ticket-authorized.json'))['status']=='authorized'
PYCHECK

printf '\n# policy change\n' >> "$TICKET/.agentlab/scope/spatial.txt"
( cd "$TICKET" && "$ROOT/bin/agentlab" ticket revalidate t1 >/tmp/agentlab-ticket-revalidate.txt 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: ticket revalidate"; }
( cd "$TICKET" && "$ROOT/bin/agentlab" ticket show t1 --json >/tmp/agentlab-ticket-stale.json 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: ticket show stale"; }
python3 - <<'PYCHECK' && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: ticket stale"; }
import json
assert json.load(open('/tmp/agentlab-ticket-stale.json'))['status']=='stale'
PYCHECK
( cd "$TICKET" && "$ROOT/bin/agentlab" ticket authorize t1 >/tmp/agentlab-ticket-reauth.txt 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: ticket reauthorize"; }
( cd "$TICKET" && "$ROOT/bin/agentlab" ticket set t1 running >/dev/null 2>&1 && "$ROOT/bin/agentlab" ticket set t1 review >/dev/null 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: ticket review transition"; }
( cd "$TICKET" && "$ROOT/bin/agentlab" inbox --json >/tmp/agentlab-ticket-review.json 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: ticket review inbox"; }
python3 - <<'PYCHECK' && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: ticket review category"; }
import json
items={i['id']:i for i in json.load(open('/tmp/agentlab-ticket-review.json'))['items']}
assert items['ticket:t1']['category']=='review'
assert items['ticket:t1']['kind']=='ticket_review'
PYCHECK
rm -rf "$TICKET"

echo "== github source and candidate approval"
SOURCE="$TMP/source"
mkdir -p "$SOURCE"
cp -R "$ROOT/tests/fixtures/mini-target/." "$SOURCE/"
( cd "$SOURCE" && git init -q -b main && git add -A && git commit -q -m init ) >/dev/null
( cd "$SOURCE" && "$ROOT/bin/agentlab" source github poll --input "$ROOT/tests/fixtures/github-notifications.json" --repo lql341/OneFLOW --json >/tmp/agentlab-source.json 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: source poll"; cat /tmp/agentlab-source.json; }
python3 - <<'PYCHECK' && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: source candidates"; }
import json
r=json.load(open('/tmp/agentlab-source.json'))
assert r['created']==2
assert r['skipped']==1
ids={c['id'] for c in r['candidates']}
assert 'gh-1001-20261102t000000z' in ids
assert 'gh-1002-20261102t000100z' in ids
PYCHECK
( cd "$SOURCE" && "$ROOT/bin/agentlab" inbox --json >/tmp/agentlab-source-inbox.json 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: source inbox"; }
python3 - <<'PYCHECK' && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: candidate inbox item"; }
import json
items={i['id']:i for i in json.load(open('/tmp/agentlab-source-inbox.json'))['items']}
assert items['candidate:gh-1001-20261102t000000z']['category']=='pending'
assert items['candidate:gh-1002-20261102t000100z']['category']=='pending'
PYCHECK
( cd "$SOURCE" && "$ROOT/bin/agentlab" decide candidate:gh-1001-20261102t000000z --approve --workstream spatial --note "accepted" >/tmp/agentlab-source-approve.txt 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: candidate approve"; cat /tmp/agentlab-source-approve.txt; }
( cd "$SOURCE" && "$ROOT/bin/agentlab" ticket show gh-1001-20261102t000000z --json >/tmp/agentlab-source-ticket.json 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: candidate ticket"; }
python3 - <<'PYCHECK' && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: candidate ticket state"; }
import json
t=json.load(open('/tmp/agentlab-source-ticket.json'))
assert t['status']=='authorized'
assert t['source']=='github'
assert t['strength']=='explicit'
PYCHECK
( cd "$SOURCE" && "$ROOT/bin/agentlab" decide candidate:gh-1002-20261102t000100z --reject --note "not now" >/tmp/agentlab-source-reject.txt 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: candidate reject"; }
( cd "$SOURCE" && "$ROOT/bin/agentlab" source github status --json >/tmp/agentlab-source-status.json 2>&1 ) && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: source status"; }
python3 - <<'PYCHECK' && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAILED: source status count"; }
import json
r=json.load(open('/tmp/agentlab-source-status.json'))
assert r['pending_candidates']==0
PYCHECK
rm -rf "$SOURCE"

echo "----"
echo "smoke: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

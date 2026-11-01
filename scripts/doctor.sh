#!/usr/bin/env bash
# Preflight for the agentlab CLI itself: tools, Pi, profile, config, target repo.
set -uo pipefail
PLATFORM="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
ok()  { printf '  ok    %s\n' "$1"; }
warn(){ printf '  warn  %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fail=1; }

echo "agentlab doctor"
echo "home: $PLATFORM"
echo

echo "tools"
for t in git python3; do
  if command -v "$t" >/dev/null 2>&1; then
    ok "$t $("$t" --version 2>/dev/null | head -1)"
  else
    bad "$t not found"
  fi
done
echo

echo "pi"
PI_BIN="${PI_BIN:-pi}"
if command -v "$PI_BIN" >/dev/null 2>&1; then
  ok "$PI_BIN $("$PI_BIN" --version 2>/dev/null | head -1)"
else
  bad "$PI_BIN not found in PATH"
fi
if [ -n "${PI_CODING_AGENT_DIR:-}" ]; then
  if [ -d "$PI_CODING_AGENT_DIR" ]; then
    ok "worker profile $PI_CODING_AGENT_DIR"
    if [ -d "$PI_CODING_AGENT_DIR/extensions" ] && [ -n "$(ls -A "$PI_CODING_AGENT_DIR/extensions" 2>/dev/null)" ]; then
      warn "worker profile has extensions; they load into workers too: $(ls "$PI_CODING_AGENT_DIR/extensions" | tr '\n' ' ')"
    fi
    [ -f "$PI_CODING_AGENT_DIR/settings.json" ] || warn "worker profile has no settings.json yet (defaults apply)"
  else
    warn "worker profile $PI_CODING_AGENT_DIR does not exist yet; Pi will create it on first run"
  fi
else
  warn "PI_CODING_AGENT_DIR is unset: workers will use the same Pi agent dir as your daily Pi"
fi
echo

echo "guard"
if [ -f "$PLATFORM/platform/extensions/guard.ts" ]; then
  ok "platform/extensions/guard.ts"
else
  bad "platform/extensions/guard.ts missing"
fi
echo

echo "target repository"
if root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  ok "git root $root"
  if [ -f "$root/.agentlab/domain.env" ]; then
    ok ".agentlab/domain.env"
    # shellcheck disable=SC1091
    ( . "$root/.agentlab/domain.env"; echo "  ok    mode=${AGENTLAB_MODE:-worker} base=${BASE_REF:-main} modules=${MODULES:-}" )
    if [ -f "$root/AGENTS.md" ]; then
      if grep -q '.agentlab' "$root/AGENTS.md"; then
        ok "root AGENTS.md points at .agentlab"
      else
        warn "root AGENTS.md exists but does not mention .agentlab; workers may miss the rules"
      fi
    else
      warn "no root AGENTS.md: workers will not load the repo rules automatically"
    fi
  else
    warn "no .agentlab/ here; run: agentlab install <domain> <target> <repo>"
  fi
else
  warn "not inside a git repository (fine for 'agentlab install')"
fi

echo
echo "doctor: $([ $fail -eq 0 ] && echo PASS || echo FAIL)"
exit $fail

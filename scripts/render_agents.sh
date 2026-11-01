#!/usr/bin/env bash
# render_agents.sh <out> <platform_agents> <domain_agents> [target_agents] [target_name]
# Single source of truth for the generated .agentlab/AGENTS.md, shared by
# install_target.sh and update.sh so the two cannot drift.
set -euo pipefail
OUT="${1:?out}"; PLATFORM_AGENTS="${2:?platform agents}"; DOMAIN_AGENTS="${3:?domain agents}"
TARGET_AGENTS="${4:-}"; TARGET_NAME="${5:-}"
mkdir -p "$(dirname "$OUT")"
cat "$PLATFORM_AGENTS" > "$OUT"
printf '\n---\n\n' >> "$OUT"
cat "$DOMAIN_AGENTS" >> "$OUT"
if [ -n "$TARGET_AGENTS" ] && [ -f "$TARGET_AGENTS" ]; then
  printf '\n---\n\n# --- target: %s ---\n\n' "$TARGET_NAME" >> "$OUT"
  cat "$TARGET_AGENTS" >> "$OUT"
fi

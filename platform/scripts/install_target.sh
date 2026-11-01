#!/usr/bin/env bash
# Usage: install_target.sh <domain> <target> <target_repo>
# Installs a domain pack plus a target overlay into <target_repo>/.agentlab/.
# Target overlay wins over the generic domain pack. Existing files are not overwritten.
set -euo pipefail
PLATFORM="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="$(cd "$PLATFORM/.." && pwd)"
DOMAIN="${1:?usage: install_target.sh <domain> <target> <target_repo>}"
TARGET_NAME="${2:?usage: install_target.sh <domain> <target> <target_repo>}"
TARGET_REPO="$(cd "${3:?target repo}" && pwd)"
SRC_DOMAIN="$HOME_DIR/domains/$DOMAIN"
SRC_TARGET="$HOME_DIR/targets/$TARGET_NAME"
[ -d "$SRC_DOMAIN" ] || { echo "no domain pack: $DOMAIN"; exit 1; }
[ -d "$SRC_TARGET" ] || { echo "no target pack: $TARGET_NAME"; exit 1; }

DEST="$TARGET_REPO/.agentlab"
mkdir -p "$DEST"/reports "$DEST"/RFC "$DEST"/repro "$DEST"/templates "$DEST"/sessions

copy_missing() {
  local from="$1" to="$2"
  (cd "$from" && find . -type f) | while IFS= read -r f; do
    if [ ! -e "$to/$f" ]; then
      mkdir -p "$(dirname "$to/$f")"
      cp -p "$from/$f" "$to/$f"
    fi
  done
}

# Target overlay first: its TASKS.md, scope/, verification/, target.env, and
# AGENTS.target.md win over the generic domain pack.
copy_missing "$SRC_TARGET" "$DEST"
copy_missing "$SRC_DOMAIN" "$DEST"
copy_missing "$PLATFORM/templates" "$DEST/templates"

# A target profile owns the scope set. Remove generic domain scopes that the
# target does not define, so workers cannot pick up irrelevant modules.
if [ -d "$SRC_TARGET/scope" ]; then
  for f in "$DEST"/scope/*.txt; do
    [ -e "$f" ] || continue
    b="$(basename "$f")"
    [ -f "$SRC_TARGET/scope/$b" ] || rm -f "$f"
  done
fi

if [ ! -f "$DEST/AGENTS.md" ]; then
  cat "$PLATFORM/AGENTS.md" > "$DEST/AGENTS.md"
  printf '\n---\n\n' >> "$DEST/AGENTS.md"
  cat "$DEST/AGENTS.domain.md" >> "$DEST/AGENTS.md"
else
  echo "existing .agentlab/AGENTS.md kept"
fi

if [ -f "$DEST/AGENTS.target.md" ] && ! grep -q "^# --- target:" "$DEST/AGENTS.md"; then
  printf '\n---\n\n# --- target: %s ---\n\n' "$TARGET_NAME" >> "$DEST/AGENTS.md"
  cat "$DEST/AGENTS.target.md" >> "$DEST/AGENTS.md"
fi

# Pi loads AGENTS.md from the repo root, not .agentlab/. Do not overwrite an
# existing OneFLOW AGENTS.md; just tell the operator.
if [ ! -f "$TARGET_REPO/AGENTS.md" ]; then
  cat > "$TARGET_REPO/AGENTS.md" <<'POINTER'
# Agent Lab target repository

Read `.agentlab/AGENTS.md`, `.agentlab/contracts/`, and `.agentlab/scope/<workstream>.txt`
before changing code. The platform scripts live outside this repository.

Do not modify `.agentlab/contracts/`, `.agentlab/verification/`, or platform scripts
without an approved RFC.
POINTER
  echo "created root AGENTS.md pointer"
else
  echo "root AGENTS.md exists; not modified (add a pointer to .agentlab/AGENTS.md manually if needed)"
fi

for d in reports RFC repro sessions; do touch "$DEST/$d/.gitkeep"; done
[ -f "$DEST/verification/run_all.sh" ] && chmod +x "$DEST/verification/run_all.sh" || true
echo "installed domain=$DOMAIN target=$TARGET_NAME -> $DEST"
echo "next: review .agentlab/, commit it to the target repo, then run preflight/run_worker"

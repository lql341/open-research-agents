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

ADDED="$DEST/.install-added"
: > "$ADDED"

copy_missing() {
  local from="$1" to="$2"
  (cd "$from" && find . -type f) | while IFS= read -r f; do
    rel="${f#./}"
    if [ ! -e "$to/$rel" ]; then
      mkdir -p "$(dirname "$to/$rel")"
      cp -p "$from/$rel" "$to/$rel"
      printf '%s\n' "${to#"$TARGET_REPO"/}/$rel" >> "$ADDED"
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
  bash "$HOME_DIR/scripts/render_agents.sh" "$DEST/AGENTS.md" "$PLATFORM/AGENTS.md" \
    "$DEST/AGENTS.domain.md" "$DEST/AGENTS.target.md" "$TARGET_NAME"
  printf '%s\n' ".agentlab/AGENTS.md" >> "$ADDED"
else
  echo "existing .agentlab/AGENTS.md kept"
fi

# Record which pack this .agentlab came from, so 'agentlab update' can re-apply it.
printf 'DOMAIN=%s\nTARGET=%s\n' "$DOMAIN" "$TARGET_NAME" > "$DEST/.pack"

# Pi loads AGENTS.md from the repo root, not .agentlab/. Do not overwrite an
# existing target AGENTS.md; just tell the operator.
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
# Only report files that survived: target scopes may replace domain scopes.
KEPT="$(mktemp)"
while IFS= read -r rel; do
  [ -n "$rel" ] && [ -e "$TARGET_REPO/$rel" ] && printf '%s\n' "$rel" >> "$KEPT"
done < "$ADDED"
count=$(wc -l < "$KEPT" | tr -d ' ')
if [ "$count" -gt 0 ]; then
  echo "added $count file(s):"
  sed 's/^/  + /' "$KEPT"
fi
rm -f "$KEPT"
rm -f "$ADDED"
echo "installed domain=$DOMAIN target=$TARGET_NAME -> $DEST"
echo "next: review .agentlab/, commit it to the target repo, then run agentlab preflight"

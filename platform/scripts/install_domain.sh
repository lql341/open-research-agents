#!/usr/bin/env bash
# Usage: install_domain.sh <domain> <target_repo>
# Installs a domain pack into <target_repo>/.agentlab/ without overwriting existing files.
set -euo pipefail
PLATFORM="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="$(cd "$PLATFORM/.." && pwd)"
DOMAIN="${1:?usage: install_domain.sh <domain> <target_repo>}"
TARGET="$(cd "${2:?target repo}" && pwd)"
SRC="$HOME_DIR/domains/$DOMAIN"
[ -d "$SRC" ] || { echo "no domain pack: $DOMAIN"; exit 1; }
DEST="$TARGET/.agentlab"
mkdir -p "$DEST"/reports "$DEST"/RFC "$DEST"/repro "$DEST"/templates "$DEST"/sessions \
  "$DEST"/tickets "$DEST"/candidates "$DEST"/sources "$DEST"/decisions

copy_missing() {
  local from="$1" to="$2"
  (cd "$from" && find . -type f) | while IFS= read -r f; do
    if [ ! -e "$to/$f" ]; then
      mkdir -p "$(dirname "$to/$f")"
      cp -p "$from/$f" "$to/$f"
    fi
  done
}

copy_missing "$SRC" "$DEST"
copy_missing "$PLATFORM/templates" "$DEST/templates"

if [ ! -f "$DEST/AGENTS.md" ]; then
  cat "$PLATFORM/AGENTS.md" > "$DEST/AGENTS.md"
  printf '\n---\n\n' >> "$DEST/AGENTS.md"
  cat "$DEST/AGENTS.domain.md" >> "$DEST/AGENTS.md"
fi

# Pi loads AGENTS.md from the repo root, not .agentlab/. Add a pointer if the repo has none.
if [ ! -f "$TARGET/AGENTS.md" ]; then
  cat > "$TARGET/AGENTS.md" <<'POINTER'
# Agent Lab target repository

Read `.agentlab/AGENTS.md`, `.agentlab/contracts/`, and `.agentlab/scope/<module>.txt` before changing code.

`core/` is human-maintained; agents read only. Do not modify `.agentlab/contracts/`,
`.agentlab/verification/`, or platform scripts without an approved RFC.
POINTER
  echo "created root AGENTS.md pointer"
else
  echo "root AGENTS.md exists; add a pointer to .agentlab/AGENTS.md manually if needed"
fi

for d in reports RFC repro sessions tickets candidates sources decisions; do touch "$DEST/$d/.gitkeep"; done
[ -f "$DEST/verification/run_all.sh" ] && chmod +x "$DEST/verification/run_all.sh" || true
echo "installed $DOMAIN -> $DEST"
echo "next: edit .agentlab/domain.env and .agentlab/scope/*.txt, fill .agentlab/contracts/, then git add .agentlab && git commit"

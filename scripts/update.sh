#!/usr/bin/env bash
# update.sh [--no-pull]
# 1) fast-forwards the platform repository (this tool),
# 2) re-applies the recorded domain/target pack to the current target repository,
# 3) reports files that changed upstream but were skipped because you edited them.
# Never overwrites an existing .agentlab file.
set -uo pipefail
HOME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLATFORM="$HOME_DIR"
PULL=1
[ "${1:-}" = "--no-pull" ] && PULL=0
fail=0

echo "== platform: $HOME_DIR"
before="$(git -C "$HOME_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
if [ $PULL -eq 1 ] && git -C "$HOME_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  if [ -n "$(git -C "$HOME_DIR" status --porcelain)" ]; then
    echo "  warn: platform working tree is dirty; skipping pull"
  elif git -C "$HOME_DIR" remote get-url origin >/dev/null 2>&1; then
    if git -C "$HOME_DIR" pull --ff-only --quiet 2>/tmp/agentlab-pull.err; then
      echo "  pulled"
    else
      echo "  warn: pull failed: $(head -1 /tmp/agentlab-pull.err)"
    fi
  else
    echo "  no origin remote; skipping pull"
  fi
fi
after="$(git -C "$HOME_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
echo "  commit: $before -> $after"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo
  echo "== target: not inside a git repository; nothing to re-apply"
  echo "update: platform only"
  exit $fail
}
cd "$ROOT"
if [ ! -d .agentlab ]; then
  echo
  echo "== target: $ROOT has no .agentlab/; nothing to re-apply"
  exit $fail
fi

echo
echo "== target: $ROOT"
if [ ! -f .agentlab/.pack ]; then
  echo "  warn: .agentlab/.pack missing (installed by an older version); cannot re-apply automatically"
  echo "        re-run: agentlab install <domain> <target> $ROOT"
  exit 1
fi
# shellcheck disable=SC1091
. .agentlab/.pack
echo "  pack: domain=$DOMAIN target=$TARGET"

ADDED_BEFORE="$(mktemp)"; trap 'rm -f "$ADDED_BEFORE"' EXIT

echo
echo "-- re-apply pack (existing files are kept)"
"$PLATFORM/platform/scripts/install_target.sh" "$DOMAIN" "$TARGET" "$ROOT"

# Generated AGENTS.md is rebuilt from the platform + domain + target rules.
# Compare, but do not overwrite a file the human may have edited.
GEN="$(mktemp)"
bash "$HOME_DIR/scripts/render_agents.sh" "$GEN" "$PLATFORM/platform/AGENTS.md" \
  ".agentlab/AGENTS.domain.md" ".agentlab/AGENTS.target.md" "$TARGET"
if [ -f .agentlab/AGENTS.md ]; then
  if cmp -s "$GEN" .agentlab/AGENTS.md; then
    echo
    echo "-- .agentlab/AGENTS.md is up to date"
  else
    cp "$GEN" .agentlab/AGENTS.md.new
    echo
    echo "-- .agentlab/AGENTS.md differs from the current rules"
    echo "   wrote .agentlab/AGENTS.md.new; diff:"
    diff -u .agentlab/AGENTS.md .agentlab/AGENTS.md.new | sed 's/^/   /' | head -40
    echo "   merge by hand, then: mv .agentlab/AGENTS.md.new .agentlab/AGENTS.md"
  fi
fi
rm -f "$GEN"

echo
echo "== next"
[ -z "$(git status --porcelain)" ] && echo "  no changes; nothing to commit" || {
  echo "  review and commit the new files:"
  git status --short | sed 's/^/    /'
}
echo "update: done (platform $after)"
exit $fail
